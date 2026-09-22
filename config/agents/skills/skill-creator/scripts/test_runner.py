#!/usr/bin/env python3

import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from datetime import datetime, timezone
from pathlib import Path


SKILL_ROOT = Path(__file__).resolve().parent.parent


class RunnerCliTest(unittest.TestCase):
    def setUp(self):
        prefix = f"skill-runner-{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}-"
        directory = tempfile.TemporaryDirectory(prefix=prefix)
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.project = self.root / "project"
        self.project.mkdir()
        self.skill = self.root / "example"
        self.skill.mkdir()
        self.skill_file = self.skill / "SKILL.md"
        self.skill_file.write_text("---\nname: example\ndescription: Original description.\n---\n\nKeep this body.\n")
        self.queries = self.root / "queries.json"
        self.queries.write_text(json.dumps([
            {"query": "positive request", "should_trigger": True},
            {"query": "negative request", "should_trigger": False},
        ]))
        self.adapter = self.root / "adapter with spaces.py"
        self.adapter.write_text(
            "import json, pathlib, sys, uuid\n"
            "request = json.load(sys.stdin)\n"
            "request_file = pathlib.Path.cwd() / (uuid.uuid4().hex + '.json')\n"
            "request_file.write_text(json.dumps(request))\n"
            "if request['operation'] == 'evaluate':\n"
            "    skill = pathlib.Path(request['skill_path']) / 'SKILL.md'\n"
            "    assert 'Keep this body.' in skill.read_text()\n"
            "    triggered = request['description'].startswith('Improved') and request['query'].startswith('positive')\n"
            "    print(json.dumps({'triggered': triggered}))\n"
            "else:\n"
            "    print(json.dumps({'text': '<new_description>Improved description.</new_description>'}))\n"
        )

    def run_cli(self, module, *arguments, include_runner=True):
        command = [
            sys.executable, "-m", f"scripts.{module}",
            "--skill-path", str(self.skill),
            "--project-root", str(self.project),
        ]
        if include_runner:
            command += ["--runner", json.dumps([sys.executable, str(self.adapter)])]
        return subprocess.run(
            command + list(arguments), cwd=SKILL_ROOT,
            capture_output=True, text=True, check=False, timeout=15,
        )

    def evaluate(self, *arguments, **options):
        return self.run_cli(
            "run_eval", "--eval-set", str(self.queries), "--runs-per-query", "1",
            *arguments, **options,
        )

    def requests(self):
        return [json.loads(path.read_text()) for path in self.project.glob("*.json")]

    def test_explicit_runner_handles_opaque_models_and_preserves_the_skill(self):
        original = self.skill_file.read_bytes()
        for model in ("provider-a/model-one", "provider-b:model-two"):
            with self.subTest(model=model):
                result = self.evaluate("--description", "Improved candidate.", "--model", model)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout)["summary"]["passed"], 2)
        requests = self.requests()
        self.assertEqual({item["model"] for item in requests},
                         {"provider-a/model-one", "provider-b:model-two"})
        self.assertTrue(all(item["version"] == 1 for item in requests))
        self.assertTrue(all("should_trigger" not in item for item in requests))
        self.assertEqual(self.skill_file.read_bytes(), original)
        self.assertFalse((self.project / ".claude").exists())

    def test_omitted_model_uses_the_runner_configuration(self):
        result = self.evaluate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(all(item["model"] is None for item in self.requests()))

    def test_missing_or_invalid_runner_fails_before_execution(self):
        for arguments in ((), ("--runner", "provider-cli --prompt"), ("--runner", '[""]')):
            with self.subTest(arguments=arguments):
                result = self.evaluate(*arguments, include_runner=False)
                self.assertEqual(result.returncode, 2)
                self.assertIn("--runner", result.stderr)
        self.assertEqual(self.requests(), [])

    def test_provider_and_protocol_errors_do_not_count_as_negative_selections(self):
        self.queries.write_text('[{"query":"negative request","should_trigger":false}]')
        cases = [
            ("import sys\nsys.stderr.write('provider unavailable')\nsys.exit(7)\n", "runner exited 7: provider unavailable"),
            ("print('{\"error\":\"unsupported model\"}')\n", "runner error: unsupported model"),
            ("print('not JSON')\n", "runner stdout must contain one JSON object"),
            ("print('[]')\n", "runner response must be a JSON object"),
            ("print('{\"triggered\":\"false\"}')\n", "boolean triggered"),
        ]
        for script, diagnostic in cases:
            with self.subTest(diagnostic=diagnostic):
                self.adapter.write_text(script)
                result = self.evaluate()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn(diagnostic, result.stderr)
                self.assertEqual(result.stdout, "")

    def test_invalid_eval_set_fails_before_runner_execution(self):
        for value in ([], [{"query": "q", "should_trigger": "false"}],
                      [{"query": "q", "should_trigger": True}] * 2):
            with self.subTest(value=value):
                self.queries.write_text(json.dumps(value))
                result = self.evaluate()
                self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.requests(), [])

    @unittest.skipUnless(os.name == "posix", "process-group cleanup is POSIX-specific")
    def test_timeout_stops_adapter_children(self):
        marker = self.project / "child-survived"
        child_code = f"import time,pathlib; time.sleep(2); pathlib.Path({str(marker)!r}).touch()"
        self.adapter.write_text(
            "import subprocess, sys, time\n"
            f"subprocess.Popen([sys.executable, '-c', {child_code!r}])\n"
            "time.sleep(60)\n"
        )
        result = self.evaluate("--timeout", "0.5", "--num-workers", "1")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("runner timed out after 0.5 seconds", result.stderr)
        self.assertEqual(result.stdout, "")
        # Cleanup closes pipes immediately; observe beyond the child's deadline.
        time.sleep(2.1)
        self.assertFalse(marker.exists())

    def test_description_cli_uses_the_same_protocol(self):
        evaluation = self.evaluate()
        self.assertEqual(evaluation.returncode, 0, evaluation.stderr)
        results_path = self.root / "results.json"
        results_path.write_text(evaluation.stdout)
        result = self.run_cli(
            "improve_description", "--eval-results", str(results_path),
            "--model", "independent-optimizer",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["description"], "Improved description.")
        completion = [item for item in self.requests() if item["operation"] == "complete"]
        self.assertEqual(len(completion), 1)
        self.assertEqual(completion[0]["model"], "independent-optimizer")

    @unittest.skipUnless(os.name == "posix", "detached process sessions are POSIX-specific")
    def test_timeout_does_not_wait_for_detached_pipe_owners(self):
        marker = self.project / "detached-child-completed"
        pid_file = self.project / "detached-child.pid"
        child_code = f"import time,pathlib; time.sleep(2); pathlib.Path({str(marker)!r}).touch()"
        self.adapter.write_text(
            "import pathlib,subprocess,sys,time\n"
            f"child=subprocess.Popen([sys.executable, '-c', {child_code!r}], start_new_session=True)\n"
            f"pathlib.Path({str(pid_file)!r}).write_text(str(child.pid))\n"
            "time.sleep(60)\n"
        )
        try:
            result = self.evaluate("--timeout", "0.5", "--num-workers", "1")
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn("runner timed out after 0.5 seconds", result.stderr)
            self.assertTrue(pid_file.exists(), "detached child did not start")
            self.assertFalse(marker.exists(), "timeout waited for the detached pipe owner")
        finally:
            if pid_file.exists():
                try:
                    os.killpg(int(pid_file.read_text()), signal.SIGKILL)
                except ProcessLookupError:
                    pass

    @unittest.skipUnless(os.name == "posix", "SIGINT cancellation is POSIX-specific")
    def test_interrupt_stops_active_and_queued_evaluations(self):
        self.queries.write_text(json.dumps([
            {"query": f"request {index}", "should_trigger": False} for index in range(6)
        ]))
        self.adapter.write_text(
            "import json,pathlib,sys,time,uuid\n"
            "request=json.load(sys.stdin)\n"
            "pathlib.Path(uuid.uuid4().hex+'.json').write_text(json.dumps(request))\n"
            "time.sleep(0.6)\n"
            "pathlib.Path('completed').touch()\n"
            "print('{\"triggered\":false}')\n"
        )
        command = [
            sys.executable, "-m", "scripts.run_eval",
            "--skill-path", str(self.skill), "--eval-set", str(self.queries),
            "--runner", json.dumps([sys.executable, str(self.adapter)]),
            "--project-root", str(self.project), "--num-workers", "1", "--runs-per-query", "1",
        ]
        with subprocess.Popen(command, cwd=SKILL_ROOT, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, text=True) as process:
            try:
                deadline = time.monotonic() + 5
                while not list(self.project.glob("*.json")):
                    self.assertIsNone(process.poll(), "evaluation exited before the adapter started")
                    self.assertLess(time.monotonic(), deadline, "adapter did not start")
                    time.sleep(0.01)
                process.send_signal(signal.SIGINT)
                stdout, _ = process.communicate(timeout=5)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.communicate()
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(stdout, "")
        self.assertEqual(len(self.requests()), 1)
        self.assertFalse((self.project / "completed").exists())

    def test_loop_evaluates_revisions_without_editing_the_skill(self):
        original = self.skill_file.read_bytes()
        result = self.run_cli(
            "run_loop", "--eval-set", str(self.queries), "--runs-per-query", "1",
            "--max-iterations", "2", "--report", "none",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(output["iterations_run"], 2)
        self.assertEqual(output["train_size"], 2)
        self.assertEqual(output["best_score"], "2/2")
        self.assertEqual(output["best_description"], "Improved description.")
        self.assertEqual(self.skill_file.read_bytes(), original)
        self.assertEqual({item["operation"] for item in self.requests()}, {"evaluate", "complete"})


if __name__ == "__main__":
    unittest.main()

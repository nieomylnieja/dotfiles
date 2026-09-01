#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3

import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path


SCRIPT = Path(__file__).with_name("ste-lint.py")


class SteLintCliTest(unittest.TestCase):
    def run_lint(self, *arguments, input_text=""):
        return subprocess.run(
            [sys.executable, str(SCRIPT), *arguments],
            input=input_text,
            capture_output=True,
            check=False,
            text=True,
        )

    def test_help(self):
        result = self.run_lint("--help")

        self.assertEqual(result.returncode, 0)
        self.assertIn("Usage: ste-lint.py", result.stdout)

    def test_stdin_json(self):
        result = self.run_lint(input_text="Use a short sentence.\n")

        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["mode"], "flavored")

    def test_unknown_option(self):
        result = self.run_lint("--unknown")

        self.assertEqual(result.returncode, 2)
        self.assertIn("unknown option: --unknown", result.stderr)

    def test_invalid_thresholds(self):
        for value in ("text", "nan", "inf", "-1"):
            with self.subTest(value=value):
                result = self.run_lint("--fail-over", value)
                self.assertEqual(result.returncode, 2)

    def test_duplicate_threshold(self):
        result = self.run_lint("--fail-over", "1", "--fail-over", "2")

        self.assertEqual(result.returncode, 2)
        self.assertIn("can be specified only once", result.stderr)

    def test_threshold_success_and_failure(self):
        clean = self.run_lint("--fail-over", "0", input_text="Use clear words.\n")
        flagged = self.run_lint(
            "--fail-over",
            "0",
            input_text="Utilize a powerful and seamless process.\n",
        )

        self.assertEqual(clean.returncode, 0)
        self.assertEqual(flagged.returncode, 1)

    def test_file_output_uses_full_path(self):
        prefix = f"ste-lint-{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}-"
        with tempfile.TemporaryDirectory(prefix=prefix) as directory:
            prose = Path(directory, "prose.md")
            prose.write_text("Use clear words.\n", encoding="utf-8")

            result = self.run_lint(str(prose))

        self.assertEqual(result.returncode, 0)
        self.assertTrue(result.stdout.startswith(str(prose)))

    def test_missing_file_and_glob(self):
        missing = self.run_lint("/tmp/ste-lint-missing-file.md")
        missing_glob = self.run_lint("/tmp/ste-lint-no-match-*.md")

        self.assertEqual(missing.returncode, 2)
        self.assertIn("file does not exist", missing.stderr)
        self.assertEqual(missing_glob.returncode, 2)
        self.assertIn("no files match pattern", missing_glob.stderr)


if __name__ == "__main__":
    unittest.main()

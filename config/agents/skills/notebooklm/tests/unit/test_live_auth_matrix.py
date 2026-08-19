"""Behavioral wiring tests for the maintainer live-auth matrix.

Two halves:

* the orchestrator half — that each phase still builds the right command, home,
  environment, and timeout for its isolated child process; and
* the scenario half (#2180) — that the recovery cells the orchestrator launches
  are real, importable, typed modules under ``scripts/_live_auth_scenarios/``
  rather than Python source strings fed to ``python -c``.

None of this can prove the *live* behaviour of a cell; only a maintainer matrix
run against real Google credentials does that.
"""

from __future__ import annotations

import argparse
import ast
import importlib
import importlib.util
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from types import ModuleType

import pytest

from scripts import live_auth_matrix

REPO_ROOT = Path(live_auth_matrix.ROOT)
SCENARIO_DIR = REPO_ROOT / "scripts" / "_live_auth_scenarios"

#: ``(scenario module, extra import the module needs)`` for every cell the
#: matrix launches. The extras are the optional server/MCP dependencies, so the
#: table doubles as the list of cells that vanish from a partial install.
SCENARIO_MODULES: tuple[tuple[str, str | None], ...] = (
    ("storage_reload", None),
    ("sibling_concurrent_reload", None),
    ("master_token_recovery", None),
    ("rest_recovery", "fastapi"),
    ("mcp_recovery", "fastmcp"),
    ("browser_refresh", None),
    ("crash_safe_writer", None),
)


def _scenario_argv(module: str, *args: str) -> list[str]:
    """The exact child-process argv a phase must use for ``module``."""
    return [sys.executable, "-m", f"scripts._live_auth_scenarios.{module}", *args]


def _import_scenario(module: str) -> ModuleType:
    """Import one scenario module, skipping when its optional extra is absent."""
    required = dict(SCENARIO_MODULES)[module]
    if required is not None:
        pytest.importorskip(required)
    return importlib.import_module(f"scripts._live_auth_scenarios.{module}")


def _args(*, skip_browser: bool) -> argparse.Namespace:
    argv = [
        "--profile",
        "source",
        "--account",
        "maintainer@example.com",
        "--base-url",
        "https://notebooklm.google.com",
        "--timeout",
        "10",
    ]
    if skip_browser:
        argv.append("--skip-browser")
    return live_auth_matrix.parse_args(argv)


def _interactive_args() -> argparse.Namespace:
    return live_auth_matrix.parse_args(
        [
            "--profile",
            "source",
            "--account",
            "maintainer@example.com",
            "--base-url",
            "https://notebooklm.google.com",
            "--timeout",
            "10",
            "--skip-browser",
            "--skip-rest",
            "--skip-mcp",
            "--include-interactive",
            "--cdp-url",
            "http://127.0.0.1:9222",
        ]
    )


def _source_profile(tmp_path: Path) -> Path:
    source = tmp_path / "profiles" / "source"
    source.mkdir(parents=True)
    (source / "storage_state.json").write_text('{"cookies": []}', encoding="utf-8")
    (source / "master_token.json").write_text('{"token": "test-only"}', encoding="utf-8")
    return source


def test_skip_browser_still_runs_storage_and_access_gate_cells(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    _source_profile(tmp_path)
    monkeypatch.setattr(live_auth_matrix, "DEFAULT_HOME", tmp_path)
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))
    calls: list[str] = []

    always = (
        "phase_baseline",
        "phase_master_refresh",
        "phase_import_filter",
        "phase_hosts",
        "phase_rpc_bundle_health",
        "phase_rpc_health",
        "phase_concurrency",
        "phase_storage_mid_session",
        "phase_sibling_concurrent_mid_session",
        "phase_master_token_mid_session",
        "phase_rest_auth_recovery",
        "phase_mcp_auth_recovery",
        "phase_rpc_access_gate_contract",
        "phase_fault_injection",
        "phase_crash_safety",
    )
    for name in always:
        monkeypatch.setattr(matrix, name, lambda name=name: calls.append(name))
    monkeypatch.setattr(
        matrix,
        "phase_browser_discovery",
        lambda: pytest.fail("browser discovery must be skipped"),
    )
    monkeypatch.setattr(
        matrix,
        "phase_browser_login",
        lambda: pytest.fail("browser login must be skipped"),
    )
    monkeypatch.setattr(
        matrix,
        "phase_browser_mid_session",
        lambda: pytest.fail("browser refresh must be skipped"),
    )
    monkeypatch.setattr(
        matrix,
        "phase_interactive_playwright_login",
        lambda: pytest.fail("interactive Playwright login must be opt-in"),
    )
    monkeypatch.setattr(
        matrix,
        "phase_interactive_master_token_login",
        lambda: pytest.fail("interactive master-token login must be opt-in"),
    )
    monkeypatch.setattr(
        matrix,
        "phase_interactive_cdp_master_token_login",
        lambda: pytest.fail("interactive CDP login must be opt-in"),
    )
    monkeypatch.setattr(matrix, "revision", lambda: "test-revision")
    monkeypatch.setattr(
        matrix,
        "worktree_info",
        lambda: {"worktree_dirty": False, "worktree_diff_hash": "test"},
    )

    assert matrix.run() == 0
    capsys.readouterr()
    assert calls == list(always)


def test_include_interactive_runs_all_human_cells_and_reports_mode(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    _source_profile(tmp_path)
    monkeypatch.setattr(live_auth_matrix, "DEFAULT_HOME", tmp_path)
    matrix = live_auth_matrix.Matrix(_interactive_args())
    calls: list[str] = []
    always = (
        "phase_baseline",
        "phase_master_refresh",
        "phase_import_filter",
        "phase_hosts",
        "phase_rpc_bundle_health",
        "phase_rpc_health",
        "phase_concurrency",
        "phase_storage_mid_session",
        "phase_sibling_concurrent_mid_session",
        "phase_master_token_mid_session",
        "phase_rpc_access_gate_contract",
        "phase_fault_injection",
        "phase_crash_safety",
    )
    for name in always:
        monkeypatch.setattr(matrix, name, lambda: None)
    interactive = (
        "phase_interactive_playwright_login",
        "phase_interactive_master_token_login",
        "phase_interactive_cdp_master_token_login",
    )
    for name in interactive:
        monkeypatch.setattr(matrix, name, lambda name=name: calls.append(name))
    monkeypatch.setattr(matrix, "revision", lambda: "test-revision")
    monkeypatch.setattr(
        matrix,
        "worktree_info",
        lambda: {"worktree_dirty": False, "worktree_diff_hash": "test"},
    )

    assert matrix.run() == 0
    report = json.loads(capsys.readouterr().out)
    assert calls == list(interactive)
    assert report["interactive_cells"] == "executed"
    assert report["interactive_cdp"] == "configured"


@pytest.mark.parametrize(
    "url",
    [
        "https://example.com:9222",
        "http://user@127.0.0.1:9222",
        "http://127.0.0.1:9222/json/version",
        "http://127.0.0.1:9222?token=secret",
        "ws://127.0.0.1:9222",
        "http://127.0.0.1",
    ],
)
def test_interactive_cdp_rejects_non_loopback_or_non_root_url(url: str) -> None:
    with pytest.raises(SystemExit):
        live_auth_matrix.parse_args(
            [
                "--account",
                "maintainer@example.com",
                "--include-interactive",
                "--cdp-url",
                url,
            ]
        )


@pytest.mark.parametrize(
    "argv",
    [
        ["--account", "maintainer@example.com", "--include-interactive"],
        [
            "--account",
            "maintainer@example.com",
            "--cdp-url",
            "http://127.0.0.1:9222",
        ],
    ],
)
def test_interactive_mode_and_cdp_url_require_each_other(argv: list[str]) -> None:
    with pytest.raises(SystemExit):
        live_auth_matrix.parse_args(argv)


def test_interactive_login_cells_use_isolated_profiles_and_verify_artifacts(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    matrix = live_auth_matrix.Matrix(_interactive_args())
    calls: list[tuple[Path, tuple[str, ...], str | None, int | None]] = []

    def fake_cli(
        home: Path,
        *args: str,
        profile: str | None = None,
        timeout: int | None = None,
        **extra: str,
    ) -> subprocess.CompletedProcess[str]:
        assert not extra
        calls.append((home, args, profile, timeout))
        assert profile is not None
        if args[0] == "login":
            profile_dir = home / "profiles" / profile
            profile_dir.mkdir(parents=True, exist_ok=True)
            (profile_dir / "storage_state.json").write_text('{"cookies": []}', encoding="utf-8")
            if "--master-token" in args:
                (profile_dir / "master_token.json").write_text(
                    '{"master_token": "test-only"}', encoding="utf-8"
                )
            return subprocess.CompletedProcess(list(args), 0, "", "")
        return subprocess.CompletedProcess(list(args), 0, '{"status": "ok"}', "")

    probes: list[str] = []

    def fake_cdp_probe(name: str) -> bool:
        probes.append(name)
        matrix.results.append({"name": name, "status": "pass", "reachable": True})
        return True

    monkeypatch.setattr(matrix, "cli", fake_cli)
    monkeypatch.setattr(matrix, "_record_cdp_endpoint", fake_cdp_probe)
    try:
        matrix.phase_interactive_playwright_login()
        matrix.phase_interactive_master_token_login()
        matrix.phase_interactive_cdp_master_token_login()
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)

    login_calls = [call for call in calls if call[1][0] == "login"]
    assert [call[2] for call in login_calls] == [
        "interactive-playwright",
        "interactive-master-token",
        "interactive-cdp-master-token",
    ]
    assert all(call[3] == 390 for call in login_calls)
    assert login_calls[0][1] == (
        "login",
        "--browser-timeout",
        "360",
        "--browser",
        "chromium",
    )
    assert all(call[1][1:3] == ("--browser-timeout", "360") for call in login_calls)
    assert "--master-token" in login_calls[1][1]
    assert "--cdp-url" in login_calls[2][1]
    assert login_calls[2][1][-1] == "http://127.0.0.1:9222"
    assert probes == ["interactive-cdp-endpoint-before", "interactive-cdp-endpoint-after"]
    assert [result["name"] for result in matrix.results] == [
        "interactive-playwright-login",
        "interactive-playwright-live-check",
        "interactive-master-token-login",
        "interactive-master-token-live-check",
        "interactive-cdp-endpoint-before",
        "interactive-cdp-master-token-login",
        "interactive-cdp-master-token-live-check",
        "interactive-cdp-endpoint-after",
    ]
    master_results = [
        result
        for result in matrix.results
        if result["name"]
        in {"interactive-master-token-login", "interactive-cdp-master-token-login"}
    ]
    assert all(result["master_token_created"] is True for result in master_results)
    assert all(result["storage_state_created"] is True for result in master_results)


def test_cdp_endpoint_probe_reports_reachability_without_response_payload(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    matrix = live_auth_matrix.Matrix(_interactive_args())
    observed: dict[str, object] = {}

    class Response:
        status = 200

        def __enter__(self) -> Response:
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def read(self) -> bytes:
            return b'{"Browser": "private-detail"}'

    def fake_urlopen(url: str, *, timeout: int) -> Response:
        observed.update(url=url, timeout=timeout)
        return Response()

    monkeypatch.setattr(live_auth_matrix.urllib.request, "urlopen", fake_urlopen)
    try:
        assert matrix._record_cdp_endpoint("cdp-probe") is True
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)

    assert observed == {"url": "http://127.0.0.1:9222/json/version", "timeout": 5}
    assert matrix.results == [{"name": "cdp-probe", "status": "pass", "reachable": True}]
    assert "private-detail" not in json.dumps(matrix.results)


def test_storage_mid_session_cell_disables_every_external_fallback(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _source_profile(tmp_path)
    monkeypatch.setattr(live_auth_matrix, "DEFAULT_HOME", tmp_path)
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))
    observed: dict[str, object] = {}

    def fake_run(
        command: list[str],
        home: Path,
        *,
        timeout: int | None = None,
        env_overrides: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        env = matrix.env(home, **(env_overrides or {}))
        observed["command"] = command
        observed["env"] = env
        observed["timeout"] = timeout
        copied = matrix.temp / "mid-session-storage" / "profiles" / "mid-session-storage"
        assert not (copied / "master_token.json").exists()
        return subprocess.CompletedProcess(
            command,
            0,
            json.dumps({"before": 2, "after": 2, "reload_calls": 1, "live_cookies": 8}),
            "",
        )

    monkeypatch.setattr(matrix, "_run", fake_run)
    try:
        matrix.phase_storage_mid_session()
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)

    env = observed["env"]
    assert isinstance(env, dict)
    assert env["NOTEBOOKLM_REFRESH_BROWSER"] == ""
    assert env["NOTEBOOKLM_REFRESH_CMD"] == ""
    assert env["NOTEBOOKLM_REFRESH_CMD_MIDSESSION"] == ""
    assert env["NOTEBOOKLM_PROFILE"] == "mid-session-storage"
    command = observed["command"]
    assert isinstance(command, list)
    assert command == _scenario_argv("storage_reload")
    assert matrix.results == [
        {
            "name": "mid-session-storage-reload",
            "status": "pass",
            "returncode": 0,
            "json": {"before": 2, "after": 2, "reload_calls": 1, "live_cookies": 8},
        }
    ]


def test_baseline_report_keeps_count_but_not_private_notebook_inventory(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _source_profile(tmp_path)
    monkeypatch.setattr(live_auth_matrix, "DEFAULT_HOME", tmp_path)
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))
    responses = iter(
        (
            subprocess.CompletedProcess(["auth"], 0, '{"status": "ok"}', ""),
            subprocess.CompletedProcess(
                ["list"],
                0,
                '{"count": 1, "notebooks": [{"id": "private-id", "title": "Private"}]}',
                "",
            ),
        )
    )
    monkeypatch.setattr(matrix, "cli", lambda *args, **kwargs: next(responses))
    try:
        matrix.phase_baseline()
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)

    assert matrix.results[1]["json"] == {"count": 1}
    assert "private-id" not in json.dumps(matrix.results)


@pytest.mark.parametrize(
    ("returncode", "stdout"),
    [
        (0, '[{"id": "private-id", "title": "Private"}]'),
        (0, '{"notebooks": [{"id": "private-id", "title": "Private"}]}'),
        (0, "not-json-private-id"),
        (1, '{"count": 1, "notebooks": [{"id": "private-id"}]}'),
    ],
)
def test_baseline_report_fails_closed_without_private_inventory(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    returncode: int,
    stdout: str,
) -> None:
    _source_profile(tmp_path)
    monkeypatch.setattr(live_auth_matrix, "DEFAULT_HOME", tmp_path)
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))
    responses = iter(
        (
            subprocess.CompletedProcess(["auth"], 0, '{"status": "ok"}', ""),
            subprocess.CompletedProcess(["list"], returncode, stdout, "list failed"),
        )
    )
    monkeypatch.setattr(matrix, "cli", lambda *args, **kwargs: next(responses))
    try:
        matrix.phase_baseline()
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)

    result = matrix.results[1]
    assert result["status"] == "fail"
    assert "json" not in result
    assert "private-id" not in json.dumps(result)


def test_realistic_recovery_cells_wire_real_process_and_adapter_paths(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _source_profile(tmp_path)
    monkeypatch.setattr(live_auth_matrix, "DEFAULT_HOME", tmp_path)
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))
    matrix.args.rpc_health_full = True
    matrix.args.read_only_notebook_id = "read-only-id"
    matrix.args.generation_notebook_id = "generation-id"
    calls: list[tuple[list[str], dict[str, str], int | None]] = []

    def fake_run(
        command: list[str],
        home: Path,
        *,
        timeout: int | None = None,
        env_overrides: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        env = matrix.env(home, **(env_overrides or {}))
        if env.get("NOTEBOOKLM_PROFILE") == "mid-session-browser":
            browser_profile = (
                matrix.temp / "mid-session-browser" / "profiles" / "mid-session-browser"
            )
            assert not (browser_profile / "master_token.json").exists()
        calls.append((command, env, timeout))
        return subprocess.CompletedProcess(command, 0, "{}", "")

    monkeypatch.setattr(matrix, "_run", fake_run)
    try:
        matrix.phase_rpc_health()
        matrix.phase_sibling_concurrent_mid_session()
        matrix.phase_master_token_mid_session()
        matrix.phase_rest_auth_recovery()
        matrix.phase_mcp_auth_recovery()
        matrix.phase_browser_mid_session()
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)

    by_profile = {
        env["NOTEBOOKLM_PROFILE"]: (command, env, timeout) for command, env, timeout in calls
    }
    assert len(by_profile) == len(calls), "a phase issued more than one subprocess call"

    rpc_command, rpc_env, rpc_timeout = by_profile["rpc-health"]
    assert rpc_command[-1] == "--full"
    assert "check_rpc_health.py" in rpc_command[-2]
    assert rpc_env["NOTEBOOKLM_READ_ONLY_NOTEBOOK_ID"] == "read-only-id"
    assert rpc_env["NOTEBOOKLM_GENERATION_NOTEBOOK_ID"] == "generation-id"
    assert rpc_timeout == 300

    assert by_profile["mid-session-sibling"][0] == _scenario_argv("sibling_concurrent_reload")
    assert by_profile["mid-session-master"][0] == _scenario_argv("master_token_recovery")
    assert by_profile["rest-live"][0] == _scenario_argv("rest_recovery")
    assert by_profile["rest-live"][1]["NOTEBOOKLM_SERVER_TOKEN"] == "matrix-rest-token"
    assert by_profile["mcp-live"][0] == _scenario_argv("mcp_recovery")

    browser_command, browser_env, browser_timeout = by_profile["mid-session-browser"]
    assert browser_command == _scenario_argv("browser_refresh")
    assert browser_env["NOTEBOOKLM_PROFILE"] == "mid-session-browser"
    assert browser_env["NOTEBOOKLM_HEADLESS_REAUTH"] == ""
    assert browser_timeout == 180


def test_run_normalizes_launch_failure(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))

    def fail_to_launch(*args: object, **kwargs: object) -> None:
        raise FileNotFoundError("private path must not be copied")

    monkeypatch.setattr(live_auth_matrix.subprocess, "Popen", fail_to_launch)
    try:
        result = matrix._run(["missing-command"], tmp_path)
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)

    assert result.returncode == 127
    assert result.stdout == ""
    assert result.stderr == "unable to launch matrix phase: FileNotFoundError"
    assert "private path" not in result.stderr


def test_concurrent_refresh_reaps_started_worker_after_partial_launch_failure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _source_profile(tmp_path)
    monkeypatch.setattr(live_auth_matrix, "DEFAULT_HOME", tmp_path)
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))

    class StartedProcess:
        pid = 12345
        returncode: int | None = None
        terminated = False
        communicated = False

        def poll(self) -> int | None:
            return self.returncode

        def communicate(self, timeout: int | None = None) -> tuple[str, str]:
            self.communicated = True
            self.returncode = -9
            return "", ""

    started = StartedProcess()
    launch_calls = 0

    def partial_launch(*args: object, **kwargs: object) -> StartedProcess:
        nonlocal launch_calls
        launch_calls += 1
        if launch_calls == 1:
            return started
        raise OSError("private launch detail")

    def terminate(process: object) -> None:
        assert process is started
        started.terminated = True

    monkeypatch.setattr(live_auth_matrix.subprocess, "Popen", partial_launch)
    monkeypatch.setattr(matrix, "_terminate_process_tree", terminate)
    try:
        matrix.phase_concurrency()
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)

    assert started.terminated is True
    assert started.communicated is True
    assert matrix.results == [
        {
            "name": "concurrent-refresh",
            "status": "fail",
            "returncodes": [127],
            "error": "unable to launch refresh worker: OSError",
        }
    ]
    assert "private launch detail" not in json.dumps(matrix.results)


@pytest.mark.skipif(os.name == "nt", reason="POSIX process-group regression")
def test_run_terminates_descendant_processes_on_timeout(tmp_path: Path) -> None:
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))
    child_pid_path = tmp_path / "child.pid"
    script = (
        "import subprocess, sys, time\n"
        "from pathlib import Path\n"
        "child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])\n"
        "Path(sys.argv[1]).write_text(str(child.pid), encoding='utf-8')\n"
        "time.sleep(60)\n"
    )
    try:
        result = matrix._run(
            [sys.executable, "-c", script, str(child_pid_path)],
            tmp_path,
            timeout=1,
        )
        child_pid = int(child_pid_path.read_text(encoding="utf-8"))
        for _ in range(40):
            try:
                os.kill(child_pid, 0)
            except ProcessLookupError:
                break
            time.sleep(0.05)
        else:
            pytest.fail("timed-out matrix phase left its descendant running")
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)

    assert result.returncode == 124


# ---------------------------------------------------------------------------
# The scenario package (#2180)
#
# These replace the string-matching assertions that used to grep the generated
# ``python -c`` source ("``tracked_master`` appears in the script"). Grepping a
# source literal proved the orchestrator built a string, not that anything was
# runnable; a typo inside the string passed the test and failed only on a live
# maintainer run. The checks below instead import the real module.
# ---------------------------------------------------------------------------


def test_matrix_no_longer_ships_python_programs_through_dash_c() -> None:
    """No phase may hand a multi-line Python program to ``python -c``."""
    source = (REPO_ROOT / "scripts" / "live_auth_matrix.py").read_text(encoding="utf-8")
    tree = ast.parse(source)
    offenders = [
        node.lineno
        for node in ast.walk(tree)
        if isinstance(node, ast.Constant) and isinstance(node.value, str) and node.value == "-c"
    ]
    # Scoped to the orchestrator on purpose: this test file still uses
    # ``python -c`` for the process-group regression helper, which is a throwaway
    # sleep loop rather than a matrix cell.
    assert offenders == [], (
        "scripts/live_auth_matrix.py builds a `python -c` command at lines "
        f"{offenders}; live-auth cells belong in scripts/_live_auth_scenarios/ (#2180)"
    )


def test_every_scenario_module_the_matrix_names_exists_on_disk() -> None:
    for module, _extra in SCENARIO_MODULES:
        assert (SCENARIO_DIR / f"{module}.py").is_file(), module
    on_disk = {path.stem for path in SCENARIO_DIR.glob("*.py") if not path.stem.startswith("_")}
    assert on_disk == {module for module, _extra in SCENARIO_MODULES}


@pytest.mark.parametrize("module", [name for name, _extra in SCENARIO_MODULES])
def test_scenario_modules_expose_typed_entry_points(module: str) -> None:
    """Each cell is importable, documented, and annotated.

    Annotations read back as strings because every scenario module carries
    ``from __future__ import annotations``.
    """
    imported = _import_scenario(module)
    assert callable(imported.main)
    assert imported.main.__doc__, f"{module}.main is undocumented"
    assert imported.main.__annotations__["return"] == "None"
    if module == "crash_safe_writer":
        # The writer is the one cell with no JSON contract: it prints nothing
        # and is expected to be killed, so it has no ``scenario()``/``PROFILE``.
        return
    assert imported.scenario.__annotations__["return"] == "ScenarioResult"
    assert imported.PROFILE


def test_scenario_profiles_match_the_orchestrator_phase_environments(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A cell's ``PROFILE`` must be the profile its phase copies credentials to.

    The scenario names its profile and the orchestrator names it again in
    ``env_overrides``; nothing links the two at runtime, so a rename on one side
    would only surface as an authentication failure on a live run.
    """
    _source_profile(tmp_path)
    monkeypatch.setattr(live_auth_matrix, "DEFAULT_HOME", tmp_path)
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))
    seen: dict[str, str] = {}

    def fake_run(
        command: list[str],
        home: Path,
        *,
        timeout: int | None = None,
        env_overrides: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        env = matrix.env(home, **(env_overrides or {}))
        seen[command[2].rsplit(".", 1)[-1]] = env["NOTEBOOKLM_PROFILE"]
        return subprocess.CompletedProcess(command, 0, "{}", "")

    monkeypatch.setattr(matrix, "_run", fake_run)
    try:
        matrix.phase_storage_mid_session()
        matrix.phase_sibling_concurrent_mid_session()
        matrix.phase_master_token_mid_session()
        matrix.phase_rest_auth_recovery()
        matrix.phase_mcp_auth_recovery()
        matrix.phase_browser_mid_session()
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)

    assert set(seen) == {
        "storage_reload",
        "sibling_concurrent_reload",
        "master_token_recovery",
        "rest_recovery",
        "mcp_recovery",
        "browser_refresh",
    }
    for module, profile in seen.items():
        assert profile == _import_scenario(module).PROFILE, module


def test_rest_scenario_bearer_token_matches_the_phase_override(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The REST cell's ``Authorization`` header must match the served token."""
    pytest.importorskip("fastapi")
    _source_profile(tmp_path)
    monkeypatch.setattr(live_auth_matrix, "DEFAULT_HOME", tmp_path)
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))
    served: dict[str, str] = {}

    def fake_run(
        command: list[str],
        home: Path,
        *,
        timeout: int | None = None,
        env_overrides: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        served.update(matrix.env(home, **(env_overrides or {})))
        return subprocess.CompletedProcess(command, 0, "{}", "")

    monkeypatch.setattr(matrix, "_run", fake_run)
    try:
        matrix.phase_rest_auth_recovery()
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)

    rest_recovery = _import_scenario("rest_recovery")
    assert served["NOTEBOOKLM_SERVER_TOKEN"] == rest_recovery.TOKEN
    assert rest_recovery.HEADERS["Authorization"] == f"Bearer {rest_recovery.TOKEN}"


def test_scenarios_never_use_bare_assert() -> None:
    """``python -O`` strips ``assert``; a stripped cell would pass vacuously."""
    offenders: list[str] = []
    for path in sorted(SCENARIO_DIR.glob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8"))
        offenders += [
            f"{path.name}:{node.lineno}" for node in ast.walk(tree) if isinstance(node, ast.Assert)
        ]
    assert offenders == [], f"use require(...) instead of assert: {offenders}"


def test_matrix_child_environment_can_import_the_scenario_package(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Prove importability in a real child, not by reasoning about sys.path.

    ``PYTHONSAFEPATH`` is forced on so the check cannot pass merely because
    ``python -m`` prepends the working directory.
    """
    _source_profile(tmp_path)
    monkeypatch.setattr(live_auth_matrix, "DEFAULT_HOME", tmp_path)
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))
    modules = [
        name
        for name, extra in SCENARIO_MODULES
        if extra is None or importlib.util.find_spec(extra) is not None
    ]
    env = matrix.env(tmp_path / "child-home", PYTHONSAFEPATH="1")
    try:
        proc = subprocess.run(
            [
                sys.executable,
                "-c",
                "import importlib, sys\n"
                "for name in sys.argv[1:]:\n"
                "    importlib.import_module('scripts._live_auth_scenarios.' + name)\n"
                "print('ok')\n",
                *modules,
            ],
            cwd=REPO_ROOT,
            env=env,
            text=True,
            capture_output=True,
            timeout=120,
            check=False,
        )
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)

    assert proc.returncode == 0, proc.stderr[-2000:]
    assert proc.stdout.strip() == "ok"


def test_matrix_child_environment_exposes_repo_root_and_src(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _source_profile(tmp_path)
    monkeypatch.setattr(live_auth_matrix, "DEFAULT_HOME", tmp_path)
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))
    try:
        entries = matrix.env(tmp_path)["PYTHONPATH"].split(os.pathsep)
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)
    assert entries == [str(REPO_ROOT / "src"), str(REPO_ROOT)]


def test_crash_safety_phase_launches_the_writer_module(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _source_profile(tmp_path)
    monkeypatch.setattr(live_auth_matrix, "DEFAULT_HOME", tmp_path)
    matrix = live_auth_matrix.Matrix(_args(skip_browser=True))
    commands: list[list[str]] = []

    class FakePopen:
        def __init__(self, command: list[str], **kwargs: object) -> None:
            commands.append(command)

        def kill(self) -> None:
            return None

        def wait(self, timeout: int | None = None) -> int:
            return 0

    monkeypatch.setattr(live_auth_matrix.subprocess, "Popen", FakePopen)
    monkeypatch.setattr(live_auth_matrix.time, "sleep", lambda _seconds: None)
    try:
        matrix.phase_crash_safety()
        target = matrix.temp / "crash" / "storage_state.json"
        source = tmp_path / "profiles" / "source" / "storage_state.json"
        assert commands == [_scenario_argv("crash_safe_writer", str(target), str(source))] * 3
    finally:
        live_auth_matrix.shutil.rmtree(matrix.temp, ignore_errors=True)


def test_crash_safe_writer_rewrites_the_target_canonically(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Run the real writer entry point, with no subprocess and no credentials.

    This is the one cell whose whole body can be exercised offline: it needs no
    live session, only a syntactically complete storage state. It pins the argv
    order (target first, source second) and the ``include_domains=None`` policy
    that makes the crash cell rewrite the state unfiltered.
    """
    writer = _import_scenario("crash_safe_writer")
    monkeypatch.setattr(writer, "WRITE_ITERATIONS", 2)
    cookies = [
        {"name": name, "value": "redacted", "domain": ".google.com", "path": "/"}
        for name in (
            "SID",
            "APISID",
            "SAPISID",
            "LSID",
            "HSID",
            "SSID",
            "__Secure-1PSID",
            "__Secure-1PSIDTS",
            "__Secure-3PSID",
            "__Secure-3PSIDTS",
        )
    ]
    source = tmp_path / "source.json"
    source.write_text(json.dumps({"cookies": cookies}), encoding="utf-8")
    target = tmp_path / "target.json"
    target.write_text("{}", encoding="utf-8")

    writer.main([str(target), str(source)])

    written = json.loads(target.read_text(encoding="utf-8"))
    # The same required set ``phase_crash_safety`` re-checks after each kill.
    assert {"SID", "APISID", "SAPISID", "LSID"} <= {cookie["name"] for cookie in written["cookies"]}
    assert json.loads(source.read_text(encoding="utf-8"))["cookies"] == cookies


def test_crash_safe_writer_loops_over_the_canonical_writer(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The cell must keep hammering one writer call so a kill can land mid-write."""
    writer = _import_scenario("crash_safe_writer")
    monkeypatch.setattr(writer, "WRITE_ITERATIONS", 3)
    calls: list[tuple[Path, dict[str, object], object]] = []

    def fake_replace(path: Path, state: dict[str, object], *, include_domains: object) -> None:
        calls.append((path, state, include_domains))

    monkeypatch.setattr(writer, "replace_from_login", fake_replace)
    source = tmp_path / "source.json"
    source.write_text(json.dumps({"cookies": []}), encoding="utf-8")
    target = tmp_path / "target.json"

    writer.main([str(target), str(source)])

    assert calls == [(target, {"cookies": []}, None)] * 3


def test_require_raises_a_named_scenario_error() -> None:
    scenarios = importlib.import_module("scripts._live_auth_scenarios")
    scenarios.require(True, "must not raise")
    with pytest.raises(scenarios.ScenarioError, match="the invariant name"):
        scenarios.require(False, "the invariant name")
    assert issubclass(scenarios.ScenarioError, RuntimeError)


def test_run_scenario_emits_one_json_line_after_the_scenario_returns(
    capsys: pytest.CaptureFixture[str],
) -> None:
    scenarios = importlib.import_module("scripts._live_auth_scenarios")
    order: list[str] = []

    async def scenario() -> dict[str, object]:
        order.append("scenario")
        return {"before": 2, "after": 2}

    scenarios.run_scenario(scenario)
    out = capsys.readouterr().out
    assert order == ["scenario"]
    assert json.loads(out) == {"before": 2, "after": 2}
    assert out.count("\n") == 1


def test_run_scenario_emits_nothing_when_the_scenario_fails(
    capsys: pytest.CaptureFixture[str],
) -> None:
    scenarios = importlib.import_module("scripts._live_auth_scenarios")

    async def scenario() -> dict[str, object]:
        scenarios.require(False, "storage reload rung was not exercised")
        raise AssertionError("unreachable")

    with pytest.raises(scenarios.ScenarioError):
        scenarios.run_scenario(scenario)
    assert capsys.readouterr().out == ""


def test_scenarios_never_read_or_write_text_with_the_ambient_locale() -> None:
    """Every text read/write in a cell must pin ``encoding=``.

    ``phase_crash_safety`` reads and writes with explicit UTF-8 on both sides,
    so a locale-dependent read inside the cell is not merely inconsistent: it
    raises before the first write, and the parent then re-reads its own pristine
    copy, parses it happily, and reports the cell as PASS without the canonical
    writer ever having run.
    """
    offenders: list[str] = []
    for path in sorted(SCENARIO_DIR.glob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if (
                isinstance(node, ast.Call)
                and isinstance(node.func, ast.Attribute)
                and node.func.attr in {"read_text", "write_text"}
                and not any(kw.arg == "encoding" for kw in node.keywords)
            ):
                offenders.append(f"{path.name}:{node.lineno} {node.func.attr}()")
    assert offenders == [], f"pass encoding='utf-8' explicitly: {offenders}"


def test_scenarios_never_pass_subprocess_output_as_an_invariant_message() -> None:
    """``require`` messages must name the invariant, not echo a child's output.

    ``_contract.require`` documents that a message "must name the broken
    invariant, never quote a credential". Forwarding the stderr tail of
    ``notebooklm login --master-token-refresh`` breaks that: the tail is
    arbitrary CLI logging, it lands in the scenario's own stderr, and the
    orchestrator copies that into a report meant for a release checklist.
    """
    offenders: list[str] = []
    for path in sorted(SCENARIO_DIR.glob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if not (
                isinstance(node, ast.Call)
                and isinstance(node.func, ast.Name)
                and node.func.id == "require"
                and len(node.args) == 2
            ):
                continue
            leaked = [
                child.attr
                for child in ast.walk(node.args[1])
                if isinstance(child, ast.Attribute) and child.attr in {"stderr", "stdout"}
            ]
            offenders += [f"{path.name}:{node.lineno} .{attr}" for attr in leaked]
    assert offenders == [], f"name the invariant instead of echoing child output: {offenders}"


def test_scenarios_restore_owner_only_mode_when_replacing_a_profile_file() -> None:
    """Any hand-rolled ``os.replace`` onto a profile file must pin 0o600.

    ``atomic_write_json`` writes credential files at 0o600
    (``src/notebooklm/_atomic_io.py``), but a bare ``write_text`` lands at the
    process umask and ``os.replace`` carries that mode onto the profile.
    """
    offenders: list[str] = []
    for path in sorted(SCENARIO_DIR.glob("*.py")):
        source = path.read_text(encoding="utf-8")
        tree = ast.parse(source)
        chmod_lines = {
            node.lineno
            for node in ast.walk(tree)
            if isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and node.func.attr == "chmod"
        }
        for node in ast.walk(tree):
            if (
                isinstance(node, ast.Call)
                and isinstance(node.func, ast.Attribute)
                and node.func.attr == "replace"
                and isinstance(node.func.value, ast.Name)
                and node.func.value.id == "os"
            ):
                # The chmod must precede the replace inside the same block.
                if not any(line < node.lineno for line in chmod_lines):
                    offenders.append(f"{path.name}:{node.lineno}")
    assert offenders == [], f"chmod(0o600) the temp file before os.replace: {offenders}"


def test_crash_safe_writer_names_its_argv_contract(tmp_path: Path) -> None:
    """A wrong invocation must not look like the SIGKILL the parent sends."""
    writer = _import_scenario("crash_safe_writer")
    scenarios = importlib.import_module("scripts._live_auth_scenarios")
    with pytest.raises(scenarios.ScenarioError, match="needs <target> <source>"):
        writer.main([str(tmp_path / "target.json")])

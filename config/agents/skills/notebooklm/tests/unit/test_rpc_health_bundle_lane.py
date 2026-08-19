"""Regression guards for RPC bundle auth-vs-drift reporting (#2174/#2175)."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path
from typing import Any

import pytest
import yaml

pytestmark = pytest.mark.repo_lint

REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = REPO_ROOT / ".github" / "workflows" / "rpc-health.yml"
BASH = shutil.which("bash")


def _steps() -> list[dict[str, Any]]:
    workflow = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    steps = workflow["jobs"]["health-check"]["steps"]
    assert isinstance(steps, list)
    return steps


def _step(name: str) -> dict[str, Any]:
    for step in _steps():
        if step.get("name") == name:
            return step
    raise AssertionError(f"step not found in rpc-health.yml: {name!r}")


def test_bundle_lane_maps_health_auth_failure_to_typed_bundle_exit() -> None:
    step = _step("Run bundle drift monitor")
    assert step["env"]["HEALTH_EXIT_CODE"] == "${{ steps.health.outputs.exit_code }}"
    script = step["run"]
    assert 'if [ "$HEALTH_EXIT_CODE" = "2" ]' in script
    assert 'echo "outcome=authentication" >> "$GITHUB_OUTPUT"' in script
    assert 'echo "exit_code=2" >> "$GITHUB_OUTPUT"' in script
    assert "No RPC or studio-enum drift conclusion was drawn" in script


def test_bundle_issue_lanes_explicitly_exclude_auth_exit() -> None:
    for name in ("Check for existing bundle drift issue", "Create Issue on bundle drift"):
        condition = _step(name)["if"]
        assert "steps.bundle.outputs.outcome == 'drift'" in condition
        assert "steps.bundle.outputs.exit_code == '1'" not in condition
        assert "steps.bundle.outputs.exit_code !=" not in condition


def test_bundle_auth_failure_routes_to_auth_issue_report() -> None:
    prepare = _step("Prepare authentication failure report")
    assert "steps.health.outputs.exit_code == '2'" in prepare["if"]
    assert "steps.bundle.outputs.exit_code == '2'" in prepare["if"]
    assert "bundle-drift-report.txt" in prepare["run"]

    dedup = _step("Check for existing Auth Failure issue")
    create = _step("Create Issue on Auth Failure")
    for step in (dedup, create):
        assert "steps.health.outputs.exit_code == '2'" in step["if"]
        assert "steps.bundle.outputs.exit_code == '2'" in step["if"]
        assert "||" in step["if"]
    assert create["with"]["content-filepath"] == "auth-failure-report.txt"


@pytest.mark.skipif(BASH is None, reason="needs bash")
def test_bundle_command_skips_capture_after_health_auth_failure(tmp_path: Path) -> None:
    """Execute the auth branch: capture is skipped and no drift claim is emitted."""
    output = tmp_path / "github-output"
    assert BASH is not None
    proc = subprocess.run(
        [BASH, "-c", _step("Run bundle drift monitor")["run"]],
        cwd=tmp_path,
        env={
            **os.environ,
            "HEALTH_EXIT_CODE": "2",
            # A cwd-relative path works in POSIX shells and Git Bash. Passing
            # ``C:\\...`` directly makes Bash interpret the drive/path syntax.
            "GITHUB_OUTPUT": output.name,
            # If the branch accidentally invokes uv, the restricted PATH makes
            # that regression fail instead of touching the network.
            "PATH": "/usr/bin:/bin",
        },
        text=True,
        capture_output=True,
        check=False,
    )

    assert proc.returncode == 2
    assert output.read_text(encoding="utf-8") == "outcome=authentication\nexit_code=2\n"
    report = (tmp_path / "bundle-drift-report.txt").read_text(encoding="utf-8")
    assert "AUTHENTICATION FAILURE" in report
    assert "No RPC or studio-enum drift conclusion was drawn" in report
    assert "ABSENT" not in report


@pytest.mark.skipif(BASH is None, reason="needs bash")
def test_bundle_command_maps_unclassified_process_exit_to_runner_error(tmp_path: Path) -> None:
    """A raw Python/uv exit 1 cannot impersonate a classified drift result."""
    output = tmp_path / "github-output"
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    fake_uv = bin_dir / "uv"
    fake_uv.write_bytes(b"#!/bin/sh\necho synthetic runner crash >&2\nexit 1\n")
    fake_uv.chmod(0o755)

    assert BASH is not None
    proc = subprocess.run(
        [BASH, "-c", _step("Run bundle drift monitor")["run"]],
        cwd=tmp_path,
        env={
            **os.environ,
            "HEALTH_EXIT_CODE": "0",
            "GITHUB_OUTPUT": output.name,
            # The shell runs with cwd=tmp_path, so a relative POSIX entry also
            # addresses the shim correctly under Git Bash on Windows.
            "PATH": "./bin:/usr/bin:/bin",
        },
        text=True,
        capture_output=True,
        check=False,
    )

    assert proc.returncode == 2
    assert output.read_text(encoding="utf-8") == "outcome=runner-error\nexit_code=2\n"
    report = (tmp_path / "bundle-drift-report.txt").read_text(encoding="utf-8")
    assert "synthetic runner crash" in report
    assert "No RPC or studio-enum drift conclusion was drawn" in report

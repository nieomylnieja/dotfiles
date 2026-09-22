"""JSON-over-stdio boundary for provider-specific evaluation adapters."""

import argparse
import json
import math
import os
import signal
import subprocess
import time
from pathlib import Path
from threading import Event


def parse_runner_command(value: str) -> list[str]:
    try:
        command = json.loads(value)
    except json.JSONDecodeError as error:
        raise argparse.ArgumentTypeError("runner must be a JSON argument array") from error
    if not isinstance(command, list) or not command or any(
        not isinstance(arg, str) or not arg for arg in command
    ):
        raise argparse.ArgumentTypeError("runner must be a nonempty array of nonempty strings")
    return command


def add_runner_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--runner", required=True, type=parse_runner_command,
                        help="Adapter command as a JSON argument array; see references/runner.md")
    parser.add_argument("--model", default=None,
                        help="Optional model ID understood by the adapter; defaults to its configuration")
    parser.add_argument("--project-root", type=Path, default=Path.cwd(),
                        help="Adapter working directory; defaults to the current directory")


def call_runner(
    command: list[str], request: dict, timeout: float, cwd: Path | None = None,
    cancelled: Event | None = None,
) -> dict:
    """Execute one request without a shell and reject missing or failed observations."""
    if not math.isfinite(timeout) or timeout <= 0:
        raise ValueError("runner timeout must be finite and positive")
    if cancelled is not None and cancelled.is_set():
        raise RuntimeError("runner cancelled")
    with subprocess.Popen(
        command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, encoding="utf-8", cwd=cwd, start_new_session=os.name == "posix",
    ) as process:
        try:
            deadline = time.monotonic() + timeout
            payload = json.dumps({"version": 1, **request})
            while True:
                if cancelled is not None and cancelled.is_set():
                    raise RuntimeError("runner cancelled")
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise subprocess.TimeoutExpired(command, timeout)
                try:
                    stdout, stderr = process.communicate(
                        payload, timeout=min(0.1, remaining) if cancelled is not None else remaining,
                    )
                    break
                except subprocess.TimeoutExpired:
                    payload = None
        except BaseException as error:
            # Adapters can own CLI children that retain the stdout/stderr pipes.
            if os.name == "posix":
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            else:
                process.kill()
            # The context closes pipes and reaps this process. A detached child
            # can retain a pipe indefinitely, so do not drain output on failure.
            if isinstance(error, subprocess.TimeoutExpired):
                raise RuntimeError(f"runner timed out after {timeout:g} seconds") from error
            raise
        if process.returncode != 0:
            raise RuntimeError(f"runner exited {process.returncode}: {stderr.strip()}")
    try:
        response = json.loads(stdout)
    except json.JSONDecodeError as error:
        raise ValueError("runner stdout must contain one JSON object") from error
    if not isinstance(response, dict):
        raise ValueError("runner response must be a JSON object")
    if "error" in response:
        raise RuntimeError(f"runner error: {response['error']}")
    return response


def complete(
    command: list[str], prompt: str, model: str | None,
    cwd: Path | None = None, timeout: float = 300,
) -> str:
    response = call_runner(
        command, {"operation": "complete", "model": model, "prompt": prompt},
        timeout=timeout, cwd=cwd,
    )
    text = response.get("text")
    if not isinstance(text, str) or not text.strip():
        raise ValueError("complete runner must return a nonempty text field")
    return text

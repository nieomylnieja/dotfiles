"""Layer-C e2e: the real ``notebooklm-server`` subprocess over a socket.

The sibling ``test_server_live.py`` intentionally stays in-process via
``httpx.ASGITransport`` and an already-open live client. This module exercises
the product boundary that path cannot cover:

* the installed ``notebooklm-server`` command starts as a child process,
* uvicorn binds a real loopback socket,
* startup reads the bearer from a temporary token file,
* the selected pytest profile reaches the process via ``--profile``, and
* the `/v1` bearer + loopback-Host gates run over real HTTP.

The default smoke is read-only. It uses ``NOTEBOOKLM_READ_ONLY_NOTEBOOK_ID`` when
set, otherwise it picks a listed notebook with sources and skips if none exists.
A small create/add/wait/chat/delete workflow is present but opt-in through
``NOTEBOOKLM_SERVER_PROCESS_MUTATION=1`` so shared profiles remain safe by
default.
"""

from __future__ import annotations

import asyncio
import json
import os
import shutil
import subprocess
import time
import warnings
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import TextIO
from uuid import uuid4

import httpx
import pytest

# Require the `server` extra; skip the module cleanly when FastAPI/uvicorn or
# python-multipart is absent.
pytest.importorskip("fastapi")
pytest.importorskip("uvicorn")
pytest.importorskip("multipart")

from notebooklm.auth import AuthTokens  # noqa: E402 - after importorskip
from notebooklm.paths import list_profiles, resolve_profile  # noqa: E402 - after importorskip
from notebooklm.server.__main__ import SERVER_TOKEN_FILE_ENV  # noqa: E402
from notebooklm.server._auth import (  # noqa: E402 - after importorskip
    ALLOW_EXTERNAL_BIND_ENV,
    SERVER_TOKEN_ENV,
)

pytestmark = pytest.mark.e2e

_PREFERRED_PROFILE = "peopleconf"
_STARTUP_TIMEOUT = 20.0
_REQUEST_TIMEOUT = 120.0
_TOKENLESS_EXIT_TIMEOUT = 5.0
_LOG_TAIL_CHARS = 4000

_RATE_LIMIT_PHRASES = (
    "rate limit",
    "rate limited",
    "rate-limited",
    "429",
    "too many requests",
)


@dataclass(frozen=True)
class RunningServer:
    """A live ``notebooklm-server`` child process and its HTTP coordinates."""

    base_url: str
    token: str
    profile: str | None
    process: subprocess.Popen
    stdout_path: Path
    stderr_path: Path

    @property
    def auth_headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.token}"}

    def logs(self) -> str:
        return f"stdout:\n{_tail(self.stdout_path)}\nstderr:\n{_tail(self.stderr_path)}"


def _server_command() -> str:
    command = shutil.which("notebooklm-server")
    if command is None:
        pytest.skip("notebooklm-server console script is unavailable")
    return command


def _tail(path: Path, *, limit: int = _LOG_TAIL_CHARS) -> str:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return f"<could not read {path}: {exc}>"
    if len(text) <= limit:
        return text
    return text[-limit:]


def _open_log(path: Path) -> TextIO:
    path.parent.mkdir(parents=True, exist_ok=True)
    return path.open("w", encoding="utf-8")


def _spawn(
    args: list[str],
    *,
    env: dict[str, str],
    stdout_path: Path,
    stderr_path: Path,
) -> subprocess.Popen:
    stdout = _open_log(stdout_path)
    stderr = _open_log(stderr_path)
    try:
        return subprocess.Popen(  # noqa: S603 - executable is resolved by shutil.which
            args,
            stdout=stdout,
            stderr=stderr,
            text=True,
            env=env,
        )
    finally:
        stdout.close()
        stderr.close()


def _stop_process(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def _wait_for_healthz(server: RunningServer) -> None:
    deadline = time.monotonic() + _STARTUP_TIMEOUT
    last_error: BaseException | None = None
    with httpx.Client(base_url=server.base_url, timeout=1.0) as http:
        while time.monotonic() < deadline:
            if server.process.poll() is not None:
                logs = server.logs()
                if "FileNotFoundError" in logs and "storage_state" in logs:
                    pytest.skip("notebooklm-server could not load auth storage")
                raise AssertionError(
                    "notebooklm-server exited before /healthz became ready "
                    f"(code={server.process.returncode})\n{logs}"
                )
            try:
                resp = http.get("/healthz")
            except httpx.HTTPError as exc:
                last_error = exc
            else:
                try:
                    body = resp.json()
                except json.JSONDecodeError as exc:
                    last_error = AssertionError(
                        f"non-JSON /healthz response ({resp.status_code}): {resp.text}"
                    )
                    last_error.__cause__ = exc
                else:
                    if resp.status_code == 200 and body == {"ok": True}:
                        return
                    last_error = AssertionError(f"unexpected /healthz response: {resp.text}")
            time.sleep(0.1)
    raise AssertionError(f"notebooklm-server did not become ready: {last_error}\n{server.logs()}")


def _has_inline_auth() -> bool:
    return bool(os.environ.get("NOTEBOOKLM_AUTH_JSON", "").strip())


def _child_env(*, profile: str | None) -> dict[str, str]:
    env = os.environ.copy()
    env.pop(SERVER_TOKEN_ENV, None)
    env.pop(SERVER_TOKEN_FILE_ENV, None)
    env.pop(ALLOW_EXTERNAL_BIND_ENV, None)
    if profile is None:
        env.pop("NOTEBOOKLM_PROFILE", None)
    else:
        env["NOTEBOOKLM_PROFILE"] = profile
    return env


def _profile_auth_error(profile: str) -> str | None:
    try:
        asyncio.run(AuthTokens.from_storage(profile=profile))
    except (FileNotFoundError, ValueError) as exc:
        return f"{type(exc).__name__}: {exc}"
    return None


def _candidate_profiles() -> list[str]:
    explicit = os.environ.get("NOTEBOOKLM_PROFILE")
    if explicit and explicit.strip():
        return [explicit.strip()]

    candidates = [resolve_profile(), _PREFERRED_PROFILE]
    candidates.extend(list_profiles())
    return list(dict.fromkeys(candidates))


def _select_server_profile() -> str | None:
    if _has_inline_auth():
        return None

    failures: list[str] = []
    for profile in _candidate_profiles():
        error = _profile_auth_error(profile)
        if error is None:
            return profile
        failures.append(f"{profile}: {error}")
    detail = "; ".join(failures) if failures else "no profiles found"
    pytest.skip(f"no authenticated NotebookLM profile available for server process e2e ({detail})")


@pytest.fixture(scope="module")
def server_process(
    tmp_path_factory: pytest.TempPathFactory,
    unused_tcp_port_factory: Callable[[], int],
) -> RunningServer:
    """Start ``notebooklm-server`` once for this module over a real socket."""
    command = _server_command()
    profile = _select_server_profile()
    token = f"e2e-rest-process-{uuid4().hex}"
    temp_dir = tmp_path_factory.mktemp("notebooklm-server-process")
    token_file = temp_dir / "server.token"
    token_file.write_text(token, encoding="utf-8")
    port = unused_tcp_port_factory()
    base_url = f"http://127.0.0.1:{port}"
    stdout_path = temp_dir / "server.stdout.log"
    stderr_path = temp_dir / "server.stderr.log"
    args = [
        command,
        "--host",
        "127.0.0.1",
        "--port",
        str(port),
        "--token-file",
        str(token_file),
        "--log-level",
        "warning",
    ]
    if profile is not None:
        args.extend(["--profile", profile])
    process = _spawn(
        args,
        env=_child_env(profile=profile),
        stdout_path=stdout_path,
        stderr_path=stderr_path,
    )
    server = RunningServer(
        base_url=base_url,
        token=token,
        profile=profile,
        process=process,
        stdout_path=stdout_path,
        stderr_path=stderr_path,
    )
    try:
        _wait_for_healthz(server)
        yield server
    finally:
        _stop_process(process)


def _client(server: RunningServer) -> httpx.Client:
    return httpx.Client(base_url=server.base_url, timeout=_REQUEST_TIMEOUT)


def _skip_if_rate_limited(response: httpx.Response) -> None:
    if response.status_code == 429:
        pytest.skip(f"rate-limited by live NotebookLM API: {response.text}")
    if response.status_code < 400:
        return
    if any(phrase in response.text.lower() for phrase in _RATE_LIMIT_PHRASES):
        pytest.skip(f"rate-limited by live NotebookLM API: {response.text}")


def _assert_ok(response: httpx.Response) -> dict:
    _skip_if_rate_limited(response)
    assert response.status_code == 200, response.text
    return response.json()


def _sources_for(http: httpx.Client, server: RunningServer, notebook_id: str) -> list[dict]:
    source_listing = _assert_ok(
        http.get(
            f"/v1/notebooks/{notebook_id}/sources",
            headers=server.auth_headers,
        )
    )
    return source_listing["sources"]


def _pick_notebook_with_sources(
    http: httpx.Client, server: RunningServer, notebooks: list[dict]
) -> tuple[str, list[dict]]:
    configured = os.environ.get("NOTEBOOKLM_READ_ONLY_NOTEBOOK_ID")
    candidates = [configured] if configured else [nb["id"] for nb in notebooks]
    for candidate in candidates:
        if not candidate:
            continue
        sources = _sources_for(http, server, candidate)
        if sources:
            return candidate, sources
        if configured:
            pytest.skip("configured NOTEBOOKLM_READ_ONLY_NOTEBOOK_ID has no sources")
    pytest.skip("no notebook with sources available for read-only REST process smoke")


@pytest.mark.readonly
def test_tokenless_startup_fails_closed(tmp_path: Path, unused_tcp_port: int) -> None:
    """The real command refuses to start without env/file bearer configuration."""
    command = _server_command()
    stdout_path = tmp_path / "tokenless.stdout.log"
    stderr_path = tmp_path / "tokenless.stderr.log"
    env = os.environ.copy()
    env.pop(SERVER_TOKEN_ENV, None)
    env.pop(SERVER_TOKEN_FILE_ENV, None)
    env.pop(ALLOW_EXTERNAL_BIND_ENV, None)
    process = _spawn(
        [
            command,
            "--host",
            "127.0.0.1",
            "--port",
            str(unused_tcp_port),
            "--log-level",
            "warning",
        ],
        env=env,
        stdout_path=stdout_path,
        stderr_path=stderr_path,
    )
    try:
        deadline = time.monotonic() + _TOKENLESS_EXIT_TIMEOUT
        while process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.05)
        if process.poll() is None:
            raise AssertionError("tokenless server did not exit promptly")
        assert process.returncode != 0
        assert "without a bearer token" in _tail(stderr_path)
    finally:
        _stop_process(process)


class TestRestServerProcessLiveReads:
    """Read-only smoke against the real REST server process."""

    @pytest.mark.readonly
    def test_healthz_is_public(self, server_process: RunningServer) -> None:
        with _client(server_process) as http:
            resp = http.get("/healthz")
        assert resp.status_code == 200
        assert resp.json() == {"ok": True}

    @pytest.mark.readonly
    def test_server_info_is_authenticated_and_profile_aware(
        self, server_process: RunningServer
    ) -> None:
        with _client(server_process) as http:
            resp = http.get("/v1/server/info", headers=server_process.auth_headers)
        body = _assert_ok(resp)
        assert body["server"] == "notebooklm-server"
        assert body["version"]
        if server_process.profile is None:
            assert isinstance(body["auth"]["profile"], str) and body["auth"]["profile"]
        else:
            assert body["auth"]["profile"] == server_process.profile
        assert isinstance(body["auth"]["authenticated"], bool)

    @pytest.mark.readonly
    def test_missing_and_wrong_bearer_are_rejected(self, server_process: RunningServer) -> None:
        with _client(server_process) as http:
            missing = http.get("/v1/notebooks")
            wrong = http.get("/v1/notebooks", headers={"Authorization": "Bearer wrong-token"})
        assert missing.status_code == 401, missing.text
        assert wrong.status_code == 401, wrong.text

    @pytest.mark.readonly
    def test_non_loopback_host_is_rejected(self, server_process: RunningServer) -> None:
        headers = {**server_process.auth_headers, "Host": "evil.example.com"}
        with _client(server_process) as http:
            resp = http.get("/v1/notebooks", headers=headers)
        assert resp.status_code == 403, resp.text

    @pytest.mark.readonly
    def test_notebook_list_get_and_sources_over_real_http(
        self, server_process: RunningServer
    ) -> None:
        with _client(server_process) as http:
            listing = _assert_ok(http.get("/v1/notebooks", headers=server_process.auth_headers))
            notebooks = listing["notebooks"]
            assert isinstance(notebooks, list)
            if not notebooks:
                pytest.skip("live REST process profile has no notebooks")
            notebook_id, sources = _pick_notebook_with_sources(http, server_process, notebooks)
            assert any(nb["id"] == notebook_id for nb in notebooks)

            notebook = _assert_ok(
                http.get(
                    f"/v1/notebooks/{notebook_id}",
                    headers=server_process.auth_headers,
                )
            )
            assert notebook["id"] == notebook_id

            assert isinstance(sources, list) and sources
            assert all(source["id"] for source in sources)


class TestRestServerProcessLiveMutation:
    """Opt-in isolated mutation workflow through the real server process."""

    @pytest.mark.skipif(
        os.environ.get("NOTEBOOKLM_SERVER_PROCESS_MUTATION") != "1",
        reason="set NOTEBOOKLM_SERVER_PROCESS_MUTATION=1 to run live REST process mutations",
    )
    @pytest.mark.timeout(180)
    def test_create_source_wait_chat_delete(self, server_process: RunningServer) -> None:
        notebook_id: str | None = None
        headers = server_process.auth_headers
        with _client(server_process) as http:
            try:
                created = http.post(
                    "/v1/notebooks",
                    headers=headers,
                    json={"title": f"E2E REST Process {uuid4().hex[:8]}"},
                )
                _skip_if_rate_limited(created)
                assert created.status_code == 201, created.text
                notebook_id = created.json()["id"]

                added = http.post(
                    f"/v1/notebooks/{notebook_id}/sources/text",
                    headers=headers,
                    json={
                        "title": "REST process source",
                        "text": (
                            "Live REST process e2e content. "
                            "The workflow verifies subprocess-backed source add, "
                            "polling, and chat over a real HTTP socket."
                        ),
                    },
                )
                _skip_if_rate_limited(added)
                assert added.status_code == 201, added.text
                source_id = added.json()["id"]

                polled = _assert_ok(
                    http.get(
                        f"/v1/notebooks/{notebook_id}/sources/{source_id}",
                        headers=headers,
                    )
                )
                if "source_id" in polled:
                    assert polled["source_id"] == source_id
                else:
                    assert polled["id"] == source_id

                waited = _assert_ok(
                    http.post(
                        f"/v1/notebooks/{notebook_id}/sources/wait",
                        headers=headers,
                        json={"source_ids": [source_id], "timeout": 60.0, "interval": 2.0},
                    )
                )
                assert waited["ok"], waited
                assert any(source["id"] == source_id for source in waited["ready"])

                answer = _assert_ok(
                    http.post(
                        f"/v1/notebooks/{notebook_id}/chat",
                        headers=headers,
                        json={"question": "In one sentence, what is this source about?"},
                    )
                )
                assert isinstance(answer["answer"], str) and answer["answer"].strip()
            finally:
                if notebook_id is not None:
                    try:
                        deleted = http.delete(f"/v1/notebooks/{notebook_id}", headers=headers)
                    except httpx.HTTPError as exc:
                        warnings.warn(
                            f"Failed to cleanup live REST process notebook {notebook_id}: {exc}",
                            stacklevel=2,
                        )
                    else:
                        if deleted.status_code not in (204, 404):
                            warnings.warn(
                                (
                                    f"Failed to cleanup live REST process notebook {notebook_id}: "
                                    f"{deleted.status_code} {deleted.text}"
                                ),
                                stacklevel=2,
                            )

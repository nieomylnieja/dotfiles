"""U1: app scaffold, lifespan, healthz, and the disabled schema surface."""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import AbstractAsyncContextManager, asynccontextmanager

import pytest
from fastapi.testclient import TestClient

from notebooklm import paths
from notebooklm.client import NotebookLMClient
from notebooklm.server.app import create_app

from .conftest import TEST_TOKEN, stale_auth_factory
from .fakes import FakeClient


def test_healthz_is_public_and_minimal() -> None:
    """GET /healthz (outside /v1, no token) returns exactly {"ok": true}."""
    app = create_app(client_factory=_factory(FakeClient()))
    with TestClient(app) as client:
        resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json() == {"ok": True}


def test_lifespan_opens_exactly_one_client_and_closes_it() -> None:
    """The lifespan opens the client once on startup and closes it on shutdown."""
    fake = FakeClient()
    opens = 0
    closed = False

    @asynccontextmanager
    async def factory() -> AsyncIterator[FakeClient]:
        nonlocal opens, closed
        opens += 1
        try:
            yield fake
        finally:
            closed = True

    app = create_app(client_factory=factory)
    with TestClient(app) as client:
        assert client.get("/healthz").status_code == 200
        assert opens == 1
        assert closed is False
    # Context exit shuts the lifespan down.
    assert opens == 1
    assert closed is True


def test_stale_auth_startup_still_serves_healthz(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A stale profile must not keep the process from serving liveness diagnostics."""
    monkeypatch.setattr(paths, "_active_profile", "before")

    app = create_app(profile="work", client_factory=stale_auth_factory())
    with TestClient(app) as client:
        resp = client.get("/healthz")
        assert paths.get_active_profile() == "work"

    assert resp.status_code == 200
    assert resp.json() == {"ok": True}
    assert paths.get_active_profile() == "before"


def test_stale_auth_startup_projects_client_routes_to_auth_error() -> None:
    """Live-client routes fail through the structured auth envelope, not startup."""
    app = create_app(client_factory=stale_auth_factory())
    headers = {"Authorization": f"Bearer {TEST_TOKEN}", "Host": "127.0.0.1"}

    with TestClient(
        app, headers=headers, client=("127.0.0.1", 5555), raise_server_exceptions=False
    ) as client:
        resp = client.get("/v1/notebooks")

    assert resp.status_code == 401
    err = resp.json()["error"]
    assert err["category"] == "auth"
    assert err["retriable"] is False
    assert err["hint"] == "Re-authenticate and retry."


def test_stale_auth_startup_raises_fresh_client_error_per_request() -> None:
    """The stored startup error must not grow tracebacks across repeated requests."""
    app = create_app(client_factory=stale_auth_factory())
    headers = {"Authorization": f"Bearer {TEST_TOKEN}", "Host": "127.0.0.1"}

    with TestClient(
        app, headers=headers, client=("127.0.0.1", 5555), raise_server_exceptions=False
    ) as client:
        stored_error = app.state.notebooklm.client_error
        assert stored_error is not None
        assert stored_error.__traceback__ is None

        assert client.get("/v1/notebooks").status_code == 401
        assert stored_error.__traceback__ is None

        assert client.get("/v1/notebooks").status_code == 401
        assert stored_error.__traceback__ is None


def test_non_auth_client_startup_failure_is_not_swallowed() -> None:
    """Only normalized auth bootstrap failures are degraded into diagnostic state."""

    @asynccontextmanager
    async def factory() -> AsyncIterator[FakeClient]:
        raise FileNotFoundError("missing storage_state.json")
        yield FakeClient()  # pragma: no cover - makes this an async context manager

    app = create_app(client_factory=factory)
    with pytest.raises(FileNotFoundError, match="missing storage_state.json"), TestClient(app):
        pass


def test_create_app_default_factory_threads_profile(monkeypatch) -> None:  # type: ignore[no-untyped-def]
    """#1769: create_app(profile=X) must reach from_storage(profile=X) through the real
    default-factory closure — not just the create_app boundary. Guards the mocked-boundary
    blind spot: a regression to `lambda: _default_factory()` (dropping profile) would pass
    every test that mocks create_app itself.

    Patches the imported ``NotebookLMClient`` class object (not an import-string), which is
    the robust form the ADR-0007 no-forbidden-monkeypatch guard permits.
    """
    seen: dict[str, object] = {}

    @asynccontextmanager
    async def _fake_ctx() -> AsyncIterator[FakeClient]:
        yield FakeClient()

    def _spy_from_storage(**kwargs: object) -> AbstractAsyncContextManager[FakeClient]:
        seen.update(kwargs)
        return _fake_ctx()

    monkeypatch.setattr(NotebookLMClient, "from_storage", staticmethod(_spy_from_storage))
    app = create_app(profile="work")  # no client_factory → exercises the default factory
    with TestClient(app) as client:
        assert client.get("/healthz").status_code == 200
    assert seen == {"profile": "work"}


def test_docs_and_openapi_are_disabled() -> None:
    """The unauthenticated schema UI is off (no tokenless surface)."""
    app = create_app(client_factory=_factory(FakeClient()))
    with TestClient(app) as client:
        assert client.get("/docs").status_code == 404
        assert client.get("/redoc").status_code == 404
        assert client.get("/openapi.json").status_code == 404


def _factory(client: FakeClient):  # type: ignore[no-untyped-def]
    @asynccontextmanager
    async def factory() -> AsyncIterator[FakeClient]:
        yield client

    return factory

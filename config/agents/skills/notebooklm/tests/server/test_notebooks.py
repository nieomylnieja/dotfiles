"""U4: /v1/notebooks list / get / create / delete."""

from __future__ import annotations

from fastapi.testclient import TestClient

from notebooklm._types.notebooks import Notebook
from notebooklm.types import SharePermission

from .fakes import FakeClient


def test_list_returns_notebooks(authed_client: TestClient, fake_client: FakeClient) -> None:
    fake_client.notebooks_store["nb-1"] = Notebook(id="nb-1", title="First")
    resp = authed_client.get("/v1/notebooks")
    assert resp.status_code == 200
    titles = [n["title"] for n in resp.json()["notebooks"]]
    assert titles == ["First"]


def test_list_projects_role_and_role_label(
    authed_client: TestClient, fake_client: FakeClient
) -> None:
    """REST rows carry the caller's role plus its agent-readable label (#2125).

    A bare ``to_jsonable`` pass would ship ``role: 3`` with nothing to decode
    it against, so the routes go through ``_app.views.notebook_view``.
    """
    fake_client.notebooks_store["nb-v"] = Notebook(
        id="nb-v", title="Read only", role=SharePermission.VIEWER
    )
    fake_client.notebooks_store["nb-o"] = Notebook(
        id="nb-o", title="Mine", role=SharePermission.OWNER
    )
    rows = {n["id"]: n for n in authed_client.get("/v1/notebooks").json()["notebooks"]}

    assert rows["nb-v"]["role"] == SharePermission.VIEWER.value
    assert rows["nb-v"]["role_label"] == "viewer"
    assert rows["nb-v"]["is_owner"] is False
    assert rows["nb-o"]["role_label"] == "owner"
    assert rows["nb-o"]["is_owner"] is True


def test_list_unstated_role_stays_null_for_machines(
    authed_client: TestClient, fake_client: FakeClient
) -> None:
    """An unstated role must NOT be optimistically reported as "owner" on the wire.

    The CLI's Access column deliberately degrades to "Owner" to match
    ``is_owner``; machine-readable surfaces stay honest and emit ``null`` so an
    agent is never told a role the backend did not state.
    """
    fake_client.notebooks_store["nb-?"] = Notebook(id="nb-?", title="No role stated")
    row = authed_client.get("/v1/notebooks").json()["notebooks"][0]

    assert row["role"] is None
    assert row["role_label"] is None
    assert row["is_owner"] is True


def test_get_projects_role_label(authed_client: TestClient, fake_client: FakeClient) -> None:
    fake_client.notebooks_store["nb-e"] = Notebook(
        id="nb-e", title="Editable", role=SharePermission.EDITOR
    )
    body = authed_client.get("/v1/notebooks/nb-e").json()

    assert body["role"] == SharePermission.EDITOR.value
    assert body["role_label"] == "editor"
    assert body["is_owner"] is False


def test_list_default_is_unbounded_no_meta(
    authed_client: TestClient, fake_client: FakeClient
) -> None:
    """The default call (no ``limit``) returns the full list, shape unchanged."""
    for i in range(3):
        fake_client.notebooks_store[f"nb-{i}"] = Notebook(id=f"nb-{i}", title=f"N{i}")
    body = authed_client.get("/v1/notebooks").json()
    assert len(body["notebooks"]) == 3
    assert "meta" not in body


def test_list_pagination_slices_and_adds_meta(
    authed_client: TestClient, fake_client: FakeClient
) -> None:
    for i in range(5):
        fake_client.notebooks_store[f"nb-{i}"] = Notebook(id=f"nb-{i}", title=f"N{i}")
    body = authed_client.get("/v1/notebooks", params={"limit": 2, "offset": 1}).json()
    assert len(body["notebooks"]) == 2
    assert body["meta"] == {"total": 5, "has_more": True, "limit": 2, "offset": 1}


def test_list_bad_bounds_is_422(authed_client: TestClient) -> None:
    assert authed_client.get("/v1/notebooks", params={"limit": 0}).status_code == 422
    assert authed_client.get("/v1/notebooks", params={"offset": -1}).status_code == 422


def test_create_returns_201_with_new_notebook(authed_client: TestClient) -> None:
    resp = authed_client.post("/v1/notebooks", json={"title": "Fresh"})
    assert resp.status_code == 201
    assert resp.json()["title"] == "Fresh"


def test_get_existing_notebook(authed_client: TestClient, fake_client: FakeClient) -> None:
    fake_client.notebooks_store["nb-9"] = Notebook(id="nb-9", title="Nine")
    resp = authed_client.get("/v1/notebooks/nb-9")
    assert resp.status_code == 200
    assert resp.json()["id"] == "nb-9"


def test_get_missing_notebook_is_404(authed_client: TestClient) -> None:
    resp = authed_client.get("/v1/notebooks/does-not-exist")
    assert resp.status_code == 404
    assert resp.json()["error"]["category"] == "not_found"


def test_delete_existing_is_204(authed_client: TestClient, fake_client: FakeClient) -> None:
    fake_client.notebooks_store["nb-3"] = Notebook(id="nb-3", title="Three")
    resp = authed_client.delete("/v1/notebooks/nb-3")
    assert resp.status_code == 204
    assert "nb-3" not in fake_client.notebooks_store


def test_delete_missing_is_idempotent_204(authed_client: TestClient) -> None:
    resp = authed_client.delete("/v1/notebooks/never-existed")
    assert resp.status_code == 204


def test_unauthorized_on_each_verb(raw_client: TestClient) -> None:
    h = {"Host": "127.0.0.1"}
    assert raw_client.get("/v1/notebooks", headers=h).status_code == 401
    assert raw_client.post("/v1/notebooks", json={"title": "x"}, headers=h).status_code == 401
    assert raw_client.delete("/v1/notebooks/nb-1", headers=h).status_code == 401


# --- Phase 4: notebook rename (PATCH) ----------------------------------------


def test_rename_notebook(authed_client: TestClient, fake_client: FakeClient) -> None:
    fake_client.notebooks_store["nb-1"] = Notebook(id="nb-1", title="Old")
    resp = authed_client.patch("/v1/notebooks/nb-1", json={"title": "New"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "renamed"
    assert body["new_title"] == "New"
    assert fake_client.notebooks_store["nb-1"].title == "New"


def test_rename_notebook_missing_title_is_422(authed_client: TestClient) -> None:
    assert authed_client.patch("/v1/notebooks/nb-1", json={}).status_code == 422


# --- Phase 4: suggested-prompts ----------------------------------------------


def test_suggested_prompts_default_surface(
    authed_client: TestClient, fake_client: FakeClient
) -> None:
    resp = authed_client.get("/v1/notebooks/nb-1/suggested-prompts")
    assert resp.status_code == 200
    body = resp.json()
    assert body["notebook_id"] == "nb-1"
    assert [s["title"] for s in body["suggestions"]] == ["Q1", "Q2"]
    # Default surface ``ask`` → mode 4.
    assert fake_client.last_suggest["mode"] == 4
    assert fake_client.last_suggest["source_ids"] is None


def test_suggested_prompts_surface_and_source_ids(
    authed_client: TestClient, fake_client: FakeClient
) -> None:
    resp = authed_client.get(
        "/v1/notebooks/nb-1/suggested-prompts",
        params={"surface": "quiz", "source_ids": ["s1", "s2"], "query": "steer"},
    )
    assert resp.status_code == 200
    assert fake_client.last_suggest["mode"] == 8  # quiz
    assert fake_client.last_suggest["source_ids"] == ["s1", "s2"]
    assert fake_client.last_suggest["query"] == "steer"


def test_suggested_prompts_bad_surface_is_422(authed_client: TestClient) -> None:
    resp = authed_client.get("/v1/notebooks/nb-1/suggested-prompts", params={"surface": "bogus"})
    assert resp.status_code == 422


def test_suggest_surface_map_is_shared_neutral_contract() -> None:
    """The REST surface→mode map is imported from the neutral app contract."""
    from notebooklm._app.notebooks import SUGGEST_SURFACE_MAP as neutral_map
    from notebooklm.server.routes.notebooks import SUGGEST_SURFACE_MAP as rest_map

    assert rest_map is neutral_map
    assert rest_map == {
        "ask": 4,
        "audio-deep-dive": 1,
        "audio-brief": 2,
        "audio-critique": 5,
        "audio-debate": 6,
        "video-explainer": 3,
        "video-short": 10,
        "quiz": 8,
        "flashcards": 9,
    }

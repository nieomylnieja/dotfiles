"""Tests for the layer-4 master-token re-mint recovery in _auth/session.py."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import httpx
import pytest

import notebooklm._auth.cookies as cookies_mod
from notebooklm._auth import master_token as mt
from notebooklm._auth import session as session_mod


@pytest.mark.asyncio
async def test_reauth_declines_without_storage_path():
    auth = MagicMock(storage_path=None)
    assert await session_mod._try_master_token_reauth(auth=auth, kernel=MagicMock()) is False


@pytest.mark.asyncio
async def test_reauth_declines_without_token_file(tmp_path):
    auth = MagicMock(storage_path=tmp_path / "storage_state.json")
    assert await session_mod._try_master_token_reauth(auth=auth, kernel=MagicMock()) is False


@pytest.mark.asyncio
async def test_reauth_success_remints_and_reloads(tmp_path):
    mt.write_master_token(
        tmp_path / "master_token.json", email="e@x.com", master_token="aas_et/M", android_id="abc"
    )
    auth = MagicMock(storage_path=tmp_path / "storage_state.json")
    jar = httpx.Cookies()
    jar.set("SID", "v", domain=".google.com")
    # _replace_cookie_jar runs for real against the MagicMock kernel (a no-op on a
    # mock jar) — only the network mint + the recovery-aware reload are stubbed.
    with (
        patch.object(mt, "mint_cookies", new=AsyncMock(return_value=jar)),
        patch.object(mt, "persist_minted_jar") as persist,
        patch.object(cookies_mod, "build_httpx_cookies_from_storage", return_value=httpx.Cookies()),
    ):
        ok = await session_mod._try_master_token_reauth(auth=auth, kernel=MagicMock())
    assert ok is True
    persist.assert_called_once()


@pytest.mark.asyncio
async def test_reauth_returns_false_on_revoked_token(tmp_path):
    mt.write_master_token(
        tmp_path / "master_token.json", email="e@x.com", master_token="aas_et/M", android_id="abc"
    )
    auth = MagicMock(storage_path=tmp_path / "storage_state.json")
    with patch.object(
        mt, "mint_cookies", new=AsyncMock(side_effect=mt.MasterTokenError("revoked"))
    ):
        ok = await session_mod._try_master_token_reauth(auth=auth, kernel=MagicMock())
    assert ok is False

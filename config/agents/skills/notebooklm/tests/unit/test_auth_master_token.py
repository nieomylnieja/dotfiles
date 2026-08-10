"""Unit tests for _auth/master_token.py (headless master-token minting).

No network: gpsoauth is faked via sys.modules; the OAuthLogin/MergeSession GETs
are intercepted with pytest-httpx's httpx_mock.
"""

from __future__ import annotations

import json
import re
import sys
import types

import httpx
import pytest

from notebooklm._auth import master_token as mt
from notebooklm._auth.master_token import MasterTokenError

_OAUTHLOGIN_RE = re.compile(r"^https://accounts\.google\.com/OAuthLogin")
_MERGESESSION_RE = re.compile(r"^https://accounts\.google\.com/MergeSession")
_ROTATE_RE = re.compile(r"^https://accounts\.google\.com/RotateCookies")


@pytest.fixture
def fake_gpsoauth(monkeypatch):
    """Install a fake `gpsoauth` module; tests set .exchange/.oauth return values."""
    mod = types.ModuleType("gpsoauth")
    mod.exchange_return = {"Token": "aas_et/MASTER"}
    mod.oauth_return = {"Auth": "ya29.FAKE"}
    mod.exchange_token = lambda email, oauth_token, android_id: mod.exchange_return
    mod.perform_oauth = lambda *a, **k: mod.oauth_return
    monkeypatch.setitem(sys.modules, "gpsoauth", mod)
    return mod


def _merge_session_cookies(*names: str) -> list[tuple[str, str]]:
    return [("set-cookie", f"{n}=val-{n}; Domain=.google.com; Path=/; Secure") for n in names]


# --- exchange_master_token -------------------------------------------------


def test_exchange_master_token_success(fake_gpsoauth):
    assert mt.exchange_master_token("e@x.com", "oauth_token", "abc") == "aas_et/MASTER"


def test_exchange_master_token_rejected(fake_gpsoauth):
    fake_gpsoauth.exchange_return = {"Error": "BadAuthentication"}
    with pytest.raises(MasterTokenError, match="oauth_token"):
        mt.exchange_master_token("e@x.com", "stale", "abc")


def test_exchange_master_token_no_secret_in_error(fake_gpsoauth):
    fake_gpsoauth.exchange_return = {"Error": "BadAuthentication"}
    with pytest.raises(MasterTokenError) as exc:
        mt.exchange_master_token("e@x.com", "SUPERSECRET", "abc")
    assert "SUPERSECRET" not in str(exc.value)


# --- mint_cookies ----------------------------------------------------------


@pytest.mark.no_default_keepalive_mock  # own the RotateCookies response (mint PSIDTS)
@pytest.mark.asyncio
async def test_mint_cookies_success_and_call_order(fake_gpsoauth, httpx_mock):
    httpx_mock.add_response(url=_OAUTHLOGIN_RE, text="APh-UBERAUTH")
    httpx_mock.add_response(
        url=_MERGESESSION_RE,
        headers=_merge_session_cookies("SID", "APISID", "SAPISID", "HSID"),
    )
    # RotateCookies mints __Secure-1PSIDTS into the same jar so it's complete.
    httpx_mock.add_response(
        url=_ROTATE_RE,
        headers=_merge_session_cookies("__Secure-1PSIDTS"),
    )
    jar = await mt.mint_cookies("e@x.com", "aas_et/MASTER", "abc")
    names = {c.name for c in jar.jar}
    assert {"SID", "APISID", "SAPISID", "__Secure-1PSIDTS"} <= names
    # OAuthLogin -> MergeSession -> RotateCookies (POST), in order.
    reqs = httpx_mock.get_requests()
    assert "OAuthLogin" in str(reqs[0].url)
    assert "MergeSession" in str(reqs[1].url)
    assert "RotateCookies" in str(reqs[2].url) and reqs[2].method == "POST"
    # uberauth was forwarded to MergeSession.
    assert "APh-UBERAUTH" in str(reqs[1].url)


@pytest.mark.asyncio
async def test_mint_cookies_revoked_master_token(fake_gpsoauth, httpx_mock):
    fake_gpsoauth.oauth_return = {"Error": "BadAuthentication"}
    with pytest.raises(MasterTokenError, match="re-bootstrap|master token"):
        await mt.mint_cookies("e@x.com", "revoked", "abc")


@pytest.mark.asyncio
async def test_mint_cookies_no_uberauth(fake_gpsoauth, httpx_mock):
    httpx_mock.add_response(url=_OAUTHLOGIN_RE, text="")
    with pytest.raises(MasterTokenError, match="uberauth"):
        await mt.mint_cookies("e@x.com", "aas_et/MASTER", "abc")


@pytest.mark.asyncio
async def test_mint_cookies_missing_required_cookie(fake_gpsoauth, httpx_mock):
    httpx_mock.add_response(url=_OAUTHLOGIN_RE, text="APh-X")
    # MergeSession returns SID but no secondary binding (APISID/SAPISID).
    httpx_mock.add_response(
        url=_MERGESESSION_RE,
        headers=_merge_session_cookies("SID"),
    )
    # RotateCookies still fires after MergeSession; the autouse keepalive mock
    # answers it, so the required-cookie check is what raises.
    with pytest.raises(MasterTokenError, match="missing required cookies"):
        await mt.mint_cookies("e@x.com", "aas_et/MASTER", "abc")


# --- storage_state_from_jar -----------------------------------------------


def test_storage_state_shape_and_namespace():
    jar = httpx.Cookies()
    jar.set("SID", "v", domain=".google.com", path="/")
    state = mt.storage_state_from_jar(jar, email="e@x.com")
    assert state["origins"] == []
    sid = next(c for c in state["cookies"] if c["name"] == "SID")
    assert sid["domain"] == ".google.com" and "secure" in sid and "httpOnly" in sid
    # notebooklm namespace carries version + account (read by account.py).
    assert state["notebooklm"] == {"version": 1, "account": {"authuser": 0, "email": "e@x.com"}}


# --- master_token.json persistence ----------------------------------------


def test_write_read_master_token_roundtrip_0600(tmp_path):
    path = tmp_path / "master_token.json"
    mt.write_master_token(path, email="e@x.com", master_token="aas_et/M", android_id="abc")
    if sys.platform != "win32":  # Windows ignores POSIX mode bits
        assert (path.stat().st_mode & 0o777) == 0o600
    rec = mt.read_master_token(path)
    assert rec["master_token"] == "aas_et/M" and rec["android_id"] == "abc"


def test_read_master_token_absent(tmp_path):
    assert mt.read_master_token(tmp_path / "nope.json") is None


def test_read_master_token_malformed(tmp_path):
    path = tmp_path / "master_token.json"
    path.write_text(json.dumps({"version": 99}))
    with pytest.raises(MasterTokenError, match="malformed|version"):
        mt.read_master_token(path)


def test_read_master_token_non_dict_json(tmp_path):
    # A bare JSON array must raise MasterTokenError, not AttributeError on .get.
    path = tmp_path / "master_token.json"
    path.write_text(json.dumps([]))
    with pytest.raises(MasterTokenError, match="malformed|version"):
        mt.read_master_token(path)


def test_generate_android_id_is_16_hex():
    aid = mt.generate_android_id()
    assert len(aid) == 16 and int(aid, 16) >= 0 and aid != mt.generate_android_id()


# --- missing optional dependency ------------------------------------------


def test_missing_gpsoauth_raises_actionable(monkeypatch):
    monkeypatch.setitem(sys.modules, "gpsoauth", None)  # `import gpsoauth` -> ImportError
    with pytest.raises(MasterTokenError, match=r"notebooklm-py\[headless\]"):
        mt.exchange_master_token("e@x.com", "tok", "abc")

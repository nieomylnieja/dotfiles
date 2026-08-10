"""In-memory browser-cookie validation and PSIDTS recovery bridge."""

from __future__ import annotations

from typing import Any

from . import cookie_policy as _cookie_policy
from . import cookies as _auth_cookies
from . import psidts_recovery as _recovery


def validate_with_recovery(
    rookiepy_cookies: list[dict[str, Any]],
) -> tuple[dict[str, Any], ValueError | None]:
    """Convert and validate rookiepy cookies, attempting one in-memory heal."""
    storage_state = _auth_cookies.convert_rookiepy_cookies_to_storage_state(rookiepy_cookies)
    initial: _cookie_policy.RequiredCookieValidationError
    try:
        _auth_cookies.extract_cookies_from_storage(storage_state)
    except _cookie_policy.RequiredCookieValidationError as exc:
        initial = exc
    else:
        entries = _auth_cookies._sanitized_auth_entries({"cookies": rookiepy_cookies})
        try:
            _auth_cookies._validate_routable_entries(
                entries,
                to_cookie=_recovery._rookiepy_entry_to_cookie,
                require_routable=True,
            )
        except _cookie_policy.RequiredCookieValidationError as exc:
            initial = exc
        else:
            return storage_state, None

    if not _recovery.recover_psidts_in_memory(rookiepy_cookies):
        return storage_state, initial
    storage_state = _auth_cookies.convert_rookiepy_cookies_to_storage_state(rookiepy_cookies)
    try:
        _auth_cookies.extract_cookies_from_storage(storage_state)
        return storage_state, None
    except _cookie_policy.RequiredCookieValidationError as final:
        return storage_state, final

"""Best-effort heal for Playwright-captured browser state, before persistence."""

from __future__ import annotations

from typing import Any

from . import cookies as _auth_cookies
from . import psidts_recovery as _psidts_recovery


def heal_captured_state(state: dict[str, Any]) -> tuple[dict[str, Any], ValueError | None]:
    """Try one in-memory PSIDTS heal on captured rows; never discard the capture.

    Google does not always answer the login flow's passive ``goto()``
    navigations with ``Set-Cookie: __Secure-1PSIDTS`` (issue #865), so a
    completed browser sign-in can land a state that carries ``SID`` and the
    secondary binding but no usable PSIDTS. Running the shared rookiepy recovery
    contract here means the first command after ``login`` works instead of
    paying for a cold-start heal. The bridge adapts only the ``httpOnly``
    spelling; the converter preserves an existing Playwright ``sameSite`` and
    newly minted recovery cookies take its safe default.

    **The heal is best-effort and this function must not raise.** Returning the
    error instead lets the caller persist what the browser gave us: those
    cookies are the product of an SSO round-trip the user just completed, and
    the disk-based ``_recover_psidts_inline`` retries the heal on the next
    command. Raising would throw that session away on a withheld rotation or a
    transient network blip — strictly worse than the pre-#2061 behaviour of
    writing the imperfect state, and the same mistake as hardening a loader that
    has no heal behind it (#2082 review).

    Note the shape change on the success path: rows are rebuilt from
    ``_sanitized_auth_entries``, which requires a non-empty string ``value``, so
    an empty-valued row that cleared the domain filter is dropped rather than
    persisted verbatim. Auth cookies always carry a value, and a valueless row
    cannot enter a request jar anyway.

    Returns:
        ``(state, error)``. ``error`` is ``None`` when the captured rows already
        validated or the in-memory heal supplied what was missing; otherwise it
        is the final validation error and ``state`` is the caller's input,
        unchanged and still worth persisting.
    """
    rookiepy_rows: list[dict[str, Any]] = []
    for entry in _auth_cookies._sanitized_auth_entries(state):
        rookiepy_entry = dict(entry)
        rookiepy_entry["http_only"] = bool(entry.get("httpOnly", False))
        rookiepy_rows.append(rookiepy_entry)

    validated_state, error = _psidts_recovery.validate_with_recovery(rookiepy_rows)
    if error is not None:
        return state, error
    return {
        "cookies": validated_state["cookies"],
        "origins": list(state.get("origins", [])),
    }, None

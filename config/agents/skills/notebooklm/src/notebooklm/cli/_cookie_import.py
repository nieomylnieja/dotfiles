"""Cookie-JSON import helpers for ``notebooklm auth import-cookies``.

Split out of :mod:`notebooklm.cli.session_cmd` to keep that module under the
ADR-0008 module-size budget (and to keep stdlib names like ``shutil`` off its
retired patch surface). ``register_session_commands`` imports
:func:`_import_cookie_json` / :func:`_read_auth_json_input` back.

These are presentation-adjacent CLI helpers (they raise ``click.ClickException``
directly), so they live beside the command rather than in ``cli/services/``.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import click

from .. import auth
from ..auth import (
    cookie_names_from_storage,
    extract_cookies_from_storage,
    missing_cookies_hint,
    replace_from_login,
)
from .services.playwright_login import filter_storage_state_cookies_by_domain_policy

__all__ = ["_import_cookie_json", "_read_auth_json_input"]


def _read_auth_json_input(path: str) -> Any:
    """Read a cookie JSON payload from a file path or stdin (``-``)."""
    try:
        if path == "-":
            return json.loads(click.get_text_stream("stdin").read())
        return json.loads(Path(path).expanduser().read_text(encoding="utf-8"))
    except UnicodeDecodeError as exc:
        raise click.ClickException(  # cli-input-validation: import-cookies text decode failure
            f"Could not decode {path!r} as UTF-8: {exc}"
        ) from None
    except json.JSONDecodeError as exc:
        raise click.ClickException(  # cli-input-validation: import-cookies JSON parse failure
            f"Invalid JSON: {exc}"
        ) from None
    except OSError as exc:
        raise click.ClickException(  # cli-input-validation: import-cookies JSON read failure
            f"Could not read {path!r}: {exc}"
        ) from None


def _coerce_cookie_json_to_storage_state(payload: Any) -> dict[str, Any]:
    """Normalize supported cookie JSON shapes to Playwright storage_state."""
    if isinstance(payload, dict) and isinstance(payload.get("cookies"), list):
        # Import only cookies: a storage_state's ``origins`` (localStorage /
        # sessionStorage) bypass the cookie-domain allowlist, so drop them rather
        # than persist unrelated site data. Matches the bare-list branch below.
        return {
            "cookies": [_normalize_imported_cookie(cookie) for cookie in payload["cookies"]],
            "origins": [],
        }
    if isinstance(payload, list):
        return {
            "cookies": [_normalize_imported_cookie(cookie) for cookie in payload],
            "origins": [],
        }
    raise click.ClickException(  # cli-input-validation: import-cookies JSON shape validation
        "Cookie JSON must be either a Playwright storage_state object "
        "with a 'cookies' list or a bare list of cookie objects."
    )


def _normalize_imported_cookie(cookie: Any) -> dict[str, Any]:
    """Translate common browser-export cookie fields toward storage_state."""
    if not isinstance(cookie, dict):
        # Reject non-object entries at the boundary rather than pass them through
        # to the downstream extractor (which assumes dict-like rows).
        raise click.ClickException(  # cli-input-validation: import-cookies non-object cookie entry
            "Each cookie must be a JSON object; the cookie list contains a non-object entry."
        )

    try:
        normalized = auth._validate_cookie_shape(cookie, require_nonempty_value=False)
    except ValueError:
        # Keep malformed object rows intact for the shared filter to classify
        # and skip with a bounded diagnostic; do not inspect their raw fields
        # in this adapter.
        return dict(cookie)
    if "expires" not in normalized:
        # EditThisCookie / Cookie-Editor style exports usually call this field
        # ``expirationDate``. Playwright storage_state uses ``expires``.
        normalized["expires"] = normalized.pop("expirationDate", -1)
    normalized.setdefault("path", "/")
    normalized.setdefault("httpOnly", False)
    name = normalized["name"]
    if name.startswith(("__Secure-", "__Host-")):
        # ``__Secure-``/``__Host-`` prefixed cookies are invalid unless ``Secure``
        # (Chromium rejects them on a storage_state re-injection), so force the
        # flag rather than persist an insecure variant when a bare-list export
        # omitted it. Many Google auth cookies (e.g. ``__Secure-1PSIDTS``) use
        # this prefix.
        normalized["secure"] = True
    else:
        normalized.setdefault("secure", False)
    normalized.setdefault("sameSite", "None")
    return normalized


def _nonempty_cookie_names(filtered_state: dict[str, Any]) -> set[str]:
    """Names of ``filtered_state`` cookies that carry a non-empty string value.

    Reads the raw cookie list rather than the flattened
    ``extract_cookies_from_storage`` dict, so a non-empty cookie is never masked
    by an empty same-name duplicate — matching the runtime jar, which skips empty
    rows when building httpx cookies.
    """
    return {
        cookie["name"]
        for cookie in filtered_state.get("cookies", [])
        if isinstance(cookie, dict)
        and isinstance(cookie.get("name"), str)
        and isinstance(cookie.get("value"), str)
        and cookie["value"]
    }


def _has_usable_secondary_binding(filtered_state: dict[str, Any]) -> bool:
    """Whether ``filtered_state`` carries a non-empty secondary auth binding.

    Restates the canonical rule from ``_auth.cookie_policy`` at the **value**
    level: that check counts a present-but-empty cookie as satisfying the
    binding, which import-cookies must not accept as a usable login.

    This is a deliberate copy, not an oversight. ``cli/`` may not import
    ``_private`` names out of public modules (``tests/_guardrails/
    test_cli_boundary.py``), and promoting an auth-policy predicate to the
    public surface is a bigger decision than this needs. The copy drifted once
    already — it kept the pre-``LSID`` rule when the canonical one gained its
    conjunct (#1977) — so ``test_cli_binding_rule_matches_cookie_policy`` pins
    the two together and fails if they diverge again.
    """
    nonempty = _nonempty_cookie_names(filtered_state)
    return "OSID" in nonempty or {"APISID", "SAPISID", "LSID"} <= nonempty


def _import_cookie_json(
    *,
    payload: Any,
    storage_path: Path,
    include_domains: set[str],
    include_optional: bool,
) -> tuple[dict[str, Any], Path | None]:
    """Validate, filter, and persist cookie JSON to ``storage_state.json``.

    Returns the persisted ``storage_state`` and the path of any ``.bak`` backup
    taken of a pre-existing target (``None`` when none was needed).
    """
    storage_state = _coerce_cookie_json_to_storage_state(payload)
    filtered_state = filter_storage_state_cookies_by_domain_policy(
        storage_state,
        include_optional=include_optional,
        include_domains=include_domains,
    )
    shaped_entries: list[dict[str, Any]] = []
    for raw_entry in filtered_state.get("cookies", []):
        try:
            shaped_entries.append(
                auth._validate_cookie_shape(raw_entry, require_nonempty_value=False)
            )
        except ValueError:
            continue

    raw_names = {entry["name"] for entry in shaped_entries}
    empty_required = sorted(
        name
        for name in auth.MINIMUM_REQUIRED_COOKIES
        if any(entry["name"] == name and not entry["value"] for entry in shaped_entries)
    )
    if empty_required:
        raise click.ClickException(  # cli-input-validation: import-cookies required-cookie value validation
            "Required cookies must have non-empty string values: " + ", ".join(empty_required)
        )

    # Normalize before any validation, diagnostics, backup, or write.  This
    # drops malformed rows without exposing raw expiry/converter errors and
    # gives the route preflight the exact storage converter used at runtime.
    filtered_state = {
        "cookies": [
            sanitized
            for raw_cookie in filtered_state.get("cookies", [])
            if (sanitized := auth._sanitize_cookie_entry(raw_cookie)) is not None
        ],
        "origins": [],
    }
    cookie_names = cookie_names_from_storage(filtered_state)
    try:
        # This validates required cookies and catches malformed cookie shapes
        # using the same loader later runtime calls use.
        extract_cookies_from_storage(filtered_state)
        auth._validate_routable_entries(
            auth._sanitized_auth_entries(filtered_state),
            to_cookie=auth._storage_entry_to_cookie,
            require_routable=True,
        )
    except ValueError as exc:
        hint = missing_cookies_hint(cookie_names)
        raise click.ClickException(  # cli-input-validation: import-cookies required-cookie validation
            f"{exc}\n\n{hint}"
        ) from None

    # Value-level binding check, run on the pre-normalization rows: normalization
    # drops empty-valued rows, so reading the persisted state here would report a
    # present-but-empty cookie as absent and skip the check entirely.
    # The name-level secondary-binding check counts a present-but-empty cookie as
    # satisfying the binding, so a set whose ``APISID``/``SAPISID`` (or ``OSID``)
    # are present-but-empty can pass required-cookie validation yet be unusable.
    # Reject that specific false-"ok". Like the login flow (which only warns), we
    # stay silent when no secondary-binding cookie is present at all.
    # ``LSID`` is in the set: without it an LSID-only import has an empty
    # ``secondary_present``, skips the check entirely, and persists a state the
    # canonical rule rejects. It also belongs in the ``Present:`` diagnostic.
    secondary_present = {"OSID", "APISID", "SAPISID", "LSID"} & raw_names
    if secondary_present and not _has_usable_secondary_binding({"cookies": shaped_entries}):
        raise click.ClickException(  # cli-input-validation: import-cookies secondary-binding validation
            "Secondary-binding cookies are present but do not form a usable "
            "binding — either their values are empty or the set is incomplete "
            "(need a non-empty OSID, or all of APISID, SAPISID and LSID). "
            "Present: " + ", ".join(sorted(secondary_present))
        )

    # Persist through the canonical storage writer (refactor (b), b-PR3): it takes
    # the pre-overwrite ``.bak`` backup INSIDE the storage lock (so it can't race a
    # concurrent keepalive write), re-applies the same idempotent write-time domain
    # filter, and writes 0700-dir / 0600-file atomically. The heavy import-side
    # validation above already guaranteed the required cookies survive the filter,
    # so ``required_cookies_dropped`` is defensive here.
    outcome = replace_from_login(
        storage_path,
        filtered_state,
        include_domains=include_domains,
        include_optional=include_optional,
        backup=True,
    )
    if outcome.required_cookies_dropped:
        hint = missing_cookies_hint(set(outcome.present_names))
        raise click.ClickException(  # cli-input-validation: import-cookies post-filter required-cookie validation
            "Required authentication cookies were dropped by the write-time "
            f"cookie-domain policy: {', '.join(outcome.missing_required)}.\n\n{hint}"
        )
    if outcome.lock_unavailable:
        raise click.ClickException(  # cli-input-validation: import-cookies storage lock unavailable
            f"Could not acquire the storage lock to write {storage_path} "
            "(another process may hold it). Try again."
        )
    return filtered_state, outcome.backup_path

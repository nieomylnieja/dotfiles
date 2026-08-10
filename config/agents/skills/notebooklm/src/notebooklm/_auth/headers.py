"""Header/route helpers for AuthTokens.

This module is intentionally small: most authuser/header helpers already live
in :mod:`notebooklm._auth.account` (``authuser_query``,
``format_authuser_value``, ``get_authuser_for_storage``,
``get_account_email_for_storage``). What lives here is the higher-level
*routing* glue that combines them — currently only
:func:`_resolve_token_route_kwargs`, used by the token-fetch entry points to
preserve explicit caller intent vs. resolved-from-storage defaults.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from .account import get_account_email_for_storage, get_authuser_for_storage
from .paths import resolve_auth_json_env


def _resolve_token_route_kwargs(
    storage_path: Path | None,
    *,
    authuser: int | None,
    account_email: str | None,
) -> dict[str, Any]:
    """Resolve token-fetch routing while preserving explicit caller intent."""
    explicit_authuser = authuser is not None
    env_auth_present = storage_path is None and resolve_auth_json_env() is not None
    env_authuser = 0
    env_account_email: str | None = None
    if env_auth_present and authuser is None:
        from .account import read_account_metadata_from_storage_state
        from .cookies import _load_storage_state

        try:
            metadata = read_account_metadata_from_storage_state(_load_storage_state(None))
        except (OSError, ValueError, TypeError):
            metadata = {}
        raw_authuser = metadata.get("authuser")
        raw_email = metadata.get("email")
        if type(raw_authuser) is int and raw_authuser >= 0:
            env_authuser = raw_authuser
        if isinstance(raw_email, str) and raw_email.strip():
            env_account_email = raw_email.strip()

    resolved_authuser = (
        authuser
        if authuser is not None
        else env_authuser
        if env_auth_present
        else get_authuser_for_storage(storage_path)
    )
    if account_email is not None:
        resolved_account_email = account_email
    elif explicit_authuser:
        resolved_account_email = None
    else:
        resolved_account_email = (
            env_account_email if env_auth_present else get_account_email_for_storage(storage_path)
        )

    route_kwargs: dict[str, Any] = {"authuser": resolved_authuser}
    if resolved_account_email is not None:
        route_kwargs["account_email"] = resolved_account_email
    if explicit_authuser:
        route_kwargs["force_authuser_query"] = True
    return route_kwargs

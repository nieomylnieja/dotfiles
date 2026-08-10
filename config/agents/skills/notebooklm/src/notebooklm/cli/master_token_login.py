"""Command-layer driver for ``notebooklm login --master-token[-refresh]``.

Thin Click-adjacent glue over :mod:`notebooklm.cli.services.login.master_token`:
resolves the profile's paths, runs the async bootstrap/refresh, and renders the
outcome. Kept out of ``session_cmd.py`` to hold that module under the size
ratchet (ADR-0008).
"""

from __future__ import annotations

import asyncio
from pathlib import Path

from ..auth import MasterTokenError, generate_android_id, read_master_token
from ..paths import get_master_token_path, get_storage_path
from .error_handler import exit_with_code
from .rendering import console
from .services.login import master_token as mt_service


def run_master_token_login(
    ctx,
    *,
    storage,
    browser,
    account_email,
    oauth_token,
    android_id,
    cdp_url,
    refresh,
    force=False,
):
    """Bootstrap or refresh headless master-token auth (see ``login --master-token``)."""
    profile = ctx.obj.get("profile") if ctx.obj else None
    storage_path = Path(storage) if storage else get_storage_path(profile=profile)
    master_token_path = get_master_token_path(profile)

    try:
        if refresh:
            asyncio.run(
                mt_service.refresh(storage_path=storage_path, master_token_path=master_token_path)
            )
            console.print(f"[green]Re-minted cookies[/green] -> {storage_path}")
            return
        if not account_email:
            console.print("[red]--master-token requires --account EMAIL[/red]")
            exit_with_code(1)
        # Guard before the (interactive) oauth_token capture so a wrong profile
        # fails fast instead of after a full sign-in.
        mt_service.assert_account_writable(
            email=account_email,
            storage_path=storage_path,
            master_token_path=master_token_path,
            force=force,
        )
        rec = read_master_token(master_token_path)
        aid = android_id or (rec["android_id"] if rec else generate_android_id())
        token = oauth_token or mt_service.capture_oauth_token(browser=browser, cdp_url=cdp_url)
        count = asyncio.run(
            mt_service.bootstrap(
                email=account_email,
                oauth_token=token,
                android_id=aid,
                storage_path=storage_path,
                master_token_path=master_token_path,
                force=force,
            )
        )
        console.print(
            f"[green]Master-token login OK[/green] — {count} notebooks. Saved to {storage_path}"
        )
    except MasterTokenError as exc:
        console.print(f"[red]{exc}[/red]")
        exit_with_code(1)

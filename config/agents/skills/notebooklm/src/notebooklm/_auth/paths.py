"""Filesystem paths, env-var name constants, and lock-path computation for auth storage.

This module is **private** (note the ``_auth`` package prefix) and distinct
from the package-level :mod:`notebooklm.paths`, which owns the user-facing
storage-path / profile-resolution helpers (``get_storage_path``,
``resolve_profile``). The two intentionally share a name because both are
"path stuff", but their concerns don't overlap and they import each other at
most transitively via :mod:`notebooklm.auth`.

This module owns the environment-variable name constants that gate refresh /
keepalive behaviour and the helper that computes the rotation sentinel path
sibling to ``storage_state.json``. Centralising them here keeps the public
``notebooklm.auth`` surface compatible while the underlying logic lives in a
single, easy-to-audit module.

Three categories of names live here:

1. **Refresh command env vars** (``NOTEBOOKLM_REFRESH_CMD``,
   ``NOTEBOOKLM_REFRESH_CMD_USE_SHELL``, ``_NOTEBOOKLM_REFRESH_ATTEMPTED``)
   read by :func:`notebooklm.auth._run_refresh_cmd` and friends.
2. **Keepalive env var** (``NOTEBOOKLM_DISABLE_KEEPALIVE_POKE``) read by
   :func:`notebooklm._auth.keepalive._poke_session` / ``_rotate_cookies``.
   It is conceptually an environment-variable name, not a keepalive parameter,
   so it lives here with the other auth env-var constants.
3. **Path helpers** (:func:`_storage_state_lock_path`,
   :func:`_rotation_lock_path`) that compute sentinel sibling files alongside
   the user's storage-state path.

The two refresh env vars and the keepalive env var are part of the documented
public surface of ``notebooklm.auth`` (see :data:`notebooklm.auth.__all__`);
``notebooklm.auth`` re-exports them by name. ``_REFRESH_ATTEMPTED_ENV`` and
``_rotation_lock_path`` are private but accessed as white-box affordances by
tests, so they are also re-exported.
"""

from __future__ import annotations

import os
from pathlib import Path

#: Inline Playwright ``storage_state`` JSON, an alternative to a profile file
#: (CI/CD, no disk writes). Read through :func:`resolve_auth_json_env` so every
#: auth-layer call site shares one presence/empty contract.
NOTEBOOKLM_AUTH_JSON_ENV = "NOTEBOOKLM_AUTH_JSON"

NOTEBOOKLM_REFRESH_CMD_ENV = "NOTEBOOKLM_REFRESH_CMD"
NOTEBOOKLM_REFRESH_CMD_USE_SHELL_ENV = "NOTEBOOKLM_REFRESH_CMD_USE_SHELL"
# Opt-in gate (default OFF for one release) promoting the refresh-cmd rung
# (L2.5) into the MID-SESSION recovery ladder, not just cold start
# (audit refresh-4). Flips to default-on a later release. See
# ``notebooklm._auth.refresh.try_refresh_cmd_reauth``.
NOTEBOOKLM_REFRESH_CMD_MIDSESSION_ENV = "NOTEBOOKLM_REFRESH_CMD_MIDSESSION"
# Opt-in gate (default OFF) that additionally routes the refresh command's
# captured stdout/stderr to the redacting DEBUG logger. OFF by default because
# the promotion of the rung into long-lived servers widens the exposure of
# whatever the command prints (audit refresh-8); the default DEBUG line carries
# only basename + exit code + byte counts.
NOTEBOOKLM_REFRESH_CMD_LOG_OUTPUT_ENV = "NOTEBOOKLM_REFRESH_CMD_LOG_OUTPUT"
_REFRESH_ATTEMPTED_ENV = "_NOTEBOOKLM_REFRESH_ATTEMPTED"

NOTEBOOKLM_DISABLE_KEEPALIVE_POKE_ENV = "NOTEBOOKLM_DISABLE_KEEPALIVE_POKE"


def resolve_auth_json_env() -> str | None:
    """Return the raw ``NOTEBOOKLM_AUTH_JSON`` value, or ``None`` if it is unset.

    The **single** read of this env var for the auth layer. Before this helper,
    seven call sites spelled the check by hand and disagreed on
    presence-vs-truthiness (the classic drift that produced #2057 / #2083): a
    *set-but-empty* value silently fell through to a profile file at some sites
    and raised at others. Centralising the read here makes the contract one
    thing everywhere:

    * unset ⇒ ``None`` (fall through to profile-file auth);
    * set ⇒ the value is returned verbatim, so ``resolve_auth_json_env() is not
      None`` means "inline env auth is selected" — a set-but-empty value counts
      as *selected*, never a silent fall-through to a file.

    The set-but-empty **configuration error** ("set but empty") is raised by the
    one consumer that actually parses the payload,
    :func:`notebooklm._auth.cookies._load_storage_state`, rather than here, so
    the presence-only callers (path resolvers, PSIDTS recovery, header routing,
    the cookie-save skip) stay behaviour-identical and cannot regress to the
    fall-through bug. See ADR-0030.
    """
    return os.environ.get(NOTEBOOKLM_AUTH_JSON_ENV)


def _storage_state_lock_path(storage_path: Path) -> Path:
    """Canonical sibling flock file shared by every ``storage_state.json`` writer.

    ``save_cookies_to_storage`` (cookie writes) and ``write_account_metadata`` /
    ``_clear_in_band_account`` (account-metadata writes) all mutate the same
    ``storage_state.json``, so they MUST serialize on the *same* lock file or a
    read-modify-write from one loses the other's update. Deriving the dotted
    ``.storage_state.json.lock`` path here keeps that contract enforced by
    construction instead of by hand-synced string literals in each caller.
    """
    return storage_path.with_name(f".{storage_path.name}.lock")


def _rotation_lock_path(storage_path: Path | None) -> Path | None:
    """Sibling sentinel used by ``_poke_session`` for cross-process coordination.

    Distinct from the ``.storage_state.json.lock`` used by ``save_cookies_to_storage``
    so a long-running save doesn't block rotations or vice versa.
    """
    if storage_path is None:
        return None
    return storage_path.with_name(f".{storage_path.name}.rotate.lock")


def _refresh_lock_path(storage_path: Path | None) -> Path | None:
    """Sibling sentinel used to serialize ``NOTEBOOKLM_REFRESH_CMD`` across processes.

    Distinct from both the storage-write lock (``.storage_state.json.lock``) and
    the rotation sentinel (``.storage_state.json.rotate.lock``): a long-running
    cookie save or a keepalive rotation must not block — or be blocked by — a
    refresh-cmd subprocess. In-process coalescing already guarantees a single
    subprocess per process (see :mod:`notebooklm._auth.single_flight`); this
    flock adds the *cross-process* exclusion that closes the refresh-cmd
    stampede ([refresh-2]). Callers pass the already-canonicalized path from
    :func:`canonical_storage_key` so relative / symlinked representations of the
    same file derive the same sentinel.
    """
    if storage_path is None:
        return None
    return storage_path.with_name(f".{storage_path.name}.refresh.lock")


def canonical_storage_key(storage_path: Path | None) -> Path | None:
    """Return the canonical form of ``storage_path`` for in-process keying.

    One helper, three consumers ([refresh-5]): the keepalive poke throttle map
    (``_LAST_POKE_ATTEMPT_MONOTONIC``), the per-loop poke lock registry
    (``_get_poke_lock``), and the refresh-cmd flock derivation
    (:func:`_refresh_lock_path`). Two syntactic representations of the SAME
    underlying file (relative vs absolute, ``~``-prefixed, or through a symlink)
    must collapse to one key or the dedupe/coalescing is silently bypassed and
    duplicate ``RotateCookies`` POSTs / refresh subprocesses fire.

    ``None`` (env-var auth, no on-disk file) is returned unchanged: there is no
    file to canonicalize and ``None`` is a legitimate throttle-map key.
    """
    if storage_path is None:
        return None
    return storage_path.expanduser().resolve()

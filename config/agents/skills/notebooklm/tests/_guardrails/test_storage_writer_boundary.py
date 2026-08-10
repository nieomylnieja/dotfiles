"""Meta-lint: ``storage_state.json`` writes funnel through the canonical writer.

Part of refactor (b) — the canonical storage writer. The single sanctioned home
for mutating ``storage_state.json`` is
``src/notebooklm/_auth/storage_writer.py``. This AST guardrail enforces the
boundary by construction (import/name-based, following ``_ast_reach_in.py`` and
the other ``tests/_guardrails/`` lints) so a new writer is loud in CI rather than
silently re-opening the lost-update / policy-bypass classes the refactor closes.

Five decidable clauses (plan §b.2 enforcement, layer 1 — AST guardrail):

(i)  Outside ``storage_writer.py`` (and ``migration.py``), no ``_auth/`` module
     may import an ``_atomic_io`` **write primitive** (``atomic_write_json`` /
     ``replace_file_atomically``) except the modules on the frozen
     ``_AUTH_WRITE_PRIMITIVE_IMPORTERS`` allowlist. Each allowlisted module is
     annotated with WHY it is (still) allowed; the storage-state-writing ones
     shrink to just the canonical writer as later PRs migrate them (b-PR3
     acceptance: the storage-state exemption shrinks to ``{migration.py}``).

(ii) Dependency-seam bindings of a write primitive (the CLI
     ``RefreshDeps.atomic_write_json=...`` keyword-binding shape) are flagged and
     must appear on the frozen ``_WRITE_PRIMITIVE_SEAM_BINDINGS`` allowlist.

(iii) A write-primitive **call** (``open`` / ``os.open`` in write mode /
     ``Path.write_text`` / ``Path.write_bytes`` / ``os.replace``) whose target is
     a ``storage_state.json``-named **string literal** is forbidden anywhere
     outside ``storage_writer.py`` / ``migration.py``.

(iv) An **equality-asserted** frozenset of EVERY module repo-wide that imports
     ``atomic_write_json`` (clause (iii) cannot see the CLI writers, which call it
     with variable paths — so this allowlist keeps them visible). A new importer
     — anywhere — turns this assertion red until it is triaged onto the list.

(v)  A module-level import of the ``_atomic_io`` **module itself** (as opposed to
     the write-primitive NAMES clauses (i)/(iv) match) — ``import
     notebooklm._atomic_io`` / ``from .. import _atomic_io`` / ``from notebooklm
     import _atomic_io``, under any alias — followed by an attribute-access CALL
     to a write primitive or the ``_atomic_write_json_unchecked`` bypass on that
     alias (``_atomic_io._atomic_write_json_unchecked(path, data)``). This shape
     imports no primitive NAME, so it is invisible to every other clause AND it
     can reach the module-private bypass that skips the runtime
     ``storage_state.json`` rejection — a real hole. An equality-asserted
     allowlist of module-importers (:data:`_ATOMIC_IO_MODULE_IMPORTERS`) freezes
     who may import the module at all.

The allowlists are module-level frozensets asserted by **equality** (not
subset), and every entry is existence-checked, so a stale entry (a module that no
longer imports the primitive) is also caught.
"""

from __future__ import annotations

import ast
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SRC_ROOT = REPO_ROOT / "src" / "notebooklm"

# The two ``_atomic_io`` symbols that perform (or wrap) the final write of a JSON
# state file. ``atomic_update_json`` is deliberately NOT in this set: it is the
# sanctioned locked read-modify-write helper for ``context.json`` / ``config.json``
# and already rejects ``storage_state.json`` paths at runtime (#1215).
_WRITE_PRIMITIVES = frozenset({"atomic_write_json", "replace_file_atomically"})

# Bare-name write primitives that, when *called* against a storage-state literal,
# are a storage-state write. ``os.open`` / ``os.replace`` are matched as
# attribute calls separately.
_BUILTIN_WRITE_CALLS = frozenset({"open"})
_OS_WRITE_CALLS = frozenset({"open", "replace"})
_PATH_WRITE_METHODS = frozenset({"write_text", "write_bytes"})

_STORAGE_STATE_LITERAL = "storage_state.json"


# --- Clause (iv): every module repo-wide that imports ``atomic_write_json`` ----
#
# Equality-asserted. Each entry is a source path relative to ``SRC_ROOT``.
# Categorised only for reviewer clarity — the guardrail asserts the whole set.
_ATOMIC_WRITE_JSON_IMPORTERS: frozenset[str] = frozenset(
    {
        # Legitimate NON-storage-state writers (permanent).
        "io.py",  # public re-export of the _atomic_io helpers
        "_auth/account.py",  # writes the legacy sibling context.json (not storage_state)
        "cli/context.py",  # CLI context.json / config.json
        "mcp/_oauth.py",  # writes the MCP OAuth token file
        # NOTE: the canonical writer ``_auth/storage_writer.py`` no longer imports
        # the PUBLIC ``atomic_write_json`` — since b-PR3 the public helper rejects
        # ``storage_state.json`` paths at runtime, and the writer uses the
        # module-private bypass ``_atomic_write_json_unchecked`` instead (tracked
        # by _ATOMIC_WRITE_JSON_BYPASS_IMPORTERS below).
        # The three CLI login/import writers migrated in b-PR3 (they now route
        # through storage_writer.replace_from_login via the auth facade) and
        # ``_auth/browser_capture.py`` migrated in b-PR2 — all dropped off here.
    }
)

# --- Clause (iv, bypass): the module-private storage-state write bypass ---------
#
# ``_atomic_io._atomic_write_json_unchecked`` is the module-private symbol the
# public ``atomic_write_json`` delegates to AFTER its ``storage_state.json``
# rejection (b-PR3). It skips that guard, so it is the ONLY way to atomically
# write a ``storage_state.json`` file — and the canonical writer is its ONLY
# sanctioned importer. Equality-asserted so any new importer of the bypass is
# loud in CI (it would be a boundary breach as severe as a bare storage-state
# write).
_ATOMIC_WRITE_JSON_BYPASS = "_atomic_write_json_unchecked"
_ATOMIC_WRITE_JSON_BYPASS_IMPORTERS: frozenset[str] = frozenset(
    {
        "_auth/storage_writer.py",  # canonical storage-state writer (refactor (b))
    }
)

# --- Clause (iv, parallel): repo-wide importers of ``replace_file_atomically`` --
#
# ``replace_file_atomically`` is the OTHER ``_atomic_io`` write primitive, and (like
# ``atomic_write_json``) can be called with a VARIABLE path that clause (iii)
# cannot see. Track it with its own equality-asserted allowlist so a future
# ``cli/``/``mcp/`` module writing storage_state via ``replace_file_atomically``
# can't escape every clause. Both current importers are legitimate non-storage
# users.
_REPLACE_FILE_ATOMICALLY_IMPORTERS: frozenset[str] = frozenset(
    {
        "io.py",  # public re-export of the _atomic_io helpers
        "cli/skill_cmd.py",  # writes skill definition files (not storage_state)
        "migration.py",  # crash-safe legacy-layout migration (#2085); the sole
        # guardrail-exempt storage_state writer (moves files via temp+rename).
    }
)

# --- Clause (i): ``_auth/`` modules allowed to import a write primitive ---------
#
# Outside these, an ``_auth/`` module importing a write primitive is a violation.
# ``storage_writer.py`` is the canonical home; the rest are annotated exemptions.
_AUTH_WRITE_PRIMITIVE_IMPORTERS: frozenset[str] = frozenset(
    {
        # canonical writer — imports the module-private bypass
        # ``_atomic_write_json_unchecked`` (counted as a write primitive here);
        # the public ``atomic_write_json`` now rejects storage_state.json paths.
        "_auth/storage_writer.py",
        "_auth/account.py",  # context.json cleanup only (not storage_state)
        # ``_auth/browser_capture.py`` migrated in b-PR2 — it no longer imports a
        # write primitive (re-mint now routes through storage_writer).
    }
)

# --- Clause (i, sub): storage-state write exemptions OUTSIDE storage_writer -----
#
# Modules that still perform a ``storage_state.json`` write via a primitive,
# beyond the canonical writer. ``migration.py`` is the permanent sole exemption
# (it moves whole files with ``shutil`` + ``atomic_update_json`` for config.json,
# #2085). The b-PR3 acceptance criterion shrinks this set to ``{migration.py}``.
_STORAGE_STATE_WRITE_EXEMPTIONS: frozenset[str] = frozenset(
    {
        "migration.py",  # permanent: legacy-profile file migration (#2085)
        # b-PR3 acceptance criterion: this set is now exactly {migration.py}.
        # ``_auth/browser_capture.py`` migrated in b-PR2; the three CLI
        # login/import writers migrated in b-PR3 (all route through the canonical
        # storage_writer, and the runtime rejection now backstops the boundary).
    }
)

# --- Clause (ii): sanctioned dependency-seam bindings of a write primitive ------
#
# No module binds a write primitive through a dependency seam any more: the CLI
# login ``RefreshDeps.atomic_write_json`` seam was removed in b-PR3 (the drivers
# now inject ``replace_from_login``, which is not a write primitive). Kept as an
# equality-asserted (empty) frozenset so a future re-introduction of a
# write-primitive seam binding is loud in CI.
_WRITE_PRIMITIVE_SEAM_BINDINGS: frozenset[str] = frozenset()

# --- Clause (v): modules that import the ``_atomic_io`` MODULE (not its NAMES) --
#
# Equality-asserted allowlist of every module repo-wide that imports the
# ``_atomic_io`` module *object* (``import notebooklm._atomic_io`` /
# ``from .. import _atomic_io`` / ``from notebooklm import _atomic_io``), as
# distinct from ``from .._atomic_io import <primitive>`` (a NAME import — clauses
# (i)/(iv)). VERIFIED by grep (2026-08): the set is currently **empty** — every
# legitimate user (io.py, storage_writer.py, account.py, migration.py,
# mcp/_oauth.py) imports the primitive NAMES, never the module object. Frozen
# empty so the FIRST module to pull in the ``_atomic_io`` module (which could then
# reach ``_atomic_write_json_unchecked`` via attribute access, skipping the public
# ``atomic_write_json``'s storage_state.json rejection) turns this red. A legit
# future module-importer must be triaged onto this list AND, if it makes a
# write-primitive attribute call, onto the clause-(v) call allowlist below.
_ATOMIC_IO_MODULE_IMPORTERS: frozenset[str] = frozenset()

# Modules allowed to CALL a write primitive via an ``_atomic_io`` module alias
# (the clause-(v) attribute-call shape). Mirrors clause (iii)'s literal-call
# allowlist: only the canonical writer / migration may write storage_state, and
# neither currently uses the module-import shape — so this is empty. Frozen so a
# new attribute-call bypass anywhere is loud.
_ATOMIC_IO_MODULE_WRITE_CALL_ALLOWLIST: frozenset[str] = frozenset()


def _iter_src_files() -> list[Path]:
    return sorted(p for p in SRC_ROOT.rglob("*.py") if "__pycache__" not in p.parts)


def _rel(path: Path) -> str:
    return path.relative_to(SRC_ROOT).as_posix()


# Exact module names that resolve to the ``_atomic_io`` write primitives, across
# relative (``from .._atomic_io``/``from ....io`` — the dots live in ``node.level``,
# stripped from ``node.module``) and absolute spellings. Exact matching (not
# ``endswith("io")``) so an unrelated module like ``studio`` cannot over-match.
_ATOMIC_IO_MODULE_NAMES = frozenset({"_atomic_io", "io", "notebooklm._atomic_io", "notebooklm.io"})


def _is_atomic_io_module(module: str) -> bool:
    return module in _ATOMIC_IO_MODULE_NAMES


def _imports_write_primitive(tree: ast.AST) -> set[str]:
    """Names of ``_atomic_io`` write primitives imported by this module.

    Counts the two public primitives (:data:`_WRITE_PRIMITIVES`) AND the
    module-private storage-state bypass (:data:`_ATOMIC_WRITE_JSON_BYPASS`) — the
    canonical writer imports the latter, and clause (i) must still recognise it as
    a write-primitive importer even though it no longer imports the public name.
    """
    found: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and _is_atomic_io_module(node.module or ""):
            for alias in node.names:
                if alias.name in _WRITE_PRIMITIVES or alias.name == _ATOMIC_WRITE_JSON_BYPASS:
                    found.add(alias.name)
    return found


def _imports_named_primitive(tree: ast.AST, name: str) -> bool:
    """Does this module ``from … import <name>`` an ``_atomic_io`` write primitive?"""
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and _is_atomic_io_module(node.module or ""):
            if any(alias.name == name for alias in node.names):
                return True
    return False


# --- Clause (v): module-import + attribute-call bypass detection ---------------
#
# ``_atomic_io`` module-object aliases arrive three ways:
#   * ``import notebooklm._atomic_io``            -> reachable as ``notebooklm._atomic_io``
#   * ``import notebooklm._atomic_io as aio``     -> direct alias ``aio``
#   * ``from .. import _atomic_io [as x]`` /
#     ``from notebooklm import _atomic_io [as x]``-> direct alias ``_atomic_io``/``x``
# ``from .._atomic_io import <name>`` is a NAME import (node.module == "_atomic_io"),
# NOT a module import — clauses (i)/(iv) own it, so it is deliberately excluded.
_ATOMIC_IO_MODULE_CONTAINERS = frozenset({"", "notebooklm"})


def _atomic_io_module_aliases(tree: ast.AST) -> tuple[set[str], bool]:
    """Local aliases binding the ``_atomic_io`` **module object**.

    Returns ``(direct_aliases, has_pkg_qualified)``:

    * ``direct_aliases`` — names that ARE the module (``... as X`` /
      ``from <container> import _atomic_io [as X]``), called as ``X.<primitive>``.
    * ``has_pkg_qualified`` — a plain ``import notebooklm._atomic_io`` (no
      ``as``) is present, so the module is reached as the attribute chain
      ``notebooklm._atomic_io.<primitive>``.
    """
    direct: set[str] = set()
    pkg_qualified = False
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name == "notebooklm._atomic_io":
                    if alias.asname:
                        direct.add(alias.asname)
                    else:
                        pkg_qualified = True
        elif isinstance(node, ast.ImportFrom):
            # ``from notebooklm import _atomic_io`` (module="notebooklm") or a
            # relative ``from . import _atomic_io`` / ``from .. import _atomic_io``
            # (module is None -> ""). The imported NAME is the module itself.
            if (node.module or "") in _ATOMIC_IO_MODULE_CONTAINERS:
                for alias in node.names:
                    if alias.name == "_atomic_io":
                        direct.add(alias.asname or "_atomic_io")
    return direct, pkg_qualified


def _imports_atomic_io_module(tree: ast.AST) -> bool:
    """Does this module import the ``_atomic_io`` module object (any alias)?"""
    direct, pkg_qualified = _atomic_io_module_aliases(tree)
    return bool(direct) or pkg_qualified


def _atomic_io_module_write_calls(tree: ast.AST) -> list[int]:
    """Line numbers of write-primitive / bypass CALLS via an ``_atomic_io`` module
    alias (``aio.atomic_write_json(...)`` / ``notebooklm._atomic_io.
    _atomic_write_json_unchecked(...)``)."""
    direct, pkg_qualified = _atomic_io_module_aliases(tree)
    if not direct and not pkg_qualified:
        return []
    targets = _WRITE_PRIMITIVES | {_ATOMIC_WRITE_JSON_BYPASS}
    hits: list[int] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        func = node.func
        if not isinstance(func, ast.Attribute) or func.attr not in targets:
            continue
        base = func.value
        # Direct alias: ``aio.atomic_write_json(...)`` / ``_atomic_io.foo(...)``.
        if isinstance(base, ast.Name) and base.id in direct:
            hits.append(node.lineno)
            continue
        # Package-qualified: ``notebooklm._atomic_io.foo(...)``.
        if (
            pkg_qualified
            and isinstance(base, ast.Attribute)
            and base.attr == "_atomic_io"
            and isinstance(base.value, ast.Name)
            and base.value.id == "notebooklm"
        ):
            hits.append(node.lineno)
    return hits


def _has_write_primitive_seam_binding(tree: ast.AST) -> bool:
    """Detect a ``foo(atomic_write_json=<name>)`` / ``x.atomic_write_json = <name>``
    dependency-seam binding of a write primitive."""
    for node in ast.walk(tree):
        # Keyword binding: ``RefreshDeps(atomic_write_json=atomic_write_json)``.
        if isinstance(node, ast.Call):
            for kw in node.keywords:
                if kw.arg in _WRITE_PRIMITIVES:
                    return True
        # Attribute assignment: ``deps.atomic_write_json = atomic_write_json``.
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Attribute) and target.attr in _WRITE_PRIMITIVES:
                    return True
    return False


def _is_storage_state_literal(node: ast.expr) -> bool:
    return (
        isinstance(node, ast.Constant)
        and isinstance(node.value, str)
        and _STORAGE_STATE_LITERAL in node.value
    )


def _write_primitive_calls_on_storage_literal(tree: ast.AST) -> list[int]:
    """Line numbers of write-primitive calls whose first arg is a storage-state
    string literal (``open("…/storage_state.json", "w")``, ``os.replace``,
    ``Path("storage_state.json").write_text(...)``)."""
    hits: list[int] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        func = node.func
        target: ast.expr | None = node.args[0] if node.args else None

        # Bare builtin ``open(<literal>, "w"...)``.
        if isinstance(func, ast.Name) and func.id in _BUILTIN_WRITE_CALLS:
            mode = node.args[1] if len(node.args) >= 2 else None
            writes = mode is None or (
                isinstance(mode, ast.Constant)
                and isinstance(mode.value, str)
                and any(c in mode.value for c in ("w", "a", "x", "+"))
            )
            if writes and target is not None and _is_storage_state_literal(target):
                hits.append(node.lineno)
            continue

        # Attribute calls: ``os.open`` / ``os.replace`` / ``<path>.write_text``.
        if isinstance(func, ast.Attribute):
            if (
                isinstance(func.value, ast.Name)
                and func.value.id == "os"
                and func.attr in _OS_WRITE_CALLS
            ):
                # ``os.open(path, flags)`` writes to args[0]; ``os.replace(src, dst)``
                # writes to args[1] (the DESTINATION). Check the right position for
                # each so a storage-state destination literal is actually matched.
                os_target = (
                    node.args[1] if func.attr == "replace" and len(node.args) >= 2 else target
                )
                if os_target is not None and _is_storage_state_literal(os_target):
                    hits.append(node.lineno)
                continue
            if func.attr in _PATH_WRITE_METHODS:
                # ``Path("…/storage_state.json").write_text(...)``.
                recv = func.value
                if (
                    isinstance(recv, ast.Call)
                    and recv.args
                    and _is_storage_state_literal(recv.args[0])
                ):
                    hits.append(node.lineno)
    return hits


def test_atomic_write_json_importers_frozen_allowlist() -> None:
    """Clause (iv): the repo-wide set of ``atomic_write_json`` importers is frozen.

    Equality (not subset): a NEW importer OR a stale entry both turn this red.
    Variable-path CLI writers (which clause (iii) cannot see) stay visible here.
    """
    actual = {
        _rel(p)
        for p in _iter_src_files()
        if _imports_named_primitive(ast.parse(p.read_text("utf-8")), "atomic_write_json")
    }
    assert actual == set(_ATOMIC_WRITE_JSON_IMPORTERS), (
        "atomic_write_json importer set drifted from the frozen allowlist. "
        f"Unexpected new importers: {sorted(actual - _ATOMIC_WRITE_JSON_IMPORTERS)}; "
        f"stale allowlist entries: {sorted(_ATOMIC_WRITE_JSON_IMPORTERS - actual)}. "
        "Any new storage_state.json writer must go through storage_writer.py; a new "
        "non-storage writer must be triaged onto _ATOMIC_WRITE_JSON_IMPORTERS."
    )


def test_atomic_write_json_bypass_importers_frozen_allowlist() -> None:
    """Clause (iv, bypass): only the canonical writer imports the storage-state
    write bypass ``_atomic_write_json_unchecked``.

    Equality-asserted. The bypass skips the public ``atomic_write_json``'s
    ``storage_state.json`` rejection (b-PR3), so any importer beyond
    ``storage_writer.py`` would be able to write storage_state.json unlocked —
    exactly the class the boundary exists to prevent.
    """
    actual = {
        _rel(p)
        for p in _iter_src_files()
        if _imports_named_primitive(ast.parse(p.read_text("utf-8")), _ATOMIC_WRITE_JSON_BYPASS)
    }
    assert actual == set(_ATOMIC_WRITE_JSON_BYPASS_IMPORTERS), (
        "storage-state write-bypass importer set drifted from the frozen allowlist. "
        f"Unexpected new importers: {sorted(actual - _ATOMIC_WRITE_JSON_BYPASS_IMPORTERS)}; "
        f"stale allowlist entries: {sorted(_ATOMIC_WRITE_JSON_BYPASS_IMPORTERS - actual)}. "
        "Only storage_writer.py may import _atomic_write_json_unchecked."
    )


def test_replace_file_atomically_importers_frozen_allowlist() -> None:
    """Clause (iv, parallel): the repo-wide set of ``replace_file_atomically``
    importers is frozen (equality-asserted), so a future ``cli``/``mcp`` module
    writing storage_state via this variable-path primitive is loud."""
    actual = {
        _rel(p)
        for p in _iter_src_files()
        if _imports_named_primitive(ast.parse(p.read_text("utf-8")), "replace_file_atomically")
    }
    assert actual == set(_REPLACE_FILE_ATOMICALLY_IMPORTERS), (
        "replace_file_atomically importer set drifted from the frozen allowlist. "
        f"Unexpected new importers: {sorted(actual - _REPLACE_FILE_ATOMICALLY_IMPORTERS)}; "
        f"stale allowlist entries: {sorted(_REPLACE_FILE_ATOMICALLY_IMPORTERS - actual)}. "
        "A new storage_state.json writer must go through storage_writer.py."
    )


def test_atomic_write_json_allowlist_entries_exist() -> None:
    """Every allowlist entry must name a real source file (no stale paths)."""
    for rel in _ATOMIC_WRITE_JSON_IMPORTERS:
        assert (SRC_ROOT / rel).is_file(), f"allowlisted importer no longer exists: {rel}"
    for rel in _ATOMIC_WRITE_JSON_BYPASS_IMPORTERS:
        assert (SRC_ROOT / rel).is_file(), f"bypass importer no longer exists: {rel}"
    for rel in _REPLACE_FILE_ATOMICALLY_IMPORTERS:
        assert (SRC_ROOT / rel).is_file(), f"rfa allowlisted importer no longer exists: {rel}"
    for rel in _AUTH_WRITE_PRIMITIVE_IMPORTERS:
        assert (SRC_ROOT / rel).is_file(), f"allowlisted _auth importer no longer exists: {rel}"
    for rel in _STORAGE_STATE_WRITE_EXEMPTIONS:
        assert (SRC_ROOT / rel).is_file(), f"storage-state exemption no longer exists: {rel}"
    for rel in _WRITE_PRIMITIVE_SEAM_BINDINGS:
        assert (SRC_ROOT / rel).is_file(), f"seam-binding entry no longer exists: {rel}"
    for rel in _ATOMIC_IO_MODULE_IMPORTERS:
        assert (SRC_ROOT / rel).is_file(), f"_atomic_io module importer no longer exists: {rel}"
    for rel in _ATOMIC_IO_MODULE_WRITE_CALL_ALLOWLIST:
        assert (SRC_ROOT / rel).is_file(), f"_atomic_io module write-call entry gone: {rel}"


def test_auth_write_primitive_importers_frozen() -> None:
    """Clause (i): only allowlisted ``_auth/`` modules import a write primitive.

    Equality-asserted, so both a new ``_auth/`` importer and a stale entry fail.
    """
    actual = {
        _rel(p)
        for p in _iter_src_files()
        if "_auth" in p.relative_to(SRC_ROOT).parts
        if _imports_write_primitive(ast.parse(p.read_text("utf-8")))
    }
    assert actual == set(_AUTH_WRITE_PRIMITIVE_IMPORTERS), (
        "_auth write-primitive importer set drifted from the frozen allowlist. "
        f"Unexpected: {sorted(actual - _AUTH_WRITE_PRIMITIVE_IMPORTERS)}; "
        f"stale: {sorted(_AUTH_WRITE_PRIMITIVE_IMPORTERS - actual)}. "
        "storage_state.json writes belong in storage_writer.py."
    )


def test_write_primitive_seam_bindings_frozen() -> None:
    """Clause (ii): dependency-seam bindings of a write primitive are allowlisted."""
    actual = {
        _rel(p)
        for p in _iter_src_files()
        if _has_write_primitive_seam_binding(ast.parse(p.read_text("utf-8")))
    }
    assert actual == set(_WRITE_PRIMITIVE_SEAM_BINDINGS), (
        "write-primitive dependency-seam bindings drifted from the frozen allowlist. "
        f"Unexpected: {sorted(actual - _WRITE_PRIMITIVE_SEAM_BINDINGS)}; "
        f"stale: {sorted(_WRITE_PRIMITIVE_SEAM_BINDINGS - actual)}."
    )


def test_atomic_io_module_importers_frozen() -> None:
    """Clause (v): the repo-wide set of modules importing the ``_atomic_io``
    module OBJECT (not its NAMES) is frozen (equality-asserted).

    Currently empty: every legitimate user imports the primitive NAMES via
    ``from .._atomic_io import ...``. A new module-object importer — the shape
    that can reach ``_atomic_write_json_unchecked`` past the public wrapper's
    storage_state.json rejection — turns this red until triaged.
    """
    actual = {
        _rel(p)
        for p in _iter_src_files()
        if _imports_atomic_io_module(ast.parse(p.read_text("utf-8")))
    }
    assert actual == set(_ATOMIC_IO_MODULE_IMPORTERS), (
        "_atomic_io MODULE-object importer set drifted from the frozen allowlist. "
        f"Unexpected new importers: {sorted(actual - _ATOMIC_IO_MODULE_IMPORTERS)}; "
        f"stale allowlist entries: {sorted(_ATOMIC_IO_MODULE_IMPORTERS - actual)}. "
        "Import the primitive NAMES via `from .._atomic_io import ...` (tracked by "
        "clauses (i)/(iv)); a module-object import + attribute-call can reach the "
        "storage-state bypass and must be triaged onto _ATOMIC_IO_MODULE_IMPORTERS."
    )


def test_no_atomic_io_module_write_primitive_attribute_calls() -> None:
    """Clause (v): no write-primitive / bypass CALL via an ``_atomic_io`` module
    alias outside the allowlist.

    This closes the module-import + attribute-call hole (``import
    notebooklm._atomic_io`` then ``_atomic_io._atomic_write_json_unchecked(...)``)
    that every NAME-based clause is blind to.
    """
    violations: dict[str, list[int]] = {}
    for path in _iter_src_files():
        rel = _rel(path)
        if rel in _ATOMIC_IO_MODULE_WRITE_CALL_ALLOWLIST:
            continue
        hits = _atomic_io_module_write_calls(ast.parse(path.read_text("utf-8")))
        if hits:
            violations[rel] = hits
    assert violations == {}, (
        "write-primitive attribute call(s) via an _atomic_io module alias outside "
        f"the clause-(v) allowlist: {violations}. Route storage_state writes through "
        "notebooklm._auth.storage_writer instead."
    )


@pytest.mark.parametrize(
    ("snippet", "should_flag"),
    [
        # The exact module-import + attribute-call bypass shapes clause (v) closes.
        (
            "import notebooklm._atomic_io\n"
            "notebooklm._atomic_io._atomic_write_json_unchecked(path, data)",
            True,
        ),
        ("import notebooklm._atomic_io as aio\naio.atomic_write_json(path, data)", True),
        ("from .. import _atomic_io\n_atomic_io.atomic_write_json(path, data)", True),
        ("from . import _atomic_io\n_atomic_io._atomic_write_json_unchecked(path, data)", True),
        ("from notebooklm import _atomic_io\n_atomic_io.replace_file_atomically(tmp, path)", True),
        ("from notebooklm import _atomic_io as m\nm.replace_file_atomically(tmp, path)", True),
        # NAME import (module == "_atomic_io") — clauses (i)/(iv) own it, NOT (v).
        ("from .._atomic_io import atomic_write_json\natomic_write_json(path, data)", False),
        (
            "from .._atomic_io import _atomic_write_json_unchecked\n_atomic_write_json_unchecked(p, d)",
            False,
        ),
        # Module alias, but a non-write attribute (atomic_update_json is allowed).
        ("import notebooklm._atomic_io as aio\naio.atomic_update_json(path, m)", False),
        # Unrelated module.
        ("import os\nos.replace(a, b)", False),
    ],
)
def test_atomic_io_module_bypass_detector_self_check(snippet: str, should_flag: bool) -> None:
    """Self-test of the clause (v) detector: the module-import + attribute-call
    bypass (incl. the ``_atomic_write_json_unchecked`` shape) is flagged, while a
    NAME import or a non-write attribute call is not."""
    hits = _atomic_io_module_write_calls(ast.parse(snippet))
    assert bool(hits) is should_flag, f"{snippet!r} -> hits={hits}, expected flag={should_flag}"


def test_atomic_io_module_import_is_detected() -> None:
    """The module-object import detector recognises every spelling (and rejects the
    NAME-import spelling that clauses (i)/(iv) own)."""
    assert _imports_atomic_io_module(ast.parse("import notebooklm._atomic_io"))
    assert _imports_atomic_io_module(ast.parse("import notebooklm._atomic_io as aio"))
    assert _imports_atomic_io_module(ast.parse("from .. import _atomic_io"))
    assert _imports_atomic_io_module(ast.parse("from . import _atomic_io as x"))
    assert _imports_atomic_io_module(ast.parse("from notebooklm import _atomic_io"))
    # NAME import — module part is "_atomic_io", not a container: NOT a module import.
    assert not _imports_atomic_io_module(
        ast.parse("from .._atomic_io import _atomic_write_json_unchecked")
    )
    assert not _imports_atomic_io_module(ast.parse("import os"))


@pytest.mark.parametrize(
    ("snippet", "should_flag"),
    [
        ('open("/x/storage_state.json", "w")', True),
        ('open("/x/storage_state.json")', True),  # default mode is read+write ambiguous → flag
        ('open("/x/storage_state.json", "r")', False),
        ('os.open("/x/storage_state.json", os.O_WRONLY)', True),
        # os.replace's DESTINATION is args[1] — the fix (NIT #5) must catch this.
        ('os.replace(tmp, "/x/storage_state.json")', True),
        ('os.replace("/x/storage_state.json", other)', False),  # source, not destination
        ('Path("/x/storage_state.json").write_text(data)', True),
        ('open("/x/context.json", "w")', False),
    ],
)
def test_write_primitive_literal_detector_self_check(snippet: str, should_flag: bool) -> None:
    """Self-test of the clause (iii) detector — in particular that ``os.replace``
    is matched on its destination (args[1]), per NIT #5."""
    hits = _write_primitive_calls_on_storage_literal(ast.parse(snippet))
    assert bool(hits) is should_flag, f"{snippet!r} -> hits={hits}, expected flag={should_flag}"


def test_no_storage_state_literal_write_primitive_calls() -> None:
    """Clause (iii): no write-primitive call on a ``storage_state.json`` literal
    outside the canonical writer / migration."""
    allowed = {"_auth/storage_writer.py", "migration.py"}
    violations: dict[str, list[int]] = {}
    for path in _iter_src_files():
        rel = _rel(path)
        if rel in allowed:
            continue
        hits = _write_primitive_calls_on_storage_literal(ast.parse(path.read_text("utf-8")))
        if hits:
            violations[rel] = hits
    assert violations == {}, (
        "write-primitive call(s) targeting a storage_state.json literal outside "
        f"storage_writer.py / migration.py: {violations}"
    )


def test_storage_state_write_exemptions_are_atomic_write_json_importers() -> None:
    """Coherence: every tracked storage-state exemption (except migration.py,
    which writes via shutil/atomic_update_json) is also an ``atomic_write_json``
    importer — so shrinking one list shrinks the other in lock-step."""
    for rel in _STORAGE_STATE_WRITE_EXEMPTIONS - {"migration.py"}:
        assert rel in _ATOMIC_WRITE_JSON_IMPORTERS, (
            f"{rel} is a storage-state exemption but not an atomic_write_json importer; "
            "the two tracking lists have drifted."
        )

"""Importable live-auth recovery scenarios for ``scripts/live_auth_matrix.py``.

Each module in this package is one *cell* of the maintainer live-auth matrix:
a small program that drives a real recovery path against real credentials and
prints a single JSON line describing what actually happened.

Why a package instead of ``python -c "<source string>"``
--------------------------------------------------------
These scenarios used to be built by concatenating Python source literals inside
``live_auth_matrix.py`` and handed to ``python -c``. That kept the process
isolation the matrix depends on, but the programs themselves were invisible to
Ruff and mypy, impossible to import from a test, and a failure reported a
traceback into ``<string>`` with no line to open. Moving them into real modules
keeps the isolation (the matrix still launches each one with
``python -m scripts._live_auth_scenarios.<module>`` in a child process with its
own ``NOTEBOOKLM_HOME`` and environment) while making the scenario bodies
lintable, type-checkable, importable, and directly testable (#2180).

Deliberately **not** under ``src/notebooklm/``: this is maintainer harness code
that must not ship to users or count against the package coverage gate.

Contract with the orchestrator
------------------------------
* Every scenario module exposes ``async def scenario() -> ScenarioResult`` and a
  synchronous ``main()`` entry point, and is runnable as ``python -m``.
* On success the process prints exactly one JSON object on stdout and exits 0.
  ``Matrix.record(..., expect_json=True)`` parses that object verbatim, so the
  key set of each payload is a frozen contract.
* On failure a scenario raises :class:`ScenarioError` via :func:`require`; the
  traceback goes to stderr and the process exits non-zero. Messages name the
  broken invariant and never carry cookie or token values.

Importability from the child process
------------------------------------
``Matrix.base_env`` puts BOTH ``<repo>/src`` and ``<repo>`` on ``PYTHONPATH``,
and every phase runs with ``cwd=<repo>``, so ``scripts._live_auth_scenarios`` is
importable in the child regardless of how the parent interpreter was started.
"""

from __future__ import annotations

from ._contract import ScenarioError, ScenarioResult, require, run_scenario

# ``emit`` is deliberately NOT re-exported: it is the printing half of
# ``run_scenario`` and no cell needs it directly. A cell that ever does can
# import it from ``._contract`` — an unused name in ``__all__`` reads like a
# supported entry point that nothing keeps honest.
__all__ = [
    "ScenarioError",
    "ScenarioResult",
    "require",
    "run_scenario",
]

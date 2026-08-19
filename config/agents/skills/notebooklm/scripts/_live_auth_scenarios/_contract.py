"""The result/failure contract shared by every live-auth scenario module.

The orchestrator (``scripts/live_auth_matrix.py``) treats a scenario child
process as: *exit 0 with one JSON object on stdout* or *non-zero with a
value-free diagnostic on stderr*. This module is the only place that shape is
implemented, so the cells cannot drift apart from each other.
"""

from __future__ import annotations

import asyncio
import json
from collections.abc import Callable, Coroutine
from typing import Any

#: The JSON object a scenario prints on success. Keys are per-scenario and are
#: read by the matrix report, so they may not be renamed casually.
ScenarioResult = dict[str, Any]


class ScenarioError(RuntimeError):
    """A live-auth scenario invariant did not hold.

    Subclasses :class:`RuntimeError` because that is what the embedded
    ``python -c`` cells raised before #2180 moved them into real modules; the
    orchestrator only ever sees the non-zero exit code and the stderr tail.
    """


def require(condition: object, message: str) -> None:
    """Fail the scenario unless ``condition`` is truthy.

    Deliberately not ``assert``: these programs may run under ``python -O``,
    where ``assert`` is stripped and the scenario would silently "pass".
    ``message`` must name the broken invariant, never quote a credential.
    """
    if not condition:
        raise ScenarioError(message)


def emit(payload: ScenarioResult) -> None:
    """Print the scenario's single-line JSON result on stdout."""
    print(json.dumps(payload))


def run_scenario(scenario: Callable[[], Coroutine[Any, Any, ScenarioResult]]) -> None:
    """Run one async scenario to completion and emit its JSON result.

    The result is printed *after* the scenario's async context managers have
    unwound, so a client that fails to close cannot be masked by a success
    payload that was already flushed.
    """
    emit(asyncio.run(scenario()))

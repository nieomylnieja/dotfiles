"""Hammer the canonical storage writer so the parent can kill it mid-write.

Unlike the other cells this one prints nothing and is *expected* to be killed:
``Matrix.phase_crash_safety`` starts it, sleeps briefly, sends ``SIGKILL``, and
then re-reads the target file. The file must always parse and must still hold
the required Google session cookies, proving ``replace_from_login`` never leaves
a torn canonical write behind.

Usage: ``python -m scripts._live_auth_scenarios.crash_safe_writer <target> <source>``
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from notebooklm._auth.storage import replace_from_login

from ._contract import require

#: Number of back-to-back canonical writes attempted before exiting normally.
WRITE_ITERATIONS = 10000


def main(argv: list[str] | None = None) -> None:
    """Rewrite ``argv[0]`` from the storage state in ``argv[1]``, repeatedly."""
    args = sys.argv[1:] if argv is None else argv
    # Name the argv contract. This cell is the only one taking arguments, and
    # it is *expected* to die by SIGKILL, so a bare IndexError from a wrong
    # invocation would be easy to mistake for the kill the parent just sent.
    require(len(args) >= 2, "crash_safe_writer needs <target> <source>")
    target = Path(args[0])
    # Explicit UTF-8, matching both sides of ``phase_crash_safety``. A
    # locale-dependent read is worse here than anywhere else in the package:
    # under a non-UTF-8 locale it raises before the first write, the parent
    # then kills an already-dead child and re-reads its own pristine copy,
    # which parses fine — so the cell reports PASS having never exercised the
    # canonical writer at all.
    state = json.loads(Path(args[1]).read_text(encoding="utf-8"))
    for _ in range(WRITE_ITERATIONS):
        replace_from_login(target, state, include_domains=None)


if __name__ == "__main__":
    main()

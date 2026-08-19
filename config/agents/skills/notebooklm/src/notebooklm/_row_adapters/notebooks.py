"""Notebook row adapters for ``batchexecute`` notebook-scoped RPCs.

Centralises the positional knowledge of the ``Project`` message returned by
notebook reads/creates and of the ``GeneratePromptSuggestions``
(``otmP3b`` / ``SUGGEST_PROMPTS``) reply.

Position contract (pinned by ``tests/unit/test_notebooks_row_adapter.py``):

* :class:`ProjectRow` — one decoded ``Project`` message:

  =====  ============================================================
  Index  Meaning
  =====  ============================================================
  3      notebook emoji
  9      ``PremiumFeatureInfo``
  11     ``ChatSession`` rows (CREATE response only)
  =====  ============================================================

* :class:`PromptSuggestionRow` — one suggestion row:

  =====  ============================================================
  Index  Meaning
  =====  ============================================================
  0      title (str)
  1      prompt (str) — a ready-to-send multi-line instruction
  =====  ============================================================
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, ClassVar

from ..rpc import RPCMethod, safe_index

__all__ = [
    "PromptSuggestionRow",
    "ProjectRow",
    "unwrap_prompt_suggestions",
]


@dataclass(frozen=True)
class ProjectRow:
    """Best-effort typed view over one decoded ``Project`` message.

    ``Notebook.from_api_response`` deliberately tolerates short rows because it
    also maps whole notebook listings: one partial row must not discard its
    siblings. These newly surfaced fields follow that contract. Missing or
    malformed optional leaves degrade to ``None``/``[]``; the load-bearing
    title/id/metadata handling remains owned by ``Notebook``.
    """

    _raw: Any = field(repr=False)

    _EMOJI_POS: ClassVar[int] = 3
    _PREMIUM_FEATURE_INFO_POS: ClassVar[int] = 9
    _CHAT_SESSIONS_POS: ClassVar[int] = 11

    @property
    def emoji(self) -> str | None:
        """Notebook emoji (``Project.emoji``), or ``None`` when unstated."""
        if not isinstance(self._raw, list) or len(self._raw) <= self._EMOJI_POS:
            return None
        value = self._raw[self._EMOJI_POS]
        return value if isinstance(value, str) else None

    @property
    def premium_feature_flags(self) -> tuple[bool | None, bool | None, bool | None] | None:
        """The three ``PremiumFeatureInfo`` flags, preserving unknown leaves.

        The mobile schema names the slots, but this positional adapter stays
        domain-type free and returns them in wire order. A present short block
        remains distinguishable from an absent block via ``None`` leaves.
        """
        if not isinstance(self._raw, list) or len(self._raw) <= self._PREMIUM_FEATURE_INFO_POS:
            return None
        block = self._raw[self._PREMIUM_FEATURE_INFO_POS]
        if not isinstance(block, list):
            return None

        def _flag(position: int) -> bool | None:
            if len(block) <= position:
                return None
            value = block[position]
            return value if isinstance(value, bool) else None

        return (_flag(0), _flag(1), _flag(2))

    @property
    def chat_session_ids(self) -> list[str]:
        """IDs from ``Project.chatSessions`` (populated on CREATE only).

        Each session is the single-field row ``[chatSessionId]``. Invalid rows
        are skipped independently so one malformed optional session does not
        make the created notebook unusable.
        """
        if not isinstance(self._raw, list) or len(self._raw) <= self._CHAT_SESSIONS_POS:
            return []
        rows = self._raw[self._CHAT_SESSIONS_POS]
        if not isinstance(rows, list):
            return []
        return [
            row[0]
            for row in rows
            if isinstance(row, list) and row and isinstance(row[0], str) and row[0]
        ]


# A single leading markdown *bullet* marker (``-``/``*``/``+``) plus its trailing
# space. The backend sometimes frames a suggestion as a markdown list item, so a
# ``prompt`` / ``title`` leaf can arrive as ``"\n- Ask X"``; an agent piping that
# straight into ``chat_ask`` would send a bullet-dash as the question. We strip
# one leading bullet so both the CLI and the MCP surface get a clean, ready-to-send
# string. Ordered-list counters (``1.`` / ``2026.``) are deliberately NOT matched:
# the only observed framing is the bullet, and a numeric prefix is frequently
# legitimate content (a year, a count) that must be preserved (#1912 review).
_LEADING_LIST_MARKER = re.compile(r"[-*+]\s+")


def _strip_leading_list_marker(text: str) -> str:
    """Return ``text`` with surrounding whitespace and one leading bullet marker removed.

    Tight normalization for suggestion leaves (issue #1909): only leading
    whitespace + a single leading bullet marker + trailing whitespace are removed.
    Interior newlines and content are left untouched, so a genuinely multi-line
    prompt keeps its body — only the leading list-item framing is stripped.

    ``lstrip`` runs before the match (not a full ``strip``) so a marker-only leaf
    like ``"\\n-   "`` collapses cleanly to ``""`` rather than a bare ``"-"``
    (#1912 review): the leading whitespace is removed first, the whole marker then
    matches, and the empty remainder is returned.
    """
    lstripped = text.lstrip()
    marker = _LEADING_LIST_MARKER.match(lstripped)
    if marker:
        return lstripped[marker.end() :].strip()
    return lstripped.rstrip()


# ``GeneratePromptSuggestions`` (``otmP3b``) method id, threaded into
# ``safe_index`` / drift diagnostics for the suggestion-list unwrap.
_SUGGEST_PROMPTS_METHOD_ID = RPCMethod.SUGGEST_PROMPTS.value

# Envelope-unwrap position: ``GeneratePromptSuggestions`` wraps the suggestion
# list as the first element of a single-element envelope
# (``[[[title, prompt], ...]]``).
_SUGGEST_PROMPTS_CONTAINER_POS = 0


def unwrap_prompt_suggestions(result: Any, *, source: str) -> list[Any]:
    """Return the suggestion-row list from a ``GeneratePromptSuggestions`` reply.

    The ``otmP3b`` reply wraps the rows as a single-element envelope
    (``[[ [title, prompt], [title, prompt], ... ]]``): the rows live at
    ``result[0]``. A falsy / non-list payload (no suggestions) yields ``[]``;
    a present-but-non-list inner container also yields ``[]``. This mirrors the
    permissive contract of the report-suggestion unwrap — a suggestion list is
    best-effort UI sugar, not a load-bearing decode, so an absent / degenerate
    payload degrades to an empty list rather than raising.
    """
    if not isinstance(result, list) or not result:
        return []
    inner = safe_index(
        result,
        _SUGGEST_PROMPTS_CONTAINER_POS,
        method_id=_SUGGEST_PROMPTS_METHOD_ID,
        source=source,
    )
    return inner if isinstance(inner, list) else []


@dataclass(frozen=True)
class PromptSuggestionRow:
    """Typed view of one raw ``GeneratePromptSuggestions`` suggestion row.

    The wrapped row is a single AI-suggested prompt entry from the ``otmP3b``
    (``SUGGEST_PROMPTS``) RPC. Position layout:

    =====  ============================================================
    Index  Meaning
    =====  ============================================================
    0      title (str)
    1      prompt (str) — a ready-to-send multi-line instruction
    =====  ============================================================

    Short / malformed rows degrade to empty strings rather than raising — a
    suggestion list is best-effort UI sugar (the same permissive contract as
    :class:`~notebooklm._row_adapters.artifacts.ReportSuggestionRow`). Positions
    are pinned by ``tests/unit/test_notebooks_row_adapter.py``.
    """

    _raw: Any = field(repr=False)

    _TITLE_POS: ClassVar[int] = 0
    _PROMPT_POS: ClassVar[int] = 1
    # A row must carry at least the prompt slot (index 1) to be usable.
    _MIN_LEN: ClassVar[int] = 2

    @property
    def is_well_formed(self) -> bool:
        """Whether the row is a list long enough to carry title + prompt."""
        return isinstance(self._raw, list) and len(self._raw) >= self._MIN_LEN

    def _str_at(self, position: int) -> str:
        """Return ``self._raw[position]`` when it is a str, else ``""``.

        Bounds-guarded so a short / malformed row degrades to ``""`` (the
        documented contract) instead of raising when a property is read without
        first checking :attr:`is_well_formed`.
        """
        if not isinstance(self._raw, list) or len(self._raw) <= position:
            return ""
        value = self._raw[position]
        return value if isinstance(value, str) else ""

    @property
    def title(self) -> str:
        """Suggestion title — empty string when absent / non-string.

        A leading markdown list marker (e.g. ``"\\n- "``) is stripped so the
        title is clean ready-to-display text (issue #1909).
        """
        return _strip_leading_list_marker(self._str_at(self._TITLE_POS))

    @property
    def prompt(self) -> str:
        """Suggestion prompt — empty string when absent / non-string.

        A leading markdown list marker (e.g. ``"\\n- "``) is stripped so the
        prompt is a clean ready-to-send string — an agent can pipe it straight
        into ``chat_ask`` without leaking a bullet-dash as the question (#1909).
        """
        return _strip_leading_list_marker(self._str_at(self._PROMPT_POS))

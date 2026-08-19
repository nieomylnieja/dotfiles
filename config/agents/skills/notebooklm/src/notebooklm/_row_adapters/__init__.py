"""Private positional-RPC-row adapter package.

Cohesive cluster promoted from the former flat ``_row_adapters_*.py`` modules (issue #1328).
Re-exports the typed row views; importers may also reach submodules directly
(``from .._row_adapters.sources import SourceRow``).
"""

from . import artifacts, chat, documents, labels, notebooks, notes, research, sources
from .artifacts import ArtifactRow, ReportSuggestionRow
from .chat import (
    AnswerRow,
    CitationDetail,
    CitationRow,
    ConversationTurnRow,
    ErrorPayloadRow,
    StreamFrameRow,
    unwrap_conversation_turns,
)
from .documents import (
    AnnotationEntryRow,
    DocumentBodyRow,
    ParagraphElementRow,
    ParagraphRow,
    StructuralElementRow,
    TextRunRow,
    build_blocks,
    build_document,
)
from .labels import LabelRow
from .notes import NoteRow
from .research import (
    ImportedSourceRow,
    ResearchResultRow,
    ResearchStartRow,
    ResearchTaskInfoRow,
    ResearchTaskRow,
    unwrap_import_rows,
    unwrap_poll_tasks,
)
from .sources import SourceRow, SourceRowShape

__all__ = [
    "artifacts",
    "chat",
    "documents",
    "labels",
    "notebooks",
    "notes",
    "research",
    "sources",
    "AnnotationEntryRow",
    "AnswerRow",
    "ArtifactRow",
    "CitationDetail",
    "CitationRow",
    "ConversationTurnRow",
    "DocumentBodyRow",
    "ErrorPayloadRow",
    "ImportedSourceRow",
    "LabelRow",
    "NoteRow",
    "ParagraphElementRow",
    "ParagraphRow",
    "ReportSuggestionRow",
    "ResearchResultRow",
    "ResearchStartRow",
    "ResearchTaskInfoRow",
    "ResearchTaskRow",
    "SourceRow",
    "SourceRowShape",
    "StreamFrameRow",
    "StructuralElementRow",
    "TextRunRow",
    "build_blocks",
    "build_document",
    "unwrap_conversation_turns",
    "unwrap_import_rows",
    "unwrap_poll_tasks",
]

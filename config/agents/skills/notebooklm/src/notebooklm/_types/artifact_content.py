"""Typed artifact content and per-user state records."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Any, TypeAlias


class ArtifactMediaType(str, Enum):
    """How an audio/video artifact URL is intended to be consumed."""

    PROGRESSIVE = "progressive"
    HLS = "hls"
    DASH = "dash"
    DOWNLOAD = "download"
    UNKNOWN = "unknown"


@dataclass(frozen=True)
class ArtifactMedia:
    """One media URL returned with an audio or video artifact.

    ``type_code`` preserves the backend integer even when :attr:`kind` is
    :attr:`ArtifactMediaType.UNKNOWN`, so a newly-added streaming variant is
    observable before the client learns its name.
    """

    url: str
    kind: ArtifactMediaType
    type_code: int | None = None
    mime_type: str | None = None


@dataclass(frozen=True)
class ArtifactSlide:
    """One rendered slide and its accessibility/search text."""

    image_url: str | None
    width: int | None
    height: int | None
    alt_text: str | None
    text: str | None


@dataclass(frozen=True)
class ArtifactInfographic:
    """One rendered infographic and its accessibility/search text."""

    title: str | None
    image_url: str | None
    width: int | None
    height: int | None
    alt_text: str | None
    text: str | None


@dataclass(frozen=True)
class AudioArtifactUserState:
    """Per-user Audio Overview playback state returned by artifact listing."""

    playback_position_seconds: float


@dataclass(frozen=True)
class FlashcardArtifactUserState:
    """Per-user flashcard study state returned by artifact listing."""

    card_acquisitions: dict[str, str]
    current_card_index: int | None = None
    hidden_card_indices: tuple[int, ...] = ()
    last_shown_order: tuple[int, ...] = ()
    current_view: str | None = None


@dataclass(frozen=True)
class UnknownArtifactUserState:
    """An artifact user-state variant this client does not yet understand.

    The raw value is retained so backend additions degrade observably instead
    of being discarded or misclassified as one of the known variants.
    """

    raw: Any


ArtifactUserState: TypeAlias = (
    AudioArtifactUserState | FlashcardArtifactUserState | UnknownArtifactUserState
)


__all__ = [
    "ArtifactInfographic",
    "ArtifactMedia",
    "ArtifactMediaType",
    "ArtifactSlide",
    "ArtifactUserState",
    "AudioArtifactUserState",
    "FlashcardArtifactUserState",
    "UnknownArtifactUserState",
]

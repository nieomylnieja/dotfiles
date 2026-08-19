"""Typed artifact content/user-state decoding for issues #2129/#2135/#2136."""

from __future__ import annotations

from datetime import datetime, timezone

from notebooklm import (
    Artifact,
    ArtifactMediaType,
    ArtifactType,
    AudioArtifactUserState,
    FlashcardArtifactUserState,
    ReportFormat,
    UnknownArtifactUserState,
)
from notebooklm.rpc import ArtifactTypeCode


def _row(type_code: int, *, length: int = 22) -> list[object]:
    row: list[object] = [None] * length
    row[:5] = ["artifact-id", "Title", type_code, None, 3]
    row[15] = [1_700_000_000, 0]
    return row


def test_audio_decodes_all_media_duration_and_resume_state() -> None:
    row = _row(ArtifactTypeCode.AUDIO.value)
    row[6] = [
        None,
        None,
        None,
        None,
        None,
        [
            ["https://example.test/audio.mp4", 1, "audio/mp4"],
            ["https://example.test/audio.m3u8", 2],
            ["https://example.test/audio.mpd", 3],
            ["https://example.test/audio-download.mp4", 4, "audio/mp4"],
        ],
        [872, 489_796_000],
    ]
    row[17] = [[[123, 500_000_000]]]

    artifact = Artifact.from_api_response(row)

    assert artifact.url == "https://example.test/audio.mp4"
    assert [media.kind for media in artifact.media_urls] == [
        ArtifactMediaType.PROGRESSIVE,
        ArtifactMediaType.HLS,
        ArtifactMediaType.DASH,
        ArtifactMediaType.DOWNLOAD,
    ]
    assert artifact.media_urls[1].mime_type is None
    assert artifact.duration_seconds == 872.489796
    assert artifact.user_state == AudioArtifactUserState(playback_position_seconds=123.5)


def test_video_retains_unknown_media_type_code() -> None:
    row = _row(ArtifactTypeCode.VIDEO.value)
    row[8] = [
        None,
        None,
        None,
        None,
        [
            ["https://example.test/video.mp4", 1, "video/mp4"],
            ["https://example.test/future", 99, "video/future"],
        ],
        [462, 291_666_000],
    ]

    artifact = Artifact.from_api_response(row)

    assert artifact.duration_seconds == 462.291666
    assert artifact.media_urls[1].kind is ArtifactMediaType.UNKNOWN
    assert artifact.media_urls[1].type_code == 99


def test_slide_and_infographic_accessibility_text_is_typed() -> None:
    slides = _row(ArtifactTypeCode.SLIDE_DECK.value)
    slides[16] = [
        ["prompt"],
        "Deck title",
        [
            [
                ["https://example.test/slide.png", 1376, 768],
                "A diagram of an agent loop",
                "THINK → ACT → OBSERVE",
            ]
        ],
        "https://example.test/deck.pdf",
    ]
    infographic = _row(ArtifactTypeCode.INFOGRAPHIC.value)
    infographic[14] = [
        ["prompt"],
        "Infographic title",
        [
            [
                "Five stages",
                ["https://example.test/info.png", 2752, 1536],
                "Five connected stages",
                "STAGE 1\nSTAGE 2\nSTAGE 3",
            ]
        ],
    ]

    slide_artifact = Artifact.from_api_response(slides)
    infographic_artifact = Artifact.from_api_response(infographic)

    assert slide_artifact.slides[0].alt_text == "A diagram of an agent loop"
    assert slide_artifact.slides[0].text == "THINK → ACT → OBSERVE"
    assert slide_artifact.slides[0].width == 1376
    assert infographic_artifact.infographics[0].title == "Five stages"
    assert infographic_artifact.infographics[0].text == "STAGE 1\nSTAGE 2\nSTAGE 3"
    assert infographic_artifact.url == "https://example.test/info.png"


def test_report_kind_maps_known_values_and_retains_future_values() -> None:
    known = _row(ArtifactTypeCode.REPORT.value)
    known[7] = ["# Report", ["Concept Explanation"]]
    future = _row(ArtifactTypeCode.REPORT.value)
    future[7] = ["# Report", ["Future Report Shape"]]

    known_artifact = Artifact.from_api_response(known)
    future_artifact = Artifact.from_api_response(future)

    assert known_artifact.report_kind == "Concept Explanation"
    assert known_artifact.report_format is ReportFormat.CONCEPT_EXPLANATION
    assert future_artifact.report_kind == "Future Report Shape"
    assert future_artifact.report_format is None


def test_common_row_metadata_decodes_without_losing_order_or_nanos() -> None:
    row = _row(ArtifactTypeCode.REPORT.value)
    row[3] = [[["source-b"]], [["source-a"]]]
    row[10] = [1_700_000_100, 250_000_000]
    row[21] = '"artifact-etag"'

    artifact = Artifact.from_api_response(row)

    assert artifact.source_ids == ("source-b", "source-a")
    assert artifact.last_modified_at == datetime(
        2023, 11, 14, 22, 15, 0, 250_000, tzinfo=timezone.utc
    )
    assert artifact.etag == '"artifact-etag"'


def test_flashcard_and_unknown_user_state_are_distinguishable() -> None:
    flashcards = _row(ArtifactTypeCode.QUIZ.value)
    flashcards[9] = [None, [1]]
    flashcards[17] = [
        None,
        None,
        [
            {
                "cardAcquisitionsMapping": {"0": "acquired", "2": "not_acquired"},
                "currentCardIndex": 11,
                "hiddenCardIndices": [4, 7],
                "lastShownOrder": [2, 0, 1],
                "currentView": "card",
            }
        ],
    ]
    future = _row(ArtifactTypeCode.FILE.value)
    future[17] = [None, ["future-state"]]

    flashcard_state = Artifact.from_api_response(flashcards).user_state
    unknown_state = Artifact.from_api_response(future).user_state

    assert flashcard_state == FlashcardArtifactUserState(
        card_acquisitions={"0": "acquired", "2": "not_acquired"},
        current_card_index=11,
        hidden_card_indices=(4, 7),
        last_shown_order=(2, 0, 1),
        current_view="card",
    )
    assert isinstance(unknown_state, UnknownArtifactUserState)
    assert unknown_state.raw == [None, ["future-state"]]


def test_quiz_app_state_is_not_misclassified_as_flashcard_progress() -> None:
    quiz = _row(ArtifactTypeCode.QUIZ.value)
    quiz[9] = [None, [2]]
    quiz[17] = [
        None,
        None,
        [
            {
                "currentView": "question",
                "currentQuestionIndex": 3,
                "hiddenQuestionIndices": [1],
                "userAnswers": {"0": 2},
            }
        ],
    ]

    state = Artifact.from_api_response(quiz).user_state

    assert isinstance(state, UnknownArtifactUserState)
    assert state.raw == quiz[17]


def test_audio_state_shape_on_another_artifact_type_stays_unknown() -> None:
    file_artifact = _row(ArtifactTypeCode.FILE.value)
    file_artifact[17] = [[[12, 0]]]

    state = Artifact.from_api_response(file_artifact).user_state

    assert isinstance(state, UnknownArtifactUserState)
    assert state.raw == file_artifact[17]


def test_fantasy_map_and_file_are_publicly_representable() -> None:
    fantasy_map = Artifact.from_api_response(
        ["fantasy", "Fantasy", ArtifactTypeCode.FANTASY_MAP.value, None, 3]
    )
    file_artifact = Artifact.from_api_response(
        ["file", "File", ArtifactTypeCode.FILE.value, None, 3]
    )

    assert fantasy_map.kind is ArtifactType.FANTASY_MAP
    assert file_artifact.kind is ArtifactType.FILE


def test_short_row_defaults_every_new_field_without_raising() -> None:
    artifact = Artifact.from_api_response(["id", "Title", 1, None, 3])

    assert artifact.media_urls == ()
    assert artifact.duration_seconds is None
    assert artifact.slides == ()
    assert artifact.infographics == ()
    assert artifact.report_kind is None
    assert artifact.source_ids == ()
    assert artifact.last_modified_at is None
    assert artifact.etag is None
    assert artifact.user_state is None

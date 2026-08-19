"""Live-recorded regression for streamed ``NextStepSuggestions`` (#2119)."""

from __future__ import annotations

import pytest

from tests.integration.conftest import skip_no_cassettes
from tests.vcr_config import notebooklm_vcr

from ._vcr_helpers import vcr_client

pytestmark = [pytest.mark.vcr, skip_no_cassettes]

CHAT_NOTEBOOK_ID = "bb00c9e3-656c-4fd2-b890-2b71e1cf3814"


@notebooklm_vcr.use_cassette("chat_next_steps.yaml")
@pytest.mark.asyncio
async def test_live_chat_answer_carries_next_step_suggestions() -> None:
    """The live backend's follow-up chips survive stream parsing and typing."""
    async with vcr_client() as client:
        result = await client.chat.ask(
            CHAT_NOTEBOOK_ID,
            "What is one useful question I should ask next?",
        )

    assert result.next_steps
    assert all(step.question and type(step.type_code) is int for step in result.next_steps)

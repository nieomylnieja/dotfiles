"""Live-recorded regression for notebook emoji mutation (#2133)."""

from __future__ import annotations

import pytest

from tests.integration.conftest import skip_no_cassettes
from tests.vcr_config import notebooklm_vcr

from ._vcr_helpers import vcr_client

pytestmark = [pytest.mark.vcr, skip_no_cassettes]


@notebooklm_vcr.use_cassette("notebooks_emoji_update.yaml")
@pytest.mark.asyncio
async def test_live_emoji_set_and_clear_preserve_title() -> None:
    """MutateProject ChangeProperty tag 3 sets emoji independently of title.

    Record with:
        NOTEBOOKLM_VCR_RECORD=1 uv run pytest tests/integration/test_notebook_emoji_vcr.py -v
    """
    title = "VCR Emoji Mutation Regression"
    async with vcr_client() as client:
        notebook = await client.notebooks.create(title)
        try:
            updated = await client.notebooks.set_emoji(notebook.id, "📖")
            assert updated.title == title
            assert updated.emoji == "📖"

            cleared = await client.notebooks.set_emoji(notebook.id, "")
            assert cleared.title == title
            assert cleared.emoji in (None, "")
        finally:
            await client.notebooks.delete(notebook.id)

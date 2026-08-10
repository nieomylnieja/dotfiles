"""Integration tests for NotesAPI.

Moved from ``tests/unit/`` to ``tests/integration/``.
Mock-backed (``pytest_httpx``); ``allow_no_vcr`` opts out of the
integration-tree VCR enforcement hook in ``tests/integration/conftest.py``.
Cassette-backed coverage lives in ``tests/integration/test_vcr_comprehensive.py``.
"""

import pytest
from pytest_httpx import HTTPXMock

from notebooklm import NotebookLMClient
from notebooklm.exceptions import NoteNotFoundError, RPCError
from notebooklm.rpc import RPCMethod

pytestmark = pytest.mark.allow_no_vcr


class TestNotesAPI:
    """Integration tests for the NotesAPI."""

    @pytest.mark.asyncio
    async def test_list_notes(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """Test listing notes in a notebook."""
        response = build_rpc_response(
            RPCMethod.GET_NOTES_AND_MIND_MAPS,
            [
                [
                    ["note_001", ["note_001", "Note content 1", None, None, "My First Note"]],
                    ["note_002", ["note_002", "Note content 2", None, None, "My Second Note"]],
                ]
            ],
        )
        httpx_mock.add_response(content=response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            notes = await client.notes.list("nb_123")

        assert len(notes) == 2
        assert notes[0].id == "note_001"
        assert notes[0].title == "My First Note"
        assert notes[0].content == "Note content 1"
        assert notes[1].id == "note_002"
        assert notes[1].title == "My Second Note"

    @pytest.mark.asyncio
    async def test_list_notes_empty(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """Test listing notes when notebook is empty."""
        response = build_rpc_response(RPCMethod.GET_NOTES_AND_MIND_MAPS, [[]])
        httpx_mock.add_response(content=response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            notes = await client.notes.list("nb_123")

        assert notes == []

    @pytest.mark.asyncio
    async def test_list_notes_excludes_mind_maps(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """Test that list() filters out mind maps."""
        response = build_rpc_response(
            RPCMethod.GET_NOTES_AND_MIND_MAPS,
            [
                [
                    ["note_001", ["note_001", "Regular note content", None, None, "Regular Note"]],
                    [
                        "mm_001",
                        ["mm_001", '{"title":"Mind Map","children":[]}', None, None, "Mind Map"],
                    ],
                ]
            ],
        )
        httpx_mock.add_response(content=response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            notes = await client.notes.list("nb_123")

        assert len(notes) == 1
        assert notes[0].id == "note_001"

    @pytest.mark.asyncio
    async def test_get_note(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """Test getting a specific note by ID."""
        response = build_rpc_response(
            RPCMethod.GET_NOTES_AND_MIND_MAPS,
            [
                [
                    ["note_001", ["note_001", "Content 1", None, None, "Note 1"]],
                    ["note_002", ["note_002", "Content 2", None, None, "Note 2"]],
                ]
            ],
        )
        httpx_mock.add_response(content=response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            note = await client.notes.get("nb_123", "note_002")

        assert note is not None
        assert note.id == "note_002"
        assert note.title == "Note 2"
        assert note.content == "Content 2"

    @pytest.mark.asyncio
    async def test_get_note_not_found(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """Test getting a note that doesn't exist raises NoteNotFoundError."""
        response = build_rpc_response(
            RPCMethod.GET_NOTES_AND_MIND_MAPS,
            [
                [
                    ["note_001", ["note_001", "Content", None, None, "Title"]],
                ]
            ],
        )
        httpx_mock.add_response(content=response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            # v0.8.0: a miss now raises NoteNotFoundError (issue #1247).
            with pytest.raises(NoteNotFoundError):
                await client.notes.get("nb_123", "nonexistent")

    @pytest.mark.asyncio
    async def test_list_notes_populates_created_at(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """``notes.list`` decodes the per-row creation timestamp (issue #1529).

        The timestamp lives in the note metadata envelope at
        ``row[1][2][2][0]``. Pin the EPOCH INT (TZ-invariant) rather than a
        wall-time string so the assertion is host-timezone independent.
        """
        metadata = [1, "400237754469", [1768312234, 146794000]]
        response = build_rpc_response(
            RPCMethod.GET_NOTES_AND_MIND_MAPS,
            [[["note_001", ["note_001", "Body", metadata, None, "Timestamped Note"]]]],
        )
        httpx_mock.add_response(content=response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            notes = await client.notes.list("nb_123")

        assert len(notes) == 1
        assert notes[0].created_at is not None
        assert int(notes[0].created_at.timestamp()) == 1768312234

    @pytest.mark.asyncio
    async def test_get_note_populates_created_at(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """``notes.get`` decodes the creation timestamp (issue #1529)."""
        metadata = [1, "400237754469", [1768311078, 286553000]]
        response = build_rpc_response(
            RPCMethod.GET_NOTES_AND_MIND_MAPS,
            [[["note_001", ["note_001", "Body", metadata, None, "Title"]]]],
        )
        httpx_mock.add_response(content=response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            note = await client.notes.get("nb_123", "note_001")

        assert note.created_at is not None
        assert int(note.created_at.timestamp()) == 1768311078

    @pytest.mark.asyncio
    async def test_create_note(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """Test creating a new note."""
        create_response = build_rpc_response(RPCMethod.CREATE_NOTE, [["new_note_id"]])
        httpx_mock.add_response(content=create_response.encode())

        update_response = build_rpc_response(RPCMethod.UPDATE_NOTE, None)
        httpx_mock.add_response(content=update_response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            note = await client.notes.create("nb_123", "My Title", "My Content")

        assert note.id == "new_note_id"
        assert note.title == "My Title"
        assert note.content == "My Content"
        # A CREATE_NOTE response with no metadata envelope leaves created_at
        # genuinely absent (soft None), not a fabricated value.
        assert note.created_at is None

        requests = httpx_mock.get_requests()
        assert RPCMethod.CREATE_NOTE in str(requests[0].url)
        assert RPCMethod.UPDATE_NOTE in str(requests[1].url)

    @pytest.mark.asyncio
    async def test_create_note_populates_created_at(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """``notes.create`` decodes the create-time timestamp when the
        CREATE_NOTE response carries the metadata envelope (issue #1529).

        The wire row is the bare inner envelope
        ``[id, content, metadata, None, title]``; ``create_note`` wraps it as
        ``[id, inner]`` so ``NoteRow``'s centralised ``row[1][2][2][0]`` descent
        reads the epoch. Pin the EPOCH INT (TZ-invariant).
        """
        inner = ["new_note_id", "", [1, "400237754469", [1768312234, 146794000]], None, "My Title"]
        create_response = build_rpc_response(RPCMethod.CREATE_NOTE, [inner])
        httpx_mock.add_response(content=create_response.encode())

        update_response = build_rpc_response(RPCMethod.UPDATE_NOTE, None)
        httpx_mock.add_response(content=update_response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            note = await client.notes.create("nb_123", "My Title", "My Content")

        assert note.id == "new_note_id"
        assert note.created_at is not None
        assert int(note.created_at.timestamp()) == 1768312234

    @pytest.mark.asyncio
    async def test_create_note_populates_created_at_flat_shape(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """``notes.create`` decodes the timestamp from the FLAT CREATE_NOTE
        shape too (issue #1529).

        Here ``result`` IS the inner envelope (``result[0]`` is the string id),
        so the timestamp lives at ``result[2][2][0]``. The flat path must yield
        the SAME decoded epoch as the wrapped path — not ``None``. Pin the EPOCH
        INT (TZ-invariant).
        """
        inner = ["new_note_id", "", [1, "400237754469", [1768312234, 146794000]], None, "My Title"]
        # Flat shape: the inner envelope is the RPC result directly (no outer
        # wrapping list around the row).
        create_response = build_rpc_response(RPCMethod.CREATE_NOTE, inner)
        httpx_mock.add_response(content=create_response.encode())

        update_response = build_rpc_response(RPCMethod.UPDATE_NOTE, None)
        httpx_mock.add_response(content=update_response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            note = await client.notes.create("nb_123", "My Title", "My Content")

        assert note.id == "new_note_id"
        assert note.created_at is not None
        assert int(note.created_at.timestamp()) == 1768312234

    @pytest.mark.asyncio
    async def test_create_note_raises_when_id_unparseable(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """A CREATE_NOTE payload with no extractable id must raise, not
        return a success-shaped ``Note(id="")`` (issue #1162)."""
        # ``[[]]`` parses but yields no note id (empty inner row).
        create_response = build_rpc_response(RPCMethod.CREATE_NOTE, [[]])
        httpx_mock.add_response(content=create_response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            with pytest.raises(RPCError, match="no usable note id"):
                await client.notes.create("nb_123", "My Title", "My Content")

        # The finalize UPDATE_NOTE must never have been attempted: bailing
        # before UPDATE_NOTE is what prevents the degenerate empty-id note.
        requests = httpx_mock.get_requests()
        assert len(requests) == 1
        assert RPCMethod.CREATE_NOTE in str(requests[0].url)

    @pytest.mark.asyncio
    async def test_update_note(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """Test updating an existing note."""
        # v0.8.0 (#1362): update() runs a GET_NOTES_AND_MIND_MAPS existence
        # preflight first; the note must be present so the UPDATE_NOTE RPC fires.
        preflight = build_rpc_response(
            RPCMethod.GET_NOTES_AND_MIND_MAPS,
            [[["note_001", ["note_001", "Existing", None, None, "Note"]]]],
        )
        httpx_mock.add_response(content=preflight.encode())
        response = build_rpc_response(RPCMethod.UPDATE_NOTE, None)
        httpx_mock.add_response(content=response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            await client.notes.update("nb_123", "note_001", "Updated content", "Updated title")

        update_request = httpx_mock.get_requests()[-1]
        assert RPCMethod.UPDATE_NOTE in str(update_request.url)
        assert "source-path=%2Fnotebook%2Fnb_123" in str(update_request.url)

    @pytest.mark.asyncio
    async def test_delete_note(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """Test deleting a note."""
        response = build_rpc_response(RPCMethod.DELETE_NOTE, None)
        httpx_mock.add_response(content=response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            result = await client.notes.delete("nb_123", "note_001")

        assert result is None
        request = httpx_mock.get_request()
        assert RPCMethod.DELETE_NOTE in str(request.url)

    @pytest.mark.asyncio
    async def test_list_mind_maps(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """Test listing mind maps in a notebook."""
        response = build_rpc_response(
            RPCMethod.GET_NOTES_AND_MIND_MAPS,
            [
                [
                    ["note_001", ["note_001", "Regular note", None, None, "Note"]],
                    [
                        "mm_001",
                        ["mm_001", '{"title":"Mind Map 1","children":[]}', None, None, "MM1"],
                    ],
                    ["mm_002", ["mm_002", '{"nodes":[{"id":"1"}]}', None, None, "MM2"]],
                ]
            ],
        )
        httpx_mock.add_response(content=response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            mind_maps = await client.notes.list_mind_maps("nb_123")

        assert len(mind_maps) == 2

    @pytest.mark.asyncio
    async def test_delete_mind_map(
        self,
        auth_tokens,
        httpx_mock: HTTPXMock,
        build_rpc_response,
    ):
        """Test deleting a mind map."""
        response = build_rpc_response(RPCMethod.DELETE_NOTE, None)
        httpx_mock.add_response(content=response.encode())

        async with NotebookLMClient(auth_tokens) as client:
            result = await client.notes.delete_mind_map("nb_123", "mm_001")

        assert result is None
        request = httpx_mock.get_request()
        assert RPCMethod.DELETE_NOTE in str(request.url)

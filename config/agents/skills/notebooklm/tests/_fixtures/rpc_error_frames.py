"""Captured ``batchexecute`` rejection frames, kept in one place.

Every constant here is a **recorded** shape, not a shape someone believed the
backend emits. That distinction is the point: issue #2134 shipped a positional
read validated only by fixtures that encoded the author's guess, and #2193
exists because the tests that guarded issue #239 asserted against a row shape
the backend has never sent.

Each entry records where it came from. When you add one, add its provenance
too — "I made this up to make the test pass" is not provenance.
"""

from __future__ import annotations

import json
from typing import Any

__all__ = [
    "CREATE_ARTIFACT_METHOD_ID",
    "INVALID_ARGUMENT_STATUS",
    "LIVE_CREATE_ARTIFACT_INVALID_ARGUMENT_BODY",
    "LIVE_RETRY_ARTIFACT_NOT_FOUND_BODY",
    "LIVE_REVISE_SLIDE_NOT_FOUND_BODY",
    "MIND_MAP_HAS_NO_OBSERVED_REJECTION",
    "USER_DISPLAYABLE_RATE_LIMIT_STATUS",
    "raw_batchexecute_body",
    "user_displayable_rejection_chunks",
]

#: ``CREATE_ARTIFACT``. Duplicated as a literal rather than imported from
#: ``RPCMethod`` so a test that decodes a captured body is comparing the body
#: against the id that was actually on the wire when it was captured — if
#: Google re-obfuscates the method, the mismatch should surface as a test
#: failure rather than being silently papered over by the enum.
CREATE_ARTIFACT_METHOD_ID = "R7cb6c"

#: The ``google.rpc.Status`` block a ``UserDisplayableError`` rejection carries
#: at index 5 of its ``wrb.fr`` frame.
#:
#: Provenance: the "Real-world structure from API rate limit response" sample
#: that has been pinned in ``tests/unit/test_decoder.py`` since the rate-limit
#: path was written. Note what it does NOT contain: index 1
#: (``google.rpc.Status.message``) is ``None`` and the detail body is int-only,
#: so this frame carries **no server-authored human-readable text at all**. The
#: message a caller sees for it is entirely client-authored (#2188).
USER_DISPLAYABLE_RATE_LIMIT_STATUS: list[Any] = [
    8,
    None,
    [
        [
            "type.googleapis.com/google.internal.labs.tailwind"
            ".orchestration.v1.UserDisplayableError",
            [None, None, None, None, [None, [[1]], 2]],
        ]
    ],
]

#: The bare ``google.rpc.Status`` a create-time rejection carries.
#:
#: Provenance: live probe 2026-08-13 against a real account — ``CREATE_ARTIFACT``
#: for an Audio Overview on a notebook with no sources. Code 3 is
#: ``INVALID_ARGUMENT``. The array is length 1: the server sent no message and
#: no details.
INVALID_ARGUMENT_STATUS: list[Any] = [3]

#: The complete raw HTTP body of that live rejection, verbatim except for the
#: ``af.httprm`` nonce (replaced with the same number of zeroes).
#:
#: Provenance: live probe 2026-08-13, ``NOTEBOOKLM_PROFILE=peopleconf``,
#: ``generate_audio`` on a freshly created source-less notebook. Kept as raw
#: text — anti-XSSI prefix, byte-count framing and trailing frames included —
#: so tests can drive the *whole* decode pipeline rather than a hand-assembled
#: chunk list.
#:
#: **Do not "correct" the byte counts.** They read ``104`` and ``25`` for chunks
#: of 102 and 23 characters — a consistent +2 — and that is what the server
#: sent: two independent captures (2026-08-13, different notebooks and
#: nonces) declare exactly the same pair, and the scrub is width-preserving so
#: it cannot have shifted them. Note the blank line after the anti-XSSI prefix,
#: which :func:`raw_batchexecute_body` does not reproduce; this body is the
#: only fixture in the suite that carries real server framing, and decoding it
#: increments ``byte_count_mismatch_total`` (pinned by
#: ``tests/unit/test_decoder.py::TestLiveCapturedFraming``). The decoder is
#: deliberately tolerant of that — see ``parse_chunked_response``'s Note: block.
LIVE_CREATE_ARTIFACT_INVALID_ARGUMENT_BODY = (
    ")]}'\n\n"
    "104\n"
    '[["wrb.fr","R7cb6c",null,null,null,[3],"generic"],["di",64],'
    '["af.httprm",64,"0000000000000000000",10]]\n'
    "25\n"
    '[["e",4,null,null,140]]\n'
)

#: ``RETRY_ARTIFACT`` refused for an artifact id that does not exist.
#:
#: Provenance: live probe 2026-08-13, same session — ``retry_failed`` against
#: ``"no-such-artifact-id"``. Code 5 is ``NOT_FOUND``. The ``+2`` byte-count
#: offset above holds here too (107 declared for 105 characters), enforced by
#: ``TestLiveCapturedFraming``. The nonce is zeroed width-preservingly: this
#: capture's was NEGATIVE (``-3683449295807497843``, 20 chars incl. the sign),
#: so the placeholder keeps the sign and is 20 too — it is not a stray extra
#: digit relative to the 19-char create placeholder.
LIVE_RETRY_ARTIFACT_NOT_FOUND_BODY = (
    ")]}'\n\n"
    "107\n"
    '[["wrb.fr","Rytqqe",null,null,null,[5],"generic"],["di",113],'
    '["af.httprm",113,"-0000000000000000000",11]]\n'
    "25\n"
    '[["e",4,null,null,143]]\n'
)

#: ``REVISE_SLIDE`` refused for an artifact id that does not exist.
#:
#: Provenance: live probe 2026-08-13, same session — ``revise_slide`` against
#: ``"no-such-artifact-id"``. Code 5 is ``NOT_FOUND``. The ``["di",87]`` /
#: ``["af.httprm",86,…]`` pair genuinely disagrees by one in this capture while
#: the other two fixtures repeat the same number — transcribed as received, and
#: another reason not to tidy these bodies into looking uniform.
LIVE_REVISE_SLIDE_NOT_FOUND_BODY = (
    ")]}'\n\n"
    "104\n"
    '[["wrb.fr","KmcKPe",null,null,null,[5],"generic"],["di",87],'
    '["af.httprm",86,"0000000000000000000",11]]\n'
    "25\n"
    '[["e",4,null,null,140]]\n'
)

#: Live evidence that the mind-map path has NO observed rejection shape.
#:
#: ``GENERATE_MIND_MAP`` on the same source-less notebook was **not refused** —
#: the backend generated a generic mind map and returned it. So unlike the three
#: artifact RPCs above, that call site has no captured status-tagged null, and
#: opting it into ``raise_on_null_status`` would be inference rather than
#: evidence. Recorded here so the next reader does not re-derive it (#2188).
MIND_MAP_HAS_NO_OBSERVED_REJECTION = True


def raw_batchexecute_body(frames: list[Any]) -> str:
    """Wrap decoded ``wrb.fr`` frames back into a raw batchexecute body.

    Mirrors the anti-XSSI prefix and byte-count framing the server uses, so a
    test can feed ``decode_response`` the same kind of string the transport
    hands it instead of pre-parsed chunks.
    """
    chunk = json.dumps(frames)
    return f")]}}'\n{len(chunk)}\n{chunk}\n"


def user_displayable_rejection_chunks(method_id: str) -> list[Any]:
    """Parsed chunks for a ``UserDisplayableError`` rejection of ``method_id``.

    A null result plus :data:`USER_DISPLAYABLE_RATE_LIMIT_STATUS` at index 5 —
    the shape ``tests/fixtures/rpc_golden/CREATE_ARTIFACT.json`` pins as its
    ``user_displayable_rate_limit`` drift case, with the detail body restored to
    the recorded structure.
    """
    return [
        [
            [
                "wrb.fr",
                method_id,
                None,
                None,
                None,
                USER_DISPLAYABLE_RATE_LIMIT_STATUS,
                "generic",
            ]
        ]
    ]

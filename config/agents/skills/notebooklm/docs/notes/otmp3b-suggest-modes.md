# `otmP3b` (GeneratePromptSuggestions) mode → surface map

Evidence record for the `suggest_prompts` mode enum (field-4 `C0` of the
`SUGGEST_PROMPTS` / `otmP3b` request). Backs the MCP `suggest_prompts` tool's
`surface` labels and the client cap (`_notebook_payloads._PROMPT_SUGGESTIONS_MODE_MAX = 10`).
Investigated live 2026-07-01 (#1726); supersedes the earlier output-only #1612 guess.

## Map

| mode | surface · format | how established |
|---|---|---|
| 1 | Audio · Deep Dive | **browser-verified** — opened the Audio Overview *Customize* dialog headless (Playwright + stored `storage_state` auth), clicked the "Deep Dive" format card, decoded the `otmP3b` request's trailing mode |
| 2 | Audio · Brief | browser-verified (Brief card) |
| 3 | Video · Explainer | real web capture — `otmP3b` request while customizing a Video Explainer |
| 4 | Chat · ask (default) | client live-probe — returns "ask about the content" chat questions; the web chat default |
| 5 | Audio · Critique | browser-verified (Critique card) |
| 6 | Audio · Debate | browser-verified (Debate card); output = debate scaffolding |
| 7 | — unidentified | no UI surface sends it; excluded from the tool |
| 8 | Quiz | client live-probe — returns quiz-generation prompts |
| 9 | Flashcards | client live-probe — returns flashcard prompts |
| 10 | Video · Short | real web capture — controlled pair (same notebook + source, mode 3 vs 10) |
| 0, 11+ | INTERNAL (server error) | out of range |

## Two axes (why the labels are honest)

There are two *different* measurements, and they are **consistent**, not contradictory:

- **Surface axis (#1726):** which mode a studio *Customize* dialog SENDS for its
  format's suggestions. This is request-side wiring — the `otmP3b` mode the UI
  emits per format. It's how the labels are assigned (a card labeled "Deep Dive"
  sends mode 1, so mode 1 = the Audio Deep Dive suggestion surface).
- **Output axis (#1612, 2026-06-20 live A/B):** what the backend RETURNS per mode.
  Modes 5/6/8/9 (critique / debate / quiz / flashcards) are format-distinctive in
  the returned text; modes 1/2/3/10 return content-direction prompts
  (persona / format / topic) that read ~like the mode-4 default.

Reconciliation: for deep-dive / brief / explainer / short, NotebookLM steers the
format via **content direction**, not format jargon — so those surfaces' suggestion
*text* is general by design, even though the *surface* (which mode the format's
dialog sends) is distinct and verified. The tool's `surface` labels therefore name
the **surface** (the format whose dialog sends the mode), not a promise about the
returned tone. Modes 5/6/8/9 also differ in output; 1/2/3/10 are the "same shape,
different surface" cases.

## Not exposed / not supported
- Mode **7**: no UI surface sends it; unmapped.
- **data-table / infographic / mind map / slide deck**: their Customize dialogs
  exist but fire NO `otmP3b` (no suggestion surface). Modes 8/9 (quiz/flashcards)
  are backend-reachable via this RPC but the web UI doesn't wire their dialogs to
  it — still valid to expose since the RPC serves them.
- **Report** suggestions: a *separate* RPC (`GET_SUGGESTED_REPORTS` / `ciyUvf`),
  not `otmP3b`.

## Method (reproducible)
Headless Playwright loaded the authenticated app via the repo's `storage_state`
auth (`browser.new_context(storage_state=…)`), navigated to a notebook, and clicked
each artifact's `button[aria-label="Customize {Type}"]` chevron (NOT the card body —
that generates). For Audio, each format card inside the dialog was clicked while
capturing the `otmP3b` request post-data (`f.req` → trailing mode int). Video modes
came from real browser network captures (`otmP3b` requests). Chat/quiz/flashcards
were client live-probes of `client.notebooks.suggest_prompts(mode=…)`.

---
name: html-to-markdown
description: |
  Convert a public, static HTML page to Markdown when the user needs the page
  content but does not need source citations and full-document conversion is
  acceptable. Do not use for research that needs citations, PDFs, authenticated
  or interactive pages, browser actions, or private-network URLs.
allowed-tools: Bash(*bun run scripts/index.ts*)
---

# HTML to Markdown

Use the web tool for sourced research.
Use `agent-browser` for JavaScript, authentication, and interaction.
Use this converter only for a public HTML document.

The script converts the complete HTML response.
It does not identify the article body or remove navigation automatically.

## Run

Run from this skill directory:

```sh
bun run scripts/index.ts https://example.com/article
```

The script writes the final source origin and the Markdown to stdout.
It omits the path, credentials, query parameters, and fragment.
It rejects:

- non-HTTP(S) URLs and URLs with embedded credentials
- loopback, private, link-local, reserved, and non-public DNS results
- redirects to those addresses
- non-HTML responses
- failed HTTP responses
- bodies larger than 2 MB by default
- more than five redirects
- operations whose DNS, redirect, HTTP, or body work exceeds the 15-second
  deadline.

Use `--max-bytes` to lower or raise the response limit for a known public page:

```sh
bun run scripts/index.ts --max-bytes 500000 https://example.com/article
```

`--allow-private` disables the network-address guard.
Use it only when the user explicitly asks to read a trusted intranet or local
page and policy permits that access:

```sh
bun run scripts/index.ts --allow-private http://127.0.0.1:8080/docs
```

The address check is a preflight guard, not a network sandbox.
Do not fetch an attacker-controlled URL from an environment that can reach
sensitive internal services.

Do not save the output unless the user asks for a file.
When saving it, use the requested path and preserve the source line.

## Failures

Report the exact `html-to-markdown:` error.
Do not fall back to browser automation for a blocked private address,
authentication failure, or permission denial.

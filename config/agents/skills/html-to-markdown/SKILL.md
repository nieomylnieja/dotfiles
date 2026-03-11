---
name: html-to-markdown
description: Extract clean markdown content from web pages, removing clutter and navigation to save tokens. Use instead of WebFetch when the user provides a URL to read or analyze, for online documentation, articles, blog posts, or any standard web page.
allowed-tools: Bash(*bun run scripts/index.ts*)
---

# HTML to Markdown

Convert web pages to clean markdown.
Uses `html-to-markdown-node` library to fetch URLs and convert HTML to markdown,
removing clutter and reducing token usage compared to raw HTML.

## Usage

Run the conversion script with a URL:

```bash
cd scripts
bun run index.ts <url>
```

Example:

```bash
bun run index.ts https://example.com
```

The script outputs markdown to stdout. Redirect to save to a file:

```bash
bun run index.ts https://example.com > content.md
```

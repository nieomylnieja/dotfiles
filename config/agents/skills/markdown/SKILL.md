---
name: markdown
description: |
  Use this skill when writing or formatting Markdown files.
  For instance, when writing or modyfing a SKILL.md file, or documenting README.md.
allowed-tools: Bash(markdownlint *) Bash(markdownfmt *) Bash(markdown-link-check *)
---

# Markdown

Guidelines for writing well-formatted markdown documents
with emphasis on semantic line breaks.

## Linting

If `markdownlint` is already configured in the project, use the project's
Makefile/justfile targets or run the linter with project's config.

Otherwise, use `markdownlint --config=~/.dotfiles/.markdownlint.yaml '<filepath>'`
to lint the files.
You can automatically do some formatting with `markdownfmt` command too.

## Links vs Code Fences

When referencing a named external resource (library, package, tool, URL),
prefer a **markdown link** over a bare code fence:

```md
<!-- WRONG — just a code fence, not navigable: -->
`github.com/go-chi/chi`

<!-- RIGHT — linked and formatted: -->
[github.com/go-chi/chi](https://github.com/go-chi/chi)
```

Use a bare code fence only for:

- Standard library packages with no meaningful canonical URL
  (e.g., `` `log/slog` ``, `` `encoding/json` ``)
- Inline code that is not a reference to an external resource

## Document Structure

### Heading Hierarchy

Use a single `#` heading per document for the title.
Structure sections with `##` through `####`;
avoid going deeper than four levels —
a fifth level usually signals the content should be split or restructured.

Headings must follow a strict hierarchy:
never skip levels (e.g., `##` followed by `####`).

### Paragraphs and Spacing

Keep paragraphs focused on a single idea.
Separate paragraphs with a blank line.
Separate sections (headings) with a single blank line before and after.

## Writing Style

- Use concise, direct language and active voice.
- Maintain a consistent tone throughout the document.
- Provide specific guidance with concrete examples,
  clear steps, and expected results.
- Avoid vague statements, excessive passive voice,
  and assuming specific reader knowledge without context.

## Code Blocks

### Language Tags

Always specify the language identifier on fenced code blocks
for correct syntax highlighting:

````md
```go
fmt.Println("hello")
```
````

### Context and Expected Output

Introduce code blocks with a sentence explaining their purpose.
When helpful, show the expected output in a separate block:

````md
Run the health check:

```sh
curl -s http://localhost:8080/health
```

Expected output:

```json
{"status": "ok"}
```
````

### Command-Line Examples

For multi-step shell procedures,
group related commands in a single block with comments,
and split unrelated steps into separate blocks.

## Tables

- Include a header row and alignment indicators.
- Keep cell content concise;
  move lengthy details into footnotes or a follow-up paragraph.
- Align columns for source readability when practical.

```md
| Method | Endpoint         | Description     | Auth |
| :----- | :--------------- | :-------------- | :--: |
| GET    | `/api/users`     | List users      |  Yes |
| POST   | `/api/users`     | Create user     |  Yes |
| DELETE | `/api/users/{id}` | Delete user     |  Yes |
```

## Images

Always provide meaningful alt text that describes the content of the image,
not just its filename:

```md
<!-- WRONG -->
![](diagram.png)
![image](diagram.png)

<!-- RIGHT -->
![Data flow between API gateway and backend services](diagram.png)
```

## Link and Reference Management

### Descriptive Link Text

Use descriptive link text that makes sense out of context.
Avoid generic labels like "click here" or "see this":

```md
<!-- WRONG -->
Click [here](./install.md) for installation.

<!-- RIGHT -->
See the [installation guide](./install.md) for setup instructions.
```

### Reference-Style Links

For documents with many links,
use reference-style links to keep the source readable:

```md
We support [API keys][api-keys], [OAuth 2.0][oauth], and [JWT][jwt].

[api-keys]: ./auth.md#api-keys
[oauth]: ./auth.md#oauth-20
[jwt]: ./auth.md#jwt
```

## Semantic Line Breaks

When writing text with a compatible markup language,
add a line break after each substantial unit of thought.

### Introduction

*Semantic Line Breaks* describe a set of conventions
for using insensitive vertical whitespace
to structure prose along semantic boundaries.

Many lightweight markup languages,
including [Markdown](https://daringfireball.net/projects/markdown/),
[reStructuredText](http://docutils.sourceforge.net/rst.html),
and [AsciiDoc](http://asciidoc.org), join consecutive lines with a space.
Conventional markup languages like HTML and XML
exhibit a similar behavior in particular contexts.
This behavior allows line breaks to be used as semantic delimiters,
making prose easier to author, edit, and read in source —
without affecting the rendered output.

To understand the benefit of semantic line breaks,
consider the following paragraph from the
[*Universal Declaration of Human Rights*](http://www.un.org/en/universal-declaration-human-rights/):

<!-- markdownlint-disable MD013 -->
> All human beings are born free and equal in dignity and rights. They are endowed with reason and> conscience and should act towards one another in a spirit of brotherhood.
<!-- markdownlint-enable MD013 -->

Without any line breaks at all,
this paragraph appears in source as a long, continuous line of text
(which may be automatically wrapped at a fixed column length,
depending on your editor settings):

<!-- markdownlint-disable MD013 -->
```md
All human beings are born free and equal in dignity and rights. They are endowed with reason and conscience and should act towards one another in a spirit of brotherhood.
```
<!-- markdownlint-enable MD013 -->

Adding a line break after each sentence
makes it easier to understand the shape and structure of the source text:

```md
All human beings are born free and equal in dignity and rights.
They are endowed with reason and conscience and should act towards one another in a spirit of brotherhood.
```

We can further clarify the source text by adding a line break
after the clause "with reason and conscience".
This helps to distinguish between
the "and" used as a coordinating conjunction between "reason and conscience" and
the "and" used as a subordinating conjunction with the clause
"and should act towards one another in a spirit of brotherhood":

```md
All human beings are born free and equal in dignity and rights.
They are endowed with reason and conscience
and should act towards one another in a spirit of brotherhood.
```

Despite these changes made to the source,
the final rendered output remains the same:

<!-- markdownlint-disable-next-line MD013 -->
> All human beings are born free and equal in dignity and rights. They are endowed with reason and conscience and should act towards one another in a spirit of brotherhood.

By inserting line breaks at semantic boundaries,
writers, editors, and other collaborators
can make source text easier to work with,
without affecting how it's seen by readers.

### Semantic Line Breaks Specification (SemBr)

The key words "==MUST==", "==MUST NOT==", "==REQUIRED==",
"==SHALL==", "==SHALL NOT==", "==SHOULD==", "==SHOULD NOT==",
"==RECOMMENDED==", "==MAY==", and "==OPTIONAL=="
in this document are to be interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

1. Text written as plain text or a compatible markup language ==MAY==
  use semantic line breaks.
2. A semantic line break ==MUST NOT== alter the final rendered output of the document.
3. A semantic line break ==SHOULD NOT== alter the intended meaning of the text.
4. A semantic line break ==MUST== occur after a sentence,
  as punctuated by a period (.), exclamation mark (!), or question mark (?).
5. A semantic line break ==SHOULD== occur after an independent clause
  as punctuated by a comma (,), semicolon (;), colon (:), or em dash (—).
6. A semantic line break ==MAY== occur after a dependent clause
  in order to clarify grammatical structure or satisfy line length constraints.
7. A semantic line break
  is ==RECOMMENDED== before an enumerated or itemized list.
8. A semantic line break ==MAY== be used after one or more items in a list
  in order to logically group related items or satisfy line length constraints.
9. A semantic line break ==MUST NOT== occur within a hyphenated word.
10. A semantic line break ==MAY== occur before and after a hyperlink.
11. A semantic line break ==MAY== occur before inline markup.
12. A maximum line length of 80 characters is ==RECOMMENDED==.
13. A line ==MAY== exceed the maximum line length if necessary,
 such as to accommodate hyperlinks, code elements, or other markup.

### Why Use Semantic Line Breaks?

For a **writer**,
semantic line breaks allow the physical structure of text
to reflect the logical structure of the thoughts that produce them.

For an **editor**,
semantic line breaks make it easier to identify grammatical mistakes
and find opportunities to simplify and clarify without altering original intent.

For a **reader**,
semantic line breaks are entirely invisible —
no changes to the source text appear in the final rendered output.

### FAQ

#### Which light markup languages support semantic line breaks?

The following light markup languages
are verified to support semantic line breaks:

- [AsciiDoc](http://asciidoc.org)
- [CommonMark](http://commonmark.org)
- [Haddock](https://www.haskell.org/haddock/doc/html/)
- [LaTeX](https://www.latex-project.org/)
- [Markdown](https://daringfireball.net/projects/markdown/)
- [MediaWiki](https://www.mediawiki.org/wiki/Help:Formatting)
- [MultiMarkdown](http://fletcherpenney.net/multimarkdown/)
- [OrgMode](http://orgmode.org)
- [reStructuredText](http://docutils.sourceforge.net/rst.html)

#### How do I know when to add semantic line breaks?

Try reading the text out loud,
as if you were speaking to an audience.
Anywhere that you pause for emphasis
or to take a breath
is usually a good candidate for a semantic line break.

#### How do I migrate existing prose to use semantic line breaks?

There is no need to rewrite or reformat an entire document all at once.
The recommended migration path for an existing document
is to use semantic line breaks for any new or revised text.
This is often a great opportunity to make an editorial pass over content
since the distinctive appearance of text with semantic line breaks
allows you to quickly identify content that has not been updated.

#### How do I use semantic line breaks with Git?

The default Git diff options emphasize line changes
in a way that may obscure certain revisions to text with semantic line breaks.
For better results use:

```sh
git diff --word-diff
```

#### How do I force a line break?

You can add a hard line break with the `<br/>` element.
Although CommonMark and other lightweight markup languages
allow trailing spaces to indicate breaks between consecutive lines,
this syntax is incompatible with
editors that automatically strip trailing whitespace.

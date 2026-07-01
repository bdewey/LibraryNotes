# Book Note Markdown

Book Note Markdown is a proposed interchange format for personal notes about books. A book note is a UTF-8 Markdown document with YAML frontmatter that identifies the book, authorship, publication date, personal rating, and reading history in a form that humans can read and apps or agents can parse.

The goal is portability. A conforming file should remain useful in any Markdown editor while giving reading, cataloging, spaced-repetition, and agentic tools enough structured metadata to recognize the book and preserve a reader's notes.

## Document Shape

A book note is a single Markdown file:

```markdown
---
title: Example Book
authors:
- Ada Lovelace
- Grace Hopper
year-published: 1843
rating: 5
reading-history:
- 2024-06-18
- 2025
---

![Book cover](example-book/cover.jpg)

Notes, quotes, questions, tags, and reflections go here.
```

The frontmatter block begins and ends with `---`. The body after the frontmatter is ordinary Markdown and should be preserved by tools unless the user asks to edit note content.

## Required Behavior

Writers should create valid YAML frontmatter and UTF-8 Markdown. Readers should ignore unknown frontmatter keys so the format can evolve.

Writers should omit unknown or unavailable values instead of writing empty placeholder values. Readers should not treat a missing field as a negative assertion. For example, a missing `rating` means the file does not declare a rating, not that the rating is zero.

## Frontmatter Schema

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `title` | string | Yes | The book title. |
| `authors` | list of strings | Yes | The book authors or contributors, in display order. If no author is known, write an empty list. |
| `year-published` | integer | No | The best-known publication year. Prefer the original publication year when known; otherwise use the edition publication year. |
| `rating` | integer | No | The reader's personal rating as a number. Implementations may choose their own scale, but should document it when exporting. |
| `reading-history` | list of dates | No | Completed reading sessions, one value per completed read or reread. |

Additional metadata may be added with new keys. Prefer plain, lowercase, hyphenated keys for cross-app readability.

## Dates

`reading-history` values represent finish dates. They may have reduced precision:

| Precision | Form | Example |
| --- | --- | --- |
| Year | `YYYY` | `2025` |
| Year and month | `YYYY-MM` | `2025-03` |
| Full date | `YYYY-MM-DD` | `2025-03-09` |

Readers should preserve the precision provided by the file. These values are dates, not timestamps, and do not carry timezone information.

## Body Conventions

The Markdown body is intentionally open-ended. Common body content includes notes, quotes, summaries, review questions, tags, and links to images.

Tools may support richer conventions in the body, but should keep them readable as Markdown. Known useful conventions include:

- Hashtags such as `#philosophy` or `#books/history`
- Question-and-answer prompts using consecutive `Q:` and `A:` lines
- Cloze deletions using `?[hint](phrase to remove)`

Apps that do not understand a body convention should leave it intact.

## Assets

Images and other assets may be referenced with ordinary Markdown links. Relative links are preferred because they keep a note portable when moved with its asset directory:

```markdown
![Book cover](example-book/cover.jpg)
```

A simple file export can place assets in a sibling directory named after the Markdown file. Other package formats may choose a different layout as long as Markdown references remain resolvable.

## Importer Guidance

Use a real YAML parser for frontmatter. Preserve unknown keys, body text, and relative asset links when round-tripping.

When matching a book note to an external catalog record, use `title` plus `authors` as the primary identity signal. Treat `year-published` as supporting evidence because it may describe either the original work or a specific edition.

When interpreting `reading-history`, each list item represents a completed read or reread. Consumers may sort by the latest date, but should not assume the list is exhaustive across every app the reader has used.

## TextBundle Compatibility

[TextBundle](https://textbundle.org/spec/) is an existing packaging specification for plain text documents with assets. A TextBundle document is a directory ending in `.textbundle`; its zipped equivalent ends in `.textpack`. The package contains an `info.json` metadata file, a `text.*` document file such as `text.md`, and optional assets under `assets/`.

Book Note Markdown does not currently require TextBundle. The question is whether a future version should define a TextBundle profile for book notes.

### Pros

- TextBundle already solves asset packaging. Cover images and embedded note images could live in `assets/` instead of relying on app-specific sibling folders.
- It has clear container rules for both folder packages (`.textbundle`) and zipped packages (`.textpack`), which helps files move through sync, backup, and sharing systems.
- It separates package metadata in `info.json` from document content in `text.md`, which can be useful for tools that want to inspect package format information before parsing Markdown.
- Existing TextBundle-aware editors and utilities may be able to open, preserve, or convert the package without understanding book-specific metadata.

### Cons

- TextBundle specifies document packaging, not a book-note metadata vocabulary. A book-note standard would still need to define fields such as `authors`, `rating`, and `reading-history`.
- A `.textbundle` directory is less convenient than a single `.md` file in many Markdown-first tools, GitHub previews, static-site generators, and agent workflows.
- Some apps and sync systems treat package directories differently from normal files, and `.textpack` adds a zip step for editing.
- Moving metadata from YAML frontmatter into `info.json` would make the Markdown file less self-describing when copied out of the package.
- Keeping both YAML frontmatter and `info.json` risks duplication unless the spec defines which source is authoritative.

### Recommendation

Keep the core book-note format as Markdown plus YAML frontmatter. That gives the broadest compatibility with existing Markdown tools and makes each note self-describing.

Consider TextBundle as an optional packaging profile for notes with assets:

```text
Example Book.textbundle/
  info.json
  text.md
  assets/
    cover.jpg
```

In that profile, `text.md` should still contain the book-note YAML frontmatter. `info.json` should describe the TextBundle package itself, while book-specific metadata remains in the Markdown frontmatter as the authoritative source.

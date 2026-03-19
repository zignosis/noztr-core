---
title: Docs Style Guide
doc_type: release_guide
status: active
owner: noztr
read_when:
  - contributing_public_docs
  - improving_website_ready_docs
  - reviewing_docs_clarity
canonical: true
---

# Docs Style Guide

This is the public docs-writing guide for `noztr`.

Use it when writing or restructuring:

- `README.md`
- `CONTRIBUTING.md`
- `CHANGELOG.md`
- `docs/`
- `docs/index.md`
- `examples/README.md`

The goal is simple:

- make the library easier for humans to evaluate and use
- make the public docs easier for contributors to extend
- make the docs easier for LLMs to route correctly

## What Public Docs Should Do

Public docs should help readers answer:

- what `noztr` is
- what it is not
- why a surface exists
- what symbol or example to start from
- what tradeoffs or limits apply

They should stand on their own without requiring internal plans, audit reports, or private notes.

## Public Docs Shape

The public docs surface is intentionally structured:

- `README.md`
  - short repo entry point
- `docs/index.md`
  - public docs router
- `docs/getting-started.md`
  - first-use path
- `docs/guides/technical-guides.md`
  - narrative guides for non-obvious jobs
- `docs/reference/api-reference.md`
  - module and symbol reference
- `docs/reference/nip-coverage.md`
  - public implementation coverage
- `docs/*.md`
  - positioning, ownership, performance, compatibility, versioning
- `docs/guides/*.md`
  - contributor style and narrative guides
- `examples/README.md`
  - task-oriented example routing

Not every supported surface needs a long-form guide.

Coverage should come from the whole public docs system:

- guides
- reference
- coverage pages
- examples

## Writing Rules

- explain the purpose of the page early
- prefer short sections with obvious headings
- hard-wrap at 100 columns
- use GitHub-flavored Markdown
- keep wording direct
- explain tradeoffs when they matter
- say why, not only what
- treat extra words as cost

## Routing Rules

- link to the canonical public page instead of repeating it
- point readers to the best example for the job
- point examples back to the most relevant guide or reference page
- keep routers lean and scannable
- do not route public readers into `.private-docs/`

## Style Expectations

- use Standard American English
- use the Oxford comma
- use `_italics_` for light emphasis and `**bold**` for strong emphasis
- prefer `-` for lists
- keep filenames stable and URL-friendly

## Public Docs Quality Bar

Good public docs:

- are technically accurate
- are honest about limitations
- help readers choose the right surface
- expose the real tradeoffs
- reduce guesswork for downstream SDKs and LLMs

Bad public docs:

- assume internal context
- overclaim support or stability
- bury the actual starting point
- repeat the same content across many pages
- mix website-presentation concerns into the canonical technical text

## Example Rule

Examples are part of the public contract surface.

When useful, docs should link to:

- one direct example
- one hostile example for misuse-prone boundaries

If an example demonstrates a specific contract layer, name that layer clearly.

## Review Questions

Before landing a public docs change, ask:

- is this the canonical public place for this content?
- does this help a reader find the right symbol, guide, or example?
- did I explain the tradeoff honestly?
- did I make the page clearer without making the surface noisier?
- would this still make sense if read outside the internal repo context?

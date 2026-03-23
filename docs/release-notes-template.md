---
title: Release Notes Template
doc_type: release_template
status: active
owner: noztr
read_when:
  - cutting_a_public_release
  - writing_release_notes
  - documenting_public_breaking_changes
canonical: true
---

# Release Notes Template

Use this when cutting a public `noztr-core` release.

This template is intentionally short and release-facing. It should summarize the public contract
change, not internal implementation history.

## Template

```md
# noztr-core <version>

Date: <YYYY-MM-DD>
Release type: <rc | additive | corrective | breaking>

## Summary

<2-4 sentence overview of what changed and why it matters>

## Public Highlights

- <new public module, helper, or docs route>
- <important downstream-facing fix>
- <important performance or compatibility note>

## Breaking Changes

- <state "none" if there are none>
- <public symbol/module route changes>
- <typed error contract changes>
- <ownership, buffer, or scratch expectation changes>
- <kernel-vs-higher-layer scope changes>

## Compatibility Notes

- <optional I6 modules if relevant>
- <split surfaces if relevant>
- <backend or Zig floor notes if relevant>

## Docs And Examples

- <new or updated docs pages>
- <new or updated examples / hostile examples>

## Verification

- `zig build lint`
- `zig build test --summary all`
- `zig build`
- `zig build release-check`
- <any public benchmark or stress rerun if relevant>

## Upgrade Guidance

- <what downstream users should recheck>
- <what noztr-sdk or other consumers should update>
```

## Required Points

Every real release note should say explicitly:

- whether the release is additive, corrective, or breaking
- whether typed public error contracts changed
- whether ownership or scratch expectations changed
- whether any kernel-vs-SDK or split-surface boundary changed

Before publication, also check [guides/release-signoff-checklist.md](guides/release-signoff-checklist.md).

## Current First-Release Guidance

For the first intentional public release:

- start with `0.1.0-rc.1` or `0.1.0`
- do not imply a long-established stable compatibility line already existed
- keep the summary honest about the library still being younger than the oldest deployed Nostr
  libraries

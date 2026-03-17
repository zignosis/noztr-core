---
title: LLM Structured Usability Audit Report
doc_type: report
status: active
owner: noztr
phase: phase-h
read_when:
  - reviewing_llm_structured_usability_findings
  - revising_post_audit_synthesis
depends_on:
  - docs/plans/llm-structured-usability-audit.md
  - docs/plans/llm-usability-pass.md
  - docs/research/exhaustive-audit-meta-analysis-report.md
canonical: true
---

# LLM Structured Usability Audit

- date: 2026-03-17
- issue: `no-ad91`
- packet: `docs/plans/llm-structured-usability-audit.md`
- author: Codex

## Purpose

- evaluate `noztr` specifically from an LLM-first integration perspective before remediation begins
- focus on structured docs, structured examples, task discoverability, contract-layer clarity, and
  downstream agent handoff quality
- challenge whether an LLM can move from task intent to correct entry point and expected failure
  contract without trial-and-error

## Scope

Reviewed directly in this pass:
- `AGENTS.md`
- `agent-brief`
- `docs/README.md`
- `handoff.md`
- `docs/plans/build-plan.md`
- `docs/plans/phase-h-remaining-work.md`
- `docs/plans/llm-usability-pass.md`
- `docs/plans/v1-api-contracts.md`
- `docs/plans/noztr-sdk-remediation-brief.md`
- `examples/README.md`
- `examples/examples.zig`
- representative examples and recipes:
  - `examples/strict_core_recipe.zig`
  - `examples/discovery_recipe.zig`
  - `examples/remote_signing_recipe.zig`
  - `examples/wallet_recipe.zig`
  - `examples/nip05_example.zig`
  - `examples/nip47_example.zig`
  - `examples/nip98_example.zig`

Explicit exclusions:
- remediation edits
- full correctness/security/performance re-audit
- SDK-side docs outside the current `noztr` repo

## Standards

- an LLM should be able to answer, for a common task:
  - which file to open first
  - which public function family to use
  - which contract layer it is on
  - which hostile or invalid example shows likely failure behavior
- structured docs should minimize cross-repo or cross-file guesswork
- structured examples should make task intent and exercised public API obvious from headings or
  nearby context
- downstream remediation coordination should be stable enough that another agent can track
  `noztr`-side changes without ad hoc prose

## Evidence Sources

Primary:
- the docs and examples listed in scope
- exported public surface evidence in `src/root.zig`

Secondary:
- the earlier `OQ-E-006` usability pass
- the completed docs/discoverability angle report

## Coverage

Explicitly checked:
- startup routing for an LLM agent
- task-to-example routing in `examples/README.md`
- whether current docs provide a structured current contract map for post-core surfaces
- whether representative recipe/example files expose enough local context to infer the intended
  public functions
- whether the new `nzdk` remediation brief is structured enough for downstream agent coordination

Explicitly not checked:
- external package-manager or website discoverability
- non-`noztr` agent prompts outside the newly added remediation brief

## Findings

### The repo still lacks one current structured contract map for many post-core public surfaces

- severity: `medium`
- scope:
  - [examples/README.md](/workspace/projects/noztr/examples/README.md#L22)
  - [v1-api-contracts.md](/workspace/projects/noztr/docs/plans/v1-api-contracts.md#L1)
  - [root.zig](/workspace/projects/noztr/src/root.zig#L97)
  - [root.zig](/workspace/projects/noztr/src/root.zig#L100)
  - [root.zig](/workspace/projects/noztr/src/root.zig#L145)
  - [root.zig](/workspace/projects/noztr/src/root.zig#L58)
- why it matters:
  - `examples/README.md` gives a task-oriented file map, which is good for initial routing
  - `docs/plans/v1-api-contracts.md` gives structured function contracts, but its declared scope is
    still Phase D core modules and it does not cover many currently important post-core surfaces
    such as `nip05_identity`, `nip46_remote_signing`, `nip47_wallet_connect`, or `nip98_http_auth`
  - for those surfaces an LLM must cross-reference task index, source exports, and example files to
    find the exact public function family
- evidence:
  - `v1-api-contracts.md` explicitly scopes itself to “Phase A H1 v1 modules”
  - current root exports show many later surfaces that are not represented there
- remediation pressure:
  - targeted fix

### Example routing is good at the file level, but still too weak at the public-symbol level for some common jobs

- severity: `medium`
- scope:
  - [examples/README.md](/workspace/projects/noztr/examples/README.md#L22)
  - [discovery_recipe.zig](/workspace/projects/noztr/examples/discovery_recipe.zig#L1)
  - [remote_signing_recipe.zig](/workspace/projects/noztr/examples/remote_signing_recipe.zig#L1)
  - [nip05_example.zig](/workspace/projects/noztr/examples/nip05_example.zig#L1)
  - [nip47_example.zig](/workspace/projects/noztr/examples/nip47_example.zig#L1)
  - [nip98_example.zig](/workspace/projects/noztr/examples/nip98_example.zig#L1)
- why it matters:
  - the recipe and example titles are readable, but the index usually names files, not the exact
    public functions those files are meant to teach
  - an LLM can often infer the right API by opening the file, but not always from the index alone
  - this is most noticeable on jobs where the direct example is thin (`NIP-05`) and the fuller
    workflow lives in a separate recipe (`discovery_recipe.zig`)
- evidence:
  - the SDK job index routes identity lookup through `discovery_recipe.zig` and `nip05_example.zig`
    without naming `address_parse`, `profile_parse_json`, or `profile_verify_json`
  - the representative files themselves show the right functions once opened
- remediation pressure:
  - targeted fix

### The downstream remediation brief is structured, but not yet executable enough for copy-paste agent handoff

- severity: `low`
- scope:
  - [noztr-sdk-remediation-brief.md](/workspace/projects/noztr/docs/plans/noztr-sdk-remediation-brief.md#L1)
- why it matters:
  - the lane table is a good stable start
  - but it does not yet include a per-lane section for:
    - likely public symbols affected
    - exact downstream prompt text
    - landed-change history as the remediation program progresses
  - another agent can work from it, but still has to translate the brief into an operational prompt
- evidence:
  - the current brief ends at a lane table and an update rule
- remediation pressure:
  - targeted fix

## Accepted Strengths

- startup routing is clear and lean
  - `AGENTS.md`, `handoff.md`, `docs/README.md`, and `agent-brief` provide a strong first-hop path
- example organization is much stronger than before
  - `examples/README.md` already separates:
    - start-here recipes
    - SDK job index
    - reference examples
    - adversarial examples
- representative recipe files are locally readable
  - the test names in `strict_core_recipe.zig`, `remote_signing_recipe.zig`, `discovery_recipe.zig`,
    and `wallet_recipe.zig` are clear enough that an LLM can usually infer intent after opening the
    file
- the new `nzdk` remediation brief is a solid base
  - it already has stable lane IDs, scopes, and downstream recheck intent

## Residual Risk

- the repo is no longer confusing at the startup level
- the remaining LLM risk is mostly mid-hop discovery:
  - “I know the job and the file, but what exact function family should I use?”
- that is a docs/examples structure problem, not evidence of kernel redesign pressure by itself

## Suggested Remediation Candidates

- targeted fix
  - add one current structured task-to-surface contract map for post-core public surfaces
- targeted fix
  - strengthen the examples index with exact public function families for the main SDK jobs
- targeted fix
  - extend the `nzdk` remediation brief with per-lane public symbols and copy-paste downstream
    prompt structure

## Completion Statement

This supplement is complete because:
- startup routing, task routing, structured examples, current contract references, and downstream
  brief structure were checked directly
- it distinguishes strengths from remaining LLM friction
- it identifies documentation-structure pressure without inflating it into a kernel rewrite signal

Reopen this supplement if:
- remediation materially changes the public surface or example organization
- a downstream agent still reports repeated trial-and-error on tasks that this report claims are
  discoverable

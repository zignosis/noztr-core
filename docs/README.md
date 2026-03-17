---
title: Docs Index
doc_type: index
status: active
owner: noztr
read_when:
  - routing_repo_docs
  - starting_unfamiliar_work
  - refining_process
canonical: true
---

# Docs Index

This index routes readers to the current control surface without forcing startup reads across the
entire repo.

## Control Surface

These docs control active work and should stay lean.

- `AGENTS.md`
  - agent operating rules, closure discipline, and repo workflow constraints
- `handoff.md`
  - current state only: next work, critical rules, and current repo status
- `docs/plans/decision-index.md`
  - startup route into accepted policy and decision areas
- `docs/plans/build-plan.md`
  - active execution baseline
- `docs/guides/PROCESS_CONTROL.md`
  - repo-specific process refinement rules for keeping the control surface lean
- `docs/plans/phase-h-remaining-work.md`
  - current active Phase H packet and next remaining work
- `docs/plans/post-audit-improvement-plan.md`
  - ordered execution plan for the completed `libnostr-z` and TigerBeetle audit follow-ups
- `docs/plans/exhaustive-pre-freeze-audit.md`
  - live working draft for the exhaustive pre-freeze audit that must precede freeze-readiness
    synthesis
- `docs/plans/docs-surface-audit.md`
  - stable-ID audit of doc bloat, repetition, and control-surface drift

## Read Paths

- Startup:
  - `AGENTS.md`
  - `handoff.md`
  - `docs/README.md`
  - files explicitly named by `./agent-brief`
- Protocol implementation or review:
  - relevant NIP text in `docs/nips/`
  - `docs/plans/decision-index.md`
  - `docs/plans/build-plan.md`
  - `docs/guides/IMPLEMENTATION_QUALITY_GATE.md` when starting or closing a slice
  - `docs/plans/decision-log.md` only when a cited decision ID or policy change requires the
    canonical payload
  - Zig guides on demand
- Process or docs refinement:
  - `docs/guides/PROCESS_CONTROL.md`
  - `docs/guides/IMPLEMENTATION_QUALITY_GATE.md` if the refinement changes staged execution rules
  - `docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md`
  - `docs/plans/packet-template.md` when creating or repairing packets
  - `docs/plans/docs-surface-audit.md`
  - `docs/plans/decision-index.md`
  - `docs/plans/decision-log.md` only when a cited decision ID or policy change requires the
    canonical payload
- Ownership and kernel-vs-SDK questions:
  - `docs/plans/noztr-sdk-ownership-matrix.md`

## Reference Docs

These are active references, not startup defaults.

- `docs/plans/decision-log.md`
- `docs/plans/noztr-sdk-ownership-matrix.md`
- `docs/guides/IMPLEMENTATION_QUALITY_GATE.md`
- `docs/plans/post-audit-improvement-plan.md`
- `docs/plans/exhaustive-pre-freeze-audit.md`
- `docs/plans/implemented-nip-review-guide.md`
- `docs/plans/nostr-principles.md`
- `docs/plans/implemented-nip-audit-report.md`
- `docs/plans/post-kernel-requested-nips-loop.md`
- `docs/plans/phase-h-kickoff.md`
- `docs/plans/phase-h-additional-nips-plan.md`
- `docs/plans/phase-h-wave1-loop.md`
- `docs/plans/llm-usability-pass.md`
- `docs/plans/security-hardening-register.md`
- `docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md`
- `docs/plans/packet-template.md`
- `docs/research/`
- `docs/release/intentional-divergences.md`
- `examples/README.md`

## Packet Docs

These are lane- or phase-specific packets. They should be read only when that lane is active.

- `docs/plans/phase-h-remaining-work.md`
- `docs/plans/exhaustive-pre-freeze-audit.md`
- `docs/plans/prompts/`

## Archive

Historical material lives under `docs/archive/`. Archive docs are valid provenance sources, but
they should not stay in the startup path or current control surface.

## Routing Rule

Do not treat every doc as complete.

- control docs carry current rules and state
- packet docs carry slice-specific deltas
- reference docs carry stable background
- archive docs carry history

If a doc no longer controls current work, move it toward reference or archive instead of keeping it
in the active read path.

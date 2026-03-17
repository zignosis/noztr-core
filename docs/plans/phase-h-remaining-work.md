---
title: Phase H Boundary Validation Packet
doc_type: packet
status: active
owner: noztr
phase: phase-h
read_when:
  - tracing_current_phase_h_work
  - executing_phase_h_boundary_validation
depends_on:
  - docs/plans/build-plan.md
  - docs/guides/IMPLEMENTATION_QUALITY_GATE.md
  - docs/plans/llm-usability-pass.md
  - docs/plans/post-exhaustive-audit-remediation-plan.md
  - docs/plans/empirical-benchmark-supplement.md
sync_touchpoints:
  - handoff.md
  - docs/README.md
  - agent-brief
canonical: true
---

# Phase H Boundary Validation Packet

Current active Phase H packet after completion of the requested-NIP loop, earlier Phase H waves, and
the `OQ-E-006` usability pass.

## Purpose

- validate the current Layer 1 kernel boundary with SDK-informed pressure before any RC API-freeze
  claim
- make the repo execute one explicit next step instead of holding Phase H in packet-selection limbo
- keep RC API-freeze deferred until SDK-informed boundary evidence is in

## Scope Delta

- current active remaining work is SDK-informed boundary validation on the current strict kernel
  surface
- active slice scope:
  - test whether current Layer 1 defaults and public teaching surface remain the right boundary once
    SDK-facing pressure is considered
  - identify any remaining blockers that require either:
    - a bounded docs/code correction inside the kernel
    - an explicit Layer 2 adapter-boundary packet
- out of scope:
  - claiming RC API-freeze by default before the validation slice runs
  - broad SDK design or post-RC redesign
  - reopening completed Phase H waves without new evidence
- completed Phase H packets remain traceability references only:
  - `docs/plans/phase-h-kickoff.md`
  - `docs/plans/phase-h-additional-nips-plan.md`
  - `docs/plans/phase-h-wave1-loop.md`
  - `docs/plans/post-kernel-requested-nips-loop.md`

## Current Status

- Phase H remains active
- the requested-NIP loop is complete through `NIP-B7`
- `OQ-E-006` is closed
- the next active Phase H slice is the empirical benchmark supplement
- RC API-freeze remains deferred until this slice shows the current boundary is stable enough
- accepted sub-findings from this slice so far:
  - export public signed event-object JSON serialization from `nip01_event`
  - keep deterministic one-recipient outbound `NIP-59` transcript construction in `noztr`
    while leaving recipient fanout and mailbox workflow in `nzdk`
  - close a second implemented-surface audit batch with typed invalid-input fixes across
    `NIP-05`, `NIP-17`, `NIP-37`, `NIP-46`, `NIP-47`, `NIP-94`, and `NIP-99`
  - backfill hostile examples on `NIP-03`, `NIP-17`, `NIP-37`, `NIP-42`, and `NIP-59`
  - close the report-only `libnostr-z` comparison lane with no immediate kernel correction required;
    keep `libnostr-z` as behavior evidence, not as a runtime or memory-model authority
  - close `no-ow4` with structural refactors across `NIP-22`, `NIP-46`, and `NIP-47`, plus
    local public assertion-density fixes on `NIP-49`, with no protocol contract change
  - close `no-3jb` by isolating `NIP-06` backend state and explicitly accepting the current
    caller-owned scratch posture in `NIP-05`, `NIP-46`, and `NIP-77`, plus the reviewed
    `bool` / `?` helper boundaries, as bounded exceptions
  - complete the exhaustive pre-freeze audit and meta-analysis
  - choose a bounded-redesign-first remediation posture instead of a major rewrite
  - defer the prepared remediation packet until one empirical benchmark supplement and revised
    synthesis complete

## Next Step

1. execute `docs/plans/empirical-benchmark-supplement.md`
2. only after that reactivate or revise
   `docs/plans/post-exhaustive-audit-remediation-plan.md`
3. keep RC API-freeze deferred until the remediation program and one freeze recheck complete
4. if remediation surfaces a real compatibility or ergonomics blocker that does not belong in
   Layer 1, create one explicit Layer 2 adapter-boundary packet instead of widening the kernel by
   default
5. after remediation and recheck close, decide whether the next packet is:
  - RC API-freeze, or
  - one explicit remaining blocker packet

## Seam Constraints

- do not treat the last completed loop as the active packet for the phase
- do not reopen completed Phase H packets just to store new pending work
- use `docs/plans/implemented-nip-review-guide.md` only for implemented-NIP audit or robustness work
- use `docs/guides/IMPLEMENTATION_QUALITY_GATE.md` for any new general implementation or review slice
- do not begin adapter-boundary implementation just because the adapter lane exists
- do not claim RC freeze from this packet alone; the point is to gather the boundary evidence first

## Open Questions Or Targeted Findings

- `OQ-BV-001`
  - does SDK-informed validation show any strict Layer 1 default that still needs an accepted
    divergence, correction, or explicit defer-to-adapter call before freeze?
- `OQ-BV-002`
  - are current examples, routing, and docs sufficient for boundary validation without reopening
    `OQ-E-006`-class teaching drift?
- `OQ-BV-003`
  - does a report-only comparison against `libnostr-z` surface any Zig, cryptography, memory,
    security, or protocol-shape concerns that should change the kernel before freeze?
  - current result:
    - comparison report completed with no immediate kernel change required
- `OQ-BV-004`
  - does a report-only Zig-quality comparison against TigerBeetle surface any implementation,
    memory, assertion, control-flow, or safety-discipline concerns that should change `noztr`
    before freeze?
  - current result:
    - comparison report completed
    - active follow-up execution is sequenced in `docs/plans/post-audit-improvement-plan.md`
    - concrete lanes:
      - `no-ow4` structural Tiger-style hotspots, complete
      - `no-3jb` explicit-state and fixed-capacity Tiger follow-ups, complete
- `OQ-BV-005`
  - can Phase H make an honest freeze-readiness claim without one explicit exhaustive audit draft
    covering protocol surfaces, public contracts, performance posture, cryptographic correctness,
    crypto/backend wrappers, and docs/examples completeness?
  - current result:
    - no
    - the exhaustive audit and `no-mja` meta-analysis are complete
    - current selected posture:
      - bounded redesign first
      - then targeted fixes
      - then a freeze recheck
    - supplemental LLM structured usability audit is complete
    - current benchmark supplement packet:
      - `docs/plans/empirical-benchmark-supplement.md`
    - prepared remediation packet remains deferred pending the supplement:
      - `docs/plans/post-exhaustive-audit-remediation-plan.md`

## Tradeoff

- choose boundary validation now rather than claiming RC-freeze readiness immediately
  - benefit:
    - lets SDK-facing evidence inform the kernel boundary before release-facing claims harden
  - cost:
    - RC-freeze work happens one step later, after the validation slice
    - extra report-only quality lanes may extend Phase H while evidence is still being gathered

## Sync Touchpoints

- teaching surface:
  - `examples/README.md`
  - any example files touched by the boundary-validation slice
- audit state:
  - `docs/plans/llm-usability-pass.md`
  - `docs/plans/security-hardening-register.md`
  - `docs/research/exhaustive-audit-meta-analysis-report.md`
  - `docs/plans/noztr-sdk-remediation-brief.md`
  - `docs/plans/empirical-benchmark-supplement.md`
- startup and discovery docs:
  - `handoff.md`
  - `docs/README.md`
  - `agent-brief`
- active baseline and policy if the freeze changes accepted behavior:
  - `docs/plans/build-plan.md`
  - `docs/plans/decision-index.md`
  - `docs/plans/decision-log.md`

## Closeout Conditions

- `OQ-E-006` remains closed in docs and state routing
- startup routing points to the current boundary-validation packet, not a completed lane
- the boundary-validation result is explicit:
  - a benchmark supplement or remediation packet is active, or
  - RC-freeze packet becomes justified after remediation and recheck
- superseded Phase H packets are marked `reference` or moved to archive

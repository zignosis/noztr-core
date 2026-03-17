---
title: External Crypto Backend Assurance Supplement
doc_type: packet
status: reference
owner: noztr
phase: phase-h
read_when:
  - tracing_current_phase_h_work
  - reviewing_external_backend_assurance
depends_on:
  - docs/plans/build-plan.md
  - docs/guides/IMPLEMENTATION_QUALITY_GATE.md
  - docs/research/exhaustive-audit-meta-analysis-report.md
  - docs/plans/post-exhaustive-audit-remediation-plan.md
target_findings:
  - no-1t7m
  - no-ik85
sync_touchpoints:
  - handoff.md
  - docs/README.md
  - agent-brief
  - docs/plans/noztr-sdk-remediation-brief.md
canonical: true
---

# External Crypto Backend Assurance Supplement

Completed supplemental Phase H packet that ran after the empirical benchmark supplement and before
remediation execution continues.

## Purpose

- add one external-assurance pass for the approved crypto backends before remediation begins
- challenge the local crypto/backend-wrapper audit with upstream provenance, release-floor, and
  build-floor evidence
- revise the post-audit synthesis only after the external assurance evidence is explicit

## Scope Delta

- in scope:
  - external provenance and release-floor evidence for the pinned `bitcoin-core/secp256k1` and
    `ElementsProject/libwally-core` dependencies
  - local build-floor assumptions against upstream documented module/configure expectations
  - whether current pinned dependencies plus local wrapper/build seams are externally defensible
    enough for pre-freeze confidence
  - whether the evidence changes rewrite or remediation pressure
- out of scope:
  - landing code fixes
  - re-running local cryptographic-correctness or wrapper-shape review as if it were a new angle
  - changing dependency policy by default
  - broad packaging or release-engineering work beyond what is needed for honest assurance judgment

## Current Status

- the nine-angle exhaustive audit is complete
- the LLM structured-usability supplement is complete
- the empirical benchmark supplement is complete
- this supplement and the revised synthesis are complete:
  - `no-1t7m`
  - `no-ik85`
- the current remediation packet is active again:
  - `docs/plans/post-exhaustive-audit-remediation-plan.md`

## Next Step

1. keep the external assurance report as reference evidence
2. execute the reactivated remediation packet in
   `docs/plans/post-exhaustive-audit-remediation-plan.md`

## Open Questions Or Targeted Findings

- `AQ-EXT-001`
  - do the current `secp256k1` and `libwally` pins still have strong enough external provenance and
    release-floor evidence for pre-freeze confidence?
- `AQ-EXT-002`
  - do the local backend build-floor assumptions remain explicit enough relative to upstream
    documented module/configure expectations?
- `AQ-EXT-003`
  - does any external-assurance finding change the current bounded-redesign-first remediation call?

## Sync Touchpoints

- startup and discovery docs:
  - `handoff.md`
  - `docs/README.md`
  - `agent-brief`
- active baseline and state:
  - `docs/plans/build-plan.md`
  - `docs/plans/phase-h-remaining-work.md`
  - `docs/plans/post-exhaustive-audit-remediation-plan.md`
- downstream coordination:
  - `docs/plans/noztr-sdk-remediation-brief.md`
- synthesis evidence:
  - `docs/research/exhaustive-audit-meta-analysis-report.md`

## Closeout Conditions

- `no-1t7m` produced a dedicated external assurance report with explicit scope, evidence, findings,
  limits, and residual risk
- `no-ik85` revised the meta-analysis and active routing honestly
- remediation is active again under the revised synthesis

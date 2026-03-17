---
title: Exhaustive Audit Meta Analysis Report
doc_type: report
status: active
owner: noztr
phase: phase-h
read_when:
  - deciding_post_audit_remediation
  - evaluating_freeze_readiness
depends_on:
  - docs/plans/exhaustive-pre-freeze-audit.md
  - docs/plans/exhaustive-pre-freeze-audit-matrix.md
  - docs/plans/audit-meta-analysis-template.md
canonical: true
---

# Exhaustive Audit Meta-Analysis

- date: 2026-03-17
- issue: `no-mja`
- packet: `no-ard`
- author: Codex
- current-note:
  - revised after the empirical benchmark supplement and the external crypto/backend assurance
    supplement

## Inputs

- completed angle reports:
  - `docs/research/exhaustive-audit-angle-1-protocol-correctness-report.md`
  - `docs/research/exhaustive-audit-angle-2-parity-interoperability-report.md`
  - `docs/research/exhaustive-audit-angle-3-security-misuse-report.md`
  - `docs/research/exhaustive-audit-angle-4-cryptographic-correctness-report.md`
  - `docs/research/exhaustive-audit-angle-5-crypto-backend-wrapper-report.md`
  - `docs/research/exhaustive-audit-angle-6-zig-engineering-report.md`
  - `docs/research/exhaustive-audit-angle-7-performance-memory-report.md`
  - `docs/research/exhaustive-audit-angle-8-api-consistency-report.md`
  - `docs/research/exhaustive-audit-angle-9-docs-discoverability-report.md`
  - `docs/research/llm-structured-usability-audit-report.md`
  - `docs/research/empirical-benchmark-supplement-report.md`
  - `docs/research/external-crypto-backend-assurance-report.md`
- finalized matrix:
  - `docs/plans/exhaustive-pre-freeze-audit-matrix.md`
- working draft ledger:
  - `docs/plans/exhaustive-pre-freeze-audit.md`

## Cross-Angle Patterns

- repeated public-path assertion leakage remains the clearest recurring defect class
  - it appeared first as a security/misuse issue and remained a live API-consistency issue
  - the problem is not the whole public facade; it is older helper families that still let caller
    input reach internal invariants before typed rejection
- backend-boundary sharpness is the main recurring design-pressure cluster
  - angle 4 did not find local crypto-framing failure
  - angle 5 did find backend-outage misclassification and a fragmented `libwally` seam
  - that creates real redesign pressure, but it is concentrated in one boundary family rather than
    spread through the library
- performance issues are real but locally bounded
  - the reports found reducer/scanner inefficiencies in `NIP-88`, `NIP-29`, and `NIP-06`
  - they do not currently point to systemic memory or runtime collapse
- empirical benchmark evidence sharpened the performance picture
  - `NIP-29` is the strongest measured local hotspot
  - `NIP-88` is a real measured hotspot but still bounded
  - `NIP-06` repeated scans are not the dominant derivation cost once backend work is included
- external backend assurance sharpened the crypto-boundary picture
  - `secp256k1` remains externally well supported for the current narrow wrapper posture
  - `libwally` remains an acceptable backend choice for the current narrow boundary
  - the main remaining external-assurance weakness is provenance/control drift around the recorded
    `libwally` pin and local feature-floor assumptions, not primitive failure or rewrite pressure
- docs/examples drift is real but not a control-surface failure
  - internal control docs stayed coherent
  - public discovery and teaching surfaces lagged on a few important examples and the root README
- LLM-first discoverability is stronger than before, but still too dependent on cross-referencing
  examples, source exports, and legacy contract docs for post-core surfaces
  - this adds documentation-structure pressure
  - it does not change the kernel-side rewrite call

## Rewrite Pressure Assessment

- `medium`
  - the audit does not support a major rewrite
  - it does support one bounded redesign area around the `libwally` seam and backend-outage
    contract sharpness, plus a set of targeted fixes on public helper families and structured
    teaching/discovery surfaces

## Remediation Posture Decision

- starting posture: `bounded redesign`

## Rationale

- why `bounded redesign` is the best match:
  - the audit found one real surface family that wants redesign rather than patching:
    - the fragmented `libwally` readiness and derivation boundary across `NIP-06` and `BIP-85`
  - starting with targeted fixes alone would understate that pressure and invite piecemeal cleanup
    without clarifying the backend seam
  - the rest of the findings fit around that redesign as targeted hardening and cleanup work
- why not `major rewrite`:
  - protocol correctness remained clean
  - parity did not surface incompatible architecture
  - cryptographic correctness stayed sound on locally owned framing
  - Zig-quality findings do not show systemic engineering collapse
  - performance issues are bounded and local
- why not pure `targeted fixes`:
  - one recurring weakness is not just a bug list; it is an over-fragmented backend boundary that
    should be made sharper before freeze confidence

## Freeze Readiness

- the repo should not proceed to RC-freeze yet
- explicit blockers from the completed audit:
  - high:
    - `NIP-86` public-path assertion leaks on overlong caller input
  - medium:
    - `NIP-46` direct helper assertion leaks
    - backend-outage misclassification in `NIP-44` and `NIP-26`
    - fragmented `libwally` readiness/derivation seam across `NIP-06` and `BIP-85`
    - canonical provenance and build-floor drift around the current `libwally` pin
    - examples/discovery drift on `NIP-59`, `NIP-05`, and the root README
    - lack of one current structured post-core contract map and too-weak public-symbol routing for
      common LLM-facing jobs
- non-blocking but still worth remediation:
  - `NIP-88` reducer hotspot
  - `NIP-29` reducer hotspot
  - `NIP-25` misuse-prone direct classifier helper
  - test-oriented verify counters in the production secp wrapper

## Accepted Exceptions That Still Hold

- current caller-owned scratch posture in `NIP-05`, `NIP-46`, and `NIP-77`
- `nip05_identity.profile_verify_json(...) -> bool`
- `NIP-59` deterministic one-recipient outbound helper split
- scratch-backed shared JSON ingress in `NIP-01`
- `NIP-27` scratch-to-capacity tradeoff absent contrary workload evidence
- commit-plus-hash pinning for approved backend exceptions

## Accepted Exceptions Under Pressure

- the isolated `NIP-06` once-only backend-state cell still holds as a local exception
- it no longer closes the broader backend-boundary question by itself because `BIP-85` still
  reaches readiness through an indirect `mnemonic_validate(...)` path

## Next Lanes

- bounded redesign
  - consolidate `libwally` readiness and derivation entry points behind one sharper backend seam
    and repair backend-outage error mapping in dependent crypto consumers
  - reconcile the canonical recorded `libwally` pin with the live build pin and record the
    approved backend feature floor explicitly
- targeted fix
  - harden the remaining public helper assertion leaks and direct-helper misuse surfaces:
    `NIP-86`, `NIP-46`, and `NIP-25`
- targeted fix
  - repair docs/examples/discovery drift:
    `NIP-59` example routing, `NIP-05` hostile example coverage, root `README.md`,
    structured post-core contract mapping, examples index symbol routing, and `nzdk`
    remediation-brief enrichment
- targeted fix
  - clean up the bounded local performance hotspots in `NIP-88` and `NIP-29`
  - keep `NIP-06` performance concerns coupled to the backend redesign lane rather than as a
    standalone required performance cleanup
- audit/freeze follow-up
  - run one post-remediation freeze-readiness recheck before any RC-freeze packet

## Decision

- no major rewrite is justified from the completed evidence
- the correct next move is a bounded-remediation program led by one backend-boundary redesign lane,
  followed by targeted hardening/cleanup lanes and then a fresh freeze-readiness check

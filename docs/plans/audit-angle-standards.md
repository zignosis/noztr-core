---
title: Audit Angle Standards
doc_type: reference
status: active
owner: noztr
phase: phase-h
read_when:
  - freezing_audit_angle_scope
  - starting_a_dedicated_audit_angle
depends_on:
  - docs/plans/exhaustive-pre-freeze-audit.md
  - docs/plans/audit-angle-report-template.md
canonical: true
---

# Audit Angle Standards

Minimum standards for each dedicated `no-ard` audit angle. These are the minimum bar for calling
an angle complete.

## Global Rules

- every angle must produce a dedicated report
- every angle must update the matrix rows it actually reviewed
- every angle must say what it did not check
- no fixes land during the audit program; findings become report entries, accepted exceptions,
  deferred remediation candidates, or blockers for later meta-analysis

## 1. Protocol Correctness

Must check:
- implemented NIP behavior against the accepted contract
- parser/builder symmetry where applicable
- canonicalization and normalization behavior
- explicit unsupported and non-goal boundaries

Completion bar:
- every implemented NIP surface has an explicit correctness status
- residual ambiguity is named, not implied

## 2. Ecosystem Parity / Interoperability

Must check:
- active production parity lane: `rust-nostr`
- ecosystem compatibility lanes where relevant: `nostr-tools`, applesauce, or spec-first fallback
- whether `noztr` divergences are intentional, bounded, and still justified

Completion bar:
- every implemented NIP surface has an explicit interoperability status
- evidence classes are named per surface: strong, secondary, weak, or unavailable

## 3. Security / Misuse Resistance

Must check:
- misuse-prone public entry points
- trust-boundary wrappers
- invalid-vs-capacity behavior
- assertion leaks
- hostile input posture
- secret exposure risks outside deep crypto correctness

Completion bar:
- every exported trust-boundary family has an explicit security posture judgment
- any freeze-blocking defect is severity-ranked

## 4. Cryptographic Correctness / Secret Handling

Must check:
- signature and verification call flows that depend on protocol framing
- transcript correctness for encryption, auth, wrap, and zap-adjacent surfaces
- randomness and nonce expectations plus caller contracts
- secret wiping, lifetime, and key-shape handling
- cryptographic preconditions documented at the public boundary

Completion bar:
- every cryptography-bearing protocol surface has an explicit correctness judgment
- unknowns are named if they depend on backend trust rather than local framing

## 5. Crypto / Backend-Wrapper Quality

Must check:
- `secp256k1` boundary sharpness
- `libwally` boundary sharpness
- error mapping quality
- backend state handling
- source pinning assumptions and dependency boundary discipline

Completion bar:
- wrappers and backend seams have an explicit quality and risk judgment
- any extraction or rewrite pressure is evidence-backed

## 6. Zig Engineering Quality

Must check:
- control-flow clarity
- function size and decomposition
- assertion density and placement
- state isolation
- obvious anti-patterns
- alignment with repo Zig style and Tiger-oriented engineering lessons

Completion bar:
- structural hotspots and systemic Zig anti-patterns are identified clearly
- local style nits are not inflated into rewrite pressure

## 7. Performance / Memory Posture

Must check:
- allocation posture
- scratch usage
- copying behavior on hot paths
- obvious asymptotic or repeated-scan concerns
- caller-owned buffer discipline
- whether current costs are acceptable for a protocol-kernel library

Completion bar:
- the report distinguishes:
  - acceptable bounded cost
  - concerning but local inefficiency
  - systemic performance pressure

## 8. API Consistency / Determinism

Must check:
- public naming coherence
- ownership-shape coherence
- error-contract consistency
- canonical emitted output versus accepted valid input
- split-surface boundary clarity

Completion bar:
- the report can say whether the public surface mainly wants:
  - targeted fixes
  - bounded redesign
  - larger rewrite pressure

## 9. Docs / Examples / Discoverability

Must check:
- examples teach the right contract layer
- hostile examples exist where needed
- discovery docs route correctly
- active audit/state docs tell the truth about current work
- freeze-critical docs are not stale or contradictory

Completion bar:
- the report can say whether the docs surface is adequate for freeze confidence
- any teaching drift or routing drift is named explicitly

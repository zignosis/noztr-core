---
title: Exhaustive Pre-Freeze Audit Matrix
doc_type: reference
status: active
owner: noztr
phase: phase-h
read_when:
  - executing_exhaustive_pre_freeze_audit
  - checking_angle_coverage
depends_on:
  - docs/plans/exhaustive-pre-freeze-audit.md
canonical: true
---

# Exhaustive Pre-Freeze Audit Matrix

Coverage matrix for `no-ard`. This is the hard execution ledger for the exhaustive pre-freeze
audit. Do not mark a cell `complete` unless the corresponding angle report names the exact evidence
that justifies completion.

## Status Keys

- `not started`
- `in progress`
- `complete`
- `not applicable`

## Angle Order

1. Protocol correctness
2. Ecosystem parity / interoperability
3. Security / misuse resistance
4. Crypto/backend-wrapper quality
5. Zig engineering quality
6. Performance / memory posture
7. API consistency / determinism
8. Docs/examples / discoverability

## Surface Matrix

| Surface | Correctness | Parity | Security | Crypto | Zig | Performance | API | Docs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Implemented NIP surfaces (`docs/plans/implemented-nip-audit-report.md`) | not started | not started | not started | not applicable | not started | not started | not started | not started |
| `src/root.zig` exported facade | not started | not applicable | not started | not applicable | not started | not started | not started | not started |
| `src/nip01_event.zig` and event core trust boundary | not started | not started | not started | not applicable | not started | not started | not started | not started |
| `src/crypto/secp256k1_backend.zig` | not applicable | not applicable | not started | not started | not started | not started | not applicable | not applicable |
| `src/nip06_mnemonic.zig` / `src/bip85_derivation.zig` / `libwally` boundary | not started | not applicable | not started | not started | not started | not started | not started | not applicable |
| Public error-contract and invalid-vs-capacity surfaces | not started | not applicable | not started | not applicable | not started | not started | not started | not applicable |
| SDK-facing split surfaces (`17`, `46`, `47`, `59`, `98`, `B7`) | not started | not started | not started | not applicable | not started | not started | not started | not started |
| Examples and discovery surface | not applicable | not applicable | not started | not applicable | not started | not applicable | not started | not started |
| Planning / audit / state docs used for freeze decisions | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | not started | not started |

## Completion Rule

Each angle report must update:
- every row it actually reviewed
- any explicit `not applicable` calls with rationale
- any residual blockers or deferred remediation candidates in
  `docs/plans/exhaustive-pre-freeze-audit.md`

## Integrity Rule

Do not backfill `complete` from memory.

If prior work materially contributes to a cell:
- cite the exact prior report or issue in the angle report
- say whether that prior work was sufficient as-is or only partial evidence

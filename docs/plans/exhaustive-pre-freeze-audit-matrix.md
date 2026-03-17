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

1. Protocol correctness: `no-3ib`
2. Ecosystem parity / interoperability: `no-f2u`
3. Security / misuse resistance: `no-odj`
4. Cryptographic correctness / secret handling: `no-dwu`
5. Crypto/backend-wrapper quality: `no-ys3`
6. Zig engineering quality: `no-5a7o`
7. Performance / memory posture: `no-jacg`
8. API consistency / determinism: `no-ohgb`
9. Docs/examples / discoverability: `no-l5h7`

## Surface Matrix

| Surface | Correctness | Parity | Security | Crypto Correctness | Crypto Boundary | Zig | Performance | API | Docs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Build and packaging surface (`build.zig`, `build.zig.zon`, `examples/build.zig`, `examples/build.zig.zon`) | not applicable | not applicable | not started | not applicable | not applicable | not started | not started | not started | not started |
| Exported facade and shared support (`src/root.zig`, `src/errors.zig`, `src/limits.zig`) | complete | not applicable | complete | not applicable | not applicable | not started | not started | not started | not started |
| Event/message/filter/key core (`src/nip01_event.zig`, `src/nip01_filter.zig`, `src/nip01_message.zig`, `src/nostr_keys.zig`, `src/nip13_pow.zig`, `src/nip19_bech32.zig`, `src/nip21_uri.zig`) | complete | complete | complete | not started | not applicable | not started | not started | not started | not started |
| Implemented NIP surfaces in `docs/plans/implemented-nip-audit-report.md` | complete | complete | complete | not started | not applicable | not started | not started | not started | not started |
| Crypto backend wrapper (`src/crypto/secp256k1_backend.zig`) | not applicable | not applicable | not started | not started | not started | not started | not started | not applicable | not applicable |
| Derivation and backend boundary (`src/nip06_mnemonic.zig`, `src/bip85_derivation.zig`, `src/unicode_nfkc.zig`, `src/unicode_nfkc_data.zig`, `src/unicode_nfkd.zig`, `src/unicode_nfkd_data.zig`) | not started | not applicable | not started | not started | not started | not started | not started | not started | not applicable |
| Cryptography-bearing protocol consumers (`src/nip26_delegation.zig`, `src/nip42_auth.zig`, `src/nip44.zig`, `src/nip49_private_key_encryption.zig`, `src/nip57_zaps.zig`, `src/nip59_wrap.zig`) | complete | complete | complete | not started | not applicable | not started | not started | not started | not started |
| Internal helpers affecting release confidence (`src/internal/relay_origin.zig`) | not started | not applicable | not started | not applicable | not applicable | not started | not started | not started | not applicable |
| Public error-contract and invalid-vs-capacity families | not started | not applicable | complete | not applicable | not applicable | not started | not started | not started | not applicable |
| Examples and discovery surface (`examples/`, `examples/README.md`, `examples/examples.zig`, `examples/common.zig`) | not applicable | not applicable | not started | not applicable | not applicable | not started | not applicable | not started | not started |
| Freeze-critical control and audit docs (`AGENTS.md`, `handoff.md`, `docs/README.md`, `docs/plans/build-plan.md`, `docs/plans/phase-h-remaining-work.md`, `docs/plans/exhaustive-pre-freeze-audit*.md`, `docs/plans/implemented-nip-audit-report.md`) | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | not applicable | not started | not started |

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

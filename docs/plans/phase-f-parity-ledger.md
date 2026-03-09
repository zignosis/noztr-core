# Phase F Parity Ledger (Model v1)

Date: 2026-03-09

Canonical ledger for parity status, deliberate differences, `noztr` uniqueness, and smallest next
actions.

## Feature Parity Status

| Scope | Status | Evidence |
| --- | --- | --- |
| Rust lane (`tools/interop/rust-nostr-parity-all`) | `HARNESS_COVERED` for 16/16 implemented NIPs; `0` `NOT_COVERED_IN_THIS_PASS`; `0` `LIB_UNSUPPORTED` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` |
| TypeScript lane (`tools/interop/ts-nostr-parity-all`) | `HARNESS_COVERED` for 16/16 implemented NIPs; `0` `NOT_COVERED_IN_THIS_PASS`; `0` `LIB_UNSUPPORTED` | `npm install && npm run run` (in `tools/interop/ts-nostr-parity-all`) |
| Full side-by-side matrix | canonical and current | `docs/plans/phase-f-parity-matrix.md` |

## Deliberate Differences

| Delta | Why deliberate | Current taxonomy | Next smallest action |
| --- | --- | --- | --- |
| NIP-40 TS path uses implementation-file fallback when package export is absent | `nostr-tools` version used here does not export `./nip40`; executable semantics still available in `lib/esm/nip40.js` | `HARNESS_COVERED` | keep fallback documented and re-check if package exports change |
| TS NIP-70 has no dedicated helper export in this package version | structural `['-']` semantics are covered through event/tag APIs | `HARNESS_COVERED` | keep structural semantics coverage until helper API exists |
| `LIB_UNSUPPORTED` claims still require executable proof of no public API path | preserve model-v1 semantics and avoid unsupported over-claims | none emitted in either lane | keep explicit proof requirement |

## noztr Uniqueness Points

| Point | Why it matters | Evidence |
| --- | --- | --- |
| Strict taxonomy + depth model in harness output | keeps pass/fail semantics machine-readable and stable | `tools/interop/rust-nostr-parity-all/src/main.rs`, `tools/interop/ts-nostr-parity-all/index.ts` |
| Exit code policy tied only to `HARNESS_COVERED` failures | avoids false negatives from intentionally deferred checks | same harness files |
| Strict default wording preserved | parity model does not alter strictness/default policy | `docs/plans/decision-log.md`, `docs/plans/build-plan.md` |

## Next Actions

1. Keep matrix and ledger authoritative for parity-model v1 status.
2. Re-run both parity-all harnesses on upstream dependency bumps to detect API drift.
3. Preserve frozen defaults posture; parity expansion remains reporting/test depth only.

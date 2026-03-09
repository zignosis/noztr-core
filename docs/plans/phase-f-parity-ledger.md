# Phase F Parity Ledger (Model v1)

Date: 2026-03-09

Canonical ledger for parity status, deliberate differences, `noztr` uniqueness, and smallest next
actions.

## Feature Parity Status

| Scope | Status | Evidence |
| --- | --- | --- |
| Rust lane (`tools/interop/rust-nostr-parity-all`) | `HARNESS_COVERED` for 11/16 implemented NIPs; 5/16 `NOT_COVERED_IN_THIS_PASS`; no `LIB_UNSUPPORTED` claims | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` |
| TypeScript lane (`tools/interop/ts-nostr-parity-all`) | `HARNESS_COVERED` for 6/16 implemented NIPs; 10/16 `NOT_COVERED_IN_THIS_PASS`; no `LIB_UNSUPPORTED` claims | `npm run run` (in `tools/interop/ts-nostr-parity-all`) |
| Full side-by-side matrix | canonical and current | `docs/plans/phase-f-parity-matrix.md` |

## Deliberate Differences

| Delta | Why deliberate | Current taxonomy | Next smallest action |
| --- | --- | --- | --- |
| TS lane does not yet cover NIP-02/09/11/59/65 | first rollout keeps scope narrow to existing overlap checks | `NOT_COVERED_IN_THIS_PASS` | add one `BASELINE` check per NIP in TS harness |
| Both lanes do not yet cover NIP-40/45/50/70/77 in parity-all | rollout prioritizes proven overlap checks and stable output contract first | `NOT_COVERED_IN_THIS_PASS` | implement one candidate overlap check starting with NIP-50 |
| `LIB_UNSUPPORTED` is not emitted by default | avoid overloaded unsupported wording without code proof | none currently | add explicit proof checks before any `LIB_UNSUPPORTED` claim |

## noztr Uniqueness Points

| Point | Why it matters | Evidence |
| --- | --- | --- |
| Strict taxonomy + depth model in harness output | keeps pass/fail semantics machine-readable and stable | `tools/interop/rust-nostr-parity-all/src/main.rs`, `tools/interop/ts-nostr-parity-all/index.ts` |
| Exit code policy tied only to `HARNESS_COVERED` failures | avoids false negatives from intentionally deferred checks | same harness files |
| Strict default wording preserved | parity model does not alter strictness/default policy | `docs/plans/decision-log.md`, `docs/plans/build-plan.md` |

## Next Actions

1. Add TS `BASELINE` checks for `NIP-02` and `NIP-09`.
2. Add one shared candidate check for `NIP-50` in rust and TS lanes.
3. Keep matrix and ledger authoritative; lane docs remain execution notes.

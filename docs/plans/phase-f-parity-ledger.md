# Phase F Parity Ledger (Model v1)

Date: 2026-03-09

Canonical ledger for parity status, deliberate differences, `noztr` uniqueness, and smallest next
actions.

## Feature Parity Status

| Scope | Status | Evidence |
| --- | --- | --- |
| Rust lane (`tools/interop/rust-nostr-parity-all`) | Active parity gate lane; `HARNESS_COVERED` for 16/16 implemented NIPs; `0` `NOT_COVERED_IN_THIS_PASS`; `0` `LIB_UNSUPPORTED` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` |
| TypeScript lane (`tools/interop/ts-nostr-parity-all`) | Archived/historical evidence lane; not part of active pass/fail cadence | Historical evidence retained in this ledger, matrix, and `docs/plans/phase-f-risk-burndown.md` |
| Full side-by-side matrix | canonical and current | `docs/plans/phase-f-parity-matrix.md` |
| Incremental depth raise (current pass) | rust lane deep-pass raised all implemented NIPs (`16/16`) to `DEEP` with additional malformed/negative assertions; defaults unchanged | `tools/interop/rust-nostr-parity-all/src/main.rs` |

## Deliberate Differences

| Delta | Why deliberate | Current taxonomy | Next smallest action |
| --- | --- | --- | --- |
| NIP-40 TS path uses implementation-file fallback when package export is absent | `nostr-tools` version used here does not export `./nip40`; executable semantics still available in `lib/esm/nip40.js` | `HARNESS_COVERED` | keep fallback documented and re-check if package exports change |
| TS NIP-70 has no dedicated helper export in this package version | structural `['-']` semantics are covered through event/tag APIs | `HARNESS_COVERED` | keep structural semantics coverage until helper API exists |
| Strict default boundary behavior differs from permissive SDK defaults in selected paths | intentional Layer 1 strictness preserves deterministic trust-boundary semantics | `HARNESS_COVERED` parity reporting + documented divergence | keep release note current in `docs/release/intentional-divergences.md` |
| `LIB_UNSUPPORTED` claims still require executable proof of no public API path | preserve model-v1 semantics and avoid unsupported over-claims | none emitted in either lane | keep explicit proof requirement |

## noztr Uniqueness Points

| Point | Why it matters | Evidence |
| --- | --- | --- |
| Strict taxonomy + depth model in harness output | keeps pass/fail semantics machine-readable and stable | `tools/interop/rust-nostr-parity-all/src/main.rs`, `tools/interop/ts-nostr-parity-all/index.ts` |
| Exit code policy tied only to `HARNESS_COVERED` failures | avoids false negatives from intentionally deferred checks | same harness files |
| Canonical-only public Layer 1 APIs | unreleased surface avoids alias drift and trust-boundary ambiguity | `src/nip01_message.zig`, `src/nip13_pow.zig`, `src/root.zig` |
| Strict default wording preserved | parity model does not alter strictness/default policy | `docs/plans/decision-log.md`, `docs/plans/build-plan.md` |

## Next Actions

1. Keep matrix and ledger authoritative for parity-model v1 status.
2. Re-run only the rust parity-all harness for active parity gates on dependency bumps.
3. Preserve frozen defaults posture; parity expansion remains reporting/test depth only.
4. Keep release-facing divergence guidance synchronized in `docs/release/intentional-divergences.md`.

## NIP-59 Deep Comparison

- rust evidence: `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml`
- rust harness area: `tools/interop/rust-nostr-parity-all/src/main.rs` (`check_nip59`)
- noztr evidence: `zig build test --summary all -- --test-filter "nip59"`
- noztr test area: `src/nip59_wrap.zig`
- outcome: rust deep `PASS` and noztr NIP-59 module tests `PASS`; no default-policy change.

## Rust Deep Pass (All Implemented NIPs)

- evidence command: `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml`
- outcome: `SUMMARY pass=16 fail=0 harness_covered=16 lib_supported=0 not_covered_in_this_pass=0 lib_unsupported=0 total=16`
- scope: all implemented rust-lane checks (`NIP-01/02/09/11/13/19/21/40/42/44/45/50/59/65/70/77`)
  now assert at least one additional malformed/negative case and report `depth=DEEP`.
- policy note: rust lane remains the active parity gate lane; frozen defaults and strictness policy
  remain unchanged.

Policy note: this governance-scope change does not modify library behavior defaults or strictness
policy.

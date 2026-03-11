# Handoff

Current project context for the Phase H kickoff baseline.

## Current Phase Status

- Planning phase records remain closed in `docs/plans/decision-log.md`.
- Active execution state is Phase H on post-Phase G local-only closure baseline.
- Frozen defaults and Layer 1 posture remain unchanged.
- Canonical Phase F trackers:
  - `docs/plans/phase-f-kickoff.md`
  - `docs/plans/phase-f-parity-matrix.md`
  - `docs/plans/phase-f-parity-ledger.md`
  - `docs/plans/phase-f-risk-burndown.md`
  - `docs/plans/phase-g-kickoff.md`

## Phase H Kickoff

- Active execution state is Phase H kickoff baseline.
- Phase G local-only closure is complete.
- `UT-E-003` and `UT-E-004` are maintenance-mode only; reopen only on new behavior-class discovery.
- Blocker visibility: `no-3uj` (git/Dolt remote + sync readiness) is deferred-by-operator and not in
  current execution focus.
- Remote readiness remains deferred-by-operator and is not required for the completed Phase G local
  closure.
- Additional-NIP planning now lives in:
  - `docs/plans/phase-h-kickoff.md`
  - `docs/plans/phase-h-additional-nips-plan.md`
  - `docs/plans/phase-h-wave1-loop.md`
  - implemented-NIP audit execution policy now lives in `docs/plans/build-plan.md`
- H0 status:
  - NIP-06 pin target, one-module boundary, typed failure posture, zeroization set, and corpus floor
    are frozen
- Wave 1 progress:
  - `NIP-25` audit is complete in `src/nip25_reactions.zig`: reaction `emoji` tags now accept the
    optional NIP-30 fourth-slot emoji-set coordinate when it is a valid `30030` address, while
    strict shortcode and URL validation remain retained as the accepted Layer 1 posture, and
    contradictory optional target metadata plus unsupported `a` kinds now reject the parse path
  - `NIP-10` audit is complete in `src/nip10_threads.zig`: legacy `mention` markers now parse as
    explicit mentions, four-slot pubkey fallback is accepted, rust parity remains `DEEP PASS`, TS
    audit parity is now `HARNESS_COVERED EDGE PASS`, and `no-4iw` is resolved by the audit
  - `NIP-18` is complete in `src/nip18_reposts.zig` with strict embedded-event consistency checks
    across `e`, `p`, `k`, and `a` tags; core builder semantics are parity-covered and the
    addressable repost builder shape is source-reviewed in this pass; contradictory optional repost
    target metadata now rejects the parse path even without embedded-event proof
  - `NIP-22` is complete in `src/nip22_comments.zig` with strict root/parent linkage validation,
    mandatory `K/k`, required author linkage for Nostr targets, accepted support for addressable
    `a+e` comment targets, NIP-73-consistent external validation, and an accepted strict
    trust-boundary divergence from permissive rust-style missing-root / optional-kind extraction
  - `NIP-42` audit is complete in `src/nip42_auth.zig`: the auth challenge bound is widened from
    `64` to `255`, while path-bound websocket origin matching, duplicate required-tag rejection,
    and unbracketed IPv6 rejection remain accepted trust-boundary behavior
  - `NIP-27` audit is complete in `src/nip27_references.zig`: strict `nostr:` URI extraction keeps
    stable byte spans and decoded profile/event/address entities, no longer treats `nrelay` as an
    inline content reference, and keeps malformed-fragment fallback that matches rust and
    `nostr-tools` tokenization behavior
  - `NIP-51` is complete in `src/nip51_lists.zig` with strict public-list extraction for the
    supported Wave 1 kinds, required `d` metadata handling for set kinds, coordinate-kind
    validation where NIP-51 specifies it, accepted broader bookmark extraction for bounded hashtag
    and URL items, ignored unrelated unknown tags, bounded broader bookmark/emoji tag builders, and
    deep rust parity coverage across all supported rust-backed public-list builders
  - deferred NIP-51 follow-up `no-e7b` now tracks private encrypted list content plus any future
    decision to widen extraction beyond the current strict Wave 1 subset
  - Wave 1 is complete; the next execution focus is the implemented-NIP audit before Wave 2 /
    `NIP-46`

## Phase G Closure Snapshot (non-remote)

- Status: non-remote release-readiness checklist pass is complete for local closure.
- Completed: rust parity baseline and aggregate Zig gates are current for kickoff baseline.
- Completed: rust-active / TS-archived governance wording is aligned across active Phase G artifacts.
- Completed: `UT-E-003`/`UT-E-004` remain maintenance-mode only with no burn-down expansion unless a
  new behavior class is discovered.
- Deferred scope: `no-3uj` remote readiness remains deferred-by-operator.

## Active Parity Gate

- Active lane: rust only (`tools/interop/rust-nostr-parity-all`).
- Current rust status: `22/22 HARNESS_COVERED`, `DEEP`, `PASS`.
- Current TS audit status: `20/20 HARNESS_COVERED`, mixed `BASELINE/EDGE/DEEP`, `PASS`
  (`tools/interop/ts-nostr-parity-all`; non-gating audit evidence lane).
- Baseline cadence run (2026-03-09): rust parity harness passed
  (`SUMMARY pass=16 fail=0 harness_covered=16 total=16`).
- Latest cadence run (2026-03-10): rust parity harness passed
  (`SUMMARY pass=22 fail=0 harness_covered=22 total=22`).
- Latest cadence run (2026-03-11): rust parity harness passed
  (`SUMMARY pass=22 fail=0 harness_covered=22 total=22`).
- Latest cadence run (2026-03-11): TS audit harness passed
  (`SUMMARY pass=20 fail=0 harness_covered=20 total=20`).
- Latest cadence run (2026-03-11): `zig build test --summary all` passed
  (`Build Summary: 8/8 steps succeeded; 584/584 tests passed`).
- Latest cadence run (2026-03-11): `zig build` passed.
- Active cadence commands:
  - `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml`
  - `zig build test --summary all && zig build`

## Secondary Audit Evidence

- TypeScript parity lane (`tools/interop/ts-nostr-parity-all`) is not an active gate lane, but it
  remains a re-runnable secondary audit evidence lane.
- Historical TS parity context remains preserved in:
  - `docs/plans/phase-f-parity-matrix.md`
  - `docs/plans/phase-f-parity-ledger.md`
  - `docs/plans/phase-f-risk-burndown.md`
  - `docs/plans/phase-f-ts-nostr-tools-parity.md`

## Burn-Down Status

- `UT-E-003` and `UT-E-004` remain maintenance-mode only; no active burn-down expansion.
- Canonical evidence baseline remains in `docs/plans/phase-f-risk-burndown.md`.
- Trigger-governance status remains unchanged: no `UT-E-001`/`A-D-001` trigger criteria fired.

## Hard-Gate Snapshot (epic `no-dr3`)

- Scope freeze: representative sets are locked for `UT-E-003` and `UT-E-004`; no class expansion
  during this pass.
- Stability window: three consecutive controlled runs completed with no drift
  (rust parity `pass=16 fail=0`; zig tests `460/460`; `zig build` pass each run).
- No-new-findings closure: latest incremental candidates produced no new behavior-class findings.
- Governance closure: open high-priority check (`P0/P1`) is `0` before and after gate sequence.
- Policy continuity: rust-active lane maintained; TS remains archived historical evidence.

## Pending Actions

1. Keep TypeScript references archive-only in docs and prevent active-cadence wording regressions.
2. Continue maintenance cadence reruns (rust parity + aggregate Zig gates) on dependency or toolchain
   changes and record outcomes in Phase H kickoff and handoff docs.
3. Continue Phase H expansion sequencing from `docs/plans/phase-h-additional-nips-plan.md`.
   Wave 1 is complete: `25`, `10`, `18`, `22`, `27`, `51`.
4. Run the implemented-NIP audit serially using the canonical review criteria and execution policy
   in `docs/plans/build-plan.md`, with `rust-nostr` as the active parity lane and `nostr-tools` as
   a secondary non-gating ecosystem signal. Every implemented NIP must be cross-checked against
   both references during the audit.
5. Continue from the completed NIP-10, NIP-18, NIP-22, NIP-25, NIP-27, NIP-42, and NIP-51 audits
   to the next implemented NIP audit item.
6. Start Wave 2 / `NIP-46` only after the implemented-NIP audit reaches an acceptable stopping
   point or explicitly recorded partial cutoff.
7. Keep `no-3uj` visible as deferred-by-operator until remote setup returns to active execution focus.

## Additional Assets

- Process-boilerplate extraction task `no-6tu` is closed; starter-consistency and shared-corpus
  evaluation task `no-tdt` is the active follow-on.
- New reusable starter assets now live under `docs/process/` and `template/`.
- Shared-corpus evaluation docs
  (`docs/process/shared-knowledge-strategy.md`, `docs/process/research-guides-catalog.md`)
  are process-evaluation artifacts only and are not canonical inputs for active Phase H execution.
- These additions do not change Phase H Layer 1 defaults, parity cadence, or current Wave 1 order.

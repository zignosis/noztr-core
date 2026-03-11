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
  - `NIP-01` audit is complete across `src/nip01_event.zig`, `src/nip01_filter.zig`, and
    `src/nip01_message.zig`: strict parsing now accepts uppercase single-letter `#X` filter keys,
    while unknown filter-field rejection and prefixed rejection-status enforcement remain accepted
    Layer 1 trust-boundary behavior
  - `NIP-02` audit is complete in `src/nip02_contacts.zig`: no Layer 1 change was required because
    valid relay-hint and petname shapes were already accepted, and the current strict contact-tag
    extraction remained acceptable on the evidence gathered in this pass
  - `NIP-09` audit is complete in `src/nip09_delete.zig`: delete `a` targets now have to satisfy
    the NIP-01 replaceable/addressable coordinate rules instead of only matching the raw
    `<kind>:<pubkey>:<identifier>` string shape
  - `NIP-11` audit is complete in `src/nip11.zig`: no Layer 1 change was required because the
    current bounded partial relay-information parser already ignores unmodeled NIP-11 fields
    cleanly while preserving the supported subset, and the audit now pins a full-spec-shaped
    compatibility vector so that broader relay documents keep parsing deterministically
  - `NIP-13` audit is complete in `src/nip13_pow.zig`: no Layer 1 change was required because the
    current PoW helper already keeps the full `0..256` difficulty domain, preserves the checked-ID
    trust-boundary entry point, and remains compatible with `nostr-tools` at the `256`-bit edge
  - `NIP-19` audit is complete in `src/nip19_bech32.zig`: `naddr` encode/decode now accepts an
    empty identifier for normal replaceable coordinates, matching the NIP text plus both reference
    lanes instead of rejecting that valid replaceable-address shape
  - `NIP-21` audit is complete in `src/nip21_uri.zig`: no separate Layer 1 change was required,
    but replaceable `nostr:naddr...` URIs with empty identifiers are now explicitly covered so the
    inherited NIP-19 compatibility fix is pinned at the URI layer as well
  - `NIP-40` audit is complete in `src/nip40_expire.zig`: malformed `expiration` metadata is now
    treated as absent and the first valid expiration tag wins deterministically, matching both
    reference lanes instead of turning optional malformed metadata into helper-level failures
  - `NIP-44` audit is complete in `src/nip44.zig`: no Layer 1 change was required because the
    current v2-only cryptographic surface already matches both reference lanes across fixture
    parity, staged failure ordering, checked conversation-key derivation, and strict
    padding/MAC/UTF-8 boundaries
  - `NIP-59` audit is complete in `src/nip59_wrap.zig`: no Layer 1 change was required because the
    current staged wrap->seal->rumor boundary already matches both reference lanes across
    unwrap/reject behavior, sender continuity, unsigned-rumor enforcement, and typed
    decrypt/signature failure mapping
  - `NIP-65` audit is complete in `src/nip65_relays.zig`: relay-list extraction now ignores
    unrelated foreign tags on `kind:10002` events while keeping malformed supported `r` relay tags,
    malformed relay URLs, invalid markers, normalized-origin dedupe, and kind checking strict and
    typed
  - `NIP-70` audit is complete in `src/nip70_protected.zig`: no Layer 1 change was required
    because only the exact single-item `["-"]` tag is canonical protection semantics in the NIP
    and both reference lanes, while malformed lookalike tags remain ignored instead of poisoning the
    helper path
  - `NIP-50` audit is complete in `src/nip50_search.zig`: bounded UTF-8 search validation is now
    decoupled from extension-token shape, and supported `key:value` extensions are extracted
    best-effort so malformed extension-like tokens remain searchable raw text instead of
    invalidating the helper path
  - `NIP-45` audit is complete in `src/nip45_count.zig`: COUNT relay parsing now accepts uppercase
    HLL hex and ignores unknown metadata keys while keeping malformed count values, malformed HLL
    length/content, and malformed top-level COUNT shapes typed and strict
  - `NIP-77` audit is complete in `src/nip77_negentropy.zig`: `NEG-ERR` reasons now accept the
    spec-required `:` delimiter with optional spaces, and bounded negentropy state can be reopened
    with a new `NEG-OPEN` without violating ordering, version, payload, or session-step checks
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
  - Wave 1 is complete and the implemented-NIP audit is complete; the next execution focus is Wave
    2 / `NIP-46`

## Phase G Closure Snapshot (non-remote)

- Status: non-remote release-readiness checklist pass is complete for local closure.
- Completed: rust parity baseline and aggregate Zig gates are current for kickoff baseline.
- Completed: rust-active / TS-archived governance wording is aligned across active Phase G artifacts.
- Completed: `UT-E-003`/`UT-E-004` remain maintenance-mode only with no burn-down expansion unless a
  new behavior class is discovered.
- Deferred scope: `no-3uj` remote readiness remains deferred-by-operator.

## Active Parity Gate

- Active lane: rust only (`tools/interop/rust-nostr-parity-all`).
- Current rust status: `23/23 HARNESS_COVERED`, mixed `BASELINE/DEEP`, `PASS`.
- Current TS audit status: `21/21 HARNESS_COVERED`, mixed `BASELINE/EDGE/DEEP`, `PASS`
  (`tools/interop/ts-nostr-parity-all`; non-gating audit evidence lane).
- Baseline cadence run (2026-03-09): rust parity harness passed
  (`SUMMARY pass=16 fail=0 harness_covered=16 total=16`).
- Latest cadence run (2026-03-10): rust parity harness passed
  (`SUMMARY pass=22 fail=0 harness_covered=22 total=22`).
- Latest cadence run (2026-03-11): rust parity harness passed
  (`SUMMARY pass=23 fail=0 harness_covered=23 total=23`).
- Latest cadence run (2026-03-11): TS audit harness passed
  (`SUMMARY pass=21 fail=0 harness_covered=21 total=21`).
- Latest cadence run (2026-03-11): `zig build test --summary all` passed
  (`Build Summary: 8/8 steps succeeded; 616/616 tests passed`).
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
4. Keep the implemented-NIP audit report current if future code changes reopen compatibility or
   strictness questions.
5. Continue Wave 2 / `NIP-46`.
   Current implemented baseline:
   - `src/nip46_remote_signing.zig` now covers method parsing, permission parsing/formatting,
     JSON request/response parse+compose, current-spec `bunker://` and `nostrconnect://`
     URI parse+compose, and strict kind-24133 envelope validation.
   - valid `switch_relays` responses with `result: null` are now preserved explicitly instead of
     being collapsed into the same state as an omitted `result` field.
   - typed result helpers now cover `connect`, `get_public_key`, `sign_event`, and
     `switch_relays`.
   Completed evidence:
   - rust overlap parity is now `HARNESS_COVERED`, `BASELINE`, `PASS`
   - TypeScript overlap evidence is now `HARNESS_COVERED`, `BASELINE`, `PASS`
   - pinned `rust-nostr` still uses the older `metadata=` client-URI shape and omits
     `switch_relays`; `noztr` keeps the current-spec split-query URI and method surface that
     matches `nostr-tools`
   Remaining Wave 2 work:
   - decide whether to add typed request builders or broader discovery helpers beyond the current
     bounded core and result-helper surface
   - update tracker state when `bd` localhost access is available again in-session
7. Keep `no-3uj` visible as deferred-by-operator until remote setup returns to active execution focus.

## Additional Assets

- Process-boilerplate extraction task `no-6tu` is closed; starter-consistency and shared-corpus
  evaluation task `no-tdt` is the active follow-on.
- New reusable starter assets now live under `docs/process/` and `template/`.
- Shared-corpus evaluation docs
  (`docs/process/shared-knowledge-strategy.md`, `docs/process/research-guides-catalog.md`)
  are process-evaluation artifacts only and are not canonical inputs for active Phase H execution.
- These additions do not change Phase H Layer 1 defaults, parity cadence, or current Wave 1 order.

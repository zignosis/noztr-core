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
  - Wave 3 / `NIP-06` is implemented in `src/nip06_mnemonic.zig` and closed:
    - current implemented scope:
      - English mnemonic validation
      - mnemonic plus optional passphrase to 64-byte seed
      - canonical `m/44'/1237'/<account>'/0/0` secret-key derivation
    - current evidence:
      - official BIP39 seed vectors covered
      - both official NIP-06 vectors covered
      - pinned rust-nostr extra mnemonic vector covered
      - fixed `account = 1` vector covered
      - invalid matrix covered for malformed length, unknown word, checksum mismatch, invalid
        UTF-8, invalid normalization, invalid seed boundary, invalid account, and
        buffer-too-small outputs
    - review finding fixed:
      - higher-account derivation no longer aliases libwally parent/output key buffers
    - accepted temporary normalization boundary:
      - current Phase H behavior accepts ASCII-only mnemonic/passphrase input after UTF-8
        validation and rejects non-ASCII input with typed `InvalidNormalization`
      - `no-09f` review is complete: full BIP39-compatible NFKD normalization remains future
        feature `no-2gp`, not immediate kernel scope
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
  - post-Wave follow-up `no-e7b` is now complete: `src/nip51_lists.zig` also supports bounded
    private-list JSON serialization, bounded private-item extraction from decrypted JSON, and
    direct NIP-44 private-list decrypt+extract
  - deprecated NIP-04 private-list compatibility is now deferred separately in `no-urr`
  - post-wave expansion `NIP-23` is now complete in `src/nip23_long_form.zig` with bounded
    long-form metadata extraction/builders for `30023` and `30024`, required single `d`,
    optional `title`/`image`/`summary`/`published_at`, ordered hashtag extraction, and ignored
    unrelated unknown tags
  - deferred backlog `NIP-24` is now complete in `src/nip24_extra_metadata.zig` with bounded
    kind-`0` metadata extras parse/serialize for `display_name`/`website`/`banner`/`bot`/
    `birthday`, deprecated `displayName` fallback, ordered generic `r`/`i`/`title`/`t`
    extraction, and direct generic tag builders for `r`/`title`/`t`
  - ownership follow-up `NIP-73` is now complete in `src/nip73_external_ids.zig` with bounded
    external-id parse/build/match helpers reused by `NIP-24` generic `i` extraction and
    `NIP-22` external-kind consistency
  - deferred backlog `NIP-03` is now complete in `src/nip03_opentimestamps.zig` with strict
    kind-`1040` extraction, exact `e`/`k` target tags, caller-buffer base64 proof decoding, target
    reference validation, bounded local proof verification floor, and direct `e`/`k` tag builders
  - deferred backlog `NIP-03` robustness review is complete:
    - standard long-form `e` tags with empty-relay / marker / pubkey suffixes are now accepted
    - bounded proof decoding, exact target-reference validation, and the bounded local proof floor
      remain unchanged
  - accepted bounded deferral:
    - networked OpenTimestamps / Bitcoin attestation verification remains out of current kernel
      scope
  - deferred backlog `NIP-17` is now complete in `src/nip17_private_messages.zig` with bounded
    kind-`14` message parsing, kind-`15` file-message parsing, direct `NIP-59`
    unwrap-to-rumor reuse for both message kinds, kind-`10050` relay-list extraction, and direct
    `p`/`relay` tag builders
  - deferred backlog `NIP-17` robustness review is complete:
    - standard long-form reply `e` tags with optional public-key suffixes are now accepted
    - kind-14 content, kind-15 required file metadata, recipient, and relay-list boundaries remain
      unchanged
  - deferred backlog `NIP-39` is now complete in `src/nip39_external_identities.zig` with bounded
    kind-`10011` claim extraction, canonical `i`-tag building, provider-specific proof-URL
    derivation, and expected proof-text generation
  - deferred backlog `NIP-39` robustness review is complete with no Layer 1 behavior change
  - accepted kernel posture: live provider fetch verification remains out of current kernel scope
    (`D-071`)
  - deferred backlog `NIP-29` is now complete in `src/nip29_relay_groups.zig` with bounded
    relay-generated group metadata/admin/member/role extraction and builders for kinds `39000`,
    `39001`, `39002`, and `39003`, raw group-reference parse/build helpers, bounded join/leave
    and put/remove-user extraction, raw `previous` tag plumbing, and pure fixed-capacity state
    reduction over caller-supplied `39000` / `39001` / `39002` / `39003` / `9000` / `9001` events
  - deferred backlog `NIP-29` robustness review is complete:
    - inbound extraction now accepts deployed three-slot `h` tags with optional relay hints
    - group-admin extraction now accepts optional compatibility labels emitted by `nostr-tools`
      without misreading those labels as permissions
    - the pure reducer ignores compatibility labels for role state, and outbound builders may emit
      the broader labeled admin shape only when a caller explicitly supplies one
    - outbound builders still reject empty admin role lists and empty optional member labels
  - accepted bounded kernel posture:
    - pure fixed-capacity state reduction is now implemented under the accepted `D-072` boundary
    - relay fetch/subscription and broader moderation orchestration remain out of current scope
  - Wave 1, the implemented-NIP audit, Wave 2 / `NIP-46`, Wave 3 / `NIP-06`, post-wave expansion
    `NIP-23`, and deferred backlog items `NIP-24`, `NIP-03`, `NIP-17`, `NIP-39`, and `NIP-29`
    are complete

## Phase G Closure Snapshot (non-remote)

- Status: non-remote release-readiness checklist pass is complete for local closure.
- Completed: rust parity baseline and aggregate Zig gates are current for kickoff baseline.
- Completed: rust-active / TS-archived governance wording is aligned across active Phase G artifacts.
- Completed: `UT-E-003`/`UT-E-004` remain maintenance-mode only with no burn-down expansion unless a
  new behavior class is discovered.
- Deferred scope: `no-3uj` remote readiness remains deferred-by-operator.

## Active Parity Gate

- Active lane: rust only (`tools/interop/rust-nostr-parity-all`).
- Current rust status: `35 HARNESS_COVERED`, `3 LIB_UNSUPPORTED`, mixed `BASELINE/EDGE/DEEP`,
  `PASS`; `NIP-26` and `NIP-37` remain source-review-only because the active Rust lane exposes no
  dedicated helper surfaces for them, `NIP-84` is also source-review-only there, and `NIP-29`
  extraction parity remains source-review-only because `rust-nostr` has no dedicated helper
  surface or reducer there.
- Current TS audit status: `33 HARNESS_COVERED`, `4 LIB_UNSUPPORTED`, mixed `BASELINE/EDGE/DEEP`,
  `PASS` (`tools/interop/ts-nostr-parity-all`; non-gating audit evidence lane).
- Baseline cadence run (2026-03-09): rust parity harness passed
  (`SUMMARY pass=16 fail=0 harness_covered=16 total=16`).
- Latest cadence run (2026-03-10): rust parity harness passed
  (`SUMMARY pass=22 fail=0 harness_covered=22 total=22`).
- Latest cadence run (2026-03-11): rust parity harness passed
  (`SUMMARY pass=23 fail=0 harness_covered=23 total=23`).
- Latest cadence run (2026-03-11): TS audit harness passed
  (`SUMMARY pass=21 fail=0 harness_covered=21 total=21`).
- Latest cadence run (2026-03-11): `zig build test --summary all` passed
  (`Build Summary: 9/9 steps succeeded; 640/640 tests passed`).
- Latest cadence run (2026-03-11): `zig build` passed.
- Latest cadence run (2026-03-12): rust parity harness passed
  (`SUMMARY pass=25 fail=0 harness_covered=25 total=25`).
- Latest cadence run (2026-03-12): TS audit harness passed
  (`SUMMARY pass=24 fail=0 harness_covered=24 total=24`).
- Latest cadence run (2026-03-12): `zig build test --summary all` passed
  (`Build Summary: 9/9 steps succeeded; 668/668 tests passed`).
- Latest cadence run (2026-03-12): `zig build` passed.
- Latest cadence run (2026-03-12): rust parity harness passed
  (`SUMMARY pass=26 fail=0 harness_covered=26 total=26`).
- Latest cadence run (2026-03-12): TS audit harness passed
  (`SUMMARY pass=25 fail=0 harness_covered=25 total=25`).
- Latest cadence run (2026-03-12): `zig build test --summary all` passed
  (`Build Summary: 9/9 steps succeeded; 682/682 tests passed`).
- Latest cadence run (2026-03-12): `zig build` passed.
- Latest cadence run (2026-03-12): rust parity harness passed
  (`SUMMARY pass=27 fail=0 harness_covered=27 total=27`).
- Latest cadence run (2026-03-12): TS audit harness passed
  (`SUMMARY pass=26 fail=0 harness_covered=26 total=26`).
- Latest cadence run (2026-03-12): `zig build test --summary all` passed
  (`Build Summary: 9/9 steps succeeded; 690/690 tests passed`).
- Latest cadence run (2026-03-12): `zig build` passed.
- Latest cadence run (2026-03-12): rust parity harness passed
  (`SUMMARY pass=28 fail=0 harness_covered=28 total=28`).
- Latest cadence run (2026-03-12): TS audit harness passed
  (`SUMMARY pass=27 fail=0 harness_covered=27 total=27`).
- Latest cadence run (2026-03-12): `zig build test --summary all` passed
  (`Build Summary: 9/9 steps succeeded; 698/698 tests passed`).
- Latest cadence run (2026-03-12): `zig build` passed.
- Latest cadence run (2026-03-12): rust parity harness passed
  (`SUMMARY pass=29 fail=0 harness_covered=29 total=29`).
- Latest cadence run (2026-03-12): TS audit harness passed
  (`SUMMARY pass=28 fail=0 harness_covered=28 total=28`).
- Latest cadence run (2026-03-12): `zig build test --summary all` passed
  (`Build Summary: 9/9 steps succeeded; 704/704 tests passed`).
- Latest cadence run (2026-03-12): `zig build` passed.
- Latest cadence run (2026-03-12): rust parity harness passed
  (`SUMMARY pass=29 fail=0 harness_covered=29 total=29`).
- Latest cadence run (2026-03-12): TS audit harness passed
  (`SUMMARY pass=29 fail=0 harness_covered=29 total=29`).
- Latest cadence run (2026-03-12): `zig build test --summary all` passed
  (`Build Summary: 9/9 steps succeeded; 714/714 tests passed`).
- Latest cadence run (2026-03-12): `zig build` passed.
- Latest cadence run (2026-03-12): rust parity harness passed
  (`SUMMARY pass=29 fail=0 harness_covered=29 total=29`).
- Latest cadence run (2026-03-12): TS audit harness passed
  (`SUMMARY pass=29 fail=0 harness_covered=29 total=29`).
- Latest cadence run (2026-03-12): `zig build test --summary all` passed
  (`Build Summary: 9/9 steps succeeded; 720/720 tests passed`).
- Latest cadence run (2026-03-12): `zig build` passed.
- Latest cadence run (2026-03-12): rust parity harness passed
  (`SUMMARY pass=30 fail=0 harness_covered=30 total=30`).
- Latest cadence run (2026-03-12): TS audit harness passed
  (`SUMMARY pass=29 fail=0 harness_covered=29 total=29`).
- Latest cadence run (2026-03-12): `zig build test --summary all` passed
  (`Build Summary: 9/9 steps succeeded; 750/750 tests passed`).
- Latest cadence run (2026-03-12): `zig build` passed.
- Latest cadence run (2026-03-13): rust parity harness passed
  (`SUMMARY pass=30 fail=0 harness_covered=30 total=30`).
- Latest cadence run (2026-03-13): TS audit harness passed
  (`SUMMARY pass=29 fail=0 harness_covered=29 total=29`).
- Latest cadence run (2026-03-13): `zig build test --summary all` passed
  (`Build Summary: 9/9 steps succeeded; 758/758 tests passed`).
- Latest cadence run (2026-03-13): `zig build` passed.
- Latest cadence run (2026-03-13): rust parity harness passed
  (`SUMMARY pass=35 fail=0 harness_covered=35 lib_unsupported=3 total=38`).
- Latest cadence run (2026-03-13): TS audit harness passed
  (`SUMMARY pass=33 fail=0 harness_covered=33 lib_unsupported=4 total=37`).
- Latest cadence run (2026-03-13): `zig build test --summary all` passed
  (`Build Summary: 9/9 steps succeeded; 844/844 tests passed`).
- Latest cadence run (2026-03-13): `zig build` passed.
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
3. Kernel-first expansion is active.
   Current state:
   - `NIP-05` is complete in `src/nip05_identity.zig`
   - `NIP-26` is complete in `src/nip26_delegation.zig`
   - `NIP-37` is complete in `src/nip37_drafts.zig`
   - `NIP-58` is complete in `src/nip58_badges.zig`
   - `NIP-84` is complete in `src/nip84_highlights.zig`
   - `NIP-32` is complete in `src/nip32_labeling.zig`
   - `NIP-36` is complete in `src/nip36_content_warning.zig`
   - `NIP-56` is complete in `src/nip56_reporting.zig`
   - accepted next-NIP boundary map lives in
     `docs/plans/noztr-sdk-ownership-matrix.md` for `05`, `07`, `26`, `32`, `36`, `37`, `56`,
     `57`, `58`, `60`, `61`, `84`, `86`, and `B7`
   - current serial kernel-first sequence `32`, `36`, `56`, `05`, `26`, `37`, `58`, `84` is
     complete
   - next recommended focus is a focused robustness batch over the completed kernel-first additions
     before starting split-later `57` / `86` work or `nzdk`
4. Keep the implemented-NIP audit report current if future code changes reopen compatibility or
   strictness questions.
   - use `docs/plans/noztr-sdk-ownership-matrix.md` when the question is whether a helper belongs
     in `noztr` or the future SDK.
   - latest kernel-boundary review found no material scope pollution; only two low-severity
     borderline helpers remain accepted in-kernel for now:
     - `src/nip39_external_identities.zig` proof URL / expected-text helpers
     - `src/nip46_remote_signing.zig` exact `nostrconnect_url` template substitution
5. Wave 2 / `NIP-46` is complete.
   Implemented baseline:
   - `src/nip46_remote_signing.zig` now covers method parsing, permission parsing/formatting,
     JSON request/response parse+compose, current-spec `bunker://` and `nostrconnect://`
     URI parse+compose, and strict kind-24133 envelope validation.
   - valid `switch_relays` responses with `result: null` are now preserved explicitly instead of
     being collapsed into the same state as an omitted `result` field.
   - typed parsed-request helpers now cover `connect`, `sign_event`, the current
     pubkey-plus-text methods, and zero-param commands.
   - direct typed request builders now cover `connect`, `sign_event`, the current
     pubkey-plus-text methods, and zero-param commands.
   - typed result helpers now cover `connect`, `get_public_key`, `sign_event`, and
     `switch_relays`.
   - appendix discovery helpers now parse signer `nostr.json?name=_` NIP-46 discovery data and
     extract bounded NIP-89 kind-`31990` remote-signer metadata.
   - signer `nostr.json` discovery accepts both the current `nip46.relays` shape and the older
     deployed pubkey-keyed relay map used by `nostr-tools`.
   - client-URI parsing now also accepts the older `metadata={...}` query shape emitted by
     `rust-nostr` and maps it into the current typed `name` / `url` / `image` fields while keeping
     split-query output as the canonical emitted form.
   Completed evidence:
   - rust overlap parity is now `HARNESS_COVERED`, `BASELINE`, `PASS`
   - TypeScript overlap evidence is now `HARNESS_COVERED`, `BASELINE`, `PASS`
   - pinned `rust-nostr` still omits `switch_relays`; `noztr` keeps the current-spec split-query
     URI output and method surface that matches `nostr-tools`, but now also accepts the older rust
     `metadata=` input shape as compatibility parse-only behavior
   Accepted out-of-scope:
   - relay/session orchestration, redirects, and end-user connection flow remain outside the
     protocol-kernel helper surface
   - deterministic `nostrconnect_url` placeholder substitution is now implemented as a bounded
     kernel helper (`D-068`)
6. Ownership follow-up / `NIP-73` is implemented.
   Current status:
   - `src/nip73_external_ids.zig` now provides bounded external-id parse/build/match helpers for
     NIP-73 content ids.
   - `src/nip24_extra_metadata.zig` now extracts generic `i` tags through the shared NIP-73 module.
   - `src/nip22_comments.zig` now reuses the same kind/value matcher for external target
     consistency.
   Evidence:
   - `zig build test --summary all`: `750/750` passed
   - `zig build`: passed
   - rust parity lane: `30/30 HARNESS_COVERED`, `PASS`; `NIP-73` is now `HARNESS_COVERED`,
     `BASELINE`
   - TypeScript parity lane: `29/29 HARNESS_COVERED`, `PASS`
   - `nostr-tools` has no dedicated NIP-73 helper surface; generic tag carriage remains
     compatible
7. Wave 3 / `NIP-06` is implemented, green, and closed.
   Current status:
   - `src/nip06_mnemonic.zig` implements the frozen narrow libwally boundary with strict
     zeroization and typed errors.
   - `zig build test --summary all` and `zig build` remain green after the NIP-06 robustness pass.
   - the fixed review finding from implementation was parent/output key aliasing during child
     derivation; separate key slots are now used.
   Robustness pass outcome:
   - no Layer 1 behavior change was required after real-world review.
   - local coverage now pins null-passphrase and empty-passphrase equivalence explicitly.
   - rust parity overlap is now `HARNESS_COVERED`, `EDGE`, `PASS`.
   - TypeScript audit overlap is now `HARNESS_COVERED`, `EDGE`, `PASS`.
   Accepted temporary normalization boundary:
   - current Phase H behavior accepts ASCII-only mnemonic/passphrase input after UTF-8 validation
     and rejects non-ASCII input with typed `InvalidNormalization`.
   Explicit follow-up:
   - `no-09f` review is complete.
   - `no-2gp` tracks any future full BIP39-compatible NFKD normalization support for non-ASCII
     parity.
7. Post-Wave NIP-51 private-list follow-up `no-e7b` is complete.
   Current status:
   - `src/nip51_lists.zig` now serializes private tag arrays into bounded JSON plaintext.
   - it now extracts private items from decrypted JSON using the same supported-tag semantics as
     public extraction.
   - it now decrypts NIP-44 private list `event.content` directly and rejects legacy `?iv=` NIP-04
     payloads with typed `UnsupportedPrivateEncoding`.
   Robustness pass outcome:
   - no Layer 1 behavior change was required after real-world review.
   - private bookmark JSON extraction now explicitly covers bounded hashtag and URL item handling.
   - rust evidence now includes generic NIP-44 JSON-array roundtrip coverage for private-list
     payloads on top of the existing public-list `NIP-51` builder coverage.
   - TypeScript audit evidence now includes generic NIP-44 JSON-array roundtrip coverage for the
     accepted private-list wire shape even though `nostr-tools` exposes no dedicated private-list
     helper.
   Explicit follow-up:
   - `no-urr` tracks any future deprecated NIP-04 compatibility adapter for private lists.
8. `NIP-44` robustness pass is complete.
   Robustness pass outcome:
   - no Layer 1 behavior change was required after real-world review.
   - the current v2-only surface, staged failure ordering, typed conversation-key boundary, and
     caller-buffer-first encrypt/decrypt helpers remain the accepted kernel posture.
   - existing Rust and TypeScript parity fixtures plus generic deployed
     `getConversationKey` / `encrypt` / `decrypt` surface review were sufficient to keep the API
     unchanged.
9. `NIP-59` robustness pass is complete.
   Robustness pass outcome:
   - no Layer 1 behavior change was required after real-world review.
   - the current staged wrap -> seal -> rumor boundary, verified seal requirement, sender
     continuity enforcement, and typed decrypt/signature failure mapping remain the accepted kernel
     posture.
   - existing Rust and TypeScript wrap/unwrap parity coverage plus source review of the deployed
     helper surfaces were sufficient to keep the API unchanged.
10. Keep `no-3uj` visible as deferred-by-operator until remote setup returns to active execution focus.

## Repo Boundary Note

- Shared-corpus and starter-framework work now lives outside `noztr` and is not part of the
  canonical startup or execution context for this repo.
- Deleted `docs/process/` and `template/` assets should not be treated as active `noztr` inputs.
- Phase H defaults, parity cadence, and current execution order are defined only by the active
  `docs/plans/*`, `docs/guides/*`, and source/test artifacts that still exist in this repo.

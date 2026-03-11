# Phase H Kickoff

Date: 2026-03-10

Purpose: start additional-NIP expansion planning after Phase G local-only closure while preserving
the validated maintenance baseline.

## Baseline

- Phase G local-only release-readiness closure is complete.
- Phase G historical closure evidence remains in:
  - `docs/plans/phase-g-kickoff.md`
  - `docs/plans/phase-f-risk-burndown.md`
- Active parity cadence and aggregate Zig gates remain the same as the completed local baseline.

## Operating Mode

- Active execution state is Phase H kickoff baseline.
- Remote readiness `no-3uj` remains deferred-by-operator and is not part of current execution scope.
- Additional-NIP expansion planning is tracked in `docs/plans/phase-h-additional-nips-plan.md`.
- Wave 1 autonomous execution loop is tracked in `docs/plans/phase-h-wave1-loop.md`.
- NIP-06 dependency strategy is selected: `libwally-core` behind the approved pinned crypto backend
  policy and a narrow boundary module.
- Phase H0 is complete:
  - NIP-06 pin target, one-module boundary, typed failure posture, zeroization set, and vector
    corpus floor are frozen in `docs/plans/phase-h-additional-nips-plan.md`

## Wave 1 Status

- `NIP-25` is complete in the current Wave 1 loop:
  - native kind-7 reaction parsing/helpers implemented in `src/nip25_reactions.zig`
  - strict target semantics use the last `e` tag and last `p` tag, with `e`-tag pubkey fallback
    only when no target `p` tag is present
  - strict custom-emoji validation requires exactly one matching `emoji` tag, a NIP-30-valid
    shortcode, and a URL-shaped image field; malformed, duplicate, or non-custom `emoji` tag usage
    is rejected
  - audit outcome: accepted the optional NIP-30 fourth-slot emoji-set coordinate on reaction
    `emoji` tags while retaining strict shortcode and URL validation as the accepted Layer 1
    posture
  - contradictory optional target metadata across `e`-author, `p`, `a`, and `k` now rejects the
    parse path, and `a` tags are limited to replaceable/addressable kinds
  - optional empty relay-hint fields are normalized to absent rather than treated as a target change
- `NIP-10` is complete in the current Wave 1 loop:
  - strict kind-1 thread/reply helpers implemented in `src/nip10_threads.zig`
  - marked `e` tags support `root` and `reply`; duplicate marked targets are rejected
  - legacy `mention` markers are accepted as explicit mention references instead of failing the
    whole extract path
  - four-slot `e` tags with a valid pubkey in slot four are accepted as bounded compatibility input
    and preserve the author pubkey in `noztr`
  - unmarked `e` tags fall back to positional NIP-10 semantics when no marked tags are present
  - empty relay-hint fields normalize to absent
  - audit outcome: prior strict rejection of removed `mention` and four-slot pubkey fallback was
    judged as unnecessary compatibility loss and corrected during the implemented-NIP audit
- `NIP-18` is complete in the current Wave 1 loop:
  - strict repost helpers implemented in `src/nip18_reposts.zig`
  - kind-6 reposts require a relay-hinted `e` tag
  - kind-16 reposts require either an embedded event payload or an address coordinate
  - when embedded event JSON is present, `e`, `p`, `k`, and `a` tags must match the embedded event
    deterministically rather than being treated as loose hints
  - rust parity harness covers the core kind-6 and kind-16 builder paths
  - addressable repost builder shape was source-reviewed against `rust-nostr` but not split into a
    separate parity-harness case in this pass
  - audit outcome: contradictory optional target metadata now rejects the parse path even without
    embedded-event proof, so empty-content reposts cannot surface impossible `k`/`a`/`p`
    combinations as if they were valid targets
- `NIP-22` is complete in the current Wave 1 loop:
  - strict comment helpers implemented in `src/nip22_comments.zig`
  - comments require one uppercase root target and one lowercase parent target on every event
  - `K` and `k` are mandatory and must match the referenced event, coordinate, or external target
  - Nostr targets require explicit `P` and `p` author linkage; kind-1 text-note targets are
    rejected so NIP-10 remains the reply path for notes
  - address-scoped comments accept a companion concrete `E/e` id and replaceable coordinates may
    carry an empty trailing `d` component
  - external targets validate `I/i` and `K/k` as a consistent NIP-73 pair, and malformed trailing
    fields on linkage tags are rejected
  - rust parity harness now records event, coordinate, external, and parent-only extraction
    behavior; `nostr-tools` provides no dedicated NIP-22 helper beyond the exported kind constant
  - audit outcome: retained as an accepted strict trust-boundary divergence because the current
    parser follows the NIP text and the richer producer-side reference behavior without obvious
    ecosystem breakage
- `NIP-27` is complete in the current Wave 1 loop:
  - strict inline `nostr:` reference extraction implemented in `src/nip27_references.zig`
  - extracted references preserve stable byte spans and decoded profile/event/address NIP-21
    entities
  - malformed, uppercase, forbidden, or payload-empty `nostr:` fragments are ignored as plain text
    rather than failing the whole content scan
  - audit outcome: narrowed inline extraction by dropping `nrelay` as a content reference after
    rust and `nostr-tools` review; malformed-fragment fallback remains unchanged because both
    reference lanes treat those fragments as plain text
  - parity harness covers bracketed references, punctuation boundaries, duplicates, and malformed
    fragment fallback against rust-nostr parser behavior, and `nostr-tools` runtime coverage now
    checks the same baseline cases
- `NIP-51` is complete in the current Wave 1 loop:
  - strict public-list helpers and bounded bookmark/emoji tag builders implemented in
    `src/nip51_lists.zig`
  - supported Wave 1 list kinds are `10000`, `10001`, `10003`, `10004`, `10005`, `10006`,
    `10007`, `10015`, `10030`, `30000`, `30002`, `30003`, `30004`, `30015`, `30030`
  - set kinds require exactly one `d` identifier and may carry one each of `title`, `image`, and
    `description`
  - bookmark and bookmark-set extraction now accepts bounded `e`, `a`, `t`, and `url` items
  - unrelated unknown tags are ignored during list extraction; malformed supported tags still
    return typed failures
  - coordinate-backed list kinds enforce the expected coordinate kind where NIP-51 specifies one
  - `emoji` items accept the optional NIP-30 emoji-set address and validate it as a `30030`
    coordinate when present
  - builder helpers now emit the optional fourth-slot NIP-30 emoji-set coordinate when present
  - private encrypted list content is now covered by dedicated NIP-44-first helpers in
    `src/nip51_lists.zig`; deprecated NIP-04 compatibility is deferred in `no-urr`
  - parity harness now covers all supported rust-backed public-list builders at `DEEP` depth
  - audit outcome: widened bookmark extraction to remove unnecessary incompatibility with broader
    rust producer output while keeping malformed supported-tag rejection and coordinate-kind checks
- Wave 1 status: complete.
- Active next execution focus: post-Wave follow-up prioritization after `no-e7b`, `no-09f`, and
  `no-7lv` closure.
- Implemented-NIP audit status:
  - `NIP-01`, `NIP-02`, `NIP-09`, `NIP-10`, `NIP-11`, `NIP-13`, `NIP-18`, `NIP-19`, `NIP-21`,
    `NIP-22`, `NIP-25`, `NIP-27`, `NIP-40`, `NIP-42`, `NIP-44`, `NIP-51`, `NIP-59`, and `NIP-65`
    audits are complete
  - `NIP-01` now accepts uppercase single-letter `#X` filter keys to match the protocol text and
    reference behavior; unknown filter-field rejection and prefixed rejection-status enforcement are
    retained as accepted Layer 1 trust-boundary behavior
  - `NIP-02` required no Layer 1 change; valid relay-hint and petname shapes were already accepted,
    and the current strict contact-tag extraction remains acceptable on the evidence gathered in
    this pass
  - `NIP-09` now rejects `a` delete targets that are syntactically shaped like coordinates but do
    not satisfy the NIP-01 replaceable/addressable coordinate rules
  - `NIP-11` required no Layer 1 change; the current bounded partial relay-information surface
    remains acceptable, and the audit now pins a full-spec-shaped compatibility vector so broader
    relay documents continue to preserve the supported subset
  - `NIP-13` required no Layer 1 change; the current PoW helper already keeps the full `0..256`
    difficulty domain and the checked-ID trust-boundary entry point, which the audit keeps as an
    accepted Zig-native improvement over narrower helper typing in the Rust reference
  - `NIP-19` now accepts empty-identifier `naddr` values for normal replaceable coordinates during
    both encode and decode, matching the NIP text and both reference lanes instead of rejecting the
    valid replaceable-address shape
  - `NIP-21` required no separate Layer 1 change; the audit now explicitly covers replaceable
    `nostr:naddr...` URIs with empty identifiers so the inherited NIP-19 compatibility fix is
    pinned at the URI layer as well
  - `NIP-40` now treats malformed expiration metadata as absent and uses the first valid
    `expiration` tag deterministically, matching both reference lanes instead of surfacing optional
    malformed metadata as helper-level typed failures
  - `NIP-44` required no Layer 1 change; the current v2-only cryptographic surface, staged failure
    ordering, fixture coverage, and checked conversation-key/decode/decrypt boundaries remain
    aligned with both reference lanes
  - `NIP-59` required no Layer 1 change; the current staged wrap->seal->rumor unwrap boundary,
    sender continuity enforcement, unsigned-rumor requirement, and typed decrypt/signature failure
    mapping remain aligned with the protocol and both reference lanes
  - `NIP-65` now ignores unrelated foreign tags during relay extraction while keeping malformed
    supported `r` tags, malformed relay URLs, and invalid markers as typed failures; this matches
    the accepted posture of staying deterministic and bounded without turning irrelevant metadata
    into whole-helper incompatibility
  - `NIP-70` required no Layer 1 change; the current exact one-item `["-"]` protected-tag
    semantics already match the NIP and both reference lanes, while malformed lookalikes remain
    safely ignored rather than being treated as canonical protection markers
  - `NIP-50` now treats malformed extension-like tokens as ordinary bounded search text and parses
    supported `key:value` extensions best-effort; this matches the NIP's best-effort search model
    and both reference lanes instead of rejecting whole queries for malformed extension syntax
  - `NIP-45` now accepts uppercase HLL hex and ignores unknown COUNT metadata keys, matching the
    protocol's forward-compatible shape better than the old strict relay-response parser
  - `NIP-77` now accepts `NEG-ERR` reasons with `:` and optional spaces and allows bounded
    negentropy session reopen on a reused state object, matching the NIP text more closely than the
    old stricter state/reason rules
  - Implemented-NIP audit status: complete
  - `NIP-18` now rejects contradictory optional repost target metadata without embedded-event proof;
    existing embedded-event consistency checks remain intact
  - `NIP-25` now accepts the optional NIP-30 emoji-set coordinate on reaction `emoji` tags; strict
    shortcode and URL validation remain intact, and contradictory optional target metadata now
    rejects the parse path
  - `NIP-27` no longer extracts `nostr:nrelay...` as an inline content reference; malformed,
    uppercase, forbidden, and payload-empty fragments still fall back to plain text
  - `NIP-42` widened the auth challenge bound from `64` to `255` after reference review; remaining
    path-bound websocket origin strictness is retained
  - `NIP-51` widened bookmark extraction to accept bounded hashtag/URL items and now ignores
    unrelated unknown tags
  - `NIP-51` now supports bounded private-list JSON serialization and NIP-44 private-item
    extraction while rejecting deprecated legacy `?iv=` payloads pending `no-urr`
- Wave 2 / `NIP-46` is complete in `no-czg`
  - bounded `src/nip46_remote_signing.zig` surface is implemented
  - current implemented scope:
    - method parsing for `connect`, `sign_event`, `ping`, `get_public_key`,
      `nip04_encrypt`, `nip04_decrypt`, `nip44_encrypt`, `nip44_decrypt`,
      and `switch_relays`
    - permission token parsing/formatting, including `sign_event:<kind>` and bounded
      raw future-method scopes
    - JSON parse/compose for request and response payloads with typed validation
    - current-spec `bunker://` and `nostrconnect://` URI parse/compose
    - strict kind-24133 event-envelope validation with exact single-`p` targeting and
      NIP-44 payload framing validation
    - explicit `result: null` preservation for valid `switch_relays` responses instead of
      collapsing `null` into an omitted result field
    - typed parsed-request helpers for `connect`, `sign_event`, the current
      pubkey-plus-text methods, and zero-param commands
    - direct typed request builders for `connect`, `sign_event`, the current
      pubkey-plus-text methods, and zero-param commands
    - typed result helpers for `connect`, `get_public_key`, `sign_event`, and
      `switch_relays`
    - appendix discovery helpers for `nostr.json?name=_` NIP-46 discovery data and
      kind-`31990` NIP-89 remote-signer events
    - signer `nostr.json` discovery accepts both the current `nip46.relays` shape and the older
      deployed pubkey-keyed relay map used by `nostr-tools`
  - parity/evidence status:
    - rust parity overlap is now `HARNESS_COVERED`, `BASELINE`, `PASS`
    - TypeScript audit overlap is now `HARNESS_COVERED`, `BASELINE`, `PASS`
    - current intentional divergence: pinned `rust-nostr` still uses the older
      `metadata=` client-URI shape and lacks `switch_relays`, while `noztr` and
      `nostr-tools` follow the current split-query URI and method surface
  - accepted out-of-scope:
    - `nostrconnect_url` placeholder expansion or redirect/template rendering remains app-flow
      logic and is intentionally outside the protocol-kernel helper surface (`D-053`)
- Wave 3 / `NIP-06` is implemented and closed in `no-7lv`
  - `src/nip06_mnemonic.zig` now implements the frozen narrow boundary:
    - English mnemonic validation
    - mnemonic plus optional passphrase to 64-byte seed
    - canonical `m/44'/1237'/<account>'/0/0` secret-key derivation
  - pinned vector/evidence status:
    - official BIP39 seed vectors covered
    - both official NIP-06 vectors covered
    - pinned rust-nostr extra mnemonic vector covered
    - fixed `account = 1` derivation vector covered
    - invalid matrix covers malformed length, unknown word, checksum mismatch, invalid UTF-8,
      invalid seed boundary, invalid account, and buffer-too-small failures
  - review finding fixed during implementation:
    - child derivation now uses separate parent/child key slots; aliasing libwally parent/output
      buffers caused a real higher-account derivation failure and is no longer allowed
  - accepted temporary normalization boundary:
    - current Phase H behavior accepts ASCII-only mnemonic/passphrase input after UTF-8 validation
      and rejects non-ASCII input with typed `InvalidNormalization`
    - `no-09f` review is complete: full BIP39-compatible NFKD normalization remains future
      feature `no-2gp`, not immediate kernel scope

## Immediate Work Tracks

- Maintain rust-active parity cadence and aggregate Zig quality gates on dependency/toolchain changes.
- Keep Wave 1 closure evidence current and retain the serial loop doc as the canonical execution
  model.
- Keep the implemented-NIP audit report current if future code changes reopen compatibility
  questions.
- `no-4iw` is resolved by the NIP-10 audit and no longer blocks interpretation of NIP-10 quality.
- Keep TypeScript parity references non-gating and use them only as secondary ecosystem audit
  evidence.
- Keep the accepted ASCII-only NIP-06 normalization boundary in place; any future full Unicode
  NFKD expansion is tracked in `no-2gp`.

## Blocker Visibility

- `no-3uj` remains visible for git/Dolt remote + sync readiness.
- Operator note: remote readiness remains deferred and is not a Phase H blocker.

# Implemented NIP Audit Report

Date: 2026-03-16

Purpose: provide one canonical review artifact for the autonomous implemented-NIP audit so
findings, accepted risks, decision points, and follow-up items can be reviewed systematically
after the audit completes. This report now also absorbs the single post-audit requested-NIP loop
so those later surfaces do not live in a second partial audit artifact.

## Scope

- This report covers the implemented NIPs in `noztr`.
- It summarizes audit conclusions after the per-NIP evidence is gathered in beads issues.
- It does not replace raw evidence in beads or canonical policy decisions in
  `docs/plans/decision-log.md`.
- The 2026-03-16 supplement folds the later requested-loop closures for `47`, `49`, `64`, `88`,
  `98`, `B7`, and `C0` back into this canonical report.

## Evidence Sources

- relevant NIP text
- current `noztr` code and tests
- `rust-nostr` harness/source behavior
- `nostr-tools` harness/source behavior for every implemented NIP
- existing in-repo ecosystem notes and intentional-divergence records

## Review Standard

- Judge each NIP against the canonical review axes and lenses in
  `docs/plans/implemented-nip-review-guide.md`.
- `rust-nostr` is the active parity lane and strongest production reference.
- `nostr-tools` is a secondary non-gating ecosystem signal.
- No reference library is treated as protocol authority.

## Audit Status

| NIP | Status | Rust Evidence | TS Evidence | Findings | Decision Points | Follow-ups | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Accepted uppercase single-letter `#X` filter keys; retained unknown filter-field rejection and prefixed rejection-status enforcement as accepted trust-boundary behavior | none | none | NIP-01 allows `a-zA-Z` tag-filter keys, and both reference lanes support uppercase matching; current unknown-field and status-prefix strictness remains more policyful but still spec-defensible |
| 02 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED BASELINE PASS` | No Layer 1 change required; valid relay-hint and petname shapes are already accepted | none | none | `rust-nostr` builders emit canonical `p` tags with optional relay and alias, but the available reference extraction surfaces are generic tag iterators rather than a dedicated strict contact-list helper |
| 03 | complete | `HARNESS_COVERED BASELINE PASS` | `HARNESS_COVERED BASELINE PASS` | No further Layer 1 change required after the bounded local proof-floor work and the deployed long-form `e`-tag compatibility fix | none | none | The current helper now covers exact target extraction, bounded proof decode, bounded local proof verification, and accepted long-form `e` tags; deeper networked Bitcoin / OpenTimestamps verification remains intentionally SDK-side |
| 05 | complete | `HARNESS_COVERED BASELINE PASS` | `HARNESS_COVERED BASELINE PASS` | Accept and canonicalize uppercase local-parts while keeping the exact NIP character set and bounded `names` / `relays` / `nip46` extraction unchanged | none | none | The NIP constrains the allowed local-part characters, but deployed libraries treat casing more loosely; canonical lowercase lookup/output preserves determinism without widening into unsupported `+`-style identifier grammar |
| 09 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED BASELINE PASS` | Tightened `a`-target deletion parsing so only valid replaceable/addressable coordinates are accepted | none | none | `rust-nostr` models delete coordinates through the NIP-01 coordinate type; TS coverage remains baseline builder/tag-shape signal only in this pass |
| 10 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Removed unnecessary rejection of legacy `mention`; removed unnecessary rejection of four-slot pubkey fallback | none | `no-4iw` closed | `noztr` now preserves four-slot author pubkey; `nostr-tools` accepts the shape but drops author |
| 11 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | No Layer 1 change required; current bounded partial-document parse remains acceptable and now has an explicit full-spec-shaped compatibility vector | none | none | `noztr` intentionally exposes a typed subset of relay-info fields, but it ignores additional NIP-11 fields without disturbing the supported subset; both reference lanes tolerate the broader document shape |
| 13 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | No Layer 1 change required; current PoW helper already preserves the full `0..256` difficulty domain and trust-boundary checked-ID entry point | none | none | `rust-nostr` remains the stronger runtime reference for normal PoW checks, but its standalone leading-zero helper is typed as `u8`; `noztr` keeps the full `256`-bit edge, and `nostr-tools` runtime evidence confirms the broader domain |
| 17 | complete | `HARNESS_COVERED BASELINE PASS` | `HARNESS_COVERED BASELINE PASS` | No further Layer 1 change required after accepting long-form reply `e` tags and adding the bounded kind-15 file-message surface | none | none | The current helper remains protocol-kernel glue: bounded parse/build/unwrap reuse and relay-list extraction, with mailbox sync and delivery workflow still left to the SDK |
| 18 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Reject contradictory repost target metadata without embedded-event proof; retained existing embedded-event consistency checks and kind-6 relay-hint requirement | none | none | `rust-nostr` builders already emit coherent repost metadata and add `a` only for coordinate-capable targets; `nostr-tools` runtime coverage now confirms kind-6/kind-16 builder behavior and protected-event empty-content handling |
| 19 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Accepted empty-identifier `naddr` encode/decode for normal replaceable coordinates | none | none | NIP-19 explicitly allows empty `d` for replaceable coordinates; both reference lanes roundtrip that shape, so the prior rejection was unnecessary incompatibility |
| 21 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | No separate Layer 1 change required; explicit replaceable-`naddr` URI coverage now pins the inherited NIP-19 compatibility fix | none | none | Current strict scheme/entity rejection remains justified; the audit mainly needed to confirm that valid empty-identifier `naddr` URIs now roundtrip cleanly through the URI layer |
| 22 | complete | `HARNESS_COVERED DEEP PASS` | `SOURCE_REVIEW_ONLY no dedicated NIP-22 helper beyond kind constant` | No Layer 1 change required; current root/parent, `K/k`, `P/p`, and kind-1 rejection posture remains justified | none | none | `rust-nostr` emits canonical full linkage when given a root target but still extracts parent-only / optional-kind shapes; `noztr` keeps the stricter trust-boundary contract |
| 23 | complete | `HARNESS_COVERED BASELINE PASS` | `HARNESS_COVERED BASELINE PASS` | Enforce lowercase hashtag semantics on long-form `t` tags during both build and extract; other metadata handling remains unchanged | none | none | NIP-23 relies on ordinary hashtag tags for topics; the Rust reference already builds canonical lowercase hashtags, so accepting uppercase on build/extract was avoidable drift from the broader tag contract |
| 24 | complete | `HARNESS_COVERED BASELINE PASS` | `HARNESS_COVERED BASELINE PASS` | Enforce lowercase generic `t` hashtag parsing so the helper matches its own builder and the NIP’s tag rule | none | none | The builder already rejected uppercase hashtags, but the parser had still accepted them; aligning those two sides removes a local contract mismatch without broadening the helper surface |
| 25 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Accepted the optional NIP-30 fourth-slot emoji-set coordinate on reaction `emoji` tags; retained strict shortcode and URL validation; now reject contradictory optional target metadata and unsupported `a` kinds | none | none | `rust-nostr` remains permissive on shortcode text and still standardizes only three-slot emoji tags; `nostr-tools` aligns on last-`e`/last-`p` target selection and strict shortcode matching |
| 26 | complete | `LIB_UNSUPPORTED BASELINE PASS` | `LIB_UNSUPPORTED BASELINE PASS` | No Layer 1 change required; the current canonical `delegation` tag, bounded condition grammar, deterministic message/signature flow, and event-field validation remain the accepted kernel scope | none | none | Neither active reference lane exposes a dedicated NIP-26 helper surface, so this remains a spec-first kernel helper reviewed mainly against the NIP text and generic Schnorr/tag behavior |
| 27 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Narrowed inline extraction to profile/event/address references by dropping `nrelay` as a NIP-27 content reference; retained ignore-as-plain-text fallback for malformed, uppercase, forbidden, and payload-empty fragments | none | none | `rust-nostr` and `nostr-tools` both treat malformed and forbidden fragments as plain text; neither treats `nrelay` as an inline content reference in this pass |
| 29 | complete | `SOURCE_REVIEW_ONLY no dedicated rust-nostr helper surface` | `HARNESS_COVERED BASELINE PASS` | Accepted deployed three-slot `h` tags with optional relay hints and optional compatibility labels on admin `p` tags; reducer now ignores labels for role state and builders can emit the broader ecosystem admin shape when asked | none | none | The NIP text only requires the `h` value, but deployed group tooling carries an extra relay hint and labeled admin tags; label-aware moderation policy remains intentionally out of scope, so the kernel treats the label as optional metadata and keeps state reduction focused on pubkeys plus roles |
| 32 | complete | `HARNESS_COVERED BASELINE PASS` | `HARNESS_COVERED BASELINE PASS` | Enforce lowercase hashtag targets on NIP-32 `t` labels; other namespace/label/target handling remains unchanged | none | none | The active references already treat lowercase hashtags as canonical standardized `t` tags; tightening the label helper here removes needless drift without changing namespace or target scope |
| 36 | complete | `HARNESS_COVERED BASELINE PASS` | `HARNESS_COVERED BASELINE PASS` | No Layer 1 change required; current first-tag extraction, empty-reason normalization, and exact NIP-32 namespace/label bridge remain acceptable | none | none | Both reference lanes expose generic tag behavior rather than a dedicated strict helper; the current bounded surface matches the NIP’s simple optional-reason shape without adding unnecessary policy |
| 37 | complete | `LIB_UNSUPPORTED BASELINE PASS` | `LIB_UNSUPPORTED BASELINE PASS` | Strengthened the minimum draft-event validation floor so encrypted/decrypted draft JSON must now include at least `kind`, `tags`, and `content`, and tightened private relay-list helpers to websocket relay URLs instead of generic HTTP-style URLs | none | none | No dedicated helper exists in the active reference lanes; this remains a spec-first kernel helper, but the prior “any object” draft floor and generic-URL relay acceptance were both too broad for the module’s accepted contract |
| 39 | complete | `HARNESS_COVERED BASELINE PASS` | `HARNESS_COVERED BASELINE PASS` | No Layer 1 scope change required; claim parsing, canonical `i` tags, proof URL derivation, and expected proof text remain accepted deterministic helper glue, and overlong identity/proof builder inputs now fail on typed validation paths instead of leaking `BufferTooSmall` | none | none | `identity_claim_build_proof_url(...)` and `identity_claim_build_expected_text(...)` remain the clearest borderline kernel helpers, but they stay accepted under `D-076` until `nzdk` grows provider adapters that make them redundant |
| 40 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Malformed expiration metadata no longer hard-fails the helper path; the first valid expiration tag now wins deterministically | none | none | `rust-nostr` and `nostr-tools` both treat malformed expiration data as non-expiring rather than exceptional; the previous typed-error path created unnecessary compatibility friction for advisory metadata |
| 42 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Widened NIP-42 challenge bound from `64` to `255`; retained path-bound websocket origin matching, duplicate-tag rejection, and unbracketed IPv6 rejection | none | none | `rust-nostr` and `nostr-tools` both accept long challenges; current remaining strictness is judged trust-boundary-positive rather than ecosystem-hostile |
| 44 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED DEEP PASS` | No Layer 1 change required; current NIP-44 v2 surface remains aligned on vectors, staged failure order, and checked cryptographic boundaries | none | none | The audit found no unjustified strictness: unsupported `#` encoding, version-before-MAC ordering, MAC-before-padding ordering, and invalid-UTF8-as-invalid-padding all remain bounded and compatible |
| 45 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Uppercase HLL hex now validates and unknown COUNT metadata keys are ignored instead of rejecting the whole response | none | none | NIP-45 says `hll` is hex-encoded and leaves room for optional relay metadata; both reference lanes tolerate forward-compatible COUNT metadata better than the old strict parser |
| 46 | complete | `HARNESS_COVERED BASELINE PASS` | `HARNESS_COVERED BASELINE PASS` | No Layer 1 change required; current message/URI/envelope/discovery surface remains compatible, and deterministic `<nostrconnect>` template substitution stays accepted under the refined kernel boundary | none | none | The current helper stays on the protocol-data side of the boundary: parse/validate/build/discovery/template substitution in `noztr`, while relay/session/auth/orchestration remains SDK work |
| 50 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Malformed extension-like search tokens no longer invalidate the helper path; supported tokens are now extracted best-effort from bounded UTF-8 search text | none | none | NIP-50 frames `search` as a human-readable string and says unsupported extensions should be ignored; both reference lanes treat malformed extension-like text as ordinary searchable text rather than invalid input |
| 51 | complete | `HARNESS_COVERED DEEP PASS` | `SOURCE_REVIEW_ONLY no dedicated NIP-51 helper beyond kind constants` | Widened bookmark extraction to accept bounded hashtag/URL items and changed unrelated unknown tags from fatal to ignored; kept typed failures for malformed supported tags and coordinate-kind enforcement | none | none | `rust-nostr` bookmark builders were broader than the old parser; `nostr-tools` provides kind-level signal only in this pass |
| 56 | complete | `HARNESS_COVERED BASELINE PASS` | `HARNESS_COVERED BASELINE PASS` | No Layer 1 change required; current required `p` target, bounded `e` / `x` / `server` extraction, and optional `p` report-type handling remain acceptable for the kernel helper surface | none | none | The active reference lanes mainly provide builder/tag-shape signal here; the current helper stays intentionally bounded around one parsed pubkey target plus optional event/blob/server context rather than becoming a moderation-policy layer |
| 57 | complete | `LIB_UNSUPPORTED BASELINE PASS` | `LIB_UNSUPPORTED BASELINE PASS` | No further Layer 1 change required after requiring signed zap requests for receipt `description`, validating receipt signatures during receipt validation, and keeping the bounded request/receipt target-continuity surface unchanged in this pass | none | none | The current kernel slice stays intentionally protocol-boundary-only: bounded zap request/receipt parse/build/validate in `noztr`, with LNURL/invoice/payment workflow left to the SDK |
| 58 | complete | `HARNESS_COVERED BASELINE PASS` | `LIB_UNSUPPORTED BASELINE PASS` | Tightened profile-badge extraction so `a`/`e` pairs must be truly consecutive; intervening unrelated tags now break the pending pair instead of being silently bridged | none | none | The NIP explicitly says profile badges are ordered consecutive pairs and unmatched `a`/`e` should be ignored; the earlier bridging behavior was a real spec mismatch |
| 59 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | No Layer 1 change required; current staged wrap->seal->rumor validation remains justified and compatible | none | none | Wrap-kind, signed-seal, unsigned-rumor, sender-continuity, and decrypt-failure boundaries all match the protocol intent; the audit found no evidence-backed relaxation that would improve compatibility without weakening trust checks |
| 65 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED BASELINE PASS` | Ignore unrelated foreign tags during relay extraction while keeping malformed `r` relay tags strict | none | none | `rust-nostr` extraction tolerates surrounding non-relay tags and yields only valid relay entries; `nostr-tools` remains builder-only signal in this pass |
| 70 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | No Layer 1 change required; exact one-item `["-"]` protected-tag semantics remain correct and compatible | none | none | The NIP and both reference lanes treat only the exact single-item `["-"]` tag as protected; malformed lookalikes remain safely ignored |
| 73 | complete | `HARNESS_COVERED BASELINE PASS` | `NOT_COVERED_IN_THIS_PASS` | No Layer 1 change required in this pass; current external-id parsing remains intentionally broader than the NIP normalization table pending stronger ecosystem evidence, and malformed blockchain value inputs now stay on the `InvalidValue` path instead of leaking `InvalidKind` | none | none | The NIP text specifies normalized forms for several IDs, but the strongest production reference lane is also broad here; tightening now would be a compatibility-policy change rather than a clear bug fix, so the kernel keeps the current bounded parser for now |
| 77 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | NEG-ERR reasons now accept the spec-required `:` delimiter without requiring a following space, and session state now allows bounded reopen on a reused state object | none | none | The prior `\": \"` requirement and idle-only reopen rule were stricter than the NIP text; both changes preserve boundedness while reducing protocol friction |
| 84 | complete | `LIB_UNSUPPORTED BASELINE PASS` | `LIB_UNSUPPORTED BASELINE PASS` | Accepted the valid three-item highlight-attribution `p` shape where the third slot is a role and no relay hint is present; this fixes a builder/parser mismatch in the module itself | none | none | Neither active reference lane exposes a dedicated NIP-84 helper; the NIP text allows a role as the last value, so accepting `["p", pubkey, role]` keeps the kernel deterministic and more interoperable than the previous parser |
| 86 | complete | `LIB_UNSUPPORTED BASELINE PASS` | `LIB_UNSUPPORTED BASELINE PASS` | No Layer 1 scope change required; serializer invalid-text handling now returns `InvalidText` instead of leaking `BufferTooSmall`, and the bounded request/response surface otherwise remains acceptable on the kernel side of the boundary | none | none | The kernel owns JSON-RPC payload parsing/building and typed admin method shapes; NIP-98 auth, HTTP transport, operator workflow, and relay policy remain outside the kernel |
| 92 | complete | `LIB_UNSUPPORTED BASELINE PASS` | `LIB_UNSUPPORTED BASELINE PASS` | Accepted bounded per-`imeta` parse/build/validate, exact URL-in-content matching, and NIP-94 field reuse for supported metadata semantics; no further Layer 1 change required after the initial implementation and review passes | none | none | Neither active reference lane exposes a dedicated NIP-92 helper; applesauce remains secondary ecosystem evidence for the pair grammar and field semantics |
| 94 | complete | `HARNESS_COVERED BASELINE PASS` | `LIB_UNSUPPORTED BASELINE PASS` | Accepted bounded kind-`1063` parse/build/validate with required `url` / lowercase MIME / `x`, exact supported-tag shapes, and repeated fallback support; no further Layer 1 change required after the initial implementation and review passes | none | none | Rust provides generic file-metadata support while `nostr-tools` remains a non-dedicated audit signal here; the current helper stays deterministic and metadata-only |
| 99 | complete | `LIB_UNSUPPORTED BASELINE PASS` | `LIB_UNSUPPORTED BASELINE PASS` | Tightened `d` so listing identifiers must be scheme-less URL-shaped values rather than generic non-empty UTF-8, while keeping the bounded metadata-only surface for `30402` / `30403` unchanged otherwise | none | none | Neither active reference lane exposes a dedicated NIP-99 helper, so the stronger identifier rule is spec-first and keeps addressable listing metadata deterministic without pulling commerce workflow into the kernel |
| B0 | complete | `LIB_UNSUPPORTED BASELINE PASS` | `LIB_UNSUPPORTED BASELINE PASS` | Accepted bounded kind-`39701` parse/build helpers with required scheme-less `d`, optional `title` / `published_at`, ordered lowercase `t` hashtags, and ignored unrelated tags; no further Layer 1 change required after Review A/B | none | none | Neither active reference lane exposes a dedicated NIP-B0 helper; the accepted surface stays metadata-only and leaves bookmark sync/browser workflow outside the kernel |
| 47 | complete | `HARNESS_COVERED BASELINE PASS` | `NOT_COVERED_IN_THIS_PASS applesauce lane unavailable locally` | Overlong direct token input now stays on typed `InvalidCapability` / `InvalidEncryptionTag` / `InvalidNotificationsTag` / `InvalidErrorObject` / `InvalidTransaction` paths, and direct error/transaction token parsers no longer reuse unrelated error variants | none | none | Requested-loop supplement: the accepted split surface stays on deterministic NWC URI handling, event-envelope extraction, and typed decrypted JSON contracts; relay, encryption, and wallet workflow remain SDK-side |
| 49 | complete | `SOURCE_REVIEW_ONLY fixed-payload parity lane` | `SOURCE_REVIEW_ONLY fixed-payload parity lane` | No further Layer 1 change required; current `ncryptsec` payload framing, bounded `NFKC` normalization, typed `log_n` / key-security handling, and caller-scratch `scrypt` surface remain acceptable after the checksum-path review fixes | none | none | Requested-loop supplement: `rust-nostr` and vendored `nostr-tools` align on `NFKC`, `scrypt`, XChaCha20-Poly1305, and the fixed versioned payload shape; password UX and storage policy remain out of scope |
| 64 | complete | `LIB_UNSUPPORTED BASELINE PASS` | `LIB_UNSUPPORTED BASELINE PASS` | No further Layer 1 change required; the structural PGN validator remains accepted after Review A closed the nonsense-token and separator-discipline bugs | none | none | Requested-loop supplement: the accepted surface stays on bounded PGN structure with optional `alt` metadata and keeps move legality, replay, rendering, and engine workflow out of the kernel |
| 88 | complete | `SOURCE_REVIEW_ONLY dedicated builder lane only` | `SOURCE_REVIEW_ONLY getter/compose lane only` | No further Layer 1 change required; poll/response parse-build helpers and the pure tally reducer remain accepted, and latest malformed same-poll responses no longer leave older valid votes counted | none | none | Requested-loop supplement: the accepted surface stays on deterministic poll metadata and pure tally reduction; relay fetches, live refresh, curation, and publish UX remain outside the kernel |
| 98 | complete | `SOURCE_REVIEW_ONLY dedicated helper lane with accepted deltas` | `SOURCE_REVIEW_ONLY helper lane with accepted deltas` | Overlong caller URL/method/payload input now stays on typed `InvalidUrl*` / `InvalidMethod*` / `InvalidPayload*` paths, and the strict auth-event/header surface otherwise remains accepted | none | none | Requested-loop supplement: the accepted split surface stays on deterministic auth-event extraction, exact request matching, lowercase payload hashing, and strict header encode/decode while HTTP middleware and session workflow remain outside the kernel |
| B7 | complete | `LIB_UNSUPPORTED BASELINE PASS` | `SOURCE_REVIEW_ONLY weak supporting lane` | No further Layer 1 change required; server-list and fallback helpers remain accepted after Review A closed path-only hash scanning and oversized invalid-input error-contract bugs | none | none | Requested-loop supplement: the accepted split surface stays on ordered `kind:10063` server lists plus deterministic fallback derivation; Blossom fetch, upload, cache, and retrieval workflow remain outside the kernel |
| C0 | complete | `SOURCE_REVIEW_ONLY dedicated builder lane only` | `SOURCE_REVIEW_ONLY getter/cast lane only` | No further Layer 1 change required; the metadata-only helper remains accepted after Review A closed lowercase `l` canonicalization and overlong builder-input error-contract bugs | none | none | Requested-loop supplement: the accepted surface stays on deterministic code-snippet metadata, repeated license/dependency extraction, and validated repository references without absorbing editor or execution workflow |

## Decision Summary

- NIP-01: accept uppercase single-letter `#X` filter keys to match the NIP text and reference
  library behavior, while retaining unknown filter-field rejection and prefixed rejection-status
  enforcement as accepted Layer 1 trust-boundary behavior.
- NIP-02: no Layer 1 change required; current contact extraction already accepts the valid relay
  hint and petname shapes called for by the NIP, and current stricter whole-tag validation remains
  acceptable on the evidence gathered in this pass.
- NIP-03: no further Layer 1 change required; keep the current bounded attestation-event surface,
  long-form `e`-tag compatibility, and local proof-verification floor, while leaving networked
  OpenTimestamps / Bitcoin verification to the SDK.
- NIP-05: accept and canonicalize uppercase local-parts for lookup/output while keeping the exact
  NIP character set and bounded document extraction unchanged.
- NIP-09: reject syntactically valid but semantically invalid `a` delete targets by enforcing the
  NIP-01 replaceable/addressable coordinate rules during delete-target extraction.
- NIP-10: accept legacy `mention` tags as explicit mentions in thread extraction instead of failing
  the helper on that input.
- NIP-10: accept four-slot `e` tags with a valid slot-four pubkey as bounded compatibility input
  instead of rejecting the whole extract path.
- NIP-11: no Layer 1 change required; keep the bounded partial relay-information surface, but
  preserve compatibility with full spec-shaped documents by ignoring unmodeled fields cleanly.
- NIP-13: no Layer 1 change required; keep the current checked-ID trust-boundary API and the full
  `0..256` difficulty domain instead of mirroring narrower helper typing from the Rust reference.
- NIP-17: no further Layer 1 change required; keep the bounded kind-14 / kind-15 parse/build and
  unwrap-reuse surface in the kernel, with mailbox / delivery orchestration still left to the SDK.
- NIP-19: accept empty-identifier `naddr` values for normal replaceable coordinates during both
  encode and decode instead of rejecting them as malformed.
- NIP-21: no separate Layer 1 change required; keep the current strict URI parser while pinning
  replaceable-`naddr` URI compatibility through explicit coverage.
- NIP-40: treat malformed expiration metadata as absent and use the first valid expiration tag
  deterministically instead of failing the helper path on malformed or conflicting optional tags.
- NIP-44: no Layer 1 change required; keep the current v2-only checked cryptographic surface and
  staged failure ordering.
- NIP-59: no Layer 1 change required; keep the current staged unwrap trust boundary and sender
  continuity checks.
- NIP-65: ignore unrelated foreign tags during relay extraction, while keeping malformed supported
  `r` tags, malformed relay URLs, and invalid markers as typed failures.
- NIP-70: no Layer 1 change required; keep exact one-item `["-"]` protected-tag semantics and
  ignore malformed lookalike tags.
- NIP-50: treat malformed extension-like tokens as raw search text and extract supported
  `key:value` extensions best-effort instead of invalidating the whole search helper path.
- NIP-45: accept uppercase HLL hex and ignore unknown COUNT metadata keys instead of rejecting the
  whole relay response.
- NIP-46: no Layer 1 change required; keep the current message/URI/envelope/discovery surface plus
  deterministic `<nostrconnect>` template substitution in the kernel, while leaving signer session
  orchestration, auth flow, and relay control to the SDK.
- NIP-77: accept `NEG-ERR` reason strings with `:` and optional space, and allow bounded session
  reopen on reused negentropy state.
- NIP-18: reject contradictory repost target metadata when empty-content reposts cannot prove the
  target via embedded JSON, while retaining current embedded-event consistency checks and the kind-6
  relay-hint requirement.
- NIP-22: keep strict root/parent scope, mandatory `K/k`, mandatory `P/p` for Nostr targets, and
  kind-1 rejection; `rust-nostr` permissive extraction is treated as a compatibility signal, not a
  reason to weaken the Layer 1 parser.
- NIP-23: enforce lowercase hashtag semantics on long-form `t` tags during both build and extract.
- NIP-24: enforce lowercase generic `t` hashtag parsing so the helper matches its own builder and
  the NIP’s tag rule.
- NIP-25: accept the optional NIP-30 emoji-set address on reaction `emoji` tags, while keeping
  strict shortcode and image-URL validation, and reject contradictory `e`/`p`/`a`/`k` target
  metadata plus unsupported `a` kinds.
- NIP-26: no Layer 1 change required; keep the current canonical `delegation` tag, bounded
  condition grammar, deterministic message/signature flow, and event-field validation as the
  accepted kernel surface.
- NIP-27: narrow strict inline reference extraction to the event/profile/address entities actually
  treated as content references in the current spec/examples and major reference libraries, while
  keeping malformed-fragment fallback as plain text.
- NIP-29: accept deployed three-slot `h` tags with optional relay hints and optional compatibility
  labels on admin `p` tags, while keeping state reduction focused on pubkeys plus roles and only
  emitting the broader labeled admin shape when a caller explicitly asks for it.
- NIP-32: enforce lowercase hashtag targets on NIP-32 `t` labels while keeping the rest of the
  namespace/label/target surface unchanged.
- NIP-36: no Layer 1 change required; keep the current first-tag extraction, empty-reason
  normalization, and exact NIP-32 namespace/label bridge.
- NIP-39: keep claim parsing plus deterministic proof-URL / expected-text helpers in the kernel for
  now under `D-076`, leave live provider fetch verification to the SDK, and keep overlong
  identity/proof builder inputs on typed `InvalidIdentity` / `InvalidProof` paths rather than
  surfacing `BufferTooSmall`.
- NIP-42: widen the challenge bound to `255` bytes, but keep path-bound websocket origin matching,
  duplicate required-tag rejection, and unbracketed IPv6 rejection as accepted trust-boundary
  behavior.
- NIP-51: accept bounded hashtag/URL bookmark items and ignore unrelated unknown tags during
  extraction, while keeping typed rejection for malformed supported tags.
- NIP-56: no Layer 1 change required; keep the current bounded report helper surface centered on
  one required `p` target plus optional event/blob/server context instead of broadening it into a
  moderation-policy or multi-target aggregation layer.
- NIP-57: no Layer 1 change required; keep the current bounded zap helper surface centered on
  signed request/receipt validation and propagated target continuity, while leaving LNURL,
  invoice, payment, and wallet workflow to the SDK.
- NIP-73: no Layer 1 change required in this pass; keep the current broader external-id parser,
  but keep malformed blockchain value inputs on the `InvalidValue` path instead of leaking
  `InvalidKind`.
- NIP-86: keep the current bounded admin request/response payload contract in the kernel, but make
  invalid serializer text fail as `InvalidText` instead of `BufferTooSmall`; NIP-98 auth,
  transport, and operator workflow remain outside it.
- NIP-92: no further Layer 1 change required; keep the current bounded per-`imeta`
  parse/build/validate surface plus exact URL-in-content matching and accepted NIP-94 field reuse.
- NIP-94: no further Layer 1 change required; keep the current bounded kind-`1063`
  parse/build/validate surface with required lowercase MIME and exact supported-tag shapes.
- NIP-99: require `d` to be a scheme-less URL-shaped identifier instead of generic non-empty UTF-8,
  while keeping the current bounded metadata-only listing helper surface.
- NIP-B0: keep the current bounded kind-`39701` helper with required scheme-less `d`, optional
  `title` / `published_at`, ordered lowercase `t` hashtags, and no bookmark workflow in-kernel.
- Requested-loop supplement:
- NIP-47: keep the split kernel surface for deterministic NWC URI handling, bounded event-envelope
  extraction, and typed decrypted JSON contracts, and keep direct token-parser failures on
  semantically correct typed errors instead of unrelated variants or debug assertions.
- NIP-49: no further Layer 1 change required; keep the current bounded `ncryptsec` payload,
  internal `NFKC`, typed `log_n` / key-security handling, and caller-scratch `scrypt` boundary.
- NIP-64: no further Layer 1 change required; keep the current bounded PGN structural validation
  helper and optional `alt` metadata while leaving move legality and chess workflow to the SDK.
- NIP-88: no further Layer 1 change required; keep the current bounded poll/response helper
  surface and pure tally reducer, with malformed latest responses suppressing older valid votes.
- NIP-98: keep the split kernel surface for strict auth-event extraction, exact request matching,
  lowercase payload hashing, and strict header helpers, and keep overlong caller inputs on typed
  invalid-input paths instead of debug assertions.
- NIP-B7: no further Layer 1 change required; keep the split kernel surface on ordered server-list
  parsing/building and deterministic fallback derivation while leaving Blossom service workflow out
  of `noztr`.
- NIP-C0: no further Layer 1 change required; keep the metadata-only helper on deterministic
  snippet metadata, repeated license/dependency extraction, and validated repository references.

## Accepted Risks

- `NIP-39` and `NIP-46` each still have one accepted borderline deterministic helper in the kernel
  under `D-076`; revisit those only when `nzdk` has stable provider adapters or connection-handoff
  helpers that would make the current kernel helpers redundant.

## Follow-up Summary

- NIP-10: no follow-up remains from `no-4iw`; the prior provisional divergence is resolved.

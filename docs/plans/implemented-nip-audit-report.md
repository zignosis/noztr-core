# Implemented NIP Audit Report

Date: 2026-03-10

Purpose: provide one canonical review artifact for the autonomous implemented-NIP audit so findings,
accepted risks, decision points, and follow-up items can be reviewed systematically after the audit
completes.

## Scope

- This report covers the implemented NIPs in `noztr`.
- It summarizes audit conclusions after the per-NIP evidence is gathered in beads issues.
- It does not replace raw evidence in beads or canonical policy decisions in
  `docs/plans/decision-log.md`.

## Evidence Sources

- relevant NIP text
- current `noztr` code and tests
- `rust-nostr` harness/source behavior
- `nostr-tools` harness/source behavior for every implemented NIP
- existing in-repo ecosystem notes and intentional-divergence records

## Review Standard

- Judge each NIP against the canonical review axes and lenses in
  `docs/plans/build-plan.md`.
- `rust-nostr` is the active parity lane and strongest production reference.
- `nostr-tools` is a secondary non-gating ecosystem signal.
- No reference library is treated as protocol authority.

## Audit Status

| NIP | Status | Rust Evidence | TS Evidence | Findings | Decision Points | Follow-ups | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Accepted uppercase single-letter `#X` filter keys; retained unknown filter-field rejection and prefixed rejection-status enforcement as accepted trust-boundary behavior | none | none | NIP-01 allows `a-zA-Z` tag-filter keys, and both reference lanes support uppercase matching; current unknown-field and status-prefix strictness remains more policyful but still spec-defensible |
| 02 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED BASELINE PASS` | No Layer 1 change required; valid relay-hint and petname shapes are already accepted | none | none | `rust-nostr` builders emit canonical `p` tags with optional relay and alias, but the available reference extraction surfaces are generic tag iterators rather than a dedicated strict contact-list helper |
| 09 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED BASELINE PASS` | Tightened `a`-target deletion parsing so only valid replaceable/addressable coordinates are accepted | none | none | `rust-nostr` models delete coordinates through the NIP-01 coordinate type; TS coverage remains baseline builder/tag-shape signal only in this pass |
| 10 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Removed unnecessary rejection of legacy `mention`; removed unnecessary rejection of four-slot pubkey fallback | none | `no-4iw` closed | `noztr` now preserves four-slot author pubkey; `nostr-tools` accepts the shape but drops author |
| 11 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | No Layer 1 change required; current bounded partial-document parse remains acceptable and now has an explicit full-spec-shaped compatibility vector | none | none | `noztr` intentionally exposes a typed subset of relay-info fields, but it ignores additional NIP-11 fields without disturbing the supported subset; both reference lanes tolerate the broader document shape |
| 13 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | No Layer 1 change required; current PoW helper already preserves the full `0..256` difficulty domain and trust-boundary checked-ID entry point | none | none | `rust-nostr` remains the stronger runtime reference for normal PoW checks, but its standalone leading-zero helper is typed as `u8`; `noztr` keeps the full `256`-bit edge, and `nostr-tools` runtime evidence confirms the broader domain |
| 18 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Reject contradictory repost target metadata without embedded-event proof; retained existing embedded-event consistency checks and kind-6 relay-hint requirement | none | none | `rust-nostr` builders already emit coherent repost metadata and add `a` only for coordinate-capable targets; `nostr-tools` runtime coverage now confirms kind-6/kind-16 builder behavior and protected-event empty-content handling |
| 19 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Accepted empty-identifier `naddr` encode/decode for normal replaceable coordinates | none | none | NIP-19 explicitly allows empty `d` for replaceable coordinates; both reference lanes roundtrip that shape, so the prior rejection was unnecessary incompatibility |
| 21 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | No separate Layer 1 change required; explicit replaceable-`naddr` URI coverage now pins the inherited NIP-19 compatibility fix | none | none | Current strict scheme/entity rejection remains justified; the audit mainly needed to confirm that valid empty-identifier `naddr` URIs now roundtrip cleanly through the URI layer |
| 22 | complete | `HARNESS_COVERED DEEP PASS` | `SOURCE_REVIEW_ONLY no dedicated NIP-22 helper beyond kind constant` | No Layer 1 change required; current root/parent, `K/k`, `P/p`, and kind-1 rejection posture remains justified | none | none | `rust-nostr` emits canonical full linkage when given a root target but still extracts parent-only / optional-kind shapes; `noztr` keeps the stricter trust-boundary contract |
| 25 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Accepted the optional NIP-30 fourth-slot emoji-set coordinate on reaction `emoji` tags; retained strict shortcode and URL validation; now reject contradictory optional target metadata and unsupported `a` kinds | none | none | `rust-nostr` remains permissive on shortcode text and still standardizes only three-slot emoji tags; `nostr-tools` aligns on last-`e`/last-`p` target selection and strict shortcode matching |
| 27 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Narrowed inline extraction to profile/event/address references by dropping `nrelay` as a NIP-27 content reference; retained ignore-as-plain-text fallback for malformed, uppercase, forbidden, and payload-empty fragments | none | none | `rust-nostr` and `nostr-tools` both treat malformed and forbidden fragments as plain text; neither treats `nrelay` as an inline content reference in this pass |
| 29 | complete | `SOURCE_REVIEW_ONLY no dedicated rust-nostr helper surface` | `HARNESS_COVERED BASELINE PASS` | Accepted deployed three-slot `h` tags with optional relay hints and optional compatibility labels on admin `p` tags; reducer now ignores labels for role state and builders can emit the broader ecosystem admin shape when asked | none | none | The NIP text only requires the `h` value, but deployed group tooling carries an extra relay hint and labeled admin tags; label-aware moderation policy remains intentionally out of scope, so the kernel treats the label as optional metadata and keeps state reduction focused on pubkeys plus roles |
| 40 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Malformed expiration metadata no longer hard-fails the helper path; the first valid expiration tag now wins deterministically | none | none | `rust-nostr` and `nostr-tools` both treat malformed expiration data as non-expiring rather than exceptional; the previous typed-error path created unnecessary compatibility friction for advisory metadata |
| 42 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Widened NIP-42 challenge bound from `64` to `255`; retained path-bound websocket origin matching, duplicate-tag rejection, and unbracketed IPv6 rejection | none | none | `rust-nostr` and `nostr-tools` both accept long challenges; current remaining strictness is judged trust-boundary-positive rather than ecosystem-hostile |
| 44 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED DEEP PASS` | No Layer 1 change required; current NIP-44 v2 surface remains aligned on vectors, staged failure order, and checked cryptographic boundaries | none | none | The audit found no unjustified strictness: unsupported `#` encoding, version-before-MAC ordering, MAC-before-padding ordering, and invalid-UTF8-as-invalid-padding all remain bounded and compatible |
| 45 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Uppercase HLL hex now validates and unknown COUNT metadata keys are ignored instead of rejecting the whole response | none | none | NIP-45 says `hll` is hex-encoded and leaves room for optional relay metadata; both reference lanes tolerate forward-compatible COUNT metadata better than the old strict parser |
| 50 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Malformed extension-like search tokens no longer invalidate the helper path; supported tokens are now extracted best-effort from bounded UTF-8 search text | none | none | NIP-50 frames `search` as a human-readable string and says unsupported extensions should be ignored; both reference lanes treat malformed extension-like text as ordinary searchable text rather than invalid input |
| 51 | complete | `HARNESS_COVERED DEEP PASS` | `SOURCE_REVIEW_ONLY no dedicated NIP-51 helper beyond kind constants` | Widened bookmark extraction to accept bounded hashtag/URL items and changed unrelated unknown tags from fatal to ignored; kept typed failures for malformed supported tags and coordinate-kind enforcement | none | none | `rust-nostr` bookmark builders were broader than the old parser; `nostr-tools` provides kind-level signal only in this pass |
| 59 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | No Layer 1 change required; current staged wrap->seal->rumor validation remains justified and compatible | none | none | Wrap-kind, signed-seal, unsigned-rumor, sender-continuity, and decrypt-failure boundaries all match the protocol intent; the audit found no evidence-backed relaxation that would improve compatibility without weakening trust checks |
| 65 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED BASELINE PASS` | Ignore unrelated foreign tags during relay extraction while keeping malformed `r` relay tags strict | none | none | `rust-nostr` extraction tolerates surrounding non-relay tags and yields only valid relay entries; `nostr-tools` remains builder-only signal in this pass |
| 70 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | No Layer 1 change required; exact one-item `["-"]` protected-tag semantics remain correct and compatible | none | none | The NIP and both reference lanes treat only the exact single-item `["-"]` tag as protected; malformed lookalikes remain safely ignored |
| 77 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | NEG-ERR reasons now accept the spec-required `:` delimiter without requiring a following space, and session state now allows bounded reopen on a reused state object | none | none | The prior `\": \"` requirement and idle-only reopen rule were stricter than the NIP text; both changes preserve boundedness while reducing protocol friction |

## Decision Summary

- NIP-01: accept uppercase single-letter `#X` filter keys to match the NIP text and reference
  library behavior, while retaining unknown filter-field rejection and prefixed rejection-status
  enforcement as accepted Layer 1 trust-boundary behavior.
- NIP-02: no Layer 1 change required; current contact extraction already accepts the valid relay
  hint and petname shapes called for by the NIP, and current stricter whole-tag validation remains
  acceptable on the evidence gathered in this pass.
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
- NIP-77: accept `NEG-ERR` reason strings with `:` and optional space, and allow bounded session
  reopen on reused negentropy state.
- NIP-18: reject contradictory repost target metadata when empty-content reposts cannot prove the
  target via embedded JSON, while retaining current embedded-event consistency checks and the kind-6
  relay-hint requirement.
- NIP-22: keep strict root/parent scope, mandatory `K/k`, mandatory `P/p` for Nostr targets, and
  kind-1 rejection; `rust-nostr` permissive extraction is treated as a compatibility signal, not a
  reason to weaken the Layer 1 parser.
- NIP-25: accept the optional NIP-30 emoji-set address on reaction `emoji` tags, while keeping
  strict shortcode and image-URL validation, and reject contradictory `e`/`p`/`a`/`k` target
  metadata plus unsupported `a` kinds.
- NIP-27: narrow strict inline reference extraction to the event/profile/address entities actually
  treated as content references in the current spec/examples and major reference libraries, while
  keeping malformed-fragment fallback as plain text.
- NIP-29: accept deployed three-slot `h` tags with optional relay hints and optional compatibility
  labels on admin `p` tags, while keeping state reduction focused on pubkeys plus roles and only
  emitting the broader labeled admin shape when a caller explicitly asks for it.
- NIP-42: widen the challenge bound to `255` bytes, but keep path-bound websocket origin matching,
  duplicate required-tag rejection, and unbracketed IPv6 rejection as accepted trust-boundary
  behavior.
- NIP-51: accept bounded hashtag/URL bookmark items and ignore unrelated unknown tags during
  extraction, while keeping typed rejection for malformed supported tags.

## Accepted Risks

- none yet

## Follow-up Summary

- NIP-10: no follow-up remains from `no-4iw`; the prior provisional divergence is resolved.

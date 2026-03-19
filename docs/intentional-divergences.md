# Intentional Divergences: `noztr` vs `rust-nostr` and `nostr-tools`

Date: 2026-03-09

Release-facing note for behavior differences that are intentional in `noztr` Layer 1 defaults.

## Layer 1 posture and why

- `noztr` follows the deterministic-and-compatible trust-boundary posture (`D-036`): Layer 1 picks
  the narrowest deterministic behavior that remains correct, bounded, explicit, and
  ecosystem-compatible.
- This keeps cryptographic and protocol behavior predictable across relays, reduces silent
  acceptance of malformed inputs, and avoids making strictness an end in itself.
- Compatibility behavior remains explicit where it would blur Layer 1 contracts, but compatibility
  itself is not treated as a smell.
- `rust-nostr` remains the strongest active comparison lane because it is widely used and provides
  good ecosystem signal, but divergences can still be intentional improvements when they are
  NIP-grounded, bounded, and documented.

## Known intentional divergences

- **Status-prefix strictness (NIP-01 relay `OK`):**
  `noztr` strict path requires prefixed rejection status (`<prefix>: <message>`) and strict lowercase
  event-id semantics at parse boundaries.
- **Strict filter/tag rules (NIP-01 filters and strict tag shape checks):**
  `noztr` strict filter boundaries reject malformed/ambiguous tag-key/value forms rather than
  accepting broad permissive shapes.
- **Auth origin/path strictness (NIP-42):**
  `noztr` binds normalized scheme/host/port/path (`/` default), ignores query/fragment for matching,
  and rejects unbracketed IPv6 authorities. The earlier `64`-byte local challenge cap was removed
  during the implemented-NIP audit because it was narrower than the protocol and major references
  without improving trust-boundary safety.
- **Canonical checked APIs for trust boundaries:**
  strict integration entry points are explicit (`pow_meets_difficulty_verified_id`,
  `delete_extract_targets_checked`, `transcript_mark_client_req`, `transcript_apply_relay`) to avoid
  partial/unchecked call paths.
- **NIP-13 full-256 PoW domain:**
  `noztr` keeps the full `0..256` leading-zero-bit domain for PoW helpers, including the all-zero
  edge case, and pairs that with an explicit checked-ID trust-boundary entry point. `rust-nostr`
  remains the strongest runtime parity lane for normal PoW behavior, but its standalone leading-zero
  helper is typed as `u8`, so `noztr` intentionally keeps the broader bounded domain instead of
  copying that narrower helper ceiling.
- **NIP-10 bounded compatibility handling:**
  `noztr` no longer rejects legacy `mention` markers or four-slot pubkey fallback in NIP-10 thread
  extraction. It accepts `mention` as an explicit mention reference and accepts a valid slot-four
  pubkey as bounded compatibility input, preserving that author pubkey in extracted references.
  This aligns the trust-boundary helper better with deployed ecosystem behavior while staying
  deterministic. `nostr-tools` still drops the author in the four-slot case, so `noztr` remains
  slightly richer than the JS reference on that one shape.
- **Strict NIP-25 shortcode enforcement with spec-complete emoji-tag acceptance:**
  `noztr` requires custom emoji shortcodes to satisfy the NIP-30 alphanumeric-or-underscore rule,
  while `rust-nostr` currently accepts broader shortcode text as long as the emoji tag URL parses.
  `noztr` now also accepts the optional NIP-30 fourth-slot emoji-set coordinate on reaction
  `emoji` tags when it is a valid `30030` address, even though the current Rust standardized tag
  model remains three-slot only. This keeps the strict shortcode contract while removing needless
  rejection of a spec-valid reaction-tag shape.
- **Strict NIP-25 target-metadata consistency:**
  `noztr` rejects contradictory reaction target metadata when `e`-author, `p`, `a`, and `k` do not
  describe the same target, and rejects `a` coordinates outside replaceable/addressable kind
  ranges. This keeps the extracted target deterministic instead of surfacing conflicting optional
  hints as if they were trustworthy.
- **Strict NIP-22 root/parent linkage validation:**
  `noztr` requires comments to carry both uppercase root scope and lowercase parent scope, mandates
  `K`/`k`, rejects ambiguous competing target families, and requires explicit `P`/`p` author
  linkage for Nostr targets while still accepting the valid address-scoped `a+e` companion-id form.
  `rust-nostr` builders emit the canonical richer form when given a root target, but its comment
  extraction still tolerates parent-only input and optional `K`/`k`. `nostr-tools` currently has no
  dedicated NIP-22 helper beyond the exported kind constant, so the JS ecosystem signal here is
  source-review only. `noztr` keeps the stricter contract because it matches the NIP text, produces
  deterministic trust-boundary parsing, validates `I/i` against `K/k` instead of treating external
  targets as opaque text, and preserves NIP-10 as the only reply path for kind-1 notes.
- **Strict NIP-18 repost-target consistency:**
  `noztr` rejects contradictory repost metadata when `k`, `a`, and `p` cannot describe the same
  target, rejects `kind 6` reposts that try to carry `a` coordinates or non-`1` `k` tags, and
  limits `a` tags to replaceable/addressable kinds. This keeps repost extraction deterministic when
  the event does not carry a full embedded target JSON blob.
- **NIP-51 emoji fourth-slot builder support:**
  `noztr` can emit the optional fourth-slot NIP-30 emoji-set coordinate on `emoji` tags, while
  `rust-nostr` standardizes only the three-item shape. This is a spec-driven builder enhancement,
  not a parsing-default change.
- **NIP-46 current-spec client URI and method surface:**
  `noztr` follows the current NIP-46 `nostrconnect://` query shape with split parameters
  (`relay`, `secret`, `perms`, `name`, `url`, `image`) and supports `switch_relays` in the
  bounded core method surface. `nostr-tools` matches that current-spec shape, while the pinned
  `rust-nostr` lane still exposes the older `metadata=` client-URI shape and does not yet expose
  `switch_relays` in its method enum. `noztr` keeps the current-spec surface instead of narrowing
  itself to the stale Rust overlap.
- **NIP-05 local-part grammar stays spec-shaped instead of following `nostr-tools`' broader regex:**
  `noztr` enforces the NIP-05 local-part character set `a-z0-9-_.` and rejects broader forms such
  as `+` that `nostr-tools` still accepts in `NIP05_REGEX`. `noztr` keeps bare-domain
  canonicalization to `_@domain` and shared `relays` / `nip46` extraction, but does not widen the
  identifier grammar beyond the NIP text just to match the JS helper regex.

## Interoperability impact and migration guidance

- Integrators moving from permissive defaults in other SDKs should expect some malformed inputs to be
  rejected earlier in `noztr` strict paths.
- Use strict checked APIs at relay or boundary ingress first, then add explicit adapter logic only
  where production traffic demonstrates necessary compatibility exceptions.
- For message/status handling, emit canonical prefixed status text on rejection paths and preserve
  lowercase canonical IDs in strict wire handling.
- For auth validation, normalize origin/path inputs up front and bracket IPv6 authorities to match
  strict relay-origin expectations.

## Parity evidence pointers

- Canonical side-by-side parity status: `docs/archive/plans/phase-f-parity-matrix.md`.
- Canonical parity deltas and model-v1 status: `docs/archive/plans/phase-f-parity-ledger.md`.
- Incremental parity-depth execution evidence: `docs/archive/plans/phase-f-risk-burndown.md`.

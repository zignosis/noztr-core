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
  and rejects unbracketed IPv6 authorities.
- **Canonical checked APIs for trust boundaries:**
  strict integration entry points are explicit (`pow_meets_difficulty_verified_id`,
  `delete_extract_targets_checked`, `transcript_mark_client_req`, `transcript_apply_relay`) to avoid
  partial/unchecked call paths.
- **NIP-10 bounded compatibility handling:**
  `noztr` no longer rejects legacy `mention` markers or four-slot pubkey fallback in NIP-10 thread
  extraction. It accepts `mention` as an explicit mention reference and accepts a valid slot-four
  pubkey as bounded compatibility input, preserving that author pubkey in extracted references.
  This aligns the trust-boundary helper better with deployed ecosystem behavior while staying
  deterministic. `nostr-tools` still drops the author in the four-slot case, so `noztr` remains
  slightly richer than the JS reference on that one shape.
- **Strict NIP-25 NIP-30 shortcode enforcement:**
  `noztr` requires custom emoji shortcodes to satisfy the NIP-30 alphanumeric-or-underscore rule,
  while `rust-nostr` currently accepts broader shortcode text as long as the emoji tag URL parses.
  This remains an accepted strict-path improvement because it preserves a deterministic, spec-aligned
  trust-boundary contract.
- **Strict NIP-22 root/parent linkage validation:**
  `noztr` requires comments to carry both uppercase root scope and lowercase parent scope, mandates
  `K`/`k`, rejects ambiguous competing target families, and requires explicit `P`/`p` author
  linkage for Nostr targets while still accepting the valid address-scoped `a+e` companion-id form.
  `rust-nostr` builders can emit parent-only comment tags and its extraction remains permissive
  about missing root scope and optional `K`/`k`. `noztr` keeps the stricter contract because it
  produces deterministic trust-boundary parsing, validates `I/i` against `K/k` instead of treating
  external targets as opaque text, and preserves NIP-10 as the only reply path for kind-1 notes.
- **Strict NIP-51 bookmark-family scope:**
  `noztr` Wave 1 public-list helper keeps `bookmarks` and `bookmark_set` aligned to the NIP-51
  table (`e` and `a` only), while `rust-nostr` bookmark builders also expose hashtag and URL tags.
  `noztr` now exposes bounded bookmark tag builders for the broader emission shapes, but keeps the
  narrower extraction boundary to preserve a deterministic trust-boundary contract instead of
  silently widening Layer 1 defaults.
- **NIP-51 emoji fourth-slot builder support:**
  `noztr` can emit the optional fourth-slot NIP-30 emoji-set coordinate on `emoji` tags, while
  `rust-nostr` standardizes only the three-item shape. This is a spec-driven builder enhancement,
  not a parsing-default change.

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

- Canonical side-by-side parity status: `docs/plans/phase-f-parity-matrix.md`.
- Canonical parity deltas and model-v1 status: `docs/plans/phase-f-parity-ledger.md`.
- Incremental parity-depth execution evidence: `docs/plans/phase-f-risk-burndown.md`.

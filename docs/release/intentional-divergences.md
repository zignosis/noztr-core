# Intentional Divergences: `noztr` vs `rust-nostr` and `nostr-tools`

Date: 2026-03-09

Release-facing note for behavior differences that are intentional in `noztr` strict defaults.

## Strictness defaults and why

- `noztr` is strict-by-default (`D-003`): trust-boundary parsing and validation prefer deterministic
  rejection over permissive normalization.
- This keeps cryptographic and protocol behavior predictable across relays, reduces silent acceptance
  of malformed inputs, and preserves typed failure contracts.
- Compatibility behavior remains an explicit adapter concern and does not weaken Layer 1 defaults.

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

---
title: Migrating From 0.1.0-rc.5
doc_type: release_guide
status: active
owner: noztr
read_when:
  - updating_from_0_1_0_rc_5
  - adapting_to_recent_public_api_breaks
canonical: true
---

# Migrating From `0.1.0-rc.5`

This guide covers the current post-`v0.1.0-rc.5` route-local type cleanup in `noztr-core`.

## Quick Path

If your project depends on `noztr-core`:

1. update explicit type references in the affected routes
2. rerun your normal build/test gates
3. refresh generated symbol indexes or local LLM context that still teach the older longer names

## Renamed Public Types

### `nip37_drafts`

- `DraftWrapInfo` -> `Wrap`
- `DraftWrapPlaintextInfo` -> `Plaintext`
- `PrivateRelayListInfo` -> `PrivateRelayList`

### `nip45_count`

- `CountMetadata` -> `Metadata`
- `CountClientMessage` -> `ClientMessage`
- `CountRelayMessage` -> `RelayMessage`

### `nip23_long_form`

- `LongFormMetadata` -> `Metadata`

### `nip99_classified_listings`

- `ListingMetadata` -> `Metadata`

## Scope

This is naming and surface-noise cleanup only.

The grouped routes stay the same.
Wire behavior, trust-boundary behavior, and ownership posture are unchanged.

If you are also updating from older release candidates, apply the earlier migration guides first:

- [migrating-from-0.1.0-rc.1.md](migrating-from-0.1.0-rc.1.md)
- [migrating-from-0.1.0-rc.2.md](migrating-from-0.1.0-rc.2.md)
- [migrating-from-0.1.0-rc.3.md](migrating-from-0.1.0-rc.3.md)
- [migrating-from-0.1.0-rc.4.md](migrating-from-0.1.0-rc.4.md)

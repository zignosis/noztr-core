---
title: Migrating From 0.1.0-rc.4
doc_type: release_guide
status: active
owner: noztr
read_when:
  - updating_from_0_1_0_rc_4
  - adapting_to_recent_public_api_breaks
canonical: true
---

# Migrating From `0.1.0-rc.4`

This guide covers the current post-`v0.1.0-rc.4` removal of `NIP-26` support from `noztr-core`.

## Quick Path

If your project depends on `noztr-core`:

1. remove any direct use of `noztr.nip26_delegation`
2. remove or replace any code that expected `NIP-26` delegation helpers from `noztr-core`
3. rerun your normal build/test gates
4. refresh generated symbol indexes or local LLM context packs that still point at the removed route

## Removed Public Route

`noztr-core` no longer exports:

- `noztr.nip26_delegation`

This includes the previous public helpers for:

- delegation tag parsing
- delegation condition parsing and formatting
- delegation message construction
- delegation signature signing and verification
- delegation event validation
- delegation tag building

## Scope

This is an intentional support removal. `NIP-26` is no longer part of the supported `noztr-core`
surface.

If you are also updating from older release candidates, apply the earlier migration guides first:

- [migrating-from-0.1.0-rc.1.md](migrating-from-0.1.0-rc.1.md)
- [migrating-from-0.1.0-rc.2.md](migrating-from-0.1.0-rc.2.md)
- [migrating-from-0.1.0-rc.3.md](migrating-from-0.1.0-rc.3.md)

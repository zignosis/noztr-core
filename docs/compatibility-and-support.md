---
title: Compatibility And Support
doc_type: release_note
status: active
owner: noztr
read_when:
  - checking_runtime_and_build_expectations
  - checking_optional_surfaces
  - evaluating_support_scope
canonical: true
---

# Compatibility And Support

This page explains what `noztr` expects from your build environment, what parts of the library are
optional or split, and what kinds of support expectations are reasonable for the project.

## Build Compatibility

Current local build floor:

- Zig `0.15.2`

Canonical local checks:

```bash
zig build test --summary all
zig build
```

If you are evaluating the library for a downstream SDK or application, start there first.

## Dependency Posture

`noztr` is stdlib-first by default, but not literally stdlib-only today.

Approved pinned backend exceptions currently exist for:

- `secp256k1`
- `libwally-core`

The project policy is:

- keep backend exceptions narrow
- keep them explicit
- keep the rest of the protocol kernel free from dependency creep

For public evaluation, the important point is not “zero dependencies at all costs.” It is “no broad
runtime or ecosystem dependency sprawl.”

## Supported Surface Types

The public docs use three important support labels:

- `implemented`
  - exported and available by default
- `optional`
  - exported only when the I6 extension build flag is enabled
- `split`
  - only the deterministic kernel slice is in `noztr`

See:

- [nip-coverage.md](reference/nip-coverage.md)

## What `optional` Means

Optional exports are currently:

- `NIP-45`
- `NIP-50`
- `NIP-77`

They are available only when the I6 extension build flag is enabled.

If you need the smallest default surface, do not assume these are present automatically.

## What `split` Means

`split` does not mean “half-implemented and vague.”

It means the project intentionally keeps only the deterministic, bounded, transport-free kernel
slice in `noztr`.

Examples:

- `NIP-47`
  - typed URI, envelope, and JSON contract helpers stay here
  - higher wallet workflow does not
- `NIP-57`
  - zap-related deterministic helpers stay here
  - broader payment workflow does not
- `NIP-86`
  - relay-management JSON-RPC contract helpers stay here
  - relay-admin workflow and orchestration do not
- `NIP-98`
  - HTTP auth event/header helpers stay here
  - transport/client policy does not
- `NIP-B7`
  - deterministic Blossom server-list and fallback helpers stay here
  - full Blossom service/runtime ownership does not

That split is a scope decision, not a temporary omission.

## Public Support Expectations

`noztr` should currently be understood as:

- reviewed and high-discipline
- younger than the oldest widely used Nostr libraries
- a strong fit for controlled Zig foundations
- not yet claiming the broadest long-lived compatibility guarantee in the ecosystem

Practical support expectations:

- public docs and examples should route you to the right surface
- typed contracts should be explicit
- release-facing changes should be documented
- pre-`1.0.0` breaking cleanup should ship with a concrete migration guide when downstream callers
  need to update symbol usage
- downstream feedback still matters before claiming a fully settled compatibility story

Current downstream migration notes:

- [guides/migrating-from-0.1.0-rc.1.md](guides/migrating-from-0.1.0-rc.1.md)
- [guides/migrating-from-0.1.0-rc.2.md](guides/migrating-from-0.1.0-rc.2.md)
- [guides/migrating-from-0.1.0-rc.3.md](guides/migrating-from-0.1.0-rc.3.md)
- [guides/migrating-from-0.1.0-rc.4.md](guides/migrating-from-0.1.0-rc.4.md)
- [guides/migrating-from-0.1.0-rc.5.md](guides/migrating-from-0.1.0-rc.5.md)

If you are updating from an older pre-`1.0` public line and a release note or changelog entry marks
the change as breaking, use the relevant migration guide first:

- [guides/migrating-from-0.1.0-rc.1.md](guides/migrating-from-0.1.0-rc.1.md)
- [guides/migrating-from-0.1.0-rc.2.md](guides/migrating-from-0.1.0-rc.2.md)
- [guides/migrating-from-0.1.0-rc.3.md](guides/migrating-from-0.1.0-rc.3.md)
- [guides/migrating-from-0.1.0-rc.4.md](guides/migrating-from-0.1.0-rc.4.md)
- [guides/migrating-from-0.1.0-rc.5.md](guides/migrating-from-0.1.0-rc.5.md)

## What `noztr` Does Not Support

By default, `noztr` does not try to support:

- websocket/TLS runtime ownership
- relay pools or subscription orchestration
- storage layers
- cache layers
- UI policy
- app workflow convenience layers

Those belong in higher layers or sibling repos.

## Related Pages

- [scope-and-tradeoffs.md](scope-and-tradeoffs.md)
- [intentional-divergences.md](intentional-divergences.md)
- [stability-and-versioning.md](stability-and-versioning.md)
- [nip-coverage.md](reference/nip-coverage.md)

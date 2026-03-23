# Changelog

This changelog records intentional public release changes for `noztr`.

Current release posture:

- the current public line is intentionally pre-`1.0.0`
- the first intentional public tag starts at `0.1.0-rc.1`
- final RC closure should still be informed by downstream `noztr-sdk` feedback

For the public versioning policy, see
[docs/stability-and-versioning.md](docs/stability-and-versioning.md).

## [Unreleased]

### Breaking Changes

- shortened route-internal public type names in the first surface-noise remediation lane:
  - `nip04`
  - `nip21_uri`
  - `nip44`
  - `nip46_remote_signing`
- shortened repeated `Info` / `Reference` public type names in the second family-scoped lane:
  - `nip28_public_chat`
  - `nip54_wiki`
  - `nip75_zap_goals`
  - `nip88_polls`
- shortened repeated `Info` / `Reference` public type names in the third family-scoped lane:
  - `nip52_calendar_events`
  - `nip58_badges`
- shortened additional route-internal metadata names in the fourth family-scoped lane:
  - `nip38_user_status`
  - `nip61_nutzaps`
  - `nip89_handlers`
- shortened redundant route-internal request/result names in the Wallet Connect route:
  - `nip47_wallet_connect`
- removed pure storage-wrapper types where direct caller-owned `[]u8` buffers are clearer:
  - `nip28_public_chat.BuiltJson`
  - `nip71_video_events.BuiltField`
  - `nip92_media_attachments.BuiltField`
- flattened the `nip46_remote_signing.Response.result` shape by removing nested response-result
  wrapper types:
  - `nip46_remote_signing.ResponsePayload`
  - `nip46_remote_signing.ResponseResult`
- flattened the `nip86_relay_management.Response.result` shape by removing its standalone wrapper
  type:
  - `nip86_relay_management.ResponsePayload`
- downstream callers that reference those public types directly need to update symbol names
- migration guide:
  - [docs/guides/migrating-from-0.1.0-rc.2.md](docs/guides/migrating-from-0.1.0-rc.2.md)

## [0.1.0-rc.2] - 2026-03-22

Release type: breaking rc

### Summary

Second public release candidate for `noztr-core`.

This RC keeps the kernel/runtime boundary and protocol surface stable, but tightens the public API
teaching surface after the first public cut: temporary naming aliases are gone, public error names
now consistently prefer descriptive names inside module namespaces, and a narrow `zig fmt`-based
lint gate is now part of the documented verification path.

### Public Highlights

- removed temporary compatibility aliases from the public API and kept only the canonical names
- normalized public error type names toward descriptive module-local names instead of short-lived
  numeric `NipXXError` symbols
- added `zig build lint` as a narrow, functional formatting gate using `zig fmt --check`
- updated the migration guide and public style guide to make the naming rule explicit

### Breaking Changes

- removed temporary public naming aliases introduced during the API-naming normalization pass
- changed public error type names across the exported surface toward descriptive names inside module
  namespaces
- downstream callers should update any explicit error type references and any old alias symbol usage
- migration guide:
  - [docs/guides/migrating-from-0.1.0-rc.1.md](docs/guides/migrating-from-0.1.0-rc.1.md)

### Compatibility Notes

- Zig toolchain floor for this RC line remains `0.15.2`
- optional I6 exports remain build-flag gated
- these changes are naming- and contract-surface changes only; they do not change wire formats,
  ownership posture, or kernel-vs-SDK scope

### Docs And Examples

- updated the public migration guide for post-`rc.1` callers
- updated the public style guide to prefer descriptive names inside module namespaces
- updated release-facing verification docs to include `zig build lint`

### Verification

- `zig build lint`
- `zig build test --summary all`
- `zig build`

## [0.1.0-rc.1] - 2026-03-21

Release type: rc

### Summary

First intentional public release candidate for `noztr-core`.

This RC establishes the documented protocol-kernel surface, adds first-class native legacy
`NIP-04` DM support, and consolidates shared trust-boundary helpers behind clearer internal
contracts.

### Added

- first-class native `NIP-04` legacy direct-message support under `noztr.nip04`
- local encrypt/decrypt, canonical `ciphertext?iv=...` payload handling, and strict `kind:4`
  event-shape parsing for legacy DMs
- public docs surface under `docs/`
- public task and example routing
- public ownership, performance, compatibility, and versioning notes
- public `CONTRIBUTING.md`
- public `CHANGELOG.md`
- `NIP-04` examples for local crypto, DM build/sign/parse/verify, and adversarial malformed-input
  coverage

### Changed

- internal planning, audit, and process docs moved to local-only `.private-docs/`
- public docs and examples now form the tracked user-facing documentation surface
- shared lower-hex, URL, relay-URL, and private-JSON boundary helpers are centralized behind
  explicit internal helper modules
- strict `NIP-04` DM parsing now accepts standard reply `e`-tag forms for better interoperability

### Breaking Changes

- none intended for the first public RC line
- the public line remains pre-`1.0.0`, so compatibility should still be treated conservatively

### Compatibility Notes

- Zig toolchain floor for this RC line is `0.15.2`
- `NIP-04` support is limited to strict legacy kind-4 DMs
- deprecated `NIP-04` private-list compatibility remains out of scope

### Docs And Examples

- updated release-facing docs under `README.md`, `docs/`, and `examples/README.md`
- added `examples/nip04_example.zig`
- added `examples/nip04_dm_recipe.zig`
- added `examples/nip04_adversarial_example.zig`

### Verification

- `zig build test --summary all`
- `zig build`

### Notes

- Treat this as a release candidate, not a long-established stable compatibility line.

## Format

Each release entry should include:

- version and date
- whether the release is additive, corrective, or breaking
- public API additions
- public API removals or breaking changes
- typed error or ownership contract changes
- docs/examples updates that materially affect downstream use

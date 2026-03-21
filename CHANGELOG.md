# Changelog

This changelog records intentional public release changes for `noztr`.

Current release posture:

- the current public line is intentionally pre-`1.0.0`
- the first intentional public tag starts at `0.1.0-rc.1`
- final RC closure should still be informed by downstream `noztr-sdk` feedback

For the public versioning policy, see
[docs/stability-and-versioning.md](docs/stability-and-versioning.md).

## [Unreleased]

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

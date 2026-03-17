---
title: TigerBeetle Zig Quality Report
doc_type: report
status: active
owner: noztr
read_when:
  - evaluating_zig_quality
  - comparing_against_tigerbeetle
depends_on:
  - docs/guides/TIGER_STYLE.md
  - docs/guides/NOZTR_STYLE.md
  - docs/guides/zig-patterns.md
  - docs/guides/zig-anti-patterns.md
canonical: true
---

# TigerBeetle Zig Quality Report

Date: 2026-03-17

Purpose: evaluate whether `noztr` is using Zig well through a TigerBeetle-oriented engineering
lens, with emphasis on function shape, assertions, explicit state, memory discipline, control flow,
and safety posture.

## Provenance

- primary style lens:
  - `docs/guides/TIGER_STYLE.md`
- project-specific adaptation:
  - `docs/guides/NOZTR_STYLE.md`
- supporting implementation rules:
  - `docs/guides/zig-patterns.md`
  - `docs/guides/zig-anti-patterns.md`
- external reference repo:
  - `https://github.com/tigerbeetle/tigerbeetle`

## Executive Result

- `noztr` is generally using Zig well for a protocol kernel.
- the repo is stronger on explicit widths, typed trust boundaries, protocol-only root scope, and
  secret handling than a typical application-oriented Zig library.
- the main Zig-quality debt is concentrated, not systemic.
- the real Tiger-style pressure points are:
  - hidden global mutable backend state
  - a few overgrown coordinator functions
  - weak assertion density in part of the public `NIP-49` surface
  - allocator-backed public ingress in some parse-heavy modules

## Strengths

- protocol-only root facade is clean and centralized
  - [root.zig](/workspace/projects/noztr/src/root.zig)
- public protocol structs generally use explicit widths instead of leaking `usize`
  - examples:
    - [nip77_negentropy.zig](/workspace/projects/noztr/src/nip77_negentropy.zig)
    - [nip46_remote_signing.zig](/workspace/projects/noztr/src/nip46_remote_signing.zig)
- secret wipe discipline is strong in cryptographic code
  - especially [nip44.zig](/workspace/projects/noztr/src/nip44.zig)
- core modules already show the intended staged, bounded, typed style
  - especially [nip01_filter.zig](/workspace/projects/noztr/src/nip01_filter.zig)

## Findings

1. High: public `NIP-49` entry points miss the repo’s Tiger-style minimum assertion density.
   - [nip49_private_key_encryption.zig:75](/workspace/projects/noztr/src/nip49_private_key_encryption.zig#L75)
   - [nip49_private_key_encryption.zig:118](/workspace/projects/noztr/src/nip49_private_key_encryption.zig#L118)
   - [nip49_private_key_encryption.zig:137](/workspace/projects/noztr/src/nip49_private_key_encryption.zig#L137)
   - [nip49_private_key_encryption.zig:147](/workspace/projects/noztr/src/nip49_private_key_encryption.zig#L147)
   - [nip49_private_key_encryption.zig:196](/workspace/projects/noztr/src/nip49_private_key_encryption.zig#L196)
   - [nip49_private_key_encryption.zig:249](/workspace/projects/noztr/src/nip49_private_key_encryption.zig#L249)
   These are important public parse/encode/encrypt/decrypt boundaries with no local assertions.

2. High: several functions exceed the 70-line cap and keep too much branchy state manipulation in
   one place.
   - [nip22_comments.zig:450](/workspace/projects/noztr/src/nip22_comments.zig#L450)
   - [nip46_remote_signing.zig:700](/workspace/projects/noztr/src/nip46_remote_signing.zig#L700)
   - [nip47_wallet_connect.zig:1864](/workspace/projects/noztr/src/nip47_wallet_connect.zig#L1864)
   - [nip47_wallet_connect.zig:2552](/workspace/projects/noztr/src/nip47_wallet_connect.zig#L2552)
   - [nip47_wallet_connect.zig:2840](/workspace/projects/noztr/src/nip47_wallet_connect.zig#L2840)
   This is the clearest structural mismatch against the TigerBeetle-style function-shape rule.

3. Medium: `NIP-06` still depends on hidden process-global backend state.
   - [nip06_mnemonic.zig:23](/workspace/projects/noztr/src/nip06_mnemonic.zig#L23)
   - [nip06_mnemonic.zig:24](/workspace/projects/noztr/src/nip06_mnemonic.zig#L24)
   - [nip06_mnemonic.zig:147](/workspace/projects/noztr/src/nip06_mnemonic.zig#L147)
   - [nip06_mnemonic.zig:155](/workspace/projects/noztr/src/nip06_mnemonic.zig#L155)
   `backend_once` and `backend_error` make public calls depend on ambient mutable state instead of
   one explicit boundary object or one clearly isolated initialization seam.

4. Medium: some public parse-heavy modules are still allocator-backed rather than Tiger-style
   fixed-capacity decode.
   - [nip05_identity.zig:37](/workspace/projects/noztr/src/nip05_identity.zig#L37)
   - [nip05_identity.zig:89](/workspace/projects/noztr/src/nip05_identity.zig#L89)
   - [nip46_remote_signing.zig:294](/workspace/projects/noztr/src/nip46_remote_signing.zig#L294)
   - [nip46_remote_signing.zig:1074](/workspace/projects/noztr/src/nip46_remote_signing.zig#L1074)
   - [nip77_negentropy.zig:79](/workspace/projects/noztr/src/nip77_negentropy.zig#L79)
   - [nip77_negentropy.zig:345](/workspace/projects/noztr/src/nip77_negentropy.zig#L345)
   This is bounded and caller-owned in `noztr`, so it is not the same problem as hidden heap
   growth, but it is still a Tiger-style divergence worth reducing where practical.

5. Low: a few boundary-facing helpers still collapse multiple failure classes into `bool` or `?`.
   - [nip05_identity.zig:119](/workspace/projects/noztr/src/nip05_identity.zig#L119)
   - [internal/relay_origin.zig:10](/workspace/projects/noztr/src/internal/relay_origin.zig#L10)
   TigerBeetle style would prefer more typed boundary reporting here, though the current forms are
   simple and locally contained.

6. Low: some classification helpers still use long compound ladders where nested explicit branches
   would be clearer.
   - [nip73_external_ids.zig:186](/workspace/projects/noztr/src/nip73_external_ids.zig#L186)
   - [nip99_classified_listings.zig:560](/workspace/projects/noztr/src/nip99_classified_listings.zig#L560)
   This is readability and branch-clarity debt, not a protocol correctness finding.

## Verdict

- `noztr` is not “bad Zig”.
- it is already solid by protocol-kernel standards and stronger than many reference libraries on
  explicitness and trust-boundary design.
- relative to a TigerBeetle-style bar, the main shortfall is not correctness but engineering
  sharpness in a few dense surfaces.
- this lane does not justify a broad rewrite, but it does justify targeted follow-up work before
  freeze confidence is claimed.

## Proposed Follow-Up Areas

- refactor the overlong coordinator functions in `NIP-22`, `NIP-46`, and `NIP-47`
- raise assertion density on the public `NIP-49` boundary surface
- evaluate whether `NIP-06` backend state can become more explicit or more clearly isolated
- reduce allocator-backed ingress where fixed-capacity decode is realistic, especially in
  `NIP-05`, `NIP-46`, and `NIP-77`
- review `bool` / `?` boundary helpers and keep only the ones that are intentionally minimal

## Closeout Call

- the TigerBeetle comparison finds real quality debt, but not a repo-wide Zig failure
- this lane should create targeted follow-up tasks rather than broad policy churn
- reopen the report only if later refactors or freeze work need to re-evaluate the same hotspots

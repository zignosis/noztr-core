---
title: External Crypto Backend Assurance Report
doc_type: report
status: active
owner: noztr
phase: phase-h
read_when:
  - reviewing_external_backend_assurance
  - revising_post_audit_synthesis
depends_on:
  - docs/plans/external-crypto-backend-assurance-supplement.md
  - docs/research/exhaustive-audit-angle-5-crypto-backend-wrapper-report.md
canonical: true
---

# External Crypto Backend Assurance Supplement

- date: 2026-03-17
- issue: `no-1t7m`
- packet: `docs/plans/external-crypto-backend-assurance-supplement.md`
- author: Codex

## Purpose

- add external provenance and build-floor assurance on top of the completed local crypto/backend
  wrapper audit
- test whether the approved backend pins and local build assumptions are externally defensible
  enough for pre-freeze confidence
- keep the result audit-only and defer all fixes to revised synthesis

## Scope

Reviewed directly in this pass:
- local dependency and backend boundary surfaces:
  - `build.zig.zon`
  - `build.zig`
  - `src/crypto/secp256k1_backend.zig`
  - `src/nip06_mnemonic.zig`
  - `src/bip85_derivation.zig`
- upstream evidence sources:
  - `bitcoin-core/secp256k1` official repository and releases:
    - <https://github.com/bitcoin-core/secp256k1>
    - <https://github.com/bitcoin-core/secp256k1/releases>
  - `ElementsProject/libwally-core` official repository:
    - <https://github.com/ElementsProject/libwally-core>

Explicit exclusions:
- line-by-line review of upstream C source internals
- fresh local protocol-framing or cryptographic-correctness review
- code fixes, pin changes, or dependency-policy changes

## Standards

- `docs/guides/IMPLEMENTATION_QUALITY_GATE.md`
- `docs/plans/external-crypto-backend-assurance-supplement.md`
- `docs/plans/audit-angle-standards.md`

## Coverage

Explicitly checked:
- current pinned source identity for both approved crypto backends
- official upstream release and security posture evidence for `secp256k1`
- official upstream project, configure/build, and security-reporting posture for `libwally-core`
- whether local `noztr` build-floor assumptions remain explicit enough relative to upstream
  documented module/configure expectations
- whether external evidence changes the current remediation or rewrite call

Explicitly not checked:
- upstream maintainer key verification performed locally on this machine
- source-level audit of upstream C internals
- packaging and release-signature verification automation in `noztr`

## Findings

### `secp256k1` external assurance is strong and the local build floor matches the intended module set

- severity: `low`
- evidence:
  - the official repository describes `libsecp256k1` as a high-assurance, no-runtime-dependency
    library and explicitly documents optional modules and tag-signature verification
  - the official releases page shows our pinned commit `0cdc758` as release `v0.6.0`
  - local `noztr` build wiring enables only the modules it actually uses:
    `SCHNORRSIG`, `EXTRAKEYS`, `ECDH`, and `RECOVERY`
- interpretation:
  - external assurance for the secp pin is good enough for the current remediation posture
  - the local build does not appear to depend on undocumented or ambient backend features
  - pin lag alone is not a rewrite or freeze blocker here

### The canonical `libwally` provenance story is currently weaker than the actual build pin

- severity: `medium`
- evidence:
  - `build.zig.zon` currently pins `libwally-core` to commit
    `455ec5b0188e1fc76f38c9b7aad7f4e24b421eb4`
  - canonical decision `D-035` still records `release_1.5.2` at commit
    `6439e6e3262c47ce0e51aa95d7b4ff67d9952c52`
  - the same older commit still appears in `docs/plans/phase-h-additional-nips-plan.md`
- interpretation:
  - the live build graph is still commit-plus-hash pinned, but the canonical recorded provenance no
    longer matches the actual pin
  - that is a real assurance and control-surface gap because pre-freeze confidence depends on the
    exact upstream identity being recorded truthfully
  - this is bounded remediation pressure, not major-rewrite pressure

### `libwally` external assurance is adequate, but local feature-floor assumptions should be recorded explicitly

- severity: `medium`
- evidence:
  - the official `libwally-core` repository documents a security-reporting path, minimal and
    standard-secp configure options, `--with-system-secp256k1`, and a WebAssembly constant-time
    caution
  - local `noztr` wiring compiles a hand-selected subset of libwally sources with:
    - `BUILD_MINIMAL`
    - `BUILD_STANDARD_SECP`
    - `WALLY_ABI_NO_ELEMENTS`
  - local `noztr` links libwally against the separately pinned `secp256k1` dependency rather than
    the upstream in-tree submodule default
- interpretation:
  - the current local build remains narrow and intentional, but the exact feature floor is still
    more implicit than ideal for external assurance
  - freeze confidence wants one canonical record of the approved backend pin plus the specific local
    build-floor assumptions
  - this strengthens the existing backend-boundary redesign lane; it does not create a new rewrite
    lane

## Accepted Exceptions

- `secp256k1` remains an approved pinned exception behind one narrow wrapper boundary
- `libwally-core` remains an approved pinned exception behind the derivation boundary
- the local build continues to use direct source selection instead of upstream autotools or CMake
  orchestration because the selected source floor is already intentionally narrower than a general
  upstream build

## Residual Risk

- `secp256k1` external assurance is stronger than `libwally` assurance in the current repo state
- the main remaining external-assurance risk is not primitive choice; it is provenance/control drift
  between the actual `libwally` pin and the canonical recorded pin plus build-floor assumptions
- this report does not independently verify upstream tag signatures or upstream maintainer key
  chains on this machine

## Synthesis Impact

- no major rewrite pressure added
- no change to the chosen bounded-redesign-first posture
- does refine remediation scope:
  - keep the existing `libwally` seam redesign lane
  - extend it to reconcile the canonical recorded `libwally` pin with the live build pin
  - record the approved backend feature floor explicitly as part of that same lane

## Completion Statement

This supplement is complete because:
- both approved crypto backends were checked against official upstream posture and the current local
  build assumptions
- the report is explicit about what was and was not externally assured
- the evidence is strong enough to revise the remediation synthesis without landing fixes

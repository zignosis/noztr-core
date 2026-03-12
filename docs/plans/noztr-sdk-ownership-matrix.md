# noztr vs SDK Ownership Matrix

Canonical boundary guide for deciding what belongs in the `noztr` protocol kernel versus the
future higher-level SDK.

## Purpose

Use this matrix when:
- reviewing NIP scope in `noztr`
- deciding whether a proposed helper belongs in Layer 1
- planning SDK responsibilities
- challenging older scope decisions that may have been too narrow or too broad

This is not a replacement for the decision log. The decision log remains the canonical source for
accepted defaults and reversals. This matrix is the operational map that keeps `noztr` and the SDK
from drifting into each other.

## Boundary Rule

Put behavior in `noztr` only when it is all of:
- protocol-facing
- pure and deterministic
- bounded and static-capacity
- reusable across many callers
- directly about parse, validate, serialize, verify, or fixed-capacity reduction

Put behavior in the SDK when it involves any of:
- network fetches or relay orchestration
- session lifecycle or connection management
- redirect, launch, or UI handoff policy
- provider-specific availability, retries, or rate limits
- local stores, caches, or sync policy
- app-flow convenience that is not protocol-kernel reuse

## Default Ownership Matrix

| Surface | `noztr` owns | SDK owns | Current posture |
| --- | --- | --- | --- |
| `NIP-46` remote signing | method/permission parsing, request/result parsing/building, envelope validation, URI parsing, signer discovery parsing, exact `<nostrconnect>` template substitution | relay pool control, signer session lifecycle, auth handling flow, URL launching, redirect policy, connection orchestration | deterministic helper glue belongs in `noztr`; client flow belongs in SDK |
| `NIP-24` extra metadata | bounded metadata extras, generic `r` / `title` / `t` tags | UX helpers and richer app-level metadata handling | keep current scope; add `i` support through `NIP-73` |
| `NIP-73` external ids | external-id parse/build/validate if accepted later | provider presets and higher-level workflows | missing dependency for fuller `NIP-24` / `NIP-39` support |
| `NIP-03` OpenTimestamps | attestation event parsing, bounded proof decode, bounded local proof verification floor | networked Bitcoin/esplora verification, remote proof-engine orchestration, caching/retry policy | bounded local verification may belong in `noztr`; networked verification does not |
| `NIP-39` external identities | claim extraction, canonical tag building, proof URL derivation, expected proof text | live provider fetch verification, trust policy, retries, provider adapters | live verification belongs in SDK |
| `NIP-29` relay groups | relay-generated event helpers, raw references, bounded user-event helpers, pure fixed-capacity state reduction | relay subscriptions, authority policy, sync/storage, moderation workflows, group client engine | pure reducers may belong in `noztr`; orchestration does not |
| `NIP-17` private messages | kind `14` / `15` parse, unwrap reuse, bounded relay-list helpers | attachment transfer workflow, mailbox policy, message sync/orchestration | current split is correct |
| `NIP-06` mnemonic and derivation | mnemonic validation, seed derivation, canonical key derivation, zeroization, typed errors | wallet UX, account management flow, secret storage policy | current split is correct |
| `NIP-44` / `NIP-59` crypto messaging | cryptographic framing, wrap/seal/rumor boundaries, checked decrypt/verify helpers | session management, key storage, mailbox workflow | current split is correct |
| `NIP-51` lists | bounded public/private list parse/build helpers | app list-management UX, sync/store policy, merge conflict policy | current split is correct |

## Review Questions

When a scope question comes up, answer these in order:
1. Is the behavior explicitly protocol-facing, or is it workflow around the protocol?
2. Can it be pure, deterministic, and fixed-capacity?
3. Would multiple SDK/app surfaces need the same logic?
4. Does putting it in `noztr` improve correctness or interoperability materially?
5. Would putting it in `noztr` pull in network, storage, UI, or policy concerns?

If the answer to `5` is yes, the behavior probably belongs in the SDK.

## Current Priority Implications

- `NIP-46`: add exact `<nostrconnect>` template substitution in `noztr` when useful.
- `NIP-73`: strongest missing protocol helper if we want fuller external-id support.
- `NIP-03`: bounded local proof verification is a valid future `noztr` improvement.
- `NIP-29`: pure fixed-capacity state reduction is a valid future `noztr` improvement.
- `NIP-39`: live verification should remain SDK work unless the project deliberately changes the
  kernel boundary.

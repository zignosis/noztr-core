---
title: Post-Audit Improvement Plan
doc_type: plan
status: active
owner: noztr
phase: phase-h
read_when:
  - planning_post_audit_improvements
  - executing_tigerbeetle_followups
  - preparing_freeze_confidence
depends_on:
  - docs/plans/phase-h-remaining-work.md
  - docs/research/libnostr-z-comparison-report.md
  - docs/research/tigerbeetle-zig-quality-report.md
  - docs/guides/IMPLEMENTATION_QUALITY_GATE.md
target_findings:
  - OQ-BV-003
  - OQ-BV-004
sync_touchpoints:
  - handoff.md
  - docs/plans/build-plan.md
  - docs/plans/phase-h-remaining-work.md
canonical: true
---

# Post-Audit Improvement Plan

This plan turns the completed `libnostr-z` and TigerBeetle report-only audits into one bounded
improvement program. It is not a broad rewrite plan. It exists to improve freeze confidence while
preserving the accepted `noztr` kernel posture.

## Purpose

- convert audit findings into a sequenced execution plan
- keep improvements narrow, evidence-backed, and aligned with `noztr`'s protocol-kernel scope
- separate changes that should happen before freeze confidence from changes that only need explicit
  acceptance or later review

## Governing Conclusions

- from `libnostr-z`:
  - keep the current `noztr` posture
  - do not widen into transport, runtime, or service layers
  - do not relax strict typed trust-boundary behavior just to mimic permissive references
  - keep reviewing scratch-heavy surfaces, but only change them when bounded fixed-capacity designs
    are realistic
- from TigerBeetle:
  - raise engineering sharpness on a narrow set of hotspots
  - reduce structural debt before claiming freeze confidence
  - challenge hidden state, overlong functions, weak assertion density, and allocator-backed public
    ingress

## Improvement Goals

1. Preserve the accepted kernel boundary while increasing implementation sharpness.
2. Remove the clearest Tiger-style structural debt from hot or public surfaces.
3. Make explicit-state and fixed-capacity exceptions either narrower or better justified.
4. Keep docs, examples, and audit artifacts aligned with the improved surface.
5. Reach a point where RC-freeze work is arguing over remaining product boundary questions rather
   than avoidable Zig-quality debt.

## Non-Goals

- adding runtime, relay-pool, websocket, storage, or SDK workflow layers to `noztr`
- broad allocator elimination at any cost
- changing accepted protocol semantics without separate evidence
- refactoring for style only where the current boundary is already clear, bounded, and tested

## Ordered Execution

### Slice 1: Structural Hotspots

Tracker lane:
- `no-ow4`

Target surfaces:
- `src/nip22_comments.zig`
- `src/nip46_remote_signing.zig`
- `src/nip47_wallet_connect.zig`
- `src/nip49_private_key_encryption.zig`

Goals:
- split overlong coordinator functions to satisfy the 70-line cap
- reduce branchy mixed-responsibility parsing/serialization coordinators into clearer staged helpers
- raise local assertion density on the public `NIP-49` boundary

Required checks:
- no accepted protocol behavior change unless separately justified
- builder/parser symmetry remains intact where applicable
- public invalid-vs-capacity behavior stays unchanged or gets strictly better
- touched public examples stay accurate

Closure bar:
- hotspot functions are structurally smaller and easier to audit
- public `NIP-49` entry points meet the repo’s assertion expectations
- `zig build test --summary all` and `zig build` pass

### Slice 2: Explicit-State And Fixed-Capacity Review

Tracker lane:
- `no-3jb`

Target surfaces:
- `src/nip06_mnemonic.zig`
- `src/nip05_identity.zig`
- `src/nip46_remote_signing.zig`
- `src/nip77_negentropy.zig`
- `src/internal/relay_origin.zig`

Goals:
- decide whether `NIP-06` global backend state can become explicit or more clearly isolated
- reduce allocator-backed public ingress where fixed-capacity decode is realistic
- explicitly accept bounded scratch-backed cases where change would add complexity without real
  trust-boundary benefit
- review `bool` / `?` boundary helpers and convert only the ones that materially benefit from typed
  reporting

Required checks:
- every retained exception must be documented as intentional, not accidental
- no new ambient mutable lifecycle should be introduced
- ownership and caller-buffer contracts must stay explicit
- avoid replacing bounded simple helpers with overengineered typed wrappers unless callers gain real
  clarity

Closure bar:
- each audited surface ends in one of:
  - refactored to a clearer fixed-capacity or explicit-state form
  - retained with explicit accepted rationale
- no hidden state or scratch-backed path remains unexplained
- `zig build test --summary all` and `zig build` pass if code changes

### Slice 3: Freeze-Readiness Consolidation

Depends on:
- `no-ow4`
- `no-3jb`

Goals:
- update the boundary-validation packet with the final post-audit result
- confirm whether any libnostr-z or TigerBeetle concern still blocks RC-freeze work
- keep the root facade protocol-only and the ownership matrix stable

Required checks:
- active docs reference the completed improvements rather than open audit narratives
- no stale watchlist item is still pretending to be “under review” after acceptance
- if a real blocker remains, open one bounded blocker lane instead of carrying vague debt forward

Closure bar:
- the post-audit plan becomes reference-only
- Phase H can either:
  - move to RC-freeze preparation, or
  - name one explicit remaining blocker packet

## Decision Rules

- Prefer targeted refactors over broad stylistic churn.
- Prefer explicit accepted exceptions over half-finished “future cleanup” language.
- Use `libnostr-z` only as a packaging and behavior signal, not as a memory or runtime model.
- Use TigerBeetle as an engineering bar, but adapt it to `noztr`’s protocol-kernel reality rather
  than copying application- or database-oriented structure mechanically.

## Success Criteria

- no obvious Tiger-style structural hotspot remains in the cited `NIP-22`, `NIP-46`, `NIP-47`, and
  `NIP-49` surfaces
- every remaining allocator-backed or hidden-state exception in the cited modules is either reduced
  or explicitly accepted with rationale
- docs and handoff routing point to concrete remaining work instead of generic post-audit intent
- Phase H boundary validation has enough evidence to stop using the audits as “open-ended review”
  lanes

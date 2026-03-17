---
title: Build Plan
doc_type: plan
status: active
owner: noztr
phase: phase-h
read_when:
  - starting_session
  - tracing_active_execution_baseline
  - updating_current_plan
depends_on:
  - docs/plans/nostr-principles.md
  - docs/plans/decision-index.md
  - docs/guides/IMPLEMENTATION_QUALITY_GATE.md
  - docs/plans/implemented-nip-review-guide.md
canonical: true
---

# noztr Build Plan

Date: 2026-03-09

Policy-routing note: use `docs/plans/decision-index.md` for startup routing and load
`docs/plans/decision-log.md` only when a cited decision or policy change requires the canonical
payload.

History-routing note: detailed phase/module history now lives in
`docs/archive/plans/build-plan-history.md`.

This artifact is the lean active execution baseline and is aligned to:

- `docs/plans/v1-scope.md`
- `docs/plans/v1-api-contracts.md`
- `docs/research/v1-implementation-decisions.md`
- `docs/guides/NOZTR_STYLE.md`
- frozen defaults `D-001`, `D-002`, `D-004`, and `D-036` in `docs/plans/nostr-principles.md`

## Decisions

- `PE-001`: freeze implementation sequencing into executable phases with measurable completion gates.
- `PE-002`: keep the deterministic-and-compatible Layer 1 posture (`D-036`) as canonical in all
  core entry points; compatibility remains explicit where it would blur trust-boundary contracts and
  must not degrade bounded deterministic behavior.
- `PE-003`: require parity-core `nip11` in the core delivery schedule and gate closure criteria.
- `PE-004`: preserve extension-lane placeholders as documentation-only (`H2/H3` roadmap lanes) with no
  v1 scope expansion.
- `PE-005`: carry only low/medium impact accepted-risk items into Phase F; no high-impact ambiguity may
  remain `decision-needed` at Phase E close.
- `PE-006`: security hardening defaults are frozen for implementation: reduced secp module surface,
  commit-SHA pinning, typed backend outage boundaries, strict transcript/auth wrappers, normalized
  NIP-42 relay path binding, unbracketed IPv6 authority rejection, and strict PoW commitment
  truthfulness/floor policy.
- `PE-007`: maintain a dedicated security hardening register in
  `docs/plans/security-hardening-register.md` and treat it as the canonical status tracker for
  low/edge security follow-ups.
- `PE-008`: start and track LLM-usability evaluation in
  `docs/plans/llm-usability-pass.md` before RC API freeze closure (`OQ-E-006`).
- `PE-009`: freeze Layer 1 trust-boundary defaults for current kernel boundaries (lowercase-only critical hex,
   deterministic `ids`/`authors` lowercase-prefix filter semantics (`1..64`), unknown filter-field
   rejection, strict relay `OK` rejection status-prefix validation, and path-bound `ws`/`wss`
   NIP-42 origin policy).
- `PE-010`: treat `docs/guides/NOZTR_STYLE.md` as the project-level strictness profile baseline for
  trust-boundary API shape, compatibility isolation, and caller-owned buffer conventions.
- `PE-011`: evaluate compatibility and ergonomics through an explicit Layer 2 adapter track; use
  `OQ-E-006` to decide adapter behavior and freeze it only after vectors and usability evidence.
- `PE-012`: adopt Phase F parity execution model v1 for interop parity-all lanes: canonical taxonomy
  (`LIB_SUPPORTED`, `HARNESS_COVERED`, `NOT_COVERED_IN_THIS_PASS`, `LIB_UNSUPPORTED`), canonical
  depth labels (`BASELINE`, `EDGE`, `DEEP`), non-zero exit only on `HARNESS_COVERED` failures,
  and no default use of overloaded `unsupported` wording.
- `PE-013`: restrict active parity gate operations to the rust lane (`rust-nostr`) and keep the
  TypeScript `nostr-tools` parity-all lane as a re-runnable non-gating audit evidence lane.
  - rationale note: `rust-nostr` is the active lane because it is a strong production reference and
    ecosystem proxy, not because it overrides NIP authority or Zig-native design goals.

## Strategic Posture

- Zig core-principles alignment: prioritize clarity, control, simplicity, explicit errors/memory,
  and deterministic outcomes because these properties preserve auditability and parity repeatability.
- Reference posture: active parity against `rust-nostr` is meant to increase ecosystem confidence
  and surface lessons from a strong deployed implementation, not to require mimicry of every edge
  behavior.
- Layer 1 posture: choose the narrowest deterministic behavior that remains correct, bounded,
  explicit, and ecosystem-compatible.
- Zig posture: preserve Zig-native API shape and bounded-system guarantees where they improve the
  library without breaking protocol or ecosystem correctness.
- Compatibility rule: do not reject input merely to express purity when the broader shape is still
  spec-valid, unambiguous, and bounded.
- Adapter rule: keep explicit compatibility adapters only for cases where broader acceptance would
  otherwise blur Layer 1 contracts.
- Architecture intent: strict kernel and compatibility adapter remain separated so interop improves
  without weakening trust-boundary defaults.

## Current Execution Baseline

- Active execution state remains Phase H on the post-Phase G local-only closure baseline.
- I0-I7 are complete. Detailed phase/module schedule and closure history now live in
  `docs/archive/plans/build-plan-history.md`.
- Rust parity remains the active gate lane. The TypeScript `nostr-tools` lane remains a re-runnable
  non-gating audit evidence lane.
- Phase G local-only release-readiness closure is complete. Remote readiness remains
  deferred-by-operator, and no git remote is configured in this repo.
- Phase H Wave 1, the implemented-NIP audit, Wave 2 / `NIP-46`, Wave 3 / `NIP-06`, and the
  post-Wave `NIP-51` private-list follow-up are complete.
- The post-kernel requested-NIP loop is complete through `NIP-B7`.
- Current live Phase H packet is `docs/plans/phase-h-remaining-work.md`.
- `OQ-E-006` usability closure is complete.
- Current remaining Phase H work is the explicit SDK-informed boundary-validation packet in
  `docs/plans/phase-h-remaining-work.md`.
- Boundary-validation has already accepted two kernel-side SDK handoff corrections:
  - public signed event-object JSON serialization
  - deterministic one-recipient `NIP-59` outbound transcript construction
- Boundary-validation has also completed a second full implemented-surface audit batch:
  - typed invalid-input fixes across `NIP-05`, `NIP-17`, `NIP-37`, `NIP-46`, `NIP-47`, `NIP-94`,
    and `NIP-99`
  - hostile example backfill on `NIP-03`, `NIP-17`, `NIP-37`, `NIP-42`, and `NIP-59`
- Boundary-validation has also closed the report-only `libnostr-z` comparison lane with no
  immediate kernel correction required.
- `docs/plans/post-kernel-requested-nips-loop.md` now remains as reference evidence for the loop
  order, closure rules, and split-surface scope calls rather than as an active execution packet.
- NIP-06 dependency strategy is resolved for current planning: adopt `libwally-core` behind the
  approved pinned crypto backend policy and a narrow boundary module.

## Active Execution Rules

- For any new implementation, audit, or robustness slice, use
  `docs/guides/IMPLEMENTATION_QUALITY_GATE.md`.
- For active Phase H remaining work and next-slice selection, use
  `docs/plans/phase-h-remaining-work.md`.
- The completed requested-NIP loop remains reference-only in
  `docs/plans/post-kernel-requested-nips-loop.md`.
- For implemented-surface audits or robustness work, use
  `docs/plans/implemented-nip-review-guide.md`.
- For kernel-vs-SDK ownership questions, use `docs/plans/noztr-sdk-ownership-matrix.md`.
- For split surfaces, stop at the deterministic protocol-kernel boundary and record the remaining
  SDK-side surface explicitly.
- For Blossom specifically, keep only deterministic kernel seams in `noztr`; route the full
  protocol/service stack to a dedicated repo that `nzdk` integrates rather than owns.
- Any default-affecting change still requires a canonical entry in `docs/plans/decision-log.md`.
- Docs/process closeout must restore the docs surface to steady state after the slice closes.

## Active References

- `docs/plans/decision-index.md`
  - startup route into accepted policy
- `docs/plans/phase-h-remaining-work.md`
  - current active Phase H packet and remaining-work routing
- `docs/guides/IMPLEMENTATION_QUALITY_GATE.md`
  - canonical staged gate for new slices
- `docs/plans/post-kernel-requested-nips-loop.md`
  - requested-NIP lane order and closure rules
- `docs/plans/implemented-nip-review-guide.md`
  - canonical review matrix plus audit/robustness execution model
- `docs/plans/llm-usability-pass.md`
  - closed `OQ-E-006` execution log and boundary-validation input
- `docs/plans/security-hardening-register.md`
  - canonical status tracker for hardening follow-ups
- `docs/plans/noztr-sdk-ownership-matrix.md`
  - kernel-vs-SDK ownership boundaries
- `docs/release/intentional-divergences.md`
  - accepted strict divergences from parity targets

## Active Risks And Open Questions

- execute the SDK-informed boundary-validation packet and make the result explicit.
- keep the completed `libnostr-z` comparison report as reference evidence; reopen only if later
  SDK or RC-freeze work surfaces a concrete contrary finding.
- RC API-freeze remains deferred until the boundary-validation slice closes.
- Layer 2 compatibility/ergonomic adapter work remains contingent; start it only if the
  boundary-validation pass finds a real blocker that belongs outside the kernel.
- `UT-E-003` and `UT-E-004` remain maintenance-mode items; reopen only on new behavior-class
  discovery.
- The deprecated `NIP-04` private-list adapter remains deferred unless real interoperability
  evidence justifies widening the kernel.
- Blossom scope remains intentionally narrow in `noztr`; revisit only if SDK-informed validation
  finds another bounded deterministic seam that materially improves interoperability.

## Active Quality Gates

- Code-change closure still requires:
  - `zig build test --summary all`
  - `zig build`
- No phase or slice closes with unresolved high-impact ambiguity.
- Canonical docs, examples, audits, and handoff state must match the accepted post-closeout state.

## Historical References

- `docs/archive/plans/build-plan-history.md`
  - archived execution narrative, old phase/module schedule, and old Phase E tradeoff snapshot
- `docs/plans/phase-h-kickoff.md`
  - completed Phase H kickoff packet retained for traceability
- `docs/plans/phase-h-additional-nips-plan.md`
  - completed Phase H expansion-planning packet retained for traceability
- `docs/plans/phase-h-wave1-loop.md`
  - completed Phase H Wave 1 packet retained for traceability
- `docs/plans/post-kernel-requested-nips-loop.md`
  - completed requested-NIP loop order, review model, and split-surface traceability
- `docs/archive/plans/phase-f-parity-matrix.md`
  - historical Phase F parity matrix
- `docs/archive/plans/phase-f-parity-ledger.md`
  - historical Phase F parity ledger
- `docs/archive/plans/phase-f-risk-burndown.md`
  - historical risk burn-down evidence

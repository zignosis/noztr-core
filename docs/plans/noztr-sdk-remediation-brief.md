---
title: noztr SDK Remediation Brief
doc_type: reference
status: active
owner: noztr
phase: phase-h
read_when:
  - syncing_remediation_changes_to_nzdk
  - checking_downstream_impact_of_noztr_changes
depends_on:
  - docs/plans/post-exhaustive-audit-remediation-plan.md
  - docs/plans/noztr-sdk-process-adaptation-brief.md
  - docs/research/exhaustive-audit-meta-analysis-report.md
  - docs/research/empirical-benchmark-supplement-report.md
  - docs/research/external-crypto-backend-assurance-report.md
canonical: true
---

# noztr SDK Remediation Brief

Structured downstream handoff surface for `nzdk` as the post-audit remediation program executes.

## Purpose

- keep `nzdk` informed about `noztr` remediation lanes in a stable, structured format
- separate:
  - what changed
  - what may affect `nzdk`
  - what `nzdk` should recheck
- avoid ad hoc narrative handoffs during multi-lane remediation

## Emission Rule

- keep this document current as the canonical downstream handoff source during remediation
- do not emit standalone `nzdk` prompts from in-flight lanes by default
- after the remediation program closes, point the downstream agent to this document and the landed
  supporting docs instead of rebuilding the history from chat state
- when the downstream need is process adaptation rather than contract drift, point to
  `docs/plans/noztr-sdk-process-adaptation-brief.md`

## Current State

- `no-65ev.1` has landed
- `no-65ev.2` has landed
- `no-65ev.3` has landed
- `no-65ev.4` has landed
- `no-65ev.5` has landed
- the RC API-freeze review `no-6e6p` is active
- the RC stress/throughput supplement `no-hd32` is complete
- the supplemental LLM structured usability audit is complete
- the empirical benchmark supplement is complete
- the external crypto/backend assurance supplement is complete
- the remediation program is complete
- the current surface still looks acceptable locally after the stress supplement, but final RC
  closure remains pending `nzdk` implementation feedback

## Downstream Read Set

- minimum current read set for `nzdk` review/update:
  - `docs/plans/noztr-sdk-remediation-brief.md`
  - `docs/plans/noztr-sdk-process-adaptation-brief.md`
  - `docs/research/post-remediation-freeze-recheck-report.md`
  - `docs/research/rc-api-freeze-review-report.md`
  - `docs/research/rc-stress-throughput-supplement-report.md`
  - `docs/plans/post-core-contract-map.md`
  - `examples/README.md`
- load specific `src/*` files only for the symbols touched by the lane being rechecked

## Breaking Changes Summary

- breaking or potentially breaking downstream-facing changes from remediation:
  - `no-65ev.1`
    - `nip44_get_conversation_key(...)` now returns `BackendUnavailable` distinctly
    - `delegation_signature_sign(...)` and `delegation_signature_verify(...)` now return
      `BackendUnavailable` distinctly
  - `no-65ev.2`
    - `nip25_reactions.reaction_classify_content(...)` changed from a plain classifier return to
      `ReactionError!ReactionType`
    - direct helper misuse on `NIP-86` and `NIP-46` now returns typed invalid-input errors where
      assertion-like behavior may previously have been assumed in tests or wrappers
- non-breaking remediation lanes:
  - `no-65ev.3`
    - docs/examples/discovery only
  - `no-65ev.4`
    - bounded local performance cleanup only; no intended semantic change
  - `no-65ev.5`
    - freeze recheck only
  - `no-6e6p`
    - RC-facing contract review only; no runtime change
  - `no-hd32`
    - stress/throughput supplement only; no runtime change

## Landed Remediation Updates

### `no-65ev.1`

- landed issue:
  - `no-65ev.1`
- affected public symbols:
  - `nip44_get_conversation_key(...)`
  - `delegation_signature_sign(...)`
  - `delegation_signature_verify(...)`
- exact public surface change:
  - `nip44_get_conversation_key(...)` now returns `BackendUnavailable` distinctly instead of
    collapsing backend outage into `EntropyUnavailable`
  - `delegation_signature_sign(...)` and `delegation_signature_verify(...)` now return
    `BackendUnavailable` distinctly instead of collapsing outage into `InvalidSecretKey` or
    `InvalidSignature`
  - `NIP-06` and `BIP-85` keep their public API shape, but now share one internal `libwally`
    backend seam instead of split readiness logic
- likely `nzdk` impact:
  - refresh any code or tests that treated those `NIP-44` / `NIP-26` paths as caller-blame-only
    failures
  - no intended happy-path behavior change on `NIP-06` or `BIP-85`
- concise downstream recheck prompt:
  - recheck conversation-key acquisition, delegation signing/verification, wallet bootstrap, and
    any `BIP-85` consumers for the new typed `BackendUnavailable` outcomes

### `no-65ev.2`

- landed issue:
  - `no-65ev.2`
- affected public symbols:
  - `nip86_relay_management.method_parse(...)`
  - `nip86_relay_management.request_parse_json(...)`
  - `nip86_relay_management.response_parse_json(...)`
  - `nip46_remote_signing.method_parse(...)`
  - `nip46_remote_signing.permission_parse(...)`
  - `nip25_reactions.reaction_classify_content(...)`
- exact public surface change:
  - `nip86_relay_management.method_parse(...)` now rejects overlong caller input as
    `InvalidMethod` instead of relying on debug assertions
  - `nip86_relay_management.request_parse_json(...)` and
    `nip86_relay_management.response_parse_json(...)` now reject overlong caller input as
    `InvalidRequest` and `InvalidResponse`
  - `nip46_remote_signing.method_parse(...)` now rejects overlong caller input as `InvalidMethod`
  - `nip46_remote_signing.permission_parse(...)` now rejects overlong scoped caller input as
    `InvalidPermission`
  - `nip25_reactions.reaction_classify_content(...)` now returns
    `ReactionError!ReactionType` and rejects overlong or non-UTF-8 direct input as
    `InvalidContent`
- likely `nzdk` impact:
  - refresh any tests or wrappers that depended on assertion-like failure behavior for direct
    helper misuse
  - update any direct `reaction_classify_content(...)` call sites for the new error-returning
    contract
- concise downstream recheck prompt:
  - recheck direct admin-helper use, direct remote-signing token helper use, and any direct
    reaction-content classification call sites for the tightened typed failure contracts

### `no-65ev.3`

- landed issue:
  - `no-65ev.3`
- affected public symbols:
  - none intended; docs/examples/discovery only
- exact public surface change:
  - added `docs/plans/post-core-contract-map.md` as the current task-to-symbol route for the main
    post-core public surfaces
  - strengthened `examples/README.md` with a public-symbol routing table, corrected `NIP-59`
    successful outbound-path routing, and added hostile `NIP-05` example coverage
  - refreshed the root `README.md` so it points to the current Phase H and remediation state
- likely `nzdk` impact:
  - easier routing to the correct docs and examples
  - no intended runtime contract change
- concise downstream recheck prompt:
  - refresh any internal links or onboarding notes to use the new post-core contract map and the
    corrected examples routing; no code changes expected by default

## Recent And Open Lane Handoff Inputs

### `no-65ev.4`

- likely affected public symbols:
  - `nip88_polls.tally_reduce(...)`
  - `nip29_groups.reduce_events(...)`
  - any adjacent reducer helper touched in the same bounded slice
- likely `nzdk` impact:
  - landed: no intended semantic change
  - only recheck if `nzdk` relies on specific complexity or local ordering assumptions
- downstream document bundle after landing:
  - `docs/research/empirical-benchmark-supplement-report.md`
  - `docs/plans/post-exhaustive-audit-remediation-plan.md`
- landed notes:
  - `NIP-88` tally reduction and `NIP-29` batch replay now use bounded reducer-local index caches
    to remove repeated linear lookup pressure
  - no public API or happy-path semantic change is intended
  - benchmark rerun materially lowered the named hotspots

### `no-65ev.5`

- likely affected public symbols:
  - none by default
- likely `nzdk` impact:
  - landed: no direct runtime change
  - no new blocker was found in the freeze recheck
- downstream document bundle after landing:
  - `docs/research/post-remediation-freeze-recheck-report.md`
  - `docs/plans/phase-h-rc-api-freeze.md`
  - current handoff/build-plan state
- landed notes:
  - the post-remediation freeze recheck passed
  - the freeze recheck justified the RC API-freeze review in `no-6e6p`, which remains open
  - downstream should keep using this brief plus the freeze-recheck report instead of chat history

### `no-6e6p`

- active issue:
  - `no-6e6p`
- affected public symbols:
  - none; release-facing review only
- exact public surface change:
  - no runtime contract change
  - local RC review evidence remains positive so far
  - root `README.md` routing is corrected so it no longer points downstream readers at the
    completed remediation packet as current work
- likely `nzdk` impact:
  - no runtime change
  - downstream should use this brief plus the RC review report to confirm or challenge the local RC
  review result
- concise downstream recheck prompt:
  - review this brief plus `docs/research/rc-api-freeze-review-report.md`, then report any
    contrary implementation feedback before RC closure

### `no-hd32`

- landed issue:
  - `no-hd32`
- affected public symbols:
  - none; stress/throughput evidence only
- exact public surface change:
  - no runtime contract change
  - bounded repeated-run and concurrent local workloads stayed clear on the named hotspot families
- likely `nzdk` impact:
  - no runtime change
  - use the supplement report only as additional local confidence evidence
- concise downstream recheck prompt:
  - no code change expected from this supplement by default; review only if you need the stronger
    local throughput/stress evidence

## Remediation Lanes

| Lane | Kernel scope | Likely `nzdk` impact | `nzdk` recheck after landing | Current status |
| --- | --- | --- | --- | --- |
| `no-65ev.1` | `libwally` seam, `NIP-06`, `BIP-85`, `NIP-44`, `NIP-26` backend-outage mapping, and backend provenance/build-floor reconciliation | landed: typed outage handling tightened on `NIP-44` / `NIP-26`; no intended happy-path API expansion | wallet/bootstrap, delegation, conversation-key acquisition, BIP-85 consumers | landed |
| `no-65ev.2` | `NIP-86`, `NIP-46`, `NIP-25` public helper hardening | landed: direct helper misuse now stays on typed errors; `reaction_classify_content(...)` now returns `ReactionError!ReactionType` | admin helper wrappers, remote-signing helper tests, any direct reaction helper use | landed |
| `no-65ev.3` | examples/docs/discovery only | landed: stronger docs/example routing, no intended runtime contract change | docs/examples references only | landed |
| `no-65ev.4` | `NIP-88`, `NIP-29` local performance cleanup; `NIP-06` only if touched indirectly by backend redesign | landed: bounded reducer-local caches, no intended happy-path API change | only if `nzdk` relies on specific complexity or ordering assumptions | landed |
| `no-65ev.5` | freeze recheck only | landed: no direct runtime change, no new blocker found | none by default; follow the freeze-recheck report and RC packet | landed |
| `no-6e6p` | RC-facing contract review only | in progress: no runtime change; local RC review is positive so far | use the brief plus RC review report to confirm or challenge closure | open |
| `no-hd32` | stress/throughput supplement only | landed: no runtime change; local throughput/stress evidence stayed clear | none by default; use only if stronger local performance evidence is helpful | landed |

## Update Rule

When a remediation lane lands, update this brief with:
- landed issue ID
- exact public surface change, if any
- exact `nzdk` impact, if any
- concise downstream recheck prompt

If a lane has no downstream impact, say so explicitly.

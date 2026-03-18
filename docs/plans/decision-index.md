---
title: Decision Index
doc_type: index
status: active
owner: noztr
read_when:
  - starting_session
  - tracing_policy_for_current_work
  - deciding_whether_the_full_decision_log_is_needed
depends_on:
  - docs/plans/decision-log.md
canonical: true
---

# Decision Index

Use this file to decide whether the full canonical decision payload is needed.

## Routing Rule

- read this index by default
- load `docs/plans/decision-log.md` only when:
  - the current task changes defaults or process policy
  - a plan, packet, audit, or handoff cites a specific decision ID
  - a review or audit needs the exact canonical payload
- some frozen defaults still live in `docs/plans/nostr-principles.md`; for example, `D-036` is not
  in `decision-log.md`

## Search Rule

- exact decision lookup:
  - `rg -n "^## D-103:" docs/plans/decision-log.md`
- decision-title scan:
  - `rg -n "^## D-" docs/plans/decision-log.md`

## Core Defaults And Parity Posture

- `D-001` freeze parity source snapshots
- `D-002` define parity as behavior, not API shape
- `D-003` strict-by-default protocol policy
- `D-004` mandatory phase closure gate

## Trust-Boundary Hardening

- `D-005` typed backend-outage errors at verify/auth trust boundaries
- `D-006` NIP-42 strict hardening semantics
- `D-007` freeze checked wrappers for strict call sites
- `D-008` secp boundary hardening and source pinning
- `D-010` NIP-42 auth boundary hardening follow-up
- `D-011` low-hardening strictness and edge-audit closure
- `D-013` finalize NIP-42 relay matching and PoW commitment hardening semantics

## Execution And Quality Process

- `D-012` dedicated security hardening register
- `D-014` start LLM-usability pass and track `OQ-E-006` closure criteria
- `D-015` record Tiger cleanliness and strictness-profile evaluation inputs
- `D-103` tighten requested-NIP closure with reject-corpus and assertion-leak checks
- `D-113` codify explicit review prompts and a shareable process-refinement playbook
- `D-114` add ordered micro-loop and audit-posture refinement guidance
- `D-115` treat process updates as coherent control-surface edits
- `D-116` restore active Phase H packet routing and split the generic implementation gate from
  specialized audit guidance
- `D-117` close `OQ-E-006` with teaching-surface fixes and carry current strict defaults forward as
  RC-freeze inputs
- `D-118` require explicit example-layer contract checks for example-bearing slices
- `D-121` codify generalized audit-hardening checks for public invalid-input paths and same-slice
  audit synchronization
- `D-122` require audit-first separation and meta-analysis before pre-freeze remediation or rewrite
- `D-123` require matrix-driven execution standards for the exhaustive pre-freeze audit
- `D-124` forbid in-audit fixes, split cryptographic audit lanes, and require whole-codebase coverage

## Docs And Active-Memory Routing

- `D-108` adopt lean control-surface rules for docs and handoff state
- `D-109` adopt unified docs frontmatter schema and decision-index routing

## Ownership And Boundary Calls

- `D-112` accept bounded `NIP-B7` Blossom server-list and fallback helpers
- `D-119` keep full Blossom protocol/service work out of `noztr` and route it to a dedicated repo
  that `nzdk` integrates
- `D-120` accept deterministic one-recipient outbound `NIP-59` transcript construction in `noztr`
  while keeping mailbox fanout and workflow in `nzdk`
- `D-125` consolidate the `libwally` backend seam and reconcile the live backend pin/build floor

## Recent Requested-NIP Acceptances

- `D-097` accept bounded `NIP-99` classified-listing metadata helpers
- `D-098` accept bounded `NIP-B0` web-bookmarking helpers
- `D-099` accept bounded public Nostr key helpers plus canonical SDK handoff recipes
- `D-100` accept bounded `NIP-29` reducer replay compatibility for `previous` tags
- `D-101` accept bounded `NIP-C0` code-snippet metadata helpers
- `D-102` accept bounded `NIP-64` chess PGN helpers with structural validation only
- `D-104` accept bounded `NIP-88` poll metadata helpers and pure tally reduction
- `D-105` accept bounded `NIP-49` private-key encryption with internal `NFKC` normalization
- `D-106` accept bounded `NIP-98` HTTP-auth event and header helpers
- `D-107` accept bounded `NIP-47` Wallet Connect kernel helpers

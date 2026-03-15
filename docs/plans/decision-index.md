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

## Docs And Active-Memory Routing

- `D-108` adopt lean control-surface rules for docs and handoff state
- `D-109` adopt unified docs frontmatter schema and decision-index routing

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

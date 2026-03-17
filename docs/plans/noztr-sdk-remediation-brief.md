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
  - docs/research/exhaustive-audit-meta-analysis-report.md
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

## Current State

- no remediation fixes have landed yet
- the supplemental LLM structured usability audit is complete
- remediation execution is now allowed to begin under the revised synthesis

## Remediation Lanes

| Lane | Kernel scope | Likely `nzdk` impact | `nzdk` recheck after landing | Current status |
| --- | --- | --- | --- | --- |
| `no-65ev.1` | `libwally` seam, `NIP-06`, `BIP-85`, `NIP-44`, `NIP-26` backend-outage mapping | possible typed error or boundary-contract changes in crypto-bearing helpers | wallet/bootstrap, delegation, conversation-key acquisition, BIP-85 consumers | deferred |
| `no-65ev.2` | `NIP-86`, `NIP-46`, `NIP-25` public helper hardening | direct helper failure behavior may tighten | admin helper wrappers, remote-signing helper tests, any direct reaction helper use | deferred |
| `no-65ev.3` | examples/docs/discovery only | teaching/discovery updates, no runtime contract change intended | docs/examples references only | deferred |
| `no-65ev.4` | `NIP-88`, `NIP-29`, `NIP-06` local performance cleanup | no intended happy-path API change | only if `nzdk` relies on specific complexity or ordering assumptions | deferred |
| `no-65ev.5` | freeze recheck only | no direct runtime change | none unless new blocker is found | deferred |

## Update Rule

When a remediation lane lands, update this brief with:
- landed issue ID
- exact public surface change, if any
- exact `nzdk` impact, if any
- concise downstream recheck prompt

If a lane has no downstream impact, say so explicitly.

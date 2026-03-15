---
title: Process Control
doc_type: policy
status: active
owner: noztr
read_when:
  - refining_process
  - reducing_doc_bloat_without_losing_rigor
  - updating_control_docs
---

# Process Control

Repo-specific refinement rules for keeping `noztr` rigorous without turning every doc into a full
history dump.

## Core Rule

Do not try to make every active doc complete.

Instead:
- keep one canonical doc for each rule set
- keep most other docs delta-oriented
- keep handoff state-only
- move history to decision records, reference docs, archive, or git history

## Doc Roles

- `policy`
  - canonical rules and gates
- `state`
  - current lane, next work, and repo status
- `packet`
  - lane- or slice-specific execution context
- `audit`
  - posture-specific findings with stable IDs
- `reference`
  - accepted background and stable guidance
- `archive`
  - historical provenance, not startup guidance

## Canonical Owners

- `AGENTS.md`
  - agent operating rules
- `handoff.md`
  - current status only
- `docs/plans/build-plan.md`
  - active execution baseline
- `docs/plans/decision-log.md`
  - accepted defaults and policy changes
- `docs/README.md`
  - docs routing and role separation

If another doc starts repeating those responsibilities, slim it or reclassify it.

## Repo-Specific Audit Postures

`noztr` should keep audits posture-specific rather than using one vague “quality” pass.

Current useful postures:
- trust-boundary posture
  - does the public parser/builder/error contract reject the right bad inputs?
- kernel-boundary posture
  - does the surface stay inside deterministic protocol-kernel ownership?
- docs/discoverability posture
  - can an agent or maintainer find the current control surface without reading repo history?

## Stable Finding IDs

Process and doc audits should use stable IDs.

Suggested pattern:
- `DOC-<area>-<number>`
- `PROC-<area>-<number>`

The exact naming scheme matters less than keeping findings addressable and reusable across handoff,
packets, and follow-up work.

## Handoff Rule

`handoff.md` must carry:
- current status
- read first
- active control docs
- next work
- critical process rules
- current repo state that can block the next session

`handoff.md` must not become:
- a running changelog
- a full requested-NIP ledger
- a second decision log
- a place to preserve historical rationale already recorded elsewhere

## Packet Rule

Packet docs should record slice-specific deltas only.

They should mostly contain:
- scope delta
- slice-specific seam constraints
- targeted findings or open questions
- closeout conditions

If a packet starts restating the full process, the control docs are not centralized enough.

## Refinement Rule

When refining an existing slice or the process itself:
1. identify the targeted finding IDs
2. state which posture is being tightened
3. implement the change
4. rerun the relevant checks
5. update the audit doc explicitly

## Archive Rule

If a doc no longer controls current work, move it out of the startup path.

Good candidates for archive or de-emphasis:
- completed execution loops
- superseded handoff-style narratives
- bootstrap planning packets whose decisions are already accepted

## Minimal Standard

Any future process tightening should preserve these properties:
- one canonical rule owner per rule set
- one short current handoff
- one docs index
- posture-specific audits instead of generic quality prose
- no active doc should have to carry history just to remain understandable

---
title: Process Control
doc_type: policy
status: active
owner: noztr
read_when:
  - refining_process
  - reducing_doc_bloat_without_losing_rigor
  - updating_control_docs
canonical: true
---

# Process Control

Canonical repo rules for keeping `noztr` rigorous without letting the active docs surface turn into
an append-only history.

For rationale, transferable lessons, and cross-repo sharing guidance, use
`docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md`.

## Core Rule

Do not try to make every active doc complete.

Instead:
- keep one canonical owner per rule set
- keep most other docs delta-oriented
- keep handoff state-only
- move history to decisions, archive, or git history

## Doc Roles

- `index`
  - routes readers to the canonical owner or next required doc
- `policy`
  - canonical rules and gates
- `state`
  - current lane, next work, and repo status
- `plan`
  - active execution baseline and accepted sequencing
- `packet`
  - lane- or slice-specific execution context
- `audit`
  - posture-specific live findings with stable IDs
- `log`
  - ongoing issue or feedback tracking that is useful but not startup-critical
- `reference`
  - accepted background and stable guidance
- `archive`
  - historical provenance, not startup guidance

## Canonical Owners

- `docs/README.md`
  - docs routing and role separation
- `AGENTS.md`
  - agent operating rules
- `handoff.md`
  - current status only
- `docs/plans/decision-index.md`
  - startup route into accepted policy areas
- `docs/plans/build-plan.md`
  - active execution baseline
- `docs/plans/decision-log.md`
  - canonical accepted defaults and policy changes

If another doc starts repeating those responsibilities, slim it, merge it, or reclassify it.

## Shared Frontmatter Standard

Use one shared frontmatter schema across projects, but only populate fields that carry signal for
the current doc.

Supported keys:
- `title`
- `doc_type`
- `status`
- `owner`
- `read_when`
- `nips`
- `depends_on`
- `target_findings`
- `sync_touchpoints`
- `supersedes`
- `posture`
- `phase`
- `canonical`
- `archive_of`

Population rule:
- keep the schema stable across projects
- omit keys that are not relevant instead of adding empty placeholders
- frontmatter is required on control docs, active plans, packet docs, audits, and long-lived
  reference docs that participate in routing
- vendored or archival material can stay lighter unless it needs routing metadata

## Decision Routing Rule

- `docs/plans/decision-index.md` is the startup route into accepted policy
- `docs/plans/decision-log.md` remains canonical, but it is reference-sized and should be loaded
  on demand
- load the full decision entry only when:
  - a task changes defaults or process policy
  - a plan, packet, audit, or handoff cites a specific decision ID
  - a review or audit needs the exact canonical payload

## Audit Posture Rule

Keep audits posture-specific rather than using one vague “quality” pass.

Current useful postures:
- trust-boundary posture
  - does the public parser/builder/error contract reject the right bad inputs?
- kernel-boundary posture
  - does the surface stay inside deterministic protocol-kernel ownership?
- docs/discoverability posture
  - can an agent or maintainer find the current control surface without rereading repo history?

Choose or revise postures from real repo failure modes:
- what kind of mistake hurts this repo most?
- what kind of mistake is easy to miss in normal code review?
- what kind of pressure should shape API or workflow decisions beyond raw correctness?

## Stable Finding ID Rule

Process and doc audits should use stable IDs.

Suggested pattern:
- `DOC-<area>-<number>`
- `PROC-<area>-<number>`

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

## Process-Change Rule

Do not treat a material process update as additive by default.

When process changes materially:
1. identify the canonical docs it changes
2. review them together as one control surface
3. remove or rewrite superseded wording
4. add only the minimum new wording still required
5. verify startup docs, state docs, reference docs, templates, and audits now agree

The goal is to avoid two quiet failure modes:
- contradictory control guidance
- append-only history living inside active docs

## Refinement Rule

When refining an existing slice or the process itself:
1. identify the targeted finding IDs
2. state which posture is being tightened
3. implement the change
4. run the canonical staged execution order that applies to the slice
5. rerun the relevant checks and audit frames
6. update the audit doc explicitly

When the refinement comes from a real escaped bug class:
- add one concrete prompt or checklist item that would have caught it
- prefer narrow prompts over broader prose
- record the lesson in `docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md` if it is worth sharing across
  repos or future slices

## Micro-Freeze Rule

For new or materially expanded trust-boundary surfaces, the freeze note should cover:
- scope
  - supported kinds, required and optional fields, multiplicity, normalization, and non-goals
- boundary
  - intended scan regions, accepted equivalent valid forms, canonical emitted forms
- invalid-vs-capacity matrix
  - what maps to invalid input, what maps to capacity failure, and what must never hit assertions
- reject corpus
  - the minimum hostile set required for the slice

The freeze note can live in a packet, handoff, or decision entry, but it should be explicit enough
that Review A validates a known contract rather than discovering one from code alone.

## Review Prompt Rule

When a slice has public parser or builder trust boundaries, Review A and Review B should use
explicit prompts instead of generic “correctness” language.

Minimum Review A prompts:
- can any user-controlled invalid input still panic or trip a debug assertion?
- can invalid input still leak as a capacity error?
- can capacity failure still leak as an invalid-input error?
- does any scan escape the intended syntactic region?
- does the parser accept nonsense just because delimiters balance?

Minimum Review B prompts:
- did canonicalization become over-strict input validation?
- did the surface stay inside deterministic kernel ownership?
- did workflow or policy behavior leak in from the SDK layer?
- do the examples show both intended use and intended rejection?

## Synchronization Rule

When a packet or refinement slice is created, declare the closeout touchpoints early enough that
they do not get missed at the end.

Use a short declaration for whether the slice changes:
- teaching surface
  - examples, README/discovery surface, or public usage guidance
- audit state
  - findings, posture status, accepted-risk state, or review conclusions
- startup or discovery docs
  - handoff, docs index, active packet routing, or other startup-path docs

The declaration should stay short and act as a closeout checklist, not as a new workflow phase.

## Closeout Consistency Rule

Closing a slice or process-refinement pass means restoring the docs surface to steady state, not
just landing the main content change.

Required closeout steps:
1. update the targeted audit findings immediately
2. update examples or discovery catalogs if the public teaching surface changed
3. remove temporary packet or startup emphasis if the slice is no longer active
4. make handoff point at the new next work instead of the slice that just closed

## Archive Rule

If a doc no longer controls current work, move it out of the startup path.

Good candidates for archive or de-emphasis:
- completed execution loops
- superseded handoff-style narratives
- bootstrap planning packets whose decisions are already accepted
- temporary closeout packets once their deltas are absorbed into the steady-state control docs
- resolved audit-history material that no longer needs to live in the active audit file

## Transfer Rule

If a process lesson is mature enough to teach another repo or agent:
- keep the canonical local rule in `PROCESS_CONTROL.md`
- capture the reusable lesson in `PROCESS_REFINEMENT_PLAYBOOK.md`
- update `docs/README.md` and `AGENTS.md` so the playbook is discoverable on demand
- keep the playbook as reference, not as a second canonical process owner

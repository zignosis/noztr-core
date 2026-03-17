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
- `docs/guides/IMPLEMENTATION_QUALITY_GATE.md`
  - canonical staged implementation, audit, and robustness gate
- `handoff.md`
  - current status only
- `docs/plans/decision-index.md`
  - startup route into accepted policy areas
- `docs/plans/build-plan.md`
  - active execution baseline
- `docs/plans/packet-template.md`
  - shared packet skeleton and minimum packet shape
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

For high-impact pre-freeze audit programs:
- define the required audit angles explicitly up front
- keep one live coverage ledger that shows what is:
  - not started
  - in progress
  - complete
  - not applicable
- require one dedicated report per angle
- do not collapse targeted follow-up lanes into “exhaustive audit” language

Minimum pre-freeze audit angles unless a packet justifies narrower scope:
- protocol correctness
- ecosystem parity / interoperability
- security / misuse resistance
- cryptographic correctness / secret handling
- crypto/backend-wrapper quality
- Zig engineering quality
- performance / memory posture
- API consistency / determinism
- docs/examples / discoverability

Each angle report must state:
- exact scope
- evidence sources
- standards used
- what was explicitly checked
- what was explicitly not checked
- findings
- accepted exceptions
- residual risk
- proposed follow-up lanes if needed

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
- pointers to canonical docs rather than copied doctrine where possible

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

When a phase remains active after one packet closes:
- create or update the current remaining-work packet for that phase
- mark the completed packet `reference` or move it to archive
- do not leave startup routing pointed at the last completed lane

Packets should use `docs/guides/IMPLEMENTATION_QUALITY_GATE.md` for the generic staged loop and
reserve their own content for slice-specific deltas.

For high-impact audit programs, the active packet should also make explicit:
- whether the current lane is evidence-only or code-changing
- which later lane owns synthesis
- which later lane, if any, owns fixes or rewrite execution

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

When the escaped bug class is pass-specific:
- codify the generalized failure pattern, not the exact module or NIP
- keep incident-specific details in audits, tests, or decision records instead of promoting them
  into repo-wide doctrine

## Audit-Then-Fix Rule

When the repo is running a high-impact multi-angle audit program:
1. finish the required audit angles first
2. keep the audit lanes evidence-producing by default
3. maintain one live working draft or coverage ledger during the audit
4. perform one explicit meta-analysis after the reports exist
5. only then decide between:
   - targeted fixes
   - bounded redesign
   - major rewrite

During that kind of audit program:
- do not land fixes during the audit program
- record the issue, severity, and likely remediation in the report and defer execution until after
  meta-analysis

The point is to avoid three failure modes:
- losing the cross-report pattern inside local patch churn
- underestimating rewrite pressure because symptoms were patched too early
- overcommitting to rewrite before the reports show which issues are systemic

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

For public parser/builder/validator families, the freeze should also identify:
- which representative overlong-input cases must stay on typed invalid-input errors
- which helper chains are expected to reject before any internal invariant or assertion matters

## Review Prompt Rule

When a slice has public parser or builder trust boundaries, Review A and Review B should use
explicit prompts instead of generic “correctness” language.

Minimum Review A prompts:
- can any user-controlled invalid input still panic or trip a debug assertion?
- can any public invalid input still reach an internal helper invariant before typed validation?
- can invalid input still leak as a capacity error?
- can capacity failure still leak as an invalid-input error?
- does any scan escape the intended syntactic region?
- does the parser accept nonsense just because delimiters balance?

Required pre-Review-A check for public trust-boundary slices:
- run one targeted assertion-leak scan on the touched parser/builder/validator chains
  - the point is not to remove all assertions
  - the point is to confirm that caller-controlled invalid input is rejected on typed public paths
    before helper invariants matter

Minimum Review B prompts:
- did canonicalization become over-strict input validation?
- did the surface stay inside deterministic kernel ownership?
- did workflow or policy behavior leak in from the SDK layer?
- do the examples show both intended use and intended rejection?
- do the examples teach the right contract layer instead of mixing:
  - full object JSON
  - canonical preimage
  - message envelope
  - checked wrapper result

## Example Contract Rule

When a slice adds or changes examples, make the example contract layer explicit.

Common layers that must not be casually mixed:
- full object JSON
- canonical preimage
- message envelope
- checked wrapper result

If an example claims parse/serialize round-trip:
- verify that the parser and serializer operate on the same layer
- say when a serializer is only for id-preimage or envelope output rather than full object parsing
- do not let a plausible-looking example become the first place a semantic contract bug hides

For SDK-facing split surfaces:
- hostile examples are mandatory, not discretionary polish
- the hostile example should show at least one caller-visible typed rejection that a consumer is
  likely to hit in practice

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
4. update canonical audit/report artifacts in the same slice when accepted behavior or live
   findings changed
5. make handoff point at the new next work instead of the slice that just closed

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

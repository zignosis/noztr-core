---
title: Implementation Quality Gate
doc_type: policy
status: active
owner: noztr
read_when:
  - starting_new_implementation_slice
  - starting_new_audit_slice
  - reviewing_candidate_closeout
depends_on:
  - AGENTS.md
  - docs/guides/PROCESS_CONTROL.md
  - docs/plans/decision-index.md
canonical: true
---

# Implementation Quality Gate

Canonical staged execution order for `noztr` implementation, audit, and robustness slices.

Use this gate for any new code-bearing or behavior-changing slice unless a more specific packet adds
only slice-specific deltas. Do not restate this whole loop inside a packet.

Specialized references:
- `docs/plans/implemented-nip-review-guide.md`
  - implemented-NIP audit and robustness-specific review posture
- `docs/plans/packet-template.md`
  - shared packet skeleton for new active slices

## Audit-Only Override

Some slices are evidence-first by design.

When an active packet declares an audit-only or report-only posture:
- use this gate to freeze scope, run reviews, and synchronize docs/reporting
- do not treat implementation/fix steps as the default closure path
- record findings, accepted exceptions, and blockers in the report artifact first
- defer non-critical fixes until the declared synthesis or meta-analysis lane

Only break audit-only posture early for:
- broken builds
- safety-critical defects
- findings that would make the ongoing audit evidence false or materially misleading

## Gate Order

1. Tracker and freeze
   - claim the `br` issue
   - freeze the exact slice and non-goals
   - record the micro-freeze:
     - scope and non-goals
     - accepted valid input versus canonical emitted output
     - invalid-vs-capacity matrix
     - reject corpus where needed
     - sync touchpoints
     - representative overlong-input cases for each public builder/parser family touched
   - stop if the slice requires a frozen-default change

2. Implement the accepted slice
   - keep the surface bounded, deterministic, and inside protocol-kernel ownership
   - add tests and examples with the code instead of later
   - do not widen scope to absorb adjacent workflow or SDK behavior
   - if examples are part of the slice, make the contract layer explicit:
     - full object JSON
     - canonical preimage
     - message envelope
     - checked wrapper result
   - if the slice is audit-only, reinterpret this step as:
     - gather evidence for the accepted audit scope
     - update the live working draft or report artifact
     - do not open broad remediation work inside the same lane by default

3. Review A
   - validate correctness, trust-boundary behavior, and parity/evidence posture
   - run one targeted assertion-leak scan on touched public parser/builder/validator chains
   - minimum prompts for parser/builder trust boundaries:
     - can invalid input still panic or hit a debug assertion
     - can public invalid input still reach an internal helper invariant before typed validation
     - can invalid input still leak as a capacity error
     - can capacity failure still leak as an invalid-input error
     - does any scan escape the intended syntactic region
     - does the parser accept nonsense because delimiters balance

4. Fix Review A findings
   - for audit-only slices, record Review A findings and defer non-critical fixes to post-audit
     synthesis unless the active packet explicitly allows immediate correction

5. Review B
   - validate kernel-vs-SDK ownership, usability, overengineering, and final public teaching shape
   - minimum prompts:
     - did canonicalization become over-strict input validation
     - did the surface stay inside deterministic kernel ownership
     - did workflow or policy behavior leak in from the SDK layer
     - do examples show intended use and intended rejection
     - do examples teach the correct contract layer instead of crossing full object JSON, canonical
       preimage, message envelope, or checked wrapper semantics

6. Fix Review B findings
   - for audit-only slices, record Review B findings and defer non-critical fixes to post-audit
     synthesis unless the active packet explicitly allows immediate correction

7. Adversarial audit
   - force public error variants directly
   - run builder/parser symmetry where both surfaces exist
   - run hostile and contradictory inputs where the surface warrants them
   - for each touched public builder/parser family, include at least one representative overlong
     input case that proves typed invalid-input handling on the public path
   - for tokenized or sectioned grammars, challenge nonsense tokens and separator discipline
   - when reference evidence is weak or `LIB_UNSUPPORTED`, rerun the spec-first challenge pass
   - for example-bearing slices, verify that any claimed parse/serialize round-trip stays within one
     contract layer

8. Green gates
   - run focused checks first when useful
   - if code changed, final closure requires fresh:
     - `zig build test --summary all`
     - `zig build`
   - docs-only passes do not need Zig gates, but they still need routing and coherence review

9. Closeout synchronization
   - apply the declared sync touchpoints explicitly:
     - teaching surface
     - audit state
     - startup and discovery docs
   - if the slice is an audit or robustness pass, update the canonical audit/report artifact in the
     same slice when accepted behavior or live findings changed
   - update canonical docs only where policy, accepted behavior, or current state changed
   - if no canonical doc changed, record that explicitly in tracker evidence

10. Scoped landing
   - make one scoped git commit for the completed slice
   - close or update the `br` issue
   - if tracker state changed:
     - `br ...`
     - `br sync --flush-only`
      - `git add .beads/`
      - `git commit -m "sync beads"`

For multi-angle pre-freeze audit programs, the scoped landing for an audit lane should usually be:
- report or working-draft updates
- tracker state updates
- no code changes unless the audit-only override allowed a critical correction

## Required Outputs

- one explicit freeze note
- one Review A result
- one Review B result
- one adversarial audit result
- fresh final gate result when code changed
- explicit docs/examples closeout
- one scoped commit

For high-impact audit-only programs, also require:
- one explicit coverage statement
- one explicit “checked vs not checked” statement
- one explicit defer-to-meta-analysis statement for non-critical fixes

## Stop Conditions

- a frozen default or policy change is required
- the slice would require unbounded allocation or workflow-coupled behavior
- parity or spec evidence exposes a material semantic conflict that is not already accepted
- the code passes only by weakening typed errors or trust-boundary checks

## Routing Rule

- packets should add only slice-specific deltas on top of this gate
- `handoff.md` should point to the current active packet or next work, not restate this loop
- `docs/plans/implemented-nip-review-guide.md` stays specialized; it does not replace this repo-wide
  gate

---
title: noztr SDK Process Adaptation Brief
doc_type: reference
status: active
owner: noztr
phase: phase-h
read_when:
  - adapting_noztr_process_lessons_to_nzdk
  - tightening_nzdk_review_and_audit_gates
depends_on:
  - docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md
  - docs/guides/PROCESS_CONTROL.md
  - docs/research/exhaustive-audit-meta-analysis-report.md
  - docs/research/libnostr-z-comparison-report.md
  - docs/research/llm-structured-usability-audit-report.md
  - docs/research/rc-stress-throughput-supplement-report.md
  - docs/research/tigerbeetle-zig-quality-report.md
canonical: true
---

# noztr SDK Process Adaptation Brief

Focused downstream brief for `nzdk` to reuse the useful parts of the recent `noztr` process and
audit work without copying `noztr` mechanically.

This is not a demand that `nzdk` become a protocol-kernel repo. It is a guide to the specific
process refinements that paid off and the escaped bug classes they were designed to catch.

## Purpose

- help `nzdk` make fewer implementation mistakes
- help `nzdk` tighten review, docs, and audit quality before more code lands
- separate:
  - what `noztr` learned
  - what generalizes well to an SDK
  - what should stay `noztr`-specific

## Read Order

Minimum downstream read order:
1. `docs/plans/noztr-sdk-remediation-brief.md`
2. `docs/plans/noztr-sdk-process-adaptation-brief.md`
3. `docs/research/rc-api-freeze-review-report.md`
4. `docs/research/exhaustive-audit-meta-analysis-report.md`
5. `docs/research/llm-structured-usability-audit-report.md`
6. `docs/research/tigerbeetle-zig-quality-report.md`
7. `docs/research/libnostr-z-comparison-report.md`

Load `docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md` only if `nzdk` is actively editing its own
process docs or wants the full rationale behind the guidance below.

## What `noztr` Learned That `nzdk` Should Reuse

### 0. Audit types should be explicit, named, and scoped

One of the biggest improvements in `noztr` was turning “do a thorough review” into named audit
angles with explicit scope and outputs.

The audit taxonomy that paid off was:
- protocol correctness
- ecosystem parity / interoperability
- security / misuse resistance
- cryptographic correctness / secret handling
- crypto/backend-wrapper quality
- Zig engineering quality
- performance / memory posture
- API consistency / determinism
- docs/examples / discoverability
- LLM structured usability
- empirical benchmark evidence
- external crypto/backend assurance
- stress / throughput evidence

`nzdk` should not copy this list unchanged, but it should use the same pattern:
- name the angle
- state what it is and is not checking
- keep one report per angle
- keep one synthesis after the angle reports

That is what made the later rewrite/remediation decision honest.

### 1. Escaped bug classes are more useful than vague “be careful” rules

The refinements that actually helped were tied to real failures:
- public invalid input reaching internal assertions
- invalid input leaking as capacity failures
- parsers accepting delimiter-shaped nonsense
- examples teaching the wrong contract layer
- docs and audit artifacts lagging accepted implementation state

`nzdk` should add prompts/checks that target its own escaped bug classes instead of adding generic
warning prose.

### 2. Audit first, then decide fixes

The highest-value change was separating:
- evidence gathering
- meta-analysis
- remediation

`nzdk` should adopt the same structure for any high-impact cleanup or pre-release hardening pass:
- finish the audit angles first
- do one explicit synthesis
- then choose:
  - targeted fixes
  - bounded redesign
  - major rewrite

This prevents local micro-fixes from hiding broader structural issues.

### 3. Distinguish public invalid-input failures from internal invariants

For `noztr`, this was the most common recurring defect class.

`nzdk` should add one explicit review question on touched public surfaces:
- can invalid caller input still reach a lower-level helper invariant before typed validation?

And one explicit test class:
- representative overlong or malformed caller input on every touched public parse/build/helper
  family

### 4. Examples are part of the contract, not secondary docs

One of the real `noztr` failures was an example that looked plausible but taught the wrong layer.

`nzdk` should treat examples as contract-bearing:
- one direct example for the intended path
- one hostile or misuse example for boundary-heavy surfaces
- explicit distinction between:
  - full object payloads
  - envelopes/messages
  - checked wrappers
  - local workflow helpers

### 5. LLM-facing docs need symbol routing, not just file routing

The `noztr` LLM supplement found that file-level docs were not enough.

`nzdk` should prefer:
- task-to-symbol maps
- “start here” routes for common jobs
- explicit hostile/example pairings for misuse-prone surfaces

This is especially important for an SDK, because the SDK owns more workflow glue and convenience
layers than `noztr`.

### 6. Closeout must restore a truthful steady state

`noztr` repeatedly saw drift when a lane was “done” in code but not in docs, examples, or audit
artifacts.

`nzdk` should require closeout to update:
- current state/handoff
- active packet or work queue
- canonical example/discovery surface
- any structured downstream or operator brief that other agents depend on

## Reference Lenses `nzdk` Should Understand

### TigerBeetle-style Zig-quality lens

The TigerBeetle comparison was not about protocol authority. It was a language-quality lens.

What it helped evaluate:
- function shape and control-flow density
- assertion density and invariant clarity
- explicit state instead of hidden mutable process-global behavior
- bounded memory and caller-owned data paths
- whether the code “looks like strong Zig” rather than just “works”

`nzdk` should reuse this lens when reviewing:
- large coordinator functions
- helper layering
- implicit state
- lifetime/ownership clarity
- safety-oriented explicitness

The important adaptation:
- use TigerBeetle as a Zig engineering bar
- do not use it as an SDK product-design authority

### `libnostr-z`-style comparison lens

The `libnostr-z` comparison was not used as architecture authority.
It was useful for:
- API-shape signal
- feature/file organization
- seeing how another Zig Nostr library exposes work to callers

What `noztr` explicitly did not copy:
- heap-first runtime posture
- crypto/runtime coupling
- broader runtime/service scope inside the core library

`nzdk` should apply that same discipline:
- compare against existing libraries for signal
- do not adopt their scope, dependency, or ownership choices by default
- ask which differences are real improvements versus just different repo goals

## What `nzdk` Should Adapt, Not Copy Blindly

### 1. Keep the audit structure, but change the angles to fit an SDK

`noztr` audited a protocol kernel. `nzdk` should audit an SDK.

Recommended SDK audit angles:
- public API consistency and naming
- misuse resistance on convenience helpers
- workflow ownership and boundary sharpness
- docs/examples/LLM task routing
- performance on real SDK flows
- dependency and backend-wrapper quality
- release packaging/onboarding quality
- Zig engineering quality

Suggested SDK-specific reference-lens mapping:
- Zig engineering quality:
  - use the TigerBeetle-style lens
- ecosystem/API-shape comparison:
  - use existing SDK/library comparisons the way `noztr` used `libnostr-z`
- docs/examples/LLM routing:
  - reuse the `noztr` LLM supplement pattern directly

`nzdk` should not mirror `noztr`'s angles exactly when the pressure is different.

### 2. Keep strictness where it helps, but do not force kernel-style fussiness into SDK UX

`noztr` benefits from narrow deterministic contracts.

`nzdk` should adapt that lesson as:
- clear contracts
- clear error mapping
- clear workflow boundaries

Not as:
- gratuitous rejection
- needless ceremony for common usage

### 3. Keep the evidence-first posture, but allow SDK-oriented ergonomic questions

For `nzdk`, the important question is often:
- is the API hard to misuse while still pleasant to adopt?

So `nzdk` should explicitly audit:
- what the obvious happy path is
- whether there is one safe default path
- whether convenience helpers still preserve correct ownership and failure semantics

## Recommended `nzdk` Execution Model

For high-impact implementation or cleanup work:
1. freeze scope and non-goals
2. freeze the caller-facing contract and misuse cases
3. implement
4. Review A:
   - invalid-input / misuse path review
   - assertion-leak / helper-invariant review
5. fix Review A
6. Review B:
   - docs/examples/discovery correctness
   - ownership/workflow boundary check
7. fix Review B
8. run required quality gates
9. update examples/docs/handoff/state
10. close only after steady-state routing is restored

For high-impact audit programs:
1. define angles explicitly
2. keep one coverage ledger
3. finish reports first
4. do one meta-analysis
5. only then choose remediation

## Suggested `nzdk` Review Prompts

These are the prompts most worth adapting.

Implementation review prompts:
- can invalid caller input still reach an internal helper invariant?
- can any invalid input still leak as the wrong public error class?
- does any convenience helper hide a workflow boundary that should remain explicit?
- does any example teach the wrong contract layer?
- is there one obvious safe path for the common job?

Docs/examples review prompts:
- can a fresh agent find the right symbol without reading repo history?
- is there one direct example and one misuse/hostile example for the boundary-heavy surface?
- are file routes and symbol routes both explicit?

Audit prompts:
- what was explicitly checked?
- what was explicitly not checked?
- what remains accepted exception versus actual debt?
- would fixing findings one by one hide a broader redesign signal?

## Concrete `nzdk` Starter Checklist

- add one stable process or implementation brief for the active SDK work
- add or improve one task-to-symbol map for the highest-traffic SDK jobs
- require one hostile example for boundary-heavy workflow helpers
- add one explicit public-invalid-input review prompt to Review A
- separate future audit work into:
  - angle reports
  - one synthesis
  - later remediation

## What `nzdk` Does Not Need To Copy

- `noztr`'s exact NIP/module-specific checklists
- protocol-kernel-specific strictness rules that would make SDK UX worse
- audit angles that only exist because `noztr` owns low-level crypto/protocol boundaries

## Success Condition

This brief succeeds if `nzdk`:
- adopts the evidence-first audit/remediation split
- adds checks for its own likely misuse and contract-drift failures
- improves symbol-level routing and hostile examples
- tightens review and docs quality without blindly inheriting kernel-specific rigidity

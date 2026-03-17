---
title: Process Refinement Playbook
doc_type: reference
status: active
owner: noztr
read_when:
  - refining_process
  - aligning_other_repos_to_noztr_lessons
  - tightening_review_gates_after_real_failures
depends_on:
  - docs/guides/PROCESS_CONTROL.md
  - docs/plans/decision-log.md
canonical: true
---

# Process Refinement Playbook

Shareable lessons from tightening the `noztr` implementation and review loop.

Canonical local rules live in `docs/guides/PROCESS_CONTROL.md`. This document is for rationale,
transfer, and “why this helped” context that other agents or sibling repos can reuse without
copying `noztr` wholesale.

## Core Principle

Do not refine the process with vague “be more careful” language.

Instead:
- identify the escaped bug class
- add one small prompt or rule that would likely have caught it
- update the canonical control surface coherently
- reclose recent work if the gate changed materially

## Additional Principle

Do not treat a process change as additive by default.

When the process changes materially:
- identify the canonical docs it changes
- review them together as one control surface
- remove or rewrite superseded wording
- add only the minimum new wording still required
- verify startup docs, state docs, templates, and audits now agree

Otherwise the repo accumulates two quiet forms of drift:
- contradictory control guidance
- append-only history inside active docs

## What `noztr` Learned

### 1. Negative-space mistakes matter more than happy-path omissions

The recurring failures were usually not forgotten valid cases.
They were:
- parsers accepting nonsense that fit delimiters
- scans escaping the intended region
- builders returning the wrong public error class
- debug assertions still reachable from invalid caller input

What helped:
- freeze reject corpora early
- make public error contracts explicit
- review where scans are allowed to look

### 2. Weak evidence demands more pre-code freezing

When strong reference implementations are missing, intuition gets noisy.

What helped:
- freeze the exact kernel slice first
- freeze the reject corpus before coding
- make Review A validate a contract instead of discover one

### 3. Invalid-vs-capacity is a real trust-boundary seam

Several bugs were really contract bugs:
- invalid input leaking as `BufferTooSmall`
- oversized invalid input reaching assertions instead of typed failures

What helped:
- write an invalid-vs-capacity matrix before coding
- test invalid input and too-small output separately
- ask whether debug and release reject the same public invalid-input shapes

### 4. Canonicalization can hide over-strictness

Canonical builders are useful, but they can quietly over-reject equivalent valid input.

What helped:
- separate accepted valid input from canonical emitted output
- test harmless representation variants
- ask whether the kernel is forcing unnecessary caller pre-normalization

### 5. Region-bounded scans deserve explicit review

A parser or extractor that scans “the whole string” is often too broad.

What helped:
- freeze the intended scan region in the contract
- add one explicit scan-escape review question
- add one hostile test where a lookalike token appears outside the intended region

### 6. Examples are part of the contract

Hostile examples taught downstream callers what the kernel rejects without requiring them to
reverse-engineer module tests.

What helped:
- one direct example
- one hostile example
- README or discovery-surface updates in the same closeout pass

Generalization:
- this is not specific to one NIP
- any SDK-facing split surface should assume that callers need at least one hostile example to
  learn the public failure contract correctly

### 6a. Example layers can be semantically wrong while still looking plausible

One recent failure was not in kernel code. It was in the teaching surface: an example used a
canonical id-preimage serializer as if it emitted full event-object JSON.

What helped:
- name the contract layer in the example freeze
- distinguish full object JSON from canonical preimage
- distinguish message envelopes from object-level parsing
- treat checked wrappers as their own layer, not as generic parse/serialize helpers

Why this matters:
- example bugs can survive first-pass review because they look coherent
- they often fail only when the full gate runs
- they teach the wrong mental model even if the library code itself is correct

### 7. Ordered micro-loops reduce synchronization errors

Trying to update code, tests, examples, audits, and docs all at once increases context switching
and closeout drift.

What helped:
- use one canonical staged execution order in the implementation gate
- keep other docs pointed at that order instead of restating it in full
- let packets record only slice-specific stage obligations

Why this helps:
- code answers whether the intended shape is implementable
- tests answer whether it is correct and adversarially covered
- examples answer whether it is teachable and usable
- audit reruns answer whether it closed the intended posture gaps
- docs closeout makes the repo truthful again

Important caveat:
- this should not become a waterfall that lets examples, audits, or docs slip into “later cleanup”
- the ordered micro-loop works only if later stages remain mandatory for done

### 7a. Public-path assertion leaks are a reusable bug class

One recurring failure mode was not “wrong protocol logic.”
It was:
- public API accepts caller input
- helper deeper in the chain was written with bounded internal assumptions
- invalid caller input reached the helper before typed validation
- debug assertions or helper-shaped error mismatches leaked into the public contract

What helped:
- scan touched public parser/builder/validator chains for assertion leaks
- freeze one representative overlong-input case per public surface family
- ask whether public invalid input still reaches an internal helper invariant

Generalization:
- this applies broadly to protocol libraries, not just this audit pass
- builders, parsers, URI/query handling, JSON validation, and metadata helpers are all susceptible

What not to do:
- do not codify the exact module or NIP that failed
- codify the failure class and keep the incident-specific details in tests and audit records

### 8. Closeout must restore steady-state routing

A process change is not complete if the startup path still acts like the temporary packet is active.

What helped:
- mark finished packets as reference when the lane closes
- shrink handoff back to steady-state next-work form
- update routing docs during closeout, not later

Related refinement:
- audit and robustness passes need the same discipline on canonical report artifacts
- if the accepted implementation state changed, the canonical audit/report surface must change in
  the same slice or the repo starts lying about what has actually been hardened

### 9. Audit and remediation should separate when rewrite pressure is the real question

One failure mode in maturing repos is patching local findings so quickly that the broader pattern
never becomes visible.

What helped:
- treat high-impact pre-freeze audits as evidence-first lanes
- keep one live coverage ledger or working draft
- finish the angle reports before opening broad fix execution
- require one meta-analysis step that decides:
  - targeted fixes
  - bounded redesign
  - major rewrite

Why this matters:
- some local bugs are symptoms of a systemic ownership or API-shape problem
- fixing them too early can hide the rewrite signal
- rewriting too early can overreact to issues that were actually isolated

Important caveat:
- this is not “never fix during an audit”
- broken builds, safety-critical defects, and findings that invalidate the audit evidence still
  justify immediate correction

Generalization:
- this pattern applies when the repo is deciding whether it is ready to freeze or whether its
  public surface needs redesign
- it is less important for small narrow slices where the failure mode is already well understood

## Useful Review Prompts

These are not canonical rules here; they are the prompts that proved useful enough to move into the
local control doc.

Review A prompts that paid off:
- can any user-controlled invalid input still panic or hit a debug assertion?
- can any invalid input still return a capacity error?
- can any capacity failure still return an invalid-input error?
- does any scan escape the intended syntactic region?
- does the parser accept nonsense just because delimiters balance?

Review B prompts that paid off:
- did canonicalization become over-strict input validation?
- did the surface stay inside deterministic protocol-kernel ownership?
- did workflow or policy behavior leak in from the SDK layer?
- do the examples show both intended use and intended rejection?
- do the examples teach the correct contract layer instead of mixing full object JSON, canonical
  preimage, message envelope, or checked wrapper semantics?

## How To Define Repo-Specific Audit Postures

Pick postures from real failure modes, not elegance.

Ask:
1. What kind of mistake hurts this repo most?
2. What kind of mistake is easy to miss in normal code review?
3. What kind of pressure should shape API or workflow decisions beyond raw correctness?

Then define audits around those pressures.

Examples:
- a security-sensitive repo may want:
  - security posture
  - operational resilience posture
  - onboarding posture
- a protocol library may want:
  - trust-boundary posture
  - language-native ergonomics posture
  - interoperability posture
- a product repo may want:
  - user-flow posture
  - observability posture
  - maintenance posture

Good audits are not generic quality checklists.
They are posture-specific lenses.

## Anti-Patterns

Avoid:
- one giant doc that tries to be gate, handoff, audit, history, and plan at once
- repeating the same doctrine in every packet
- keeping completed loops in startup reading
- audits with no stable finding IDs
- shrinking packets so much that important slice-specific assumptions disappear
- creating multiple audit docs that do not clearly differ in question or posture
- treating every process change as additive instead of revising the existing control surface

## How To Share This With Other Repos

When another repo wants to learn from `noztr`:
1. copy the pattern, not the exact doc topology
2. keep one canonical control doc and one playbook or reference doc
3. reuse the prompts that match the repo’s real failure modes
4. rename audit postures and finding IDs to fit the target repo
5. avoid copying `noztr` packet or phase names unless the workflow is actually shared

## Minimal Adoption Path For Another Repo

If another repo wants the benefits without copying everything:

1. Define doc roles and add simple frontmatter.
2. Create one docs index.
3. Pick 2-3 audit postures that fit the repo.
4. Give audit findings stable IDs.
5. Make packets target those IDs instead of repeating full doctrine.
6. Archive completed loops and superseded packets.
7. Keep handoff short and current.

That is enough to improve clarity a lot without importing the full `noztr` process.

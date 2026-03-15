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

Reusable lessons from tightening the `noztr` implementation/review loop.

This document is meant to be shareable with other agents and sibling repos. It is not a second
copy of `AGENTS.md` or `PROCESS_CONTROL.md`. It captures the specific refinements that proved
useful after real implementation failures, especially in weak-evidence or split-surface NIPs.

## Core Principle

Do not refine the process with vague “be more careful” language.

Instead:
- identify the exact bug class that escaped
- add one small rule or review question that targets that class directly
- keep the new rule near the canonical process owner
- reclose recently landed slices if the gate changed materially

## What `noztr` Learned

### 1. Negative-space mistakes are more common than happy-path mistakes

The recent misses were usually not “we forgot the obvious valid case”.
They were:
- a parser accepting nonsense that fit the delimiters
- a scan escaping the intended region
- a builder returning the wrong public error class
- a debug assertion still reachable from invalid caller input

Process implication:
- freeze the reject corpus early
- make public error contracts explicit
- review where scans are allowed to look

### 2. Weak evidence means more pre-code freezing, not more post-code debate

When direct reference libraries are weak or absent, implementation intuition is too noisy.

What worked better:
- freeze the exact `noztr` slice first
- freeze the reject corpus before coding
- assume Review A should validate a contract, not discover the contract

### 3. Invalid-vs-capacity is a first-class boundary, not cleanup detail

Several failures were really contract bugs:
- invalid input leaking as `BufferTooSmall`
- oversized invalid input reaching assertions instead of typed failures

What worked better:
- write an invalid-vs-capacity matrix before coding
- test both invalid input and too-small output explicitly
- ask whether debug and release reject the same public invalid-input shapes

### 4. Canonicalization can hide over-strictness

Canonical builders are useful, but they can quietly over-reject equivalent valid input.

What worked better:
- separate “accepted valid input” from “canonical emitted output”
- test inputs that differ only by harmless representation details
- ask whether the kernel is rejecting a valid equivalent just to force the caller to pre-normalize

### 5. Region-bounded scans deserve explicit review

A parser or extractor that scans “the whole string” is often too broad.

What worked better:
- freeze the intended scan region in the contract
- add one explicit review question for scan escape
- add one hostile test where a lookalike token appears outside the intended region

### 6. Examples are part of the contract

Hostile examples were useful because they taught downstream callers what the kernel rejects without
requiring them to reverse-engineer module tests.

What worked better:
- one direct example
- one hostile example
- README/discovery surface updated in the same closeout pass

### 7. Closeout must restore steady-state routing

A process change is not complete if the startup path still acts like the temporary packet is active.

What worked better:
- mark finished packets as reference when the lane closes
- shrink handoff back to steady-state next-work form
- update routing docs during closeout, not later

## Micro-Freeze Template

Use this before coding a new trust-boundary surface.

### Scope Freeze

- supported kinds
- required tags / fields
- optional tags / fields
- multiplicity / ordering rules
- normalization / canonicalization rules
- ignored / unsupported shapes
- explicit non-goals
- SDK-side remainder, if split

### Boundary Freeze

- intended scan regions
- accepted equivalent valid forms
- canonical emitted forms
- invalid-vs-capacity matrix for each public builder or validator

### Reject Corpus Freeze

Minimum set:
- arbitrary-but-delimited nonsense
- malformed section or tag separators
- overlong fields
- contradictory optional metadata where applicable
- debug-vs-release equivalent invalid-input checks
- lookalike tokens outside the intended scan region

## Review A Prompts

Review A should challenge correctness, trust boundary, and spec fit.

Ask these exact questions:
- can any user-controlled invalid input still panic or hit a debug assertion?
- can any invalid input still return a capacity error?
- can any capacity failure still return an invalid-input error?
- does any scan escape the intended syntactic region?
- does the parser accept nonsense just because delimiters balance?
- does the builder/parser symmetry hold on canonical shapes?
- do near-canonical malformed shapes fail predictably?

## Review B Prompts

Review B should challenge ownership, KISS, and usability.

Ask these exact questions:
- did this surface stay inside deterministic protocol-kernel ownership?
- did we add workflow or policy behavior that belongs in the SDK?
- did canonicalization accidentally become over-strict input validation?
- is the public API smaller and clearer than the same behavior embedded in downstream code?
- do the examples show both intended use and intended rejection?

## When To Tighten The Gate

Add a new process rule when:
- the same bug class appears more than once
- the bug class is hard to spot from generic review language
- a small explicit prompt would likely have caught it

Do not add a new process rule when:
- the issue is a one-off typo or wiring mistake
- the new rule would duplicate an existing canonical rule
- the rule is so broad that it becomes ceremonial

## How To Share This With Other Repos

When another repo wants to learn from `noztr`:
1. copy the pattern, not the exact doc topology
2. keep one canonical control doc and one playbook/reference doc
3. reuse the review prompts that match the repo’s real failure modes
4. rename audit postures and finding IDs to fit the target repo
5. avoid copying `noztr`-specific packet or phase names unless the workflow is actually shared

## Minimum Transferable Lessons

If another agent only copies a few things from `noztr`, it should copy these:
- invalid-vs-capacity matrices for public builders/validators
- explicit assertion-leak checks
- explicit scan-region checks
- reject corpora for weak-evidence specs
- hostile consumer-facing examples
- steady-state docs restoration as part of done

# Phase H Wave 1 Execution Loop

Date: 2026-03-10

Purpose: define the autonomous implementation loop for Wave 1 so each NIP proceeds through the same
bounded plan, coding, review, parity, and closure sequence with minimal operator supervision.

## Scope

- Applies only after `no-8zr.1` / Phase H0 NIP-06 boundary freeze is complete and closed.
- Applies to Wave 1 NIPs in this order:
  - `25`
  - `10`
  - `18`
  - `22`
  - `27`
  - `51`
- Applies only after Phase H kickoff and with the current Layer 1 posture and bounded defaults
  unchanged.
- Rust lane remains the active parity reference lane.

## Autonomy Rule

- Do not start any Wave 1 implementation issue until the required H0 checkpoint (`no-8zr.1`) is
  complete.
- Execute the loop autonomously from claim to closure for the current NIP without pausing for routine
  operator confirmation.
- After closing one NIP, claim the next ready Wave 1 issue and continue immediately.
- Do not stop at "analysis complete", "plan ready", or "ready to implement". Carry work through code,
  tests, review, docs, and tracker closure.
- Use beads to capture discovered follow-up work instead of pausing to ask what to do next.
- Only pause for:
  - a required frozen-default change,
  - a trust-boundary ambiguity that would materially change accepted behavior,
  - a tool/platform permission boundary that cannot be satisfied by existing approvals,
  - or an irreducible external dependency failure.

## Loop Contract

Each Wave 1 NIP must complete the full loop below before the next NIP begins.

1. Tracker step
   - claim the active beads issue for the NIP.
   - confirm dependencies and acceptance criteria are present.
   - if new work is discovered, create a linked beads issue with `discovered-from`.
   - if the ready queue includes non-Wave 1 work, do not let it preempt the active serial Wave 1
     lane unless the active Wave 1 item is blocked and the alternate work is explicitly allowed by
     current phase sequencing.

2. Contract step
   - freeze the narrow module contract before coding.
   - identify exact file targets, typed error surface, fixed-capacity limits, and required vectors.
   - stop immediately if the contract would force a frozen-default change.
   - record a minimum contract-freeze payload in the issue evidence or canonical doc update:
     - file targets
     - public API names
     - typed error set
     - fixed-capacity limits
     - explicit in-scope
     - explicit out-of-scope
     - parity source(s)
     - required valid vectors
     - required invalid vectors

3. Implementation step
   - implement one module/file slice at a time.
   - keep public APIs caller-buffer-first where relevant, bounded, and aligned with `D-036`
     (deterministic, explicit, and compatibility-preserving rather than strict for its own sake).
   - add assertions for positive and negative space in every function path.
   - add or update one exported-surface smoke test in `src/root.zig` for every new public module.

4. Correctness and edge-case step
   - add happy-path and invalid-path tests together with the code.
   - force every public error variant directly.
   - include boundary vectors for malformed shape, max/min bounds, duplicate/ambiguous input, and
     deterministic repeat runs.

5. Parity step
   - compare behavior against the active rust reference lane where coverage exists.
   - treat rust parity as a compatibility-confidence and learning tool, not as an instruction to
     clone every reference edge behavior.
   - classify parity evidence for the implemented surface using one of:
     - `HARNESS_COVERED`
     - `SOURCE_REVIEW_ONLY`
     - `NO_REFERENCE_COVERAGE`
   - record any intentional divergence rather than silently adjusting Layer 1 behavior.
   - if parity evidence shows a required semantic mismatch, stop and record the decision point before
      changing defaults.
   - consult the implemented-NIP review criteria in `docs/plans/build-plan.md` when deciding
     whether a narrower behavior is justified or is creating unnecessary incompatibility.
   - preserve Zig-native guarantees and API clarity when they improve the implementation without
     weakening protocol correctness, bounds, or compatibility posture.

6. Review Cycle A
   - review for correctness first: trust boundaries, malformed input handling, typed failures,
     deterministic outputs, and runtime bounds.
   - review for edge cases second: malformed tags, duplicate semantics, UTF-8/hex/path boundaries,
     cap overflow, and caller-buffer behavior.
   - review for parity third: rust lane comparison results, missing parity cases, and any strict
     intentional divergence.
   - review for overengineering fourth: remove speculative helpers, extra abstraction layers, generic
     parsers, API breadth not required by the accepted contract, or reinvention of functionality
     already available in Zig stdlib, approved backend boundaries, or existing in-repo helpers.
   - review for style fifth: Tiger line/function limits, assertions, explicit widths, and no compound
     control-flow shortcuts.
   - review for usability sixth:
     - LLM POV: can the correct API and safe call sequence be discovered from names/docs without
       trial and error.
     - human POV: are the public names, typed errors, and trust-boundary flows understandable to a
       maintainer reading the module cold.
   - review for Zig guidance seventh:
     - conforms to `docs/guides/zig-patterns.md`
     - does not introduce forbidden forms from `docs/guides/zig-anti-patterns.md`
   - implement fixes found in Review Cycle A before advancing.

7. Review Cycle B
   - re-review the fixed implementation for regression after Cycle A changes.
   - repeat correctness, edge-case, parity, overengineering, style, usability, and Zig
     pattern/anti-pattern checks on the final candidate.
   - confirm the final candidate is simpler or equal in complexity relative to the pre-review state.
   - no NIP closes until Review Cycle B is clean.

8. Gate step
   - run focused module tests or a focused check for the implemented surface first.
   - run `zig build test --summary all`.
   - run `zig build`.
   - run any focused rust parity comparison commands for the implemented surface.
   - final closure may use only fresh gate evidence from the final post-Review-B candidate; do not
     close on stale pre-fix gate results.
   - do not advance on red gates.

9. Documentation and tracker closure step
   - update docs for accepted behavior, learnings, and reasoning; do not leave important findings in
     memory-only state.
   - route findings into existing canonical artifacts instead of creating new running ledgers:
     - `docs/plans/decision-log.md` for accepted default or policy changes
     - `docs/plans/build-plan.md` for accepted execution-baseline or phase-state changes
     - `docs/plans/phase-h-additional-nips-plan.md` for accepted NIP scope, sequencing, or
       acceptance-criteria changes
     - `docs/plans/phase-h-kickoff.md` and `handoff.md` for current status and next-step changes
     - `docs/release/intentional-divergences.md` for accepted strict divergences from parity targets
     - `docs/plans/llm-usability-pass.md` if a Wave 1 result materially affects LLM-first or general
       API usability guidance
     - `README.md` only when user-visible capability surface changed
   - if no canonical document changes are needed, record an explicit `docs reviewed, no update
     needed` note in the beads issue evidence rather than leaving doc review implicit.
   - refresh `./agent-brief` whenever canonical project-state artifacts change so session startup
     context remains current.
   - capture per-NIP implementation evidence in the beads issue itself when it does not rise to a
     canonical-doc update.
   - use a minimum beads closure-evidence payload:
     - contract summary
     - tests added
     - Review Cycle A result
     - Review Cycle B result
     - parity result plus taxonomy
     - intentional divergences
     - final gate outputs
     - docs updated or `docs reviewed, no update needed`
     - discovered follow-up issues
   - add a short per-NIP handoff summary when the closure materially changes current execution state:
     - implemented
     - parity taxonomy
     - intentional divergences
     - next item
     - open follow-ups
   - run a required ambiguity checkpoint before issue closure:
     - classify remaining ambiguities as `resolved`, `accepted-risk`, or `decision-needed`
     - do not close the NIP if any high-impact ambiguity remains `decision-needed`
   - close the beads issue with the implemented acceptance evidence.
   - confirm the next serial dependency is actually unblocked in beads before claiming the next NIP.
   - claim the next ready Wave 1 issue and continue.

10. Tracker-outage recovery step
   - if `bd` or Dolt is unavailable during claim/update/close work:
     - restore the local tracker service first
     - rerun the blocked tracker command after health is restored
     - do not silently skip tracker updates or closure
     - if recovery fails, record the pending tracker action and current evidence in `handoff.md`
       before pausing

11. Scope-drift control step
   - if implementation starts requiring another NIP's semantics, compatibility layer behavior, or
     broader API breadth than the frozen contract:
     - stop widening the current module
     - create a linked `discovered-from` issue for the new scope
     - reduce the active implementation back to the accepted contract before continuing
   - if a fix would widen permissiveness at a trust boundary, require explicit documentation of why
     the wider acceptance remains strict-safe; otherwise stop for decision rather than silently
     broadening compatibility.

## Required Review Checklist

- Correctness
  - public boundaries return typed errors only
  - malformed and ambiguous inputs are rejected explicitly
  - deterministic output and deterministic error behavior are preserved
  - bounded memory/work invariants are explicit
- Edge cases
  - invalid corpus covers malformed shape plus boundary sizes
  - duplicate or conflicting tag/state semantics are tested
  - invalid UTF-8, hex, or token forms are covered where relevant
- Parity
  - rust comparison done where equivalent behavior exists
  - parity taxonomy is recorded as `HARNESS_COVERED`, `SOURCE_REVIEW_ONLY`, or
    `NO_REFERENCE_COVERAGE`
  - intentional divergences are documented, not implied
  - reference-library differences are judged against NIPs, ecosystem compatibility, and Zig-native
    bounded-contract quality rather than copied automatically
- Overengineering
  - no abstraction introduced without direct domain need
  - no broad generic helper introduced where one explicit helper is clearer
  - no future-phase API breadth slipped into the current NIP
  - no reinvention of stdlib, approved backend-boundary, or existing in-repo functionality without
    a documented bounded-contract reason
- Style
  - no function over 70 lines
  - no line over 100 columns
  - assertions cover both positive and negative space
  - explicit-width integers only
- Usability
  - LLM POV: safe entry points and typed failure paths are discoverable from names and docs
  - human POV: public API, invariants, and expected call sequence are understandable without hidden context
- Zig guidance
  - approved safe patterns from `docs/guides/zig-patterns.md` are used where applicable
  - forbidden forms from `docs/guides/zig-anti-patterns.md` are explicitly checked and absent
- Closure discipline
  - ambiguity checkpoint is complete and no high-impact item remains `decision-needed`
  - beads evidence includes the minimum closure payload
  - `./agent-brief` is refreshed when canonical artifacts changed
  - final closure gates are fresh from the post-Review-B candidate
  - next serial dependency is confirmed unblocked before the next claim
  - scope drift and hidden compatibility widening are either rejected or explicitly tracked

## Stop Conditions

- Stop if a module needs a frozen-default change.
- Stop if parity with rust-nostr shows a semantic conflict that is not already an intentional
  divergence.
- Stop if correct implementation would require an unbounded allocation path.
- Stop if the code passes tests only by weakening typed-error precision or trust-boundary checks.

## Decisions

- `H-W1-001`: execute Wave 1 serially, one NIP at a time, with full closure gates before advancing.
- `H-W1-002`: make correctness, edge-case handling, parity, overengineering review, and style review
  explicit mandatory loop stages rather than ad hoc reviewer memory.
- `H-W1-003`: require two review cycles for every NIP before closure.
- `H-W1-004`: require documentation capture of implementation learnings and reasoning for every NIP
  in existing canonical artifacts or the beads issue evidence.
- `H-W1-005`: require LLM POV, human POV, and Zig pattern/anti-pattern review for every NIP.
- `H-W1-006`: require the Phase H0 NIP-06 boundary freeze checkpoint to close before any Wave 1
  implementation starts.
- `H-W1-007`: require a per-NIP ambiguity checkpoint and forbid closure with high-impact
  `decision-needed` ambiguity.
- `H-W1-008`: require a minimum contract-freeze record and a minimum beads closure-evidence payload.
- `H-W1-009`: require explicit parity taxonomy and tracker-outage recovery behavior.
- `H-W1-010`: require `./agent-brief` refresh whenever canonical state artifacts change.
- `H-W1-011`: require one exported-surface smoke test per new public module.
- `H-W1-012`: require explicit `docs reviewed, no update needed` evidence when canonical docs do not
  change.
- `H-W1-013`: require a focused module gate before aggregate gates.
- `H-W1-014`: require fresh final-candidate gate evidence for closure and verification that the next
  serial dependency actually unblocked before advancing.
- `H-W1-015`: require explicit scope-drift control and forbid silent compatibility widening in the
  strict path.

## Tradeoffs

## Tradeoff T-H-W1-001: Serial closure loop versus parallel Wave 1 coding

- Context: Wave 1 NIPs can be implemented in parallel for throughput or serially for stricter gate
  discipline.
- Options:
  - O1: execute serially with full closure on each NIP.
  - O2: parallelize multiple Wave 1 NIPs.
- Decision: O1.
- Benefits: clearer defect isolation, lower policy drift, and easier parity/review bookkeeping.
- Costs: lower short-term throughput.
- Risks: perceived slower visible progress.
- Mitigations: keep the loop tight, keep scopes narrow, and move immediately to the next NIP on
  closure.
- Reversal Trigger: evidence that serial execution causes delay without reducing rework.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: all Wave 1 NIPs.

## Open Questions

- `OQ-H-W1-001`: which Wave 1 NIP should become the first rust-parity-backed implementation candidate
  if rust reference coverage is uneven across the set.

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: trust-boundary correctness and typed failures are first-class loop gates.
- `P02`: scope remains protocol-kernel work only.
- `P03`: parity review is explicit and tied to the active rust lane.
- `P04`: policy changes require explicit stop and decision handling.
- `P05`: determinism and direct forcing tests are mandatory closure conditions.
- `P06`: bounded memory/work and anti-overengineering review are explicit loop steps.

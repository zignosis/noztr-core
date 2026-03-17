# AGENTS.md — noztr

Pure Zig Nostr protocol library. Zig stdlib only by default, with approved pinned crypto backend
exceptions recorded in the decision log.

## Session Startup

- Run `./agent-brief` first.
- Read `AGENTS.md` and `handoff.md` every session.
- Then read only the current execution files called out by `./agent-brief`.
- Use `docs/README.md` to route any further doc reads instead of scanning `docs/` blindly.
- Treat `docs/plans/decision-index.md` as the startup route into accepted policy; load
  `docs/plans/decision-log.md` only when the current task changes policy, cites a specific
  decision ID, or needs the exact canonical decision payload.
- Read `docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md` when the task is refining repo process,
  tightening review gates after real failures, or sharing `noztr` process lessons with another
  repo or agent.
- Read `docs/guides/IMPLEMENTATION_QUALITY_GATE.md` when the task starts or repairs an
  implementation, audit, or robustness slice.
- Read `docs/guides/TIGER_STYLE.md`, `docs/guides/NOZTR_STYLE.md`,
  `docs/guides/zig-patterns.md`, and `docs/guides/zig-anti-patterns.md` only when the task touches
  Zig implementation, public API shape, or code review.
- Read `docs/plans/packet-template.md` when creating or repairing packet docs.
- Read `docs/plans/noztr-sdk-ownership-matrix.md` when the task touches kernel-vs-SDK scope,
  deterministic protocol glue, or higher-level workflow ownership.
- Read `docs/plans/audit-angle-standards.md` and `docs/plans/audit-angle-report-template.md` when
  the task starts a dedicated exhaustive-audit angle.
- Read planning prompt artifacts only when the task is phase-planning work.
- Work in phase order. Do not skip phase gates.

## Artifact Authority

- Pre-v1 broad studies are reference-only inputs and do not set policy defaults.
- v1 artifacts are canonical working outputs for downstream phases.
- `docs/archive/` is reference-only historical material; do not load it on startup unless the task
  explicitly needs historical evidence or traceability.
- `docs/plans/build-plan.md` is a working baseline until Phase E finalization.
- Precedence on conflict: `docs/plans/nostr-principles.md` and
  `docs/plans/decision-log.md` > v1 artifacts > pre-v1 broad studies.

## Build & Test

```bash
zig build test --summary all   # MUST pass with zero leaks
zig build                      # build static library
```

Run tests after every code change.

## Tooling Rule

- Use `bun` for local JavaScript/TypeScript tooling in this repo.
- Do not use `npm` for local interop harness setup or execution.

## Phase-Gated Workflow

- Use one prompt per phase from `docs/plans/prompts/`.
- Complete the current phase exit criteria before starting the next phase.
- Keep outputs narrow and phase-specific.
- Document tradeoffs for every material decision.
- Use a required ambiguity checkpoint before phase closure.
- If a phase reveals uncertainty, write it as an open question and stop phase advancement.

## Project State Updates

- Keep project context current after meaningful progress:
  - Active phase owner updates `handoff.md` before phase closure.
  - Ensure `docs/plans/build-plan.md` reflects accepted decisions.
  - Ensure `docs/plans/decision-index.md` reflects active policy-routing needs.
  - Ensure `docs/plans/decision-log.md` records accepted default changes.
  - Ensure `./agent-brief` output reflects the current active execution path.
- Keep the active packet surface current when a phase stays open after a slice closes.
  - Completed packets move to `reference` or archive.
  - New pending work goes into the current packet for the still-active phase.
- Keep `handoff.md` state-oriented; move historical narrative to decision records, reference docs,
  archive, or git history instead of growing the startup path.
- Do not rely on memory-only context between sessions.

## Protocol Work Closure Discipline

- For every new or materially changed NIP surface, create and maintain a short spec-to-contract
  checklist before closure:
  - supported kinds
  - required tags / fields
  - optional tags / fields
  - multiplicity and ordering rules
  - normalization / canonicalization rules
  - ignored or explicitly unsupported shapes
  - explicit non-goals and SDK-side work
- No NIP closes until the checklist is mapped to code, tests, examples, or an explicit accepted
  non-goal.
- Treat builder/parser symmetry as a required test class:
  - canonical builder output must round-trip through the parser where applicable
  - parser-accepted canonical input must be buildable where applicable
  - near-canonical malformed shapes must fail predictably
- Review the public error contract explicitly:
  - public error variants must describe the real cause
  - do not return capacity errors for invalid input or invalid-input errors for capacity failures
  - freeze an explicit invalid-vs-capacity matrix before coding every new builder or validator
  - no user-controlled invalid input may rely on debug assertions for rejection in the public path
  - run one targeted public-path assertion-leak scan on touched parser/builder/validator chains
  - ask explicitly whether any public invalid input still reaches an internal helper invariant
- When reference libraries are `LIB_UNSUPPORTED` or only weak evidence exists, require one extra
  spec-first challenge pass before closure.
  - that extra pass must include a pre-code reject corpus, not only additional happy-path evidence
  - reject corpus minimum:
    - arbitrary-but-delimited nonsense
    - malformed section or tag separators
    - overlong fields
    - contradictory optional metadata where applicable
    - debug-vs-release equivalent failure checks for public invalid-input paths
- Keep canonical audit and status artifacts current as part of closure, not as later cleanup.
- Add at least one representative overlong-input test for each public builder/parser family touched
  by the slice.
- If the review process gets stricter mid-stream, run a short retroactive backfill pass on all
  recently closed or newly expanded NIPs before claiming the stronger standard is in force.
- For boundary-heavy SDK-facing surfaces, require at least one consumer-facing hostile or invalid
  example fixture in addition to module tests so callers can see the intended failure contract.
- Treat audit-report synchronization as same-slice work when an audit or robustness pass changes
  the accepted contract or closes live findings.
- For high-impact multi-angle pre-freeze audits:
  - finish the required audit angles before default remediation work begins
  - keep one live working draft or coverage ledger
  - separate evidence-gathering lanes from later remediation lanes
  - do not land fixes during the audit program
  - require one explicit meta-analysis before deciding on targeted fixes, bounded redesign, or a
    major rewrite

## Coding Standards

Read `docs/guides/TIGER_STYLE.md` and `docs/guides/NOZTR_STYLE.md` for code work. Tiger is the
hard engineering baseline; NOZTR Style is the project-specific protocol-kernel profile. The
critical rules:

- **70 lines per function** — no exceptions
- **100 columns per line** — no exceptions
- **4-space indentation**
- **Minimum 2 assertions per function** — pre/postconditions and invariants
- Pair assertions: positive AND negative space
- **Static allocation only** — no dynamic allocation after init
- **Dependency default** — Zig stdlib only unless an approved pinned crypto backend exception is
  recorded in `docs/plans/decision-log.md`
- Follow KISS — prefer the simplest solution that satisfies requirements
- Keep protocol behavior simple, bounded, and not fussy — do not add narrow helper rules, extra
  typed failures, or special-case parsing unless they materially improve trust-boundary behavior,
  correctness, or interoperability
- Reuse approved implementations before writing from scratch — approved means Zig stdlib or existing in-repo modules/utilities only
- `defer` for cleanup, `errdefer` for error paths
- All errors handled — never discarded
- No recursion — all paths bounded
- Explicitly-sized types: `u32` not `usize`
- **snake_case**, no abbreviations
- Callbacks last in parameter lists
- Variables at smallest scope, close to usage
- Simple, explicit control flow — no compound conditions

## Module Conventions

- One `.zig` file per NIP/feature in `src/`
- Tests co-located (test blocks at bottom)
- `std.testing.allocator` for all test allocations
- Doc comments (`///`) on public API
- Tests must cover happy path + error cases
- For protocol modules, tests must also cover:
  - per-field negative corpus
  - builder/parser symmetry where applicable
  - at least one adversarial or hostile-input case for boundary-heavy surfaces
  - at least one nonsense-but-delimited invalid case when the surface tokenizes free text or
    sectioned content
  - section/tag separator discipline when the grammar has adjacent structured regions

## What NOT To Do

- Do NOT add unapproved dependencies — only `@import("std")` is allowed unless a pinned crypto
  backend exception is accepted in `docs/plans/decision-log.md`
- Do NOT use `ArrayList` or unbounded dynamic allocation
- Do NOT use recursion
- Do NOT silently swallow errors with `try`/`catch`

## Guides

- `docs/guides/TIGER_STYLE.md`: hard engineering baseline
- `docs/guides/NOZTR_STYLE.md`: noztr protocol-kernel style profile
- `docs/guides/PROCESS_CONTROL.md`: process-control and docs-surface refinement rules
- `docs/guides/IMPLEMENTATION_QUALITY_GATE.md`: canonical staged implementation/audit gate
- `docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md`: shareable process lessons learned from real slices
- `docs/guides/zig-patterns.md`: approved Zig-safe patterns
- `docs/guides/zig-anti-patterns.md`: forbidden Zig footguns
- `docs/plans/packet-template.md`: packet skeleton for new or repaired active slices
- Other guide documents are load-on-demand, not required startup context

<!-- BEGIN BEADS INTEGRATION -->
## Issue Tracking with br (beads_rust)

**Note:** `br` is non-invasive and never executes git commands. After `br sync --flush-only`, you must manually run `git add .beads/ && git commit`.

**IMPORTANT**: This project uses **br (beads_rust)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why br?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: sync exports to `.beads/` for manual git versioning
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
br ready --json
```

**Create new issues:**

```bash
br create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
br create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:br-123 --json
```

**Claim and update:**

```bash
br update <id> --claim --json
br update br-42 --priority 1 --json
```

**Complete work:**

```bash
br close br-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `br ready` shows unblocked issues
2. **Claim your task atomically**: `br update <id> --claim`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `br create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `br close <id> --reason "Done"`
6. **Sync tracker state when needed**:
   ```bash
   br sync --flush-only
   git add .beads/
   git commit -m "sync beads"
   ```

### Important Rules

- ✅ Use br for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `br ready` before asking "what should I work on?"
- ✅ Treat all `br` mutations and all git-writing steps as serial-only operations
- ✅ Run this sequence in order when tracker state changes: `br update/close/create` ->
  `br sync --flush-only` -> `git add .beads/` -> `git commit`
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems
- ❌ Do NOT run `br` mutations, `br sync`, or git commits in parallel

For more details, see README.md and docs/QUICKSTART.md.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. If a git remote is configured and
in active scope, work is NOT complete until `git push` succeeds. If remote readiness is explicitly
deferred or no git remote is configured, complete the local-only workflow and record the deferred
remote state in `handoff.md`.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE WHEN REMOTE READINESS IS IN SCOPE**:
   ```bash
   git remote -v
   git pull --rebase
   br sync --flush-only
   git add .beads/
   git commit -m "sync beads"
   git push
   git status  # MUST show "up to date with origin"
   ```
   If no remote is configured or remote readiness is deferred-by-operator, skip push and record that
   deferred state in `handoff.md`.
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- If a git remote is configured and in scope, work is NOT complete until `git push` succeeds
- NEVER stop before pushing when remote readiness is in scope - that leaves work stranded locally
- NEVER say "ready to push when you are" when remote readiness is in scope - YOU must push
- If push fails and remote readiness is in scope, resolve and retry until it succeeds
- If remote readiness is deferred or unavailable, record that explicitly and do not present local-only
  completion as remotely landed

<!-- END BEADS INTEGRATION -->

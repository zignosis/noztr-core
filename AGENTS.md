# AGENTS.md — noztr

Pure Zig Nostr protocol library. Zero external dependencies — Zig stdlib only.

## Session Startup

- Run `./agent-brief` first.
- Read these in order:
  - `AGENTS.md`
  - `docs/guides/TIGER_STYLE.md`
  - `docs/guides/zig-patterns.md`
  - `docs/guides/zig-anti-patterns.md` (if present)
  - `docs/plans/nostr-principles.md` (if present)
  - `docs/plans/decision-log.md` (if present)
  - `docs/plans/build-plan.md`
  - `docs/plans/prompts/README.md`
- Work in phase order. Do not skip phase gates.

## Build & Test

```bash
zig build test --summary all   # MUST pass with zero leaks
zig build                      # build static library
```

Run tests after every code change.

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
  - Ensure `docs/plans/decision-log.md` records accepted default changes.
  - Ensure `./agent-brief` output reflects current artifact status.
- Do not rely on memory-only context between sessions.

## Coding Standards

Read `docs/guides/TIGER_STYLE.md` — every word. Non-negotiable. The critical rules:

- **70 lines per function** — no exceptions
- **100 columns per line** — no exceptions
- **4-space indentation**
- **Minimum 2 assertions per function** — pre/postconditions and invariants
- Pair assertions: positive AND negative space
- **Static allocation only** — no dynamic allocation after init
- **Zero dependencies** — Zig stdlib only
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

## What NOT To Do

- Do NOT add external dependencies — only `@import("std")` is allowed
- Do NOT use `ArrayList` or unbounded dynamic allocation
- Do NOT use recursion
- Do NOT silently swallow errors with `try`/`catch`

## Guides

Read everything in `docs/guides/`.

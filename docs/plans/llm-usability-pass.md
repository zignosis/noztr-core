# LLM Usability Pass (OQ-E-006)

Date: 2026-03-07

Status: in-progress

Purpose: evaluate hardened v1 APIs from an LLM-first integration workflow before RC API freeze.

Decision linkage: this pass remains in progress and is the decision input for first RC strictness-profile
default freezing.

## Scope Snapshot

- In scope: implemented strict-default modules in `src/` (`nip01_event`, `nip01_filter`,
  `nip01_message`, `nip42_auth`, `nip70_protected`, `nip11`, `nip09_delete`, `nip40_expire`,
  `nip13_pow`) and implemented I4 modules (`nip19_bech32`, `nip21_uri`, `nip02_contacts`,
  `nip65_relays`) plus root exports in `src/root.zig`.
- In scope: contract/doc parity on currently shipped signatures, typed errors, and strict transcript
  semantics.
- In scope: trust-boundary wrapper ergonomics (`pow_meets_difficulty_verified_id`,
  `delete_extract_targets_checked`, transcript marker/apply functions).
- In scope: transcript naming cleanup for compatibility aliasing (`transcript_apply_compat`, with
  `transcript_apply` as alias) and strict canonical path (`transcript_mark_client_req` +
  `transcript_apply_relay`).
- Out of scope: transport/runtime integration helpers, post-RC API redesign.

## Task Battery

- T1 `event lifecycle`: parse -> canonical serialize -> compute id -> verify split/full paths.
- T2 `filter matching`: parse multi-field filters and evaluate deterministic OR-of-filters behavior.
- T3 `message grammar`: parse/serialize REQ and COUNT with multiple filters; enforce strict relay
  grammar (`OK` lowercase hex id, prefixed status).
- T4 `transcript flow`: apply `transcript_mark_client_req` then relay transitions for
  `EVENT* -> EOSE -> CLOSED` and `REQ -> CLOSED` early-close branch.
- T5 `auth/protected`: validate strict challenge/relay/timestamp checks and protected-event policy
  coupling.
- T6 `policy wrappers`: compare wrapper-safe flows vs compatibility helpers for PoW/delete call sites.

## Rubric

- `R1 discoverability`: can an LLM locate the correct strict API and wrapper entry points from names
  and exported surfaces without trial-and-error.
- `R2 boundary clarity`: typed errors communicate trust-boundary causes precisely enough for policy
  handling.
- `R3 composition cost`: common relay/client workflows require low ceremony while keeping strict
  defaults explicit.
- `R4 misuse resistance`: unsafe or ambiguous paths are difficult to pick accidentally.
- `R5 docs parity`: planning artifacts match implemented signatures and semantics.

Scoring scale per rubric item:

- `2`: good (clear with no notable friction)
- `1`: acceptable (minor friction)
- `0`: poor (repeated confusion or unsafe default tendency)

Pass threshold:

- No `0` on `R2` or `R4`.
- Average score >= `1.4` across `R1`..`R5` for the first full battery run.

## Initial Findings and Recommendations

Initial findings after parity refresh of current docs:

- `F1`: event API naming drift existed in contracts (`EventComputeIdError` vs implemented
  `EventShapeError`, missing `event_serialize_canonical_json` / checked id surfaces).
- `F2`: message transcript semantics drift existed in contracts (`CLOSED` now allowed pre-EOSE,
  plus explicit `transcript_apply` helper).
- `F3`: PoW wrapper error naming drift existed in contracts (`InvalidEventId` vs canonical
  `InvalidId` under `PowVerifiedIdError`).
- `F4`: security follow-up status drift existed for usability sequencing (pending vs started).
- `F5`: transcript naming needed explicit doc cleanup so compatibility aliasing does not hide the
  strict canonical path (`transcript_mark_client_req` + `transcript_apply_relay`), while
  preserving alias discoverability (`transcript_apply_compat` and `transcript_apply`).

Recommendations:

- `REC-1`: keep wrapper names (`*_checked`, `*_verified_id`) as canonical trust-boundary defaults in
  docs and examples.
- `REC-2`: include one compact transcript state diagram in this artifact before closure to reduce
  ordering ambiguity for LLM-generated call sequences.
- `REC-3`: keep error-name parity checks in the task battery as a standing gate each time
  `v1-api-contracts.md` is updated.
- `REC-4`: track OQ-E-006 progress only through this artifact plus
  `docs/plans/security-hardening-register.md` to avoid status drift.
- `REC-5`: keep `transcript_apply_compat` documented as compatibility alias only, with canonical
  strict flow documented as `transcript_mark_client_req` then `transcript_apply_relay`; keep
  `transcript_apply` documented as alias-equivalent to `transcript_apply_compat`.

## Strictness Profile Decision Inputs (Current)

- Keep these currently strict behaviors as explicit evaluation targets for RC defaults:
  - filter `ids`/`authors` lowercase hex-prefix semantics (`1..64`).
  - unknown filter-field rejection.
  - relay `OK` status-prefix strictness.
  - NIP-42 origin strictness (normalized path binding and `ws`/`wss` distinction).
- Current hygiene baseline for usability runs: Tiger hard checks are clean in `src/` (`>100` columns none,
  `>70`-line functions none); strict-width and anti-pattern cleanup remains a quality follow-up where
  applicable.

## OQ-E-006 Closure Criteria

`OQ-E-006` is closed only when all criteria below are complete:

- C1 task battery executed end-to-end at least once against current implementation and docs.
- C2 rubric pass threshold met (`R2`/`R4` non-zero; average >= `1.4`).
- C3 all Medium+ usability blockers identified in the battery are either fixed or explicitly accepted
  with owner + reversal trigger.
- C4 `docs/plans/v1-api-contracts.md`, `docs/plans/build-plan.md`, `docs/plans/decision-log.md`,
  `docs/plans/security-hardening-register.md`, and `handoff.md` reflect the same usability status.
- C5 decision-log entry records closure state transition for `OQ-E-006` before RC API freeze.

## Decisions

- `UL-001`: treat this artifact as the canonical execution log for usability pass status and closure
  criteria.
- `UL-002`: run usability evaluation on hardened strict APIs only (post-security checkpoint sequence).

## Tradeoffs

## Tradeoff T-UL-001: Immediate usability feedback versus post-hardening stability

- Context: usability testing can begin earlier on evolving APIs or after hardening stabilizes.
- Options:
  - O1: start before hardening completion.
  - O2: start after hardening completion.
- Decision: O2.
- Benefits: lower churn and more reliable UX signal for release-facing APIs.
- Costs: later feedback on pre-hardening ergonomics.
- Risks: remaining usability issues may cluster close to RC freeze.
- Mitigations: run focused task battery now and track closure criteria explicitly.
- Reversal Trigger: security follow-up reopens major API surfaces and invalidates current run.
- Principles Impacted: P01, P03, P05.
- Scope Impacted: OQ-E-006 closure workflow and release readiness checks.

## Open Questions

- `OQ-UL-001`: does transcript helper naming (`transcript_apply_compat`/`transcript_apply` aliases
  versus canonical `transcript_mark_client_req` + `transcript_apply_relay`) require an
  example-first docs update beyond current signatures to reduce LLM misuse risk.
- `OQ-UL-002`: should RC defaults preserve the current strict profile on filter/relay-origin/status
  parsing, or downgrade selected paths for interoperability.

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: trust-boundary wrappers and typed failures are explicitly evaluated.
- `P02`: scope remains protocol-kernel APIs and avoids transport-coupled UX assumptions.
- `P03`: parity drift checks are explicit in task battery and findings.
- `P04`: relay/auth/protected policy usability is included as a dedicated battery task.
- `P05`: deterministic transcript and grammar semantics are explicitly tested.
- `P06`: evaluation focuses on bounded strict APIs and does not introduce unbounded runtime behavior.

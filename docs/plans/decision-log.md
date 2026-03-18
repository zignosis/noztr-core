---
title: Decision Log
doc_type: reference
status: active
owner: noztr
read_when:
  - tracing_specific_decision_id
  - changing_policy_defaults
  - auditing_exact_contract_history
canonical: true
---

# Decision Log

Immutable record of accepted planning decisions.

Startup-routing note: use `docs/plans/decision-index.md` to decide whether the full canonical
payload is needed for the current task.

## Change Control

- Add new decisions; do not edit accepted decision payloads except typo-only fixes.
- If meaning changes, add a new decision ID and mark the old one superseded.
- Canonical payload must be self-contained in each decision entry.
- Do not rely on cross-file references as the only source for canonical fields.
- Required decision fields: Date, Status, Decision, Why, Tradeoff, Reversal Trigger.
- Traceability fields required: Related Tradeoff IDs, Supersedes.

## Phase Closure Evidence Rules

- Every closed phase must include one evidence record in this file.
- Evidence record fields: Phase, Closure Date, Gate Result, Ambiguity Snapshot,
  Decision-Needed Count (High Impact), Owner.
- Phase closure is invalid if high-impact `decision-needed` count is non-zero.

## D-001: Freeze parity source snapshots

- Date: 2026-03-04
- Status: accepted
- Decision: freeze the parity baseline on this exact snapshot set:
  - applesauce
    - repo: `git@github.com:hzrd149/applesauce.git`
    - local path: `/workspace/pkgs/applesauce`
    - commit: `5f152fc98e5baa97e8176e54ce9b9345976c8b32`
  - rust-nostr
    - repo: `git@github.com:rust-nostr/nostr.git`
    - local path: `/workspace/pkgs/nostr`
    - commit: `9bcc6cd779a7c6eb41509b37aee4575fa5ae47b9`
  - libnostr-z
    - repo: `git@github.com:privkeyio/libnostr-z.git`
    - local path: `/workspace/pkgs/nostr/libnostr-z`
    - commit: `a849dc804521801971f42d71c172aa681ecdc573`
  - pin date: `2026-03-04`
- Reference role: these sources are pinned to make analysis and parity evidence reproducible. They
  are strong implementation references, not protocol authority.
- Why: reproducible analysis across phased planning.
- Tradeoff: stale source risk versus reproducibility.
- Related Tradeoff: T-0-002.
- Reversal Trigger: parity analysis requires upstream changes not represented in
  pinned commits.
- Supersedes: none
- Later refinement: `D-124` tightens this rule by forbidding all in-audit fixes and expanding the
  required audit surface and angle split.

## D-002: Define parity as behavior, not API shape

- Date: 2026-03-04
- Status: accepted
- Decision: parity means behavioral parity (parse, validate, serialize, verify,
  and tests), not API shape parity. Treat `rust-nostr` as the primary active parity lane because it
  is a strong production reference and ecosystem proxy, not because it is the canonical truth of
  the protocol. Improvements over the reference remain allowed when they are NIP-grounded,
  explicitly reasoned, bounded, and test-backed.
- Why: preserve Zig-native API quality and constraints while using a strong ecosystem reference to
  improve compatibility confidence.
- Tradeoff: adapter work versus cleaner long-term core API.
- Related Tradeoff: T-0-002.
- Reversal Trigger: explicit product requirement for source-compatible APIs.
- Supersedes: none
- Later refinement: `D-124` tightens the active audit program by splitting cryptographic review and
  requiring whole-codebase coverage.

## D-003: Strict-by-default protocol policy

- Date: 2026-03-04
- Status: accepted
- Decision: strict parsing/validation by default; compatibility handling only by
  documented exception with tests.
- Why: deterministic behavior and lower safety risk.
- Tradeoff: reduced permissiveness versus clearer semantics.
- Related Tradeoff: T-0-001, T-0-003.
- Reversal Trigger: high-value interop blocked without broad compatibility mode.
- Supersedes: none

## D-004: Mandatory phase closure gate

- Date: 2026-03-04
- Status: accepted
- Decision: no phase closure without tradeoff records and ambiguity checkpoint.
- Why: prevent silent decision drift and late-stage rework.
- Tradeoff: more process overhead versus higher planning quality.
- Related Tradeoff: T-0-004.
- Reversal Trigger: demonstrated process bottleneck without quality benefits.
- Supersedes: none

## D-005: Typed backend-outage errors at verify/auth trust boundaries

- Date: 2026-03-06
- Status: accepted
- Decision: event verify and NIP-42 auth paths must expose backend outage as typed errors distinct
  from cryptographic invalidity.
- Why: relay policy and observability need outage-versus-invalid separation for deterministic handling.
- Tradeoff: larger error surfaces versus precise failure semantics.
- Related Tradeoff: T-0-003.
- Reversal Trigger: backend integration no longer has outage semantics that can be observed at boundary.
- Supersedes: none

## D-006: NIP-42 strict hardening semantics

- Date: 2026-03-06
- Status: accepted
- Decision: challenge rotation clears authenticated pubkeys; duplicate required `relay`/`challenge`
  tags are rejected as `DuplicateRequiredTag`; freshness rejects `FutureTimestamp` and
  `StaleTimestamp` beyond window.
- Why: closes replay/ambiguity gaps while preserving deterministic strict defaults.
- Tradeoff: stricter validation versus permissive ecosystem tolerance.
- Related Tradeoff: T-0-001, T-0-003.
- Reversal Trigger: standards-backed parity evidence requires broader permissive behavior.
- Supersedes: none

## D-007: Freeze checked wrappers for strict call sites

- Date: 2026-03-06
- Status: accepted
- Decision: treat `pow_meets_difficulty_verified_id`, `delete_extract_targets_checked`, and transcript
  split markers (`transcript_mark_client_req`, `transcript_apply_relay`) as canonical safe wrappers.
- Why: reduces misuse risk by collapsing multi-step validation into single typed entry points.
- Tradeoff: additional API surface versus safer default integration behavior.
- Related Tradeoff: T-0-001.
- Reversal Trigger: wrapper layering causes measurable maintenance burden without reducing defects.
- Supersedes: none

## D-008: secp boundary hardening and source pinning

- Date: 2026-03-06
- Status: accepted
- Decision: reduce exposed secp boundary module surface and require commit-SHA pinning for the selected
  backend.
- Why: minimizes accidental direct backend usage and supply-chain drift.
- Tradeoff: less flexibility in backend updates versus stronger reproducibility and safety.
- Related Tradeoff: T-0-003.
- Reversal Trigger: verified security maintenance need requires backend pin update or boundary expansion.
- Supersedes: none

## D-009: Post-security usability evaluation sequencing

- Date: 2026-03-06
- Status: accepted
- Decision: schedule LLM-first usability evaluation after security hardening completion and before the
  first release-candidate API freeze.
- Why: evaluate developer UX on hardened APIs rather than pre-hardening surfaces.
- Tradeoff: delayed UX feedback versus lower churn and clearer usability signal.
- Related Tradeoff: T-0-004.
- Reversal Trigger: security-critical issue requires postponing usability work.
- Supersedes: none

## D-010: NIP-42 auth boundary hardening follow-up

- Date: 2026-03-06
- Status: accepted
- Decision: extend strict NIP-42 auth hardening with distinct challenge-set boundary failures
  (`ChallengeEmpty` vs `ChallengeTooLong`) and relay-origin matching that accepts bracketed IPv6
  authorities while preserving strict scheme/host/port equality semantics.
- Why: removes ambiguity at the auth challenge boundary and closes IPv6 authority parsing gaps without
  widening origin-match permissiveness.
- Tradeoff: larger typed error surface and stricter authority parsing behavior versus permissive
  fallback matching.
- Related Tradeoff: T-0-001, T-0-003.
- Reversal Trigger: standards-backed interop evidence requires a different strict origin policy.
- Supersedes: none

## D-011: Low-hardening strictness and edge-audit closure

- Date: 2026-03-06
- Status: accepted
- Decision: close low-hardening parser gaps by requiring relay `OK` event ids to be strict lowercase
  hex and rejecting empty `#x` arrays in strict filter parsing; close edge-case audit with no
  unresolved Medium+ findings.
- Why: preserves deterministic strict boundaries and removes acceptance ambiguity in low-severity edge
  paths.
- Tradeoff: stricter rejection behavior versus permissive parsing of malformed relay/filter payloads.
- Related Tradeoff: T-0-001, T-0-003.
- Reversal Trigger: standards-backed parity evidence requires accepting uppercase `OK` ids or empty
  `#x` arrays in strict mode.
- Supersedes: none

## D-012: Dedicated security hardening register

- Date: 2026-03-06
- Status: accepted
- Decision: maintain `docs/plans/security-hardening-register.md` as the dedicated security hardening
  status register and link it from planning artifacts.
- Why: keeps implemented controls and low/edge follow-up status in one auditable location.
- Tradeoff: one additional artifact to maintain versus lower hardening status drift.
- Related Tradeoff: T-0-004.
- Reversal Trigger: register duplicates policy content without improving hardening traceability.
- Supersedes: none

## D-013: Finalize NIP-42 relay matching and PoW commitment hardening semantics

- Date: 2026-03-07
- Status: accepted
- Decision: strict NIP-42 relay matching now binds normalized path in addition to
  scheme/host/port (query/fragment ignored; missing path normalized to `/`) and rejects
  unbracketed IPv6 authorities; strict PoW commitment policy enforces both commitment
  truthfulness (`actual_bits >= commitment`) and commitment floor (`commitment >= required_bits`).
- Why: closes remaining low-severity ambiguity in relay-origin and PoW commitment checks while
  preserving deterministic strict defaults.
- Tradeoff: stricter URL/PoW validation behavior versus permissive acceptance of ambiguous inputs.
- Related Tradeoff: T-0-001, T-0-003.
- Reversal Trigger: standards-backed parity evidence requires a less strict relay-origin or
  commitment policy.
- Supersedes: D-010

- Follow-up observations (low):
  - closed: normalized-path binding in NIP-42 relay origin matching (`/` default;
    query/fragment ignored).
  - closed: unbracketed IPv6 authority rejection in NIP-42 relay matching.
  - closed: canonical event runtime shape/UTF-8 validation guards.
  - closed: PoW commitment truthfulness/floor enforcement (`actual_bits >= commitment >=
    required_bits`).
  - closed: `auth_validate_event` expected challenge bounds guard rejects empty and oversized
    `expected_challenge` inputs.
  - closed: `event_compute_id` invalid runtime shape now fails with typed error instead of
    all-zero compatibility fallback (`src/nip01_event.zig`).
  - superseded: LLM-first usability evaluation status moved to `D-014` (`OQ-E-006`).
  - canonical tracker: `docs/plans/security-hardening-register.md`.

## D-014: Start LLM-usability pass and track OQ-E-006 closure criteria

- Date: 2026-03-07
- Status: accepted
- Decision: start the LLM-first usability pass and treat `docs/plans/llm-usability-pass.md` as the
  working artifact for OQ-E-006 execution status, findings, recommendations, and closure criteria.
- Why: hardening defaults are now stable and usability evaluation should run on the hardened API
  surface before RC freeze.
- Tradeoff: additional near-term documentation and evaluation overhead versus earlier API ergonomics
  signal on strict, security-finalized surfaces.
- Related Tradeoff: T-0-004.
- Reversal Trigger: security-critical regressions require pausing usability work until hardening
  stability is restored.
- Supersedes: none

- Status snapshot:
  - `event_compute_id` all-zero fallback follow-up: closed (canonical typed runtime-shape failure).
  - superseded: LLM-first usability evaluation closure state moved to `D-117`.
  - security hardening tracker remains canonical: `docs/plans/security-hardening-register.md`.

## D-015: Record Tiger cleanliness and strictness-profile evaluation inputs

- Date: 2026-03-07
- Status: accepted
- Decision: record current implementation hygiene and interoperability evaluation inputs as follows:
  - Tiger hard rules are currently clean for `src/` on hard checks (`>100` columns: none,
    `>70`-line functions: none).
  - strict-width and anti-pattern cleanup remains tracked as quality follow-up where applicable.
  - strictness/interoperability choices were validated through `OQ-E-006` and now carry forward as
    RC-freeze inputs: strict filter full-hex requirement, unknown filter-field rejection, strict
    relay `OK` status-prefix validation, and strict NIP-42 origin matching (path-bound plus
    `ws`/`wss` distinction).
- Why: keeps current implementation hygiene and strictness-default evaluation criteria explicit before RC
  profile defaults are frozen.
- Tradeoff: additional documentation maintenance versus lower policy drift across planning artifacts.
- Related Tradeoff: T-0-001, T-0-004.
- Reversal Trigger: accepted strictness-profile defaults or Tiger baseline regressions require policy
  update.
- Supersedes: none

## D-016: Adopt dedicated NOZTR style profile and planning links

- Date: 2026-03-07
- Status: accepted
- Decision: adopt `docs/guides/NOZTR_STYLE.md` as the dedicated project style profile and link it from
  active planning artifacts (`docs/plans/build-plan.md`, `docs/plans/decision-log.md`, `handoff.md`).
  The profile freezes core defaults for strict protocol-kernel behavior, typed trust-boundary errors,
  bounded memory/work, caller-owned buffers, strict-default plus explicit compatibility adapters, and
  one-obvious-way canonical safe trust-boundary entry points.
- Why: centralizes strictness and API-usage expectations in one stable reference and reduces policy
  drift between implementation, planning, and LLM usability evaluation.
- Tradeoff: one additional artifact to maintain versus clearer enforcement and lower ambiguity.
- Related Tradeoff: T-0-001, T-0-003, T-0-004.
- Reversal Trigger: the style profile duplicates existing canonical defaults without improving
  strictness decisions or usability outcomes.
- Supersedes: none

## D-017: Adopt two-layer architecture intent and strictness evaluation loop

- Date: 2026-03-07
- Status: accepted
- Decision: keep Layer 1 as the strict protocol kernel and treat Layer 2 as an explicit
  compatibility/ergonomic adapter lane. Layer 1 defaults are lowercase-only critical hex and unknown
  filter-field rejection; compatibility tolerance is evaluated and introduced only in Layer 2 through
  the `OQ-E-006` loop (boundary choice -> tradeoff record -> forcing vectors -> usability evidence ->
  decision-log freeze).
- Why: preserves deterministic kernel guarantees while allowing practical interop improvements without
  silent default drift.
- Tradeoff: additional adapter design/test effort versus clearer guarantees and lower trust-boundary
  ambiguity in core modules.
- Related Tradeoff: T-0-001, T-0-003, T-0-004.
- Reversal Trigger: standards-backed evidence shows strict Layer 1 defaults block required parity and
  cannot be handled safely by Layer 2 adapters.
- Supersedes: none

## D-018: Overengineering mitigation pass for trust boundaries and strict filters

- Date: 2026-03-08
- Status: accepted
- Decision: apply a focused overengineering/correctness mitigation pass that (1) clarifies the
  canonical trust-boundary path to checked strict entry points, (2) reduces parser error ambiguity by
  documenting implemented typed variants at the message boundary, and (3) tightens strict
  `nip01_filter` semantics to deterministic lowercase hex-prefix matching for `ids`/`authors`
  (`1..64`) with lowercase-only `#x` keys.
- Why: removes avoidable ambiguity in policy-facing docs while matching current implementation
  behavior and preserving deterministic strict defaults.
- Tradeoff: tighter and more explicit strict contracts versus reduced permissiveness and less
  shorthand flexibility in docs.
- Related Tradeoff: T-0-001, T-0-003, T-0-004.
- Reversal Trigger: standards-backed parity evidence requires broader permissive defaults at Layer 1.
- Supersedes: none

## D-019: Close I7 with regression and contract-trace evidence pack

- Date: 2026-03-08
- Status: accepted
- Decision: treat the I7 closure evidence pack as complete and canonical for the current
  implementation baseline, with required artifacts:
  - `docs/archive/plans/i7-regression-evidence.md`
  - `docs/archive/plans/i7-api-contract-trace-checklist.md`
  - `docs/archive/plans/i7-phase-f-kickoff-handoff.md`
- Why: closes I7 with explicit command evidence, replay evidence, and contract-to-implementation
  traceability before Phase F kickoff.
- Tradeoff: additional documentation maintenance versus lower closure-status drift and higher audit
  confidence.
- Related Tradeoff: T-0-004, T-E-001.
- Reversal Trigger: closure evidence artifacts become stale relative to accepted implementation
  behavior or gate commands.
- Supersedes: none

## D-020: Post-I7 phase-state naming and contract delta sync

- Date: 2026-03-08
- Status: accepted
- Decision: standardize post-I7 wording so planning prompt phase closure records remain historical in
  `decision-log`, while active execution state is explicitly described as post-I7 baseline with
  Phase F kickoff actions. Synchronize contract docs with implemented deltas: NIP-44 padded-length
  return type/bounds (`u32`, `32..65536`), parser `OutOfMemory` variants where implemented,
  strict `kind <= 65535` boundaries, transcript canonical-vs-compat alias wording,
  NIP-77 `NEG-CLOSE`/`NEG-ERR` parser APIs, NIP-50 unsupported multi-colon token handling,
  and NIP-09 duplicate-`d` coordinate matching policy.
- Why: removes phase-status contradiction and keeps API contract language aligned with current code.
- Tradeoff: additional documentation maintenance versus lower closure drift and clearer integration
  guidance.
- Related Tradeoff: T-0-004, T-E-001.
- Reversal Trigger: accepted implementation/default changes require a new naming convention or
  contract wording baseline.
- Supersedes: none

## D-021: Start Phase F execution tracking on post-I7 baseline

- Date: 2026-03-08
- Status: accepted
- Decision: start active Phase F execution tracking on the post-I7 baseline and anchor kickoff
  execution guidance in the historical Phase F kickoff packet
  (`docs/archive/plans/phase-f-kickoff.md`), including UT-E-003/UT-E-004 burn-down, optional
  corpus review triggers (`UT-E-001`/`A-D-001`), and dual-run gate reminders.
- Why: keeps execution state explicit after I7 closure while preserving deterministic gate posture.
- Tradeoff: additional tracking artifact maintenance versus lower phase-state drift.
- Related Tradeoff: T-0-004, T-E-001.
- Reversal Trigger: execution tracking responsibilities move into another canonical artifact without
  losing traceability.
- Supersedes: none

- Policy note: no frozen-default or strictness-policy changes are introduced by this kickoff update.

## D-022: Record Phase F first-pass risk burn-down evidence

- Date: 2026-03-08
- Status: accepted
- Decision: capture the first concrete Phase F replay/boundary pass for `UT-E-003` and `UT-E-004` in
  `docs/archive/plans/phase-f-risk-burndown.md`, including baseline snapshot, replay matrix
  template, command evidence, outcomes, and next owners.
- Why: establish auditable execution evidence for carry-forward risk burn-down without waiting for
  phase closure.
- Tradeoff: one additional status artifact to maintain versus lower execution-status drift.
- Related Tradeoff: T-0-004, T-E-001.
- Reversal Trigger: Phase F execution evidence is moved into another canonical artifact with equal or
  better traceability.
- Supersedes: none

- Policy note: this evidence-capture decision introduces no frozen-default or strictness-policy change.

## D-023: Phase F Step 5 documentation lock for trigger governance

- Date: 2026-03-08
- Status: accepted
- Decision: lock Phase F Step 5 documentation status as follows: frozen strict defaults remained
  unchanged during Steps 1-3, and trigger evaluation for `UT-E-001`/`A-D-001` fired no criteria in
  current passes.
- Why: keeps default-governance state explicit while burn-down work progresses.
- Tradeoff: one additional documentation update versus lower policy-state drift.
- Related Tradeoff: T-0-004, T-E-001.
- Reversal Trigger: future trigger criteria fire and require default-policy change consideration.
- Supersedes: none

- Policy note: if future `UT-E-001`/`A-D-001` trigger criteria fire, add an explicit decision-log
  entry before changing defaults.

## D-024: Phase F cadence/governance check (Step 2 and Step 4)

- Date: 2026-03-08
- Status: accepted
- Decision: record that aggregate dual-run gates were executed after each increment pass in Step 2 and
  Step 4 (expanded matrix); latest aggregate result is `454/456` passed, `2` skipped.
- Why: keeps execution cadence and gate posture explicit while burn-down increments proceed.
- Tradeoff: one additional status record versus lower governance-state drift.
- Related Tradeoff: T-0-004, T-E-001.
- Reversal Trigger: trigger criteria fire and governance requires default-policy change consideration.
- Supersedes: none

- Policy note: no `UT-E-001`/`A-D-001` trigger criteria fired in this cadence check, so no
  policy/default changes were considered.
- Rule note: any future trigger firing must be captured in this decision log before default changes.

## D-025: Phase F cadence/governance check (TS parity-all and rust depth-notch)

- Date: 2026-03-09
- Status: accepted
- Decision: record that aggregate dual-run gates were executed after each cadence increment for the
  TS parity-all step and the rust depth-notch step; latest aggregate remains `454/456` passed,
  `2` skipped.
- Why: keeps increment-level gate cadence and governance posture explicit as replay depth expands.
- Tradeoff: one additional decision-log checkpoint versus lower governance-state drift.
- Related Tradeoff: T-0-004, T-E-001.
- Reversal Trigger: `UT-E-001` or `A-D-001` trigger criteria fire and require default-policy
  change consideration.
- Supersedes: none

- Policy note: no `UT-E-001`/`A-D-001` trigger criteria fired at this checkpoint, so no
  policy/default changes were considered.
- Rule note: any future trigger firing requires a decision-log entry before any default changes.

## D-026: Adopt Phase F parity execution model v1

- Date: 2026-03-09
- Status: accepted
- Decision: adopt parity execution model v1 for parity-all interop harnesses and docs with:
  - canonical taxonomy terms: `LIB_SUPPORTED`, `HARNESS_COVERED`,
    `NOT_COVERED_IN_THIS_PASS`, `LIB_UNSUPPORTED`.
  - canonical depth labels: `BASELINE`, `EDGE`, `DEEP`.
  - stable output shape per check: `NIP-XX | taxonomy=<...> | depth=<...> | result=<...>`.
  - non-zero process exit only when a `HARNESS_COVERED` check fails.
  - implemented-but-untested NIPs default to `NOT_COVERED_IN_THIS_PASS`.
  - `LIB_UNSUPPORTED` is emitted only when explicitly proven in harness code.
  - canonical parity status lives in:
    - `docs/archive/plans/phase-f-parity-matrix.md`
    - `docs/archive/plans/phase-f-parity-ledger.md`
- Why: remove overloaded unsupported wording, stabilize machine/human parse output, and keep one
  canonical parity status source across lanes.
- Tradeoff: extra taxonomy/depth bookkeeping versus clearer parity semantics and lower status drift.
- Related Tradeoff: T-0-004, T-E-001.
- Reversal Trigger: taxonomy/depth model adds sustained maintenance cost without improving parity
  traceability.
- Supersedes: none

- Policy note: this adoption introduces no frozen-default or strictness-policy change.

## D-027: Narrow active parity reference scope to rust-nostr

- Date: 2026-03-09
- Status: accepted
- Decision: keep `rust-nostr` as the only active parity gate lane and archive
  `nostr-tools` parity-all operations as historical evidence only. Preserve all existing
  TypeScript parity results in canonical Phase F artifacts.
- Why: a single active parity gate lane reduces operational cadence overhead while preserving
  historical cross-language evidence for auditability.
- Tradeoff: less active cross-language pass/fail signal versus simpler, more stable gate operations.
- Related Tradeoff: T-0-004, T-E-001.
- Reversal Trigger: sustained parity drift or integration demand requires reactivating a
  second active gate lane.
- Supersedes: none

- Policy note: this governance-scope decision does not change frozen defaults or strictness/library
  behavior.

## D-028: Record NIP-59 deep parity evidence on rust active lane

- Date: 2026-03-09
- Status: accepted
- Decision: raise rust parity-all `NIP-59` depth from `BASELINE` to `DEEP` and record comparative
  evidence against existing `noztr` NIP-59 module tests while keeping TypeScript parity lane archived
  as historical-only evidence.
- Why: increases parity confidence on the active lane with sender/recipient boundary negatives and
  deterministic repeated-unwrap checks without changing gate operations scope.
- Tradeoff: slightly higher harness maintenance cost versus stronger active-lane NIP-59 rejection
  coverage.
- Related Tradeoff: T-0-004, T-E-001.
- Reversal Trigger: deep-case maintenance cost outweighs parity confidence benefit or active lane
  changes from rust-only governance.
- Supersedes: none

- Policy note: this parity-depth evidence decision does not change frozen defaults or strictness/library
  behavior.

## D-029: Normalize dependency policy to stdlib-first plus approved pinned crypto backends

- Date: 2026-03-10
- Status: accepted
- Decision: normalize the repository dependency policy to `stdlib-first` rather than absolute
  zero-dependency wording. Public protocol modules remain `@import("std")` by default, while
  approved pinned crypto backend exceptions are allowed only when recorded in this decision log.
  Every approved exception must stay behind one narrow boundary module, use pinned source identity,
  expose typed error mapping, preserve bounded runtime behavior, and carry vector/differential
  verification evidence.
- Why: the pinned `bitcoin-core/secp256k1` backend is already an accepted implementation choice and
  the canonical policy should describe the real dependency posture without allowing ad hoc drift.
- Tradeoff: slightly broader dependency policy surface versus truthful canonical guidance and tighter
  control over security-sensitive exceptions.
- Related Tradeoff: T-0-003, T-0-004.
- Reversal Trigger: all approved backend exceptions are removed and the repository returns to a true
  zero-external-dependency posture.
- Supersedes: none

## D-030: Select libwally-core as the vetted NIP-06 dependency path

- Date: 2026-03-10
- Status: accepted
- Decision: for planned NIP-06 support, adopt `libwally-core` as the vetted external implementation
  path for BIP39/BIP32 rather than in-house implementation. The integration must follow `D-029`:
  pinned source identity, one narrow boundary module, typed error mapping, deterministic vectors, and
  no unbounded runtime allocation introduced by the boundary.
- Why: BIP39/BIP32 are security-sensitive key-management primitives; using a mature vetted library is
  lower risk than in-house implementation and keeps Phase H focused on bounded boundary contracts.
- Tradeoff: additional supply-chain surface versus lower wallet-primitive implementation risk and
  faster convergence on a defensible NIP-06 plan.
- Related Tradeoff: T-X-004.
- Reversal Trigger: `libwally-core` cannot satisfy pinned-boundary, typed-error, deterministic-corpus,
  or bounded-runtime requirements for noztr.
- Supersedes: none

## D-031: Close Phase G locally and start Phase H expansion planning

- Date: 2026-03-10
- Status: accepted
- Decision: close Phase G on local-only non-remote release-readiness criteria, explicitly defer
  remote readiness blocker `no-3uj` outside the completed Phase G closure gate, and start Phase H
  kickoff for additional NIP expansion planning in:
  - `docs/plans/phase-h-kickoff.md`
  - `docs/plans/phase-h-additional-nips-plan.md`
- Why: no remote is currently configured/in active scope, so tying phase closure to unavailable
  remote infrastructure would mis-state the actual operator environment and block planning progress.
- Tradeoff: Phase G closes without remote push evidence versus an accurate local execution-state
  record and continued roadmap progress.
- Related Tradeoff: T-0-004.
- Reversal Trigger: remote setup returns to active scope and requires reopening release-readiness
  closure criteria.
- Supersedes: none

## D-032: Freeze Phase H NIP-06 minimum functional boundary and acceptance posture

- Date: 2026-03-10
- Status: accepted
- Decision: for Phase H, NIP-06 scope is frozen to the minimum fully functional Nostr derivation
  boundary: mnemonic validation, mnemonic plus optional passphrase to seed, BIP32 master-key
  creation, and derivation of Nostr keys at `m/44'/1237'/<account>'/0/0`. Acceptance requires strict
  zeroization of sensitive temporary material and typed errors on every public boundary. Broader
  rust-nostr parity depth and deeper edge-case expansion remain a later-phase follow-up after the
  initial narrow boundary lands.
- Why: keeps the Phase H NIP-06 surface useful for real Nostr workflows without expanding into a
  broad wallet API before the boundary is proven.
- Tradeoff: narrower short-term API breadth versus lower security review surface and clearer
  acceptance criteria.
- Related Tradeoff: T-H-ANIP-002, T-H-ANIP-003.
- Reversal Trigger: actual Nostr integrator demand proves the frozen minimum boundary is insufficient
  for core workflows.
- Supersedes: none

## D-033: Adopt a serial autonomous closure loop for Phase H Wave 1

- Date: 2026-03-10
- Status: accepted
- Decision: execute Phase H Wave 1 serially, one NIP at a time, through an explicit closure loop in
  `docs/plans/phase-h-wave1-loop.md` with mandatory stages for contract freeze, implementation,
  correctness/edge-case tests, rust parity review, overengineering review, style review, gates, and
  tracker closure before advancing.
- Why: converts the implementation process from operator memory into a repeatable system that keeps
  correctness, parity, and style checks mandatory under low-supervision execution.
- Tradeoff: lower parallel throughput versus cleaner defect isolation, lower policy drift, and higher
  review consistency.
- Related Tradeoff: T-H-W1-001.
- Reversal Trigger: evidence shows serial loop execution adds delay without reducing rework or review
  misses.
- Supersedes: none

## D-034: Expand the Phase H Wave 1 loop to dual-review and mandatory documentation capture

- Date: 2026-03-10
- Status: accepted
- Decision: expand the Phase H Wave 1 execution loop so every NIP must complete two review cycles
  before closure, must capture implementation learnings in existing canonical artifacts or beads
  issue evidence, and must be reviewed from correctness, edge-case, rust parity, overengineering,
  style, LLM usability, human usability, and Zig pattern/anti-pattern perspectives.
- Why: the original loop was not strict enough to guarantee autonomous execution quality without
  relying on operator memory for review depth or documentation follow-through.
- Tradeoff: more per-NIP review/documentation work versus lower defect escape risk and lower loss of
  reasoning between sessions.
- Related Tradeoff: T-H-W1-001.
- Reversal Trigger: evidence shows the added review/documentation stages do not materially improve
  implementation quality or traceability.
- Supersedes: none

## D-035: Freeze the Phase H0 NIP-06 libwally boundary, pin target, and corpus floor

- Date: 2026-03-10
- Status: accepted
- Decision: complete the Phase H0 checkpoint for NIP-06 by freezing the integration target on
  `ElementsProject/libwally-core` release tag `release_1.5.2` at commit
  `6439e6e3262c47ce0e51aa95d7b4ff67d9952c52`. Freeze the implementation boundary to one module,
  `src/nip06_mnemonic.zig`, with this public surface only:
  - `mnemonic_validate`
  - `mnemonic_to_seed`
  - `derive_nostr_secret_key_from_seed`
  - `derive_nostr_secret_key`
  External `libwally-core` usage is limited to mnemonic validation, mnemonic-to-seed conversion,
  master-key creation from seed, and hardened/non-hardened derivation for the canonical Nostr path
  `m/44'/1237'/<account>'/0/0`. Public-key derivation remains on the existing secp boundary rather
  than expanding the `libwally-core` boundary. The minimum required corpus is frozen to:
  - valid:
    - official BIP39 mnemonic-to-seed vectors
    - the two official NIP-06 mnemonic-to-secret-key vectors from `docs/nips/06.md`
    - the additional pinned rust-nostr mnemonic-to-secret-key vector in
      `/workspace/pkgs/nostr/crates/nostr/src/nips/nip06/mod.rs`
    - at least one higher-account derivation vector for `account = 1`
  - invalid:
    - malformed mnemonic length
    - unknown word
    - checksum mismatch
    - invalid UTF-8 / normalization failure at the boundary
    - `account >= 2^31` reject
    - seed/output buffer too small reject
  Sensitive buffers requiring strict zeroization are frozen to: mnemonic-derived seed, master key
  material, derived child private keys, and temporary output staging used before copy-out.
- Why: this turns H0 from a generic dependency intent into a concrete, reviewable implementation
  contract that satisfies the refined loop requirements before further Wave 1 work continues.
- Tradeoff: tighter up-front boundary/corpus decisions versus less flexibility during eventual NIP-06
  coding.
- Related Tradeoff: T-H-ANIP-002, T-H-ANIP-003.
- Reversal Trigger: the selected `libwally-core` release or the frozen surface cannot satisfy
  bounded-runtime, typed-error, deterministic-corpus, or strict-zeroization requirements during
  implementation.
- Supersedes: none

## D-036: Adopt deterministic-and-compatible trust-boundary posture

- Date: 2026-03-10
- Status: accepted
- Decision: replace the blunt "strict-by-default" shorthand with this canonical posture for Layer 1
  protocol behavior:
  - choose the narrowest deterministic behavior that remains correct, bounded, explicit, and
    ecosystem-compatible.
  - do not reject input merely to enforce stylistic purity when the NIP intentionally leaves room
    and the broader shape remains unambiguous and bounded.
  - do reject malformed, cryptographically invalid, ambiguity-creating, or safety-eroding input at
    trust boundaries.
  - keep compatibility adaptations explicit when they would otherwise blur Layer 1 contracts, but do
    not treat compatibility itself as suspect.
- Parity note: parity review should learn from strong deployed references such as `rust-nostr`, but
  should not copy reference-library edge behavior blindly when a more correct or more Zig-appropriate
  bounded contract is justified and documented.
- Why: Nostr NIPs intentionally leave implementation room in several places, and the project goal is
  not "strict for strictness' sake" but deterministic correctness with low-friction ecosystem
  interoperability.
- Tradeoff: more case-by-case review effort versus a more accurate and useful protocol posture.
- Related Tradeoff: T-0-001, T-0-003.
- Reversal Trigger: evidence shows this posture causes ambiguous Layer 1 behavior or compatibility
  exceptions expand without bounded, explicit contracts.
- Supersedes: D-003

## D-037: Use `nostr-tools` as a secondary non-gating ecosystem audit signal

- Date: 2026-03-10
- Status: accepted
- Decision: keep `rust-nostr` as the only active parity gate lane, but include archived
  `nostr-tools` evidence as a secondary non-gating signal during implemented-NIP audits where it
  helps estimate broader ecosystem compatibility. `nostr-tools` evidence informs audit judgment; it
  does not become an active pass/fail release gate or override NIP authority.
- Why: `nostr-tools` is a major deployed library and improves ecosystem-confidence review, while a
  single active gate lane keeps execution cadence simpler and more reliable.
- Tradeoff: more audit evidence to weigh versus better visibility into real compatibility pressure.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: the extra audit signal adds sustained review noise without improving decisions,
  or needs to become an active gate lane to remain useful.
- Supersedes: none

## D-038: Widen the NIP-42 challenge bound while keeping fixed-state auth handling

- Date: 2026-03-10
- Status: accepted
- Decision: widen the fixed NIP-42 challenge bound from `64` bytes to `255` bytes in
  `nip42_auth`, while keeping challenge storage static and typed.
- Why: NIP-42 does not define a `64`-byte challenge maximum, and both `rust-nostr` and
  `nostr-tools` accept longer challenge strings. The `64`-byte cap created unnecessary
  interoperability risk without materially improving trust-boundary correctness.
- Tradeoff: slightly larger fixed auth state versus lower compatibility friction with relays that
  issue longer opaque challenges.
- Related Tradeoff: T-0-001, T-0-003.
- Reversal Trigger: production evidence shows a lower bound is required for safety or operational
  reasons beyond the existing fixed-state limit.
- Supersedes: none

## D-039: Widen NIP-51 bookmark extraction and ignore unrelated unknown tags

- Date: 2026-03-10
- Status: accepted
- Decision: widen `nip51_lists` extraction so `bookmarks` and `bookmark_set` accept bounded hashtag
  and URL items in addition to `e` and `a`, and ignore unrelated unknown tags instead of failing
  the entire extract path. Malformed supported tags still return typed errors.
- Why: `rust-nostr` bookmark builders emit broader bounded hashtag/URL shapes, NIP-51 is meant to
  carry references broadly, and failing whole extraction on unrelated extra tags created
  unnecessary compatibility loss without improving trust-boundary safety.
- Tradeoff: slightly broader public-list extraction surface versus materially better compatibility
  with real producer output and future extension tags.
- Related Tradeoff: T-0-001, T-0-002, T-0-003.
- Reversal Trigger: broader bookmark extraction causes ambiguous semantics or ecosystem evidence
  shows the narrower table-only interpretation is required for interoperable behavior.
- Supersedes: none

## D-040: Accept optional NIP-30 emoji-set coordinates in NIP-25 reactions

- Date: 2026-03-10
- Status: accepted
- Decision: widen `nip25_reactions` so reaction `emoji` tags accept the optional fourth-slot
  NIP-30 emoji-set coordinate when it is a valid `30030` address, while keeping strict shortcode
  and URL validation.
- Why: NIP-30 explicitly allows the optional emoji-set address on kind-7 custom-emoji tags, and
  rejecting it created unnecessary incompatibility with spec-valid reaction events without
  improving trust-boundary safety.
- Tradeoff: slightly broader reaction emoji-tag acceptance versus materially better compatibility
  with spec-valid NIP-30 producer output.
- Related Tradeoff: T-0-001, T-0-002, T-0-003.
- Reversal Trigger: production evidence shows the optional fourth slot creates ambiguity or
  ecosystem incompatibility that outweighs the spec-valid compatibility gain.
- Supersedes: none

## D-041: Reject contradictory NIP-25 target metadata and unsupported `a` kinds

- Date: 2026-03-10
- Status: accepted
- Decision: tighten `nip25_reactions` so it rejects reaction targets with contradictory optional
  metadata (`e`-author versus `p`, `a` pubkey versus author pubkey, `a` kind versus `k`) and
  rejects `a` coordinates whose kind is neither replaceable nor addressable.
- Why: these shapes create ambiguous target descriptions without adding compatibility value, and
  `a` tags are only defined for replaceable or addressable events in NIP-01.
- Tradeoff: stricter rejection of internally inconsistent optional metadata versus clearer
  trust-boundary target extraction semantics.
- Related Tradeoff: T-0-001, T-0-003.
- Reversal Trigger: ecosystem evidence shows deployed producers emit these contradictory shapes in a
  way that must be tolerated for interoperability, without sacrificing deterministic target
  handling.
- Supersedes: none

## D-042: Reject contradictory NIP-18 target metadata without embedded-event proof

- Date: 2026-03-10
- Status: accepted
- Decision: tighten `nip18_reposts` so repost parsing rejects contradictory optional target
  metadata when no embedded event proves the target (`kind 6` with non-`1` `k` or any `a` tag,
  `kind 16` with `k == 1`, `a` kinds outside replaceable/addressable ranges, `a`/`p` pubkey
  mismatch, or `a`/`k` kind mismatch).
- Why: these shapes describe impossible or internally inconsistent repost targets, and accepting
  them surfaced ambiguous target state without adding real compatibility value.
- Tradeoff: stricter rejection of contradictory optional repost metadata versus clearer
  trust-boundary extraction semantics when repost content is empty or does not carry the full
  embedded event.
- Related Tradeoff: T-0-001, T-0-003.
- Reversal Trigger: ecosystem evidence shows these contradictory shapes are common and must be
  tolerated for interoperability without weakening deterministic repost semantics.
- Supersedes: none

## D-043: Narrow NIP-27 inline extraction to event/profile/address references

- Date: 2026-03-11
- Status: accepted
- Decision: narrow `nip27_references` so strict inline extraction recognizes only the event,
  profile, and address entities actually treated as content references in the current NIP-27
  examples and the pinned Rust/TypeScript reference lanes. `nostr:nrelay...` is no longer emitted
  as a NIP-27 content reference, while malformed, uppercase, forbidden, and payload-empty fragments
  continue to fall back to plain text rather than failing the whole scan.
- Why: extracting `nrelay` created compatibility drift without improving trust-boundary safety, but
  the existing ignore-as-plain-text fallback already matches the deployed reference behavior for
  malformed or forbidden fragments.
- Tradeoff: slightly narrower inline extraction surface versus better ecosystem alignment and a
  clearer Layer 1 contract for text-reference parsing.
- Related Tradeoff: T-0-001, T-0-002, T-0-003.
- Reversal Trigger: future NIP text or strong ecosystem evidence establishes relay pointers as
  common and interoperable inline content references rather than separate URI/use-case surfaces.
- Supersedes: none

## D-044: Accept uppercase single-letter NIP-01 filter keys

- Date: 2026-03-11
- Status: accepted
- Decision: widen `nip01_filter` so strict filter parsing accepts uppercase single-letter `#X` tag
  keys in addition to lowercase ones. Matching remains exact to the tag byte present on the event,
  and the rest of the current NIP-01 filter/message strictness is unchanged.
- Why: NIP-01 explicitly allows `#<single-letter (a-zA-Z)>` filter keys, `rust-nostr` models
  uppercase single-letter tags directly, and `nostr-tools` matches uppercase `#X` filters as
  written. Rejecting uppercase keys was narrower than the protocol and ecosystem without improving
  safety or boundedness.
- Tradeoff: slightly broader tag-filter input surface versus materially better spec and ecosystem
  compatibility.
- Related Tradeoff: T-0-001, T-0-002, T-0-003.
- Reversal Trigger: strong interoperability evidence shows uppercase single-letter tag filters are
  harmful or ambiguous at the trust boundary despite their NIP-01 allowance.
- Supersedes: none

## D-045: Reject semantically invalid NIP-09 delete coordinates

- Date: 2026-03-11
- Status: accepted
- Decision: tighten `nip09_delete` so `a` delete targets must satisfy the NIP-01 coordinate rules
  for replaceable/addressable events, not merely the `<kind>:<pubkey>:<identifier>` string shape.
  Ephemeral kinds, replaceable kinds with a non-empty identifier, and addressable kinds without an
  identifier now fail as `InvalidAddressCoordinate`.
- Why: deletion requests should not accept coordinate forms that the protocol itself does not treat
  as valid event addresses, and allowing them created a correctness bug rather than useful
  compatibility.
- Tradeoff: stricter rejection of semantically invalid delete coordinates versus clearer and safer
  delete-target semantics.
- Related Tradeoff: T-0-001, T-0-003.
- Reversal Trigger: future NIP guidance or strong ecosystem evidence establishes broader delete
  coordinate semantics that remain unambiguous and safe.
- Supersedes: none

## D-046: Preserve the full `0..256` NIP-13 difficulty domain

- Date: 2026-03-11
- Status: accepted
- Decision: keep the current `nip13_pow` surface unchanged. `noztr` continues to count leading zero
  bits across the full `0..256` range and keeps `pow_meets_difficulty_verified_id` as the explicit
  checked-ID trust-boundary entry point.
- Why: NIP-13 defines difficulty as the number of leading zero bits in the 32-byte event id, which
  is naturally a `0..256` property. The Rust reference remains the active runtime parity lane for
  normal PoW behavior, but its standalone leading-zero helper is typed as `u8`. Narrowing `noztr`
  to match that helper type would lose a correct bounded edge case without improving compatibility
  or safety.
- Tradeoff: one documented Zig-native divergence from a reference helper type versus a more correct
  and fully bounded NIP-13 domain.
- Related Tradeoff: T-0-001, T-0-002, T-0-003.
- Reversal Trigger: future protocol guidance or strong ecosystem evidence establishes that the full
  `256`-bit edge should not be represented or checked as part of PoW difficulty semantics.
- Supersedes: none

## D-047: Accept empty-identifier `naddr` values for replaceable coordinates

- Date: 2026-03-11
- Status: accepted
- Decision: widen `nip19_bech32` so `naddr` encode/decode accepts an empty identifier in TLV type
  `0` when representing a normal replaceable coordinate.
- Why: NIP-19 explicitly says the `naddr` identifier uses an empty string for normal replaceable
  events. Both `rust-nostr` and `nostr-tools` roundtrip that shape. The prior `noztr` rejection was
  unnecessary incompatibility, not a useful trust-boundary safeguard.
- Tradeoff: slightly broader accepted `naddr` value surface versus materially better spec and
  ecosystem compatibility for replaceable coordinates.
- Related Tradeoff: T-0-001, T-0-002, T-0-003.
- Reversal Trigger: future NIP guidance removes empty-identifier replaceable coordinates or strong
  ecosystem evidence shows the widened shape is harmful or ambiguous.
- Supersedes: none

## D-048: Treat malformed NIP-40 expiration metadata as absent

- Date: 2026-03-11
- Status: accepted
- Decision: widen `nip40_expire` so malformed `expiration` tags no longer fail the helper path.
  The first valid expiration tag wins deterministically; malformed or conflicting later tags are
  ignored.
- Why: `expiration` is advisory optional metadata. `rust-nostr` and `nostr-tools` both treat
  malformed expiration data as effectively non-expiring rather than exceptional. The prior `noztr`
  typed-error path created unnecessary compatibility friction without improving safety.
- Tradeoff: broader tolerance for malformed optional expiration metadata versus fewer typed helper
  failures and materially better ecosystem alignment.
- Related Tradeoff: T-0-001, T-0-002, T-0-003.
- Reversal Trigger: future NIP guidance requires malformed expiration metadata to invalidate the
  event or strong ecosystem evidence shows first-valid expiration handling is harmful.
- Supersedes: none

## D-049: Ignore unrelated foreign tags during NIP-65 relay extraction

- Date: 2026-03-11
- Status: accepted
- Decision: widen `nip65_relays` so `relay_list_extract` ignores non-`r` tags on `kind:10002`
  events. Strict validation remains in force for actual `r` relay tags: malformed relay tag arity,
  malformed relay URLs, and invalid `read`/`write` markers still return typed failures.
- Why: NIP-65 defines relay metadata through `r` tags, but it does not require unrelated foreign
  tags to poison the whole extraction path. `rust-nostr` extracts only valid relay entries and
  tolerates surrounding non-relay tags. The prior `noztr` behavior created unnecessary
  incompatibility by rejecting the entire helper path for unrelated metadata that can be safely
  ignored without weakening the trust boundary for supported relay tags.
- Tradeoff: broader acceptance of mixed-tag relay-list events versus fewer helper-level failures on
  irrelevant surrounding metadata, while preserving strict validation for supported relay entries.
- Related Tradeoff: T-0-001, T-0-002, T-0-003.
- Reversal Trigger: future NIP guidance explicitly requires non-`r` tags on relay-list events to
  invalidate extraction or strong ecosystem evidence shows foreign-tag tolerance causes ambiguity or
  unsafe relay selection.
- Supersedes: none

## D-050: Treat malformed NIP-50 extension-like tokens as raw search text

- Date: 2026-03-11
- Status: accepted
- Decision: widen `nip50_search` so `search_field_validate` only enforces bounded UTF-8 shape, and
  `search_tokens_parse` performs best-effort extraction of supported `key:value` tokens. Malformed
  extension-like tokens such as `include:` or `language:en:us` are ignored instead of invalidating
  the helper path.
- Why: NIP-50 defines `search` as a human-readable query string and says unsupported extensions
  should be ignored. `rust-nostr` and `nostr-tools` both treat malformed extension-like search text
  as ordinary searchable text rather than invalid input. The prior `noztr` behavior created
  unnecessary incompatibility by turning best-effort extension parsing into a whole-query failure.
- Tradeoff: less typed rejection of malformed extension-like token syntax versus materially better
  compatibility with the protocol's best-effort search model and both reference lanes.
- Related Tradeoff: T-0-001, T-0-002, T-0-003.
- Reversal Trigger: future NIP guidance requires malformed extension-like tokens to invalidate the
  entire search query or strong ecosystem evidence shows best-effort parsing causes ambiguity or
  unsafe relay behavior.
- Supersedes: none

## D-051: Accept uppercase HLL hex and ignore unknown NIP-45 COUNT metadata keys

- Date: 2026-03-11
- Status: accepted
- Decision: widen `nip45_count` so COUNT relay parsing accepts uppercase hex digits in `hll` and
  ignores unknown metadata keys inside the COUNT response object instead of rejecting the whole
  response.
- Why: NIP-45 describes `hll` as hex-encoded without requiring lowercase, and COUNT response
  metadata is open enough that rejecting future unknown keys creates avoidable forward-compatibility
  friction. Both reference lanes are more tolerant than the prior strict parser shape.
- Tradeoff: slightly broader COUNT metadata acceptance versus materially better forward
  compatibility and fewer unnecessary relay-response failures.
- Related Tradeoff: T-0-001, T-0-002, T-0-003.
- Reversal Trigger: future NIP guidance explicitly requires lowercase-only HLL encoding or bans
  unknown COUNT metadata keys, or strong ecosystem evidence shows this tolerance causes ambiguity.
- Supersedes: none

## D-052: Relax NIP-77 NEG-ERR delimiter and allow bounded session reopen

- Date: 2026-03-11
- Status: accepted
- Decision: widen `nip77_negentropy` so `NEG-ERR` reasons accept the NIP-required `:` delimiter
  with optional following spaces, and `negentropy_state_apply` allows a new `NEG-OPEN` to reset a
  reused state object instead of requiring the state to remain idle forever after the first open.
- Why: NIP-77 says error reasons use a single-word prefix followed by `:` and then a human-readable
  message; it does not require `\": \"` specifically. The protocol also explicitly allows a new
  `NEG-OPEN` on an existing subscription flow by first closing the previous one. The prior `noztr`
  behavior added unnecessary compatibility friction without improving safety or boundedness.
- Tradeoff: slightly broader accepted NEG-ERR formatting and reopen sequencing versus better
  protocol compatibility and simpler reuse of the bounded state object.
- Related Tradeoff: T-0-001, T-0-002, T-0-003.
- Reversal Trigger: future NIP guidance requires `\": \"` specifically or forbids bounded state
  reuse for subsequent `NEG-OPEN` messages, or strong ecosystem evidence shows this tolerance is
  harmful.
- Supersedes: none

## D-053: Keep `nostrconnect_url` template rendering out of the NIP-46 kernel

- Date: 2026-03-11
- Status: accepted
- Decision: keep `nostrconnect_url` parsing and validation in `nip46_remote_signing`, but leave
  placeholder expansion or redirect/template rendering out of the module. `noztr` will not turn
  the NIP-46 helper into an application-flow or connection-orchestration surface.
- Why: replacing `<nostrconnect>` inside an HTTPS redirect template is not wire-format parsing; it
  is application-flow behavior that depends on UI, redirect policy, and handoff semantics outside
  the protocol kernel. The bounded kernel value is in validating the template field and exposing the
  parsed discovery data, not in deciding how an app launches or hands off a connection.
- Tradeoff: less turnkey convenience for client apps versus a cleaner kernel boundary, less
  overengineering, and lower risk of mixing app UX policy into Layer 1 helpers.
- Related Tradeoff: T-0-001, T-0-002, T-0-003.
- Reversal Trigger: repeated downstream application code shows a single obvious, protocol-grounded,
  low-policy rendering helper that materially improves interoperability without dragging UI or
  redirect semantics into the kernel.
- Supersedes: none

## D-054: Use an ASCII-only normalization boundary for Phase H NIP-06

- Date: 2026-03-11
- Status: superseded by `D-091`
- Decision: for the current Phase H NIP-06 boundary, accept ASCII-only mnemonic and passphrase
  input after UTF-8 validation and reject non-ASCII input with typed `InvalidNormalization`.
  Full BIP39-compatible NFKD normalization remains follow-up issue `no-09f`; the current boundary
  must not silently derive seeds from non-ASCII input that could disagree with spec-compliant
  wallets.
- Why: `libwally-core` does not normalize mnemonic or passphrase input, Zig stdlib does not provide
  a small built-in NFKD path, and silent acceptance of non-ASCII input would create hidden
  interoperability risk against BIP39- and rust-nostr-compatible derivation behavior. ASCII-only
  rejection is the smallest deterministic workaround that preserves an honest boundary.
- Tradeoff: temporary rejection of non-ASCII mnemonic/passphrase input versus avoiding silent
  cross-wallet seed mismatch while keeping the Phase H implementation narrow and reviewable.
- Related Tradeoff: T-H-ANIP-002, T-H-ANIP-003, T-0-001, T-0-003.
- Reversal Trigger: a bounded, test-backed NFKD implementation is accepted for the repo or the
  approved backend path gains spec-compliant normalization directly.
- Supersedes: none

## D-055: Keep full NIP-06 NFKD normalization out of the current kernel scope

- Date: 2026-03-11
- Status: superseded by `D-091`
- Decision: complete the `no-09f` review by keeping `D-054` as the current accepted NIP-06
  boundary and not implementing full in-repo Unicode NFKD normalization now. Track any future
  full BIP39-compatible Unicode normalization work in `no-2gp` instead of expanding the current
  kernel immediately.
- Why: `noztr` currently exposes an English-only mnemonic boundary, so the practical parity gain
  from full NFKD support is non-ASCII passphrase handling. The current ASCII-only rejection already
  avoids silent cross-wallet seed mismatch. A direct in-repo normalization port would require a
  substantial generated Unicode data surface, roughly `625 KB` from the upstream Rust reference
  tables, or a new dependency-policy exception beyond the current approved crypto backend model.
- Tradeoff: non-ASCII passphrases remain unsupported for now versus avoiding a large Unicode
  subsystem or a new non-crypto dependency exception in the protocol kernel.
- Related Tradeoff: T-H-ANIP-002, T-H-ANIP-003, T-0-001, T-0-003.
- Reversal Trigger: clear integrator demand or interoperability evidence makes non-ASCII
  passphrase support worth the additional code/data or dependency-policy cost.
- Supersedes: none

## D-056: Implement NIP-51 private lists with an NIP-44-first boundary

- Date: 2026-03-11
- Status: accepted
- Decision: complete `no-e7b` by adding bounded NIP-51 private-list helpers for JSON plaintext
  serialization, private-item extraction from decrypted JSON, and direct NIP-44 decrypt+extract
  support in `src/nip51_lists.zig`. Treat deprecated NIP-04 ciphertext discovery as unsupported in
  the current kernel and track any compatibility adapter work separately in `no-urr`.
- Why: `noztr` already has an audited NIP-44 boundary in `src/nip44.zig`, while NIP-04 remains
  deferred and intentionally absent from the current kernel. Supporting NIP-44 private list content
  now materially improves NIP-51 completeness without reopening deprecated DM crypto scope or
  broadening the issue into a second encryption subsystem.
- Tradeoff: modern private-list interoperability for current NIP-51 producers versus rejecting
  legacy `?iv=` payloads until a narrow compatibility adapter is explicitly accepted.
- Related Tradeoff: T-H-ANIP-001, T-H-ANIP-003, T-0-001, T-0-003.
- Reversal Trigger: concrete ecosystem evidence shows that NIP-04 private-list compatibility is
  still common enough to justify a bounded adapter in the kernel.
- Supersedes: none

## D-057: Accept legacy NIP-46 `metadata=` client URIs as parse-only compatibility input

- Date: 2026-03-12
- Status: accepted
- Decision: during the NIP-46 robustness pass, accept the older `nostrconnect://...?...&metadata={}`
  client-URI shape emitted by `rust-nostr` as an input-only compatibility path. Parse `name`,
  `url`, and first `icons[]` entry out of legacy metadata JSON, but keep `noztr` serialization on
  the current split-query form (`name`, `url`, `image`, `perms`) and let explicit split fields win
  when both shapes are present.
- Why: the current spec and `nostr-tools` use split query parameters, but a strong deployed Rust
  reference still emits `metadata={...}`. Accepting that older input improves real-world
  interoperability without weakening trust boundaries or reintroducing app-flow policy into the
  kernel.
- Tradeoff: one bounded compatibility parse path versus slightly more URI parsing complexity.
- Related Tradeoff: T-H-ANIP-001, T-0-001, T-0-003.
- Reversal Trigger: the broader ecosystem fully converges on the current split-query shape and the
  compatibility path no longer provides practical value.
- Supersedes: none

## D-058: Keep Phase H NIP-24 bounded to metadata extras plus generic `r` / `title` / `t`

- Date: 2026-03-12
- Status: accepted
- Decision: complete `no-hu1` by implementing `src/nip24_extra_metadata.zig` as a bounded helper
  surface for kind-`0` metadata extras (`display_name`, `website`, `banner`, `bot`, `birthday`)
  plus the generic `r`, `title`, and `t` tag meanings. Defer `i` tag extraction/building to a
  follow-up NIP-73 helper issue (`no-fah`) instead of inventing an ad hoc parser inside the NIP-24
  module.
- Why: the metadata extras and generic tags provide the low-ambiguity, high-utility part of NIP-24
  that fits the current kernel posture. The `i` tag grammar belongs to NIP-73, so partially
  re-creating it inside NIP-24 would widen scope and duplicate protocol ownership in the wrong
  module.
- Tradeoff: immediate coverage for the common kind-`0` and generic tag helpers versus leaving one
  NIP-24 tag family deferred until the NIP-73 boundary exists.
- Related Tradeoff: T-H-ANIP-001, T-H-ANIP-003, T-0-001, T-0-003.
- Reversal Trigger: NIP-73 helpers are accepted into current scope or ecosystem evidence shows the
  `i` tag must be handled sooner with a bounded shared parser.
- Supersedes: none

## D-059: Keep Phase H NIP-03 at a bounded attestation-event boundary

- Date: 2026-03-12
- Status: accepted
- Decision: complete `no-wo7` by implementing `src/nip03_opentimestamps.zig` as a strict
  kind-`1040` attestation boundary with exact `e`/`k` target tags, caller-buffer base64 proof
  decoding, and target-reference validation against a supplied event. Do not claim full
  OpenTimestamps / Bitcoin attestation verification in the current kernel.
- Why: `rust-nostr` only gives local builder-level evidence for NIP-03 and relies on a dedicated
  `nostr-ots` dependency for deeper proof generation. Bringing a full OpenTimestamps verifier into
  `noztr` now would widen dependency and format-parser scope well beyond the narrow helper posture
  of the remaining deferred Phase H items.
- Tradeoff: immediate deterministic attestation event handling and proof-shape validation versus
  leaving deeper OTS attestation semantics as future work.
- Related Tradeoff: T-H-ANIP-001, T-H-ANIP-003, T-0-001, T-0-003.
- Reversal Trigger: a bounded OpenTimestamps parser/verification subsystem is accepted into scope or
  ecosystem evidence shows the current attestation boundary is too shallow for practical use.
- Supersedes: none

## D-060: Keep Phase H NIP-17 bounded to kind-14 message helpers plus kind-10050 relay lists

- Date: 2026-03-12
- Status: accepted
- Decision: complete `no-0jq` by implementing `src/nip17_private_messages.zig` only as a bounded
  helper layer for kind-`14` rumor/message parsing, gift-wrap unwrap plus inner kind-`14` parse,
  kind-`10050` relay-list extraction, and direct `p`/`relay` tag builders. Defer kind-`15`
  file-message handling to follow-up issue `no-nv9`.
- Why: this captures the low-ambiguity, production-useful part of NIP-17 while reusing the already
  accepted `NIP-44` and `NIP-59` trust boundaries. It avoids turning the kernel into a chat SDK or
  file-transfer orchestration layer.
- Tradeoff: immediate deterministic private-message and inbox-relay helpers versus leaving
  file-message support for a later bounded pass.
- Related Tradeoff: T-H-ANIP-001, T-H-ANIP-003, T-0-001, T-0-003.
- Reversal Trigger: kind-`15` becomes necessary for current scope or current `NIP-17`
  interoperability evidence shows the bounded kind-`14`/`10050` split is insufficient.
- Supersedes: none

## D-061: Keep Phase H NIP-39 bounded to claim parsing plus deterministic proof material

- Date: 2026-03-12
- Status: accepted
- Decision: complete `no-g5j` by implementing `src/nip39_external_identities.zig` as a bounded
  helper surface for kind-`10011` identity-claim extraction, canonical `i` tag building,
  provider-specific proof-URL derivation, and expected proof-text generation. Overlong identity
  and proof inputs must fail on typed `InvalidIdentity` / `InvalidProof` paths rather than leaking
  `BufferTooSmall` through the builder surface. Do not perform provider network fetch verification
  inside the kernel.
- Why: this captures the deterministic protocol value of NIP-39 while keeping network fetches,
  provider trust policy, and external API behavior out of the core library. It also keeps the
  boundary compatible with the current KISS posture instead of embedding partial web clients into
  the kernel.
- Tradeoff: immediate typed claim/proof-material helpers versus leaving live provider verification
  for an opt-in adapter layer.
- Related Tradeoff: T-H-ANIP-001, T-H-ANIP-003, T-0-001, T-0-003.
- Reversal Trigger: provider verification becomes required for current scope and a bounded
  non-kernel adapter model is insufficient.
- Supersedes: none

## D-062: Keep Phase H NIP-29 bounded to relay-generated group event helpers

- Date: 2026-03-12
- Status: accepted
- Decision: complete `no-j2g` by implementing `src/nip29_relay_groups.zig` only for the
  relay-generated group events:
  - kind-`39000` metadata extraction/building
  - kind-`39001` admin extraction/building
  - kind-`39002` member extraction/building
  - compatibility parsing for deployed `nostr-tools` metadata/member shapes where it is bounded and
    unambiguous
  Do not add group loading, relay fetch/subscription logic, moderation-event orchestration, or
  evolving group-state machinery to the kernel.
- Why: this captures the deterministic event-boundary value of NIP-29 without turning `noztr` into
  a relay client or group-state engine. It also preserves compatibility with the main deployed TS
  helper lane where that compatibility does not compromise the raw event contract.
- Tradeoff: immediate useful event helpers for the relay-generated group state versus leaving
  broader group orchestration and moderation surfaces for later evaluation.
- Related Tradeoff: T-H-ANIP-001, T-H-ANIP-003, T-0-001, T-0-003.
- Reversal Trigger: future evidence shows that group reference/moderation helpers are required for
  current scope and can be added without violating the bounded kernel posture.
- Supersedes: none

## D-063: Extend Phase H NIP-17 to a bounded kind-15 file-message boundary

- Date: 2026-03-12
- Status: accepted
- Decision: close `no-nv9` by extending `src/nip17_private_messages.zig` with a bounded kind-`15`
  file-message helper surface that includes:
  - required recipient `p` tag handling shared with kind-`14`
  - optional reply `e` and `subject` handling shared with kind-`14`
  - required file metadata tags `file-type`, `encryption-algorithm`, `decryption-key`,
    `decryption-nonce`, and `x`
  - bounded optional `ox`, `size`, `dim`, `blurhash`, repeated `thumb`, and repeated `fallback`
  - direct `NIP-59` unwrap plus inner kind-`15` parse helper
  Do not add file-transfer orchestration, send/publish workflow helpers, or alternate metadata
  alias grammars in the kernel.
- Why: this captures the deterministic event-boundary value of kind-`15` while keeping the module
  aligned with the existing bounded `kind-14`/`NIP-59` posture. The reference lanes do not expose a
  stronger dedicated kind-`15` helper contract, so the right kernel move is a narrow parse/unwrap
  boundary instead of a workflow API.
- Tradeoff: immediate typed file-message handling and unwrap symmetry versus leaving richer file
  send/build orchestration and compatibility aliases for higher layers or future follow-ups.
- Related Tradeoff: T-H-ANIP-001, T-H-ANIP-003, T-0-001, T-0-003.
- Reversal Trigger: ecosystem evidence shows the current strict file-metadata grammar is too narrow
  for real deployed interoperability or a stronger bounded builder surface becomes necessary for
  current scope.
- Supersedes: D-060

## D-064: Keep deeper NIP-03 OpenTimestamps and Bitcoin verification out of the kernel

- Date: 2026-03-12
- Status: accepted
- Decision: close `no-y0i` by keeping deeper OpenTimestamps proof verification and Bitcoin
  attestation verification out of the current kernel scope. `src/nip03_opentimestamps.zig` remains
  the bounded event-layer helper for kind-`1040`, exact target tags, and caller-buffer proof
  decoding only.
- Why: this preserves the accepted bounded attestation-event posture from `D-059` and avoids
  pulling a larger proof-parser / chain-verification subsystem into Layer 1 without strong
  cross-reference evidence that it belongs there.
- Tradeoff: explicit event-boundary handling without end-to-end attestation verification versus
  leaving deeper proof verification to a higher layer or future scoped work.
- Related Tradeoff: T-H-ANIP-001, T-H-ANIP-003, T-0-001, T-0-003.
- Reversal Trigger: operator scope changes or ecosystem evidence show that bounded deeper proof
  verification is required inside the kernel and can be added without violating the current
  posture.
- Supersedes: D-059

## D-065: Keep live NIP-39 provider verification outside the kernel

- Date: 2026-03-12
- Status: accepted
- Decision: close `no-t9x` by keeping live provider fetch verification for NIP-39 outside the
  kernel. `src/nip39_external_identities.zig` remains limited to claim extraction, canonical tag
  building, deterministic proof-URL derivation, and expected-proof-text generation.
- Why: network fetches, provider trust policy, and remote availability handling are not core
  protocol-kernel concerns. The accepted value of the current NIP-39 surface is deterministic proof
  material, not embedded web verification clients.
- Tradeoff: simpler deterministic kernel boundary versus leaving provider verification to an opt-in
  higher layer.
- Related Tradeoff: T-H-ANIP-001, T-H-ANIP-003, T-0-001, T-0-003.
- Reversal Trigger: current scope explicitly requires in-library provider verification and a
  bounded non-kernel adapter model is shown to be insufficient.
- Supersedes: D-061

## D-066: Extend Phase H NIP-29 to bounded references, roles, and user-event helpers

- Date: 2026-03-12
- Status: accepted
- Decision: close `no-ebj` by extending `src/nip29_relay_groups.zig` with the smallest coherent
  kernel-safe expansion beyond relay-generated metadata/admin/member events:
  - raw `<host>'<group-id>` group-reference parse/build
  - kind-`39003` role extraction/building
  - kind-`9021` and kind-`9022` bounded join/leave extraction
  - kind-`9000` and kind-`9001` bounded put/remove-user extraction
  - raw `previous` tag parse/build helpers
  Do not add relay fetch/subscription logic, derived membership-state helpers, random previous-tag
  selection policy, or broader moderation orchestration.
- Why: this captures the deterministic event-local value that local reference implementations
  actually support without turning `noztr` into a relay client or group-state engine. It also keeps
  the surface aligned with the KISS posture by treating `previous` as raw tag plumbing only.
- Tradeoff: useful bounded group-reference and user-event helpers versus leaving higher-level group
  workflows and stateful policy outside the kernel.
- Related Tradeoff: T-H-ANIP-001, T-H-ANIP-003, T-0-001, T-0-003.
- Reversal Trigger: operator scope expands to require stateful group orchestration or ecosystem
  evidence shows the current bounded surface is insufficient for interoperable group tooling.
- Supersedes: D-062

## Phase Closure Evidence

### P0-E-001: Phase 0 closure record

- Phase: 0
- Closure Date: 2026-03-05
- Gate Result: pass
- Ambiguity Snapshot: `A-0-001` accepted-risk, `A-0-002` resolved, `A-0-003`
  resolved.
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

### PA-E-001: Phase A closure record

- Phase: A
- Closure Date: 2026-03-05
- Gate Result: pass
- Ambiguity Snapshot: `A-A-001` resolved, `A-A-002` resolved, `A-A-003` resolved.
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

### PB-E-001: Phase B closure record

- Phase: B
- Closure Date: 2026-03-05
- Gate Result: pass
- Ambiguity Snapshot: `A-B-001` resolved, `A-B-002` resolved, `A-B-003` resolved, `A-B-004`
  resolved, `A-B-005` resolved, `A-B-006` resolved, `A-B-007` resolved, `A-B-008` resolved,
  `A-B-009` resolved, `A-B-010` resolved, `A-B-011` resolved.
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

### PC1-E-001: Phase C1 closure record

- Phase: C1
- Closure Date: 2026-03-05
- Gate Result: pass
- Ambiguity Snapshot: `A-C1-001` resolved, `A-C1-002` resolved, `A-C1-003` accepted-risk.
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

### PC2-E-001: Phase C2 closure record

- Phase: C2
- Closure Date: 2026-03-05
- Gate Result: pass
- Ambiguity Snapshot: `A-C2-001` resolved, `A-C2-002` resolved, `A-C2-003` accepted-risk.
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

### PC3-E-001: Phase C3 closure record

- Phase: C3
- Closure Date: 2026-03-05
- Gate Result: pass
- Ambiguity Snapshot: `A-C3-001` resolved, `A-C3-002` resolved, `A-C3-003` accepted-risk.
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

### PC0-E-001: Phase C0 closure record

- Phase: C0
- Closure Date: 2026-03-05
- Gate Result: pass
- Ambiguity Snapshot: `A-C0-001` accepted-risk, `A-C0-002` accepted-risk, `A-C0-003` resolved.
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

### PC4-E-001: Phase C4 closure record

- Phase: C4
- Closure Date: 2026-03-05
- Gate Result: pass
- Ambiguity Snapshot: `A-C4-001` accepted-risk, `A-C4-002` accepted-risk, `A-C4-003` resolved.
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

### PD-E-001: Phase D closure record

- Phase: D
- Closure Date: 2026-03-05
- Gate Result: pass
- Ambiguity Snapshot: `A-D-001` accepted-risk, `A-D-002` accepted-risk, `A-D-003` resolved.
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

### PE-E-001: Phase E closure record

- Phase: E
- Closure Date: 2026-03-05
- Gate Result: pass
- Ambiguity Snapshot: `A-E-001` accepted-risk, `A-E-002` accepted-risk, `A-E-003` accepted-risk.
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

### PF-E-001: Phase F closure record

- Phase: F
- Closure Date: 2026-03-05
- Gate Result: pass
- Ambiguity Snapshot: `A-F-001` accepted-risk, `A-F-002` accepted-risk, `A-F-003` resolved.
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

### PI7-E-001: Implementation phase I7 closure record

- Phase: I7
- Closure Date: 2026-03-08
- Gate Result: pass
- Ambiguity Snapshot: carry-forward accepted risks only (`UT-E-001`, `UT-E-002`, `UT-E-003`,
  `UT-E-004`, `A-D-001`).
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

### PG-E-001: Phase G local-only closure record

- Phase: G
- Closure Date: 2026-03-10
- Gate Result: pass (local-only closure)
- Ambiguity Snapshot: carry-forward only (`OQ-E-006` in progress for RC freeze; `no-3uj` remote
  readiness deferred-by-operator and outside closure scope).
- Decision-Needed Count (High Impact): 0
- Owner: active phase owner

## D-067: Accept bounded deployed NIP-29 compatibility shapes for group `h` and admin `p` tags

- Date: 2026-03-12
- Status: accepted
- Decision: widen the NIP-29 kernel just enough to accept two deployed compatibility shapes during
  extraction:
  - user and moderation `h` tags may carry an optional third-slot relay hint when it is URL-shaped
  - group-admin `p` tags may carry an optional third-slot compatibility label before permissions,
    and that slot is treated as label metadata rather than as a role
  Keep canonical `h` builders unchanged: emitted `h` tags remain two-item tags unless a caller
  explicitly wants the broader deployed relay-hint form. Allow bounded admin-tag builders to emit
  the optional compatibility label when a caller supplies one. Do not turn the reducer or the core
  group-state model into a label-aware policy surface.
- Why: deployed ecosystem helpers, especially `nostr-tools` and applesauce, use these shapes, and
  the old parser was stricter than necessary in ways that created avoidable compatibility friction
  without improving safety or determinism.
- Tradeoff: slightly broader accepted inbound shape versus a small increase in parser surface; this
  remains bounded because the third `h` slot must still be URL-shaped, admin labels stay optional,
  and reducer state still tracks only pubkeys plus roles.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: the deployed ecosystem converges on a narrower canonical group-tag/admin-tag
  shape or these compatibility slots begin causing ambiguous or unsafe behavior in practice.
- Supersedes: none

## D-068: Refine the NIP-46 kernel boundary to allow deterministic template substitution

- Date: 2026-03-12
- Status: accepted
- Decision: keep NIP-46 relay/session orchestration, redirect handling, and end-user connection
  flow outside the kernel, but allow deterministic `nostrconnect_url` template substitution inside
  the kernel. `src/nip46_remote_signing.zig` may expose a bounded helper that replaces the exact
  `<nostrconnect>` placeholder with a validated `nostrconnect://...` URI string, while leaving
  launching, redirects, and relay/session control to higher layers.
- Why: the NIP-46 appendix explicitly defines this placeholder replacement as protocol-facing data
  published by signers. Treating the substitution itself as app-flow was too absolute; the actual
  app-flow boundary is what happens after the URL is constructed.
- Tradeoff: a slightly wider deterministic helper surface versus clearer spec completeness and less
  duplicated template handling in downstream callers.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: template substitution proves to require environment-specific redirect policy or
  other non-deterministic behavior after all.
- Supersedes: D-053

## D-069: Keep NIP-24 generic `i` tags owned by NIP-73 and prioritize NIP-73 support

- Date: 2026-03-12
- Status: accepted
- Decision: keep the decision that generic `i` tag grammar should not be reimplemented ad hoc
  inside `src/nip24_extra_metadata.zig`, but tighten the rationale: this is not a broad
  out-of-scope exclusion, it is a dependency/ownership decision. If we want fuller rust-nostr-like
  functionality for NIP-24/NIP-39 adjacent external identifiers, the right change is to implement a
  bounded NIP-73 helper and then wire NIP-24 generic `i` handling through it.
- Why: `24.md` explicitly points `i` tags at NIP-73, and rust-nostr also centralizes external-id
  handling there. The gap is missing NIP-73 support, not that the kernel should permanently ignore
  generic `i` tags.
- Tradeoff: a delayed but cleaner generic `i` implementation versus a faster ad hoc parser in the
  wrong module.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: current scope explicitly rejects NIP-73 but still requires generic `i` support
  in `NIP-24`, forcing a local fallback grammar.
- Supersedes: D-058

## D-070: Refine NIP-03 scope to include bounded local proof verification but not networked chain verification

- Date: 2026-03-12
- Status: accepted
- Decision: reopen the NIP-03 boundary partially. Keep networked Bitcoin/esplora verification and
  full external proof-engine orchestration outside the kernel, but allow a bounded local
  verification floor inside `src/nip03_opentimestamps.zig`:
  - parse the decoded proof structure far enough to verify that it commits to the referenced event
    id digest
  - verify the presence of at least one Bitcoin attestation in the proof
  - keep deterministic caller-buffer operation and typed failures
  Do not turn the kernel into a networked attestation verifier.
- Why: the old boundary only validated tags and base64 shape, which is too thin for a NIP whose
  core claim is that the proof attests to an event in Bitcoin. A bounded local verification floor
  improves correctness materially without requiring network clients in Layer 1.
- Tradeoff: more parser complexity versus a more functionally complete NIP-03 helper that still
  avoids network-coupled behavior.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: bounded local proof verification proves too large or too unstable to keep KISS
  and static-bound requirements.
- Supersedes: D-064

## D-071: Keep live NIP-39 provider verification outside the kernel

- Date: 2026-03-12
- Status: accepted
- Decision: keep live provider fetch verification for NIP-39 outside the kernel. The accepted
  kernel surface remains claim extraction, canonical tag building, deterministic proof-URL
  derivation, and expected-proof-text generation.
- Why: provider fetches, remote availability, content parsing, trust policy, and rate limiting are
  adapter/client concerns rather than deterministic protocol-kernel behavior, and rust-nostr does
  not provide a stronger in-kernel reference surface here either.
- Tradeoff: simpler deterministic kernel boundary versus leaving live verification to an opt-in
  higher layer.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: current scope explicitly requires in-library provider verification and a
  bounded adapter model is shown to be insufficient.
- Supersedes: D-065

## D-072: Refine NIP-29 scope to allow pure fixed-capacity state reduction but not relay orchestration

- Date: 2026-03-12
- Status: accepted
- Decision: reopen the NIP-29 boundary partially. Keep relay fetch/subscription logic, relay
  authority checks, random `previous` selection policy, and broader moderation/orchestration
  outside the kernel, but allow a pure fixed-capacity reducer over caller-supplied NIP-29 events if
  we need fuller functional parity later. That reducer may reconstruct bounded group state from a
  supplied canonical sequence without performing any network or storage orchestration.
- Why: `29.md` explicitly says group state should be reconstructable from the canonical event
  sequence. Treating all state reconstruction as out of scope was too absolute. The real boundary is
  networked relay/client orchestration, not pure event reduction.
- Tradeoff: more protocol logic inside the kernel versus a more functionally complete and still
  deterministic group helper surface.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: a fixed-capacity reducer proves too coupled to relay policy or too complex to
  preserve KISS and boundedness.
- Supersedes: D-066

## D-073: Keep a canonical `noztr` vs SDK ownership matrix for kernel-boundary decisions

- Date: 2026-03-12
- Status: accepted
- Decision: adopt `docs/plans/noztr-sdk-ownership-matrix.md` as the canonical operational guide for
  deciding whether new functionality belongs in the `noztr` protocol kernel or the future SDK. Use
  it during NIP implementation, review, and decision-hygiene passes together with the decision log.
- Why: the project now has enough implemented surface that scope drift can happen in both
  directions: pushing orchestration into `noztr` or keeping deterministic protocol glue out of it.
  A small explicit ownership map helps keep future reviews and SDK work consistent without
  reopening the same boundary argument every time.
- Tradeoff: one more targeted planning artifact versus less repeated scope ambiguity and less
  accidental doc drift across NIP reviews.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: the matrix becomes redundant with a future SDK repo's own canonical boundary
  docs or proves too stale to maintain.
- Supersedes: none

## D-074: Implement bounded NIP-73 external-id helpers and wire NIP-24 through them

- Date: 2026-03-12
- Status: accepted
- Decision: implement `src/nip73_external_ids.zig` as the reusable external-id boundary for
  protocol-facing `i`/`k` external content handling, and wire `src/nip24_extra_metadata.zig`
  generic `i` extraction through it instead of keeping that support deferred. Reuse the same
  matcher for NIP-22 external target consistency checks.
- Why: `D-069` already established that generic `i` support should arrive through a proper NIP-73
  helper rather than an ad hoc local parser. Landing the shared module now improves completeness and
  keeps external-id logic in one bounded place.
- Tradeoff: a slightly broader kernel surface versus cleaner ownership, less duplicated parser
  logic, and less drift across NIP-22 / NIP-24 / later external-id surfaces.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: the bounded helper proves insufficient and forces per-NIP grammars anyway.
- Supersedes: none

## D-075: Implement bounded local NIP-03 proof verification floor

- Date: 2026-03-13
- Status: accepted
- Decision: implement the bounded local NIP-03 proof-verification floor in the kernel. The
  accepted floor validates the detached OpenTimestamps header magic, major version `1`, root
  `sha256` digest op, exact target event-id digest match, iterative timestamp-tree structure with
  known op tags, and at least one Bitcoin attestation. Pending attestations are tolerated when the
  proof still carries a valid Bitcoin attestation. Networked Bitcoin/esplora verification and live
  block-header fetching remain outside the kernel.
- Why: this closes the largest functional gap in the NIP-03 helper without pulling relay/network
  policy or blockchain I/O into `noztr`.
- Tradeoff: more local parser complexity versus a meaningfully more functional and still bounded
  attestation helper surface.
- Related Tradeoff: T-H-ANIP-010.
- Reversal Trigger: the accepted local floor proves too brittle, too large for KISS, or ecosystem
  evidence requires materially broader local proof semantics.
- Supersedes: none

## D-076: Keep two borderline deterministic helpers in the kernel pending SDK work

- Date: 2026-03-13
- Status: accepted
- Decision: after a dedicated kernel-boundary review, keep these currently implemented helpers in
  `noztr` for now:
  - `src/nip39_external_identities.zig`
    - `identity_claim_build_proof_url(...)`
    - `identity_claim_build_expected_text(...)`
  - `src/nip46_remote_signing.zig`
    - `discovery_render_nostrconnect_url(...)`
- Why: they are still pure, deterministic, bounded, and reusable across multiple callers, so they
  do not yet justify churn just before SDK work starts. At the same time, they are the clearest
  current examples of helper glue that is close to SDK/provider concerns, so they should stay
  explicitly marked as borderline rather than silently canonicalized as permanent kernel scope.
- Tradeoff: preserve current ergonomics and avoid premature movement versus accepting a small amount
  of provider- or handoff-adjacent glue in the kernel for now.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: `nzdk` grows stable provider adapters or NIP-46 connection-handoff helpers that
  make these kernel helpers redundant or better-scoped in the SDK.
- Supersedes: none

## D-077: Map the next requested NIP set across `noztr` and `nzdk` before implementation

- Date: 2026-03-13
- Status: accepted
- Decision: use the ownership matrix as the canonical pre-implementation split for the next
  requested NIP set:
  - kernel-first in `noztr`: `32`, `36`, `56`, `05`, `26`, `37`, `58`, `84`
  - split between `noztr` and `nzdk`: `57`, `86`
  - SDK-first in `nzdk`: `07`, `60`, `61`, `B7`
- Why: this keeps protocol-facing bounded helpers in the kernel while avoiding browser, wallet,
  payment, and service-integration workflow from leaking into `noztr` just before SDK work starts.
- Tradeoff: slower “implement everything in one repo” momentum versus a cleaner long-term kernel /
  SDK split and fewer future reversals.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: protocol evidence or product scope changes show that one of the SDK-first items
  needs a smaller bounded kernel slice earlier than planned.
- Supersedes: none

## D-078: Implement bounded NIP-05 identity helpers in the kernel

- Date: 2026-03-13
- Status: accepted
- Decision: implement `src/nip05_identity.zig` as the bounded kernel surface for NIP-05 address
  parsing, canonical well-known URL composition, raw `nostr.json` verification, and bounded
  optional `relays` / `nip46` extraction keyed by the matched public key. Keep HTTP fetch, redirect
  handling, caching, and higher-level trust UX in the future SDK.
- Why: this is deterministic protocol glue that many SDK surfaces will reuse, and it materially
  improves kernel completeness for both relay and client work without pulling in network workflow.
- Tradeoff: a slightly broader kernel helper surface versus cleaner SDK layering and less repeated
  NIP-05 parser/verification logic.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: the helper proves to require network/policy assumptions that cannot stay pure
  and bounded.
- Supersedes: none

## D-079: Implement bounded NIP-26 delegation helpers as a spec-first kernel module

- Date: 2026-03-13
- Status: accepted
- Decision: implement `src/nip26_delegation.zig` as the bounded kernel surface for exact
  `delegation` tag parse/build, fixed-capacity condition parse/format, exact delegation message
  construction, deterministic Schnorr sign/verify, and pure event-condition validation. Keep relay
  author-query expansion, delegation issuance UX, and key-custody workflow in the future SDK.
- Why: the NIP-26 protocol surface is small, deterministic, and directly reusable across relay and
  client code even though the active Rust and TypeScript reference lanes do not expose a dedicated
  helper surface. The right comparison posture here is spec-first plus source review, not waiting
  for higher-level library convenience APIs.
- Tradeoff: a slightly more crypto-adjacent kernel module versus a cleaner relay/client base and
  less need for ad hoc delegation parsing in the future SDK.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: real ecosystem evidence shows that the accepted exact tag or lower-hex rules are
  materially too narrow for interoperability, or the module proves to require orchestration logic to
  remain useful.
- Supersedes: none

## D-080: Implement bounded NIP-37 draft-wrap and private relay-list helpers

- Date: 2026-03-13
- Status: accepted
- Decision: implement `src/nip37_drafts.zig` as the bounded kernel surface for kind-`31234`
  draft-wrap metadata parsing, validated draft JSON NIP-44 encrypt/decrypt helpers, direct
  `d`/`k`/`expiration` tag builders, kind-`10013` private relay-tag builders, private relay-list
  JSON serialization/extraction, and NIP-44 private relay-list extraction. Keep draft sync, editor
  workflow, local storage, publish/delete workflow, and relay-selection policy in the future SDK.
- Why: both NIP-37 surfaces are deterministic protocol glue built on top of already-implemented
  NIP-44 helpers, and multiple future SDK/client flows will need the same strict metadata and
  private relay-list handling without wanting to re-implement the encrypted-content boundary.
- Tradeoff: a broader private-content helper surface in the kernel versus cleaner SDK layering and
  less repeated draft/private-relay parsing logic later.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: real-world draft or private-relay payload evidence shows that the accepted exact
  `d`/`k`/relay-tag rules are materially too narrow, or the module proves to require stateful draft
  workflow to stay useful.
- Supersedes: none

## D-081: Implement bounded NIP-58 badge helpers in the kernel

- Date: 2026-03-13
- Status: accepted
- Decision: implement `src/nip58_badges.zig` as the bounded kernel surface for kind-`30009` badge
  definition parsing/building, kind-`8` badge award parsing/building, kind-`30008` profile-badge
  pair extraction, and pure cross-event consistency validation. Keep badge presentation, profile
  ordering policy, sync, and UX workflow in the future SDK.
- Why: NIP-58 badge definitions, awards, and profile-badge references are deterministic protocol
  glue that multiple clients will need to parse or compose consistently. The kernel can provide the
  tag-level contract and pair validation without becoming a badge UX layer.
- Tradeoff: a slightly broader content-helper surface in the kernel versus cleaner SDK layering and
  less repeated badge-tag parsing later.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: real-world badge events show that the accepted exact `d` / `a` / `e` /
  recipient handling is materially too narrow, or the helper proves to require presentation or sync
  policy to remain useful.
- Supersedes: none

## D-082: Implement bounded NIP-84 highlight helpers in the kernel

- Date: 2026-03-13
- Status: accepted
- Decision: implement `src/nip84_highlights.zig` as the bounded kernel surface for kind-`9802`
  highlight source extraction/building (`e`, `a`, `r`), bounded `p` attribution parsing/building,
  bounded URL-reference parsing/building, and optional `context` / `comment` parsing/building.
  Keep highlight rendering, article-reader UX, quote composition flow, and presentation policy in
  the future SDK.
- Why: NIP-84 is deterministic tag-level protocol glue and is useful to both relays and clients
  without requiring reader workflow or rendering policy to live in the kernel. A spec-first helper
  is appropriate here because neither active reference lane exposes a dedicated NIP-84 helper.
- Tradeoff: a slightly broader content-helper surface in the kernel versus cleaner SDK layering and
  less repeated source/attribution parsing later.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: real-world highlight traffic shows that the accepted exact source or
  attribution rules are materially too narrow, or the helper proves to require reader workflow to
  remain useful.
- Supersedes: none

## D-083: Tighten recent kernel-first helpers after the first post-implementation audit pass

- Date: 2026-03-13
- Status: accepted
- Decision: keep `NIP-37`, `NIP-58`, and `NIP-84` in-kernel, but refine their contracts after the
  first focused audit:
  - `NIP-37` now enforces a stronger minimum draft-event shape (`kind`, `tags`, `content`) before
    encrypting or accepting decrypted draft JSON
  - `NIP-58` now treats profile-badge `a`/`e` pairs as truly consecutive and ignores unmatched
    definitions when unrelated tags intervene
  - `NIP-84` now accepts the deployed three-item `p` shape where the third slot is a role rather
    than a relay URL, aligning the parser with the module’s own builder and the NIP’s “role as last
    value” wording
- Why: the first audit found one real builder/parser mismatch, one real spec mismatch, and one
  under-enforced validation floor. Tightening those now improves correctness and interoperability
  without widening the kernel into SDK territory.
- Tradeoff: slightly broader acceptance for valid highlight attribution tags and slightly stricter
  validation for draft JSON/profile-badge ordering.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: real traffic shows that the accepted three-item highlight `p` role form is
  still insufficient, or the tightened draft/profile-badge validation floor creates unjustified
  ecosystem incompatibility.
- Supersedes: none

## D-084: Canonicalize uppercase NIP-05 local-parts without widening the identifier grammar

- Date: 2026-03-13
- Status: accepted
- Decision: widen `src/nip05_identity.zig` so NIP-05 address parsing accepts uppercase ASCII in the
  local-part, canonicalizes it to lowercase for storage/lookup/output, and leaves the rest of the
  identifier grammar unchanged. `+`, whitespace, percent-encoding, and other unsupported local-part
  characters remain rejected.
- Why: the NIP constrains the allowed local-part characters but does not justify rejecting
  uppercase-only variants as a compatibility boundary. Deployed library behavior is broader on
  casing, and accepting then canonicalizing uppercase improves interoperability without making the
  grammar fuzzy or undermining deterministic well-known URL composition.
- Tradeoff: slightly broader input acceptance versus a narrower literal interpretation of the
  `a-z0-9-_.` character set.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: strong standards-backed evidence shows uppercase local-parts must remain
  rejected for interoperability or security reasons.
- Supersedes: none

## D-085: Enforce lowercase hashtag semantics across the kernel-first metadata helpers

- Date: 2026-03-13
- Status: accepted
- Decision: tighten `src/nip23_long_form.zig`, `src/nip24_extra_metadata.zig`, and
  `src/nip32_labeling.zig` so their `t`-tag helpers reject uppercase hashtags during extraction and
  building. The accepted surface remains lowercase-only for long-form topics, generic NIP-24
  hashtags, and NIP-32 hashtag targets.
- Why: the broader tag contract already treats hashtags as lowercase canonical data, the Rust
  reference lowers or rejects uppercase hashtags, and the audit found local inconsistencies where
  some builders rejected uppercase while their paired parsers still accepted it.
- Tradeoff: slightly stricter parse behavior on malformed uppercase hashtag tags versus a clearer,
  more deterministic canonical `t`-tag contract across adjacent modules.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: strong ecosystem evidence shows uppercase hashtag tags are materially common
  and rejecting them causes more interoperability harm than contract clarity provides.
- Supersedes: none

## D-086: Implement bounded NIP-57 zap helpers in the kernel

- Date: 2026-03-13
- Status: accepted
- Decision: implement `src/nip57_zaps.zig` as the bounded kernel surface for kind-`9734`
  zap-request extraction/building/validation and kind-`9735` zap-receipt
  extraction/building/validation.
  - accepted kernel floor:
    - request helpers enforce exact single-`p`, exact single `relays`, optional `amount`,
      optional `lnurl`, optional `e`, optional `a`, optional `k`, and optional `P`
    - request validation verifies the embedded event signature/id and enforces optional query amount
      plus optional receipt-signer continuity
    - receipt validation verifies the receipt event signature/id, parses the embedded request JSON,
      validates the embedded request, and enforces propagated target continuity across `p` / `P` /
      `e` / `a` / `k`
    - the `description` builder now requires a valid signed zap request rather than any arbitrary
      JSON event
  - deferred to SDK:
    - LNURL fetch, callback orchestration, invoice parsing, payment flow, wallet orchestration, and
      UI/payment policy
- Why: zap request and receipt contracts are deterministic protocol glue that both clients and
  relays need to parse and validate consistently, while LNURL and payment workflow are clearly
  higher-level orchestration.
- Tradeoff: a broader event-validation helper surface in the kernel versus cleaner SDK layering and
  less repeated zap-contract logic later.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: deployed zap traffic shows the accepted exact bounded tag contract is
  materially too narrow, or invoice-level validation proves inseparable from the kernel slice.
- Supersedes: none

## D-087: Implement bounded NIP-86 relay-management RPC helpers in the kernel

- Date: 2026-03-13
- Status: accepted
- Decision: implement `src/nip86_relay_management.zig` as the bounded kernel surface for
  NIP-86 JSON-RPC-like request/response parse/build/validate helpers and typed method handling.
  - accepted kernel floor:
    - request parsing/serialization for all current draft methods
    - typed response parsing/serialization for method-appropriate result payloads
    - bounded validation for pubkeys, event ids, kinds, URLs, IPs, and optional reasons
    - serializer invalid-text failures must stay on the `InvalidText` path rather than surfacing
      as capacity errors
  - deferred to SDK or relay application:
    - NIP-98 authorization event handling
    - HTTP transport, admin session handling, retries, operator workflow, and relay policy
- Why: the RPC payload contract is deterministic protocol glue and useful to multiple callers,
  while auth, transport, and operator workflow are orchestration concerns.
- Tradeoff: a slightly broader administrative protocol surface in the kernel versus cleaner SDK and
  relay-application layering.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: the draft method surface changes materially enough that the current typed kernel
  contract causes repeated churn, or real relay implementations show the accepted payload floor is
  too narrow.
- Supersedes: none

## D-088: Implement bounded BIP-85 derivation helpers adjacent to NIP-06

- Date: 2026-03-14
- Status: accepted
- Decision: implement `src/bip85_derivation.zig` as a bounded Nostr-relevant kernel helper module
  adjacent to `NIP-06`.
  - accepted kernel floor:
    - deterministic BIP-85 lowercase-hex entropy-text derivation from the existing BIP39 seed
      boundary
    - deterministic English BIP39 child entropy derivation
    - deterministic English BIP39 child mnemonic derivation
    - direct seed-based helpers plus convenience wrappers from mnemonic + optional passphrase
    - fixed bounds, typed errors, zeroization, and no wallet/account state in the kernel
  - explicitly out of current kernel scope:
    - non-English BIP39 language packs
    - other BIP-85 applications such as WIF, XPRV, passwords, or dice-style higher-level UX
    - wallet/account/storage/import-export flow, which remains SDK work
- Why: `nzdk` wallet work benefits from a deterministic child-entropy/kernel derivation layer, and
  this can be added cleanly on top of the already accepted `libwally`-backed NIP-06 seed boundary
  without widening the kernel into wallet orchestration.
- Tradeoff: a slightly broader derivation surface in the kernel versus less duplicated wallet
  primitive logic in the SDK.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: real SDK usage shows the accepted English-only hex/BIP39 floor is still too
  narrow, or the surface starts pulling workflow/state concerns into the kernel.
- Supersedes: none

## D-089: Keep full NIP-06 Unicode NFKD normalization out of current scope after the post-kernel review

- Date: 2026-03-14
- Status: superseded by `D-091`
- Decision: close the post-kernel loop review of `no-2gp` without implementing full NFKD
  normalization.
  - accepted current posture:
    - the ASCII-only `NIP-06` boundary remains in place
    - `BIP-85` support does not change that Unicode-normalization decision
    - full NFKD only reopens on real SDK wallet pressure or demonstrated interoperability demand
- Why: the practical parity gain is still limited to non-ASCII mnemonic/passphrase handling, and
  the cost remains the same as before: a substantial Unicode normalization subsystem or a new
  non-crypto dependency exception.
- Tradeoff: keep a known Unicode limitation versus avoiding a large complexity jump without actual
  downstream pressure.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: `nzdk` wallet work or real producer data shows the current ASCII-only posture
  is materially blocking intended use.
- Supersedes: none

## D-090: Keep deprecated NIP-04 private-list compatibility out of current scope after the post-kernel review

- Date: 2026-03-14
- Status: accepted
- Decision: close the post-kernel loop review of `no-urr` without implementing a deprecated
  NIP-04 private-list compatibility adapter.
  - accepted current posture:
    - `NIP-51` private lists remain `NIP-44`-first in the kernel
    - deprecated `?iv=` discovery remains out of scope until real interoperability evidence
      justifies carrying it
- Why: there is still no evidence-backed demand from current SDK/bootstrap work that would justify
  widening the kernel to support deprecated private-list encryption.
- Tradeoff: narrower historical compatibility versus keeping the kernel aligned to the current
  accepted private-list boundary.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: real interoperability evidence shows materially relevant private-list traffic
  still depends on deprecated NIP-04 ciphertext discovery.
- Supersedes: none

## D-091: Implement full BIP39-compatible NFKD normalization in the NIP-06 boundary

- Date: 2026-03-15
- Status: accepted
- Decision: replace the temporary ASCII-only normalization boundary in `src/nip06_mnemonic.zig`
  with full bounded `NFKD` normalization before BIP39 seed derivation.
  - accepted implementation floor:
    - repo-owned static `NFKD` tables generated from local Unicode data
    - bounded runtime normalizer in `src/unicode_nfkd.zig`
    - `NIP-06` mnemonic and passphrase inputs normalize before validation / seed derivation
    - no runtime Unicode dependency is introduced into the kernel
  - explicitly still out of scope:
    - broad public Unicode utility APIs
    - turning `noztr` into a general text-normalization library
- Why: `nzdk` and other downstream consumers need `noztr` to be the authoritative Zig Nostr core
  library, and BIP39-compatible wallet flows should not silently diverge on composed vs decomposed
  Unicode input.
- Compatibility note:
  - this is intentionally stricter to BIP39 than the currently covered `rust-nostr` helper path
    for non-ASCII passphrase equivalence
  - current `nostr-tools` helper behavior matches the accepted `NFKD` result
- Tradeoff: a moderate increase in static data / code size versus correct BIP39 interoperability and
  a cleaner SDK dependency boundary.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: none expected; only revisit if a future lower-level shared library absorbs this
  exact bounded normalization surface.
- Supersedes: `D-055`, `D-089`

## D-092: Keep the current crypto wrapper in noztr and treat standalone extraction as future research

- Date: 2026-03-15
- Status: accepted
- Decision: keep the current `secp256k1` / `libwally` wrapper boundary inside `noztr` and do not
  extract it into a standalone library yet.
  - accepted current posture:
    - `noztr` continues to own the protocol-kernel crypto boundary it already uses
    - a future standalone lower-level Zig Bitcoin primitive library remains plausible
    - any such library must start as separate ground-up research, not as a direct extraction of the
      current wrapper
  - if that future library is opened later, likely scope includes:
    - secp256k1 primitives
    - BIP32 derivation/key handling
    - fixed-capacity typed error / zeroization boundaries
  - explicitly not implied by this decision:
    - moving Nostr protocol logic out of `noztr`
    - broadening `noztr` into a generic Bitcoin / wallet SDK
- Why: the current wrapper is shaped for `noztr`'s protocol-kernel needs and is not yet the right
  generally reusable API for Bitcoin / Lightning / Cashu / Nostr consumers.
- Tradeoff: keep a narrow, locally useful boundary for now versus avoiding a premature shared
  library with unclear scope.
- Related Tradeoff: T-H-ANIP-011.
- Reversal Trigger: separate research establishes a stable primitive surface, target consumers, and
  dependency posture for a standalone library.
- Supersedes: none

## D-093: Freeze the next requested-NIP loop after the current kernel-complete baseline

- Date: 2026-03-15
- Status: accepted
- Decision: track the newly requested NIPs in
  `docs/plans/post-kernel-requested-nips-loop.md` and execute them serially under one enforced
  meta-loop.
  - accepted classification:
    - `NIP-40` is already implemented and enters the loop only as a review checkpoint
    - `NIP-47`, `NIP-98`, and `NIP-B7` are split surfaces where `noztr` owns only the
      deterministic protocol/kernel slice
    - `NIP-49`, `NIP-64`, `NIP-88`, `NIP-92`, `NIP-94`, `NIP-99`, `NIP-B0`, and `NIP-C0` are
      kernel-first bounded protocol candidates
  - accepted execution rule:
    - each NIP must complete research freeze, implementation, Review A, Review B, green gates,
      docs/examples, and one scoped git commit before the next NIP starts
- Why: the current kernel baseline is stable enough to resume deliberate expansion, but the next
  set mixes low-ambiguity metadata NIPs with split wallet/HTTP/media surfaces that can drift into
  SDK scope without a frozen per-NIP boundary.
- Tradeoff: slower serial delivery versus lower boundary drift, higher review quality, and more
  reliable examples/docs per NIP.
- Related Tradeoff: T-0-001, T-0-002, T-0-004.
- Reversal Trigger: a future accepted planning change replaces the serial two-review model with a
  more effective execution lane without lowering review quality or boundary discipline.
- Supersedes: none

## D-094: Accept broader NIP-40 expiration tags by using the timestamp slot and ignoring extras

- Date: 2026-03-15
- Status: accepted
- Decision: widen `src/nip40_expire.zig` so `expiration` tags use the timestamp in slot two even
  when extra trailing items are present.
  - accepted behavior:
    - the second item remains the only parsed timestamp source
    - empty or malformed timestamps still behave as absent expiration metadata
    - extra trailing items after the timestamp are ignored
    - first valid expiration still wins deterministically
- Why: the NIP only requires the timestamp, and broader ecosystem helpers such as `nostr-tools` and
  applesauce already read the timestamp while ignoring extra trailing fields. Rejecting or ignoring
  the whole tag when a valid timestamp is present was unnecessary compatibility loss for advisory
  metadata.
- Tradeoff: slightly broader acceptance of malformed optional tag shapes versus better compatibility
  with real helper behavior while keeping the trust boundary deterministic and typed.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: stronger protocol or ecosystem evidence shows extra trailing expiration fields
  should invalidate the tag rather than be ignored.
- Supersedes: none

## D-095: Accept bounded NIP-94 file-metadata helpers with strict MIME and exact supported-tag shapes

- Date: 2026-03-15
- Status: accepted
- Decision: implement `src/nip94_file_metadata.zig` as the accepted `noztr` slice for `NIP-94`.
  - accepted behavior:
    - only kind-`1063` events are accepted
    - required supported tags are `url`, `m`, and `x`
    - `m` must be a lowercase MIME-type token pair (`type/subtype`)
    - `ox` is accepted as optional original-file hash metadata
    - supported singleton tags require exact NIP-shaped item counts
    - `thumb` and `image` accept only the canonical 2-item or 3-item shapes
    - repeated `fallback` URLs are accepted through caller-owned bounded buffers
    - unrelated unknown tags are ignored
    - the event `content` remains the caption/description text
  - accepted evidence posture:
    - rust parity is `HARNESS_COVERED`
    - the TypeScript lane records `NIP-94` as `LIB_UNSUPPORTED` because there is no dedicated
      `nostr-tools` helper surface
    - applesauce was reviewed as secondary ecosystem evidence during the freeze/review pass
- Why: `NIP-94` is a good protocol-kernel fit for bounded parse/build/validate helpers, but the
  accepted trust boundary should stay stricter than the initial draft implementation on the core
  file-metadata tags. Lowercase MIME enforcement and exact supported-tag shapes improve correctness
  and avoid widening `url`/`m`/`x`-style tags without a parity-backed reason, while keeping the
  broader file workflow itself out of the kernel.
- Tradeoff: slightly narrower acceptance for malformed supported tags versus stronger trust-boundary
  behavior and a cleaner contract for downstream SDK/file-service work.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: stronger ecosystem evidence shows deployed canonical helpers intentionally rely
  on broader supported-tag shapes or broader MIME acceptance without introducing ambiguity.
- Supersedes: none

## D-096: Accept bounded NIP-92 `imeta` helpers with strict supported-field semantics

- Date: 2026-03-15
- Status: accepted
- Decision: implement `src/nip92_media_attachments.zig` as the accepted `noztr` slice for `NIP-92`.
  - accepted behavior:
    - the helper operates on one `imeta` tag at a time
    - `imeta` must contain a `url` pair and at least one other supported metadata pair
    - each field item is parsed as one `key value...` pair split on the first space
    - supported field semantics reuse the accepted `NIP-94` value rules where representable
    - supported singleton fields are duplicate-strict
    - repeated `fallback` URLs are accepted through caller-owned bounded buffers
    - unknown fields are ignored inbound, but the canonical builder accepts only supported fields
    - `thumb` and `image` accept only URL values because the `imeta` key/value grammar has no
      separate slot for the optional NIP-94 thumbnail/preview hash
    - URL-to-content matching now requires a bounded exact URL occurrence rather than prefix-only
      substring matches inside larger URLs
  - accepted evidence posture:
    - rust parity is `LIB_UNSUPPORTED`; the local rust reference exposes no dedicated NIP-92 helper
    - the TypeScript lane is also `LIB_UNSUPPORTED` for `nostr-tools`
    - applesauce was reviewed as the relevant secondary ecosystem reference for `imeta` grammar and
      NIP-94 field reuse
- Why: `NIP-92` is a good protocol-kernel fit for bounded inline-media metadata helpers, but the
  accepted kernel slice should stay deterministic and explicit. Strict supported-field handling,
  duplicate rejection, and exact URL-in-content matching provide a stronger trust boundary than a
  generic last-value-wins field map while still preserving the deployed `imeta` key/value grammar.
- Tradeoff: slightly stricter duplicate and malformed-field behavior versus a clearer kernel
  contract for downstream media/attachment workflow in `nzdk`.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: stronger ecosystem evidence shows broader duplicate/field handling improves
  interoperability materially without weakening the supported-field trust boundary.
- Supersedes: none

## D-097: Accept bounded NIP-99 classified-listing metadata helpers

- Date: 2026-03-15
- Status: accepted
- Decision: implement `src/nip99_classified_listings.zig` as the accepted `noztr` slice for
  `NIP-99`.
  - accepted behavior:
    - only kinds `30402` and `30403` are accepted
    - `d` is required and must be a scheme-less URL-shaped identifier
    - `title`, `summary`, `published_at`, `location`, `price`, `status`, and `g` are treated as
      supported singleton metadata tags
    - `image` tags are accepted in ordered form with required URL and optional dimensions
    - `t` hashtags are accepted in ordered form
    - `price` is parsed as amount + currency with optional frequency
    - `status` accepts canonical `active` / `sold` plus bounded other values
    - unrelated tags such as `e` and `a` are ignored inbound
  - accepted evidence posture:
    - rust parity is `LIB_UNSUPPORTED`; there is no dedicated `rust-nostr` NIP-99 helper
    - the TypeScript lane is also `LIB_UNSUPPORTED`; there is no dedicated `nostr-tools` or
      applesauce NIP-99 helper
    - Review A found no additional correctness/parity or trust-boundary issue after the bounded
      implementation and green gate run
    - Review B found no boundary or overengineering issue after the example/index fixes; the
      accepted surface remains metadata-only and keeps commerce/search workflow out of the kernel
- Why: `NIP-99` is structurally close to `NIP-23` and is a good fit for bounded metadata
  parse/build/validate helpers, but the accepted kernel slice should stop at structured listing
  metadata. That gives `nzdk` and app code deterministic listing contracts without pulling listing
  publish/search/inventory workflow into `noztr`.
- Tradeoff: narrower metadata-only scope versus omitting broader marketplace behavior that some apps
  will still need above the kernel.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: stronger ecosystem evidence shows a clearly deterministic additional listing
  helper surface that materially improves interoperability without dragging commerce workflow into
  the kernel.
- Supersedes: none

## D-098: Accept bounded NIP-B0 web-bookmarking helpers

- Date: 2026-03-15
- Status: accepted
- Decision: implement `src/nipb0_web_bookmarking.zig` as the accepted `noztr` slice for
  `NIP-B0`.
  - accepted behavior:
    - only kind-`39701` events are accepted
    - `d` is required and must be a scheme-less URL-shaped identifier
    - `title` and `published_at` are accepted as optional singleton metadata tags
    - `t` hashtags are accepted in ordered form with lowercase hashtag semantics
    - unrelated tags are ignored inbound
    - event `content` may be empty, but when present must be valid UTF-8
  - accepted evidence posture:
    - rust parity is `LIB_UNSUPPORTED`; there is no dedicated `rust-nostr` NIP-B0 helper
    - the TypeScript lane is also `LIB_UNSUPPORTED`; there is no dedicated `nostr-tools` or
      applesauce NIP-B0 helper
    - Review A found no correctness, strictness, or symmetry issue after the bounded
      implementation and green gate run
    - Review B found no overengineering or boundary issue; the accepted surface remains
      metadata-only and keeps bookmark sync/browser workflow out of the kernel
- Why: `NIP-B0` is a straightforward metadata-helper fit for the kernel and is structurally close
  to the accepted `NIP-23` / `NIP-99` family. A bounded parse/build surface gives downstream SDK
  code deterministic bookmark identifiers and metadata without dragging preview, sync, or browser
  integration into `noztr`.
- Tradeoff: narrower metadata-only scope versus leaving richer bookmark workflow to `nzdk` or app
  code.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: stronger ecosystem evidence shows a clearly deterministic additional helper
  surface that materially improves interoperability without pulling bookmark workflow into the
  kernel.
- Supersedes: none

## D-099: Accept bounded public Nostr key helpers plus canonical SDK handoff recipes

- Date: 2026-03-15
- Status: accepted
- Decision: expose `src/nostr_keys.zig` as the bounded public helper surface for deterministic
  Nostr x-only public-key derivation and event signing, and use it to land the first
  `nzdk`-driven canonical handoff recipes.
  - accepted behavior:
    - `nostr_derive_public_key(...)` derives one x-only public key from one `[32]u8` secret key
    - `nostr_sign_event(...)` computes the canonical event id, requires the event pubkey to match
      the signing secret key, and signs the event in place
    - `examples/nip03_verification_recipe.zig` is the canonical end-to-end local
      OpenTimestamps verification recipe over the existing bounded proof floor
    - `examples/nip17_wrap_recipe.zig` is the canonical end-to-end wrapped-message transcript
      recipe using only public `noztr` APIs
  - accepted evidence posture:
    - the change came from the first `nzdk` cross-repo feedback packet rather than a new NIP lane
    - the added helper surface reuses the existing approved secp256k1 backend and does not add a
      second crypto path
    - green gates passed after the helper and recipe additions
- Why: downstream SDK work found three real friction points: no public recipe-grade NIP-17
  wrap/build transcript, no public local-verification recipe for `NIP-03`, and no clean public
  way to derive an x-only public key from a Nostr secret key without reaching into internals. A
  tiny deterministic helper surface plus canonical recipes fixes those gaps without dragging
  session, relay, or wallet orchestration into the kernel.
- Tradeoff: a slightly broader non-NIP helper surface versus cleaner downstream SDK reuse and less
  incentive for apps or SDKs to bypass the kernel boundary.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: future evidence shows the public key/signing helper should move to a dedicated
  lower-level crypto library without weakening the current `noztr` / `nzdk` boundary.
- Supersedes: none

## D-100: Accept bounded NIP-29 reducer replay compatibility for `previous` tags

- Date: 2026-03-15
- Status: accepted
- Decision: widen the pure `NIP-29` reducer replay path just enough to tolerate bounded
  `previous` references on `put-user` and `remove-user` moderation events.
  - accepted behavior:
    - `group_state_apply_event(...)` and `group_state_apply_events(...)` now accept valid
      moderation events that carry bounded `previous` tags
    - reducer replay still ignores `previous` semantics for state reconstruction; the tags are
      accepted, parsed, and then dropped because they do not affect the fixed-capacity state model
    - canonical downstream examples now include:
      - `examples/nip29_reducer_recipe.zig`
      - `examples/nip29_adversarial_example.zig`
  - accepted evidence posture:
    - the issue came directly from `nzdk` group-session replay work
    - the change keeps the reducer deterministic and bounded
    - green gates passed after the reducer fix and example additions
- Why: the reducer previously reused the moderation extractors with zero-capacity `previous`
  scratch, which made otherwise valid replay events fail. SDKs should not have to strip protocol
  tags or normalize events just to make kernel-owned reducer replay work.
- Tradeoff: a slightly broader tolerated replay shape versus preserving a too-narrow reducer input
  contract that rejected valid moderation events.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: future protocol or ecosystem evidence shows reducer replay should preserve or
  model `previous` semantics rather than ignoring them.
- Supersedes: none

## D-101: Accept bounded NIP-C0 code-snippet metadata helpers

- Date: 2026-03-15
- Status: accepted
- Decision: implement `src/nipc0_code_snippets.zig` as the accepted `noztr` slice for `NIP-C0`.
  - accepted behavior:
    - only kind-`1337` events are accepted
    - event `content` is required and must be non-empty valid UTF-8
    - `l`, `name`, `extension`, `description`, `runtime`, and `repo` are supported optional
      singleton tags
    - `license` tags are accepted in ordered repeated form with an optional third-slot text
      reference
    - `dep` tags are accepted in ordered repeated form
    - `repo` accepts either a standard URL or a
      `30617:<pubkey>:<identifier>` repository coordinate with an optional relay-hint URL
    - canonical builders lowercase ASCII language tags on output
    - overlong or malformed builder inputs stay on typed `Invalid*Tag` paths instead of leaking
      `BufferTooSmall`
    - unrelated tags are ignored inbound
    - canonical downstream examples now include:
      - `examples/nipc0_example.zig`
      - `examples/code_snippet_adversarial_example.zig`
  - accepted evidence posture:
    - the vendored `docs/nips/C0.md` text was rechecked against the official mirror / primary
      source during the freeze pass
    - `rust-nostr` provides dedicated outbound `CodeSnippet` builder coverage, but no comparable
      strict parser surface, so parity evidence for this pass is source-review rather than harness
    - applesauce provides getter/cast coverage for `kind:1337` metadata, but no comparable strict
      parse/build contract, so the TypeScript lane is source-review evidence only in this pass
    - Review A initially found two issues and both are fixed in the accepted surface:
      - overlong builder inputs now map to typed `Invalid*Tag` failures instead of panicking or
        surfacing `BufferTooSmall`
      - canonical `l` builders now lowercase ASCII output to match the NIP text and rust helper
        behavior
    - Review B found and fixed low-severity docs/example issues; the accepted surface remains
      metadata-only and keeps editor/run/share workflow out of the kernel
    - green gates passed after the review fixes:
      - `zig build test --summary all`
      - `zig build`
- Why: `NIP-C0` is a clean metadata-helper fit for the kernel and gives downstream SDK/app code a
  deterministic contract for code-snippet metadata, repeated licenses/dependencies, and validated
  repository references without dragging syntax-highlighting, editing, or execution workflow into
  `noztr`.
- Tradeoff: a narrow metadata-only scope versus leaving richer snippet UX and runtime workflow to
  `nzdk` or application code.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: stronger protocol or ecosystem evidence shows a clearly deterministic
  additional helper surface that materially improves interoperability without pulling editor or
  execution workflow into the kernel.
- Supersedes: none

## D-102: Accept bounded NIP-64 chess PGN helpers with structural validation only

- Date: 2026-03-15
- Status: accepted
- Decision: implement `src/nip64_chess_pgn.zig` as the accepted `noztr` slice for `NIP-64`.
  - accepted behavior:
    - only kind-`64` events are accepted
    - event `content` is required and must be non-empty valid UTF-8
    - `alt` is accepted as an optional singleton metadata tag
    - content validation accepts one-or-more PGN games in the database with:
      - bounded tag-pair parsing
      - balanced quoted strings, brace comments, and recursive-variation parentheses
      - required game termination markers (`*`, `1-0`, `0-1`, `1/2-1/2`)
      - bounded PGN movetext token classes for move numbers, SAN-like moves, castling, NAGs, and
        annotation glyphs
    - malformed tag-pair sections without whitespace separation before movetext are rejected
    - canonical downstream examples now include:
      - `examples/nip64_example.zig`
      - `examples/chess_pgn_adversarial_example.zig`
  - accepted non-goals:
    - full chess move legality checking
    - board-state replay
    - board rendering, playback, and engine workflow
  - accepted evidence posture:
    - the vendored `docs/nips/64.md` text was rechecked against the official source during the
      freeze pass
    - `rust-nostr` currently marks `NIP-64` unsupported, so rust parity for this pass is
      `LIB_UNSUPPORTED`
    - I did not find a comparable strict parser in the pinned local TypeScript lane, so the
      secondary ecosystem signal for this pass is also weak and source/spec-first only
    - because both reference lanes are weak here, this NIP received the extra spec-first challenge
      pass required by the strengthened process
    - Review A found two issues and both are fixed in the accepted surface:
      - movetext validation no longer accepts arbitrary non-delimiter text before a result marker
      - malformed tag-pair sections without delimiter whitespace no longer fall through into
        accepted movetext
    - Review B found no boundary or overengineering issue; the accepted surface remains a narrow
      structural validation helper and keeps chess workflow out of the kernel
    - green gates passed:
      - `zig build test --summary all`
      - `zig build`
- Why: `NIP-64` is a reasonable kernel fit only if it stays on deterministic PGN structure rather
  than drifting into chess-engine or viewer behavior. A bounded structural validator plus optional
  `alt` metadata gives downstream callers a useful trust-boundary floor for PGN notes without
  pulling gameplay or rendering concerns into `noztr`.
- Tradeoff: a narrower structural-validation-only helper versus not enforcing the stronger
  client-side SHOULD for full move legality inside the kernel.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: stronger protocol or ecosystem evidence shows a clearly bounded legality or
  richer PGN helper surface that materially improves interoperability without pulling chess-engine
  workflow into the kernel.
- Supersedes: none

## D-103: Tighten requested-NIP closure with reject-corpus and assertion-leak checks

- Date: 2026-03-15
- Status: accepted
- Decision: strengthen the active requested-NIP execution loop and closure discipline using the
  implementation misses found during `NIP-C0` and `NIP-64`.
  - accepted process additions:
    - freeze an explicit invalid-vs-capacity matrix before coding every new public builder or
      validator boundary
    - reject any public invalid-input path that depends on debug assertions instead of typed
      runtime failures
    - when reference lanes are `LIB_UNSUPPORTED` or weak, require a pre-code reject corpus, not
      only additional happy-path evidence
    - minimum reject corpus classes are:
      - arbitrary-but-delimited nonsense
      - malformed section/tag separators
      - overlong fields
      - contradictory optional metadata where applicable
      - debug-vs-release equivalent invalid-input behavior
    - for tokenized or sectioned grammars, the adversarial audit must explicitly challenge
      nonsense tokens and separator discipline, not only balancing or delimiter checks
  - accepted artifact updates:
    - `AGENTS.md`
    - `docs/plans/build-plan.md`
    - `docs/plans/post-kernel-requested-nips-loop.md`
- Why: the recent misses were not happy-path design failures; they were negative-space trust-boundary
  misses. The common pattern was a validator or builder that looked structurally plausible on the
  first pass but had not frozen enough rejection behavior up front, especially when reference
  implementations were weak or absent.
- Tradeoff: more pre-code and review overhead versus fewer post-implementation trust-boundary fixes
  and less dependence on Review A to discover avoidable negative-space mistakes.
- Related Tradeoff: T-0-001, T-0-004.
- Reversal Trigger: future execution evidence shows the stronger reject-corpus and assertion-leak
  requirements add churn without materially reducing post-implementation review findings.
- Supersedes: none

## D-104: Accept bounded NIP-88 poll metadata helpers and pure tally reduction

- Date: 2026-03-15
- Status: accepted
- Decision: implement `src/nip88_polls.zig` as the accepted `noztr` slice for `NIP-88`.
  - accepted behavior:
    - only kind-`1068` poll events and kind-`1018` poll-response events are accepted by the strict
      extractors
    - poll event `content` is required and must be non-empty valid UTF-8
    - `option` tags are required, ordered, and must have exact shape
      `["option", <alphanumeric-id>, <non-empty-label>]`
    - poll option ids must be unique within one poll
    - `relay` tags are accepted in ordered repeated form and must be websocket relay URLs
    - `polltype` is accepted as an optional singleton tag with values `singlechoice` or
      `multiplechoice`; missing `polltype` defaults to `singlechoice`
    - `endsAt` is accepted as an optional singleton unix-seconds tag
    - unrelated tags are ignored inbound on polls
    - poll responses require exactly one strict `e` tag referencing the poll event plus one-or-more
      `response` tags on the direct extractor path
    - direct builders cover canonical `option`, `relay`, `polltype`, `endsAt`, poll-reference `e`,
      and `response` tags
    - the pure tally reducer keeps exactly one latest same-poll response event per pubkey within
      poll limits, with equal timestamps broken deterministically by lexical event id
    - singlechoice tallying uses only the first response tag
    - multiplechoice tallying counts the first response tag per distinct poll option id and ignores
      later duplicate selections for the same id
    - latest malformed same-poll responses now suppress older valid votes by winning reducer
      selection but contributing zero counted selections
    - canonical downstream examples now include:
      - `examples/nip88_example.zig`
      - `examples/polls_adversarial_example.zig`
  - accepted non-goals:
    - relay fetch and subscription workflow
    - live result refresh and UI policy
    - follow-set / proof-of-work / web-of-trust result curation
    - poll publish UX and response-composition workflow
  - accepted evidence posture:
    - the vendored `docs/nips/88.md` text was rechecked against the official source during the
      freeze pass
    - `rust-nostr` provides dedicated `NIP-88` poll and poll-response builders, but not a complete
      matching strict parser or reducer, so rust parity for this pass is source-review only
    - applesauce provides poll getter helpers and compose operations, but not a matching strict
      parser/reducer contract, so the TypeScript lane is also source-review only for this pass
    - Review A found one high-severity reducer bug and it is fixed in the accepted surface:
      - a latest malformed same-poll response no longer leaves an older valid vote counted
    - Review B found one low-severity docs/example discoverability gap and it is fixed:
      - `examples/README.md` now indexes the direct and adversarial `NIP-88` examples
    - green gates passed on the post-review candidate:
      - `zig build test --summary all`
      - `zig build`
- Why: `NIP-88` is a good kernel fit when scoped to deterministic metadata extraction, canonical
  tag builders, and a pure fixed-capacity tally reducer. That gives downstream callers a reliable
  trust-boundary floor for poll parsing and vote counting without dragging relay orchestration,
  curation policy, or UI workflow into `noztr`.
- Tradeoff: a narrow pure-reducer kernel slice versus leaving richer poll workflow and curation
  logic for `nzdk` or applications.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: stronger protocol or ecosystem evidence shows a clearly bounded additional
  helper surface that materially improves interoperability without pulling poll workflow or
  curation policy into the kernel.
- Supersedes: none

## D-105: Accept bounded NIP-49 private-key encryption with internal NFKC normalization

- Date: 2026-03-15
- Status: accepted
- Decision: implement `src/nip49_private_key_encryption.zig` as the accepted `noztr` slice for
  `NIP-49`.
  - accepted behavior:
    - only version `0x02` payloads are accepted
    - fixed payload parse/serialize is strict on the 91-byte
      `version || log_n || salt || nonce || key_security || ciphertext` contract
    - canonical bech32 encode/decode is exposed for the `ncryptsec` HRP
    - passwords are normalized through a new internal bounded `NFKC` helper in
      `src/unicode_nfkc.zig`, backed by checked-in canonical composition tables in
      `src/unicode_nfkc_data.zig`
    - the public boundary accepts typed key-security bytes `weak`, `medium`, and `unknown`
    - the public boundary accepts typed `log_n` values only within the accepted bounded range, with
      fixed `scrypt` parameters `r=8` and `p=1`
    - callers must provide fixed-capacity scratch for `scrypt`, and the module exposes an explicit
      scratch-sizing helper
    - encrypt/decrypt helpers validate secp256k1 secret-key shape at the public boundary
    - decrypt authentication failures map to `InvalidCiphertext`, and successful plaintext still
      must validate as one secp256k1 secret key
    - canonical downstream examples now include:
      - `examples/nip49_example.zig`
      - `examples/private_key_encryption_adversarial_example.zig`
  - accepted non-goals:
    - password UX and policy
    - secret storage, export/import workflow, and recovery policy
    - any broad public Unicode normalization API beyond the narrow internal helper needed here
  - accepted evidence posture:
    - the vendored `docs/nips/49.md` text was rechecked during the freeze pass
    - `rust-nostr` and vendored `nostr-tools` both normalize passwords with `NFKC`, derive the
      symmetric key with `scrypt`, and use XChaCha20-Poly1305 over the same fixed payload shape
    - Review A found two real implementation issues and both are fixed in the accepted surface:
      - bech32 checksum staging now uses the correct `expanded_hrp + data` buffer size
      - checksum bit-shift extraction no longer overflows the loop index type
    - Review B found no additional boundary or overengineering issue; the accepted surface remains
      a caller-scratch-first kernel helper rather than a password-management workflow
    - green gates passed on the post-review candidate:
      - `zig build test --summary all`
      - `zig build`
- Why: `NIP-49` is a good kernel fit when kept on deterministic payload framing, typed password
  normalization, bounded key derivation, and strict secret-key validation. That gives downstream
  callers a reliable `ncryptsec` trust boundary without pulling password UX, storage, or recovery
  policy into `noztr`.
- Tradeoff: a narrower caller-scratch-first encryption boundary versus a more ergonomic but less
  explicit API that would hide runtime allocation, password workflow, or storage concerns.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: stronger protocol or ecosystem evidence shows a bounded additional helper
  surface that materially improves interoperability without widening `noztr` into password UX,
  storage policy, or a broad Unicode API.
- Supersedes: none

## D-106: Accept bounded NIP-98 HTTP-auth event and header helpers

- Date: 2026-03-15
- Status: accepted
- Decision: implement `src/nip98_http_auth.zig` as the accepted `noztr` slice for `NIP-98`.
  - accepted behavior:
    - only kind-`27235` events are accepted by the strict extractor and validator paths
    - strict extraction requires exactly one `u` tag and exactly one `method` tag; `payload` is
      optional and accepted at most once
    - `u` tags must use exact two-item shape `["u", <absolute-url>]`
    - `method` tags must use exact two-item shape `["method", <http-token>]`
    - `payload` tags must use exact two-item shape `["payload", <64-char-lowercase-sha256-hex>]`
    - unrelated tags are ignored inbound
    - event `content` is not required to be empty on the strict parser path because the NIP says
      it `SHOULD` be empty, not `MUST`; canonical downstream examples still emit empty content
    - request validation uses exact byte equality for URL and method matching, and exact lowercase
      hex equality for payload matching when a payload hash is expected
    - timestamp freshness remains caller policy through explicit `now`, `max_past_seconds`, and
      `max_future_seconds` inputs; the module does not fetch wall-clock time internally
    - canonical builders cover strict `u`, `method`, and `payload` tags plus lowercase SHA-256
      request-body hashing
    - strict header helpers cover:
      - exact `Authorization: Nostr <base64-json-event>` formatting
      - base64 decode from one strict `Nostr ` header value
      - one safe wrapper that decodes, parses, verifies, and exact-matches a header in one call
  - accepted non-goals:
    - HTTP middleware and request execution
    - client/server transport workflow
    - challenge/session management
    - redirect, retry, cache, or auth-policy orchestration
  - accepted evidence posture:
    - the vendored `docs/nips/98.md` text was rechecked during the freeze pass
    - `rust-nostr` provides dedicated `NIP-98` auth helpers and a combined verify-header path, but
      it hard-codes a narrower method enum and an embedded timestamp policy window
    - vendored `nostr-tools` provides token helpers, but its method comparison is case-insensitive
      and its payload hashing helper is object-JSON-oriented rather than raw-body-byte oriented
    - `libnostr-z` provides similar helper coverage, but it also embeds time policy and
      case-insensitive method handling
    - Review A found one real public error-contract issue and it is fixed:
      - direct base64 decode no longer reports empty or oversized decoded event payloads as
        header-shape failures
    - Review B found one real builder-boundary issue and it is fixed:
      - header formatting no longer accepts arbitrary non-base64 token bytes
    - adversarial downstream examples now include:
      - `examples/nip98_example.zig`
      - `examples/http_auth_adversarial_example.zig`
    - green gates passed on the post-review candidate:
      - `zig build test --summary all`
      - `zig build`
- Why: `NIP-98` is a good kernel fit when scoped to deterministic auth-event extraction, exact
  request matching, pure payload hashing, strict header encoding/decoding, and one obvious safe
  verify wrapper. That gives downstream HTTP clients and servers a reusable trust-boundary floor
  without pulling transport middleware or session policy into `noztr`.
- Tradeoff: a strict exact-match kernel slice versus broader convenience behavior such as
  case-insensitive methods, embedded wall-clock policy, or middleware ergonomics.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: stronger protocol or ecosystem evidence shows a bounded additional helper
  surface that materially improves interoperability without pulling HTTP workflow or session policy
  into the kernel.
- Supersedes: none

## D-107: Accept bounded NIP-47 Wallet Connect kernel helpers

- Date: 2026-03-15
- Status: accepted
- Decision: implement `src/nip47_wallet_connect.zig` as the accepted `noztr` slice for `NIP-47`.
  - accepted behavior:
    - strict event-envelope helpers cover:
      - kind `13194` info events
      - kind `23194` request events
      - kind `23195` response events
      - legacy notification kind `23196`
      - NIP-44 notification kind `23197`
    - connection URIs require lowercase 32-byte hex wallet pubkeys and secrets, one-or-more
      websocket relay URLs, and optional `lud16`
    - info-event content keeps ordered raw capability tokens, accepts optional singleton
      `encryption` and `notifications` tags, and defaults missing `encryption` to `nip04`
    - request events require exactly one `p` tag, accept optional singleton `expiration` and
      `encryption` tags, and default missing `encryption` to `nip04`
    - response events require exactly one `p` tag, exactly one `e` tag, accept optional singleton
      `encryption`, and default missing `encryption` to `nip04`
    - notification events require exactly one `p` tag; kind `23196` defaults to `nip04` and kind
      `23197` defaults to `nip44_v2`, with optional singleton `encryption` override support
    - decrypted JSON request helpers expose typed unions only for the spec command-section methods:
      - `pay_invoice`
      - `pay_keysend`
      - `make_invoice`
      - `lookup_invoice`
      - `list_transactions`
      - `get_balance`
      - `get_info`
      - `make_hold_invoice`
      - `cancel_hold_invoice`
      - `settle_hold_invoice`
    - unsupported request/result methods are rejected on the public boundary
    - decrypted JSON responses require `result_type`, `error`, and `result`, with strict
      null-versus-object exclusivity
    - `get_info` preserves ordered raw validated method and notification tokens for forward
      compatibility rather than collapsing them into a closed enum
    - generic transaction metadata accepts only JSON objects with serialized size
      `<= 4096` bytes
    - canonical downstream examples now include:
      - `examples/nip47_example.zig`
      - `examples/wallet_connect_adversarial_example.zig`
  - accepted non-goals:
    - relay lifecycle and transport/session orchestration
    - wallet service orchestration and payment execution workflow
    - runtime NIP-04/NIP-44 encryption/decryption handling
    - wallet API bridging and notification handling policy
  - accepted evidence posture:
    - the vendored `docs/nips/47.md` text was rechecked during the freeze pass
    - `rust-nostr` and `libnostr-z` were used as parity references for URI shape, method/result
      coverage, and notification structure
    - the applesauce reference lane was unavailable in the local checkout, so this close used the
      spec plus available rust/zig reference lanes
    - Review A found one real public error-contract issue and it is fixed:
      - serializer-side invalid text now stays on `InvalidParams`, `InvalidResult`, and
        `InvalidNotification` instead of collapsing to generic `InvalidContent`
    - Review B found no further boundary or overengineering issue after example/export/index
      parity updates
    - green gates passed on the post-review candidate:
      - `zig build test --summary all`
      - `zig build`
- Why: `NIP-47` is a good split kernel fit when scoped to deterministic NWC URI handling,
  bounded envelope extraction, typed decrypted JSON contracts, and exact public error surfaces.
  That gives downstream wallet and SDK code a reusable trust-boundary floor without pulling relay,
  payment, or encryption workflow into `noztr`.
- Tradeoff: a narrow split-surface kernel helper versus a more ergonomic but workflow-entangled
  API that would hide transport, encryption, or wallet-service policy inside the library.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: stronger protocol or ecosystem evidence shows a bounded additional helper
  surface that materially improves interoperability without widening `noztr` into wallet
  orchestration, relay workflow, or runtime encryption handling.
- Supersedes: none

## D-108: Adopt lean control-surface rules for docs and handoff state

- Date: 2026-03-15
- Status: accepted
- Decision: adopt a leaner docs control surface influenced by the refined `nzdk` process.
  - accepted behavior:
    - `docs/README.md` is added as the canonical docs router for active vs reference vs archive
      material
    - `docs/guides/PROCESS_CONTROL.md` is added as the repo-specific policy for keeping control
      docs lean
    - `docs/plans/docs-surface-audit.md` is added as the stable-ID audit for doc-bloat and
      discoverability findings
    - `handoff.md` is reduced to current-state control information only and must not act as a
      running changelog
    - process/docs findings should use stable IDs instead of prose-only “cleanup later” notes
  - accepted non-goals:
    - immediate full rewrite of legacy planning/reference docs
    - collapsing the decision log into a shorter file at the cost of losing accepted-default
      provenance
  - accepted follow-up posture:
    - keep `decision-log.md` as a large reference surface if it remains the canonical home for
      accepted defaults
    - continue trimming active-doc repetition where it improves routing without hiding slice-
      specific assumptions
- Why: the repo had enough rigor, but too much active-memory load. The biggest problem was not
  missing policy; it was that `handoff.md`, `build-plan.md`, and other active docs were carrying
  overlapping narrative state. A lean control surface keeps rigor high while making startup reads
  cheaper and current work easier to find.
- Tradeoff: more explicit doc-role separation versus maintaining the illusion that every active doc
  can be complete on its own.
- Related Tradeoff: T-0-001, T-0-004.
- Reversal Trigger: the leaner control surface causes repeated routing confusion or loses material
  execution context that cannot be recovered from the decision log, build plan, archive, or git
  history.
- Supersedes: none

## D-109: Adopt unified docs frontmatter schema and decision-index routing

- Date: 2026-03-15
- Status: accepted
- Decision: standardize the active `noztr` docs surface on a shared frontmatter schema and route
  startup policy reads through a compact decision index.
  - accepted behavior:
    - `docs/guides/PROCESS_CONTROL.md` defines the shared docs frontmatter schema
      (`title`, `doc_type`, `status`, `owner`, `read_when`, `depends_on`, `supersedes`,
      `posture`, `phase`, `canonical`, `archive_of`)
    - docs should use the shared schema across projects, but only populate fields that are relevant
      for the current doc
    - `docs/plans/decision-index.md` is added as the startup route into accepted policy areas
    - `docs/plans/decision-log.md` remains canonical, but is moved out of the default startup path
      and treated as on-demand reference
    - `agent-brief`, `docs/README.md`, `handoff.md`, and active control docs should route readers
      through the decision index before loading the full decision log
  - accepted non-goals:
    - immediate frontmatter rollout across every archival or vendored markdown file
    - replacing the decision log with summaries that lose canonical accepted-default payloads
- Why: the repo needs consistent metadata across projects, but the larger gain is to stop paying
  reference-doc cost in every startup path. A shared sparse frontmatter schema improves routing
  consistency, and a decision index keeps accepted-default provenance without making the full log
  part of active memory by default.
- Tradeoff: more explicit metadata and one additional routing artifact versus lower startup cost and
  more uniform docs handling across repos.
- Related Tradeoff: T-0-004.
- Reversal Trigger: the shared schema becomes noisy without improving routing, or the decision index
  introduces enough drift/confusion that direct startup reads of the full decision log become
  cheaper than maintaining the split.
- Supersedes: none

## D-110: Make closeout consistency an explicit docs-control rule

- Date: 2026-03-15
- Status: accepted
- Decision: treat closeout consistency as an explicit part of done for process/doc refinement and
  slice closure.
  - accepted behavior:
    - `docs/guides/PROCESS_CONTROL.md` defines a `log` doc role for ongoing issue/feedback
      tracking that is useful but not startup-critical
    - closure must restore the docs surface to steady state rather than leaving temporary emphasis
      in startup docs
    - targeted audit findings must be updated immediately when the slice closes
    - examples or discovery catalogs must be updated when the public teaching surface changes
    - handoff should point at the new next work instead of the slice that just closed
  - accepted non-goals:
    - adding extra closure layers for their own sake
    - turning every closed slice into a permanent active packet
- Why: a technically correct change can still leave process drift if the surrounding docs surface
  remains temporarily expanded. Making closeout consistency explicit closes that gap and helps keep
  the active-memory path lean after each finished slice.
- Tradeoff: slightly more explicit closeout discipline versus allowing stale routing or teaching
  surfaces to persist after technically successful work.
- Related Tradeoff: T-0-004.
- Reversal Trigger: the explicit closeout-consistency rule adds ceremony without measurably reducing
  stale startup routing, audit drift, or doc-surface regrowth.
- Supersedes: none

## D-111: Make refinement-packet synchronization touchpoints explicit

- Date: 2026-03-15
- Status: accepted
- Decision: require active refinement packets to declare their closeout synchronization touchpoints
  early enough that they can be checked deliberately at closure time.
  - accepted behavior:
    - `docs/guides/PROCESS_CONTROL.md` defines synchronization discipline for packet/refinement work
    - shared frontmatter may include `nips`, `target_findings`, and `sync_touchpoints` when they
      carry signal
    - active packets should declare whether the slice changes the teaching surface, audit state, or
      startup/discovery docs
    - the declaration is a short closeout checklist, not a new workflow phase
    - the active requested-NIP loop packet incorporates this declaration into its research/freeze
      and closeout steps
  - accepted non-goals:
    - introducing another review cycle
    - expanding packet docs into full planning artifacts just to name obvious touchpoints
- Why: the repo already had stronger closeout rules, but some synchronization work was still being
  discovered late by memory. Declaring the touchpoints early makes doc-routing, audit, and teaching
  updates visible before the slice is finished without adding real process weight.
- Tradeoff: a small amount of explicit packet metadata/checklist discipline versus a quieter class
  of closeout drift.
- Related Tradeoff: T-0-004.
- Reversal Trigger: touchpoint declarations become rote noise that do not measurably improve
  closeout consistency.
- Supersedes: none

## D-112: Accept bounded NIP-B7 Blossom server-list and fallback helpers

- Date: 2026-03-15
- Status: accepted
- Decision: implement `src/nipb7_blossom_servers.zig` as the accepted `noztr` slice for `NIP-B7`.
  - accepted behavior:
    - strict event helpers cover only kind `10063`
    - extraction requires one-or-more ordered `server` tags and rejects malformed `server` tags
      instead of guessing at partial shapes
    - accepted `server` tags are exactly `["server", "<url>"]`
    - accepted server URLs require:
      - `http` or `https`
      - a host
      - no userinfo
      - no query or fragment
      - optional base-path support
    - canonical `server` tag builders trim trailing `/` while preserving an accepted base path
    - blob-reference extraction accepts only `http` or `https` URLs with a real path, then uses
      the last bounded 64-character hex occurrence in the URL path to extract the blob hash
    - blob-reference extraction accepts uppercase or mixed-case hash input and canonicalizes output
      fallback paths/URLs to lowercase hex
    - optional extensions are accepted only as non-empty suffixes matching
      `[A-Za-z0-9][A-Za-z0-9._-]*`
    - public helpers expose deterministic fallback path and fallback URL builders
    - public error contracts keep invalid input on:
      - `InvalidServerTag`
      - `InvalidServerUrl`
      - `InvalidBlobUrl`
      - `InvalidBlobHash`
      - `InvalidBlobExtension`
      while reserving `BufferTooSmall` for caller-output capacity failures
    - canonical downstream examples now include:
      - `examples/nipb7_example.zig`
      - `examples/blossom_adversarial_example.zig`
  - accepted non-goals:
    - BUD upload, download, existence-check, or cache workflow
    - content-hash verification after retrieval
    - fallback retry policy or well-known-server policy
    - Blossom URI (`BUD-10`) parsing
  - accepted evidence posture:
    - the vendored `docs/nips/B7.md` text was rechecked during freeze
    - local `BUD-03` wording was used to freeze the ordered server-list semantics and the
      “last occurrence of a 64 char hex string” retrieval rule
    - the local applesauce helper lane was used only as weak supporting evidence that server-list
      handling treats these entries as server-base URLs rather than arbitrary fetch URLs
    - the local rust lane did not expose a strong direct `kind:10063` helper surface, so this
      close used the extra weak-evidence reject corpus
    - Review A found two real trust-boundary issues and both are fixed:
      - blob-hash extraction no longer scans the host portion of a URL and only considers the path
      - oversized invalid caller input no longer leaks through debug assertions and now stays on
        typed public errors
    - Review B found no further boundary or overengineering issue after the accepted split stayed
      at ordered server-list parsing plus deterministic fallback derivation
    - green gates passed on the post-review candidate:
      - `zig build test --summary all`
      - `zig build`
- Why: `NIP-B7` is a good split kernel fit when scoped to ordered `kind:10063` server-list
  parsing/building and pure fallback path/URL derivation from a broken blob URL. That gives
  downstream SDK and app code a reusable trust-boundary floor without pulling file-service,
  retrieval, or cache workflow into `noztr`.
- Tradeoff: a narrow deterministic helper surface versus a more ergonomic but workflow-entangled
  blob-discovery API that would need network policy, retry behavior, and existence checks.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: stronger protocol or ecosystem evidence shows a bounded additional helper
  surface that materially improves interoperability without widening `noztr` into Blossom service
  workflow.
- Supersedes: none

## D-113: Codify explicit review prompts and a shareable process-refinement playbook

- Date: 2026-03-15
- Status: accepted
- Decision: codify the process lessons validated during `NIP-B7` into the canonical control docs
  and add a reusable `noztr` playbook for cross-repo sharing.
  - accepted behavior:
    - `docs/guides/PROCESS_CONTROL.md` now requires a more explicit micro-freeze for materially
      expanded trust-boundary surfaces:
      - scope
      - intended scan regions
      - accepted equivalent valid forms
      - canonical emitted forms
      - invalid-vs-capacity matrix
      - reject corpus
    - `PROCESS_CONTROL.md` now defines minimum Review A prompts:
      - can invalid input still panic or hit a debug assertion?
      - can invalid input still leak as a capacity error?
      - can capacity failure still leak as an invalid-input error?
      - does any scan escape the intended syntactic region?
      - does the parser accept nonsense just because delimiters balance?
    - `PROCESS_CONTROL.md` now defines minimum Review B prompts:
      - did canonicalization become over-strict input validation?
      - did the surface stay inside deterministic kernel ownership?
      - did workflow or policy behavior leak in from the SDK layer?
      - do examples show both intended use and intended rejection?
    - `docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md` is added as a shareable `noztr` reference for
      process lessons learned from real slices
    - `AGENTS.md`, `docs/README.md`, and `handoff.md` route process-refinement tasks to the new
      playbook on demand
  - accepted non-goals:
    - turning the playbook into a second canonical process owner
    - requiring every repo to copy `noztr`’s exact doc layout or packet names
    - adding new review phases beyond the existing freeze / Review A / Review B structure
  - accepted evidence posture:
    - the trigger for this refinement was recent `noztr` implementation evidence, not a theoretical
      cleanup preference
    - the `NIP-B7` slice validated that the refined process caught three concrete bug classes:
      - over-strict valid-input rejection
      - scan-region escape
      - assertion-order public error leakage
    - the useful process additions were small, explicit prompts rather than broader prose
- Why: the updated process is working, but the main remaining risk is that the sharpest lessons
  still live too much in reviewer memory. Converting those lessons into exact review prompts and a
  reusable playbook keeps the stronger gate teachable without inflating the main control docs.
- Tradeoff: slightly more explicit review structure and one more reference doc versus lower reliance
  on conversational memory and easier cross-repo process transfer.
- Related Tradeoff: T-0-004.
- Reversal Trigger: the added prompts become ceremonial, fail to catch the intended bug classes, or
  the playbook drifts into a second canonical process owner instead of remaining a shareable
  reference.
- Supersedes: none

## D-114: Add ordered micro-loop and audit-posture refinement guidance

- Date: 2026-03-15
- Status: accepted
- Decision: extend the `noztr` process-refinement guidance with ordered micro-loop discipline,
  clearer audit-posture design prompts, and explicit anti-patterns for cross-repo sharing.
  - accepted behavior:
    - `docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md` now captures:
      - ordered micro-loops as the preferred way to reduce synchronization errors
      - guidance for choosing audit postures from real failure modes rather than aesthetic symmetry
      - explicit process anti-patterns
      - a minimal adoption path for other repos
    - `docs/guides/PROCESS_CONTROL.md` now states that refinement work should use the canonical
      staged execution order that applies to the slice, then rerun the relevant audit frames
    - `PROCESS_CONTROL.md` now also prompts posture selection from the repo’s actual failure modes
      and keeps the playbook explicitly reference-only
  - accepted non-goals:
    - creating a new workflow phase
    - making the playbook part of default startup reads
    - forcing `noztr` to mirror sibling-repo doc topology exactly
  - accepted evidence posture:
    - the useful delta came from the latest `nzdk` playbook refinement, specifically:
      - ordered micro-loops to reduce sync drift
      - repo-specific audit-posture design guidance
      - explicit anti-patterns and minimal-adoption framing
    - `noztr` adopted only the parts that improve its current process without expanding the active
      startup path
- Why: the first `noztr` playbook captured local lessons well, but it still benefited from a
  clearer explanation of why staged execution reduces drift and how another repo should choose its
  audit lenses without cargo-culting `noztr` wholesale.
- Tradeoff: slightly more reference guidance in the playbook versus better transferability and less
  process ambiguity when another repo wants to learn from `noztr`.
- Related Tradeoff: T-0-004.
- Reversal Trigger: the additional playbook guidance turns into noise, duplicates the canonical
  process owner, or stops reflecting real process failures and improvements.
- Supersedes: none

## D-115: Treat process updates as coherent control-surface edits

- Date: 2026-03-15
- Status: accepted
- Decision: process updates are not additive by default; they must be applied as coherent edits to
  the existing docs control surface.
  - accepted behavior:
    - when process changes materially, the repo should review together:
      - `docs/guides/PROCESS_CONTROL.md`
      - `docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md`
      - `docs/README.md`
      - `handoff.md`
      - `docs/plans/docs-surface-audit.md`
    - superseded wording should be removed or rewritten instead of left beside the new rule
    - `PROCESS_CONTROL.md` remains the canonical local rule owner
    - `PROCESS_REFINEMENT_PLAYBOOK.md` remains a reference doc for rationale and transfer, not a
      second rule owner
    - `docs/plans/docs-surface-audit.md` should keep live findings only; resolved-history material
      moves to archive when it still matters for provenance
    - `docs/archive/plans/docs-surface-audit-history.md` now holds resolved audit history
  - accepted non-goals:
    - merging `PROCESS_CONTROL.md` and `PROCESS_REFINEMENT_PLAYBOOK.md` into one doc
    - moving large reference material back into the startup path
    - preserving every resolved refinement note in the active audit surface
  - accepted evidence posture:
    - the trigger for this change was local additive drift in the process/reference tier, not a
      startup-path regression
    - the sibling `nzdk` playbook refinement validated the same principle explicitly:
      process changes should revise the current control surface, not merely append new doctrine
- Why: the repo’s startup path remained lean, but the process/reference layer had started to drift
  toward additive overlap between the canonical process owner, the external playbook, and the
  active audit. Treating process changes as coherent control-surface edits keeps the docs system
  understandable without collapsing distinct doc roles.
- Tradeoff: slightly more deliberate docs-maintenance work on each material process change versus
  lower long-term drift and less repeated rule language.
- Related Tradeoff: T-0-004.
- Reversal Trigger: the coherent-edit requirement adds cost without reducing duplication or drift,
  or the split between control and playbook docs stops buying clarity.
- Supersedes: none

## D-116: Restore active Phase H packet routing and split the generic implementation gate from specialized audit guidance

- Date: 2026-03-16
- Status: accepted
- Decision: keep Phase H active while `OQ-E-006` remains open, restore a current Phase H packet,
  and separate the repo-wide implementation gate from the implemented-NIP audit guide.
  - accepted behavior:
    - `docs/plans/phase-h-remaining-work.md` is the current active Phase H packet
    - `docs/plans/phase-h-kickoff.md`, `docs/plans/phase-h-additional-nips-plan.md`, and
      `docs/plans/phase-h-wave1-loop.md` are retained as `reference` packets for completed lanes
    - `docs/guides/IMPLEMENTATION_QUALITY_GATE.md` is the canonical staged execution order for new
      implementation, audit, and robustness slices
    - `docs/plans/implemented-nip-review-guide.md` remains a specialized implemented-surface audit
      and robustness guide rather than a generic repo-wide gate
    - `docs/plans/packet-template.md` is the shared packet skeleton for new or repaired packets
    - startup routing now points to the live Phase H packet instead of completed Phase H packets
    - `handoff.md` returns to a state-first pointer surface instead of acting like a secondary
      control manual
  - accepted non-goals:
    - rewriting completed Phase H packet history into new summary prose
    - changing the accepted semantics of completed Phase H implementation slices
    - closing Phase H before `OQ-E-006` closes
- Why: the requested-NIP loop closed, but Phase H did not. Leaving startup and packet routing aimed
  at completed lanes made the repo look more finished than it is and pushed control-doc burden back
  into `handoff.md`. A current remaining-work packet plus a repo-wide implementation gate restores
  truthful routing with less repetition.
- Tradeoff: one more canonical process doc and one small active packet versus continued drift where
  completed packets masquerade as current work and handoff regrows into a secondary control doc.
- Related Tradeoff: T-0-004.
- Reversal Trigger: the separate generic gate and remaining-work packet add more routing noise than
  clarity, or future work proves that the specialized audit guide alone is sufficient for all new
  slices.
- Supersedes: none

## D-117: Close OQ-E-006 with teaching-surface fixes and keep current strict defaults as RC-freeze inputs

- Date: 2026-03-16
- Status: accepted
- Decision: close `OQ-E-006` after a full battery run with teaching-surface fixes only:
  - add one strict-core recipe for event lifecycle, message grammar, transcript flow, and checked
    wrapper usage
  - strengthen the thin `NIP-01` and `NIP-42` reference examples to show the canonical verified flow
  - keep the current strict filter, relay `OK`, and NIP-42 origin defaults as carried-forward
    RC-freeze inputs
- Why: the usability pass found real discoverability gaps in examples and routing, but did not
  produce evidence that the current strict kernel defaults should be weakened or rolled back.
- Tradeoff: a modest increase in example-surface maintenance versus materially lower LLM and SDK
  guesswork on the canonical strict path.
- Related Tradeoff: T-0-001, T-0-004.
- Reversal Trigger: a later RC-freeze or adapter-boundary slice finds evidence that the current
  strict defaults cause unacceptable interoperability or usability failure at the kernel boundary.
- Supersedes: the open-status snapshot in `D-014`

- Closure snapshot:
  - `OQ-E-006`: closed (`docs/plans/llm-usability-pass.md`)
  - battery result: pass (`R1=2`, `R2=2`, `R3=1`, `R4=2`, `R5=2`, average `1.8`)
  - Medium+ blockers: none remaining after example-routing fixes
  - next work: choose and freeze the next Phase H packet for RC API-freeze or Layer 2
    adapter-boundary execution

## D-118: Require explicit example-layer contract checks for example-bearing slices

- Date: 2026-03-16
- Status: accepted
- Decision: when a slice adds or changes examples, Review B and the implementation gate must check
  that the example is teaching the correct contract layer.
  - minimum explicit layer distinctions:
    - full object JSON
    - canonical preimage
    - message envelope
    - checked wrapper result
  - required behavior:
    - if an example claims parse/serialize round-trip, confirm parser and serializer are on the same
      layer
    - if a serializer only emits canonical id-preimage or envelope output, say so and do not teach
      it as full object parsing
- Why: `OQ-E-006` surfaced a real teaching bug where a plausible example crossed the event-object
  and canonical-preimage layers. The library contract was correct, but the example taught the wrong
  model until the full gate caught it.
- Tradeoff: one more narrow review prompt versus lower risk that examples become the first place
  semantic contract confusion escapes.
- Related Tradeoff: T-0-004.
- Reversal Trigger: the example-layer check stops catching real teaching mistakes or becomes too
  vague to apply consistently.
- Supersedes: none

## D-119: Keep full Blossom protocol/service work out of `noztr`

- Date: 2026-03-16
- Status: accepted
- Decision: keep Blossom ownership split at the deterministic protocol-kernel boundary.
  - accepted behavior:
    - `noztr` keeps only deterministic Blossom kernel seams
    - the currently accepted `NIP-B7` slice remains:
      - ordered `kind:10063` server-list parsing/building
      - deterministic fallback path/URL derivation
    - future Blossom additions in `noztr` are allowed only if they stay:
      - protocol-facing
      - pure and deterministic
      - bounded and fixed-capacity
      - transport-free and service-policy-free
    - plausible future kernel candidates may include:
      - bounded `BUD-10` URI parsing/building
      - bounded descriptor or auth-token helpers that remain transport-free
    - the full Blossom protocol/service stack does not belong in `noztr`
    - the full Blossom protocol/service stack should live in a dedicated repo that `nzdk`
      integrates rather than owns directly
  - accepted non-goals for `noztr`:
    - Blossom HTTP client/server endpoint flows
    - upload, download, mirror, media, report, or payment workflow
    - storage, cache, retry, availability, or service policy
- Why: Blossom is important ecosystem infrastructure, but the full stack is a protocol-plus-service
  system rather than a pure kernel seam. Keeping the service/runtime surface out of `noztr`
  preserves the strict deterministic boundary while still leaving room for narrow reusable helpers
  that materially improve interoperability.
- Tradeoff: one extra repo boundary versus a cleaner kernel and a clearer separation between
  deterministic protocol glue and service/runtime workflow.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: protocol or ecosystem evidence shows that the dedicated-repo split creates more
  fragmentation than clarity, or that a materially larger Blossom surface can be kept purely
  deterministic and transport-free inside `noztr`.
- Supersedes: none

## D-120: Accept deterministic one-recipient outbound `NIP-59` transcript construction in `noztr`

- Date: 2026-03-16
- Status: accepted
- Decision: keep the outbound `NIP-17`/`NIP-59` ownership split at the deterministic transcript
  seam.
  - accepted behavior:
    - `noztr` may expose a bounded public helper that builds one recipient-specific
      `rumor -> seal -> wrap` transcript
    - the accepted helper must stay:
      - deterministic
      - one-recipient only
      - caller-buffer-first
      - caller-driven for secrets, nonces, and timestamps
      - free of relay, mailbox, sender-copy, and session policy
    - `nip01_event` may expose unsigned full event-object JSON serialization for unsigned-rumor
      staging when it stays shape-checked and explicitly distinct from canonical-preimage output
  - accepted non-goals:
    - recipient fanout
    - relay selection or publish workflow
    - mailbox copy policy
    - session orchestration
    - delivery retries or storage policy
- Why: `nzdk` pressure showed that outbound transcript staging was being duplicated in recipes and
  SDK code even though the core cryptographic and serialization work is deterministic, bounded, and
  reusable across callers. Pulling just the one-recipient transcript builder into `noztr` removes
  duplicated kernel glue without widening the library into mailbox workflow.
- Tradeoff: a slightly larger `NIP-59` kernel surface versus less duplicated and potentially
  inconsistent outbound transcript staging in downstream SDK code.
- Related Tradeoff: T-0-001, T-0-002.
- Reversal Trigger: the helper starts attracting recipient fanout, relay policy, or session-shaped
  logic, or real SDK evidence shows that the one-recipient seam is too narrow to be reusable.
- Supersedes: none

## D-121: Codify generalized audit-hardening checks instead of pass-specific incident rules

- Date: 2026-03-17
- Status: accepted
- Decision: promote the reusable failure classes from the second full implemented-surface audit into
  the repo-wide process, while keeping pass-specific details in tests and audit records.
  - accepted behavior:
    - process refinements should codify generalized failure patterns, not the exact NIP/module that
      triggered them
    - Review A for public trust-boundary slices now includes one targeted public-path
      assertion-leak scan on touched parser/builder/validator chains
    - freezes and adversarial audits must include representative overlong-input cases for each
      touched public builder/parser family
    - SDK-facing split surfaces require hostile examples as a default rule, not only when someone
      remembers they are boundary-heavy
    - audit and robustness slices must update canonical audit/report artifacts in the same slice
      when accepted behavior or live findings changed
    - review language should explicitly ask whether public invalid input still reaches an internal
      helper invariant before typed validation
  - accepted non-goals:
    - turning incident-specific checks into permanent repo-wide doctrine
    - requiring repo-wide grep rituals on untouched code
    - duplicating detailed audit history in the process docs
- Why: the latest audit found a recurring generic bug class: public invalid input reaching helper
  assertions or helper-shaped assumptions before typed validation. It also reconfirmed two general
  closure risks: hostile examples lagging behind SDK-facing surfaces and canonical audit artifacts
  drifting behind accepted implementation state. These are reusable process lessons, not one-off
  facts about a particular NIP set.
- Tradeoff: slightly more explicit freeze/review/audit work on public trust-boundary slices versus
  lower risk of assertion leaks, weaker hostile coverage, and stale canonical audit docs.
- Related Tradeoff: T-0-004.
- Reversal Trigger: the generalized checks stop catching real trust-boundary or closeout drift
  issues, or they create enough routine overhead that a narrower formulation is clearly better.
- Supersedes: none

## D-122: Separate high-impact pre-freeze audits from remediation and require meta-analysis first

- Date: 2026-03-17
- Status: accepted
- Decision: when `noztr` is running a high-impact multi-angle pre-freeze audit program, the default
  posture is audit-first and evidence-producing rather than patch-as-you-go remediation.
  - accepted behavior:
    - define the required audit angles explicitly up front
    - keep one live working draft or coverage ledger during the audit
    - require one dedicated report per audit angle, or one explicitly cited canonical report that
      owns that angle
    - each angle report must state:
      - exact scope
      - evidence sources
      - standards used
      - what was checked
      - what was not checked
      - findings
      - accepted exceptions
      - residual risk
    - do not treat targeted follow-up lanes as equivalent to one exhaustive pre-freeze audit
    - defer non-critical fixes until after one explicit meta-analysis step
    - note:
      - this was the initial softer posture and was later tightened by `D-124`
    - the meta-analysis step must decide whether the next remediation posture is:
      - targeted fixes
      - bounded redesign
      - major rewrite
  - historical exceptions in the initial version:
    - broken builds
    - safety-critical defects
    - findings severe enough that leaving them unfixed would make the ongoing audit evidence false
      or materially misleading
  - current rule:
    - `D-124` removes these in-audit fix exceptions for the active pre-freeze audit program
  - accepted non-goals:
    - mixing exhaustive evidence gathering with routine micro-fix churn
    - deciding against rewrite pressure before the reports exist
    - deciding for major rewrite before the reports show the issue pattern is systemic
- Why: the repo reached a point where targeted follow-up audits and local fixes could easily be
  mistaken for an exhaustive freeze-readiness program. That would overstate coverage, hide
  cross-angle patterns, and weaken the rewrite decision. Separating audit from remediation keeps the
  evidence honest and makes the later synthesis capable of answering whether the right next step is
  targeted cleanup, bounded redesign, or a major rewrite.
- Tradeoff: slower immediate patch velocity during the audit program versus a stronger basis for
  high-impact architectural decisions and a lower risk of accidental under- or over-reaction.
- Related Tradeoff: T-0-004.
- Reversal Trigger: the audit-first separation causes unacceptable delay without improving rewrite
  or remediation decisions, or the repo shows that a narrower variant catches the same class of
  failure just as well.
- Supersedes: none

## D-123: Drive the exhaustive pre-freeze audit with a fixed angle order, matrix, and templates

- Date: 2026-03-17
- Status: accepted
- Decision: the `no-ard` exhaustive pre-freeze audit must use a fixed execution framework rather
  than ad hoc report writing.
  - accepted behavior:
    - freeze one audit angle order for the active program:
      - protocol correctness
      - ecosystem parity / interoperability
      - security / misuse resistance
      - crypto/backend-wrapper quality
      - Zig engineering quality
      - performance / memory posture
      - API consistency / determinism
      - docs/examples / discoverability
      - final meta-analysis
    - maintain one hard surface-by-angle coverage ledger in
      `docs/plans/exhaustive-pre-freeze-audit-matrix.md`
    - require dedicated angle reports to use
      `docs/plans/audit-angle-report-template.md`
    - require the final synthesis to use
      `docs/plans/audit-meta-analysis-template.md`
    - define severity and rewrite-pressure interpretation explicitly inside the audit packet
    - do not mark matrix coverage complete without cited report evidence
  - accepted non-goals:
    - freeform angle ordering during the active program
    - vague claims that a surface was reviewed without matrix/report backing
    - skipping from angle reports straight into remediation without the meta-analysis step
- Why: the audit-first rule established the right separation, but execution could still drift
  without harder controls. A fixed order, explicit matrix, and shared templates make the program
  easier to execute thoroughly and much harder to hand-wave.
- Tradeoff: more structure and upfront documentation overhead versus stronger audit completeness,
  clearer residual-risk accounting, and less room for accidental overclaiming.
- Related Tradeoff: T-0-004.
- Reversal Trigger: the added execution framework becomes mostly ceremonial and does not materially
  improve audit thoroughness or honesty.
- Supersedes: none

## D-124: Forbid in-audit fixes, split cryptographic lanes, and require whole-codebase audit coverage

- Date: 2026-03-17
- Status: accepted
- Decision: tighten the active pre-freeze audit program again so it is stricter and more explicit.
  - accepted behavior:
    - no code fixes land during the active multi-angle pre-freeze audit program
    - all findings stay in reports, the matrix, or the working draft until the angle reports and
      meta-analysis complete
    - split cryptographic review into two distinct audit angles:
      - cryptographic correctness / secret handling
      - crypto/backend-wrapper quality
    - the exhaustive audit must cover the entire release-relevant codebase, not only implemented
      NIP modules
    - the matrix must explicitly cover:
      - build and packaging surface
      - exported facade and shared support
      - event/message/filter/key core
      - implemented NIP surfaces
      - crypto backends and derivation boundaries
      - cryptography-bearing protocol consumers
      - internal helpers that affect release confidence
      - examples and discovery surface
      - freeze-critical control and audit docs
    - each audit angle must use the shared per-angle standards as its minimum completion bar
  - accepted non-goals:
    - interrupting the audit program to patch even serious local findings
    - calling the audit exhaustive if only the implemented NIPs were reviewed
    - collapsing cryptographic framing review and backend-wrapper review into one vague lane
- Why: the prior audit-first structure was directionally right, but it still left room for two
  failure modes: drifting back into patch-as-you-go behavior, and under-specifying the actual audit
  surface. Splitting the cryptographic lanes and expanding the matrix to the whole release-relevant
  codebase makes the audit more honest and more likely to produce a reliable rewrite decision.
- Tradeoff: slower short-term response to discovered issues versus a cleaner global picture of
  whether the library wants targeted fixes, bounded redesign, or a major rewrite.
- Related Tradeoff: T-0-004.
- Reversal Trigger: the stricter no-fix rule or expanded surface matrix proves to be overbroad and
  does not materially improve the later remediation decision.
- Supersedes: parts of `D-122` and `D-123` where they allowed narrower angle sets or immediate
  in-audit fixes.

## D-125: Consolidate the libwally backend seam and reconcile the live backend pin/build floor

- Date: 2026-03-17
- Status: accepted
- Decision: close the first post-audit remediation lane by sharpening the approved `libwally`
  boundary in three ways.
  - accepted behavior:
    - move shared `libwally` readiness and BIP32 derivation entry points behind one internal seam:
      - `src/internal/libwally_backend.zig`
    - remove the old indirect `BIP-85` readiness probe through
      `nip06_mnemonic.mnemonic_validate(...)`
    - preserve typed backend-outage semantics on older crypto-bearing leaves by exposing
      `BackendUnavailable` distinctly in:
      - `nip44_get_conversation_key(...)`
      - `delegation_signature_sign(...)`
      - `delegation_signature_verify(...)`
    - reconcile canonical provenance to the live `libwally-core` pin in `build.zig.zon`:
      - commit: `455ec5b0188e1fc76f38c9b7aad7f4e24b421eb4`
      - content hash: `N-V-__8AAAitUgDcU4g8UG0hStyFchfa999eIbWld-EKdpd4`
    - record the approved backend feature floor explicitly:
      - `BUILD_MINIMAL`
      - `BUILD_STANDARD_SECP`
      - `WALLY_ABI_NO_ELEMENTS`
      - direct source floor limited to the files selected in `build.zig`
      - secp dependency remains the separately pinned `bitcoin-core/secp256k1` backend
  - accepted non-goals:
    - widening the public `NIP-06` or `BIP-85` API
    - changing wallet workflow ownership or moving protocol logic into `nzdk`
    - broad crypto-library extraction or major rewrite
- Why: the exhaustive audit and external assurance supplement showed one real redesign cluster:
  local `libwally` readiness and derivation were still fragmented, backend-outage semantics were
  misclassified on older leaves, and the canonical recorded `libwally` provenance no longer matched
  the live build graph. Closing all three in one bounded lane sharpens the backend story without
  expanding the kernel.
- Tradeoff: one extra internal backend module and a small public error-surface expansion versus a
  cleaner derivation seam, more honest outage handling, and truthful backend provenance.
- Related Tradeoff: T-H-ANIP-002, T-H-ANIP-011.
- Reversal Trigger: the approved backend exception is removed entirely or a later bounded primitive
  library supersedes this exact seam without widening the current protocol ownership boundary.
- Supersedes: the stale live-pin portion of `D-035`.

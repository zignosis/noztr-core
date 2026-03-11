# Decision Log

Immutable record of accepted planning decisions.

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
    - local path: `/workspace/pkgs/libnostr-z`
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
  - LLM-first usability evaluation (`OQ-E-006`): in-progress (`docs/plans/llm-usability-pass.md`).
  - security hardening tracker remains canonical: `docs/plans/security-hardening-register.md`.

## D-015: Record Tiger cleanliness and strictness-profile evaluation inputs

- Date: 2026-03-07
- Status: accepted
- Decision: record current implementation hygiene and interoperability evaluation inputs as follows:
  - Tiger hard rules are currently clean for `src/` on hard checks (`>100` columns: none,
    `>70`-line functions: none).
  - strict-width and anti-pattern cleanup remains tracked as quality follow-up where applicable.
  - strictness/interoperability choices remain under evaluation through `OQ-E-006`: strict filter full-hex
    requirement, unknown filter-field rejection, strict relay `OK` status-prefix validation,
    and strict NIP-42 origin matching (path-bound plus `ws`/`wss` distinction).
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
  - `docs/plans/i7-regression-evidence.md`
  - `docs/plans/i7-api-contract-trace-checklist.md`
  - `docs/plans/i7-phase-f-kickoff-handoff.md`
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
  execution guidance in `docs/plans/phase-f-kickoff.md`, including UT-E-003/UT-E-004 burn-down,
  optional corpus review triggers (`UT-E-001`/`A-D-001`), and dual-run gate reminders.
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
  `docs/plans/phase-f-risk-burndown.md`, including baseline snapshot, replay matrix template, command
  evidence, outcomes, and next owners.
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
    - `docs/plans/phase-f-parity-matrix.md`
    - `docs/plans/phase-f-parity-ledger.md`
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

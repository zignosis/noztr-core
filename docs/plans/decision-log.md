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
  and tests), not API shape parity.
- Why: preserve Zig-native API quality and constraints.
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

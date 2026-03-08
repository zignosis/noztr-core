# Security Hardening Register

Date: 2026-03-07

Dedicated status register for implemented security hardening controls and edge-case follow-ups.

## Implemented Hardening Measures

### Crypto Boundary

| Measure | Status | File references | Rationale |
| --- | --- | --- | --- |
| Reduced secp boundary surface and pinned backend revision policy | done | `docs/plans/decision-log.md` (`D-008`), `docs/plans/build-plan.md`, `src/root.zig` | Limits accidental direct backend usage and reduces supply-chain drift risk. |
| Typed outage separation at verify/auth boundaries | done | `docs/plans/decision-log.md` (`D-005`), `src/errors.zig`, `src/nip42_auth.zig` | Preserves deterministic policy decisions by separating invalid input from backend outage. |

### Parser/Lifetime Safety

| Measure | Status | File references | Rationale |
| --- | --- | --- | --- |
| Canonical event runtime shape validation before checked id paths | done | `src/nip01_event.zig`, `src/nip13_pow.zig` | Prevents malformed in-memory event shapes from reaching cryptographic checks. |
| UTF-8 validation guards for strict event/text boundaries | done | `src/nip01_event.zig`, `src/nip01_message.zig`, `src/nip01_filter.zig`, `src/nip11.zig` | Rejects malformed text at trust boundaries to avoid ambiguous behavior. |

### Auth/Session Policy

| Measure | Status | File references | Rationale |
| --- | --- | --- | --- |
| NIP-42 challenge rotation clears authenticated pubkeys | done | `docs/plans/decision-log.md` (`D-006`), `src/nip42_auth.zig` | Prevents stale-auth reuse after challenge changes. |
| `auth_validate_event` expected-challenge bounds guard (empty/oversized rejected) | done | `src/nip42_auth.zig`, `docs/plans/v1-api-contracts.md` | Enforces strict challenge-boundary handling for direct validation call sites. |
| Duplicate required NIP-42 tags rejected (`relay`, `challenge`) | done | `docs/plans/decision-log.md` (`D-006`), `src/nip42_auth.zig` | Removes ambiguity from multi-tag auth payloads. |
| Freshness window rejects future/stale auth timestamps | done | `docs/plans/decision-log.md` (`D-006`), `src/nip42_auth.zig` | Reduces replay acceptance window and enforces deterministic policy. |
| Relay origin match binds normalized path in addition to scheme/host/port | done | `docs/plans/decision-log.md` (`D-013`), `src/nip42_auth.zig` | Closes origin ambiguity by requiring strict relay match on normalized path (`?query`/`#fragment` ignored; missing path normalized to `/`). |
| NIP-42 relay authority parser rejects unbracketed IPv6 authorities | done | `docs/plans/decision-log.md` (`D-013`), `src/nip42_auth.zig` | Prevents ambiguous host/port parsing and keeps IPv6 authority handling strict and deterministic. |

### PoW/Delete Wrappers

| Measure | Status | File references | Rationale |
| --- | --- | --- | --- |
| Checked PoW wrapper couples id validity with PoW checks | done | `docs/plans/decision-log.md` (`D-007`), `src/nip13_pow.zig`, `src/root.zig` | Reduces call-site misuse by enforcing verify-first flow. |
| PoW commitment policy enforces truthfulness and floor (`actual_bits >= commitment >= required_bits`) | done | `docs/plans/decision-log.md` (`D-013`), `src/nip13_pow.zig` | Prevents overstated commitments and declared-target downgrades in strict PoW validation. |
| Checked delete extraction wrapper for relay-safe call sites | done | `docs/plans/decision-log.md` (`D-007`), `src/nip09_delete.zig`, `src/root.zig` | Enforces author-bound delete target checks behind one safe entry point. |

### Transcript Strictness

| Measure | Status | File references | Rationale |
| --- | --- | --- | --- |
| Transcript marker wrappers (`transcript_mark_client_req`, `transcript_apply_relay`) | done | `docs/plans/decision-log.md` (`D-007`), `src/nip01_message.zig`, `src/root.zig` | Constrains transcript transitions to strict, typed state updates. |
| Strict relay `OK` event id lowercase-hex requirement | done | `docs/plans/decision-log.md` (`D-011`), `src/nip01_message.zig` | Removes event-id parse ambiguity in relay acknowledgment paths. |

## Edge-Case Audit History

| Follow-up item | Status | File references | Notes |
| --- | --- | --- | --- |
| normalized-path binding in NIP-42 relay matching (`/` default; query/fragment ignored) | closed | `src/nip42_auth.zig`, `docs/plans/decision-log.md` (`D-013`) | Closed by strict origin comparison on normalized path plus scheme/host/port. |
| unbracketed IPv6 authority rejection in NIP-42 relay matching | closed | `src/nip42_auth.zig`, `docs/plans/decision-log.md` (`D-013`) | Closed by strict authority parser rejection and mismatch tests. |
| canonical event runtime shape/UTF-8 validation guards | closed | `src/nip01_event.zig`, `src/nip13_pow.zig` | Closed by preflight shape guards and UTF-8 checks on checked paths. |
| PoW commitment truthfulness and floor enforcement | closed | `src/nip13_pow.zig`, `docs/plans/decision-log.md` (`D-013`) | Closed by enforcing `actual_bits >= commitment` and `commitment >= required_bits`. |
| `event_compute_id` invalid-runtime-shape typed failure | closed | `src/nip01_event.zig`, `docs/plans/v1-api-contracts.md`, `docs/plans/decision-log.md` (`D-013`) | Closed by replacing all-zero compatibility fallback with explicit typed failure for invalid runtime event shapes. |
| LLM-first usability evaluation sequencing (`OQ-E-006`, `D-009`, `D-014`) | in progress | `docs/plans/llm-usability-pass.md`, `docs/plans/build-plan.md`, `docs/plans/decision-log.md`, `handoff.md` | Started post-security checkpoint; closure criteria tracked in `docs/plans/llm-usability-pass.md` before first RC API freeze. |

## Strictness/Interoperability Matrix (Current, Under Evaluation)

| Topic | Current behavior | Interop posture | Status |
| --- | --- | --- | --- |
| Filter full-hex requirement | strict full-hex validation on strict filter identities/tag values | stricter than permissive parser ecosystems | in evaluation via `OQ-E-006` |
| Unknown filter field handling | unknown filter fields rejected in strict parsing | favors deterministic parsing over permissive forward-compat handling | in evaluation via `OQ-E-006` |
| Relay `OK` status prefix handling | strict prefix-form status validation | may reject ecosystem-variant free-form status text | in evaluation via `OQ-E-006` |
| NIP-42 relay origin policy | strict normalized path binding plus `ws`/`wss` scheme distinction | maximizes origin determinism; may reduce tolerant origin matching | in evaluation via `OQ-E-006` |

## Maintenance Rule

- Keep this register updated whenever security defaults or edge-case follow-up status changes.
- Reflect accepted policy changes in `docs/plans/decision-log.md` first, then mirror status here.

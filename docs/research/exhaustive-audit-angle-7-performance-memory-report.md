---
title: Exhaustive Audit Angle 7 Performance Memory Report
doc_type: report
status: active
owner: noztr
phase: phase-h
read_when:
  - reviewing_exhaustive_audit_angle_results
  - evaluating_performance_posture
depends_on:
  - docs/plans/exhaustive-pre-freeze-audit.md
  - docs/plans/exhaustive-pre-freeze-audit-matrix.md
  - docs/plans/audit-angle-standards.md
canonical: true
---

# Exhaustive Audit Angle 7: Performance / Memory Posture

- date: 2026-03-17
- issue: `no-jacg`
- packet: `no-ard`
- author: Codex

## Purpose

- evaluate whether `noztr`'s current allocation, scratch, copying, and obvious algorithmic choices
  are acceptable for a bounded protocol-kernel library
- distinguish acceptable bounded cost from local inefficiency and from broader redesign pressure
- this angle is a static code review, not a benchmark or profiler run

## Scope

Reviewed directly in this pass:
- `src/nip88_polls.zig`
- `src/nip29_relay_groups.zig`
- `src/nip06_mnemonic.zig`
- `src/nip01_event.zig`
- `src/nip47_wallet_connect.zig`
- `src/nip21_uri.zig`
- `src/nip49_private_key_encryption.zig`
- `src/limits.zig`

Explicit exclusions:
- runtime benchmarks
- allocator tracing
- external relay/runtime performance

## Standards

- `docs/plans/audit-angle-standards.md`
  - allocation posture
  - scratch usage
  - copying behavior on hot paths
  - obvious asymptotic or repeated-scan concerns
  - caller-owned buffer discipline
  - whether current costs are acceptable for a protocol-kernel library

## Evidence Sources

Primary:
- local source in the reviewed modules
- current fixed limits in `src/limits.zig`

Secondary:
- prior accepted ownership posture from `docs/plans/post-audit-improvement-plan.md`

## Coverage

Explicitly checked:
- obvious static hot paths on reducer-style surfaces
- JSON parse/copy posture in shared event parsing
- borrowed-slice versus copied-slice behavior on a high-surface split module
- current scratch discipline on the most obvious crypto-bound memory-heavy path
- repeated-pass behavior on mnemonic validation and seed derivation

Explicitly not checked:
- measured throughput
- cache behavior
- end-to-end SDK or network workloads

Matrix rows touched:
- `Build and packaging surface`: `not applicable`
- `Exported facade and shared support`: `not applicable`
- `Event/message/filter/key core`: `complete`
- `Implemented NIP surfaces in docs/plans/implemented-nip-audit-report.md`: `complete`
- `Derivation and backend boundary`: `complete`
- `Cryptography-bearing protocol consumers`: `complete`
- `Freeze-critical control and audit docs`: `not applicable`

## Findings

### NIP-88 tally reduction still uses quadratic lookup on the main aggregation path

- severity: `medium`
- scope:
  - [nip88_polls.zig](/workspace/projects/noztr/src/nip88_polls.zig#L248)
  - [nip88_polls.zig](/workspace/projects/noztr/src/nip88_polls.zig#L489)
  - [nip88_polls.zig](/workspace/projects/noztr/src/nip88_polls.zig#L534)
  - [nip88_polls.zig](/workspace/projects/noztr/src/nip88_polls.zig#L594)
  - [nip88_polls.zig](/workspace/projects/noztr/src/nip88_polls.zig#L604)
- why it matters:
  - the reducer walks every response, linearly searches the latest-response set by pubkey, then
    linearly searches poll options while counting votes
  - with `tags_max = 2048`, worst-case work is still bounded but can grow into millions of
    comparisons on the one obvious aggregation hotspot
- remediation pressure:
  - targeted fix

### NIP-29 group reducers still rebuild user state with repeated linear membership lookup

- severity: `medium`
- scope:
  - [nip29_relay_groups.zig](/workspace/projects/noztr/src/nip29_relay_groups.zig#L1084)
  - [nip29_relay_groups.zig](/workspace/projects/noztr/src/nip29_relay_groups.zig#L1131)
  - [nip29_relay_groups.zig](/workspace/projects/noztr/src/nip29_relay_groups.zig#L1146)
  - [nip29_relay_groups.zig](/workspace/projects/noztr/src/nip29_relay_groups.zig#L1199)
  - [nip29_relay_groups.zig](/workspace/projects/noztr/src/nip29_relay_groups.zig#L1211)
- why it matters:
  - admin/member snapshot and put-user reducers call `ensure_user_slot(...)` for each user-bearing
    tag or event
  - `ensure_user_slot(...)` linearly scans existing users before inserting, which keeps the posture
    bounded but locally inefficient on the main state-rebuild path
- remediation pressure:
  - targeted fix

### NIP-06 still does repeated full-string passes and linear wordlist scans before backend validation

- severity: `low`
- scope:
  - [nip06_mnemonic.zig](/workspace/projects/noztr/src/nip06_mnemonic.zig#L31)
  - [nip06_mnemonic.zig](/workspace/projects/noztr/src/nip06_mnemonic.zig#L62)
  - [nip06_mnemonic.zig](/workspace/projects/noztr/src/nip06_mnemonic.zig#L221)
  - [nip06_mnemonic.zig](/workspace/projects/noztr/src/nip06_mnemonic.zig#L240)
  - [nip06_mnemonic.zig](/workspace/projects/noztr/src/nip06_mnemonic.zig#L270)
- why it matters:
  - validation and seed derivation normalize, count words, and linearly search the BIP39 wordlist
    before the backend validates again
  - the cost is bounded by `nip06_mnemonic_bytes_max = 256`, so this is local inefficiency, not a
    freeze blocker
- remediation pressure:
  - targeted fix

## Accepted Exceptions

- scope:
  - [nip01_event.zig](/workspace/projects/noztr/src/nip01_event.zig#L50)
  - [nip01_event.zig](/workspace/projects/noztr/src/nip01_event.zig#L526)
  - [nip01_event.zig](/workspace/projects/noztr/src/nip01_event.zig#L541)
- rationale:
  - shared JSON ingress is intentionally scratch-backed and caller-owned
  - the parser prevalidates input, uses a temporary arena for the JSON value tree, then copies the
    owned slices needed for the returned event into caller scratch
- risk:
  - peak memory is higher when callers choose arena-style scratch
- reversal trigger:
  - reopen if measured workloads show this shared-core posture is materially too expensive

- scope:
  - [nip47_wallet_connect.zig](/workspace/projects/noztr/src/nip47_wallet_connect.zig#L1161)
  - [nip47_wallet_connect.zig](/workspace/projects/noztr/src/nip47_wallet_connect.zig#L2153)
  - [nip47_wallet_connect.zig](/workspace/projects/noztr/src/nip47_wallet_connect.zig#L2222)
  - [nip21_uri.zig](/workspace/projects/noztr/src/nip21_uri.zig#L12)
  - [nip49_private_key_encryption.zig](/workspace/projects/noztr/src/nip49_private_key_encryption.zig#L285)
- rationale:
  - these surfaces show the accepted good end of the repo’s posture:
    - borrow from caller-owned scratch where practical
    - keep ownership explicit
    - avoid heap growth
    - use fixed scratch on crypto-heavy paths
- risk:
  - none beyond the normal caller-owned lifetime contract
- reversal trigger:
  - reopen if later API/docs review shows callers are routinely confused about the ownership model

- scope:
  - `NIP-27` scratch-to-capacity tradeoff
- rationale:
  - it is an API tradeoff and not current evidence of a freeze blocker
- risk:
  - callers can still pay extra scratch cost relative to actual match count
- reversal trigger:
  - reopen if consumer evidence shows this tradeoff materially hurts adoption or hot-path memory
    use

## Residual Risk

- this angle is static, so it cannot prove absence of runtime hotspots under real workloads
- the current evidence points to bounded local inefficiency, not systemic performance collapse

## Suggested Remediation Candidates

- targeted fix
  - reduce linear lookup pressure in `NIP-88` tally reduction
- targeted fix
  - reduce repeated linear membership lookup in `NIP-29` group-state reduction
- targeted fix
  - tighten repeated-pass `NIP-06` validation if later priorities justify it
- bounded redesign only if consumer evidence appears
  - revisit the `NIP-27` scratch-to-capacity ownership tradeoff

## Completion Statement

This angle is complete because:
- the obvious reducer and parse hotspots were checked directly
- acceptable bounded costs were separated from real local inefficiencies
- no critical or high performance blocker emerged from static review

Reopen this angle if:
- benchmarks or SDK workloads surface a hotspot not visible from static review
- later API/docs evidence shows the accepted ownership tradeoffs are too costly in practice

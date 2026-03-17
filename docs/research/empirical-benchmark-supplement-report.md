---
title: Empirical Benchmark Supplement Report
doc_type: report
status: active
owner: noztr
phase: phase-h
read_when:
  - reviewing_empirical_benchmark_results
  - revising_post_audit_synthesis
depends_on:
  - docs/plans/empirical-benchmark-supplement.md
  - docs/research/exhaustive-audit-angle-7-performance-memory-report.md
canonical: true
---

# Empirical Benchmark Supplement

- date: 2026-03-17
- issue: `no-m4o2`
- packet: `docs/plans/empirical-benchmark-supplement.md`
- author: Codex

## Purpose

- add measured local workload evidence on top of the completed static performance audit
- test whether the named hotspots still justify remediation or redesign pressure once actually run
- keep the result audit-only and defer all fixes to revised synthesis

## Scope

Benchmarked directly in this pass:
- `nip88_polls.poll_tally_reduce(...)`
- `nip29_relay_groups.group_state_apply_events(...)`
- `nip06_mnemonic.mnemonic_validate(...)`
- `nip06_mnemonic.mnemonic_to_seed(...)`
- `nip06_mnemonic.derive_nostr_secret_key(...)`
- `bip85_derivation.derive_bip39_mnemonic(...)`

Explicit exclusions:
- relay or network workloads
- SDK end-to-end workloads
- allocator tracing
- profiler sampling
- cross-machine comparisons

## Standards

- `docs/guides/IMPLEMENTATION_QUALITY_GATE.md`
- `docs/plans/empirical-benchmark-supplement.md`
- `docs/plans/audit-angle-standards.md`

## Method

- reproducible harness:
  - [exhaustive_audit_empirical.zig](/workspace/projects/noztr/tools/benchmarks/exhaustive_audit_empirical.zig)
- command:
  - `zig build empirical-benchmark -Doptimize=ReleaseFast`
- mode:
  - `ReleaseFast`
- host:
  - Linux `6.18.13-200.fc43.x86_64`
  - CPU: Intel Core i9-14900HX
- discipline:
  - fixed synthetic inputs
  - warmup before timing
  - two full runs recorded
  - measured local `ns/op`

## Coverage

Explicitly checked:
- the two reducer families that static audit identified as local hotspots
- the `NIP-06` validation/derivation path and one `BIP-85` child-mnemonic path
- whether measured cost changes rewrite/remediation pressure

Explicitly not checked:
- throughput under concurrent callers
- memory allocator pressure
- cache-miss or branch-mispredict profiling
- real SDK workloads

## Results

| Case | Run 1 ns/op | Run 2 ns/op | Read |
| --- | ---: | ---: | --- |
| `NIP-88` `poll_tally_reduce` `32 options / 256 responses` | 66,147 | 46,642 | real local hotspot |
| `NIP-88` `poll_tally_reduce` `32 options / 1024 responses` | 291,705 | 321,922 | grows materially with response count |
| `NIP-29` `group_state_apply_events` `256 users` | 51,338 | 48,249 | moderate snapshot-replay cost |
| `NIP-29` `group_state_apply_events` `1024 users` | 557,103 | 538,181 | strongest measured hotspot |
| `NIP-06` `mnemonic_validate` | 55,465 | 54,169 | local text/word checks are cheap |
| `NIP-06` `mnemonic_to_seed` | 1,299,022 | 1,303,116 | backend-heavy path |
| `NIP-06` `derive_nostr_secret_key` | 1,369,380 | 1,354,298 | backend-heavy path |
| `BIP-85` `derive_bip39_mnemonic` | 1,389,010 | 1,349,805 | backend-heavy path |

## Findings

### `NIP-29` is the strongest measured local performance hotspot

- severity: `medium`
- evidence:
  - 256 users: `~48-51 us/op`
  - 1024 users: `~538-557 us/op`
- interpretation:
  - the measured growth supports the static finding that repeated linear membership lookup is the
    strongest reducer hotspot in the current codebase
  - this remains bounded and local, but it is the clearest performance cleanup candidate

### `NIP-88` shows real reducer pressure, but still bounded sub-millisecond local cost

- severity: `medium`
- evidence:
  - 256 responses: `~47-66 us/op`
  - 1024 responses: `~292-322 us/op`
- interpretation:
  - the hotspot is real and scales materially with response count
  - the measured cost supports a targeted cleanup, not redesign language by itself

### `NIP-06` repeated local scans are not the dominant derivation cost

- severity: `low`
- evidence:
  - `mnemonic_validate`: `~54-55 us/op`
  - `mnemonic_to_seed`, `derive_nostr_secret_key`, and `derive_bip39_mnemonic`:
    `~1.30-1.39 ms/op`
- interpretation:
  - once backend work is included, the local repeated-pass/word-scan cost is small relative to the
    crypto/backend path
  - this does not justify a standalone performance-remediation requirement for `NIP-06`
  - any future `NIP-06` cleanup should be coupled to the backend-seam redesign, not treated as a
    separate performance blocker

## Accepted Exceptions

- the bounded caller-owned scratch posture remains accepted
- the isolated `NIP-06` backend state exception still stands
- the empirical data does not challenge the accepted `NIP-05` / `NIP-46` / `NIP-77`
  scratch-backed ingress posture

## Residual Risk

- measurements come from one host in one optimization mode
- no profiler or allocator instrumentation was used
- no real SDK workload was measured
- absolute numbers are machine-specific; relative pressure between cases is the important signal

## Synthesis Impact

- no major rewrite pressure added
- no change to the chosen bounded-redesign-first posture
- does change remediation priority:
  - keep `NIP-29` and `NIP-88` in the targeted performance lane
  - drop standalone `NIP-06` performance cleanup as a required remediation item
  - keep `NIP-06` performance review coupled to the backend-seam redesign only

## Completion Statement

This supplement is complete because:
- the named static hotspots were measured directly
- the result is explicit about what was and was not measured
- the evidence is strong enough to revise the remediation synthesis without landing fixes

---
title: RC Stress And Throughput Supplement Report
doc_type: report
status: active
owner: noztr
phase: phase-h
read_when:
  - reviewing_rc_stress_throughput_results
  - deciding_if_final_rc_closure_is_still_honest
depends_on:
  - docs/plans/rc-stress-throughput-supplement.md
  - docs/research/empirical-benchmark-supplement-report.md
  - docs/research/post-remediation-freeze-recheck-report.md
canonical: true
---

# RC Stress And Throughput Supplement

- date: 2026-03-18
- issue: `no-hd32`
- packet: `docs/plans/rc-stress-throughput-supplement.md`
- author: Codex

## Purpose

- add one final measured repeated-run and bounded concurrent workload pass before RC closure
- challenge the earlier benchmark and freeze-readiness result with stronger local throughput evidence
- keep the result explicit about what it proves and what it does not

## Scope

Benchmarked directly in this pass:
- `nip88_polls.poll_tally_reduce(...)`
- `nip29_relay_groups.group_state_apply_events(...)`
- `nip06_mnemonic.derive_nostr_secret_key(...)`

Explicit exclusions:
- relay or network stress
- SDK end-to-end workloads
- shared mutable caller-state contention
- allocator tracing
- profiler sampling
- long-duration soak work

## Standards

- `docs/guides/IMPLEMENTATION_QUALITY_GATE.md`
- `docs/plans/rc-stress-throughput-supplement.md`
- `docs/plans/audit-angle-standards.md`

## Method

- reproducible harness:
  - [rc_stress_throughput.zig](/workspace/projects/noztr/tools/benchmarks/rc_stress_throughput.zig)
- command:
  - `zig build rc-stress-throughput -Doptimize=ReleaseFast`
- mode:
  - `ReleaseFast`
- host:
  - Linux `6.18.13-200.fc43.x86_64`
  - CPU: Intel Core i9-14900HX
  - logical CPUs reported: `32`
- discipline:
  - fixed synthetic inputs
  - `5` waves per case
  - thread counts: `1`, `4`, `8`
  - independent per-thread contexts
  - measured wall-clock `ns/op` plus aggregate `ops/s`

## Coverage

Explicitly checked:
- repeated-run stability for the named local hotspot families
- bounded concurrent scaling on the pure reducer paths
- bounded concurrent scaling on one representative backend-heavy derivation path
- whether the result changes RC confidence or reopens remediation pressure

Explicitly not checked:
- shared-input aliasing or shared caller-state misuse
- external runtime, relay, or network behavior
- allocator pressure under long-lived process load
- profiler-level hotspot attribution

## Results

| Case | Threads | Iterations / thread | Avg ns/op | Min ns/op | Max ns/op | Ops/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `NIP-88` `poll_tally_reduce` `32 options / 1024 responses` | `1` | `120` | `122,042` | `85,468` | `142,333` | `8,193` |
| `NIP-88` `poll_tally_reduce` `32 options / 1024 responses` | `4` | `80` | `30,073` | `24,131` | `39,893` | `33,251` |
| `NIP-88` `poll_tally_reduce` `32 options / 1024 responses` | `8` | `60` | `14,436` | `14,271` | `14,717` | `69,271` |
| `NIP-29` `group_state_apply_events` `1024 users` | `1` | `120` | `47,292` | `37,186` | `55,647` | `21,145` |
| `NIP-29` `group_state_apply_events` `1024 users` | `4` | `80` | `14,277` | `13,839` | `14,771` | `70,039` |
| `NIP-29` `group_state_apply_events` `1024 users` | `8` | `60` | `7,212` | `7,012` | `7,428` | `138,656` |
| `NIP-06` `derive_nostr_secret_key` | `1` | `120` | `1,311,897` | `1,270,852` | `1,365,542` | `762` |
| `NIP-06` `derive_nostr_secret_key` | `4` | `40` | `426,334` | `376,990` | `444,978` | `2,345` |
| `NIP-06` `derive_nostr_secret_key` | `8` | `20` | `254,715` | `251,467` | `257,626` | `3,925` |

## Findings

### No local collapse or surprise contention appeared on the named reducer paths

- severity: `low`
- evidence:
  - `NIP-88` scaled from about `8.2k ops/s` at `1` thread to about `69.3k ops/s` at `8`
  - `NIP-29` scaled from about `21.1k ops/s` at `1` thread to about `138.7k ops/s` at `8`
- interpretation:
  - the post-remediation reducer posture holds up under bounded concurrent local workloads
  - no new shared-state or scaling blocker appeared on these pure helper families

### The representative backend-heavy derivation path scales materially without obvious outage or lock collapse

- severity: `low`
- evidence:
  - `NIP-06` `derive_nostr_secret_key` scaled from about `762 ops/s` at `1` thread to about
    `3,925 ops/s` at `8`
- interpretation:
  - the sharpened backend seam does not show an obvious concurrency-collapse signal on this local
    workload
  - this does not prove full backend-thread-safety for every future usage pattern, but it does
    improve confidence in the accepted current seam

### The supplement does not reopen remediation or rewrite pressure

- severity: `low`
- evidence:
  - all named cases remained bounded
  - no measured local hotspot regressed into a redesign-level failure mode
  - no runtime or test failure occurred while running the supplement harness or full Zig gates
- interpretation:
  - the supplement strengthens the earlier local performance read
  - it does not change the architecture call or create a new blocker packet by itself

## Accepted Exceptions

- independent per-thread contexts remain the right benchmark posture for this supplement
  - rationale:
    - `noztr` is a bounded protocol library, not a shared-state runtime
  - reversal trigger:
    - reopen if downstream consumer evidence shows a real shared-state contention pattern that the
      current supplement does not model

## Residual Risk

- this is still local workload evidence, not production relay stress evidence
- it does not prove allocator, cache, or branch behavior under long-duration process load
- it does not prove end-to-end SDK throughput
- absolute numbers are host-specific; the important signal is bounded behavior and scaling shape

## Synthesis Impact

- no remediation lane reopens
- no major rewrite pressure is added
- no new blocker packet is justified from this supplement alone
- the RC review remains locally positive, but final closure still depends on downstream `nzdk`
  implementation feedback

## Completion Statement

This supplement is complete because:
- the named hotspot families were rerun under stronger repeated-run and bounded concurrent loads
- the result is explicit about method, limits, and residual risk
- the evidence is strong enough to inform RC confidence honestly without pretending to prove more
  than it does

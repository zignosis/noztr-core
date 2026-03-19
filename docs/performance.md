---
title: Performance
doc_type: release_note
status: active
owner: noztr
read_when:
  - evaluating_noztr_performance
  - rerunning_public_benchmarks
  - understanding_local_throughput_expectations
canonical: true
---

# Performance

`noztr` is optimized as a bounded protocol kernel, not as a full relay runtime or end-to-end network
stack.

That distinction matters when reading the performance numbers.

## What The Library Is Trying To Be Fast At

`noztr` is built to be fast at:

- local parsing and validation
- deterministic serialization and verification helpers
- pure reducers
- bounded protocol transformations
- controlled cryptographic helper flows

It is not trying to measure:

- websocket or relay throughput
- end-to-end network latency
- database or storage behavior
- full application workflow throughput

## Current Measured Evidence

The strongest public measurements currently come from the empirical benchmark and RC
stress/throughput supplements.

Representative results on the audit host:

| Workload | Profile | Threads | Approx. rate |
| --- | --- | --- | --- |
| `NIP-88` `poll_tally_reduce` with `32` options and `1024` responses | standard | `1` | `11.7k ops/s` |
| `NIP-88` `poll_tally_reduce` with `32` options and `1024` responses | standard | `8` | `65.1k ops/s` |
| `NIP-29` `group_state_apply_events` with `1024` users | standard | `1` | `22.4k ops/s` |
| `NIP-29` `group_state_apply_events` with `1024` users | standard | `8` | `123.3k ops/s` |
| `NIP-06` `derive_nostr_secret_key` | standard | `1` | `724 ops/s` |
| `NIP-06` `derive_nostr_secret_key` | standard | `8` | `3.41k ops/s` |
| `NIP-88` `poll_tally_reduce` with `32` options and `1024` responses | soak | `8` | `77.0k ops/s` |
| `NIP-29` `group_state_apply_events` with `1024` users | soak | `8` | `155.6k ops/s` |
| `NIP-06` `derive_nostr_secret_key` | soak | `8` | `4.76k ops/s` |

## What Those Numbers Mean

- local reducer and helper hotspots are comfortably in fast local-library territory
- `NIP-29` and `NIP-88` scale well under bounded concurrent local load
- `NIP-06` is much slower because it is backend-heavy and cryptographic by nature, not because of
  unusual local protocol overhead
- the current evidence did not show local collapse or surprising contention in the named workloads

## What These Numbers Do Not Prove

These measurements are intentionally narrower than a production-scale relay or SDK benchmark.

They do not prove:

- full production relay throughput
- end-to-end client or SDK performance
- network or websocket behavior
- storage or cache behavior
- behavior on every machine class

So the honest claim is:

- `noztr` is a strong-performing protocol kernel
- it is not yet claiming full application-stack or relay-stack stress proof

## How To Rerun The Public Evidence

```bash
zig build empirical-benchmark -Doptimize=ReleaseFast
zig build rc-stress-throughput -Doptimize=ReleaseFast
zig build rc-stress-throughput-soak -Doptimize=ReleaseFast
zig build rc-stress-throughput-csv -Doptimize=ReleaseFast
zig build rc-stress-throughput-markdown -Doptimize=ReleaseFast
```

## How To Use This Page

If you are deciding whether `noztr` fits your system:

- use this page to understand local kernel expectations
- use [scope-and-tradeoffs.md](/workspace/projects/noztr/docs/scope-and-tradeoffs.md) to
  confirm the library matches your architecture
- use [examples/README.md](/workspace/projects/noztr/examples/README.md) to find the exact
  high-value surface you care about

If you want broad workflow or network throughput out of the box, `noztr` is the wrong layer to
judge by that requirement alone.

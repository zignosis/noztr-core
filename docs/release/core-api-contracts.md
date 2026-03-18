---
title: Core API Contracts
doc_type: release_reference
status: active
owner: noztr
read_when:
  - learning_core_noztr_surface
  - routing_event_filter_message_work
  - onboarding_public_consumers
canonical: true
---

# Core API Contracts

This is the public-facing route into the oldest and most central `noztr` surfaces.

Use it for:

- events
- filters
- client and relay messages
- auth / protected-event checks
- deletion helpers
- proof-of-work helpers

For newer or more specialized surfaces, use
[contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md).

## Core Surface

| Job | Module | Start here | Example |
| --- | --- | --- | --- |
| Parse, serialize, sign, verify, or inspect events | `nip01_event` | root export `noztr.nip01_event` | [nip01_example.zig](/workspace/projects/noztr/examples/nip01_example.zig) |
| Parse filters and test event matching | `nip01_filter` | root export `noztr.nip01_filter` | [nip01_example.zig](/workspace/projects/noztr/examples/nip01_example.zig) |
| Parse or serialize client/relay messages | `nip01_message` | root export `noztr.nip01_message` | [nip01_example.zig](/workspace/projects/noztr/examples/nip01_example.zig) |
| Validate auth events and protected-event access | `nip42_auth`, `nip70_protected` | root exports `noztr.nip42_auth`, `noztr.nip70_protected` | [nip42_example.zig](/workspace/projects/noztr/examples/nip42_example.zig), [nip70_example.zig](/workspace/projects/noztr/examples/nip70_example.zig) |
| Extract deletion targets and evaluate delete applicability | `nip09_delete` | root export `noztr.nip09_delete` | [nip09_example.zig](/workspace/projects/noztr/examples/nip09_example.zig) |
| Check or build PoW-related behavior | `nip13_pow` | root export `noztr.nip13_pow` | [nip13_example.zig](/workspace/projects/noztr/examples/nip13_example.zig) |

## Contract Expectations

- public trust-boundary functions use typed errors
- invalid input and capacity failures are intentionally kept distinct
- checked helpers are preferred at boundary ingress
- examples are part of the public teaching surface

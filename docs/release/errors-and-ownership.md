---
title: Errors And Ownership
doc_type: release_guide
status: active
owner: noztr
read_when:
  - understanding_public_failure_contracts
  - understanding_buffer_and_scratch_ownership
  - onboarding_llms_and_humans
canonical: true
---

# Errors And Ownership

This page explains two public contracts that matter across almost every `noztr` surface:

- who owns buffers, slices, and scratch space
- how public failures are classified

Use it alongside:

- [core-api-contracts.md](/workspace/projects/noztr/docs/release/core-api-contracts.md)
- [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)
- [examples/README.md](/workspace/projects/noztr/examples/README.md)

## Ownership Model

`noztr` is a protocol kernel. Its public surface is intentionally explicit about memory and buffer
responsibility.

The default expectation is:

- callers provide output buffers
- callers provide scratch buffers when a surface needs temporary workspace
- returned slices usually borrow from caller-owned input or caller-owned output
- the library avoids a heap-first public API style

In practice this means:

- read the function signature carefully
- size output buffers using the documented limits for the surface
- treat output slices as valid only as long as the underlying caller-owned storage remains valid
- do not assume hidden background ownership or long-lived retained allocations

Useful public starting points:

- shared limits: `noztr.limits`
- shared error namespace: `noztr.errors`
- strict core example: [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig)
- wallet/key example: [wallet_recipe.zig](/workspace/projects/noztr/examples/wallet_recipe.zig)

## Error Model

Public trust-boundary functions use typed errors instead of permissive skip-or-null behavior.

The library tries to keep these categories distinct:

- invalid input
  - malformed, contradictory, non-canonical, or unsupported caller input
- capacity failure
  - caller-provided output or scratch storage is too small
- backend outage
  - an approved crypto backend is unavailable or not usable
- policy or support boundary
  - optional or intentionally unsupported behavior is outside the accepted kernel contract

The public contract goal is simple:

- invalid input should fail as invalid input
- capacity shortages should fail as capacity shortages
- backend outages should not be misreported as caller blame

## Practical Reading Rule

When you open a new surface, check three things in this order:

1. What inputs are caller-controlled?
2. What buffers or scratch regions must the caller provide?
3. Which failures mean "bad input" versus "buffer too small" versus "backend unavailable"?

That reading order will prevent most misuse.

## What To Expect From Examples

Examples are part of the public contract surface, not only demos.

- direct examples show the intended happy path
- hostile examples show the intended failure contract

For boundary-heavy surfaces, read both.

Good first pairs:

- core checked flow:
  - [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig)
  - [nip42_adversarial_example.zig](/workspace/projects/noztr/examples/nip42_adversarial_example.zig)
- remote signing:
  - [remote_signing_recipe.zig](/workspace/projects/noztr/examples/remote_signing_recipe.zig)
  - [remote_signing_adversarial_example.zig](/workspace/projects/noztr/examples/remote_signing_adversarial_example.zig)
- gift wrap:
  - [nip17_wrap_recipe.zig](/workspace/projects/noztr/examples/nip17_wrap_recipe.zig)
  - [nip59_adversarial_example.zig](/workspace/projects/noztr/examples/nip59_adversarial_example.zig)
- wallet connect:
  - [nip47_example.zig](/workspace/projects/noztr/examples/nip47_example.zig)
  - [wallet_connect_adversarial_example.zig](/workspace/projects/noztr/examples/wallet_connect_adversarial_example.zig)
- HTTP auth:
  - [nip98_example.zig](/workspace/projects/noztr/examples/nip98_example.zig)
  - [http_auth_adversarial_example.zig](/workspace/projects/noztr/examples/http_auth_adversarial_example.zig)

## What This Does Not Mean

This page does not promise that every module uses exactly the same concrete error enum shape.

It does mean the library tries to preserve the same release-facing discipline:

- explicit ownership
- bounded caller-controlled buffers
- typed failure causes
- no silent fallback from malformed input to "best effort"

## Next Step

- for task routing, use [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)
- for module browsing, use [api-reference.md](/workspace/projects/noztr/docs/release/api-reference.md)
- for example routing, use [examples/README.md](/workspace/projects/noztr/examples/README.md)

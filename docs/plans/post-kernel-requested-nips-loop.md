# Post-Kernel Requested NIP Loop

Date: 2026-03-15

Purpose: classify the newly requested NIPs after the current kernel-complete baseline and define
the serial research -> implementation -> review loop for each item.

## Requested Set

- `40`
- `47`
- `49`
- `64`
- `88`
- `98`
- `92`
- `94`
- `99`
- `B0`
- `B7`
- `C0`

## Current Call

- `NIP-40` is already implemented in `src/nip40_expire.zig`.
  It enters this loop only as a review checkpoint, not as new implementation work.
- `NIP-47`, `NIP-98`, and `NIP-B7` are split surfaces.
  `noztr` owns only the deterministic protocol/kernel slice.
  `nzdk` owns transport, orchestration, wallet/file-service workflow, and runtime policy.
- `NIP-49`, `NIP-64`, `NIP-88`, `NIP-92`, `NIP-94`, `NIP-99`, `NIP-B0`, and `NIP-C0` are good
  protocol-kernel fits for bounded parse/build/validate helpers and any pure fixed-capacity
  reducers they clearly require.

## Classification Matrix

| NIP | State | Placement | `noztr` slice | `nzdk` / app slice | Execution bucket |
| --- | --- | --- | --- | --- | --- |
| `40` | already implemented | `noztr` | keep current expiration parse/check helpers and reconfirm parity/strictness | event-retention policy and client filtering remain above the kernel | review-only |
| `47` | not started | split | NWC URI, info/request/response/notification event parse/build/validate, typed method/result contracts, encryption-negotiation metadata, bounded event/tag checks | relay lifecycle, wallet service orchestration, payment workflow, notification handling, wallet API bridging | split-high |
| `49` | not started | `noztr` | bounded private-key encrypt/decrypt, NFKC normalization boundary, typed parameter/flag handling, serialized NIP-49 payload contract | password UX, secret storage/import/export, recovery policy | kernel-medium |
| `64` | not started | `noztr` | bounded PGN note validation helpers, direct tag/build support, optional pure PGN-shape checks that stay deterministic | board rendering, move playback, engine integration, game UX | kernel-low |
| `88` | not started | `noztr` | poll event/response parse/build helpers, poll-type rules, bounded pure vote-tally reducer | poll publish UX, relay fetches, live result refresh, voter filters | kernel-medium |
| `92` | complete | `noztr` | bounded per-`imeta` parse/build/validate, exact URL-in-content matching, and NIP-94 field reuse for supported metadata semantics | media fetch, preview generation, upload flow, attachment UX | kernel-medium |
| `94` | complete | `noztr` | bounded file-metadata event parse/build/validate, typed required URL/lowercase MIME/hash handling, exact supported tag shapes, repeated fallback support, and optional metadata/image references | file upload/download flow, preview fetch, hosting service integration | kernel-low |
| `98` | not started | split | bounded auth event parse/build/validate, exact URL/method/payload-hash helpers, optional auth-header encode/decode glue | HTTP client/server middleware, request execution, challenge/session handling | split-medium |
| `99` | complete | `noztr` | bounded listing metadata parse/build/validate, draft/inactive distinction, price/status tag handling, ordered images/hashtags, and ignored unrelated tags | listing publish UX, search, inventory/state workflows, commerce extensions | kernel-medium |
| `B0` | complete | `noztr` | bounded web-bookmark parse/build helpers around `39701`, required scheme-less `d`, optional `title` / `published_at` / `t`, ignored unrelated tags, and bounded UTF-8 content | bookmark sync, browser integration, preview/render policy | kernel-low |
| `B7` | not started | split | bounded `kind:10063` Blossom server-list parse/build helpers and deterministic fallback URL/path derivation where protocol-shaped | BUD fetch/upload/download flow, existence checks, caching, media workflow | split-medium |
| `C0` | not started | `noztr` | bounded code-snippet parse/build helpers for language/name/extension/repo metadata and deterministic repo reference validation | syntax highlighting, run/share workflow, editor integration | kernel-low |

## Recommended Serial Order

1. `40` review-only checkpoint
2. `94`
3. `92`
4. `99`
5. `B0`
6. `C0`
7. `64`
8. `88`
9. `49`
10. `98`
11. `47`
12. `B7`

Rationale:
- `94` before `92` because `imeta` reuses NIP-94 fields.
- content/metadata NIPs come before crypto- or transport-heavy NIPs.
- split surfaces (`98`, `47`, `B7`) stay later so the kernel boundary is exercised only after the
  lower-ambiguity helpers are stable.

## Per-NIP Execution Loop

Run this loop for each NIP, serially, without overlap:

1. Research and freeze
   - read the vendored NIP text in `docs/nips/`
   - verify current wording against the official mirror / primary source
   - inspect `rust-nostr`, `nostr-tools`, and applesauce behavior where relevant
   - freeze the exact `noztr` slice, explicit non-goals, and likely example surface
   - freeze a short spec-to-contract checklist:
     - supported kinds
     - required tags / fields
     - optional tags / fields
     - multiplicity / ordering rules
     - normalization / canonicalization rules
     - ignored / unsupported shapes
   - freeze an explicit invalid-vs-capacity matrix for each new public builder/validator boundary
   - if reference lanes are `LIB_UNSUPPORTED` or weak, freeze a reject corpus before coding:
     - arbitrary-but-delimited nonsense
     - malformed section/tag separators
     - overlong fields
     - contradictory optional metadata where applicable
     - debug-vs-release equivalent invalid-input failures
   - record any ambiguity before implementation starts

2. Implement the frozen kernel slice
   - keep the code bounded, deterministic, static-capacity, and KISS
   - do not pull SDK/workflow concerns into the kernel
   - add direct examples while implementing, not as an afterthought
   - add negative fixtures and hostile transcripts where the surface warrants them

3. Review A: correctness / parity / trust boundary
   - spec correctness
   - parity/evidence against `rust-nostr`, `nostr-tools`, and applesauce where relevant
   - security / trust-boundary behavior
   - unnecessary strictness

4. Fix Review A findings

5. Review B: boundary / usability / overengineering
   - `noztr` vs `nzdk` ownership check
   - KISS and overengineering check
   - LLM/human usability check
   - examples and public doc comments check

6. Fix Review B findings

7. Adversarial audit
   - challenge builder/parser symmetry
   - challenge public error semantics
   - run per-field negative corpus
   - run hostile or contradictory transcripts / fixtures where relevant
   - for tokenized or sectioned grammars, challenge nonsense tokens and separator discipline
   - if references are `LIB_UNSUPPORTED`, do one extra spec-first challenge pass

8. Close the NIP with green gates
   - `zig build test --summary all`
   - `zig build`
   - parity/evidence lanes updated as appropriate
   - active docs updated
   - examples updated
   - one scoped git commit for the NIP before moving on

## Meta Loop Rule

- Only one requested NIP may be `in_progress` at a time.
- Do not start the next NIP until the current one has:
  - frozen research scope
  - implementation complete
  - Review A complete
  - Review B complete
  - adversarial audit complete
  - green gates
  - updated docs/examples
  - a scoped git commit
- Split NIPs must stop at the kernel boundary.
  SDK transport/workflow work is recorded for `nzdk`, not implemented ad hoc in `noztr`.

## Required Review Outputs Per NIP

- one short research/freeze note in the active planning docs or handoff
- one Review A record
- one Review B record
- one explicit statement of what remains SDK-side, if the NIP is split

## Example Requirement

Every newly implemented NIP in this loop must land with:

- at least one direct per-NIP example in `examples/`
- at least one invalid or hostile fixture/example when the NIP has a trust-boundary surface
- README index coverage in `examples/README.md`
- recipe updates if the NIP materially affects SDK-facing flows

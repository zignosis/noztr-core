# v1 libnostr-z Deep Study (Phase C3)

Date: 2026-03-05

Scope: H1-selected NIPs and v1 build-plan modules only.

## Source Provenance

- Local mirror path: `/workspace/pkgs/nostr/libnostr-z`
- Origin URL: `git@github.com:privkeyio/libnostr-z.git`
- Commit hash: `a849dc804521801971f42d71c172aa681ecdc573`
- Pin date: `2026-03-04` (frozen by `D-001`)
- Reproducibility note:
  - Verify snapshot with:
    - `git -C /workspace/pkgs/nostr/libnostr-z remote get-url origin`
    - `git -C /workspace/pkgs/nostr/libnostr-z rev-parse HEAD`
  - Study is valid only for this pinned commit and must be re-run after any `D-001` refresh.

## Decisions

- `C3-001`: adopt libnostr-z behavioral invariants for v1 parity-core/parity-optional surfaces only
  when they are compatible with strict defaults (`D-003`) and bounded Zig runtime constraints.
- `C3-002`: adapt libnostr-z module boundaries and transcript patterns to caller-owned buffers and
  explicit error contracts; do not copy allocator-heavy ownership models.
- `C3-003`: reject libnostr-z dependency/runtime assumptions that violate stdlib-only and static
  allocation policy (noscrypt/OpenSSL/C wrapper/StringZilla/dynamic runtime collections).
- `C3-004`: treat libnostr-z as behavior and edge-case evidence, not API-shape authority (`D-002`).

## Parity Gap Map (v1 Scope)

| v1 module | Scope class | libnostr-z evidence | Coverage status | Gap and enforceable recommendation |
| --- | --- | --- | --- | --- |
| `nip01_event` | parity-core | `/workspace/pkgs/nostr/libnostr-z/src/event.zig`, `/workspace/pkgs/nostr/libnostr-z/src/replaceable.zig` | partial | Keep canonical id/signature/replaceable ordering behavior, but replace permissive parsing (uppercase tags, nullable expiration parse) with strict typed errors and bounded fixed-capacity event structs. |
| `nip01_filter` | parity-core | `/workspace/pkgs/nostr/libnostr-z/src/filter.zig`, `/workspace/pkgs/nostr/libnostr-z/src/messages.zig` | partial | Preserve filter AND/OR semantics and `#x` handling, but move from heap-backed slices to fixed limits and reject invalid/malformed filter fields in strict mode. |
| `nip01_message` | parity-core | `/workspace/pkgs/nostr/libnostr-z/src/messages.zig` | partial | Preserve message enum grammar (`EVENT/REQ/CLOSE/AUTH/COUNT/NEG-*`) and transcript serialization patterns, but enforce exact arity/type checks and eliminate parse-time allocations on hot paths. |
| `nip42_auth` | parity-core | `/workspace/pkgs/nostr/libnostr-z/src/auth.zig` | partial | Preserve relay/challenge tag extraction and URL normalization checks, but add explicit auth-event validator (`kind=22242`, timestamp window, signature checked upstream, relay/challenge match typed failures). |
| `nip70_protected` | parity-core | `/workspace/pkgs/nostr/libnostr-z/src/event.zig` | partial | Keep exact protected-tag detection (`["-"]` only), and add dedicated acceptance gate module bound to authenticated pubkey context; default deny when unauthenticated. |
| `nip09_delete` | parity-core | `/workspace/pkgs/nostr/libnostr-z/src/event.zig` | gap | libnostr-z exposes only `kind=5` detection and `e` extraction; implement full author-bound delete policy for `e`/`a` coordinates and strict empty-target rejection in `nip09_delete`. |
| `nip40_expire` | parity-core | `/workspace/pkgs/nostr/libnostr-z/src/event.zig` | partial | Preserve expiration tag presence semantics, but reject malformed `expiration` values instead of silently treating parse failure as non-expired. |
| `nip13_pow` | parity-core | `/workspace/pkgs/nostr/libnostr-z/src/pow.zig` | partial | Preserve leading-zero-bit and nonce-tag behavior, but remove page-allocator JSON parse dependency from validator path and use strict typed nonce/target parse outcomes. |
| `nip19_bech32` | parity-optional | `/workspace/pkgs/nostr/libnostr-z/src/bech32.zig` | partial | Preserve bech32 checksum, mixed-case rejection, and TLV decode shape, but enforce strict required/optional TLV validation for v1 entities and avoid allocator ownership in core decode path. |
| `nip21_uri` | parity-optional | `/workspace/pkgs/nostr/libnostr-z/src/nip21.zig` | parity-ready | Keep `nostr:` scheme requirement and `nsec` rejection behavior; keep decoded-entity typing but route ownership to caller buffers in core APIs. |
| `nip02_contacts` | parity-optional | `/workspace/pkgs/nostr/libnostr-z/src/event.zig` (kind constants only) | gap | No dedicated kind-3 contact extraction module; implement strict `p`-tag extraction and malformed-pubkey error paths in `nip02_contacts`. |
| `nip65_relays` | parity-optional | `/workspace/pkgs/nostr/libnostr-z/src/relay_metadata.zig` | partial | Preserve kind-10002 parsing and marker semantics (`read`/`write`/empty), but reject unknown marker tokens and malformed relay URLs explicitly in strict mode. |
| `nip44` | parity-core | `/workspace/pkgs/nostr/libnostr-z/src/crypto.zig` | partial | Preserve v2 framing/padding/range gates and decrypt check order, but reject dependency-backed cryptography and allocation-heavy payload flow; implement stdlib-only bounded NIP-44 contract in `noztr`. |
| `nip59_wrap` | parity-core | `/workspace/pkgs/nostr/libnostr-z/src/nip59.zig` | partial | Preserve unwrap stage ordering (`wrap -> seal -> rumor`) and signature checks, but add strict rumor constraints and deterministic timestamp policy hooks without heap growth. |
| `nip45_count` | parity-optional | `/workspace/pkgs/nostr/libnostr-z/src/messages.zig` | partial | Preserve COUNT request/response grammar, but add strict optional metadata handling (`approximate`, `hll`) and explicit malformed object errors. |
| `nip50_search` | parity-optional | `/workspace/pkgs/nostr/libnostr-z/src/filter.zig`, `/workspace/pkgs/nostr/libnostr-z/src/utils.zig` | partial | Preserve optional `search` field carriage and token match utility, but isolate from core parser and keep extension-gated semantics only. |
| `nip77_negentropy` | parity-optional | `/workspace/pkgs/nostr/libnostr-z/src/messages.zig`, `/workspace/pkgs/nostr/libnostr-z/src/negentropy.zig` | partial | Preserve NEG message family and item ordering (`timestamp`,`id`), but replace dynamic storage/maps with bounded static structures and strict v1 framing policy in extension module. |
| `nip11` | parity-core | `/workspace/pkgs/nostr/libnostr-z/src/nip11.zig` | partial | Preserve partial-document acceptance and known-field extraction, but add strict known-type validation and bounded parser contracts for structured sub-objects. |

## Adopt / Adapt / Reject

| Candidate | Decision | Evidence (libnostr-z source) | v1 modules impacted | Enforceable action |
| --- | --- | --- | --- | --- |
| Root facade + feature-oriented files | Adopt | `/workspace/pkgs/nostr/libnostr-z/src/root.zig` | all v1 modules | Keep one-file-per-feature export surface in `src/root.zig` while maintaining module-specific contracts. |
| Replaceable tie-break (`created_at`, then lexical `id`) | Adopt | `/workspace/pkgs/nostr/libnostr-z/src/replaceable.zig` | `nip01_event` | Encode deterministic replacement helper with direct vectors for equal-timestamp branch behavior. |
| Message grammar enums for client/relay channels | Adopt | `/workspace/pkgs/nostr/libnostr-z/src/messages.zig` | `nip01_message`, `nip45_count`, `nip77_negentropy` | Keep explicit union-style message types and exact formatter helpers for transcript parity. |
| NIP-21 strict `nostr:` parsing with `nsec` deny | Adopt | `/workspace/pkgs/nostr/libnostr-z/src/nip21.zig` | `nip21_uri` | Keep strict scheme + secret-key rejection default and typed URI decode outcomes. |
| NIP-65 marker model (`read`/`write`/both) | Adapt | `/workspace/pkgs/nostr/libnostr-z/src/relay_metadata.zig` | `nip65_relays` | Keep marker semantics but add strict reject for unknown marker tokens and invalid URL forms. |
| NIP-44 algorithm order and range checks | Adapt | `/workspace/pkgs/nostr/libnostr-z/src/crypto.zig` | `nip44`, `nip59_wrap` | Preserve v2 check order and framing limits; reimplement with stdlib-only crypto and caller-owned buffers. |
| NIP-77 reconciliation ordering/state flow | Adapt | `/workspace/pkgs/nostr/libnostr-z/src/negentropy.zig` | `nip77_negentropy` | Keep protocol ordering and mode flow while replacing dynamic lists/maps with bounded structures and explicit limits. |
| noscrypt/OpenSSL C-backed crypto stack | Reject | `/workspace/pkgs/nostr/libnostr-z/build.zig`, `/workspace/pkgs/nostr/libnostr-z/src/crypto.zig` | `nip01_event`, `nip44`, `nip59_wrap` | Do not link C/system crypto libs; implement cryptographic boundaries with Zig stdlib only. |
| StringZilla + C wrapper dependency path | Reject | `/workspace/pkgs/nostr/libnostr-z/build.zig`, `/workspace/pkgs/nostr/libnostr-z/build.zig.zon`, `/workspace/pkgs/nostr/libnostr-z/src/stringzilla.zig` | hashing/serialization paths | Remove external string library assumptions; use stdlib hashing/serialization primitives. |
| Heap-first runtime collections in hot parsers | Reject | `/workspace/pkgs/nostr/libnostr-z/src/event.zig`, `/workspace/pkgs/nostr/libnostr-z/src/filter.zig`, `/workspace/pkgs/nostr/libnostr-z/src/messages.zig`, `/workspace/pkgs/nostr/libnostr-z/src/negentropy.zig` | all v1 modules | Replace `ArrayListUnmanaged`, `AutoHashMap`, ad hoc `allocator.dupe` usage in runtime parse paths with fixed-capacity caller-owned storage. |

## Edge Cases to Preserve for Parity Behavior

- Replaceable/addressable ordering rule and equal-timestamp lexical tie-break must stay deterministic
  (`/workspace/pkgs/nostr/libnostr-z/src/replaceable.zig`).
- Protected event tag semantics must remain exact: only tag shape `["-"]` sets protected status; extra
  tag elements are not protected (`/workspace/pkgs/nostr/libnostr-z/src/event.zig`).
- COUNT and NEG message grammar must preserve canonical wire names and payload framing behavior
  (`/workspace/pkgs/nostr/libnostr-z/src/messages.zig`).
- NIP-21 must reject `nsec` even when scheme and checksum decode pass
  (`/workspace/pkgs/nostr/libnostr-z/src/nip21.zig`).
- NIP-13 committed-difficulty behavior must preserve "missing target means no commitment check"
  semantics while still enforcing requested minimum difficulty (`/workspace/pkgs/nostr/libnostr-z/src/pow.zig`).
- NIP-44 decrypt gate ordering must stay strict: payload length checks, version check, MAC validation,
  decrypt, then padding validation (`/workspace/pkgs/nostr/libnostr-z/src/crypto.zig`).
- NIP-77 item ordering must stay timestamp-ascending, id-lexical for equal timestamps
  (`/workspace/pkgs/nostr/libnostr-z/src/negentropy.zig`).

## Rejected Dependency and Runtime Assumptions

- External dependency graph is incompatible with `noztr` defaults:
  - `noscrypt` dependency and C header imports (`/workspace/pkgs/nostr/libnostr-z/build.zig`,
    `/workspace/pkgs/nostr/libnostr-z/src/crypto.zig`).
  - `stringzilla` dependency and C wrapper build (`/workspace/pkgs/nostr/libnostr-z/build.zig`,
    `/workspace/pkgs/nostr/libnostr-z/build.zig.zon`).
  - OpenSSL system link requirements (`ssl`, `crypto`) (`/workspace/pkgs/nostr/libnostr-z/build.zig`).
- Runtime assumptions rejected for v1 kernel:
  - page allocator defaults in parse paths (`/workspace/pkgs/nostr/libnostr-z/src/event.zig`,
    `/workspace/pkgs/nostr/libnostr-z/src/pow.zig`).
  - unbounded/dynamic collection growth in core protocol paths (`/workspace/pkgs/nostr/libnostr-z/src/filter.zig`,
    `/workspace/pkgs/nostr/libnostr-z/src/messages.zig`, `/workspace/pkgs/nostr/libnostr-z/src/negentropy.zig`).
  - global mutable crypto context lifecycle (`/workspace/pkgs/nostr/libnostr-z/src/crypto.zig`) as a
    mandatory runtime dependency for all event verify/sign operations.

## Ambiguity Checkpoint

`A-C3-001`
- Topic: strictness for uppercase single-letter tag keys (`E/P/T`) in event/filter parsing.
- Impact: high.
- Status: resolved.
- Default: strict v1 parser treats tag keys as case-sensitive protocol data and rejects unsupported
  uppercase compatibility behavior in default mode.
- Owner: active phase owner.

`A-C3-002`
- Topic: acceptance depth for NIP-44 implementation parity when reference uses external crypto backend.
- Impact: high.
- Status: resolved.
- Default: preserve algorithm/vector behavior parity only; reject backend/runtime parity assumptions.
- Owner: active phase owner.

`A-C3-003`
- Topic: optional NIP depth for `nip45_count` metadata (`approximate`, `hll`) in first strict API.
- Impact: medium.
- Status: accepted-risk.
- Default: include typed fields and validation hooks in contracts; final vector depth remains Phase D gate.
- Owner: active phase owner.

Ambiguity checkpoint result: high-impact `decision-needed` count = 0.

## Tradeoffs

## Tradeoff T-C3-001: Behavioral reuse versus dependency/runtime reuse

- Context: libnostr-z offers broad parity behavior with external crypto/C dependencies.
- Options:
  - O1: reuse libnostr-z behavior and dependency/runtime stack.
  - O2: reuse behavior contracts only and reimplement internals under stdlib-only bounded runtime.
- Decision: O2.
- Benefits: preserves parity goals while satisfying `D-001`/`D-003`/`P06` constraints.
- Costs: more implementation effort and translation risk.
- Risks: subtle behavior drift during translation.
- Mitigations: map each adopted behavior to explicit vectors in Phase D.
- Reversal Trigger: repeated parity failures demonstrate behavior cannot be retained without backend reuse.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: all v1 modules, especially `nip44`, `nip59_wrap`, `nip01_event`.

## Tradeoff T-C3-002: Strict parser defaults versus compatibility tolerance

- Context: libnostr-z accepts permissive patterns (for example mixed tag-case and malformed-value skips).
- Options:
  - O1: preserve permissive parser behavior in default mode.
  - O2: keep strict default, place compatibility in explicit opt-in adapters only.
- Decision: O2.
- Benefits: deterministic failures and lower trust-boundary ambiguity.
- Costs: compatibility users need explicit adapter path.
- Risks: ecosystem friction with permissive peers.
- Mitigations: document narrow compatibility hooks with forcing tests, never default-enabled.
- Reversal Trigger: high-value interop blockers cannot be addressed without default permissiveness.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: `nip01_event`, `nip01_filter`, `nip01_message`, `nip65_relays`.

## Tradeoff T-C3-003: Full optional-NIP parity depth versus phased extension isolation

- Context: libnostr-z mixes optional channels into core parsing/runtime surfaces.
- Options:
  - O1: include optional-NIP depth directly in core parser flows.
  - O2: preserve optional behavior parity via dedicated extension modules and explicit gates.
- Decision: O2.
- Benefits: protects core stability while keeping optional parity trajectory.
- Costs: more module boundary plumbing and feature gating work.
- Risks: optional-profile drift if under-tested.
- Mitigations: enforce Phase D optional vector minimums from Phase B defaults.
- Reversal Trigger: extension boundary overhead exceeds maintenance value.
- Principles Impacted: P02, P03, P05, P06.
- Scope Impacted: `nip45_count`, `nip50_search`, `nip77_negentropy`, `nip19_bech32`, `nip21_uri`.

## Open Questions

- `OQ-C3-001`: confirm in Phase C4 whether `nip11` should expose strict-known-field validation as a
  separate entry point from permissive partial-document parsing (`status: accepted-risk`).
- `OQ-C3-002`: confirm in Phase D whether strict default should reject uppercase single-letter tag
  filter keys unconditionally, with compatibility parser split for parity corpus replay (`status: accepted-risk`).
- `OQ-C3-003`: confirm in Phase D whether `nip77_negentropy` v1 implementation remains framing-first
  with bounded data structures before any optimization enhancements (`status: accepted-risk`).

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: trust-boundary integrity preserved by strict reject defaults, explicit auth/protected/delete
  policy gaps, and no permissive cryptographic shortcuts.
- `P02`: protocol-kernel scope preserved by rejecting transport/runtime coupling and isolating optional
  channels into explicit modules.
- `P03`: interop convergence preserved by mapping each v1 module to concrete parity-core/parity-optional
  evidence and enforceable actions.
- `P04`: relay/auth routing semantics remain explicit via NIP-11/NIP-42/NIP-70 findings and dedicated
  acceptance-gate recommendations.
- `P05`: deterministic behavior preserved by adopted tie-break, framing, and decrypt-check-order invariants.
- `P06`: bounded memory/work posture preserved by explicit rejection of dynamic dependency/runtime
  assumptions and allocation-heavy parser patterns.
- Phase closure gate check: high-impact ambiguities with status `decision-needed` = 0.

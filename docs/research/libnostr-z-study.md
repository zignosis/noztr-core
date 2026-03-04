# libnostr-z study for noztr

This note reviews `privkeyio/libnostr-z` as an implementation reference and filters findings through
noztr constraints: stdlib-only, zero external dependencies, static allocation discipline, and
maintainability over feature-count.

## 1) Module organization and API patterns worth studying

- Flat, capability-oriented module layout works well for Nostr: `event.zig`, `filter.zig`,
  `messages.zig`, then one file per NIP/protocol feature.
- `root.zig` acts as a public facade that re-exports stable types while keeping implementation files
  separate. This gives users a single import surface and keeps internal reshuffles low-risk.
- Public API has paired parse entry points (`parse` + `parseWithAllocator`) and often serializer
  entry points that write into caller buffers. This split is a strong Zig pattern.
- Builder-style APIs (`EventBuilder.setKind().setContent().sign()`) reduce call-site verbosity and
  are ergonomic for event construction.
- Message APIs separate wire protocol directions (`ClientMsg` vs `RelayMsg`), which keeps state and
  validation responsibilities explicit.
- Useful idiom to keep: fixed-size stack buffers + `std.io.fixedBufferStream` for deterministic
  serialization without hidden allocations.

What to keep in mind for noztr adaptation:

- Keep one-file-per-feature where feasible, but cap per-file complexity by splitting large NIP files
  into submodules once they exceed readability thresholds.
- Preserve strict public/internal boundaries in `root.zig` (public re-exports only).
- Prefer explicit init/deinit lifecycles for any stateful subsystem (crypto context, pools, relay
  state), but avoid global mutable singleton state.

## 2) NIP coverage breadth versus maintainability

- libnostr-z targets broad NIP coverage (core + many optional/vertical features).
- Breadth improves adoption for app developers, but increases maintenance pressure from protocol
  churn, draft NIP changes, and cross-feature coupling.
- Several modules are domain-specific (wallet, DLC, Joinstr, marketplace, groups). These are useful
  for product teams but can dilute focus in a base protocol library.
- Large monolithic feature files increase review and regression risk, especially when protocol and
  transport logic mix in one unit.

Implication for noztr:

- Prioritize a tiered scope model:
  - Tier 1: core protocol and broadly stable NIPs.
  - Tier 2: widely used but higher-volatility NIPs behind clear module boundaries.
  - Tier 3: experimental/vertical features gated behind explicit opt-in.
- Track coverage as a maintained matrix (implemented, partial, planned, rejected) so roadmap stays
  intentional rather than reactive.

## 3) Dependency and portability analysis

Dependency stack observed in libnostr-z:

- `noscrypt` external dependency for cryptographic operations.
- System OpenSSL linkage (`ssl`, `crypto`) in build graph.
- C interop layer (`sz_wrapper.c`) compiled into a static helper library.
- StringZilla third-party dependency used through wrapper bindings.

Mismatch versus noztr target:

- noztr requires zero external dependencies and stdlib-only implementation.
- OpenSSL/system-link requirements reduce portability and reproducibility across targets.
- C wrappers and third-party C/C++ libraries complicate cross-compilation and toolchain setup.
- Security/audit scope expands significantly when native wrappers and external crypto stacks are
  included.

Portability conclusion:

- Architectural ideas are reusable; dependency choices are not.
- Any adopted pattern must be reimplemented with Zig stdlib primitives and explicit, bounded memory
  behavior.

## 4) Testing approach observations

- Tests are co-located in module files (`test` blocks at file bottom), which supports local reasoning
  and easy refactor safety.
- Coverage style is behavior-oriented for parsing/serialization and includes many protocol examples
  (positive and some negative paths).
- CI executes `zig build` and `zig build test` across Linux and macOS, which is a solid baseline for
  portability checks.
- Current dependency-driven CI setup installs platform libraries, showing tests are not fully hermetic
  under a stdlib-only definition.

Takeaways for noztr:

- Keep co-located tests and expand explicit negative-space assertions (invalid JSON, boundary lengths,
  malformed tags, signature mismatch).
- Enforce allocator discipline in tests (`std.testing.allocator`) and leak checks as a release gate.
- Add deterministic vectors for crypto and wire canonicalization to avoid behavior drift.

## 5) Adopt / Adapt / Reject table for noztr

| Item | libnostr-z pattern | noztr decision | Rationale |
|---|---|---|---|
| Module facade | `root.zig` re-export surface | Adopt | Clean API boundary and import ergonomics. |
| Feature files | Mostly one file per NIP/feature | Adopt | Aligns with noztr module convention. |
| Builder API | Chainable `EventBuilder` methods | Adapt | Keep ergonomics, but enforce strict size/line/assert rules. |
| Parse overloads | `parse` + allocator variant | Adopt | Good explicit memory contract pattern. |
| Fixed buffer IO | `fixedBufferStream` serializers | Adopt | Deterministic memory behavior, no hidden alloc. |
| Broad NIP scope | Many optional and vertical NIPs | Adapt | Use tiered roadmap to protect maintainability. |
| noscrypt dependency | External crypto package | Reject | Violates zero-dependency rule. |
| OpenSSL linkage | `linkSystemLibrary("ssl"/"crypto")` | Reject | Violates stdlib-only and hurts portability. |
| C wrapper layer | `sz_wrapper.c` and C bindings | Reject | Violates pure Zig goal and raises integration risk. |
| StringZilla | External high-performance string lib | Reject | Violates dependency policy; reimplement needed ops in stdlib. |
| CI dependency install | apt/brew crypto toolchain setup | Adapt | Keep multi-OS CI, remove external package requirement. |

## 6) Concrete guidance for a stdlib-only reimplementation path

- Define a strict core-first implementation sequence:
  - Step 1: core event model, canonical serialization, id hashing, signature verify/sign.
  - Step 2: filters and client/relay wire messages.
  - Step 3: selected stable NIPs in priority order.
- Replace external crypto with stdlib-backed primitives where available, and isolate any algorithmic
  gaps behind internal interfaces so implementation can evolve without API churn.
- Standardize buffer-first APIs:
  - Caller provides output buffers.
  - Return `error.BufferTooSmall` deterministically.
  - No unbounded growth containers in hot paths.
- Keep parse/serialize contracts explicit and symmetric:
  - `parseFromSlice` style entry points with allocator only when ownership is required.
  - `serializeInto` style entry points for zero-allocation paths.
- Build a test matrix before expanding NIP breadth:
  - Known-good vectors for ids/signatures/bech32.
  - Property checks for round-trip parse/serialize invariants.
  - Protocol conformance cases for malformed and adversarial inputs.
- Gate every new NIP behind a maintainability checklist:
  - Stable spec status.
  - Bounded memory model.
  - At least one interoperability fixture.
  - Clear reject criteria if dependency pressure appears.
- Keep transport concerns isolated from core event logic so websocket/relay pool complexity does not
  leak into base protocol modules.

Bottom line: treat libnostr-z as an API and packaging reference, not a dependency model reference.
Adopt its modular public-surface ideas, but reimplement internals in pure Zig stdlib with bounded
memory and explicit ownership everywhere.

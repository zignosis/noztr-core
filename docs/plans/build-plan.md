# noztr Build Plan

This plan is implementation-ready for a low-level Zig Nostr library with stdlib-only dependencies,
bounded/static memory posture, and TigerStyle constraints.

Note: Phase numbers in this document are implementation phases, separate from the
research/planning prompt phases in `docs/plans/prompts/`.

- Scope priority: protocol core first, then relay semantics, then private messaging.
- Architecture baseline: applesauce informs outer-layer adapters only, not core module design.
- Scope target: stage toward protocol support parity with `libnostr-z` without violating TigerStyle.
- Delivery model: each phase ends with `zig build test --summary all` passing and a usable subset.
- Decision policy: every material decision records explicit tradeoffs.
- Phase policy: no phase closes without ambiguity checkpoint results.
- Frozen defaults source: `docs/plans/nostr-principles.md`.
- Accepted default changes log: `docs/plans/decision-log.md`.

## Ground Rules

- One file per feature/NIP under `src/`.
- Public APIs are buffer-first; caller owns memory.
- No dynamic allocation after init on runtime paths.
- Explicit bounds on every variable-length field.
- Every function must satisfy TigerStyle constraints:
  - max 70 lines
  - max 100 columns
  - min 2 assertions with positive and negative space
  - simple control flow, no recursion, explicit error handling

## Phase 0 - Skeleton, Limits, and Shared Primitives

Working subset: compiles as a static library, exposes limits and shared utility functions.

Modules:

### `src/limits.zig`

- NIPs covered: cross-cutting constants for NIP-01 and NIP-44.
- Public API signatures:

```zig
pub const Limits = struct {
    pub const event_json_max: u32 = 262144;
    pub const tags_max: u16 = 128;
    pub const tag_items_max: u16 = 32;
    pub const tag_item_bytes_max: u16 = 2048;
    pub const content_bytes_max: u16 = 65535;
    pub const filter_ids_max: u16 = 1024;
    pub const filter_authors_max: u16 = 1024;
    pub const relay_message_bytes_max: u32 = 262144;
    pub const nip44_plaintext_min: u16 = 1;
    pub const nip44_plaintext_max: u16 = 65535;
};
```

- Data structures and bounds:
  - constants only; compile-time assertions tie limits together.
- Error sets:
  - none in this module.
- Assertion checklist:
  - compile-time positive: max >= min for every range.
  - compile-time negative: reject impossible layout relationships.
- Test vectors and edge cases:
  - compile-time tests for every constant relation.
- Exit criteria:
  - all limit invariants encoded as compile-time assertions.

### `src/errors.zig`

- NIPs covered: shared boundary errors for all phases.
- Public API signatures:

```zig
pub const ParseError = error{ InputTooShort, InputTooLong, InvalidFormat, InvalidUtf8 };
pub const EncodeError = error{ BufferTooSmall, ValueOutOfRange };
pub const VerifyError = error{ InvalidId, InvalidSignature, InvalidPubkey };
```

- Data structures and bounds:
  - error sets only.
- Assertion checklist:
  - positive: each boundary maps to one local error set.
  - negative: no catch-all `error.Invalid` in public signatures.
- Test plan:
  - compile checks for imports and names.
- Exit criteria:
  - root export file compiles with no cyclic dependencies.

Phase 0 TigerStyle exit:

- `zig build test --summary all` passes.
- No function exceeds 70 lines.
- Assertion density >= 2 per function in all implemented files.

## Phase 1 - Core Events and Filters (MVP)

Working subset: parse/validate/serialize/verify core events and filters deterministically.

Modules:

### `src/nip01_event.zig`

- NIPs covered: NIP-01 (includes moved behavior from NIP-12, NIP-16, NIP-20, NIP-33).
- Public API signatures:

```zig
pub const Event = struct {
    id: [32]u8,
    pubkey: [32]u8,
    created_at: u64,
    kind: u32,
    tags_count: u16,
    tags: [Limits.tags_max]Tag,
    content_len: u16,
    content: [Limits.content_bytes_max]u8,
    sig: [64]u8,
};

pub const Tag = struct {
    item_count: u16,
    items: [Limits.tag_items_max]TagItem,
};

pub const TagItem = struct {
    len: u16,
    bytes: [Limits.tag_item_bytes_max]u8,
};

pub const EventParseError = error{
    InputTooShort,
    InputTooLong,
    InvalidJson,
    InvalidField,
    InvalidHex,
    InvalidUtf8,
    TooManyTags,
    TooManyTagItems,
    TagItemTooLong,
};

pub const EventVerifyError = error{ InvalidId, InvalidSignature, InvalidPubkey };

pub fn event_parse_json(
    input: []const u8,
    scratch_allocator: std.mem.Allocator,
) EventParseError!Event;

pub fn event_serialize_canonical(
    output: []u8,
    event: *const Event,
) error{BufferTooSmall}![]const u8;

pub fn event_compute_id(event: *const Event) [32]u8;
pub fn event_verify_id(event: *const Event) EventVerifyError!void;
pub fn event_verify_signature(event: *const Event) EventVerifyError!void;
pub fn event_verify(event: *const Event) EventVerifyError!void;
```

- Data structures and bounds:
  - fixed arrays for tags and content; no heap ownership inside `Event`.
  - parser uses caller-supplied fixed allocator scratch; no retained allocations.
  - strict lowercase hex decode for `id`, `pubkey`, `sig`.
- Assertion checklist:
  - preconditions: input len > 0, output buffers non-empty.
  - preconditions: `tags_count <= Limits.tags_max` and `content_len <= content.len`.
  - postconditions: canonical byte output is deterministic for same `Event`.
  - postconditions: computed `id` length always 32 bytes.
  - invariants: `event_verify` implies `event_verify_id` and signature verification pass.
  - negative space: reject duplicate key ambiguity in strict mode.
  - negative space: reject wrong hex length or mixed invalid utf-8 fields.
- Test vectors, edge cases, and error paths:
  - happy path: canonical event fixtures and known ID/signature vectors.
  - edge: empty content, max content, max tags, max tag items.
  - edge: replaceable/addressable tie-break at equal `created_at` by lexical `id`.
  - error: malformed JSON, duplicate critical keys, invalid field types.
  - error: wrong hex size, uppercase-only policy decisions, bad Schnorr signature.

### `src/nip01_filter.zig`

- NIPs covered: NIP-01 filter grammar.
- Public API signatures:

```zig
pub const Filter = struct {
    ids_count: u16,
    ids: [Limits.filter_ids_max][32]u8,
    authors_count: u16,
    authors: [Limits.filter_authors_max][32]u8,
    kinds_count: u16,
    kinds: [128]u32,
    tags_count: u16,
    tags: [64]FilterTag,
    since: ?u64,
    until: ?u64,
    limit: ?u16,
};

pub const FilterTag = struct {
    key: u8,
    value_count: u16,
    values: [256][32]u8,
};

pub fn filter_parse_json(
    input: []const u8,
    scratch_allocator: std.mem.Allocator,
) error{InvalidFilter, InputTooLong, InvalidHex, TooManyValues}!Filter;

pub fn filter_matches_event(filter: *const Filter, event: *const Event) bool;
```

- Data structures and bounds:
  - bounded IDs/authors/kinds/tag-values.
  - nullable time windows and `limit` with explicit `u16` cap.
- Error sets:
  - `InvalidFilter`, `InvalidHex`, `TooManyValues`, size guards.
- Assertion checklist:
  - preconditions: `since <= until` when both present.
  - postconditions: normalized hex entries always 32 bytes.
  - invariants: matching is pure and side-effect free.
  - negative space: unknown `#` tag key forms rejected in strict mode.
- Test plan:
  - vectors for each filter field individually and combined.
  - edge limits for each list.
  - malformed `#` keys and invalid hex values.

Phase 1 TigerStyle exit:

- All core event and filter functions split to <= 70 lines.
- At least two assertions per function, with explicit negative-space tests.
- Deterministic canonicalization vectors pass on repeated runs.

## Phase 2 - Relay Message and Auth Semantics

Working subset: encode/decode client-relay messages and enforce auth/protected flow state.

Modules:

### `src/nip01_message.zig`

- NIPs covered: NIP-01 message grammar, NIP-20 command result semantics.
- Public API signatures:

```zig
pub const ClientMessageType = enum(u8) { event, req, close, auth, count };
pub const RelayMessageType = enum(u8) { event, eose, ok, closed, notice, auth, count };

pub const ClientMessage = union(ClientMessageType) {
    event: Event,
    req: ReqMessage,
    close: CloseMessage,
    auth: Event,
    count: CountMessage,
};

pub fn client_message_parse_json(
    input: []const u8,
    scratch_allocator: std.mem.Allocator,
) error{InvalidMessage, InputTooLong}!ClientMessage;

pub fn relay_message_serialize_json(
    output: []u8,
    message: *const RelayMessage,
) error{BufferTooSmall}![]const u8;
```

- Data structures and bounds:
  - subscription id max bytes: 64.
  - max filters per REQ: 16.
- Error sets:
  - `InvalidMessage`, `InvalidPrefix`, `InputTooLong`, `BufferTooSmall`.
- Assertion checklist:
  - preconditions: top-level array length >= 2.
  - invariants: message type determines exact payload shape.
  - negative space: reject unknown command strings in strict mode.
- Test plan:
  - transcript vectors: `REQ -> EVENT* -> EOSE -> CLOSE`.
  - `OK` prefix mapping cases (`invalid:`, `auth-required:`, `rate-limited:`).
  - malformed array arity and field type errors.

### `src/nip42_auth.zig` and `src/nip70_protected.zig`

- NIPs covered: NIP-42, NIP-70.
- Public API signatures:

```zig
pub const AuthState = struct {
    challenge_len: u8,
    challenge: [64]u8,
    authed_pubkeys_count: u16,
    authed_pubkeys: [64][32]u8,
};

pub fn auth_state_init(state: *AuthState) void;
pub fn auth_state_set_challenge(state: *AuthState, challenge: []const u8)
    error{ChallengeTooLong}!void;
pub fn auth_state_accept_event(state: *AuthState, auth_event: *const Event)
    error{InvalidAuthEvent, SignatureInvalid}!void;
pub fn protected_event_can_accept(state: *const AuthState, event: *const Event) bool;
```

- Data structures and bounds:
  - bounded challenge storage and bounded authenticated key set.
- Error sets:
  - `ChallengeTooLong`, `InvalidAuthEvent`, `SignatureInvalid`, `PubkeySetFull`.
- Assertion checklist:
  - preconditions: AUTH event kind and tags match expected challenge semantics.
  - invariants: challenge rotation invalidates stale assumptions.
  - negative space: `['-']` protected tag rejected if sender not authenticated.
- Test plan:
  - challenge rotation success/failure cases.
  - auth event with mismatched pubkey.
  - protected tag acceptance only for authenticated pubkey.

Phase 2 TigerStyle exit:

- Deterministic relay transcript tests pass.
- Auth state transitions fully covered (both allowed and denied paths).

## Phase 3 - Lifecycle Policy Primitives

Working subset: deterministic validators for deletion, expiration, and PoW difficulty.

Modules:

### `src/nip09_delete.zig`, `src/nip40_expire.zig`, `src/nip13_pow.zig`

- NIPs covered: NIP-09, NIP-40, NIP-13.
- Public API signatures:

```zig
pub fn deletion_can_apply(
    delete_event: *const Event,
    target_event: *const Event,
) error{InvalidDeleteEvent}!bool;

pub fn event_is_expired(event: *const Event, now_unix_seconds: u64) bool;

pub fn pow_leading_zero_bits(id: *const [32]u8) u16;
pub fn pow_meets_difficulty(event: *const Event, required_bits: u16)
    error{InvalidNonceTag}!bool;
```

- Data structures and bounds:
  - no dynamic storage; all checks are pure function primitives.
- Error sets:
  - `InvalidDeleteEvent`, `InvalidExpirationTag`, `InvalidNonceTag`, `DifficultyOutOfRange`.
- Assertion checklist:
  - preconditions: timestamp and tag parse constraints.
  - invariants: difficulty result deterministic for same input.
  - negative space: malformed nonce/expiration tags fail explicitly.
- Test plan:
  - delete before/after target ingest ordering scenarios.
  - expiration at boundary second and off-by-one.
  - known PoW vectors for leading-zero bit counting and invalid nonce tags.

Phase 3 TigerStyle exit:

- Every policy helper pure and side-effect free.
- 100 percent branch coverage for tag parsing and boundary behavior in this phase.

## Phase 4 - Identity and Reference Codecs

Working subset: deterministic encode/decode for bech32 entities and `nostr:` URI references,
plus relay-list helpers.

Modules:

### `src/nip19_bech32.zig`, `src/nip21_uri.zig`, `src/nip02_contacts.zig`, `src/nip65_relays.zig`

- NIPs covered: NIP-19, NIP-21, NIP-02, NIP-65.
- Public API signatures:

```zig
pub const Nip19EntityType = enum(u8) { npub, nsec, note, nprofile, nevent, naddr, nrelay };

pub fn nip19_encode(
    output: []u8,
    entity_type: Nip19EntityType,
    payload: []const u8,
) error{BufferTooSmall, InvalidPayload}![]const u8;

pub fn nip19_decode(
    input: []const u8,
    output_payload: []u8,
) error{InvalidBech32, InvalidPrefix, BufferTooSmall}!DecodedNip19;

pub fn nip21_parse(input: []const u8) error{InvalidUri, InvalidEntity}!Nip21Reference;

pub fn relay_list_extract_write_read(
    event: *const Event,
    output: []RelayPermission,
) error{InvalidRelayListEvent, BufferTooSmall}!u16;
```

- Data structures and bounds:
  - max NIP-19 string length constant per entity type.
  - TLV decoding uses fixed item cap (for example 32 entries).
- Error sets:
  - strict separation of decode errors vs semantic validation errors.
- Assertion checklist:
  - preconditions: expected HRP prefix for each entity type.
  - postconditions: decoded binary sizes match entity requirements.
  - negative space: invalid checksum and malformed TLV lengths rejected.
- Test plan:
  - canonical vectors for each entity type.
  - bad checksum, mixed-case violations, overlong inputs.
  - relay permissions parsing with duplicate and malformed entries.

Phase 4 TigerStyle exit:

- Codec round-trips stable across repeated encode/decode.
- No hidden allocation in encode/decode hot paths.

## Phase 5 - Private Messaging Core (NIP-44, then NIP-59 baseline)

Working subset: complete NIP-44 v2 encrypt/decrypt and message key derivation primitives;
foundation APIs used by NIP-59 wrappers.

Modules:

### `src/nip44.zig` (detailed contract)

- NIPs covered: NIP-44 (v2), used by NIP-59.
- Public API signatures:

```zig
pub const NIP44_VERSION: u8 = 0x02;
pub const NIP44_NONCE_BYTES: u8 = 32;
pub const NIP44_MAC_BYTES: u8 = 32;
pub const NIP44_MIN_PLAINTEXT: u16 = 1;
pub const NIP44_MAX_PLAINTEXT: u16 = 65535;
pub const NIP44_MIN_RAW_PAYLOAD: u32 = 99;
pub const NIP44_MAX_RAW_PAYLOAD: u32 = 65603;
pub const NIP44_MIN_BASE64_PAYLOAD: u32 = 132;
pub const NIP44_MAX_BASE64_PAYLOAD: u32 = 87472;

pub const Nip44Error = error{
    InvalidPrivateKey,
    InvalidPublicKey,
    InvalidConversationKeyLength,
    InvalidNonceLength,
    InvalidPlaintextLength,
    InvalidPayloadLength,
    InvalidVersion,
    UnsupportedEncoding,
    InvalidBase64,
    InvalidMac,
    InvalidPadding,
    BufferTooSmall,
    EntropyUnavailable,
};

pub const Nip44NonceProvider = *const fn (
    context: ?*anyopaque,
    out_nonce: *[32]u8,
) Nip44Error!void;

pub const Nip44DecodedPayload = struct {
    nonce: [32]u8,
    ciphertext_len: u32,
    ciphertext: []const u8,
    mac: [32]u8,
};

pub fn nip44_get_conversation_key(
    private_key: *const [32]u8,
    public_key: *const [32]u8,
) Nip44Error![32]u8;

pub fn nip44_calc_padded_plaintext_len(plaintext_len: u16) Nip44Error!u16;

pub fn nip44_encrypt_to_base64(
    output_base64: []u8,
    conversation_key: *const [32]u8,
    plaintext: []const u8,
    nonce_provider_context: ?*anyopaque,
    nonce_provider: Nip44NonceProvider,
) Nip44Error![]const u8;

pub fn nip44_encrypt_with_nonce_to_base64(
    output_base64: []u8,
    conversation_key: *const [32]u8,
    plaintext: []const u8,
    nonce: *const [32]u8,
) Nip44Error![]const u8;

pub fn nip44_decrypt_from_base64(
    output_plaintext: []u8,
    conversation_key: *const [32]u8,
    payload_base64: []const u8,
) Nip44Error![]const u8;

pub fn nip44_decode_payload(
    payload_base64: []const u8,
    raw_output: []u8,
) Nip44Error!Nip44DecodedPayload;
```

- Data structures and explicit bounds:
  - plaintext bounds: 1..65535 bytes.
  - padded plaintext payload (without 2-byte prefix): 32..65536 bytes.
  - encrypted padded blob length: `2 + calc_padded_len(plaintext_len)`.
  - raw framed payload bytes: `1 + 32 + ciphertext_len + 32` (99..65603).
  - base64 payload chars with padding: 132..87472.
  - no dynamic allocation in encrypt/decrypt; caller supplies output buffers.

- Behavior details (must match NIP-44 v2):
  - conversation key:
    - ECDH `shared_x = secp256k1(priv_a, pub_b)` using unhashed 32-byte x coordinate.
    - HKDF-extract with SHA-256: `IKM=shared_x`, `salt="nip44-v2"` UTF-8 bytes.
    - result is 32-byte `conversation_key`; symmetric under role swap.
  - nonce generation:
    - 32 random bytes from CSPRNG via `nonce_provider` callback.
    - callback is injectable for deterministic tests.
    - nonce reuse is caller-prohibited and documented as catastrophic for message secrecy.
  - message key derivation:
    - HKDF-expand SHA-256 with `PRK=conversation_key`, `info=nonce`, `L=76`.
    - bytes `[0..32]` -> ChaCha20 key.
    - bytes `[32..44]` -> ChaCha20 nonce (12 bytes).
    - bytes `[44..76]` -> HMAC-SHA256 key.
  - padding rules:
    - compute `calc_padded_len(unpadded_len)` exactly per NIP pseudocode.
    - if `unpadded_len <= 32`, padded_len = 32.
    - else `next_power = 1 << (floor(log2(unpadded_len - 1)) + 1)`.
    - `chunk = 32` when `next_power <= 256`, else `next_power / 8`.
    - padded_len = `chunk * (floor((unpadded_len - 1) / chunk) + 1)`.
    - padded blob is `[u16_be plaintext_len][plaintext][zero padding]`.
  - framing and MAC:
    - ciphertext is ChaCha20 keystream XOR over padded blob, counter 0.
    - MAC is `HMAC_SHA256(hmac_key, nonce || ciphertext)`.
    - final raw payload frame: `version || nonce || ciphertext || mac`.
    - final transport string: base64 with padding of raw payload bytes.
  - decryption checks:
    - if first payload char is `#`, return `UnsupportedEncoding`.
    - validate base64 input length range before decode.
    - validate decoded byte length range after decode.
    - reject unknown version (`!= 0x02`) as `InvalidVersion`.
    - verify MAC with constant-time compare before decrypting.
    - decrypt then validate padding length and zero-fill shape exactly.
    - reject plaintext length 0 and any padding mismatch.

- Constant-time requirements:
  - MAC comparison must use constant-time byte accumulation with no early exit.
  - MAC mismatch and length mismatch timing should not leak partial equality.
  - secret intermediate buffers (`shared_x`, key material) wiped via dedicated wipe helper.

- Assertion checklist:
  - preconditions: conversation key is exactly 32 bytes at API boundary.
  - preconditions: output buffers are large enough for worst-case branch.
  - postconditions: encrypt output begins with base64 for version byte `0x02` frame.
  - postconditions: decrypt output length equals prefixed u16 length.
  - invariants: derive keys deterministically for same `(conversation_key, nonce)`.
  - negative space: plaintext len 0, payload `#...`, bad MAC, bad padding all fail.

- Official vector strategy:
  - vendor `nip44.vectors.json` under `test_vectors/` with pinned checksum:
    `269ed0f69e4c192512cc779e78c555090cebc7c785b609e338a62afc3ce25040`.
  - tests must include:
    - valid `get_conversation_key` vectors.
    - valid `get_message_keys` vectors.
    - valid `calc_padded_len` vectors.
    - valid encrypt/decrypt vectors with fixed nonce.
    - long-message checksum vectors.
    - invalid vectors for key parsing, plaintext lengths, payload decode, MAC failure.
  - deterministic test harness: fixed nonce provider, no wall clock dependencies.

### `src/nip59_wrap.zig` (baseline)

- NIPs covered: NIP-59 minimal rumor/seal/wrap parse and unwrap checks.
- Public API signatures:

```zig
pub fn nip59_unwrap(
    output_inner_event: *Event,
    conversation_key: *const [32]u8,
    wrap_event: *const Event,
    scratch_allocator: std.mem.Allocator,
) error{InvalidWrapEvent, InvalidSealEvent, InvalidRumorEvent, DecryptFailed}!void;
```

- Data structures and bounds:
  - unwrap only in this phase; outbound orchestration deferred.
- Error sets:
  - explicit unwrap-stage errors.
- Assertion checklist:
  - must verify outer event signature before NIP-44 decrypt path.
  - negative space: wrong nesting/kinds fail at stage boundary.
- Test plan:
  - valid wrap->seal->rumor vectors.
  - invalid signature and invalid inner kind vectors.

Phase 5 TigerStyle exit:

- NIP-44 vectors pass including invalid corpus.
- MAC compare helper audited in tests for branchless compare behavior.
- No allocation in runtime encrypt/decrypt APIs.

## Phase 6 - Optional Extension Channel Features

Working subset: extension messages that do not alter Phase 1-5 contracts.

Modules:

### `src/nip45_count.zig`, `src/nip50_search.zig`, `src/nip77_negentropy.zig`

- NIPs covered: NIP-45, NIP-50, NIP-77.
- Public API signatures:

```zig
pub fn count_message_parse(input: []const u8, scratch_allocator: std.mem.Allocator)
    error{InvalidCountMessage}!CountMessage;

pub fn search_filter_validate(filter: *const Filter) error{InvalidSearchFilter}!void;

pub fn negentropy_message_parse(input: []const u8)
    error{InvalidNegentropyMessage}!NegentropyMessage;
```

- Data structures and bounds:
  - separate subscription namespace for NIP-77 ids.
- Error sets:
  - each extension has distinct parse errors.
- Assertion checklist:
  - extension parsing cannot mutate core state directly.
  - negative space: core parser rejects extension fields unless extension module invoked.
- Test plan:
  - message-shape vectors and namespace collision checks.

Phase 6 TigerStyle exit:

- Extensions compile behind explicit build options.
- Disabling extensions leaves core ABI stable and tests green.

## Proposed `build.zig` Structure

- Target outputs:
  - static library: `noztr`.
  - unit tests per module and aggregate test step.
- Build options:
  - `enable_extensions` (default false).
  - `strict_mode` (default true).
- Source organization:
  - `src/root.zig` exports stable public API.
  - `src/limits.zig`, `src/errors.zig`, and one file per NIP/feature.
  - tests co-located in each source file (`test` blocks).
  - vector files in `test_vectors/` loaded only in tests.

Suggested build steps:

```zig
const lib = b.addStaticLibrary(.{
    .name = "noztr",
    .root_source_file = b.path("src/root.zig"),
    .target = target,
    .optimize = optimize,
});

const lib_tests = b.addTest(.{
    .root_source_file = b.path("src/root.zig"),
    .target = target,
    .optimize = optimize,
});

const run_lib_tests = b.addRunArtifact(lib_tests);
const test_step = b.step("test", "Run noztr unit tests");
test_step.dependOn(&run_lib_tests.step);
```

- Test organization details:
  - `test "phase1 event canonical vectors" { ... }`
  - `test "phase2 auth state transitions" { ... }`
  - `test "phase5 nip44 official vectors" { ... }`
  - every public error variant must have at least one direct forcing test.

## Cross-Phase Definition of Done

- API contract:
  - every public function has documented bounds, error set, and deterministic behavior.
- Safety:
  - assertion pairs present for pre/post/invariant in all non-trivial functions.
  - no recursion, no compound condition ambiguity.
- Memory:
  - runtime paths are allocation-free after init.
  - caller-owned buffers for all encode/decode/encrypt/decrypt paths.
- Conformance:
  - protocol vectors and invalid corpora pass.
  - round-trip tests prove canonical stability.
- Tooling:
  - `zig build test --summary all` passes with zero leaks.
  - `zig build` produces static library artifact.

## Risks and Open Questions

- Zig stdlib secp256k1 surface stability:
  - confirm required ECDH primitive availability and BIP340-compliant key validation semantics.
- Strict vs compatibility parser policy:
  - decide compile-time, runtime, or dual mode before freezing Phase 1 API.
- Maximum bounds tuning:
  - initial caps are conservative; adjust with interoperability corpus before v1 freeze.
- NIP-77 depth decision:
  - implement message framing only or full negentropy algorithm in first extension release.
- NIP-59/NIP-17 outbound orchestration:
  - this plan delivers decrypt/verify-first; fan-out publication remains a later layer.
- Official vector provenance and maintenance:
  - store pinned vectors in-repo with checksum verification to avoid network dependency in CI.
- Side-channel review depth:
  - constant-time behavior and key wipe patterns need dedicated review pass before v1 tag.

This phased plan can be implemented directly without additional architecture discovery.

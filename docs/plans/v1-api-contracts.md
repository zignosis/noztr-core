# v1 API Contracts (Phase D)

Date: 2026-03-07

Scope: implementation-ready contracts for all Phase A H1 v1 modules.

## Decisions

- `PD-001`: all strict APIs are canonical; compatibility behavior remains explicit and outside
  default entry points.
- `PD-002`: all runtime encode/decode/verify/encrypt APIs are caller-buffer-first with explicit
  typed failures and fixed bounds.
- `PD-003`: every module contract includes deterministic behavior, assertion pairs, and required
  happy/error vectors.
- `PD-004`: optional modules keep the Phase B minimum vector gate (`3 valid + 3 invalid`) and do
  not alter core parser defaults.
- `PD-005`: security-hardening defaults are canonical in strict APIs: backend outage is typed,
  relay-auth freshness rejects stale and future timestamps beyond window, and new checked wrappers
  are preferred.
- `PD-006`: I6 optional root exports are feature-gated by build option `enable_i6_extensions`
  (default enabled) with explicit disabled-mode semantics.

## Global Contract Rules

- Public functions must use explicit integer widths (`u8/u16/u32/u64`) and must not expose `usize`
  in wire/state contracts.
- Public parse/verify/encode APIs must return typed error sets; no catch-all `error.Invalid`.
- Output-writing APIs must return `error.BufferTooSmall` without truncation.
- Strict mode is default (`D-003`); compatibility behavior is opt-in only.
- Root export semantics for I6 optional modules are feature-gated by build option
  `enable_i6_extensions` (default `true`):
  - when enabled, `root.nip45_count`, `root.nip50_search`, and `root.nip77_negentropy` export full
    module APIs;
  - when disabled, those root exports resolve to empty structs while core module exports and strict
    defaults remain unchanged.
- Determinism is required: identical inputs produce identical outputs and identical error variants.
- Memory policy at runtime is bounded and caller-owned: no unbounded/runtime-heap growth in hot
  crypto paths; unwrap parsing uses caller-provided bounded scratch.

## Module Contracts

### `nip01_event`

```zig
pub const EventParseError = error{
    InputTooShort, InputTooLong, OutOfMemory, InvalidJson, InvalidField, InvalidHex,
    InvalidUtf8, DuplicateField, TooManyTags, TooManyTagItems, TagItemTooLong,
};
pub const EventShapeError = error{
    InvalidUtf8, ContentTooLong, TooManyTags, TooManyTagItems, TagItemTooLong,
};
pub const EventSerializeError = EventShapeError || error{BufferTooSmall};
pub const EventVerifyError = error{ InvalidId, InvalidSignature, InvalidPubkey, BackendUnavailable };
pub const EventVerifyIdError = EventVerifyError || EventShapeError;

pub fn event_parse_json(input: []const u8, scratch: std.mem.Allocator)
    EventParseError!Event;
pub fn event_serialize_canonical(output: []u8, event: *const Event)
    EventSerializeError![]const u8;
pub fn event_serialize_canonical_json(output: []u8, event: *const Event)
    EventSerializeError![]const u8;
pub fn event_compute_id(event: *const Event) EventShapeError![32]u8;
pub fn event_compute_id_checked(event: *const Event) EventShapeError![32]u8;
pub fn event_verify_id(event: *const Event) EventVerifyError!void;
pub fn event_verify_id_checked(event: *const Event) EventVerifyIdError!void;
pub fn event_verify_signature(event: *const Event) EventVerifyError!void;
pub fn event_verify(event: *const Event) EventVerifyError!void;
pub fn event_replace_decision(current: *const Event, candidate: *const Event)
    enum{ keep_current, replace_with_candidate };
```

- Bounds: input <= `Limits.event_json_max`; `tags_count <= Limits.tags_max`; `content_len <=
  Limits.content_bytes_max`; strict event `kind <= 65535`; hex lengths fixed (`id/pubkey=64`,
  `sig=128`).
- Failure modes: malformed JSON/field typing, duplicate critical keys, invalid lowercase hex,
  out-of-bounds tags/content, invalid id recomputation, invalid signature/pubkey, typed
  signature-backend outage.
- Deterministic behavior: canonical serialization bytes, computed id, and replace ordering are
  deterministic (`created_at`, then lexical `id`).
- Runtime-shape note: canonical serialize/compute surfaces return `EventShapeError` variants when
  runtime shape invariants are violated. Trust-boundary call sites should continue to use
  `event_verify_id` (or checked wrappers such as `pow_meets_difficulty_verified_id`) for
  policy-facing invalid-id handling.
- Assertion pairs: assert required field presence and assert no extra critical duplicates; assert
  bounds in positive space and return typed over-bound errors in negative space.
- Vectors: happy (`canonical round-trip`, `verify split/full`, `tie-break replaceable/addressable`);
  error (`duplicate key`, `invalid hex length/case`, `invalid id`, `invalid sig`, `backend outage`,
  `too many tags`).

### `nip01_filter`

```zig
pub const FilterParseError = error{
    InputTooLong, OutOfMemory, InvalidFilter, InvalidHex, InvalidTagKey,
    TooManyTagKeys,
    TooManyIds, TooManyAuthors, TooManyKinds, TooManyTagValues,
    InvalidTimeWindow, ValueOutOfRange,
};

pub fn filter_parse_json(input: []const u8, scratch: std.mem.Allocator)
    FilterParseError!Filter;
pub fn filter_matches_event(filter: *const Filter, event: *const Event) bool;
pub fn filters_match_event(filters: []const Filter, event: *const Event) bool;
```

- Bounds: all lists fixed-capacity; `ids`/`authors` entries are strict lowercase hex prefixes with
  length `1..64` and are matched by prefix; tag-key list is bounded by `Limits.filter_tag_keys_max`
  with typed overflow `TooManyTagKeys`; `subscription` filter arrays are bounded by module
  constants; parsed `kinds` values are bounded to strict `<= 65535`; optional `limit` is bounded to
  `u16`; `since <= until` when both are present.
- Failure modes: malformed filter object/field type, invalid `#x` key shape, uppercase/non-lowercase
  `#x` key suffix, invalid lowercase hex prefix, empty `#x` value arrays, over-capacity arrays,
  invalid time window.
- Deterministic behavior: AND within one filter, OR across filter list; id/author checks use
  deterministic nibble-precision prefix matching; same filter/event input returns identical boolean.
- Assertion pairs: assert key shape is `#` plus exactly one lowercase ASCII letter and reject all
  other forms; assert id/author prefix lengths are `1..64` lowercase hex and reject invalid forms;
  assert typed rejection paths for every over-capacity list, including `TooManyTagKeys`.
- Vectors: happy (`single-field`, `combined-and`, `or-across-filters`, `id/author prefix match`,
  `odd-length prefix nibble match`); error (`bad # key`, `uppercase #x key`, `invalid hex prefix`,
  `empty #x array`, `since>until`, each capacity overflow including `TooManyTagKeys`).

### `nip01_message`

```zig
pub const MessageParseError = error{
    InputTooLong, InvalidMessage, InvalidCommand, InvalidArity,
    InvalidFieldType, InvalidFilter, InvalidEvent, InvalidPrefix,
};
pub const MessageEncodeError = error{ BufferTooSmall, ValueOutOfRange };

pub fn client_message_parse_json(input: []const u8, scratch: std.mem.Allocator)
    MessageParseError!ClientMessage;
pub fn relay_message_parse_json(input: []const u8, scratch: std.mem.Allocator)
    MessageParseError!RelayMessage;
pub fn client_message_serialize_json(output: []u8, message: *const ClientMessage)
    MessageEncodeError![]const u8;
pub fn relay_message_serialize_json(output: []u8, message: *const RelayMessage)
    MessageEncodeError![]const u8;
pub fn transcript_mark_client_req(state: *TranscriptState, subscription_id: []const u8)
    error{InvalidTranscriptTransition}!void;
pub fn transcript_apply(state: *TranscriptState, message: *const RelayMessage)
    error{InvalidTranscriptTransition}!void;
pub fn transcript_apply_compat(state: *TranscriptState, message: *const RelayMessage)
    error{InvalidTranscriptTransition}!void;
pub fn transcript_apply_relay(state: *TranscriptState, message: RelayMessage)
    error{InvalidTranscriptTransition}!void;
```

- Bounds: message JSON input <= `Limits.relay_message_bytes_max`; `subscription_id` length `1..64`;
  bounded filter arrays per `REQ` and `COUNT` (multi-filter supported); bounded transcript steps per
  subscription.
- `OK` status semantics: success (`accepted=true`) allows empty/free-form string status; rejection
  (`accepted=false`) requires prefixed status (`<prefix>: <message>`).
- Failure modes: unknown command in strict mode, malformed array arity/types, malformed `OK`/
  `CLOSED` prefix shape, malformed rejected-`OK` prefix shape, uppercase/non-hex `OK` event id,
  invalid transcript transition.
- Deterministic behavior: same message bytes parse to same union variant; transcript transition
  decisions are deterministic per prior state and explicit client `REQ` marker, with strict flow
  semantics (`REQ marker; relay EVENT* -> EOSE? -> EVENT* -> CLOSED?`) and terminal `CLOSED`.
- Canonical-vs-compat transcript wording: canonical strict path is
  `transcript_mark_client_req` + `transcript_apply_relay`; `transcript_apply` and
  `transcript_apply_compat` are compatibility alias wrappers.
- Assertion pairs: assert command token valid and assert explicit reject for unknown token; assert
  expected arity and reject all other arities.
- Vectors: happy (`mark REQ; relay EVENT* -> EOSE -> EVENT* -> CLOSED`, `mark REQ -> CLOSED`
  pre-EOSE, valid
  `OK/CLOSED/NOTICE/AUTH/COUNT` grammar);
  error (`unknown command`, `bad arity`, `bad prefix`, `OK` uppercase id reject,
  invalid transcript order).

### `nip42_auth`

```zig
pub const AuthError = error{
    ChallengeEmpty, ChallengeTooLong, RelayUrlMismatch, ChallengeMismatch,
    InvalidAuthEventKind, MissingRelayTag, MissingChallengeTag,
    DuplicateRequiredTag,
    FutureTimestamp, StaleTimestamp, InvalidSignature, BackendUnavailable, PubkeySetFull,
};

pub fn auth_state_init(state: *AuthState) void;
pub fn auth_state_set_challenge(state: *AuthState, challenge: []const u8)
    error{ChallengeEmpty, ChallengeTooLong}!void;
pub fn auth_validate_event(auth_event: *const Event, expected_relay: []const u8,
    expected_challenge: []const u8, now_unix_seconds: u64, window_seconds: u32)
    AuthError!void;
pub fn auth_state_accept_event(state: *AuthState, auth_event: *const Event,
    expected_relay: []const u8, now_unix_seconds: u64, window_seconds: u32)
    AuthError!void;
pub fn auth_state_is_pubkey_authenticated(state: *const AuthState, pubkey: *const [32]u8) bool;
```

- Bounds: challenge length `1..64`; authenticated key store fixed-capacity; timestamp skew bounded by
  `window_seconds` (`u32`) as bounded symmetric skew (`created_at` within `[now-window,
  now+window]` is accepted); future beyond window rejects `FutureTimestamp`, stale beyond window
  rejects `StaleTimestamp`; `auth_validate_event` expected challenge input must also be length
  `1..64`.
- Failure modes: empty challenge set attempt, too-long challenge set attempt, wrong kind,
   missing/mismatched `relay` or `challenge`, invalid signature, duplicate required tags,
   expected challenge empty/too-long reject in `auth_validate_event`,
   unbracketed IPv6 relay authority rejection, future timestamp rejection, stale timestamp
   rejection, typed backend outage, full auth-set capacity.
- Deterministic behavior: auth validation outcome depends only on event/tags/time inputs and current
  challenge state; challenge rotation clears authenticated pubkeys before next accept; strict relay
  origin matching compares normalized scheme/host/port/path, ignores query/fragment, normalizes
  missing path to `/`, accepts bracketed IPv6 authorities, and rejects unbracketed IPv6 authorities.
- Assertion pairs: assert challenge exists before accept and reject mismatch explicitly; assert
  `created_at` is within freshness window and reject stale/future violations.
- Vectors: happy (`valid auth`, `challenge rotation then valid auth`); error (`wrong kind`,
   `relay mismatch`, `challenge mismatch`, `empty challenge`, `challenge too long`,
   `validate expected challenge empty`, `validate expected challenge too long`,
   `duplicate required tags`, `future timestamp`, `stale timestamp`, `backend outage`,
   `pubkey set full`, `normalized path match/mismatch`, `query/fragment ignored`,
   `missing-path equals /`, `bracketed ipv6 origin match/mismatch`, `unbracketed ipv6 reject`).

### `nip70_protected`

```zig
pub const ProtectedError = error{ ProtectedAuthRequired, ProtectedPubkeyMismatch };

pub fn event_has_protected_tag(event: *const Event) bool;
pub fn protected_event_validate(event: *const Event, authenticated_pubkey: ?*const [32]u8)
    ProtectedError!void;
```

- Bounds: protected tag shape is exactly one-item tag `['-']`.
- Failure modes: protected event without auth context, protected event with auth pubkey mismatch.
- Deterministic behavior: tag detection and policy outcome are deterministic for same event/auth
  inputs.
- Assertion pairs: assert protected-tag shape exactness and assert non-exact forms do not trigger
  protected path; assert authenticated pubkey equality and reject mismatch.
- Vectors: happy (`non-protected accept`, `protected + matching auth accept`); error (`protected
  unauthenticated`, `protected mismatched pubkey`, malformed protected tag shape not treated as
  protected).

### `nip09_delete`

```zig
pub const DeleteError = error{
    InvalidDeleteEventKind, EmptyDeleteTargets, InvalidETag,
    InvalidATag, InvalidAddressCoordinate, CrossAuthorDelete,
};
pub const DeleteExtractError = error{
    BufferTooSmall, EmptyDeleteTargets, InvalidETag,
    InvalidATag, InvalidAddressCoordinate,
};
pub const DeleteExtractCheckedError = DeleteExtractError || error{InvalidDeleteEventKind};

pub fn delete_extract_targets(delete_event: *const Event, out: []DeleteTarget)
    DeleteExtractError!u16;
pub fn delete_extract_targets_checked(delete_event: *const Event, out: []DeleteTarget)
    DeleteExtractCheckedError!u16;
pub fn deletion_can_apply(delete_event: *const Event, target_event: *const Event)
    DeleteError!bool;
```

- Bounds: at least one `e` or `a` target required; extracted target count bounded by output slice.
- Failure modes: checked extract rejects non-kind-5 input, empty targets, malformed `e`/`a` tags,
  and `BufferTooSmall`; apply rejects cross-author deletes.
- Coordinate-match policy: duplicate `d` tags on target events are rejected for `a`-coordinate
  matching to preserve deterministic identifier resolution.
- Safe wrapper: `delete_extract_targets_checked` enforces kind and target validation in one typed API
  surface for relay call sites.
- Deterministic behavior: same delete/target pair yields identical apply decision.
- Assertion pairs: assert delete kind is `5` and reject others; assert author equality for apply and
  reject cross-author paths.
- Vectors: happy (`valid e-target delete`, `valid a-target timestamp-bound delete`); error (`empty
  targets`, malformed `e/a`, cross-author target, delete-of-delete no-op path).

### `nip40_expire`

```zig
pub const ExpirationError = error{ InvalidExpirationTag, InvalidTimestamp };

pub fn event_expiration_unix_seconds(event: *const Event)
    ExpirationError!?u64;
pub fn event_is_expired_at(event: *const Event, now_unix_seconds: u64)
    ExpirationError!bool;
```

- Bounds: `expiration` tag must contain exactly one integer-seconds value parseable to `u64`.
- Failure modes: malformed tag shape/value, invalid integer representation.
- Deterministic behavior: expiry result is pure and deterministic (`expired == now > expiration`).
- Assertion pairs: assert parsed timestamp is valid u64 and reject parse failures; assert boundary
  equality is non-expired and assert one-second-after is expired.
- Vectors: happy (`no expiration`, `future expiration`, boundary equality case);
  error (`bad integer`, `bad tag arity`, duplicate conflicting expiration handling rule).

### `nip13_pow`

```zig
pub const PowError = error{
    DifficultyOutOfRange, InvalidNonceTag, InvalidNonceCounter,
    InvalidNonceCommitment,
};
pub const PowVerifiedIdError = PowError || error{ InvalidId };

pub fn pow_leading_zero_bits(id: *const [32]u8) u16;
pub fn pow_extract_nonce_target(event: *const Event)
    PowError!?u16;
pub fn pow_meets_difficulty(event: *const Event, required_bits: u16)
    PowError!bool;
pub fn pow_meets_difficulty_verified_id(event: *const Event, required_bits: u16)
    PowVerifiedIdError!bool;
```

- Bounds: `required_bits` in `0..256`; nonce tag shape `['nonce', counter]` or
  `['nonce', counter, target]`.
- Failure modes: malformed nonce shape, invalid integer counter/target, out-of-range difficulty.
- Deterministic behavior: leading-zero count is deterministic bit scan of event id bytes; when nonce
  commitment is present, strict validation enforces `actual_bits >= commitment` and
  `commitment >= required_bits`.
- Compatibility default: `pow_meets_difficulty` is safe-by-default compatibility behavior and returns
  `false` for invalid/non-canonical event ids.
- Internal helper: `pow_meets_difficulty_unchecked` remains internal-only.
- Safe wrapper: `pow_meets_difficulty_verified_id` first checks event id canonical validity before PoW
  comparison and returns `InvalidId` on shape/verification mismatch while preserving all `PowError`
  variants for nonce/difficulty failures.
- Assertion pairs: assert `required_bits <= 256` and reject higher values; assert valid nonce tag
  arities and reject others; assert commitment floor/truthfulness and reject weaker or overstated
  commitments.
- Vectors: happy (`known id leading-zero vectors`, `meets required`, `missing commitment accepted`);
  error (`bad nonce value`, `bad nonce arity`, `required_bits out of range`,
  `commitment below required`, `actual bits below commitment`).

### `nip19_bech32`

```zig
pub const Nip19Error = error{
    InvalidBech32, InvalidChecksum, MixedCase, InvalidPrefix,
    InvalidPayload, MissingRequiredTlv, MalformedKnownOptionalTlv,
    BufferTooSmall, ValueOutOfRange,
};

pub fn nip19_encode(output: []u8, entity: Nip19Entity)
    Nip19Error![]const u8;
pub fn nip19_decode(input: []const u8, tlv_scratch: []u8)
    Nip19Error!Nip19Entity;
```

- Bounds: TLV `T`/`L` are `u8`; each TLV value <= 255 bytes; decoded entity fields bounded by
  fixed-size structs/slices.
- Failure modes: bad checksum, mixed-case input, unknown HRP, missing required TLVs, malformed known
  optional TLV payloads, insufficient output/scratch.
- Deterministic behavior: encode/decode for valid inputs is stable and idempotent; unknown TLV types
  are ignored, known malformed optional TLVs are rejected.
- Assertion pairs: assert required TLVs exist and reject missing; assert optional known TLV formats
  are valid when present and reject malformed.
- Vectors: happy (`npub/nsec/note`, `nprofile/nevent/naddr/nrelay`, unknown TLV ignored);
  error (`checksum`, `mixed case`, `missing required TLV`, malformed known optional TLV).

### `nip21_uri`

```zig
pub const Nip21Error = error{ InvalidUri, InvalidScheme, ForbiddenEntity, InvalidEntityEncoding };

pub fn nip21_parse(input: []const u8, tlv_scratch: []u8)
    Nip21Error!Nip21Reference;
pub fn nip21_is_valid(input: []const u8, tlv_scratch: []u8) bool;
```

- Bounds: input must begin with `nostr:` and contain one NIP-19 identifier; same underlying NIP-19
  bounds apply.
- Failure modes: non-`nostr:` scheme, forbidden `nsec`, invalid embedded NIP-19 encoding.
- Deterministic behavior: parser is strict and deterministic; no regex-only permissive path.
- Assertion pairs: assert scheme exact match and reject all others; assert forbidden entity rejection
  for `nsec` and accept allowed entities.
- Vectors: happy (`nostr:npub...`, `nostr:note...`, `nostr:nprofile...`);
  error (`http://...`, `nostr:nsec...`, malformed embedded bech32).

### `nip02_contacts`

```zig
pub const ContactsError = error{
    InvalidEventKind, InvalidContactTag, InvalidPubkey,
    BufferTooSmall,
};

pub fn contacts_extract(event: *const Event, out: []ContactEntry)
    ContactsError!u16;
```

- Bounds: event kind must be `3`; output entries bounded by caller-provided `out`.
- Failure modes: wrong event kind, malformed non-`p` tag in strict extraction, invalid pubkey hex,
  output capacity overflow.
- Deterministic behavior: extraction order follows source tag order; identical event yields identical
  extracted list.
- Assertion pairs: assert kind `3` and reject others; assert `p` tag pubkey length/hex validity and
  reject malformed pubkeys.
- Vectors: happy (`kind-3 with valid p tags`, optional relay/petname preserved);
  error (`wrong kind`, `non-p tag in strict path`, malformed pubkey, `BufferTooSmall`).

### `nip65_relays`

```zig
pub const RelaysError = error{
    InvalidEventKind, InvalidRelayTag, InvalidRelayUrl,
    InvalidMarker, BufferTooSmall,
};

pub fn relay_list_extract(event: *const Event, out: []RelayPermission)
    RelaysError!u16;
pub fn relay_marker_parse(marker: []const u8)
    error{InvalidMarker}!enum{ read, write, both };
```

- Bounds: event kind must be `10002`; marker token is `"read"`, `"write"`, or empty.
- Failure modes: malformed `r` tag, invalid URL, unknown marker, wrong event kind, out buffer full.
- Deterministic behavior: dedupe and permission merge are deterministic and stable by first-seen
  relay order.
- Assertion pairs: assert allowed marker token set and reject unknown tokens; assert URL validation
  pass/fail with typed error.
- Vectors: happy (`read/write/both`, duplicate relay dedupe stability);
  error (`unknown marker`, malformed URL, wrong kind, non-`r` strict extraction failure).

### `nip44`

```zig
pub const Nip44Error = error{
    InvalidPrivateKey, InvalidPublicKey, InvalidConversationKeyLength,
    InvalidNonceLength, InvalidPlaintextLength, InvalidPayloadLength,
    InvalidVersion, UnsupportedEncoding, InvalidBase64,
    InvalidMac, InvalidPadding, BufferTooSmall, EntropyUnavailable,
};

pub const Nip44NonceProvider = *const fn (ctx: ?*anyopaque, out_nonce: *[32]u8)
    Nip44Error!void;

pub fn nip44_get_conversation_key(private_key: *const [32]u8, public_key: *const [32]u8)
    Nip44Error![32]u8;
pub fn nip44_calc_padded_plaintext_len(plaintext_len: u16)
    Nip44Error!u32;
pub fn nip44_encrypt_to_base64(output: []u8, conversation_key: *const [32]u8,
    plaintext: []const u8, nonce_ctx: ?*anyopaque, nonce_provider: Nip44NonceProvider)
    Nip44Error![]const u8;
pub fn nip44_encrypt_with_nonce_to_base64(output: []u8, conversation_key: *const [32]u8,
    plaintext: []const u8, nonce: *const [32]u8)
    Nip44Error![]const u8;
pub fn nip44_decode_payload(payload_base64: []const u8, raw_output: []u8)
    Nip44Error!Nip44DecodedPayload;
pub fn nip44_decrypt_from_base64(output_plaintext: []u8, conversation_key: *const [32]u8,
    payload_base64: []const u8)
    Nip44Error![]const u8;
```

- Bounds: plaintext input `1..65535`; padded plaintext length result excludes the two-byte length
  prefix and is `32..65536`; base64 payload `132..87472`; decoded payload `99..65603`; version must
  be `0x02`; all buffers caller-owned.
- Allocation policy: encrypt/decrypt hot paths perform no unbounded/runtime-heap allocation.
- Failure modes: unsupported `#` encoding, invalid lengths, invalid version, invalid MAC,
  invalid padding, invalid UTF-8 plaintext after padding checks (typed `InvalidPadding`),
  key/nonce errors, buffer insufficiency.
- Deterministic behavior: fixed nonce path is fully deterministic; decrypt check order is strict
  (`length -> version -> MAC -> decrypt -> padding`); constant-time MAC compare required.
- Assertion pairs: assert length-range preconditions and reject out-of-range; assert MAC validity
  before decrypt and reject invalid MAC without decrypt path.
- Vectors: happy (`official nip44 vectors`, fixed nonce encrypt/decrypt, long-message checksum);
  error (`bad version`, `bad MAC`, `bad padding`, `#` payload, invalid base64 range).

### `nip59_wrap`

```zig
pub const WrapError = error{
    InvalidWrapEvent, InvalidSealEvent, InvalidRumorEvent,
    InvalidWrapKind, InvalidSealKind, InvalidSealSignature,
    SenderMismatch, DecryptFailed, OutOfMemory,
};

pub fn nip59_unwrap(output_rumor: *Event, recipient_private_key_material: *const [32]u8,
    wrap_event: *const Event, scratch: std.mem.Allocator)
    WrapError!void;
pub fn nip59_validate_wrap_structure(wrap_event: *const Event)
    WrapError!void;
```

- Bounds: staged unwrap only; all inner decode and parse operations bounded by existing event/NIP-44
  limits; strict unwrap parsing uses caller-provided bounded scratch. Unwrap derives per-layer NIP-44
  conversation keys from recipient private key material using `wrap.pubkey` first, then `seal.pubkey`.
- Failure modes: wrong outer kind, malformed wrap/seal/rumor layer, invalid seal signature,
  sender mismatch spoof, decrypt failure at any stage, rumor `sig` field present in strict unwrap.
- Deterministic behavior: staged order fixed (`wrap -> seal -> rumor`) and failure stage is
  deterministic for identical inputs.
- Assertion pairs: assert outer signature verifies before decrypt and reject otherwise; assert sender
  continuity across layers and reject mismatch; assert rumor is unsigned and reject any rumor `sig`
  field.
- Vectors: happy (`valid wrap->seal->rumor chain`, sender-consistent unwrap);
  error (`bad outer kind`, `bad seal sig`, `sender mismatch spoof`, malformed rumor payload).

### `nip45_count`

```zig
pub const CountError = error{
    InvalidCountMessage, InvalidCountObject, InvalidCountValue,
    InvalidApproximateValue, InvalidHllHex, InvalidHllLength,
    InvalidQueryId,
};

pub fn count_client_message_parse(input: []const u8, scratch: std.mem.Allocator)
    CountError!CountClientMessage;
pub fn count_relay_message_parse(input: []const u8, scratch: std.mem.Allocator)
    CountError!CountRelayMessage;
pub fn count_metadata_validate(metadata: *const CountMetadata)
    CountError!void;
```

- Bounds: query id length `1..64`; `hll` (if present) must be exactly 512 hex chars.
- COUNT request filters are parsed through shared message grammar and support one-or-more filters.
- Failure modes: malformed COUNT array grammar, malformed count object, non-integer count,
  invalid metadata types/lengths.
- Deterministic behavior: parser and metadata validation outcomes are deterministic; unsupported COUNT
  is represented through strict `CLOSED` flow in message layer.
- Assertion pairs: assert count object has required `count` integer and reject non-int; assert
  optional `hll` length/hex validity and reject malformed forms.
- Vectors: happy (`valid COUNT request`, `valid COUNT response`, valid `approximate`/`hll` metadata);
  error (`bad array arity`, invalid `count` type, invalid `hll` length/hex).

### `nip50_search`

```zig
pub const SearchError = error{ InvalidSearchValue, InvalidSearchToken };

pub fn search_field_validate(value: []const u8)
    SearchError!void;
pub fn search_tokens_parse(value: []const u8, out_tokens: []SearchToken)
    error{BufferTooSmall, InvalidSearchValue}!u16;
```

- Bounds: `search` must be UTF-8 string within module max byte cap; parsed token list bounded by
  output capacity.
- Failure modes: non-string/non-UTF-8 search value, invalid token encoding when strict token parser is
  used.
- Deterministic behavior: extension parser only; unsupported `key:value` tokens are ignored by
  policy and do not mutate core filter parse behavior.
- Unsupported multi-colon policy: unsupported tokens with multiple colons (for example
  `custom:alpha:beta`) are ignored; malformed supported tokens with additional colons remain typed
  failures.
- Assertion pairs: assert base search value is string and reject non-string; assert unsupported
  extension tokens are ignored (not fatal) in strict extension policy.
- Vectors: happy (`plain query`, `query with supported token`, `query with unsupported token ignored`);
  error (`non-string search`, malformed strict-token shape, output overflow).

### `nip77_negentropy`

```zig
pub const NegentropyError = error{
    InvalidNegOpen, InvalidNegMsg, InvalidNegClose,
    InvalidNegErr,
    InvalidHexPayload, UnsupportedVersion, ReservedTimestamp,
    InvalidOrdering, SessionStateExceeded,
};

pub fn negentropy_open_parse(input: []const u8, scratch: std.mem.Allocator)
    NegentropyError!NegOpenMessage;
pub fn negentropy_msg_parse(input: []const u8, scratch: std.mem.Allocator)
    NegentropyError!NegMsgMessage;
pub fn negentropy_close_parse(input: []const u8, scratch: std.mem.Allocator)
    NegentropyError!NegCloseMessage;
pub fn negentropy_err_parse(input: []const u8, scratch: std.mem.Allocator)
    NegentropyError!NegErrMessage;
pub fn negentropy_state_apply(state: *NegentropyState, message: *const NegentropyMessage)
    NegentropyError!void;
pub fn negentropy_items_validate_order(items: []const NegentropyItem)
    NegentropyError!void;
```

- Bounds: protocol version strict default `0x61`; hex payload must decode within bounded session
  buffers; reserved timestamp `2^64-1` forbidden; session steps bounded.
- Failure modes: malformed NEG family message shapes, invalid hex framing, unsupported version,
  ordering violation, session-bound overflow; strict `NEG-ERR` parse/state validation rejects
  malformed reason shape/prefix with typed `InvalidNegErr`.
- Deterministic behavior: parser/state transitions deterministic for same message sequence;
  ordering invariant (`timestamp asc`, `id lexical asc`) strictly enforced.
- Assertion pairs: assert canonical version acceptance and typed reject for unsupported versions;
  assert ordering invariant and reject first violation deterministically.
- Vectors: happy (`NEG-OPEN`, `NEG-MSG`, `NEG-CLOSE`, `NEG-ERR` valid flow with deterministic
  ordering); error (`malformed hex`, version mismatch path, reserved timestamp,
  `NEG-CLOSE`/`NEG-ERR` shape violations, ordering violation, session overflow).

### `nip11`

```zig
pub const Nip11Error = error{
    OutOfMemory, InvalidJson, InvalidKnownFieldType, InvalidStructuredField,
    InvalidPubkey, TooManySupportedNips, LimitationOutOfRange,
    InputTooLong,
};

pub fn nip11_parse_document(input: []const u8, scratch: std.mem.Allocator)
    Nip11Error!RelayInformationDocument;
pub fn nip11_validate_known_fields(doc: *const RelayInformationDocument)
    Nip11Error!void;
```

- Bounds: input length bounded by NIP-11 parser cap; known structured fields parsed with explicit
  object/list caps; per-field list/object caps have typed overflow errors.
- Failure modes: malformed JSON, known-field type mismatch, malformed known structured sub-object,
  invalid relay pubkey hex, and cap overflows with typed variants.
- Deterministic behavior: unknown fields are ignored; known fields (when present) are strictly type
  checked with deterministic typed failure.
- Assertion pairs: assert known field type correctness and reject mismatches; assert unknown fields
  do not fail parse and are ignored; assert relay pubkey is strict lowercase 32-byte hex.
- Vectors: happy (`partial document with known valid fields`, unknown field ignored, supported_nips
  valid list);
  error (`known field wrong type`, `malformed limitations object`, invalid pubkey hex,
  supported_nips cap overflow, input over cap).

## Test Vector Gate

- Core modules (`nip01_event`, `nip01_filter`, `nip01_message`, `nip42_auth`, `nip70_protected`,
  `nip09_delete`, `nip40_expire`, `nip13_pow`, `nip44`, `nip59_wrap`, `nip11`): minimum
  `5 valid + 5 invalid` vectors each.
- Optional modules (`nip19_bech32`, `nip21_uri`, `nip02_contacts`, `nip65_relays`, `nip45_count`,
  `nip50_search`, `nip77_negentropy`): minimum `3 valid + 3 invalid` vectors each (Phase B gate).
- Every public error variant must have at least one forcing test.

## Ambiguity Checkpoint

`A-D-001`
- Topic: optional module vector depth beyond current minimum.
- Impact: medium.
- Status: accepted-risk.
- Default: keep `3 valid + 3 invalid` for optional modules in v1, raise only with parity-corpus
  evidence.
- Owner: active phase owner.

`A-D-002`
- Topic: compatibility API placement (`co-located` vs `compat/` namespace).
- Impact: low.
- Status: accepted-risk.
- Default: keep strict entry points canonical; choose physical placement in Phase E/F organization
  without changing behavior contracts.
- Owner: active phase owner.

`A-D-003`
- Topic: NIP-42 strict relay origin matching with bracketed IPv6 authorities.
- Impact: medium.
- Status: resolved.
- Default: strict auth compares normalized scheme/host/port/path, accepts bracketed IPv6
  authority parsing, rejects unbracketed IPv6 authorities, ignores query/fragment, and normalizes
  missing path to `/`.
- Owner: active phase owner.

Ambiguity checkpoint result: high-impact `decision-needed` count = 0.

## Extension Lane Placeholders (Documentation Only)

Accepted roadmap items from `docs/plans/v1-additional-nips-roadmap.md` are placeholders only and do
not expand v1 scope:

- H2 Wave 1 placeholder contracts: NIPs `06`, `46`, `51`, `10`, `25`.
- H2 Wave 2 placeholder contracts: NIPs `18`, `22`, `23`, `27`, `36`, `48`, `56`, `58`, `98`, `99`.
- H3 defer/monitor placeholders: NIPs `03`, `14`, `24`, `26`, `30`, `31`, `32`, `38`, `39`, `41`,
  `52`, `53`, `57`, `60`, `61`.
- H3 rejected hold placeholders: NIPs `07`, `08`, `47`, `55`.

Placeholder gate requirements:

- no v1 module/function additions from these lanes in Phase D;
- no frozen default (`D-001..D-004`) changes;
- only documentation stubs and future contract skeleton IDs in later phases.

## Tradeoffs

## Tradeoff T-D-001: Deep per-module API specificity versus concise contracts

- Context: Phase D can be brief and defer detail, or explicit and implementation-ready.
- Options:
  - O1: concise per-module summaries.
  - O2: explicit signatures, bounds, failures, assertion pairs, and vector gates now.
- Decision: O2.
- Benefits: no architecture clarification needed before coding.
- Costs: longer artifact and higher up-front maintenance.
- Risks: signature drift if later edits are unmanaged.
- Mitigations: Phase E changes must update this file and include decision-log evidence when defaults
  change.
- Reversal Trigger: repeated evidence that over-specific contracts slow delivery without reducing
  implementation ambiguity.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: all v1 modules.

## Tradeoff T-D-002: Strict known-optional TLV rejection versus permissive optional parsing

- Context: NIP-19 optional known TLVs may appear malformed in ecosystem payloads.
- Options:
  - O1: permissive drop malformed known optional TLVs.
  - O2: reject malformed known optional TLVs in strict path.
- Decision: O2.
- Benefits: tighter typed integrity and deterministic error surfaces.
- Costs: stricter behavior than permissive peers.
- Risks: compatibility friction with malformed inputs.
- Mitigations: compatibility adapters can exist outside strict default path.
- Reversal Trigger: standards-backed requirement mandates permissive handling.
- Principles Impacted: P01, P03, P05.
- Scope Impacted: `nip19_bech32`, `nip21_uri`.

## Tradeoff T-D-003: Optional-module minimum vector gate stability versus immediate expansion

- Context: optional modules can either keep current baseline or increase vector burden now.
- Options:
  - O1: keep baseline `3 valid + 3 invalid` in v1.
  - O2: raise all optional modules to core-level vector depth immediately.
- Decision: O1.
- Benefits: consistent with prior phase decisions and phase velocity.
- Costs: lower immediate corpus depth for optional modules.
- Risks: optional behavior drift in low-diversity corpora.
- Mitigations: accepted-risk recorded and revisit trigger in Phase E corpus review.
- Reversal Trigger: parity regression in optional modules or repeated bug escapes.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: `nip19_bech32`, `nip21_uri`, `nip02_contacts`, `nip65_relays`, `nip45_count`,
  `nip50_search`, `nip77_negentropy`.

## Open Questions

- `OQ-D-001`: determine in Phase E whether `nip77_negentropy` requires higher invalid-vector density
  than other optional modules based on corpus complexity. Status: accepted-risk.
- `OQ-D-002`: determine in Phase E whether NIP-44 vector fixtures should add cross-language
  differential replay in CI beyond current pinned corpus. Status: accepted-risk.

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: cryptographic and trust-boundary failures are explicit (`nip01_event`, `nip42_auth`,
  `nip70_protected`, `nip44`, `nip59_wrap`).
- `P02`: module boundaries stay protocol-kernel focused; extension-lane items are placeholders only.
- `P03`: behavior parity contracts are explicit and implementation-ready across all v1 modules.
- `P04`: relay/auth/protected behavior is explicit and typed.
- `P05`: deterministic contracts include canonical serialization, ordering rules, and fixed
  check-order requirements.
- `P06`: bounded memory/work enforced by caller-buffer APIs, fixed capacities, and explicit overflow
  failures.
- Phase D gate status: pass; no high-impact ambiguity remains `decision-needed`.

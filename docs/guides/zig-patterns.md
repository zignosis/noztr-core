# Zig Patterns For `noztr` (0.15)

This guide is for low-level Nostr protocol work where determinism, bounds, and explicit failure
behavior matter more than convenience. Every pattern here is stdlib-only and designed for
TigerStyle constraints: fixed limits, simple control flow, assertion pairs, and static allocation.

## 1) Error-set design and explicit failure modes

Treat protocol failures as part of the API contract. Small, specific error sets make call sites
predictable, make tests precise, and avoid collapsing unrelated faults into `error.Invalid`.

```zig
const std = @import("std");
const assert = std.debug.assert;

pub const DecodeError = error{
    InputTooShort,
    InputTooLong,
    InvalidUtf8,
    InvalidHex,
    InvalidFieldCount,
    InvalidSignature,
    UnsupportedVersion,
};

pub fn parse_version(byte: u8) DecodeError!u8 {
    assert(byte <= 0x7f);

    if (byte == 1) {
        assert(byte != 0);
        return 1;
    }
    if (byte == 0) {
        return DecodeError.UnsupportedVersion;
    }
    return DecodeError.UnsupportedVersion;
}
```

- Keep one error set per boundary (`DecodeError`, `EncodeError`, `VerifyError`) instead of one
  global set.
- Name errors by failure mode, not implementation detail: `InvalidPubkeyLength`, not
  `SliceError`.
- Convert foreign errors immediately at boundaries so internal layers do not leak unrelated errors.
- For each public function, document all errors and add tests that force each one.

## 2) Canonical serialization patterns for deterministic hashing/signing

Canonical bytes must be one-to-one with semantic content. If two logically identical events can
produce different bytes, signatures and hashes will diverge.

```zig
const std = @import("std");
const assert = std.debug.assert;

const Event = struct {
    created_at: u64,
    kind: u32,
    pubkey: [32]u8,
    content_len: u16,
    content: [512]u8,
};

pub fn serialize_event(out: []u8, event: *const Event) error{BufferTooSmall}![]const u8 {
    assert(event.content_len <= event.content.len);
    assert(event.content_len <= 512);

    const need: u32 = 8 + 4 + 32 + 2 + event.content_len;
    if (out.len < need) return error.BufferTooSmall;
    assert(need > 0);

    var index: u32 = 0;
    std.mem.writeInt(u64, out[index..][0..8], event.created_at, .big);
    index += 8;
    std.mem.writeInt(u32, out[index..][0..4], event.kind, .big);
    index += 4;
    @memcpy(out[index..][0..32], event.pubkey[0..32]);
    index += 32;
    std.mem.writeInt(u16, out[index..][0..2], event.content_len, .big);
    index += 2;
    @memcpy(out[index..][0..event.content_len], event.content[0..event.content_len]);
    index += event.content_len;

    assert(index == need);
    assert(index <= out.len);
    return out[0..index];
}
```

- Serialize fields in a fixed order with fixed integer endianness (`.big` is common for protocol
  wire formats).
- Length-prefix variable fields (`content_len` before `content`) and assert max sizes.
- Never hash ad hoc JSON text directly; hash canonical bytes after normalization.
- Reject duplicate semantic encodings (for example, multiple ways to encode the same integer).

## 3) Fixed-capacity buffers and static allocation strategies

Use caller-owned memory and explicit capacities. This makes memory behavior deterministic and keeps
allocation policy out of protocol logic.

```zig
const std = @import("std");
const assert = std.debug.assert;

pub const FixedWriter = struct {
    bytes: [2048]u8,
    used: u16,

    pub fn init(self: *FixedWriter) void {
        self.* = .{ .bytes = [_]u8{0} ** 2048, .used = 0 };
        assert(self.used == 0);
        assert(self.bytes.len == 2048);
    }

    pub fn write(self: *FixedWriter, source: []const u8) error{NoSpace}!void {
        assert(self.used <= self.bytes.len);
        if (source.len == 0) return;

        const remaining: u16 = @intCast(self.bytes.len - self.used);
        if (source.len > remaining) return error.NoSpace;

        const start: u16 = self.used;
        const end: u16 = self.used + @as(u16, @intCast(source.len));
        @memcpy(self.bytes[start..end], source);
        self.used = end;

        assert(self.used >= start);
        assert(self.used <= self.bytes.len);
    }
};
```

- Prefer fixed arrays in state structs, and pass slices into helpers.
- Keep `used`, `capacity`, and index math in explicitly sized integers (`u16`, `u32`).
- Define maximum frame/event sizes once, and assert relationships at compile time when possible.
- For temporary JSON parse scratch, use `std.heap.FixedBufferAllocator` backed by static memory.

## 4) Safe parsing patterns for untrusted JSON/protocol messages

Untrusted input should pass through staged validation. Do not mix syntax parsing, semantic checks,
and state mutation in one function.

```zig
const std = @import("std");
const assert = std.debug.assert;

const ParseError = error{ InputTooLarge, InvalidJson, MissingField, InvalidField };

const EventEnvelope = struct {
    id: [64]u8,
    pubkey: [64]u8,
    kind: u32,
    content: []const u8,
};

pub fn parse_event_envelope(input: []const u8) ParseError!EventEnvelope {
    assert(input.len > 0);
    if (input.len > 4096) return ParseError.InputTooLarge;

    var scratch: [8192]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    const allocator = fixed.allocator();

    const parsed = std.json.parseFromSlice(EventEnvelope, allocator, input, .{}) catch {
        return ParseError.InvalidJson;
    };
    defer parsed.deinit();

    const value = parsed.value;
    if (value.kind > 65535) return ParseError.InvalidField;
    if (value.content.len > 1024) return ParseError.InvalidField;

    assert(value.content.len <= 1024);
    assert(value.kind <= 65535);
    return value;
}
```

- Stage 1: hard cap input size before any parse.
- Stage 2: parse into a narrow struct with fixed-size fields where possible.
- Stage 3: semantic validation (ranges, expected kinds, key lengths, timestamp window).
- Stage 4: only then hand validated data to storage/signature logic.
- On JSON APIs, prefer explicit required fields and reject unknown critical fields.

## 5) Crypto boundary patterns (key material handling, zeroing, ct comparisons)

Keep crypto code at clear boundaries: decode inputs, validate lengths, call primitive, wipe secrets,
and return explicit errors.

```zig
const std = @import("std");
const assert = std.debug.assert;

fn wipe_bytes(target: []u8) void {
    assert(target.len <= 128);
    var index: u32 = 0;
    while (index < target.len) : (index += 1) {
        @volatileStore(&target[index], 0);
    }
    assert(index == target.len);
    assert(target.len == 0 or target[0] == 0);
}

fn constant_time_equal(left: []const u8, right: []const u8) bool {
    assert(left.len <= 64);
    if (left.len != right.len) return false;

    var diff: u8 = 0;
    var index: u32 = 0;
    while (index < left.len) : (index += 1) {
        diff |= left[index] ^ right[index];
    }

    assert(index == left.len);
    assert(diff == 0 or diff != 0);
    return diff == 0;
}
```

- Never keep secret scalars in long-lived shared structs if function-local scope is enough.
- Wipe temporary key material with a dedicated wipe helper on every return path (`defer`).
- Use constant-time comparison for tags, MACs, and signatures after length checks.
- Do not branch on secret data or leak secret-dependent lengths in protocol-visible outputs.

## 6) Assertion-pair templates (positive and negative space)

Assertion pairs catch boundary mistakes early. For each invariant, assert what must hold and what
must not hold nearby in control flow.

```zig
const std = @import("std");
const assert = std.debug.assert;

fn decode_hex_32(source: []const u8, target: *[32]u8) error{InvalidLength, InvalidHex}!void {
    assert(source.len <= 64);
    if (source.len != 64) return error.InvalidLength;

    var i: u32 = 0;
    while (i < 32) : (i += 1) {
        const hi = std.fmt.charToDigit(source[i * 2], 16) catch return error.InvalidHex;
        const lo = std.fmt.charToDigit(source[i * 2 + 1], 16) catch return error.InvalidHex;
        target[i] = @intCast((hi << 4) | lo);
    }

    assert(i == 32);
    assert(source.len != 0);
}
```

- Precondition pair: `assert(source.len <= max);` and runtime error for invalid external lengths.
- Postcondition pair: `assert(index == expected);` and `assert(index <= buffer.len);`.
- State transition pair: assert old state before mutation and new state after mutation.
- Split conditions instead of `assert(a and b)` to localize failures quickly.

## 7) Test-vector harness patterns for protocol conformance

Protocol correctness comes from deterministic vectors, not random spot checks. Keep vectors in a
stable table and test encode, decode, hash, and verify paths against the same data.

```zig
const std = @import("std");
const assert = std.debug.assert;

const Vector = struct {
    name: []const u8,
    canonical_hex: []const u8,
    sha256_hex: [64]u8,
    should_accept: bool,
};

test "protocol vectors" {
    const vectors = [_]Vector{
        .{
            .name = "minimal_event",
            .canonical_hex = "000000000000000100000001" ++
                "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff" ++
                "0000",
            .sha256_hex = "2f4c9f6fd3e6e4f2b2b6f0ad11cd5be8d6f4b7d7a3e42035f709b721b8a3408e".*,
            .should_accept = true,
        },
    };

    for (vectors) |vector| {
        assert(vector.name.len > 0);
        assert(vector.canonical_hex.len > 0);

        if (vector.should_accept) {
            // Decode -> parse -> canonicalize -> hash -> compare expected hash.
            // Keep this flow identical across all vectors.
        } else {
            // Verify expected error branch for malformed vectors.
        }
    }
}
```

- Include both accepted and rejected vectors for each NIP feature.
- Test transition edges: max length, max tags, empty content, malformed UTF-8, bad signature.
- Keep harness deterministic: no network, no wall clock, no random seeds unless fixed.
- Put vector-name strings in failures so regressions map directly to fixture entries.

## 8) Anti-patterns to avoid

- Parsing and verifying in one pass with side effects (hard to test and easy to bypass checks).
- Using `usize` for protocol fields that are serialized (`u32`/`u16` should match wire format).
- Dynamic allocation growth during hot-path parse/verify logic.
- Broad error funnels (`catch |_| return error.Invalid`) that erase root cause.
- Hashing pretty-printed JSON or map iteration order instead of canonical wire bytes.
- Early returns that forget secret wiping, or comparisons that use non-constant-time equality.
- Compound condition trees that hide branch coverage gaps.
- Helpers that silently clamp or truncate invalid input instead of returning explicit errors.

These patterns are intended to be copied into `noztr` modules and adapted per NIP, while preserving
the same safety envelope: bounded inputs, canonical bytes, explicit failures, and deterministic
tests.

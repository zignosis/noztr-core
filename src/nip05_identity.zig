const std = @import("std");
const limits = @import("limits.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const relay_origin = @import("internal/relay_origin.zig");
const websocket_relay_url = @import("internal/websocket_relay_url.zig");

pub const Nip05Error = error{
    OutOfMemory,
    InvalidAddress,
    InvalidLocalPart,
    InvalidDomain,
    InvalidUrl,
    InvalidJson,
    MissingName,
    InvalidNames,
    InvalidPubkey,
    InvalidRelays,
    InvalidNip46,
    InvalidRelayUrl,
    TooManyRelays,
    BufferTooSmall,
};

pub const Address = struct {
    name: []const u8,
    domain: []const u8,
};

pub const Profile = struct {
    public_key: [32]u8,
    relays: []const []const u8 = &.{},
    nip46_relays: []const []const u8 = &.{},
};

const lookup_url_validation_bytes_max: usize =
    @as(usize, limits.nip05_identifier_bytes_max) + 40;

/// Parses a NIP-05 address or bare domain into canonical local-part plus domain.
pub fn address_parse(input: []const u8, scratch: std.mem.Allocator) Nip05Error!Address {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(input.len <= std.math.maxInt(usize));

    if (input.len > limits.tag_item_bytes_max) return error.InvalidAddress;
    const separator = std.mem.indexOfScalar(u8, input, '@');
    const parts = try split_address(input, separator);
    try validate_local_part(parts.name);
    try validate_domain(parts.domain);

    const owned_name = try duplicate_name(parts.name, scratch);
    errdefer if (!std.mem.eql(u8, owned_name, "_")) scratch.free(owned_name);
    const owned_domain = scratch.dupe(u8, parts.domain) catch return error.OutOfMemory;
    return .{ .name = owned_name, .domain = owned_domain };
}

/// Formats a canonical NIP-05 address as `<local>@<domain>`.
pub fn address_format(output: []u8, address: *const Address) Nip05Error![]const u8 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(address) != 0);

    try validate_local_part(address.name);
    try validate_domain(address.domain);
    var canonical_name_storage: [limits.nip05_identifier_bytes_max]u8 = undefined;
    const canonical_name = lowercase_ascii_copy(address.name, canonical_name_storage[0..]);
    return std.fmt.bufPrint(output, "{s}@{s}", .{ canonical_name, address.domain }) catch {
        return error.BufferTooSmall;
    };
}

/// Builds the canonical well-known lookup URL for a parsed NIP-05 address.
pub fn address_compose_well_known_url(
    output: []u8,
    address: *const Address,
) Nip05Error![]const u8 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(address) != 0);

    try validate_local_part(address.name);
    try validate_domain(address.domain);
    var canonical_name_storage: [limits.nip05_identifier_bytes_max]u8 = undefined;
    const canonical_name = lowercase_ascii_copy(address.name, canonical_name_storage[0..]);
    const rendered = std.fmt.bufPrint(
        output,
        "https://{s}/.well-known/nostr.json?name={s}",
        .{ address.domain, canonical_name },
    ) catch return error.BufferTooSmall;
    try validate_lookup_url(rendered);
    return rendered;
}

/// Parses a NIP-05 `nostr.json` response for the requested name plus optional `relays` and `nip46`.
pub fn profile_parse_json(
    address: *const Address,
    input: []const u8,
    scratch: std.mem.Allocator,
) Nip05Error!Profile {
    std.debug.assert(@intFromPtr(address) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = try parse_root_object(input, parse_arena.allocator());
    const object = root.object;
    const pubkey = try parse_names_pubkey(object, address.name);
    const relays = try parse_optional_relay_map(
        object.get("relays"),
        pubkey,
        scratch,
        .relays,
    );
    const nip46_relays =
        try parse_optional_relay_map(object.get("nip46"), pubkey, scratch, .nip46);
    return .{
        .public_key = pubkey,
        .relays = relays,
        .nip46_relays = nip46_relays,
    };
}

/// Verifies that a NIP-05 document maps the requested name to the expected public key.
pub fn profile_verify_json(
    expected_pubkey: *const [32]u8,
    address: *const Address,
    input: []const u8,
    scratch: std.mem.Allocator,
) Nip05Error!bool {
    std.debug.assert(@intFromPtr(expected_pubkey) != 0);
    std.debug.assert(@intFromPtr(address) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = try parse_root_object(input, parse_arena.allocator());
    const actual = parse_names_pubkey(root.object, address.name) catch |err| switch (err) {
        error.MissingName => return false,
        else => return err,
    };
    return std.mem.eql(u8, expected_pubkey[0..], actual[0..]);
}

const AddressParts = struct {
    name: []const u8,
    domain: []const u8,
};

const RelayMapKind = enum {
    relays,
    nip46,
};

fn split_address(input: []const u8, separator: ?usize) Nip05Error!AddressParts {
    std.debug.assert(input.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (input.len == 0) return error.InvalidAddress;
    if (input.len > limits.tag_item_bytes_max) return error.InvalidAddress;
    if (separator == null) {
        return .{ .name = "_", .domain = input };
    }

    const index = separator.?;
    if (std.mem.indexOfScalarPos(u8, input, index + 1, '@') != null) return error.InvalidAddress;
    if (index == 0 or index + 1 >= input.len) return error.InvalidAddress;

    return .{
        .name = input[0..index],
        .domain = input[index + 1 ..],
    };
}

fn duplicate_name(name: []const u8, scratch: std.mem.Allocator) Nip05Error![]const u8 {
    std.debug.assert(name.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (name.len > limits.nip05_identifier_bytes_max) return error.InvalidLocalPart;
    if (std.mem.eql(u8, name, "_")) return "_";
    const owned = scratch.alloc(u8, name.len) catch return error.OutOfMemory;
    @memcpy(owned, name);
    lowercase_ascii_in_place(owned);
    return owned;
}

fn parse_root_object(
    input: []const u8,
    parse_allocator: std.mem.Allocator,
) Nip05Error!std.json.Value {
    std.debug.assert(input.len <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(parse_allocator.ptr) != 0);

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        parse_allocator,
        input,
        .{},
    ) catch |parse_error| {
        return map_json_parse_error(parse_error);
    };
    if (root != .object) return error.InvalidJson;
    return root;
}

fn parse_names_pubkey(object: std.json.ObjectMap, name: []const u8) Nip05Error![32]u8 {
    std.debug.assert(name.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);

    if (name.len > limits.nip05_identifier_bytes_max) return error.InvalidLocalPart;
    const names = object.get("names") orelse return error.MissingName;
    if (names != .object) return error.InvalidNames;
    var canonical_name_storage: [limits.nip05_identifier_bytes_max]u8 = undefined;
    const canonical_name = lowercase_ascii_copy(name, canonical_name_storage[0..]);
    const value = names.object.get(canonical_name) orelse return error.MissingName;
    if (value != .string) return error.InvalidNames;
    return parse_lower_hex_32(value.string) catch return error.InvalidPubkey;
}

fn parse_optional_relay_map(
    value: ?std.json.Value,
    pubkey: [32]u8,
    scratch: std.mem.Allocator,
    kind: RelayMapKind,
) Nip05Error![]const []const u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.nip05_relays_max > 0);

    if (value == null) return &.{};
    if (value.? != .object) return relay_map_error(kind);

    const pubkey_hex = std.fmt.bytesToHex(pubkey, .lower);
    const relay_value = value.?.object.get(&pubkey_hex) orelse return &.{};
    return try parse_relay_array(relay_value, scratch, kind);
}

fn parse_relay_array(
    value: std.json.Value,
    scratch: std.mem.Allocator,
    kind: RelayMapKind,
) Nip05Error![]const []const u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.nip05_relays_max <= limits.nip46_relays_max);

    if (value != .array) return relay_map_error(kind);
    if (value.array.items.len > limits.nip05_relays_max) return error.TooManyRelays;

    const output = scratch.alloc([]const u8, value.array.items.len) catch return error.OutOfMemory;
    for (value.array.items, 0..) |item, index| {
        if (item != .string) return relay_map_error(kind);
        output[index] = try duplicate_relay_url(item.string, scratch);
    }
    return output;
}

fn relay_map_error(kind: RelayMapKind) Nip05Error {
    std.debug.assert(@typeInfo(RelayMapKind) == .@"enum");
    std.debug.assert(@typeInfo(Nip05Error) == .error_set);

    return switch (kind) {
        .relays => error.InvalidRelays,
        .nip46 => error.InvalidNip46,
    };
}

fn validate_local_part(name: []const u8) Nip05Error!void {
    std.debug.assert(name.len <= std.math.maxInt(usize));
    std.debug.assert(limits.nip05_identifier_bytes_max > 0);

    if (name.len == 0) return error.InvalidLocalPart;
    if (name.len > limits.nip05_identifier_bytes_max) return error.InvalidLocalPart;
    for (name) |byte| {
        if (byte >= 'a' and byte <= 'z') continue;
        if (byte >= 'A' and byte <= 'Z') continue;
        if (byte >= '0' and byte <= '9') continue;
        if (byte == '-' or byte == '_' or byte == '.') continue;
        return error.InvalidLocalPart;
    }
}

fn lowercase_ascii_in_place(text: []u8) void {
    std.debug.assert(text.len <= limits.nip05_identifier_bytes_max);
    std.debug.assert(limits.nip05_identifier_bytes_max > 0);

    for (text) |*byte| {
        byte.* = std.ascii.toLower(byte.*);
    }
}

fn lowercase_ascii_copy(text: []const u8, output: []u8) []const u8 {
    std.debug.assert(text.len <= limits.nip05_identifier_bytes_max);
    std.debug.assert(output.len >= text.len);

    for (text, 0..) |byte, index| {
        output[index] = std.ascii.toLower(byte);
    }
    return output[0..text.len];
}

fn validate_domain(domain: []const u8) Nip05Error!void {
    std.debug.assert(domain.len <= std.math.maxInt(usize));
    std.debug.assert(limits.nip05_identifier_bytes_max > 0);

    if (domain.len == 0) return error.InvalidDomain;
    if (domain.len > limits.nip05_identifier_bytes_max) return error.InvalidDomain;
    if (!std.unicode.utf8ValidateSlice(domain)) return error.InvalidDomain;
    for (domain) |byte| {
        if (std.ascii.isWhitespace(byte)) return error.InvalidDomain;
        if (byte == '/' or byte == '?' or byte == '#' or byte == '@' or byte == '\\') {
            return error.InvalidDomain;
        }
    }

    var buffer: [lookup_url_validation_bytes_max]u8 = undefined;
    const rendered = std.fmt.bufPrint(
        buffer[0..],
        "https://{s}/.well-known/nostr.json?name=_",
        .{domain},
    ) catch return error.InvalidDomain;
    try validate_lookup_url(rendered);
}

fn validate_lookup_url(text: []const u8) Nip05Error!void {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.content_bytes_max > 0);

    if (text.len > limits.content_bytes_max) return error.InvalidUrl;
    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (!std.mem.eql(u8, parsed.scheme, "https")) return error.InvalidUrl;
    if (parsed.host == null) return error.InvalidUrl;
}

fn duplicate_relay_url(text: []const u8, scratch: std.mem.Allocator) Nip05Error![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    _ = parse_relay_url(text) catch return error.InvalidRelayUrl;
    return scratch.dupe(u8, text) catch return error.OutOfMemory;
}

fn parse_relay_url(text: []const u8) error{InvalidRelayUrl}!relay_origin.WebsocketOrigin {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(relay_origin.WebsocketOrigin) > 0);

    return websocket_relay_url.parse_origin(text, limits.tag_item_bytes_max);
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.pubkey_hex_length);
    std.debug.assert(limits.pubkey_hex_length == 64);

    return lower_hex_32.parse(text);
}

fn map_json_parse_error(parse_error: anyerror) Nip05Error {
    std.debug.assert(@typeInfo(@TypeOf(parse_error)) == .error_set);
    std.debug.assert(@typeInfo(Nip05Error) == .error_set);

    return switch (parse_error) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidJson,
    };
}

test "address parse supports canonical and bare-domain forms" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const canonical = try address_parse("bob@example.com", arena.allocator());
    try std.testing.expectEqualStrings("bob", canonical.name);
    try std.testing.expectEqualStrings("example.com", canonical.domain);

    const bare = try address_parse("example.com", arena.allocator());
    try std.testing.expectEqualStrings("_", bare.name);
    try std.testing.expectEqualStrings("example.com", bare.domain);

    const root = try address_parse("_@example.com", arena.allocator());
    try std.testing.expectEqualStrings("_", root.name);
    try std.testing.expectEqualStrings("example.com", root.domain);

    const upper = try address_parse("Bob@Example.com", arena.allocator());
    try std.testing.expectEqualStrings("bob", upper.name);
    try std.testing.expectEqualStrings("Example.com", upper.domain);
}

test "address parse rejects malformed local part and domain" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidLocalPart,
        address_parse("a+b@example.com", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidAddress,
        address_parse("a@b@example.com", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidDomain,
        address_parse("bob@example.com/path", arena.allocator()),
    );
}

test "address formatting and well-known URL stay canonical" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const address = try address_parse("_@example.com", arena.allocator());
    var address_buffer: [128]u8 = undefined;
    const rendered = try address_format(address_buffer[0..], &address);
    try std.testing.expectEqualStrings("_@example.com", rendered);

    var url_buffer: [128]u8 = undefined;
    const url = try address_compose_well_known_url(url_buffer[0..], &address);
    try std.testing.expectEqualStrings(
        "https://example.com/.well-known/nostr.json?name=_",
        url,
    );

    const manual = Address{ .name = "Bob", .domain = "Example.com" };
    try std.testing.expectEqualStrings(
        "bob@Example.com",
        try address_format(address_buffer[0..], &manual),
    );
    try std.testing.expectEqualStrings(
        "https://Example.com/.well-known/nostr.json?name=bob",
        try address_compose_well_known_url(url_buffer[0..], &manual),
    );
}

test "profile parse and verify canonicalize uppercase local parts" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const json =
        \\{"names":{"bob":"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272"}}
    ;
    const address = try address_parse("Bob@example.com", arena.allocator());
    const expected = parse_lower_hex_32(
        "68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272",
    ) catch unreachable;

    const profile = try profile_parse_json(&address, json, arena.allocator());
    try std.testing.expectEqualSlices(u8, expected[0..], profile.public_key[0..]);
    try std.testing.expect(
        try profile_verify_json(&expected, &address, json, arena.allocator()),
    );
}

test "profile parse extracts pubkey relays and nip46 relays" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const pubkey = "68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272";
    const json_lines = [_][]const u8{
        "{\"names\":{\"_\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\",",
        "\"bad\":\"npub1ignored\"},\"relays\":{",
        "\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[",
        "\"wss://relay.example.com\",\"wss://relay2.example.com\"],",
        "\"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\":[\"not-a-relay\"]},",
        "\"nip46\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[",
        "\"wss://bunker.example.com\"]}}",
    };
    const json = try std.mem.concat(std.testing.allocator, u8, &json_lines);
    defer std.testing.allocator.free(json);

    const address = try address_parse("example.com", arena.allocator());
    const profile = try profile_parse_json(&address, json, arena.allocator());
    const expected = parse_lower_hex_32(pubkey) catch unreachable;
    try std.testing.expectEqualSlices(u8, expected[0..], profile.public_key[0..]);
    try std.testing.expectEqual(@as(usize, 2), profile.relays.len);
    try std.testing.expectEqualStrings("wss://relay.example.com", profile.relays[0]);
    try std.testing.expectEqual(@as(usize, 1), profile.nip46_relays.len);
    try std.testing.expectEqualStrings("wss://bunker.example.com", profile.nip46_relays[0]);
}

test "profile parse and verify reject invalid matched entries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bad_name_json =
        \\{"names":{"_":"NPUB1NOTHEX"}}
    ;
    const bad_relay_lines = [_][]const u8{
        "{\"names\":{\"_\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"},",
        "\"relays\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[",
        "\"https://not-a-websocket.example.com\"]}}",
    };
    const bad_relay_json = try std.mem.concat(std.testing.allocator, u8, &bad_relay_lines);
    defer std.testing.allocator.free(bad_relay_json);
    const address = try address_parse("example.com", arena.allocator());
    const expected = parse_lower_hex_32(
        "68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272",
    ) catch unreachable;

    try std.testing.expectError(
        error.InvalidPubkey,
        profile_parse_json(&address, bad_name_json, arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidRelayUrl,
        profile_parse_json(&address, bad_relay_json, arena.allocator()),
    );
    try std.testing.expectEqual(
        false,
        try profile_verify_json(&expected, &address, "{\"names\":{}}", arena.allocator()),
    );
}

test "nip05 public paths reject overlong caller input with typed errors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const overlong_local = ("a" ** 4097) ++ "@example.com";
    const overlong_domain = "bob@" ++ ("a" ** 4097);
    const overlong_relay =
        "{\"names\":{\"ok\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}," ++
        "\"relays\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[\"" ++
        "wss://" ++ ("a" ** 5000) ++ ".example\"]}}";

    try std.testing.expectError(
        error.InvalidAddress,
        address_parse("a" ** 5000, arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidAddress,
        address_parse(overlong_local, arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidAddress,
        address_parse(overlong_domain, arena.allocator()),
    );

    const address = Address{ .name = "ok", .domain = "example.com" };
    try std.testing.expectError(
        error.InvalidRelayUrl,
        profile_parse_json(&address, overlong_relay, arena.allocator()),
    );
}

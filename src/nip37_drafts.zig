const std = @import("std");
const limits = @import("limits.zig");
const json_string_writer = @import("internal/json_string_writer.zig");
const url_with_host = @import("internal/url_with_host.zig");
const relay_origin = @import("internal/relay_origin.zig");
const nip01_event = @import("nip01_event.zig");
const nip44 = @import("nip44.zig");

pub const draft_wrap_kind: u32 = 31234;
pub const private_relay_list_kind: u32 = 10013;

pub const DraftError = nip44.ConversationEncryptionError || error{
    OutOfMemory,
    InvalidDraftWrapKind,
    MissingIdentifierTag,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    MissingDraftKindTag,
    DuplicateDraftKindTag,
    InvalidDraftKindTag,
    DuplicateExpirationTag,
    InvalidExpirationTag,
    InvalidDraftJson,
    InvalidPrivateRelayListKind,
    InvalidPrivateRelayTag,
    InvalidPrivateRelayUrl,
    InvalidPrivateJson,
    InvalidPrivateTagArray,
    TooManyPrivateTags,
    TooManyPrivateTagItems,
    UnsupportedPrivateEncoding,
    BufferTooSmall,
};

pub const Wrap = struct {
    identifier: []const u8,
    draft_kind: u32,
    expiration: ?u64 = null,
    ciphertext: []const u8,
    is_deleted: bool,
};

pub const Plaintext = struct {
    identifier: []const u8,
    draft_kind: u32,
    expiration: ?u64 = null,
    plaintext_json: []const u8,
    is_deleted: bool,
};

pub const PrivateRelayList = struct {
    relay_count: u16,
    plaintext_json: []const u8,
};

pub const TagBuilder = struct {
    items: [2][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const TagBuilder) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Parses bounded NIP-37 draft-wrap metadata from a kind-31234 event.
pub fn draft_wrap_parse(event: *const nip01_event.Event) DraftError!Wrap {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.kind <= limits.kind_max);

    if (event.kind != draft_wrap_kind) return error.InvalidDraftWrapKind;

    var identifier: ?[]const u8 = null;
    var draft_kind: ?u32 = null;
    var expiration: ?u64 = null;
    for (event.tags) |tag| {
        try apply_draft_tag(tag, &identifier, &draft_kind, &expiration);
    }
    if (identifier == null) return error.MissingIdentifierTag;
    if (draft_kind == null) return error.MissingDraftKindTag;
    return .{
        .identifier = identifier.?,
        .draft_kind = draft_kind.?,
        .expiration = expiration,
        .ciphertext = event.content,
        .is_deleted = event.content.len == 0,
    };
}

/// Decrypts a NIP-37 draft-wrap payload and returns the validated plaintext JSON object.
pub fn draft_wrap_decrypt_json(
    plaintext_output: []u8,
    event: *const nip01_event.Event,
    author_private_key: *const [32]u8,
    scratch: std.mem.Allocator,
) DraftError!Plaintext {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(@intFromPtr(author_private_key) != 0);

    const info = try draft_wrap_parse(event);
    if (info.is_deleted) {
        return .{
            .identifier = info.identifier,
            .draft_kind = info.draft_kind,
            .expiration = info.expiration,
            .plaintext_json = "",
            .is_deleted = true,
        };
    }
    if (private_content_is_nip04_legacy(info.ciphertext)) {
        return error.UnsupportedPrivateEncoding;
    }

    const plaintext = try decrypt_private_content(
        plaintext_output,
        author_private_key,
        &event.pubkey,
        info.ciphertext,
    );
    try validate_draft_json(plaintext, info.draft_kind, scratch);
    return .{
        .identifier = info.identifier,
        .draft_kind = info.draft_kind,
        .expiration = info.expiration,
        .plaintext_json = plaintext,
        .is_deleted = false,
    };
}

/// Encrypts validated draft JSON for storage in a kind-31234 event `.content`.
pub fn draft_wrap_encrypt_json(
    output: []u8,
    author_private_key: *const [32]u8,
    author_pubkey: *const [32]u8,
    draft_json: []const u8,
    scratch: std.mem.Allocator,
) DraftError![]const u8 {
    std.debug.assert(@intFromPtr(author_private_key) != 0);
    std.debug.assert(@intFromPtr(author_pubkey) != 0);

    try validate_draft_json(draft_json, null, scratch);
    return encrypt_private_content(output, author_private_key, author_pubkey, draft_json);
}

/// Builds a canonical `d` tag for a NIP-37 draft wrap.
pub fn draft_build_identifier_tag(
    output: *TagBuilder,
    identifier: []const u8,
) DraftError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `k` tag for a NIP-37 draft wrap.
pub fn draft_build_kind_tag(
    output: *TagBuilder,
    kind: u32,
) DraftError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(kind <= limits.kind_max);

    if (kind == draft_wrap_kind) return error.InvalidDraftKindTag;
    output.items[0] = "k";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{kind}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `expiration` tag for a NIP-37 draft wrap.
pub fn draft_build_expiration_tag(
    output: *TagBuilder,
    unix_seconds: u64,
) DraftError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(unix_seconds <= std.math.maxInt(u64));

    output.items[0] = "expiration";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{unix_seconds}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical private `relay` tag for kind-10013 plaintext JSON.
pub fn private_relay_build_tag(
    output: *TagBuilder,
    relay_url: []const u8,
) DraftError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);

    output.items[0] = "relay";
    output.items[1] = parse_relay_url(relay_url) catch return error.InvalidPrivateRelayUrl;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Serializes private relay tags into the encrypted JSON-array plaintext form for kind-10013.
pub fn private_relay_list_serialize_json(
    output: []u8,
    tags: []const nip01_event.EventTag,
) DraftError![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(usize));
    std.debug.assert(tags.len <= limits.tags_max);

    if (tags.len > limits.tags_max) return error.TooManyPrivateTags;

    var stream = std.io.fixedBufferStream(output);
    const writer = stream.writer();
    try write_private_byte(writer, '[');
    for (tags, 0..) |tag, index| {
        if (index != 0) try write_private_byte(writer, ',');
        try write_private_relay_tag_json(writer, tag);
    }
    try write_private_byte(writer, ']');
    return stream.getWritten();
}

/// Parses kind-10013 private JSON content into ordered relay URLs.
pub fn private_relay_list_extract_json(
    input_json: []const u8,
    out: [][]const u8,
    scratch: std.mem.Allocator,
) DraftError!PrivateRelayList {
    std.debug.assert(out.len <= limits.tags_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const root = try parse_private_json_root(input_json, scratch);
    var count: u16 = 0;
    for (root.array.items) |tag_value| {
        const relay_url = parse_private_relay_tag(tag_value) catch |err| switch (err) {
            error.InvalidPrivateTagArray => return error.InvalidPrivateTagArray,
            error.TooManyPrivateTagItems => return error.TooManyPrivateTagItems,
            error.InvalidPrivateRelayTag => return error.InvalidPrivateRelayTag,
            error.InvalidPrivateRelayUrl => return error.InvalidPrivateRelayUrl,
            error.UnexpectedTag => continue,
        };
        if (count == out.len) return error.BufferTooSmall;
        out[count] = relay_url;
        count += 1;
    }
    return .{ .relay_count = count, .plaintext_json = input_json };
}

/// Decrypts kind-10013 private relay-list content and extracts ordered relay URLs.
pub fn private_relay_list_extract_nip44(
    plaintext_output: []u8,
    event: *const nip01_event.Event,
    author_private_key: *const [32]u8,
    out: [][]const u8,
    scratch: std.mem.Allocator,
) DraftError!PrivateRelayList {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(@intFromPtr(author_private_key) != 0);

    if (event.kind != private_relay_list_kind) return error.InvalidPrivateRelayListKind;
    if (event.content.len == 0) {
        return .{ .relay_count = 0, .plaintext_json = "" };
    }
    if (private_content_is_nip04_legacy(event.content)) {
        return error.UnsupportedPrivateEncoding;
    }

    const plaintext = try decrypt_private_content(
        plaintext_output,
        author_private_key,
        &event.pubkey,
        event.content,
    );
    return private_relay_list_extract_json(plaintext, out, scratch);
}

fn apply_draft_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    draft_kind: *?u32,
    expiration: *?u64,
) DraftError!void {
    std.debug.assert(@intFromPtr(identifier) != 0);
    std.debug.assert(@intFromPtr(draft_kind) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return parse_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, tag.items[0], "k")) return parse_kind_tag(tag, draft_kind);
    if (std.mem.eql(u8, tag.items[0], "expiration")) {
        return parse_expiration_tag(tag, expiration);
    }
}

fn parse_identifier_tag(tag: nip01_event.EventTag, identifier: *?[]const u8) DraftError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(identifier) != 0);

    if (identifier.* != null) return error.DuplicateIdentifierTag;
    identifier.* = parse_single_utf8_value(tag) catch return error.InvalidIdentifierTag;
}

fn parse_kind_tag(tag: nip01_event.EventTag, draft_kind: *?u32) DraftError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(draft_kind) != 0);

    if (draft_kind.* != null) return error.DuplicateDraftKindTag;
    const text = parse_single_utf8_value(tag) catch return error.InvalidDraftKindTag;
    const kind = parse_decimal_u32(text) catch return error.InvalidDraftKindTag;
    if (kind == draft_wrap_kind) return error.InvalidDraftKindTag;
    draft_kind.* = kind;
}

fn parse_expiration_tag(tag: nip01_event.EventTag, expiration: *?u64) DraftError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(expiration) != 0);

    if (expiration.* != null) return error.DuplicateExpirationTag;
    const text = parse_single_utf8_value(tag) catch return error.InvalidExpirationTag;
    expiration.* = parse_decimal_u64(text) catch return error.InvalidExpirationTag;
}

fn parse_single_utf8_value(tag: nip01_event.EventTag) error{InvalidTag}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidTag;
    return parse_nonempty_utf8(tag.items[1]);
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidTag}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (text.len == 0) return error.InvalidTag;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidTag;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidTag;
    return text;
}

fn parse_decimal_u32(text: []const u8) error{InvalidDecimal}!u32 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidDecimal;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidDecimal;
    for (text) |byte| {
        if (byte < '0' or byte > '9') return error.InvalidDecimal;
    }
    return std.fmt.parseInt(u32, text, 10) catch return error.InvalidDecimal;
}

fn parse_decimal_u64(text: []const u8) error{InvalidDecimal}!u64 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidDecimal;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidDecimal;
    for (text) |byte| {
        if (byte < '0' or byte > '9') return error.InvalidDecimal;
    }
    return std.fmt.parseInt(u64, text, 10) catch return error.InvalidDecimal;
}

fn validate_draft_json(
    input: []const u8,
    expected_kind: ?u32,
    scratch: std.mem.Allocator,
) DraftError!void {
    std.debug.assert(input.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (input.len == 0) return error.InvalidDraftJson;
    if (input.len > limits.content_bytes_max) return error.InvalidDraftJson;
    if (!std.unicode.utf8ValidateSlice(input)) return error.InvalidDraftJson;
    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        parse_arena.allocator(),
        input,
        .{},
    ) catch |err| return map_json_parse_error(err, error.InvalidDraftJson);
    if (root != .object) return error.InvalidDraftJson;
    try validate_draft_event_shape(root.object);
    if (expected_kind) |kind| {
        try validate_draft_kind_match(root.object, kind);
    }
}

fn validate_draft_event_shape(object: std.json.ObjectMap) DraftError!void {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(limits.kind_max > 0);

    const kind_value = object.get("kind") orelse return error.InvalidDraftJson;
    if (kind_value != .integer) return error.InvalidDraftJson;
    if (kind_value.integer < 0) return error.InvalidDraftJson;
    if (kind_value.integer > limits.kind_max) return error.InvalidDraftJson;

    const tags_value = object.get("tags") orelse return error.InvalidDraftJson;
    if (tags_value != .array) return error.InvalidDraftJson;

    const content_value = object.get("content") orelse return error.InvalidDraftJson;
    if (content_value != .string) return error.InvalidDraftJson;
}

fn validate_draft_kind_match(object: std.json.ObjectMap, expected_kind: u32) DraftError!void {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(expected_kind <= limits.kind_max);

    const kind_value = object.get("kind") orelse return error.InvalidDraftJson;
    if (kind_value != .integer) return error.InvalidDraftJson;
    if (kind_value.integer < 0) return error.InvalidDraftJson;
    if (kind_value.integer > limits.kind_max) return error.InvalidDraftJson;
    if (@as(u32, @intCast(kind_value.integer)) != expected_kind) {
        return error.InvalidDraftJson;
    }
}

fn decrypt_private_content(
    plaintext_output: []u8,
    author_private_key: *const [32]u8,
    author_pubkey: *const [32]u8,
    ciphertext: []const u8,
) DraftError![]const u8 {
    std.debug.assert(@intFromPtr(author_private_key) != 0);
    std.debug.assert(@intFromPtr(author_pubkey) != 0);

    var conversation_key = try nip44.nip44_get_conversation_key(author_private_key, author_pubkey);
    defer std.crypto.secureZero(u8, conversation_key[0..]);
    return nip44.nip44_decrypt_from_base64(plaintext_output, &conversation_key, ciphertext);
}

fn encrypt_private_content(
    output: []u8,
    author_private_key: *const [32]u8,
    author_pubkey: *const [32]u8,
    plaintext: []const u8,
) DraftError![]const u8 {
    std.debug.assert(@intFromPtr(author_private_key) != 0);
    std.debug.assert(@intFromPtr(author_pubkey) != 0);

    var conversation_key = try nip44.nip44_get_conversation_key(author_private_key, author_pubkey);
    defer std.crypto.secureZero(u8, conversation_key[0..]);
    return nip44.nip44_encrypt_to_base64(
        output,
        &conversation_key,
        plaintext,
        null,
        random_nonce_provider,
    );
}

fn parse_private_json_root(
    input_json: []const u8,
    parse_allocator: std.mem.Allocator,
) DraftError!std.json.Value {
    std.debug.assert(input_json.len <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(parse_allocator.ptr) != 0);

    if (input_json.len == 0) return error.InvalidPrivateJson;
    if (!std.unicode.utf8ValidateSlice(input_json)) return error.InvalidPrivateJson;
    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        parse_allocator,
        input_json,
        .{},
    ) catch |err| {
        return map_json_parse_error(err, error.InvalidPrivateJson);
    };
    if (root != .array) return error.InvalidPrivateJson;
    if (root.array.items.len > limits.tags_max) return error.TooManyPrivateTags;
    return root;
}

fn parse_private_relay_tag(value: std.json.Value) error{
    InvalidPrivateTagArray,
    TooManyPrivateTagItems,
    InvalidPrivateRelayTag,
    InvalidPrivateRelayUrl,
    UnexpectedTag,
}![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.tag_items_max >= 2);

    if (value != .array) return error.InvalidPrivateTagArray;
    if (value.array.items.len == 0) return error.InvalidPrivateTagArray;
    if (value.array.items.len > limits.tag_items_max) return error.TooManyPrivateTagItems;

    var items: [limits.tag_items_max][]const u8 = undefined;
    for (value.array.items, 0..) |item, index| {
        if (item != .string) return error.InvalidPrivateTagArray;
        items[index] = try validate_private_tag_item(item.string);
    }
    if (!std.mem.eql(u8, items[0], "relay")) return error.UnexpectedTag;
    if (value.array.items.len != 2) return error.InvalidPrivateRelayTag;
    return parse_relay_url(items[1]) catch return error.InvalidPrivateRelayUrl;
}

fn validate_private_tag_item(text: []const u8) error{InvalidPrivateTagArray}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidPrivateTagArray;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidPrivateTagArray;
    return text;
}

fn write_private_relay_tag_json(writer: anytype, tag: nip01_event.EventTag) DraftError!void {
    std.debug.assert(@TypeOf(writer) != void);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) return error.InvalidPrivateRelayTag;
    if (!std.mem.eql(u8, tag.items[0], "relay")) return error.InvalidPrivateRelayTag;
    _ = parse_relay_url(tag.items[1]) catch return error.InvalidPrivateRelayUrl;
    try write_private_byte(writer, '[');
    try write_private_string_json(writer, tag.items[0]);
    try write_private_byte(writer, ',');
    try write_private_string_json(writer, tag.items[1]);
    try write_private_byte(writer, ']');
}

fn write_private_string_json(writer: anytype, value: []const u8) DraftError!void {
    std.debug.assert(@TypeOf(writer) != void);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    json_string_writer.write_string_json(writer, value, .reject) catch |err| switch (err) {
        error.BufferTooSmall => return error.BufferTooSmall,
        error.InvalidControlByte => return error.InvalidPrivateTagArray,
    };
}

fn write_private_escape(writer: anytype, suffix: u8) DraftError!void {
    std.debug.assert(@TypeOf(writer) != void);
    std.debug.assert(suffix <= 255);

    try json_string_writer.write_escape(writer, suffix);
}

fn write_private_byte(writer: anytype, byte: u8) DraftError!void {
    std.debug.assert(@TypeOf(writer) != void);
    std.debug.assert(byte <= 255);

    try json_string_writer.write_byte(writer, byte);
}

test "draft private JSON rejects control bytes in tag items" {
    var buffer: [32]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    try std.testing.expectError(
        error.InvalidPrivateTagArray,
        write_private_string_json(stream.writer(), &[_]u8{0x01}),
    );
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    return url_with_host.parse(text, limits.tag_item_bytes_max);
}

fn parse_relay_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUrl;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidUrl;
    if (relay_origin.parse_websocket_origin(text) == null) return error.InvalidUrl;
    return text;
}

fn private_content_is_nip04_legacy(content: []const u8) bool {
    std.debug.assert(content.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(u8) == 1);

    return std.mem.indexOf(u8, content, "?iv=") != null;
}

fn random_nonce_provider(_: ?*anyopaque, nonce_output: *[32]u8) nip44.ConversationEncryptionError!void {
    std.debug.assert(@intFromPtr(nonce_output) != 0);
    std.debug.assert(nonce_output.len == limits.nip44_nonce_bytes);

    std.crypto.random.bytes(nonce_output[0..]);
}

fn map_json_parse_error(
    parse_error: anyerror,
    fallback: DraftError,
) DraftError {
    std.debug.assert(@typeInfo(DraftError) == .error_set);
    std.debug.assert(@typeInfo(@TypeOf(parse_error)) == .error_set);

    return switch (parse_error) {
        error.OutOfMemory => error.OutOfMemory,
        else => fallback,
    };
}

fn event_for_tags(
    kind: u32,
    tags: []const nip01_event.EventTag,
    content: []const u8,
) nip01_event.Event {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(tags.len <= limits.tags_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{2} ** 32,
        .created_at = 1,
        .kind = kind,
        .tags = tags,
        .content = content,
        .sig = [_]u8{0} ** 64,
    };
}

test "draft wrap parse extracts required tags and deleted state" {
    var tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "draft-1" } },
        .{ .items = &.{ "k", "1" } },
        .{ .items = &.{ "expiration", "1700000000" } },
    };
    const event = event_for_tags(draft_wrap_kind, tags[0..], "");

    const parsed = try draft_wrap_parse(&event);
    try std.testing.expectEqualStrings("draft-1", parsed.identifier);
    try std.testing.expectEqual(@as(u32, 1), parsed.draft_kind);
    try std.testing.expectEqual(@as(?u64, 1_700_000_000), parsed.expiration);
    try std.testing.expect(parsed.is_deleted);
}

test "draft wrap parse rejects duplicate required tags" {
    var tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "draft-1" } },
        .{ .items = &.{ "d", "draft-2" } },
        .{ .items = &.{ "k", "1" } },
    };
    const event = event_for_tags(draft_wrap_kind, tags[0..], "ciphertext");

    try std.testing.expectError(error.DuplicateIdentifierTag, draft_wrap_parse(&event));
    try std.testing.expect(tags.len == 3);
}

test "draft wrap decrypt validates decrypted json object" {
    const allocator = std.testing.allocator;
    const private_key = [_]u8{1} ** 32;
    const public_key = [_]u8{2} ** 32;
    const draft_json =
        "{\"kind\":1,\"created_at\":1,\"tags\":[],\"content\":\"hello\",\"pubkey\":\"aa\"}";

    var ciphertext: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const encoded = try draft_wrap_encrypt_json(
        ciphertext[0..],
        &private_key,
        &public_key,
        draft_json,
        allocator,
    );
    var tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "draft-1" } },
        .{ .items = &.{ "k", "1" } },
    };
    var event = event_for_tags(draft_wrap_kind, tags[0..], encoded);
    event.pubkey = public_key;

    var plaintext: [limits.nip44_plaintext_max_bytes]u8 = undefined;
    const parsed = try draft_wrap_decrypt_json(plaintext[0..], &event, &private_key, allocator);
    try std.testing.expectEqualStrings("draft-1", parsed.identifier);
    try std.testing.expectEqual(@as(u32, 1), parsed.draft_kind);
    try std.testing.expectEqualStrings(draft_json, parsed.plaintext_json);
    try std.testing.expect(!parsed.is_deleted);
}

test "draft wrap decrypt rejects legacy private encoding" {
    const allocator = std.testing.allocator;
    const private_key = [_]u8{1} ** 32;
    var tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "draft-1" } },
        .{ .items = &.{ "k", "1" } },
    };
    const event = event_for_tags(draft_wrap_kind, tags[0..], "abc?iv=legacy");
    var plaintext: [limits.nip44_plaintext_max_bytes]u8 = undefined;

    try std.testing.expectError(
        error.UnsupportedPrivateEncoding,
        draft_wrap_decrypt_json(plaintext[0..], &event, &private_key, allocator),
    );
}

test "draft wrap decrypt rejects mismatched decrypted draft kind" {
    const allocator = std.testing.allocator;
    const private_key = [_]u8{1} ** 32;
    const public_key = [_]u8{2} ** 32;
    const draft_json =
        "{\"kind\":42,\"created_at\":1,\"tags\":[],\"content\":\"hello\"}";

    var ciphertext: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const encoded = try draft_wrap_encrypt_json(
        ciphertext[0..],
        &private_key,
        &public_key,
        draft_json,
        allocator,
    );
    var tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "draft-1" } },
        .{ .items = &.{ "k", "1" } },
    };
    var event = event_for_tags(draft_wrap_kind, tags[0..], encoded);
    event.pubkey = public_key;
    var plaintext: [limits.nip44_plaintext_max_bytes]u8 = undefined;

    try std.testing.expectError(
        error.InvalidDraftJson,
        draft_wrap_decrypt_json(plaintext[0..], &event, &private_key, allocator),
    );
}

test "draft wrap encrypt rejects non-event-shaped json objects" {
    const allocator = std.testing.allocator;
    const private_key = [_]u8{1} ** 32;
    const public_key = [_]u8{2} ** 32;
    var ciphertext: [limits.nip44_payload_base64_max_bytes]u8 = undefined;

    try std.testing.expectError(
        error.InvalidDraftJson,
        draft_wrap_encrypt_json(
            ciphertext[0..],
            &private_key,
            &public_key,
            "{\"kind\":1,\"note\":\"missing tags and content\"}",
            allocator,
        ),
    );
}

test "private relay list serialize and extract json" {
    var builder_a = TagBuilder{};
    var builder_b = TagBuilder{};
    const tag_a = try private_relay_build_tag(&builder_a, "wss://relay.one");
    const tag_b = try private_relay_build_tag(&builder_b, "wss://relay.two");
    const tags = [_]nip01_event.EventTag{ tag_a, tag_b };

    var json_output: [256]u8 = undefined;
    const json = try private_relay_list_serialize_json(json_output[0..], tags[0..]);
    var relay_urls: [4][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed = try private_relay_list_extract_json(json, relay_urls[0..], arena.allocator());
    try std.testing.expectEqual(@as(u16, 2), parsed.relay_count);
    try std.testing.expectEqualStrings("wss://relay.one", relay_urls[0]);
    try std.testing.expectEqualStrings("wss://relay.two", relay_urls[1]);
}

test "private relay list extract nip44 decrypts relay urls" {
    const private_key = [_]u8{1} ** 32;
    const public_key = [_]u8{2} ** 32;
    const json = "[[\"relay\",\"wss://relay.one\"],[\"relay\",\"wss://relay.two\"]]";

    var ciphertext: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const encoded = try encrypt_private_content(
        ciphertext[0..],
        &private_key,
        &public_key,
        json,
    );
    const event = event_for_tags(private_relay_list_kind, &.{}, encoded);
    var relay_event = event;
    relay_event.pubkey = public_key;
    var plaintext: [limits.nip44_plaintext_max_bytes]u8 = undefined;
    var relay_urls: [4][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed = try private_relay_list_extract_nip44(
        plaintext[0..],
        &relay_event,
        &private_key,
        relay_urls[0..],
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(u16, 2), parsed.relay_count);
    try std.testing.expectEqualStrings(json, parsed.plaintext_json);
}

test "private relay list extract rejects malformed relay tag" {
    var relay_urls: [1][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidPrivateRelayUrl,
        private_relay_list_extract_json(
            "[[\"relay\",\"not a url\"]]",
            relay_urls[0..],
            arena.allocator(),
        ),
    );
}

test "private relay list rejects non-websocket relay urls" {
    var relay_urls: [1][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var built: TagBuilder = .{};

    try std.testing.expectError(
        error.InvalidPrivateRelayUrl,
        private_relay_build_tag(&built, "https://relay.example"),
    );
    try std.testing.expectError(
        error.InvalidPrivateRelayUrl,
        private_relay_list_extract_json(
            "[[\"relay\",\"https://relay.example\"]]",
            relay_urls[0..],
            arena.allocator(),
        ),
    );
}

test "draft builders reject overlong caller input with typed errors" {
    var built: TagBuilder = .{};
    const overlong_identifier = "x" ** (limits.tag_item_bytes_max + 1);
    const overlong_relay = "wss://" ++ ("a" ** 9000) ++ ".example";

    try std.testing.expectError(
        error.InvalidIdentifierTag,
        draft_build_identifier_tag(&built, overlong_identifier[0..]),
    );
    try std.testing.expectError(
        error.InvalidPrivateRelayUrl,
        private_relay_build_tag(&built, overlong_relay),
    );
}

test "draft wrap encrypt rejects overlong draft json with typed error" {
    const allocator = std.testing.allocator;
    const private_key = [_]u8{1} ** 32;
    const public_key = [_]u8{2} ** 32;
    var ciphertext: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const overlong_json = "{" ++ ("a" ** limits.content_bytes_max) ++ "}";

    try std.testing.expectError(
        error.InvalidDraftJson,
        draft_wrap_encrypt_json(
            ciphertext[0..],
            &private_key,
            &public_key,
            overlong_json[0..],
            allocator,
        ),
    );
}

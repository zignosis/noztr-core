const std = @import("std");
const limits = @import("limits.zig");

pub const Nip11Error = error{
    InvalidJson,
    InvalidKnownFieldType,
    InvalidStructuredField,
    InputTooLong,
};

pub const Limitation = struct {
    max_message_length: ?u32 = null,
    max_subscriptions: ?u32 = null,
    max_filters: ?u32 = null,
    max_limit: ?u32 = null,
    max_subid_length: ?u32 = null,
    max_event_tags: ?u32 = null,
    max_content_length: ?u32 = null,
    min_pow_difficulty: ?u32 = null,
};

pub const RelayInformationDocument = struct {
    name: ?[]const u8 = null,
    pubkey: ?[]const u8 = null,
    supported_nips: []const u32 = &.{},
    limitation: ?Limitation = null,
};

pub fn nip11_parse_document(
    input: []const u8,
    scratch: std.mem.Allocator,
) Nip11Error!RelayInformationDocument {
    std.debug.assert(input.len <= limits.relay_message_bytes_max + 1);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (input.len > limits.relay_message_bytes_max) {
        return error.InputTooLong;
    }
    const root = std.json.parseFromSliceLeaky(std.json.Value, scratch, input, .{}) catch {
        return error.InvalidJson;
    };
    if (root != .object) {
        return error.InvalidJson;
    }

    var document = RelayInformationDocument{};
    var iterator = root.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;
        try parse_known_top_level_field(&document, key, value, scratch);
    }

    try nip11_validate_known_fields(&document);
    return document;
}

pub fn nip11_validate_known_fields(doc: *const RelayInformationDocument) Nip11Error!void {
    std.debug.assert(doc.supported_nips.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(doc) != 0);

    if (doc.name) |name| {
        if (!std.unicode.utf8ValidateSlice(name)) {
            return error.InvalidKnownFieldType;
        }
    }
    if (doc.pubkey) |pubkey| {
        if (!std.unicode.utf8ValidateSlice(pubkey)) {
            return error.InvalidKnownFieldType;
        }
    }

    var index: usize = 0;
    while (index < doc.supported_nips.len) : (index += 1) {
        _ = doc.supported_nips[index];
    }
}

fn parse_known_top_level_field(
    doc: *RelayInformationDocument,
    key: []const u8,
    value: std.json.Value,
    scratch: std.mem.Allocator,
) Nip11Error!void {
    std.debug.assert(@intFromPtr(doc) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (std.mem.eql(u8, key, "name")) {
        if (value != .string) {
            return error.InvalidKnownFieldType;
        }
        doc.name = value.string;
        return;
    }
    if (std.mem.eql(u8, key, "pubkey")) {
        if (value != .string) {
            return error.InvalidKnownFieldType;
        }
        doc.pubkey = value.string;
        return;
    }
    if (std.mem.eql(u8, key, "supported_nips")) {
        doc.supported_nips = try parse_supported_nips(value, scratch);
        return;
    }
    if (std.mem.eql(u8, key, "limitation")) {
        doc.limitation = try parse_limitation(value);
        return;
    }
}

fn parse_supported_nips(value: std.json.Value, scratch: std.mem.Allocator) Nip11Error![]const u32 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .array) {
        return error.InvalidKnownFieldType;
    }
    const output = scratch.alloc(u32, value.array.items.len) catch return error.InvalidJson;

    var index: usize = 0;
    while (index < value.array.items.len) : (index += 1) {
        const item = value.array.items[index];
        if (item != .integer) {
            return error.InvalidKnownFieldType;
        }
        if (item.integer < 0) {
            return error.InvalidKnownFieldType;
        }
        output[index] = std.math.cast(u32, item.integer) orelse return error.InvalidKnownFieldType;
    }
    return output;
}

fn parse_limitation(value: std.json.Value) Nip11Error!Limitation {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(Limitation) > 0);

    if (value != .object) {
        return error.InvalidStructuredField;
    }

    var limitation = Limitation{};
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const field_value = entry.value_ptr.*;
        try parse_known_limitation_field(&limitation, key, field_value);
    }
    return limitation;
}

fn parse_known_limitation_field(
    limitation: *Limitation,
    key: []const u8,
    field_value: std.json.Value,
) Nip11Error!void {
    std.debug.assert(@intFromPtr(limitation) != 0);
    std.debug.assert(key.len <= 64);

    if (std.mem.eql(u8, key, "max_message_length")) {
        limitation.max_message_length = try parse_limitation_u32(field_value);
        return;
    }
    if (std.mem.eql(u8, key, "max_subscriptions")) {
        limitation.max_subscriptions = try parse_limitation_u32(field_value);
        return;
    }
    if (std.mem.eql(u8, key, "max_filters")) {
        limitation.max_filters = try parse_limitation_u32(field_value);
        return;
    }
    if (std.mem.eql(u8, key, "max_limit")) {
        limitation.max_limit = try parse_limitation_u32(field_value);
        return;
    }
    if (std.mem.eql(u8, key, "max_subid_length")) {
        limitation.max_subid_length = try parse_limitation_u32(field_value);
        return;
    }
    if (std.mem.eql(u8, key, "max_event_tags")) {
        limitation.max_event_tags = try parse_limitation_u32(field_value);
        return;
    }
    if (std.mem.eql(u8, key, "max_content_length")) {
        limitation.max_content_length = try parse_limitation_u32(field_value);
        return;
    }
    if (std.mem.eql(u8, key, "min_pow_difficulty")) {
        limitation.min_pow_difficulty = try parse_limitation_u32(field_value);
        return;
    }
}

fn parse_limitation_u32(field_value: std.json.Value) Nip11Error!u32 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(u32) == 4);

    if (field_value != .integer) {
        return error.InvalidStructuredField;
    }
    if (field_value.integer < 0) {
        return error.InvalidStructuredField;
    }
    return std.math.cast(u32, field_value.integer) orelse error.InvalidStructuredField;
}

test "nip11 parses partial valid document" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const input =
        "{" ++
        "\"name\":\"relay-a\"," ++
        "\"supported_nips\":[1,11,42]," ++
        "\"limitation\":{\"max_message_length\":2048}}";
    const document = try nip11_parse_document(input, arena.allocator());

    try std.testing.expectEqualStrings("relay-a", document.name.?);
    try std.testing.expect(document.supported_nips.len == 3);
    try std.testing.expect(document.limitation.?.max_message_length.? == 2048);
}

test "nip11 valid vectors satisfy strict known-field and unknown-field behavior" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const vector_1 =
        "{" ++
        "\"name\":\"relay-a\"," ++
        "\"supported_nips\":[1]," ++
        "\"unknown_field\":{\"anything\":true}}";
    const document_1 = try nip11_parse_document(vector_1, arena.allocator());

    try std.testing.expectEqualStrings("relay-a", document_1.name.?);
    try std.testing.expectEqual(@as(u32, 1), document_1.supported_nips[0]);

    const vector_2 =
        "{" ++
        "\"pubkey\":\"aabbcc\"," ++
        "\"limitation\":{\"max_subscriptions\":100," ++
        "\"unknown_nested\":9}}";
    const document_2 = try nip11_parse_document(vector_2, arena.allocator());

    try std.testing.expectEqualStrings("aabbcc", document_2.pubkey.?);
    try std.testing.expectEqual(@as(u32, 100), document_2.limitation.?.max_subscriptions.?);

    const vector_3 =
        "{" ++
        "\"name\":\"relay-b\"," ++
        "\"supported_nips\":[]}";
    const document_3 = try nip11_parse_document(vector_3, arena.allocator());

    try std.testing.expectEqualStrings("relay-b", document_3.name.?);
    try std.testing.expectEqual(@as(usize, 0), document_3.supported_nips.len);

    const vector_4 =
        "{" ++
        "\"limitation\":{" ++
        "\"max_message_length\":1024," ++
        "\"max_content_length\":4096," ++
        "\"min_pow_difficulty\":20}}";
    const document_4 = try nip11_parse_document(vector_4, arena.allocator());

    try std.testing.expect(document_4.limitation != null);
    try std.testing.expectEqual(@as(u32, 1024), document_4.limitation.?.max_message_length.?);

    const vector_5 = "{}";
    const document_5 = try nip11_parse_document(vector_5, arena.allocator());

    try std.testing.expect(document_5.name == null);
    try std.testing.expectEqual(@as(usize, 0), document_5.supported_nips.len);
}

test "nip11 invalid vectors reject typed failures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidKnownFieldType,
        nip11_parse_document("{\"name\":10}", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidKnownFieldType,
        nip11_parse_document("{\"pubkey\":3}", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidKnownFieldType,
        nip11_parse_document("{\"supported_nips\":\"11\"}", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidKnownFieldType,
        nip11_parse_document("{\"supported_nips\":[1,\"x\"]}", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidStructuredField,
        nip11_parse_document("{\"limitation\":\"bad\"}", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidStructuredField,
        nip11_parse_document(
            "{\"limitation\":{\"max_subscriptions\":\"x\"}}",
            arena.allocator(),
        ),
    );
}

test "nip11 forcing InvalidJson through malformed document" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidJson,
        nip11_parse_document("{\"name\":\"relay", arena.allocator()),
    );
}

test "nip11 forcing InputTooLong before parse stage" {
    const input_len: usize = @as(usize, limits.relay_message_bytes_max) + 1;
    const input = try std.testing.allocator.alloc(u8, input_len);
    defer std.testing.allocator.free(input);

    @memset(input, 'a');

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InputTooLong,
        nip11_parse_document(input, arena.allocator()),
    );
}

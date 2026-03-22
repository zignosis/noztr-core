const std = @import("std");
const limits = @import("limits.zig");
const nip01_filter = @import("nip01_filter.zig");

/// Typed strict COUNT parser and metadata errors.
pub const CountError = error{
    InvalidCountMessage,
    InvalidCountObject,
    InvalidCountValue,
    InvalidApproximateValue,
    InvalidHllHex,
    InvalidHllLength,
    InvalidQueryId,
};

/// Optional COUNT response metadata fields.
pub const CountMetadata = struct {
    approximate: ?bool = null,
    hll: ?[]const u8 = null,
};

/// Strict COUNT client message payload.
pub const CountClientMessage = struct {
    query_id: []const u8,
    filters: [limits.message_filters_max]nip01_filter.Filter,
    filters_count: u8,
};

/// Strict COUNT relay message payload.
pub const CountRelayMessage = struct {
    query_id: []const u8,
    count: u64,
    metadata: CountMetadata,
};

/// Parse strict client COUNT message: ["COUNT", query_id, filter1, ...].
pub fn count_client_message_parse(
    input: []const u8,
    scratch: std.mem.Allocator,
) CountError!CountClientMessage {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.message_filters_max > 0);

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = try parse_count_array(input, parse_arena.allocator());
    if (root.array.items.len < 3) {
        return error.InvalidCountMessage;
    }

    const query_id = try parse_query_id_owned(root.array.items[1], scratch);
    var filters: [limits.message_filters_max]nip01_filter.Filter = undefined;
    const filters_count = try parse_client_filters(root.array.items, scratch, &filters);
    return .{
        .query_id = query_id,
        .filters = filters,
        .filters_count = filters_count,
    };
}

/// Parse strict relay COUNT message: ["COUNT", query_id, count_object].
pub fn count_relay_message_parse(
    input: []const u8,
    scratch: std.mem.Allocator,
) CountError!CountRelayMessage {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.subscription_id_bytes_max == 64);

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = try parse_count_array(input, parse_arena.allocator());
    if (root.array.items.len != 3) {
        return error.InvalidCountMessage;
    }

    const query_id = try parse_query_id_owned(root.array.items[1], scratch);
    const parsed_count = try parse_count_object(root.array.items[2], scratch);
    return .{
        .query_id = query_id,
        .count = parsed_count.count,
        .metadata = parsed_count.metadata,
    };
}

/// Validate optional COUNT metadata (`approximate`, `hll`).
pub fn count_metadata_validate(metadata: *const CountMetadata) CountError!void {
    std.debug.assert(@intFromPtr(metadata) != 0);
    std.debug.assert(limits.nip45_hll_hex_length == 512);

    if (metadata.hll) |hll| {
        if (hll.len != limits.nip45_hll_hex_length) {
            return error.InvalidHllLength;
        }
        try validate_hex(hll);
    }
}

fn parse_count_array(
    input: []const u8,
    parse_allocator: std.mem.Allocator,
) CountError!std.json.Value {
    std.debug.assert(@intFromPtr(parse_allocator.ptr) != 0);
    std.debug.assert(limits.relay_message_bytes_max >= limits.event_json_max);

    if (input.len == 0) {
        return error.InvalidCountMessage;
    }
    if (input.len > limits.relay_message_bytes_max) {
        return error.InvalidCountMessage;
    }

    const root = std.json.parseFromSliceLeaky(std.json.Value, parse_allocator, input, .{}) catch {
        return error.InvalidCountMessage;
    };
    if (root != .array) {
        return error.InvalidCountMessage;
    }
    if (root.array.items.len == 0) {
        return error.InvalidCountMessage;
    }
    try validate_count_command(root.array.items[0]);
    return root;
}

fn validate_count_command(value: std.json.Value) CountError!void {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.subscription_id_bytes_max == 64);

    if (value != .string) {
        return error.InvalidCountMessage;
    }
    if (!std.mem.eql(u8, value.string, "COUNT")) {
        return error.InvalidCountMessage;
    }
}

fn parse_query_id_owned(value: std.json.Value, scratch: std.mem.Allocator) CountError![]const u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.subscription_id_bytes_max == 64);

    if (value != .string) {
        return error.InvalidQueryId;
    }
    if (value.string.len == 0) {
        return error.InvalidQueryId;
    }
    if (value.string.len > limits.subscription_id_bytes_max) {
        return error.InvalidQueryId;
    }
    return scratch.dupe(u8, value.string) catch return error.InvalidCountMessage;
}

fn parse_client_filters(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
    filters: *[limits.message_filters_max]nip01_filter.Filter,
) CountError!u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(@intFromPtr(filters) != 0);

    const filter_count: u32 = @intCast(values.len - 2);
    if (filter_count == 0) {
        return error.InvalidCountMessage;
    }
    if (filter_count > limits.message_filters_max) {
        return error.InvalidCountMessage;
    }

    var index: u32 = 0;
    while (index < filter_count) : (index += 1) {
        const value_index: usize = @intCast(index + 2);
        const output_index: usize = @intCast(index);
        filters[output_index] = try parse_filter_value(values[value_index], scratch);
    }
    return @intCast(filter_count);
}

fn parse_filter_value(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) CountError!nip01_filter.Filter {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(@sizeOf(nip01_filter.Filter) > 0);

    if (value != .object) {
        return error.InvalidCountMessage;
    }
    return nip01_filter.filter_parse_value(value, scratch) catch return error.InvalidCountMessage;
}

const ParsedCountObject = struct {
    count: u64,
    metadata: CountMetadata,
};

fn parse_count_object(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) CountError!ParsedCountObject {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (value != .object) {
        return error.InvalidCountObject;
    }

    var metadata = CountMetadata{};
    var has_count = false;
    var parsed_count: u64 = 0;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const item = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "count")) {
            parsed_count = try parse_count_value(item);
            has_count = true;
        } else if (std.mem.eql(u8, key, "approximate")) {
            metadata.approximate = try parse_approximate(item);
        } else if (std.mem.eql(u8, key, "hll")) {
            metadata.hll = try parse_hll_owned(item, scratch);
        }
    }

    if (!has_count) {
        return error.InvalidCountObject;
    }
    try count_metadata_validate(&metadata);
    return .{ .count = parsed_count, .metadata = metadata };
}

fn parse_count_value(value: std.json.Value) CountError!u64 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(u64) == 8);

    if (value != .integer) {
        return error.InvalidCountValue;
    }
    if (value.integer < 0) {
        return error.InvalidCountValue;
    }
    return std.math.cast(u64, value.integer) orelse error.InvalidCountValue;
}

fn parse_approximate(value: std.json.Value) CountError!bool {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(bool) == 1);

    if (value != .bool) {
        return error.InvalidApproximateValue;
    }
    return value.bool;
}

fn parse_hll_owned(value: std.json.Value, scratch: std.mem.Allocator) CountError![]const u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.nip45_hll_hex_length == 512);

    if (value != .string) {
        return error.InvalidHllHex;
    }
    return scratch.dupe(u8, value.string) catch return error.InvalidCountMessage;
}

fn validate_hex(value: []const u8) CountError!void {
    std.debug.assert(value.len <= limits.relay_message_bytes_max);
    std.debug.assert(limits.nip45_hll_hex_length == 512);

    var index: u32 = 0;
    while (index < value.len) : (index += 1) {
        const byte = value[index];
        const is_digit = byte >= '0' and byte <= '9';
        if (is_digit) {
            continue;
        }
        const is_lower_hex = byte >= 'a' and byte <= 'f';
        const is_upper_hex = byte >= 'A' and byte <= 'F';
        if (!is_lower_hex and !is_upper_hex) {
            return error.InvalidHllHex;
        }
    }
}

fn build_hll_hex(out: []u8) void {
    std.debug.assert(out.len == limits.nip45_hll_hex_length);
    std.debug.assert(out.len > 0);

    var index: u32 = 0;
    while (index < out.len) : (index += 1) {
        if ((index % 2) == 0) {
            out[index] = 'a';
        } else {
            out[index] = '1';
        }
    }
}

test "count client parser accepts strict valid vectors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const one_filter = try count_client_message_parse(
        "[\"COUNT\",\"q1\",{\"kinds\":[1]}]",
        arena.allocator(),
    );
    const two_filters = try count_client_message_parse(
        "[\"COUNT\",\"q2\",{\"kinds\":[1]},{\"kinds\":[2]}]",
        arena.allocator(),
    );
    const max_query = try count_client_message_parse(
        "[\"COUNT\",\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
            "{\"kinds\":[1]}]",
        arena.allocator(),
    );

    try std.testing.expectEqualStrings("q1", one_filter.query_id);
    try std.testing.expect(one_filter.filters_count == 1);
    try std.testing.expect(two_filters.filters_count == 2);
    try std.testing.expect(two_filters.filters[1].kinds[0] == 2);
    try std.testing.expect(max_query.query_id.len == 64);
}

test "count relay parser accepts strict valid vectors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var hll_text: [limits.nip45_hll_hex_length]u8 = undefined;
    build_hll_hex(hll_text[0..]);
    const relay_hll = try std.fmt.allocPrint(
        std.testing.allocator,
        "[\"COUNT\",\"q3\",{{\"count\":7,\"hll\":\"{s}\"}}]",
        .{hll_text[0..]},
    );
    defer std.testing.allocator.free(relay_hll);

    const count_only = try count_relay_message_parse(
        "[\"COUNT\",\"q1\",{\"count\":42}]",
        arena.allocator(),
    );
    const with_approx = try count_relay_message_parse(
        "[\"COUNT\",\"q2\",{\"count\":9,\"approximate\":true}]",
        arena.allocator(),
    );
    const with_unknown = try count_relay_message_parse(
        "[\"COUNT\",\"q2x\",{\"count\":11,\"future\":1}]",
        arena.allocator(),
    );
    const with_hll = try count_relay_message_parse(relay_hll, arena.allocator());

    try std.testing.expect(count_only.count == 42);
    try std.testing.expect(with_approx.metadata.approximate.?);
    try std.testing.expect(with_unknown.count == 11);
    try std.testing.expect(with_unknown.metadata.approximate == null);
    try std.testing.expect(with_hll.metadata.hll.?.len == limits.nip45_hll_hex_length);
}

test "count parser rejects strict invalid vectors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidCountMessage,
        count_client_message_parse("[\"NOPE\",\"q1\",{}]", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidCountMessage,
        count_client_message_parse("[\"COUNT\",\"q1\"]", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidCountObject,
        count_relay_message_parse("[\"COUNT\",\"q1\",7]", arena.allocator()),
    );
}

test "count parser forces every CountError variant" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var bad_hll: [limits.nip45_hll_hex_length]u8 = undefined;
    build_hll_hex(bad_hll[0..]);
    bad_hll[10] = 'G';
    const relay_bad_hll = try std.fmt.allocPrint(
        std.testing.allocator,
        "[\"COUNT\",\"q1\",{{\"count\":1,\"hll\":\"{s}\"}}]",
        .{bad_hll[0..]},
    );
    defer std.testing.allocator.free(relay_bad_hll);

    try std.testing.expectError(
        error.InvalidCountMessage,
        count_client_message_parse("[\"COUNT\",\"q1\",{\"#e\":[]}]", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidCountObject,
        count_relay_message_parse("[\"COUNT\",\"q1\",{}]", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidCountValue,
        count_relay_message_parse("[\"COUNT\",\"q1\",{\"count\":\"x\"}]", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidApproximateValue,
        count_relay_message_parse(
            "[\"COUNT\",\"q1\",{\"count\":1,\"approximate\":\"true\"}]",
            arena.allocator(),
        ),
    );
    try std.testing.expectError(
        error.InvalidHllHex,
        count_relay_message_parse(relay_bad_hll, arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidHllLength,
        count_relay_message_parse(
            "[\"COUNT\",\"q1\",{\"count\":1,\"hll\":\"aa\"}]",
            arena.allocator(),
        ),
    );
    try std.testing.expectError(
        error.InvalidQueryId,
        count_client_message_parse("[\"COUNT\",\"\",{}]", arena.allocator()),
    );
}

test "count metadata validator enforces optional field rules" {
    var hll_text: [limits.nip45_hll_hex_length]u8 = undefined;
    build_hll_hex(hll_text[0..]);

    var valid = CountMetadata{ .approximate = false, .hll = hll_text[0..] };
    try count_metadata_validate(&valid);

    var uppercase_hex = hll_text;
    uppercase_hex[0] = 'A';
    uppercase_hex[1] = 'B';
    var uppercase_valid = CountMetadata{ .hll = uppercase_hex[0..] };
    try count_metadata_validate(&uppercase_valid);

    var wrong_length = CountMetadata{ .hll = "ab" };
    try std.testing.expectError(error.InvalidHllLength, count_metadata_validate(&wrong_length));

    var invalid_hex_text = hll_text;
    invalid_hex_text[0] = 'G';
    var wrong_hex = CountMetadata{ .hll = invalid_hex_text[0..] };
    try std.testing.expectError(error.InvalidHllHex, count_metadata_validate(&wrong_hex));
}

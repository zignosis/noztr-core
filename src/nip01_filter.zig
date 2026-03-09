const std = @import("std");
const limits = @import("limits.zig");
const shared_errors = @import("errors.zig");
const nip01_event = @import("nip01_event.zig");

pub const FilterParseError = shared_errors.FilterParseError;

pub const FilterTagCondition = struct {
    key: u8,
    values: []const []const u8 = &.{},
};

pub const Filter = struct {
    ids: [limits.filter_ids_max][32]u8 = [_][32]u8{[_]u8{0} ** 32} ** limits.filter_ids_max,
    ids_prefix_nibbles: [limits.filter_ids_max]u8 = [_]u8{0} ** limits.filter_ids_max,
    ids_count: u16 = 0,

    authors: [limits.filter_authors_max][32]u8 = [_][32]u8{[_]u8{0} ** 32} **
        limits.filter_authors_max,
    authors_prefix_nibbles: [limits.filter_authors_max]u8 = [_]u8{0} ** limits.filter_authors_max,
    authors_count: u16 = 0,

    kinds: [limits.filter_kinds_max]u32 = [_]u32{0} ** limits.filter_kinds_max,
    kinds_count: u16 = 0,

    since: ?u64 = null,
    until: ?u64 = null,
    limit: ?u16 = null,

    tag_conditions: []const FilterTagCondition = &.{},
};

/// Parse a filter from a JSON value tree and copy owned fields into `scratch`.
pub fn filter_parse_value(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) FilterParseError!Filter {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .object) {
        return error.InvalidFilter;
    }

    var filter = Filter{};
    var tag_conditions_temp: [limits.filter_tag_keys_max]FilterTagCondition = undefined;
    var tag_conditions_count: u16 = 0;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const item_value = entry.value_ptr.*;

        if (std.mem.eql(u8, key, "ids")) {
            try parse_filter_ids(&filter, item_value);
        } else if (std.mem.eql(u8, key, "authors")) {
            try parse_filter_authors(&filter, item_value);
        } else if (std.mem.eql(u8, key, "kinds")) {
            try parse_filter_kinds(&filter, item_value);
        } else if (std.mem.eql(u8, key, "since")) {
            filter.since = try parse_filter_u64(item_value);
        } else if (std.mem.eql(u8, key, "until")) {
            filter.until = try parse_filter_u64(item_value);
        } else if (std.mem.eql(u8, key, "limit")) {
            filter.limit = try parse_filter_u16(item_value);
        } else {
            const tag_key = try parse_filter_tag_key(key);
            if (tag_conditions_count == limits.filter_tag_keys_max) {
                return error.TooManyTagKeys;
            }

            const values = try parse_filter_tag_values(item_value, scratch);
            tag_conditions_temp[tag_conditions_count] = .{ .key = tag_key, .values = values };
            tag_conditions_count += 1;
        }
    }

    filter.tag_conditions = try finalize_tag_conditions(
        scratch,
        tag_conditions_temp[0..tag_conditions_count],
    );

    if (filter.since != null and filter.until != null) {
        if (filter.since.? > filter.until.?) {
            return error.InvalidTimeWindow;
        }
    }

    return filter;
}

pub fn filter_parse_json(input: []const u8, scratch: std.mem.Allocator) FilterParseError!Filter {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.event_json_max <= limits.relay_message_bytes_max);

    if (input.len > limits.event_json_max) {
        return error.InputTooLong;
    }

    if (input.len == 0) {
        return error.InvalidFilter;
    }

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        parse_arena.allocator(),
        input,
        .{},
    ) catch |parse_error| {
        return map_filter_json_parse_error(parse_error);
    };

    return filter_parse_value(root, scratch);
}

pub fn filter_matches_event(filter: *const Filter, event: *const nip01_event.Event) bool {
    std.debug.assert(filter.ids_count <= limits.filter_ids_max);
    std.debug.assert(filter.authors_count <= limits.filter_authors_max);

    if (filter.since) |since_unix_seconds| {
        if (event.created_at >= since_unix_seconds) {
            if (filter.until) |until_unix_seconds| {
                if (event.created_at <= until_unix_seconds) {
                    // Keep matching.
                } else {
                    return false;
                }
            }
        } else {
            return false;
        }
    } else {
        if (filter.until) |until_unix_seconds| {
            if (event.created_at <= until_unix_seconds) {
                // Keep matching.
            } else {
                return false;
            }
        }
    }

    if (filter.ids_count > 0) {
        const has_matching_id = filter_has_id(filter, &event.id);
        if (has_matching_id) {
            // Keep matching.
        } else {
            return false;
        }
    }

    if (filter.authors_count > 0) {
        const has_matching_author = filter_has_author(filter, &event.pubkey);
        if (has_matching_author) {
            // Keep matching.
        } else {
            return false;
        }
    }

    if (filter.kinds_count > 0) {
        const has_matching_kind = filter_has_kind(filter, event.kind);
        if (has_matching_kind) {
            // Keep matching.
        } else {
            return false;
        }
    }

    if (filter.tag_conditions.len > 0) {
        if (filter_matches_tag_conditions(filter, event)) {
            // Keep matching.
        } else {
            return false;
        }
    }

    return true;
}

pub fn filters_match_event(filters: []const Filter, event: *const nip01_event.Event) bool {
    std.debug.assert(filters.len <= std.math.maxInt(u32));
    std.debug.assert(event.created_at <= std.math.maxInt(u64));

    var index: u32 = 0;
    while (index < filters.len) : (index += 1) {
        const matched = filter_matches_event(&filters[index], event);
        if (matched) {
            return true;
        }
    }

    return false;
}

fn filter_has_id(filter: *const Filter, event_id: *const [32]u8) bool {
    std.debug.assert(filter.ids_count <= limits.filter_ids_max);
    std.debug.assert(filter.ids_prefix_nibbles[0] <= limits.id_hex_length);
    std.debug.assert(event_id[0] <= 255);

    var index: u16 = 0;
    while (index < filter.ids_count) : (index += 1) {
        if (prefix_matches_hex_bytes(
            &filter.ids[index],
            filter.ids_prefix_nibbles[index],
            event_id,
        )) {
            return true;
        }
    }

    return false;
}

fn filter_has_author(filter: *const Filter, event_author: *const [32]u8) bool {
    std.debug.assert(filter.authors_count <= limits.filter_authors_max);
    std.debug.assert(filter.authors_prefix_nibbles[0] <= limits.pubkey_hex_length);
    std.debug.assert(event_author[0] <= 255);

    var index: u16 = 0;
    while (index < filter.authors_count) : (index += 1) {
        if (prefix_matches_hex_bytes(
            &filter.authors[index],
            filter.authors_prefix_nibbles[index],
            event_author,
        )) {
            return true;
        }
    }

    return false;
}

fn filter_has_kind(filter: *const Filter, event_kind: u32) bool {
    std.debug.assert(filter.kinds_count <= limits.filter_kinds_max);
    std.debug.assert(event_kind <= std.math.maxInt(u32));

    var index: u16 = 0;
    while (index < filter.kinds_count) : (index += 1) {
        if (filter.kinds[index] == event_kind) {
            return true;
        }
    }

    return false;
}

fn map_filter_json_parse_error(parse_error: anyerror) FilterParseError {
    std.debug.assert(@intFromError(parse_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (parse_error) {
        error.ValueTooLong => error.InputTooLong,
        error.DuplicateField => error.InvalidFilter,
        error.OutOfMemory => error.OutOfMemory,
        error.UnexpectedToken => error.InvalidFilter,
        error.UnexpectedEndOfInput => error.InvalidFilter,
        error.BufferUnderrun => error.InvalidFilter,
        error.SyntaxError => error.InvalidFilter,
        error.InvalidNumber => error.InvalidFilter,
        error.Overflow => error.InvalidFilter,
        error.InvalidCharacter => error.InvalidFilter,
        error.InvalidEnumTag => error.InvalidFilter,
        error.UnknownField => error.InvalidFilter,
        error.MissingField => error.InvalidFilter,
        error.LengthMismatch => error.InvalidFilter,
        else => error.InvalidFilter,
    };
}

fn parse_filter_tag_key(key: []const u8) FilterParseError!u8 {
    std.debug.assert(limits.filter_tag_values_max > 0);
    std.debug.assert(limits.filter_tag_keys_max <= limits.filter_tag_values_max);

    if (key.len == 0) {
        return error.InvalidFilter;
    }

    if (key[0] != '#') {
        return error.InvalidFilter;
    }

    if (key.len != 2) {
        return error.InvalidTagKey;
    }

    const tag_key = key[1];
    const is_lower_ascii = tag_key >= 'a' and tag_key <= 'z';
    if (is_lower_ascii) {
        return tag_key;
    }

    return error.InvalidTagKey;
}

fn parse_filter_tag_values(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) FilterParseError![]const []const u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.filter_tag_values_max > 0);

    if (value != .array) {
        return error.InvalidFilter;
    }

    if (value.array.items.len > limits.filter_tag_values_max) {
        return error.TooManyTagValues;
    }

    if (value.array.items.len == 0) {
        return error.InvalidFilter;
    }

    const values = scratch.alloc(
        []const u8,
        value.array.items.len,
    ) catch return error.OutOfMemory;
    var index: u32 = 0;
    while (index < value.array.items.len) : (index += 1) {
        const item = value.array.items[index];
        if (item != .string) {
            return error.InvalidFilter;
        }

        if (!std.unicode.utf8ValidateSlice(item.string)) {
            return error.InvalidFilter;
        }

        values[index] = try copy_filter_string(item.string, scratch);
    }

    return values;
}

fn copy_filter_string(source: []const u8, scratch: std.mem.Allocator) FilterParseError![]const u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.event_json_max > 0);

    if (source.len > limits.event_json_max) {
        return error.InvalidFilter;
    }

    const copy = scratch.alloc(u8, source.len) catch return error.OutOfMemory;
    if (source.len > 0) {
        @memcpy(copy, source);
    }
    return copy;
}

fn finalize_tag_conditions(
    scratch: std.mem.Allocator,
    input: []const FilterTagCondition,
) FilterParseError![]const FilterTagCondition {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.filter_tag_keys_max > 0);

    if (input.len > limits.filter_tag_keys_max) {
        return error.TooManyTagKeys;
    }

    const output = scratch.alloc(FilterTagCondition, input.len) catch return error.OutOfMemory;
    if (input.len > 0) {
        @memcpy(output, input);
    }
    return output;
}

fn filter_matches_tag_conditions(filter: *const Filter, event: *const nip01_event.Event) bool {
    std.debug.assert(filter.tag_conditions.len <= limits.filter_tag_keys_max);
    std.debug.assert(event.tags.len <= limits.tags_max);

    var condition_index: u32 = 0;
    while (condition_index < filter.tag_conditions.len) : (condition_index += 1) {
        const condition = filter.tag_conditions[condition_index];
        if (event_has_tag_value(event, condition.key, condition.values)) {
            // Keep matching.
        } else {
            return false;
        }
    }

    return true;
}

fn event_has_tag_value(event: *const nip01_event.Event, key: u8, values: []const []const u8) bool {
    std.debug.assert(event.tags.len <= limits.tags_max);
    std.debug.assert(key <= 255);

    if (values.len == 0) {
        return false;
    }

    var tag_index: u32 = 0;
    while (tag_index < event.tags.len) : (tag_index += 1) {
        const tag = event.tags[tag_index];
        if (tag.items.len == 0) {
            continue;
        }

        const tag_key = tag.items[0];
        if (tag_key.len != 1) {
            continue;
        }
        if (tag_key[0] != key) {
            continue;
        }

        var value_index: u32 = 0;
        while (value_index < values.len) : (value_index += 1) {
            if (tag_contains_value(tag, values[value_index])) {
                return true;
            }
        }
    }

    return false;
}

fn tag_contains_value(tag: nip01_event.EventTag, wanted: []const u8) bool {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(wanted.len <= limits.tag_item_bytes_max);

    if (tag.items.len < 2) {
        return false;
    }

    return std.mem.eql(u8, tag.items[1], wanted);
}

fn parse_filter_ids(filter: *Filter, value: std.json.Value) FilterParseError!void {
    std.debug.assert(filter.ids_count <= limits.filter_ids_max);
    std.debug.assert(limits.id_hex_length == 64);

    if (value != .array) {
        return error.InvalidFilter;
    }

    if (value.array.items.len == 0) {
        return error.InvalidFilter;
    }

    var index: u32 = 0;
    while (index < value.array.items.len) : (index += 1) {
        if (filter.ids_count == limits.filter_ids_max) {
            return error.TooManyIds;
        }

        const parsed_prefix = try parse_filter_hex_prefix_32(value.array.items[index]);
        filter.ids[filter.ids_count] = parsed_prefix.bytes;
        filter.ids_prefix_nibbles[filter.ids_count] = parsed_prefix.nibbles;
        filter.ids_count += 1;
    }
}

fn parse_filter_authors(filter: *Filter, value: std.json.Value) FilterParseError!void {
    std.debug.assert(filter.authors_count <= limits.filter_authors_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (value != .array) {
        return error.InvalidFilter;
    }

    if (value.array.items.len == 0) {
        return error.InvalidFilter;
    }

    var index: u32 = 0;
    while (index < value.array.items.len) : (index += 1) {
        if (filter.authors_count == limits.filter_authors_max) {
            return error.TooManyAuthors;
        }

        const parsed_prefix = try parse_filter_hex_prefix_32(value.array.items[index]);
        filter.authors[filter.authors_count] = parsed_prefix.bytes;
        filter.authors_prefix_nibbles[filter.authors_count] = parsed_prefix.nibbles;
        filter.authors_count += 1;
    }
}

fn parse_filter_kinds(filter: *Filter, value: std.json.Value) FilterParseError!void {
    std.debug.assert(filter.kinds_count <= limits.filter_kinds_max);
    std.debug.assert(@sizeOf(u32) == 4);

    if (value != .array) {
        return error.InvalidFilter;
    }

    if (value.array.items.len == 0) {
        return error.InvalidFilter;
    }

    var index: u32 = 0;
    while (index < value.array.items.len) : (index += 1) {
        if (filter.kinds_count == limits.filter_kinds_max) {
            return error.TooManyKinds;
        }

        filter.kinds[filter.kinds_count] = try parse_filter_u32(value.array.items[index]);
        filter.kinds_count += 1;
    }
}

fn parse_filter_u32(value: std.json.Value) FilterParseError!u32 {
    std.debug.assert(@sizeOf(u32) == 4);
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.kind_max == std.math.maxInt(u16));

    if (value != .integer) {
        return error.InvalidFilter;
    }

    if (value.integer < 0) {
        return error.ValueOutOfRange;
    }

    const parsed = std.math.cast(u32, value.integer) orelse return error.ValueOutOfRange;
    if (parsed > limits.kind_max) {
        return error.ValueOutOfRange;
    }
    return parsed;
}

fn parse_filter_u64(value: std.json.Value) FilterParseError!u64 {
    std.debug.assert(@sizeOf(u64) == 8);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (value != .integer) {
        return error.InvalidFilter;
    }

    if (value.integer < 0) {
        return error.ValueOutOfRange;
    }

    const parsed = std.math.cast(u64, value.integer) orelse return error.ValueOutOfRange;
    return parsed;
}

fn parse_filter_u16(value: std.json.Value) FilterParseError!u16 {
    std.debug.assert(@sizeOf(u16) == 2);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (value != .integer) {
        return error.InvalidFilter;
    }

    if (value.integer < 0) {
        return error.ValueOutOfRange;
    }

    const parsed = std.math.cast(u16, value.integer) orelse return error.ValueOutOfRange;
    return parsed;
}

const HexPrefix32 = struct {
    bytes: [32]u8,
    nibbles: u8,
};

fn parse_filter_hex_prefix_32(value: std.json.Value) FilterParseError!HexPrefix32 {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length == 64);

    var output: [32]u8 = [_]u8{0} ** 32;
    const source = if (value == .string) value.string else return error.InvalidFilter;
    try validate_filter_lower_hex(source, 1, 64);

    var source_index: u32 = 0;
    var output_index: u32 = 0;
    while (source_index + 1 < source.len) : (source_index += 2) {
        const high_nibble = hex_char_to_nibble(source[source_index]);
        const low_nibble = hex_char_to_nibble(source[source_index + 1]);
        output[output_index] = (high_nibble << 4) | low_nibble;
        output_index += 1;
    }

    const has_odd_nibble = (source.len % 2) == 1;
    if (has_odd_nibble) {
        const last_nibble = hex_char_to_nibble(source[source.len - 1]);
        output[output_index] = last_nibble << 4;
    }

    return .{ .bytes = output, .nibbles = @intCast(source.len) };
}

fn validate_filter_lower_hex(
    source: []const u8,
    min_length: u8,
    max_length: u8,
) FilterParseError!void {
    std.debug.assert(min_length > 0);
    std.debug.assert(min_length <= max_length);

    if (source.len < min_length) {
        return error.InvalidHex;
    }
    if (source.len > max_length) {
        return error.InvalidHex;
    }

    var index: u32 = 0;
    while (index < source.len) : (index += 1) {
        const byte = source[index];
        const is_digit = byte >= '0' and byte <= '9';
        if (is_digit) {
            continue;
        }

        const is_lower_hex = byte >= 'a' and byte <= 'f';
        if (!is_lower_hex) {
            return error.InvalidHex;
        }
    }
}

fn hex_char_to_nibble(character: u8) u8 {
    std.debug.assert(character <= 127);
    std.debug.assert(
        (character >= '0' and character <= '9') or (character >= 'a' and character <= 'f'),
    );

    if (character >= '0' and character <= '9') {
        return character - '0';
    }
    return character - 'a' + 10;
}

fn prefix_matches_hex_bytes(prefix: *const [32]u8, nibbles: u8, target: *const [32]u8) bool {
    std.debug.assert(nibbles > 0);
    std.debug.assert(nibbles <= 64);

    const full_bytes = @as(u8, nibbles / 2);
    var index: u8 = 0;
    while (index < full_bytes) : (index += 1) {
        if (prefix[index] != target[index]) {
            return false;
        }
    }

    if ((nibbles % 2) == 1) {
        const masked_prefix = prefix[full_bytes] & 0xF0;
        const masked_target = target[full_bytes] & 0xF0;
        if (masked_prefix != masked_target) {
            return false;
        }
    }

    return true;
}

fn write_repeated_string_filter_json(
    writer: anytype,
    field_name: []const u8,
    value: []const u8,
    count: u32,
) !void {
    std.debug.assert(field_name.len > 0);
    std.debug.assert(count <= std.math.maxInt(u32));

    try writer.writeAll("{\"");
    try writer.writeAll(field_name);
    try writer.writeAll("\":[");

    var index: u32 = 0;
    while (index < count) : (index += 1) {
        if (index > 0) {
            try writer.writeAll(",");
        }
        try writer.writeAll("\"");
        try writer.writeAll(value);
        try writer.writeAll("\"");
    }

    try writer.writeAll("]}");
}

fn write_repeated_u32_filter_json(
    writer: anytype,
    field_name: []const u8,
    value: u32,
    count: u32,
) !void {
    std.debug.assert(field_name.len > 0);
    std.debug.assert(count <= std.math.maxInt(u32));

    try writer.writeAll("{\"");
    try writer.writeAll(field_name);
    try writer.writeAll("\":[");

    var index: u32 = 0;
    while (index < count) : (index += 1) {
        if (index > 0) {
            try writer.writeAll(",");
        }
        try writer.print("{d}", .{value});
    }

    try writer.writeAll("]}");
}

fn force_filter_parse_error(
    input: []const u8,
    expected_error: FilterParseError,
    allocator: std.mem.Allocator,
) !void {
    std.debug.assert(@intFromPtr(allocator.ptr) != 0);
    std.debug.assert(@intFromError(expected_error) >= 0);

    try std.testing.expectError(expected_error, filter_parse_json(input, allocator));
}

test "filters OR behavior is deterministic" {
    var event = nip01_event.Event{
        .id = [_]u8{5} ** 32,
        .pubkey = [_]u8{6} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 7,
        .created_at = 123,
        .content = "ok",
    };
    event.id = try nip01_event.event_compute_id(&event);

    var filter_reject = Filter{};
    filter_reject.kinds[0] = 999;
    filter_reject.kinds_count = 1;

    var filter_accept = Filter{};
    filter_accept.kinds[0] = 7;
    filter_accept.kinds_count = 1;

    const filters = [_]Filter{ filter_reject, filter_accept };
    const matched_a = filters_match_event(filters[0..], &event);
    const matched_b = filters_match_event(filters[0..], &event);

    try std.testing.expect(matched_a);
    try std.testing.expect(matched_b);
}

test "parsed filter fields drive deterministic matching" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const filter_json =
        "{" ++
        "\"ids\":[\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"]," ++
        "\"authors\":[\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"]," ++
        "\"kinds\":[1]," ++
        "\"since\":100," ++
        "\"until\":200," ++
        "\"limit\":10}";

    const filter = try filter_parse_json(filter_json, arena.allocator());
    var event = nip01_event.Event{
        .id = [_]u8{0xaa} ** 32,
        .pubkey = [_]u8{0xbb} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 150,
        .content = "ok",
    };
    const matched_a = filter_matches_event(&filter, &event);
    const matched_b = filter_matches_event(&filter, &event);
    try std.testing.expect(matched_a);
    try std.testing.expect(matched_b);
}

test "filter ids and authors support lowercase hex prefixes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const filter = try filter_parse_json(
        "{\"ids\":[\"aa\"],\"authors\":[\"bbb\"],\"kinds\":[1]}",
        arena.allocator(),
    );
    const event = nip01_event.Event{
        .id = [_]u8{0xaa} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 150,
        .content = "ok",
    };

    var matching_event = event;
    matching_event.pubkey = [_]u8{0} ** 32;
    matching_event.pubkey[0] = 0xbb;
    matching_event.pubkey[1] = 0xb1;

    var non_matching_event = matching_event;
    non_matching_event.pubkey[1] = 0xa1;

    try std.testing.expect(filter_matches_event(&filter, &matching_event));
    try std.testing.expect(!filter_matches_event(&filter, &non_matching_event));
}

test "odd-length id prefix uses nibble-precision matching" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const filter = try filter_parse_json("{\"ids\":[\"abc\"]}", arena.allocator());
    var matched_event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{6} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 7,
        .created_at = 123,
        .content = "ok",
    };
    matched_event.id[0] = 0xab;
    matched_event.id[1] = 0xc7;

    var rejected_event = matched_event;
    rejected_event.id[1] = 0xd7;

    try std.testing.expect(filter_matches_event(&filter, &matched_event));
    try std.testing.expect(!filter_matches_event(&filter, &rejected_event));
}

test "filter parse value copies tag values into scratch" {
    var scratch_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer scratch_arena.deinit();
    var filter: Filter = undefined;

    {
        var parse_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer parse_arena.deinit();

        const input = "{\"#e\":[\"target\",\"backup\"]}";
        const root = try std.json.parseFromSliceLeaky(
            std.json.Value,
            parse_arena.allocator(),
            input,
            .{},
        );
        const source_values = root.object.get("#e").?.array.items;

        filter = try filter_parse_value(root, scratch_arena.allocator());
        try std.testing.expect(filter.tag_conditions.len == 1);
        try std.testing.expect(filter.tag_conditions[0].values.len == 2);
        try std.testing.expect(
            @intFromPtr(filter.tag_conditions[0].values[0].ptr) !=
                @intFromPtr(source_values[0].string.ptr),
        );
    }

    try std.testing.expectEqualStrings("target", filter.tag_conditions[0].values[0]);
    try std.testing.expectEqualStrings("backup", filter.tag_conditions[0].values[1]);
}

test "parsed filters keep OR-across-filters deterministic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const reject_filter = try filter_parse_json("{\"kinds\":[999]}", arena.allocator());
    const accept_filter = try filter_parse_json("{\"kinds\":[7]}", arena.allocator());

    var event = nip01_event.Event{
        .id = [_]u8{5} ** 32,
        .pubkey = [_]u8{6} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 7,
        .created_at = 123,
        .content = "ok",
    };
    event.id = try nip01_event.event_compute_id(&event);

    const filters = [_]Filter{ reject_filter, accept_filter };
    try std.testing.expect(filters_match_event(filters[0..], &event));
    try std.testing.expect(filters_match_event(filters[0..], &event));
}

test "filter parse rejects malformed tag key shapes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(error.InvalidTagKey, filter_parse_json(
        "{\"#\":[\"abc\"]}",
        arena.allocator(),
    ));
    try std.testing.expectError(error.InvalidTagKey, filter_parse_json(
        "{\"#ab\":[\"abc\"]}",
        arena.allocator(),
    ));
    try std.testing.expectError(error.InvalidTagKey, filter_parse_json(
        "{\"#1\":[\"abc\"]}",
        arena.allocator(),
    ));
    try std.testing.expectError(error.InvalidTagKey, filter_parse_json(
        "{\"#_\":[\"abc\"]}",
        arena.allocator(),
    ));
}

test "parsed tag filter matches event tags deterministically" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const filter = try filter_parse_json("{\"#e\":[\"target\"]}", arena.allocator());
    const first_tag = [_][]const u8{ "p", "ignored" };
    const second_tag = [_][]const u8{ "e", "target", "relay" };
    const tags = [_]nip01_event.EventTag{
        .{ .items = first_tag[0..] },
        .{ .items = second_tag[0..] },
    };

    const event = nip01_event.Event{
        .id = [_]u8{0xaa} ** 32,
        .pubkey = [_]u8{0xbb} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 100,
        .content = "ok",
        .tags = tags[0..],
    };

    try std.testing.expect(filter_matches_event(&filter, &event));
    try std.testing.expect(filter_matches_event(&filter, &event));
}

test "filter parse rejects uppercase #X tag key" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidTagKey,
        filter_parse_json("{\"#E\":[\"target\"]}", arena.allocator()),
    );
}

test "tag filter does not match non-indexed tag values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const filter = try filter_parse_json("{\"#e\":[\"target\"]}", arena.allocator());
    const tag_items = [_][]const u8{ "e", "indexed", "target" };
    const tags = [_]nip01_event.EventTag{.{ .items = tag_items[0..] }};
    const event = nip01_event.Event{
        .id = [_]u8{0xaa} ** 32,
        .pubkey = [_]u8{0xbb} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 100,
        .content = "ok",
        .tags = tags[0..],
    };

    try std.testing.expect(!filter_matches_event(&filter, &event));
    try std.testing.expect(!filter_matches_event(&filter, &event));
}

test "filter parse returns TooManyTagValues for #x overflow" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var input_buffer: [32_768]u8 = undefined;
    var stream = std.io.fixedBufferStream(&input_buffer);
    const writer = stream.writer();

    try writer.writeAll("{\"#e\":[");
    var index: u32 = 0;
    while (index < limits.filter_tag_values_max + 1) : (index += 1) {
        if (index > 0) {
            try writer.writeAll(",");
        }
        try writer.writeAll("\"x\"");
    }
    try writer.writeAll("]}");

    const input = input_buffer[0..stream.pos];
    try std.testing.expectError(
        error.TooManyTagValues,
        filter_parse_json(input, arena.allocator()),
    );
}

test "filter parse rejects empty #x value arrays" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidFilter,
        filter_parse_json("{\"#e\":[]}", arena.allocator()),
    );
}

test "filter parse rejects empty ids authors and kinds arrays" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidFilter,
        filter_parse_json("{\"ids\":[]}", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidFilter,
        filter_parse_json("{\"authors\":[]}", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidFilter,
        filter_parse_json("{\"kinds\":[]}", arena.allocator()),
    );
}

test "filter parse forces InputTooLong and InvalidFilter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const too_long_input = [_]u8{0} ** (limits.event_json_max + 1);
    try force_filter_parse_error(&too_long_input, error.InputTooLong, arena.allocator());
    try force_filter_parse_error("[]", error.InvalidFilter, arena.allocator());
}

test "filter parse maps allocator exhaustion to OutOfMemory" {
    const input = "{\"#e\":[\"target\"]}";

    var tiny_buffer: [64]u8 = undefined;
    var tiny_allocator = std.heap.FixedBufferAllocator.init(&tiny_buffer);

    try std.testing.expectError(
        error.OutOfMemory,
        filter_parse_json(input, tiny_allocator.allocator()),
    );
}

test "filter parse forces InvalidHex and InvalidTagKey" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try force_filter_parse_error(
        "{\"ids\":[\"gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg\"]}",
        error.InvalidHex,
        arena.allocator(),
    );
    try force_filter_parse_error("{\"#ab\":[\"abc\"]}", error.InvalidTagKey, arena.allocator());
}

test "finalize tag conditions returns TooManyTagKeys for synthetic overflow" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var synthetic: [limits.filter_tag_keys_max + 1]FilterTagCondition = undefined;
    var index: u32 = 0;
    while (index < synthetic.len) : (index += 1) {
        synthetic[index] = .{
            .key = @as(u8, 'a') + @as(u8, @intCast(index % 26)),
            .values = &.{"x"},
        };
    }

    try std.testing.expectError(
        error.TooManyTagKeys,
        finalize_tag_conditions(arena.allocator(), synthetic[0..]),
    );
}

test "filter parse forces TooManyIds overflow" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var input_buffer: [96_000]u8 = undefined;
    var stream = std.io.fixedBufferStream(&input_buffer);
    const writer = stream.writer();

    try write_repeated_string_filter_json(
        writer,
        "ids",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        limits.filter_ids_max + 1,
    );
    const input = input_buffer[0..stream.pos];
    try force_filter_parse_error(input, error.TooManyIds, arena.allocator());
}

test "filter parse forces TooManyAuthors overflow" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var input_buffer: [96_000]u8 = undefined;
    var stream = std.io.fixedBufferStream(&input_buffer);
    const writer = stream.writer();

    try write_repeated_string_filter_json(
        writer,
        "authors",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        limits.filter_authors_max + 1,
    );
    const input = input_buffer[0..stream.pos];
    try force_filter_parse_error(input, error.TooManyAuthors, arena.allocator());
}

test "filter parse forces TooManyKinds overflow" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var input_buffer: [4_096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&input_buffer);
    const writer = stream.writer();

    try write_repeated_u32_filter_json(
        writer,
        "kinds",
        1,
        limits.filter_kinds_max + 1,
    );
    const input = input_buffer[0..stream.pos];
    try force_filter_parse_error(input, error.TooManyKinds, arena.allocator());
}

test "filter parse forces InvalidTimeWindow and ValueOutOfRange" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try force_filter_parse_error(
        "{\"since\":20,\"until\":10}",
        error.InvalidTimeWindow,
        arena.allocator(),
    );
    try force_filter_parse_error(
        "{\"kinds\":[4294967296]}",
        error.ValueOutOfRange,
        arena.allocator(),
    );
    try force_filter_parse_error(
        "{\"kinds\":[65536]}",
        error.ValueOutOfRange,
        arena.allocator(),
    );
}

test "tag filters keep OR-across-filters deterministic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const reject_filter = try filter_parse_json("{\"#e\":[\"wrong\"]}", arena.allocator());
    const accept_filter = try filter_parse_json("{\"#e\":[\"target\"]}", arena.allocator());
    const tag_items = [_][]const u8{ "e", "target" };
    const tags = [_]nip01_event.EventTag{.{ .items = tag_items[0..] }};

    const event = nip01_event.Event{
        .id = [_]u8{5} ** 32,
        .pubkey = [_]u8{6} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 7,
        .created_at = 123,
        .content = "ok",
        .tags = tags[0..],
    };

    const filters = [_]Filter{ reject_filter, accept_filter };
    try std.testing.expect(filters_match_event(filters[0..], &event));
    try std.testing.expect(filters_match_event(filters[0..], &event));
}

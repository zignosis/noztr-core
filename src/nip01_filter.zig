const std = @import("std");
const limits = @import("limits.zig");
const shared_errors = @import("errors.zig");
const nip01_event = @import("nip01_event.zig");

pub const FilterParseError = shared_errors.FilterParseError;

pub const Filter = struct {
    ids: [limits.filter_ids_max][32]u8 = [_][32]u8{[_]u8{0} ** 32} ** limits.filter_ids_max,
    ids_count: u16 = 0,

    authors: [limits.filter_authors_max][32]u8 = [_][32]u8{[_]u8{0} ** 32} **
        limits.filter_authors_max,
    authors_count: u16 = 0,

    kinds: [limits.filter_kinds_max]u32 = [_]u32{0} ** limits.filter_kinds_max,
    kinds_count: u16 = 0,

    since: ?u64 = null,
    until: ?u64 = null,
    limit: ?u16 = null,
};

pub fn filter_parse_json(input: []const u8, scratch: std.mem.Allocator) FilterParseError!Filter {
    std.debug.assert(input.len <= limits.event_json_max + 1);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (input.len > limits.event_json_max) {
        return error.InputTooLong;
    }

    if (input.len == 0) {
        return error.InvalidFilter;
    }

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        scratch,
        input,
        .{},
    ) catch |parse_error| {
        return map_filter_json_parse_error(parse_error);
    };

    if (root != .object) {
        return error.InvalidFilter;
    }

    var filter = Filter{};
    var iterator = root.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;

        if (std.mem.eql(u8, key, "ids")) {
            try parse_filter_ids(&filter, value);
        } else if (std.mem.eql(u8, key, "authors")) {
            try parse_filter_authors(&filter, value);
        } else if (std.mem.eql(u8, key, "kinds")) {
            try parse_filter_kinds(&filter, value);
        } else if (std.mem.eql(u8, key, "since")) {
            filter.since = try parse_filter_u64(value);
        } else if (std.mem.eql(u8, key, "until")) {
            filter.until = try parse_filter_u64(value);
        } else if (std.mem.eql(u8, key, "limit")) {
            filter.limit = try parse_filter_u16(value);
        } else {
            try validate_unknown_filter_key(key);
        }
    }

    if (filter.since != null and filter.until != null) {
        if (filter.since.? > filter.until.?) {
            return error.InvalidTimeWindow;
        }
    }

    return filter;
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
    std.debug.assert(event_id[0] <= 255);

    var index: u16 = 0;
    while (index < filter.ids_count) : (index += 1) {
        if (std.mem.eql(u8, &filter.ids[index], event_id)) {
            return true;
        }
    }

    return false;
}

fn filter_has_author(filter: *const Filter, event_author: *const [32]u8) bool {
    std.debug.assert(filter.authors_count <= limits.filter_authors_max);
    std.debug.assert(event_author[0] <= 255);

    var index: u16 = 0;
    while (index < filter.authors_count) : (index += 1) {
        if (std.mem.eql(u8, &filter.authors[index], event_author)) {
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
        error.OutOfMemory => error.InvalidFilter,
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

fn validate_unknown_filter_key(key: []const u8) FilterParseError!void {
    std.debug.assert(key.len <= std.math.maxInt(u16));
    std.debug.assert(limits.filter_tag_values_max > 0);

    if (key.len > 0) {
        if (key[0] == '#') {
            if (key.len == 2) {
                return error.TooManyTagValues;
            }

            return error.InvalidTagKey;
        }
    }

    return error.InvalidFilter;
}

fn parse_filter_ids(filter: *Filter, value: std.json.Value) FilterParseError!void {
    std.debug.assert(filter.ids_count <= limits.filter_ids_max);
    std.debug.assert(limits.id_hex_length == 64);

    if (value != .array) {
        return error.InvalidFilter;
    }

    var index: u32 = 0;
    while (index < value.array.items.len) : (index += 1) {
        if (filter.ids_count == limits.filter_ids_max) {
            return error.TooManyIds;
        }

        const parsed = try parse_filter_hex_32(value.array.items[index]);
        filter.ids[filter.ids_count] = parsed;
        filter.ids_count += 1;
    }
}

fn parse_filter_authors(filter: *Filter, value: std.json.Value) FilterParseError!void {
    std.debug.assert(filter.authors_count <= limits.filter_authors_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (value != .array) {
        return error.InvalidFilter;
    }

    var index: u32 = 0;
    while (index < value.array.items.len) : (index += 1) {
        if (filter.authors_count == limits.filter_authors_max) {
            return error.TooManyAuthors;
        }

        const parsed = try parse_filter_hex_32(value.array.items[index]);
        filter.authors[filter.authors_count] = parsed;
        filter.authors_count += 1;
    }
}

fn parse_filter_kinds(filter: *Filter, value: std.json.Value) FilterParseError!void {
    std.debug.assert(filter.kinds_count <= limits.filter_kinds_max);
    std.debug.assert(@sizeOf(u32) == 4);

    if (value != .array) {
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

    if (value != .integer) {
        return error.InvalidFilter;
    }

    if (value.integer < 0) {
        return error.ValueOutOfRange;
    }

    const parsed = std.math.cast(u32, value.integer) orelse return error.ValueOutOfRange;
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

fn parse_filter_hex_32(value: std.json.Value) FilterParseError![32]u8 {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length == 64);

    var output: [32]u8 = undefined;
    const source = if (value == .string) value.string else return error.InvalidFilter;
    try validate_filter_lower_hex(source, 64);
    _ = std.fmt.hexToBytes(&output, source) catch return error.InvalidHex;
    return output;
}

fn validate_filter_lower_hex(source: []const u8, expected_length: u8) FilterParseError!void {
    std.debug.assert(expected_length > 0);
    std.debug.assert(expected_length == 64);

    if (source.len != expected_length) {
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

test "filters OR behavior is deterministic" {
    var event = nip01_event.Event{
        .id = [_]u8{5} ** 32,
        .pubkey = [_]u8{6} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 7,
        .created_at = 123,
        .content = "ok",
    };
    event.id = nip01_event.event_compute_id(&event);

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
    event.id = nip01_event.event_compute_id(&event);

    const filters = [_]Filter{ reject_filter, accept_filter };
    try std.testing.expect(filters_match_event(filters[0..], &event));
    try std.testing.expect(filters_match_event(filters[0..], &event));
}

test "filter typed parse errors are forceable" {
    const too_long_input = [_]u8{0} ** (limits.event_json_max + 1);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InputTooLong,
        filter_parse_json(&too_long_input, std.testing.allocator),
    );
    try std.testing.expectError(error.InvalidTimeWindow, filter_parse_json(
        "{\"since\":20,\"until\":10}",
        arena.allocator(),
    ));
}

const std = @import("std");
const limits = @import("limits.zig");
const nip01_filter = @import("nip01_filter.zig");

/// Typed strict errors for NIP-77 negentropy parsing, ordering, and state transitions.
pub const NegentropyError = error{
    InvalidNegOpen,
    InvalidNegMsg,
    InvalidNegClose,
    InvalidNegErr,
    InvalidHexPayload,
    UnsupportedVersion,
    ReservedTimestamp,
    InvalidOrdering,
    SessionStateExceeded,
};

/// Negentropy item ordering tuple (`timestamp`, `id`) used by range reconciliation.
pub const NegentropyItem = struct {
    timestamp: u64,
    id: [32]u8,
};

/// Strict NEG-OPEN shape with one filter object and one hex payload.
pub const NegOpenMessage = struct {
    subscription_id: []const u8,
    filter: nip01_filter.Filter,
    payload_hex: []const u8,
};

/// Strict NEG-MSG shape with one subscription id and one hex payload.
pub const NegMsgMessage = struct {
    subscription_id: []const u8,
    payload_hex: []const u8,
};

/// Strict NEG-CLOSE shape with one subscription id.
pub const NegCloseMessage = struct {
    subscription_id: []const u8,
};

/// Strict NEG-ERR shape with one subscription id and one reason string.
pub const NegErrMessage = struct {
    subscription_id: []const u8,
    reason: []const u8,
};

/// Negentropy message family used by deterministic state transitions.
pub const NegentropyMessage = union(enum) {
    open: NegOpenMessage,
    msg: NegMsgMessage,
    close: NegCloseMessage,
    err: NegErrMessage,
};

/// Bounded deterministic session state for one negentropy subscription flow.
pub const NegentropyState = struct {
    stage: Stage = .idle,
    subscription_id: [limits.subscription_id_bytes_max]u8 = [_]u8{0} **
        limits.subscription_id_bytes_max,
    subscription_id_len: u8 = 0,
    steps: u16 = 0,

    pub const Stage = enum {
        idle,
        open,
        closed,
    };
};

const ParseKind = enum {
    neg_open,
    neg_msg,
    neg_close,
    neg_err,
};

/// Parse strict canonical NEG-OPEN JSON shape.
pub fn negentropy_open_parse(
    input: []const u8,
    scratch: std.mem.Allocator,
) NegentropyError!NegOpenMessage {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.nip77_negentropy_protocol_version > 0);

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const values = try parse_neg_array(input, parse_arena.allocator(), .neg_open);
    if (values.len != 4) {
        return error.InvalidNegOpen;
    }
    try parse_command(values[0], .neg_open);

    const subscription_id = try parse_subscription_id(values[1], scratch, .neg_open);
    const filter = try parse_filter(values[2], scratch);
    const payload_hex = try parse_payload_hex(values[3], scratch, .neg_open);
    try payload_hex_validate(payload_hex);

    return .{
        .subscription_id = subscription_id,
        .filter = filter,
        .payload_hex = payload_hex,
    };
}

/// Parse strict canonical NEG-MSG JSON shape.
pub fn negentropy_msg_parse(
    input: []const u8,
    scratch: std.mem.Allocator,
) NegentropyError!NegMsgMessage {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.nip77_negentropy_protocol_version > 0);

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const values = try parse_neg_array(input, parse_arena.allocator(), .neg_msg);
    if (values.len != 3) {
        return error.InvalidNegMsg;
    }
    try parse_command(values[0], .neg_msg);

    const subscription_id = try parse_subscription_id(values[1], scratch, .neg_msg);
    const payload_hex = try parse_payload_hex(values[2], scratch, .neg_msg);
    try payload_hex_validate(payload_hex);

    return .{
        .subscription_id = subscription_id,
        .payload_hex = payload_hex,
    };
}

/// Parse strict canonical NEG-CLOSE JSON shape.
pub fn negentropy_close_parse(
    input: []const u8,
    scratch: std.mem.Allocator,
) NegentropyError!NegCloseMessage {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const values = try parse_neg_array(input, parse_arena.allocator(), .neg_close);
    if (values.len != 2) {
        return error.InvalidNegClose;
    }
    try parse_command(values[0], .neg_close);

    const subscription_id = try parse_subscription_id(values[1], scratch, .neg_close);
    return .{ .subscription_id = subscription_id };
}

/// Parse strict canonical NEG-ERR JSON shape.
pub fn negentropy_err_parse(
    input: []const u8,
    scratch: std.mem.Allocator,
) NegentropyError!NegErrMessage {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const values = try parse_neg_array(input, parse_arena.allocator(), .neg_err);
    if (values.len != 3) {
        return error.InvalidNegErr;
    }
    try parse_command(values[0], .neg_err);

    const subscription_id = try parse_subscription_id(values[1], scratch, .neg_err);
    const reason = try parse_reason(values[2], scratch, .neg_err);
    return .{ .subscription_id = subscription_id, .reason = reason };
}

/// Apply one negentropy message to bounded deterministic session state.
pub fn negentropy_state_apply(
    state: *NegentropyState,
    message: *const NegentropyMessage,
) NegentropyError!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(message) != 0);

    if (state.steps >= limits.nip77_negentropy_session_steps_max) {
        return error.SessionStateExceeded;
    }

    switch (message.*) {
        .open => |open_message| {
            try state_set_subscription(state, open_message.subscription_id);
            state.stage = .open;
        },
        .msg => |msg_message| {
            if (state.stage != .open) {
                return error.InvalidNegMsg;
            }
            if (!state_subscription_matches(state, msg_message.subscription_id)) {
                return error.InvalidNegMsg;
            }
        },
        .close => |close_message| {
            if (state.stage != .open) {
                return error.InvalidNegClose;
            }
            if (!state_subscription_matches(state, close_message.subscription_id)) {
                return error.InvalidNegClose;
            }
            state.stage = .closed;
        },
        .err => |err_message| {
            if (state.stage != .open) {
                return error.InvalidNegErr;
            }
            if (!state_subscription_matches(state, err_message.subscription_id)) {
                return error.InvalidNegErr;
            }
            if (!reason_has_prefix_message(err_message.reason)) {
                return error.InvalidNegErr;
            }
            state.stage = .closed;
        },
    }

    state.steps += 1;
}

/// Validate strict ordering (`timestamp` asc, then lexical `id` asc).
pub fn negentropy_items_validate_order(items: []const NegentropyItem) NegentropyError!void {
    std.debug.assert(items.len <= limits.nip77_negentropy_hex_payload_bytes_max);
    std.debug.assert(@sizeOf(NegentropyItem) > 0);

    var index: u32 = 0;
    while (index < items.len) : (index += 1) {
        const current = items[index];
        if (current.timestamp == std.math.maxInt(u64)) {
            return error.ReservedTimestamp;
        }

        if (index == 0) {
            continue;
        }

        const previous = items[index - 1];
        if (current.timestamp < previous.timestamp) {
            return error.InvalidOrdering;
        }
        if (current.timestamp == previous.timestamp) {
            const order = std.mem.order(u8, &previous.id, &current.id);
            if (order != .lt) {
                return error.InvalidOrdering;
            }
        }
    }
}

fn parse_neg_array(
    input: []const u8,
    parse_allocator: std.mem.Allocator,
    parse_kind: ParseKind,
) NegentropyError![]const std.json.Value {
    std.debug.assert(@intFromPtr(parse_allocator.ptr) != 0);
    std.debug.assert(limits.nip77_negentropy_hex_payload_bytes_max > 0);

    if (input.len == 0) {
        return parse_kind_error(parse_kind);
    }
    if (input.len > limits.relay_message_bytes_max) {
        return parse_input_limit_error(parse_kind);
    }

    const root = std.json.parseFromSliceLeaky(std.json.Value, parse_allocator, input, .{}) catch {
        return parse_kind_error(parse_kind);
    };
    if (root != .array) {
        return parse_kind_error(parse_kind);
    }
    if (root.array.items.len == 0) {
        return parse_kind_error(parse_kind);
    }

    return root.array.items;
}

fn parse_input_limit_error(parse_kind: ParseKind) NegentropyError {
    std.debug.assert(@sizeOf(ParseKind) > 0);
    std.debug.assert(limits.relay_message_bytes_max > 0);

    if (parse_kind == .neg_msg) {
        return error.InvalidHexPayload;
    }
    return parse_kind_error(parse_kind);
}

fn parse_command(value: std.json.Value, parse_kind: ParseKind) NegentropyError!void {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    if (value != .string) {
        return parse_kind_error(parse_kind);
    }

    switch (parse_kind) {
        .neg_open => {
            if (!std.mem.eql(u8, value.string, "NEG-OPEN")) {
                return error.InvalidNegOpen;
            }
        },
        .neg_msg => {
            if (!std.mem.eql(u8, value.string, "NEG-MSG")) {
                return error.InvalidNegMsg;
            }
        },
        .neg_close => {
            if (!std.mem.eql(u8, value.string, "NEG-CLOSE")) {
                return error.InvalidNegClose;
            }
        },
        .neg_err => {
            if (!std.mem.eql(u8, value.string, "NEG-ERR")) {
                return error.InvalidNegErr;
            }
        },
    }
}

fn parse_subscription_id(
    value: std.json.Value,
    scratch: std.mem.Allocator,
    parse_kind: ParseKind,
) NegentropyError![]const u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    if (value != .string) {
        return parse_kind_error(parse_kind);
    }
    if (value.string.len == 0) {
        return parse_kind_error(parse_kind);
    }
    if (value.string.len > limits.subscription_id_bytes_max) {
        return parse_kind_error(parse_kind);
    }

    return scratch.dupe(u8, value.string) catch {
        return parse_kind_error(parse_kind);
    };
}

fn parse_filter(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) NegentropyError!nip01_filter.Filter {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(@sizeOf(nip01_filter.Filter) > 0);

    if (value != .object) {
        return error.InvalidNegOpen;
    }
    return nip01_filter.filter_parse_value(value, scratch) catch return error.InvalidNegOpen;
}

fn parse_payload_hex(
    value: std.json.Value,
    scratch: std.mem.Allocator,
    parse_kind: ParseKind,
) NegentropyError![]const u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.nip77_negentropy_hex_payload_bytes_max > 0);

    if (value != .string) {
        return parse_kind_error(parse_kind);
    }
    if (value.string.len == 0) {
        return error.InvalidHexPayload;
    }

    return scratch.dupe(u8, value.string) catch {
        return parse_kind_error(parse_kind);
    };
}

fn parse_reason(
    value: std.json.Value,
    scratch: std.mem.Allocator,
    parse_kind: ParseKind,
) NegentropyError![]const u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    if (value != .string) {
        return parse_kind_error(parse_kind);
    }
    if (!reason_has_prefix_message(value.string)) {
        return parse_kind_error(parse_kind);
    }

    return scratch.dupe(u8, value.string) catch {
        return parse_kind_error(parse_kind);
    };
}

fn reason_has_prefix_message(reason: []const u8) bool {
    std.debug.assert(limits.subscription_id_bytes_max > 0);
    std.debug.assert(reason.len <= limits.relay_message_bytes_max);

    if (reason.len < 3) {
        return false;
    }

    const delimiter = std.mem.indexOfScalar(u8, reason, ':') orelse return false;
    if (delimiter == 0) {
        return false;
    }
    var suffix_start = delimiter + 1;
    while (suffix_start < reason.len and reason[suffix_start] == ' ') {
        suffix_start += 1;
    }
    if (suffix_start >= reason.len) {
        return false;
    }
    return true;
}

fn payload_hex_validate(payload_hex: []const u8) NegentropyError!void {
    std.debug.assert(limits.nip77_negentropy_hex_payload_bytes_max > 0);
    std.debug.assert(limits.nip77_negentropy_protocol_version > 0);

    if (payload_hex.len == 0) {
        return error.InvalidHexPayload;
    }
    if (payload_hex.len % 2 != 0) {
        return error.InvalidHexPayload;
    }
    const payload_bytes_len = payload_hex.len / 2;
    if (payload_bytes_len > limits.nip77_negentropy_hex_payload_bytes_max) {
        return error.InvalidHexPayload;
    }

    var index: u32 = 0;
    while (index < payload_hex.len) : (index += 2) {
        _ = try hex_nibble(payload_hex[index]);
        _ = try hex_nibble(payload_hex[index + 1]);
    }

    const first_hi = try hex_nibble(payload_hex[0]);
    const first_lo = try hex_nibble(payload_hex[1]);
    const version = (first_hi << 4) | first_lo;
    if (version != limits.nip77_negentropy_protocol_version) {
        return error.UnsupportedVersion;
    }
}

fn hex_nibble(character: u8) NegentropyError!u8 {
    std.debug.assert(character <= 255);
    std.debug.assert(limits.id_hex_length > 0);

    return std.fmt.charToDigit(character, 16) catch {
        return error.InvalidHexPayload;
    };
}

fn parse_kind_error(parse_kind: ParseKind) NegentropyError {
    std.debug.assert(@sizeOf(ParseKind) > 0);
    std.debug.assert(limits.nip77_negentropy_session_steps_max > 0);

    switch (parse_kind) {
        .neg_open => {
            return error.InvalidNegOpen;
        },
        .neg_msg => {
            return error.InvalidNegMsg;
        },
        .neg_close => {
            return error.InvalidNegClose;
        },
        .neg_err => {
            return error.InvalidNegErr;
        },
    }
}

fn state_set_subscription(
    state: *NegentropyState,
    subscription_id: []const u8,
) NegentropyError!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    if (subscription_id.len == 0) {
        return error.InvalidNegOpen;
    }
    if (subscription_id.len > limits.subscription_id_bytes_max) {
        return error.InvalidNegOpen;
    }

    @memset(state.subscription_id[0..], 0);
    @memcpy(state.subscription_id[0..subscription_id.len], subscription_id);
    state.subscription_id_len = @intCast(subscription_id.len);
}

fn state_subscription_matches(state: *const NegentropyState, subscription_id: []const u8) bool {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(state.subscription_id_len <= limits.subscription_id_bytes_max);

    if (subscription_id.len != state.subscription_id_len) {
        return false;
    }

    const state_id = state.subscription_id[0..state.subscription_id_len];
    return std.mem.eql(u8, state_id, subscription_id);
}

test "negentropy parse valid strict vectors" {
    var scratch_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer scratch_arena.deinit();
    const allocator = scratch_arena.allocator();

    try std.testing.expect(@intFromPtr(allocator.ptr) != 0);
    try std.testing.expect(limits.nip77_negentropy_protocol_version == 0x61);

    const open_input = "[\"NEG-OPEN\",\"sub-1\",{\"kinds\":[1]},\"6100\"]";
    const open_message = try negentropy_open_parse(open_input, allocator);
    try std.testing.expectEqualStrings("sub-1", open_message.subscription_id);
    try std.testing.expect(open_message.filter.kinds_count == 1);
    try std.testing.expectEqualStrings("6100", open_message.payload_hex);

    const msg_input = "[\"NEG-MSG\",\"sub-1\",\"61ff\"]";
    const msg_message = try negentropy_msg_parse(msg_input, allocator);
    try std.testing.expectEqualStrings("sub-1", msg_message.subscription_id);
    try std.testing.expectEqualStrings("61ff", msg_message.payload_hex);

    const close_input = "[\"NEG-CLOSE\",\"sub-1\"]";
    const close_message = try negentropy_close_parse(close_input, allocator);
    try std.testing.expectEqualStrings("sub-1", close_message.subscription_id);

    var state = NegentropyState{};
    const open_union: NegentropyMessage = .{ .open = open_message };
    const msg_union: NegentropyMessage = .{ .msg = msg_message };
    const close_union: NegentropyMessage = .{ .close = close_message };
    try negentropy_state_apply(&state, &open_union);
    try negentropy_state_apply(&state, &msg_union);
    try negentropy_state_apply(&state, &close_union);
    try std.testing.expect(state.stage == .closed);
    try std.testing.expectEqual(@as(u16, 3), state.steps);
}

test "negentropy parse valid strict neg err vector" {
    var scratch_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer scratch_arena.deinit();
    const allocator = scratch_arena.allocator();

    try std.testing.expect(@intFromPtr(allocator.ptr) != 0);
    try std.testing.expect(limits.subscription_id_bytes_max > 0);

    const err_input = "[\"NEG-ERR\",\"sub-1\",\"blocked: query too big\"]";
    const err_message = try negentropy_err_parse(err_input, allocator);
    try std.testing.expectEqualStrings("sub-1", err_message.subscription_id);
    try std.testing.expectEqualStrings("blocked: query too big", err_message.reason);

    const err_no_space_input = "[\"NEG-ERR\",\"sub-2\",\"blocked:query too big\"]";
    const err_no_space_message = try negentropy_err_parse(err_no_space_input, allocator);
    try std.testing.expectEqualStrings("sub-2", err_no_space_message.subscription_id);
    try std.testing.expectEqualStrings("blocked:query too big", err_no_space_message.reason);
}

test "negentropy parse invalid vectors" {
    var scratch_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer scratch_arena.deinit();
    const allocator = scratch_arena.allocator();

    try std.testing.expect(@intFromPtr(allocator.ptr) != 0);
    try std.testing.expect(limits.nip77_negentropy_hex_payload_bytes_max > 0);

    try std.testing.expectError(
        error.InvalidNegOpen,
        negentropy_open_parse("[\"NEG-OPEN\",\"sub\",\"6100\"]", allocator),
    );
    try std.testing.expectError(
        error.InvalidNegMsg,
        negentropy_msg_parse("[\"NEG-OPEN\",\"sub\",\"6100\"]", allocator),
    );
    try std.testing.expectError(
        error.InvalidHexPayload,
        negentropy_msg_parse("[\"NEG-MSG\",\"sub\",\"61f\"]", allocator),
    );
    try std.testing.expectError(
        error.InvalidHexPayload,
        negentropy_msg_parse("[\"NEG-MSG\",\"sub\",\"61zz\"]", allocator),
    );
    try std.testing.expectError(
        error.UnsupportedVersion,
        negentropy_msg_parse("[\"NEG-MSG\",\"sub\",\"6200\"]", allocator),
    );
    try std.testing.expectError(
        error.InvalidNegClose,
        negentropy_close_parse("[\"NEG-CLOSE\",\"sub\",\"extra\"]", allocator),
    );
    try std.testing.expectError(
        error.InvalidNegClose,
        negentropy_close_parse("[\"NEG-MSG\",\"sub\"]", allocator),
    );
    try std.testing.expectError(
        error.InvalidNegErr,
        negentropy_err_parse("[\"NEG-ERR\",\"sub\"]", allocator),
    );
    try std.testing.expectError(
        error.InvalidNegErr,
        negentropy_err_parse("[\"NEG-ERR\",\"sub\",\"blocked\"]", allocator),
    );
}

test "negentropy ordering vectors include reserved and tie-break failures" {
    try std.testing.expect(@sizeOf(NegentropyItem) > 0);
    try std.testing.expect(std.math.maxInt(u64) > 0);

    const ordered_items = [_]NegentropyItem{
        .{ .timestamp = 1, .id = [_]u8{0x00} ** 32 },
        .{ .timestamp = 1, .id = [_]u8{0x01} ** 32 },
        .{ .timestamp = 2, .id = [_]u8{0x00} ** 32 },
    };
    try negentropy_items_validate_order(ordered_items[0..]);

    const reserved_items = [_]NegentropyItem{
        .{ .timestamp = std.math.maxInt(u64), .id = [_]u8{0x00} ** 32 },
    };
    try std.testing.expectError(
        error.ReservedTimestamp,
        negentropy_items_validate_order(reserved_items[0..]),
    );

    const tie_break_items = [_]NegentropyItem{
        .{ .timestamp = 5, .id = [_]u8{0x10} ** 32 },
        .{ .timestamp = 5, .id = [_]u8{0x10} ** 32 },
    };
    try std.testing.expectError(
        error.InvalidOrdering,
        negentropy_items_validate_order(tie_break_items[0..]),
    );
}

test "negentropy state vectors include transition and overflow failures" {
    try std.testing.expect(limits.nip77_negentropy_session_steps_max > 0);
    try std.testing.expect(limits.subscription_id_bytes_max > 0);

    var idle_state = NegentropyState{};
    const msg_union: NegentropyMessage = .{ .msg = .{
        .subscription_id = "sub",
        .payload_hex = "6100",
    } };
    const close_union: NegentropyMessage = .{ .close = .{ .subscription_id = "sub" } };
    const err_union: NegentropyMessage = .{ .err = .{
        .subscription_id = "sub",
        .reason = "closed: timeout",
    } };
    try std.testing.expectError(
        error.InvalidNegMsg,
        negentropy_state_apply(&idle_state, &msg_union),
    );
    try std.testing.expectError(
        error.InvalidNegClose,
        negentropy_state_apply(&idle_state, &close_union),
    );
    try std.testing.expectError(
        error.InvalidNegErr,
        negentropy_state_apply(&idle_state, &err_union),
    );

    const open_union: NegentropyMessage = .{ .open = .{
        .subscription_id = "sub",
        .filter = .{},
        .payload_hex = "6100",
    } };
    try negentropy_state_apply(&idle_state, &open_union);
    try negentropy_state_apply(&idle_state, &open_union);
    try std.testing.expect(idle_state.stage == .open);
    try std.testing.expectEqual(@as(u16, 2), idle_state.steps);

    var error_state = NegentropyState{};
    try negentropy_state_apply(&error_state, &open_union);
    try negentropy_state_apply(&error_state, &err_union);
    try std.testing.expect(error_state.stage == .closed);
    try std.testing.expectEqual(@as(u16, 2), error_state.steps);

    const malformed_err_union: NegentropyMessage = .{ .err = .{
        .subscription_id = "sub",
        .reason = "closed",
    } };
    try std.testing.expectError(
        error.InvalidNegErr,
        negentropy_state_apply(&idle_state, &malformed_err_union),
    );

    var overflow_state = NegentropyState{};
    overflow_state.stage = .open;
    overflow_state.subscription_id_len = 3;
    overflow_state.subscription_id[0] = 's';
    overflow_state.subscription_id[1] = 'u';
    overflow_state.subscription_id[2] = 'b';
    overflow_state.steps = limits.nip77_negentropy_session_steps_max;
    try std.testing.expectError(
        error.SessionStateExceeded,
        negentropy_state_apply(&overflow_state, &msg_union),
    );
}

test "negentropy payload limit overflow maps to InvalidHexPayload" {
    var scratch_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer scratch_arena.deinit();
    const allocator = scratch_arena.allocator();

    try std.testing.expect(@intFromPtr(allocator.ptr) != 0);
    try std.testing.expect(limits.nip77_negentropy_hex_payload_bytes_max > 0);

    const payload_hex_len = @as(usize, limits.nip77_negentropy_hex_payload_bytes_max) * 2 + 2;
    var payload_hex = try allocator.alloc(u8, payload_hex_len);

    @memset(payload_hex, '0');
    payload_hex[0] = '6';
    payload_hex[1] = '1';

    const json_input = try std.fmt.allocPrint(
        allocator,
        "[\"NEG-MSG\",\"sub\",\"{s}\"]",
        .{payload_hex},
    );

    try std.testing.expectError(
        error.InvalidHexPayload,
        negentropy_msg_parse(json_input, allocator),
    );
}

const std = @import("std");
const limits = @import("limits.zig");

pub const RelayManagementError = error{
    InvalidRequest,
    InvalidResponse,
    InvalidMethod,
    InvalidParams,
    TooManyParams,
    InvalidPubkey,
    InvalidEventId,
    InvalidKind,
    InvalidIp,
    InvalidUrl,
    InvalidText,
    BufferTooSmall,
};

pub const RelayManagementMethod = enum {
    supportedmethods,
    banpubkey,
    unbanpubkey,
    listbannedpubkeys,
    allowpubkey,
    unallowpubkey,
    listallowedpubkeys,
    listeventsneedingmoderation,
    allowevent,
    banevent,
    listbannedevents,
    changerelayname,
    changerelaydescription,
    changerelayicon,
    allowkind,
    disallowkind,
    listallowedkinds,
    blockip,
    unblockip,
    listblockedips,
};

pub const PubkeyReason = struct {
    pubkey: [32]u8,
    reason: ?[]const u8 = null,
};

pub const EventIdReason = struct {
    id: [32]u8,
    reason: ?[]const u8 = null,
};

pub const IpReason = struct {
    ip: []const u8,
    reason: ?[]const u8 = null,
};

pub const Request = union(enum) {
    supportedmethods,
    banpubkey: PubkeyReason,
    unbanpubkey: PubkeyReason,
    listbannedpubkeys,
    allowpubkey: PubkeyReason,
    unallowpubkey: PubkeyReason,
    listallowedpubkeys,
    listeventsneedingmoderation,
    allowevent: EventIdReason,
    banevent: EventIdReason,
    listbannedevents,
    changerelayname: []const u8,
    changerelaydescription: []const u8,
    changerelayicon: []const u8,
    allowkind: u32,
    disallowkind: u32,
    listallowedkinds,
    blockip: IpReason,
    unblockip: []const u8,
    listblockedips,
};

pub const ResponsePayload = union(enum) {
    absent,
    ack,
    methods: []const []const u8,
    pubkeys: []const PubkeyReason,
    events: []const EventIdReason,
    kinds: []const u32,
    ips: []const IpReason,
};

pub const Response = struct {
    result: ResponsePayload = .absent,
    error_text: ?[]const u8 = null,
};

pub fn method_parse(text: []const u8) RelayManagementError!RelayManagementMethod {
    std.debug.assert(@sizeOf(RelayManagementMethod) > 0);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidMethod;

    if (std.mem.eql(u8, text, "supportedmethods")) return .supportedmethods;
    if (std.mem.eql(u8, text, "banpubkey")) return .banpubkey;
    if (std.mem.eql(u8, text, "unbanpubkey")) return .unbanpubkey;
    if (std.mem.eql(u8, text, "listbannedpubkeys")) return .listbannedpubkeys;
    if (std.mem.eql(u8, text, "allowpubkey")) return .allowpubkey;
    if (std.mem.eql(u8, text, "unallowpubkey")) return .unallowpubkey;
    if (std.mem.eql(u8, text, "listallowedpubkeys")) return .listallowedpubkeys;
    if (std.mem.eql(u8, text, "listeventsneedingmoderation")) return .listeventsneedingmoderation;
    if (std.mem.eql(u8, text, "allowevent")) return .allowevent;
    if (std.mem.eql(u8, text, "banevent")) return .banevent;
    if (std.mem.eql(u8, text, "listbannedevents")) return .listbannedevents;
    if (std.mem.eql(u8, text, "changerelayname")) return .changerelayname;
    if (std.mem.eql(u8, text, "changerelaydescription")) return .changerelaydescription;
    if (std.mem.eql(u8, text, "changerelayicon")) return .changerelayicon;
    if (std.mem.eql(u8, text, "allowkind")) return .allowkind;
    if (std.mem.eql(u8, text, "disallowkind")) return .disallowkind;
    if (std.mem.eql(u8, text, "listallowedkinds")) return .listallowedkinds;
    if (std.mem.eql(u8, text, "blockip")) return .blockip;
    if (std.mem.eql(u8, text, "unblockip")) return .unblockip;
    if (std.mem.eql(u8, text, "listblockedips")) return .listblockedips;
    return error.InvalidMethod;
}

pub fn method_text(method: RelayManagementMethod) []const u8 {
    std.debug.assert(@intFromEnum(method) <= @intFromEnum(RelayManagementMethod.listblockedips));
    std.debug.assert(@typeInfo(RelayManagementMethod) == .@"enum");

    return switch (method) {
        .supportedmethods => "supportedmethods",
        .banpubkey => "banpubkey",
        .unbanpubkey => "unbanpubkey",
        .listbannedpubkeys => "listbannedpubkeys",
        .allowpubkey => "allowpubkey",
        .unallowpubkey => "unallowpubkey",
        .listallowedpubkeys => "listallowedpubkeys",
        .listeventsneedingmoderation => "listeventsneedingmoderation",
        .allowevent => "allowevent",
        .banevent => "banevent",
        .listbannedevents => "listbannedevents",
        .changerelayname => "changerelayname",
        .changerelaydescription => "changerelaydescription",
        .changerelayicon => "changerelayicon",
        .allowkind => "allowkind",
        .disallowkind => "disallowkind",
        .listallowedkinds => "listallowedkinds",
        .blockip => "blockip",
        .unblockip => "unblockip",
        .listblockedips => "listblockedips",
    };
}

/// Parse a bounded NIP-86 JSON-RPC request.
/// See `examples/nip86_example.zig` and `examples/relay_admin_recipe.zig`.
pub fn request_parse_json(input: []const u8, scratch: std.mem.Allocator) RelayManagementError!Request {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.relay_message_bytes_max > 0);

    if (input.len > limits.relay_message_bytes_max) return error.InvalidRequest;

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = parse_json_root(input, parse_arena.allocator()) catch return error.InvalidRequest;
    if (root != .object) return error.InvalidRequest;
    return parse_request_object(root.object, scratch);
}

/// Serialize a bounded NIP-86 JSON-RPC request.
pub fn request_serialize_json(output: []u8, request: Request) RelayManagementError![]const u8 {
    std.debug.assert(output.len <= limits.relay_message_bytes_max);
    std.debug.assert(@sizeOf(Request) > 0);

    var index: u32 = 0;
    try write_bytes(output, &index, "{\"method\":");
    try write_json_string(output, &index, method_text(request_method(request)));
    try write_bytes(output, &index, ",\"params\":[");
    try serialize_request_params(output, &index, request);
    try write_bytes(output, &index, "]}");
    return output[0..@intCast(index)];
}

/// Parse a bounded NIP-86 JSON-RPC response for the expected method.
/// See `examples/relay_admin_recipe.zig`.
pub fn response_parse_json(
    input: []const u8,
    expected_method: RelayManagementMethod,
    out_methods: [][]const u8,
    out_pubkeys: []PubkeyReason,
    out_events: []EventIdReason,
    out_kinds: []u32,
    out_ips: []IpReason,
    scratch: std.mem.Allocator,
) RelayManagementError!Response {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.relay_message_bytes_max > 0);

    if (input.len > limits.relay_message_bytes_max) return error.InvalidResponse;

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = parse_json_root(input, parse_arena.allocator()) catch return error.InvalidResponse;
    if (root != .object) return error.InvalidResponse;
    return parse_response_object(
        root.object,
        expected_method,
        out_methods,
        out_pubkeys,
        out_events,
        out_kinds,
        out_ips,
        scratch,
    );
}

/// Serialize a bounded NIP-86 JSON-RPC response.
pub fn response_serialize_json(output: []u8, response: Response) RelayManagementError![]const u8 {
    std.debug.assert(output.len <= limits.relay_message_bytes_max);
    std.debug.assert(@sizeOf(Response) > 0);

    var index: u32 = 0;
    try write_bytes(output, &index, "{\"result\":");
    try serialize_response_result(output, &index, response.result);
    try write_bytes(output, &index, ",\"error\":");
    if (response.error_text) |text| {
        try write_json_string(output, &index, text);
    } else {
        try write_bytes(output, &index, "null");
    }
    try write_bytes(output, &index, "}");
    return output[0..@intCast(index)];
}

fn parse_json_root(
    input: []const u8,
    parse_allocator: std.mem.Allocator,
) error{InvalidJson}!std.json.Value {
    std.debug.assert(input.len <= limits.relay_message_bytes_max);
    std.debug.assert(@intFromPtr(parse_allocator.ptr) != 0);

    if (input.len == 0) return error.InvalidJson;
    if (!std.unicode.utf8ValidateSlice(input)) return error.InvalidJson;
    return std.json.parseFromSliceLeaky(std.json.Value, parse_allocator, input, .{}) catch {
        return error.InvalidJson;
    };
}

fn parse_request_object(
    object: std.json.ObjectMap,
    scratch: std.mem.Allocator,
) RelayManagementError!Request {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var method: ?RelayManagementMethod = null;
    var params: ?[]const std.json.Value = null;
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "method")) {
            method = try parse_method_value(entry.value_ptr.*);
        } else if (std.mem.eql(u8, entry.key_ptr.*, "params")) {
            params = try parse_params_array(entry.value_ptr.*);
        }
    }
    return parse_request_params(method orelse return error.InvalidRequest, params orelse return error.InvalidRequest, scratch);
}

fn parse_method_value(value: std.json.Value) RelayManagementError!RelayManagementMethod {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(RelayManagementMethod) > 0);

    if (value != .string) return error.InvalidMethod;
    return method_parse(value.string);
}

fn parse_params_array(value: std.json.Value) RelayManagementError![]const std.json.Value {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.tag_items_max > 0);

    if (value != .array) return error.InvalidParams;
    if (value.array.items.len > 2) return error.TooManyParams;
    return value.array.items;
}

fn parse_request_params(
    method: RelayManagementMethod,
    params: []const std.json.Value,
    scratch: std.mem.Allocator,
) RelayManagementError!Request {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(params.len <= 2);

    return switch (method) {
        .supportedmethods => try parse_zero_param_request(params, .supportedmethods),
        .listbannedpubkeys => try parse_zero_param_request(params, .listbannedpubkeys),
        .listallowedpubkeys => try parse_zero_param_request(params, .listallowedpubkeys),
        .listeventsneedingmoderation => try parse_zero_param_request(params, .listeventsneedingmoderation),
        .listbannedevents => try parse_zero_param_request(params, .listbannedevents),
        .listallowedkinds => try parse_zero_param_request(params, .listallowedkinds),
        .listblockedips => try parse_zero_param_request(params, .listblockedips),
        .banpubkey => .{ .banpubkey = try parse_pubkey_reason(params, scratch) },
        .unbanpubkey => .{ .unbanpubkey = try parse_pubkey_reason(params, scratch) },
        .allowpubkey => .{ .allowpubkey = try parse_pubkey_reason(params, scratch) },
        .unallowpubkey => .{ .unallowpubkey = try parse_pubkey_reason(params, scratch) },
        .allowevent => .{ .allowevent = try parse_event_reason(params, scratch) },
        .banevent => .{ .banevent = try parse_event_reason(params, scratch) },
        .changerelayname => .{ .changerelayname = try parse_one_text_param(params, scratch) },
        .changerelaydescription => .{ .changerelaydescription = try parse_one_text_param(params, scratch) },
        .changerelayicon => .{ .changerelayicon = try parse_one_url_param(params, scratch) },
        .allowkind => .{ .allowkind = try parse_one_kind_param(params) },
        .disallowkind => .{ .disallowkind = try parse_one_kind_param(params) },
        .blockip => .{ .blockip = try parse_ip_reason(params, scratch) },
        .unblockip => .{ .unblockip = try parse_one_ip_param(params, scratch) },
    };
}

fn parse_zero_param_request(params: []const std.json.Value, request: Request) RelayManagementError!Request {
    std.debug.assert(params.len <= 2);
    std.debug.assert(@sizeOf(Request) > 0);

    if (params.len != 0) return error.InvalidParams;
    return request;
}

fn parse_pubkey_reason(
    params: []const std.json.Value,
    scratch: std.mem.Allocator,
) RelayManagementError!PubkeyReason {
    std.debug.assert(params.len <= 2);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (params.len == 0 or params.len > 2) return error.InvalidParams;
    return .{
        .pubkey = try parse_hex_field(params[0], error.InvalidPubkey),
        .reason = try parse_optional_reason(params, scratch),
    };
}

fn parse_event_reason(
    params: []const std.json.Value,
    scratch: std.mem.Allocator,
) RelayManagementError!EventIdReason {
    std.debug.assert(params.len <= 2);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (params.len == 0 or params.len > 2) return error.InvalidParams;
    return .{
        .id = try parse_hex_field(params[0], error.InvalidEventId),
        .reason = try parse_optional_reason(params, scratch),
    };
}

fn parse_ip_reason(params: []const std.json.Value, scratch: std.mem.Allocator) RelayManagementError!IpReason {
    std.debug.assert(params.len <= 2);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (params.len == 0 or params.len > 2) return error.InvalidParams;
    return .{
        .ip = try parse_ip_value(params[0], scratch),
        .reason = try parse_optional_reason(params, scratch),
    };
}

fn parse_optional_reason(
    params: []const std.json.Value,
    scratch: std.mem.Allocator,
) RelayManagementError!?[]const u8 {
    std.debug.assert(params.len <= 2);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (params.len < 2) return null;
    const parsed = try parse_text_value(params[1], scratch);
    return parsed;
}

fn parse_one_text_param(params: []const std.json.Value, scratch: std.mem.Allocator) RelayManagementError![]const u8 {
    std.debug.assert(params.len <= 2);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (params.len != 1) return error.InvalidParams;
    return parse_text_value(params[0], scratch);
}

fn parse_one_url_param(params: []const std.json.Value, scratch: std.mem.Allocator) RelayManagementError![]const u8 {
    std.debug.assert(params.len <= 2);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (params.len != 1) return error.InvalidParams;
    return parse_url_value(params[0], scratch);
}

fn parse_one_kind_param(params: []const std.json.Value) RelayManagementError!u32 {
    std.debug.assert(params.len <= 2);
    std.debug.assert(@sizeOf(u32) == 4);

    if (params.len != 1) return error.InvalidParams;
    return parse_kind_value(params[0]);
}

fn parse_one_ip_param(params: []const std.json.Value, scratch: std.mem.Allocator) RelayManagementError![]const u8 {
    std.debug.assert(params.len <= 2);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (params.len != 1) return error.InvalidParams;
    return parse_ip_value(params[0], scratch);
}

fn parse_hex_field(value: std.json.Value, invalid: RelayManagementError) RelayManagementError![32]u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (value != .string) return invalid;
    if (value.string.len != limits.pubkey_hex_length) return invalid;
    var out: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&out, value.string) catch return invalid;
    return out;
}

fn parse_text_value(value: std.json.Value, scratch: std.mem.Allocator) RelayManagementError![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .string) return error.InvalidText;
    if (!std.unicode.utf8ValidateSlice(value.string)) return error.InvalidText;
    return scratch.dupe(u8, value.string) catch return error.InvalidRequest;
}

fn parse_url_value(value: std.json.Value, scratch: std.mem.Allocator) RelayManagementError![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const text = try parse_text_value(value, scratch);
    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (parsed.scheme.len == 0 or parsed.host == null) return error.InvalidUrl;
    return text;
}

fn parse_kind_value(value: std.json.Value) RelayManagementError!u32 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.kind_max == std.math.maxInt(u16));

    if (value != .integer) return error.InvalidKind;
    if (value.integer < 0) return error.InvalidKind;
    return std.math.cast(u32, value.integer) orelse error.InvalidKind;
}

fn parse_ip_value(value: std.json.Value, scratch: std.mem.Allocator) RelayManagementError![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const text = try parse_text_value(value, scratch);
    _ = std.net.Address.parseIp(text, 0) catch return error.InvalidIp;
    return text;
}

fn parse_response_object(
    object: std.json.ObjectMap,
    expected_method: RelayManagementMethod,
    out_methods: [][]const u8,
    out_pubkeys: []PubkeyReason,
    out_events: []EventIdReason,
    out_kinds: []u32,
    out_ips: []IpReason,
    scratch: std.mem.Allocator,
) RelayManagementError!Response {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var result_value: ?std.json.Value = null;
    var error_text: ?[]const u8 = null;
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "result")) result_value = entry.value_ptr.*;
        if (std.mem.eql(u8, entry.key_ptr.*, "error")) {
            error_text = try parse_optional_error(entry.value_ptr.*, scratch);
        }
    }
    if (result_value == null) return error.InvalidResponse;
    return .{
        .result = try parse_response_payload(
            result_value.?,
            expected_method,
            out_methods,
            out_pubkeys,
            out_events,
            out_kinds,
            out_ips,
            scratch,
        ),
        .error_text = error_text,
    };
}

fn parse_optional_error(value: std.json.Value, scratch: std.mem.Allocator) RelayManagementError!?[]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value == .null) return null;
    const parsed = try parse_text_value(value, scratch);
    return parsed;
}

fn parse_response_payload(
    value: std.json.Value,
    expected_method: RelayManagementMethod,
    out_methods: [][]const u8,
    out_pubkeys: []PubkeyReason,
    out_events: []EventIdReason,
    out_kinds: []u32,
    out_ips: []IpReason,
    scratch: std.mem.Allocator,
) RelayManagementError!ResponsePayload {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(@sizeOf(ResponsePayload) > 0);

    return switch (expected_method) {
        .supportedmethods => .{ .methods = try parse_string_array(value, out_methods, scratch) },
        .listbannedpubkeys, .listallowedpubkeys => .{
            .pubkeys = try parse_pubkey_entries(value, out_pubkeys, scratch),
        },
        .listeventsneedingmoderation, .listbannedevents => .{
            .events = try parse_event_entries(value, out_events, scratch),
        },
        .listallowedkinds => .{ .kinds = try parse_kind_array(value, out_kinds) },
        .listblockedips => .{ .ips = try parse_ip_entries(value, out_ips, scratch) },
        else => try parse_ack_result(value),
    };
}

fn parse_ack_result(value: std.json.Value) RelayManagementError!ResponsePayload {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(ResponsePayload) > 0);

    if (value != .bool) return error.InvalidResponse;
    if (!value.bool) return error.InvalidResponse;
    return .ack;
}

fn parse_string_array(
    value: std.json.Value,
    out: [][]const u8,
    scratch: std.mem.Allocator,
) RelayManagementError![]const []const u8 {
    std.debug.assert(out.len <= limits.tags_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .array) return error.InvalidResponse;
    if (value.array.items.len > out.len) return error.InvalidResponse;
    var index: u16 = 0;
    while (index < value.array.items.len) : (index += 1) {
        out[index] = try parse_text_value(value.array.items[index], scratch);
    }
    return out[0..index];
}

fn parse_pubkey_entries(
    value: std.json.Value,
    out: []PubkeyReason,
    scratch: std.mem.Allocator,
) RelayManagementError![]const PubkeyReason {
    std.debug.assert(out.len <= limits.tags_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .array) return error.InvalidResponse;
    if (value.array.items.len > out.len) return error.InvalidResponse;
    var index: u16 = 0;
    while (index < value.array.items.len) : (index += 1) {
        out[index] = try parse_pubkey_entry(value.array.items[index], scratch);
    }
    return out[0..index];
}

fn parse_pubkey_entry(value: std.json.Value, scratch: std.mem.Allocator) RelayManagementError!PubkeyReason {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .object) return error.InvalidResponse;
    var pubkey: ?[32]u8 = null;
    var reason: ?[]const u8 = null;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "pubkey")) {
            pubkey = try parse_hex_field(entry.value_ptr.*, error.InvalidResponse);
        } else if (std.mem.eql(u8, entry.key_ptr.*, "reason")) {
            reason = try parse_text_value(entry.value_ptr.*, scratch);
        }
    }
    return .{ .pubkey = pubkey orelse return error.InvalidResponse, .reason = reason };
}

fn parse_event_entries(
    value: std.json.Value,
    out: []EventIdReason,
    scratch: std.mem.Allocator,
) RelayManagementError![]const EventIdReason {
    std.debug.assert(out.len <= limits.tags_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .array) return error.InvalidResponse;
    if (value.array.items.len > out.len) return error.InvalidResponse;
    var index: u16 = 0;
    while (index < value.array.items.len) : (index += 1) {
        out[index] = try parse_event_entry(value.array.items[index], scratch);
    }
    return out[0..index];
}

fn parse_event_entry(value: std.json.Value, scratch: std.mem.Allocator) RelayManagementError!EventIdReason {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .object) return error.InvalidResponse;
    var id: ?[32]u8 = null;
    var reason: ?[]const u8 = null;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "id")) {
            id = try parse_hex_field(entry.value_ptr.*, error.InvalidResponse);
        } else if (std.mem.eql(u8, entry.key_ptr.*, "reason")) {
            reason = try parse_text_value(entry.value_ptr.*, scratch);
        }
    }
    return .{ .id = id orelse return error.InvalidResponse, .reason = reason };
}

fn parse_kind_array(value: std.json.Value, out: []u32) RelayManagementError![]const u32 {
    std.debug.assert(out.len <= limits.tags_max);
    std.debug.assert(@sizeOf(u32) == 4);

    if (value != .array) return error.InvalidResponse;
    if (value.array.items.len > out.len) return error.InvalidResponse;
    var index: u16 = 0;
    while (index < value.array.items.len) : (index += 1) {
        out[index] = try parse_kind_value(value.array.items[index]);
    }
    return out[0..index];
}

fn parse_ip_entries(
    value: std.json.Value,
    out: []IpReason,
    scratch: std.mem.Allocator,
) RelayManagementError![]const IpReason {
    std.debug.assert(out.len <= limits.tags_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .array) return error.InvalidResponse;
    if (value.array.items.len > out.len) return error.InvalidResponse;
    var index: u16 = 0;
    while (index < value.array.items.len) : (index += 1) {
        out[index] = try parse_ip_entry(value.array.items[index], scratch);
    }
    return out[0..index];
}

fn parse_ip_entry(value: std.json.Value, scratch: std.mem.Allocator) RelayManagementError!IpReason {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .object) return error.InvalidResponse;
    var ip: ?[]const u8 = null;
    var reason: ?[]const u8 = null;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "ip")) {
            ip = try parse_ip_value(entry.value_ptr.*, scratch);
        } else if (std.mem.eql(u8, entry.key_ptr.*, "reason")) {
            reason = try parse_text_value(entry.value_ptr.*, scratch);
        }
    }
    return .{ .ip = ip orelse return error.InvalidResponse, .reason = reason };
}

fn request_method(request: Request) RelayManagementMethod {
    std.debug.assert(@sizeOf(Request) > 0);
    std.debug.assert(@sizeOf(RelayManagementMethod) > 0);

    return switch (request) {
        .supportedmethods => .supportedmethods,
        .banpubkey => .banpubkey,
        .unbanpubkey => .unbanpubkey,
        .listbannedpubkeys => .listbannedpubkeys,
        .allowpubkey => .allowpubkey,
        .unallowpubkey => .unallowpubkey,
        .listallowedpubkeys => .listallowedpubkeys,
        .listeventsneedingmoderation => .listeventsneedingmoderation,
        .allowevent => .allowevent,
        .banevent => .banevent,
        .listbannedevents => .listbannedevents,
        .changerelayname => .changerelayname,
        .changerelaydescription => .changerelaydescription,
        .changerelayicon => .changerelayicon,
        .allowkind => .allowkind,
        .disallowkind => .disallowkind,
        .listallowedkinds => .listallowedkinds,
        .blockip => .blockip,
        .unblockip => .unblockip,
        .listblockedips => .listblockedips,
    };
}

fn serialize_request_params(output: []u8, index: *u32, request: Request) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(output.len <= limits.relay_message_bytes_max);

    switch (request) {
        .supportedmethods, .listbannedpubkeys, .listallowedpubkeys, .listeventsneedingmoderation, .listbannedevents, .listallowedkinds, .listblockedips => {},
        .banpubkey => |entry| try serialize_pubkey_reason_params(output, index, entry),
        .unbanpubkey => |entry| try serialize_pubkey_reason_params(output, index, entry),
        .allowpubkey => |entry| try serialize_pubkey_reason_params(output, index, entry),
        .unallowpubkey => |entry| try serialize_pubkey_reason_params(output, index, entry),
        .allowevent => |entry| try serialize_event_reason_params(output, index, entry),
        .banevent => |entry| try serialize_event_reason_params(output, index, entry),
        .changerelayname => |text| try write_json_string(output, index, text),
        .changerelaydescription => |text| try write_json_string(output, index, text),
        .changerelayicon => |text| try write_json_string(output, index, text),
        .allowkind => |kind| try write_u32(output, index, kind),
        .disallowkind => |kind| try write_u32(output, index, kind),
        .blockip => |entry| try serialize_ip_reason_params(output, index, entry),
        .unblockip => |ip| try write_json_string(output, index, ip),
    }
}

fn serialize_pubkey_reason_params(
    output: []u8,
    index: *u32,
    entry: PubkeyReason,
) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(entry.pubkey[0] <= 255);

    const hex = std.fmt.bytesToHex(entry.pubkey, .lower);
    try write_json_string(output, index, hex[0..]);
    if (entry.reason) |reason| {
        try write_bytes(output, index, ",");
        try write_json_string(output, index, reason);
    }
}

fn serialize_event_reason_params(
    output: []u8,
    index: *u32,
    entry: EventIdReason,
) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(entry.id[0] <= 255);

    const hex = std.fmt.bytesToHex(entry.id, .lower);
    try write_json_string(output, index, hex[0..]);
    if (entry.reason) |reason| {
        try write_bytes(output, index, ",");
        try write_json_string(output, index, reason);
    }
}

fn serialize_ip_reason_params(output: []u8, index: *u32, entry: IpReason) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(entry.ip.len <= limits.tag_item_bytes_max);

    try write_json_string(output, index, entry.ip);
    if (entry.reason) |reason| {
        try write_bytes(output, index, ",");
        try write_json_string(output, index, reason);
    }
}

fn serialize_response_result(
    output: []u8,
    index: *u32,
    result: ResponsePayload,
) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(ResponsePayload) > 0);

    switch (result) {
        .absent => try write_bytes(output, index, "null"),
        .ack => try write_bytes(output, index, "true"),
        .methods => |items| try serialize_string_array(output, index, items),
        .pubkeys => |items| try serialize_pubkey_entries(output, index, items),
        .events => |items| try serialize_event_entries(output, index, items),
        .kinds => |items| try serialize_kind_array(output, index, items),
        .ips => |items| try serialize_ip_entries(output, index, items),
    }
}

fn serialize_string_array(output: []u8, index: *u32, items: []const []const u8) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(items.len <= limits.tags_max);

    try write_bytes(output, index, "[");
    for (items, 0..) |item, idx| {
        if (idx != 0) try write_bytes(output, index, ",");
        try write_json_string(output, index, item);
    }
    try write_bytes(output, index, "]");
}

fn serialize_pubkey_entries(
    output: []u8,
    index: *u32,
    items: []const PubkeyReason,
) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(items.len <= limits.tags_max);

    try write_bytes(output, index, "[");
    for (items, 0..) |item, idx| {
        if (idx != 0) try write_bytes(output, index, ",");
        const hex = std.fmt.bytesToHex(item.pubkey, .lower);
        try write_bytes(output, index, "{\"pubkey\":");
        try write_json_string(output, index, hex[0..]);
        if (item.reason) |reason| {
            try write_bytes(output, index, ",\"reason\":");
            try write_json_string(output, index, reason);
        }
        try write_bytes(output, index, "}");
    }
    try write_bytes(output, index, "]");
}

fn serialize_event_entries(
    output: []u8,
    index: *u32,
    items: []const EventIdReason,
) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(items.len <= limits.tags_max);

    try write_bytes(output, index, "[");
    for (items, 0..) |item, idx| {
        if (idx != 0) try write_bytes(output, index, ",");
        const hex = std.fmt.bytesToHex(item.id, .lower);
        try write_bytes(output, index, "{\"id\":");
        try write_json_string(output, index, hex[0..]);
        if (item.reason) |reason| {
            try write_bytes(output, index, ",\"reason\":");
            try write_json_string(output, index, reason);
        }
        try write_bytes(output, index, "}");
    }
    try write_bytes(output, index, "]");
}

fn serialize_kind_array(output: []u8, index: *u32, items: []const u32) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(items.len <= limits.tags_max);

    try write_bytes(output, index, "[");
    for (items, 0..) |item, idx| {
        if (idx != 0) try write_bytes(output, index, ",");
        try write_u32(output, index, item);
    }
    try write_bytes(output, index, "]");
}

fn serialize_ip_entries(output: []u8, index: *u32, items: []const IpReason) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(items.len <= limits.tags_max);

    try write_bytes(output, index, "[");
    for (items, 0..) |item, idx| {
        if (idx != 0) try write_bytes(output, index, ",");
        try write_bytes(output, index, "{\"ip\":");
        try write_json_string(output, index, item.ip);
        if (item.reason) |reason| {
            try write_bytes(output, index, ",\"reason\":");
            try write_json_string(output, index, reason);
        }
        try write_bytes(output, index, "}");
    }
    try write_bytes(output, index, "]");
}

fn write_json_string(output: []u8, index: *u32, text: []const u8) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(text.len <= limits.relay_message_bytes_max);

    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidText;
    try write_bytes(output, index, "\"");
    for (text) |byte| {
        switch (byte) {
            '\\' => try write_bytes(output, index, "\\\\"),
            '"' => try write_bytes(output, index, "\\\""),
            '\n' => try write_bytes(output, index, "\\n"),
            '\r' => try write_bytes(output, index, "\\r"),
            '\t' => try write_bytes(output, index, "\\t"),
            else => {
                if (byte < 0x20) return error.InvalidText;
                try write_byte(output, index, byte);
            },
        }
    }
    try write_bytes(output, index, "\"");
}

fn write_u32(output: []u8, index: *u32, value: u32) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(value <= limits.kind_max);

    var buffer: [16]u8 = undefined;
    const rendered = std.fmt.bufPrint(buffer[0..], "{d}", .{value}) catch {
        return error.BufferTooSmall;
    };
    try write_bytes(output, index, rendered);
}

fn write_bytes(output: []u8, index: *u32, text: []const u8) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(text.len <= limits.relay_message_bytes_max);

    if (index.* + text.len > output.len) return error.BufferTooSmall;
    @memcpy(output[index.* .. index.* + text.len], text);
    index.* += @intCast(text.len);
}

fn write_byte(output: []u8, index: *u32, byte: u8) RelayManagementError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(byte <= 0xff);

    if (index.* + 1 > output.len) return error.BufferTooSmall;
    output[index.*] = byte;
    index.* += 1;
}

const banpubkey_request_json =
    \\{"method":"banpubkey","params":["0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","spam"]}
;

const pubkey_list_response_json =
    \\{"result":[{"pubkey":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","reason":"spam"}],"error":null}
;

const supported_methods_response_json =
    \\{"result":["banpubkey","listblockedips"],"error":null}
;

const ack_response_json =
    \\{"result":true,"error":null}
;

test "request parse and serialize roundtrip bounded relay-management methods" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed = try request_parse_json(banpubkey_request_json, arena.allocator());
    var output: [256]u8 = undefined;

    const encoded = try request_serialize_json(output[0..], parsed);
    try std.testing.expect(parsed == .banpubkey);
    try std.testing.expectEqualStrings(
        "{\"method\":\"banpubkey\",\"params\":[\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"spam\"]}",
        encoded,
    );
}

test "response parse decodes typed list results by expected method" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var entries: [2]PubkeyReason = undefined;
    var methods: [1][]const u8 = undefined;
    var events: [1]EventIdReason = undefined;
    var kinds: [1]u32 = undefined;
    var ips: [1]IpReason = undefined;
    const parsed = try response_parse_json(
        pubkey_list_response_json,
        .listbannedpubkeys,
        methods[0..],
        entries[0..],
        events[0..],
        kinds[0..],
        ips[0..],
        arena.allocator(),
    );

    try std.testing.expect(parsed.result == .pubkeys);
    try std.testing.expectEqual(@as(usize, 1), parsed.result.pubkeys.len);
    try std.testing.expectEqualStrings("spam", parsed.result.pubkeys[0].reason.?);
}

test "response parse handles supportedmethods and ack results" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var methods: [2][]const u8 = undefined;
    var pubkeys: [1]PubkeyReason = undefined;
    var events: [1]EventIdReason = undefined;
    var kinds: [2]u32 = undefined;
    var ips: [1]IpReason = undefined;
    const methods_response = try response_parse_json(
        supported_methods_response_json,
        .supportedmethods,
        methods[0..],
        pubkeys[0..],
        events[0..],
        kinds[0..],
        ips[0..],
        arena.allocator(),
    );
    const ack_response = try response_parse_json(
        ack_response_json,
        .banpubkey,
        methods[0..],
        pubkeys[0..],
        events[0..],
        kinds[0..],
        ips[0..],
        arena.allocator(),
    );

    try std.testing.expect(methods_response.result == .methods);
    try std.testing.expectEqualStrings("listblockedips", methods_response.result.methods[1]);
    try std.testing.expect(ack_response.result == .ack);
}

test "serializers reject invalid text instead of surfacing capacity errors" {
    var output: [256]u8 = undefined;

    try std.testing.expectError(
        error.InvalidText,
        request_serialize_json(
            output[0..],
            .{ .changerelayname = "bad\x01name" },
        ),
    );

    try std.testing.expectError(
        error.InvalidText,
        response_serialize_json(
            output[0..],
            .{ .result = .ack, .error_text = "bad\x02error" },
        ),
    );
}

test "public relay-management parse helpers reject overlong caller input with typed errors" {
    var overlong_method: [limits.tag_item_bytes_max + 1]u8 = undefined;
    @memset(overlong_method[0..], 'a');
    try std.testing.expectError(
        error.InvalidMethod,
        method_parse(overlong_method[0..]),
    );

    const message_len = limits.relay_message_bytes_max + 1;
    const overlong_json = try std.testing.allocator.alloc(u8, message_len);
    defer std.testing.allocator.free(overlong_json);
    @memset(overlong_json, 'a');

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidRequest,
        request_parse_json(overlong_json, arena.allocator()),
    );

    var methods: [1][]const u8 = undefined;
    var pubkeys: [1]PubkeyReason = undefined;
    var events: [1]EventIdReason = undefined;
    var kinds: [1]u32 = undefined;
    var ips: [1]IpReason = undefined;
    try std.testing.expectError(
        error.InvalidResponse,
        response_parse_json(
            overlong_json,
            .supportedmethods,
            methods[0..],
            pubkeys[0..],
            events[0..],
            kinds[0..],
            ips[0..],
            arena.allocator(),
        ),
    );
}

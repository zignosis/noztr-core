const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const nip44 = @import("nip44.zig");
const relay_origin = @import("internal/relay_origin.zig");

pub const remote_signing_event_kind: u32 = 24_133;

pub const Nip46Error = error{
    InvalidMethod,
    InvalidPermission,
    InvalidPermissionKind,
    InvalidMessage,
    InvalidRequest,
    InvalidResponse,
    InvalidId,
    InvalidParam,
    TooManyParams,
    InvalidUnsignedEvent,
    InvalidSignedEvent,
    InvalidUri,
    InvalidScheme,
    InvalidPubkey,
    MissingRelay,
    TooManyRelays,
    InvalidRelayUrl,
    MissingSecret,
    InvalidSecret,
    InvalidName,
    InvalidUrl,
    InvalidImage,
    TooManyPermissions,
    BufferTooSmall,
    InvalidEventKind,
    MissingTargetPubkey,
    DuplicateTargetPubkey,
    InvalidTargetPubkey,
    TargetPubkeyMismatch,
    InvalidEncryptedContent,
    OutOfMemory,
};

pub const RemoteSigningMethod = enum {
    connect,
    sign_event,
    ping,
    get_public_key,
    nip04_encrypt,
    nip04_decrypt,
    nip44_encrypt,
    nip44_decrypt,
    switch_relays,
};

pub const PermissionScope = union(enum) {
    none,
    event_kind: u32,
    raw: []const u8,
};

pub const Permission = struct {
    method: RemoteSigningMethod,
    scope: PermissionScope = .none,
};

pub const Request = struct {
    id: []const u8,
    method: RemoteSigningMethod,
    params: []const []const u8,
};

pub const ResponseResult = union(enum) {
    text: []const u8,
    relay_list: []const []const u8,
};

pub const ResponsePayload = union(enum) {
    absent,
    null_result,
    value: ResponseResult,
};

pub const Response = struct {
    id: []const u8,
    result: ResponsePayload = .absent,
    error_text: ?[]const u8 = null,
};

/// Typed `connect` response outcome.
pub const ConnectResult = union(enum) {
    ack,
    secret_echo: []const u8,
};

pub const Message = union(enum) {
    request: Request,
    response: Response,
};

pub const BunkerUri = struct {
    remote_signer_pubkey: [32]u8,
    relays: []const []const u8,
    secret: ?[]const u8 = null,
};

pub const ClientUri = struct {
    client_pubkey: [32]u8,
    relays: []const []const u8,
    secret: []const u8,
    permissions: []const Permission = &.{},
    name: ?[]const u8 = null,
    url: ?[]const u8 = null,
    image: ?[]const u8 = null,
};

pub const ConnectionUri = union(enum) {
    bunker: BunkerUri,
    client: ClientUri,
};

pub const Envelope = struct {
    target_pubkey: [32]u8,
};

pub fn method_parse(text: []const u8) Nip46Error!RemoteSigningMethod {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@sizeOf(RemoteSigningMethod) > 0);

    if (std.mem.eql(u8, text, "connect")) return .connect;
    if (std.mem.eql(u8, text, "sign_event")) return .sign_event;
    if (std.mem.eql(u8, text, "ping")) return .ping;
    if (std.mem.eql(u8, text, "get_public_key")) return .get_public_key;
    if (std.mem.eql(u8, text, "nip04_encrypt")) return .nip04_encrypt;
    if (std.mem.eql(u8, text, "nip04_decrypt")) return .nip04_decrypt;
    if (std.mem.eql(u8, text, "nip44_encrypt")) return .nip44_encrypt;
    if (std.mem.eql(u8, text, "nip44_decrypt")) return .nip44_decrypt;
    if (std.mem.eql(u8, text, "switch_relays")) return .switch_relays;
    return error.InvalidMethod;
}

pub fn method_text(method: RemoteSigningMethod) []const u8 {
    std.debug.assert(@intFromEnum(method) <= @intFromEnum(RemoteSigningMethod.switch_relays));
    std.debug.assert(!@inComptime());

    return switch (method) {
        .connect => "connect",
        .sign_event => "sign_event",
        .ping => "ping",
        .get_public_key => "get_public_key",
        .nip04_encrypt => "nip04_encrypt",
        .nip04_decrypt => "nip04_decrypt",
        .nip44_encrypt => "nip44_encrypt",
        .nip44_decrypt => "nip44_decrypt",
        .switch_relays => "switch_relays",
    };
}

pub fn permission_parse(text: []const u8) Nip46Error!Permission {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@sizeOf(Permission) > 0);

    const colon = std.mem.indexOfScalar(u8, text, ':');
    if (colon == null) {
        return .{ .method = try method_parse(text) };
    }

    const method_name = text[0..colon.?];
    const scope_text = text[colon.? + 1 ..];
    if (method_name.len == 0 or scope_text.len == 0) {
        return error.InvalidPermission;
    }

    const method = try method_parse(method_name);
    if (method == .sign_event) {
        const kind = std.fmt.parseUnsigned(u32, scope_text, 10) catch {
            return error.InvalidPermissionKind;
        };
        if (kind > limits.kind_max) {
            return error.InvalidPermissionKind;
        }
        return .{ .method = method, .scope = .{ .event_kind = kind } };
    }
    if (!std.unicode.utf8ValidateSlice(scope_text)) {
        return error.InvalidPermission;
    }
    return .{ .method = method, .scope = .{ .raw = scope_text } };
}

pub fn permission_format(output: []u8, permission: Permission) Nip46Error![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(@sizeOf(Permission) > 0);

    const method_name = method_text(permission.method);
    switch (permission.scope) {
        .none => {
            if (output.len < method_name.len) {
                return error.BufferTooSmall;
            }
            @memcpy(output[0..method_name.len], method_name);
            return output[0..method_name.len];
        },
        .event_kind => |kind| {
            return std.fmt.bufPrint(output, "{s}:{d}", .{ method_name, kind }) catch {
                return error.BufferTooSmall;
            };
        },
        .raw => |raw| {
            if (raw.len == 0) {
                return error.InvalidPermission;
            }
            if (!std.unicode.utf8ValidateSlice(raw)) {
                return error.InvalidPermission;
            }
            return std.fmt.bufPrint(output, "{s}:{s}", .{ method_name, raw }) catch {
                return error.BufferTooSmall;
            };
        },
    }
}

pub fn message_parse_json(input: []const u8, scratch: std.mem.Allocator) Nip46Error!Message {
    std.debug.assert(input.len <= limits.nip46_message_json_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (input.len == 0) {
        return error.InvalidMessage;
    }
    if (input.len > limits.nip46_message_json_bytes_max) {
        return error.InvalidMessage;
    }
    if (!std.unicode.utf8ValidateSlice(input)) {
        return error.InvalidMessage;
    }

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        parse_arena.allocator(),
        input,
        .{},
    ) catch {
        return error.InvalidMessage;
    };
    if (root != .object) {
        return error.InvalidMessage;
    }
    return parse_message_object(root.object, scratch);
}

pub fn message_serialize_json(output: []u8, message: Message) Nip46Error![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(Message) > 0);

    var stream = std.io.fixedBufferStream(output);
    const writer = stream.writer();
    switch (message) {
        .request => |request| try write_request_json(writer, request),
        .response => |response| try write_response_json(writer, response),
    }
    return output[0..stream.pos];
}

pub fn request_validate(request: *const Request, scratch: std.mem.Allocator) Nip46Error!void {
    std.debug.assert(@intFromPtr(request) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    try validate_message_id(request.id);
    if (request.params.len > limits.nip46_message_params_max) {
        return error.TooManyParams;
    }

    switch (request.method) {
        .connect => try validate_connect_params(request.params, scratch),
        .sign_event => try validate_sign_event_params(request.params, scratch),
        .ping, .get_public_key, .switch_relays => try require_zero_params(request.params),
        .nip04_encrypt, .nip04_decrypt, .nip44_encrypt, .nip44_decrypt => {
            try validate_pubkey_text_params(request.params);
        },
    }
}

pub fn response_validate(
    response: *const Response,
    method: RemoteSigningMethod,
    scratch: std.mem.Allocator,
) Nip46Error!void {
    std.debug.assert(@intFromPtr(response) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    try validate_response_common(response);
    switch (response.result) {
        .absent => {},
        .null_result => {
            if (method != .switch_relays) {
                return error.InvalidResponse;
            }
        },
        .value => |result| try validate_response_result(result, method, scratch),
    }
}

/// Parse a validated `connect` response into `ack` or a secret echo.
pub fn response_result_connect(response: *const Response) Nip46Error!ConnectResult {
    std.debug.assert(@intFromPtr(response) != 0);
    std.debug.assert(@sizeOf(ConnectResult) > 0);

    try validate_response_common(response);
    const text = try response_text_payload(response);
    if (std.mem.eql(u8, text, "ack")) {
        return .ack;
    }
    return .{ .secret_echo = text };
}

/// Parse a validated `get_public_key` response into the returned pubkey.
pub fn response_result_get_public_key(response: *const Response) Nip46Error![32]u8 {
    std.debug.assert(@intFromPtr(response) != 0);
    std.debug.assert(limits.pubkey_hex_length == 64);

    try validate_response_common(response);
    const text = try response_text_payload(response);
    return parse_lower_hex_32(text) catch return error.InvalidPubkey;
}

/// Parse a validated `sign_event` response into the signed event payload.
pub fn response_result_sign_event(
    response: *const Response,
    scratch: std.mem.Allocator,
) Nip46Error!nip01_event.Event {
    std.debug.assert(@intFromPtr(response) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    try validate_response_common(response);
    const text = try response_text_payload(response);
    return nip01_event.event_parse_json(text, scratch) catch return error.InvalidSignedEvent;
}

/// Parse a validated `switch_relays` response into an updated relay list or `null`.
pub fn response_result_switch_relays(response: *const Response) Nip46Error!?[]const []const u8 {
    std.debug.assert(@intFromPtr(response) != 0);
    std.debug.assert(@sizeOf(ResponsePayload) > 0);

    try validate_response_common(response);
    return switch (response.result) {
        .null_result => null,
        .value => |payload| switch (payload) {
            .relay_list => |relays| relays,
            .text => error.InvalidResponse,
        },
        .absent => error.InvalidResponse,
    };
}

pub fn uri_parse(input: []const u8, scratch: std.mem.Allocator) Nip46Error!ConnectionUri {
    std.debug.assert(input.len <= limits.nip46_uri_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const parts = try parse_uri_parts(input);
    if (scheme_is(parts.scheme, "bunker")) {
        return .{ .bunker = try parse_bunker_uri(parts.authority, parts.query, scratch) };
    }
    if (scheme_is(parts.scheme, "nostrconnect")) {
        return .{ .client = try parse_client_uri(parts.authority, parts.query, scratch) };
    }
    return error.InvalidScheme;
}

pub fn uri_serialize(output: []u8, uri: ConnectionUri) Nip46Error![]const u8 {
    std.debug.assert(output.len <= limits.nip46_uri_bytes_max);
    std.debug.assert(@sizeOf(ConnectionUri) > 0);

    var stream = std.io.fixedBufferStream(output);
    const writer = stream.writer();
    switch (uri) {
        .bunker => |bunker| try write_bunker_uri(writer, bunker),
        .client => |client| try write_client_uri(writer, client),
    }
    return output[0..stream.pos];
}

pub fn envelope_validate(
    event: *const nip01_event.Event,
    expected_target_pubkey: ?*const [32]u8,
    nip44_scratch: []u8,
) Nip46Error!Envelope {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(nip44_scratch.len <= limits.nip44_payload_decoded_max_bytes);

    if (event.kind != remote_signing_event_kind) {
        return error.InvalidEventKind;
    }
    if (event.content.len == 0) {
        return error.InvalidEncryptedContent;
    }

    var target_pubkey: ?[32]u8 = null;
    for (event.tags) |tag| {
        if (!tag_is_p(tag)) {
            continue;
        }
        if (target_pubkey != null) {
            return error.DuplicateTargetPubkey;
        }
        target_pubkey = try parse_target_pubkey(tag);
    }
    const resolved = target_pubkey orelse return error.MissingTargetPubkey;
    if (expected_target_pubkey) |expected| {
        if (!std.mem.eql(u8, expected, &resolved)) {
            return error.TargetPubkeyMismatch;
        }
    }

    _ = nip44.nip44_decode_payload(event.content, nip44_scratch) catch {
        return error.InvalidEncryptedContent;
    };
    return .{ .target_pubkey = resolved };
}

const ParsedUriParts = struct {
    scheme: []const u8,
    authority: []const u8,
    query: ?[]const u8,
};

fn parse_message_object(
    object: std.json.ObjectMap,
    scratch: std.mem.Allocator,
) Nip46Error!Message {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var id: ?[]const u8 = null;
    var method: ?RemoteSigningMethod = null;
    var params: ?[]const []const u8 = null;
    var result: ResponsePayload = .absent;
    var error_text: ?[]const u8 = null;
    var saw_result = false;
    var saw_error = false;

    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "id")) {
            if (id != null) return error.InvalidMessage;
            id = try parse_id_value(value, scratch);
            continue;
        }
        if (std.mem.eql(u8, key, "method")) {
            if (method != null) return error.InvalidMessage;
            method = try parse_method_value(value);
            continue;
        }
        if (std.mem.eql(u8, key, "params")) {
            if (params != null) return error.InvalidMessage;
            params = try parse_string_array_value(
                value,
                limits.nip46_message_params_max,
                limits.nip46_message_json_bytes_max,
                scratch,
            );
            continue;
        }
        if (std.mem.eql(u8, key, "result")) {
            if (saw_result) return error.InvalidMessage;
            result = try parse_result_value(value, scratch);
            saw_result = true;
            continue;
        }
        if (std.mem.eql(u8, key, "error")) {
            if (saw_error) return error.InvalidMessage;
            error_text = try parse_optional_string_value(
                value,
                limits.nip46_message_json_bytes_max,
                scratch,
            );
            saw_error = true;
        }
    }

    if (id == null) {
        return error.InvalidMessage;
    }
    if (method != null or params != null) {
        if (saw_result or saw_error) return error.InvalidMessage;
        const request = Request{
            .id = id.?,
            .method = method orelse return error.InvalidRequest,
            .params = params orelse return error.InvalidRequest,
        };
        try request_validate(&request, scratch);
        return .{ .request = request };
    }

    const response = Response{
        .id = id.?,
        .result = if (saw_result) result else .absent,
        .error_text = if (saw_error) error_text else null,
    };
    return .{ .response = response };
}

fn parse_id_value(value: std.json.Value, scratch: std.mem.Allocator) Nip46Error![]const u8 {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const id = try parse_required_string_value(
        value,
        limits.nip46_message_id_bytes_max,
        scratch,
        error.InvalidId,
    );
    try validate_message_id(id);
    return id;
}

fn parse_method_value(value: std.json.Value) Nip46Error!RemoteSigningMethod {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(@sizeOf(RemoteSigningMethod) > 0);

    if (value != .string) {
        return error.InvalidMethod;
    }
    return method_parse(value.string);
}

fn parse_result_value(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) Nip46Error!ResponsePayload {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value == .null) {
        return .null_result;
    }
    if (value == .string) {
        return .{ .value = .{
            .text = try duplicate_valid_utf8(
                value.string,
                limits.nip46_message_json_bytes_max,
                scratch,
            ),
        } };
    }
    if (value != .array) {
        return error.InvalidResponse;
    }

    const relays = try parse_string_array_value(
        value,
        limits.nip46_relays_max,
        limits.tag_item_bytes_max,
        scratch,
    );
    var index: usize = 0;
    while (index < relays.len) : (index += 1) {
        _ = parse_relay_url(relays[index]) catch return error.InvalidRelayUrl;
    }
    return .{ .value = .{ .relay_list = relays } };
}

fn parse_string_array_value(
    value: std.json.Value,
    max_items: u8,
    max_item_len: u32,
    scratch: std.mem.Allocator,
) Nip46Error![]const []const u8 {
    std.debug.assert(max_items > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .array) {
        return error.InvalidParam;
    }
    if (value.array.items.len > max_items) {
        return error.TooManyParams;
    }

    const out = scratch.alloc([]const u8, value.array.items.len) catch return error.OutOfMemory;
    var index: usize = 0;
    while (index < value.array.items.len) : (index += 1) {
        out[index] = try parse_required_string_value(
            value.array.items[index],
            max_item_len,
            scratch,
            error.InvalidParam,
        );
    }
    return out;
}

fn parse_optional_string_value(
    value: std.json.Value,
    max_len: u32,
    scratch: std.mem.Allocator,
) Nip46Error!?[]const u8 {
    std.debug.assert(max_len > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value == .null) {
        return null;
    }
    return try parse_required_string_value(value, max_len, scratch, error.InvalidResponse);
}

fn parse_required_string_value(
    value: std.json.Value,
    max_len: u32,
    scratch: std.mem.Allocator,
    invalid_error: Nip46Error,
) Nip46Error![]const u8 {
    std.debug.assert(max_len > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .string) {
        return invalid_error;
    }
    return duplicate_valid_utf8(value.string, max_len, scratch) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => invalid_error,
    };
}

fn duplicate_valid_utf8(
    text: []const u8,
    max_len: u32,
    scratch: std.mem.Allocator,
) error{InvalidParam, OutOfMemory}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(u32));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (text.len == 0) {
        return error.InvalidParam;
    }
    if (text.len > max_len) {
        return error.InvalidParam;
    }
    if (!std.unicode.utf8ValidateSlice(text)) {
        return error.InvalidParam;
    }
    return scratch.dupe(u8, text) catch return error.OutOfMemory;
}

fn validate_message_id(id: []const u8) Nip46Error!void {
    std.debug.assert(id.len <= limits.nip46_message_id_bytes_max);
    std.debug.assert(id.len <= std.math.maxInt(usize));

    if (id.len == 0) {
        return error.InvalidId;
    }
    if (id.len > limits.nip46_message_id_bytes_max) {
        return error.InvalidId;
    }
    if (!std.unicode.utf8ValidateSlice(id)) {
        return error.InvalidId;
    }
}

fn validate_response_common(response: *const Response) Nip46Error!void {
    std.debug.assert(@intFromPtr(response) != 0);
    std.debug.assert(@sizeOf(ResponsePayload) > 0);

    try validate_message_id(response.id);
    if (response.error_text) |text| {
        if (!std.unicode.utf8ValidateSlice(text)) {
            return error.InvalidResponse;
        }
    }
    if (response.error_text == null and response.result == .absent) {
        return error.InvalidResponse;
    }
}

fn response_text_payload(response: *const Response) Nip46Error![]const u8 {
    std.debug.assert(@intFromPtr(response) != 0);
    std.debug.assert(@sizeOf(ResponsePayload) > 0);

    return switch (response.result) {
        .value => |payload| switch (payload) {
            .text => |text| text,
            .relay_list => error.InvalidResponse,
        },
        .absent, .null_result => error.InvalidResponse,
    };
}

fn validate_connect_params(
    params: []const []const u8,
    scratch: std.mem.Allocator,
) Nip46Error!void {
    std.debug.assert(params.len <= limits.nip46_message_params_max);
    std.debug.assert(limits.pubkey_hex_length == 64);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (params.len < 1 or params.len > 3) {
        return error.InvalidRequest;
    }
    _ = parse_lower_hex_32(params[0]) catch return error.InvalidPubkey;
    if (params.len >= 2) {
        try validate_secret(params[1]);
    }
    if (params.len == 3) {
        _ = try parse_permissions_csv(params[2], scratch);
    }
}

fn validate_sign_event_params(
    params: []const []const u8,
    scratch: std.mem.Allocator,
) Nip46Error!void {
    std.debug.assert(params.len <= limits.nip46_message_params_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (params.len != 1) {
        return error.InvalidRequest;
    }
    try validate_unsigned_event_json(params[0], scratch);
}

fn require_zero_params(params: []const []const u8) Nip46Error!void {
    std.debug.assert(params.len <= limits.nip46_message_params_max);
    std.debug.assert(params.len <= std.math.maxInt(usize));

    if (params.len != 0) {
        return error.InvalidRequest;
    }
}

fn validate_pubkey_text_params(params: []const []const u8) Nip46Error!void {
    std.debug.assert(params.len <= limits.nip46_message_params_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (params.len != 2) {
        return error.InvalidRequest;
    }
    _ = parse_lower_hex_32(params[0]) catch return error.InvalidPubkey;
    if (!std.unicode.utf8ValidateSlice(params[1])) {
        return error.InvalidParam;
    }
}

fn validate_response_result(
    result: ResponseResult,
    method: RemoteSigningMethod,
    scratch: std.mem.Allocator,
) Nip46Error!void {
    std.debug.assert(@intFromEnum(method) <= @intFromEnum(RemoteSigningMethod.switch_relays));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    switch (method) {
        .connect => try validate_connect_result(result),
        .sign_event => try validate_sign_event_result(result, scratch),
        .ping => try validate_ping_result(result),
        .get_public_key => try validate_pubkey_result(result),
        .nip04_encrypt, .nip04_decrypt, .nip44_encrypt, .nip44_decrypt => {
            try validate_text_result(result);
        },
        .switch_relays => try validate_switch_relays_result(result),
    }
}

fn validate_connect_result(result: ResponseResult) Nip46Error!void {
    std.debug.assert(@sizeOf(ResponseResult) > 0);
    std.debug.assert(!@inComptime());

    switch (result) {
        .text => |text| if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidResponse,
        .relay_list => return error.InvalidResponse,
    }
}

fn validate_sign_event_result(
    result: ResponseResult,
    scratch: std.mem.Allocator,
) Nip46Error!void {
    std.debug.assert(@sizeOf(ResponseResult) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    switch (result) {
        .text => |text| {
            _ = nip01_event.event_parse_json(text, scratch) catch return error.InvalidSignedEvent;
        },
        .relay_list => return error.InvalidResponse,
    }
}

fn validate_ping_result(result: ResponseResult) Nip46Error!void {
    std.debug.assert(@sizeOf(ResponseResult) > 0);
    std.debug.assert(!@inComptime());

    switch (result) {
        .text => |text| {
            if (!std.mem.eql(u8, text, "pong")) return error.InvalidResponse;
        },
        .relay_list => return error.InvalidResponse,
    }
}

fn validate_pubkey_result(result: ResponseResult) Nip46Error!void {
    std.debug.assert(@sizeOf(ResponseResult) > 0);
    std.debug.assert(limits.pubkey_hex_length == 64);

    switch (result) {
        .text => |text| _ = parse_lower_hex_32(text) catch return error.InvalidPubkey,
        .relay_list => return error.InvalidResponse,
    }
}

fn validate_text_result(result: ResponseResult) Nip46Error!void {
    std.debug.assert(@sizeOf(ResponseResult) > 0);
    std.debug.assert(!@inComptime());

    switch (result) {
        .text => |text| if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidResponse,
        .relay_list => return error.InvalidResponse,
    }
}

fn validate_switch_relays_result(result: ResponseResult) Nip46Error!void {
    std.debug.assert(@sizeOf(ResponseResult) > 0);
    std.debug.assert(!@inComptime());

    switch (result) {
        .text => return error.InvalidResponse,
        .relay_list => |relays| {
            var index: usize = 0;
            while (index < relays.len) : (index += 1) {
                _ = parse_relay_url(relays[index]) catch return error.InvalidRelayUrl;
            }
        },
    }
}

fn parse_uri_parts(input: []const u8) Nip46Error!ParsedUriParts {
    std.debug.assert(input.len <= limits.nip46_uri_bytes_max);
    std.debug.assert(input.len <= std.math.maxInt(usize));

    if (input.len == 0 or input.len > limits.nip46_uri_bytes_max) {
        return error.InvalidUri;
    }

    const scheme_end = std.mem.indexOf(u8, input, "://") orelse return error.InvalidUri;
    if (scheme_end == 0) {
        return error.InvalidUri;
    }
    const scheme = input[0..scheme_end];
    const rest = input[scheme_end + 3 ..];
    if (rest.len == 0) {
        return error.InvalidUri;
    }

    const query_index = std.mem.indexOfScalar(u8, rest, '?');
    const authority = if (query_index) |index| rest[0..index] else rest;
    if (authority.len == 0 or std.mem.indexOfScalar(u8, authority, '/') != null) {
        return error.InvalidUri;
    }
    const query = if (query_index) |index| rest[index + 1 ..] else null;
    return .{ .scheme = scheme, .authority = authority, .query = query };
}

fn scheme_is(left: []const u8, right: []const u8) bool {
    std.debug.assert(left.len > 0);
    std.debug.assert(right.len > 0);

    return std.ascii.eqlIgnoreCase(left, right);
}

fn parse_bunker_uri(
    authority: []const u8,
    query: ?[]const u8,
    scratch: std.mem.Allocator,
) Nip46Error!BunkerUri {
    std.debug.assert(authority.len == limits.pubkey_hex_length);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const pubkey = parse_lower_hex_32(authority) catch return error.InvalidPubkey;
    var relay_buf: [limits.nip46_relays_max][]const u8 = undefined;
    var relay_count: u8 = 0;
    var secret: ?[]const u8 = null;

    if (query) |raw_query| {
        try parse_uri_query(raw_query, scratch, &relay_buf, &relay_count, &secret, null);
    }
    if (relay_count == 0) {
        return error.MissingRelay;
    }
    const relays = try duplicate_relay_slice(relay_buf[0..relay_count], scratch);
    return .{ .remote_signer_pubkey = pubkey, .relays = relays, .secret = secret };
}

fn parse_client_uri(
    authority: []const u8,
    query: ?[]const u8,
    scratch: std.mem.Allocator,
) Nip46Error!ClientUri {
    std.debug.assert(authority.len == limits.pubkey_hex_length);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const pubkey = parse_lower_hex_32(authority) catch return error.InvalidPubkey;
    var relay_buf: [limits.nip46_relays_max][]const u8 = undefined;
    var relay_count: u8 = 0;
    var secret: ?[]const u8 = null;
    var metadata = ClientMetadata{};

    const raw_query = query orelse return error.InvalidUri;
    try parse_uri_query(raw_query, scratch, &relay_buf, &relay_count, &secret, &metadata);
    if (relay_count == 0) {
        return error.MissingRelay;
    }
    const resolved_secret = secret orelse return error.MissingSecret;
    const relays = try duplicate_relay_slice(relay_buf[0..relay_count], scratch);
    return .{
        .client_pubkey = pubkey,
        .relays = relays,
        .secret = resolved_secret,
        .permissions = metadata.permissions,
        .name = metadata.name,
        .url = metadata.url,
        .image = metadata.image,
    };
}

const ClientMetadata = struct {
    permissions: []const Permission = &.{},
    name: ?[]const u8 = null,
    url: ?[]const u8 = null,
    image: ?[]const u8 = null,
};

fn parse_uri_query(
    raw_query: []const u8,
    scratch: std.mem.Allocator,
    relay_buf: *[limits.nip46_relays_max][]const u8,
    relay_count: *u8,
    secret: *?[]const u8,
    metadata: ?*ClientMetadata,
) Nip46Error!void {
    std.debug.assert(raw_query.len <= limits.nip46_uri_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var pair_iter = std.mem.splitScalar(u8, raw_query, '&');
    while (pair_iter.next()) |pair| {
        if (pair.len == 0) {
            continue;
        }
        const separator = std.mem.indexOfScalar(u8, pair, '=') orelse return error.InvalidUri;
        const key = pair[0..separator];
        const value = pair[separator + 1 ..];
        try apply_query_pair(key, value, scratch, relay_buf, relay_count, secret, metadata);
    }
}

fn apply_query_pair(
    raw_key: []const u8,
    raw_value: []const u8,
    scratch: std.mem.Allocator,
    relay_buf: *[limits.nip46_relays_max][]const u8,
    relay_count: *u8,
    secret: *?[]const u8,
    metadata: ?*ClientMetadata,
) Nip46Error!void {
    std.debug.assert(raw_key.len <= limits.tag_item_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const key = try query_decode_component(raw_key, false, scratch);
    const value = try query_decode_component(raw_value, true, scratch);
    if (std.mem.eql(u8, key, "relay")) {
        try append_query_relay(value, relay_buf, relay_count);
        return;
    }
    if (std.mem.eql(u8, key, "secret")) {
        if (secret.* != null) return error.InvalidUri;
        try validate_secret(value);
        secret.* = value;
        return;
    }
    if (metadata == null) {
        return;
    }
    if (std.mem.eql(u8, key, "perms")) {
        metadata.?.permissions = try parse_permissions_csv(value, scratch);
        return;
    }
    if (std.mem.eql(u8, key, "name")) {
        try validate_name(value);
        metadata.?.name = value;
        return;
    }
    if (std.mem.eql(u8, key, "url")) {
        _ = parse_url(value) catch return error.InvalidUrl;
        metadata.?.url = value;
        return;
    }
    if (std.mem.eql(u8, key, "image")) {
        _ = parse_url(value) catch return error.InvalidImage;
        metadata.?.image = value;
    }
}

fn append_query_relay(
    relay: []const u8,
    relay_buf: *[limits.nip46_relays_max][]const u8,
    relay_count: *u8,
) Nip46Error!void {
    std.debug.assert(relay_count.* <= limits.nip46_relays_max);
    std.debug.assert(relay.len <= limits.tag_item_bytes_max);

    _ = parse_relay_url(relay) catch return error.InvalidRelayUrl;
    if (relay_count.* == limits.nip46_relays_max) {
        return error.TooManyRelays;
    }
    relay_buf[relay_count.*] = relay;
    relay_count.* += 1;
}

fn parse_permissions_csv(
    perms_text: []const u8,
    scratch: std.mem.Allocator,
) Nip46Error![]const Permission {
    std.debug.assert(perms_text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (perms_text.len == 0) {
        return error.InvalidPermission;
    }

    var count: u8 = 0;
    var splitter = std.mem.splitScalar(u8, perms_text, ',');
    while (splitter.next()) |token| {
        if (token.len == 0) return error.InvalidPermission;
        if (count == limits.nip46_permissions_max) return error.TooManyPermissions;
        count += 1;
    }

    const permissions = scratch.alloc(Permission, count) catch return error.OutOfMemory;
    var index: usize = 0;
    splitter = std.mem.splitScalar(u8, perms_text, ',');
    while (splitter.next()) |token| {
        permissions[index] = try permission_parse(token);
        index += 1;
    }
    return permissions;
}

fn duplicate_relay_slice(
    input: []const []const u8,
    scratch: std.mem.Allocator,
) Nip46Error![]const []const u8 {
    std.debug.assert(input.len <= limits.nip46_relays_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const output = scratch.alloc([]const u8, input.len) catch return error.OutOfMemory;
    @memcpy(output, input);
    return output;
}

fn query_decode_component(
    text: []const u8,
    plus_as_space: bool,
    scratch: std.mem.Allocator,
) Nip46Error![]const u8 {
    std.debug.assert(text.len <= limits.nip46_uri_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const out = scratch.alloc(u8, text.len) catch return error.OutOfMemory;
    var read_index: usize = 0;
    var write_index: usize = 0;
    while (read_index < text.len) : (read_index += 1) {
        const byte = text[read_index];
        if (plus_as_space and byte == '+') {
            out[write_index] = ' ';
            write_index += 1;
            continue;
        }
        if (byte != '%') {
            out[write_index] = byte;
            write_index += 1;
            continue;
        }
        if (read_index + 2 >= text.len) {
            return error.InvalidUri;
        }
        const decoded = decode_hex_byte(text[read_index + 1], text[read_index + 2]) catch {
            return error.InvalidUri;
        };
        out[write_index] = decoded;
        write_index += 1;
        read_index += 2;
    }
    return out[0..write_index];
}

fn decode_hex_byte(high: u8, low: u8) error{InvalidHex}!u8 {
    std.debug.assert(high <= 255);
    std.debug.assert(low <= 255);

    const hi = decode_hex_nibble(high) catch return error.InvalidHex;
    const lo = decode_hex_nibble(low) catch return error.InvalidHex;
    return (hi << 4) | lo;
}

fn decode_hex_nibble(byte: u8) error{InvalidHex}!u8 {
    std.debug.assert(byte <= 255);
    std.debug.assert(@sizeOf(u8) == 1);

    if (byte >= '0' and byte <= '9') return byte - '0';
    if (byte >= 'a' and byte <= 'f') return byte - 'a' + 10;
    if (byte >= 'A' and byte <= 'F') return byte - 'A' + 10;
    return error.InvalidHex;
}

fn write_request_json(writer: anytype, request: Request) Nip46Error!void {
    std.debug.assert(request.params.len <= limits.nip46_message_params_max);
    std.debug.assert(request.id.len <= limits.nip46_message_id_bytes_max);

    try validate_message_id(request.id);
    try write_all(writer, "{\"id\":");
    try write_json_string(writer, request.id);
    try write_all(writer, ",\"method\":");
    try write_json_string(writer, method_text(request.method));
    try write_all(writer, ",\"params\":[");
    try write_json_string_array(writer, request.params);
    try write_all(writer, "]}");
}

fn write_response_json(writer: anytype, response: Response) Nip46Error!void {
    std.debug.assert(response.id.len <= limits.nip46_message_id_bytes_max);
    std.debug.assert(@sizeOf(Response) > 0);

    try validate_message_id(response.id);
    try write_all(writer, "{\"id\":");
    try write_json_string(writer, response.id);
    switch (response.result) {
        .absent => {},
        .null_result => try write_all(writer, ",\"result\":null"),
        .value => |result| {
            try write_all(writer, ",\"result\":");
            try write_result_json(writer, result);
        },
    }
    if (response.error_text) |text| {
        try write_all(writer, ",\"error\":");
        try write_json_string(writer, text);
    }
    try write_all(writer, "}");
}

fn write_result_json(writer: anytype, result: ResponseResult) Nip46Error!void {
    std.debug.assert(@sizeOf(ResponseResult) > 0);
    std.debug.assert(!@inComptime());

    switch (result) {
        .text => |text| try write_json_string(writer, text),
        .relay_list => |relays| {
            try write_byte(writer, '[');
            try write_json_string_array(writer, relays);
            try write_byte(writer, ']');
        },
    }
}

fn write_json_string_array(writer: anytype, values: []const []const u8) Nip46Error!void {
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(values.len <= std.math.maxInt(usize));

    var index: usize = 0;
    while (index < values.len) : (index += 1) {
        if (index != 0) try write_byte(writer, ',');
        try write_json_string(writer, values[index]);
    }
}

fn write_json_string(writer: anytype, value: []const u8) Nip46Error!void {
    std.debug.assert(value.len <= limits.nip46_message_json_bytes_max);
    std.debug.assert(value.len <= std.math.maxInt(usize));

    try write_byte(writer, '"');
    for (value) |byte| {
        try write_json_escaped_byte(writer, byte);
    }
    try write_byte(writer, '"');
}

fn write_json_escaped_byte(writer: anytype, byte: u8) Nip46Error!void {
    std.debug.assert(byte <= 255);
    std.debug.assert(@sizeOf(u8) == 1);

    switch (byte) {
        '"' => try write_all(writer, "\\\""),
        '\\' => try write_all(writer, "\\\\"),
        '\n' => try write_all(writer, "\\n"),
        '\r' => try write_all(writer, "\\r"),
        '\t' => try write_all(writer, "\\t"),
        0x08 => try write_all(writer, "\\b"),
        0x0c => try write_all(writer, "\\f"),
        else => {
            if (byte < 0x20) {
                try write_print(writer, "\\u00{X:0>2}", .{byte});
                return;
            }
            try write_byte(writer, byte);
        },
    }
}

fn write_bunker_uri(writer: anytype, bunker: BunkerUri) Nip46Error!void {
    std.debug.assert(bunker.relays.len <= limits.nip46_relays_max);
    std.debug.assert(@sizeOf(BunkerUri) > 0);

    const hex = std.fmt.bytesToHex(bunker.remote_signer_pubkey, .lower);
    try write_print(writer, "bunker://{s}", .{hex});
    try write_uri_query(writer, bunker.relays, bunker.secret, null);
}

fn write_client_uri(writer: anytype, client: ClientUri) Nip46Error!void {
    std.debug.assert(client.relays.len <= limits.nip46_relays_max);
    std.debug.assert(client.permissions.len <= limits.nip46_permissions_max);

    const hex = std.fmt.bytesToHex(client.client_pubkey, .lower);
    try write_print(writer, "nostrconnect://{s}", .{hex});
    const metadata = ClientMetadata{
        .permissions = client.permissions,
        .name = client.name,
        .url = client.url,
        .image = client.image,
    };
    try write_uri_query(writer, client.relays, client.secret, metadata);
}

fn write_uri_query(
    writer: anytype,
    relays: []const []const u8,
    secret: ?[]const u8,
    metadata: ?ClientMetadata,
) Nip46Error!void {
    std.debug.assert(relays.len <= limits.nip46_relays_max);
    std.debug.assert(@sizeOf(ClientMetadata) > 0);

    var wrote_query = false;
    var index: usize = 0;
    while (index < relays.len) : (index += 1) {
        try write_query_pair(writer, &wrote_query, "relay", relays[index]);
    }
    if (secret) |text| try write_query_pair(writer, &wrote_query, "secret", text);
    if (metadata) |meta| {
        if (meta.permissions.len != 0) {
            var perms_buffer: [limits.tag_item_bytes_max]u8 = undefined;
            const perms_text = try join_permissions(perms_buffer[0..], meta.permissions);
            try write_query_pair(writer, &wrote_query, "perms", perms_text);
        }
        if (meta.name) |name| try write_query_pair(writer, &wrote_query, "name", name);
        if (meta.url) |url| try write_query_pair(writer, &wrote_query, "url", url);
        if (meta.image) |image| try write_query_pair(writer, &wrote_query, "image", image);
    }
}

fn write_query_pair(
    writer: anytype,
    wrote_query: *bool,
    key: []const u8,
    value: []const u8,
) Nip46Error!void {
    std.debug.assert(key.len > 0);
    std.debug.assert(@intFromPtr(wrote_query) != 0);

    if (!wrote_query.*) {
        try write_byte(writer, '?');
        wrote_query.* = true;
    } else {
        try write_byte(writer, '&');
    }
    try write_all(writer, key);
    try write_byte(writer, '=');
    try write_percent_encoded(writer, value);
}

fn join_permissions(output: []u8, permissions: []const Permission) Nip46Error![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(permissions.len <= limits.nip46_permissions_max);

    var used: usize = 0;
    var index: usize = 0;
    while (index < permissions.len) : (index += 1) {
        if (index != 0) {
            if (used == output.len) return error.BufferTooSmall;
            output[used] = ',';
            used += 1;
        }
        const written = try permission_format(output[used..], permissions[index]);
        used += written.len;
    }
    return output[0..used];
}

fn write_percent_encoded(writer: anytype, text: []const u8) Nip46Error!void {
    std.debug.assert(text.len <= limits.nip46_uri_bytes_max);
    std.debug.assert(text.len <= std.math.maxInt(usize));

    for (text) |byte| {
        if (is_unreserved_query_byte(byte)) {
            try write_byte(writer, byte);
            continue;
        }
        if (byte == ' ') {
            try write_byte(writer, '+');
            continue;
        }
        var encoded: [3]u8 = undefined;
        encoded[0] = '%';
        encoded[1] = hex_upper(byte >> 4);
        encoded[2] = hex_upper(byte & 0x0f);
        try write_all(writer, encoded[0..]);
    }
}

fn write_all(writer: anytype, text: []const u8) Nip46Error!void {
    std.debug.assert(text.len <= limits.nip46_uri_bytes_max);
    std.debug.assert(text.len <= std.math.maxInt(usize));

    writer.writeAll(text) catch return error.BufferTooSmall;
}

fn write_byte(writer: anytype, byte: u8) Nip46Error!void {
    std.debug.assert(byte <= 255);
    std.debug.assert(@sizeOf(u8) == 1);

    writer.writeByte(byte) catch return error.BufferTooSmall;
}

fn write_print(writer: anytype, comptime fmt: []const u8, args: anytype) Nip46Error!void {
    std.debug.assert(fmt.len > 0);
    std.debug.assert(fmt.len <= limits.nip46_uri_bytes_max);

    writer.print(fmt, args) catch return error.BufferTooSmall;
}

fn is_unreserved_query_byte(byte: u8) bool {
    std.debug.assert(byte <= 255);
    std.debug.assert(@sizeOf(u8) == 1);

    if (byte >= 'a' and byte <= 'z') return true;
    if (byte >= 'A' and byte <= 'Z') return true;
    if (byte >= '0' and byte <= '9') return true;
    return switch (byte) {
        '-', '.', '_', '~', ':', '/', ',' => true,
        else => false,
    };
}

fn hex_upper(nibble: u8) u8 {
    std.debug.assert(nibble < 16);
    std.debug.assert(@sizeOf(u8) == 1);

    if (nibble < 10) return nibble + '0';
    return nibble - 10 + 'A';
}

fn tag_is_p(tag: nip01_event.EventTag) bool {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len <= std.math.maxInt(usize));

    if (tag.items.len == 0) {
        return false;
    }
    return std.mem.eql(u8, tag.items[0], "p");
}

fn parse_target_pubkey(tag: nip01_event.EventTag) Nip46Error![32]u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (tag.items.len < 2 or tag.items.len > 2) {
        return error.InvalidTargetPubkey;
    }
    return parse_lower_hex_32(tag.items[1]) catch error.InvalidTargetPubkey;
}

fn validate_secret(secret: []const u8) Nip46Error!void {
    std.debug.assert(secret.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.nip46_secret_bytes_max > 0);

    if (secret.len == 0 or secret.len > limits.nip46_secret_bytes_max) {
        return error.InvalidSecret;
    }
    if (!std.unicode.utf8ValidateSlice(secret)) {
        return error.InvalidSecret;
    }
}

fn validate_name(name: []const u8) Nip46Error!void {
    std.debug.assert(name.len <= limits.tag_item_bytes_max);
    std.debug.assert(name.len <= std.math.maxInt(usize));

    if (name.len == 0) return error.InvalidName;
    if (!std.unicode.utf8ValidateSlice(name)) return error.InvalidName;
}

fn validate_unsigned_event_json(
    input: []const u8,
    scratch: std.mem.Allocator,
) Nip46Error!void {
    std.debug.assert(input.len <= limits.event_json_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (input.len == 0 or input.len > limits.event_json_max) {
        return error.InvalidUnsignedEvent;
    }
    if (!std.unicode.utf8ValidateSlice(input)) {
        return error.InvalidUnsignedEvent;
    }

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        parse_arena.allocator(),
        input,
        .{},
    ) catch return error.InvalidUnsignedEvent;
    if (root != .object) {
        return error.InvalidUnsignedEvent;
    }
    try validate_unsigned_event_object(root.object);
}

fn validate_unsigned_event_object(object: std.json.ObjectMap) Nip46Error!void {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(limits.kind_max == std.math.maxInt(u16));

    var has_kind = false;
    var has_created_at = false;
    var has_content = false;
    var has_tags = false;
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "kind")) {
            try validate_unsigned_kind(value);
            has_kind = true;
            continue;
        }
        if (std.mem.eql(u8, key, "created_at")) {
            try validate_unsigned_created_at(value);
            has_created_at = true;
            continue;
        }
        if (std.mem.eql(u8, key, "content")) {
            try validate_unsigned_content(value);
            has_content = true;
            continue;
        }
        if (std.mem.eql(u8, key, "tags")) {
            try validate_unsigned_tags(value);
            has_tags = true;
        }
    }
    if (!has_kind or !has_created_at or !has_content or !has_tags) {
        return error.InvalidUnsignedEvent;
    }
}

fn validate_unsigned_kind(value: std.json.Value) Nip46Error!void {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(limits.kind_max <= std.math.maxInt(u32));

    if (value != .integer or value.integer < 0) {
        return error.InvalidUnsignedEvent;
    }
    if (@as(u64, @intCast(value.integer)) > limits.kind_max) {
        return error.InvalidUnsignedEvent;
    }
}

fn validate_unsigned_created_at(value: std.json.Value) Nip46Error!void {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(@sizeOf(u64) == 8);

    if (value != .integer or value.integer < 0) {
        return error.InvalidUnsignedEvent;
    }
}

fn validate_unsigned_content(value: std.json.Value) Nip46Error!void {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(limits.content_bytes_max > 0);

    if (value != .string) {
        return error.InvalidUnsignedEvent;
    }
    if (value.string.len > limits.content_bytes_max) {
        return error.InvalidUnsignedEvent;
    }
    if (!std.unicode.utf8ValidateSlice(value.string)) {
        return error.InvalidUnsignedEvent;
    }
}

fn validate_unsigned_tags(value: std.json.Value) Nip46Error!void {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(limits.tags_max > 0);

    if (value != .array) {
        return error.InvalidUnsignedEvent;
    }
    if (value.array.items.len > limits.tags_max) {
        return error.InvalidUnsignedEvent;
    }
    var tag_index: usize = 0;
    while (tag_index < value.array.items.len) : (tag_index += 1) {
        const tag = value.array.items[tag_index];
        if (tag != .array) return error.InvalidUnsignedEvent;
        if (tag.array.items.len > limits.tag_items_max) return error.InvalidUnsignedEvent;
        var item_index: usize = 0;
        while (item_index < tag.array.items.len) : (item_index += 1) {
            const item = tag.array.items[item_index];
            if (item != .string) return error.InvalidUnsignedEvent;
            if (item.string.len > limits.tag_item_bytes_max) return error.InvalidUnsignedEvent;
            if (!std.unicode.utf8ValidateSlice(item.string)) return error.InvalidUnsignedEvent;
        }
    }
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    var output: [32]u8 = undefined;
    if (text.len != limits.pubkey_hex_length) {
        return error.InvalidHex;
    }
    for (text) |byte| {
        const is_digit = byte >= '0' and byte <= '9';
        const is_hex = byte >= 'a' and byte <= 'f';
        if (is_digit or is_hex) {
            continue;
        }
        return error.InvalidHex;
    }
    _ = std.fmt.hexToBytes(&output, text) catch return error.InvalidHex;
    return output;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= std.math.maxInt(usize));

    if (text.len == 0) return error.InvalidUrl;
    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (parsed.scheme.len == 0) return error.InvalidUrl;
    if (parsed.host == null) return error.InvalidUrl;
    return text;
}

fn parse_relay_url(text: []const u8) error{InvalidRelayUrl}!relay_origin.WebsocketOrigin {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@sizeOf(relay_origin.WebsocketOrigin) > 0);

    if (text.len == 0) return error.InvalidRelayUrl;
    for (text) |byte| {
        if (byte <= 0x20 or byte == '\\') return error.InvalidRelayUrl;
    }
    const origin = relay_origin.parse_websocket_origin(text) orelse {
        return error.InvalidRelayUrl;
    };
    if (origin.port == 0) return error.InvalidRelayUrl;
    return origin;
}

test "method and permission parsing cover current command set" {
    try std.testing.expectEqual(RemoteSigningMethod.connect, try method_parse("connect"));
    try std.testing.expectEqual(
        RemoteSigningMethod.switch_relays,
        try method_parse("switch_relays"),
    );

    const connect_permission = try permission_parse("connect");
    try std.testing.expectEqual(RemoteSigningMethod.connect, connect_permission.method);
    try std.testing.expect(connect_permission.scope == .none);

    const sign_permission = try permission_parse("sign_event:13");
    try std.testing.expectEqual(RemoteSigningMethod.sign_event, sign_permission.method);
    try std.testing.expectEqual(@as(u32, 13), sign_permission.scope.event_kind);

    const raw_permission = try permission_parse("nip44_encrypt:dm");
    try std.testing.expectEqual(RemoteSigningMethod.nip44_encrypt, raw_permission.method);
    try std.testing.expectEqualStrings("dm", raw_permission.scope.raw);
}

test "permission formatting is deterministic" {
    var buffer: [64]u8 = undefined;

    const plain = try permission_format(
        buffer[0..],
        .{ .method = .get_public_key },
    );
    try std.testing.expectEqualStrings("get_public_key", plain);

    const scoped = try permission_format(
        buffer[0..],
        .{ .method = .sign_event, .scope = .{ .event_kind = 1_059 } },
    );
    try std.testing.expectEqualStrings("sign_event:1059", scoped);
}

test "message parse and serialize roundtrip request and response" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const request_json =
        "{\"id\":\"42\",\"method\":\"connect\",\"params\":[\"" ++
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "\",\"secret\"]}";
    const request_message = try message_parse_json(request_json, arena.allocator());
    try std.testing.expect(request_message == .request);
    try std.testing.expectEqual(@as(usize, 2), request_message.request.params.len);

    var request_output: [256]u8 = undefined;
    const request_encoded = try message_serialize_json(request_output[0..], request_message);
    try std.testing.expectEqualStrings(request_json, request_encoded);

    const response_json =
        "{\"id\":\"42\",\"result\":[\"wss://relay.one\",\"wss://relay.two\"],\"error\":null}";
    const response_message = try message_parse_json(response_json, arena.allocator());
    try std.testing.expect(response_message == .response);
    try std.testing.expect(response_message.response.result == .value);
    try std.testing.expect(response_message.response.result.value == .relay_list);

    var response_output: [256]u8 = undefined;
    const response_encoded = try message_serialize_json(response_output[0..], response_message);
    try std.testing.expectEqualStrings(
        "{\"id\":\"42\",\"result\":[\"wss://relay.one\",\"wss://relay.two\"]}",
        response_encoded,
    );
}

test "request validation enforces current NIP-46 method contracts" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const connect = Request{
        .id = "1",
        .method = .connect,
        .params = &.{
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "secret",
            "sign_event:1,ping",
        },
    };
    try request_validate(&connect, arena.allocator());

    const bad_ping = Request{
        .id = "1",
        .method = .ping,
        .params = &.{"extra"},
    };
    try std.testing.expectError(error.InvalidRequest, request_validate(&bad_ping, arena.allocator()));
}

test "response validation covers ping and signed-event results" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const ping_ok = Response{
        .id = "a",
        .result = .{ .value = .{ .text = "pong" } },
    };
    try response_validate(&ping_ok, .ping, arena.allocator());

    const sign_ok = Response{
        .id = "b",
        .result = .{ .value = .{
            .text =
                "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
                "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
                "\"created_at\":1,\"kind\":1,\"tags\":[],\"content\":\"hi\"}",
        } },
    };
    try std.testing.expectError(
        error.InvalidSignedEvent,
        response_validate(&sign_ok, .sign_event, arena.allocator()),
    );
}

test "switch_relays null result is preserved and valid" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const response_json = "{\"id\":\"42\",\"result\":null}";
    const message = try message_parse_json(response_json, arena.allocator());
    try std.testing.expect(message == .response);
    try std.testing.expect(message.response.result == .null_result);
    try response_validate(&message.response, .switch_relays, arena.allocator());

    var output: [128]u8 = undefined;
    const encoded = try message_serialize_json(output[0..], message);
    try std.testing.expectEqualStrings(response_json, encoded);
}

test "typed response helpers expose current NIP-46 result shapes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const connect_ack = Response{
        .id = "connect-1",
        .result = .{ .value = .{ .text = "ack" } },
    };
    const connect_result = try response_result_connect(&connect_ack);
    try std.testing.expect(connect_result == .ack);

    const pubkey_response = Response{
        .id = "pubkey-1",
        .result = .{ .value = .{
            .text = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        } },
    };
    const pubkey = try response_result_get_public_key(&pubkey_response);
    try std.testing.expectEqualStrings(
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        &std.fmt.bytesToHex(pubkey, .lower),
    );

    const sign_response = Response{
        .id = "sign-1",
        .result = .{ .value = .{
            .text =
                "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
                "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
                "\"created_at\":1,\"kind\":1,\"tags\":[],\"content\":\"ok\"," ++
                "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
                "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}",
        } },
    };
    const signed_event = try response_result_sign_event(&sign_response, arena.allocator());
    try std.testing.expectEqual(@as(u32, 1), signed_event.kind);
    try std.testing.expectEqualStrings("ok", signed_event.content);

    const relay_response = Response{
        .id = "relay-1",
        .result = .{ .value = .{ .relay_list = &.{"wss://relay.one"} } },
    };
    const relays = (try response_result_switch_relays(&relay_response)).?;
    try std.testing.expectEqual(@as(usize, 1), relays.len);
    try std.testing.expectEqualStrings("wss://relay.one", relays[0]);

    const null_response = Response{
        .id = "relay-2",
        .result = .null_result,
    };
    try std.testing.expect((try response_result_switch_relays(&null_response)) == null);
}

test "uri parse and serialize follow current bunker and nostrconnect forms" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bunker_text =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two&secret=abc";
    const bunker = try uri_parse(bunker_text, arena.allocator());
    try std.testing.expect(bunker == .bunker);
    try std.testing.expectEqual(@as(usize, 2), bunker.bunker.relays.len);

    var bunker_output: [512]u8 = undefined;
    const bunker_encoded = try uri_serialize(bunker_output[0..], bunker);
    try std.testing.expectEqualStrings(
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
            "?relay=wss://relay.one&relay=wss://relay.two&secret=abc",
        bunker_encoded,
    );

    const client_text =
        "nostrconnect://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=s3cr3t&perms=sign_event%3A1%2Cping&name=My+Client" ++
        "&url=https%3A%2F%2Fclient.example&image=https%3A%2F%2Fclient.example%2Fapp.png";
    const client = try uri_parse(client_text, arena.allocator());
    try std.testing.expect(client == .client);
    try std.testing.expectEqualStrings("My Client", client.client.name.?);
    try std.testing.expectEqual(@as(usize, 2), client.client.permissions.len);
}

test "uri parsing rejects missing required relay and secret" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.MissingRelay,
        uri_parse(
            "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            arena.allocator(),
        ),
    );
    try std.testing.expectError(
        error.MissingSecret,
        uri_parse(
            "nostrconnect://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
                "?relay=wss%3A%2F%2Frelay.one",
            arena.allocator(),
        ),
    );
}

test "unsigned sign_event payload validation requires bounded event shape" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const good =
        "{\"kind\":1,\"content\":\"hello\",\"tags\":[[\"p\",\"" ++
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "\"]],\"created_at\":1}";
    try validate_unsigned_event_json(good, arena.allocator());

    const bad =
        "{\"kind\":70000,\"content\":\"hello\",\"tags\":[],\"created_at\":1}";
    try std.testing.expectError(
        error.InvalidUnsignedEvent,
        validate_unsigned_event_json(bad, arena.allocator()),
    );
}

test "envelope validation requires exact single p tag and NIP-44 payload framing" {
    const p_tag = [_][]const u8{
        "p",
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    };
    const tags = [_]nip01_event.EventTag{.{ .items = p_tag[0..] }};
    const event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = remote_signing_event_kind,
        .created_at = 0,
        .content = "%%%not-base64%%%",
        .tags = tags[0..],
    };
    var scratch: [limits.nip44_payload_decoded_max_bytes]u8 = undefined;
    try std.testing.expectError(
        error.InvalidEncryptedContent,
        envelope_validate(&event, null, scratch[0..]),
    );
}

test "message parsing rejects mixed request and response fields" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const mixed = "{\"id\":\"1\",\"method\":\"ping\",\"params\":[],\"result\":\"pong\"}";
    try std.testing.expectError(error.InvalidMessage, message_parse_json(mixed, arena.allocator()));
}

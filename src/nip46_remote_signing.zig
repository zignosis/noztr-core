const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const nip44 = @import("nip44.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const relay_origin = @import("internal/relay_origin.zig");
const websocket_relay_url = @import("internal/websocket_relay_url.zig");

pub const remote_signing_event_kind: u32 = 24_133;

pub const RemoteSigningError = error{
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
    InvalidDiscoveryDocument,
    InvalidDiscoveryEvent,
    MissingDiscoveryPubkey,
    MissingDiscoveryKind,
    DuplicateDiscoveryKind,
    InvalidNostrConnectUrl,
    OutOfMemory,
};

pub const Method = enum {
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

pub const Scope = union(enum) {
    none,
    event_kind: u32,
    raw: []const u8,
};

pub const Permission = struct {
    method: Method,
    scope: Scope = .none,
};

/// Typed `connect` request parameters.
pub const Connect = struct {
    remote_signer_pubkey: [32]u8,
    secret: ?[]const u8 = null,
    requested_permissions: []const Permission = &.{},
};

/// Typed pubkey-plus-text request parameters.
pub const PubkeyText = struct {
    pubkey: [32]u8,
    text: []const u8,
};

pub const Request = struct {
    id: []const u8,
    method: Method,
    params: []const []const u8,
};

pub const RequestBuilder = struct {
    params: [3][]const u8 = undefined,
    pubkey_hex: [limits.pubkey_hex_length]u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    param_count: u8 = 0,

    /// Returns the built request view backed by this buffer.
    pub fn as_request(self: *const RequestBuilder, id: []const u8, method: Method) Request {
        std.debug.assert(self.param_count <= self.params.len);
        std.debug.assert(id.len <= limits.nip46_message_id_bytes_max);

        return .{
            .id = id,
            .method = method,
            .params = self.params[0..self.param_count],
        };
    }
};

pub const Result = union(enum) {
    absent,
    null_result,
    text: []const u8,
    relays: []const []const u8,
};

pub const Response = struct {
    id: []const u8,
    result: Result = .absent,
    error_text: ?[]const u8 = null,
};

/// Typed `connect` response outcome.
pub const ConnectResult = union(enum) {
    ack,
    secret_echo: []const u8,
};

/// Typed request view over the bounded NIP-46 method set.
pub const TypedRequest = union(enum) {
    connect: Connect,
    sign_event_json: []const u8,
    ping,
    get_public_key,
    nip04_encrypt: PubkeyText,
    nip04_decrypt: PubkeyText,
    nip44_encrypt: PubkeyText,
    nip44_decrypt: PubkeyText,
    switch_relays,
};

pub const Message = union(enum) {
    request: Request,
    response: Response,
};

pub const Bunker = struct {
    remote_signer_pubkey: [32]u8,
    relays: []const []const u8,
    secret: ?[]const u8 = null,
};

pub const Client = struct {
    client_pubkey: [32]u8,
    relays: []const []const u8,
    secret: []const u8,
    permissions: []const Permission = &.{},
    name: ?[]const u8 = null,
    url: ?[]const u8 = null,
    image: ?[]const u8 = null,
};

pub const Uri = union(enum) {
    bunker: Bunker,
    client: Client,
};

pub const Discovery = struct {
    app_pubkey: [32]u8,
    relays: []const []const u8 = &.{},
    nostrconnect_url: ?[]const u8 = null,
};

const nostrconnect_url_placeholder = "<nostrconnect>";

pub fn method_parse(text: []const u8) RemoteSigningError!Method {
    std.debug.assert(@sizeOf(Method) > 0);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidMethod;

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

pub fn method_text(method: Method) []const u8 {
    std.debug.assert(@intFromEnum(method) <= @intFromEnum(Method.switch_relays));
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

pub fn permission_parse(text: []const u8) RemoteSigningError!Permission {
    std.debug.assert(@sizeOf(Permission) > 0);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    const colon = std.mem.indexOfScalar(u8, text, ':');
    if (colon == null) {
        return .{ .method = try method_parse(text) };
    }
    if (text.len > limits.tag_item_bytes_max) return error.InvalidPermission;

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

pub fn permission_format(output: []u8, permission: Permission) RemoteSigningError![]const u8 {
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

pub fn message_parse_json(input: []const u8, scratch: std.mem.Allocator) RemoteSigningError!Message {
    std.debug.assert(input.len <= std.math.maxInt(usize));
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

pub fn message_serialize_json(output: []u8, message: Message) RemoteSigningError![]const u8 {
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

pub fn request_validate(request: *const Request, scratch: std.mem.Allocator) RemoteSigningError!void {
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

/// Parse a validated request into typed method-specific parameters.
pub fn request_parse_typed(
    request: *const Request,
    scratch: std.mem.Allocator,
) RemoteSigningError!TypedRequest {
    std.debug.assert(@intFromPtr(request) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    try request_validate(request, scratch);
    return switch (request.method) {
        .connect => .{ .connect = try parse_typed_connect_request(request.params, scratch) },
        .sign_event => .{ .sign_event_json = request.params[0] },
        .ping => .ping,
        .get_public_key => .get_public_key,
        .nip04_encrypt => .{ .nip04_encrypt = try parse_pubkey_text_request(request.params) },
        .nip04_decrypt => .{ .nip04_decrypt = try parse_pubkey_text_request(request.params) },
        .nip44_encrypt => .{ .nip44_encrypt = try parse_pubkey_text_request(request.params) },
        .nip44_decrypt => .{ .nip44_decrypt = try parse_pubkey_text_request(request.params) },
        .switch_relays => .switch_relays,
    };
}

/// Build a typed `connect` request using caller-provided id storage.
/// See `examples/nip46_example.zig` and `examples/remote_signing_recipe.zig`.
pub fn request_build_connect(
    output: *RequestBuilder,
    id: []const u8,
    request: *const Connect,
    scratch: std.mem.Allocator,
) RemoteSigningError!Request {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(request) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    output.pubkey_hex = std.fmt.bytesToHex(request.remote_signer_pubkey, .lower);
    output.params[0] = output.pubkey_hex[0..];
    output.param_count = 1;
    if (request.secret) |secret| {
        output.params[1] = secret;
        output.param_count = 2;
    }
    if (request.requested_permissions.len != 0) {
        output.params[2] = try join_permissions(
            output.text_storage[0..],
            request.requested_permissions,
        );
        output.param_count = 3;
    }
    const built = output.as_request(id, .connect);
    try request_validate(&built, scratch);
    return built;
}

/// Build a typed `sign_event` request using caller-provided unsigned event JSON.
pub fn request_build_sign_event(
    output: *RequestBuilder,
    id: []const u8,
    unsigned_event_json: []const u8,
    scratch: std.mem.Allocator,
) RemoteSigningError!Request {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(unsigned_event_json.len <= std.math.maxInt(usize));

    output.params[0] = unsigned_event_json;
    output.param_count = 1;
    const built = output.as_request(id, .sign_event);
    try request_validate(&built, scratch);
    return built;
}

/// Build a typed pubkey-plus-text request for the current encrypt/decrypt methods.
pub fn request_build_pubkey_text(
    output: *RequestBuilder,
    id: []const u8,
    method: Method,
    request: *const PubkeyText,
    scratch: std.mem.Allocator,
) RemoteSigningError!Request {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(request) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (!method_is_pubkey_text(method)) {
        return error.InvalidMethod;
    }
    output.pubkey_hex = std.fmt.bytesToHex(request.pubkey, .lower);
    output.params[0] = output.pubkey_hex[0..];
    output.params[1] = request.text;
    output.param_count = 2;
    const built = output.as_request(id, method);
    try request_validate(&built, scratch);
    return built;
}

/// Build a typed zero-param request for `ping`, `get_public_key`, or `switch_relays`.
pub fn request_build_empty(
    output: *RequestBuilder,
    id: []const u8,
    method: Method,
    scratch: std.mem.Allocator,
) RemoteSigningError!Request {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(@intFromEnum(method) <= @intFromEnum(Method.switch_relays));

    if (!method_is_zero_param(method)) {
        return error.InvalidMethod;
    }
    output.param_count = 0;
    const built = output.as_request(id, method);
    try request_validate(&built, scratch);
    return built;
}

pub fn response_validate(
    response: *const Response,
    method: Method,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
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
        .text, .relays => try validate_response_result(response.result, method, scratch),
    }
}

/// Parse a validated `connect` response into `ack` or a secret echo.
pub fn response_result_connect(response: *const Response) RemoteSigningError!ConnectResult {
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
pub fn response_result_get_public_key(response: *const Response) RemoteSigningError![32]u8 {
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
) RemoteSigningError!nip01_event.Event {
    std.debug.assert(@intFromPtr(response) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    try validate_response_common(response);
    const text = try response_text_payload(response);
    return nip01_event.event_parse_json(text, scratch) catch return error.InvalidSignedEvent;
}

/// Parse a validated `switch_relays` response into an updated relay list or `null`.
pub fn response_result_switch_relays(response: *const Response) RemoteSigningError!?[]const []const u8 {
    std.debug.assert(@intFromPtr(response) != 0);
    std.debug.assert(@sizeOf(Result) > 0);

    try validate_response_common(response);
    return switch (response.result) {
        .null_result => null,
        .relays => |relays| relays,
        .absent, .text => error.InvalidResponse,
    };
}

pub fn uri_parse(input: []const u8, scratch: std.mem.Allocator) RemoteSigningError!Uri {
    std.debug.assert(input.len <= std.math.maxInt(usize));
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

pub fn uri_serialize(output: []u8, uri: Uri) RemoteSigningError![]const u8 {
    std.debug.assert(output.len <= limits.nip46_uri_bytes_max);
    std.debug.assert(@sizeOf(Uri) > 0);

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
) RemoteSigningError![32]u8 {
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
    return resolved;
}

/// Parse the NIP-46 discovery fields from a signer's `nostr.json?name=_` document.
/// See `examples/discovery_recipe.zig`.
pub fn discovery_parse_well_known(
    input: []const u8,
    scratch: std.mem.Allocator,
) RemoteSigningError!Discovery {
    std.debug.assert(input.len <= limits.relay_message_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (input.len == 0 or input.len > limits.relay_message_bytes_max) {
        return error.InvalidDiscoveryDocument;
    }

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        parse_arena.allocator(),
        input,
        .{},
    ) catch return error.InvalidDiscoveryDocument;
    if (root != .object) {
        return error.InvalidDiscoveryDocument;
    }
    return parse_well_known_root(root.object, scratch);
}

/// Extract bounded NIP-46 discovery fields from a kind-31990 remote-signer event.
pub fn discovery_parse_nip89(
    event: *const nip01_event.Event,
    scratch: std.mem.Allocator,
) RemoteSigningError!Discovery {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (event.kind != 31_990) {
        return error.InvalidDiscoveryEvent;
    }

    var relays_buf: [limits.nip46_relays_max][]const u8 = undefined;
    var relay_count: u8 = 0;
    var saw_kind = false;
    var discovery_url: ?[]const u8 = null;
    for (event.tags) |tag| {
        try parse_discovery_tag(
            tag,
            &relays_buf,
            &relay_count,
            &saw_kind,
            &discovery_url,
        );
    }
    if (!saw_kind) {
        return error.MissingDiscoveryKind;
    }
    return .{
        .app_pubkey = event.pubkey,
        .relays = try duplicate_relay_slice(relays_buf[0..relay_count], scratch),
        .nostrconnect_url = discovery_url,
    };
}

/// Render a discovery `nostrconnect_url` template using one exact placeholder substitution.
/// See `examples/discovery_recipe.zig` and `examples/remote_signing_recipe.zig`.
pub fn discovery_render_nostrconnect_url(
    output: []u8,
    template_url: []const u8,
    connection_uri: []const u8,
    scratch: std.mem.Allocator,
) RemoteSigningError![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    _ = parse_url(template_url) catch return error.InvalidNostrConnectUrl;
    try validate_nostrconnect_client_uri(connection_uri, scratch);

    const placeholder_start = try find_single_nostrconnect_placeholder(template_url);
    const rendered_len = template_url.len - nostrconnect_url_placeholder.len + connection_uri.len;
    if (rendered_len > limits.nip46_uri_bytes_max) return error.InvalidNostrConnectUrl;
    if (rendered_len > output.len) return error.BufferTooSmall;

    @memcpy(output[0..placeholder_start], template_url[0..placeholder_start]);
    const uri_end = placeholder_start + connection_uri.len;
    @memcpy(output[placeholder_start..uri_end], connection_uri);
    const suffix = template_url[placeholder_start + nostrconnect_url_placeholder.len ..];
    @memcpy(output[uri_end .. uri_end + suffix.len], suffix);

    const rendered = output[0..rendered_len];
    _ = parse_url(rendered) catch return error.InvalidNostrConnectUrl;
    return rendered;
}

const ParsedUriParts = struct {
    scheme: []const u8,
    authority: []const u8,
    query: ?[]const u8,
};

const WellKnownPartial = struct {
    app_pubkey: ?[32]u8 = null,
    relays: []const []const u8 = &.{},
    nostrconnect_url: ?[]const u8 = null,
};

const MessageParseState = struct {
    id: ?[]const u8 = null,
    method: ?Method = null,
    params: ?[]const []const u8 = null,
    result: Result = .absent,
    error_text: ?[]const u8 = null,
    saw_result: bool = false,
    saw_error: bool = false,
};

fn parse_message_object(
    object: std.json.ObjectMap,
    scratch: std.mem.Allocator,
) RemoteSigningError!Message {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var state = MessageParseState{};
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        try parse_message_field(&state, entry.key_ptr.*, entry.value_ptr.*, scratch);
    }
    return build_message_from_state(state, scratch);
}

fn parse_message_field(
    state: *MessageParseState,
    key: []const u8,
    value: std.json.Value,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (std.mem.eql(u8, key, "id")) {
        if (state.id != null) return error.InvalidMessage;
        state.id = try parse_id_value(value, scratch);
        return;
    }
    if (std.mem.eql(u8, key, "method")) {
        if (state.method != null) return error.InvalidMessage;
        state.method = try parse_method_value(value);
        return;
    }
    if (std.mem.eql(u8, key, "params")) {
        if (state.params != null) return error.InvalidMessage;
        state.params = try parse_string_array_value(
            value,
            limits.nip46_message_params_max,
            limits.nip46_message_json_bytes_max,
            scratch,
        );
        return;
    }
    if (std.mem.eql(u8, key, "result")) {
        if (state.saw_result) return error.InvalidMessage;
        state.result = try parse_result_value(value, scratch);
        state.saw_result = true;
        return;
    }
    if (std.mem.eql(u8, key, "error")) {
        if (state.saw_error) return error.InvalidMessage;
        state.error_text = try parse_optional_string_value(
            value,
            limits.nip46_message_json_bytes_max,
            scratch,
        );
        state.saw_error = true;
    }
}

fn build_message_from_state(
    state: MessageParseState,
    scratch: std.mem.Allocator,
) RemoteSigningError!Message {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(@sizeOf(MessageParseState) > 0);

    const id = state.id orelse return error.InvalidMessage;
    if (state.method != null or state.params != null) {
        return build_request_message(id, state, scratch);
    }
    return build_response_message(id, state);
}

fn build_request_message(
    id: []const u8,
    state: MessageParseState,
    scratch: std.mem.Allocator,
) RemoteSigningError!Message {
    std.debug.assert(id.len > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (state.saw_result or state.saw_error) return error.InvalidMessage;
    const request = Request{
        .id = id,
        .method = state.method orelse return error.InvalidRequest,
        .params = state.params orelse return error.InvalidRequest,
    };
    try request_validate(&request, scratch);
    return .{ .request = request };
}

fn build_response_message(id: []const u8, state: MessageParseState) RemoteSigningError!Message {
    std.debug.assert(id.len > 0);
    std.debug.assert(@sizeOf(MessageParseState) > 0);

    const response = Response{
        .id = id,
        .result = if (state.saw_result) state.result else .absent,
        .error_text = if (state.saw_error) state.error_text else null,
    };
    return .{ .response = response };
}

fn parse_well_known_root(
    object: std.json.ObjectMap,
    scratch: std.mem.Allocator,
) RemoteSigningError!Discovery {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var partial = WellKnownPartial{};
    const names_value = object.get("names") orelse return error.MissingDiscoveryPubkey;
    partial.app_pubkey = try parse_well_known_names(names_value);
    if (object.get("nip46")) |nip46_value| {
        try parse_well_known_nip46(&partial, nip46_value, partial.app_pubkey.?, scratch);
    }
    const app_pubkey = partial.app_pubkey orelse return error.MissingDiscoveryPubkey;
    return .{
        .app_pubkey = app_pubkey,
        .relays = partial.relays,
        .nostrconnect_url = partial.nostrconnect_url,
    };
}

fn validate_nostrconnect_client_uri(
    connection_uri: []const u8,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
    std.debug.assert(connection_uri.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const parsed = try uri_parse(connection_uri, scratch);
    if (parsed != .client) {
        return error.InvalidScheme;
    }
}

fn find_single_nostrconnect_placeholder(template_url: []const u8) RemoteSigningError!usize {
    std.debug.assert(template_url.len <= std.math.maxInt(usize));
    std.debug.assert(nostrconnect_url_placeholder.len > 0);

    const placeholder_start = std.mem.indexOf(u8, template_url, nostrconnect_url_placeholder) orelse {
        return error.InvalidNostrConnectUrl;
    };
    const next_index = placeholder_start + nostrconnect_url_placeholder.len;
    if (std.mem.indexOfPos(u8, template_url, next_index, nostrconnect_url_placeholder) != null) {
        return error.InvalidNostrConnectUrl;
    }
    return placeholder_start;
}

fn parse_well_known_names(value: std.json.Value) RemoteSigningError![32]u8 {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (value != .object) {
        return error.InvalidDiscoveryDocument;
    }
    const name_value = value.object.get("_") orelse return error.MissingDiscoveryPubkey;
    if (name_value != .string) {
        return error.InvalidDiscoveryDocument;
    }
    return parse_lower_hex_32(name_value.string) catch return error.InvalidPubkey;
}

fn parse_well_known_nip46(
    partial: *WellKnownPartial,
    value: std.json.Value,
    app_pubkey: [32]u8,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
    std.debug.assert(@intFromPtr(partial) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .object) {
        return error.InvalidDiscoveryDocument;
    }
    var relay_buf: [limits.nip46_relays_max][]const u8 = undefined;
    var relay_count: u8 = 0;
    var discovery_url = partial.nostrconnect_url;
    var saw_relays = false;
    const pubkey_hex = std.fmt.bytesToHex(app_pubkey, .lower);
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const field = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "relays")) {
            try parse_well_known_relays(field, &relay_buf, &relay_count, scratch);
            saw_relays = true;
            continue;
        }
        if (std.mem.eql(u8, key, "nostrconnect_url")) {
            discovery_url = try parse_well_known_discovery_url(field, scratch);
            continue;
        }
        if (!saw_relays and std.mem.eql(u8, key, &pubkey_hex)) {
            try parse_well_known_relays(field, &relay_buf, &relay_count, scratch);
            saw_relays = true;
        }
    }
    partial.relays = try duplicate_relay_slice(relay_buf[0..relay_count], scratch);
    partial.nostrconnect_url = discovery_url;
}

fn parse_well_known_relays(
    value: std.json.Value,
    relay_buf: *[limits.nip46_relays_max][]const u8,
    relay_count: *u8,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(relay_count.* <= limits.nip46_relays_max);

    if (value != .array) {
        return error.InvalidDiscoveryDocument;
    }
    var index: usize = 0;
    while (index < value.array.items.len) : (index += 1) {
        const item = value.array.items[index];
        if (item != .string) {
            return error.InvalidDiscoveryDocument;
        }
        const relay = duplicate_valid_utf8(
            item.string,
            limits.tag_item_bytes_max,
            scratch,
        ) catch return error.InvalidDiscoveryDocument;
        try append_query_relay(relay, relay_buf, relay_count);
    }
}

fn parse_well_known_discovery_url(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) RemoteSigningError![]const u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (value != .string) {
        return error.InvalidDiscoveryDocument;
    }
    const text = duplicate_valid_utf8(
        value.string,
        limits.tag_item_bytes_max,
        scratch,
    ) catch return error.InvalidDiscoveryDocument;
    _ = parse_url(text) catch return error.InvalidNostrConnectUrl;
    return text;
}

fn parse_discovery_tag(
    tag: nip01_event.EventTag,
    relays_buf: *[limits.nip46_relays_max][]const u8,
    relay_count: *u8,
    saw_kind: *bool,
    discovery_url: *?[]const u8,
) RemoteSigningError!void {
    std.debug.assert(@intFromPtr(relay_count) != 0);
    std.debug.assert(@intFromPtr(saw_kind) != 0);

    if (tag.items.len == 0) {
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "k")) {
        try parse_discovery_kind_tag(tag, saw_kind);
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "relay")) {
        try parse_discovery_relay_tag(tag, relays_buf, relay_count);
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "nostrconnect_url")) {
        try parse_discovery_url_tag(tag, discovery_url);
    }
}

fn parse_discovery_kind_tag(tag: nip01_event.EventTag, saw_kind: *bool) RemoteSigningError!void {
    std.debug.assert(@intFromPtr(saw_kind) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) {
        return error.InvalidDiscoveryEvent;
    }
    if (!std.mem.eql(u8, tag.items[1], "24133")) {
        return error.InvalidDiscoveryEvent;
    }
    if (saw_kind.*) {
        return error.DuplicateDiscoveryKind;
    }
    saw_kind.* = true;
}

fn parse_discovery_relay_tag(
    tag: nip01_event.EventTag,
    relays_buf: *[limits.nip46_relays_max][]const u8,
    relay_count: *u8,
) RemoteSigningError!void {
    std.debug.assert(@intFromPtr(relay_count) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) {
        return error.InvalidDiscoveryEvent;
    }
    try append_query_relay(tag.items[1], relays_buf, relay_count);
}

fn parse_discovery_url_tag(
    tag: nip01_event.EventTag,
    discovery_url: *?[]const u8,
) RemoteSigningError!void {
    std.debug.assert(@intFromPtr(discovery_url) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) {
        return error.InvalidDiscoveryEvent;
    }
    _ = parse_url(tag.items[1]) catch return error.InvalidNostrConnectUrl;
    if (discovery_url.* != null) {
        return error.InvalidDiscoveryEvent;
    }
    discovery_url.* = tag.items[1];
}

fn parse_id_value(value: std.json.Value, scratch: std.mem.Allocator) RemoteSigningError![]const u8 {
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

fn parse_method_value(value: std.json.Value) RemoteSigningError!Method {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(@sizeOf(Method) > 0);

    if (value != .string) {
        return error.InvalidMethod;
    }
    return method_parse(value.string);
}

fn parse_result_value(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) RemoteSigningError!Result {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value == .null) {
        return .null_result;
    }
    if (value == .string) {
        return .{
            .text = try duplicate_valid_utf8(
                value.string,
                limits.nip46_message_json_bytes_max,
                scratch,
            ),
        };
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
    return .{ .relays = relays };
}

fn parse_string_array_value(
    value: std.json.Value,
    max_items: u8,
    max_item_len: u32,
    scratch: std.mem.Allocator,
) RemoteSigningError![]const []const u8 {
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
) RemoteSigningError!?[]const u8 {
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
    invalid_error: RemoteSigningError,
) RemoteSigningError![]const u8 {
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
) error{ InvalidParam, OutOfMemory }![]const u8 {
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

fn validate_message_id(id: []const u8) RemoteSigningError!void {
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

fn validate_response_common(response: *const Response) RemoteSigningError!void {
    std.debug.assert(@intFromPtr(response) != 0);
    std.debug.assert(@sizeOf(Result) > 0);

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

fn response_text_payload(response: *const Response) RemoteSigningError![]const u8 {
    std.debug.assert(@intFromPtr(response) != 0);
    std.debug.assert(@sizeOf(Result) > 0);

    return switch (response.result) {
        .text => |text| text,
        .absent, .null_result, .relays => error.InvalidResponse,
    };
}

fn validate_connect_params(
    params: []const []const u8,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
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

fn method_is_pubkey_text(method: Method) bool {
    std.debug.assert(@intFromEnum(method) <= @intFromEnum(Method.switch_relays));
    std.debug.assert(@sizeOf(Method) > 0);

    return switch (method) {
        .nip04_encrypt, .nip04_decrypt, .nip44_encrypt, .nip44_decrypt => true,
        else => false,
    };
}

fn method_is_zero_param(method: Method) bool {
    std.debug.assert(@intFromEnum(method) <= @intFromEnum(Method.switch_relays));
    std.debug.assert(@sizeOf(Method) > 0);

    return switch (method) {
        .ping, .get_public_key, .switch_relays => true,
        else => false,
    };
}

fn parse_typed_connect_request(
    params: []const []const u8,
    scratch: std.mem.Allocator,
) RemoteSigningError!Connect {
    std.debug.assert(params.len <= limits.nip46_message_params_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var parsed = Connect{
        .remote_signer_pubkey = parse_lower_hex_32(params[0]) catch return error.InvalidPubkey,
    };
    if (params.len >= 2) {
        parsed.secret = params[1];
    }
    if (params.len == 3) {
        parsed.requested_permissions = try parse_permissions_csv(params[2], scratch);
    }
    return parsed;
}

fn validate_sign_event_params(
    params: []const []const u8,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
    std.debug.assert(params.len <= limits.nip46_message_params_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (params.len != 1) {
        return error.InvalidRequest;
    }
    try validate_unsigned_event_json(params[0], scratch);
}

fn require_zero_params(params: []const []const u8) RemoteSigningError!void {
    std.debug.assert(params.len <= limits.nip46_message_params_max);
    std.debug.assert(params.len <= std.math.maxInt(usize));

    if (params.len != 0) {
        return error.InvalidRequest;
    }
}

fn validate_pubkey_text_params(params: []const []const u8) RemoteSigningError!void {
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

fn parse_pubkey_text_request(params: []const []const u8) RemoteSigningError!PubkeyText {
    std.debug.assert(params.len <= limits.nip46_message_params_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    return .{
        .pubkey = parse_lower_hex_32(params[0]) catch return error.InvalidPubkey,
        .text = params[1],
    };
}

fn validate_response_result(
    result: Result,
    method: Method,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
    std.debug.assert(@intFromEnum(method) <= @intFromEnum(Method.switch_relays));
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

fn validate_connect_result(result: Result) RemoteSigningError!void {
    std.debug.assert(@sizeOf(Result) > 0);
    std.debug.assert(!@inComptime());

    switch (result) {
        .text => |text| if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidResponse,
        .absent, .null_result, .relays => return error.InvalidResponse,
    }
}

fn validate_sign_event_result(
    result: Result,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
    std.debug.assert(@sizeOf(Result) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    switch (result) {
        .text => |text| {
            _ = nip01_event.event_parse_json(text, scratch) catch return error.InvalidSignedEvent;
        },
        .absent, .null_result, .relays => return error.InvalidResponse,
    }
}

fn validate_ping_result(result: Result) RemoteSigningError!void {
    std.debug.assert(@sizeOf(Result) > 0);
    std.debug.assert(!@inComptime());

    switch (result) {
        .text => |text| {
            if (!std.mem.eql(u8, text, "pong")) return error.InvalidResponse;
        },
        .absent, .null_result, .relays => return error.InvalidResponse,
    }
}

fn validate_pubkey_result(result: Result) RemoteSigningError!void {
    std.debug.assert(@sizeOf(Result) > 0);
    std.debug.assert(limits.pubkey_hex_length == 64);

    switch (result) {
        .text => |text| _ = parse_lower_hex_32(text) catch return error.InvalidPubkey,
        .absent, .null_result, .relays => return error.InvalidResponse,
    }
}

fn validate_text_result(result: Result) RemoteSigningError!void {
    std.debug.assert(@sizeOf(Result) > 0);
    std.debug.assert(!@inComptime());

    switch (result) {
        .text => |text| if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidResponse,
        .absent, .null_result, .relays => return error.InvalidResponse,
    }
}

fn validate_switch_relays_result(result: Result) RemoteSigningError!void {
    std.debug.assert(@sizeOf(Result) > 0);
    std.debug.assert(!@inComptime());

    switch (result) {
        .relays => |relays| {
            var index: usize = 0;
            while (index < relays.len) : (index += 1) {
                _ = parse_relay_url(relays[index]) catch return error.InvalidRelayUrl;
            }
        },
        .absent, .null_result, .text => return error.InvalidResponse,
    }
}

fn parse_uri_parts(input: []const u8) RemoteSigningError!ParsedUriParts {
    std.debug.assert(input.len <= std.math.maxInt(usize));
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
) RemoteSigningError!Bunker {
    std.debug.assert(authority.len <= std.math.maxInt(usize));
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
) RemoteSigningError!Client {
    std.debug.assert(authority.len <= std.math.maxInt(usize));
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
) RemoteSigningError!void {
    std.debug.assert(raw_query.len <= std.math.maxInt(usize));
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
) RemoteSigningError!void {
    std.debug.assert(raw_key.len <= std.math.maxInt(usize));
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
    if (std.mem.eql(u8, key, "metadata")) {
        try parse_legacy_metadata_json(metadata.?, value, scratch);
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

fn parse_legacy_metadata_json(
    metadata: *ClientMetadata,
    input: []const u8,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
    std.debug.assert(@intFromPtr(metadata) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        parse_arena.allocator(),
        input,
        .{},
    ) catch return error.InvalidUri;
    if (root != .object) {
        return error.InvalidUri;
    }
    try parse_legacy_metadata_name(metadata, root.object, scratch);
    try parse_legacy_metadata_url(metadata, root.object, scratch);
    try parse_legacy_metadata_icons(metadata, root.object, scratch);
}

fn parse_legacy_metadata_name(
    metadata: *ClientMetadata,
    object: std.json.ObjectMap,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
    std.debug.assert(@intFromPtr(metadata) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (metadata.name != null) {
        return;
    }
    const value = object.get("name") orelse return;
    const name = try parse_required_string_value(
        value,
        limits.tag_item_bytes_max,
        scratch,
        error.InvalidName,
    );
    try validate_name(name);
    metadata.name = name;
}

fn parse_legacy_metadata_url(
    metadata: *ClientMetadata,
    object: std.json.ObjectMap,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
    std.debug.assert(@intFromPtr(metadata) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (metadata.url != null) {
        return;
    }
    const value = object.get("url") orelse return;
    const url = try parse_required_string_value(
        value,
        limits.tag_item_bytes_max,
        scratch,
        error.InvalidUrl,
    );
    _ = parse_url(url) catch return error.InvalidUrl;
    metadata.url = url;
}

fn parse_legacy_metadata_icons(
    metadata: *ClientMetadata,
    object: std.json.ObjectMap,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
    std.debug.assert(@intFromPtr(metadata) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (metadata.image != null) {
        return;
    }
    const value = object.get("icons") orelse return;
    if (value != .array) {
        return error.InvalidUri;
    }
    if (value.array.items.len == 0) {
        return;
    }
    const first = try parse_required_string_value(
        value.array.items[0],
        limits.tag_item_bytes_max,
        scratch,
        error.InvalidImage,
    );
    _ = parse_url(first) catch return error.InvalidImage;
    metadata.image = first;
}

fn append_query_relay(
    relay: []const u8,
    relay_buf: *[limits.nip46_relays_max][]const u8,
    relay_count: *u8,
) RemoteSigningError!void {
    std.debug.assert(relay_count.* <= limits.nip46_relays_max);
    std.debug.assert(relay.len <= std.math.maxInt(usize));

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
) RemoteSigningError![]const Permission {
    std.debug.assert(perms_text.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (perms_text.len > limits.tag_item_bytes_max) {
        return error.InvalidPermission;
    }
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
) RemoteSigningError![]const []const u8 {
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
) RemoteSigningError![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (text.len > limits.nip46_uri_bytes_max) {
        return error.InvalidUri;
    }
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

fn write_request_json(writer: anytype, request: Request) RemoteSigningError!void {
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

fn write_response_json(writer: anytype, response: Response) RemoteSigningError!void {
    std.debug.assert(response.id.len <= limits.nip46_message_id_bytes_max);
    std.debug.assert(@sizeOf(Response) > 0);

    try validate_message_id(response.id);
    try write_all(writer, "{\"id\":");
    try write_json_string(writer, response.id);
    switch (response.result) {
        .absent => {},
        .null_result => try write_all(writer, ",\"result\":null"),
        .text, .relays => {
            try write_all(writer, ",\"result\":");
            try write_result_json(writer, response.result);
        },
    }
    if (response.error_text) |text| {
        try write_all(writer, ",\"error\":");
        try write_json_string(writer, text);
    }
    try write_all(writer, "}");
}

fn write_result_json(writer: anytype, result: Result) RemoteSigningError!void {
    std.debug.assert(@sizeOf(Result) > 0);
    std.debug.assert(!@inComptime());

    switch (result) {
        .text => |text| try write_json_string(writer, text),
        .relays => |relays| {
            try write_byte(writer, '[');
            try write_json_string_array(writer, relays);
            try write_byte(writer, ']');
        },
        .absent, .null_result => return error.InvalidResponse,
    }
}

fn write_json_string_array(writer: anytype, values: []const []const u8) RemoteSigningError!void {
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(values.len <= std.math.maxInt(usize));

    var index: usize = 0;
    while (index < values.len) : (index += 1) {
        if (index != 0) try write_byte(writer, ',');
        try write_json_string(writer, values[index]);
    }
}

fn write_json_string(writer: anytype, value: []const u8) RemoteSigningError!void {
    std.debug.assert(value.len <= limits.nip46_message_json_bytes_max);
    std.debug.assert(value.len <= std.math.maxInt(usize));

    try write_byte(writer, '"');
    for (value) |byte| {
        try write_json_escaped_byte(writer, byte);
    }
    try write_byte(writer, '"');
}

fn write_json_escaped_byte(writer: anytype, byte: u8) RemoteSigningError!void {
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

fn write_bunker_uri(writer: anytype, bunker: Bunker) RemoteSigningError!void {
    std.debug.assert(bunker.relays.len <= limits.nip46_relays_max);
    std.debug.assert(@sizeOf(Bunker) > 0);

    const hex = std.fmt.bytesToHex(bunker.remote_signer_pubkey, .lower);
    try write_print(writer, "bunker://{s}", .{hex});
    try write_uri_query(writer, bunker.relays, bunker.secret, null);
}

fn write_client_uri(writer: anytype, client: Client) RemoteSigningError!void {
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
) RemoteSigningError!void {
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
) RemoteSigningError!void {
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

fn join_permissions(output: []u8, permissions: []const Permission) RemoteSigningError![]const u8 {
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

fn write_percent_encoded(writer: anytype, text: []const u8) RemoteSigningError!void {
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

fn write_all(writer: anytype, text: []const u8) RemoteSigningError!void {
    std.debug.assert(text.len <= limits.nip46_uri_bytes_max);
    std.debug.assert(text.len <= std.math.maxInt(usize));

    writer.writeAll(text) catch return error.BufferTooSmall;
}

fn write_byte(writer: anytype, byte: u8) RemoteSigningError!void {
    std.debug.assert(byte <= 255);
    std.debug.assert(@sizeOf(u8) == 1);

    writer.writeByte(byte) catch return error.BufferTooSmall;
}

fn write_print(writer: anytype, comptime fmt: []const u8, args: anytype) RemoteSigningError!void {
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

fn parse_target_pubkey(tag: nip01_event.EventTag) RemoteSigningError![32]u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (tag.items.len < 2 or tag.items.len > 2) {
        return error.InvalidTargetPubkey;
    }
    return parse_lower_hex_32(tag.items[1]) catch error.InvalidTargetPubkey;
}

fn validate_secret(secret: []const u8) RemoteSigningError!void {
    std.debug.assert(secret.len <= std.math.maxInt(usize));
    std.debug.assert(limits.nip46_secret_bytes_max > 0);

    if (secret.len == 0 or secret.len > limits.nip46_secret_bytes_max) {
        return error.InvalidSecret;
    }
    if (secret.len > limits.tag_item_bytes_max) {
        return error.InvalidSecret;
    }
    if (!std.unicode.utf8ValidateSlice(secret)) {
        return error.InvalidSecret;
    }
}

fn validate_name(name: []const u8) RemoteSigningError!void {
    std.debug.assert(name.len <= std.math.maxInt(usize));
    std.debug.assert(name.len <= std.math.maxInt(usize));

    if (name.len == 0) return error.InvalidName;
    if (name.len > limits.tag_item_bytes_max) return error.InvalidName;
    if (!std.unicode.utf8ValidateSlice(name)) return error.InvalidName;
}

fn validate_unsigned_event_json(
    input: []const u8,
    scratch: std.mem.Allocator,
) RemoteSigningError!void {
    std.debug.assert(input.len <= std.math.maxInt(usize));
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

fn validate_unsigned_event_object(object: std.json.ObjectMap) RemoteSigningError!void {
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

fn validate_unsigned_kind(value: std.json.Value) RemoteSigningError!void {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(limits.kind_max <= std.math.maxInt(u32));

    if (value != .integer or value.integer < 0) {
        return error.InvalidUnsignedEvent;
    }
    if (@as(u64, @intCast(value.integer)) > limits.kind_max) {
        return error.InvalidUnsignedEvent;
    }
}

fn validate_unsigned_created_at(value: std.json.Value) RemoteSigningError!void {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(@sizeOf(u64) == 8);

    if (value != .integer or value.integer < 0) {
        return error.InvalidUnsignedEvent;
    }
}

fn validate_unsigned_content(value: std.json.Value) RemoteSigningError!void {
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

fn validate_unsigned_tags(value: std.json.Value) RemoteSigningError!void {
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

    return lower_hex_32.parse(text);
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(text.len <= std.math.maxInt(usize));

    if (text.len == 0) return error.InvalidUrl;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidUrl;
    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (parsed.scheme.len == 0) return error.InvalidUrl;
    if (parsed.host == null) return error.InvalidUrl;
    return text;
}

fn parse_relay_url(text: []const u8) error{InvalidRelayUrl}!relay_origin.WebsocketOrigin {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(relay_origin.WebsocketOrigin) > 0);

    return websocket_relay_url.parse_origin(text, limits.tag_item_bytes_max);
}

test "method and permission parsing cover current command set" {
    try std.testing.expectEqual(Method.connect, try method_parse("connect"));
    try std.testing.expectEqual(
        Method.switch_relays,
        try method_parse("switch_relays"),
    );

    const connect_permission = try permission_parse("connect");
    try std.testing.expectEqual(Method.connect, connect_permission.method);
    try std.testing.expect(connect_permission.scope == .none);

    const sign_permission = try permission_parse("sign_event:13");
    try std.testing.expectEqual(Method.sign_event, sign_permission.method);
    try std.testing.expectEqual(@as(u32, 13), sign_permission.scope.event_kind);

    const raw_permission = try permission_parse("nip44_encrypt:dm");
    try std.testing.expectEqual(Method.nip44_encrypt, raw_permission.method);
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
    try std.testing.expect(response_message.response.result == .relays);

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

test "typed request parsing exposes current NIP-46 method params" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const connect_request = Request{
        .id = "typed-1",
        .method = .connect,
        .params = &.{
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "secret",
            "sign_event:1,ping",
        },
    };
    const connect = try request_parse_typed(&connect_request, arena.allocator());
    try std.testing.expect(connect == .connect);
    try std.testing.expectEqual(@as(usize, 2), connect.connect.requested_permissions.len);
    try std.testing.expectEqualStrings("secret", connect.connect.secret.?);

    const encrypt_request = Request{
        .id = "typed-2",
        .method = .nip44_encrypt,
        .params = &.{
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "hello",
        },
    };
    const encrypt = try request_parse_typed(&encrypt_request, arena.allocator());
    try std.testing.expect(encrypt == .nip44_encrypt);
    try std.testing.expectEqualStrings("hello", encrypt.nip44_encrypt.text);

    const switch_relays_request = Request{
        .id = "typed-3",
        .method = .switch_relays,
        .params = &.{},
    };
    try std.testing.expect(
        (try request_parse_typed(&switch_relays_request, arena.allocator())) == .switch_relays,
    );
}

test "typed request builders produce validated current method shapes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var connect_output: RequestBuilder = .{};
    const connect_request = try request_build_connect(
        &connect_output,
        "build-1",
        &.{
            .remote_signer_pubkey = [_]u8{0x01} ** 32,
            .secret = "secret",
            .requested_permissions = &.{
                .{ .method = .ping },
                .{ .method = .sign_event, .scope = .{ .event_kind = 1 } },
            },
        },
        arena.allocator(),
    );
    try std.testing.expectEqual(Method.connect, connect_request.method);
    try std.testing.expectEqual(@as(usize, 3), connect_request.params.len);

    var sign_output: RequestBuilder = .{};
    const sign_request = try request_build_sign_event(
        &sign_output,
        "build-2",
        "{\"kind\":1,\"content\":\"hello\",\"tags\":[],\"created_at\":1}",
        arena.allocator(),
    );
    try std.testing.expectEqual(Method.sign_event, sign_request.method);
    try std.testing.expectEqual(@as(usize, 1), sign_request.params.len);

    var dm_output: RequestBuilder = .{};
    const dm_request = try request_build_pubkey_text(
        &dm_output,
        "build-3",
        .nip44_encrypt,
        &.{
            .pubkey = [_]u8{0xaa} ** 32,
            .text = "hello",
        },
        arena.allocator(),
    );
    try std.testing.expectEqual(Method.nip44_encrypt, dm_request.method);
    try std.testing.expectEqual(@as(usize, 2), dm_request.params.len);

    var empty_output: RequestBuilder = .{};
    const empty_request = try request_build_empty(
        &empty_output,
        "build-4",
        .switch_relays,
        arena.allocator(),
    );
    try std.testing.expectEqual(Method.switch_relays, empty_request.method);
    try std.testing.expectEqual(@as(usize, 0), empty_request.params.len);
}

test "typed request builders reject mismatched method families" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output: RequestBuilder = .{};
    try std.testing.expectError(
        error.InvalidMethod,
        request_build_pubkey_text(
            &output,
            "bad-1",
            .connect,
            &.{
                .pubkey = [_]u8{0} ** 32,
                .text = "hello",
            },
            arena.allocator(),
        ),
    );
    try std.testing.expectError(
        error.InvalidMethod,
        request_build_empty(&output, "bad-2", .sign_event, arena.allocator()),
    );
}

test "response validation covers ping and signed-event results" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const ping_ok = Response{
        .id = "a",
        .result = .{ .text = "pong" },
    };
    try response_validate(&ping_ok, .ping, arena.allocator());

    const sign_ok = Response{
        .id = "b",
        .result = .{
            .text = "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
                "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
                "\"created_at\":1,\"kind\":1,\"tags\":[],\"content\":\"hi\"}",
        },
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
        .result = .{ .text = "ack" },
    };
    const connect_result = try response_result_connect(&connect_ack);
    try std.testing.expect(connect_result == .ack);

    const pubkey_response = Response{
        .id = "pubkey-1",
        .result = .{
            .text = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        },
    };
    const pubkey = try response_result_get_public_key(&pubkey_response);
    try std.testing.expectEqualStrings(
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        &std.fmt.bytesToHex(pubkey, .lower),
    );

    const sign_response = Response{
        .id = "sign-1",
        .result = .{
            .text = "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
                "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
                "\"created_at\":1,\"kind\":1,\"tags\":[],\"content\":\"ok\"," ++
                "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
                "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}",
        },
    };
    const signed_event = try response_result_sign_event(&sign_response, arena.allocator());
    try std.testing.expectEqual(@as(u32, 1), signed_event.kind);
    try std.testing.expectEqualStrings("ok", signed_event.content);

    const relay_response = Response{
        .id = "relay-1",
        .result = .{ .relays = &.{"wss://relay.one"} },
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

test "uri parse accepts legacy rust metadata client shape" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const client_text =
        "nostrconnect://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?metadata=%7B%22name%22%3A%22Example%22%2C%22url%22%3A%22https%3A%2F%2Fclient.example%22" ++
        "%2C%22icons%22%3A%5B%22https%3A%2F%2Fclient.example%2Ficon.png%22%5D%7D" ++
        "&relay=wss%3A%2F%2Frelay.one&secret=s3cr3t";
    const client = try uri_parse(client_text, arena.allocator());

    try std.testing.expect(client == .client);
    try std.testing.expectEqualStrings("Example", client.client.name.?);
    try std.testing.expectEqualStrings("https://client.example", client.client.url.?);
    try std.testing.expectEqualStrings(
        "https://client.example/icon.png",
        client.client.image.?,
    );
    try std.testing.expectEqual(@as(usize, 1), client.client.relays.len);
    try std.testing.expectEqualStrings("s3cr3t", client.client.secret);
}

test "uri parse lets explicit split metadata override legacy metadata json" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const client_text =
        "nostrconnect://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?metadata=%7B%22name%22%3A%22Legacy%22%2C%22url%22%3A%22https%3A%2F%2Fold.example%22%2C" ++
        "%22icons%22%3A%5B%22https%3A%2F%2Fold.example%2Ficon.png%22%5D%7D" ++
        "&relay=wss%3A%2F%2Frelay.one&secret=s3cr3t&name=Current&url=https%3A%2F%2Fclient.example" ++
        "&image=https%3A%2F%2Fclient.example%2Fapp.png";
    const client = try uri_parse(client_text, arena.allocator());

    try std.testing.expect(client == .client);
    try std.testing.expectEqualStrings("Current", client.client.name.?);
    try std.testing.expectEqualStrings("https://client.example", client.client.url.?);
    try std.testing.expectEqualStrings("https://client.example/app.png", client.client.image.?);
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
    try std.testing.expectError(
        error.InvalidUri,
        uri_parse(
            "nostrconnect://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
                "?metadata=%7Bbad-json%7D&relay=wss%3A%2F%2Frelay.one&secret=s3cr3t",
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

test "discovery_parse_well_known extracts app pubkey and nip46 block" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const document =
        "{\"names\":{\"_\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"}," ++
        "\"nip46\":{\"relays\":[\"wss://relay.one\",\"wss://relay.two\"]," ++
        "\"nostrconnect_url\":\"https://bunker.example/<nostrconnect>\"}}";
    const info = try discovery_parse_well_known(document, arena.allocator());
    try std.testing.expectEqual(@as(usize, 2), info.relays.len);
    try std.testing.expectEqualStrings("wss://relay.one", info.relays[0]);
    try std.testing.expectEqualStrings(
        "https://bunker.example/<nostrconnect>",
        info.nostrconnect_url.?,
    );
}

test "discovery_parse_well_known accepts legacy pubkey-keyed relay maps" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const document =
        "{\"names\":{\"_\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"}," ++
        "\"nip46\":{\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\":" ++
        "[\"wss://relay.one\"]}}";
    const info = try discovery_parse_well_known(document, arena.allocator());
    try std.testing.expectEqual(@as(usize, 1), info.relays.len);
    try std.testing.expectEqualStrings("wss://relay.one", info.relays[0]);
    try std.testing.expect(info.nostrconnect_url == null);
}

test "discovery_parse_nip89 extracts bounded remote-signer metadata" {
    const k_tag = [_][]const u8{ "k", "24133" };
    const relay_tag = [_][]const u8{ "relay", "wss://relay.one" };
    const url_tag = [_][]const u8{
        "nostrconnect_url",
        "https://bunker.example/<nostrconnect>",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = k_tag[0..] },
        .{ .items = relay_tag[0..] },
        .{ .items = url_tag[0..] },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{1} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 31_990,
        .created_at = 0,
        .content = "{}",
        .tags = tags[0..],
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const info = try discovery_parse_nip89(&event, arena.allocator());
    try std.testing.expectEqual(@as(usize, 1), info.relays.len);
    try std.testing.expectEqualStrings("wss://relay.one", info.relays[0]);
    try std.testing.expectEqualStrings(
        "https://bunker.example/<nostrconnect>",
        info.nostrconnect_url.?,
    );
}

test "discovery_render_nostrconnect_url performs exact placeholder substitution" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const template = "https://bunker.example/connect/<nostrconnect>";
    const connection_uri =
        "nostrconnect://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=s3cr3t";
    var output: [limits.nip46_uri_bytes_max]u8 = undefined;
    const rendered = try discovery_render_nostrconnect_url(
        output[0..],
        template,
        connection_uri,
        arena.allocator(),
    );
    try std.testing.expectEqualStrings(
        "https://bunker.example/connect/" ++ connection_uri,
        rendered,
    );
}

test "discovery_render_nostrconnect_url rejects missing or duplicate placeholders" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const connection_uri =
        "nostrconnect://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=s3cr3t";
    var output: [limits.nip46_uri_bytes_max]u8 = undefined;

    try std.testing.expectError(
        error.InvalidNostrConnectUrl,
        discovery_render_nostrconnect_url(
            output[0..],
            "https://bunker.example/connect",
            connection_uri,
            arena.allocator(),
        ),
    );
    try std.testing.expectError(
        error.InvalidNostrConnectUrl,
        discovery_render_nostrconnect_url(
            output[0..],
            "https://bunker.example/<nostrconnect>/<nostrconnect>",
            connection_uri,
            arena.allocator(),
        ),
    );
}

test "discovery_render_nostrconnect_url rejects non-client connection uris" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const connection_uri =
        "bunker://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
        "?relay=wss%3A%2F%2Frelay.one&secret=abc";
    var output: [limits.nip46_uri_bytes_max]u8 = undefined;

    try std.testing.expectError(
        error.InvalidScheme,
        discovery_render_nostrconnect_url(
            output[0..],
            "https://bunker.example/<nostrconnect>",
            connection_uri,
            arena.allocator(),
        ),
    );
}

test "nip46 public uri and builder paths reject overlong caller input with typed errors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var request_output: RequestBuilder = .{};
    try std.testing.expectError(
        error.InvalidUnsignedEvent,
        request_build_sign_event(
            &request_output,
            "id",
            "{" ++ ("a" ** 262145),
            arena.allocator(),
        ),
    );

    try std.testing.expectError(
        error.InvalidUri,
        uri_parse("nostrconnect://" ++ ("a" ** 5000), arena.allocator()),
    );

    try std.testing.expectError(
        error.InvalidUri,
        uri_parse(
            "nostrconnect://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
                "?relay=" ++ ("a" ** 4097) ++ "&secret=s3cr3t",
            arena.allocator(),
        ),
    );
}

test "direct nip46 token helpers reject overlong caller input with typed errors" {
    var overlong_token: [limits.tag_item_bytes_max + 1]u8 = undefined;
    @memset(overlong_token[0..], 'a');

    try std.testing.expectError(
        error.InvalidMethod,
        method_parse(overlong_token[0..]),
    );

    overlong_token[0] = 'p';
    overlong_token[1] = ':';
    try std.testing.expectError(
        error.InvalidPermission,
        permission_parse(overlong_token[0..]),
    );
}

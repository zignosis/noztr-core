const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const http_auth_kind: u32 = 27235;
pub const authorization_scheme = "Nostr ";
pub const payload_hash_hex_length: u8 = 64;

pub const Nip98Error = nip01_event.EventParseError || nip01_event.EventShapeError ||
    nip01_event.EventVerifyError || error{
    UnsupportedKind,
    MissingUrlTag,
    MissingMethodTag,
    DuplicateUrlTag,
    DuplicateMethodTag,
    DuplicatePayloadTag,
    InvalidUrl,
    InvalidMethod,
    InvalidPayload,
    InvalidUrlTag,
    InvalidMethodTag,
    InvalidPayloadTag,
    InvalidAuthorizationHeader,
    InvalidBase64,
    UrlMismatch,
    MethodMismatch,
    PayloadMismatch,
    EventExpired,
    EventTooNew,
    BufferTooSmall,
};

pub const HttpAuthInfo = struct {
    url: []const u8,
    method: []const u8,
    payload_hex: ?[]const u8 = null,
};

pub const VerifiedAuthorization = struct {
    event: nip01_event.Event,
    info: HttpAuthInfo,
};

pub const BuiltTag = struct {
    items: [2][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Returns whether the event kind is supported by the strict NIP-98 helper.
pub fn http_auth_is_supported(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.kind <= std.math.maxInt(u32));

    return event.kind == http_auth_kind;
}

/// Extracts the bounded NIP-98 request metadata from one event.
pub fn http_auth_extract(event: *const nip01_event.Event) Nip98Error!HttpAuthInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != http_auth_kind) return error.UnsupportedKind;

    var url: ?[]const u8 = null;
    var method: ?[]const u8 = null;
    var payload_hex: ?[]const u8 = null;
    for (event.tags) |tag| {
        try apply_tag(tag, &url, &method, &payload_hex);
    }

    return .{
        .url = url orelse return error.MissingUrlTag,
        .method = method orelse return error.MissingMethodTag,
        .payload_hex = payload_hex,
    };
}

/// Validates one auth event against an exact request match and caller-supplied time window.
pub fn http_auth_validate_request(
    event: *const nip01_event.Event,
    expected_url: []const u8,
    expected_method: []const u8,
    expected_payload_hex: ?[]const u8,
    now: u64,
    max_past_seconds: u64,
    max_future_seconds: u64,
) Nip98Error!HttpAuthInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(now <= std.math.maxInt(u64));

    _ = validate_absolute_url(expected_url) catch return error.InvalidUrl;
    _ = validate_http_method(expected_method) catch return error.InvalidMethod;
    if (expected_payload_hex) |payload_hex| {
        _ = validate_payload_hex(payload_hex) catch return error.InvalidPayload;
    }

    const info = try http_auth_extract(event);
    try validate_timestamp(event.created_at, now, max_past_seconds, max_future_seconds);
    if (!std.mem.eql(u8, info.url, expected_url)) return error.UrlMismatch;
    if (!std.mem.eql(u8, info.method, expected_method)) return error.MethodMismatch;
    try validate_expected_payload(info.payload_hex, expected_payload_hex);
    return info;
}

/// Verifies one auth event id and signature, then validates its request metadata.
pub fn http_auth_verify_request(
    event: *const nip01_event.Event,
    expected_url: []const u8,
    expected_method: []const u8,
    expected_payload_hex: ?[]const u8,
    now: u64,
    max_past_seconds: u64,
    max_future_seconds: u64,
) Nip98Error!HttpAuthInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(now <= std.math.maxInt(u64));

    try nip01_event.event_verify(event);
    return http_auth_validate_request(
        event,
        expected_url,
        expected_method,
        expected_payload_hex,
        now,
        max_past_seconds,
        max_future_seconds,
    );
}

/// Extracts the base64 event token from one strict `Authorization` header value.
pub fn http_auth_parse_authorization_header(header: []const u8) Nip98Error![]const u8 {
    std.debug.assert(header.len <= std.math.maxInt(usize));
    std.debug.assert(authorization_scheme.len > 0);

    if (!std.mem.startsWith(u8, header, authorization_scheme)) {
        return error.InvalidAuthorizationHeader;
    }
    if (header.len == authorization_scheme.len) return error.InvalidAuthorizationHeader;

    const token = header[authorization_scheme.len..];
    for (token) |byte| {
        if (std.ascii.isWhitespace(byte)) return error.InvalidAuthorizationHeader;
    }
    return token;
}

/// Decodes the base64 event JSON from one strict `Authorization` header value.
pub fn http_auth_decode_authorization_header(
    output: []u8,
    header: []const u8,
) Nip98Error![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(usize));
    std.debug.assert(header.len <= std.math.maxInt(usize));

    const token = try http_auth_parse_authorization_header(header);
    return http_auth_decode_base64_event_json(output, token);
}

/// Decodes one base64 event JSON token into caller-owned output.
pub fn http_auth_decode_base64_event_json(output: []u8, input: []const u8) Nip98Error![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(usize));
    std.debug.assert(input.len <= std.math.maxInt(usize));

    if (input.len == 0) return error.InputTooShort;
    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(input) catch {
        return error.InvalidBase64;
    };
    if (decoded_len > limits.event_json_max) return error.InputTooLong;
    if (decoded_len > output.len) return error.BufferTooSmall;

    std.base64.standard.Decoder.decode(output[0..decoded_len], input) catch {
        return error.InvalidBase64;
    };
    return output[0..decoded_len];
}

/// Parses one strict `Authorization` header value into a bounded event.
pub fn http_auth_parse_authorization_header_event(
    decoded_json_output: []u8,
    header: []const u8,
    scratch: std.mem.Allocator,
) Nip98Error!nip01_event.Event {
    std.debug.assert(decoded_json_output.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const decoded = try http_auth_decode_authorization_header(decoded_json_output, header);
    return nip01_event.event_parse_json(decoded, scratch);
}

/// Canonical trust-boundary wrapper for strict header decode, parse, verify, and request match.
pub fn http_auth_verify_authorization_header(
    decoded_json_output: []u8,
    header: []const u8,
    expected_url: []const u8,
    expected_method: []const u8,
    expected_payload_hex: ?[]const u8,
    now: u64,
    max_past_seconds: u64,
    max_future_seconds: u64,
    scratch: std.mem.Allocator,
) Nip98Error!VerifiedAuthorization {
    std.debug.assert(decoded_json_output.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const event = try http_auth_parse_authorization_header_event(
        decoded_json_output,
        header,
        scratch,
    );
    const info = try http_auth_verify_request(
        &event,
        expected_url,
        expected_method,
        expected_payload_hex,
        now,
        max_past_seconds,
        max_future_seconds,
    );
    return .{ .event = event, .info = info };
}

/// Builds a strict `u` tag from one absolute URL.
pub fn http_auth_build_url_tag(
    output: *BuiltTag,
    url: []const u8,
) Nip98Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(url.len <= limits.tag_item_bytes_max);

    output.items[0] = "u";
    output.items[1] = validate_absolute_url(url) catch return error.InvalidUrlTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a strict `method` tag from one validated HTTP token.
pub fn http_auth_build_method_tag(
    output: *BuiltTag,
    method: []const u8,
) Nip98Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(method.len <= limits.tag_item_bytes_max);

    output.items[0] = "method";
    output.items[1] = validate_http_method(method) catch return error.InvalidMethodTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a strict lowercase-hex `payload` tag.
pub fn http_auth_build_payload_tag(
    output: *BuiltTag,
    payload_hex: []const u8,
) Nip98Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(payload_hex.len <= limits.tag_item_bytes_max);

    output.items[0] = "payload";
    output.items[1] = validate_payload_hex(payload_hex) catch return error.InvalidPayloadTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Computes one lowercase SHA-256 hex digest for a request body.
pub fn http_auth_payload_sha256_hex(output: []u8, payload: []const u8) Nip98Error![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(usize));
    std.debug.assert(payload.len <= std.math.maxInt(usize));

    if (output.len < payload_hash_hex_length) return error.BufferTooSmall;

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(payload, &digest, .{});
    write_lower_hex(output[0..payload_hash_hex_length], digest[0..]);
    return output[0..payload_hash_hex_length];
}

/// Base64-encodes one canonical event JSON into caller-owned output.
pub fn http_auth_encode_event_json_base64(
    output: []u8,
    event: *const nip01_event.Event,
    json_scratch: []u8,
) Nip98Error![]const u8 {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(json_scratch.len <= std.math.maxInt(usize));

    try nip01_event.event_verify(event);
    const json = try serialize_event_json_object(json_scratch, event);
    const encoded_len = std.base64.standard.Encoder.calcSize(json.len);
    if (encoded_len > output.len) return error.BufferTooSmall;

    return std.base64.standard.Encoder.encode(output[0..encoded_len], json);
}

/// Formats one strict `Authorization: Nostr <base64>` header value.
pub fn http_auth_format_authorization_header(
    output: []u8,
    base64_event_json: []const u8,
) Nip98Error![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(usize));
    std.debug.assert(base64_event_json.len <= std.math.maxInt(usize));

    if (base64_event_json.len == 0) return error.InputTooShort;
    try validate_base64_token(base64_event_json);
    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(base64_event_json) catch {
        return error.InvalidBase64;
    };
    if (decoded_len == 0) return error.InputTooShort;
    if (decoded_len > limits.event_json_max) return error.InputTooLong;
    const total_len = authorization_scheme.len + base64_event_json.len;
    if (total_len > output.len) return error.BufferTooSmall;

    @memcpy(output[0..authorization_scheme.len], authorization_scheme);
    @memcpy(output[authorization_scheme.len..total_len], base64_event_json);
    return output[0..total_len];
}

/// Serializes, base64-encodes, and formats one strict authorization header value.
pub fn http_auth_encode_authorization_header(
    output: []u8,
    event: *const nip01_event.Event,
    json_scratch: []u8,
) Nip98Error![]const u8 {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(json_scratch.len <= std.math.maxInt(usize));

    try nip01_event.event_verify(event);
    const json = try serialize_event_json_object(json_scratch, event);
    const encoded_len = std.base64.standard.Encoder.calcSize(json.len);
    const total_len = authorization_scheme.len + encoded_len;
    if (total_len > output.len) return error.BufferTooSmall;

    @memcpy(output[0..authorization_scheme.len], authorization_scheme);
    _ = std.base64.standard.Encoder.encode(output[authorization_scheme.len..total_len], json);
    return output[0..total_len];
}

fn apply_tag(
    tag: nip01_event.EventTag,
    url: *?[]const u8,
    method: *?[]const u8,
    payload_hex: *?[]const u8,
) Nip98Error!void {
    std.debug.assert(@intFromPtr(url) != 0);
    std.debug.assert(@intFromPtr(method) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "u")) return apply_url_tag(tag, url);
    if (std.mem.eql(u8, name, "method")) return apply_method_tag(tag, method);
    if (std.mem.eql(u8, name, "payload")) return apply_payload_tag(tag, payload_hex);
}

fn apply_url_tag(tag: nip01_event.EventTag, url: *?[]const u8) Nip98Error!void {
    std.debug.assert(@intFromPtr(url) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (url.* != null) return error.DuplicateUrlTag;
    url.* = parse_url_tag(tag) catch return error.InvalidUrlTag;
}

fn apply_method_tag(tag: nip01_event.EventTag, method: *?[]const u8) Nip98Error!void {
    std.debug.assert(@intFromPtr(method) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (method.* != null) return error.DuplicateMethodTag;
    method.* = parse_method_tag(tag) catch return error.InvalidMethodTag;
}

fn apply_payload_tag(tag: nip01_event.EventTag, payload_hex: *?[]const u8) Nip98Error!void {
    std.debug.assert(@intFromPtr(payload_hex) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (payload_hex.* != null) return error.DuplicatePayloadTag;
    payload_hex.* = parse_payload_tag(tag) catch return error.InvalidPayloadTag;
}

fn parse_url_tag(tag: nip01_event.EventTag) error{InvalidValue}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return validate_absolute_url(tag.items[1]) catch return error.InvalidValue;
}

fn parse_method_tag(tag: nip01_event.EventTag) error{InvalidValue}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return validate_http_method(tag.items[1]) catch return error.InvalidValue;
}

fn parse_payload_tag(tag: nip01_event.EventTag) error{InvalidValue}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return validate_payload_hex(tag.items[1]) catch return error.InvalidValue;
}

fn validate_timestamp(
    created_at: u64,
    now: u64,
    max_past_seconds: u64,
    max_future_seconds: u64,
) Nip98Error!void {
    std.debug.assert(now <= std.math.maxInt(u64));
    std.debug.assert(created_at <= std.math.maxInt(u64));

    if (created_at > now) {
        const future_delta = created_at - now;
        if (future_delta > max_future_seconds) return error.EventTooNew;
        return;
    }

    const past_delta = now - created_at;
    if (past_delta > max_past_seconds) return error.EventExpired;
}

fn validate_expected_payload(
    actual_payload_hex: ?[]const u8,
    expected_payload_hex: ?[]const u8,
) Nip98Error!void {
    std.debug.assert(@intFromBool(actual_payload_hex != null) <= 1);
    std.debug.assert(@intFromBool(expected_payload_hex != null) <= 1);

    if (expected_payload_hex == null) return;
    if (actual_payload_hex == null) return error.PayloadMismatch;
    if (!std.mem.eql(u8, actual_payload_hex.?, expected_payload_hex.?)) {
        return error.PayloadMismatch;
    }
}

fn validate_absolute_url(text: []const u8) error{InvalidValue}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= std.math.maxInt(usize));

    if (text.len == 0) return error.InvalidValue;
    const parsed = std.Uri.parse(text) catch return error.InvalidValue;
    if (parsed.scheme.len == 0) return error.InvalidValue;
    if (parsed.host == null) return error.InvalidValue;
    return text;
}

fn validate_http_method(text: []const u8) error{InvalidValue}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= std.math.maxInt(usize));

    if (text.len == 0) return error.InvalidValue;
    for (text) |byte| {
        if (!http_method_byte_is_valid(byte)) return error.InvalidValue;
    }
    return text;
}

fn http_method_byte_is_valid(byte: u8) bool {
    std.debug.assert(byte <= 255);
    std.debug.assert(@TypeOf(byte) == u8);

    if (std.ascii.isAlphanumeric(byte)) return true;
    if (byte == '!') return true;
    if (byte == '#') return true;
    if (byte == '$') return true;
    if (byte == '%') return true;
    if (byte == '&') return true;
    if (byte == '\'') return true;
    if (byte == '*') return true;
    if (byte == '+') return true;
    if (byte == '-') return true;
    if (byte == '.') return true;
    if (byte == '^') return true;
    if (byte == '_') return true;
    if (byte == '`') return true;
    if (byte == '|') return true;
    if (byte == '~') return true;
    return false;
}

fn validate_payload_hex(text: []const u8) error{InvalidValue}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(payload_hash_hex_length > 0);

    if (text.len != payload_hash_hex_length) return error.InvalidValue;
    for (text) |byte| {
        const is_digit = byte >= '0' and byte <= '9';
        const is_hex = byte >= 'a' and byte <= 'f';
        if (is_digit or is_hex) {
            continue;
        }
        return error.InvalidValue;
    }
    return text;
}

fn write_lower_hex(output: []u8, input: []const u8) void {
    const alphabet = "0123456789abcdef";
    std.debug.assert(output.len == input.len * 2);
    std.debug.assert(input.len <= std.math.maxInt(usize));

    for (input, 0..) |byte, index| {
        output[index * 2] = alphabet[byte >> 4];
        output[index * 2 + 1] = alphabet[byte & 0x0f];
    }
}

fn validate_base64_token(input: []const u8) Nip98Error!void {
    std.debug.assert(input.len <= std.math.maxInt(usize));
    std.debug.assert(authorization_scheme.len > 0);

    if (input.len == 0) return error.InputTooShort;
    if (input.len % 4 != 0) return error.InvalidBase64;

    var padding_started = false;
    var padding_count: u8 = 0;
    for (input) |byte| {
        if (byte == '=') {
            padding_started = true;
            padding_count += 1;
            if (padding_count > 2) return error.InvalidBase64;
            continue;
        }
        if (padding_started) return error.InvalidBase64;
        if (!base64_byte_is_valid(byte)) return error.InvalidBase64;
    }
}

fn base64_byte_is_valid(byte: u8) bool {
    std.debug.assert(byte <= 255);
    std.debug.assert(@TypeOf(byte) == u8);

    if (byte >= 'A' and byte <= 'Z') return true;
    if (byte >= 'a' and byte <= 'z') return true;
    if (byte >= '0' and byte <= '9') return true;
    if (byte == '+') return true;
    if (byte == '/') return true;
    return false;
}

fn serialize_event_json_object(
    output: []u8,
    event: *const nip01_event.Event,
) error{BufferTooSmall}![]const u8 {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(output.len <= std.math.maxInt(usize));

    const id_hex = std.fmt.bytesToHex(event.id, .lower);
    const pubkey_hex = std.fmt.bytesToHex(event.pubkey, .lower);
    const sig_hex = std.fmt.bytesToHex(event.sig, .lower);
    var index: u32 = 0;

    try write_event_bytes(output, &index, "{\"id\":\"");
    try write_event_bytes(output, &index, id_hex[0..]);
    try write_event_bytes(output, &index, "\",\"pubkey\":\"");
    try write_event_bytes(output, &index, pubkey_hex[0..]);
    try write_event_bytes(output, &index, "\",\"created_at\":");
    try write_event_u64(output, &index, event.created_at);
    try write_event_bytes(output, &index, ",\"kind\":");
    try write_event_u64(output, &index, event.kind);
    try write_event_bytes(output, &index, ",\"tags\":");
    try write_event_tags(output, &index, event.tags);
    try write_event_bytes(output, &index, ",\"content\":");
    try write_event_json_string(output, &index, event.content);
    try write_event_bytes(output, &index, ",\"sig\":\"");
    try write_event_bytes(output, &index, sig_hex[0..]);
    try write_event_bytes(output, &index, "\"}");
    return output[0..@intCast(index)];
}

fn write_event_tags(
    output: []u8,
    index: *u32,
    tags: []const nip01_event.EventTag,
) error{BufferTooSmall}!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(tags.len <= limits.tags_max);

    try write_event_bytes(output, index, "[");
    for (tags, 0..) |tag, tag_index| {
        if (tag_index != 0) try write_event_bytes(output, index, ",");
        try write_event_bytes(output, index, "[");
        for (tag.items, 0..) |item, item_index| {
            if (item_index != 0) try write_event_bytes(output, index, ",");
            try write_event_json_string(output, index, item);
        }
        try write_event_bytes(output, index, "]");
    }
    try write_event_bytes(output, index, "]");
}

fn write_event_json_string(
    output: []u8,
    index: *u32,
    input: []const u8,
) error{BufferTooSmall}!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(input.len <= limits.content_bytes_max);

    try write_event_bytes(output, index, "\"");
    for (input) |byte| {
        if (byte == '"' or byte == '\\') {
            try write_event_bytes(output, index, "\\");
            try write_event_byte(output, index, byte);
            continue;
        }
        if (byte < 0x20) {
            try write_event_control_escape(output, index, byte);
            continue;
        }
        try write_event_byte(output, index, byte);
    }
    try write_event_bytes(output, index, "\"");
}

fn write_event_control_escape(
    output: []u8,
    index: *u32,
    byte: u8,
) error{BufferTooSmall}!void {
    const alphabet = "0123456789abcdef";
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(byte < 0x20);

    try write_event_bytes(output, index, "\\u00");
    try write_event_byte(output, index, alphabet[byte >> 4]);
    try write_event_byte(output, index, alphabet[byte & 0x0f]);
}

fn write_event_u64(output: []u8, index: *u32, value: u64) error{BufferTooSmall}!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(value <= std.math.maxInt(u64));

    var digits: [20]u8 = undefined;
    const rendered = std.fmt.bufPrint(digits[0..], "{d}", .{value}) catch {
        return error.BufferTooSmall;
    };
    try write_event_bytes(output, index, rendered);
}

fn write_event_bytes(
    output: []u8,
    index: *u32,
    bytes: []const u8,
) error{BufferTooSmall}!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(bytes.len <= std.math.maxInt(usize));

    if (output.len - index.* < bytes.len) return error.BufferTooSmall;
    @memcpy(output[index.* .. index.* + bytes.len], bytes);
    index.* += @intCast(bytes.len);
}

fn write_event_byte(output: []u8, index: *u32, byte: u8) error{BufferTooSmall}!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(byte <= 255);

    if (index.* == output.len) return error.BufferTooSmall;
    output[index.*] = byte;
    index.* += 1;
}

fn test_event(kind: u32, tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(kind <= std.math.maxInt(u32));
    std.debug.assert(tags.len <= limits.tags_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = 1_700_000_000,
        .content = "",
        .tags = tags,
    };
}

fn test_signed_event(
    kind: u32,
    created_at: u64,
    content: []const u8,
    tags: []const nip01_event.EventTag,
) !nip01_event.Event {
    std.debug.assert(kind <= std.math.maxInt(u32));
    std.debug.assert(created_at <= std.math.maxInt(u64));

    const secret_key = [_]u8{0x11} ** 32;
    const nostr_keys = @import("nostr_keys.zig");
    const pubkey = try nostr_keys.nostr_derive_public_key(&secret_key);
    var event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = created_at,
        .content = content,
        .tags = tags,
    };
    try nostr_keys.nostr_sign_event(&secret_key, &event);
    return event;
}

test "http auth extract parses required and optional tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "u", "https://api.example.com/v1?id=1" } },
        .{ .items = &.{ "method", "PATCH" } },
        .{ .items = &.{ "payload",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" } },
        .{ .items = &.{ "x", "ignored" } },
    };
    var event = test_event(http_auth_kind, tags[0..]);
    event.content = "ignored by strict kernel";

    const info = try http_auth_extract(&event);

    try std.testing.expectEqualStrings("https://api.example.com/v1?id=1", info.url);
    try std.testing.expectEqualStrings("PATCH", info.method);
    try std.testing.expectEqualStrings(
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        info.payload_hex.?,
    );
}

test "http auth extract rejects duplicate and malformed required tags" {
    const duplicate_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "u", "https://api.example.com" } },
        .{ .items = &.{ "u", "https://api.example.com/other" } },
        .{ .items = &.{ "method", "GET" } },
    };
    const bad_method_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "u", "https://api.example.com" } },
        .{ .items = &.{ "method", "GET " } },
    };
    const bad_payload_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "u", "https://api.example.com" } },
        .{ .items = &.{ "method", "GET" } },
        .{ .items = &.{ "payload",
            "ABCDEFabcdef0123456789abcdef0123456789abcdef0123456789abcdef01" } },
    };

    try std.testing.expectError(
        error.DuplicateUrlTag,
        http_auth_extract(&test_event(http_auth_kind, duplicate_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidMethodTag,
        http_auth_extract(&test_event(http_auth_kind, bad_method_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidPayloadTag,
        http_auth_extract(&test_event(http_auth_kind, bad_payload_tags[0..])),
    );
}

test "http auth validate request keeps exact url and method matching" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "u", "https://api.example.com/v1?x=1" } },
        .{ .items = &.{ "method", "GET" } },
    };
    const event = test_event(http_auth_kind, tags[0..]);

    _ = try http_auth_validate_request(
        &event,
        "https://api.example.com/v1?x=1",
        "GET",
        null,
        1_700_000_000,
        60,
        30,
    );
    try std.testing.expectError(
        error.UrlMismatch,
        http_auth_validate_request(
            &event,
            "https://api.example.com/v1?x=2",
            "GET",
            null,
            1_700_000_000,
            60,
            30,
        ),
    );
    try std.testing.expectError(
        error.MethodMismatch,
        http_auth_validate_request(
            &event,
            "https://api.example.com/v1?x=1",
            "get",
            null,
            1_700_000_000,
            60,
            30,
        ),
    );
}

test "http auth validate request distinguishes invalid caller input from mismatch" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "u", "https://api.example.com" } },
        .{ .items = &.{ "method", "POST" } },
    };
    const event = test_event(http_auth_kind, tags[0..]);

    try std.testing.expectError(
        error.InvalidUrl,
        http_auth_validate_request(&event, "not-a-url", "POST", null, 1_700_000_000, 60, 30),
    );
    try std.testing.expectError(
        error.InvalidMethod,
        http_auth_validate_request(
            &event,
            "https://api.example.com",
            "POST ",
            null,
            1_700_000_000,
            60,
            30,
        ),
    );
}

test "http auth validate request enforces payload and time windows" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "u", "https://api.example.com/upload" } },
        .{ .items = &.{ "method", "POST" } },
        .{ .items = &.{ "payload",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" } },
    };
    const event = test_event(http_auth_kind, tags[0..]);

    _ = try http_auth_validate_request(
        &event,
        "https://api.example.com/upload",
        "POST",
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        1_700_000_010,
        60,
        30,
    );
    try std.testing.expectError(
        error.PayloadMismatch,
        http_auth_validate_request(
            &event,
            "https://api.example.com/upload",
            "POST",
            "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
            1_700_000_010,
            60,
            30,
        ),
    );
    try std.testing.expectError(
        error.EventExpired,
        http_auth_validate_request(
            &event,
            "https://api.example.com/upload",
            "POST",
            null,
            1_700_000_100,
            60,
            30,
        ),
    );
    try std.testing.expectError(
        error.EventTooNew,
        http_auth_validate_request(
            &event,
            "https://api.example.com/upload",
            "POST",
            null,
            1_699_999_950,
            60,
            30,
        ),
    );
}

test "http auth builders stay symmetric with extractors" {
    var url_tag: BuiltTag = .{};
    var method_tag: BuiltTag = .{};
    var payload_tag: BuiltTag = .{};
    const tags = [_]nip01_event.EventTag{
        try http_auth_build_url_tag(&url_tag, "https://api.example.com/v1"),
        try http_auth_build_method_tag(&method_tag, "PATCH"),
        try http_auth_build_payload_tag(
            &payload_tag,
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        ),
    };
    const event = test_event(http_auth_kind, tags[0..]);

    const info = try http_auth_extract(&event);
    try std.testing.expectEqualStrings("u", url_tag.items[0]);
    try std.testing.expectEqualStrings("method", method_tag.items[0]);
    try std.testing.expectEqualStrings("payload", payload_tag.items[0]);
    try std.testing.expectEqualStrings("https://api.example.com/v1", info.url);
    try std.testing.expectEqualStrings("PATCH", info.method);
}

test "http auth builders reject invalid tag values with typed errors" {
    var url_tag: BuiltTag = .{};
    var method_tag: BuiltTag = .{};
    var payload_tag: BuiltTag = .{};

    try std.testing.expectError(error.InvalidUrlTag, http_auth_build_url_tag(&url_tag, "relative"));
    try std.testing.expectError(
        error.InvalidMethodTag,
        http_auth_build_method_tag(&method_tag, "GET "),
    );
    try std.testing.expectError(
        error.InvalidPayloadTag,
        http_auth_build_payload_tag(
            &payload_tag,
            "0123456789ABCDEF0123456789abcdef0123456789abcdef0123456789abcdef",
        ),
    );
}

test "http auth payload hash helper emits lowercase hex and typed capacity" {
    var output: [payload_hash_hex_length]u8 = undefined;
    var tiny_output: [payload_hash_hex_length - 1]u8 = undefined;

    const hash = try http_auth_payload_sha256_hex(output[0..], "{\"ok\":true}");
    try std.testing.expectEqual(@as(usize, payload_hash_hex_length), hash.len);
    try std.testing.expect(hash[0] >= '0');
    try std.testing.expectError(
        error.BufferTooSmall,
        http_auth_payload_sha256_hex(tiny_output[0..], "{\"ok\":true}"),
    );
}

test "http auth header helpers enforce strict scheme and payload boundaries" {
    var json_output: [limits.event_json_max]u8 = undefined;
    var header_output: [128]u8 = undefined;
    const token = try http_auth_decode_base64_event_json(
        json_output[0..],
        "eyJraW5kIjoyNzIzNSwiY29udGVudCI6IiJ9",
    );

    try std.testing.expectEqualStrings("{\"kind\":27235,\"content\":\"\"}", token);
    try std.testing.expectEqualStrings(
        "eyJraW5kIjoyNzIzNSwiY29udGVudCI6IiJ9",
        try http_auth_parse_authorization_header(
            "Nostr eyJraW5kIjoyNzIzNSwiY29udGVudCI6IiJ9",
        ),
    );
    try std.testing.expectEqualStrings(
        "Nostr eyJraW5kIjoyNzIzNSwiY29udGVudCI6IiJ9",
        try http_auth_format_authorization_header(
            header_output[0..],
            "eyJraW5kIjoyNzIzNSwiY29udGVudCI6IiJ9",
        ),
    );
    try std.testing.expectError(
        error.InvalidAuthorizationHeader,
        http_auth_parse_authorization_header("nostr eyJraW5kIjoyNzIzNSwiY29udGVudCI6IiJ9"),
    );
    try std.testing.expectError(
        error.InvalidAuthorizationHeader,
        http_auth_parse_authorization_header("Nostr  eyJraW5kIjoyNzIzNSwiY29udGVudCI6IiJ9"),
    );
    try std.testing.expectError(
        error.InvalidBase64,
        http_auth_decode_base64_event_json(json_output[0..], "%%%not-base64%%%"),
    );
    try std.testing.expectError(
        error.InvalidBase64,
        http_auth_format_authorization_header(header_output[0..], "%%%not-base64%%%"),
    );
    try std.testing.expectError(
        error.InputTooShort,
        http_auth_decode_base64_event_json(json_output[0..], ""),
    );
    try std.testing.expectError(
        error.InputTooShort,
        http_auth_format_authorization_header(header_output[0..], ""),
    );
}

test "http auth encode header and verify safe wrapper round trips canonical event json" {
    var url_tag: BuiltTag = .{};
    var method_tag: BuiltTag = .{};
    const tags = [_]nip01_event.EventTag{
        try http_auth_build_url_tag(&url_tag, "https://api.example.com/v1"),
        try http_auth_build_method_tag(&method_tag, "GET"),
    };
    const event = try test_signed_event(http_auth_kind, 1_700_000_000, "", tags[0..]);

    var header_output: [limits.event_json_max * 2]u8 = undefined;
    var json_scratch: [limits.event_json_max]u8 = undefined;
    const header = try http_auth_encode_authorization_header(
        header_output[0..],
        &event,
        json_scratch[0..],
    );

    var decode_output: [limits.event_json_max]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const verified = try http_auth_verify_authorization_header(
        decode_output[0..],
        header,
        "https://api.example.com/v1",
        "GET",
        null,
        1_700_000_000,
        60,
        30,
        arena.allocator(),
    );

    try std.testing.expectEqual(event.pubkey, verified.event.pubkey);
    try std.testing.expectEqualStrings("https://api.example.com/v1", verified.info.url);
    try std.testing.expectEqualStrings("GET", verified.info.method);
}

test "http auth verify request rejects invalid signatures without hiding the cause" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "u", "https://api.example.com" } },
        .{ .items = &.{ "method", "GET" } },
    };
    const event = test_event(http_auth_kind, tags[0..]);

    try std.testing.expectError(
        error.InvalidId,
        http_auth_verify_request(&event, "https://api.example.com", "GET", null, 1_700_000_000,
            60, 30),
    );
}

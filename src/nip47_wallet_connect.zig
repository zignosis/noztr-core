const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const relay_origin = @import("internal/relay_origin.zig");
const websocket_relay_url = @import("internal/websocket_relay_url.zig");

pub const info_event_kind: u32 = 13_194;
pub const request_event_kind: u32 = 23_194;
pub const response_event_kind: u32 = 23_195;
pub const notification_legacy_event_kind: u32 = 23_196;
pub const notification_event_kind: u32 = 23_197;
pub const uri_scheme = "nostr+walletconnect://";
pub const metadata_bytes_max: u16 = 4_096;
pub const message_json_bytes_max: u32 = limits.nip46_message_json_bytes_max;

pub const NwcError = error{
    UnsupportedKind,
    InvalidUri,
    InvalidScheme,
    InvalidPubkey,
    InvalidNodePubkey,
    InvalidSecret,
    InvalidRelayUrl,
    MissingRelay,
    TooManyRelays,
    InvalidLud16,
    InvalidCapability,
    DuplicateEncryptionTag,
    InvalidEncryptionTag,
    DuplicateNotificationsTag,
    InvalidNotificationsTag,
    MissingTargetPubkey,
    DuplicateTargetPubkey,
    InvalidTargetPubkey,
    MissingRequestEventId,
    DuplicateRequestEventId,
    InvalidRequestEventId,
    DuplicateExpirationTag,
    InvalidExpirationTag,
    InvalidMethod,
    InvalidRequest,
    InvalidResponse,
    InvalidNotification,
    InvalidResult,
    InvalidParams,
    InvalidErrorObject,
    InvalidTransaction,
    InvalidMetadata,
    InvalidContent,
    InvalidInfoContent,
    BufferTooSmall,
    OutOfMemory,
};

pub const Method = enum {
    pay_invoice,
    pay_keysend,
    make_invoice,
    lookup_invoice,
    list_transactions,
    get_balance,
    get_info,
    make_hold_invoice,
    cancel_hold_invoice,
    settle_hold_invoice,
};

pub const Encryption = enum {
    nip44_v2,
    nip04,
};

pub const NotificationType = enum {
    payment_received,
    payment_sent,
    hold_invoice_accepted,
};

pub const ErrorCode = enum {
    rate_limited,
    not_implemented,
    insufficient_balance,
    payment_failed,
    not_found,
    quota_exceeded,
    restricted,
    unauthorized,
    internal,
    unsupported_encryption,
    other,
};

pub const TransactionType = enum {
    incoming,
    outgoing,
};

pub const TransactionState = enum {
    pending,
    settled,
    accepted,
    expired,
    failed,
};

pub const ConnectionUri = struct {
    wallet_service_pubkey: [32]u8,
    client_secret: [32]u8,
    relays: []const []const u8,
    lud16: ?[]const u8 = null,
};

pub const InfoEventInfo = struct {
    capability_count: u16 = 0,
    encryption_count: u8 = 0,
    notification_count: u8 = 0,
};

pub const RequestEvent = struct {
    wallet_service_pubkey: [32]u8,
    encryption: Encryption = .nip04,
    expiration: ?u64 = null,
    encrypted_content: []const u8,
};

pub const ResponseEvent = struct {
    client_pubkey: [32]u8,
    request_event_id: [32]u8,
    encryption: Encryption = .nip04,
    encrypted_content: []const u8,
};

pub const NotificationEvent = struct {
    client_pubkey: [32]u8,
    encryption: Encryption,
    encrypted_content: []const u8,
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

pub fn method_parse(text: []const u8) NwcError!Method {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(Method) > 0);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidCapability;
    if (std.mem.eql(u8, text, "pay_invoice")) return .pay_invoice;
    if (std.mem.eql(u8, text, "pay_keysend")) return .pay_keysend;
    if (std.mem.eql(u8, text, "make_invoice")) return .make_invoice;
    if (std.mem.eql(u8, text, "lookup_invoice")) return .lookup_invoice;
    if (std.mem.eql(u8, text, "list_transactions")) return .list_transactions;
    if (std.mem.eql(u8, text, "get_balance")) return .get_balance;
    if (std.mem.eql(u8, text, "get_info")) return .get_info;
    if (std.mem.eql(u8, text, "make_hold_invoice")) return .make_hold_invoice;
    if (std.mem.eql(u8, text, "cancel_hold_invoice")) return .cancel_hold_invoice;
    if (std.mem.eql(u8, text, "settle_hold_invoice")) return .settle_hold_invoice;
    return error.InvalidCapability;
}

pub fn method_text(method: Method) []const u8 {
    std.debug.assert(@typeInfo(Method) == .@"enum");
    std.debug.assert(@intFromEnum(method) <= @intFromEnum(Method.settle_hold_invoice));

    return switch (method) {
        .pay_invoice => "pay_invoice",
        .pay_keysend => "pay_keysend",
        .make_invoice => "make_invoice",
        .lookup_invoice => "lookup_invoice",
        .list_transactions => "list_transactions",
        .get_balance => "get_balance",
        .get_info => "get_info",
        .make_hold_invoice => "make_hold_invoice",
        .cancel_hold_invoice => "cancel_hold_invoice",
        .settle_hold_invoice => "settle_hold_invoice",
    };
}

pub fn encryption_parse(text: []const u8) NwcError!Encryption {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(Encryption) > 0);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidEncryptionTag;
    if (std.mem.eql(u8, text, "nip44_v2")) return .nip44_v2;
    if (std.mem.eql(u8, text, "nip04")) return .nip04;
    return error.InvalidEncryptionTag;
}

pub fn encryption_text(encryption: Encryption) []const u8 {
    std.debug.assert(@typeInfo(Encryption) == .@"enum");
    std.debug.assert(@intFromEnum(encryption) <= @intFromEnum(Encryption.nip04));

    return switch (encryption) {
        .nip44_v2 => "nip44_v2",
        .nip04 => "nip04",
    };
}

pub fn notification_type_parse(text: []const u8) NwcError!NotificationType {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(NotificationType) > 0);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidNotificationsTag;
    if (std.mem.eql(u8, text, "payment_received")) return .payment_received;
    if (std.mem.eql(u8, text, "payment_sent")) return .payment_sent;
    if (std.mem.eql(u8, text, "hold_invoice_accepted")) return .hold_invoice_accepted;
    return error.InvalidNotificationsTag;
}

pub fn notification_type_text(notification_type: NotificationType) []const u8 {
    std.debug.assert(@typeInfo(NotificationType) == .@"enum");
    std.debug.assert(@intFromEnum(notification_type) <=
        @intFromEnum(NotificationType.hold_invoice_accepted));

    return switch (notification_type) {
        .payment_received => "payment_received",
        .payment_sent => "payment_sent",
        .hold_invoice_accepted => "hold_invoice_accepted",
    };
}

pub fn error_code_parse(text: []const u8) NwcError!ErrorCode {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(ErrorCode) > 0);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidErrorObject;
    if (std.mem.eql(u8, text, "RATE_LIMITED")) return .rate_limited;
    if (std.mem.eql(u8, text, "NOT_IMPLEMENTED")) return .not_implemented;
    if (std.mem.eql(u8, text, "INSUFFICIENT_BALANCE")) return .insufficient_balance;
    if (std.mem.eql(u8, text, "PAYMENT_FAILED")) return .payment_failed;
    if (std.mem.eql(u8, text, "NOT_FOUND")) return .not_found;
    if (std.mem.eql(u8, text, "QUOTA_EXCEEDED")) return .quota_exceeded;
    if (std.mem.eql(u8, text, "RESTRICTED")) return .restricted;
    if (std.mem.eql(u8, text, "UNAUTHORIZED")) return .unauthorized;
    if (std.mem.eql(u8, text, "INTERNAL")) return .internal;
    if (std.mem.eql(u8, text, "UNSUPPORTED_ENCRYPTION")) return .unsupported_encryption;
    if (std.mem.eql(u8, text, "OTHER")) return .other;
    return error.InvalidErrorObject;
}

pub fn error_code_text(error_code: ErrorCode) []const u8 {
    std.debug.assert(@typeInfo(ErrorCode) == .@"enum");
    std.debug.assert(@intFromEnum(error_code) <= @intFromEnum(ErrorCode.other));

    return switch (error_code) {
        .rate_limited => "RATE_LIMITED",
        .not_implemented => "NOT_IMPLEMENTED",
        .insufficient_balance => "INSUFFICIENT_BALANCE",
        .payment_failed => "PAYMENT_FAILED",
        .not_found => "NOT_FOUND",
        .quota_exceeded => "QUOTA_EXCEEDED",
        .restricted => "RESTRICTED",
        .unauthorized => "UNAUTHORIZED",
        .internal => "INTERNAL",
        .unsupported_encryption => "UNSUPPORTED_ENCRYPTION",
        .other => "OTHER",
    };
}

pub fn transaction_type_parse(text: []const u8) NwcError!TransactionType {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(TransactionType) > 0);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidTransaction;
    if (std.mem.eql(u8, text, "incoming")) return .incoming;
    if (std.mem.eql(u8, text, "outgoing")) return .outgoing;
    return error.InvalidTransaction;
}

pub fn transaction_type_text(transaction_type: TransactionType) []const u8 {
    std.debug.assert(@typeInfo(TransactionType) == .@"enum");
    std.debug.assert(@intFromEnum(transaction_type) <= @intFromEnum(TransactionType.outgoing));

    return switch (transaction_type) {
        .incoming => "incoming",
        .outgoing => "outgoing",
    };
}

pub fn transaction_state_parse(text: []const u8) NwcError!TransactionState {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(TransactionState) > 0);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidTransaction;
    if (std.mem.eql(u8, text, "pending")) return .pending;
    if (std.mem.eql(u8, text, "settled")) return .settled;
    if (std.mem.eql(u8, text, "accepted")) return .accepted;
    if (std.mem.eql(u8, text, "expired")) return .expired;
    if (std.mem.eql(u8, text, "failed")) return .failed;
    return error.InvalidTransaction;
}

pub fn transaction_state_text(transaction_state: TransactionState) []const u8 {
    std.debug.assert(@typeInfo(TransactionState) == .@"enum");
    std.debug.assert(@intFromEnum(transaction_state) <= @intFromEnum(TransactionState.failed));

    return switch (transaction_state) {
        .pending => "pending",
        .settled => "settled",
        .accepted => "accepted",
        .expired => "expired",
        .failed => "failed",
    };
}

pub fn connection_uri_parse(
    input: []const u8,
    out_relays: [][]const u8,
    scratch: std.mem.Allocator,
) NwcError!ConnectionUri {
    std.debug.assert(input.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const parsed = try parse_uri_parts(input);
    if (!std.mem.eql(u8, parsed.scheme, "nostr+walletconnect")) return error.InvalidScheme;

    const wallet_service_pubkey = parse_lower_hex_32(parsed.authority) catch {
        return error.InvalidPubkey;
    };
    const raw_query = parsed.query orelse return error.InvalidUri;
    return parse_connection_query(raw_query, wallet_service_pubkey, out_relays, scratch);
}

pub fn connection_uri_serialize(
    output: []u8,
    connection_uri: ConnectionUri,
) NwcError![]const u8 {
    std.debug.assert(output.len <= limits.nip46_uri_bytes_max);
    std.debug.assert(connection_uri.relays.len <= std.math.maxInt(usize));

    var index: u32 = 0;
    var wallet_service_pubkey_hex: [limits.pubkey_hex_length]u8 = undefined;
    var client_secret_hex: [limits.pubkey_hex_length]u8 = undefined;
    write_lower_hex(wallet_service_pubkey_hex[0..], connection_uri.wallet_service_pubkey[0..]);
    write_lower_hex(client_secret_hex[0..], connection_uri.client_secret[0..]);

    try write_bytes(output, &index, uri_scheme);
    try write_bytes(output, &index, wallet_service_pubkey_hex[0..]);
    try write_bytes(output, &index, "?");
    for (connection_uri.relays, 0..) |relay, relay_index| {
        if (relay_index != 0) try write_bytes(output, &index, "&");
        _ = parse_relay_url(relay) catch return error.InvalidRelayUrl;
        try write_bytes(output, &index, "relay=");
        try write_percent_encoded(output, &index, relay);
    }
    if (connection_uri.relays.len == 0) return error.MissingRelay;
    try write_bytes(output, &index, "&secret=");
    try write_bytes(output, &index, client_secret_hex[0..]);
    if (connection_uri.lud16) |lud16| {
        try validate_lud16(lud16);
        try write_bytes(output, &index, "&lud16=");
        try write_percent_encoded(output, &index, lud16);
    }
    return output[0..@intCast(index)];
}

pub fn info_event_extract(
    event: *const nip01_event.Event,
    out_capabilities: [][]const u8,
    out_encryptions: []Encryption,
    out_notifications: []NotificationType,
) NwcError!InfoEventInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != info_event_kind) return error.UnsupportedKind;
    if (event.content.len == 0) return error.InvalidInfoContent;

    var info = try parse_info_content(event.content, out_capabilities);
    var saw_encryption_tag = false;
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (std.mem.eql(u8, tag.items[0], "encryption")) {
            if (saw_encryption_tag) return error.DuplicateEncryptionTag;
            info.encryption_count = try parse_encryption_tag(tag, out_encryptions);
            saw_encryption_tag = true;
            continue;
        }
        if (std.mem.eql(u8, tag.items[0], "notifications")) {
            if (info.notification_count != 0) return error.DuplicateNotificationsTag;
            info.notification_count = try parse_notifications_tag(tag, out_notifications);
        }
    }
    if (!saw_encryption_tag) {
        if (out_encryptions.len == 0) return error.BufferTooSmall;
        out_encryptions[0] = .nip04;
        info.encryption_count = 1;
    }
    return info;
}

pub fn request_event_extract(event: *const nip01_event.Event) NwcError!RequestEvent {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != request_event_kind) return error.UnsupportedKind;
    const encrypted_content = validate_encrypted_content(event.content) catch return error.InvalidContent;

    var wallet_service_pubkey: ?[32]u8 = null;
    var encryption: ?Encryption = null;
    var expiration: ?u64 = null;
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (std.mem.eql(u8, tag.items[0], "p")) {
            if (wallet_service_pubkey != null) return error.DuplicateTargetPubkey;
            wallet_service_pubkey = parse_pubkey_tag(tag) catch return error.InvalidTargetPubkey;
            continue;
        }
        if (std.mem.eql(u8, tag.items[0], "encryption")) {
            if (encryption != null) return error.DuplicateEncryptionTag;
            encryption = parse_encryption_singleton_tag(tag) catch return error.InvalidEncryptionTag;
            continue;
        }
        if (std.mem.eql(u8, tag.items[0], "expiration")) {
            if (expiration != null) return error.DuplicateExpirationTag;
            expiration = parse_expiration_tag(tag) catch return error.InvalidExpirationTag;
        }
    }
    return .{
        .wallet_service_pubkey = wallet_service_pubkey orelse return error.MissingTargetPubkey,
        .encryption = encryption orelse .nip04,
        .expiration = expiration,
        .encrypted_content = encrypted_content,
    };
}

pub fn response_event_extract(event: *const nip01_event.Event) NwcError!ResponseEvent {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != response_event_kind) return error.UnsupportedKind;
    const encrypted_content = validate_encrypted_content(event.content) catch return error.InvalidContent;

    var client_pubkey: ?[32]u8 = null;
    var request_event_id: ?[32]u8 = null;
    var encryption: ?Encryption = null;
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (std.mem.eql(u8, tag.items[0], "p")) {
            if (client_pubkey != null) return error.DuplicateTargetPubkey;
            client_pubkey = parse_pubkey_tag(tag) catch return error.InvalidTargetPubkey;
            continue;
        }
        if (std.mem.eql(u8, tag.items[0], "e")) {
            if (request_event_id != null) return error.DuplicateRequestEventId;
            request_event_id = parse_event_id_tag(tag) catch return error.InvalidRequestEventId;
            continue;
        }
        if (std.mem.eql(u8, tag.items[0], "encryption")) {
            if (encryption != null) return error.DuplicateEncryptionTag;
            encryption = parse_encryption_singleton_tag(tag) catch return error.InvalidEncryptionTag;
        }
    }
    return .{
        .client_pubkey = client_pubkey orelse return error.MissingTargetPubkey,
        .request_event_id = request_event_id orelse return error.MissingRequestEventId,
        .encryption = encryption orelse .nip04,
        .encrypted_content = encrypted_content,
    };
}

pub fn notification_event_extract(event: *const nip01_event.Event) NwcError!NotificationEvent {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    const encrypted_content = validate_encrypted_content(event.content) catch return error.InvalidContent;
    const default_encryption = switch (event.kind) {
        notification_legacy_event_kind => Encryption.nip04,
        notification_event_kind => Encryption.nip44_v2,
        else => return error.UnsupportedKind,
    };

    var client_pubkey: ?[32]u8 = null;
    var encryption: ?Encryption = null;
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (std.mem.eql(u8, tag.items[0], "p")) {
            if (client_pubkey != null) return error.DuplicateTargetPubkey;
            client_pubkey = parse_pubkey_tag(tag) catch return error.InvalidTargetPubkey;
            continue;
        }
        if (std.mem.eql(u8, tag.items[0], "encryption")) {
            if (encryption != null) return error.DuplicateEncryptionTag;
            encryption = parse_encryption_singleton_tag(tag) catch return error.InvalidEncryptionTag;
        }
    }
    return .{
        .client_pubkey = client_pubkey orelse return error.MissingTargetPubkey,
        .encryption = encryption orelse default_encryption,
        .encrypted_content = encrypted_content,
    };
}

pub fn nwc_build_pubkey_tag(
    output: *BuiltTag,
    pubkey: *const [32]u8,
) NwcError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(pubkey) != 0);

    output.items[0] = "p";
    write_lower_hex(output.text_storage[0..limits.pubkey_hex_length], pubkey[0..]);
    output.items[1] = output.text_storage[0..limits.pubkey_hex_length];
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn nwc_build_event_id_tag(
    output: *BuiltTag,
    event_id: *const [32]u8,
) NwcError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(event_id) != 0);

    output.items[0] = "e";
    write_lower_hex(output.text_storage[0..limits.id_hex_length], event_id[0..]);
    output.items[1] = output.text_storage[0..limits.id_hex_length];
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn nwc_build_encryption_tag(
    output: *BuiltTag,
    encryption: Encryption,
) NwcError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@typeInfo(Encryption) == .@"enum");

    output.items[0] = "encryption";
    output.items[1] = encryption_text(encryption);
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn nwc_build_expiration_tag(
    output: *BuiltTag,
    expiration: u64,
) NwcError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(expiration <= std.math.maxInt(u64));

    output.items[0] = "expiration";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{expiration}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn nwc_build_info_encryption_tag(
    output: *BuiltTag,
    encryptions: []const Encryption,
) NwcError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(encryptions.len <= std.math.maxInt(usize));

    if (encryptions.len == 0) return error.InvalidEncryptionTag;
    output.items[0] = "encryption";
    output.items[1] = try join_encryptions(output.text_storage[0..], encryptions);
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn nwc_build_info_notifications_tag(
    output: *BuiltTag,
    notifications: []const NotificationType,
) NwcError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(notifications.len <= std.math.maxInt(usize));

    if (notifications.len == 0) return error.InvalidNotificationsTag;
    output.items[0] = "notifications";
    output.items[1] = try join_notifications(output.text_storage[0..], notifications);
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn nwc_format_info_capabilities(
    output: []u8,
    capabilities: []const []const u8,
) NwcError![]const u8 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(capabilities.len <= std.math.maxInt(usize));

    if (capabilities.len == 0) return error.InvalidInfoContent;
    var index: u32 = 0;
    for (capabilities, 0..) |capability, capability_index| {
        _ = validate_capability_token(capability) catch return error.InvalidCapability;
        if (capability_index != 0) try write_bytes(output, &index, " ");
        try write_bytes(output, &index, capability);
    }
    return output[0..@intCast(index)];
}

const UriParts = struct {
    scheme: []const u8,
    authority: []const u8,
    query: ?[]const u8,
};

fn parse_uri_parts(input: []const u8) NwcError!UriParts {
    std.debug.assert(input.len <= std.math.maxInt(usize));
    std.debug.assert(uri_scheme.len > 0);

    if (input.len == 0 or input.len > limits.nip46_uri_bytes_max) return error.InvalidUri;
    const scheme_end = std.mem.indexOf(u8, input, "://") orelse return error.InvalidUri;
    const scheme = input[0..scheme_end];
    const rest = input[scheme_end + 3 ..];
    if (rest.len == 0) return error.InvalidUri;

    const query_index = std.mem.indexOfScalar(u8, rest, '?');
    const authority = if (query_index) |index| rest[0..index] else rest;
    if (authority.len == 0) return error.InvalidUri;
    if (std.mem.indexOfScalar(u8, authority, '/') != null) return error.InvalidUri;
    const query = if (query_index) |index| rest[index + 1 ..] else null;
    return .{ .scheme = scheme, .authority = authority, .query = query };
}

fn parse_connection_query(
    raw_query: []const u8,
    wallet_service_pubkey: [32]u8,
    out_relays: [][]const u8,
    scratch: std.mem.Allocator,
) NwcError!ConnectionUri {
    std.debug.assert(raw_query.len <= limits.nip46_uri_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (raw_query.len > limits.nip46_uri_bytes_max) return error.InvalidUri;
    var relay_count: u16 = 0;
    var client_secret: ?[32]u8 = null;
    var lud16: ?[]const u8 = null;
    var pair_iter = std.mem.splitScalar(u8, raw_query, '&');
    while (pair_iter.next()) |pair| {
        if (pair.len == 0) continue;
        const separator = std.mem.indexOfScalar(u8, pair, '=') orelse return error.InvalidUri;
        const key = try query_decode_component(pair[0..separator], false, scratch);
        const value = try query_decode_component(pair[separator + 1 ..], true, scratch);
        if (std.mem.eql(u8, key, "relay")) {
            if (relay_count == out_relays.len) return error.TooManyRelays;
            _ = parse_relay_url(value) catch return error.InvalidRelayUrl;
            out_relays[relay_count] = value;
            relay_count += 1;
            continue;
        }
        if (std.mem.eql(u8, key, "secret")) {
            if (client_secret != null) return error.InvalidUri;
            client_secret = parse_lower_hex_32(value) catch return error.InvalidSecret;
            continue;
        }
        if (std.mem.eql(u8, key, "lud16")) {
            if (lud16 != null) return error.InvalidUri;
            try validate_lud16(value);
            lud16 = value;
        }
    }
    if (relay_count == 0) return error.MissingRelay;
    return .{
        .wallet_service_pubkey = wallet_service_pubkey,
        .client_secret = client_secret orelse return error.InvalidSecret,
        .relays = out_relays[0..relay_count],
        .lud16 = lud16,
    };
}

fn parse_info_content(content: []const u8, out_capabilities: [][]const u8) NwcError!InfoEventInfo {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(out_capabilities.len <= std.math.maxInt(usize));

    if (content.len > limits.content_bytes_max) return error.InvalidInfoContent;
    var info = InfoEventInfo{};
    var splitter = std.mem.splitScalar(u8, content, ' ');
    while (splitter.next()) |token| {
        if (token.len == 0) return error.InvalidInfoContent;
        _ = validate_capability_token(token) catch return error.InvalidCapability;
        if (info.capability_count == out_capabilities.len) return error.BufferTooSmall;
        out_capabilities[info.capability_count] = token;
        info.capability_count += 1;
    }
    if (info.capability_count == 0) return error.InvalidInfoContent;
    return info;
}

fn parse_encryption_tag(tag: nip01_event.EventTag, out_encryptions: []Encryption) NwcError!u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(out_encryptions.len <= std.math.maxInt(usize));

    if (tag.items.len != 2) return error.InvalidEncryptionTag;
    var count: u8 = 0;
    var splitter = std.mem.splitScalar(u8, tag.items[1], ' ');
    while (splitter.next()) |token| {
        if (token.len == 0) return error.InvalidEncryptionTag;
        if (count == out_encryptions.len) return error.BufferTooSmall;
        out_encryptions[count] = try encryption_parse(token);
        count += 1;
    }
    if (count == 0) return error.InvalidEncryptionTag;
    return count;
}

fn parse_notifications_tag(
    tag: nip01_event.EventTag,
    out_notifications: []NotificationType,
) NwcError!u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(out_notifications.len <= std.math.maxInt(usize));

    if (tag.items.len != 2) return error.InvalidNotificationsTag;
    var count: u8 = 0;
    var splitter = std.mem.splitScalar(u8, tag.items[1], ' ');
    while (splitter.next()) |token| {
        if (token.len == 0) return error.InvalidNotificationsTag;
        if (count == out_notifications.len) return error.BufferTooSmall;
        out_notifications[count] = try notification_type_parse(token);
        count += 1;
    }
    return count;
}

fn parse_encryption_singleton_tag(tag: nip01_event.EventTag) NwcError!Encryption {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@sizeOf(Encryption) > 0);

    if (tag.items.len != 2) return error.InvalidEncryptionTag;
    return encryption_parse(tag.items[1]);
}

fn parse_expiration_tag(tag: nip01_event.EventTag) NwcError!u64 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@sizeOf(u64) == 8);

    if (tag.items.len != 2) return error.InvalidExpirationTag;
    return std.fmt.parseUnsigned(u64, tag.items[1], 10) catch return error.InvalidExpirationTag;
}

fn parse_pubkey_tag(tag: nip01_event.EventTag) NwcError![32]u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (tag.items.len != 2) return error.InvalidTargetPubkey;
    return parse_lower_hex_32(tag.items[1]) catch return error.InvalidTargetPubkey;
}

fn parse_event_id_tag(tag: nip01_event.EventTag) NwcError![32]u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.id_hex_length == 64);

    if (tag.items.len != 2) return error.InvalidRequestEventId;
    return parse_lower_hex_32(tag.items[1]) catch return error.InvalidRequestEventId;
}

fn validate_capability_token(text: []const u8) error{InvalidValue}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(text.len <= std.math.maxInt(usize));

    if (text.len == 0) return error.InvalidValue;
    if (text.len > limits.content_bytes_max) return error.InvalidValue;
    for (text) |byte| {
        const is_lower = byte >= 'a' and byte <= 'z';
        const is_digit = byte >= '0' and byte <= '9';
        if (is_lower or is_digit or byte == '_') continue;
        return error.InvalidValue;
    }
    return text;
}

fn validate_encrypted_content(text: []const u8) error{InvalidValue}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(text.len <= std.math.maxInt(usize));

    if (text.len == 0) return error.InvalidValue;
    if (text.len > limits.content_bytes_max) return error.InvalidValue;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidValue;
    return text;
}

fn validate_lud16(text: []const u8) NwcError!void {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(text.len <= std.math.maxInt(usize));

    if (text.len == 0) return error.InvalidLud16;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidLud16;
    const at_index = std.mem.indexOfScalar(u8, text, '@') orelse return error.InvalidLud16;
    if (at_index == 0 or at_index + 1 >= text.len) return error.InvalidLud16;
    if (std.mem.indexOfScalar(u8, text[at_index + 1 ..], '@') != null) return error.InvalidLud16;
}

fn parse_relay_url(text: []const u8) error{InvalidValue}!relay_origin.WebsocketOrigin {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(relay_origin.WebsocketOrigin) > 0);

    return websocket_relay_url.parse_origin(text, limits.tag_item_bytes_max) catch return error.InvalidValue;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidValue}![32]u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (text.len != 64) return error.InvalidValue;
    var output: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&output, text) catch return error.InvalidValue;
    for (text) |byte| {
        const is_digit = byte >= '0' and byte <= '9';
        const is_hex = byte >= 'a' and byte <= 'f';
        if (is_digit or is_hex) continue;
        return error.InvalidValue;
    }
    return output;
}

fn query_decode_component(
    text: []const u8,
    plus_as_space: bool,
    scratch: std.mem.Allocator,
) NwcError![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (text.len > limits.nip46_uri_bytes_max) return error.InvalidUri;
    const output = scratch.alloc(u8, text.len) catch return error.OutOfMemory;
    var read_index: usize = 0;
    var write_index: usize = 0;
    while (read_index < text.len) : (read_index += 1) {
        const byte = text[read_index];
        if (plus_as_space and byte == '+') {
            output[write_index] = ' ';
            write_index += 1;
            continue;
        }
        if (byte != '%') {
            output[write_index] = byte;
            write_index += 1;
            continue;
        }
        if (read_index + 2 >= text.len) return error.InvalidUri;
        const hi = std.fmt.charToDigit(text[read_index + 1], 16) catch return error.InvalidUri;
        const lo = std.fmt.charToDigit(text[read_index + 2], 16) catch return error.InvalidUri;
        output[write_index] = @intCast((hi << 4) | lo);
        write_index += 1;
        read_index += 2;
    }
    return output[0..write_index];
}

fn join_encryptions(output: []u8, encryptions: []const Encryption) NwcError![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(encryptions.len <= std.math.maxInt(usize));

    var index: u32 = 0;
    for (encryptions, 0..) |encryption, encryption_index| {
        if (encryption_index != 0) try write_bytes(output, &index, " ");
        try write_bytes(output, &index, encryption_text(encryption));
    }
    return output[0..@intCast(index)];
}

fn join_notifications(
    output: []u8,
    notifications: []const NotificationType,
) NwcError![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(notifications.len <= std.math.maxInt(usize));

    var index: u32 = 0;
    for (notifications, 0..) |notification, notification_index| {
        if (notification_index != 0) try write_bytes(output, &index, " ");
        try write_bytes(output, &index, notification_type_text(notification));
    }
    return output[0..@intCast(index)];
}

fn write_percent_encoded(output: []u8, index: *u32, text: []const u8) NwcError!void {
    const hex = "0123456789ABCDEF";
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(text.len <= std.math.maxInt(usize));

    for (text) |byte| {
        if (percent_encode_byte_is_safe(byte)) {
            try write_byte(output, index, byte);
            continue;
        }
        try write_byte(output, index, '%');
        try write_byte(output, index, hex[byte >> 4]);
        try write_byte(output, index, hex[byte & 0x0f]);
    }
}

fn percent_encode_byte_is_safe(byte: u8) bool {
    std.debug.assert(byte <= 255);
    std.debug.assert(@TypeOf(byte) == u8);

    if (byte >= 'A' and byte <= 'Z') return true;
    if (byte >= 'a' and byte <= 'z') return true;
    if (byte >= '0' and byte <= '9') return true;
    if (byte == '-' or byte == '.' or byte == '_' or byte == '~') return true;
    return false;
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

fn write_bytes(output: []u8, index: *u32, bytes: []const u8) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(bytes.len <= std.math.maxInt(usize));

    if (output.len - index.* < bytes.len) return error.BufferTooSmall;
    @memcpy(output[index.* .. index.* + bytes.len], bytes);
    index.* += @intCast(bytes.len);
}

fn write_byte(output: []u8, index: *u32, byte: u8) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(byte <= 255);

    if (index.* == output.len) return error.BufferTooSmall;
    output[index.*] = byte;
    index.* += 1;
}

pub fn Outcome(comptime T: type) type {
    return union(enum) {
        result: T,
        err: ErrorInfo,
    };
}

pub const ErrorInfo = struct {
    code: ErrorCode,
    message: []const u8,
};

pub const PayInvoiceRequest = struct {
    id: ?[]const u8 = null,
    invoice: []const u8,
    amount: ?u64 = null,
};

pub const KeysendTlvRecord = struct {
    tlv_type: u64,
    value: []const u8,
};

pub const PayKeysendRequest = struct {
    id: ?[]const u8 = null,
    amount: u64,
    pubkey: [32]u8,
    preimage: ?[]const u8 = null,
    tlv_records: []const KeysendTlvRecord = &.{},
};

pub const MakeInvoiceRequest = struct {
    amount: u64,
    description: ?[]const u8 = null,
    description_hash: ?[]const u8 = null,
    expiry: ?u64 = null,
};

pub const LookupInvoiceRequest = struct {
    payment_hash: ?[]const u8 = null,
    invoice: ?[]const u8 = null,
};

pub const ListTransactionsRequest = struct {
    from: ?u64 = null,
    until: ?u64 = null,
    limit: ?u64 = null,
    offset: ?u64 = null,
    unpaid: ?bool = null,
    tx_type: ?TransactionType = null,
};

pub const MakeHoldInvoiceRequest = struct {
    amount: u64,
    description: ?[]const u8 = null,
    description_hash: ?[]const u8 = null,
    expiry: ?u64 = null,
    payment_hash: []const u8,
    min_cltv_expiry_delta: ?u32 = null,
};

pub const CancelHoldInvoiceRequest = struct {
    payment_hash: []const u8,
};

pub const SettleHoldInvoiceRequest = struct {
    preimage: []const u8,
};

pub const Request = union(Method) {
    pay_invoice: PayInvoiceRequest,
    pay_keysend: PayKeysendRequest,
    make_invoice: MakeInvoiceRequest,
    lookup_invoice: LookupInvoiceRequest,
    list_transactions: ListTransactionsRequest,
    get_balance,
    get_info,
    make_hold_invoice: MakeHoldInvoiceRequest,
    cancel_hold_invoice: CancelHoldInvoiceRequest,
    settle_hold_invoice: SettleHoldInvoiceRequest,
};

pub const PaymentResult = struct {
    preimage: []const u8,
    fees_paid: ?u64 = null,
};

pub const BalanceResult = struct {
    balance: u64,
};

pub const WalletInfoResult = struct {
    alias: ?[]const u8 = null,
    color: ?[]const u8 = null,
    pubkey: ?[32]u8 = null,
    network: ?[]const u8 = null,
    block_height: ?u32 = null,
    block_hash: ?[32]u8 = null,
    methods: []const []const u8,
    notifications: []const []const u8 = &.{},
};

pub const Transaction = struct {
    tx_type: ?TransactionType = null,
    state: ?TransactionState = null,
    invoice: ?[]const u8 = null,
    description: ?[]const u8 = null,
    description_hash: ?[]const u8 = null,
    preimage: ?[]const u8 = null,
    payment_hash: ?[]const u8 = null,
    amount: ?u64 = null,
    fees_paid: ?u64 = null,
    created_at: ?u64 = null,
    expires_at: ?u64 = null,
    settled_at: ?u64 = null,
    settle_deadline: ?u32 = null,
    metadata: ?std.json.Value = null,
};

pub const Response = union(Method) {
    pay_invoice: Outcome(PaymentResult),
    pay_keysend: Outcome(PaymentResult),
    make_invoice: Outcome(Transaction),
    lookup_invoice: Outcome(Transaction),
    list_transactions: Outcome([]const Transaction),
    get_balance: Outcome(BalanceResult),
    get_info: Outcome(WalletInfoResult),
    make_hold_invoice: Outcome(Transaction),
    cancel_hold_invoice: Outcome(void),
    settle_hold_invoice: Outcome(void),
};

pub const Notification = union(NotificationType) {
    payment_received: Transaction,
    payment_sent: Transaction,
    hold_invoice_accepted: Transaction,
};

const TransactionShape = enum {
    make_invoice,
    lookup_invoice,
    make_hold_invoice,
    list_transaction,
    payment_received,
    payment_sent,
    hold_invoice_accepted,
};

pub fn request_parse_json(input: []const u8, scratch: std.mem.Allocator) NwcError!Request {
    std.debug.assert(input.len <= message_json_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const root = try parse_json_root(input, scratch, error.InvalidRequest);
    if (root != .object) return error.InvalidRequest;
    return parse_request_object(root.object, scratch);
}

pub fn request_serialize_json(output: []u8, request: Request) NwcError![]const u8 {
    std.debug.assert(output.len <= message_json_bytes_max);
    std.debug.assert(@sizeOf(Request) > 0);

    var index: u32 = 0;
    try write_bytes(output, &index, "{\"method\":");
    try write_json_string(output, &index, request_method_text(request));
    try write_bytes(output, &index, ",\"params\":");
    try write_request_params_json(output, &index, request);
    try write_bytes(output, &index, "}");
    return output[0..@intCast(index)];
}

pub fn response_parse_json(input: []const u8, scratch: std.mem.Allocator) NwcError!Response {
    std.debug.assert(input.len <= message_json_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const root = try parse_json_root(input, scratch, error.InvalidResponse);
    if (root != .object) return error.InvalidResponse;
    return parse_response_object(root.object, scratch);
}

pub fn response_serialize_json(output: []u8, response: Response) NwcError![]const u8 {
    std.debug.assert(output.len <= message_json_bytes_max);
    std.debug.assert(@sizeOf(Response) > 0);

    var index: u32 = 0;
    try write_bytes(output, &index, "{\"result_type\":");
    try write_json_string(output, &index, response_method_text(response));
    try write_bytes(output, &index, ",\"error\":");
    try write_response_error_json(output, &index, response);
    try write_bytes(output, &index, ",\"result\":");
    try write_response_result_json(output, &index, response);
    try write_bytes(output, &index, "}");
    return output[0..@intCast(index)];
}

pub fn notification_parse_json(
    input: []const u8,
    scratch: std.mem.Allocator,
) NwcError!Notification {
    std.debug.assert(input.len <= message_json_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const root = try parse_json_root(input, scratch, error.InvalidNotification);
    if (root != .object) return error.InvalidNotification;
    return parse_notification_object(root.object, scratch);
}

pub fn notification_serialize_json(
    output: []u8,
    notification: Notification,
) NwcError![]const u8 {
    std.debug.assert(output.len <= message_json_bytes_max);
    std.debug.assert(@sizeOf(Notification) > 0);

    var index: u32 = 0;
    try write_bytes(output, &index, "{\"notification_type\":");
    try write_json_string(output, &index, notification_method_text(notification));
    try write_bytes(output, &index, ",\"notification\":");
    try write_notification_result_json(output, &index, notification);
    try write_bytes(output, &index, "}");
    return output[0..@intCast(index)];
}

fn parse_json_root(
    input: []const u8,
    scratch: std.mem.Allocator,
    invalid_err: NwcError,
) NwcError!std.json.Value {
    std.debug.assert(input.len <= message_json_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (input.len == 0 or input.len > message_json_bytes_max) return invalid_err;
    if (!std.unicode.utf8ValidateSlice(input)) return invalid_err;
    return std.json.parseFromSliceLeaky(std.json.Value, scratch, input, .{}) catch {
        return invalid_err;
    };
}

fn parse_request_object(
    object: std.json.ObjectMap,
    scratch: std.mem.Allocator,
) NwcError!Request {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var method: ?Method = null;
    var params: ?std.json.Value = null;
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        if (std.mem.eql(u8, key, "method")) {
            if (method != null) return error.InvalidRequest;
            method = try parse_method_value(entry.value_ptr.*, error.InvalidRequest);
            continue;
        }
        if (std.mem.eql(u8, key, "params")) {
            if (params != null) return error.InvalidRequest;
            params = entry.value_ptr.*;
        }
    }
    return parse_request_params(
        method orelse return error.InvalidRequest,
        params orelse return error.InvalidRequest,
        scratch,
    );
}

fn parse_request_params(
    method: Method,
    value: std.json.Value,
    scratch: std.mem.Allocator,
) NwcError!Request {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    return switch (method) {
        .pay_invoice => .{ .pay_invoice = try parse_pay_invoice_params(value) },
        .pay_keysend => .{ .pay_keysend = try parse_pay_keysend_params(value, scratch) },
        .make_invoice => .{ .make_invoice = try parse_make_invoice_params(value) },
        .lookup_invoice => .{ .lookup_invoice = try parse_lookup_invoice_params(value) },
        .list_transactions => .{ .list_transactions = try parse_list_transactions_params(value) },
        .get_balance => try parse_empty_request_params(value, .get_balance),
        .get_info => try parse_empty_request_params(value, .get_info),
        .make_hold_invoice => .{ .make_hold_invoice = try parse_make_hold_invoice_params(value) },
        .cancel_hold_invoice => .{
            .cancel_hold_invoice = try parse_cancel_hold_invoice_params(value),
        },
        .settle_hold_invoice => .{
            .settle_hold_invoice = try parse_settle_hold_invoice_params(value),
        },
    };
}

fn parse_empty_request_params(value: std.json.Value, request: Request) NwcError!Request {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(Request) > 0);

    if (value != .object) return error.InvalidParams;
    if (!object_is_empty(value.object)) return error.InvalidParams;
    return request;
}

fn parse_pay_invoice_params(value: std.json.Value) NwcError!PayInvoiceRequest {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(PayInvoiceRequest) > 0);

    if (value != .object) return error.InvalidParams;
    var request = PayInvoiceRequest{ .invoice = undefined };
    var saw_invoice = false;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const field = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "id")) {
            if (request.id != null) return error.InvalidParams;
            request.id = try parse_optional_text(field, false, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "invoice")) {
            if (saw_invoice) return error.InvalidParams;
            request.invoice = try parse_required_text(field, false, error.InvalidParams);
            saw_invoice = true;
            continue;
        }
        if (std.mem.eql(u8, key, "amount")) {
            if (request.amount != null) return error.InvalidParams;
            request.amount = try parse_required_u64(field, error.InvalidParams);
        }
    }
    if (!saw_invoice) return error.InvalidParams;
    return request;
}

fn parse_pay_keysend_params(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) NwcError!PayKeysendRequest {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .object) return error.InvalidParams;
    var request = PayKeysendRequest{
        .amount = 0,
        .pubkey = undefined,
    };
    var saw_amount = false;
    var saw_pubkey = false;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const field = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "id")) {
            if (request.id != null) return error.InvalidParams;
            request.id = try parse_optional_text(field, false, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "amount")) {
            if (saw_amount) return error.InvalidParams;
            request.amount = try parse_required_u64(field, error.InvalidParams);
            saw_amount = true;
            continue;
        }
        if (std.mem.eql(u8, key, "pubkey")) {
            if (saw_pubkey) return error.InvalidParams;
            request.pubkey = try parse_required_hex32(field, error.InvalidParams);
            saw_pubkey = true;
            continue;
        }
        if (std.mem.eql(u8, key, "preimage")) {
            if (request.preimage != null) return error.InvalidParams;
            request.preimage = try parse_optional_text(field, false, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "tlv_records")) {
            if (request.tlv_records.len != 0) return error.InvalidParams;
            request.tlv_records = try parse_tlv_records(field, scratch);
        }
    }
    if (!saw_amount or !saw_pubkey) return error.InvalidParams;
    return request;
}

fn parse_make_invoice_params(value: std.json.Value) NwcError!MakeInvoiceRequest {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(MakeInvoiceRequest) > 0);

    if (value != .object) return error.InvalidParams;
    var request = MakeInvoiceRequest{ .amount = 0 };
    var saw_amount = false;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const field = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "amount")) {
            if (saw_amount) return error.InvalidParams;
            request.amount = try parse_required_u64(field, error.InvalidParams);
            saw_amount = true;
            continue;
        }
        if (std.mem.eql(u8, key, "description")) {
            if (request.description != null) return error.InvalidParams;
            request.description = try parse_optional_text(field, true, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "description_hash")) {
            if (request.description_hash != null) return error.InvalidParams;
            request.description_hash = try parse_optional_text(field, true, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "expiry")) {
            if (request.expiry != null) return error.InvalidParams;
            request.expiry = try parse_required_u64(field, error.InvalidParams);
        }
    }
    if (!saw_amount) return error.InvalidParams;
    return request;
}

fn parse_lookup_invoice_params(value: std.json.Value) NwcError!LookupInvoiceRequest {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(LookupInvoiceRequest) > 0);

    if (value != .object) return error.InvalidParams;
    var request = LookupInvoiceRequest{};
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const field = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "payment_hash")) {
            if (request.payment_hash != null) return error.InvalidParams;
            request.payment_hash = try parse_optional_text(field, true, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "invoice")) {
            if (request.invoice != null) return error.InvalidParams;
            request.invoice = try parse_optional_text(field, true, error.InvalidParams);
        }
    }
    if (request.payment_hash == null and request.invoice == null) return error.InvalidParams;
    return request;
}

fn parse_list_transactions_params(value: std.json.Value) NwcError!ListTransactionsRequest {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(ListTransactionsRequest) > 0);

    if (value != .object) return error.InvalidParams;
    var request = ListTransactionsRequest{};
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const field = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "from")) {
            if (request.from != null) return error.InvalidParams;
            request.from = try parse_required_u64(field, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "until")) {
            if (request.until != null) return error.InvalidParams;
            request.until = try parse_required_u64(field, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "limit")) {
            if (request.limit != null) return error.InvalidParams;
            request.limit = try parse_required_u64(field, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "offset")) {
            if (request.offset != null) return error.InvalidParams;
            request.offset = try parse_required_u64(field, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "unpaid")) {
            if (request.unpaid != null) return error.InvalidParams;
            request.unpaid = try parse_required_bool(field, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "type")) {
            if (request.tx_type != null) return error.InvalidParams;
            request.tx_type = try parse_transaction_type_value(field, error.InvalidParams);
        }
    }
    return request;
}

fn parse_make_hold_invoice_params(value: std.json.Value) NwcError!MakeHoldInvoiceRequest {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(MakeHoldInvoiceRequest) > 0);

    if (value != .object) return error.InvalidParams;
    var request = MakeHoldInvoiceRequest{
        .amount = 0,
        .payment_hash = undefined,
    };
    var saw_amount = false;
    var saw_payment_hash = false;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const field = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "amount")) {
            if (saw_amount) return error.InvalidParams;
            request.amount = try parse_required_u64(field, error.InvalidParams);
            saw_amount = true;
            continue;
        }
        if (std.mem.eql(u8, key, "description")) {
            if (request.description != null) return error.InvalidParams;
            request.description = try parse_optional_text(field, true, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "description_hash")) {
            if (request.description_hash != null) return error.InvalidParams;
            request.description_hash = try parse_optional_text(field, true, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "expiry")) {
            if (request.expiry != null) return error.InvalidParams;
            request.expiry = try parse_required_u64(field, error.InvalidParams);
            continue;
        }
        if (std.mem.eql(u8, key, "payment_hash")) {
            if (saw_payment_hash) return error.InvalidParams;
            request.payment_hash = try parse_required_text(field, false, error.InvalidParams);
            saw_payment_hash = true;
            continue;
        }
        if (std.mem.eql(u8, key, "min_cltv_expiry_delta")) {
            if (request.min_cltv_expiry_delta != null) return error.InvalidParams;
            request.min_cltv_expiry_delta = try parse_required_u32(field, error.InvalidParams);
        }
    }
    if (!saw_amount or !saw_payment_hash) return error.InvalidParams;
    return request;
}

fn parse_cancel_hold_invoice_params(value: std.json.Value) NwcError!CancelHoldInvoiceRequest {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(CancelHoldInvoiceRequest) > 0);

    if (value != .object) return error.InvalidParams;
    var payment_hash: ?[]const u8 = null;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        if (!std.mem.eql(u8, entry.key_ptr.*, "payment_hash")) continue;
        if (payment_hash != null) return error.InvalidParams;
        payment_hash = try parse_required_text(entry.value_ptr.*, false, error.InvalidParams);
    }
    return .{ .payment_hash = payment_hash orelse return error.InvalidParams };
}

fn parse_settle_hold_invoice_params(value: std.json.Value) NwcError!SettleHoldInvoiceRequest {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(SettleHoldInvoiceRequest) > 0);

    if (value != .object) return error.InvalidParams;
    var preimage: ?[]const u8 = null;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        if (!std.mem.eql(u8, entry.key_ptr.*, "preimage")) continue;
        if (preimage != null) return error.InvalidParams;
        preimage = try parse_required_text(entry.value_ptr.*, false, error.InvalidParams);
    }
    return .{ .preimage = preimage orelse return error.InvalidParams };
}

fn parse_tlv_records(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) NwcError![]const KeysendTlvRecord {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .array) return error.InvalidParams;
    const records = scratch.alloc(KeysendTlvRecord, value.array.items.len) catch {
        return error.OutOfMemory;
    };
    for (value.array.items, 0..) |item, index| {
        records[index] = try parse_tlv_record(item);
    }
    return records;
}

fn parse_tlv_record(value: std.json.Value) NwcError!KeysendTlvRecord {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(KeysendTlvRecord) > 0);

    if (value != .object) return error.InvalidParams;
    var record = KeysendTlvRecord{
        .tlv_type = 0,
        .value = undefined,
    };
    var saw_type = false;
    var saw_value = false;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        if (std.mem.eql(u8, key, "type")) {
            if (saw_type) return error.InvalidParams;
            record.tlv_type = try parse_required_u64(entry.value_ptr.*, error.InvalidParams);
            saw_type = true;
            continue;
        }
        if (std.mem.eql(u8, key, "value")) {
            if (saw_value) return error.InvalidParams;
            record.value = try parse_required_text(entry.value_ptr.*, false, error.InvalidParams);
            saw_value = true;
        }
    }
    if (!saw_type or !saw_value) return error.InvalidParams;
    return record;
}

fn parse_response_object(
    object: std.json.ObjectMap,
    scratch: std.mem.Allocator,
) NwcError!Response {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var method: ?Method = null;
    var error_value: ?std.json.Value = null;
    var result_value: ?std.json.Value = null;
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        if (std.mem.eql(u8, key, "result_type")) {
            if (method != null) return error.InvalidResponse;
            method = try parse_method_value(entry.value_ptr.*, error.InvalidResponse);
            continue;
        }
        if (std.mem.eql(u8, key, "error")) {
            if (error_value != null) return error.InvalidResponse;
            error_value = entry.value_ptr.*;
            continue;
        }
        if (std.mem.eql(u8, key, "result")) {
            if (result_value != null) return error.InvalidResponse;
            result_value = entry.value_ptr.*;
        }
    }
    return parse_response_fields(
        method orelse return error.InvalidResponse,
        error_value orelse return error.InvalidResponse,
        result_value orelse return error.InvalidResponse,
        scratch,
    );
}

fn parse_response_fields(
    method: Method,
    error_value: std.json.Value,
    result_value: std.json.Value,
    scratch: std.mem.Allocator,
) NwcError!Response {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (error_value != .null) {
        if (result_value != .null) return error.InvalidResponse;
        const err_info = try parse_error_info(error_value, error.InvalidResponse);
        return build_error_response(method, err_info);
    }
    return parse_response_result(method, result_value, scratch);
}

fn parse_response_result(
    method: Method,
    value: std.json.Value,
    scratch: std.mem.Allocator,
) NwcError!Response {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    return switch (method) {
        .pay_invoice => .{ .pay_invoice = .{ .result = try parse_payment_result(value) } },
        .pay_keysend => .{ .pay_keysend = .{ .result = try parse_payment_result(value) } },
        .make_invoice => .{
            .make_invoice = .{
                .result = try parse_transaction_value(
                    value,
                    .make_invoice,
                    error.InvalidResponse,
                ),
            },
        },
        .lookup_invoice => .{
            .lookup_invoice = .{
                .result = try parse_transaction_value(
                    value,
                    .lookup_invoice,
                    error.InvalidResponse,
                ),
            },
        },
        .list_transactions => .{
            .list_transactions = .{
                .result = try parse_transactions_result(value, scratch),
            },
        },
        .get_balance => .{
            .get_balance = .{ .result = try parse_balance_result(value) },
        },
        .get_info => .{
            .get_info = .{ .result = try parse_wallet_info_result(value, scratch) },
        },
        .make_hold_invoice => .{
            .make_hold_invoice = .{
                .result = try parse_transaction_value(
                    value,
                    .make_hold_invoice,
                    error.InvalidResponse,
                ),
            },
        },
        .cancel_hold_invoice => .{
            .cancel_hold_invoice = .{ .result = try parse_empty_result(value) },
        },
        .settle_hold_invoice => .{
            .settle_hold_invoice = .{ .result = try parse_empty_result(value) },
        },
    };
}

fn parse_payment_result(value: std.json.Value) NwcError!PaymentResult {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(PaymentResult) > 0);

    if (value != .object) return error.InvalidResult;
    var result = PaymentResult{ .preimage = undefined };
    var saw_preimage = false;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        if (std.mem.eql(u8, key, "preimage")) {
            if (saw_preimage) return error.InvalidResult;
            result.preimage = try parse_required_text(entry.value_ptr.*, false, error.InvalidResult);
            saw_preimage = true;
            continue;
        }
        if (std.mem.eql(u8, key, "fees_paid")) {
            if (result.fees_paid != null) return error.InvalidResult;
            result.fees_paid = try parse_required_u64(entry.value_ptr.*, error.InvalidResult);
        }
    }
    if (!saw_preimage) return error.InvalidResult;
    return result;
}

fn parse_balance_result(value: std.json.Value) NwcError!BalanceResult {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(BalanceResult) > 0);

    if (value != .object) return error.InvalidResult;
    var balance: ?u64 = null;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        if (!std.mem.eql(u8, entry.key_ptr.*, "balance")) continue;
        if (balance != null) return error.InvalidResult;
        balance = try parse_required_u64(entry.value_ptr.*, error.InvalidResult);
    }
    return .{ .balance = balance orelse return error.InvalidResult };
}

fn parse_wallet_info_result(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) NwcError!WalletInfoResult {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .object) return error.InvalidResult;
    var result = WalletInfoResult{ .methods = undefined };
    var saw_methods = false;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const field = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "alias")) {
            if (result.alias != null) return error.InvalidResult;
            result.alias = try parse_optional_text(field, true, error.InvalidResult);
            continue;
        }
        if (std.mem.eql(u8, key, "color")) {
            if (result.color != null) return error.InvalidResult;
            result.color = try parse_optional_text(field, true, error.InvalidResult);
            continue;
        }
        if (std.mem.eql(u8, key, "pubkey")) {
            if (result.pubkey != null) return error.InvalidResult;
            result.pubkey = try parse_optional_hex32(field, error.InvalidResult);
            continue;
        }
        if (std.mem.eql(u8, key, "network")) {
            if (result.network != null) return error.InvalidResult;
            result.network = try parse_optional_text(field, true, error.InvalidResult);
            continue;
        }
        if (std.mem.eql(u8, key, "block_height")) {
            if (result.block_height != null) return error.InvalidResult;
            result.block_height = try parse_required_u32(field, error.InvalidResult);
            continue;
        }
        if (std.mem.eql(u8, key, "block_hash")) {
            if (result.block_hash != null) return error.InvalidResult;
            result.block_hash = try parse_optional_hex32(field, error.InvalidResult);
            continue;
        }
        if (std.mem.eql(u8, key, "methods")) {
            if (saw_methods) return error.InvalidResult;
            result.methods = try parse_token_array(field, scratch, error.InvalidResult);
            saw_methods = true;
            continue;
        }
        if (std.mem.eql(u8, key, "notifications")) {
            if (result.notifications.len != 0) return error.InvalidResult;
            result.notifications = try parse_token_array(field, scratch, error.InvalidResult);
        }
    }
    if (!saw_methods or result.methods.len == 0) return error.InvalidResult;
    return result;
}

fn parse_transactions_result(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) NwcError![]const Transaction {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .object) return error.InvalidResult;
    var transactions_value: ?std.json.Value = null;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        if (!std.mem.eql(u8, entry.key_ptr.*, "transactions")) continue;
        if (transactions_value != null) return error.InvalidResult;
        transactions_value = entry.value_ptr.*;
    }
    const resolved = transactions_value orelse return error.InvalidResult;
    if (resolved != .array) return error.InvalidResult;
    const items = scratch.alloc(Transaction, resolved.array.items.len) catch {
        return error.OutOfMemory;
    };
    for (resolved.array.items, 0..) |item, index| {
        items[index] = try parse_transaction_value(
            item,
            .list_transaction,
            error.InvalidResponse,
        );
    }
    return items;
}

fn parse_empty_result(value: std.json.Value) NwcError!void {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(void) == 0);

    if (value != .object) return error.InvalidResult;
    if (!object_is_empty(value.object)) return error.InvalidResult;
}

fn parse_notification_object(
    object: std.json.ObjectMap,
    scratch: std.mem.Allocator,
) NwcError!Notification {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var notification_type: ?NotificationType = null;
    var notification_value: ?std.json.Value = null;
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        if (std.mem.eql(u8, key, "notification_type")) {
            if (notification_type != null) return error.InvalidNotification;
            notification_type = try parse_notification_type_value(
                entry.value_ptr.*,
                error.InvalidNotification,
            );
            continue;
        }
        if (std.mem.eql(u8, key, "notification")) {
            if (notification_value != null) return error.InvalidNotification;
            notification_value = entry.value_ptr.*;
        }
    }
    return parse_notification_value(
        notification_type orelse return error.InvalidNotification,
        notification_value orelse return error.InvalidNotification,
        scratch,
    );
}

fn parse_notification_value(
    notification_type: NotificationType,
    value: std.json.Value,
    scratch: std.mem.Allocator,
) NwcError!Notification {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    return switch (notification_type) {
        .payment_received => .{
            .payment_received = try parse_transaction_value(
                value,
                .payment_received,
                error.InvalidNotification,
            ),
        },
        .payment_sent => .{
            .payment_sent = try parse_transaction_value(
                value,
                .payment_sent,
                error.InvalidNotification,
            ),
        },
        .hold_invoice_accepted => .{
            .hold_invoice_accepted = try parse_transaction_value(
                value,
                .hold_invoice_accepted,
                error.InvalidNotification,
            ),
        },
    };
}

fn parse_transaction_value(
    value: std.json.Value,
    shape: TransactionShape,
    invalid_err: NwcError,
) NwcError!Transaction {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@typeInfo(TransactionShape) == .@"enum");

    if (value != .object) return error.InvalidTransaction;
    var tx = Transaction{};
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        try parse_transaction_field(&tx, entry.key_ptr.*, entry.value_ptr.*);
    }
    try validate_transaction_shape(tx, shape, invalid_err);
    return tx;
}

fn parse_transaction_field(
    tx: *Transaction,
    key: []const u8,
    field: std.json.Value,
) NwcError!void {
    std.debug.assert(@intFromPtr(tx) != 0);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (std.mem.eql(u8, key, "type")) {
        if (tx.tx_type != null) return error.InvalidTransaction;
        tx.tx_type = try parse_transaction_type_value(field, error.InvalidTransaction);
        return;
    }
    if (std.mem.eql(u8, key, "state")) {
        if (tx.state != null) return error.InvalidTransaction;
        tx.state = try parse_transaction_state_value(field, error.InvalidTransaction);
        return;
    }
    if (std.mem.eql(u8, key, "invoice")) {
        if (tx.invoice != null) return error.InvalidTransaction;
        tx.invoice = try parse_optional_text(field, true, error.InvalidTransaction);
        return;
    }
    if (std.mem.eql(u8, key, "description")) {
        if (tx.description != null) return error.InvalidTransaction;
        tx.description = try parse_optional_text(field, true, error.InvalidTransaction);
        return;
    }
    if (std.mem.eql(u8, key, "description_hash")) {
        if (tx.description_hash != null) return error.InvalidTransaction;
        tx.description_hash = try parse_optional_text(field, true, error.InvalidTransaction);
        return;
    }
    if (std.mem.eql(u8, key, "preimage")) {
        if (tx.preimage != null) return error.InvalidTransaction;
        tx.preimage = try parse_optional_text(field, true, error.InvalidTransaction);
        return;
    }
    if (std.mem.eql(u8, key, "payment_hash")) {
        if (tx.payment_hash != null) return error.InvalidTransaction;
        tx.payment_hash = try parse_optional_text(field, true, error.InvalidTransaction);
        return;
    }
    try parse_transaction_numeric_field(tx, key, field);
}

fn parse_transaction_numeric_field(
    tx: *Transaction,
    key: []const u8,
    field: std.json.Value,
) NwcError!void {
    std.debug.assert(@intFromPtr(tx) != 0);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (std.mem.eql(u8, key, "amount")) {
        if (tx.amount != null) return error.InvalidTransaction;
        tx.amount = try parse_required_u64(field, error.InvalidTransaction);
        return;
    }
    if (std.mem.eql(u8, key, "fees_paid")) {
        if (tx.fees_paid != null) return error.InvalidTransaction;
        tx.fees_paid = try parse_required_u64(field, error.InvalidTransaction);
        return;
    }
    if (std.mem.eql(u8, key, "created_at")) {
        if (tx.created_at != null) return error.InvalidTransaction;
        tx.created_at = try parse_required_u64(field, error.InvalidTransaction);
        return;
    }
    if (std.mem.eql(u8, key, "expires_at")) {
        if (tx.expires_at != null) return error.InvalidTransaction;
        tx.expires_at = try parse_required_u64(field, error.InvalidTransaction);
        return;
    }
    if (std.mem.eql(u8, key, "settled_at")) {
        if (tx.settled_at != null) return error.InvalidTransaction;
        tx.settled_at = try parse_required_u64(field, error.InvalidTransaction);
        return;
    }
    if (std.mem.eql(u8, key, "settle_deadline")) {
        if (tx.settle_deadline != null) return error.InvalidTransaction;
        tx.settle_deadline = try parse_required_u32(field, error.InvalidTransaction);
        return;
    }
    if (std.mem.eql(u8, key, "metadata")) {
        if (tx.metadata != null) return error.InvalidTransaction;
        tx.metadata = try parse_metadata_value(field, error.InvalidTransaction);
    }
}

fn validate_transaction_shape(
    tx: Transaction,
    shape: TransactionShape,
    invalid_err: NwcError,
) NwcError!void {
    std.debug.assert(@typeInfo(TransactionShape) == .@"enum");
    std.debug.assert(@sizeOf(Transaction) > 0);

    switch (shape) {
        .make_invoice => try validate_make_invoice_transaction(tx, invalid_err),
        .lookup_invoice => try validate_lookup_transaction(tx, invalid_err),
        .make_hold_invoice => try validate_make_hold_transaction(tx, invalid_err),
        .list_transaction => try validate_lookup_transaction(tx, invalid_err),
        .payment_received => try validate_payment_received_transaction(tx, invalid_err),
        .payment_sent => try validate_payment_sent_transaction(tx, invalid_err),
        .hold_invoice_accepted => try validate_hold_notification_transaction(tx, invalid_err),
    }
}

fn validate_make_invoice_transaction(tx: Transaction, invalid_err: NwcError) NwcError!void {
    std.debug.assert(@sizeOf(Transaction) > 0);
    std.debug.assert(@sizeOf(NwcError) > 0);

    if (tx.invoice == null) return invalid_err;
    if (tx.amount == null) return invalid_err;
    if (tx.created_at == null) return invalid_err;
}

fn validate_lookup_transaction(tx: Transaction, invalid_err: NwcError) NwcError!void {
    std.debug.assert(@sizeOf(Transaction) > 0);
    std.debug.assert(@sizeOf(NwcError) > 0);

    if (tx.payment_hash == null) return invalid_err;
    if (tx.amount == null) return invalid_err;
    if (tx.created_at == null) return invalid_err;
}

fn validate_make_hold_transaction(tx: Transaction, invalid_err: NwcError) NwcError!void {
    std.debug.assert(@sizeOf(Transaction) > 0);
    std.debug.assert(@sizeOf(NwcError) > 0);

    if (tx.payment_hash == null) return invalid_err;
    if (tx.amount == null) return invalid_err;
    if (tx.created_at == null) return invalid_err;
    if (tx.expires_at == null) return invalid_err;
}

fn validate_payment_received_transaction(
    tx: Transaction,
    invalid_err: NwcError,
) NwcError!void {
    std.debug.assert(@sizeOf(Transaction) > 0);
    std.debug.assert(@sizeOf(NwcError) > 0);

    if (tx.invoice == null or tx.preimage == null) return invalid_err;
    if (tx.payment_hash == null or tx.amount == null) return invalid_err;
    if (tx.fees_paid == null or tx.created_at == null) return invalid_err;
    if (tx.settled_at == null) return invalid_err;
    if (tx.tx_type != null and tx.tx_type.? != .incoming) return invalid_err;
    if (tx.state != null and tx.state.? != .settled) return invalid_err;
}

fn validate_payment_sent_transaction(tx: Transaction, invalid_err: NwcError) NwcError!void {
    std.debug.assert(@sizeOf(Transaction) > 0);
    std.debug.assert(@sizeOf(NwcError) > 0);

    if (tx.invoice == null or tx.preimage == null) return invalid_err;
    if (tx.payment_hash == null or tx.amount == null) return invalid_err;
    if (tx.fees_paid == null or tx.created_at == null) return invalid_err;
    if (tx.settled_at == null) return invalid_err;
    if (tx.tx_type != null and tx.tx_type.? != .outgoing) return invalid_err;
    if (tx.state != null and tx.state.? != .settled) return invalid_err;
}

fn validate_hold_notification_transaction(
    tx: Transaction,
    invalid_err: NwcError,
) NwcError!void {
    std.debug.assert(@sizeOf(Transaction) > 0);
    std.debug.assert(@sizeOf(NwcError) > 0);

    if (tx.invoice == null or tx.payment_hash == null) return invalid_err;
    if (tx.amount == null or tx.created_at == null) return invalid_err;
    if (tx.expires_at == null or tx.settle_deadline == null) return invalid_err;
    if (tx.tx_type != null and tx.tx_type.? != .incoming) return invalid_err;
    if (tx.state != null and tx.state.? != .accepted) return invalid_err;
}

fn build_error_response(method: Method, err_info: ErrorInfo) NwcError!Response {
    std.debug.assert(@typeInfo(Method) == .@"enum");
    std.debug.assert(@sizeOf(ErrorInfo) > 0);

    return switch (method) {
        .pay_invoice => .{ .pay_invoice = .{ .err = err_info } },
        .pay_keysend => .{ .pay_keysend = .{ .err = err_info } },
        .make_invoice => .{ .make_invoice = .{ .err = err_info } },
        .lookup_invoice => .{ .lookup_invoice = .{ .err = err_info } },
        .list_transactions => .{ .list_transactions = .{ .err = err_info } },
        .get_balance => .{ .get_balance = .{ .err = err_info } },
        .get_info => .{ .get_info = .{ .err = err_info } },
        .make_hold_invoice => .{ .make_hold_invoice = .{ .err = err_info } },
        .cancel_hold_invoice => .{ .cancel_hold_invoice = .{ .err = err_info } },
        .settle_hold_invoice => .{ .settle_hold_invoice = .{ .err = err_info } },
    };
}

fn parse_error_info(value: std.json.Value, invalid_err: NwcError) NwcError!ErrorInfo {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(ErrorInfo) > 0);

    if (value != .object) return invalid_err;
    var code: ?ErrorCode = null;
    var message: ?[]const u8 = null;
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        if (std.mem.eql(u8, key, "code")) {
            if (code != null) return invalid_err;
            code = try parse_error_code_value(entry.value_ptr.*, invalid_err);
            continue;
        }
        if (std.mem.eql(u8, key, "message")) {
            if (message != null) return invalid_err;
            message = try parse_required_text(entry.value_ptr.*, false, invalid_err);
        }
    }
    return .{
        .code = code orelse return invalid_err,
        .message = message orelse return invalid_err,
    };
}

fn parse_method_value(value: std.json.Value, invalid_err: NwcError) NwcError!Method {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(Method) > 0);

    if (value != .string) return invalid_err;
    return method_parse(value.string) catch return error.InvalidMethod;
}

fn parse_notification_type_value(
    value: std.json.Value,
    invalid_err: NwcError,
) NwcError!NotificationType {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(NotificationType) > 0);

    if (value != .string) return invalid_err;
    return notification_type_parse(value.string) catch return invalid_err;
}

fn parse_error_code_value(value: std.json.Value, invalid_err: NwcError) NwcError!ErrorCode {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(ErrorCode) > 0);

    if (value != .string) return invalid_err;
    return error_code_parse(value.string) catch return invalid_err;
}

fn parse_transaction_type_value(
    value: std.json.Value,
    invalid_err: NwcError,
) NwcError!TransactionType {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(TransactionType) > 0);

    if (value != .string) return invalid_err;
    return transaction_type_parse(value.string) catch return invalid_err;
}

fn parse_transaction_state_value(
    value: std.json.Value,
    invalid_err: NwcError,
) NwcError!TransactionState {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(TransactionState) > 0);

    if (value != .string) return invalid_err;
    return transaction_state_parse(value.string) catch return invalid_err;
}

fn parse_required_text(
    value: std.json.Value,
    allow_empty: bool,
    invalid_err: NwcError,
) NwcError![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@TypeOf(allow_empty) == bool);

    if (value != .string) return invalid_err;
    if (!std.unicode.utf8ValidateSlice(value.string)) return invalid_err;
    if (!allow_empty and value.string.len == 0) return invalid_err;
    return value.string;
}

fn parse_optional_text(
    value: std.json.Value,
    empty_as_none: bool,
    invalid_err: NwcError,
) NwcError!?[]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@TypeOf(empty_as_none) == bool);

    if (value == .null) return null;
    const text = try parse_required_text(value, true, invalid_err);
    if (empty_as_none and text.len == 0) return null;
    return text;
}

fn parse_required_u64(value: std.json.Value, invalid_err: NwcError) NwcError!u64 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(u64) == 8);

    if (value != .integer or value.integer < 0) return invalid_err;
    return @intCast(value.integer);
}

fn parse_required_u32(value: std.json.Value, invalid_err: NwcError) NwcError!u32 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(u32) == 4);

    const number = try parse_required_u64(value, invalid_err);
    if (number > std.math.maxInt(u32)) return invalid_err;
    return @intCast(number);
}

fn parse_required_bool(value: std.json.Value, invalid_err: NwcError) NwcError!bool {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@TypeOf(value) == std.json.Value);

    if (value != .bool) return invalid_err;
    return value.bool;
}

fn parse_required_hex32(value: std.json.Value, invalid_err: NwcError) NwcError![32]u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (value != .string) return invalid_err;
    return parse_lower_hex_32(value.string) catch return invalid_err;
}

fn parse_optional_hex32(value: std.json.Value, invalid_err: NwcError) NwcError!?[32]u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (value == .null) return null;
    return try parse_required_hex32(value, invalid_err);
}

fn parse_token_array(
    value: std.json.Value,
    scratch: std.mem.Allocator,
    invalid_err: NwcError,
) NwcError![]const []const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .array) return invalid_err;
    const items = scratch.alloc([]const u8, value.array.items.len) catch {
        return error.OutOfMemory;
    };
    for (value.array.items, 0..) |item, index| {
        if (item != .string) return invalid_err;
        _ = validate_capability_token(item.string) catch return invalid_err;
        items[index] = item.string;
    }
    return items;
}

fn parse_metadata_value(value: std.json.Value, invalid_err: NwcError) NwcError!?std.json.Value {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(NwcError) > 0);

    if (value == .null) return null;
    if (value != .object) return invalid_err;
    var buffer: [metadata_bytes_max + 1]u8 = undefined;
    var stream = std.io.fixedBufferStream(buffer[0..]);
    stream.writer().print("{f}", .{std.json.fmt(value, .{})}) catch return invalid_err;
    return value;
}

fn object_is_empty(object: std.json.ObjectMap) bool {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(@typeInfo(bool) == .bool);

    return object.count() == 0;
}

fn request_method_text(request: Request) []const u8 {
    std.debug.assert(@sizeOf(Request) > 0);
    std.debug.assert(@sizeOf(Method) > 0);

    return switch (request) {
        .pay_invoice => method_text(.pay_invoice),
        .pay_keysend => method_text(.pay_keysend),
        .make_invoice => method_text(.make_invoice),
        .lookup_invoice => method_text(.lookup_invoice),
        .list_transactions => method_text(.list_transactions),
        .get_balance => method_text(.get_balance),
        .get_info => method_text(.get_info),
        .make_hold_invoice => method_text(.make_hold_invoice),
        .cancel_hold_invoice => method_text(.cancel_hold_invoice),
        .settle_hold_invoice => method_text(.settle_hold_invoice),
    };
}

fn response_method_text(response: Response) []const u8 {
    std.debug.assert(@sizeOf(Response) > 0);
    std.debug.assert(@sizeOf(Method) > 0);

    return switch (response) {
        .pay_invoice => method_text(.pay_invoice),
        .pay_keysend => method_text(.pay_keysend),
        .make_invoice => method_text(.make_invoice),
        .lookup_invoice => method_text(.lookup_invoice),
        .list_transactions => method_text(.list_transactions),
        .get_balance => method_text(.get_balance),
        .get_info => method_text(.get_info),
        .make_hold_invoice => method_text(.make_hold_invoice),
        .cancel_hold_invoice => method_text(.cancel_hold_invoice),
        .settle_hold_invoice => method_text(.settle_hold_invoice),
    };
}

fn notification_method_text(notification: Notification) []const u8 {
    std.debug.assert(@sizeOf(Notification) > 0);
    std.debug.assert(@sizeOf(NotificationType) > 0);

    return switch (notification) {
        .payment_received => notification_type_text(.payment_received),
        .payment_sent => notification_type_text(.payment_sent),
        .hold_invoice_accepted => notification_type_text(.hold_invoice_accepted),
    };
}

fn write_request_params_json(output: []u8, index: *u32, request: Request) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(Request) > 0);

    switch (request) {
        .pay_invoice => |params| try write_pay_invoice_params_json(output, index, params),
        .pay_keysend => |params| try write_pay_keysend_params_json(output, index, params),
        .make_invoice => |params| try write_make_invoice_params_json(output, index, params),
        .lookup_invoice => |params| try write_lookup_invoice_params_json(output, index, params),
        .list_transactions => |params| {
            try write_list_transactions_params_json(output, index, params);
        },
        .get_balance => try write_empty_object(output, index),
        .get_info => try write_empty_object(output, index),
        .make_hold_invoice => |params| {
            try write_make_hold_invoice_params_json(output, index, params);
        },
        .cancel_hold_invoice => |params| {
            try write_cancel_hold_invoice_params_json(output, index, params);
        },
        .settle_hold_invoice => |params| {
            try write_settle_hold_invoice_params_json(output, index, params);
        },
    }
}

fn write_pay_invoice_params_json(
    output: []u8,
    index: *u32,
    params: PayInvoiceRequest,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(PayInvoiceRequest) > 0);

    if (params.invoice.len == 0) return error.InvalidParams;
    try write_bytes(output, index, "{");
    var first = true;
    if (params.id) |id| {
        try write_string_field(output, index, &first, "id", id, error.InvalidParams);
    }
    try write_string_field(
        output,
        index,
        &first,
        "invoice",
        params.invoice,
        error.InvalidParams,
    );
    if (params.amount) |amount| try write_u64_field(output, index, &first, "amount", amount);
    try write_bytes(output, index, "}");
}

fn write_pay_keysend_params_json(
    output: []u8,
    index: *u32,
    params: PayKeysendRequest,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(PayKeysendRequest) > 0);

    try write_bytes(output, index, "{");
    var first = true;
    if (params.id) |id| {
        try write_string_field(output, index, &first, "id", id, error.InvalidParams);
    }
    try write_u64_field(output, index, &first, "amount", params.amount);
    try write_hex32_field(output, index, &first, "pubkey", params.pubkey, error.InvalidParams);
    if (params.preimage) |preimage| {
        try write_string_field(
            output,
            index,
            &first,
            "preimage",
            preimage,
            error.InvalidParams,
        );
    }
    if (params.tlv_records.len != 0) {
        try write_tlv_records_field(output, index, &first, params.tlv_records, error.InvalidParams);
    }
    try write_bytes(output, index, "}");
}

fn write_make_invoice_params_json(
    output: []u8,
    index: *u32,
    params: MakeInvoiceRequest,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(MakeInvoiceRequest) > 0);

    try write_bytes(output, index, "{");
    var first = true;
    try write_u64_field(output, index, &first, "amount", params.amount);
    if (params.description) |description| {
        try write_string_field(
            output,
            index,
            &first,
            "description",
            description,
            error.InvalidParams,
        );
    }
    if (params.description_hash) |description_hash| {
        try write_string_field(
            output,
            index,
            &first,
            "description_hash",
            description_hash,
            error.InvalidParams,
        );
    }
    if (params.expiry) |expiry| try write_u64_field(output, index, &first, "expiry", expiry);
    try write_bytes(output, index, "}");
}

fn write_lookup_invoice_params_json(
    output: []u8,
    index: *u32,
    params: LookupInvoiceRequest,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(LookupInvoiceRequest) > 0);

    if (params.payment_hash == null and params.invoice == null) return error.InvalidParams;
    try write_bytes(output, index, "{");
    var first = true;
    if (params.payment_hash) |payment_hash| {
        try write_string_field(
            output,
            index,
            &first,
            "payment_hash",
            payment_hash,
            error.InvalidParams,
        );
    }
    if (params.invoice) |invoice| {
        try write_string_field(output, index, &first, "invoice", invoice, error.InvalidParams);
    }
    try write_bytes(output, index, "}");
}

fn write_list_transactions_params_json(
    output: []u8,
    index: *u32,
    params: ListTransactionsRequest,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(ListTransactionsRequest) > 0);

    try write_bytes(output, index, "{");
    var first = true;
    if (params.from) |from| try write_u64_field(output, index, &first, "from", from);
    if (params.until) |until| try write_u64_field(output, index, &first, "until", until);
    if (params.limit) |limit| try write_u64_field(output, index, &first, "limit", limit);
    if (params.offset) |offset| try write_u64_field(output, index, &first, "offset", offset);
    if (params.unpaid) |unpaid| try write_bool_field(output, index, &first, "unpaid", unpaid);
    if (params.tx_type) |tx_type| {
        try write_string_field(
            output,
            index,
            &first,
            "type",
            transaction_type_text(tx_type),
            error.InvalidParams,
        );
    }
    try write_bytes(output, index, "}");
}

fn write_make_hold_invoice_params_json(
    output: []u8,
    index: *u32,
    params: MakeHoldInvoiceRequest,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(MakeHoldInvoiceRequest) > 0);

    if (params.payment_hash.len == 0) return error.InvalidParams;
    try write_bytes(output, index, "{");
    var first = true;
    try write_u64_field(output, index, &first, "amount", params.amount);
    if (params.description) |description| {
        try write_string_field(
            output,
            index,
            &first,
            "description",
            description,
            error.InvalidParams,
        );
    }
    if (params.description_hash) |description_hash| {
        try write_string_field(
            output,
            index,
            &first,
            "description_hash",
            description_hash,
            error.InvalidParams,
        );
    }
    if (params.expiry) |expiry| try write_u64_field(output, index, &first, "expiry", expiry);
    try write_string_field(
        output,
        index,
        &first,
        "payment_hash",
        params.payment_hash,
        error.InvalidParams,
    );
    if (params.min_cltv_expiry_delta) |delta| {
        try write_u32_field(output, index, &first, "min_cltv_expiry_delta", delta);
    }
    try write_bytes(output, index, "}");
}

fn write_cancel_hold_invoice_params_json(
    output: []u8,
    index: *u32,
    params: CancelHoldInvoiceRequest,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(CancelHoldInvoiceRequest) > 0);

    if (params.payment_hash.len == 0) return error.InvalidParams;
    try write_bytes(output, index, "{\"payment_hash\":");
    try write_json_string(output, index, params.payment_hash);
    try write_bytes(output, index, "}");
}

fn write_settle_hold_invoice_params_json(
    output: []u8,
    index: *u32,
    params: SettleHoldInvoiceRequest,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(SettleHoldInvoiceRequest) > 0);

    if (params.preimage.len == 0) return error.InvalidParams;
    try write_bytes(output, index, "{\"preimage\":");
    try write_json_string(output, index, params.preimage);
    try write_bytes(output, index, "}");
}

fn write_response_error_json(
    output: []u8,
    index: *u32,
    response: Response,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(Response) > 0);

    switch (response) {
        inline else => |outcome| switch (outcome) {
            .result => try write_bytes(output, index, "null"),
            .err => |err_info| try write_error_info_json(output, index, err_info),
        },
    }
}

fn write_response_result_json(
    output: []u8,
    index: *u32,
    response: Response,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(Response) > 0);

    switch (response) {
        .pay_invoice, .pay_keysend => |outcome| try write_payment_response_result(
            output,
            index,
            outcome,
        ),
        .make_invoice => |outcome| try write_result_or_null_json(
            output,
            index,
            outcome,
            write_make_invoice_payload,
        ),
        .lookup_invoice => |outcome| try write_result_or_null_json(
            output,
            index,
            outcome,
            write_lookup_transaction_payload,
        ),
        .list_transactions => |outcome| try write_result_or_null_json(
            output,
            index,
            outcome,
            write_transactions_payload,
        ),
        .get_balance => |outcome| try write_result_or_null_json(
            output,
            index,
            outcome,
            write_balance_payload,
        ),
        .get_info => |outcome| try write_result_or_null_json(
            output,
            index,
            outcome,
            write_wallet_info_payload,
        ),
        .make_hold_invoice => |outcome| try write_result_or_null_json(
            output,
            index,
            outcome,
            write_make_hold_payload,
        ),
        .cancel_hold_invoice, .settle_hold_invoice => |outcome| {
            try write_empty_response_result(output, index, outcome);
        },
    }
}

fn write_payment_response_result(
    output: []u8,
    index: *u32,
    outcome: Outcome(PaymentResult),
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(PaymentResult) > 0);

    try write_result_or_null_json(output, index, outcome, write_payment_result_payload);
}

fn write_empty_response_result(
    output: []u8,
    index: *u32,
    outcome: Outcome(void),
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(void) == 0);

    try write_result_or_null_json(output, index, outcome, write_empty_payload);
}

fn write_notification_result_json(
    output: []u8,
    index: *u32,
    notification: Notification,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(Notification) > 0);

    switch (notification) {
        .payment_received => |tx| {
            try validate_payment_received_transaction(tx, error.InvalidNotification);
            try write_transaction_json(output, index, tx, error.InvalidNotification);
        },
        .payment_sent => |tx| {
            try validate_payment_sent_transaction(tx, error.InvalidNotification);
            try write_transaction_json(output, index, tx, error.InvalidNotification);
        },
        .hold_invoice_accepted => |tx| {
            try validate_hold_notification_transaction(tx, error.InvalidNotification);
            try write_transaction_json(output, index, tx, error.InvalidNotification);
        },
    }
}

fn write_result_or_null_json(
    output: []u8,
    index: *u32,
    outcome: anytype,
    comptime writer_fn: anytype,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@TypeOf(writer_fn) == @TypeOf(writer_fn));

    switch (outcome) {
        .result => |result| try writer_fn(output, index, result),
        .err => try write_bytes(output, index, "null"),
    }
}

fn write_payment_result_payload(
    output: []u8,
    index: *u32,
    result: PaymentResult,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(PaymentResult) > 0);

    if (result.preimage.len == 0) return error.InvalidResult;
    try write_bytes(output, index, "{");
    var first = true;
    try write_string_field(
        output,
        index,
        &first,
        "preimage",
        result.preimage,
        error.InvalidResult,
    );
    if (result.fees_paid) |fees_paid| {
        try write_u64_field(output, index, &first, "fees_paid", fees_paid);
    }
    try write_bytes(output, index, "}");
}

fn write_make_invoice_payload(
    output: []u8,
    index: *u32,
    tx: Transaction,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(Transaction) > 0);

    try validate_make_invoice_transaction(tx, error.InvalidResponse);
    try write_transaction_json(output, index, tx, error.InvalidResponse);
}

fn write_lookup_transaction_payload(
    output: []u8,
    index: *u32,
    tx: Transaction,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(Transaction) > 0);

    try validate_lookup_transaction(tx, error.InvalidResponse);
    try write_transaction_json(output, index, tx, error.InvalidResponse);
}

fn write_make_hold_payload(output: []u8, index: *u32, tx: Transaction) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(Transaction) > 0);

    try validate_make_hold_transaction(tx, error.InvalidResponse);
    try write_transaction_json(output, index, tx, error.InvalidResponse);
}

fn write_transactions_payload(
    output: []u8,
    index: *u32,
    transactions: []const Transaction,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(transactions.len <= std.math.maxInt(usize));

    try write_bytes(output, index, "{\"transactions\":[");
    for (transactions, 0..) |tx, tx_index| {
        try validate_lookup_transaction(tx, error.InvalidResponse);
        if (tx_index != 0) try write_bytes(output, index, ",");
        try write_transaction_json(output, index, tx, error.InvalidResponse);
    }
    try write_bytes(output, index, "]}");
}

fn write_balance_payload(
    output: []u8,
    index: *u32,
    result: BalanceResult,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(BalanceResult) > 0);

    try write_bytes(output, index, "{\"balance\":");
    try write_u64(output, index, result.balance);
    try write_bytes(output, index, "}");
}

fn write_wallet_info_payload(
    output: []u8,
    index: *u32,
    result: WalletInfoResult,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(WalletInfoResult) > 0);

    if (result.methods.len == 0) return error.InvalidResult;
    try write_bytes(output, index, "{");
    var first = true;
    if (result.alias) |alias| {
        try write_string_field(output, index, &first, "alias", alias, error.InvalidResult);
    }
    if (result.color) |color| {
        try write_string_field(output, index, &first, "color", color, error.InvalidResult);
    }
    if (result.pubkey) |pubkey| {
        try write_hex32_field(output, index, &first, "pubkey", pubkey, error.InvalidResult);
    }
    if (result.network) |network| {
        try write_string_field(output, index, &first, "network", network, error.InvalidResult);
    }
    if (result.block_height) |height| {
        try write_u32_field(output, index, &first, "block_height", height);
    }
    if (result.block_hash) |block_hash| {
        try write_hex32_field(
            output,
            index,
            &first,
            "block_hash",
            block_hash,
            error.InvalidResult,
        );
    }
    try write_string_array_field(
        output,
        index,
        &first,
        "methods",
        result.methods,
        error.InvalidResult,
    );
    if (result.notifications.len != 0) {
        try write_string_array_field(
            output,
            index,
            &first,
            "notifications",
            result.notifications,
            error.InvalidResult,
        );
    }
    try write_bytes(output, index, "}");
}

fn write_empty_payload(output: []u8, index: *u32, _: void) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(void) == 0);

    try write_empty_object(output, index);
}

fn write_error_info_json(output: []u8, index: *u32, err_info: ErrorInfo) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(ErrorInfo) > 0);

    if (err_info.message.len == 0) return error.InvalidErrorObject;
    try write_bytes(output, index, "{");
    var first = true;
    try write_string_field(
        output,
        index,
        &first,
        "code",
        error_code_text(err_info.code),
        error.InvalidErrorObject,
    );
    try write_string_field(
        output,
        index,
        &first,
        "message",
        err_info.message,
        error.InvalidErrorObject,
    );
    try write_bytes(output, index, "}");
}

fn write_transaction_json(
    output: []u8,
    index: *u32,
    tx: Transaction,
    invalid_err: NwcError,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(Transaction) > 0);

    try write_bytes(output, index, "{");
    var first = true;
    if (tx.tx_type) |tx_type| {
        try write_string_field(
            output,
            index,
            &first,
            "type",
            transaction_type_text(tx_type),
            invalid_err,
        );
    }
    if (tx.state) |state| {
        try write_string_field(
            output,
            index,
            &first,
            "state",
            transaction_state_text(state),
            invalid_err,
        );
    }
    try write_transaction_string_fields(output, index, &first, tx, invalid_err);
    try write_transaction_numeric_fields(output, index, &first, tx);
    try write_bytes(output, index, "}");
}

fn write_transaction_string_fields(
    output: []u8,
    index: *u32,
    first: *bool,
    tx: Transaction,
    invalid_err: NwcError,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@intFromPtr(first) != 0);

    if (tx.invoice) |invoice| {
        try write_string_field(output, index, first, "invoice", invoice, invalid_err);
    }
    if (tx.description) |description| {
        try write_string_field(output, index, first, "description", description, invalid_err);
    }
    if (tx.description_hash) |description_hash| {
        try write_string_field(output, index, first, "description_hash", description_hash, invalid_err);
    }
    if (tx.preimage) |preimage| {
        try write_string_field(output, index, first, "preimage", preimage, invalid_err);
    }
    if (tx.payment_hash) |payment_hash| {
        try write_string_field(output, index, first, "payment_hash", payment_hash, invalid_err);
    }
}

fn write_transaction_numeric_fields(
    output: []u8,
    index: *u32,
    first: *bool,
    tx: Transaction,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@intFromPtr(first) != 0);

    if (tx.amount) |amount| try write_u64_field(output, index, first, "amount", amount);
    if (tx.fees_paid) |fees_paid| try write_u64_field(output, index, first, "fees_paid", fees_paid);
    if (tx.created_at) |created_at| {
        try write_u64_field(output, index, first, "created_at", created_at);
    }
    if (tx.expires_at) |expires_at| {
        try write_u64_field(output, index, first, "expires_at", expires_at);
    }
    if (tx.settled_at) |settled_at| {
        try write_u64_field(output, index, first, "settled_at", settled_at);
    }
    if (tx.settle_deadline) |settle_deadline| {
        try write_u32_field(output, index, first, "settle_deadline", settle_deadline);
    }
    if (tx.metadata) |metadata| {
        try write_json_value_field(output, index, first, "metadata", metadata);
    }
}

fn write_tlv_records_field(
    output: []u8,
    index: *u32,
    first: *bool,
    records: []const KeysendTlvRecord,
    invalid_err: NwcError,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@intFromPtr(first) != 0);

    try write_field_prefix(output, index, first, "tlv_records");
    try write_bytes(output, index, "[");
    for (records, 0..) |record, record_index| {
        if (record_index != 0) try write_bytes(output, index, ",");
        try write_bytes(output, index, "{");
        var record_first = true;
        try write_u64_field(output, index, &record_first, "type", record.tlv_type);
        try write_string_field(
            output,
            index,
            &record_first,
            "value",
            record.value,
            invalid_err,
        );
        try write_bytes(output, index, "}");
    }
    try write_bytes(output, index, "]");
}

fn write_string_array_field(
    output: []u8,
    index: *u32,
    first: *bool,
    name: []const u8,
    items: []const []const u8,
    invalid_err: NwcError,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@intFromPtr(first) != 0);

    try write_field_prefix(output, index, first, name);
    try write_bytes(output, index, "[");
    for (items, 0..) |item, item_index| {
        if (item_index != 0) try write_bytes(output, index, ",");
        try validate_json_text(item, false, invalid_err);
        try write_json_string(output, index, item);
    }
    try write_bytes(output, index, "]");
}

fn write_string_field(
    output: []u8,
    index: *u32,
    first: *bool,
    name: []const u8,
    value: []const u8,
    invalid_err: NwcError,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@intFromPtr(first) != 0);

    try validate_json_text(value, false, invalid_err);
    try write_field_prefix(output, index, first, name);
    try write_json_string(output, index, value);
}

fn write_hex32_field(
    output: []u8,
    index: *u32,
    first: *bool,
    name: []const u8,
    value: [32]u8,
    invalid_err: NwcError,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@intFromPtr(first) != 0);

    var buffer: [64]u8 = undefined;
    write_lower_hex(buffer[0..], value[0..]);
    try write_string_field(output, index, first, name, buffer[0..], invalid_err);
}

fn validate_json_text(text: []const u8, allow_empty: bool, invalid_err: NwcError) NwcError!void {
    std.debug.assert(text.len <= message_json_bytes_max);
    std.debug.assert(@TypeOf(allow_empty) == bool);

    if (!std.unicode.utf8ValidateSlice(text)) return invalid_err;
    if (!allow_empty and text.len == 0) return invalid_err;
    for (text) |byte| {
        if (byte == '\n' or byte == '\r' or byte == '\t') continue;
        if (byte < 0x20) return invalid_err;
    }
}

fn write_u64_field(
    output: []u8,
    index: *u32,
    first: *bool,
    name: []const u8,
    value: u64,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@intFromPtr(first) != 0);

    try write_field_prefix(output, index, first, name);
    try write_u64(output, index, value);
}

fn write_u32_field(
    output: []u8,
    index: *u32,
    first: *bool,
    name: []const u8,
    value: u32,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@intFromPtr(first) != 0);

    try write_field_prefix(output, index, first, name);
    try write_u32(output, index, value);
}

fn write_bool_field(
    output: []u8,
    index: *u32,
    first: *bool,
    name: []const u8,
    value: bool,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@intFromPtr(first) != 0);

    try write_field_prefix(output, index, first, name);
    try write_bytes(output, index, if (value) "true" else "false");
}

fn write_json_value_field(
    output: []u8,
    index: *u32,
    first: *bool,
    name: []const u8,
    value: std.json.Value,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@intFromPtr(first) != 0);

    _ = try parse_metadata_value(value, error.InvalidMetadata);
    try write_field_prefix(output, index, first, name);
    try write_json_value(output, index, value);
}

fn write_field_prefix(
    output: []u8,
    index: *u32,
    first: *bool,
    name: []const u8,
) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@intFromPtr(first) != 0);

    if (!first.*) try write_bytes(output, index, ",");
    first.* = false;
    try write_json_string(output, index, name);
    try write_bytes(output, index, ":");
}

fn write_empty_object(output: []u8, index: *u32) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(void) == 0);

    try write_bytes(output, index, "{}");
}

fn write_json_string(output: []u8, index: *u32, text: []const u8) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(text.len <= message_json_bytes_max);

    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidContent;
    try write_bytes(output, index, "\"");
    for (text) |byte| {
        switch (byte) {
            '\\' => try write_bytes(output, index, "\\\\"),
            '"' => try write_bytes(output, index, "\\\""),
            '\n' => try write_bytes(output, index, "\\n"),
            '\r' => try write_bytes(output, index, "\\r"),
            '\t' => try write_bytes(output, index, "\\t"),
            else => {
                if (byte < 0x20) return error.InvalidContent;
                try write_byte(output, index, byte);
            },
        }
    }
    try write_bytes(output, index, "\"");
}

fn write_json_value(output: []u8, index: *u32, value: std.json.Value) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    const start: usize = @intCast(index.*);
    var stream = std.io.fixedBufferStream(output[start..]);
    stream.writer().print("{f}", .{std.json.fmt(value, .{})}) catch {
        return error.BufferTooSmall;
    };
    index.* += @intCast(stream.pos);
}

fn write_u64(output: []u8, index: *u32, value: u64) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(u64) == 8);

    var buffer: [24]u8 = undefined;
    const rendered = std.fmt.bufPrint(buffer[0..], "{d}", .{value}) catch {
        return error.BufferTooSmall;
    };
    try write_bytes(output, index, rendered);
}

fn write_u32(output: []u8, index: *u32, value: u32) NwcError!void {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@sizeOf(u32) == 4);

    var buffer: [16]u8 = undefined;
    const rendered = std.fmt.bufPrint(buffer[0..], "{d}", .{value}) catch {
        return error.BufferTooSmall;
    };
    try write_bytes(output, index, rendered);
}

test "method and enum parsing cover supported kernel contract" {
    const overlong = [_]u8{'a'} ** (limits.tag_item_bytes_max + 1);

    try std.testing.expectEqual(Method.pay_invoice, try method_parse("pay_invoice"));
    try std.testing.expectEqual(Encryption.nip44_v2, try encryption_parse("nip44_v2"));
    try std.testing.expectEqual(
        NotificationType.hold_invoice_accepted,
        try notification_type_parse("hold_invoice_accepted"),
    );
    try std.testing.expectEqual(
        TransactionState.accepted,
        try transaction_state_parse("accepted"),
    );
    try std.testing.expectEqual(ErrorCode.unsupported_encryption, try error_code_parse(
        "UNSUPPORTED_ENCRYPTION",
    ));
    try std.testing.expectError(error.InvalidCapability, method_parse(overlong[0..]));
    try std.testing.expectError(error.InvalidEncryptionTag, encryption_parse(overlong[0..]));
    try std.testing.expectError(
        error.InvalidNotificationsTag,
        notification_type_parse(overlong[0..]),
    );
    try std.testing.expectError(error.InvalidErrorObject, error_code_parse(overlong[0..]));
    try std.testing.expectError(error.InvalidTransaction, transaction_type_parse(overlong[0..]));
    try std.testing.expectError(error.InvalidTransaction, transaction_state_parse(overlong[0..]));
    try std.testing.expectError(error.InvalidErrorObject, error_code_parse("UNKNOWN"));
    try std.testing.expectError(error.InvalidTransaction, transaction_type_parse("sideways"));
    try std.testing.expectError(error.InvalidTransaction, transaction_state_parse("queued"));
}

test "connection uri parse and format keep relay order and lowercase secrets" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var relays: [2][]const u8 = undefined;
    var output: [512]u8 = undefined;

    const parsed = try connection_uri_parse(
        "nostr+walletconnect://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
            "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two" ++
            "&secret=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ++
            "&lud16=alice%40example.com",
        relays[0..],
        arena.allocator(),
    );
    const rendered = try connection_uri_serialize(output[0..], parsed);

    try std.testing.expectEqualStrings("wss://relay.one", parsed.relays[0]);
    try std.testing.expectEqualStrings("wss://relay.two", parsed.relays[1]);
    try std.testing.expectEqualStrings("alice@example.com", parsed.lud16.?);
    try std.testing.expect(std.mem.startsWith(u8, rendered, uri_scheme));
}

test "nwc public uri paths reject overlong caller input with typed errors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var relays: [2][]const u8 = undefined;

    try std.testing.expectError(
        error.InvalidUri,
        connection_uri_parse(
            "nostr+walletconnect://" ++ ("a" ** 5000),
            relays[0..],
            arena.allocator(),
        ),
    );

    try std.testing.expectError(
        error.InvalidUri,
        connection_uri_parse(
            "nostr+walletconnect://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
                "?relay=" ++ ("a" ** 4097) ++
                "&secret=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            relays[0..],
            arena.allocator(),
        ),
    );
}

test "event extractors apply default encryption and strict tag rules" {
    const request_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "p", "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" } },
        .{ .items = &.{ "expiration", "1700000100" } },
    };
    const request_event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = request_event_kind,
        .created_at = 1_700_000_000,
        .content = "encrypted",
        .tags = request_tags[0..],
    };
    const response_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "p", "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" } },
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
    };
    const response_event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = response_event_kind,
        .created_at = 1_700_000_000,
        .content = "encrypted",
        .tags = response_tags[0..],
    };

    const request = try request_event_extract(&request_event);
    const response = try response_event_extract(&response_event);

    try std.testing.expectEqual(Encryption.nip04, request.encryption);
    try std.testing.expectEqual(@as(u64, 1_700_000_100), request.expiration.?);
    try std.testing.expectEqual(Encryption.nip04, response.encryption);
    try std.testing.expect(response.request_event_id[0] == 0xaa);
}

test "info event extract defaults missing encryption to nip04" {
    const info_event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = info_event_kind,
        .created_at = 1_700_000_000,
        .content = "pay_invoice notifications",
        .tags = &.{
            .{ .items = &.{ "notifications", "payment_received payment_sent" } },
        },
    };
    var capabilities: [4][]const u8 = undefined;
    var encryptions: [2]Encryption = undefined;
    var notifications: [2]NotificationType = undefined;

    const parsed = try info_event_extract(
        &info_event,
        capabilities[0..],
        encryptions[0..],
        notifications[0..],
    );

    try std.testing.expectEqual(@as(u16, 2), parsed.capability_count);
    try std.testing.expectEqual(@as(u8, 1), parsed.encryption_count);
    try std.testing.expectEqual(Encryption.nip04, encryptions[0]);
    try std.testing.expectEqualStrings("pay_invoice", capabilities[0]);
    try std.testing.expectEqual(NotificationType.payment_received, notifications[0]);
}

test "request json roundtrips pay_keysend with tlv records" {
    const input =
        \\{"method":"pay_keysend","params":{"id":"req-1","amount":21,"pubkey":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","preimage":"abcd","tlv_records":[{"type":5482373484,"value":"0011"}]}}
    ;
    var output: [512]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed = try request_parse_json(input, arena.allocator());
    const encoded = try request_serialize_json(output[0..], parsed);

    switch (parsed) {
        .pay_keysend => |request| {
            try std.testing.expectEqual(@as(u64, 21), request.amount);
            try std.testing.expectEqual(@as(usize, 1), request.tlv_records.len);
            try std.testing.expectEqual(@as(u64, 5_482_373_484), request.tlv_records[0].tlv_type);
        },
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"tlv_records\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"type\":5482373484") != null);
}

test "response json roundtrips get_info with raw methods and notifications" {
    const input =
        \\{"result_type":"get_info","error":null,"result":{"alias":"wallet","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","methods":["pay_invoice","future_capability"],"notifications":["payment_received"]}}
    ;
    var output: [512]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed = try response_parse_json(input, arena.allocator());
    const encoded = try response_serialize_json(output[0..], parsed);

    switch (parsed) {
        .get_info => |outcome| switch (outcome) {
            .result => |result| {
                try std.testing.expectEqualStrings("wallet", result.alias.?);
                try std.testing.expectEqual(@as(usize, 2), result.methods.len);
                try std.testing.expectEqualStrings("future_capability", result.methods[1]);
                try std.testing.expectEqual(@as(u8, 0xaa), result.pubkey.?[0]);
            },
            .err => return error.TestUnexpectedResult,
        },
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"future_capability\"") != null);
}

test "request parse keeps invalid param errors off generic content failures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidParams,
        request_parse_json(
            "{\"method\":\"pay_invoice\",\"params\":{\"invoice\":123}}",
            arena.allocator(),
        ),
    );
}

test "notification parse rejects mismatched transaction type for payment_received" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidNotification,
        notification_parse_json(
            "{\"notification_type\":\"payment_received\",\"notification\":{" ++
                "\"type\":\"outgoing\",\"invoice\":\"lnbc1\",\"preimage\":\"aa\",\"payment_hash\":\"bb\"," ++
                "\"amount\":1,\"fees_paid\":1,\"created_at\":1,\"settled_at\":2}}",
            arena.allocator(),
        ),
    );
}

test "response parse rejects error objects with non-null results" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidResponse,
        response_parse_json(
            "{\"result_type\":\"pay_invoice\",\"error\":{\"code\":\"OTHER\",\"message\":\"x\"}," ++
                "\"result\":{\"preimage\":\"abcd\"}}",
            arena.allocator(),
        ),
    );
}

test "request serializer keeps invalid UTF-8 on InvalidParams" {
    const invalid_invoice = [_]u8{0xff};
    var output: [128]u8 = undefined;

    try std.testing.expectError(
        error.InvalidParams,
        request_serialize_json(
            output[0..],
            .{ .pay_invoice = .{ .invoice = invalid_invoice[0..] } },
        ),
    );
}

const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const url_with_scheme = @import("internal/url_with_scheme.zig");

pub const recommendation_kind: u32 = 31989;
pub const handler_kind: u32 = 31990;

pub const HandlerError = error{
    InvalidRecommendationKind,
    InvalidHandlerKind,
    MissingSupportedKindTag,
    DuplicateSupportedKindTag,
    InvalidSupportedKindTag,
    InvalidHandlerReferenceTag,
    MissingIdentifierTag,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    MissingHandlerKindTag,
    InvalidEndpointTag,
    DuplicateClientTag,
    InvalidClientTag,
    BufferTooSmall,
};

pub const Reference = struct {
    pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
    platform: ?[]const u8 = null,
};

pub const Recommendation = struct {
    supported_kind: u32,
    handler_count: u16 = 0,
};

pub const HandlerEndpoint = struct {
    platform: []const u8,
    url_template: []const u8,
    entity_name: ?[]const u8 = null,
};

pub const Handler = struct {
    identifier: []const u8,
    content: []const u8,
    supported_kind_count: u16 = 0,
    endpoint_count: u16 = 0,
};

pub const ClientTag = struct {
    name: []const u8,
    handler: Reference,
    relay_hint: ?[]const u8 = null,
};

pub const BuiltTag = struct {
    items: [4][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded NIP-89 recommendation data from a kind-31989 event.
pub fn recommendation_extract(
    event: *const nip01_event.Event,
    out_handlers: []Reference,
) HandlerError!Recommendation {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_handlers.len <= limits.tags_max);

    if (event.kind != recommendation_kind) return error.InvalidRecommendationKind;

    var info = Recommendation{ .supported_kind = 0 };
    var saw_kind = false;
    for (event.tags) |tag| try apply_recommendation_tag(tag, &info, &saw_kind, out_handlers);
    if (!saw_kind) return error.MissingSupportedKindTag;
    return info;
}

/// Extracts bounded NIP-89 handler data from a kind-31990 event.
pub fn handler_extract(
    event: *const nip01_event.Event,
    out_supported_kinds: []u32,
    out_endpoints: []HandlerEndpoint,
) HandlerError!Handler {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_supported_kinds.len <= limits.tags_max);

    if (event.kind != handler_kind) return error.InvalidHandlerKind;

    var identifier: ?[]const u8 = null;
    var info = Handler{ .identifier = undefined, .content = event.content };
    for (event.tags) |tag| {
        try apply_handler_tag(tag, &identifier, &info, out_supported_kinds, out_endpoints);
    }
    if (info.supported_kind_count == 0) return error.MissingHandlerKindTag;
    info.identifier = identifier orelse return error.MissingIdentifierTag;
    return info;
}

/// Extracts the optional `client` tag from an arbitrary event.
pub fn client_extract(event: *const nip01_event.Event) HandlerError!?ClientTag {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    var parsed: ?ClientTag = null;
    for (event.tags) |tag| {
        if (tag.items.len == 0 or !std.mem.eql(u8, tag.items[0], "client")) continue;
        if (parsed != null) return error.DuplicateClientTag;
        parsed = parse_client_tag(tag) catch return error.InvalidClientTag;
    }
    return parsed;
}

/// Builds a canonical recommendation `d` tag naming the supported event kind.
pub fn recommendation_build_supported_kind_tag(
    output: *BuiltTag,
    supported_kind: u32,
) HandlerError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(supported_kind <= limits.kind_max);

    output.items[0] = "d";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{supported_kind}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical recommendation `a` tag referencing a kind-31990 handler.
pub fn recommendation_build_handler_tag(
    output: *BuiltTag,
    coordinate_text: []const u8,
    relay_hint: ?[]const u8,
    platform: ?[]const u8,
) HandlerError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 4);

    _ = parse_handler_coordinate(coordinate_text) catch return error.InvalidHandlerReferenceTag;
    output.items[0] = "a";
    output.items[1] = coordinate_text;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidHandlerReferenceTag;
        output.item_count = 3;
    }
    if (platform) |value| {
        output.items[output.item_count] = parse_platform(value) catch {
            return error.InvalidHandlerReferenceTag;
        };
        output.item_count += 1;
    }
    return output.as_event_tag();
}

/// Builds a canonical handler `d` tag.
pub fn handler_build_identifier_tag(
    output: *BuiltTag,
    identifier: []const u8,
) HandlerError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 4);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical handler `k` tag.
pub fn handler_build_supported_kind_tag(
    output: *BuiltTag,
    supported_kind: u32,
) HandlerError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(supported_kind <= limits.kind_max);

    output.items[0] = "k";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{supported_kind}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical handler endpoint tag such as `web`, `ios`, or `android`.
pub fn handler_build_endpoint_tag(
    output: *BuiltTag,
    platform: []const u8,
    url_template: []const u8,
    entity_name: ?[]const u8,
) HandlerError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 4);

    output.items[0] = parse_platform(platform) catch return error.InvalidEndpointTag;
    output.items[1] = parse_url(url_template) catch return error.InvalidEndpointTag;
    output.item_count = 2;
    if (entity_name) |value| {
        output.items[2] = parse_nonempty_utf8(value) catch return error.InvalidEndpointTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical `client` tag for arbitrary published events.
pub fn client_build_tag(
    output: *BuiltTag,
    name: []const u8,
    coordinate_text: []const u8,
    relay_hint: ?[]const u8,
) HandlerError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 4);

    output.items[0] = "client";
    output.items[1] = parse_nonempty_utf8(name) catch return error.InvalidClientTag;
    _ = parse_handler_coordinate(coordinate_text) catch return error.InvalidClientTag;
    output.items[2] = coordinate_text;
    output.item_count = 3;
    if (relay_hint) |value| {
        output.items[3] = parse_url(value) catch return error.InvalidClientTag;
        output.item_count = 4;
    }
    return output.as_event_tag();
}

fn apply_recommendation_tag(
    tag: nip01_event.EventTag,
    info: *Recommendation,
    saw_kind: *bool,
    out_handlers: []Reference,
) HandlerError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(saw_kind) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) {
        if (saw_kind.*) return error.DuplicateSupportedKindTag;
        info.supported_kind = parse_supported_kind_tag(tag) catch return error.InvalidSupportedKindTag;
        saw_kind.* = true;
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "a")) {
        if (info.handler_count == out_handlers.len) return error.BufferTooSmall;
        out_handlers[info.handler_count] = parse_handler_reference_tag(tag) catch {
            return error.InvalidHandlerReferenceTag;
        };
        info.handler_count += 1;
    }
}

fn apply_handler_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    info: *Handler,
    out_supported_kinds: []u32,
    out_endpoints: []HandlerEndpoint,
) HandlerError!void {
    std.debug.assert(@intFromPtr(identifier) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) {
        if (identifier.* != null) return error.DuplicateIdentifierTag;
        identifier.* = parse_identifier_tag(tag) catch return error.InvalidIdentifierTag;
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "k")) {
        if (info.supported_kind_count == out_supported_kinds.len) return error.BufferTooSmall;
        out_supported_kinds[info.supported_kind_count] = parse_handler_kind_tag(tag) catch {
            return error.InvalidSupportedKindTag;
        };
        info.supported_kind_count += 1;
        return;
    }
    if (info.endpoint_count == out_endpoints.len) return error.BufferTooSmall;
    out_endpoints[info.endpoint_count] = parse_endpoint_tag(tag) catch return error.InvalidEndpointTag;
    info.endpoint_count += 1;
}

fn parse_supported_kind_tag(tag: nip01_event.EventTag) error{InvalidTag}!u32 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len != 2) return error.InvalidTag;
    return std.fmt.parseUnsigned(u32, tag.items[1], 10) catch return error.InvalidTag;
}

fn parse_handler_reference_tag(tag: nip01_event.EventTag) error{InvalidTag}!Reference {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len < 2 or tag.items.len > 4) return error.InvalidTag;
    var parsed = parse_handler_coordinate(tag.items[1]) catch return error.InvalidTag;
    parsed.relay_hint = if (tag.items.len >= 3)
        parse_url(tag.items[2]) catch return error.InvalidTag
    else
        null;
    parsed.platform = if (tag.items.len == 4)
        parse_platform(tag.items[3]) catch return error.InvalidTag
    else
        null;
    return parsed;
}

fn parse_identifier_tag(tag: nip01_event.EventTag) error{InvalidTag}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len != 2) return error.InvalidTag;
    return parse_nonempty_utf8(tag.items[1]) catch return error.InvalidTag;
}

fn parse_handler_kind_tag(tag: nip01_event.EventTag) error{InvalidTag}!u32 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len != 2) return error.InvalidTag;
    return std.fmt.parseUnsigned(u32, tag.items[1], 10) catch return error.InvalidTag;
}

fn parse_endpoint_tag(tag: nip01_event.EventTag) error{InvalidTag}!HandlerEndpoint {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (std.mem.eql(u8, tag.items[0], "client")) return error.InvalidTag;
    if (tag.items.len < 2 or tag.items.len > 3) return error.InvalidTag;
    return .{
        .platform = parse_platform(tag.items[0]) catch return error.InvalidTag,
        .url_template = parse_url(tag.items[1]) catch return error.InvalidTag,
        .entity_name = if (tag.items.len == 3)
            parse_nonempty_utf8(tag.items[2]) catch return error.InvalidTag
        else
            null,
    };
}

fn parse_client_tag(tag: nip01_event.EventTag) error{InvalidTag}!ClientTag {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len < 3 or tag.items.len > 4) return error.InvalidTag;
    return .{
        .name = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidTag,
        .handler = parse_handler_coordinate(tag.items[2]) catch return error.InvalidTag,
        .relay_hint = if (tag.items.len == 4)
            parse_url(tag.items[3]) catch return error.InvalidTag
        else
            null,
    };
}

fn parse_handler_coordinate(text: []const u8) error{InvalidCoordinate}!Reference {
    std.debug.assert(limits.pubkey_hex_length == 64);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidCoordinate;
    const first_colon = std.mem.indexOfScalar(u8, text, ':') orelse return error.InvalidCoordinate;
    const second_rel = std.mem.indexOfScalar(u8, text[first_colon + 1 ..], ':') orelse {
        return error.InvalidCoordinate;
    };
    const second_colon = first_colon + second_rel + 1;
    if (first_colon == 0 or second_colon == first_colon + 1) return error.InvalidCoordinate;

    const kind = std.fmt.parseUnsigned(u32, text[0..first_colon], 10) catch {
        return error.InvalidCoordinate;
    };
    if (kind != handler_kind) return error.InvalidCoordinate;

    return .{
        .pubkey = lower_hex_32.parse(text[first_colon + 1 .. second_colon]) catch {
            return error.InvalidCoordinate;
        },
        .identifier = parse_nonempty_utf8(text[second_colon + 1 ..]) catch {
            return error.InvalidCoordinate;
        },
    };
}

fn parse_platform(text: []const u8) error{InvalidPlatform}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidPlatform;
    const platform = parse_nonempty_utf8(text) catch return error.InvalidPlatform;
    for (platform) |byte| {
        if (std.ascii.isWhitespace(byte) or byte == ':') return error.InvalidPlatform;
    }
    return platform;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidUtf8;
    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    return url_with_scheme.parse_utf8(text, limits.tag_item_bytes_max);
}

test "NIP-89 extracts recommendations and handlers" {
    const rec_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "31337" } },
        .{ .items = &.{ "a", "31990:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:zapstr", "wss://relay.one", "web" } },
    };
    const rec = nip01_event.Event{
        .id = [_]u8{0x89} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = recommendation_kind,
        .tags = rec_tags[0..],
        .content = "",
        .sig = [_]u8{0x22} ** 64,
    };
    var handlers: [1]Reference = undefined;
    const rec_info = try recommendation_extract(&rec, handlers[0..]);
    try std.testing.expectEqual(@as(u32, 31337), rec_info.supported_kind);
    try std.testing.expectEqualStrings("zapstr", handlers[0].identifier);

    const handler_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "zapstr" } },
        .{ .items = &.{ "k", "31337" } },
        .{ .items = &.{ "web", "https://zapstr.example/a/<bech32>", "nevent" } },
    };
    const handler = nip01_event.Event{
        .id = [_]u8{0x8a} ** 32,
        .pubkey = [_]u8{0x12} ** 32,
        .created_at = 2,
        .kind = handler_kind,
        .tags = handler_tags[0..],
        .content = "{\"name\":\"Zapstr\"}",
        .sig = [_]u8{0x23} ** 64,
    };
    var supported: [1]u32 = undefined;
    var endpoints: [1]HandlerEndpoint = undefined;
    const handler_info = try handler_extract(&handler, supported[0..], endpoints[0..]);
    try std.testing.expectEqualStrings("zapstr", handler_info.identifier);
    try std.testing.expectEqual(@as(u16, 1), handler_info.endpoint_count);
}

test "NIP-89 extracts and builds client tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "client", "My Client", "31990:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:client", "wss://relay.one" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x8b} ** 32,
        .pubkey = [_]u8{0x13} ** 32,
        .created_at = 3,
        .kind = 1,
        .tags = tags[0..],
        .content = "hello",
        .sig = [_]u8{0x24} ** 64,
    };
    const client = (try client_extract(&event)).?;
    try std.testing.expectEqualStrings("My Client", client.name);

    var built: BuiltTag = .{};
    const tag = try client_build_tag(
        &built,
        "My Client",
        "31990:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:client",
        null,
    );
    try std.testing.expectEqualStrings("client", tag.items[0]);
}

test "NIP-89 rejects overlong client coordinate input with typed error" {
    var built: BuiltTag = .{};
    const overlong = [_]u8{'a'} ** (limits.tag_item_bytes_max + 1);

    try std.testing.expectError(
        error.InvalidClientTag,
        client_build_tag(&built, "My Client", overlong[0..], null),
    );
}

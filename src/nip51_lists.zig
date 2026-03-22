const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const json_string_writer = @import("internal/json_string_writer.zig");
const nip44 = @import("nip44.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const relay_origin = @import("internal/relay_origin.zig");
const url_with_host = @import("internal/url_with_host.zig");
const websocket_relay_url = @import("internal/websocket_relay_url.zig");

pub const ListError = error{
    UnsupportedListKind,
    MissingIdentifier,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    DuplicateTitleTag,
    InvalidTitleTag,
    DuplicateImageTag,
    InvalidImageTag,
    DuplicateDescriptionTag,
    InvalidDescriptionTag,
    UnexpectedTag,
    InvalidPubkeyTag,
    InvalidPubkey,
    InvalidEventTag,
    InvalidEventId,
    InvalidCoordinateTag,
    InvalidCoordinate,
    InvalidHashtagTag,
    InvalidWordTag,
    InvalidRelayTag,
    InvalidRelayUrl,
    InvalidUrlTag,
    InvalidUrl,
    InvalidEmojiTag,
    BufferTooSmall,
};

pub const PrivateListError = ListError || nip44.ConversationEncryptionError || error{
    InvalidPrivateJson,
    InvalidPrivateTagArray,
    TooManyPrivateTags,
    TooManyPrivateTagItems,
    UnsupportedPrivateEncoding,
};

pub const ListKind = enum(u32) {
    mute_list = 10000,
    pinned_notes = 10001,
    bookmarks = 10003,
    communities = 10004,
    public_chats = 10005,
    blocked_relays = 10006,
    search_relays = 10007,
    interests = 10015,
    emojis = 10030,
    follow_set = 30000,
    relay_set = 30002,
    bookmark_set = 30003,
    articles_curation_set = 30004,
    interest_set = 30015,
    emoji_set = 30030,
};

pub const ListMetadata = struct {
    identifier: ?[]const u8 = null,
    title: ?[]const u8 = null,
    image: ?[]const u8 = null,
    description: ?[]const u8 = null,
};

pub const ListPubkey = struct {
    pubkey: [32]u8,
};

pub const ListEvent = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const ListCoordinate = struct {
    kind: u32,
    pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
};

pub const ListEmoji = struct {
    shortcode: []const u8,
    image_url: []const u8,
    set_coordinate: ?ListCoordinate = null,
};

pub const ListItem = union(enum) {
    pubkey: ListPubkey,
    event: ListEvent,
    coordinate: ListCoordinate,
    hashtag: []const u8,
    url: []const u8,
    word: []const u8,
    relay_url: []const u8,
    emoji: ListEmoji,
};

pub const ListInfo = struct {
    kind: ListKind,
    metadata: ListMetadata = .{},
    item_count: u16,
};

pub const PrivateListInfo = struct {
    kind: ListKind,
    item_count: u16,
    plaintext_json: []const u8,
};

pub const BuiltTag = struct {
    items: [4][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    /// Returns the built tag view backed by this buffer.
    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

pub const BookmarkBuilderItem = union(enum) {
    event: ListEvent,
    coordinate: ListCoordinate,
    hashtag: []const u8,
    url: []const u8,
};

const ItemFamily = enum {
    pubkey,
    event,
    coordinate,
    hashtag,
    url,
    word,
    relay_url,
    emoji,
};

/// Returns the supported strict NIP-51 list kind for `kind`, or `null` when unsupported.
pub fn list_kind_classify(kind: u32) ?ListKind {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(@sizeOf(ListKind) == @sizeOf(u32));

    return switch (kind) {
        10000 => .mute_list,
        10001 => .pinned_notes,
        10003 => .bookmarks,
        10004 => .communities,
        10005 => .public_chats,
        10006 => .blocked_relays,
        10007 => .search_relays,
        10015 => .interests,
        10030 => .emojis,
        30000 => .follow_set,
        30002 => .relay_set,
        30003 => .bookmark_set,
        30004 => .articles_curation_set,
        30015 => .interest_set,
        30030 => .emoji_set,
        else => null,
    };
}

/// Returns whether the event kind is supported by the strict NIP-51 public-list helper.
pub fn list_is_supported(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.kind <= limits.kind_max);

    return list_kind_classify(event.kind) != null;
}

/// Extracts strict public NIP-51 list items from a supported list event.
/// See `examples/nip51_example.zig` and `examples/private_lists_recipe.zig`.
///
/// Lifetime and ownership:
/// - `ListItem.pubkey` and `ListItem.event.event_id` are copied into `out`.
/// - metadata text, relay hints, URLs, hashtags, words, coordinates, and emoji shortcodes borrow
///   from `event.tags` item storage.
/// - Keep `event` and its tag item backing storage alive and unmodified while using `out`.
///
/// Scope note:
/// - Only public tag-carried list items are extracted here.
/// - Encrypted private list content in `event.content` is intentionally out of scope for this
///   strict Wave 1 helper and is ignored by this function.
pub fn list_extract(event: *const nip01_event.Event, out: []ListItem) ListError!ListInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out.len <= std.math.maxInt(u16));

    const kind = list_kind_classify(event.kind) orelse return error.UnsupportedListKind;
    var info = ListInfo{ .kind = kind, .item_count = 0 };
    var index: usize = 0;
    while (index < event.tags.len) : (index += 1) {
        const tag = event.tags[index];
        if (try apply_metadata_tag(kind, tag, &info.metadata)) {
            continue;
        }
        const parsed_item = parse_item_tag(kind, tag) catch |parse_error| switch (parse_error) {
            error.UnexpectedTag => continue,
            else => return parse_error,
        };
        if (info.item_count == out.len) {
            return error.BufferTooSmall;
        }
        out[info.item_count] = parsed_item;
        info.item_count += 1;
    }

    if (kind_requires_identifier(kind) and info.metadata.identifier == null) {
        return error.MissingIdentifier;
    }
    return info;
}

/// Builds a `d` tag for addressable list kinds.
pub fn list_build_identifier_tag(
    output: *BuiltTag,
    identifier: []const u8,
) ListError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a bookmark-family public item tag.
pub fn bookmark_build_tag(
    output: *BuiltTag,
    item: BookmarkBuilderItem,
) ListError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(&output.text_storage) != 0);

    return switch (item) {
        .event => |event| build_event_tag(output, "e", event),
        .coordinate => |coordinate| try build_coordinate_tag(output, "a", coordinate, false),
        .hashtag => |hashtag| try build_hashtag_tag(output, hashtag),
        .url => |url| try build_url_tag(output, url),
    };
}

/// Builds an `emoji` tag and includes the optional fourth-slot emoji-set coordinate when present.
pub fn emoji_build_tag(
    output: *BuiltTag,
    emoji: *const ListEmoji,
) ListError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(emoji) != 0);

    _ = parse_nonempty_utf8(emoji.shortcode) catch return error.InvalidEmojiTag;
    _ = parse_url(emoji.image_url) catch return error.InvalidEmojiTag;
    if (!shortcode_is_valid(emoji.shortcode)) {
        return error.InvalidEmojiTag;
    }

    output.items[0] = "emoji";
    output.items[1] = emoji.shortcode;
    output.items[2] = emoji.image_url;
    output.item_count = 3;
    if (emoji.set_coordinate) |coordinate| {
        if (coordinate.kind != 30030) {
            return error.InvalidEmojiTag;
        }
        output.items[3] = format_coordinate_text(
            output.text_storage[0..],
            coordinate,
            true,
        ) catch return error.InvalidEmojiTag;
        output.item_count = 4;
    }
    return output.as_event_tag();
}

/// Serializes private NIP-51 item tags into the encrypted JSON-array plaintext form.
pub fn list_private_serialize_json(
    output: []u8,
    tags: []const nip01_event.EventTag,
) PrivateListError![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(usize));
    std.debug.assert(tags.len <= std.math.maxInt(usize));

    if (tags.len > limits.tags_max) {
        return error.TooManyPrivateTags;
    }

    var stream = std.io.fixedBufferStream(output);
    const writer = stream.writer();
    try write_private_byte(writer, '[');
    for (tags, 0..) |tag, index| {
        if (index != 0) {
            try write_private_byte(writer, ',');
        }
        try write_private_tag_json(writer, tag);
    }
    try write_private_byte(writer, ']');
    return stream.getWritten();
}

/// Parses private NIP-51 item JSON into strict list items.
/// See `examples/private_lists_recipe.zig`.
pub fn list_private_extract_json(
    event_kind: u32,
    input_json: []const u8,
    out: []ListItem,
    scratch: std.mem.Allocator,
) PrivateListError!PrivateListInfo {
    std.debug.assert(event_kind <= limits.kind_max);
    std.debug.assert(out.len <= std.math.maxInt(u16));

    const kind = list_kind_classify(event_kind) orelse return error.UnsupportedListKind;
    return list_private_extract_json_kind(kind, input_json, out, scratch);
}

/// Decrypts strict NIP-44 private list content and parses the contained item JSON.
pub fn list_private_extract_nip44(
    plaintext_output: []u8,
    event: *const nip01_event.Event,
    author_private_key: *const [32]u8,
    out: []ListItem,
    scratch: std.mem.Allocator,
) PrivateListError!PrivateListInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(@intFromPtr(author_private_key) != 0);

    const kind = list_kind_classify(event.kind) orelse return error.UnsupportedListKind;
    if (event.content.len == 0) {
        return .{ .kind = kind, .item_count = 0, .plaintext_json = "" };
    }
    if (private_content_is_nip04_legacy(event.content)) {
        return error.UnsupportedPrivateEncoding;
    }

    var conversation_key = try nip44.nip44_get_conversation_key(author_private_key, &event.pubkey);
    defer std.crypto.secureZero(u8, conversation_key[0..]);

    const plaintext = try nip44.nip44_decrypt_from_base64(
        plaintext_output,
        &conversation_key,
        event.content,
    );
    return list_private_extract_json_kind(kind, plaintext, out, scratch);
}

fn apply_metadata_tag(
    kind: ListKind,
    tag: nip01_event.EventTag,
    metadata: *ListMetadata,
) ListError!bool {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (tag.items.len == 0) {
        return error.UnexpectedTag;
    }
    if (!kind_is_set(kind)) {
        return false;
    }

    const tag_name = tag.items[0];
    if (std.mem.eql(u8, tag_name, "d")) {
        try apply_identifier_tag(tag, metadata);
        return true;
    }
    if (std.mem.eql(u8, tag_name, "title")) {
        try apply_title_tag(tag, metadata);
        return true;
    }
    if (std.mem.eql(u8, tag_name, "image")) {
        try apply_image_tag(tag, metadata);
        return true;
    }
    if (std.mem.eql(u8, tag_name, "description")) {
        try apply_description_tag(tag, metadata);
        return true;
    }
    return false;
}

fn list_private_extract_json_kind(
    kind: ListKind,
    input_json: []const u8,
    out: []ListItem,
    scratch: std.mem.Allocator,
) PrivateListError!PrivateListInfo {
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));
    std.debug.assert(out.len <= std.math.maxInt(u16));

    const root = try parse_private_json_root(input_json, scratch);
    var info = PrivateListInfo{ .kind = kind, .item_count = 0, .plaintext_json = input_json };
    for (root.array.items) |tag_value| {
        const item = parse_private_json_tag(kind, tag_value) catch |err| switch (err) {
            error.UnexpectedTag => continue,
            else => return err,
        };
        if (info.item_count == out.len) {
            return error.BufferTooSmall;
        }
        out[info.item_count] = item;
        info.item_count += 1;
    }
    return info;
}

fn parse_private_json_root(
    input_json: []const u8,
    parse_allocator: std.mem.Allocator,
) PrivateListError!std.json.Value {
    std.debug.assert(input_json.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(parse_allocator.ptr) != 0);

    if (input_json.len == 0 or input_json.len > limits.content_bytes_max) {
        return error.InvalidPrivateJson;
    }
    if (!std.unicode.utf8ValidateSlice(input_json)) {
        return error.InvalidPrivateJson;
    }

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        parse_allocator,
        input_json,
        .{},
    ) catch {
        return error.InvalidPrivateJson;
    };
    if (root != .array) {
        return error.InvalidPrivateJson;
    }
    if (root.array.items.len > limits.tags_max) {
        return error.TooManyPrivateTags;
    }
    return root;
}

fn parse_private_json_tag(kind: ListKind, value: std.json.Value) PrivateListError!ListItem {
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (value != .array) {
        return error.InvalidPrivateTagArray;
    }
    if (value.array.items.len == 0) {
        return error.InvalidPrivateTagArray;
    }
    if (value.array.items.len > limits.tag_items_max) {
        return error.TooManyPrivateTagItems;
    }

    var items: [limits.tag_items_max][]const u8 = undefined;
    for (value.array.items, 0..) |item, index| {
        if (item != .string) {
            return error.InvalidPrivateTagArray;
        }
        try validate_private_tag_item(item.string);
        items[index] = item.string;
    }

    return parse_item_tag(kind, .{ .items = items[0..value.array.items.len] });
}

fn validate_private_tag_item(item: []const u8) PrivateListError!void {
    std.debug.assert(item.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (item.len > limits.tag_item_bytes_max) {
        return error.InvalidPrivateTagArray;
    }
    if (!std.unicode.utf8ValidateSlice(item)) {
        return error.InvalidPrivateTagArray;
    }
}

fn write_private_tag_json(writer: anytype, tag: nip01_event.EventTag) PrivateListError!void {
    std.debug.assert(tag.items.len <= std.math.maxInt(usize));
    std.debug.assert(@TypeOf(writer) != void);

    if (tag.items.len > limits.tag_items_max) {
        return error.TooManyPrivateTagItems;
    }

    try write_private_byte(writer, '[');
    for (tag.items, 0..) |item, index| {
        if (index != 0) {
            try write_private_byte(writer, ',');
        }
        try validate_private_tag_item(item);
        try write_private_string_json(writer, item);
    }
    try write_private_byte(writer, ']');
}

fn write_private_string_json(writer: anytype, value: []const u8) PrivateListError!void {
    std.debug.assert(value.len <= std.math.maxInt(usize));
    std.debug.assert(@TypeOf(writer) != void);

    json_string_writer.write_string_json(writer, value, .escape) catch |err| switch (err) {
        error.BufferTooSmall => return error.BufferTooSmall,
        error.InvalidControlByte => unreachable,
    };
}

fn write_private_escape(writer: anytype, escape_byte: u8) PrivateListError!void {
    std.debug.assert(@TypeOf(writer) != void);
    std.debug.assert(escape_byte > 0);

    try json_string_writer.write_escape(writer, escape_byte);
}

fn write_private_control_escape(writer: anytype, byte: u8) PrivateListError!void {
    std.debug.assert(@TypeOf(writer) != void);
    std.debug.assert(byte < 0x20);

    try json_string_writer.write_control_escape(writer, byte);
}

fn write_private_byte(writer: anytype, byte: u8) PrivateListError!void {
    std.debug.assert(@TypeOf(writer) != void);
    std.debug.assert(byte <= 255);

    try json_string_writer.write_byte(writer, byte);
}

test "private list JSON escapes control bytes in tag items" {
    var buffer: [32]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    try write_private_string_json(stream.writer(), &[_]u8{0x01});
    try std.testing.expectEqualStrings("\"\\u0001\"", buffer[0..stream.pos]);
}

fn private_content_is_nip04_legacy(content: []const u8) bool {
    std.debug.assert(content.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(u8) == 1);

    return std.mem.indexOf(u8, content, "?iv=") != null;
}

fn apply_identifier_tag(tag: nip01_event.EventTag, metadata: *ListMetadata) ListError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.identifier != null) {
        return error.DuplicateIdentifierTag;
    }
    metadata.identifier = try parse_single_utf8_value(tag, error.InvalidIdentifierTag);
}

fn apply_title_tag(tag: nip01_event.EventTag, metadata: *ListMetadata) ListError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.title != null) {
        return error.DuplicateTitleTag;
    }
    metadata.title = try parse_single_utf8_value(tag, error.InvalidTitleTag);
}

fn apply_image_tag(tag: nip01_event.EventTag, metadata: *ListMetadata) ListError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.image != null) {
        return error.DuplicateImageTag;
    }
    metadata.image = try parse_single_url_value(tag, error.InvalidImageTag);
}

fn apply_description_tag(tag: nip01_event.EventTag, metadata: *ListMetadata) ListError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.description != null) {
        return error.DuplicateDescriptionTag;
    }
    metadata.description = try parse_single_utf8_value(tag, error.InvalidDescriptionTag);
}

fn kind_is_set(kind: ListKind) bool {
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));
    std.debug.assert(!@inComptime());

    return switch (kind) {
        .follow_set,
        .relay_set,
        .bookmark_set,
        .articles_curation_set,
        .interest_set,
        .emoji_set,
        => true,
        else => false,
    };
}

fn kind_requires_identifier(kind: ListKind) bool {
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));
    std.debug.assert(!@inComptime());

    return kind_is_set(kind);
}

fn parse_item_tag(kind: ListKind, tag: nip01_event.EventTag) ListError!ListItem {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));

    if (tag.items.len == 0) {
        return error.UnexpectedTag;
    }

    const tag_name = tag.items[0];
    if (std.mem.eql(u8, tag_name, "p")) return parse_pubkey_item(kind, tag);
    if (std.mem.eql(u8, tag_name, "e")) return parse_event_item(kind, tag);
    if (std.mem.eql(u8, tag_name, "a")) return parse_coordinate_item(kind, tag);
    if (std.mem.eql(u8, tag_name, "t")) return parse_hashtag_item(kind, tag);
    if (std.mem.eql(u8, tag_name, "url")) return parse_url_item(kind, tag);
    if (std.mem.eql(u8, tag_name, "word")) return parse_word_item(kind, tag);
    if (std.mem.eql(u8, tag_name, "relay")) return parse_relay_item(kind, tag);
    if (std.mem.eql(u8, tag_name, "emoji")) return parse_emoji_item(kind, tag);
    return error.UnexpectedTag;
}

fn build_event_tag(
    output: *BuiltTag,
    tag_name: []const u8,
    event: ListEvent,
) ListError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(tag_name.len > 0);

    output.items[0] = tag_name;
    output.items[1] = write_lower_hex_32(output.text_storage[0..64], event.event_id);
    output.item_count = 2;
    if (event.relay_hint) |hint| {
        if ((parse_optional_hint(hint) catch return error.InvalidEventTag)) |normalized_hint| {
            output.items[2] = normalized_hint;
            output.item_count = 3;
        }
    }
    return output.as_event_tag();
}

fn build_coordinate_tag(
    output: *BuiltTag,
    tag_name: []const u8,
    coordinate: ListCoordinate,
    require_nonempty_identifier: bool,
) ListError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(tag_name.len > 0);

    output.items[0] = tag_name;
    output.items[1] = try format_coordinate_text(
        output.text_storage[0..],
        coordinate,
        require_nonempty_identifier,
    );
    output.item_count = 2;
    if (coordinate.relay_hint) |hint| {
        if ((parse_optional_hint(hint) catch return error.InvalidCoordinateTag)) |normalized_hint| {
            output.items[2] = normalized_hint;
            output.item_count = 3;
        }
    }
    return output.as_event_tag();
}

fn build_hashtag_tag(output: *BuiltTag, hashtag: []const u8) ListError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(hashtag.len <= limits.tag_item_bytes_max);

    _ = parse_nonempty_utf8(hashtag) catch return error.InvalidHashtagTag;
    if (has_ascii_whitespace(hashtag)) {
        return error.InvalidHashtagTag;
    }

    output.items[0] = "t";
    output.items[1] = hashtag;
    output.item_count = 2;
    return output.as_event_tag();
}

fn build_url_tag(output: *BuiltTag, url: []const u8) ListError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(url.len <= limits.tag_item_bytes_max);

    output.items[0] = "url";
    output.items[1] = try parse_url(url);
    output.item_count = 2;
    return output.as_event_tag();
}

fn parse_pubkey_item(kind: ListKind, tag: nip01_event.EventTag) ListError!ListItem {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));

    try require_family(kind, .pubkey);
    if (tag.items.len != 2) {
        return error.InvalidPubkeyTag;
    }
    return .{
        .pubkey = .{
            .pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidPubkey,
        },
    };
}

fn parse_event_item(kind: ListKind, tag: nip01_event.EventTag) ListError!ListItem {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));

    try require_family(kind, .event);
    if (tag.items.len < 2 or tag.items.len > 3) {
        return error.InvalidEventTag;
    }

    var parsed = ListEvent{
        .event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidEventId,
    };
    if (tag.items.len == 3) {
        parsed.relay_hint = parse_optional_hint(tag.items[2]) catch return error.InvalidEventTag;
    }
    return .{ .event = parsed };
}

fn parse_coordinate_item(kind: ListKind, tag: nip01_event.EventTag) ListError!ListItem {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));

    try require_family(kind, .coordinate);
    if (tag.items.len < 2 or tag.items.len > 3) {
        return error.InvalidCoordinateTag;
    }

    var parsed = parse_address_coordinate(tag.items[1]) catch return error.InvalidCoordinate;
    if (tag.items.len == 3) {
        parsed.relay_hint = parse_optional_hint(tag.items[2]) catch {
            return error.InvalidCoordinateTag;
        };
    }
    if (!coordinate_kind_matches_list(kind, parsed.kind)) {
        return error.InvalidCoordinate;
    }
    return .{ .coordinate = parsed };
}

fn parse_hashtag_item(kind: ListKind, tag: nip01_event.EventTag) ListError!ListItem {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));

    try require_family(kind, .hashtag);
    const value = try parse_single_utf8_value(tag, error.InvalidHashtagTag);
    if (has_ascii_whitespace(value)) {
        return error.InvalidHashtagTag;
    }
    return .{ .hashtag = value };
}

fn parse_url_item(kind: ListKind, tag: nip01_event.EventTag) ListError!ListItem {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));

    try require_family(kind, .url);
    const value = try parse_single_url_value(tag, error.InvalidUrlTag);
    return .{ .url = value };
}

fn parse_word_item(kind: ListKind, tag: nip01_event.EventTag) ListError!ListItem {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));

    try require_family(kind, .word);
    const value = try parse_single_utf8_value(tag, error.InvalidWordTag);
    if (contains_ascii_uppercase(value)) {
        return error.InvalidWordTag;
    }
    return .{ .word = value };
}

fn parse_relay_item(kind: ListKind, tag: nip01_event.EventTag) ListError!ListItem {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));

    try require_family(kind, .relay_url);
    const value = try parse_single_utf8_value(tag, error.InvalidRelayTag);
    _ = parse_relay_url(value) catch return error.InvalidRelayUrl;
    return .{ .relay_url = value };
}

fn parse_emoji_item(kind: ListKind, tag: nip01_event.EventTag) ListError!ListItem {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));

    try require_family(kind, .emoji);
    if (tag.items.len < 3 or tag.items.len > 4) {
        return error.InvalidEmojiTag;
    }

    var parsed = ListEmoji{
        .shortcode = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidEmojiTag,
        .image_url = parse_url(tag.items[2]) catch return error.InvalidEmojiTag,
    };
    if (!shortcode_is_valid(parsed.shortcode)) {
        return error.InvalidEmojiTag;
    }
    if (tag.items.len == 4) {
        const set_coordinate = parse_address_coordinate(tag.items[3]) catch {
            return error.InvalidEmojiTag;
        };
        if (set_coordinate.kind != 30030) {
            return error.InvalidEmojiTag;
        }
        parsed.set_coordinate = set_coordinate;
    }
    return .{ .emoji = parsed };
}

fn require_family(kind: ListKind, family: ItemFamily) ListError!void {
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));
    std.debug.assert(@intFromEnum(family) <= @intFromEnum(ItemFamily.emoji));

    if (!kind_allows_family(kind, family)) {
        return error.UnexpectedTag;
    }
}

fn kind_allows_family(kind: ListKind, family: ItemFamily) bool {
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));
    std.debug.assert(@intFromEnum(family) <= @intFromEnum(ItemFamily.emoji));

    return switch (kind) {
        .mute_list => mute_list_allows_family(family),
        .pinned_notes, .public_chats => family == .event,
        .bookmarks, .bookmark_set => {
            return family == .event or family == .coordinate or family == .hashtag or
                family == .url;
        },
        .communities => family == .coordinate,
        .articles_curation_set => family == .coordinate or family == .event,
        .blocked_relays, .search_relays, .relay_set => family == .relay_url,
        .interests => family == .hashtag or family == .coordinate,
        .emojis => family == .emoji or family == .coordinate,
        .follow_set => family == .pubkey,
        .interest_set => family == .hashtag,
        .emoji_set => family == .emoji,
    };
}

fn mute_list_allows_family(family: ItemFamily) bool {
    std.debug.assert(@intFromEnum(family) <= @intFromEnum(ItemFamily.emoji));
    std.debug.assert(!@inComptime());

    return family == .pubkey or family == .hashtag or family == .word or family == .event;
}

fn coordinate_kind_matches_list(kind: ListKind, coordinate_kind: u32) bool {
    std.debug.assert(@intFromEnum(kind) <= @intFromEnum(ListKind.emoji_set));
    std.debug.assert(coordinate_kind <= limits.kind_max);

    return switch (kind) {
        .bookmarks, .bookmark_set, .articles_curation_set => coordinate_kind == 30023,
        .communities => coordinate_kind == 34550,
        .interests => coordinate_kind == 30015,
        .emojis => coordinate_kind == 30030,
        else => true,
    };
}

fn parse_single_utf8_value(
    tag: nip01_event.EventTag,
    invalid_error: ListError,
) ListError![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@typeInfo(ListError) == .error_set);

    if (tag.items.len != 2) {
        return invalid_error;
    }
    return parse_nonempty_utf8(tag.items[1]) catch invalid_error;
}

fn parse_single_url_value(
    tag: nip01_event.EventTag,
    invalid_error: ListError,
) ListError![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@typeInfo(ListError) == .error_set);

    if (tag.items.len != 2) {
        return invalid_error;
    }
    return parse_url(tag.items[1]) catch invalid_error;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len >= 0);

    if (text.len == 0) {
        return error.InvalidUtf8;
    }
    if (!std.unicode.utf8ValidateSlice(text)) {
        return error.InvalidUtf8;
    }
    return text;
}

fn parse_optional_hint(text: []const u8) error{InvalidHint}!?[]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len >= 0);

    if (text.len == 0) {
        return null;
    }
    if (!std.unicode.utf8ValidateSlice(text)) {
        return error.InvalidHint;
    }
    return text;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.id_hex_length == 64);

    return lower_hex_32.parse(text);
}

fn parse_address_coordinate(text: []const u8) error{InvalidCoordinate}!ListCoordinate {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    const first_colon = std.mem.indexOfScalar(u8, text, ':') orelse {
        return error.InvalidCoordinate;
    };
    if (first_colon == 0) {
        return error.InvalidCoordinate;
    }

    const second_rel = std.mem.indexOfScalar(u8, text[first_colon + 1 ..], ':') orelse {
        return error.InvalidCoordinate;
    };
    const second_colon = first_colon + second_rel + 1;
    if (second_colon == first_colon + 1) {
        return error.InvalidCoordinate;
    }

    const kind = std.fmt.parseUnsigned(u32, text[0..first_colon], 10) catch {
        return error.InvalidCoordinate;
    };
    if (kind > limits.kind_max) {
        return error.InvalidCoordinate;
    }

    const pubkey = parse_lower_hex_32(text[first_colon + 1 .. second_colon]) catch {
        return error.InvalidCoordinate;
    };
    const identifier = text[second_colon + 1 ..];
    return .{ .kind = kind, .pubkey = pubkey, .identifier = identifier };
}

fn format_coordinate_text(
    output: []u8,
    coordinate: ListCoordinate,
    require_nonempty_identifier: bool,
) ListError![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(coordinate.kind <= limits.kind_max);

    if (require_nonempty_identifier and coordinate.identifier.len == 0) {
        return error.InvalidCoordinate;
    }
    if (!std.unicode.utf8ValidateSlice(coordinate.identifier)) {
        return error.InvalidCoordinate;
    }

    const pubkey_hex = std.fmt.bytesToHex(coordinate.pubkey, .lower);
    return std.fmt.bufPrint(
        output,
        "{d}:{s}:{s}",
        .{ coordinate.kind, pubkey_hex[0..], coordinate.identifier },
    ) catch error.InvalidCoordinate;
}

fn write_lower_hex_32(output: []u8, value: [32]u8) []const u8 {
    std.debug.assert(output.len >= limits.id_hex_length);
    std.debug.assert(limits.id_hex_length == 64);

    const hex = std.fmt.bytesToHex(value, .lower);
    @memcpy(output[0..limits.id_hex_length], hex[0..]);
    return output[0..limits.id_hex_length];
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len >= 0);

    return url_with_host.parse(text, limits.tag_item_bytes_max);
}

fn parse_relay_url(text: []const u8) error{InvalidRelayUrl}!relay_origin.WebsocketOrigin {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len >= 0);

    return websocket_relay_url.parse_origin(text, limits.tag_item_bytes_max);
}

fn shortcode_is_valid(shortcode: []const u8) bool {
    std.debug.assert(shortcode.len <= limits.tag_item_bytes_max);
    std.debug.assert(shortcode.len >= 0);

    if (shortcode.len == 0) {
        return false;
    }
    for (shortcode) |byte| {
        const is_alpha = (byte >= 'a' and byte <= 'z') or (byte >= 'A' and byte <= 'Z');
        const is_digit = byte >= '0' and byte <= '9';
        if (is_alpha or is_digit or byte == '_') {
            continue;
        }
        return false;
    }
    return true;
}

fn contains_ascii_uppercase(text: []const u8) bool {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len >= 0);

    for (text) |byte| {
        if (byte >= 'A' and byte <= 'Z') {
            return true;
        }
    }
    return false;
}

fn has_ascii_whitespace(text: []const u8) bool {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len >= 0);

    for (text) |byte| {
        if (byte == ' ' or byte == '\t' or byte == '\n' or byte == '\r') {
            return true;
        }
    }
    return false;
}

fn list_event(
    kind: u32,
    content: []const u8,
    tags: []const nip01_event.EventTag,
) nip01_event.Event {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(content.len <= limits.content_bytes_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = 0,
        .content = content,
        .tags = tags,
    };
}

fn list_event_with_pubkey(
    kind: u32,
    pubkey: [32]u8,
    content: []const u8,
    tags: []const nip01_event.EventTag,
) nip01_event.Event {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(content.len <= limits.content_bytes_max);

    var event = list_event(kind, content, tags);
    event.pubkey = pubkey;
    return event;
}

fn parse_hex_32_test(hex: []const u8) ![32]u8 {
    std.debug.assert(hex.len <= std.math.maxInt(usize));
    std.debug.assert(limits.id_hex_length == 64);

    var output: [32]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 64), hex.len);
    _ = try std.fmt.hexToBytes(&output, hex);
    return output;
}

fn expect_single_tag_error(
    expected: ListError,
    kind: u32,
    tag_items: []const []const u8,
) !void {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(tag_items.len <= limits.tag_items_max);

    const tags = [_]nip01_event.EventTag{.{ .items = tag_items }};
    var items: [1]ListItem = undefined;
    try std.testing.expectError(
        expected,
        list_extract(&list_event(kind, "", tags[0..]), items[0..]),
    );
}

fn expect_list_success(
    event: *const nip01_event.Event,
    out: []ListItem,
    expected_kind: ListKind,
    expected_count: u16,
) !ListInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out.len <= std.math.maxInt(u16));

    const parsed = try list_extract(event, out);
    try std.testing.expectEqual(expected_kind, parsed.kind);
    try std.testing.expectEqual(expected_count, parsed.item_count);
    return parsed;
}

fn expect_tag_items(tag: nip01_event.EventTag, expected: []const []const u8) !void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(expected.len <= limits.tag_items_max);

    try std.testing.expectEqual(expected.len, tag.items.len);
    for (expected, 0..) |item, index| {
        try std.testing.expectEqualStrings(item, tag.items[index]);
    }
}

test "list kind classify covers supported and unsupported kinds" {
    try std.testing.expectEqual(ListKind.mute_list, list_kind_classify(10000).?);
    try std.testing.expectEqual(ListKind.bookmark_set, list_kind_classify(30003).?);
    try std.testing.expectEqual(@as(?ListKind, null), list_kind_classify(30005));
}

test "list extract valid mute list preserves item order" {
    const p_tag = [_][]const u8{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const t_tag = [_][]const u8{ "t", "nostr" };
    const word_tag = [_][]const u8{ "word", "spam phrase" };
    const e_tag = [_][]const u8{
        "e",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        "wss://relay.example",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = p_tag[0..] },
        .{ .items = t_tag[0..] },
        .{ .items = word_tag[0..] },
        .{ .items = e_tag[0..] },
    };
    const event = list_event(10000, "opaque encrypted content", tags[0..]);
    var items: [4]ListItem = undefined;

    const parsed = try list_extract(&event, items[0..]);

    try std.testing.expectEqual(ListKind.mute_list, parsed.kind);
    try std.testing.expectEqual(@as(u16, 4), parsed.item_count);
    try std.testing.expect(items[0] == .pubkey);
    try std.testing.expect(items[1] == .hashtag);
    try std.testing.expect(items[2] == .word);
    try std.testing.expect(items[3] == .event);
    try std.testing.expect(items[0].pubkey.pubkey[0] == 0xaa);
    try std.testing.expectEqualStrings("nostr", items[1].hashtag);
    try std.testing.expectEqualStrings("spam phrase", items[2].word);
    try std.testing.expect(items[3].event.event_id[0] == 0xbb);
    try std.testing.expectEqualStrings("wss://relay.example", items[3].event.relay_hint.?);
}

test "bookmark builders emit bounded identifier event and coordinate tags" {
    var identifier_tag: BuiltTag = .{};
    var event_tag: BuiltTag = .{};
    var coordinate_tag: BuiltTag = .{};

    const built_identifier = try list_build_identifier_tag(&identifier_tag, "saved");
    const built_event = try bookmark_build_tag(&event_tag, .{
        .event = .{
            .event_id = [_]u8{0xaa} ** 32,
            .relay_hint = "wss://relay.example",
        },
    });
    const built_coordinate = try bookmark_build_tag(&coordinate_tag, .{
        .coordinate = .{
            .kind = 30023,
            .pubkey = [_]u8{0xbb} ** 32,
            .identifier = "yak",
            .relay_hint = "wss://relay.article",
        },
    });

    try expect_tag_items(built_identifier, &.{ "d", "saved" });
    try expect_tag_items(
        built_event,
        &.{
            "e",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "wss://relay.example",
        },
    );
    try expect_tag_items(
        built_coordinate,
        &.{
            "a",
            "30023:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:yak",
            "wss://relay.article",
        },
    );
}

test "bookmark and emoji builders widen emission and bookmark extraction accepts breadth" {
    var hashtag_tag: BuiltTag = .{};
    var url_tag: BuiltTag = .{};
    var emoji_tag: BuiltTag = .{};
    var items: [2]ListItem = undefined;

    const built_hashtag = try bookmark_build_tag(&hashtag_tag, .{ .hashtag = "nostr" });
    const built_url = try bookmark_build_tag(&url_tag, .{ .url = "https://example.com/post" });
    const built_emoji = try emoji_build_tag(&emoji_tag, &.{
        .shortcode = "soapbox",
        .image_url = "https://cdn.example/soapbox.png",
        .set_coordinate = .{
            .kind = 30030,
            .pubkey = [_]u8{0xcc} ** 32,
            .identifier = "icons",
        },
    });
    const tags = [_]nip01_event.EventTag{ built_hashtag, built_url };

    try expect_tag_items(built_hashtag, &.{ "t", "nostr" });
    try expect_tag_items(built_url, &.{ "url", "https://example.com/post" });
    try expect_tag_items(
        built_emoji,
        &.{
            "emoji",
            "soapbox",
            "https://cdn.example/soapbox.png",
            "30030:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc:icons",
        },
    );
    const parsed = try list_extract(&list_event(10003, "", tags[0..]), items[0..]);
    try std.testing.expectEqual(ListKind.bookmarks, parsed.kind);
    try std.testing.expectEqual(@as(u16, 2), parsed.item_count);
    try std.testing.expect(items[0] == .hashtag);
    try std.testing.expect(items[1] == .url);
    try std.testing.expectEqualStrings("nostr", items[0].hashtag);
    try std.testing.expectEqualStrings("https://example.com/post", items[1].url);
}

test "bookmark and emoji builders reject invalid inputs" {
    var identifier_tag: BuiltTag = .{};
    var hashtag_tag: BuiltTag = .{};
    var url_tag: BuiltTag = .{};
    var emoji_tag: BuiltTag = .{};

    try std.testing.expectError(
        error.InvalidIdentifierTag,
        list_build_identifier_tag(&identifier_tag, ""),
    );
    try std.testing.expectError(
        error.InvalidHashtagTag,
        bookmark_build_tag(&hashtag_tag, .{ .hashtag = "bad tag" }),
    );
    try std.testing.expectError(
        error.InvalidUrl,
        bookmark_build_tag(&url_tag, .{ .url = "not a url" }),
    );
    try std.testing.expectError(
        error.InvalidEmojiTag,
        emoji_build_tag(&emoji_tag, &.{
            .shortcode = "soapbox",
            .image_url = "https://cdn.example/soapbox.png",
            .set_coordinate = .{
                .kind = 30030,
                .pubkey = [_]u8{0xdd} ** 32,
                .identifier = "",
            },
        }),
    );
}

test "list extract valid bookmark set captures metadata and mixed item families" {
    const d_tag = [_][]const u8{ "d", "saved" };
    const title_tag = [_][]const u8{ "title", "Saved Items" };
    const image_tag = [_][]const u8{ "image", "https://cdn.example/saved.png" };
    const description_tag = [_][]const u8{ "description", "bookmark set" };
    const e_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const a_tag = [_][]const u8{
        "a",
        "30023:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:article",
        "wss://relay.article",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = d_tag[0..] },
        .{ .items = title_tag[0..] },
        .{ .items = image_tag[0..] },
        .{ .items = description_tag[0..] },
        .{ .items = e_tag[0..] },
        .{ .items = a_tag[0..] },
    };
    const event = list_event(30003, "", tags[0..]);
    var items: [2]ListItem = undefined;

    const parsed = try list_extract(&event, items[0..]);

    try std.testing.expectEqual(ListKind.bookmark_set, parsed.kind);
    try std.testing.expectEqualStrings("saved", parsed.metadata.identifier.?);
    try std.testing.expectEqualStrings("Saved Items", parsed.metadata.title.?);
    try std.testing.expectEqualStrings("https://cdn.example/saved.png", parsed.metadata.image.?);
    try std.testing.expectEqualStrings("bookmark set", parsed.metadata.description.?);
    try std.testing.expectEqual(@as(u16, 2), parsed.item_count);
    try std.testing.expect(items[0] == .event);
    try std.testing.expect(items[1] == .coordinate);
    try std.testing.expect(items[1].coordinate.kind == 30023);
    try std.testing.expectEqualStrings("article", items[1].coordinate.identifier);
}

test "list extract valid emoji and interest lists remain deterministic" {
    const emoji_tag = [_][]const u8{
        "emoji",
        "soapbox",
        "https://cdn.example/soapbox.png",
        "30030:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd:icons",
    };
    const emoji_set_d = [_][]const u8{ "d", "icons" };
    const interest_t = [_][]const u8{ "t", "zig" };
    const interest_a = [_][]const u8{
        "a",
        "30015:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc:systems",
    };
    const emoji_tags = [_]nip01_event.EventTag{
        .{ .items = emoji_set_d[0..] },
        .{ .items = emoji_tag[0..] },
    };
    const interest_tags = [_]nip01_event.EventTag{
        .{ .items = interest_t[0..] },
        .{ .items = interest_a[0..] },
    };
    const emoji_event = list_event(30030, "", emoji_tags[0..]);
    const interests_event = list_event(10015, "", interest_tags[0..]);
    var emoji_items: [1]ListItem = undefined;
    var interest_items: [2]ListItem = undefined;

    const first_emoji = try list_extract(&emoji_event, emoji_items[0..]);
    const second_emoji = try list_extract(&emoji_event, emoji_items[0..]);
    const interests = try list_extract(&interests_event, interest_items[0..]);

    try std.testing.expectEqual(first_emoji.kind, second_emoji.kind);
    try std.testing.expectEqual(first_emoji.item_count, second_emoji.item_count);
    try std.testing.expectEqualStrings("icons", first_emoji.metadata.identifier.?);
    try std.testing.expect(emoji_items[0] == .emoji);
    try std.testing.expectEqualStrings("soapbox", emoji_items[0].emoji.shortcode);
    try std.testing.expect(emoji_items[0].emoji.set_coordinate != null);
    try std.testing.expect(emoji_items[0].emoji.set_coordinate.?.kind == 30030);
    try std.testing.expectEqual(ListKind.interests, interests.kind);
    try std.testing.expectEqual(@as(u16, 2), interests.item_count);
    try std.testing.expect(interest_items[0] == .hashtag);
    try std.testing.expect(interest_items[1] == .coordinate);
    try std.testing.expectEqualStrings("zig", interest_items[0].hashtag);
}

test "list extract valid remaining supported public list kinds" {
    const pinned_e = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const community_a = [_][]const u8{
        "a",
        "34550:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:garden",
    };
    const relay_tag = [_][]const u8{ "relay", "wss://relay.example" };
    const follow_d = [_][]const u8{ "d", "team" };
    const follow_p = [_][]const u8{
        "p",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    };
    const articles_d = [_][]const u8{ "d", "essays" };
    const article_a = [_][]const u8{
        "a",
        "30023:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc:yak",
    };
    const article_e = [_][]const u8{
        "e",
        "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
    };
    const interest_set_d = [_][]const u8{ "d", "topics" };
    const interest_set_t = [_][]const u8{ "t", "nostr" };

    const pinned_tags = [_]nip01_event.EventTag{.{ .items = pinned_e[0..] }};
    const community_tags = [_]nip01_event.EventTag{.{ .items = community_a[0..] }};
    const relay_tags = [_]nip01_event.EventTag{.{ .items = relay_tag[0..] }};
    const follow_tags = [_]nip01_event.EventTag{
        .{ .items = follow_d[0..] },
        .{ .items = follow_p[0..] },
    };
    const article_tags = [_]nip01_event.EventTag{
        .{ .items = articles_d[0..] },
        .{ .items = article_a[0..] },
        .{ .items = article_e[0..] },
    };
    const interest_set_tags = [_]nip01_event.EventTag{
        .{ .items = interest_set_d[0..] },
        .{ .items = interest_set_t[0..] },
    };

    var event_items: [1]ListItem = undefined;
    var coordinate_items: [1]ListItem = undefined;
    var relay_items: [1]ListItem = undefined;
    var follow_items: [1]ListItem = undefined;
    var article_items: [2]ListItem = undefined;
    var interest_set_items: [1]ListItem = undefined;

    const pinned = try list_extract(&list_event(10001, "", pinned_tags[0..]), event_items[0..]);
    const communities = try list_extract(
        &list_event(10004, "", community_tags[0..]),
        coordinate_items[0..],
    );
    const blocked_relays = try list_extract(
        &list_event(10006, "", relay_tags[0..]),
        relay_items[0..],
    );
    const follow_set = try list_extract(
        &list_event(30000, "", follow_tags[0..]),
        follow_items[0..],
    );
    const article_set = try list_extract(
        &list_event(30004, "", article_tags[0..]),
        article_items[0..],
    );
    const interest_set = try list_extract(
        &list_event(30015, "", interest_set_tags[0..]),
        interest_set_items[0..],
    );

    try std.testing.expectEqual(ListKind.pinned_notes, pinned.kind);
    try std.testing.expectEqual(@as(u16, 1), pinned.item_count);
    try std.testing.expect(event_items[0] == .event);
    try std.testing.expectEqual(ListKind.communities, communities.kind);
    try std.testing.expect(coordinate_items[0] == .coordinate);
    try std.testing.expect(coordinate_items[0].coordinate.kind == 34550);
    try std.testing.expectEqual(ListKind.blocked_relays, blocked_relays.kind);
    try std.testing.expect(relay_items[0] == .relay_url);
    try std.testing.expectEqualStrings("wss://relay.example", relay_items[0].relay_url);
    try std.testing.expectEqual(ListKind.follow_set, follow_set.kind);
    try std.testing.expectEqualStrings("team", follow_set.metadata.identifier.?);
    try std.testing.expect(follow_items[0] == .pubkey);
    try std.testing.expectEqual(ListKind.articles_curation_set, article_set.kind);
    try std.testing.expectEqualStrings("essays", article_set.metadata.identifier.?);
    try std.testing.expect(article_items[0] == .coordinate);
    try std.testing.expect(article_items[1] == .event);
    try std.testing.expectEqual(ListKind.interest_set, interest_set.kind);
    try std.testing.expectEqualStrings("topics", interest_set.metadata.identifier.?);
    try std.testing.expect(interest_set_items[0] == .hashtag);
}

test "list extract valid supported event and relay kinds remain strict" {
    const event_id = "abababababababababababababababababababababababababababababababab";
    const relay_url = "wss://relay.example";
    const event_tag = [_][]const u8{ "e", event_id, relay_url };
    const relay_tag = [_][]const u8{ "relay", relay_url };
    const single_event_tags = [_]nip01_event.EventTag{.{ .items = event_tag[0..] }};
    const single_relay_tags = [_]nip01_event.EventTag{.{ .items = relay_tag[0..] }};
    var event_items: [1]ListItem = undefined;
    var relay_items: [1]ListItem = undefined;

    _ = try expect_list_success(
        &list_event(10001, "", single_event_tags[0..]),
        event_items[0..],
        .pinned_notes,
        1,
    );
    _ = try expect_list_success(
        &list_event(10005, "", single_event_tags[0..]),
        event_items[0..],
        .public_chats,
        1,
    );
    _ = try expect_list_success(
        &list_event(10006, "", single_relay_tags[0..]),
        relay_items[0..],
        .blocked_relays,
        1,
    );
    _ = try expect_list_success(
        &list_event(10007, "", single_relay_tags[0..]),
        relay_items[0..],
        .search_relays,
        1,
    );

    try std.testing.expect(event_items[0] == .event);
    try std.testing.expectEqualStrings(relay_url, event_items[0].event.relay_hint.?);
    try std.testing.expect(relay_items[0] == .relay_url);
    try std.testing.expectEqualStrings(relay_url, relay_items[0].relay_url);
}

test "list extract valid bookmark emoji and community kinds stay aligned" {
    const bookmark_event = [_][]const u8{
        "e",
        "1212121212121212121212121212121212121212121212121212121212121212",
    };
    const emoji_tag = [_][]const u8{
        "emoji",
        "soapbox",
        "https://cdn.example/soapbox.png",
    };
    const emoji_coordinate = [_][]const u8{
        "a",
        "30030:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd:icons",
    };
    const community_coordinate = [_][]const u8{
        "a",
        "34550:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee:zig",
    };
    const bookmark_tags = [_]nip01_event.EventTag{.{ .items = bookmark_event[0..] }};
    const emoji_tags = [_]nip01_event.EventTag{
        .{ .items = emoji_tag[0..] },
        .{ .items = emoji_coordinate[0..] },
    };
    const community_tags = [_]nip01_event.EventTag{.{ .items = community_coordinate[0..] }};
    var bookmark_items: [1]ListItem = undefined;
    var emoji_items: [2]ListItem = undefined;
    var community_items: [1]ListItem = undefined;

    _ = try expect_list_success(&list_event(10003, "", bookmark_tags[0..]), bookmark_items[0..], .bookmarks, 1);
    _ = try expect_list_success(&list_event(10030, "", emoji_tags[0..]), emoji_items[0..], .emojis, 2);
    _ = try expect_list_success(
        &list_event(10004, "", community_tags[0..]),
        community_items[0..],
        .communities,
        1,
    );

    try std.testing.expect(bookmark_items[0] == .event);
    try std.testing.expect(emoji_items[0] == .emoji);
    try std.testing.expect(emoji_items[1] == .coordinate);
    try std.testing.expect(community_items[0] == .coordinate);
}

test "list extract valid supported set kinds remain deterministic" {
    const d_team = [_][]const u8{ "d", "team" };
    const d_relays = [_][]const u8{ "d", "relays" };
    const d_topics = [_][]const u8{ "d", "topics" };
    const d_articles = [_][]const u8{ "d", "articles" };
    const pubkey_tag = [_][]const u8{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const relay_tag = [_][]const u8{ "relay", "wss://relay.example" };
    const hashtag_tag = [_][]const u8{ "t", "zig" };
    const article_coordinate = [_][]const u8{
        "a",
        "30023:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:yak",
    };
    const event_tag = [_][]const u8{
        "e",
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    };
    const follow_tags = [_]nip01_event.EventTag{ .{ .items = d_team[0..] }, .{ .items = pubkey_tag[0..] } };
    const relay_tags = [_]nip01_event.EventTag{ .{ .items = d_relays[0..] }, .{ .items = relay_tag[0..] } };
    const interest_tags = [_]nip01_event.EventTag{ .{ .items = d_topics[0..] }, .{ .items = hashtag_tag[0..] } };
    const curation_tags = [_]nip01_event.EventTag{
        .{ .items = d_articles[0..] },
        .{ .items = article_coordinate[0..] },
        .{ .items = event_tag[0..] },
    };
    var one_item: [1]ListItem = undefined;
    var two_items: [2]ListItem = undefined;

    const follow = try expect_list_success(&list_event(30000, "", follow_tags[0..]), one_item[0..], .follow_set, 1);
    const relay = try expect_list_success(&list_event(30002, "", relay_tags[0..]), one_item[0..], .relay_set, 1);
    const interest = try expect_list_success(&list_event(30015, "", interest_tags[0..]), one_item[0..], .interest_set, 1);
    const curation = try expect_list_success(
        &list_event(30004, "", curation_tags[0..]),
        two_items[0..],
        .articles_curation_set,
        2,
    );

    try std.testing.expectEqualStrings("team", follow.metadata.identifier.?);
    try std.testing.expectEqualStrings("relays", relay.metadata.identifier.?);
    try std.testing.expectEqualStrings("topics", interest.metadata.identifier.?);
    try std.testing.expectEqualStrings("articles", curation.metadata.identifier.?);
}

test "list extract rejects unsupported kinds and missing identifier" {
    const unsupported = list_event(30005, "", &.{});
    const p_tag = [_][]const u8{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const missing_d_tags = [_]nip01_event.EventTag{.{ .items = p_tag[0..] }};
    const missing_d_event = list_event(30000, "", missing_d_tags[0..]);
    var items: [1]ListItem = undefined;

    try std.testing.expectError(
        error.UnsupportedListKind,
        list_extract(&unsupported, items[0..]),
    );
    try std.testing.expectError(
        error.MissingIdentifier,
        list_extract(&missing_d_event, items[0..]),
    );
}

test "list extract rejects duplicate metadata and ignores unknown tags" {
    const d_one = [_][]const u8{ "d", "a" };
    const d_two = [_][]const u8{ "d", "b" };
    const relay_tag = [_][]const u8{ "relay", "wss://relay.example" };
    const duplicate_d_tags = [_]nip01_event.EventTag{
        .{ .items = d_one[0..] },
        .{ .items = d_two[0..] },
    };
    const unexpected_tags = [_]nip01_event.EventTag{.{ .items = relay_tag[0..] }};
    const duplicate_event = list_event(30030, "", duplicate_d_tags[0..]);
    const unexpected_event = list_event(10000, "", unexpected_tags[0..]);
    var items: [1]ListItem = undefined;

    try std.testing.expectError(
        error.DuplicateIdentifierTag,
        list_extract(&duplicate_event, items[0..]),
    );
    const parsed = try list_extract(&unexpected_event, items[0..]);
    try std.testing.expectEqual(ListKind.mute_list, parsed.kind);
    try std.testing.expectEqual(@as(u16, 0), parsed.item_count);
}

test "list extract rejects invalid image metadata and accepts broad bookmark tags" {
    const invalid_image = [_][]const u8{ "image", "not a url" };
    const d_tag = [_][]const u8{ "d", "saved" };
    const hashtag = [_][]const u8{ "t", "nostr" };
    const url_tag = [_][]const u8{ "url", "https://example.com/post" };
    const invalid_image_tags = [_]nip01_event.EventTag{
        .{ .items = d_tag[0..] },
        .{ .items = invalid_image[0..] },
    };
    const bookmark_hashtag_tags = [_]nip01_event.EventTag{
        .{ .items = d_tag[0..] },
        .{ .items = hashtag[0..] },
    };
    const bookmark_url_tags = [_]nip01_event.EventTag{
        .{ .items = d_tag[0..] },
        .{ .items = url_tag[0..] },
    };
    var image_items: [1]ListItem = undefined;
    var bookmark_items: [2]ListItem = undefined;

    try std.testing.expectError(
        error.InvalidImageTag,
        list_extract(&list_event(30030, "", invalid_image_tags[0..]), image_items[0..]),
    );
    const hashtag_parsed = try list_extract(
        &list_event(30003, "", bookmark_hashtag_tags[0..]),
        bookmark_items[0..],
    );
    try std.testing.expectEqual(ListKind.bookmark_set, hashtag_parsed.kind);
    try std.testing.expectEqual(@as(u16, 1), hashtag_parsed.item_count);
    try std.testing.expect(bookmark_items[0] == .hashtag);
    const url_parsed = try list_extract(
        &list_event(30003, "", bookmark_url_tags[0..]),
        bookmark_items[0..],
    );
    try std.testing.expectEqual(ListKind.bookmark_set, url_parsed.kind);
    try std.testing.expectEqual(@as(u16, 1), url_parsed.item_count);
    try std.testing.expect(bookmark_items[0] == .url);
}

test "list extract rejects malformed pubkey event and coordinate tags" {
    const bad_pubkey = [_][]const u8{ "p", "ABC" };
    const bad_event = [_][]const u8{ "e", "xyz" };
    const bad_coordinate = [_][]const u8{ "a", "30023:nothex:identifier" };
    const wrong_coordinate_kind = [_][]const u8{
        "a",
        "30023:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc:community",
    };

    try expect_single_tag_error(error.InvalidPubkey, 10000, bad_pubkey[0..]);
    try expect_single_tag_error(error.InvalidEventId, 10001, bad_event[0..]);
    try expect_single_tag_error(error.InvalidCoordinate, 10004, bad_coordinate[0..]);
    try expect_single_tag_error(error.InvalidCoordinate, 10004, wrong_coordinate_kind[0..]);
}

test "list extract rejects malformed hashtag word relay url and emoji tags" {
    const bad_hashtag = [_][]const u8{ "t", "bad tag" };
    const bad_word = [_][]const u8{ "word", "BadWord" };
    const bad_relay = [_][]const u8{ "relay", "https://relay.example" };
    const bad_emoji = [_][]const u8{ "emoji", "soap-box", "https://cdn.example/soapbox.png" };
    const bad_emoji_set = [_][]const u8{
        "emoji",
        "soapbox",
        "https://cdn.example/soapbox.png",
        "30023:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee:icons",
    };

    try expect_single_tag_error(error.InvalidHashtagTag, 10015, bad_hashtag[0..]);
    try expect_single_tag_error(error.InvalidWordTag, 10000, bad_word[0..]);
    try expect_single_tag_error(error.InvalidRelayUrl, 10006, bad_relay[0..]);
    try expect_single_tag_error(error.InvalidEmojiTag, 10030, bad_emoji[0..]);
    try expect_single_tag_error(error.InvalidEmojiTag, 10030, bad_emoji_set[0..]);
}

test "list extract returns buffer too small for public items" {
    const first_tag = [_][]const u8{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const second_tag = [_][]const u8{
        "p",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    };
    const d_tag = [_][]const u8{ "d", "team" };
    const tags = [_]nip01_event.EventTag{
        .{ .items = d_tag[0..] },
        .{ .items = first_tag[0..] },
        .{ .items = second_tag[0..] },
    };
    const event = list_event(30000, "", tags[0..]);
    var items: [1]ListItem = undefined;

    try std.testing.expectError(error.BufferTooSmall, list_extract(&event, items[0..]));
}

test "private list serializer emits escaped bounded json" {
    const tag_items = [_][]const u8{ "x", "line\nbreak", "\"quote\"" };
    const tags = [_]nip01_event.EventTag{.{ .items = tag_items[0..] }};
    var output: [128]u8 = undefined;

    const json = try list_private_serialize_json(output[0..], tags[0..]);

    try std.testing.expectEqualStrings(
        "[[\"x\",\"line\\nbreak\",\"\\\"quote\\\"\"]]",
        json,
    );
    try std.testing.expect(json[0] == '[');
    try std.testing.expect(json[json.len - 1] == ']');
}

test "private list json extract parses supported items and ignores unknown tags" {
    const json =
        "[[\"p\",\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"]," ++
        "[\"title\",\"ignored\"],[\"word\",\"spam phrase\"]]";
    var items: [2]ListItem = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed = try list_private_extract_json(
        10000,
        json,
        items[0..],
        arena.allocator(),
    );

    try std.testing.expectEqual(ListKind.mute_list, parsed.kind);
    try std.testing.expectEqual(@as(u16, 2), parsed.item_count);
    try std.testing.expect(items[0] == .pubkey);
    try std.testing.expect(items[1] == .word);
    try std.testing.expectEqualStrings(json, parsed.plaintext_json);
    try std.testing.expectEqualStrings("spam phrase", items[1].word);
}

test "private bookmark json extract accepts bounded hashtag and url items" {
    const json =
        "[[\"t\",\"nostr\"],[\"url\",\"https://example.com/post\"],[\"title\",\"ignored\"]]";
    var items: [2]ListItem = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed = try list_private_extract_json(
        10003,
        json,
        items[0..],
        arena.allocator(),
    );

    try std.testing.expectEqual(ListKind.bookmarks, parsed.kind);
    try std.testing.expectEqual(@as(u16, 2), parsed.item_count);
    try std.testing.expect(items[0] == .hashtag);
    try std.testing.expect(items[1] == .url);
    try std.testing.expectEqualStrings("nostr", items[0].hashtag);
    try std.testing.expectEqualStrings("https://example.com/post", items[1].url);
}

test "private list nip44 extract roundtrips mute list content" {
    const private_key = try parse_hex_32_test(
        "0000000000000000000000000000000000000000000000000000000000000001",
    );
    const pubkey = try parse_hex_32_test(
        "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
    );
    const p_tag = [_][]const u8{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const word_tag = [_][]const u8{ "word", "spam phrase" };
    const tags = [_]nip01_event.EventTag{
        .{ .items = p_tag[0..] },
        .{ .items = word_tag[0..] },
    };
    var plaintext_json: [256]u8 = undefined;
    const json = try list_private_serialize_json(plaintext_json[0..], tags[0..]);

    var nonce = [_]u8{0} ** limits.nip44_nonce_bytes;
    nonce[limits.nip44_nonce_bytes - 1] = 1;
    var payload_output: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
    var conversation_key = try nip44.nip44_get_conversation_key(&private_key, &pubkey);
    defer std.crypto.secureZero(u8, conversation_key[0..]);
    const payload = try nip44.nip44_encrypt_with_nonce_to_base64(
        payload_output[0..],
        &conversation_key,
        json,
        &nonce,
    );

    const event = list_event_with_pubkey(10000, pubkey, payload, &.{});
    var decrypted_plaintext: [limits.nip44_plaintext_max_bytes]u8 = undefined;
    var items: [2]ListItem = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed = try list_private_extract_nip44(
        decrypted_plaintext[0..],
        &event,
        &private_key,
        items[0..],
        arena.allocator(),
    );

    try std.testing.expectEqual(ListKind.mute_list, parsed.kind);
    try std.testing.expectEqual(@as(u16, 2), parsed.item_count);
    try std.testing.expect(items[0] == .pubkey);
    try std.testing.expect(items[1] == .word);
    try std.testing.expectEqualStrings(json, parsed.plaintext_json);
    try std.testing.expectEqualStrings("spam phrase", items[1].word);
}

test "private list nip44 extract treats empty content as empty private set" {
    const event = list_event(30003, "", &.{});
    var plaintext: [1]u8 = undefined;
    var items: [1]ListItem = undefined;
    const private_key = [_]u8{1} ** 32;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed = try list_private_extract_nip44(
        plaintext[0..],
        &event,
        &private_key,
        items[0..],
        arena.allocator(),
    );

    try std.testing.expectEqual(ListKind.bookmark_set, parsed.kind);
    try std.testing.expectEqual(@as(u16, 0), parsed.item_count);
    try std.testing.expectEqualStrings("", parsed.plaintext_json);
}

test "private list extract rejects legacy nip04 marker malformed json and bad tags" {
    const legacy = list_event(10000, "payload?iv=legacy", &.{});
    var plaintext: [limits.nip44_plaintext_max_bytes]u8 = undefined;
    var items: [1]ListItem = undefined;
    const private_key = [_]u8{1} ** 32;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.UnsupportedPrivateEncoding,
        list_private_extract_nip44(
            plaintext[0..],
            &legacy,
            &private_key,
            items[0..],
            arena.allocator(),
        ),
    );
    try std.testing.expectError(
        error.InvalidPrivateJson,
        list_private_extract_json(10000, "{", items[0..], arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidRelayUrl,
        list_private_extract_json(
            10006,
            "[[\"relay\",\"https://relay.example\"]]",
            items[0..],
            arena.allocator(),
        ),
    );
}

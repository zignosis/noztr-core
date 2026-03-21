const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");

pub const reaction_event_kind: u32 = 7;

pub const ReactionError = error{
    InvalidReactionKind,
    InvalidContent,
    MissingEventTag,
    InvalidEventTag,
    InvalidEventId,
    InvalidPubkeyTag,
    InvalidPubkey,
    InvalidCoordinate,
    InvalidKindTag,
    InvalidEmojiTag,
};

pub const ReactionType = enum {
    like,
    dislike,
    emoji,
    custom_emoji,

    pub fn is_positive(self: ReactionType) bool {
        std.debug.assert(@intFromEnum(self) <= @intFromEnum(ReactionType.custom_emoji));
        std.debug.assert(!@inComptime());

        return self == .like;
    }

    pub fn is_negative(self: ReactionType) bool {
        std.debug.assert(@intFromEnum(self) <= @intFromEnum(ReactionType.custom_emoji));
        std.debug.assert(!@inComptime());

        return self == .dislike;
    }
};

pub const ReactionCoordinate = struct {
    kind: u32,
    pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
};

pub const ReactionTarget = struct {
    event_id: [32]u8,
    event_hint: ?[]const u8 = null,
    author_pubkey: ?[32]u8 = null,
    author_hint: ?[]const u8 = null,
    coordinate: ?ReactionCoordinate = null,
    reacted_kind: ?u32 = null,
    reaction_type: ReactionType,
    content: []const u8,
    custom_emoji_url: ?[]const u8 = null,
};

/// Returns whether the event is a native NIP-25 reaction event.
pub fn reaction_is_reaction(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.kind <= std.math.maxInt(u32));

    return event.kind == reaction_event_kind;
}

/// Classifies a reaction content value.
pub fn reaction_classify_content(content: []const u8) ReactionError!ReactionType {
    std.debug.assert(limits.content_bytes_max > 0);
    std.debug.assert(@sizeOf(ReactionType) > 0);

    if (content.len > limits.content_bytes_max) return error.InvalidContent;
    if (!std.unicode.utf8ValidateSlice(content)) return error.InvalidContent;

    if (content.len == 0) {
        return .like;
    }
    if (std.mem.eql(u8, content, "+")) {
        return .like;
    }
    if (std.mem.eql(u8, content, "-")) {
        return .dislike;
    }
    if (is_custom_emoji_shortcode(content)) {
        return .custom_emoji;
    }
    return .emoji;
}

/// Parses a strict native NIP-25 reaction target from a kind-7 event.
pub fn reaction_parse(event: *const nip01_event.Event) ReactionError!ReactionTarget {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != reaction_event_kind) {
        return error.InvalidReactionKind;
    }

    var parsed = ReactionTarget{
        .event_id = undefined,
        .reaction_type = try reaction_classify_content(event.content),
        .content = event.content,
    };
    var found_event = false;
    var found_custom_emoji = false;
    var found_pubkey_tag = false;
    var event_author_pubkey: ?[32]u8 = null;

    for (event.tags) |tag| {
        try parse_reaction_tag(
            tag,
            &parsed,
            &found_event,
            &found_custom_emoji,
            &found_pubkey_tag,
            &event_author_pubkey,
        );
    }

    if (!found_event) {
        return error.MissingEventTag;
    }
    if (parsed.reaction_type == .custom_emoji and !found_custom_emoji) {
        return error.InvalidEmojiTag;
    }
    if (!found_pubkey_tag) {
        parsed.author_pubkey = event_author_pubkey;
    }
    try validate_target_metadata(&parsed, event_author_pubkey);

    return parsed;
}

fn parse_reaction_tag(
    tag: nip01_event.EventTag,
    parsed: *ReactionTarget,
    found_event: *bool,
    found_custom_emoji: *bool,
    found_pubkey_tag: *bool,
    event_author_pubkey: *?[32]u8,
) ReactionError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(parsed) != 0);

    if (tag.items.len == 0) {
        return error.InvalidEventTag;
    }

    const tag_name = tag.items[0];
    if (std.mem.eql(u8, tag_name, "e")) {
        try parse_event_tag(tag, parsed, event_author_pubkey);
        found_event.* = true;
        return;
    }
    if (std.mem.eql(u8, tag_name, "p")) {
        try parse_pubkey_tag(tag, parsed);
        found_pubkey_tag.* = true;
        return;
    }
    if (std.mem.eql(u8, tag_name, "a")) {
        parsed.coordinate = try parse_coordinate_tag(tag);
        return;
    }
    if (std.mem.eql(u8, tag_name, "k")) {
        parsed.reacted_kind = try parse_kind_tag(tag);
        return;
    }
    if (std.mem.eql(u8, tag_name, "emoji")) {
        if (found_custom_emoji.*) {
            return error.InvalidEmojiTag;
        }
        parsed.custom_emoji_url = try parse_emoji_tag(tag, parsed.content, parsed.reaction_type);
        found_custom_emoji.* = true;
    }
}

fn parse_event_tag(
    tag: nip01_event.EventTag,
    parsed: *ReactionTarget,
    event_author_pubkey: *?[32]u8,
) ReactionError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(parsed) != 0);

    if (tag.items.len < 2) {
        return error.InvalidEventTag;
    }

    parsed.event_id = parse_lower_hex_32(tag.items[1]) catch {
        return error.InvalidEventId;
    };
    parsed.event_hint = null;
    event_author_pubkey.* = null;
    if (tag.items.len >= 3) {
        parsed.event_hint = parse_optional_hint(tag.items[2]) catch {
            return error.InvalidEventTag;
        };
    }
    if (tag.items.len >= 4) {
        const pubkey = parse_lower_hex_32(tag.items[3]) catch {
            return error.InvalidPubkey;
        };
        event_author_pubkey.* = pubkey;
    }
}

fn parse_pubkey_tag(tag: nip01_event.EventTag, parsed: *ReactionTarget) ReactionError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(parsed) != 0);

    if (tag.items.len < 2) {
        return error.InvalidPubkeyTag;
    }

    const pubkey = parse_lower_hex_32(tag.items[1]) catch {
        return error.InvalidPubkey;
    };
    parsed.author_pubkey = pubkey;
    parsed.author_hint = null;
    if (tag.items.len >= 3) {
        parsed.author_hint = parse_optional_hint(tag.items[2]) catch {
            return error.InvalidPubkeyTag;
        };
    }
}

fn parse_coordinate_tag(tag: nip01_event.EventTag) ReactionError!ReactionCoordinate {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (tag.items.len < 2) {
        return error.InvalidCoordinate;
    }

    var coordinate = try parse_address_coordinate(tag.items[1]);
    if (tag.items.len >= 3) {
        coordinate.relay_hint = parse_optional_hint(tag.items[2]) catch {
            return error.InvalidCoordinate;
        };
    }
    return coordinate;
}

fn parse_kind_tag(tag: nip01_event.EventTag) ReactionError!u32 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.kind_max <= std.math.maxInt(u32));

    if (tag.items.len < 2) {
        return error.InvalidKindTag;
    }

    const parsed = std.fmt.parseUnsigned(u32, tag.items[1], 10) catch {
        return error.InvalidKindTag;
    };
    if (parsed > limits.kind_max) {
        return error.InvalidKindTag;
    }
    return parsed;
}

fn parse_emoji_tag(
    tag: nip01_event.EventTag,
    content: []const u8,
    reaction_type: ReactionType,
) ReactionError!?[]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(content.len <= limits.content_bytes_max);

    if (reaction_type != .custom_emoji) {
        return error.InvalidEmojiTag;
    }
    if (tag.items.len < 3) {
        return error.InvalidEmojiTag;
    }
    if (tag.items.len > 4) {
        return error.InvalidEmojiTag;
    }

    const shortcode = shortcode_without_colons(content) orelse {
        return error.InvalidEmojiTag;
    };
    if (!std.mem.eql(u8, tag.items[1], shortcode)) {
        return error.InvalidEmojiTag;
    }
    if (tag.items.len == 4) {
        try parse_emoji_set_coordinate(tag.items[3]);
    }
    return parse_image_url(tag.items[2]) catch {
        return error.InvalidEmojiTag;
    };
}

fn parse_emoji_set_coordinate(text: []const u8) ReactionError!void {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.kind_max <= std.math.maxInt(u32));

    const coordinate = parse_address_coordinate(text) catch {
        return error.InvalidEmojiTag;
    };
    if (coordinate.kind != 30030) {
        return error.InvalidEmojiTag;
    }
}

fn validate_target_metadata(
    parsed: *const ReactionTarget,
    event_author_pubkey: ?[32]u8,
) ReactionError!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(limits.kind_max <= std.math.maxInt(u32));

    if (parsed.coordinate) |coordinate| {
        if (!coordinate_kind_supports_a_tag(coordinate.kind)) {
            return error.InvalidCoordinate;
        }
        if (parsed.reacted_kind) |reacted_kind| {
            if (coordinate.kind != reacted_kind) {
                return error.InvalidKindTag;
            }
        }
    }
    if (parsed.author_pubkey) |author_pubkey| {
        if (event_author_pubkey) |event_pubkey| {
            if (!std.mem.eql(u8, &author_pubkey, &event_pubkey)) {
                return error.InvalidPubkey;
            }
        }
        if (parsed.coordinate) |coordinate| {
            if (!std.mem.eql(u8, &coordinate.pubkey, &author_pubkey)) {
                return error.InvalidPubkey;
            }
        }
    }
}

fn coordinate_kind_supports_a_tag(kind: u32) bool {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(limits.kind_max <= std.math.maxInt(u32));

    if (kind == 0 or kind == 3) {
        return true;
    }
    if (kind >= 10000 and kind < 20000) {
        return true;
    }
    if (kind >= 30000 and kind < 40000) {
        return true;
    }
    return false;
}

fn parse_address_coordinate(text: []const u8) ReactionError!ReactionCoordinate {
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
    return .{
        .kind = kind,
        .pubkey = pubkey,
        .identifier = identifier,
    };
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.id_hex_length == 64);

    return lower_hex_32.parse(text);
}

fn parse_nonempty_hint(text: []const u8) error{InvalidHint}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len >= 0);

    if (text.len == 0) {
        return error.InvalidHint;
    }
    if (!std.unicode.utf8ValidateSlice(text)) {
        return error.InvalidHint;
    }
    return text;
}

fn parse_image_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len >= 0);

    if (text.len == 0) {
        return error.InvalidUrl;
    }
    const parsed = std.Uri.parse(text) catch {
        return error.InvalidUrl;
    };
    if (parsed.scheme.len == 0) {
        return error.InvalidUrl;
    }
    if (parsed.host == null) {
        return error.InvalidUrl;
    }
    return text;
}

fn parse_optional_hint(text: []const u8) error{InvalidHint}!?[]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len >= 0);

    if (text.len == 0) {
        return null;
    }
    const hint = try parse_nonempty_hint(text);
    return hint;
}

fn is_custom_emoji_shortcode(content: []const u8) bool {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(std.unicode.utf8ValidateSlice(content));

    const shortcode = shortcode_without_colons(content) orelse {
        return false;
    };
    return shortcode_is_valid(shortcode);
}

fn shortcode_without_colons(content: []const u8) ?[]const u8 {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(std.unicode.utf8ValidateSlice(content));

    if (content.len < 3) {
        return null;
    }
    if (content[0] != ':' or content[content.len - 1] != ':') {
        return null;
    }
    const inner = content[1 .. content.len - 1];
    if (std.mem.indexOfScalar(u8, inner, ':') != null) {
        return null;
    }
    return inner;
}

fn shortcode_is_valid(shortcode: []const u8) bool {
    std.debug.assert(shortcode.len <= limits.content_bytes_max);
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

fn reaction_event(
    kind: u32,
    content: []const u8,
    tags: []const nip01_event.EventTag,
) nip01_event.Event {
    std.debug.assert(kind <= std.math.maxInt(u32));
    std.debug.assert(tags.len <= limits.tags_max);

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

test "reaction classify content covers like dislike emoji and custom emoji" {
    try std.testing.expectEqual(ReactionType.like, try reaction_classify_content(""));
    try std.testing.expectEqual(ReactionType.like, try reaction_classify_content("+"));
    try std.testing.expectEqual(ReactionType.dislike, try reaction_classify_content("-"));
    try std.testing.expectEqual(ReactionType.emoji, try reaction_classify_content("🤙"));
    try std.testing.expectEqual(
        ReactionType.custom_emoji,
        try reaction_classify_content(":soapbox:"),
    );
    try std.testing.expectEqual(ReactionType.emoji, try reaction_classify_content(":soap-box:"));
    try std.testing.expect((try reaction_classify_content("+")).is_positive());
    try std.testing.expect((try reaction_classify_content("-")).is_negative());
}

test "reaction classify content rejects invalid direct helper input" {
    var overlong_content: [limits.content_bytes_max + 1]u8 = undefined;
    @memset(overlong_content[0..], 'a');

    try std.testing.expectError(
        error.InvalidContent,
        reaction_classify_content(overlong_content[0..]),
    );

    const invalid_utf8 = [_]u8{0xff};
    try std.testing.expectError(
        error.InvalidContent,
        reaction_classify_content(invalid_utf8[0..]),
    );
}

test "reaction parse valid like path uses last e and last p tags" {
    const first_e = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "wss://relay.one",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const second_e = [_][]const u8{
        "e",
        "2222222222222222222222222222222222222222222222222222222222222222",
        "wss://relay.two",
        "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
    };
    const first_p = [_][]const u8{
        "p",
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    };
    const second_p = [_][]const u8{
        "p",
        "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
        "wss://author.hint",
    };
    const k_tag = [_][]const u8{ "k", "1" };
    const tags = [_]nip01_event.EventTag{
        .{ .items = first_e[0..] },
        .{ .items = first_p[0..] },
        .{ .items = second_e[0..] },
        .{ .items = second_p[0..] },
        .{ .items = k_tag[0..] },
    };
    const event = reaction_event(7, "", tags[0..]);

    const parsed = try reaction_parse(&event);

    try std.testing.expect(parsed.event_id[0] == 0x22);
    try std.testing.expectEqualStrings("wss://relay.two", parsed.event_hint.?);
    try std.testing.expect(parsed.author_pubkey.?[0] == 0xdd);
    try std.testing.expectEqualStrings("wss://author.hint", parsed.author_hint.?);
    try std.testing.expectEqual(@as(?u32, 1), parsed.reacted_kind);
    try std.testing.expectEqual(ReactionType.like, parsed.reaction_type);
}

test "reaction parse last e tag does not inherit earlier e author fallback" {
    const first_e = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "wss://relay.one",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const second_e = [_][]const u8{
        "e",
        "2222222222222222222222222222222222222222222222222222222222222222",
        "wss://relay.two",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = first_e[0..] },
        .{ .items = second_e[0..] },
    };
    const event = reaction_event(7, "+", tags[0..]);

    const parsed = try reaction_parse(&event);

    try std.testing.expect(parsed.event_id[0] == 0x22);
    try std.testing.expectEqualStrings("wss://relay.two", parsed.event_hint.?);
    try std.testing.expect(parsed.author_pubkey == null);
}

test "reaction parse valid custom emoji path requires matching emoji tag" {
    const e_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const a_tag = [_][]const u8{
        "a",
        "30023:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:ident",
        "wss://coord.hint",
    };
    const emoji_tag = [_][]const u8{
        "emoji",
        "soapbox",
        "https://cdn.example/soapbox.png",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = a_tag[0..] },
        .{ .items = emoji_tag[0..] },
    };
    const event = reaction_event(7, ":soapbox:", tags[0..]);

    const parsed = try reaction_parse(&event);

    try std.testing.expectEqual(ReactionType.custom_emoji, parsed.reaction_type);
    try std.testing.expectEqualStrings(
        "https://cdn.example/soapbox.png",
        parsed.custom_emoji_url.?,
    );
    try std.testing.expectEqual(@as(u32, 30023), parsed.coordinate.?.kind);
    try std.testing.expectEqualStrings("ident", parsed.coordinate.?.identifier);
    try std.testing.expectEqualStrings("wss://coord.hint", parsed.coordinate.?.relay_hint.?);
}

test "reaction parse accepts optional emoji-set coordinate on emoji tag" {
    const e_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const emoji_tag = [_][]const u8{
        "emoji",
        "soapbox",
        "https://cdn.example/soapbox.png",
        "30030:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:icons",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = emoji_tag[0..] },
    };

    const parsed = try reaction_parse(&reaction_event(7, ":soapbox:", tags[0..]));

    try std.testing.expectEqual(ReactionType.custom_emoji, parsed.reaction_type);
    try std.testing.expectEqualStrings(
        "https://cdn.example/soapbox.png",
        parsed.custom_emoji_url.?,
    );
}

test "reaction parse valid e tag pubkey fallback works without p tag" {
    const e_tag = [_][]const u8{
        "e",
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
        "wss://relay",
        "abababababababababababababababababababababababababababababababab",
    };
    const tags = [_]nip01_event.EventTag{.{ .items = e_tag[0..] }};
    const event = reaction_event(7, "-", tags[0..]);

    const parsed = try reaction_parse(&event);

    try std.testing.expect(parsed.event_id[0] == 0xff);
    try std.testing.expect(parsed.author_pubkey.?[0] == 0xab);
    try std.testing.expectEqual(ReactionType.dislike, parsed.reaction_type);
}

test "reaction parse rejects wrong kind and missing e tag" {
    const p_tag = [_][]const u8{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const tags = [_]nip01_event.EventTag{.{ .items = p_tag[0..] }};
    const wrong_kind = reaction_event(1, "+", tags[0..]);
    const missing_e = reaction_event(7, "+", tags[0..]);

    try std.testing.expectError(error.InvalidReactionKind, reaction_parse(&wrong_kind));
    try std.testing.expectError(error.MissingEventTag, reaction_parse(&missing_e));
}

test "reaction parse rejects malformed e and p tags" {
    const bad_e_tag = [_][]const u8{ "e", "xyz" };
    const bad_p_tag = [_][]const u8{ "p", "xyz" };
    const good_e_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const bad_e_tags = [_]nip01_event.EventTag{.{ .items = bad_e_tag[0..] }};
    const bad_p_tags = [_]nip01_event.EventTag{
        .{ .items = good_e_tag[0..] },
        .{ .items = bad_p_tag[0..] },
    };
    const bad_e_event = reaction_event(7, "+", bad_e_tags[0..]);
    const bad_p_event = reaction_event(7, "+", bad_p_tags[0..]);

    try std.testing.expectError(error.InvalidEventId, reaction_parse(&bad_e_event));
    try std.testing.expectError(error.InvalidPubkey, reaction_parse(&bad_p_event));
}

test "reaction parse rejects malformed a k and emoji tags" {
    const e_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const bad_a_tag = [_][]const u8{ "a", "1:bad:coord" };
    const bad_k_tag = [_][]const u8{ "k", "70000" };
    const missing_emoji_tag_items = [_][]const u8{ "emoji", "soapbox" };
    const mismatch_emoji_tag_items = [_][]const u8{ "emoji", "other", "https://cdn" };
    const empty_emoji_url_items = [_][]const u8{ "emoji", "soapbox", "" };
    const invalid_shortcode_items = [_][]const u8{ "emoji", "soap-box", "https://cdn" };
    const invalid_url_items = [_][]const u8{ "emoji", "soapbox", "not a url" };
    const invalid_emoji_set_items = [_][]const u8{
        "emoji",
        "soapbox",
        "https://cdn.example/soapbox.png",
        "30000:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:icons",
    };

    const bad_a_tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = bad_a_tag[0..] },
    };
    const bad_k_tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = bad_k_tag[0..] },
    };
    const missing_emoji_tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = missing_emoji_tag_items[0..] },
    };
    const mismatch_emoji_tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = mismatch_emoji_tag_items[0..] },
    };
    const empty_emoji_url_tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = empty_emoji_url_items[0..] },
    };
    const invalid_shortcode_tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = invalid_shortcode_items[0..] },
    };
    const invalid_url_tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = invalid_url_items[0..] },
    };
    const invalid_emoji_set_tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = invalid_emoji_set_items[0..] },
    };

    try std.testing.expectError(
        error.InvalidCoordinate,
        reaction_parse(&reaction_event(7, "+", bad_a_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidKindTag,
        reaction_parse(&reaction_event(7, "+", bad_k_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidEmojiTag,
        reaction_parse(&reaction_event(7, ":soapbox:", missing_emoji_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidEmojiTag,
        reaction_parse(&reaction_event(7, ":soapbox:", mismatch_emoji_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidEmojiTag,
        reaction_parse(&reaction_event(7, ":soapbox:", empty_emoji_url_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidEmojiTag,
        reaction_parse(&reaction_event(7, ":soap-box:", invalid_shortcode_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidEmojiTag,
        reaction_parse(&reaction_event(7, ":soapbox:", invalid_url_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidEmojiTag,
        reaction_parse(&reaction_event(7, ":soapbox:", invalid_emoji_set_tags[0..])),
    );
}

test "reaction parse accepts empty relay hints as absent" {
    const e_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    };
    const p_tag = [_][]const u8{
        "p",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        "",
    };
    const a_tag = [_][]const u8{
        "a",
        "30023:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:ident",
        "",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = p_tag[0..] },
        .{ .items = a_tag[0..] },
    };
    const event = reaction_event(7, "+", tags[0..]);

    const parsed = try reaction_parse(&event);

    try std.testing.expect(parsed.event_hint == null);
    try std.testing.expect(parsed.author_hint == null);
    try std.testing.expect(parsed.coordinate.?.relay_hint == null);
}

test "reaction parse rejects duplicate emoji tags and empty tag names" {
    const e_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const emoji_tag = [_][]const u8{
        "emoji",
        "soapbox",
        "https://cdn.example/soapbox.png",
    };
    const empty_tag_items = [_][]const u8{};
    const duplicate_emoji_tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = emoji_tag[0..] },
        .{ .items = emoji_tag[0..] },
    };
    const empty_tag_name_tags = [_]nip01_event.EventTag{
        .{ .items = empty_tag_items[0..] },
        .{ .items = e_tag[0..] },
    };

    try std.testing.expectError(
        error.InvalidEmojiTag,
        reaction_parse(&reaction_event(7, ":soapbox:", duplicate_emoji_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidEventTag,
        reaction_parse(&reaction_event(7, "+", empty_tag_name_tags[0..])),
    );
}

test "reaction parse rejects emoji tag on non-custom reaction content" {
    const e_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const emoji_tag = [_][]const u8{
        "emoji",
        "soapbox",
        "https://cdn.example/soapbox.png",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = emoji_tag[0..] },
    };

    try std.testing.expectError(
        error.InvalidEmojiTag,
        reaction_parse(&reaction_event(7, "+", tags[0..])),
    );
}

test "reaction parse rejects inconsistent target metadata and unsupported coordinate kinds" {
    const mismatched_author_tags = [_]nip01_event.EventTag{
        .{ .items = (&[_][]const u8{
            "e",
            "1111111111111111111111111111111111111111111111111111111111111111",
            "",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        })[0..] },
        .{ .items = (&[_][]const u8{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        })[0..] },
    };
    const mismatched_coordinate_tags = [_]nip01_event.EventTag{
        .{ .items = (&[_][]const u8{
            "e",
            "1111111111111111111111111111111111111111111111111111111111111111",
            "",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        })[0..] },
        .{ .items = (&[_][]const u8{
            "a",
            "30023:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:article",
        })[0..] },
    };
    const mismatched_kind_tags = [_]nip01_event.EventTag{
        .{ .items = (&[_][]const u8{
            "e",
            "1111111111111111111111111111111111111111111111111111111111111111",
        })[0..] },
        .{ .items = (&[_][]const u8{
            "a",
            "30023:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:article",
        })[0..] },
        .{ .items = (&[_][]const u8{ "k", "1" })[0..] },
    };
    const unsupported_coordinate_kind_tags = [_]nip01_event.EventTag{
        .{ .items = (&[_][]const u8{
            "e",
            "1111111111111111111111111111111111111111111111111111111111111111",
        })[0..] },
        .{ .items = (&[_][]const u8{
            "a",
            "1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:note",
        })[0..] },
    };

    try std.testing.expectError(
        error.InvalidPubkey,
        reaction_parse(&reaction_event(7, "+", mismatched_author_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidPubkey,
        reaction_parse(&reaction_event(7, "+", mismatched_coordinate_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidKindTag,
        reaction_parse(&reaction_event(7, "+", mismatched_kind_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidCoordinate,
        reaction_parse(&reaction_event(7, "+", unsupported_coordinate_kind_tags[0..])),
    );
}

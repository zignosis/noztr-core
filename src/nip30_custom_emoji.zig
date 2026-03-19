const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const emoji_tag_name: []const u8 = "emoji";
pub const emoji_set_kind: u32 = 30030;

pub const Nip30Error = error{
    InvalidEmojiTag,
    InvalidShortcode,
    InvalidImageUrl,
    InvalidEmojiSetAddress,
};

pub const EmojiTagInfo = struct {
    shortcode: []const u8,
    image_url: []const u8,
    emoji_set_address: ?[]const u8 = null,
};

pub const BuiltTag = struct {
    items: [4][]const u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Returns whether a shortcode matches the NIP-30 alphanumeric-or-underscore rule.
pub fn emoji_shortcode_is_valid(shortcode: []const u8) bool {
    std.debug.assert(shortcode.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (shortcode.len == 0) return false;
    for (shortcode) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '_') continue;
        return false;
    }
    return true;
}

/// Extracts a shortcode from an exact `:shortcode:` token.
pub fn emoji_shortcode_from_token(token: []const u8) Nip30Error![]const u8 {
    std.debug.assert(token.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (token.len < 3) return error.InvalidShortcode;
    if (token[0] != ':' or token[token.len - 1] != ':') return error.InvalidShortcode;
    const shortcode = token[1 .. token.len - 1];
    if (!emoji_shortcode_is_valid(shortcode)) return error.InvalidShortcode;
    return shortcode;
}

/// Extracts a strict NIP-30 emoji tag.
pub fn emoji_tag_extract(tag: nip01_event.EventTag) Nip30Error!EmojiTagInfo {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 4);

    if (tag.items.len < 3 or tag.items.len > 4) return error.InvalidEmojiTag;
    if (!std.mem.eql(u8, tag.items[0], emoji_tag_name)) return error.InvalidEmojiTag;

    const shortcode = parse_shortcode(tag.items[1]) catch return error.InvalidShortcode;
    const image_url = parse_url(tag.items[2]) catch return error.InvalidImageUrl;
    const emoji_set = if (tag.items.len == 4)
        parse_emoji_set_address(tag.items[3]) catch return error.InvalidEmojiSetAddress
    else
        null;
    return .{ .shortcode = shortcode, .image_url = image_url, .emoji_set_address = emoji_set };
}

/// Builds a canonical NIP-30 emoji tag.
pub fn emoji_build_tag(
    output: *BuiltTag,
    shortcode: []const u8,
    image_url: []const u8,
    emoji_set_address: ?[]const u8,
) Nip30Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(shortcode.len <= limits.tag_item_bytes_max);

    output.items[0] = emoji_tag_name;
    output.items[1] = parse_shortcode(shortcode) catch return error.InvalidShortcode;
    output.items[2] = parse_url(image_url) catch return error.InvalidImageUrl;
    output.item_count = 3;
    if (emoji_set_address) |value| {
        output.items[3] = parse_emoji_set_address(value) catch {
            return error.InvalidEmojiSetAddress;
        };
        output.item_count = 4;
    }
    return output.as_event_tag();
}

fn parse_shortcode(shortcode: []const u8) error{InvalidText}![]const u8 {
    std.debug.assert(shortcode.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (!emoji_shortcode_is_valid(shortcode)) return error.InvalidText;
    return shortcode;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (text.len == 0) return error.InvalidUrl;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUrl;
    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (parsed.scheme.len == 0) return error.InvalidUrl;
    return text;
}

fn parse_emoji_set_address(text: []const u8) error{InvalidAddress}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    var parts = std.mem.splitScalar(u8, text, ':');
    const kind_text = parts.next() orelse return error.InvalidAddress;
    const pubkey_text = parts.next() orelse return error.InvalidAddress;
    const identifier = parts.next() orelse return error.InvalidAddress;
    if (parts.next() != null) return error.InvalidAddress;
    const kind = std.fmt.parseUnsigned(u32, kind_text, 10) catch return error.InvalidAddress;
    if (kind != emoji_set_kind) {
        return error.InvalidAddress;
    }
    _ = parse_lower_hex_32(pubkey_text) catch return error.InvalidAddress;
    if (identifier.len == 0) return error.InvalidAddress;
    if (!std.unicode.utf8ValidateSlice(identifier)) return error.InvalidAddress;
    return text;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.pubkey_hex_length);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (text.len != limits.pubkey_hex_length) return error.InvalidHex;
    var out: [32]u8 = undefined;
    var index: usize = 0;
    while (index < out.len) : (index += 1) {
        const start = index * 2;
        out[index] = std.fmt.parseUnsigned(u8, text[start .. start + 2], 16) catch {
            return error.InvalidHex;
        };
    }
    if (!std.mem.eql(u8, &std.fmt.bytesToHex(out, .lower), text)) return error.InvalidHex;
    return out;
}

test "NIP-30 extracts emoji tags with optional set coordinates" {
    const tag = nip01_event.EventTag{
        .items = &.{
            "emoji",
            "soapbox",
            "https://cdn.example/soapbox.png",
            "30030:1111111111111111111111111111111111111111111111111111111111111111:icons",
        },
    };

    const info = try emoji_tag_extract(tag);

    try std.testing.expectEqualStrings("soapbox", info.shortcode);
    try std.testing.expectEqualStrings("https://cdn.example/soapbox.png", info.image_url);
    try std.testing.expect(info.emoji_set_address != null);
}

test "NIP-30 extracts shortcode tokens and rejects malformed ones" {
    try std.testing.expectEqualStrings("soapbox", try emoji_shortcode_from_token(":soapbox:"));
    try std.testing.expect(!emoji_shortcode_is_valid("soap-box"));
    try std.testing.expectError(error.InvalidShortcode, emoji_shortcode_from_token("soapbox"));
}

test "NIP-30 builds canonical emoji tags" {
    var built: BuiltTag = .{};

    const tag = try emoji_build_tag(&built, "wave", "https://cdn.example/wave.png", null);

    try std.testing.expectEqualStrings("emoji", tag.items[0]);
    try std.testing.expectEqualStrings("wave", tag.items[1]);
    try std.testing.expectEqualStrings("https://cdn.example/wave.png", tag.items[2]);
}

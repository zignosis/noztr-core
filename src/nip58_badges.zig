const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const badge_award_kind: u32 = 8;
pub const profile_badges_kind: u32 = 30008;
pub const badge_definition_kind: u32 = 30009;
pub const profile_badges_identifier: []const u8 = "profile_badges";

pub const Nip58Error = error{
    InvalidBadgeDefinitionKind,
    MissingIdentifierTag,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    DuplicateNameTag,
    InvalidNameTag,
    DuplicateDescriptionTag,
    InvalidDescriptionTag,
    DuplicateImageTag,
    InvalidImageTag,
    InvalidThumbTag,
    InvalidBadgeAwardKind,
    MissingBadgeDefinitionTag,
    DuplicateBadgeDefinitionTag,
    InvalidBadgeDefinitionTag,
    MissingAwardedPubkeyTag,
    InvalidAwardedPubkeyTag,
    InvalidProfileBadgesKind,
    InvalidProfileBadgesIdentifier,
    DuplicateProfileBadgesIdentifierTag,
    InvalidAwardEventTag,
    MismatchedBadgeDefinition,
    MismatchedBadgeAward,
    BadgeAwardMissingProfilePubkey,
    BufferTooSmall,
};

pub const ImageInfo = struct {
    url: []const u8,
    dimensions: ?[]const u8 = null,
};

pub const BadgeDefinitionReference = struct {
    issuer_pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
};

pub const BadgeDefinitionInfo = struct {
    issuer_pubkey: [32]u8,
    identifier: []const u8,
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    image: ?ImageInfo = null,
    thumb_count: u16 = 0,
};

pub const BadgeAwardRecipient = struct {
    pubkey: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const BadgeAwardInfo = struct {
    event_id: [32]u8,
    badge_definition: BadgeDefinitionReference,
    recipient_count: u16,
};

pub const BadgeAwardEventReference = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const ProfileBadgePair = struct {
    badge_definition: BadgeDefinitionReference,
    award_event: BadgeAwardEventReference,
};

pub const ProfileBadgesInfo = struct {
    pair_count: u16,
};

pub const BuiltTag = struct {
    items: [3][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded badge-definition metadata from a kind-30009 event.
pub fn badge_definition_extract(
    event: *const nip01_event.Event,
    out_thumbs: []ImageInfo,
) Nip58Error!BadgeDefinitionInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_thumbs.len <= limits.tags_max);

    if (event.kind != badge_definition_kind) return error.InvalidBadgeDefinitionKind;

    var identifier: ?[]const u8 = null;
    var info = BadgeDefinitionInfo{ .issuer_pubkey = event.pubkey, .identifier = undefined };
    for (event.tags) |tag| {
        try apply_definition_tag(tag, &identifier, &info, out_thumbs);
    }
    info.identifier = identifier orelse return error.MissingIdentifierTag;
    return info;
}

/// Extracts a bounded badge-award surface from a kind-8 event.
pub fn badge_award_extract(
    event: *const nip01_event.Event,
    out_recipients: []BadgeAwardRecipient,
) Nip58Error!BadgeAwardInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_recipients.len <= limits.tags_max);

    if (event.kind != badge_award_kind) return error.InvalidBadgeAwardKind;

    var badge_definition: ?BadgeDefinitionReference = null;
    var recipient_count: u16 = 0;
    for (event.tags) |tag| {
        try apply_award_tag(tag, &badge_definition, out_recipients, &recipient_count);
    }
    if (badge_definition == null) return error.MissingBadgeDefinitionTag;
    if (recipient_count == 0) return error.MissingAwardedPubkeyTag;
    return .{
        .event_id = event.id,
        .badge_definition = badge_definition.?,
        .recipient_count = recipient_count,
    };
}

/// Extracts ordered consecutive profile badge pairs from a kind-30008 event.
pub fn profile_badges_extract(
    event: *const nip01_event.Event,
    out_pairs: []ProfileBadgePair,
) Nip58Error!ProfileBadgesInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_pairs.len <= limits.tags_max);

    if (event.kind != profile_badges_kind) return error.InvalidProfileBadgesKind;

    var has_identifier = false;
    var pending_definition: ?nip01_event.EventTag = null;
    var count: u16 = 0;
    for (event.tags) |tag| {
        try apply_profile_tag(
            tag,
            &has_identifier,
            &pending_definition,
            out_pairs,
            &count,
        );
    }
    if (!has_identifier) return error.InvalidProfileBadgesIdentifier;
    return .{ .pair_count = count };
}

/// Validates that a parsed badge award references the supplied badge definition.
pub fn badge_award_validate_definition(
    award: *const BadgeAwardInfo,
    definition: *const BadgeDefinitionInfo,
) Nip58Error!void {
    std.debug.assert(@intFromPtr(award) != 0);
    std.debug.assert(@intFromPtr(definition) != 0);

    if (!std.mem.eql(u8, &award.badge_definition.issuer_pubkey, &definition.issuer_pubkey)) {
        return error.MismatchedBadgeDefinition;
    }
    if (!std.mem.eql(u8, award.badge_definition.identifier, definition.identifier)) {
        return error.MismatchedBadgeDefinition;
    }
}

/// Validates one profile-badge pair against the supplied award, definition, and profile pubkey.
pub fn profile_badge_pair_validate(
    pair: *const ProfileBadgePair,
    award: *const BadgeAwardInfo,
    award_recipients: []const BadgeAwardRecipient,
    definition: *const BadgeDefinitionInfo,
    profile_pubkey: *const [32]u8,
) Nip58Error!void {
    std.debug.assert(@intFromPtr(pair) != 0);
    std.debug.assert(@intFromPtr(award) != 0);

    try badge_award_validate_definition(award, definition);
    if (!std.mem.eql(u8, &pair.award_event.event_id, &award.event_id)) {
        return error.MismatchedBadgeAward;
    }
    if (!std.mem.eql(u8, &pair.badge_definition.issuer_pubkey, &definition.issuer_pubkey)) {
        return error.MismatchedBadgeDefinition;
    }
    if (!std.mem.eql(u8, pair.badge_definition.identifier, definition.identifier)) {
        return error.MismatchedBadgeDefinition;
    }
    if (!award_has_recipient(award_recipients, profile_pubkey)) {
        return error.BadgeAwardMissingProfilePubkey;
    }
}

/// Builds a badge-definition `d` tag.
pub fn badge_build_identifier_tag(
    output: *BuiltTag,
    identifier: []const u8,
) Nip58Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a badge-definition `name` tag.
pub fn badge_build_name_tag(
    output: *BuiltTag,
    name: []const u8,
) Nip58Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(name.len <= limits.tag_item_bytes_max);

    output.items[0] = "name";
    output.items[1] = parse_nonempty_utf8(name) catch return error.InvalidNameTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a badge-definition `description` tag.
pub fn badge_build_description_tag(
    output: *BuiltTag,
    description: []const u8,
) Nip58Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(description.len <= limits.tag_item_bytes_max);

    output.items[0] = "description";
    output.items[1] = parse_nonempty_utf8(description) catch return error.InvalidDescriptionTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a badge-definition `image` tag.
pub fn badge_build_image_tag(
    output: *BuiltTag,
    image_url: []const u8,
    dimensions: ?[]const u8,
) Nip58Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(image_url.len <= limits.tag_item_bytes_max);

    output.items[0] = "image";
    output.items[1] = parse_url(image_url) catch return error.InvalidImageTag;
    output.item_count = 2;
    if (dimensions) |value| {
        output.items[2] = parse_dimensions(value) catch return error.InvalidImageTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a badge-definition `thumb` tag.
pub fn badge_build_thumb_tag(
    output: *BuiltTag,
    thumb_url: []const u8,
    dimensions: ?[]const u8,
) Nip58Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(thumb_url.len <= limits.tag_item_bytes_max);

    output.items[0] = "thumb";
    output.items[1] = parse_url(thumb_url) catch return error.InvalidThumbTag;
    output.item_count = 2;
    if (dimensions) |value| {
        output.items[2] = parse_dimensions(value) catch return error.InvalidThumbTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a badge-award or profile-pair `a` tag referencing a badge definition.
pub fn badge_build_definition_tag(
    output: *BuiltTag,
    reference: *const BadgeDefinitionReference,
) Nip58Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(reference) != 0);

    output.items[0] = "a";
    output.items[1] = try format_definition_coordinate(output.text_storage[0..], reference);
    output.item_count = 2;
    if (reference.relay_hint) |relay_hint| {
        output.items[2] = parse_url(relay_hint) catch return error.InvalidBadgeDefinitionTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a badge-award `p` tag.
pub fn badge_build_awarded_pubkey_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
) Nip58Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(pubkey_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(pubkey_hex) catch return error.InvalidAwardedPubkeyTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidAwardedPubkeyTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds the fixed profile-badges `d` tag.
pub fn profile_badges_build_identifier_tag(
    output: *BuiltTag,
) Nip58Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(profile_badges_identifier.len > 0);

    output.items[0] = "d";
    output.items[1] = profile_badges_identifier;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a profile-badge-pair `e` tag referencing a badge award.
pub fn profile_badges_build_award_tag(
    output: *BuiltTag,
    event_id_hex: []const u8,
    relay_hint: ?[]const u8,
) Nip58Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(event_id_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(event_id_hex) catch return error.InvalidAwardEventTag;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidAwardEventTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

fn apply_definition_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    info: *BadgeDefinitionInfo,
    out_thumbs: []ImageInfo,
) Nip58Error!void {
    std.debug.assert(@intFromPtr(identifier) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "d")) return parse_definition_identifier(tag, identifier);
    if (std.mem.eql(u8, name, "name")) return parse_definition_name(tag, info);
    if (std.mem.eql(u8, name, "description")) return parse_definition_description(tag, info);
    if (std.mem.eql(u8, name, "image")) return parse_definition_image(tag, info);
    if (std.mem.eql(u8, name, "thumb")) return parse_definition_thumb(tag, info, out_thumbs);
}

fn parse_definition_identifier(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
) Nip58Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(identifier) != 0);

    if (identifier.* != null) return error.DuplicateIdentifierTag;
    identifier.* = parse_single_utf8_value(tag) catch return error.InvalidIdentifierTag;
}

fn parse_definition_name(tag: nip01_event.EventTag, info: *BadgeDefinitionInfo) Nip58Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.name != null) return error.DuplicateNameTag;
    info.name = parse_single_utf8_value(tag) catch return error.InvalidNameTag;
}

fn parse_definition_description(
    tag: nip01_event.EventTag,
    info: *BadgeDefinitionInfo,
) Nip58Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.description != null) return error.DuplicateDescriptionTag;
    info.description = parse_single_utf8_value(tag) catch return error.InvalidDescriptionTag;
}

fn parse_definition_image(tag: nip01_event.EventTag, info: *BadgeDefinitionInfo) Nip58Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.image != null) return error.DuplicateImageTag;
    info.image = .{
        .url = try parse_required_url_item(tag, 1, error.InvalidImageTag),
        .dimensions = try parse_optional_dimensions_item(tag, 2, error.InvalidImageTag),
    };
}

fn parse_definition_thumb(
    tag: nip01_event.EventTag,
    info: *BadgeDefinitionInfo,
    out_thumbs: []ImageInfo,
) Nip58Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.thumb_count == out_thumbs.len) return error.BufferTooSmall;
    out_thumbs[info.thumb_count] = .{
        .url = try parse_required_url_item(tag, 1, error.InvalidThumbTag),
        .dimensions = try parse_optional_dimensions_item(tag, 2, error.InvalidThumbTag),
    };
    info.thumb_count += 1;
}

fn apply_award_tag(
    tag: nip01_event.EventTag,
    badge_definition: *?BadgeDefinitionReference,
    out_recipients: []BadgeAwardRecipient,
    recipient_count: *u16,
) Nip58Error!void {
    std.debug.assert(@intFromPtr(badge_definition) != 0);
    std.debug.assert(@intFromPtr(recipient_count) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "a")) {
        return parse_award_definition_tag(tag, badge_definition);
    }
    if (std.mem.eql(u8, tag.items[0], "p")) {
        return parse_award_pubkey_tag(tag, out_recipients, recipient_count);
    }
}

fn parse_award_definition_tag(
    tag: nip01_event.EventTag,
    badge_definition: *?BadgeDefinitionReference,
) Nip58Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(badge_definition) != 0);

    if (badge_definition.* != null) return error.DuplicateBadgeDefinitionTag;
    badge_definition.* = try parse_definition_reference_tag(tag, error.InvalidBadgeDefinitionTag);
}

fn parse_award_pubkey_tag(
    tag: nip01_event.EventTag,
    out_recipients: []BadgeAwardRecipient,
    recipient_count: *u16,
) Nip58Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(recipient_count) != 0);

    if (tag.items.len < 2) return error.InvalidAwardedPubkeyTag;
    if (recipient_count.* == out_recipients.len) return error.BufferTooSmall;
    out_recipients[recipient_count.*] = .{
        .pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidAwardedPubkeyTag,
        .relay_hint = try parse_optional_url_item(tag, 2, error.InvalidAwardedPubkeyTag),
    };
    recipient_count.* += 1;
}

fn apply_profile_tag(
    tag: nip01_event.EventTag,
    has_identifier: *bool,
    pending_definition: *?nip01_event.EventTag,
    out_pairs: []ProfileBadgePair,
    count: *u16,
) Nip58Error!void {
    std.debug.assert(@intFromPtr(has_identifier) != 0);
    std.debug.assert(@intFromPtr(count) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) {
        return parse_profile_identifier_tag(tag, has_identifier);
    }
    if (std.mem.eql(u8, tag.items[0], "a")) {
        pending_definition.* = tag;
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "e")) {
        if (pending_definition.* == null) return;
        if (count.* == out_pairs.len) return error.BufferTooSmall;
        out_pairs[count.*] = .{
            .badge_definition = try parse_definition_reference_tag(
                pending_definition.*.?,
                error.InvalidBadgeDefinitionTag,
            ),
            .award_event = try parse_award_event_tag(tag),
        };
        pending_definition.* = null;
        count.* += 1;
    }
}

fn parse_profile_identifier_tag(tag: nip01_event.EventTag, has_identifier: *bool) Nip58Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(has_identifier) != 0);

    if (has_identifier.*) return error.DuplicateProfileBadgesIdentifierTag;
    const identifier = parse_single_utf8_value(tag) catch return error.InvalidProfileBadgesIdentifier;
    if (!std.mem.eql(u8, identifier, profile_badges_identifier)) {
        return error.InvalidProfileBadgesIdentifier;
    }
    has_identifier.* = true;
}

fn parse_definition_reference_tag(
    tag: nip01_event.EventTag,
    invalid_error: Nip58Error,
) Nip58Error!BadgeDefinitionReference {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@typeInfo(Nip58Error) == .error_set);

    if (tag.items.len < 2 or tag.items.len > 3) return invalid_error;
    if (!std.mem.eql(u8, tag.items[0], "a")) return invalid_error;

    var parsed = try parse_definition_coordinate_text(tag.items[1], invalid_error);
    parsed.relay_hint = try parse_optional_url_item(tag, 2, invalid_error);
    return parsed;
}

fn parse_award_event_tag(tag: nip01_event.EventTag) Nip58Error!BadgeAwardEventReference {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len < 2) return error.InvalidAwardEventTag;
    if (!std.mem.eql(u8, tag.items[0], "e")) return error.InvalidAwardEventTag;
    return .{
        .event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidAwardEventTag,
        .relay_hint = try parse_optional_url_item(tag, 2, error.InvalidAwardEventTag),
    };
}

fn parse_definition_coordinate_text(
    text: []const u8,
    invalid_error: Nip58Error,
) Nip58Error!BadgeDefinitionReference {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@typeInfo(Nip58Error) == .error_set);

    var parts = std.mem.splitScalar(u8, text, ':');
    const kind_text = parts.next() orelse return invalid_error;
    const pubkey_text = parts.next() orelse return invalid_error;
    const identifier = parts.next() orelse return invalid_error;
    if (parts.next() != null) return invalid_error;

    const kind = parse_decimal_u32(kind_text) catch return invalid_error;
    if (kind != badge_definition_kind) return invalid_error;
    return .{
        .issuer_pubkey = parse_lower_hex_32(pubkey_text) catch return invalid_error,
        .identifier = parse_nonempty_utf8(identifier) catch return invalid_error,
    };
}

fn format_definition_coordinate(
    output: []u8,
    reference: *const BadgeDefinitionReference,
) Nip58Error![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(@intFromPtr(reference) != 0);

    const issuer_hex = std.fmt.bytesToHex(reference.issuer_pubkey, .lower);
    return std.fmt.bufPrint(
        output,
        "{d}:{s}:{s}",
        .{ badge_definition_kind, issuer_hex, reference.identifier },
    ) catch return error.BufferTooSmall;
}

fn parse_required_url_item(
    tag: nip01_event.EventTag,
    index: usize,
    invalid_error: Nip58Error,
) Nip58Error![]const u8 {
    std.debug.assert(index < limits.tag_items_max);
    std.debug.assert(@typeInfo(Nip58Error) == .error_set);

    if (tag.items.len <= index) return invalid_error;
    return parse_url(tag.items[index]) catch return invalid_error;
}

fn parse_optional_url_item(
    tag: nip01_event.EventTag,
    index: usize,
    invalid_error: Nip58Error,
) Nip58Error!?[]const u8 {
    std.debug.assert(index < limits.tag_items_max);
    std.debug.assert(@typeInfo(Nip58Error) == .error_set);

    if (tag.items.len <= index) return null;
    if (tag.items[index].len == 0) return null;
    return parse_url(tag.items[index]) catch return invalid_error;
}

fn parse_optional_dimensions_item(
    tag: nip01_event.EventTag,
    index: usize,
    invalid_error: Nip58Error,
) Nip58Error!?[]const u8 {
    std.debug.assert(index < limits.tag_items_max);
    std.debug.assert(@typeInfo(Nip58Error) == .error_set);

    if (tag.items.len <= index) return null;
    return parse_dimensions(tag.items[index]) catch return invalid_error;
}

fn award_has_recipient(
    recipients: []const BadgeAwardRecipient,
    profile_pubkey: *const [32]u8,
) bool {
    std.debug.assert(recipients.len <= limits.tags_max);
    std.debug.assert(@intFromPtr(profile_pubkey) != 0);

    for (recipients) |recipient| {
        if (std.mem.eql(u8, &recipient.pubkey, profile_pubkey)) return true;
    }
    return false;
}

fn parse_single_utf8_value(tag: nip01_event.EventTag) error{InvalidTag}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidTag;
    return parse_nonempty_utf8(tag.items[1]);
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidTag}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (text.len == 0) return error.InvalidTag;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidTag;
    return text;
}

fn parse_dimensions(text: []const u8) error{InvalidDimensions}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    const separator = std.mem.indexOfScalar(u8, text, 'x') orelse return error.InvalidDimensions;
    if (separator == 0 or separator + 1 >= text.len) return error.InvalidDimensions;
    _ = parse_decimal_u32(text[0..separator]) catch return error.InvalidDimensions;
    _ = parse_decimal_u32(text[separator + 1 ..]) catch return error.InvalidDimensions;
    return text;
}

fn parse_decimal_u32(text: []const u8) error{InvalidDecimal}!u32 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidDecimal;
    for (text) |byte| {
        if (byte < '0' or byte > '9') return error.InvalidDecimal;
    }
    return std.fmt.parseInt(u32, text, 10) catch return error.InvalidDecimal;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUrl;
    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (parsed.scheme.len == 0) return error.InvalidUrl;
    if (parsed.host == null) return error.InvalidUrl;
    return text;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.id_hex_length);
    std.debug.assert(limits.id_hex_length == 64);

    var output: [32]u8 = undefined;
    if (text.len != limits.id_hex_length) return error.InvalidHex;
    try validate_lower_hex(text);
    _ = std.fmt.hexToBytes(&output, text) catch return error.InvalidHex;
    return output;
}

fn validate_lower_hex(text: []const u8) error{InvalidHex}!void {
    std.debug.assert(text.len <= limits.id_hex_length);
    std.debug.assert(limits.id_hex_length == 64);

    for (text) |byte| {
        if (byte >= '0' and byte <= '9') continue;
        if (byte >= 'a' and byte <= 'f') continue;
        return error.InvalidHex;
    }
}

fn event_for_tags(
    kind: u32,
    pubkey: [32]u8,
    event_id: [32]u8,
    tags: []const nip01_event.EventTag,
) nip01_event.Event {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(tags.len <= limits.tags_max);

    return .{
        .id = event_id,
        .pubkey = pubkey,
        .created_at = 1,
        .kind = kind,
        .tags = tags,
        .content = "",
        .sig = [_]u8{0} ** 64,
    };
}

test "badge definition extract parses required and optional metadata" {
    const issuer = [_]u8{1} ** 32;
    var tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "bravery" } },
        .{ .items = &.{ "name", "Medal of Bravery" } },
        .{ .items = &.{ "description", "Awarded for bravery" } },
        .{ .items = &.{ "image", "https://example.com/badge.png", "1024x1024" } },
        .{ .items = &.{ "thumb", "https://example.com/thumb.png", "256x256" } },
    };
    const event = event_for_tags(badge_definition_kind, issuer, [_]u8{3} ** 32, tags[0..]);
    var thumbs: [2]ImageInfo = undefined;

    const parsed = try badge_definition_extract(&event, thumbs[0..]);
    try std.testing.expectEqualStrings("bravery", parsed.identifier);
    try std.testing.expectEqualStrings("Medal of Bravery", parsed.name.?);
    try std.testing.expectEqualStrings("Awarded for bravery", parsed.description.?);
    try std.testing.expectEqual(@as(u16, 1), parsed.thumb_count);
    try std.testing.expectEqualStrings("https://example.com/thumb.png", thumbs[0].url);
}

test "badge award extract parses badge definition and recipients" {
    var tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "a", "30009:0101010101010101010101010101010101010101010101010101010101010101:bravery" } },
        .{ .items = &.{ "p", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
        .{ .items = &.{ "p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" } },
    };
    const event = event_for_tags(badge_award_kind, [_]u8{1} ** 32, [_]u8{9} ** 32, tags[0..]);
    var recipients: [2]BadgeAwardRecipient = undefined;

    const parsed = try badge_award_extract(&event, recipients[0..]);
    try std.testing.expectEqual(@as(u16, 2), parsed.recipient_count);
    try std.testing.expectEqualStrings("bravery", parsed.badge_definition.identifier);
    try std.testing.expectEqual(@as(u8, 0xaa), recipients[0].pubkey[0]);
}

test "badge award validate definition rejects mismatched coordinate" {
    const issuer = [_]u8{1} ** 32;
    const definition = BadgeDefinitionInfo{
        .issuer_pubkey = issuer,
        .identifier = "bravery",
    };
    const award = BadgeAwardInfo{
        .event_id = [_]u8{2} ** 32,
        .badge_definition = .{ .issuer_pubkey = issuer, .identifier = "honor" },
        .recipient_count = 1,
    };

    try std.testing.expectError(
        error.MismatchedBadgeDefinition,
        badge_award_validate_definition(&award, &definition),
    );
}

test "profile badges extract parses consecutive pairs and ignores unmatched tags" {
    var tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "profile_badges" } },
        .{ .items = &.{ "a", "30009:0101010101010101010101010101010101010101010101010101010101010101:bravery" } },
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "wss://relay.example" } },
        .{ .items = &.{ "e", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" } },
        .{ .items = &.{ "a", "30009:0101010101010101010101010101010101010101010101010101010101010101:honor" } },
    };
    const event = event_for_tags(profile_badges_kind, [_]u8{2} ** 32, [_]u8{3} ** 32, tags[0..]);
    var pairs: [2]ProfileBadgePair = undefined;

    const parsed = try profile_badges_extract(&event, pairs[0..]);
    try std.testing.expectEqual(@as(u16, 1), parsed.pair_count);
    try std.testing.expectEqualStrings("bravery", pairs[0].badge_definition.identifier);
    try std.testing.expectEqual(@as(u8, 0xaa), pairs[0].award_event.event_id[0]);
}

test "profile badge pair validate checks definition award and recipient" {
    const issuer = [_]u8{1} ** 32;
    const profile_pubkey = [_]u8{0xaa} ** 32;
    const definition = BadgeDefinitionInfo{
        .issuer_pubkey = issuer,
        .identifier = "bravery",
    };
    const award = BadgeAwardInfo{
        .event_id = [_]u8{9} ** 32,
        .badge_definition = .{ .issuer_pubkey = issuer, .identifier = "bravery" },
        .recipient_count = 1,
    };
    const recipients = [_]BadgeAwardRecipient{
        .{ .pubkey = profile_pubkey },
    };
    const pair = ProfileBadgePair{
        .badge_definition = .{ .issuer_pubkey = issuer, .identifier = "bravery" },
        .award_event = .{ .event_id = [_]u8{9} ** 32 },
    };

    try profile_badge_pair_validate(&pair, &award, recipients[0..], &definition, &profile_pubkey);
    try std.testing.expect(recipients.len == 1);
}

test "badge builders emit canonical tags" {
    var output = BuiltTag{};
    const issuer = [_]u8{1} ** 32;
    const definition_tag = try badge_build_definition_tag(
        &output,
        &.{ .issuer_pubkey = issuer, .identifier = "bravery" },
    );
    try std.testing.expectEqualStrings("a", definition_tag.items[0]);
    try std.testing.expect(std.mem.startsWith(u8, definition_tag.items[1], "30009:"));

    const profile_tag = try profile_badges_build_identifier_tag(&output);
    try std.testing.expectEqualStrings("d", profile_tag.items[0]);
    try std.testing.expectEqualStrings(profile_badges_identifier, profile_tag.items[1]);
}

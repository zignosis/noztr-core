const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const nip94_file_metadata = @import("nip94_file_metadata.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const url_with_scheme = @import("internal/url_with_scheme.zig");

pub const community_definition_kind: u32 = 34550;
pub const community_post_kind: u32 = 1111;
pub const community_approval_kind: u32 = 4550;

pub const CommunityError = error{
    InvalidCommunityDefinitionKind,
    InvalidCommunityPostKind,
    InvalidCommunityApprovalKind,
    MissingIdentifierTag,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    DuplicateNameTag,
    InvalidNameTag,
    DuplicateDescriptionTag,
    InvalidDescriptionTag,
    DuplicateImageTag,
    InvalidImageTag,
    InvalidModeratorTag,
    InvalidRelayTag,
    MissingCommunityTag,
    DuplicateCommunityTag,
    InvalidCommunityTag,
    MissingCommunityAuthorTag,
    DuplicateCommunityAuthorTag,
    InvalidCommunityAuthorTag,
    MissingCommunityKindTag,
    DuplicateCommunityKindTag,
    InvalidCommunityKindTag,
    MissingParentTag,
    DuplicateParentTag,
    InvalidParentTag,
    MissingParentAuthorTag,
    DuplicateParentAuthorTag,
    InvalidParentAuthorTag,
    MissingParentKindTag,
    DuplicateParentKindTag,
    InvalidParentKindTag,
    CommunityAuthorMismatch,
    TopLevelCommunityMismatch,
    TopLevelParentKindMismatch,
    MissingApprovedTarget,
    MissingApprovedAuthorTag,
    DuplicateApprovedEventTag,
    InvalidApprovedEventTag,
    DuplicateApprovedCoordinateTag,
    InvalidApprovedCoordinateTag,
    MissingApprovedKindTag,
    DuplicateApprovedKindTag,
    InvalidApprovedKindTag,
    InvalidApprovalContent,
    BufferTooSmall,
};

pub const Dimensions = nip94_file_metadata.Dimensions;

pub const Coordinate = struct {
    pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
};

pub const AddressableTarget = struct {
    kind: u32,
    pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
};

pub const Moderator = struct {
    pubkey: [32]u8,
    relay_hint: ?[]const u8 = null,
    role: ?[]const u8 = null,
};

pub const Relay = struct {
    url: []const u8,
    marker: ?[]const u8 = null,
};

pub const Community = struct {
    identifier: []const u8,
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    image_url: ?[]const u8 = null,
    image_dimensions: ?Dimensions = null,
    moderator_count: u16 = 0,
    relay_count: u16 = 0,
};

pub const EventRef = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const ParentTarget = union(enum) {
    coordinate: AddressableTarget,
    event: EventRef,
};

pub const Relation = enum {
    top_level,
    reply,
};

pub const Post = struct {
    community: Coordinate,
    parent: ParentTarget,
    parent_author: [32]u8,
    parent_author_hint: ?[]const u8 = null,
    parent_kind: u32,
    relation: Relation,
    content: []const u8,
};

pub const ApprovedTarget = union(enum) {
    event: EventRef,
    coordinate: AddressableTarget,
};

pub const Approval = struct {
    content: []const u8,
    community_count: u16 = 0,
    approved: ?ApprovedTarget = null,
    approved_author: [32]u8,
    approved_author_hint: ?[]const u8 = null,
    approved_kind: u32,
};

pub const TagBuilder = struct {
    items: [5][]const u8 = undefined,
    text_storage: [2][limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const TagBuilder) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded community-definition metadata from a `kind:34550` event.
pub fn extract(
    event: *const nip01_event.Event,
    out_moderators: []Moderator,
    out_relays: []Relay,
) CommunityError!Community {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_moderators.len <= limits.tags_max);

    if (event.kind != community_definition_kind) return error.InvalidCommunityDefinitionKind;

    var identifier: ?[]const u8 = null;
    var info = Community{ .identifier = undefined };
    for (event.tags) |tag| try apply_community_tag(tag, &identifier, &info, out_moderators, out_relays);
    info.identifier = identifier orelse return error.MissingIdentifierTag;
    return info;
}

/// Extracts community linkage from a `kind:1111` community post.
pub fn post_extract(event: *const nip01_event.Event) CommunityError!Post {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != community_post_kind) return error.InvalidCommunityPostKind;

    var upper: ?AddressableTarget = null;
    var upper_author: ?TagPubkey = null;
    var saw_upper_kind = false;
    var lower_coord: ?AddressableTarget = null;
    var lower_event: ?EventRef = null;
    var lower_author: ?TagPubkey = null;
    var lower_kind: ?u32 = null;
    for (event.tags) |tag| {
        try apply_post_tag(
            tag,
            &upper,
            &upper_author,
            &saw_upper_kind,
            &lower_coord,
            &lower_event,
            &lower_author,
            &lower_kind,
        );
    }
    const upper_coordinate = upper orelse return error.MissingCommunityTag;
    if (upper_coordinate.kind != community_definition_kind) return error.InvalidCommunityTag;
    const community = to_community_coordinate(upper_coordinate);
    const community_author = upper_author orelse return error.MissingCommunityAuthorTag;
    if (!saw_upper_kind) return error.MissingCommunityKindTag;
    if (!std.mem.eql(u8, &community.pubkey, &community_author.pubkey)) {
        return error.CommunityAuthorMismatch;
    }
    const parent_author = lower_author orelse return error.MissingParentAuthorTag;
    const parent_kind = lower_kind orelse return error.MissingParentKindTag;
    if (lower_event == null and lower_coord == null) return error.MissingParentTag;
    if (lower_event != null and lower_coord != null) return error.DuplicateParentTag;

    if (lower_coord) |coord| {
        if (coord.kind == community_definition_kind) {
            try ensure_top_level_match(&community, &coord, &community_author, parent_author, parent_kind);
            return .{
                .community = community,
                .parent = .{ .coordinate = coord },
                .parent_author = parent_author.pubkey,
                .parent_author_hint = parent_author.hint,
                .parent_kind = parent_kind,
                .relation = .top_level,
                .content = event.content,
            };
        }
        return .{
            .community = community,
            .parent = .{ .coordinate = coord },
            .parent_author = parent_author.pubkey,
            .parent_author_hint = parent_author.hint,
            .parent_kind = parent_kind,
            .relation = .reply,
            .content = event.content,
        };
    }
    return .{
        .community = community,
        .parent = .{ .event = lower_event.? },
        .parent_author = parent_author.pubkey,
        .parent_author_hint = parent_author.hint,
        .parent_kind = parent_kind,
        .relation = .reply,
        .content = event.content,
    };
}

/// Extracts community approvals from a `kind:4550` moderation approval event.
pub fn approval_extract(
    event: *const nip01_event.Event,
    out_communities: []Coordinate,
) CommunityError!Approval {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_communities.len <= limits.tags_max);

    if (event.kind != community_approval_kind) return error.InvalidCommunityApprovalKind;
    if (!std.unicode.utf8ValidateSlice(event.content)) return error.InvalidApprovalContent;

    var info = Approval{
        .content = event.content,
        .approved_author = undefined,
        .approved_kind = 0,
    };
    var author: ?TagPubkey = null;
    var saw_kind = false;
    for (event.tags) |tag| {
        try apply_approval_tag(tag, &info, out_communities, &author, &saw_kind);
    }
    if (info.community_count == 0) return error.MissingCommunityTag;
    if (info.approved == null) {
        return error.MissingApprovedTarget;
    }
    const approved_author = author orelse return error.MissingApprovedAuthorTag;
    if (!saw_kind) return error.MissingApprovedKindTag;
    info.approved_author = approved_author.pubkey;
    info.approved_author_hint = approved_author.hint;
    return info;
}

pub fn build_identifier_tag(
    output: *TagBuilder,
    identifier: []const u8,
) CommunityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn build_name_tag(
    output: *TagBuilder,
    name: []const u8,
) CommunityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    output.items[0] = "name";
    output.items[1] = parse_nonempty_utf8(name) catch return error.InvalidNameTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn build_description_tag(
    output: *TagBuilder,
    description: []const u8,
) CommunityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    output.items[0] = "description";
    output.items[1] = parse_nonempty_utf8(description) catch return error.InvalidDescriptionTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn build_image_tag(
    output: *TagBuilder,
    image_url: []const u8,
    dimensions: ?Dimensions,
) CommunityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    output.items[0] = "image";
    output.items[1] = parse_url(image_url) catch return error.InvalidImageTag;
    output.item_count = 2;
    if (dimensions) |value| {
        if (value.width == 0 or value.height == 0) return error.InvalidImageTag;
        output.items[2] = std.fmt.bufPrint(
            output.text_storage[0][0..],
            "{}x{}",
            .{ value.width, value.height },
        ) catch return error.BufferTooSmall;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

pub fn build_moderator_tag(
    output: *TagBuilder,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
    role: ?[]const u8,
) CommunityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    _ = lower_hex_32.parse(pubkey_hex) catch return error.InvalidModeratorTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    if (relay_hint) |url| {
        output.items[2] = parse_url(url) catch return error.InvalidModeratorTag;
        output.item_count = 3;
    }
    if (role) |text| {
        output.items[output.item_count] = parse_nonempty_utf8(text) catch {
            return error.InvalidModeratorTag;
        };
        output.item_count += 1;
    }
    return output.as_event_tag();
}

pub fn build_relay_tag(
    output: *TagBuilder,
    relay_url: []const u8,
    marker: ?[]const u8,
) CommunityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    output.items[0] = "relay";
    output.items[1] = parse_url(relay_url) catch return error.InvalidRelayTag;
    output.item_count = 2;
    if (marker) |text| {
        output.items[2] = parse_nonempty_utf8(text) catch return error.InvalidRelayTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

pub fn post_build_uppercase_community_tag(
    output: *TagBuilder,
    coordinate_text: []const u8,
    relay_hint: ?[]const u8,
) CommunityError!nip01_event.EventTag {
    return build_case_coordinate_tag(output, "A", coordinate_text, relay_hint, error.InvalidCommunityTag);
}

pub fn post_build_lowercase_community_tag(
    output: *TagBuilder,
    coordinate_text: []const u8,
    relay_hint: ?[]const u8,
) CommunityError!nip01_event.EventTag {
    return build_case_coordinate_tag(output, "a", coordinate_text, relay_hint, error.InvalidParentTag);
}

pub fn post_build_lowercase_parent_event_tag(
    output: *TagBuilder,
    event_id_hex: []const u8,
    relay_hint: ?[]const u8,
) CommunityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    _ = lower_hex_32.parse(event_id_hex) catch return error.InvalidParentTag;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    if (relay_hint) |url| {
        output.items[2] = parse_url(url) catch return error.InvalidParentTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

pub fn post_build_uppercase_author_tag(
    output: *TagBuilder,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
) CommunityError!nip01_event.EventTag {
    return build_case_pubkey_tag(output, "P", pubkey_hex, relay_hint, error.InvalidCommunityAuthorTag);
}

pub fn post_build_lowercase_author_tag(
    output: *TagBuilder,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
) CommunityError!nip01_event.EventTag {
    return build_case_pubkey_tag(output, "p", pubkey_hex, relay_hint, error.InvalidParentAuthorTag);
}

pub fn post_build_uppercase_kind_tag(
    output: *TagBuilder,
    kind: u32,
) CommunityError!nip01_event.EventTag {
    return build_case_kind_tag(output, "K", kind, error.InvalidCommunityKindTag);
}

pub fn post_build_lowercase_kind_tag(
    output: *TagBuilder,
    kind: u32,
) CommunityError!nip01_event.EventTag {
    return build_case_kind_tag(output, "k", kind, error.InvalidParentKindTag);
}

pub fn approval_build_community_tag(
    output: *TagBuilder,
    coordinate_text: []const u8,
    relay_hint: ?[]const u8,
) CommunityError!nip01_event.EventTag {
    return build_case_coordinate_tag(output, "a", coordinate_text, relay_hint, error.InvalidCommunityTag);
}

pub fn approval_build_post_coordinate_tag(
    output: *TagBuilder,
    coordinate_text: []const u8,
    relay_hint: ?[]const u8,
) CommunityError!nip01_event.EventTag {
    return build_case_coordinate_tag(output, "a", coordinate_text, relay_hint, error.InvalidApprovedCoordinateTag);
}

pub fn approval_build_post_event_tag(
    output: *TagBuilder,
    event_id_hex: []const u8,
    relay_hint: ?[]const u8,
) CommunityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    _ = lower_hex_32.parse(event_id_hex) catch return error.InvalidApprovedEventTag;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    if (relay_hint) |url| {
        output.items[2] = parse_url(url) catch return error.InvalidApprovedEventTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

pub fn approval_build_post_author_tag(
    output: *TagBuilder,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
) CommunityError!nip01_event.EventTag {
    return build_case_pubkey_tag(output, "p", pubkey_hex, relay_hint, error.InvalidCommunityAuthorTag);
}

pub fn approval_build_post_kind_tag(
    output: *TagBuilder,
    kind: u32,
) CommunityError!nip01_event.EventTag {
    return build_case_kind_tag(output, "k", kind, error.InvalidApprovedKindTag);
}

const TagPubkey = struct {
    pubkey: [32]u8,
    hint: ?[]const u8 = null,
};

fn apply_community_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    info: *Community,
    out_moderators: []Moderator,
    out_relays: []Relay,
) CommunityError!void {
    std.debug.assert(@intFromPtr(identifier) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, tag.items[0], "name")) return apply_name_tag(tag, info);
    if (std.mem.eql(u8, tag.items[0], "description")) return apply_description_tag(tag, info);
    if (std.mem.eql(u8, tag.items[0], "image")) return apply_image_tag(tag, info);
    if (std.mem.eql(u8, tag.items[0], "p")) return append_moderator(tag, info, out_moderators);
    if (std.mem.eql(u8, tag.items[0], "relay")) return append_relay(tag, info, out_relays);
}

fn apply_identifier_tag(tag: nip01_event.EventTag, field: *?[]const u8) CommunityError!void {
    std.debug.assert(@intFromPtr(field) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (field.* != null) return error.DuplicateIdentifierTag;
    if (tag.items.len != 2) return error.InvalidIdentifierTag;
    field.* = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidIdentifierTag;
}

fn apply_name_tag(tag: nip01_event.EventTag, info: *Community) CommunityError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (info.name != null) return error.DuplicateNameTag;
    if (tag.items.len != 2) return error.InvalidNameTag;
    info.name = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidNameTag;
}

fn apply_description_tag(tag: nip01_event.EventTag, info: *Community) CommunityError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (info.description != null) return error.DuplicateDescriptionTag;
    if (tag.items.len != 2) return error.InvalidDescriptionTag;
    info.description = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidDescriptionTag;
}

fn apply_image_tag(tag: nip01_event.EventTag, info: *Community) CommunityError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (info.image_url != null) return error.DuplicateImageTag;
    if (tag.items.len < 2 or tag.items.len > 3) return error.InvalidImageTag;
    info.image_url = parse_url(tag.items[1]) catch return error.InvalidImageTag;
    if (tag.items.len == 3) {
        info.image_dimensions = parse_dimensions(tag.items[2]) catch return error.InvalidImageTag;
    }
}

fn append_moderator(
    tag: nip01_event.EventTag,
    info: *Community,
    out_moderators: []Moderator,
) CommunityError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.moderator_count <= out_moderators.len);

    if (info.moderator_count == out_moderators.len) return error.BufferTooSmall;
    out_moderators[info.moderator_count] = parse_moderator_tag(tag) catch {
        return error.InvalidModeratorTag;
    };
    info.moderator_count += 1;
}

fn append_relay(
    tag: nip01_event.EventTag,
    info: *Community,
    out_relays: []Relay,
) CommunityError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.relay_count <= out_relays.len);

    if (info.relay_count == out_relays.len) return error.BufferTooSmall;
    out_relays[info.relay_count] = parse_relay_tag(tag) catch return error.InvalidRelayTag;
    info.relay_count += 1;
}

fn apply_post_tag(
    tag: nip01_event.EventTag,
    upper: *?AddressableTarget,
    upper_author: *?TagPubkey,
    saw_upper_kind: *bool,
    lower_coord: *?AddressableTarget,
    lower_event: *?EventRef,
    lower_author: *?TagPubkey,
    lower_kind: *?u32,
) CommunityError!void {
    std.debug.assert(@intFromPtr(upper) != 0);
    std.debug.assert(@intFromPtr(lower_kind) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "A")) return apply_single_coordinate_tag(tag, upper, error.DuplicateCommunityTag, error.InvalidCommunityTag);
    if (std.mem.eql(u8, tag.items[0], "P")) return apply_single_pubkey_tag(tag, upper_author, error.DuplicateCommunityAuthorTag, error.InvalidCommunityAuthorTag);
    if (std.mem.eql(u8, tag.items[0], "K")) return apply_upper_kind_tag(tag, saw_upper_kind);
    if (std.mem.eql(u8, tag.items[0], "a")) return apply_single_coordinate_tag(tag, lower_coord, error.DuplicateParentTag, error.InvalidParentTag);
    if (std.mem.eql(u8, tag.items[0], "e")) return apply_single_event_tag(tag, lower_event, error.DuplicateParentTag, error.InvalidParentTag);
    if (std.mem.eql(u8, tag.items[0], "p")) return apply_single_pubkey_tag(tag, lower_author, error.DuplicateParentAuthorTag, error.InvalidParentAuthorTag);
    if (std.mem.eql(u8, tag.items[0], "k")) return apply_lower_kind_tag(tag, lower_kind);
}

fn apply_approval_tag(
    tag: nip01_event.EventTag,
    info: *Approval,
    out_communities: []Coordinate,
    author: *?TagPubkey,
    saw_kind: *bool,
) CommunityError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(author) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "a")) return apply_approval_a_tag(tag, info, out_communities);
    if (std.mem.eql(u8, tag.items[0], "e")) {
        if (info.approved != null) return error.DuplicateApprovedEventTag;
        info.approved = .{ .event = try parse_event_tag(tag, error.InvalidApprovedEventTag) };
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "p")) {
        return apply_single_pubkey_tag(
            tag,
            author,
            error.DuplicateCommunityAuthorTag,
            error.InvalidCommunityAuthorTag,
        );
    }
    if (std.mem.eql(u8, tag.items[0], "k")) return apply_approval_kind_tag(tag, info, saw_kind);
}

fn apply_approval_a_tag(
    tag: nip01_event.EventTag,
    info: *Approval,
    out_communities: []Coordinate,
) CommunityError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.community_count <= out_communities.len);

    const coordinate = try parse_coordinate_tag(tag, error.InvalidApprovedCoordinateTag);
    if (coordinate.kind == community_definition_kind) {
        if (info.community_count == out_communities.len) return error.BufferTooSmall;
        out_communities[info.community_count] = to_community_coordinate(coordinate);
        info.community_count += 1;
        return;
    }
    if (info.approved != null) return error.DuplicateApprovedCoordinateTag;
    info.approved = .{ .coordinate = coordinate };
}

fn ensure_top_level_match(
    community: *const Coordinate,
    parent: *const AddressableTarget,
    community_author: *const TagPubkey,
    parent_author: TagPubkey,
    parent_kind: u32,
) CommunityError!void {
    std.debug.assert(@intFromPtr(community) != 0);
    std.debug.assert(@intFromPtr(parent) != 0);

    if (parent_kind != community_definition_kind) return error.TopLevelParentKindMismatch;
    if (parent.kind != community_definition_kind) return error.TopLevelCommunityMismatch;
    if (!std.mem.eql(u8, &community.pubkey, &parent.pubkey)) return error.TopLevelCommunityMismatch;
    if (!std.mem.eql(u8, community.identifier, parent.identifier)) return error.TopLevelCommunityMismatch;
    if (!std.mem.eql(u8, &community_author.pubkey, &parent_author.pubkey)) {
        return error.TopLevelCommunityMismatch;
    }
}

fn apply_single_coordinate_tag(
    tag: nip01_event.EventTag,
    field: *?AddressableTarget,
    duplicate_error: CommunityError,
    invalid_error: CommunityError,
) CommunityError!void {
    std.debug.assert(@intFromPtr(field) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (field.* != null) return duplicate_error;
    field.* = try parse_coordinate_tag(tag, invalid_error);
}

fn apply_single_event_tag(
    tag: nip01_event.EventTag,
    field: *?EventRef,
    duplicate_error: CommunityError,
    invalid_error: CommunityError,
) CommunityError!void {
    std.debug.assert(@intFromPtr(field) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (field.* != null) return duplicate_error;
    field.* = try parse_event_tag(tag, invalid_error);
}

fn apply_single_pubkey_tag(
    tag: nip01_event.EventTag,
    field: *?TagPubkey,
    duplicate_error: CommunityError,
    invalid_error: CommunityError,
) CommunityError!void {
    std.debug.assert(@intFromPtr(field) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (field.* != null) return duplicate_error;
    field.* = try parse_pubkey_tag(tag, invalid_error);
}

fn apply_upper_kind_tag(tag: nip01_event.EventTag, saw_upper_kind: *bool) CommunityError!void {
    std.debug.assert(@intFromPtr(saw_upper_kind) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (saw_upper_kind.*) return error.DuplicateCommunityKindTag;
    if (try parse_kind_tag(tag, error.InvalidCommunityKindTag) != community_definition_kind) {
        return error.InvalidCommunityKindTag;
    }
    saw_upper_kind.* = true;
}

fn apply_lower_kind_tag(tag: nip01_event.EventTag, field: *?u32) CommunityError!void {
    std.debug.assert(@intFromPtr(field) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (field.* != null) return error.DuplicateParentKindTag;
    field.* = try parse_kind_tag(tag, error.InvalidParentKindTag);
}

fn apply_approval_kind_tag(
    tag: nip01_event.EventTag,
    info: *Approval,
    saw_kind: *bool,
) CommunityError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(saw_kind) != 0);

    if (saw_kind.*) return error.DuplicateApprovedKindTag;
    info.approved_kind = try parse_kind_tag(tag, error.InvalidApprovedKindTag);
    saw_kind.* = true;
}

fn build_case_coordinate_tag(
    output: *TagBuilder,
    name: []const u8,
    coordinate_text: []const u8,
    relay_hint: ?[]const u8,
    invalid_error: CommunityError,
) CommunityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    _ = parse_coordinate_text(coordinate_text) catch return invalid_error;
    output.items[0] = name;
    output.items[1] = coordinate_text;
    output.item_count = 2;
    if (relay_hint) |url| {
        output.items[2] = parse_url(url) catch return invalid_error;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

fn build_case_pubkey_tag(
    output: *TagBuilder,
    name: []const u8,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
    invalid_error: CommunityError,
) CommunityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    _ = lower_hex_32.parse(pubkey_hex) catch return invalid_error;
    output.items[0] = name;
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    if (relay_hint) |url| {
        output.items[2] = parse_url(url) catch return invalid_error;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

fn build_case_kind_tag(
    output: *TagBuilder,
    name: []const u8,
    kind: u32,
    invalid_error: CommunityError,
) CommunityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(kind <= limits.kind_max);

    if (kind > limits.kind_max) return invalid_error;
    output.items[0] = name;
    output.items[1] = std.fmt.bufPrint(output.text_storage[0][0..], "{d}", .{kind}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

fn parse_moderator_tag(tag: nip01_event.EventTag) CommunityError!Moderator {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len > 0);

    if (tag.items.len < 2 or tag.items.len > 4) return error.InvalidModeratorTag;
    return .{
        .pubkey = lower_hex_32.parse(tag.items[1]) catch return error.InvalidModeratorTag,
        .relay_hint = if (tag.items.len >= 3) parse_url(tag.items[2]) catch {
            return error.InvalidModeratorTag;
        } else null,
        .role = if (tag.items.len == 4) parse_nonempty_utf8(tag.items[3]) catch {
            return error.InvalidModeratorTag;
        } else null,
    };
}

fn parse_relay_tag(tag: nip01_event.EventTag) CommunityError!Relay {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len > 0);

    if (tag.items.len < 2 or tag.items.len > 3) return error.InvalidRelayTag;
    return .{
        .url = parse_url(tag.items[1]) catch return error.InvalidRelayTag,
        .marker = if (tag.items.len == 3) parse_nonempty_utf8(tag.items[2]) catch {
            return error.InvalidRelayTag;
        } else null,
    };
}

fn parse_coordinate_tag(tag: nip01_event.EventTag, invalid_error: CommunityError) CommunityError!AddressableTarget {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len > 0);

    if (tag.items.len < 2 or tag.items.len > 3) return invalid_error;
    const parsed = parse_coordinate_text(tag.items[1]) catch return invalid_error;
    return .{
        .kind = parsed.kind,
        .pubkey = parsed.pubkey,
        .identifier = parsed.identifier,
        .relay_hint = if (tag.items.len == 3) parse_url(tag.items[2]) catch return invalid_error else null,
    };
}

fn parse_event_tag(tag: nip01_event.EventTag, invalid_error: CommunityError) CommunityError!EventRef {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len > 0);

    if (tag.items.len < 2 or tag.items.len > 3) return invalid_error;
    return .{
        .event_id = lower_hex_32.parse(tag.items[1]) catch return invalid_error,
        .relay_hint = if (tag.items.len == 3) parse_url(tag.items[2]) catch return invalid_error else null,
    };
}

fn parse_pubkey_tag(tag: nip01_event.EventTag, invalid_error: CommunityError) CommunityError!TagPubkey {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len > 0);

    if (tag.items.len < 2 or tag.items.len > 3) return invalid_error;
    return .{
        .pubkey = lower_hex_32.parse(tag.items[1]) catch return invalid_error,
        .hint = if (tag.items.len == 3) parse_url(tag.items[2]) catch return invalid_error else null,
    };
}

fn parse_kind_tag(tag: nip01_event.EventTag, invalid_error: CommunityError) CommunityError!u32 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len > 0);

    if (tag.items.len != 2) return invalid_error;
    return std.fmt.parseUnsigned(u32, tag.items[1], 10) catch return invalid_error;
}

const ParsedCoordinate = struct {
    kind: u32,
    pubkey: [32]u8,
    identifier: []const u8,
};

fn parse_coordinate_text(text: []const u8) error{InvalidCoordinate}!ParsedCoordinate {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (text.len == 0) return error.InvalidCoordinate;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidCoordinate;
    var parts = std.mem.splitScalar(u8, text, ':');
    const kind_text = parts.next() orelse return error.InvalidCoordinate;
    const pubkey_text = parts.next() orelse return error.InvalidCoordinate;
    const identifier = parts.next() orelse return error.InvalidCoordinate;
    if (parts.next() != null) return error.InvalidCoordinate;
    return .{
        .kind = std.fmt.parseUnsigned(u32, kind_text, 10) catch return error.InvalidCoordinate,
        .pubkey = lower_hex_32.parse(pubkey_text) catch return error.InvalidCoordinate,
        .identifier = parse_nonempty_utf8(identifier) catch return error.InvalidCoordinate,
    };
}

fn parse_dimensions(text: []const u8) error{InvalidDimensions}!Dimensions {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidDimensions;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidDimensions;
    const split_at = std.mem.indexOfScalar(u8, text, 'x') orelse return error.InvalidDimensions;
    const width = std.fmt.parseUnsigned(u32, text[0..split_at], 10) catch {
        return error.InvalidDimensions;
    };
    const height = std.fmt.parseUnsigned(u32, text[split_at + 1 ..], 10) catch {
        return error.InvalidDimensions;
    };
    if (width == 0 or height == 0) return error.InvalidDimensions;
    return .{ .width = width, .height = height };
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUtf8;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    return url_with_scheme.parse_utf8(text, limits.tag_item_bytes_max);
}

fn to_community_coordinate(target: AddressableTarget) Coordinate {
    std.debug.assert(target.kind == community_definition_kind);
    std.debug.assert(target.identifier.len > 0);

    return .{
        .pubkey = target.pubkey,
        .identifier = target.identifier,
        .relay_hint = target.relay_hint,
    };
}

test "NIP-72 extracts community definition metadata" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "zig" } },
        .{ .items = &.{ "name", "Zig" } },
        .{ .items = &.{ "description", "Zig on nostr" } },
        .{ .items = &.{ "image", "https://cdn.example/zig.png", "640x480" } },
        .{ .items = &.{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "wss://relay.example.com",
            "moderator",
        } },
        .{ .items = &.{ "relay", "wss://relay.example.com", "requests" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x72} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = community_definition_kind,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x22} ** 64,
    };
    var moderators: [1]Moderator = undefined;
    var relays: [1]Relay = undefined;

    const info = try extract(&event, moderators[0..], relays[0..]);

    try std.testing.expectEqualStrings("zig", info.identifier);
    try std.testing.expectEqualStrings("Zig", info.name.?);
    try std.testing.expectEqual(@as(u16, 1), info.moderator_count);
    try std.testing.expectEqual(@as(u16, 1), info.relay_count);
}

test "NIP-72 extracts top-level community posts" {
    const community = "34550:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:zig";
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "A", community, "wss://relay.example.com" } },
        .{ .items = &.{
            "P",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "wss://relay.example.com",
        } },
        .{ .items = &.{ "K", "34550" } },
        .{ .items = &.{ "a", community, "wss://relay.example.com" } },
        .{ .items = &.{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "wss://relay.example.com",
        } },
        .{ .items = &.{ "k", "34550" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x73} ** 32,
        .pubkey = [_]u8{0x12} ** 32,
        .created_at = 2,
        .kind = community_post_kind,
        .tags = tags[0..],
        .content = "hello",
        .sig = [_]u8{0x23} ** 64,
    };

    const info = try post_extract(&event);

    try std.testing.expectEqual(Relation.top_level, info.relation);
    try std.testing.expectEqualStrings("zig", info.community.identifier);
    try std.testing.expectEqual(@as(u32, 34550), info.parent_kind);
}

test "NIP-72 extracts community approvals" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "a",
            "34550:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:zig",
            "wss://relay.example.com",
        } },
        .{ .items = &.{
            "e",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            "wss://relay.example.com",
        } },
        .{ .items = &.{
            "p",
            "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
            "wss://relay.example.com",
        } },
        .{ .items = &.{ "k", "1111" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x74} ** 32,
        .pubkey = [_]u8{0x13} ** 32,
        .created_at = 3,
        .kind = community_approval_kind,
        .tags = tags[0..],
        .content = "{\"kind\":1111}",
        .sig = [_]u8{0x24} ** 64,
    };
    var communities: [1]Coordinate = undefined;

    const info = try approval_extract(&event, communities[0..]);

    try std.testing.expectEqual(@as(u16, 1), info.community_count);
    try std.testing.expect(info.approved != null);
    try std.testing.expect(info.approved.? == .event);
    try std.testing.expectEqual(@as(u32, 1111), info.approved_kind);
}

test "NIP-72 builds community tags" {
    var coord_built: TagBuilder = .{};
    var kind_built: TagBuilder = .{};

    const a_tag = try post_build_uppercase_community_tag(
        &coord_built,
        "34550:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:zig",
        "wss://relay.example.com",
    );
    const k_tag = try post_build_lowercase_kind_tag(&kind_built, 1111);

    try std.testing.expectEqualStrings("A", a_tag.items[0]);
    try std.testing.expectEqualStrings("k", k_tag.items[0]);
    try std.testing.expectEqualStrings("1111", k_tag.items[1]);
}

test "NIP-72 rejects overlong identifier builder input with typed error" {
    var built: TagBuilder = .{};
    const overlong = [_]u8{'a'} ** (limits.tag_item_bytes_max + 1);

    try std.testing.expectError(
        error.InvalidIdentifierTag,
        build_identifier_tag(&built, overlong[0..]),
    );
}

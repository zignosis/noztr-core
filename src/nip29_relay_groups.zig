const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const group_metadata_kind: u32 = 39000;
pub const group_admins_kind: u32 = 39001;
pub const group_members_kind: u32 = 39002;

pub const Nip29Error = error{
    InvalidGroupKind,
    InvalidIdentifierTag,
    DuplicateIdentifierTag,
    MissingIdentifierTag,
    InvalidNameTag,
    DuplicateNameTag,
    InvalidPictureTag,
    DuplicatePictureTag,
    InvalidAboutTag,
    DuplicateAboutTag,
    InvalidFlagTag,
    DuplicateFlagTag,
    ConflictingFlagTag,
    InvalidAdminTag,
    InvalidMemberTag,
    BufferTooSmall,
};

pub const GroupMetadataFlag = enum {
    private,
    restricted,
    hidden,
    closed,

    pub fn as_text(self: GroupMetadataFlag) []const u8 {
        std.debug.assert(@intFromEnum(self) <= std.math.maxInt(u8));
        std.debug.assert(@typeInfo(GroupMetadataFlag).@"enum".fields.len == 4);

        return switch (self) {
            .private => "private",
            .restricted => "restricted",
            .hidden => "hidden",
            .closed => "closed",
        };
    }
};

pub const GroupMetadata = struct {
    group_id: []const u8,
    name: ?[]const u8 = null,
    picture: ?[]const u8 = null,
    about: ?[]const u8 = null,
    is_private: bool = false,
    is_restricted: bool = false,
    is_hidden: bool = false,
    is_closed: bool = false,
};

pub const GroupAdmin = struct {
    pubkey: [32]u8,
    roles: []const []const u8,
};

pub const GroupMember = struct {
    pubkey: [32]u8,
    label: ?[]const u8 = null,
};

pub const GroupAdminsInfo = struct {
    group_id: []const u8,
    admins: []const GroupAdmin,
};

pub const GroupMembersInfo = struct {
    group_id: []const u8,
    members: []const GroupMember,
};

pub const BuiltTag = struct {
    items: [limits.tag_items_max][]const u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded NIP-29 group metadata from a kind-39000 event.
pub fn group_metadata_extract(event: *const nip01_event.Event) Nip29Error!GroupMetadata {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != group_metadata_kind) return error.InvalidGroupKind;

    var metadata = GroupMetadata{ .group_id = "" };
    var flags = MetadataFlags{};
    for (event.tags) |tag| {
        try apply_metadata_tag(tag, &metadata, &flags);
    }
    if (metadata.group_id.len == 0) return error.MissingIdentifierTag;
    try validate_flag_conflicts(&flags);
    return metadata;
}

/// Extracts bounded NIP-29 group-admin entries from a kind-39001 event.
pub fn group_admins_extract(
    event: *const nip01_event.Event,
    out_admins: []GroupAdmin,
    out_roles: [][]const u8,
) Nip29Error!GroupAdminsInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_admins.len <= limits.tags_max);

    if (event.kind != group_admins_kind) return error.InvalidGroupKind;

    var group_id: []const u8 = "";
    var admin_count: u16 = 0;
    var role_count: u16 = 0;
    for (event.tags) |tag| {
        try apply_admin_tag(tag, &group_id, out_admins, out_roles, &admin_count, &role_count);
    }
    if (group_id.len == 0) return error.MissingIdentifierTag;
    return .{
        .group_id = group_id,
        .admins = out_admins[0..admin_count],
    };
}

/// Extracts bounded NIP-29 group-member entries from a kind-39002 event.
pub fn group_members_extract(
    event: *const nip01_event.Event,
    out_members: []GroupMember,
) Nip29Error!GroupMembersInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_members.len <= limits.tags_max);

    if (event.kind != group_members_kind) return error.InvalidGroupKind;

    var group_id: []const u8 = "";
    var member_count: u16 = 0;
    for (event.tags) |tag| {
        try apply_member_tag(tag, &group_id, out_members, &member_count);
    }
    if (group_id.len == 0) return error.MissingIdentifierTag;
    return .{
        .group_id = group_id,
        .members = out_members[0..member_count],
    };
}

/// Builds a canonical NIP-29 `d` tag.
pub fn group_build_identifier_tag(
    output: *BuiltTag,
    group_id: []const u8,
) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(group_id.len <= limits.tag_item_bytes_max);

    output.items[0] = "d";
    output.items[1] = parse_group_id(group_id) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical NIP-29 `name` tag.
pub fn group_build_name_tag(output: *BuiltTag, name: []const u8) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(name.len <= limits.tag_item_bytes_max);

    output.items[0] = "name";
    output.items[1] = parse_nonempty_utf8(name) catch return error.InvalidNameTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical NIP-29 `picture` tag.
pub fn group_build_picture_tag(
    output: *BuiltTag,
    picture_url: []const u8,
) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(picture_url.len <= limits.tag_item_bytes_max);

    output.items[0] = "picture";
    output.items[1] = parse_url(picture_url) catch return error.InvalidPictureTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical NIP-29 `about` tag.
pub fn group_build_about_tag(
    output: *BuiltTag,
    about: []const u8,
) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(about.len <= limits.tag_item_bytes_max);

    output.items[0] = "about";
    output.items[1] = parse_nonempty_utf8(about) catch return error.InvalidAboutTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical NIP-29 metadata flag tag.
pub fn group_build_flag_tag(
    output: *BuiltTag,
    flag: GroupMetadataFlag,
) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromEnum(flag) <= std.math.maxInt(u8));

    output.items[0] = flag.as_text();
    output.item_count = 1;
    return output.as_event_tag();
}

/// Builds a canonical NIP-29 admin `p` tag with raw role labels.
pub fn group_build_admin_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
    roles: []const []const u8,
) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(roles.len + 2 <= limits.tag_items_max);

    _ = parse_lower_hex_32(pubkey_hex) catch return error.InvalidAdminTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    for (roles, 0..) |role, index| {
        output.items[index + 2] = parse_role(role) catch return error.InvalidAdminTag;
        output.item_count += 1;
    }
    return output.as_event_tag();
}

/// Builds a bounded NIP-29 member `p` tag with optional compatibility label.
pub fn group_build_member_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
    label: ?[]const u8,
) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(pubkey_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(pubkey_hex) catch return error.InvalidMemberTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    if (label) |value| {
        output.items[2] = parse_member_label(value) catch return error.InvalidMemberTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

const MetadataFlags = struct {
    saw_private: bool = false,
    saw_public: bool = false,
    saw_restricted: bool = false,
    saw_hidden: bool = false,
    saw_closed: bool = false,
    saw_open: bool = false,
};

fn apply_metadata_tag(
    tag: nip01_event.EventTag,
    metadata: *GroupMetadata,
    flags: *MetadataFlags,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(metadata) != 0);
    std.debug.assert(@intFromPtr(flags) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return parse_identifier_tag(tag, &metadata.group_id);
    if (std.mem.eql(u8, tag.items[0], "name")) return parse_name_tag(tag, metadata);
    if (std.mem.eql(u8, tag.items[0], "picture")) return parse_picture_tag(tag, metadata);
    if (std.mem.eql(u8, tag.items[0], "about")) return parse_about_tag(tag, metadata);
    return parse_metadata_flag(tag, metadata, flags);
}

fn parse_identifier_tag(tag: nip01_event.EventTag, group_id: *[]const u8) Nip29Error!void {
    std.debug.assert(@intFromPtr(group_id) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (!std.mem.eql(u8, tag.items[0], "d")) return;
    if (group_id.*.len != 0) return error.DuplicateIdentifierTag;
    if (tag.items.len != 2) return error.InvalidIdentifierTag;
    group_id.* = parse_group_id(tag.items[1]) catch return error.InvalidIdentifierTag;
}

fn parse_name_tag(tag: nip01_event.EventTag, metadata: *GroupMetadata) Nip29Error!void {
    std.debug.assert(@intFromPtr(metadata) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (metadata.name != null) return error.DuplicateNameTag;
    if (tag.items.len != 2) return error.InvalidNameTag;
    metadata.name = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidNameTag;
}

fn parse_picture_tag(tag: nip01_event.EventTag, metadata: *GroupMetadata) Nip29Error!void {
    std.debug.assert(@intFromPtr(metadata) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (metadata.picture != null) return error.DuplicatePictureTag;
    if (tag.items.len != 2) return error.InvalidPictureTag;
    metadata.picture = parse_url(tag.items[1]) catch return error.InvalidPictureTag;
}

fn parse_about_tag(tag: nip01_event.EventTag, metadata: *GroupMetadata) Nip29Error!void {
    std.debug.assert(@intFromPtr(metadata) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (metadata.about != null) return error.DuplicateAboutTag;
    if (tag.items.len != 2) return error.InvalidAboutTag;
    metadata.about = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidAboutTag;
}

fn parse_metadata_flag(
    tag: nip01_event.EventTag,
    metadata: *GroupMetadata,
    flags: *MetadataFlags,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(metadata) != 0);
    std.debug.assert(@intFromPtr(flags) != 0);

    if (tag.items.len != 1) return;
    if (std.mem.eql(u8, tag.items[0], "private")) {
        if (flags.saw_private) return error.DuplicateFlagTag;
        flags.saw_private = true;
        metadata.is_private = true;
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "restricted")) {
        if (flags.saw_restricted) return error.DuplicateFlagTag;
        flags.saw_restricted = true;
        metadata.is_restricted = true;
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "hidden")) {
        if (flags.saw_hidden) return error.DuplicateFlagTag;
        flags.saw_hidden = true;
        metadata.is_hidden = true;
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "closed")) {
        if (flags.saw_closed) return error.DuplicateFlagTag;
        flags.saw_closed = true;
        metadata.is_closed = true;
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "public")) {
        if (flags.saw_public) return error.DuplicateFlagTag;
        flags.saw_public = true;
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "open")) {
        if (flags.saw_open) return error.DuplicateFlagTag;
        flags.saw_open = true;
    }
}

fn validate_flag_conflicts(flags: *const MetadataFlags) Nip29Error!void {
    std.debug.assert(@intFromPtr(flags) != 0);
    std.debug.assert(@sizeOf(MetadataFlags) > 0);

    if (flags.saw_private and flags.saw_public) return error.ConflictingFlagTag;
    if (flags.saw_closed and flags.saw_open) return error.ConflictingFlagTag;
}

fn apply_admin_tag(
    tag: nip01_event.EventTag,
    group_id: *[]const u8,
    out_admins: []GroupAdmin,
    out_roles: [][]const u8,
    admin_count: *u16,
    role_count: *u16,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(group_id) != 0);
    std.debug.assert(@intFromPtr(admin_count) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return parse_identifier_tag(tag, group_id);
    if (!std.mem.eql(u8, tag.items[0], "p")) return;
    try parse_admin_tag(tag, out_admins, out_roles, admin_count, role_count);
}

fn parse_admin_tag(
    tag: nip01_event.EventTag,
    out_admins: []GroupAdmin,
    out_roles: [][]const u8,
    admin_count: *u16,
    role_count: *u16,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(admin_count) != 0);
    std.debug.assert(@intFromPtr(role_count) != 0);

    if (tag.items.len < 2) return error.InvalidAdminTag;
    if (admin_count.* == out_admins.len) return error.BufferTooSmall;
    const roles_start = role_count.*;
    for (tag.items[2..]) |role| {
        if (role_count.* == out_roles.len) return error.BufferTooSmall;
        out_roles[role_count.*] = parse_role(role) catch return error.InvalidAdminTag;
        role_count.* += 1;
    }
    out_admins[admin_count.*] = .{
        .pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidAdminTag,
        .roles = out_roles[roles_start..role_count.*],
    };
    admin_count.* += 1;
}

fn apply_member_tag(
    tag: nip01_event.EventTag,
    group_id: *[]const u8,
    out_members: []GroupMember,
    member_count: *u16,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(group_id) != 0);
    std.debug.assert(@intFromPtr(member_count) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return parse_identifier_tag(tag, group_id);
    if (!std.mem.eql(u8, tag.items[0], "p")) return;
    try parse_member_tag(tag, out_members, member_count);
}

fn parse_member_tag(
    tag: nip01_event.EventTag,
    out_members: []GroupMember,
    member_count: *u16,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(member_count) != 0);
    std.debug.assert(out_members.len <= limits.tags_max);

    if (tag.items.len != 2 and tag.items.len != 3) return error.InvalidMemberTag;
    if (member_count.* == out_members.len) return error.BufferTooSmall;
    out_members[member_count.*] = .{
        .pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidMemberTag,
        .label = null,
    };
    if (tag.items.len == 3 and tag.items[2].len != 0) {
        out_members[member_count.*].label =
            parse_member_label(tag.items[2]) catch return error.InvalidMemberTag;
    }
    member_count.* += 1;
}

fn parse_group_id(text: []const u8) error{InvalidGroupId}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidGroupId;
    for (text) |byte| {
        if (byte >= 'a' and byte <= 'z') continue;
        if (byte >= '0' and byte <= '9') continue;
        if (byte == '-' or byte == '_') continue;
        return error.InvalidGroupId;
    }
    return text;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidText}![]const u8 {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (text.len == 0) return error.InvalidText;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidText;
    return text;
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

fn parse_role(text: []const u8) error{InvalidRole}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidRole;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidRole;
    if (contains_ascii_space(text)) return error.InvalidRole;
    return text;
}

fn parse_member_label(text: []const u8) error{InvalidLabel}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidLabel;
    if (contains_ascii_control(text)) return error.InvalidLabel;
    return text;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.id_hex_length);
    std.debug.assert(limits.id_hex_length == 64);

    var output: [32]u8 = undefined;
    if (text.len != limits.id_hex_length) return error.InvalidHex;
    for (text) |byte| {
        if (byte >= '0' and byte <= '9') continue;
        if (byte >= 'a' and byte <= 'f') continue;
        return error.InvalidHex;
    }
    _ = std.fmt.hexToBytes(&output, text) catch return error.InvalidHex;
    return output;
}

fn contains_ascii_space(text: []const u8) bool {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max >= limits.tag_item_bytes_max);

    for (text) |byte| {
        if (std.ascii.isWhitespace(byte)) return true;
    }
    return false;
}

fn contains_ascii_control(text: []const u8) bool {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max >= limits.tag_item_bytes_max);

    for (text) |byte| {
        if (std.ascii.isControl(byte)) return true;
    }
    return false;
}

fn test_event(kind: u32, tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(kind <= std.math.maxInt(u32));
    std.debug.assert(tags.len <= limits.tags_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = kind,
        .tags = tags,
        .content = "",
        .sig = [_]u8{0} ** 64,
    };
}

test "group metadata extract accepts canonical and compatibility tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{ "name", "Pizza Lovers" } },
        .{ .items = &.{ "picture", "https://pizza.example/pizza.png" } },
        .{ .items = &.{ "about", "a group for people who love pizza" } },
        .{ .items = &.{"private"} },
        .{ .items = &.{"open"} },
    };

    const metadata = try group_metadata_extract(&test_event(group_metadata_kind, tags[0..]));

    try std.testing.expectEqualStrings("pizza-lovers", metadata.group_id);
    try std.testing.expectEqualStrings("Pizza Lovers", metadata.name.?);
    try std.testing.expectEqualStrings("https://pizza.example/pizza.png", metadata.picture.?);
    try std.testing.expect(metadata.is_private);
    try std.testing.expect(!metadata.is_closed);
}

test "group metadata extract rejects duplicate and conflicting flags" {
    const duplicate_d = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{ "d", "pizza-lovers" } },
    };
    const conflicting = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{"private"} },
        .{ .items = &.{"public"} },
    };

    try std.testing.expectError(
        error.DuplicateIdentifierTag,
        group_metadata_extract(&test_event(group_metadata_kind, duplicate_d[0..])),
    );
    try std.testing.expectError(
        error.ConflictingFlagTag,
        group_metadata_extract(&test_event(group_metadata_kind, conflicting[0..])),
    );
}

test "group admins extract preserves ordered raw roles" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "ceo",
            "gardener",
        } },
        .{ .items = &.{ "name", "ignored" } },
    };
    var admins: [1]GroupAdmin = undefined;
    var roles: [2][]const u8 = undefined;

    const info = try group_admins_extract(
        &test_event(group_admins_kind, tags[0..]),
        admins[0..],
        roles[0..],
    );

    try std.testing.expectEqualStrings("pizza-lovers", info.group_id);
    try std.testing.expectEqual(@as(usize, 1), info.admins.len);
    try std.testing.expectEqual(@as(usize, 2), info.admins[0].roles.len);
    try std.testing.expectEqualStrings("ceo", info.admins[0].roles[0]);
    try std.testing.expectEqualStrings("gardener", info.admins[0].roles[1]);
}

test "group members extract accepts optional compatibility labels" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "",
        } },
        .{ .items = &.{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            "vip",
        } },
    };
    var members: [2]GroupMember = undefined;

    const info = try group_members_extract(&test_event(group_members_kind, tags[0..]), members[0..]);

    try std.testing.expectEqualStrings("pizza-lovers", info.group_id);
    try std.testing.expectEqual(@as(usize, 2), info.members.len);
    try std.testing.expect(info.members[0].label == null);
    try std.testing.expectEqualStrings("vip", info.members[1].label.?);
}

test "group builders emit canonical metadata admin and member tags" {
    var identifier_tag: BuiltTag = .{};
    var admin_tag: BuiltTag = .{};
    var member_tag: BuiltTag = .{};

    const identifier = try group_build_identifier_tag(&identifier_tag, "pizza-lovers");
    const admin = try group_build_admin_tag(
        &admin_tag,
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        &.{ "ceo", "gardener" },
    );
    const member = try group_build_member_tag(
        &member_tag,
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "vip",
    );

    try std.testing.expectEqualStrings("d", identifier.items[0]);
    try std.testing.expectEqualStrings("pizza-lovers", identifier.items[1]);
    try std.testing.expectEqualStrings("p", admin.items[0]);
    try std.testing.expectEqualStrings("ceo", admin.items[2]);
    try std.testing.expectEqualStrings("gardener", admin.items[3]);
    try std.testing.expectEqualStrings("vip", member.items[2]);
}

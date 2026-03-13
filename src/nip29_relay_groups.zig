const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const group_metadata_kind: u32 = 39000;
pub const group_admins_kind: u32 = 39001;
pub const group_members_kind: u32 = 39002;
pub const group_roles_kind: u32 = 39003;
pub const group_put_user_kind: u32 = 9000;
pub const group_remove_user_kind: u32 = 9001;
pub const group_join_request_kind: u32 = 9021;
pub const group_leave_request_kind: u32 = 9022;

pub const Nip29Error = error{
    InvalidGroupKind,
    InvalidGroupReference,
    InvalidGroupHost,
    GroupStateMismatch,
    InvalidGroupTag,
    DuplicateGroupTag,
    MissingGroupTag,
    InvalidRoleTag,
    InvalidCodeTag,
    DuplicateCodeTag,
    InvalidPreviousTag,
    InvalidPutUserTag,
    DuplicatePutUserTag,
    MissingPutUserTag,
    InvalidRemoveUserTag,
    DuplicateRemoveUserTag,
    MissingRemoveUserTag,
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
    label: ?[]const u8 = null,
    roles: []const []const u8,
};

pub const GroupReference = struct {
    host: []const u8,
    id: []const u8,
};

pub const group_state_user_roles_max: u16 = limits.tag_items_max - 2;

pub const GroupMember = struct {
    pubkey: [32]u8,
    label: ?[]const u8 = null,
};

pub const GroupRole = struct {
    name: []const u8,
    description: ?[]const u8 = null,
};

pub const GroupAdminsInfo = struct {
    group_id: []const u8,
    admins: []const GroupAdmin,
};

pub const GroupMembersInfo = struct {
    group_id: []const u8,
    members: []const GroupMember,
};

pub const GroupRolesInfo = struct {
    group_id: []const u8,
    roles: []const GroupRole,
};

pub const GroupJoinRequestInfo = struct {
    group_id: []const u8,
    invite_code: ?[]const u8 = null,
    reason: ?[]const u8 = null,
    previous_refs: []const []const u8,
};

pub const GroupLeaveRequestInfo = struct {
    group_id: []const u8,
    reason: ?[]const u8 = null,
    previous_refs: []const []const u8,
};

pub const GroupPutUserInfo = struct {
    group_id: []const u8,
    pubkey: [32]u8,
    roles: []const []const u8,
    reason: ?[]const u8 = null,
    previous_refs: []const []const u8,
};

pub const GroupRemoveUserInfo = struct {
    group_id: []const u8,
    pubkey: [32]u8,
    reason: ?[]const u8 = null,
    previous_refs: []const []const u8,
};

pub const GroupStateUser = struct {
    pubkey: [32]u8,
    label: ?[]const u8 = null,
    roles: []const []const u8 = &.{},
    is_member: bool = false,
};

pub const GroupState = struct {
    metadata: GroupMetadata = .{ .group_id = "" },
    users: []GroupStateUser = &.{},
    supported_roles: []GroupRole = &.{},
    user_storage: []GroupStateUser,
    supported_role_storage: []GroupRole,
    user_role_storage: [][]const u8,

    pub fn init(
        user_storage: []GroupStateUser,
        supported_role_storage: []GroupRole,
        user_role_storage: [][]const u8,
    ) GroupState {
        std.debug.assert(user_storage.len <= limits.tags_max);
        std.debug.assert(
            user_role_storage.len >= user_storage.len * group_state_user_roles_max,
        );

        return .{
            .user_storage = user_storage,
            .supported_role_storage = supported_role_storage,
            .user_role_storage = user_role_storage,
        };
    }

    pub fn reset(self: *GroupState) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(self.user_storage.len <= limits.tags_max);

        self.metadata = .{ .group_id = "" };
        self.users = self.user_storage[0..0];
        self.supported_roles = self.supported_role_storage[0..0];
    }
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

/// Parse a raw `<host>'<group-id>` group reference. Host-only input defaults `id` to `_`.
pub fn group_reference_parse(text: []const u8) Nip29Error!GroupReference {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    const separator = std.mem.indexOfScalar(u8, text, '\'');
    if (separator == null) {
        return .{
            .host = parse_group_host(text) catch return error.InvalidGroupReference,
            .id = "_",
        };
    }
    const split = separator.?;
    if (split == 0 or split + 1 >= text.len) return error.InvalidGroupReference;
    return .{
        .host = parse_group_host(text[0..split]) catch return error.InvalidGroupReference,
        .id = parse_group_id(text[split + 1 ..]) catch return error.InvalidGroupReference,
    };
}

/// Build a raw `<host>'<group-id>` group reference.
pub fn group_reference_build(output: []u8, reference: *const GroupReference) Nip29Error![]const u8 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(reference) != 0);

    const host = parse_group_host(reference.host) catch return error.InvalidGroupReference;
    const group_id = parse_group_id(reference.id) catch return error.InvalidGroupReference;
    return std.fmt.bufPrint(output, "{s}'{s}", .{ host, group_id }) catch {
        return error.BufferTooSmall;
    };
}

/// Extract bounded NIP-29 group-role entries from a kind-39003 event.
pub fn group_roles_extract(
    event: *const nip01_event.Event,
    out_roles: []GroupRole,
) Nip29Error!GroupRolesInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_roles.len <= limits.tags_max);

    if (event.kind != group_roles_kind) return error.InvalidGroupKind;

    var group_id: []const u8 = "";
    var role_count: u16 = 0;
    for (event.tags) |tag| {
        try apply_role_tag(tag, &group_id, out_roles, &role_count);
    }
    if (group_id.len == 0) return error.MissingIdentifierTag;
    return .{
        .group_id = group_id,
        .roles = out_roles[0..role_count],
    };
}

/// Applies one caller-supplied NIP-29 event to fixed-capacity group state.
pub fn group_state_apply_event(
    state: *GroupState,
    event: *const nip01_event.Event,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(event) != 0);

    switch (event.kind) {
        group_metadata_kind => try reduce_metadata_event(state, event),
        group_admins_kind => try reduce_admins_event(state, event),
        group_members_kind => try reduce_members_event(state, event),
        group_roles_kind => try reduce_supported_roles_event(state, event),
        group_put_user_kind => try reduce_put_user_event(state, event),
        group_remove_user_kind => try reduce_remove_user_event(state, event),
        else => {},
    }
}

/// Applies a caller-supplied canonical sequence of NIP-29 events to fixed-capacity group state.
pub fn group_state_apply_events(
    state: *GroupState,
    events: []const nip01_event.Event,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(state.users.len <= state.user_storage.len);
    std.debug.assert(state.supported_roles.len <= state.supported_role_storage.len);

    for (events) |*event| {
        try group_state_apply_event(state, event);
    }
}

/// Extract a bounded NIP-29 join request from a kind-9021 event.
pub fn group_join_request_extract(
    event: *const nip01_event.Event,
    previous_out: [][]const u8,
) Nip29Error!GroupJoinRequestInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(previous_out.len <= limits.tags_max);

    if (event.kind != group_join_request_kind) return error.InvalidGroupKind;
    return extract_join_request(event, previous_out);
}

/// Extract a bounded NIP-29 leave request from a kind-9022 event.
pub fn group_leave_request_extract(
    event: *const nip01_event.Event,
    previous_out: [][]const u8,
) Nip29Error!GroupLeaveRequestInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(previous_out.len <= limits.tags_max);

    if (event.kind != group_leave_request_kind) return error.InvalidGroupKind;
    return extract_leave_request(event, previous_out);
}

/// Extract a bounded NIP-29 put-user moderation event from a kind-9000 event.
pub fn group_put_user_extract(
    event: *const nip01_event.Event,
    out_roles: [][]const u8,
    out_previous: [][]const u8,
) Nip29Error!GroupPutUserInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_roles.len <= limits.tags_max);

    if (event.kind != group_put_user_kind) return error.InvalidGroupKind;
    return extract_put_user(event, out_roles, out_previous);
}

/// Extract a bounded NIP-29 remove-user moderation event from a kind-9001 event.
pub fn group_remove_user_extract(
    event: *const nip01_event.Event,
    out_previous: [][]const u8,
) Nip29Error!GroupRemoveUserInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_previous.len <= limits.tags_max);

    if (event.kind != group_remove_user_kind) return error.InvalidGroupKind;
    return extract_remove_user(event, out_previous);
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

/// Builds a canonical NIP-29 `h` tag for user or moderation events.
pub fn group_build_group_tag(output: *BuiltTag, group_id: []const u8) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(group_id.len <= limits.tag_item_bytes_max);

    output.items[0] = "h";
    output.items[1] = parse_group_id(group_id) catch return error.InvalidGroupTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical NIP-29 `role` tag for kind-39003 events.
pub fn group_build_role_tag(
    output: *BuiltTag,
    role_name: []const u8,
    description: ?[]const u8,
) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(role_name.len <= limits.tag_item_bytes_max);

    output.items[0] = "role";
    output.items[1] = parse_role(role_name) catch return error.InvalidRoleTag;
    output.item_count = 2;
    if (description) |value| {
        output.items[2] = parse_nonempty_utf8(value) catch return error.InvalidRoleTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical NIP-29 `code` tag for join requests.
pub fn group_build_code_tag(output: *BuiltTag, code: []const u8) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(code.len <= limits.tag_item_bytes_max);

    output.items[0] = "code";
    output.items[1] = parse_nonempty_utf8(code) catch return error.InvalidCodeTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical NIP-29 `previous` tag.
pub fn group_build_previous_tag(
    output: *BuiltTag,
    previous_ref: []const u8,
) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(previous_ref.len <= limits.tag_item_bytes_max);

    output.items[0] = "previous";
    output.items[1] = parse_previous_ref(previous_ref) catch return error.InvalidPreviousTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical NIP-29 `p` tag for put/remove user moderation events.
pub fn group_build_user_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
    roles: []const []const u8,
) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(roles.len + 2 <= limits.tag_items_max);

    _ = parse_lower_hex_32(pubkey_hex) catch return error.InvalidPutUserTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    for (roles, 0..) |role, index| {
        output.items[index + 2] = parse_role(role) catch return error.InvalidPutUserTag;
        output.item_count += 1;
    }
    return output.as_event_tag();
}

/// Builds a canonical NIP-29 admin `p` tag with optional compatibility label.
pub fn group_build_admin_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
    label: ?[]const u8,
    roles: []const []const u8,
) Nip29Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(roles.len + 3 <= limits.tag_items_max);

    _ = parse_lower_hex_32(pubkey_hex) catch return error.InvalidAdminTag;
    if (roles.len == 0) return error.InvalidAdminTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    if (label) |value| {
        if (value.len == 0) return error.InvalidAdminTag;
        output.items[2] = parse_member_label(value) catch return error.InvalidAdminTag;
        output.item_count = 3;
    }
    const roles_offset: u8 = if (label == null) 2 else 3;
    for (roles, 0..) |role, index| {
        output.items[index + roles_offset] = parse_role(role) catch return error.InvalidAdminTag;
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
        if (value.len == 0) return error.InvalidMemberTag;
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
    const label = admin_label_item(tag) catch return error.InvalidAdminTag;
    const role_items = admin_permission_items(tag);
    for (role_items) |role| {
        if (role_count.* == out_roles.len) return error.BufferTooSmall;
        out_roles[role_count.*] = parse_role(role) catch return error.InvalidAdminTag;
        role_count.* += 1;
    }
    out_admins[admin_count.*] = .{
        .pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidAdminTag,
        .label = label,
        .roles = out_roles[roles_start..role_count.*],
    };
    admin_count.* += 1;
}

fn admin_label_item(tag: nip01_event.EventTag) error{InvalidLabel}!?[]const u8 {
    std.debug.assert(tag.items.len >= 2);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 4) return null;
    if (tag.items[2].len == 0) return null;
    return try parse_member_label(tag.items[2]);
}

fn admin_permission_items(tag: nip01_event.EventTag) []const []const u8 {
    std.debug.assert(tag.items.len >= 2);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 3) return tag.items[2..];
    if (tag.items.len == 3) return tag.items[2..];
    return tag.items[3..];
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

fn apply_role_tag(
    tag: nip01_event.EventTag,
    group_id: *[]const u8,
    out_roles: []GroupRole,
    role_count: *u16,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(group_id) != 0);
    std.debug.assert(@intFromPtr(role_count) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return parse_identifier_tag(tag, group_id);
    if (!std.mem.eql(u8, tag.items[0], "role")) return;
    try parse_role_tag(tag, out_roles, role_count);
}

fn parse_role_tag(
    tag: nip01_event.EventTag,
    out_roles: []GroupRole,
    role_count: *u16,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(role_count) != 0);
    std.debug.assert(out_roles.len <= limits.tags_max);

    if (tag.items.len != 2 and tag.items.len != 3) return error.InvalidRoleTag;
    if (role_count.* == out_roles.len) return error.BufferTooSmall;
    out_roles[role_count.*] = .{
        .name = parse_role(tag.items[1]) catch return error.InvalidRoleTag,
        .description = null,
    };
    if (tag.items.len == 3) {
        out_roles[role_count.*].description =
            parse_nonempty_utf8(tag.items[2]) catch return error.InvalidRoleTag;
    }
    role_count.* += 1;
}

fn extract_join_request(
    event: *const nip01_event.Event,
    previous_out: [][]const u8,
) Nip29Error!GroupJoinRequestInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(previous_out.len <= limits.tags_max);

    var info = GroupJoinRequestInfo{
        .group_id = "",
        .reason = parse_optional_reason(event.content) catch return error.InvalidGroupTag,
        .previous_refs = previous_out[0..0],
    };
    var previous_count: u16 = 0;
    var saw_code = false;
    for (event.tags) |tag| {
        try apply_join_request_tag(tag, &info, previous_out, &previous_count, &saw_code);
    }
    if (info.group_id.len == 0) return error.MissingGroupTag;
    info.previous_refs = previous_out[0..previous_count];
    return info;
}

fn apply_join_request_tag(
    tag: nip01_event.EventTag,
    info: *GroupJoinRequestInfo,
    previous_out: [][]const u8,
    previous_count: *u16,
    saw_code: *bool,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(previous_count) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "h")) return parse_group_tag(tag, &info.group_id);
    if (std.mem.eql(u8, tag.items[0], "previous")) {
        return parse_previous_tag(tag, previous_out, previous_count);
    }
    if (!std.mem.eql(u8, tag.items[0], "code")) return;
    if (saw_code.*) return error.DuplicateCodeTag;
    if (tag.items.len != 2) return error.InvalidCodeTag;
    info.invite_code = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidCodeTag;
    saw_code.* = true;
}

fn extract_leave_request(
    event: *const nip01_event.Event,
    previous_out: [][]const u8,
) Nip29Error!GroupLeaveRequestInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(previous_out.len <= limits.tags_max);

    var info = GroupLeaveRequestInfo{
        .group_id = "",
        .reason = parse_optional_reason(event.content) catch return error.InvalidGroupTag,
        .previous_refs = previous_out[0..0],
    };
    var previous_count: u16 = 0;
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (std.mem.eql(u8, tag.items[0], "h")) {
            try parse_group_tag(tag, &info.group_id);
            continue;
        }
        if (std.mem.eql(u8, tag.items[0], "previous")) {
            try parse_previous_tag(tag, previous_out, &previous_count);
        }
    }
    if (info.group_id.len == 0) return error.MissingGroupTag;
    info.previous_refs = previous_out[0..previous_count];
    return info;
}

fn extract_put_user(
    event: *const nip01_event.Event,
    out_roles: [][]const u8,
    out_previous: [][]const u8,
) Nip29Error!GroupPutUserInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_roles.len <= limits.tags_max);

    var info = GroupPutUserInfo{
        .group_id = "",
        .pubkey = undefined,
        .roles = out_roles[0..0],
        .reason = parse_optional_reason(event.content) catch return error.InvalidGroupTag,
        .previous_refs = out_previous[0..0],
    };
    var state = UserEventState{};
    for (event.tags) |tag| {
        try apply_put_user_tag(tag, &info, out_roles, out_previous, &state);
    }
    return finalize_put_user_info(&info, &state);
}

const UserEventState = struct {
    saw_group: bool = false,
    saw_target: bool = false,
    role_count: u16 = 0,
    previous_count: u16 = 0,
};

fn apply_put_user_tag(
    tag: nip01_event.EventTag,
    info: *GroupPutUserInfo,
    out_roles: [][]const u8,
    out_previous: [][]const u8,
    state: *UserEventState,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(state) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "h")) {
        if (state.saw_group) return error.DuplicateGroupTag;
        try parse_group_tag(tag, &info.group_id);
        state.saw_group = true;
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "previous")) {
        return parse_previous_tag(tag, out_previous, &state.previous_count);
    }
    if (!std.mem.eql(u8, tag.items[0], "p")) return;
    if (state.saw_target) return error.DuplicatePutUserTag;
    try parse_user_tag(tag, &info.pubkey, out_roles, &state.role_count);
    state.saw_target = true;
}

fn finalize_put_user_info(
    info: *GroupPutUserInfo,
    state: *const UserEventState,
) Nip29Error!GroupPutUserInfo {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(state) != 0);

    if (!state.saw_group) return error.MissingGroupTag;
    if (!state.saw_target) return error.MissingPutUserTag;
    info.roles = info.roles.ptr[0..state.role_count];
    info.previous_refs = info.previous_refs.ptr[0..state.previous_count];
    return info.*;
}

fn extract_remove_user(
    event: *const nip01_event.Event,
    out_previous: [][]const u8,
) Nip29Error!GroupRemoveUserInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_previous.len <= limits.tags_max);

    var info = GroupRemoveUserInfo{
        .group_id = "",
        .pubkey = undefined,
        .reason = parse_optional_reason(event.content) catch return error.InvalidGroupTag,
        .previous_refs = out_previous[0..0],
    };
    var state = RemoveUserState{};
    for (event.tags) |tag| {
        try apply_remove_user_tag(tag, &info, out_previous, &state);
    }
    if (!state.saw_group) return error.MissingGroupTag;
    if (!state.saw_target) return error.MissingRemoveUserTag;
    info.previous_refs = out_previous[0..state.previous_count];
    return info;
}

const RemoveUserState = struct {
    saw_group: bool = false,
    saw_target: bool = false,
    previous_count: u16 = 0,
};

fn apply_remove_user_tag(
    tag: nip01_event.EventTag,
    info: *GroupRemoveUserInfo,
    out_previous: [][]const u8,
    state: *RemoveUserState,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(state) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "h")) {
        if (state.saw_group) return error.DuplicateGroupTag;
        try parse_group_tag(tag, &info.group_id);
        state.saw_group = true;
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "previous")) {
        return parse_previous_tag(tag, out_previous, &state.previous_count);
    }
    if (!std.mem.eql(u8, tag.items[0], "p")) return;
    if (state.saw_target) return error.DuplicateRemoveUserTag;
    if (tag.items.len != 2) return error.InvalidRemoveUserTag;
    info.pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidRemoveUserTag;
    state.saw_target = true;
}

fn parse_group_tag(tag: nip01_event.EventTag, group_id: *[]const u8) Nip29Error!void {
    std.debug.assert(@intFromPtr(group_id) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2 and tag.items.len != 3) return error.InvalidGroupTag;
    group_id.* = parse_group_id(tag.items[1]) catch return error.InvalidGroupTag;
    if (tag.items.len == 3 and tag.items[2].len != 0) {
        _ = parse_url(tag.items[2]) catch return error.InvalidGroupTag;
    }
}

fn reduce_metadata_event(
    state: *GroupState,
    event: *const nip01_event.Event,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(event.kind == group_metadata_kind);

    const metadata = try group_metadata_extract(event);
    try ensure_state_group_id(state, metadata.group_id);
    state.metadata = metadata;
}

fn reduce_supported_roles_event(
    state: *GroupState,
    event: *const nip01_event.Event,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(event.kind == group_roles_kind);

    const info = try group_roles_extract(event, state.supported_role_storage);
    try ensure_state_group_id(state, info.group_id);
    state.supported_roles = state.supported_role_storage[0..info.roles.len];
}

fn reduce_admins_event(
    state: *GroupState,
    event: *const nip01_event.Event,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(event.kind == group_admins_kind);

    var group_id: []const u8 = "";
    clear_admin_snapshot(state);
    for (event.tags) |tag| {
        try reduce_admin_snapshot_tag(state, tag, &group_id);
    }
    if (group_id.len == 0) return error.MissingIdentifierTag;
    try ensure_state_group_id(state, group_id);
    compact_inactive_users(state);
}

fn reduce_admin_snapshot_tag(
    state: *GroupState,
    tag: nip01_event.EventTag,
    group_id: *[]const u8,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(group_id) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return parse_identifier_tag(tag, group_id);
    if (!std.mem.eql(u8, tag.items[0], "p")) return;
    try apply_admin_snapshot_user(state, tag);
}

fn apply_admin_snapshot_user(state: *GroupState, tag: nip01_event.EventTag) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 2) return error.InvalidAdminTag;
    const pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidAdminTag;
    const user_index = try ensure_user_slot(state, &pubkey);
    try set_user_roles(state, user_index, admin_permission_items(tag), error.InvalidAdminTag);
}

fn reduce_members_event(
    state: *GroupState,
    event: *const nip01_event.Event,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(event.kind == group_members_kind);

    var group_id: []const u8 = "";
    clear_member_snapshot(state);
    for (event.tags) |tag| {
        try reduce_member_snapshot_tag(state, tag, &group_id);
    }
    if (group_id.len == 0) return error.MissingIdentifierTag;
    try ensure_state_group_id(state, group_id);
    compact_inactive_users(state);
}

fn reduce_member_snapshot_tag(
    state: *GroupState,
    tag: nip01_event.EventTag,
    group_id: *[]const u8,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(group_id) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return parse_identifier_tag(tag, group_id);
    if (!std.mem.eql(u8, tag.items[0], "p")) return;
    try apply_member_snapshot_user(state, tag);
}

fn apply_member_snapshot_user(state: *GroupState, tag: nip01_event.EventTag) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2 and tag.items.len != 3) return error.InvalidMemberTag;
    var user = GroupMember{
        .pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidMemberTag,
        .label = null,
    };
    if (tag.items.len == 3 and tag.items[2].len != 0) {
        user.label = parse_member_label(tag.items[2]) catch return error.InvalidMemberTag;
    }
    const user_index = try ensure_user_slot(state, &user.pubkey);
    state.user_storage[user_index].label = user.label;
    state.user_storage[user_index].is_member = true;
}

fn reduce_put_user_event(
    state: *GroupState,
    event: *const nip01_event.Event,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(event.kind == group_put_user_kind);

    var roles: [group_state_user_roles_max][]const u8 = undefined;
    var previous: [0][]const u8 = .{};
    const info = try group_put_user_extract(event, roles[0..], previous[0..]);
    const user_index = try ensure_user_slot(state, &info.pubkey);
    try ensure_state_group_id(state, info.group_id);
    try set_user_roles(state, user_index, info.roles, error.InvalidPutUserTag);
    state.user_storage[user_index].is_member = true;
}

fn reduce_remove_user_event(
    state: *GroupState,
    event: *const nip01_event.Event,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(event.kind == group_remove_user_kind);

    var previous: [0][]const u8 = .{};
    const info = try group_remove_user_extract(event, previous[0..]);
    try ensure_state_group_id(state, info.group_id);
    const user_index = find_user_index(state, &info.pubkey) orelse return;
    clear_user(state, user_index);
    compact_inactive_users(state);
}

fn ensure_state_group_id(state: *GroupState, group_id: []const u8) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(group_id.len <= limits.tag_item_bytes_max);

    if (state.metadata.group_id.len == 0) {
        state.metadata.group_id = group_id;
        return;
    }
    if (!std.mem.eql(u8, state.metadata.group_id, group_id)) {
        return error.GroupStateMismatch;
    }
}

fn clear_admin_snapshot(state: *GroupState) void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(state.users.len <= state.user_storage.len);

    for (state.users) |*user| {
        user.roles = &.{};
    }
}

fn clear_member_snapshot(state: *GroupState) void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(state.users.len <= state.user_storage.len);

    for (state.users) |*user| {
        user.is_member = false;
        user.label = null;
    }
}

fn ensure_user_slot(state: *GroupState, pubkey: *const [32]u8) Nip29Error!u16 {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(pubkey) != 0);

    if (find_user_index(state, pubkey)) |index| return index;
    if (state.users.len == state.user_storage.len) return error.BufferTooSmall;
    const index: u16 = @intCast(state.users.len);
    state.user_storage[index] = .{ .pubkey = pubkey.* };
    state.users = state.user_storage[0 .. state.users.len + 1];
    return index;
}

fn find_user_index(state: *const GroupState, pubkey: *const [32]u8) ?u16 {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(pubkey) != 0);

    for (state.users, 0..) |user, index| {
        if (std.mem.eql(u8, user.pubkey[0..], pubkey[0..])) return @intCast(index);
    }
    return null;
}

fn set_user_roles(
    state: *GroupState,
    user_index: u16,
    role_items: []const []const u8,
    invalid_error: Nip29Error,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(user_index < state.user_storage.len);

    if (role_items.len > group_state_user_roles_max) return error.BufferTooSmall;
    const slot = user_role_slot(state, user_index);
    for (role_items, 0..) |role, index| {
        slot[index] = parse_role(role) catch return invalid_error;
    }
    state.user_storage[user_index].roles = slot[0..role_items.len];
}

fn user_role_slot(state: *GroupState, user_index: u16) [][]const u8 {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(user_index < state.user_storage.len);

    const start: usize = @intCast(user_index * group_state_user_roles_max);
    const end: usize = start + group_state_user_roles_max;
    return state.user_role_storage[start..end];
}

fn clear_user(state: *GroupState, user_index: u16) void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(user_index < state.user_storage.len);

    state.user_storage[user_index].roles = &.{};
    state.user_storage[user_index].label = null;
    state.user_storage[user_index].is_member = false;
}

fn compact_inactive_users(state: *GroupState) void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(state.users.len <= state.user_storage.len);

    var index: u16 = 0;
    while (index < state.users.len) {
        if (user_is_active(&state.user_storage[index])) {
            index += 1;
            continue;
        }
        remove_user_at(state, index);
    }
}

fn user_is_active(user: *const GroupStateUser) bool {
    std.debug.assert(@intFromPtr(user) != 0);
    std.debug.assert(user.roles.len <= group_state_user_roles_max);

    return user.is_member or user.roles.len != 0;
}

fn remove_user_at(state: *GroupState, user_index: u16) void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(user_index < state.user_storage.len);

    const last_index: u16 = @intCast(state.users.len - 1);
    if (user_index != last_index) {
        state.user_storage[user_index] = state.user_storage[last_index];
        const dst = user_role_slot(state, user_index);
        const src = user_role_slot(state, last_index);
        for (src, 0..) |role, index| {
            dst[index] = role;
        }
        state.user_storage[user_index].roles =
            dst[0..state.user_storage[user_index].roles.len];
    }
    state.users = state.user_storage[0..last_index];
}

fn parse_user_tag(
    tag: nip01_event.EventTag,
    pubkey: *[32]u8,
    out_roles: [][]const u8,
    role_count: *u16,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(pubkey) != 0);
    std.debug.assert(@intFromPtr(role_count) != 0);

    if (tag.items.len < 2) return error.InvalidPutUserTag;
    pubkey.* = parse_lower_hex_32(tag.items[1]) catch return error.InvalidPutUserTag;
    for (tag.items[2..]) |role| {
        if (role_count.* == out_roles.len) return error.BufferTooSmall;
        out_roles[role_count.*] = parse_role(role) catch return error.InvalidPutUserTag;
        role_count.* += 1;
    }
}

fn parse_previous_tag(
    tag: nip01_event.EventTag,
    out_previous: [][]const u8,
    previous_count: *u16,
) Nip29Error!void {
    std.debug.assert(@intFromPtr(previous_count) != 0);
    std.debug.assert(out_previous.len <= limits.tags_max);

    if (tag.items.len != 2) return error.InvalidPreviousTag;
    if (previous_count.* == out_previous.len) return error.BufferTooSmall;
    out_previous[previous_count.*] =
        parse_previous_ref(tag.items[1]) catch return error.InvalidPreviousTag;
    previous_count.* += 1;
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

fn parse_group_host(text: []const u8) error{InvalidHost}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidHost;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidHost;
    for (text) |byte| {
        if (std.ascii.isWhitespace(byte)) return error.InvalidHost;
        if (byte == '\'' or byte == '/' or byte == '?' or byte == '#') return error.InvalidHost;
    }
    return text;
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

fn parse_previous_ref(text: []const u8) error{InvalidPrevious}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len != 8) return error.InvalidPrevious;
    for (text) |byte| {
        if (byte >= '0' and byte <= '9') continue;
        if (byte >= 'a' and byte <= 'f') continue;
        return error.InvalidPrevious;
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

fn parse_optional_reason(text: []const u8) error{InvalidReason}!?[]const u8 {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (text.len == 0) return null;
    return parse_nonempty_utf8(text) catch return error.InvalidReason;
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

fn test_event_with_content(
    kind: u32,
    tags: []const nip01_event.EventTag,
    content: []const u8,
) nip01_event.Event {
    std.debug.assert(kind <= std.math.maxInt(u32));
    std.debug.assert(content.len <= limits.content_bytes_max);

    const event = test_event(kind, tags);
    return .{
        .id = event.id,
        .pubkey = event.pubkey,
        .created_at = event.created_at,
        .kind = event.kind,
        .tags = event.tags,
        .content = content,
        .sig = event.sig,
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

test "group admins extract preserves compatibility label and ordered permissions" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "ceo",
            "put-user",
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
    try std.testing.expectEqualStrings("ceo", info.admins[0].label.?);
    try std.testing.expectEqual(@as(usize, 2), info.admins[0].roles.len);
    try std.testing.expectEqualStrings("put-user", info.admins[0].roles[0]);
    try std.testing.expectEqualStrings("gardener", info.admins[0].roles[1]);
}

test "group admins extract ignores empty compatibility label before permissions" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "",
            "put-user",
            "delete-event",
        } },
    };
    var admins: [1]GroupAdmin = undefined;
    var roles: [2][]const u8 = undefined;

    const info = try group_admins_extract(
        &test_event(group_admins_kind, tags[0..]),
        admins[0..],
        roles[0..],
    );

    try std.testing.expectEqual(@as(usize, 1), info.admins.len);
    try std.testing.expect(info.admins[0].label == null);
    try std.testing.expectEqual(@as(usize, 2), info.admins[0].roles.len);
    try std.testing.expectEqualStrings("put-user", info.admins[0].roles[0]);
    try std.testing.expectEqualStrings("delete-event", info.admins[0].roles[1]);
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
        "ceo",
        &.{ "put-user", "gardener" },
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
    try std.testing.expectEqualStrings("put-user", admin.items[3]);
    try std.testing.expectEqualStrings("gardener", admin.items[4]);
    try std.testing.expectEqualStrings("vip", member.items[2]);
}

test "group builders reject empty optional role and label output" {
    var admin_tag: BuiltTag = .{};
    var member_tag: BuiltTag = .{};

    try std.testing.expectError(
        error.InvalidAdminTag,
        group_build_admin_tag(
            &admin_tag,
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "",
            &.{},
        ),
    );
    try std.testing.expectError(
        error.InvalidMemberTag,
        group_build_member_tag(
            &member_tag,
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "",
        ),
    );
    try std.testing.expectError(
        error.InvalidAdminTag,
        group_build_admin_tag(
            &admin_tag,
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "",
            &.{ "put-user" },
        ),
    );
}

test "group reference parse and build keep host and id" {
    var output: [64]u8 = undefined;

    const parsed = try group_reference_parse("groups.example'pizza-lovers");
    const root = try group_reference_parse("groups.example");
    const built = try group_reference_build(output[0..], &parsed);

    try std.testing.expectEqualStrings("groups.example", parsed.host);
    try std.testing.expectEqualStrings("pizza-lovers", parsed.id);
    try std.testing.expectEqualStrings("_", root.id);
    try std.testing.expectEqualStrings("groups.example'pizza-lovers", built);
}

test "group roles extract and moderation builders are bounded" {
    const role_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{ "role", "admin", "full access" } },
        .{ .items = &.{ "role", "moderator" } },
    };
    var roles: [2]GroupRole = undefined;
    var role_tag: BuiltTag = .{};
    var group_tag: BuiltTag = .{};
    var previous_tag: BuiltTag = .{};
    var user_tag: BuiltTag = .{};
    var code_tag: BuiltTag = .{};

    const parsed = try group_roles_extract(&test_event(group_roles_kind, role_tags[0..]), roles[0..]);
    const built_role = try group_build_role_tag(&role_tag, "admin", "full access");
    const built_group = try group_build_group_tag(&group_tag, "pizza-lovers");
    const built_previous = try group_build_previous_tag(&previous_tag, "deadbeef");
    const built_user = try group_build_user_tag(
        &user_tag,
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        &.{ "admin", "moderator" },
    );
    const built_code = try group_build_code_tag(&code_tag, "invite-123");

    try std.testing.expectEqualStrings("pizza-lovers", parsed.group_id);
    try std.testing.expectEqual(@as(usize, 2), parsed.roles.len);
    try std.testing.expectEqualStrings("admin", parsed.roles[0].name);
    try std.testing.expectEqualStrings("role", built_role.items[0]);
    try std.testing.expectEqualStrings("h", built_group.items[0]);
    try std.testing.expectEqualStrings("previous", built_previous.items[0]);
    try std.testing.expectEqualStrings("p", built_user.items[0]);
    try std.testing.expectEqualStrings("code", built_code.items[0]);
}

test "group join leave and user moderation extraction stays bounded" {
    const join_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "h", "pizza-lovers", "wss://groups.example" } },
        .{ .items = &.{ "code", "invite-123" } },
        .{ .items = &.{ "previous", "deadbeef" } },
    };
    const leave_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "h", "pizza-lovers", "wss://groups.example" } },
        .{ .items = &.{ "previous", "feedbead" } },
    };
    const put_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "h", "pizza-lovers", "wss://groups.example" } },
        .{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "admin",
            "moderator",
        } },
        .{ .items = &.{ "previous", "deadbeef" } },
    };
    const remove_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "h", "pizza-lovers", "wss://groups.example" } },
        .{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        } },
        .{ .items = &.{ "previous", "feedbead" } },
    };
    var join_previous: [1][]const u8 = undefined;
    var leave_previous: [1][]const u8 = undefined;
    var put_roles: [2][]const u8 = undefined;
    var put_previous: [1][]const u8 = undefined;
    var remove_previous: [1][]const u8 = undefined;

    const join = try group_join_request_extract(
        &test_event_with_content(group_join_request_kind, join_tags[0..], "please let me in"),
        join_previous[0..],
    );
    const leave = try group_leave_request_extract(
        &test_event_with_content(group_leave_request_kind, leave_tags[0..], "bye"),
        leave_previous[0..],
    );
    const put_user = try group_put_user_extract(
        &test_event_with_content(group_put_user_kind, put_tags[0..], "adding moderator"),
        put_roles[0..],
        put_previous[0..],
    );
    const remove_user = try group_remove_user_extract(
        &test_event_with_content(group_remove_user_kind, remove_tags[0..], "removing spammer"),
        remove_previous[0..],
    );

    try std.testing.expectEqualStrings("pizza-lovers", join.group_id);
    try std.testing.expectEqualStrings("invite-123", join.invite_code.?);
    try std.testing.expectEqual(@as(usize, 1), join.previous_refs.len);
    try std.testing.expectEqualStrings("pizza-lovers", leave.group_id);
    try std.testing.expectEqual(@as(usize, 1), leave.previous_refs.len);
    try std.testing.expectEqual(@as(usize, 2), put_user.roles.len);
    try std.testing.expectEqualStrings("admin", put_user.roles[0]);
    try std.testing.expectEqual(@as(usize, 1), remove_user.previous_refs.len);
}

test "group join request rejects invalid relay-hint h tag" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "h", "pizza-lovers", "bad relay" } },
    };
    var previous: [1][]const u8 = undefined;

    try std.testing.expectError(
        error.InvalidGroupTag,
        group_join_request_extract(
            &test_event_with_content(group_join_request_kind, tags[0..], ""),
            previous[0..],
        ),
    );
}

test "group state reducer applies snapshots and moderation updates" {
    const metadata_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{ "name", "Pizza Lovers" } },
        .{ .items = &.{"public"} },
    };
    const role_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{ "role", "moderator", "can delete spam" } },
    };
    const admin_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "moderator",
        } },
    };
    const member_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "vip",
        } },
        .{ .items = &.{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
    };
    const put_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "h", "pizza-lovers" } },
        .{ .items = &.{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "moderator",
        } },
    };
    const remove_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "h", "pizza-lovers" } },
        .{ .items = &.{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
    };
    const ignored_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "h", "pizza-lovers" } },
    };
    const events = [_]nip01_event.Event{
        test_event(group_metadata_kind, metadata_tags[0..]),
        test_event(group_roles_kind, role_tags[0..]),
        test_event(group_admins_kind, admin_tags[0..]),
        test_event(group_members_kind, member_tags[0..]),
        test_event_with_content(group_put_user_kind, put_tags[0..], "promote"),
        test_event_with_content(group_remove_user_kind, remove_tags[0..], "remove"),
        test_event_with_content(group_join_request_kind, ignored_tags[0..], "ignored"),
    };
    var users: [2]GroupStateUser = undefined;
    var roles: [1]GroupRole = undefined;
    var user_roles: [2 * group_state_user_roles_max][]const u8 = undefined;
    var state = GroupState.init(users[0..], roles[0..], user_roles[0..]);

    state.reset();
    try group_state_apply_events(&state, events[0..]);

    try std.testing.expectEqualStrings("pizza-lovers", state.metadata.group_id);
    try std.testing.expectEqualStrings("Pizza Lovers", state.metadata.name.?);
    try std.testing.expectEqual(@as(usize, 1), state.supported_roles.len);
    try std.testing.expectEqualStrings("moderator", state.supported_roles[0].name);
    try std.testing.expectEqual(@as(usize, 1), state.users.len);
    try std.testing.expect(state.users[0].is_member);
    try std.testing.expectEqualStrings("vip", state.users[0].label.?);
    try std.testing.expectEqual(@as(usize, 1), state.users[0].roles.len);
    try std.testing.expectEqualStrings("moderator", state.users[0].roles[0]);
}

test "group state reducer replaces snapshots and rejects mixed groups" {
    const first_admins = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "ceo",
        } },
        .{ .items = &.{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            "moderator",
        } },
    };
    const second_admins = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            "gardener",
        } },
    };
    const other_metadata = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "other-group" } },
    };
    var users: [2]GroupStateUser = undefined;
    var roles: [1]GroupRole = undefined;
    var user_roles: [2 * group_state_user_roles_max][]const u8 = undefined;
    var state = GroupState.init(users[0..], roles[0..], user_roles[0..]);

    state.reset();
    try group_state_apply_event(&state, &test_event(group_admins_kind, first_admins[0..]));
    try group_state_apply_event(&state, &test_event(group_admins_kind, second_admins[0..]));

    try std.testing.expectEqual(@as(usize, 1), state.users.len);
    try std.testing.expectEqualStrings("pizza-lovers", state.metadata.group_id);
    try std.testing.expectEqualStrings("gardener", state.users[0].roles[0]);
    try std.testing.expectError(
        error.GroupStateMismatch,
        group_state_apply_event(&state, &test_event(group_metadata_kind, other_metadata[0..])),
    );
}

test "group state reducer ignores admin compatibility label for roles" {
    const admin_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "pizza-lovers" } },
        .{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "ceo",
            "put-user",
            "delete-event",
        } },
    };
    var users: [1]GroupStateUser = undefined;
    var roles: [0]GroupRole = .{};
    var user_roles: [group_state_user_roles_max][]const u8 = undefined;
    var state = GroupState.init(users[0..], roles[0..], user_roles[0..]);

    state.reset();
    try group_state_apply_event(&state, &test_event(group_admins_kind, admin_tags[0..]));

    try std.testing.expectEqual(@as(usize, 1), state.users.len);
    try std.testing.expectEqual(@as(usize, 2), state.users[0].roles.len);
    try std.testing.expectEqualStrings("put-user", state.users[0].roles[0]);
    try std.testing.expectEqualStrings("delete-event", state.users[0].roles[1]);
}

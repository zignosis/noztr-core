const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const repository_announcement_kind: u32 = 30617;
pub const repository_state_kind: u32 = 30618;
pub const user_grasp_list_kind: u32 = 10317;

pub const Nip34Error = error{
    InvalidRepositoryAnnouncementKind,
    InvalidRepositoryStateKind,
    InvalidUserGraspListKind,
    MissingIdentifierTag,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    DuplicateNameTag,
    InvalidNameTag,
    DuplicateDescriptionTag,
    InvalidDescriptionTag,
    DuplicateEarliestUniqueCommitTag,
    InvalidEarliestUniqueCommitTag,
    InvalidWebTag,
    InvalidCloneTag,
    InvalidRelaysTag,
    InvalidMaintainersTag,
    InvalidTopicTag,
    DuplicateHeadTag,
    InvalidHeadTag,
    InvalidRefTag,
    InvalidGraspTag,
    BufferTooSmall,
};

pub const RepositoryAnnouncementInfo = struct {
    identifier: []const u8,
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    earliest_unique_commit: ?[]const u8 = null,
    is_personal_fork: bool = false,
    web_count: u16 = 0,
    clone_count: u16 = 0,
    relay_count: u16 = 0,
    maintainer_count: u16 = 0,
    topic_count: u16 = 0,
};

pub const RepositoryStateRef = struct {
    name: []const u8,
    commit_id: []const u8,
};

pub const RepositoryStateInfo = struct {
    identifier: []const u8,
    head_ref: ?[]const u8 = null,
    ref_count: u16 = 0,
};

pub const UserGraspListInfo = struct {
    server_count: u16 = 0,
};

pub const BuiltTag = struct {
    items: [limits.tag_items_max][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded repository-announcement metadata from a `kind:30617` event.
pub fn repository_announcement_extract(
    event: *const nip01_event.Event,
    out_web: [][]const u8,
    out_clone: [][]const u8,
    out_relays: [][]const u8,
    out_maintainers: [][32]u8,
    out_topics: [][]const u8,
) Nip34Error!RepositoryAnnouncementInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_web.len <= limits.tags_max);

    if (event.kind != repository_announcement_kind) return error.InvalidRepositoryAnnouncementKind;

    var identifier: ?[]const u8 = null;
    var info = RepositoryAnnouncementInfo{ .identifier = undefined };
    for (event.tags) |tag| {
        try apply_announcement_tag(tag, &identifier, &info, out_web, out_clone, out_relays, out_maintainers, out_topics);
    }
    info.identifier = identifier orelse return error.MissingIdentifierTag;
    return info;
}

/// Extracts bounded repository state from a `kind:30618` event.
pub fn repository_state_extract(
    event: *const nip01_event.Event,
    out_refs: []RepositoryStateRef,
) Nip34Error!RepositoryStateInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_refs.len <= limits.tags_max);

    if (event.kind != repository_state_kind) return error.InvalidRepositoryStateKind;

    var identifier: ?[]const u8 = null;
    var info = RepositoryStateInfo{ .identifier = undefined };
    for (event.tags) |tag| {
        try apply_state_tag(tag, &identifier, &info, out_refs);
    }
    info.identifier = identifier orelse return error.MissingIdentifierTag;
    return info;
}

/// Extracts bounded grasp-server URLs from a `kind:10317` user grasp list.
pub fn user_grasp_list_extract(
    event: *const nip01_event.Event,
    out_servers: [][]const u8,
) Nip34Error!UserGraspListInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_servers.len <= limits.tags_max);

    if (event.kind != user_grasp_list_kind) return error.InvalidUserGraspListKind;

    var info = UserGraspListInfo{};
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (!std.mem.eql(u8, tag.items[0], "g")) continue;
        if (tag.items.len != 2) return error.InvalidGraspTag;
        if (info.server_count == out_servers.len) return error.BufferTooSmall;
        out_servers[info.server_count] = parse_url(tag.items[1]) catch return error.InvalidGraspTag;
        info.server_count += 1;
    }
    return info;
}

/// Builds a repository `d` tag.
pub fn repository_build_identifier_tag(
    output: *BuiltTag,
    identifier: []const u8,
) Nip34Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a repository `name` tag.
pub fn repository_build_name_tag(
    output: *BuiltTag,
    name: []const u8,
) Nip34Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(name.len <= limits.tag_item_bytes_max);

    output.items[0] = "name";
    output.items[1] = parse_nonempty_utf8(name) catch return error.InvalidNameTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a repository `description` tag.
pub fn repository_build_description_tag(
    output: *BuiltTag,
    description: []const u8,
) Nip34Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(description.len <= limits.tag_item_bytes_max);

    output.items[0] = "description";
    output.items[1] = parse_nonempty_utf8(description) catch return error.InvalidDescriptionTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a multi-value repository URL or relay tag (`web`, `clone`, or `relays`).
pub fn repository_build_url_list_tag(
    output: *BuiltTag,
    name: []const u8,
    values: []const []const u8,
) Nip34Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(values.len + 1 <= limits.tag_items_max);

    if (!is_supported_url_list_name(name)) return error.InvalidWebTag;
    if (values.len == 0) return error.InvalidWebTag;
    output.items[0] = name;
    output.item_count = 1;
    for (values) |value| {
        output.items[output.item_count] = parse_url(value) catch return map_url_list_error(name);
        output.item_count += 1;
    }
    return output.as_event_tag();
}

/// Builds the `r` earliest-unique-commit tag.
pub fn repository_build_earliest_unique_commit_tag(
    output: *BuiltTag,
    commit_id: []const u8,
) Nip34Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(commit_id.len <= limits.tag_item_bytes_max);

    output.items[0] = "r";
    output.items[1] = parse_commit_id(commit_id) catch return error.InvalidEarliestUniqueCommitTag;
    output.items[2] = "euc";
    output.item_count = 3;
    return output.as_event_tag();
}

/// Builds the multi-value `maintainers` tag.
pub fn repository_build_maintainers_tag(
    output: *BuiltTag,
    pubkeys: []const []const u8,
) Nip34Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(pubkeys.len + 1 <= limits.tag_items_max);

    if (pubkeys.len == 0) return error.InvalidMaintainersTag;
    output.items[0] = "maintainers";
    output.item_count = 1;
    for (pubkeys) |pubkey| {
        _ = parse_lower_hex_32(pubkey) catch return error.InvalidMaintainersTag;
        output.items[output.item_count] = pubkey;
        output.item_count += 1;
    }
    return output.as_event_tag();
}

/// Builds a repository `t` topic tag.
pub fn repository_build_topic_tag(
    output: *BuiltTag,
    topic: []const u8,
) Nip34Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(topic.len <= limits.tag_item_bytes_max);

    output.items[0] = "t";
    output.items[1] = parse_nonempty_utf8(topic) catch return error.InvalidTopicTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a repository-state `refs/...` tag.
pub fn repository_build_ref_tag(
    output: *BuiltTag,
    ref_name: []const u8,
    commit_id: []const u8,
) Nip34Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(ref_name.len <= limits.tag_item_bytes_max);

    output.items[0] = parse_ref_name(ref_name) catch return error.InvalidRefTag;
    output.items[1] = parse_commit_id(commit_id) catch return error.InvalidRefTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds the repository-state `HEAD` tag.
pub fn repository_build_head_tag(
    output: *BuiltTag,
    ref_name: []const u8,
) Nip34Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(ref_name.len <= limits.tag_item_bytes_max - 5);

    output.items[0] = "HEAD";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "ref: {s}", .{
        parse_ref_name(ref_name) catch return error.InvalidHeadTag,
    }) catch return error.BufferTooSmall;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds the multi-value grasp-server `g` tag.
pub fn repository_build_grasp_servers_tag(
    output: *BuiltTag,
    urls: []const []const u8,
) Nip34Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(urls.len + 1 <= limits.tag_items_max);

    if (urls.len == 0) return error.InvalidGraspTag;
    output.items[0] = "g";
    output.item_count = 1;
    for (urls) |url| {
        output.items[output.item_count] = parse_url(url) catch return error.InvalidGraspTag;
        output.item_count += 1;
    }
    return output.as_event_tag();
}

fn apply_announcement_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    info: *RepositoryAnnouncementInfo,
    out_web: [][]const u8,
    out_clone: [][]const u8,
    out_relays: [][]const u8,
    out_maintainers: [][32]u8,
    out_topics: [][]const u8,
) Nip34Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, name, "name")) return apply_text_tag(tag, &info.name, error.DuplicateNameTag, error.InvalidNameTag);
    if (std.mem.eql(u8, name, "description")) return apply_text_tag(tag, &info.description, error.DuplicateDescriptionTag, error.InvalidDescriptionTag);
    if (std.mem.eql(u8, name, "web")) return append_url_values(tag, &info.web_count, out_web, error.InvalidWebTag);
    if (std.mem.eql(u8, name, "clone")) return append_url_values(tag, &info.clone_count, out_clone, error.InvalidCloneTag);
    if (std.mem.eql(u8, name, "relays")) return append_url_values(tag, &info.relay_count, out_relays, error.InvalidRelaysTag);
    if (std.mem.eql(u8, name, "maintainers")) return append_maintainers(tag, info, out_maintainers);
    if (std.mem.eql(u8, name, "t")) return append_topic(tag, info, out_topics);
    if (std.mem.eql(u8, name, "r")) return apply_euc_tag(tag, info);
}

fn apply_state_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    info: *RepositoryStateInfo,
    out_refs: []RepositoryStateRef,
) Nip34Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, tag.items[0], "HEAD")) return apply_head_tag(tag, info);
    if (!std.mem.startsWith(u8, tag.items[0], "refs/")) return;
    if (tag.items.len < 2) return error.InvalidRefTag;
    if (info.ref_count == out_refs.len) return error.BufferTooSmall;
    out_refs[info.ref_count] = .{
        .name = parse_ref_name(tag.items[0]) catch return error.InvalidRefTag,
        .commit_id = parse_commit_id(tag.items[1]) catch return error.InvalidRefTag,
    };
    info.ref_count += 1;
}

fn apply_identifier_tag(tag: nip01_event.EventTag, identifier: *?[]const u8) Nip34Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(identifier) != 0);

    if (identifier.* != null) return error.DuplicateIdentifierTag;
    if (tag.items.len != 2) return error.InvalidIdentifierTag;
    identifier.* = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidIdentifierTag;
}

fn apply_text_tag(
    tag: nip01_event.EventTag,
    field: *?[]const u8,
    duplicate_error: Nip34Error,
    invalid_error: Nip34Error,
) Nip34Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = parse_nonempty_utf8(tag.items[1]) catch return invalid_error;
}

fn append_url_values(
    tag: nip01_event.EventTag,
    count: *u16,
    out: [][]const u8,
    invalid_error: Nip34Error,
) Nip34Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(count) != 0);

    if (tag.items.len < 2) return invalid_error;
    for (tag.items[1..]) |value| {
        if (count.* == out.len) return error.BufferTooSmall;
        out[count.*] = parse_url(value) catch return invalid_error;
        count.* += 1;
    }
}

fn append_maintainers(
    tag: nip01_event.EventTag,
    info: *RepositoryAnnouncementInfo,
    out: [][32]u8,
) Nip34Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(out.len <= limits.tags_max);

    if (tag.items.len < 2) return error.InvalidMaintainersTag;
    for (tag.items[1..]) |value| {
        if (info.maintainer_count == out.len) return error.BufferTooSmall;
        out[info.maintainer_count] = parse_lower_hex_32(value) catch return error.InvalidMaintainersTag;
        info.maintainer_count += 1;
    }
}

fn append_topic(
    tag: nip01_event.EventTag,
    info: *RepositoryAnnouncementInfo,
    out: [][]const u8,
) Nip34Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(out.len <= limits.tags_max);

    if (tag.items.len != 2) return error.InvalidTopicTag;
    const topic = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidTopicTag;
    if (std.mem.eql(u8, topic, "personal-fork")) info.is_personal_fork = true;
    if (info.topic_count == out.len) return error.BufferTooSmall;
    out[info.topic_count] = topic;
    info.topic_count += 1;
}

fn apply_euc_tag(tag: nip01_event.EventTag, info: *RepositoryAnnouncementInfo) Nip34Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len != 3) return;
    if (!std.mem.eql(u8, tag.items[2], "euc")) return;
    if (info.earliest_unique_commit != null) return error.DuplicateEarliestUniqueCommitTag;
    info.earliest_unique_commit = parse_commit_id(tag.items[1]) catch {
        return error.InvalidEarliestUniqueCommitTag;
    };
}

fn apply_head_tag(tag: nip01_event.EventTag, info: *RepositoryStateInfo) Nip34Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.head_ref != null) return error.DuplicateHeadTag;
    if (tag.items.len != 2) return error.InvalidHeadTag;
    if (!std.mem.startsWith(u8, tag.items[1], "ref: ")) return error.InvalidHeadTag;
    info.head_ref = parse_ref_name(tag.items[1][5..]) catch return error.InvalidHeadTag;
}

fn is_supported_url_list_name(name: []const u8) bool {
    std.debug.assert(name.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    return std.mem.eql(u8, name, "web") or
        std.mem.eql(u8, name, "clone") or
        std.mem.eql(u8, name, "relays");
}

fn map_url_list_error(name: []const u8) Nip34Error {
    std.debug.assert(is_supported_url_list_name(name));
    std.debug.assert(name.len <= limits.tag_item_bytes_max);

    if (std.mem.eql(u8, name, "clone")) return error.InvalidCloneTag;
    if (std.mem.eql(u8, name, "relays")) return error.InvalidRelaysTag;
    return error.InvalidWebTag;
}

fn parse_ref_name(text: []const u8) error{InvalidRef}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    const parsed = parse_nonempty_utf8(text) catch return error.InvalidRef;
    if (!std.mem.startsWith(u8, parsed, "refs/")) return error.InvalidRef;
    return parsed;
}

fn parse_commit_id(text: []const u8) error{InvalidCommit}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.id_hex_length == 64);

    const parsed = parse_nonempty_utf8(text) catch return error.InvalidCommit;
    if (parsed.len < 7 or parsed.len > 64) return error.InvalidCommit;
    for (parsed) |byte| {
        if (!std.ascii.isHex(byte)) return error.InvalidCommit;
        if (std.ascii.isUpper(byte)) return error.InvalidCommit;
    }
    return parsed;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    _ = parse_nonempty_utf8(text) catch return error.InvalidUrl;
    const uri = std.Uri.parse(text) catch return error.InvalidUrl;
    if (uri.scheme.len == 0) return error.InvalidUrl;
    return text;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (text.len != limits.pubkey_hex_length) return error.InvalidHex;
    var out: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&out, text) catch return error.InvalidHex;
    return out;
}

test "NIP-34 extracts repository announcement metadata" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "noztr" } },
        .{ .items = &.{ "name", "noztr" } },
        .{ .items = &.{ "web", "https://example.com/noztr" } },
        .{ .items = &.{ "clone", "https://git.example.com/noztr.git" } },
        .{ .items = &.{ "relays", "wss://relay.example" } },
        .{ .items = &.{ "r", "0123456789abcdef0123456789abcdef01234567", "euc" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x34} ** 32,
        .pubkey = [_]u8{0x21} ** 32,
        .created_at = 1,
        .kind = repository_announcement_kind,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x31} ** 64,
    };
    var web: [1][]const u8 = undefined;
    var clone: [1][]const u8 = undefined;
    var relays: [1][]const u8 = undefined;
    var maintainers: [1][32]u8 = undefined;
    var topics: [1][]const u8 = undefined;

    const info = try repository_announcement_extract(
        &event,
        web[0..],
        clone[0..],
        relays[0..],
        maintainers[0..],
        topics[0..],
    );

    try std.testing.expectEqualStrings("noztr", info.identifier);
    try std.testing.expectEqual(@as(u16, 1), info.web_count);
    try std.testing.expect(info.earliest_unique_commit != null);
}

test "NIP-34 extracts repository state refs" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "noztr" } },
        .{ .items = &.{ "refs/heads/main", "0123456789abcdef0123456789abcdef01234567" } },
        .{ .items = &.{ "HEAD", "ref: refs/heads/main" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x35} ** 32,
        .pubkey = [_]u8{0x22} ** 32,
        .created_at = 2,
        .kind = repository_state_kind,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x32} ** 64,
    };
    var refs: [1]RepositoryStateRef = undefined;

    const info = try repository_state_extract(&event, refs[0..]);

    try std.testing.expectEqualStrings("noztr", info.identifier);
    try std.testing.expectEqualStrings("refs/heads/main", info.head_ref.?);
    try std.testing.expectEqual(@as(u16, 1), info.ref_count);
}

test "NIP-34 builds maintainers tag" {
    var built: BuiltTag = .{};
    const pubkeys = [_][]const u8{
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };

    const tag = try repository_build_maintainers_tag(&built, pubkeys[0..]);

    try std.testing.expectEqualStrings("maintainers", tag.items[0]);
    try std.testing.expectEqualStrings(pubkeys[0], tag.items[1]);
}

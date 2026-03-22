const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");

pub const report_event_kind: u32 = 1984;

pub const Nip56Error = error{
    InvalidReportKind,
    MissingPubkeyTarget,
    MissingReportType,
    InvalidPubkeyReportTag,
    InvalidEventReportTag,
    InvalidBlobReportTag,
    InvalidServerTag,
    BufferTooSmall,
};

pub const ReportType = enum {
    nudity,
    malware,
    profanity,
    illegal,
    spam,
    impersonation,
    other,

    pub fn text(self: ReportType) []const u8 {
        std.debug.assert(@intFromEnum(self) <= @intFromEnum(ReportType.other));
        std.debug.assert(@typeInfo(ReportType) == .@"enum");

        return switch (self) {
            .nudity => "nudity",
            .malware => "malware",
            .profanity => "profanity",
            .illegal => "illegal",
            .spam => "spam",
            .impersonation => "impersonation",
            .other => "other",
        };
    }
};

pub const PubkeyReportTarget = struct {
    pubkey: [32]u8,
    report_type: ?ReportType = null,
};

pub const EventReportTarget = struct {
    event_id: [32]u8,
    report_type: ReportType,
};

pub const BlobReportTarget = struct {
    hash: [32]u8,
    report_type: ReportType,
};

pub const ReportInfo = struct {
    content: []const u8,
    pubkey_target: PubkeyReportTarget,
    event_target: ?EventReportTarget = null,
    blob_target: ?BlobReportTarget = null,
    server_urls: [][]const u8,
};

pub const BuiltTag = struct {
    items: [3][]const u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts the bounded NIP-56 report surface from a kind-1984 event.
pub fn report_extract(
    event: *const nip01_event.Event,
    out_server_urls: [][]const u8,
) Nip56Error!ReportInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_server_urls.len <= limits.tags_max);

    if (event.kind != report_event_kind) return error.InvalidReportKind;

    var pubkey_target: ?PubkeyReportTarget = null;
    var event_target: ?EventReportTarget = null;
    var blob_target: ?BlobReportTarget = null;
    var server_count: u16 = 0;
    for (event.tags) |tag| {
        try apply_report_tag(
            tag,
            &pubkey_target,
            &event_target,
            &blob_target,
            out_server_urls,
            &server_count,
        );
    }
    if (pubkey_target == null) return error.MissingPubkeyTarget;
    if (pubkey_target.?.report_type == null and event_target == null and blob_target == null) {
        return error.MissingReportType;
    }
    return .{
        .content = event.content,
        .pubkey_target = pubkey_target.?,
        .event_target = event_target,
        .blob_target = blob_target,
        .server_urls = out_server_urls[0..server_count],
    };
}

/// Builds a NIP-56 `p` tag with optional report type.
pub fn report_build_pubkey_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
    report_type: ?ReportType,
) Nip56Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(pubkey_hex.len <= limits.tag_item_bytes_max);

    _ = parse_nostr_hex_32(pubkey_hex) catch return error.InvalidPubkeyReportTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    if (report_type) |report| {
        output.items[2] = report.text();
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a NIP-56 `e` report tag.
pub fn report_build_event_tag(
    output: *BuiltTag,
    event_id_hex: []const u8,
    report_type: ReportType,
) Nip56Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(event_id_hex.len <= limits.tag_item_bytes_max);

    _ = parse_nostr_hex_32(event_id_hex) catch return error.InvalidEventReportTag;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.items[2] = report_type.text();
    output.item_count = 3;
    return output.as_event_tag();
}

/// Builds a NIP-56 `x` blob report tag.
pub fn report_build_blob_tag(
    output: *BuiltTag,
    hash_hex: []const u8,
    report_type: ReportType,
) Nip56Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(hash_hex.len <= limits.tag_item_bytes_max);

    _ = parse_compat_hex_32(hash_hex) catch return error.InvalidBlobReportTag;
    output.items[0] = "x";
    output.items[1] = hash_hex;
    output.items[2] = report_type.text();
    output.item_count = 3;
    return output.as_event_tag();
}

/// Builds a NIP-56 `server` tag.
pub fn report_build_server_tag(
    output: *BuiltTag,
    server_url: []const u8,
) Nip56Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(server_url.len <= limits.tag_item_bytes_max);

    output.items[0] = "server";
    output.items[1] = parse_url(server_url) catch return error.InvalidServerTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Compatibility alias for older NIP-56 `p` report tag builder naming.
pub const build_pubkey_report_tag = report_build_pubkey_tag;

/// Compatibility alias for older NIP-56 `e` report tag builder naming.
pub const build_event_report_tag = report_build_event_tag;

/// Compatibility alias for older NIP-56 `x` report tag builder naming.
pub const build_blob_report_tag = report_build_blob_tag;

/// Compatibility alias for older NIP-56 `server` tag builder naming.
pub const build_server_tag = report_build_server_tag;

fn apply_report_tag(
    tag: nip01_event.EventTag,
    pubkey_target: *?PubkeyReportTarget,
    event_target: *?EventReportTarget,
    blob_target: *?BlobReportTarget,
    out_server_urls: [][]const u8,
    server_count: *u16,
) Nip56Error!void {
    std.debug.assert(@intFromPtr(pubkey_target) != 0);
    std.debug.assert(@intFromPtr(server_count) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "p")) return parse_pubkey_tag(tag, pubkey_target);
    if (std.mem.eql(u8, tag.items[0], "e")) return parse_event_tag(tag, event_target);
    if (std.mem.eql(u8, tag.items[0], "x")) return parse_blob_tag(tag, blob_target);
    if (std.mem.eql(u8, tag.items[0], "server")) {
        return parse_server_tag(tag, out_server_urls, server_count);
    }
}

fn parse_pubkey_tag(
    tag: nip01_event.EventTag,
    target: *?PubkeyReportTarget,
) Nip56Error!void {
    std.debug.assert(@intFromPtr(target) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 2) return error.InvalidPubkeyReportTag;
    if (target.* != null) return;
    const report_type = try parse_optional_pubkey_report_type(tag);
    target.* = .{
        .pubkey = parse_nostr_hex_32(tag.items[1]) catch return error.InvalidPubkeyReportTag,
        .report_type = report_type,
    };
}

fn parse_event_tag(
    tag: nip01_event.EventTag,
    target: *?EventReportTarget,
) Nip56Error!void {
    std.debug.assert(@intFromPtr(target) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 2) return error.InvalidEventReportTag;
    if (tag.items.len < 3) return;
    if (target.* != null) return;
    const report_type = parse_report_type(tag.items[2]) catch {
        if (is_generic_event_tag(tag.items[2])) return;
        return error.InvalidEventReportTag;
    };
    target.* = .{
        .event_id = parse_nostr_hex_32(tag.items[1]) catch return error.InvalidEventReportTag,
        .report_type = report_type,
    };
}

fn parse_blob_tag(
    tag: nip01_event.EventTag,
    target: *?BlobReportTarget,
) Nip56Error!void {
    std.debug.assert(@intFromPtr(target) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 3) return error.InvalidBlobReportTag;
    if (target.* != null) return;
    target.* = .{
        .hash = parse_compat_hex_32(tag.items[1]) catch return error.InvalidBlobReportTag,
        .report_type = parse_report_type(tag.items[2]) catch return error.InvalidBlobReportTag,
    };
}

fn parse_server_tag(
    tag: nip01_event.EventTag,
    out_server_urls: [][]const u8,
    count: *u16,
) Nip56Error!void {
    std.debug.assert(@intFromPtr(count) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) return error.InvalidServerTag;
    if (count.* == out_server_urls.len) return error.BufferTooSmall;
    out_server_urls[count.*] = parse_url(tag.items[1]) catch return error.InvalidServerTag;
    count.* += 1;
}

fn parse_optional_pubkey_report_type(tag: nip01_event.EventTag) Nip56Error!?ReportType {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len >= 2);

    if (tag.items.len < 3) return null;
    if (tag.items[2].len == 0) return null;
    return parse_report_type(tag.items[2]) catch {
        if (is_url_shaped(tag.items[2])) return null;
        return error.InvalidPubkeyReportTag;
    };
}

fn parse_report_type(text: []const u8) error{InvalidReportType}!ReportType {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@typeInfo(ReportType) == .@"enum");

    if (std.mem.eql(u8, text, "nudity")) return .nudity;
    if (std.mem.eql(u8, text, "malware")) return .malware;
    if (std.mem.eql(u8, text, "profanity")) return .profanity;
    if (std.mem.eql(u8, text, "illegal")) return .illegal;
    if (std.mem.eql(u8, text, "spam")) return .spam;
    if (std.mem.eql(u8, text, "impersonation")) return .impersonation;
    if (std.mem.eql(u8, text, "other")) return .other;
    return error.InvalidReportType;
}

fn is_generic_event_tag(item: []const u8) bool {
    std.debug.assert(item.len <= limits.tag_item_bytes_max);
    std.debug.assert(item.len <= limits.content_bytes_max);

    if (item.len == 0) return true;
    if (std.mem.eql(u8, item, "root")) return true;
    if (std.mem.eql(u8, item, "reply")) return true;
    if (std.mem.eql(u8, item, "mention")) return true;
    return is_url_shaped(item);
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (!is_url_shaped(text)) return error.InvalidUrl;
    return text;
}

fn is_url_shaped(text: []const u8) bool {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0) return false;
    const parsed = std.Uri.parse(text) catch return false;
    return parsed.scheme.len != 0 and parsed.host != null;
}

fn parse_nostr_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    return lower_hex_32.parse(text);
}

fn parse_compat_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length == 64);

    var output: [32]u8 = undefined;
    if (text.len != 64) return error.InvalidHex;
    _ = std.fmt.hexToBytes(output[0..], text) catch return error.InvalidHex;
    for (text) |byte| {
        if (!std.ascii.isHex(byte)) return error.InvalidHex;
    }
    return output;
}

fn test_event(tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(report_event_kind <= limits.kind_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{1} ** 32,
        .sig = [_]u8{2} ** 64,
        .kind = report_event_kind,
        .created_at = 1,
        .content = "details",
        .tags = tags,
    };
}

test "report extract parses profile and note report shapes" {
    const profile_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "impersonation" } },
    };
    var servers: [1][]const u8 = undefined;
    const profile = try report_extract(&test_event(profile_tags[0..]), servers[0..]);
    try std.testing.expect(profile.pubkey_target.report_type.? == .impersonation);
    try std.testing.expect(profile.event_target == null);

    const note_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" } },
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "illegal" } },
        .{ .items = &.{ "server", "https://blob.example/file" } },
    };
    const note = try report_extract(&test_event(note_tags[0..]), servers[0..]);
    try std.testing.expect(note.pubkey_target.report_type == null);
    try std.testing.expect(note.event_target.?.report_type == .illegal);
    try std.testing.expectEqualStrings("https://blob.example/file", note.server_urls[0]);
}

test "report extract accepts blob reports and ignores generic e tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "", "ignored" } },
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "", "root" } },
        .{ .items = &.{ "x", "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "malware" } },
    };
    var servers: [1][]const u8 = undefined;
    const parsed = try report_extract(&test_event(tags[0..]), servers[0..]);

    try std.testing.expect(parsed.event_target == null);
    try std.testing.expect(parsed.blob_target.?.report_type == .malware);
    try std.testing.expect(parsed.pubkey_target.report_type == null);
}

test "report extract rejects malformed required report state" {
    const missing_pubkey = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "illegal" } },
    };
    const missing_type = [_]nip01_event.EventTag{
        .{ .items = &.{ "p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" } },
    };
    const invalid_pubkey_type = [_]nip01_event.EventTag{
        .{ .items = &.{ "p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "bad" } },
    };
    const invalid_blob = [_]nip01_event.EventTag{
        .{ .items = &.{ "p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "other" } },
        .{ .items = &.{ "x", "bad", "malware" } },
    };
    var servers: [1][]const u8 = undefined;

    try std.testing.expectError(error.MissingPubkeyTarget, report_extract(&test_event(missing_pubkey[0..]), servers[0..]));
    try std.testing.expectError(error.MissingReportType, report_extract(&test_event(missing_type[0..]), servers[0..]));
    try std.testing.expectError(error.InvalidPubkeyReportTag, report_extract(&test_event(invalid_pubkey_type[0..]), servers[0..]));
    try std.testing.expectError(error.InvalidBlobReportTag, report_extract(&test_event(invalid_blob[0..]), servers[0..]));
}

test "report hex policy keeps nostr ids strict and blob hashes compatible" {
    var built: BuiltTag = .{};

    try std.testing.expectError(
        error.InvalidPubkeyReportTag,
        report_build_pubkey_tag(
            &built,
            "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
            .spam,
        ),
    );
    try std.testing.expectEqualStrings(
        "x",
        (try report_build_blob_tag(
            &built,
            "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",
            .malware,
        )).items[0],
    );
}

test "report builders emit canonical tags" {
    var pubkey_tag: BuiltTag = .{};
    var event_tag: BuiltTag = .{};
    var blob_tag: BuiltTag = .{};
    var server_tag: BuiltTag = .{};

    try std.testing.expectEqualStrings(
        "p",
        (try report_build_pubkey_tag(
            &pubkey_tag,
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            .spam,
        )).items[0],
    );
    try std.testing.expectEqualStrings(
        "e",
        (try report_build_event_tag(
            &event_tag,
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            .illegal,
        )).items[0],
    );
    try std.testing.expectEqualStrings(
        "x",
        (try report_build_blob_tag(
            &blob_tag,
            "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
            .malware,
        )).items[0],
    );
    try std.testing.expectEqualStrings(
        "server",
        (try report_build_server_tag(&server_tag, "https://blob.example/file")).items[0],
    );
}

const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const text_note_kind: u32 = 1;
pub const subject_tag_name: []const u8 = "subject";

pub const Nip14Error = error{
    InvalidTextNoteKind,
    DuplicateSubjectTag,
    InvalidSubjectTag,
};

pub const BuiltTag = struct {
    items: [2][]const u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts the strict `subject` tag from a kind-1 text note, or `null` when absent.
pub fn subject_extract(event: *const nip01_event.Event) Nip14Error!?[]const u8 {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != text_note_kind) return error.InvalidTextNoteKind;

    var subject: ?[]const u8 = null;
    for (event.tags) |tag| {
        if (!is_subject_tag(tag)) continue;
        if (subject != null) return error.DuplicateSubjectTag;
        subject = parse_subject_tag(tag) catch return error.InvalidSubjectTag;
    }
    return subject;
}

/// Builds a canonical `subject` tag for a kind-1 text note.
pub fn subject_build_tag(output: *BuiltTag, subject: []const u8) Nip14Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(subject.len <= limits.tag_item_bytes_max);

    output.items[0] = subject_tag_name;
    output.items[1] = parse_nonempty_utf8(subject) catch return error.InvalidSubjectTag;
    output.item_count = 2;
    return output.as_event_tag();
}

fn is_subject_tag(tag: nip01_event.EventTag) bool {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max > 0);

    return tag.items.len != 0 and std.mem.eql(u8, tag.items[0], subject_tag_name);
}

fn parse_subject_tag(tag: nip01_event.EventTag) error{InvalidTag}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len != 2) return error.InvalidTag;
    return parse_nonempty_utf8(tag.items[1]) catch return error.InvalidTag;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

test "NIP-14 extracts a text-note subject tag" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "subject", "Release planning" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x14} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = text_note_kind,
        .tags = tags[0..],
        .content = "hello",
        .sig = [_]u8{0x22} ** 64,
    };

    const subject = try subject_extract(&event);

    try std.testing.expect(subject != null);
    try std.testing.expectEqualStrings("Release planning", subject.?);
}

test "NIP-14 rejects duplicate subject tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "subject", "one" } },
        .{ .items = &.{ "subject", "two" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x15} ** 32,
        .pubkey = [_]u8{0x12} ** 32,
        .created_at = 2,
        .kind = text_note_kind,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x23} ** 64,
    };

    try std.testing.expectError(error.DuplicateSubjectTag, subject_extract(&event));
}

test "NIP-14 builds canonical subject tags" {
    var built: BuiltTag = .{};

    const tag = try subject_build_tag(&built, "Re: Release planning");

    try std.testing.expectEqualStrings("subject", tag.items[0]);
    try std.testing.expectEqualStrings("Re: Release planning", tag.items[1]);
}

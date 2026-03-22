const std = @import("std");
const nip01_event = @import("nip01_event.zig");

pub const ProtectedError = error{ ProtectedAuthRequired, ProtectedPubkeyMismatch };

pub fn event_has_protected_tag(event: *const nip01_event.Event) bool {
    std.debug.assert(event.tags.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(event) != 0);

    var index: usize = 0;
    while (index < event.tags.len) : (index += 1) {
        const tag = event.tags[index];
        if (tag.items.len != 1) {
            continue;
        }
        if (std.mem.eql(u8, tag.items[0], "-")) {
            return true;
        }
    }
    return false;
}

pub fn protected_event_validate(
    event: *const nip01_event.Event,
    authenticated_pubkey: ?*const [32]u8,
) ProtectedError!void {
    std.debug.assert(event.pubkey[0] <= 255);
    std.debug.assert(@intFromPtr(event) != 0);

    if (!event_has_protected_tag(event)) {
        return;
    }
    if (authenticated_pubkey == null) {
        return error.ProtectedAuthRequired;
    }
    if (!std.mem.eql(u8, &event.pubkey, authenticated_pubkey.?)) {
        return error.ProtectedPubkeyMismatch;
    }
}

fn test_event(pubkey: [32]u8, tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(tags.len <= std.math.maxInt(u16));
    std.debug.assert(pubkey[0] <= 255);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{2} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "x",
        .tags = tags,
    };
}

test "protected tag detection accepts exact shape only" {
    const items_protected = [_][]const u8{"-"};
    const items_empty = [_][]const u8{};
    const items_dash_extra = [_][]const u8{ "-", "x" };
    const items_text = [_][]const u8{"p"};
    const items_misplaced = [_][]const u8{ "x", "-" };

    const tags_empty = [_]nip01_event.EventTag{};
    const tags_exact = [_]nip01_event.EventTag{.{ .items = items_protected[0..] }};
    const tags_empty_item = [_]nip01_event.EventTag{.{ .items = items_empty[0..] }};
    const tags_dash_extra = [_]nip01_event.EventTag{.{ .items = items_dash_extra[0..] }};
    const tags_text = [_]nip01_event.EventTag{.{ .items = items_text[0..] }};
    const tags_misplaced = [_]nip01_event.EventTag{.{ .items = items_misplaced[0..] }};
    const tags_mixed = [_]nip01_event.EventTag{
        .{ .items = items_dash_extra[0..] },
        .{ .items = items_protected[0..] },
    };

    const pubkey = [_]u8{1} ** 32;
    try std.testing.expect(!event_has_protected_tag(&test_event(pubkey, tags_empty[0..])));
    try std.testing.expect(event_has_protected_tag(&test_event(pubkey, tags_exact[0..])));
    try std.testing.expect(!event_has_protected_tag(&test_event(pubkey, tags_empty_item[0..])));
    try std.testing.expect(!event_has_protected_tag(&test_event(pubkey, tags_dash_extra[0..])));
    try std.testing.expect(!event_has_protected_tag(&test_event(pubkey, tags_text[0..])));
    try std.testing.expect(!event_has_protected_tag(&test_event(pubkey, tags_misplaced[0..])));
    try std.testing.expect(event_has_protected_tag(&test_event(pubkey, tags_mixed[0..])));
}

test "protected event validation has 5 valid and 5 invalid vectors" {
    const items_protected = [_][]const u8{"-"};
    const items_dash_extra = [_][]const u8{ "-", "x" };
    const items_empty = [_][]const u8{};
    const items_text = [_][]const u8{"p"};
    const items_subject = [_][]const u8{ "subject", "hello" };

    const tags_none = [_]nip01_event.EventTag{};
    const tags_protected = [_]nip01_event.EventTag{.{ .items = items_protected[0..] }};
    const tags_dash_extra = [_]nip01_event.EventTag{.{ .items = items_dash_extra[0..] }};
    const tags_empty_item = [_]nip01_event.EventTag{.{ .items = items_empty[0..] }};
    const tags_text = [_]nip01_event.EventTag{.{ .items = items_text[0..] }};
    const tags_subject = [_]nip01_event.EventTag{.{ .items = items_subject[0..] }};
    const tags_mixed_exact = [_]nip01_event.EventTag{
        .{ .items = items_dash_extra[0..] },
        .{ .items = items_protected[0..] },
    };
    const tags_double_exact = [_]nip01_event.EventTag{
        .{ .items = items_protected[0..] },
        .{ .items = items_protected[0..] },
    };
    const tags_exact_plus_subject = [_]nip01_event.EventTag{
        .{ .items = items_protected[0..] },
        .{ .items = items_subject[0..] },
    };

    const event_pubkey = [_]u8{1} ** 32;
    const auth_matching = [_]u8{1} ** 32;
    const auth_mismatch_a = [_]u8{2} ** 32;
    const auth_mismatch_b = [_]u8{3} ** 32;

    try protected_event_validate(&test_event(event_pubkey, tags_none[0..]), null);
    try protected_event_validate(&test_event(event_pubkey, tags_dash_extra[0..]), null);
    try protected_event_validate(&test_event(event_pubkey, tags_empty_item[0..]), null);
    try protected_event_validate(&test_event(event_pubkey, tags_text[0..]), null);
    try protected_event_validate(&test_event(event_pubkey, tags_protected[0..]), &auth_matching);

    try std.testing.expectError(
        error.ProtectedAuthRequired,
        protected_event_validate(&test_event(event_pubkey, tags_protected[0..]), null),
    );
    try std.testing.expectError(
        error.ProtectedPubkeyMismatch,
        protected_event_validate(&test_event(event_pubkey, tags_protected[0..]), &auth_mismatch_a),
    );
    try std.testing.expectError(
        error.ProtectedAuthRequired,
        protected_event_validate(&test_event(event_pubkey, tags_exact_plus_subject[0..]), null),
    );
    try std.testing.expectError(
        error.ProtectedAuthRequired,
        protected_event_validate(&test_event(event_pubkey, tags_mixed_exact[0..]), null),
    );
    try std.testing.expectError(
        error.ProtectedPubkeyMismatch,
        protected_event_validate(
            &test_event(event_pubkey, tags_double_exact[0..]),
            &auth_mismatch_b,
        ),
    );

    try protected_event_validate(&test_event(event_pubkey, tags_mixed_exact[0..]), &auth_matching);
    try protected_event_validate(&test_event(event_pubkey, tags_subject[0..]), null);
}

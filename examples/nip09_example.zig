const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-09 example: checked delete extraction and apply decision" {
    const event_id_hex = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const delete_tag_items = [_][]const u8{ "e", event_id_hex };
    const delete_tags = [_]noztr.nip01_event.EventTag{.{ .items = delete_tag_items[0..] }};
    const pubkey = [_]u8{0x44} ** 32;
    const delete_event = common.simple_event(5, pubkey, "", delete_tags[0..]);
    var targets: [1]noztr.nip09_delete.DeleteTarget = undefined;
    var target_event = common.simple_event(1, pubkey, "target", &.{});
    target_event.id = [_]u8{0xaa} ** 32;

    const count = try noztr.delete_extract_targets_checked(&delete_event, targets[0..]);
    const applies = try noztr.nip09_delete.deletion_can_apply(&delete_event, &target_event);

    try std.testing.expectEqual(@as(u16, 1), count);
    try std.testing.expect(applies);
}

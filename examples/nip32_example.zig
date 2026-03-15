const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-32 example: extract labels and targets from a kind-1985 label event" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "L", "ugc" } },
        .{ .items = &.{ "l", "spam", "ugc" } },
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
    };
    const event = common.simple_event(1985, [_]u8{0x32} ** 32, "", tags[0..]);
    var namespaces: [1]noztr.nip32_labeling.LabelNamespace = undefined;
    var labels: [1]noztr.nip32_labeling.Label = undefined;
    var targets: [1]noztr.nip32_labeling.LabelTarget = undefined;

    const info = try noztr.nip32_labeling.label_event_extract(
        &event,
        namespaces[0..],
        labels[0..],
        targets[0..],
    );

    try std.testing.expectEqual(@as(usize, 1), info.labels.len);
    try std.testing.expect(info.targets[0] == .event);
}

const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-56 example: extract a bounded report surface" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "p", "1111111111111111111111111111111111111111111111111111111111111111", "spam" } },
        .{ .items = &.{ "server", "https://relay.example/report" } },
    };
    const event = common.simple_event(1984, [_]u8{0x56} ** 32, "spam report", tags[0..]);
    var servers: [1][]const u8 = undefined;

    const report = try noztr.nip56_reporting.report_extract(&event, servers[0..]);

    try std.testing.expect(report.pubkey_target.report_type != null);
    try std.testing.expectEqual(@as(usize, 1), report.server_urls.len);
}

const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-61 example: informational and nutzap tag helpers" {
    const info_tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relay", "wss://relay.one" } },
        .{ .items = &.{ "mint", "https://mint.example", "sat" } },
        .{ .items = &.{ "pubkey", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
    };
    const info_event = common.simple_event(
        noztr.nip61_nutzaps.informational_kind,
        [_]u8{0x61} ** 32,
        "",
        info_tags[0..],
    );
    var relays: [1][]const u8 = undefined;
    var mints: [1]noztr.nip61_nutzaps.MintPreference = undefined;
    const info = try noztr.nip61_nutzaps.informational_extract(&info_event, relays[0..], mints[0..]);
    try std.testing.expectEqual(@as(u16, 1), info.mint_count);

    var built: noztr.nip61_nutzaps.BuiltTag = .{};
    const proof = try noztr.nip61_nutzaps.nutzap_build_proof_tag(&built, "{\"amount\":1}");
    try std.testing.expectEqualStrings("proof", proof.items[0]);
}

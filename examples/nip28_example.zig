const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-28 example: channel metadata and linkage helpers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const create = common.simple_event(
        noztr.nip28_public_chat.channel_create_kind,
        [_]u8{0x28} ** 32,
        "{\"name\":\"Demo\",\"relays\":[\"wss://relay.one\"]}",
        &.{},
    );
    var relays: [1][]const u8 = undefined;
    const metadata = try noztr.nip28_public_chat.channel_create_extract(
        &create,
        relays[0..],
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("Demo", metadata.name.?);

    var built_tag: noztr.nip28_public_chat.BuiltTag = .{};
    const root_tag = try noztr.nip28_public_chat.channel_build_event_tag(
        &built_tag,
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "wss://relay.one",
        .root,
    );
    try std.testing.expectEqualStrings("root", root_tag.items[3]);

    var built_json: noztr.nip28_public_chat.BuiltJson = .{};
    const reason = try noztr.nip28_public_chat.channel_build_reason_json(&built_json, "spam");
    try std.testing.expectEqualStrings("{\"reason\":\"spam\"}", reason);
}

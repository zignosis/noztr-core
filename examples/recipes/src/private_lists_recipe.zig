const std = @import("std");
const noztr = @import("noztr");

test "recipe: private list helpers roundtrip without decrypt flow noise" {
    const pubkey_tag = [_][]const u8{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const word_tag = [_][]const u8{ "word", "spam phrase" };
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = pubkey_tag[0..] },
        .{ .items = word_tag[0..] },
    };
    var json_output: [256]u8 = undefined;
    const json = try noztr.nip51_lists.list_private_serialize_json(json_output[0..], tags[0..]);
    var items: [2]noztr.nip51_lists.ListItem = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    // This shows the bounded plaintext JSON layer that nzdk can wrap with NIP-44 flows.
    const parsed = try noztr.nip51_lists.list_private_extract_json(
        10000,
        json,
        items[0..],
        arena.allocator(),
    );

    try std.testing.expectEqual(.mute_list, parsed.kind);
    try std.testing.expect(items[0] == .pubkey);
    try std.testing.expect(items[1] == .word);
}

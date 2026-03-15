const std = @import("std");
const noztr = @import("noztr");

test "NIP-77 example: parse NEG-OPEN and apply it to bounded session state" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const open = try noztr.nip77_negentropy.negentropy_open_parse(
        "[\"NEG-OPEN\",\"sub\",{\"kinds\":[1]},\"6100\"]",
        arena.allocator(),
    );
    var state = noztr.nip77_negentropy.NegentropyState{};
    const message = noztr.nip77_negentropy.NegentropyMessage{ .open = open };
    try noztr.nip77_negentropy.negentropy_state_apply(&state, &message);

    try std.testing.expectEqual(.open, state.stage);
    try std.testing.expectEqualStrings("sub", state.subscription_id[0..state.subscription_id_len]);
}

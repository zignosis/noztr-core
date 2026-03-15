const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-64 example: validate and extract chess PGN note" {
    var alt_tag: noztr.nip64_chess_pgn.BuiltTag = .{};
    const built_alt = try noztr.nip64_chess_pgn.chess_pgn_build_alt_tag(
        &alt_tag,
        "Fischer vs. Spassky",
    );
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "alt", "Fischer vs. Spassky" } },
    };
    const content =
        "[White \"Fischer, Robert J.\"]\n" ++
        "[Black \"Spassky, Boris V.\"]\n\n" ++
        "1. e4 e5 2. Nf3 Nc6 3. Bb5 *";
    const event = common.simple_event(
        noztr.nip64_chess_pgn.chess_pgn_kind,
        [_]u8{0x64} ** 32,
        content,
        tags[0..],
    );

    const parsed = try noztr.nip64_chess_pgn.chess_pgn_extract(&event);

    try std.testing.expectEqualStrings("alt", built_alt.items[0]);
    try std.testing.expectEqualStrings("Fischer vs. Spassky", parsed.alt.?);
    try std.testing.expectEqual(@as(u16, 1), parsed.game_count);
    try std.testing.expectEqualStrings(content, parsed.content);
}

const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-64 adversarial example: reject malformed PGN structure" {
    const event = common.simple_event(
        noztr.nip64_chess_pgn.chess_pgn_kind,
        [_]u8{0x64} ** 32,
        "[White \"Fischer\"]\n\n1. e4 {open *",
        &.{},
    );
    var alt_tag: noztr.nip64_chess_pgn.BuiltTag = .{};

    try std.testing.expectError(error.InvalidPgn, noztr.nip64_chess_pgn.chess_pgn_extract(&event));
    try std.testing.expectError(
        error.InvalidAltTag,
        noztr.nip64_chess_pgn.chess_pgn_build_alt_tag(&alt_tag, ""),
    );
}

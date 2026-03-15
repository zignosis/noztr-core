const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-B7 adversarial example: malformed server urls and blob urls stay typed" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "server", "https://cdn.example.com?x=1" } },
    };
    const event = common.simple_event(
        noztr.nipb7_blossom_servers.blossom_server_list_kind,
        [_]u8{0xb7} ** 32,
        "",
        tags[0..],
    );
    var built_tag: noztr.nipb7_blossom_servers.BuiltTag = .{};
    var servers: [1][]const u8 = undefined;
    var url_output: [128]u8 = undefined;

    try std.testing.expectError(
        error.InvalidServerTag,
        noztr.nipb7_blossom_servers.blossom_servers_extract(&event, servers[0..]),
    );
    try std.testing.expectError(
        error.InvalidServerUrl,
        noztr.nipb7_blossom_servers.blossom_build_server_tag(
            &built_tag,
            "https://cdn.example.com?x=1",
        ),
    );
    try std.testing.expectError(
        error.InvalidBlobUrl,
        noztr.nipb7_blossom_servers.blossom_build_fallback_url_for_blob(
            url_output[0..],
            "https://blossom.example.com",
            "https://cdn.example.com/"
            ++ "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553.pdf"
            ++ "?download=1",
        ),
    );
}

const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-B7 example: extract servers and derive a fallback blob URL" {
    var built_tag: noztr.nipb7_blossom_servers.BuiltTag = .{};
    const tag = try noztr.nipb7_blossom_servers.blossom_build_server_tag(
        &built_tag,
        "https://blossom.self.hosted/",
    );
    const tags = [_]noztr.nip01_event.EventTag{
        tag,
        .{ .items = &.{ "server", "http://127.0.0.1:24242/cache" } },
    };
    const event = common.simple_event(
        noztr.nipb7_blossom_servers.blossom_server_list_kind,
        [_]u8{0xb7} ** 32,
        "",
        tags[0..],
    );
    var servers: [2][]const u8 = undefined;
    var url_output: [160]u8 = undefined;

    const parsed = try noztr.nipb7_blossom_servers.blossom_servers_extract(
        &event,
        servers[0..],
    );
    const fallback = try noztr.nipb7_blossom_servers.blossom_build_fallback_url_for_blob(
        url_output[0..],
        parsed.server_urls[0],
        "https://cdn.broken-domain.com/"
        ++ "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553.pdf",
    );

    try std.testing.expectEqual(@as(usize, 2), parsed.server_urls.len);
    try std.testing.expectEqualStrings("https://blossom.self.hosted", parsed.server_urls[0]);
    try std.testing.expectEqualStrings(
        "https://blossom.self.hosted/"
        ++ "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553.pdf",
        fallback,
    );
}

const std = @import("std");
const noztr = @import("noztr");

test "recipe: remote signing helpers compose without extra sdk machinery" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var request_output: noztr.nip46_remote_signing.BuiltRequest = .{};
    const request = try noztr.nip46_remote_signing.request_build_connect(
        &request_output,
        "sdk-connect",
        &.{
            .remote_signer_pubkey = [_]u8{0x01} ** 32,
            .secret = "secret",
            .requested_permissions = &.{
                .{ .method = .ping },
                .{ .method = .sign_event, .scope = .{ .event_kind = 1 } },
            },
        },
        arena.allocator(),
    );
    var uri_output: [noztr.limits.nip46_uri_bytes_max]u8 = undefined;
    const connection_uri = try noztr.nip46_remote_signing.uri_serialize(
        uri_output[0..],
        .{ .client = .{
            .client_pubkey = [_]u8{0x02} ** 32,
            .relays = &.{"wss://relay.one"},
            .secret = "secret",
            .permissions = &.{.{ .method = .ping }},
            .name = "SDK Client",
        } },
    );
    var rendered_output: [noztr.limits.nip46_uri_bytes_max]u8 = undefined;
    const rendered = try noztr.nip46_remote_signing.discovery_render_nostrconnect_url(
        rendered_output[0..],
        "https://bunker.example/connect/<nostrconnect>",
        connection_uri,
        arena.allocator(),
    );

    try std.testing.expectEqual(.connect, request.method);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "nostrconnect://") != null);
}

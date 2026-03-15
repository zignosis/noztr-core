const std = @import("std");
const noztr = @import("noztr");

test "NIP-46 example: build and validate a connect request" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output: noztr.nip46_remote_signing.BuiltRequest = .{};
    const request = try noztr.nip46_remote_signing.request_build_connect(
        &output,
        "sdk-connect",
        &.{
            .remote_signer_pubkey = [_]u8{0x46} ** 32,
            .secret = "secret",
            .requested_permissions = &.{.{ .method = .sign_event, .scope = .{ .event_kind = 1 } }},
        },
        arena.allocator(),
    );

    try noztr.nip46_remote_signing.request_validate(&request, arena.allocator());
    try std.testing.expectEqual(.connect, request.method);
}

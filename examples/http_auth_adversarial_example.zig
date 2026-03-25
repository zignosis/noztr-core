const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-98 adversarial example: malformed headers and payload tags stay typed" {
    var payload_tag: noztr.nip98_http_auth.TagBuilder = .{};
    var header_output: [128]u8 = undefined;
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "u", "https://api.example.com/upload" } },
        .{ .items = &.{ "method", "POST" } },
        .{ .items = &.{ "payload", "ABCDEFabcdef0123456789abcdef0123456789abcdef0123456789abcdef01" } },
    };
    const event = common.simple_event(
        noztr.nip98_http_auth.http_auth_kind,
        [_]u8{0x55} ** 32,
        "",
        tags[0..],
    );

    try std.testing.expectError(error.InvalidPayloadTag, noztr.nip98_http_auth.extract(&event));
    try std.testing.expectError(
        error.InvalidPayloadTag,
        noztr.nip98_http_auth.build_payload_tag(
            &payload_tag,
            "ABCDEFabcdef0123456789abcdef0123456789abcdef0123456789abcdef01",
        ),
    );
    try std.testing.expectError(
        error.InvalidBase64,
        noztr.nip98_http_auth.format_authorization_header(
            header_output[0..],
            "%%%not-base64%%%",
        ),
    );
    try std.testing.expectError(
        error.InvalidAuthorizationHeader,
        noztr.nip98_http_auth.parse_authorization_header(
            "Nostr  eyJraW5kIjoyNzIzNSwiY29udGVudCI6IiJ9",
        ),
    );
}

const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-98 example: build and verify an authorization header" {
    const secret_key = [_]u8{0x11} ** 32;
    const pubkey = try common.derive_public_key(&secret_key);
    var url_tag: noztr.nip98_http_auth.BuiltTag = .{};
    var method_tag: noztr.nip98_http_auth.BuiltTag = .{};
    var payload_tag: noztr.nip98_http_auth.BuiltTag = .{};
    var payload_hex_output: [noztr.nip98_http_auth.payload_hash_hex_length]u8 = undefined;
    const payload_hex = try noztr.nip98_http_auth.http_auth_payload_sha256_hex(
        payload_hex_output[0..],
        "{\"name\":\"zig\"}",
    );
    const tags = [_]noztr.nip01_event.EventTag{
        try noztr.nip98_http_auth.http_auth_build_url_tag(
            &url_tag,
            "https://api.example.com/upload?lang=zig",
        ),
        try noztr.nip98_http_auth.http_auth_build_method_tag(&method_tag, "POST"),
        try noztr.nip98_http_auth.http_auth_build_payload_tag(&payload_tag, payload_hex),
    };
    var event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = noztr.nip98_http_auth.http_auth_kind,
        .created_at = 1_700_000_000,
        .content = "",
        .tags = tags[0..],
    };
    var header_output: [1024]u8 = undefined;
    var json_scratch: [1024]u8 = undefined;
    var decoded_json_output: [1024]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try common.sign_event(&secret_key, &event);
    const header = try noztr.nip98_http_auth.http_auth_encode_authorization_header(
        header_output[0..],
        &event,
        json_scratch[0..],
    );
    const verified = try noztr.nip98_http_auth.http_auth_verify_authorization_header(
        decoded_json_output[0..],
        header,
        "https://api.example.com/upload?lang=zig",
        "POST",
        payload_hex,
        1_700_000_010,
        60,
        30,
        arena.allocator(),
    );

    try std.testing.expectEqualStrings("Nostr ", header[0..6]);
    try std.testing.expectEqual(pubkey, verified.event.pubkey);
    try std.testing.expectEqualStrings("https://api.example.com/upload?lang=zig", verified.info.url);
    try std.testing.expectEqualStrings("POST", verified.info.method);
    try std.testing.expectEqualStrings(payload_hex, verified.info.payload_hex.?);
}

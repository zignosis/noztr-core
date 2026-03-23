const std = @import("std");
const noztr = @import("noztr");

const valid_nip04_payload = "sN1Hm//UOqmtq8V++NVQnA==?iv=RERERERERERERERERERERA==";
const valid_nip46_uri =
    "nostrconnect://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
    "?relay=wss%3A%2F%2Frelay.example.com&secret=shared-secret";

test "deterministic imported-input property lane rejects or roundtrips bounded text inputs" {
    var prng = std.Random.DefaultPrng.init(0xC0DEC0DE5EED1234);
    const random = prng.random();

    var nip21_scratch: [noztr.limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    var nip04_output: [noztr.limits.nip04_payload_max_bytes]u8 = undefined;

    var generated: [192]u8 = undefined;

    var iteration: usize = 0;
    while (iteration < 256) : (iteration += 1) {
        const len = random.intRangeAtMost(usize, 0, generated.len);
        fill_random_ascii(generated[0..len], random);

        exercise_nip04(generated[0..len], nip04_output[0..]) catch |err| switch (err) {
            error.InvalidPayloadFormat,
            error.InvalidBase64,
            error.InvalidIvLength,
            error.InvalidCiphertextLength,
            error.BufferTooSmall,
            => {},
            else => return err,
        };

        _ = noztr.nip21_uri.uri_parse(generated[0..len], nip21_scratch[0..]) catch |err| switch (err) {
            error.InvalidUri,
            error.InvalidScheme,
            error.ForbiddenEntity,
            error.InvalidEntityEncoding,
            => {},
        };

        var uri_scratch_storage: [2048]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(uri_scratch_storage[0..]);
        _ = noztr.nip46_remote_signing.uri_parse(generated[0..len], fba.allocator()) catch |err| switch (err) {
            error.InvalidUri,
            error.InvalidScheme,
            error.InvalidPubkey,
            error.MissingRelay,
            error.TooManyRelays,
            error.InvalidRelayUrl,
            error.MissingSecret,
            error.InvalidSecret,
            error.InvalidPermission,
            error.InvalidPermissionKind,
            error.InvalidName,
            error.InvalidUrl,
            error.InvalidImage,
            error.TooManyPermissions,
            error.BufferTooSmall,
            error.OutOfMemory,
            => {},
            else => return err,
        };
    }
}

test "deterministic imported-input mutation lane preserves typed boundaries on valid seeds" {
    var payload_storage = valid_nip04_payload.*;
    var uri_storage = valid_nip46_uri.*;
    var tlv_scratch: [noztr.limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    var serialize_output: [noztr.limits.nip46_uri_bytes_max]u8 = undefined;
    var nip04_output: [noztr.limits.nip04_payload_max_bytes]u8 = undefined;

    for (0..payload_storage.len) |index| {
        const original = payload_storage[index];
        payload_storage[index] = mutate_ascii_byte(original);
        exercise_nip04(payload_storage[0..], nip04_output[0..]) catch |err| switch (err) {
            error.InvalidPayloadFormat,
            error.InvalidBase64,
            error.InvalidIvLength,
            error.InvalidCiphertextLength,
            => {},
            else => return err,
        };
        payload_storage[index] = original;
    }

    var bech32_output: [noztr.limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    const npub = try noztr.nip19_bech32.nip19_encode(
        bech32_output[0..],
        .{ .npub = [_]u8{0x11} ** 32 },
    );
    var uri_buf: [noztr.limits.nip21_uri_bytes_max]u8 = undefined;
    const valid_nip21 = try std.fmt.bufPrint(uri_buf[0..], "nostr:{s}", .{npub});

    for (0..valid_nip21.len) |index| {
        const original = uri_buf[index];
        uri_buf[index] = mutate_ascii_byte(original);
        _ = noztr.nip21_uri.uri_parse(uri_buf[0..valid_nip21.len], tlv_scratch[0..]) catch |err| switch (err) {
            error.InvalidUri,
            error.InvalidScheme,
            error.ForbiddenEntity,
            error.InvalidEntityEncoding,
            => {},
        };
        uri_buf[index] = original;
    }

    for (0..uri_storage.len) |index| {
        const original = uri_storage[index];
        uri_storage[index] = mutate_ascii_byte(original);
        var fba_storage: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(fba_storage[0..]);
        const parsed = noztr.nip46_remote_signing.uri_parse(uri_storage[0..], fba.allocator()) catch |err| switch (err) {
            error.InvalidUri,
            error.InvalidScheme,
            error.InvalidPubkey,
            error.MissingRelay,
            error.TooManyRelays,
            error.InvalidRelayUrl,
            error.MissingSecret,
            error.InvalidSecret,
            error.InvalidPermission,
            error.InvalidPermissionKind,
            error.InvalidName,
            error.InvalidUrl,
            error.InvalidImage,
            error.TooManyPermissions,
            error.BufferTooSmall,
            error.OutOfMemory,
            => {
                uri_storage[index] = original;
                continue;
            },
            else => return err,
        };
        const rendered = try noztr.nip46_remote_signing.uri_serialize(serialize_output[0..], parsed);
        var reparsed_storage: [4096]u8 = undefined;
        var reparsed_fba = std.heap.FixedBufferAllocator.init(reparsed_storage[0..]);
        _ = try noztr.nip46_remote_signing.uri_parse(rendered, reparsed_fba.allocator());
        uri_storage[index] = original;
    }
}

fn exercise_nip04(input: []const u8, output: []u8) !void {
    const parsed = try noztr.nip04.nip04_payload_parse(input);
    const rendered = try noztr.nip04.nip04_payload_serialize(
        output,
        parsed.ciphertext_base64,
        parsed.iv_base64,
    );
    const reparsed = try noztr.nip04.nip04_payload_parse(rendered);
    try std.testing.expectEqualStrings(parsed.ciphertext_base64, reparsed.ciphertext_base64);
    try std.testing.expectEqualStrings(parsed.iv_base64, reparsed.iv_base64);
}

fn fill_random_ascii(output: []u8, random: std.Random) void {
    for (output) |*byte| {
        byte.* = switch (random.intRangeAtMost(u8, 0, 7)) {
            0 => random.intRangeAtMost(u8, '0', '9'),
            1 => random.intRangeAtMost(u8, 'a', 'z'),
            2 => random.intRangeAtMost(u8, 'A', 'Z'),
            3 => '?',
            4 => '=',
            5 => ':',
            6 => '/',
            else => random.intRangeAtMost(u8, 33, 126),
        };
    }
}

fn mutate_ascii_byte(byte: u8) u8 {
    return switch (byte) {
        'a'...'y', 'A'...'Y', '0'...'8' => byte + 1,
        'z' => '0',
        'Z' => 'a',
        '9' => 'A',
        else => '?',
    };
}

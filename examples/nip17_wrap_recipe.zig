const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "recipe: build and unwrap a full signed NIP-17 gift wrap transcript" {
    const sender_secret = [_]u8{0x11} ** 32;
    const wrap_secret = [_]u8{0x22} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const sender_pubkey = try common.derive_public_key(&sender_secret);
    const wrap_pubkey = try common.derive_public_key(&wrap_secret);
    const recipient_pubkey = try common.derive_public_key(&recipient_secret);
    const recipient_hex = std.fmt.bytesToHex(recipient_pubkey, .lower);
    var recipient_tag: noztr.nip17_private_messages.BuiltTag = .{};
    const built_recipient = try noztr.nip17_private_messages.nip17_build_recipient_tag(
        &recipient_tag,
        recipient_hex[0..],
        null,
    );
    const rumor_tags = [_]noztr.nip01_event.EventTag{built_recipient};
    var rumor = common.simple_event(14, sender_pubkey, "ciphertext payload", rumor_tags[0..]);
    try common.finalize_event_id(&rumor);
    var rumor_json_storage: [512]u8 = undefined;
    const rumor_json = try build_unsigned_dm_rumor_json(rumor_json_storage[0..], &rumor);
    var seal_payload_storage: [1024]u8 = undefined;
    const seal_payload = try encrypt_for_recipient(
        seal_payload_storage[0..],
        &sender_secret,
        &recipient_pubkey,
        rumor_json,
        [_]u8{0x44} ** 32,
    );
    var seal = common.simple_event(13, sender_pubkey, seal_payload, &.{});
    try common.sign_event(&sender_secret, &seal);
    var seal_json_storage: [1536]u8 = undefined;
    const seal_json = try noztr.nip01_event.event_serialize_json_object(
        seal_json_storage[0..],
        &seal,
    );
    var wrap_payload_storage: [2048]u8 = undefined;
    const wrap_payload = try encrypt_for_recipient(
        wrap_payload_storage[0..],
        &wrap_secret,
        &recipient_pubkey,
        seal_json,
        [_]u8{0x55} ** 32,
    );
    var wrap = common.simple_event(1059, wrap_pubkey, wrap_payload, &.{});
    try common.sign_event(&wrap_secret, &wrap);
    const wrap_conversation_key = try noztr.nip44.nip44_get_conversation_key(
        &recipient_secret,
        &wrap_pubkey,
    );
    var seal_plaintext: [1536]u8 = undefined;
    const decrypted_seal = try noztr.nip44.nip44_decrypt_from_base64(
        seal_plaintext[0..],
        &wrap_conversation_key,
        wrap.content,
    );
    try std.testing.expectEqualStrings(seal_json, decrypted_seal);
    var parse_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer parse_arena.deinit();
    _ = try noztr.nip01_event.event_parse_json(decrypted_seal, parse_arena.allocator());
    var rumor_output: noztr.nip01_event.Event = undefined;
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed = try noztr.nip17_private_messages.nip17_unwrap_message(
        &rumor_output,
        &recipient_secret,
        &wrap,
        recipients[0..],
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(usize, 1), parsed.recipients.len);
    try std.testing.expectEqualStrings("ciphertext payload", parsed.content);
    try std.testing.expect(std.mem.eql(u8, &parsed.recipients[0].pubkey, &recipient_pubkey));
}

test "recipe: mailbox relay list authors can be matched to one recipient secret" {
    const recipient_secret = [_]u8{0x33} ** 32;
    const recipient_pubkey = try common.derive_public_key(&recipient_secret);
    const relay_tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relay", "wss://relay.one" } },
    };
    const relay_event = common.simple_event(10050, recipient_pubkey, "", relay_tags[0..]);
    var relays: [1][]const u8 = undefined;

    const relay_count = try noztr.nip17_private_messages.nip17_relay_list_extract(
        &relay_event,
        relays[0..],
    );
    try std.testing.expectEqual(@as(u16, 1), relay_count);
    try std.testing.expect(std.mem.eql(u8, &relay_event.pubkey, &recipient_pubkey));
}

fn build_unsigned_dm_rumor_json(
    output: []u8,
    rumor: *const noztr.nip01_event.Event,
) ![]const u8 {
    std.debug.assert(output.len >= 128);
    std.debug.assert(@intFromPtr(rumor) != 0);

    const id_hex = std.fmt.bytesToHex(rumor.id, .lower);
    const pubkey_hex = std.fmt.bytesToHex(rumor.pubkey, .lower);
    const recipient_hex = rumor.tags[0].items[1];
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"created_at\":{d},\"kind\":14," ++
            "\"tags\":[[\"p\",\"{s}\"]],\"content\":\"{s}\"}}",
        .{ id_hex[0..], pubkey_hex[0..], rumor.created_at, recipient_hex, rumor.content },
    );
}

fn encrypt_for_recipient(
    output: []u8,
    sender_secret: *const [32]u8,
    recipient_pubkey: *const [32]u8,
    plaintext: []const u8,
    nonce: [32]u8,
) ![]const u8 {
    std.debug.assert(@intFromPtr(sender_secret) != 0);
    std.debug.assert(@intFromPtr(recipient_pubkey) != 0);

    const conversation_key = try noztr.nip44.nip44_get_conversation_key(
        sender_secret,
        recipient_pubkey,
    );
    return noztr.nip44.nip44_encrypt_with_nonce_to_base64(
        output,
        &conversation_key,
        plaintext,
        &nonce,
    );
}

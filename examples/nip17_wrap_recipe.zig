const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "recipe: build and unwrap a full signed NIP-17 gift wrap transcript" {
    const sender_secret = [_]u8{0x11} ** 32;
    const wrap_secret = [_]u8{0x22} ** 32;
    const recipient_secret = [_]u8{0x33} ** 32;
    const sender_pubkey = try common.derive_public_key(&sender_secret);
    const recipient_pubkey = try common.derive_public_key(&recipient_secret);
    const recipient_hex = std.fmt.bytesToHex(recipient_pubkey, .lower);
    var recipient_tag: noztr.nip17_private_messages.TagBuilder = .{};
    const built_recipient = try noztr.nip17_private_messages.nip17_build_recipient_tag(
        &recipient_tag,
        recipient_hex[0..],
        null,
    );
    const rumor_tags = [_]noztr.nip01_event.EventTag{built_recipient};
    var rumor = common.simple_event(14, sender_pubkey, "ciphertext payload", rumor_tags[0..]);
    try common.finalize_event_id(&rumor);
    var rumor_json_storage: [512]u8 = undefined;
    var seal_json_storage: [1536]u8 = undefined;
    var seal_payload_storage: [1024]u8 = undefined;
    var wrap_payload_storage: [2048]u8 = undefined;
    var seal: noztr.nip01_event.Event = undefined;
    var wrap: noztr.nip59_wrap.BuiltWrapEvent = .{};

    const built = try noztr.nip59_wrap.build_outbound_for_recipient(
        &seal,
        &wrap,
        &sender_secret,
        &wrap_secret,
        &recipient_pubkey,
        &rumor,
        rumor_json_storage[0..],
        seal_json_storage[0..],
        seal_payload_storage[0..],
        wrap_payload_storage[0..],
        1_700_000_001,
        1_700_000_002,
        &([_]u8{0x44} ** 32),
        &([_]u8{0x55} ** 32),
    );
    const wrap_conversation_key = try noztr.nip44.get_conversation_key(
        &recipient_secret,
        &wrap.event.pubkey,
    );
    var seal_plaintext: [1536]u8 = undefined;
    const decrypted_seal = try noztr.nip44.decrypt_from_base64(
        seal_plaintext[0..],
        &wrap_conversation_key,
        wrap.event.content,
    );
    try std.testing.expectEqualStrings(built.seal_json, decrypted_seal);
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
        &wrap.event,
        recipients[0..],
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(usize, 1), parsed.recipients.len);
    try std.testing.expectEqualStrings("ciphertext payload", parsed.content);
    try std.testing.expect(std.mem.eql(u8, &parsed.recipients[0].pubkey, &recipient_pubkey));
    try std.testing.expectEqualStrings(built.rumor_json, try noztr.nip01_event.event_serialize_json_object_unsigned(
        rumor_json_storage[0..],
        &rumor,
    ));
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

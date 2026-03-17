const std = @import("std");
const noztr = @import("noztr");

test "NIP-59 adversarial example: mismatched sender rumor stays typed" {
    const sender_secret = [_]u8{0} ** 31 ++ [_]u8{3};
    const wrap_secret = [_]u8{0} ** 31 ++ [_]u8{4};
    const recipient_secret = [_]u8{0} ** 31 ++ [_]u8{5};
    const wrong_sender_secret = [_]u8{0} ** 31 ++ [_]u8{6};
    const wrong_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&wrong_sender_secret);
    const recipient_pubkey = try noztr.nostr_keys.nostr_derive_public_key(&recipient_secret);
    var rumor = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = wrong_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = 14,
        .created_at = 1_710_000_000,
        .content = "hello-mismatched-sender",
        .tags = &.{},
    };
    var seal: noztr.nip01_event.Event = undefined;
    var wrap: noztr.nip59_wrap.BuiltWrapEvent = .{};
    var rumor_json_storage: [512]u8 = undefined;
    var seal_json_storage: [1024]u8 = undefined;
    var seal_payload_storage: [2048]u8 = undefined;
    var wrap_payload_storage: [4096]u8 = undefined;
    const nonce_a = [_]u8{0x44} ** 32;
    const nonce_b = [_]u8{0x55} ** 32;

    rumor.id = try noztr.nip01_event.event_compute_id_checked(&rumor);
    try std.testing.expectError(
        error.InvalidRumorEvent,
        noztr.nip59_wrap.nip59_build_outbound_for_recipient(
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
            1_710_000_001,
            1_710_000_002,
            &nonce_a,
            &nonce_b,
        ),
    );
}

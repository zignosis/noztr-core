const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

fn build_signed_text_note(
    secret_key: *const [32]u8,
    created_at: u64,
    content: []const u8,
) !noztr.nip01_event.Event {
    const pubkey = try common.derive_public_key(secret_key);
    var event = common.simple_event(1, pubkey, content, &.{});
    event.created_at = created_at;
    try common.sign_event(secret_key, &event);
    return event;
}

test "recipe: strict core event lifecycle and filter matching stay discoverable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const secret_key = [_]u8{0x21} ** 32;
    const event = try build_signed_text_note(&secret_key, 7, "strict core");
    const pubkey_hex = std.fmt.bytesToHex(event.pubkey, .lower);
    var event_json_output: [512]u8 = undefined;
    var preimage_output: [256]u8 = undefined;
    var filter_output: [160]u8 = undefined;

    const event_json = try common.simple_event_json(event_json_output[0..], &event);
    const canonical_json = try noztr.nip01_event.event_serialize_canonical_json(
        preimage_output[0..],
        &event,
    );
    const reparsed = try noztr.nip01_event.event_parse_json(event_json, arena.allocator());
    const computed_id = try noztr.nip01_event.event_compute_id_checked(&reparsed);
    const author_filter_json = try std.fmt.bufPrint(
        filter_output[0..],
        "{{\"kinds\":[1],\"authors\":[\"{s}\"]}}",
        .{pubkey_hex[0..]},
    );
    const filter_a = try noztr.nip01_filter.filter_parse_json("{\"kinds\":[7]}", arena.allocator());
    const filter_b = try noztr.nip01_filter.filter_parse_json(
        author_filter_json,
        arena.allocator(),
    );
    const filters = [_]noztr.nip01_filter.Filter{ filter_a, filter_b };

    try std.testing.expectEqualSlices(u8, event.id[0..], reparsed.id[0..]);
    try std.testing.expectEqualSlices(u8, event.id[0..], computed_id[0..]);
    try noztr.nip01_event.event_verify_id(&reparsed);
    try noztr.nip01_event.event_verify(&reparsed);
    try std.testing.expect(noztr.nip01_filter.filters_match_event(filters[0..], &reparsed));
    try std.testing.expect(std.mem.startsWith(u8, event_json, "{\"id\":\""));
    try std.testing.expect(std.mem.startsWith(u8, canonical_json, "[0,\""));
}

test "recipe: strict message grammar and transcript flow stay explicit" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const req = try noztr.nip01_message.client_message_parse_json(
        "[\"REQ\",\"sub-1\",{\"kinds\":[1]},{\"authors\":[\"0123456789abcdef0123456789abcdef" ++
            "0123456789abcdef0123456789abcdef\"]}]",
        arena.allocator(),
    );
    const count = try noztr.nip01_message.client_message_parse_json(
        "[\"COUNT\",\"sub-1\",{\"kinds\":[1]},{\"authors\":[\"0123456789abcdef0123456789abcdef" ++
            "0123456789abcdef0123456789abcdef\"]}]",
        arena.allocator(),
    );
    const ok = try noztr.nip01_message.relay_message_parse_json(
        "[\"OK\",\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",true," ++
            "\"duplicate: already have this event\"]",
        arena.allocator(),
    );
    var req_output: [256]u8 = undefined;
    var count_output: [128]u8 = undefined;
    var ok_output: [512]u8 = undefined;
    var state = noztr.nip01_message.TranscriptState{};
    var early_close = noztr.nip01_message.TranscriptState{};
    const relay_event = noztr.nip01_message.RelayMessage{ .event = .{
        .subscription_id = "sub-1",
        .event = common.simple_event(1, [_]u8{0x33} ** 32, "event", &.{}),
    } };

    try noztr.transcript_mark_client_req(&state, "sub-1");
    try noztr.transcript_apply_relay(&state, relay_event);
    try noztr.transcript_apply_relay(&state, .{ .eose = .{ .subscription_id = "sub-1" } });
    try noztr.transcript_apply_relay(
        &state,
        .{ .closed = .{ .subscription_id = "sub-1", .status = "closed: complete" } },
    );
    try noztr.transcript_mark_client_req(&early_close, "sub-2");
    try noztr.transcript_apply_relay(
        &early_close,
        .{ .closed = .{ .subscription_id = "sub-2", .status = "closed: rate-limited" } },
    );

    try std.testing.expect(req == .req);
    try std.testing.expectEqual(@as(u8, 2), req.req.filters_count);
    try std.testing.expect(count == .count);
    try std.testing.expectEqual(@as(u8, 2), count.count.filters_count);
    try std.testing.expect(ok == .ok);
    try std.testing.expectEqualStrings(
        "[\"REQ\",\"sub-1\",{\"kinds\":[1]},{\"authors\":[\"0123456789abcdef0123456789abcdef" ++
            "0123456789abcdef0123456789abcdef\"]}]",
        try noztr.nip01_message.client_message_serialize_json(req_output[0..], &req),
    );
    try std.testing.expectEqualStrings(
        "[\"COUNT\",\"sub-1\",{\"kinds\":[1]},{\"authors\":[\"0123456789abcdef0123456789abcdef" ++
            "0123456789abcdef0123456789abcdef\"]}]",
        try noztr.nip01_message.client_message_serialize_json(count_output[0..], &count),
    );
    try std.testing.expectEqualStrings(
        "[\"OK\",\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",true," ++
            "\"duplicate: already have this event\"]",
        try noztr.nip01_message.relay_message_serialize_json(ok_output[0..], &ok),
    );
    try std.testing.expect(state.stage == .closed);
    try std.testing.expect(early_close.stage == .closed);
}

test "recipe: checked trust-boundary wrappers stay explicit" {
    const nonce_items = [_][]const u8{ "nonce", "1", "0" };
    const delete_items = [_][]const u8{
        "e",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const nonce_tags = [_]noztr.nip01_event.EventTag{.{ .items = nonce_items[0..] }};
    const delete_tags = [_]noztr.nip01_event.EventTag{.{ .items = delete_items[0..] }};
    const pubkey = [_]u8{0x44} ** 32;
    var pow_event = common.simple_event(1, pubkey, "pow", nonce_tags[0..]);
    const delete_event = common.simple_event(5, pubkey, "", delete_tags[0..]);
    var targets: [1]noztr.nip09_delete.DeleteTarget = undefined;

    try common.finalize_event_id(&pow_event);

    try std.testing.expect(try noztr.pow_meets_difficulty_verified_id(&pow_event, 0));
    try std.testing.expectEqual(
        @as(u16, 1),
        try noztr.delete_extract_targets_checked(&delete_event, targets[0..]),
    );
}

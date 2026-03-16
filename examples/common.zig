const noztr = @import("noztr");

pub fn simple_event(
    kind: u32,
    pubkey: [32]u8,
    content: []const u8,
    tags: []const noztr.nip01_event.EventTag,
) noztr.nip01_event.Event {
    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = 1,
        .content = content,
        .tags = tags,
    };
}

pub fn finalize_event_id(event: *noztr.nip01_event.Event) !void {
    event.id = try noztr.nip01_event.event_compute_id_checked(event);
}

pub fn simple_event_json(
    output: []u8,
    event: *const noztr.nip01_event.Event,
) ![]const u8 {
    return noztr.nip01_event.event_serialize_json_object(output, event);
}

pub fn derive_public_key(secret_key: *const [32]u8) ![32]u8 {
    return noztr.nostr_keys.nostr_derive_public_key(secret_key);
}

pub fn sign_event(secret_key: *const [32]u8, event: *noztr.nip01_event.Event) !void {
    try noztr.nostr_keys.nostr_sign_event(secret_key, event);
}

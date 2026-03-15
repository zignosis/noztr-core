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

const std = @import("std");

/// Strict-by-default shared limits for core protocol modules.
///
/// All constants are fixed-width and bounded to preserve deterministic behavior.
pub const Limits = struct {
    pub const event_json_max: u32 = 262_144;
    pub const content_bytes_max: u32 = 65_536;
    pub const tags_max: u16 = 2_048;
    pub const tag_items_max: u16 = 16;
    pub const tag_item_bytes_max: u16 = 4_096;

    pub const filter_ids_max: u16 = 1_024;
    pub const filter_authors_max: u16 = 1_024;
    pub const filter_kinds_max: u16 = 128;
    pub const filter_tag_values_max: u16 = 2_048;

    pub const relay_message_bytes_max: u32 = 524_288;
    pub const subscription_id_bytes_max: u8 = 64;

    pub const id_hex_length: u8 = 64;
    pub const pubkey_hex_length: u8 = 64;
    pub const sig_hex_length: u8 = 128;
};

pub const event_json_max: u32 = Limits.event_json_max;
pub const content_bytes_max: u32 = Limits.content_bytes_max;
pub const tags_max: u16 = Limits.tags_max;
pub const tag_items_max: u16 = Limits.tag_items_max;
pub const tag_item_bytes_max: u16 = Limits.tag_item_bytes_max;

pub const filter_ids_max: u16 = Limits.filter_ids_max;
pub const filter_authors_max: u16 = Limits.filter_authors_max;
pub const filter_kinds_max: u16 = Limits.filter_kinds_max;
pub const filter_tag_values_max: u16 = Limits.filter_tag_values_max;

pub const relay_message_bytes_max: u32 = Limits.relay_message_bytes_max;
pub const subscription_id_bytes_max: u8 = Limits.subscription_id_bytes_max;

pub const id_hex_length: u8 = Limits.id_hex_length;
pub const pubkey_hex_length: u8 = Limits.pubkey_hex_length;
pub const sig_hex_length: u8 = Limits.sig_hex_length;

comptime {
    std.debug.assert(Limits.content_bytes_max <= Limits.event_json_max);
    std.debug.assert(Limits.relay_message_bytes_max >= Limits.event_json_max);
    std.debug.assert(Limits.tag_item_bytes_max <= Limits.content_bytes_max);
    std.debug.assert(Limits.id_hex_length == Limits.pubkey_hex_length);
    std.debug.assert(Limits.sig_hex_length == Limits.id_hex_length * 2);
    std.debug.assert(Limits.subscription_id_bytes_max > 0);
}

test "limits relation checks stay true" {
    try std.testing.expect(Limits.content_bytes_max <= Limits.event_json_max);
    try std.testing.expect(Limits.relay_message_bytes_max >= Limits.event_json_max);
    try std.testing.expect(Limits.tag_item_bytes_max <= Limits.content_bytes_max);
    try std.testing.expect(Limits.id_hex_length == Limits.pubkey_hex_length);
    try std.testing.expect(Limits.sig_hex_length == Limits.id_hex_length * 2);
}

test "limits negative-space boundaries are explicit" {
    const content_exceeds_event = Limits.content_bytes_max + 1 > Limits.event_json_max;
    const signature_not_truncated = Limits.sig_hex_length != Limits.id_hex_length;

    try std.testing.expect(!content_exceeds_event);
    try std.testing.expect(signature_not_truncated);
}

const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const relay_origin = @import("internal/relay_origin.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const websocket_relay_url = @import("internal/websocket_relay_url.zig");

pub const discovery_kind: u32 = 30166;
pub const monitor_kind: u32 = 10166;

pub const RelayDiscoveryError = error{
    InvalidDiscoveryKind,
    InvalidMonitorKind,
    MissingIdentifierTag,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    DuplicateOpenRttTag,
    InvalidOpenRttTag,
    DuplicateReadRttTag,
    InvalidReadRttTag,
    DuplicateWriteRttTag,
    InvalidWriteRttTag,
    DuplicateNetworkTag,
    InvalidNetworkTag,
    DuplicateRelayTypeTag,
    InvalidRelayTypeTag,
    InvalidSupportedNipTag,
    InvalidRequirementTag,
    InvalidTopicTag,
    InvalidKindTag,
    DuplicateGeohashTag,
    InvalidGeohashTag,
    MissingFrequencyTag,
    DuplicateFrequencyTag,
    InvalidFrequencyTag,
    InvalidTimeoutTag,
    InvalidCheckTag,
    BufferTooSmall,
};

pub const RelayIdentity = union(enum) {
    relay_url: []const u8,
    relay_pubkey: [32]u8,
};

pub const DiscoveryRttMetric = enum {
    open,
    read,
    write,
};

pub const RelayRequirement = struct {
    name: []const u8,
    enabled: bool,
};

pub const RelayKindPolicy = struct {
    kind: u32,
    accepted: bool,
};

pub const RelayMonitorTimeout = struct {
    check: ?[]const u8 = null,
    milliseconds: u32,
};

pub const RelayDiscoveryInfo = struct {
    identity: RelayIdentity,
    content: []const u8,
    open_rtt_ms: ?u32 = null,
    read_rtt_ms: ?u32 = null,
    write_rtt_ms: ?u32 = null,
    network_type: ?[]const u8 = null,
    relay_type: ?[]const u8 = null,
    geohash: ?[]const u8 = null,
    supported_nip_count: u16 = 0,
    requirement_count: u16 = 0,
    topic_count: u16 = 0,
    kind_policy_count: u16 = 0,
};

pub const RelayMonitorInfo = struct {
    content: []const u8,
    frequency_seconds: u64,
    geohash: ?[]const u8 = null,
    timeout_count: u16 = 0,
    check_count: u16 = 0,
};

pub const BuiltTag = struct {
    items: [3][]const u8 = undefined,
    text_storage: [3][limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded relay discovery metadata from a kind-30166 event.
pub fn relay_discovery_extract(
    event: *const nip01_event.Event,
    out_supported_nips: []u16,
    out_requirements: []RelayRequirement,
    out_topics: [][]const u8,
    out_kind_policies: []RelayKindPolicy,
) RelayDiscoveryError!RelayDiscoveryInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_supported_nips.len <= limits.tags_max);

    if (event.kind != discovery_kind) return error.InvalidDiscoveryKind;

    var identity: ?RelayIdentity = null;
    var info = RelayDiscoveryInfo{
        .identity = undefined,
        .content = event.content,
    };
    for (event.tags) |tag| {
        try apply_discovery_tag(
            tag,
            &identity,
            &info,
            out_supported_nips,
            out_requirements,
            out_topics,
            out_kind_policies,
        );
    }
    info.identity = identity orelse return error.MissingIdentifierTag;
    return info;
}

/// Extracts bounded relay monitor announcement metadata from a kind-10166 event.
pub fn relay_monitor_extract(
    event: *const nip01_event.Event,
    out_timeouts: []RelayMonitorTimeout,
    out_checks: [][]const u8,
) RelayDiscoveryError!RelayMonitorInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_checks.len <= limits.tags_max);

    if (event.kind != monitor_kind) return error.InvalidMonitorKind;

    var saw_frequency = false;
    var info = RelayMonitorInfo{
        .content = event.content,
        .frequency_seconds = 0,
    };
    for (event.tags) |tag| {
        try apply_monitor_tag(tag, &saw_frequency, &info, out_timeouts, out_checks);
    }
    if (!saw_frequency) return error.MissingFrequencyTag;
    return info;
}

pub fn relay_discovery_build_url_tag(
    output: *BuiltTag,
    relay_url: []const u8,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    const origin = relay_url_validate(relay_url) catch return error.InvalidIdentifierTag;
    output.items[0] = "d";
    output.items[1] = render_normalized_origin(output.text_storage[0][0..], origin) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn relay_discovery_build_pubkey_tag(
    output: *BuiltTag,
    relay_pubkey: *const [32]u8,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(relay_pubkey) != 0);

    output.items[0] = "d";
    output.items[1] = std.fmt.bufPrint(
        output.text_storage[0][0..],
        "{s}",
        .{std.fmt.bytesToHex(relay_pubkey.*, .lower)},
    ) catch return error.BufferTooSmall;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn relay_discovery_build_rtt_tag(
    output: *BuiltTag,
    metric: DiscoveryRttMetric,
    milliseconds: u32,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(milliseconds <= std.math.maxInt(u32));

    output.items[0] = switch (metric) {
        .open => "rtt-open",
        .read => "rtt-read",
        .write => "rtt-write",
    };
    output.items[1] = std.fmt.bufPrint(output.text_storage[0][0..], "{d}", .{milliseconds}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn relay_discovery_build_network_tag(
    output: *BuiltTag,
    network_type: []const u8,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    output.items[0] = "n";
    output.items[1] = parse_lower_token(network_type) catch return error.InvalidNetworkTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn relay_discovery_build_relay_type_tag(
    output: *BuiltTag,
    relay_type: []const u8,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    output.items[0] = "T";
    output.items[1] = parse_pascal_token(relay_type) catch return error.InvalidRelayTypeTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn relay_discovery_build_supported_nip_tag(
    output: *BuiltTag,
    nip_number: u16,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(nip_number <= std.math.maxInt(u16));

    if (nip_number == 0) return error.InvalidSupportedNipTag;
    output.items[0] = "N";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0][0..], "{d}", .{nip_number}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn relay_discovery_build_requirement_tag(
    output: *BuiltTag,
    requirement: []const u8,
    enabled: bool,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    output.items[0] = "R";
    output.items[1] = render_prefixed_token(
        output.text_storage[0][0..],
        requirement,
        enabled,
    ) catch return error.InvalidRequirementTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn relay_discovery_build_topic_tag(
    output: *BuiltTag,
    topic: []const u8,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    output.items[0] = "t";
    output.items[1] = parse_topic(topic) catch return error.InvalidTopicTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn relay_discovery_build_kind_tag(
    output: *BuiltTag,
    kind: u32,
    accepted: bool,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(kind <= limits.kind_max);

    output.items[0] = "k";
    output.items[1] = render_kind_policy(output.text_storage[0][0..], kind, accepted) catch {
        return error.InvalidKindTag;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn relay_discovery_build_geohash_tag(
    output: *BuiltTag,
    geohash: []const u8,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    output.items[0] = "g";
    output.items[1] = parse_geohash(geohash) catch return error.InvalidGeohashTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn relay_monitor_build_frequency_tag(
    output: *BuiltTag,
    frequency_seconds: u64,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(frequency_seconds <= std.math.maxInt(u64));

    if (frequency_seconds == 0) return error.InvalidFrequencyTag;
    output.items[0] = "frequency";
    output.items[1] = std.fmt.bufPrint(
        output.text_storage[0][0..],
        "{d}",
        .{frequency_seconds},
    ) catch return error.BufferTooSmall;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn relay_monitor_build_timeout_tag(
    output: *BuiltTag,
    milliseconds: u32,
    check: ?[]const u8,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    output.items[0] = "timeout";
    output.item_count = 2;
    if (check) |value| {
        output.items[1] = parse_lower_token(value) catch return error.InvalidTimeoutTag;
        output.items[2] = std.fmt.bufPrint(
            output.text_storage[0][0..],
            "{d}",
            .{milliseconds},
        ) catch return error.BufferTooSmall;
        output.item_count = 3;
        return output.as_event_tag();
    }

    output.items[1] = std.fmt.bufPrint(output.text_storage[0][0..], "{d}", .{milliseconds}) catch {
        return error.BufferTooSmall;
    };
    return output.as_event_tag();
}

pub fn relay_monitor_build_check_tag(
    output: *BuiltTag,
    check: []const u8,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    output.items[0] = "c";
    output.items[1] = parse_lower_token(check) catch return error.InvalidCheckTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn relay_monitor_build_geohash_tag(
    output: *BuiltTag,
    geohash: []const u8,
) RelayDiscoveryError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    output.items[0] = "g";
    output.items[1] = parse_geohash(geohash) catch return error.InvalidGeohashTag;
    output.item_count = 2;
    return output.as_event_tag();
}

fn apply_discovery_tag(
    tag: nip01_event.EventTag,
    identity: *?RelayIdentity,
    info: *RelayDiscoveryInfo,
    out_supported_nips: []u16,
    out_requirements: []RelayRequirement,
    out_topics: [][]const u8,
    out_kind_policies: []RelayKindPolicy,
) RelayDiscoveryError!void {
    std.debug.assert(@intFromPtr(identity) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "d")) return apply_identity_tag(tag, identity);
    if (std.mem.eql(u8, name, "rtt-open")) {
        return apply_rtt_tag(
            tag,
            &info.open_rtt_ms,
            error.DuplicateOpenRttTag,
            error.InvalidOpenRttTag,
        );
    }
    if (std.mem.eql(u8, name, "rtt-read")) {
        return apply_rtt_tag(
            tag,
            &info.read_rtt_ms,
            error.DuplicateReadRttTag,
            error.InvalidReadRttTag,
        );
    }
    if (std.mem.eql(u8, name, "rtt-write")) {
        return apply_rtt_tag(
            tag,
            &info.write_rtt_ms,
            error.DuplicateWriteRttTag,
            error.InvalidWriteRttTag,
        );
    }
    if (std.mem.eql(u8, name, "n")) {
        return apply_text_tag(
            tag,
            &info.network_type,
            error.DuplicateNetworkTag,
            error.InvalidNetworkTag,
            parse_lower_token,
        );
    }
    if (std.mem.eql(u8, name, "T")) {
        return apply_text_tag(
            tag,
            &info.relay_type,
            error.DuplicateRelayTypeTag,
            error.InvalidRelayTypeTag,
            parse_pascal_token,
        );
    }
    if (std.mem.eql(u8, name, "g")) {
        return apply_text_tag(
            tag,
            &info.geohash,
            error.DuplicateGeohashTag,
            error.InvalidGeohashTag,
            parse_geohash,
        );
    }
    if (std.mem.eql(u8, name, "N")) return append_supported_nip(tag, info, out_supported_nips);
    if (std.mem.eql(u8, name, "R")) return append_requirement(tag, info, out_requirements);
    if (std.mem.eql(u8, name, "t")) return append_topic(tag, info, out_topics);
    if (std.mem.eql(u8, name, "k")) return append_kind_policy(tag, info, out_kind_policies);
}

fn apply_monitor_tag(
    tag: nip01_event.EventTag,
    saw_frequency: *bool,
    info: *RelayMonitorInfo,
    out_timeouts: []RelayMonitorTimeout,
    out_checks: [][]const u8,
) RelayDiscoveryError!void {
    std.debug.assert(@intFromPtr(saw_frequency) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "frequency")) {
        return apply_frequency_tag(tag, saw_frequency, info);
    }
    if (std.mem.eql(u8, name, "timeout")) return append_timeout(tag, info, out_timeouts);
    if (std.mem.eql(u8, name, "c")) return append_check(tag, info, out_checks);
    if (std.mem.eql(u8, name, "g")) {
        return apply_text_tag(
            tag,
            &info.geohash,
            error.DuplicateGeohashTag,
            error.InvalidGeohashTag,
            parse_geohash,
        );
    }
}

fn apply_identity_tag(
    tag: nip01_event.EventTag,
    identity: *?RelayIdentity,
) RelayDiscoveryError!void {
    std.debug.assert(@intFromPtr(identity) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (identity.* != null) return error.DuplicateIdentifierTag;
    if (tag.items.len != 2) return error.InvalidIdentifierTag;
    identity.* = parse_identity_value(tag.items[1]) catch return error.InvalidIdentifierTag;
}

fn parse_identity_value(text: []const u8) error{InvalidIdentity}!RelayIdentity {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (text.len == 0) return error.InvalidIdentity;
    if (relay_url_validate(text)) |_| {
        return .{ .relay_url = text };
    } else |_| {}
    const pubkey = lower_hex_32.parse(text) catch return error.InvalidIdentity;
    return .{ .relay_pubkey = pubkey };
}

fn apply_rtt_tag(
    tag: nip01_event.EventTag,
    field: *?u32,
    duplicate_error: RelayDiscoveryError,
    invalid_error: RelayDiscoveryError,
) RelayDiscoveryError!void {
    std.debug.assert(@intFromPtr(field) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = parse_u32_text(tag.items[1]) catch return invalid_error;
}

fn apply_text_tag(
    tag: nip01_event.EventTag,
    field: *?[]const u8,
    duplicate_error: RelayDiscoveryError,
    invalid_error: RelayDiscoveryError,
    parser: fn ([]const u8) anyerror![]const u8,
) RelayDiscoveryError!void {
    std.debug.assert(@intFromPtr(field) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = parser(tag.items[1]) catch return invalid_error;
}

fn append_supported_nip(
    tag: nip01_event.EventTag,
    info: *RelayDiscoveryInfo,
    out_supported_nips: []u16,
) RelayDiscoveryError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_supported_nips.len <= std.math.maxInt(u16));

    if (tag.items.len != 2) return error.InvalidSupportedNipTag;
    if (info.supported_nip_count == out_supported_nips.len) return error.BufferTooSmall;
    out_supported_nips[info.supported_nip_count] = parse_nip_number(tag.items[1]) catch {
        return error.InvalidSupportedNipTag;
    };
    info.supported_nip_count += 1;
}

fn append_requirement(
    tag: nip01_event.EventTag,
    info: *RelayDiscoveryInfo,
    out_requirements: []RelayRequirement,
) RelayDiscoveryError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_requirements.len <= std.math.maxInt(u16));

    if (tag.items.len != 2) return error.InvalidRequirementTag;
    if (info.requirement_count == out_requirements.len) return error.BufferTooSmall;
    out_requirements[info.requirement_count] = parse_requirement(tag.items[1]) catch {
        return error.InvalidRequirementTag;
    };
    info.requirement_count += 1;
}

fn append_topic(
    tag: nip01_event.EventTag,
    info: *RelayDiscoveryInfo,
    out_topics: [][]const u8,
) RelayDiscoveryError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_topics.len <= std.math.maxInt(u16));

    if (tag.items.len != 2) return error.InvalidTopicTag;
    if (info.topic_count == out_topics.len) return error.BufferTooSmall;
    out_topics[info.topic_count] = parse_topic(tag.items[1]) catch return error.InvalidTopicTag;
    info.topic_count += 1;
}

fn append_kind_policy(
    tag: nip01_event.EventTag,
    info: *RelayDiscoveryInfo,
    out_kind_policies: []RelayKindPolicy,
) RelayDiscoveryError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_kind_policies.len <= std.math.maxInt(u16));

    if (tag.items.len != 2) return error.InvalidKindTag;
    if (info.kind_policy_count == out_kind_policies.len) return error.BufferTooSmall;
    out_kind_policies[info.kind_policy_count] = parse_kind_policy(tag.items[1]) catch {
        return error.InvalidKindTag;
    };
    info.kind_policy_count += 1;
}

fn apply_frequency_tag(
    tag: nip01_event.EventTag,
    saw_frequency: *bool,
    info: *RelayMonitorInfo,
) RelayDiscoveryError!void {
    std.debug.assert(@intFromPtr(saw_frequency) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (saw_frequency.*) return error.DuplicateFrequencyTag;
    if (tag.items.len != 2) return error.InvalidFrequencyTag;
    info.frequency_seconds = parse_frequency(tag.items[1]) catch return error.InvalidFrequencyTag;
    saw_frequency.* = true;
}

fn append_timeout(
    tag: nip01_event.EventTag,
    info: *RelayMonitorInfo,
    out_timeouts: []RelayMonitorTimeout,
) RelayDiscoveryError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_timeouts.len <= std.math.maxInt(u16));

    if (info.timeout_count == out_timeouts.len) return error.BufferTooSmall;
    out_timeouts[info.timeout_count] = parse_timeout_tag(tag) catch return error.InvalidTimeoutTag;
    info.timeout_count += 1;
}

fn append_check(
    tag: nip01_event.EventTag,
    info: *RelayMonitorInfo,
    out_checks: [][]const u8,
) RelayDiscoveryError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_checks.len <= std.math.maxInt(u16));

    if (tag.items.len != 2) return error.InvalidCheckTag;
    if (info.check_count == out_checks.len) return error.BufferTooSmall;
    out_checks[info.check_count] = parse_lower_token(tag.items[1]) catch {
        return error.InvalidCheckTag;
    };
    info.check_count += 1;
}

fn parse_nip_number(text: []const u8) error{InvalidValue}!u16 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@sizeOf(u16) == 2);

    const value = std.fmt.parseUnsigned(u16, text, 10) catch return error.InvalidValue;
    if (value == 0) return error.InvalidValue;
    return value;
}

fn parse_requirement(text: []const u8) error{InvalidValue}!RelayRequirement {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= std.math.maxInt(u16));

    if (text.len == 0) return error.InvalidValue;
    if (text[0] == '!') {
        return .{
            .name = try parse_lower_token(text[1..]),
            .enabled = false,
        };
    }
    return .{
        .name = try parse_lower_token(text),
        .enabled = true,
    };
}

fn parse_kind_policy(text: []const u8) error{InvalidValue}!RelayKindPolicy {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.kind_max == std.math.maxInt(u16));

    if (text.len == 0) return error.InvalidValue;
    const accepted = text[0] != '!';
    const number_text = if (accepted) text else text[1..];
    const kind = std.fmt.parseUnsigned(u32, number_text, 10) catch return error.InvalidValue;
    if (kind > limits.kind_max) return error.InvalidValue;
    return .{ .kind = kind, .accepted = accepted };
}

fn parse_timeout_tag(tag: nip01_event.EventTag) error{InvalidValue}!RelayMonitorTimeout {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 3);

    if (tag.items.len == 2) {
        return .{ .milliseconds = try parse_u32_text(tag.items[1]) };
    }
    if (tag.items.len != 3) return error.InvalidValue;

    const first_ms = parse_u32_text(tag.items[1]) catch null;
    const second_ms = parse_u32_text(tag.items[2]) catch null;
    if (first_ms) |milliseconds| {
        if (second_ms != null) return error.InvalidValue;
        return .{
            .check = try parse_lower_token(tag.items[2]),
            .milliseconds = milliseconds,
        };
    }
    const check = try parse_lower_token(tag.items[1]);
    return .{
        .check = check,
        .milliseconds = second_ms orelse return error.InvalidValue,
    };
}

fn parse_frequency(text: []const u8) error{InvalidValue}!u64 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@sizeOf(u64) == 8);

    const value = std.fmt.parseUnsigned(u64, text, 10) catch return error.InvalidValue;
    if (value == 0) return error.InvalidValue;
    return value;
}

fn parse_u32_text(text: []const u8) error{InvalidValue}!u32 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@sizeOf(u32) == 4);

    return std.fmt.parseUnsigned(u32, text, 10) catch return error.InvalidValue;
}

fn parse_lower_token(text: []const u8) error{InvalidValue}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0 or text.len > limits.tag_item_bytes_max) return error.InvalidValue;
    for (text) |byte| {
        if (byte >= 'a' and byte <= 'z') continue;
        if (byte >= '0' and byte <= '9') continue;
        if (byte == '-') continue;
        return error.InvalidValue;
    }
    return text;
}

fn parse_pascal_token(text: []const u8) error{InvalidValue}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0 or text.len > limits.tag_item_bytes_max) return error.InvalidValue;
    if (!std.ascii.isUpper(text[0])) return error.InvalidValue;
    for (text[1..]) |byte| {
        if (std.ascii.isAlphabetic(byte)) continue;
        if (std.ascii.isDigit(byte)) continue;
        return error.InvalidValue;
    }
    return text;
}

fn parse_topic(text: []const u8) error{InvalidValue}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0 or text.len > limits.tag_item_bytes_max) return error.InvalidValue;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidValue;
    for (text) |byte| {
        if (std.ascii.isWhitespace(byte)) return error.InvalidValue;
        if (std.ascii.isUpper(byte)) return error.InvalidValue;
    }
    return text;
}

fn parse_geohash(text: []const u8) error{InvalidValue}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0 or text.len > limits.tag_item_bytes_max) return error.InvalidValue;
    for (text) |byte| {
        if (byte >= '0' and byte <= '9') continue;
        if (byte == 'b' or byte == 'c' or byte == 'd') continue;
        if (byte == 'e' or byte == 'f' or byte == 'g') continue;
        if (byte == 'h' or byte == 'j' or byte == 'k') continue;
        if (byte == 'm' or byte == 'n' or byte == 'p') continue;
        if (byte == 'q' or byte == 'r' or byte == 's') continue;
        if (byte == 't' or byte == 'u' or byte == 'v') continue;
        if (byte == 'w' or byte == 'x' or byte == 'y' or byte == 'z') continue;
        return error.InvalidValue;
    }
    return text;
}

fn render_prefixed_token(
    output: []u8,
    token: []const u8,
    enabled: bool,
) error{InvalidValue}![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(token.len <= limits.tag_item_bytes_max);

    const parsed = try parse_lower_token(token);
    if (enabled) return parsed;
    if (parsed.len + 1 > output.len) return error.InvalidValue;
    output[0] = '!';
    @memcpy(output[1 .. parsed.len + 1], parsed);
    return output[0 .. parsed.len + 1];
}

fn render_kind_policy(
    output: []u8,
    kind: u32,
    accepted: bool,
) error{InvalidValue}![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(kind <= limits.kind_max);

    if (kind > limits.kind_max) return error.InvalidValue;
    if (accepted) {
        return std.fmt.bufPrint(output, "{d}", .{kind}) catch return error.InvalidValue;
    }
    return std.fmt.bufPrint(output, "!{d}", .{kind}) catch return error.InvalidValue;
}

fn relay_url_validate(url: []const u8) error{InvalidUrl}!relay_origin.WebsocketOrigin {
    std.debug.assert(url.len <= limits.tag_item_bytes_max);
    std.debug.assert(@sizeOf(relay_origin.WebsocketOrigin) > 0);

    return websocket_relay_url.parse_origin(url, limits.tag_item_bytes_max) catch return error.InvalidUrl;
}

fn render_normalized_origin(
    output: []u8,
    origin: relay_origin.WebsocketOrigin,
) error{BufferTooSmall}![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(origin.scheme.len > 0);

    var stream = std.io.fixedBufferStream(output);
    const writer = stream.writer();
    try write_lower_ascii(writer, origin.scheme);
    writer.writeAll("://") catch return error.BufferTooSmall;
    try write_lower_ascii(writer, origin.host);
    if (!is_default_port(origin.scheme, origin.port)) {
        writer.print(":{d}", .{origin.port}) catch return error.BufferTooSmall;
    }
    writer.writeAll(origin.path) catch return error.BufferTooSmall;
    return output[0..stream.pos];
}

fn write_lower_ascii(writer: anytype, text: []const u8) error{BufferTooSmall}!void {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@TypeOf(writer) != void);

    for (text) |byte| {
        writer.writeByte(std.ascii.toLower(byte)) catch return error.BufferTooSmall;
    }
}

fn is_default_port(scheme: []const u8, port: u16) bool {
    std.debug.assert(scheme.len > 0);
    std.debug.assert(port <= std.math.maxInt(u16));

    if (std.ascii.eqlIgnoreCase(scheme, "ws")) return port == 80;
    if (std.ascii.eqlIgnoreCase(scheme, "wss")) return port == 443;
    return false;
}

fn build_event(
    kind: u32,
    tags: []const nip01_event.EventTag,
    content: []const u8,
) nip01_event.Event {
    std.debug.assert(kind <= std.math.maxInt(u32));
    std.debug.assert(tags.len <= limits.tags_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{1} ** 32,
        .sig = [_]u8{2} ** 64,
        .kind = kind,
        .created_at = 1,
        .content = content,
        .tags = tags,
    };
}

test "relay discovery extract parses bounded metadata and normalized identity tags" {
    var d_tag = BuiltTag{};
    var rtt_tag = BuiltTag{};
    var network_tag = BuiltTag{};
    var type_tag = BuiltTag{};
    var nip_tag = BuiltTag{};
    var req_tag = BuiltTag{};
    var topic_tag = BuiltTag{};
    var kind_tag = BuiltTag{};
    var geo_tag = BuiltTag{};

    const tags = [_]nip01_event.EventTag{
        try relay_discovery_build_url_tag(&d_tag, "WSS://Relay.EXAMPLE:443/path?drop=1"),
        try relay_discovery_build_rtt_tag(&rtt_tag, .open, 234),
        try relay_discovery_build_network_tag(&network_tag, "clearnet"),
        try relay_discovery_build_relay_type_tag(&type_tag, "PrivateInbox"),
        try relay_discovery_build_supported_nip_tag(&nip_tag, 11),
        try relay_discovery_build_requirement_tag(&req_tag, "payment", false),
        try relay_discovery_build_topic_tag(&topic_tag, "nsfw"),
        try relay_discovery_build_kind_tag(&kind_tag, 1, false),
        try relay_discovery_build_geohash_tag(&geo_tag, "ww8p1r4t8"),
    };
    const event = build_event(discovery_kind, tags[0..], "{\"name\":\"relay\"}");
    var supported_nips: [2]u16 = undefined;
    var requirements: [2]RelayRequirement = undefined;
    var topics: [2][]const u8 = undefined;
    var kind_policies: [2]RelayKindPolicy = undefined;

    const parsed = try relay_discovery_extract(
        &event,
        supported_nips[0..],
        requirements[0..],
        topics[0..],
        kind_policies[0..],
    );

    try std.testing.expect(parsed.identity == .relay_url);
    try std.testing.expectEqualStrings(
        "WSS://Relay.EXAMPLE:443/path?drop=1",
        parsed.identity.relay_url,
    );
    try std.testing.expectEqualStrings("{\"name\":\"relay\"}", parsed.content);
    try std.testing.expectEqual(@as(?u32, 234), parsed.open_rtt_ms);
    try std.testing.expectEqualStrings("clearnet", parsed.network_type.?);
    try std.testing.expectEqualStrings("PrivateInbox", parsed.relay_type.?);
    try std.testing.expectEqualStrings("ww8p1r4t8", parsed.geohash.?);
    try std.testing.expectEqual(@as(u16, 1), parsed.supported_nip_count);
    try std.testing.expectEqual(@as(u16, 1), parsed.requirement_count);
    try std.testing.expectEqual(@as(u16, 1), parsed.topic_count);
    try std.testing.expectEqual(@as(u16, 1), parsed.kind_policy_count);
    try std.testing.expectEqual(@as(u16, 11), supported_nips[0]);
    try std.testing.expect(!requirements[0].enabled);
    try std.testing.expectEqualStrings("payment", requirements[0].name);
    try std.testing.expectEqualStrings("nsfw", topics[0]);
    try std.testing.expect(!kind_policies[0].accepted);
    try std.testing.expectEqual(@as(u32, 1), kind_policies[0].kind);
    try std.testing.expectEqualStrings("wss://relay.example/path", tags[0].items[1]);
}

test "relay discovery extract accepts relay pubkey identity" {
    var id_tag = BuiltTag{};
    const relay_pubkey = [_]u8{0xaa} ** 32;
    const tags = [_]nip01_event.EventTag{
        try relay_discovery_build_pubkey_tag(&id_tag, &relay_pubkey),
    };
    const event = build_event(discovery_kind, tags[0..], "");

    var supported_nips: [1]u16 = undefined;
    var requirements: [1]RelayRequirement = undefined;
    var topics: [1][]const u8 = undefined;
    var kind_policies: [1]RelayKindPolicy = undefined;
    const parsed = try relay_discovery_extract(
        &event,
        supported_nips[0..],
        requirements[0..],
        topics[0..],
        kind_policies[0..],
    );

    try std.testing.expect(parsed.identity == .relay_pubkey);
    try std.testing.expectEqualSlices(u8, relay_pubkey[0..], parsed.identity.relay_pubkey[0..]);
}

test "relay monitor extract parses canonical and ambiguous timeout orders" {
    var freq_tag = BuiltTag{};
    var timeout_tag = BuiltTag{};
    var check_tag = BuiltTag{};
    var geo_tag = BuiltTag{};
    const tags = [_]nip01_event.EventTag{
        try relay_monitor_build_frequency_tag(&freq_tag, 3600),
        try relay_monitor_build_timeout_tag(&timeout_tag, 5000, "open"),
        .{ .items = &.{ "timeout", "3000", "read" } },
        try relay_monitor_build_check_tag(&check_tag, "dns"),
        try relay_monitor_build_geohash_tag(&geo_tag, "ww8p1r4t8"),
    };
    const event = build_event(monitor_kind, tags[0..], "");
    var timeouts: [2]RelayMonitorTimeout = undefined;
    var checks: [1][]const u8 = undefined;

    const parsed = try relay_monitor_extract(&event, timeouts[0..], checks[0..]);

    try std.testing.expectEqual(@as(u64, 3600), parsed.frequency_seconds);
    try std.testing.expectEqual(@as(u16, 2), parsed.timeout_count);
    try std.testing.expectEqual(@as(u16, 1), parsed.check_count);
    try std.testing.expectEqualStrings("ww8p1r4t8", parsed.geohash.?);
    try std.testing.expectEqualStrings("open", timeouts[0].check.?);
    try std.testing.expectEqual(@as(u32, 5000), timeouts[0].milliseconds);
    try std.testing.expectEqualStrings("read", timeouts[1].check.?);
    try std.testing.expectEqual(@as(u32, 3000), timeouts[1].milliseconds);
    try std.testing.expectEqualStrings("dns", checks[0]);
}

test "relay discovery and monitor direct invalid input stays typed" {
    var overlong: [limits.tag_item_bytes_max + 2]u8 = undefined;
    var topic_tag = BuiltTag{};
    var timeout_tag = BuiltTag{};
    @memset(overlong[0..], 'a');

    try std.testing.expectError(
        error.InvalidTopicTag,
        relay_discovery_build_topic_tag(&topic_tag, overlong[0..]),
    );
    try std.testing.expectError(
        error.InvalidTimeoutTag,
        relay_monitor_build_timeout_tag(&timeout_tag, 3000, overlong[0..]),
    );
}

test "relay discovery and monitor reject malformed tags deterministically" {
    const discovery_tags = [_]nip01_event.EventTag{.{ .items = &.{ "d", "https://not-a-relay" } }};
    const discovery_event = build_event(discovery_kind, discovery_tags[0..], "");
    var supported_nips: [1]u16 = undefined;
    var requirements: [1]RelayRequirement = undefined;
    var topics: [1][]const u8 = undefined;
    var kind_policies: [1]RelayKindPolicy = undefined;
    try std.testing.expectError(
        error.InvalidIdentifierTag,
        relay_discovery_extract(
            &discovery_event,
            supported_nips[0..],
            requirements[0..],
            topics[0..],
            kind_policies[0..],
        ),
    );

    const monitor_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "frequency", "3600" } },
        .{ .items = &.{ "timeout", "open", "read" } },
    };
    const monitor_event = build_event(monitor_kind, monitor_tags[0..], "");
    var timeouts: [1]RelayMonitorTimeout = undefined;
    var checks: [1][]const u8 = undefined;
    try std.testing.expectError(
        error.InvalidTimeoutTag,
        relay_monitor_extract(&monitor_event, timeouts[0..], checks[0..]),
    );
}

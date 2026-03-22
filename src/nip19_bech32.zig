const std = @import("std");
const limits = @import("limits.zig");

pub const Bech32Error = error{
    InvalidBech32,
    InvalidChecksum,
    MixedCase,
    InvalidPrefix,
    InvalidPayload,
    MissingRequiredTlv,
    MalformedKnownOptionalTlv,
    BufferTooSmall,
    ValueOutOfRange,
};

pub const RelayList = struct {
    count: u8 = 0,
    values: [limits.nip19_relays_max][]const u8 = [_][]const u8{""} ** limits.nip19_relays_max,
};

pub const NprofilePointer = struct {
    pubkey: [32]u8,
    relays: RelayList = .{},
};

pub const NeventPointer = struct {
    id: [32]u8,
    relays: RelayList = .{},
    author: ?[32]u8 = null,
    kind: ?u32 = null,
};

pub const NaddrPointer = struct {
    identifier: []const u8,
    pubkey: [32]u8,
    kind: u32,
    relays: RelayList = .{},
};

pub const NrelayPointer = struct {
    relay: []const u8,
};

pub const Nip19Entity = union(enum) {
    npub: [32]u8,
    nsec: [32]u8,
    note: [32]u8,
    nprofile: NprofilePointer,
    nevent: NeventPointer,
    naddr: NaddrPointer,
    nrelay: NrelayPointer,
};

const bech32_charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";
const bech32_generator = [_]u32{ 0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3 };

pub fn nip19_encode(output: []u8, entity: Nip19Entity) Bech32Error![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(usize));
    std.debug.assert(limits.nip19_tlv_scratch_bytes_max > 0);

    switch (entity) {
        .npub => |value| return encode_fixed_entity(output, "npub", &value),
        .nsec => |value| return encode_fixed_entity(output, "nsec", &value),
        .note => |value| return encode_fixed_entity(output, "note", &value),
        .nprofile => |value| return encode_nprofile(output, value),
        .nevent => |value| return encode_nevent(output, value),
        .naddr => |value| return encode_naddr(output, value),
        .nrelay => |value| return encode_nrelay(output, value),
    }
}

/// Decodes a NIP-19 bech32 identifier into a typed entity.
///
/// Lifetime and ownership:
/// - Returned fixed entities (`npub`, `nsec`, `note`) own copied 32-byte arrays.
/// - Returned TLV entities may borrow `tlv_scratch` for string slices:
///   `nprofile.relays`, `nevent.relays`, `naddr.identifier`, `naddr.relays`, and
///   `nrelay.relay`.
/// - Keep `tlv_scratch` alive and unmodified while using these borrowed fields.
pub fn nip19_decode(input: []const u8, tlv_scratch: []u8) Bech32Error!Nip19Entity {
    if (input.len > limits.nip19_bech32_identifier_bytes_max) {
        return error.InvalidBech32;
    }
    std.debug.assert(input.len <= limits.nip19_bech32_identifier_bytes_max);
    std.debug.assert(tlv_scratch.len <= std.math.maxInt(usize));

    var hrp_buffer: [limits.nip19_bech32_hrp_bytes_max]u8 = undefined;
    var data_values: [limits.nip19_bech32_identifier_bytes_max]u8 = undefined;

    const parsed = try decode_bech32(input, &hrp_buffer, &data_values);
    const payload_values = parsed.data_values[0 .. parsed.data_values.len - 6];
    const payload_len = try convert_bits(tlv_scratch, payload_values, 5, 8, false);
    const payload = tlv_scratch[0..payload_len];

    if (std.mem.eql(u8, parsed.hrp, "npub")) return decode_fixed_entity(payload, .npub);
    if (std.mem.eql(u8, parsed.hrp, "nsec")) return decode_fixed_entity(payload, .nsec);
    if (std.mem.eql(u8, parsed.hrp, "note")) return decode_fixed_entity(payload, .note);
    if (std.mem.eql(u8, parsed.hrp, "nprofile")) {
        return .{ .nprofile = try decode_nprofile(payload) };
    }
    if (std.mem.eql(u8, parsed.hrp, "nevent")) return .{ .nevent = try decode_nevent(payload) };
    if (std.mem.eql(u8, parsed.hrp, "naddr")) return .{ .naddr = try decode_naddr(payload) };
    if (std.mem.eql(u8, parsed.hrp, "nrelay")) return .{ .nrelay = try decode_nrelay(payload) };

    return error.InvalidPrefix;
}

fn encode_fixed_entity(output: []u8, hrp: []const u8, value: *const [32]u8) Bech32Error![]const u8 {
    std.debug.assert(value.len == 32);
    std.debug.assert(hrp.len <= limits.nip19_bech32_hrp_bytes_max);

    return encode_bech32(output, hrp, value[0..]);
}

fn decode_fixed_entity(
    payload: []const u8,
    comptime tag: std.meta.Tag(Nip19Entity),
) Bech32Error!Nip19Entity {
    std.debug.assert(payload.len <= limits.nip19_tlv_scratch_bytes_max);
    std.debug.assert(@typeInfo(Nip19Entity).@"union".tag_type != null);

    if (payload.len != 32) {
        return error.InvalidPayload;
    }

    var value: [32]u8 = undefined;
    @memcpy(value[0..], payload);
    return @unionInit(Nip19Entity, @tagName(tag), value);
}

fn encode_nprofile(output: []u8, pointer: NprofilePointer) Bech32Error![]const u8 {
    std.debug.assert(pointer.pubkey.len == 32);
    std.debug.assert(pointer.relays.count <= limits.nip19_relays_max);

    var payload: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    var payload_len: u16 = 0;

    try append_tlv(&payload, &payload_len, 0, pointer.pubkey[0..], true);
    try append_relays_tlv(&payload, &payload_len, pointer.relays);
    return encode_bech32(output, "nprofile", payload[0..payload_len]);
}

fn encode_nevent(output: []u8, pointer: NeventPointer) Bech32Error![]const u8 {
    std.debug.assert(pointer.id.len == 32);
    std.debug.assert(pointer.relays.count <= limits.nip19_relays_max);

    var payload: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    var payload_len: u16 = 0;

    try append_tlv(&payload, &payload_len, 0, pointer.id[0..], true);
    try append_relays_tlv(&payload, &payload_len, pointer.relays);
    if (pointer.author) |author| {
        try append_tlv(&payload, &payload_len, 2, author[0..], true);
    }
    if (pointer.kind) |kind| {
        var kind_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &kind_bytes, kind, .big);
        try append_tlv(&payload, &payload_len, 3, kind_bytes[0..], true);
    }
    return encode_bech32(output, "nevent", payload[0..payload_len]);
}

fn encode_naddr(output: []u8, pointer: NaddrPointer) Bech32Error![]const u8 {
    std.debug.assert(pointer.pubkey.len == 32);
    std.debug.assert(pointer.identifier.len <= limits.nip19_identifier_tlv_bytes_max);

    var payload: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    var payload_len: u16 = 0;
    var kind_bytes: [4]u8 = undefined;

    std.mem.writeInt(u32, &kind_bytes, pointer.kind, .big);
    try append_tlv(&payload, &payload_len, 0, pointer.identifier, false);
    try append_relays_tlv(&payload, &payload_len, pointer.relays);
    try append_tlv(&payload, &payload_len, 2, pointer.pubkey[0..], true);
    try append_tlv(&payload, &payload_len, 3, kind_bytes[0..], true);
    return encode_bech32(output, "naddr", payload[0..payload_len]);
}

fn encode_nrelay(output: []u8, pointer: NrelayPointer) Bech32Error![]const u8 {
    std.debug.assert(pointer.relay.len <= limits.nip19_identifier_tlv_bytes_max);
    std.debug.assert(limits.nip19_relays_max > 0);

    if (pointer.relay.len == 0) {
        return error.ValueOutOfRange;
    }

    var payload: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    var payload_len: u16 = 0;

    try append_tlv(&payload, &payload_len, 0, pointer.relay, true);
    return encode_bech32(output, "nrelay", payload[0..payload_len]);
}

fn append_relays_tlv(
    payload: *[limits.nip19_tlv_scratch_bytes_max]u8,
    payload_len: *u16,
    relays: RelayList,
) Bech32Error!void {
    std.debug.assert(relays.count <= limits.nip19_relays_max);
    std.debug.assert(payload_len.* <= payload.len);

    var index: u8 = 0;
    while (index < relays.count) : (index += 1) {
        try append_tlv(payload, payload_len, 1, relays.values[index], true);
    }
}

fn append_tlv(
    payload: *[limits.nip19_tlv_scratch_bytes_max]u8,
    payload_len: *u16,
    tlv_type: u8,
    value: []const u8,
    non_empty: bool,
) Bech32Error!void {
    std.debug.assert(payload_len.* <= payload.len);
    std.debug.assert(tlv_type <= limits.nip19_tlv_type_max);

    if (value.len > limits.nip19_tlv_length_max) {
        return error.ValueOutOfRange;
    }
    if (non_empty and value.len == 0) {
        return error.ValueOutOfRange;
    }

    const needed = @as(u16, 2) + @as(u16, @intCast(value.len));
    if (payload_len.* + needed > payload.len) {
        return error.ValueOutOfRange;
    }

    const start = payload_len.*;
    payload[start] = tlv_type;
    payload[start + 1] = @intCast(value.len);
    @memcpy(payload[start + 2 .. start + 2 + value.len], value);
    payload_len.* += needed;
}

const Bech32Decoded = struct {
    hrp: []const u8,
    data_values: []const u8,
};

const Bech32CaseState = struct {
    saw_upper: bool = false,
    saw_lower: bool = false,
};

fn decode_bech32(
    input: []const u8,
    hrp_buffer: *[limits.nip19_bech32_hrp_bytes_max]u8,
    data_values_buffer: *[limits.nip19_bech32_identifier_bytes_max]u8,
) Bech32Error!Bech32Decoded {
    if (input.len > limits.nip19_bech32_identifier_bytes_max) {
        return error.InvalidBech32;
    }
    std.debug.assert(input.len <= limits.nip19_bech32_identifier_bytes_max);
    std.debug.assert(hrp_buffer.len == limits.nip19_bech32_hrp_bytes_max);

    if (input.len < 8) {
        return error.InvalidBech32;
    }

    const separator_index = std.mem.lastIndexOfScalar(u8, input, '1') orelse {
        return error.InvalidBech32;
    };
    if (separator_index == 0) {
        return error.InvalidBech32;
    }
    if (separator_index + 7 > input.len) {
        return error.InvalidBech32;
    }

    var case_state = Bech32CaseState{};
    const hrp = try normalize_hrp(
        input[0..separator_index],
        hrp_buffer,
        &case_state,
    );
    const data_values = try decode_data_values(
        input[separator_index + 1 ..],
        data_values_buffer,
        &case_state,
    );
    if (!verify_checksum(hrp, data_values)) {
        return error.InvalidChecksum;
    }
    return .{ .hrp = hrp, .data_values = data_values };
}

fn normalize_hrp(
    input_hrp: []const u8,
    hrp_buffer: *[limits.nip19_bech32_hrp_bytes_max]u8,
    case_state: *Bech32CaseState,
) Bech32Error![]const u8 {
    std.debug.assert(input_hrp.len <= limits.nip19_bech32_hrp_bytes_max);
    std.debug.assert(hrp_buffer.len == limits.nip19_bech32_hrp_bytes_max);
    std.debug.assert(@intFromPtr(case_state) != 0);

    if (input_hrp.len == 0) {
        return error.InvalidBech32;
    }
    if (input_hrp.len > hrp_buffer.len) {
        return error.InvalidBech32;
    }

    for (input_hrp, 0..) |char, index| {
        const lowered = try normalize_bech32_char(char, case_state);
        hrp_buffer[index] = lowered;
    }
    return hrp_buffer[0..input_hrp.len];
}

fn decode_data_values(
    input_data: []const u8,
    output_values: *[limits.nip19_bech32_identifier_bytes_max]u8,
    case_state: *Bech32CaseState,
) Bech32Error![]const u8 {
    std.debug.assert(input_data.len <= limits.nip19_bech32_identifier_bytes_max);
    std.debug.assert(output_values.len == limits.nip19_bech32_identifier_bytes_max);
    std.debug.assert(@intFromPtr(case_state) != 0);

    if (input_data.len < 6) {
        return error.InvalidBech32;
    }
    if (input_data.len > output_values.len) {
        return error.InvalidBech32;
    }

    for (input_data, 0..) |char, index| {
        const lowered = try normalize_bech32_char(char, case_state);
        const value = charset_value(lowered) orelse return error.InvalidBech32;
        output_values[index] = value;
    }
    return output_values[0..input_data.len];
}

fn normalize_bech32_char(char: u8, case_state: *Bech32CaseState) Bech32Error!u8 {
    std.debug.assert(@intFromPtr(case_state) != 0);
    std.debug.assert(!(case_state.saw_upper and case_state.saw_lower));

    if (char < 33 or char > 126) {
        return error.InvalidBech32;
    }

    var lowered = char;
    if (char >= 'A' and char <= 'Z') {
        case_state.saw_upper = true;
        lowered = char + 32;
    } else if (char >= 'a' and char <= 'z') {
        case_state.saw_lower = true;
    }
    if (case_state.saw_upper and case_state.saw_lower) {
        return error.MixedCase;
    }
    return lowered;
}

fn encode_bech32(output: []u8, hrp: []const u8, payload: []const u8) Bech32Error![]const u8 {
    std.debug.assert(hrp.len > 0);
    std.debug.assert(hrp.len <= limits.nip19_bech32_hrp_bytes_max);

    var data_values: [limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    const data_len = try convert_bits(&data_values, payload, 8, 5, true);
    const total_len = hrp.len + 1 + data_len + 6;

    if (total_len > limits.nip19_bech32_identifier_bytes_max) {
        return error.ValueOutOfRange;
    }
    if (output.len < total_len) {
        return error.BufferTooSmall;
    }

    @memcpy(output[0..hrp.len], hrp);
    output[hrp.len] = '1';
    var index: usize = 0;
    while (index < data_len) : (index += 1) {
        output[hrp.len + 1 + index] = bech32_charset[data_values[index]];
    }
    const checksum = create_checksum(hrp, data_values[0..data_len]);
    var checksum_index: usize = 0;
    while (checksum_index < checksum.len) : (checksum_index += 1) {
        output[hrp.len + 1 + data_len + checksum_index] = bech32_charset[checksum[checksum_index]];
    }
    return output[0..total_len];
}

fn convert_bits(
    output: []u8,
    input: []const u8,
    from_bits: u8,
    to_bits: u8,
    pad: bool,
) Bech32Error!u16 {
    std.debug.assert(from_bits > 0);
    std.debug.assert(to_bits > 0);

    var accumulator: u32 = 0;
    var bits: u8 = 0;
    var output_index: u16 = 0;
    const max_value = (@as(u32, 1) << @intCast(to_bits)) - 1;
    const from_mask = (@as(u32, 1) << @intCast(from_bits)) - 1;

    for (input) |value| {
        if ((@as(u32, value) & ~from_mask) != 0) return error.InvalidPayload;
        accumulator = (accumulator << @intCast(from_bits)) | value;
        bits += from_bits;
        while (bits >= to_bits) {
            bits -= to_bits;
            if (output_index >= output.len) return error.BufferTooSmall;
            output[output_index] = @intCast((accumulator >> @intCast(bits)) & max_value);
            output_index += 1;
        }
    }

    if (pad) {
        if (bits > 0) {
            if (output_index >= output.len) return error.BufferTooSmall;
            output[output_index] = @intCast((accumulator << @intCast(to_bits - bits)) & max_value);
            output_index += 1;
        }
        return output_index;
    }

    if (bits >= from_bits) return error.InvalidPayload;
    if (((accumulator << @intCast(to_bits - bits)) & max_value) != 0) return error.InvalidPayload;
    return output_index;
}

fn charset_value(char: u8) ?u8 {
    std.debug.assert(bech32_charset.len == 32);
    std.debug.assert(char <= 127 or char > 127);

    var index: u8 = 0;
    while (index < bech32_charset.len) : (index += 1) {
        if (bech32_charset[index] == char) {
            return index;
        }
    }
    return null;
}

fn bech32_polymod_step(checksum: u32) u32 {
    std.debug.assert(@sizeOf(u32) == 4);
    std.debug.assert(checksum <= std.math.maxInt(u32));

    const top = checksum >> 25;
    var next = (checksum & 0x1ffffff) << 5;
    var index: u8 = 0;
    while (index < bech32_generator.len) : (index += 1) {
        if (((top >> @intCast(index)) & 1) != 0) {
            next ^= bech32_generator[index];
        }
    }
    return next;
}

fn checksum_with_hrp(hrp: []const u8, data_values: []const u8, add_zero_tail: bool) u32 {
    std.debug.assert(hrp.len > 0);
    std.debug.assert(data_values.len <= limits.nip19_bech32_identifier_bytes_max);

    var checksum: u32 = 1;
    for (hrp) |char| {
        checksum = bech32_polymod_step(checksum) ^ (char >> 5);
    }
    checksum = bech32_polymod_step(checksum);
    for (hrp) |char| {
        checksum = bech32_polymod_step(checksum) ^ (char & 31);
    }
    for (data_values) |value| {
        checksum = bech32_polymod_step(checksum) ^ value;
    }
    if (add_zero_tail) {
        var index: u8 = 0;
        while (index < 6) : (index += 1) {
            checksum = bech32_polymod_step(checksum);
        }
    }
    return checksum;
}

fn create_checksum(hrp: []const u8, data_values: []const u8) [6]u8 {
    std.debug.assert(hrp.len > 0);
    std.debug.assert(data_values.len <= limits.nip19_bech32_identifier_bytes_max);

    const polymod = checksum_with_hrp(hrp, data_values, true) ^ 1;
    var checksum: [6]u8 = undefined;
    var index: u8 = 0;
    while (index < checksum.len) : (index += 1) {
        const shift = 5 * (5 - index);
        checksum[index] = @intCast((polymod >> @intCast(shift)) & 31);
    }
    return checksum;
}

fn verify_checksum(hrp: []const u8, data_values: []const u8) bool {
    std.debug.assert(hrp.len > 0);
    std.debug.assert(data_values.len >= 6);

    return checksum_with_hrp(hrp, data_values, false) == 1;
}

const TlvEntry = struct {
    tlv_type: u8,
    value: []const u8,
};

fn tlv_next(payload: []const u8, index: *u16, count: *u8) Bech32Error!?TlvEntry {
    std.debug.assert(@intFromPtr(index) != 0);
    std.debug.assert(@intFromPtr(count) != 0);

    if (index.* == payload.len) return null;
    if (payload.len - index.* < 2) return error.InvalidPayload;
    if (count.* >= limits.nip19_tlv_entries_max) return error.ValueOutOfRange;

    const tlv_type = payload[index.*];
    const tlv_length: u8 = payload[index.* + 1];
    const value_start = index.* + 2;
    const value_end = value_start + tlv_length;
    if (value_end > payload.len) return error.InvalidPayload;

    index.* = value_end;
    count.* += 1;
    return .{ .tlv_type = tlv_type, .value = payload[value_start..value_end] };
}

fn relay_list_push(relays: *RelayList, value: []const u8, optional_known: bool) Bech32Error!void {
    std.debug.assert(@intFromPtr(relays) != 0);
    std.debug.assert(relays.count <= limits.nip19_relays_max);

    if (value.len == 0) {
        if (optional_known) {
            return error.MalformedKnownOptionalTlv;
        }
        return error.InvalidPayload;
    }
    if (relays.count >= limits.nip19_relays_max) {
        return error.ValueOutOfRange;
    }

    relays.values[relays.count] = value;
    relays.count += 1;
}

fn decode_nprofile(payload: []const u8) Bech32Error!NprofilePointer {
    std.debug.assert(payload.len <= limits.nip19_tlv_scratch_bytes_max);
    std.debug.assert(limits.nip19_relays_max > 0);

    var pointer = NprofilePointer{ .pubkey = [_]u8{0} ** 32 };
    var index: u16 = 0;
    var count: u8 = 0;
    var have_pubkey = false;

    while (try tlv_next(payload, &index, &count)) |entry| {
        if (entry.tlv_type == 0) {
            if (entry.value.len != 32 or have_pubkey) return error.InvalidPayload;
            @memcpy(pointer.pubkey[0..], entry.value);
            have_pubkey = true;
        } else if (entry.tlv_type == 1) {
            try relay_list_push(&pointer.relays, entry.value, true);
        }
    }
    if (!have_pubkey) return error.MissingRequiredTlv;
    return pointer;
}

fn decode_nevent(payload: []const u8) Bech32Error!NeventPointer {
    std.debug.assert(payload.len <= limits.nip19_tlv_scratch_bytes_max);
    std.debug.assert(@sizeOf(u32) == 4);

    var pointer = NeventPointer{ .id = [_]u8{0} ** 32 };
    var index: u16 = 0;
    var count: u8 = 0;
    var have_id = false;

    while (try tlv_next(payload, &index, &count)) |entry| {
        if (entry.tlv_type == 0) {
            if (entry.value.len != 32 or have_id) return error.InvalidPayload;
            @memcpy(pointer.id[0..], entry.value);
            have_id = true;
        } else if (entry.tlv_type == 1) {
            try relay_list_push(&pointer.relays, entry.value, true);
        } else if (entry.tlv_type == 2) {
            if (entry.value.len != 32) return error.MalformedKnownOptionalTlv;
            if (pointer.author != null) return error.InvalidPayload;
            var author: [32]u8 = undefined;
            @memcpy(author[0..], entry.value);
            pointer.author = author;
        } else if (entry.tlv_type == 3) {
            if (entry.value.len != 4) return error.MalformedKnownOptionalTlv;
            if (pointer.kind != null) return error.InvalidPayload;
            pointer.kind = std.mem.readInt(u32, entry.value[0..4], .big);
        }
    }
    if (!have_id) return error.MissingRequiredTlv;
    return pointer;
}

fn decode_naddr(payload: []const u8) Bech32Error!NaddrPointer {
    std.debug.assert(payload.len <= limits.nip19_tlv_scratch_bytes_max);
    std.debug.assert(@sizeOf(u32) == 4);

    var pointer = NaddrPointer{ .identifier = "", .pubkey = [_]u8{0} ** 32, .kind = 0 };
    var index: u16 = 0;
    var count: u8 = 0;
    var have_identifier = false;
    var have_pubkey = false;
    var have_kind = false;

    while (try tlv_next(payload, &index, &count)) |entry| {
        if (entry.tlv_type == 0) {
            if (have_identifier) return error.InvalidPayload;
            pointer.identifier = entry.value;
            have_identifier = true;
        } else if (entry.tlv_type == 1) {
            try relay_list_push(&pointer.relays, entry.value, true);
        } else if (entry.tlv_type == 2) {
            if (entry.value.len != 32 or have_pubkey) return error.InvalidPayload;
            @memcpy(pointer.pubkey[0..], entry.value);
            have_pubkey = true;
        } else if (entry.tlv_type == 3) {
            if (entry.value.len != 4) return error.InvalidPayload;
            if (have_kind) return error.InvalidPayload;
            pointer.kind = std.mem.readInt(u32, entry.value[0..4], .big);
            have_kind = true;
        }
    }
    if (!have_identifier or !have_pubkey or !have_kind) return error.MissingRequiredTlv;
    return pointer;
}

fn decode_nrelay(payload: []const u8) Bech32Error!NrelayPointer {
    std.debug.assert(payload.len <= limits.nip19_tlv_scratch_bytes_max);
    std.debug.assert(limits.nip19_tlv_entries_max > 0);

    var index: u16 = 0;
    var count: u8 = 0;
    var relay: ?[]const u8 = null;

    while (try tlv_next(payload, &index, &count)) |entry| {
        if (entry.tlv_type != 0) continue;
        if (relay != null) return error.InvalidPayload;
        if (entry.value.len == 0) return error.InvalidPayload;
        relay = entry.value;
    }
    if (relay == null) return error.MissingRequiredTlv;
    return .{ .relay = relay.? };
}

fn append_tlv_for_test(
    payload: *[limits.nip19_tlv_scratch_bytes_max]u8,
    payload_len: *u16,
    tlv_type: u8,
    value: []const u8,
) void {
    std.debug.assert(value.len <= limits.nip19_tlv_length_max);
    std.debug.assert(payload_len.* + 2 + value.len <= payload.len);

    const start = payload_len.*;
    payload[start] = tlv_type;
    payload[start + 1] = @intCast(value.len);
    @memcpy(payload[start + 2 .. start + 2 + value.len], value);
    payload_len.* += @intCast(2 + value.len);
}

test "nip19 valid vectors include fixed, tlv, and roundtrip" {
    var output: [512]u8 = undefined;
    var scratch: [512]u8 = undefined;

    const key = [_]u8{0x11} ** 32;
    const npub_text = try nip19_encode(output[0..], .{ .npub = key });
    const decoded_npub = try nip19_decode(npub_text, scratch[0..]);
    try std.testing.expect(decoded_npub == .npub);
    try std.testing.expectEqualSlices(u8, key[0..], decoded_npub.npub[0..]);

    var relays = RelayList{};
    relays.values[0] = "wss://relay.example";
    relays.values[1] = "wss://relay.backup";
    relays.count = 2;

    const nevent_entity = Nip19Entity{
        .nevent = .{
            .id = [_]u8{0x22} ** 32,
            .relays = relays,
            .author = [_]u8{0x33} ** 32,
            .kind = 1,
        },
    };
    const nevent_text = try nip19_encode(output[0..], nevent_entity);
    const decoded_nevent = try nip19_decode(nevent_text, scratch[0..]);
    try std.testing.expect(decoded_nevent == .nevent);
    try std.testing.expectEqual(@as(u8, 2), decoded_nevent.nevent.relays.count);
    try std.testing.expectEqual(@as(u32, 1), decoded_nevent.nevent.kind.?);

    const reencoded_nevent = try nip19_encode(output[0..], decoded_nevent);
    try std.testing.expectEqualStrings(nevent_text, reencoded_nevent);
}

test "nip19 valid vectors include nsec naddr and nrelay" {
    var output: [512]u8 = undefined;
    var scratch: [512]u8 = undefined;

    const secret = [_]u8{0xAA} ** 32;
    const nsec_text = try nip19_encode(output[0..], .{ .nsec = secret });
    const decoded_nsec = try nip19_decode(nsec_text, scratch[0..]);
    try std.testing.expect(decoded_nsec == .nsec);
    try std.testing.expectEqualSlices(u8, secret[0..], decoded_nsec.nsec[0..]);

    var relays = RelayList{};
    relays.values[0] = "wss://relay.naddr";
    relays.count = 1;

    const naddr_entity = Nip19Entity{
        .naddr = .{
            .identifier = "article-42",
            .pubkey = [_]u8{0xBB} ** 32,
            .kind = 30023,
            .relays = relays,
        },
    };
    const naddr_text = try nip19_encode(output[0..], naddr_entity);
    const decoded_naddr = try nip19_decode(naddr_text, scratch[0..]);
    try std.testing.expect(decoded_naddr == .naddr);
    try std.testing.expectEqualStrings("article-42", decoded_naddr.naddr.identifier);
    try std.testing.expectEqual(@as(u32, 30023), decoded_naddr.naddr.kind);
    try std.testing.expectEqual(@as(u8, 1), decoded_naddr.naddr.relays.count);
    try std.testing.expectEqualStrings("wss://relay.naddr", decoded_naddr.naddr.relays.values[0]);

    const replaceable_naddr_entity = Nip19Entity{
        .naddr = .{
            .identifier = "",
            .pubkey = [_]u8{0xBC} ** 32,
            .kind = 10002,
        },
    };
    const replaceable_naddr_text = try nip19_encode(output[0..], replaceable_naddr_entity);
    const decoded_replaceable_naddr = try nip19_decode(replaceable_naddr_text, scratch[0..]);
    try std.testing.expect(decoded_replaceable_naddr == .naddr);
    try std.testing.expectEqualStrings("", decoded_replaceable_naddr.naddr.identifier);
    try std.testing.expectEqual(@as(u32, 10002), decoded_replaceable_naddr.naddr.kind);

    const nrelay_entity = Nip19Entity{
        .nrelay = .{ .relay = "wss://relay.only" },
    };
    const nrelay_text = try nip19_encode(output[0..], nrelay_entity);
    const decoded_nrelay = try nip19_decode(nrelay_text, scratch[0..]);
    try std.testing.expect(decoded_nrelay == .nrelay);
    try std.testing.expectEqualStrings("wss://relay.only", decoded_nrelay.nrelay.relay);
}

test "nip19 unknown tlv types are ignored" {
    var payload: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    var payload_len: u16 = 0;
    var output: [512]u8 = undefined;
    var scratch: [512]u8 = undefined;

    append_tlv_for_test(&payload, &payload_len, 0, &([_]u8{0x44} ** 32));
    append_tlv_for_test(&payload, &payload_len, 9, "ignored-data");
    append_tlv_for_test(&payload, &payload_len, 1, "wss://relay.unknown");

    const text = try encode_bech32(output[0..], "nprofile", payload[0..payload_len]);
    const decoded = try nip19_decode(text, scratch[0..]);
    try std.testing.expect(decoded == .nprofile);
    try std.testing.expectEqual(@as(u8, 1), decoded.nprofile.relays.count);
    try std.testing.expectEqualStrings("wss://relay.unknown", decoded.nprofile.relays.values[0]);
}

test "nip19 invalid vectors enforce strict failures" {
    var output: [512]u8 = undefined;
    var scratch: [512]u8 = undefined;
    var payload: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    var payload_len: u16 = 0;

    const valid = try nip19_encode(output[0..], .{ .note = [_]u8{0x55} ** 32 });
    var bad_checksum: [512]u8 = undefined;
    @memcpy(bad_checksum[0..valid.len], valid);
    bad_checksum[valid.len - 1] = if (bad_checksum[valid.len - 1] == 'q') 'p' else 'q';
    try std.testing.expectError(
        error.InvalidChecksum,
        nip19_decode(bad_checksum[0..valid.len], scratch[0..]),
    );

    var mixed_case: [512]u8 = undefined;
    @memcpy(mixed_case[0..valid.len], valid);
    mixed_case[0] = 'N';
    try std.testing.expectError(
        error.MixedCase,
        nip19_decode(mixed_case[0..valid.len], scratch[0..]),
    );

    var mixed_upper_hrp_lower_data: [512]u8 = undefined;
    @memcpy(mixed_upper_hrp_lower_data[0..valid.len], valid);
    mixed_upper_hrp_lower_data[0] = 'N';
    mixed_upper_hrp_lower_data[1] = 'O';
    mixed_upper_hrp_lower_data[2] = 'T';
    mixed_upper_hrp_lower_data[3] = 'E';
    try std.testing.expectError(
        error.MixedCase,
        nip19_decode(mixed_upper_hrp_lower_data[0..valid.len], scratch[0..]),
    );

    var mixed_lower_hrp_upper_data: [512]u8 = undefined;
    @memcpy(mixed_lower_hrp_upper_data[0..valid.len], valid);
    const separator_index = std.mem.lastIndexOfScalar(u8, valid, '1').?;
    var data_index = separator_index + 1;
    while (data_index < valid.len) : (data_index += 1) {
        const value = mixed_lower_hrp_upper_data[data_index];
        if (value >= 'a' and value <= 'z') {
            mixed_lower_hrp_upper_data[data_index] = value - 32;
            break;
        }
    }
    try std.testing.expect(data_index < valid.len);
    try std.testing.expectError(
        error.MixedCase,
        nip19_decode(mixed_lower_hrp_upper_data[0..valid.len], scratch[0..]),
    );

    payload_len = 0;
    append_tlv_for_test(&payload, &payload_len, 1, "wss://relay.only");
    const missing_required = try encode_bech32(output[0..], "nprofile", payload[0..payload_len]);
    try std.testing.expectError(
        error.MissingRequiredTlv,
        nip19_decode(missing_required, scratch[0..]),
    );

    payload_len = 0;
    append_tlv_for_test(&payload, &payload_len, 0, &([_]u8{0x77} ** 32));
    append_tlv_for_test(&payload, &payload_len, 2, &([_]u8{0x66} ** 31));
    const malformed_optional = try encode_bech32(output[0..], "nevent", payload[0..payload_len]);
    try std.testing.expectError(
        error.MalformedKnownOptionalTlv,
        nip19_decode(malformed_optional, scratch[0..]),
    );
}

test "nip19 decode rejects oversized input before parsing" {
    const oversized_len = @as(u16, limits.nip19_bech32_identifier_bytes_max) + 1;
    var input: [oversized_len]u8 = undefined;
    @memset(input[0..], 'q');

    var scratch: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    try std.testing.expectError(error.InvalidBech32, nip19_decode(input[0..], scratch[0..]));
}

test "nip19 decode forces invalid prefix and fixed-payload shape errors" {
    var output: [512]u8 = undefined;
    var scratch: [512]u8 = undefined;

    const unknown_prefix = try encode_bech32(output[0..], "abc", &([_]u8{0x01} ** 32));
    try std.testing.expectError(error.InvalidPrefix, nip19_decode(unknown_prefix, scratch[0..]));

    const invalid_fixed_payload = try encode_bech32(output[0..], "npub", &([_]u8{0x02} ** 31));
    try std.testing.expectError(
        error.InvalidPayload,
        nip19_decode(invalid_fixed_payload, scratch[0..]),
    );
}

test "nip19 public paths force BufferTooSmall on encode and decode" {
    var small_output: [10]u8 = undefined;
    var output: [512]u8 = undefined;
    var small_scratch: [31]u8 = undefined;

    try std.testing.expectError(
        error.BufferTooSmall,
        nip19_encode(small_output[0..], .{ .npub = [_]u8{0x11} ** 32 }),
    );

    const text = try nip19_encode(output[0..], .{ .npub = [_]u8{0x22} ** 32 });
    try std.testing.expectError(error.BufferTooSmall, nip19_decode(text, small_scratch[0..]));
}

test "nip19 encode forces ValueOutOfRange for empty required string fields" {
    var output: [512]u8 = undefined;

    try std.testing.expectError(
        error.ValueOutOfRange,
        nip19_encode(output[0..], .{ .nrelay = .{ .relay = "" } }),
    );
}

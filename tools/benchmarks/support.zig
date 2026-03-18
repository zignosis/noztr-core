const std = @import("std");
const noztr = @import("noztr");

pub const limits = noztr.limits;
pub const nip01_event = noztr.nip01_event;
pub const nip06_mnemonic = noztr.nip06_mnemonic;
pub const nip29 = noztr.nip29_relay_groups;
pub const nip88 = noztr.nip88_polls;
pub const bip85 = noztr.bip85_derivation;

pub const Nip06Context = struct {
    mnemonic: []const u8 =
        "install scatter logic circle pencil average fall shoe quantum disease suspect usage",
    passphrase: ?[]const u8 = null,
    seed_output: [limits.nip06_seed_bytes]u8 = undefined,
    secret_output: [limits.nip06_secret_key_bytes]u8 = undefined,
    child_mnemonic_output: [limits.bip85_mnemonic_bytes_max]u8 = undefined,
};

pub fn PollContext(comptime option_count: usize, comptime response_count: usize) type {
    return struct {
        const Self = @This();

        poll_id_hex: [limits.id_hex_length]u8 = undefined,
        option_ids: [option_count][8]u8 = undefined,
        option_labels: [option_count][16]u8 = undefined,
        poll_tag_items: [option_count][3][]const u8 = undefined,
        poll_tags: [option_count]nip01_event.EventTag = undefined,
        response_tag_items: [response_count][2][2][]const u8 = undefined,
        response_tags: [response_count][2]nip01_event.EventTag = undefined,
        responses: [response_count]nip01_event.Event = undefined,
        latest: [response_count]nip88.CountedResponse = undefined,
        tallies: [option_count]nip88.OptionTally = undefined,
        poll_event: nip01_event.Event = undefined,

        pub fn init(self: *Self) void {
            std.debug.assert(@intFromPtr(self) != 0);
            std.debug.assert(option_count > 0);

            fill_hex_from_repeated_byte(self.poll_id_hex[0..], 0x40);
            self.init_poll_tags();
            self.init_responses();
            self.poll_event = .{
                .id = [_]u8{0x40} ** 32,
                .pubkey = [_]u8{0x50} ** 32,
                .sig = [_]u8{0xaa} ** 64,
                .kind = nip88.poll_kind,
                .created_at = 10,
                .content = "benchmark poll",
                .tags = self.poll_tags[0..],
            };
        }

        fn init_poll_tags(self: *Self) void {
            std.debug.assert(@intFromPtr(self) != 0);
            std.debug.assert(option_count <= limits.tags_max);

            for (&self.poll_tags, 0..) |*tag, index| {
                const option_id = fill_ascii_counter(self.option_ids[index][0..], "opt", index);
                const label = fill_ascii_counter(self.option_labels[index][0..], "choice", index);
                self.poll_tag_items[index][0] = "option";
                self.poll_tag_items[index][1] = option_id;
                self.poll_tag_items[index][2] = label;
                tag.* = .{ .items = self.poll_tag_items[index][0..] };
            }
        }

        fn init_responses(self: *Self) void {
            std.debug.assert(@intFromPtr(self) != 0);
            std.debug.assert(response_count > 0);

            for (&self.responses, 0..) |*response, index| {
                const pubkey = unique_32_bytes(index + 1);
                const id = unique_32_bytes(index + 101);
                const option_index = index % option_count;
                self.response_tag_items[index][0][0] = "e";
                self.response_tag_items[index][0][1] = self.poll_id_hex[0..];
                self.response_tag_items[index][1][0] = "response";
                self.response_tag_items[index][1][1] = self.option_ids[option_index][0..];
                self.response_tags[index][0] = .{ .items = self.response_tag_items[index][0][0..] };
                self.response_tags[index][1] = .{ .items = self.response_tag_items[index][1][0..] };
                response.* = .{
                    .id = id,
                    .pubkey = pubkey,
                    .sig = [_]u8{0xbb} ** 64,
                    .kind = nip88.poll_response_kind,
                    .created_at = 20 + index,
                    .content = "",
                    .tags = self.response_tags[index][0..],
                };
            }
        }
    };
}

pub fn GroupContext(comptime user_count: usize) type {
    return struct {
        const Self = @This();

        metadata_items: [1][2][]const u8 = undefined,
        metadata_tags: [1]nip01_event.EventTag = undefined,
        admin_pubkeys: [user_count][limits.pubkey_hex_length]u8 = undefined,
        member_pubkeys: [user_count][limits.pubkey_hex_length]u8 = undefined,
        admin_items: [user_count + 1][3][]const u8 = undefined,
        member_items: [user_count + 1][2][]const u8 = undefined,
        admin_tags: [user_count + 1]nip01_event.EventTag = undefined,
        member_tags: [user_count + 1]nip01_event.EventTag = undefined,
        events: [3]nip01_event.Event = undefined,
        users: [user_count]nip29.GroupStateUser = undefined,
        roles: [0]nip29.GroupRole = .{},
        user_roles: [user_count * nip29.group_state_user_roles_max][]const u8 = undefined,
        state: nip29.GroupState = undefined,

        pub fn init(self: *Self) void {
            std.debug.assert(@intFromPtr(self) != 0);
            std.debug.assert(user_count > 0);

            self.init_metadata();
            self.init_admin_snapshot();
            self.init_member_snapshot();
            self.state = nip29.GroupState.init(
                self.users[0..],
                self.roles[0..],
                self.user_roles[0..],
            );
            self.events = .{
                test_group_event(nip29.group_metadata_kind, self.metadata_tags[0..]),
                test_group_event(nip29.group_admins_kind, self.admin_tags[0..]),
                test_group_event(nip29.group_members_kind, self.member_tags[0..]),
            };
        }

        fn init_metadata(self: *Self) void {
            std.debug.assert(@intFromPtr(self) != 0);
            std.debug.assert(self.metadata_tags.len == 1);

            self.metadata_items[0][0] = "d";
            self.metadata_items[0][1] = "pizza-lovers";
            self.metadata_tags[0] = .{ .items = self.metadata_items[0][0..] };
        }

        fn init_admin_snapshot(self: *Self) void {
            std.debug.assert(@intFromPtr(self) != 0);
            std.debug.assert(self.admin_tags.len == user_count + 1);

            self.admin_items[0][0] = "d";
            self.admin_items[0][1] = "pizza-lovers";
            self.admin_tags[0] = .{ .items = self.admin_items[0][0..2] };
            for (&self.admin_pubkeys, 0..) |*pubkey, index| {
                fill_hex_from_bytes(pubkey[0..], unique_32_bytes(index + 1));
                self.admin_items[index + 1][0] = "p";
                self.admin_items[index + 1][1] = pubkey[0..];
                self.admin_items[index + 1][2] = "moderator";
                self.admin_tags[index + 1] = .{ .items = self.admin_items[index + 1][0..3] };
            }
        }

        fn init_member_snapshot(self: *Self) void {
            std.debug.assert(@intFromPtr(self) != 0);
            std.debug.assert(self.member_tags.len == user_count + 1);

            self.member_items[0][0] = "d";
            self.member_items[0][1] = "pizza-lovers";
            self.member_tags[0] = .{ .items = self.member_items[0][0..2] };
            for (&self.member_pubkeys, 0..) |*pubkey, index| {
                fill_hex_from_bytes(pubkey[0..], unique_32_bytes(index + 1));
                self.member_items[index + 1][0] = "p";
                self.member_items[index + 1][1] = pubkey[0..];
                self.member_tags[index + 1] = .{ .items = self.member_items[index + 1][0..2] };
            }
        }
    };
}

fn fill_ascii_counter(output: []u8, prefix: []const u8, index: usize) []const u8 {
    std.debug.assert(output.len >= prefix.len + 4);
    std.debug.assert(prefix.len > 0);

    @memcpy(output[0..prefix.len], prefix);
    const suffix = std.fmt.bufPrint(output[prefix.len..], "{d}", .{index}) catch unreachable;
    return output[0 .. prefix.len + suffix.len];
}

fn unique_32_bytes(index: usize) [32]u8 {
    std.debug.assert(index <= std.math.maxInt(u32));
    std.debug.assert(@sizeOf(u32) == 4);

    var bytes = [_]u8{0} ** 32;
    std.mem.writeInt(u32, bytes[0..4], @intCast(index), .big);
    std.mem.writeInt(u32, bytes[4..8], @intCast(index * 17), .big);
    return bytes;
}

fn fill_hex_from_repeated_byte(output: []u8, byte: u8) void {
    std.debug.assert(output.len == limits.id_hex_length);
    std.debug.assert(output.len % 2 == 0);

    const bytes = [_]u8{byte} ** 32;
    fill_hex_from_bytes(output, bytes);
}

fn fill_hex_from_bytes(output: []u8, bytes: [32]u8) void {
    std.debug.assert(output.len == limits.id_hex_length);
    std.debug.assert(@sizeOf(@TypeOf(bytes)) == 32);

    const alphabet = "0123456789abcdef";
    for (bytes, 0..) |value, index| {
        output[index * 2] = alphabet[value >> 4];
        output[index * 2 + 1] = alphabet[value & 0x0f];
    }
}

fn test_group_event(kind: u32, tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(tags.len <= limits.tags_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = kind,
        .tags = tags,
        .content = "",
        .sig = [_]u8{0} ** 64,
    };
}

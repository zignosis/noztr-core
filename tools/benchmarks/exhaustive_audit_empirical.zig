const std = @import("std");
const builtin = @import("builtin");
const noztr = @import("noztr");

const limits = noztr.limits;
const nip01_event = noztr.nip01_event;
const nip06_mnemonic = noztr.nip06_mnemonic;
const nip29 = noztr.nip29_relay_groups;
const nip88 = noztr.nip88_polls;
const bip85 = noztr.bip85_derivation;

var benchmark_sink: u64 = 0;

pub fn main() !void {
    var stdout_buffer: [4096]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&stdout_buffer);

    try writer.interface.print("noztr empirical benchmark supplement\n", .{});
    try writer.interface.print("mode: {s}\n", .{@tagName(builtin.mode)});
    try writer.interface.print("zig: {s}\n\n", .{builtin.zig_version_string});

    try bench_nip88(&writer.interface);
    try bench_nip29(&writer.interface);
    try bench_nip06_and_bip85(&writer.interface);
    try writer.interface.print("\nbenchmark_sink: {d}\n", .{benchmark_sink});
    try writer.interface.flush();
}

fn bench_nip88(writer: *std.Io.Writer) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(!@inComptime());

    var case_256 = PollContext(32, 256){};
    var case_1024 = PollContext(32, 1024){};
    case_256.init();
    case_1024.init();

    try writer.print("NIP-88 poll_tally_reduce\n", .{});
    try measure_case(writer, "  32 options / 256 responses", 300, &case_256, run_poll_case);
    try measure_case(writer, "  32 options / 1024 responses", 80, &case_1024, run_poll_case);
    try writer.print("\n", .{});
}

fn bench_nip29(writer: *std.Io.Writer) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(!@inComptime());

    var case_256 = GroupContext(256){};
    var case_1024 = GroupContext(1024){};
    case_256.init();
    case_1024.init();

    try writer.print("NIP-29 group_state_apply_events\n", .{});
    try measure_case(writer, "  256 users snapshot replay", 200, &case_256, run_group_case);
    try measure_case(writer, "  1024 users snapshot replay", 40, &case_1024, run_group_case);
    try writer.print("\n", .{});
}

fn bench_nip06_and_bip85(writer: *std.Io.Writer) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(!@inComptime());

    var context = Nip06Context{};

    try writer.print("NIP-06 / BIP-85 derivation paths\n", .{});
    try measure_case(writer, "  mnemonic_validate", 4000, &context, run_mnemonic_validate_case);
    try measure_case(writer, "  mnemonic_to_seed", 2000, &context, run_mnemonic_seed_case);
    try measure_case(writer, "  derive_nostr_secret_key", 1500, &context, run_secret_key_case);
    try measure_case(writer, "  derive_bip39_mnemonic", 800, &context, run_bip85_case);
    try writer.print("\n", .{});
}

fn measure_case(
    writer: *std.Io.Writer,
    label: []const u8,
    iterations: u32,
    context: anytype,
    run_one: anytype,
) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(iterations > 0);

    var warmup: u8 = 0;
    while (warmup < 5) : (warmup += 1) try run_one(context);

    var timer = try std.time.Timer.start();
    var index: u32 = 0;
    while (index < iterations) : (index += 1) try run_one(context);

    const total_ns = timer.read();
    const ns_per_iter = @divTrunc(total_ns, iterations);
    try writer.print("{s}: {d} ns/op ({d} iterations)\n", .{ label, ns_per_iter, iterations });
}

fn run_poll_case(context: anytype) !void {
    std.debug.assert(@intFromPtr(context) != 0);
    std.debug.assert(context.responses.len > 0);

    const tally = try nip88.poll_tally_reduce(
        &context.poll_event,
        context.responses[0..],
        context.latest[0..],
        context.tallies[0..],
    );
    benchmark_sink +%= tally.counted_pubkey_count;
}

fn run_group_case(context: anytype) !void {
    std.debug.assert(@intFromPtr(context) != 0);
    std.debug.assert(context.events.len > 0);

    context.state.reset();
    try nip29.group_state_apply_events(&context.state, context.events[0..]);
    benchmark_sink +%= context.state.users.len;
}

fn run_mnemonic_validate_case(context: *Nip06Context) !void {
    std.debug.assert(@intFromPtr(context) != 0);
    std.debug.assert(context.mnemonic.len > 0);

    try nip06_mnemonic.mnemonic_validate(context.mnemonic);
    benchmark_sink +%= context.mnemonic.len;
}

fn run_mnemonic_seed_case(context: *Nip06Context) !void {
    std.debug.assert(@intFromPtr(context) != 0);
    std.debug.assert(context.seed_output.len == limits.nip06_seed_bytes);

    const seed = try nip06_mnemonic.mnemonic_to_seed(
        context.seed_output[0..],
        context.mnemonic,
        context.passphrase,
    );
    benchmark_sink +%= seed[0];
}

fn run_secret_key_case(context: *Nip06Context) !void {
    std.debug.assert(@intFromPtr(context) != 0);
    std.debug.assert(context.secret_output.len == limits.nip06_secret_key_bytes);

    const secret = try nip06_mnemonic.derive_nostr_secret_key(
        context.secret_output[0..],
        context.mnemonic,
        context.passphrase,
        0,
    );
    benchmark_sink +%= secret[0];
}

fn run_bip85_case(context: *Nip06Context) !void {
    std.debug.assert(@intFromPtr(context) != 0);
    std.debug.assert(context.child_mnemonic_output.len >= limits.bip85_mnemonic_bytes_max);

    const child = try bip85.derive_bip39_mnemonic(
        context.child_mnemonic_output[0..],
        context.mnemonic,
        context.passphrase,
        .words_12,
        0,
    );
    benchmark_sink +%= child.len;
}

const Nip06Context = struct {
    mnemonic: []const u8 =
        "install scatter logic circle pencil average fall shoe quantum disease suspect usage",
    passphrase: ?[]const u8 = null,
    seed_output: [limits.nip06_seed_bytes]u8 = undefined,
    secret_output: [limits.nip06_secret_key_bytes]u8 = undefined,
    child_mnemonic_output: [limits.bip85_mnemonic_bytes_max]u8 = undefined,
};

fn PollContext(comptime option_count: usize, comptime response_count: usize) type {
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

        fn init(self: *Self) void {
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

fn GroupContext(comptime user_count: usize) type {
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

        fn init(self: *Self) void {
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

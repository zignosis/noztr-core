const std = @import("std");
const builtin = @import("builtin");
const noztr = @import("noztr");
const support = @import("support.zig");

const limits = support.limits;
const nip06_mnemonic = support.nip06_mnemonic;
const nip29 = support.nip29;
const nip88 = support.nip88;
const bip85 = support.bip85;
const Nip06Context = support.Nip06Context;

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

    var context = support.Nip06Context{};

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

const PollContext = support.PollContext;
const GroupContext = support.GroupContext;

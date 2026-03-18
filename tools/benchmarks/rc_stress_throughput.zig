const std = @import("std");
const builtin = @import("builtin");
const support = @import("support.zig");

const nip06_mnemonic = support.nip06_mnemonic;
const nip29 = support.nip29;
const nip88 = support.nip88;

const poll_context_type = support.PollContext(32, 1024);
const group_context_type = support.GroupContext(1024);
const max_threads: usize = 8;
const wave_count: u32 = 5;

var benchmark_sink = std.atomic.Value(u64).init(0);

pub fn main() !void {
    var stdout_buffer: [4096]u8 = undefined;
    var writer = std.fs.File.stdout().writer(&stdout_buffer);
    const config = try parse_args();
    const cpu_count = std.Thread.getCpuCount() catch 0;

    try write_header(&writer.interface, config, cpu_count);
    try bench_poll(&writer.interface, config);
    try bench_group(&writer.interface, config);
    try bench_secret_key(&writer.interface, config);
    try write_footer(&writer.interface, config);
    try writer.interface.flush();
}

fn parse_args() !Config {
    var config = Config{};
    var args = std.process.args();

    _ = args.skip();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--mode=standard")) {
            config.mode = .standard;
        } else if (std.mem.eql(u8, arg, "--mode=soak")) {
            config.mode = .soak;
        } else if (std.mem.eql(u8, arg, "--format=text")) {
            config.format = .text;
        } else if (std.mem.eql(u8, arg, "--format=csv")) {
            config.format = .csv;
        } else if (std.mem.eql(u8, arg, "--format=markdown")) {
            config.format = .markdown;
        } else {
            return error.InvalidArguments;
        }
    }
    return config;
}

fn write_header(
    writer: *std.Io.Writer,
    config: Config,
    cpu_count: usize,
) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(cpu_count <= std.math.maxInt(u16));

    switch (config.format) {
        .text => try write_text_header(writer, config, cpu_count),
        .csv => try write_csv_header(writer, config, cpu_count),
        .markdown => try write_markdown_header(writer, config, cpu_count),
    }
}

fn write_text_header(
    writer: *std.Io.Writer,
    config: Config,
    cpu_count: usize,
) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(cpu_count <= std.math.maxInt(u16));

    try writer.print("noztr rc stress and throughput supplement\n", .{});
    try writer.print("mode: {s}\n", .{@tagName(builtin.mode)});
    try writer.print("zig: {s}\n", .{builtin.zig_version_string});
    try writer.print("profile: {s}\n", .{@tagName(config.mode)});
    try writer.print("cpu_count: {d}\n\n", .{cpu_count});
}

fn write_csv_header(
    writer: *std.Io.Writer,
    config: Config,
    cpu_count: usize,
) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(cpu_count <= std.math.maxInt(u16));

    try writer.print("# noztr rc stress and throughput supplement\n", .{});
    try writer.print("# mode: {s}\n", .{@tagName(builtin.mode)});
    try writer.print("# zig: {s}\n", .{builtin.zig_version_string});
    try writer.print("# profile: {s}\n", .{@tagName(config.mode)});
    try writer.print("# cpu_count: {d}\n", .{cpu_count});
    try writer.print(
        "workload,threads,iterations_per_thread,avg_ns_op,min_ns_op,max_ns_op,ops_per_s\n",
        .{},
    );
}

fn write_markdown_header(
    writer: *std.Io.Writer,
    config: Config,
    cpu_count: usize,
) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(cpu_count <= std.math.maxInt(u16));

    try writer.print("# RC Stress And Throughput Benchmark\n\n", .{});
    try writer.print("- mode: `{s}`\n", .{@tagName(builtin.mode)});
    try writer.print("- zig: `{s}`\n", .{builtin.zig_version_string});
    try writer.print("- profile: `{s}`\n", .{@tagName(config.mode)});
    try writer.print("- cpu_count: `{d}`\n\n", .{cpu_count});
    try writer.print(
        "| Workload | Threads | Iterations / thread | Avg ns/op | Min ns/op | Max ns/op | Ops/s |\n",
        .{},
    );
    try writer.print("| --- | ---: | ---: | ---: | ---: | ---: | ---: |\n", .{});
}

fn write_footer(writer: *std.Io.Writer, config: Config) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(benchmark_sink.load(.seq_cst) >= 0);

    const sink = benchmark_sink.load(.seq_cst);
    switch (config.format) {
        .text => try writer.print("\nbenchmark_sink: {d}\n", .{sink}),
        .csv => try writer.print("# benchmark_sink: {d}\n", .{sink}),
        .markdown => try writer.print("\n- benchmark_sink: `{d}`\n", .{sink}),
    }
}

fn bench_poll(writer: *std.Io.Writer, config: Config) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(!@inComptime());

    if (config.format == .text) try writer.print("NIP-88 poll_tally_reduce stress\n", .{});
    const profile = profile_for(.poll, config.mode);
    try measure_poll(writer, config.format, profile);
    if (config.format == .text) try writer.print("\n", .{});
}

fn bench_group(writer: *std.Io.Writer, config: Config) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(!@inComptime());

    if (config.format == .text) try writer.print("NIP-29 group_state_apply_events stress\n", .{});
    const profile = profile_for(.group, config.mode);
    try measure_group(writer, config.format, profile);
    if (config.format == .text) try writer.print("\n", .{});
}

fn bench_secret_key(writer: *std.Io.Writer, config: Config) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(!@inComptime());

    if (config.format == .text) try writer.print("NIP-06 derive_nostr_secret_key stress\n", .{});
    const profile = profile_for(.secret_key, config.mode);
    try measure_secret_key(writer, config.format, profile);
    if (config.format == .text) try writer.print("\n", .{});
}

fn measure_poll(
    writer: *std.Io.Writer,
    format: OutputFormat,
    profile: ThreadProfile,
) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(profile.thread_counts.len == profile.iterations.len);

    var contexts: [max_threads]poll_context_type = undefined;
    var index: usize = 0;

    while (index < profile.thread_counts.len) : (index += 1) {
        const thread_count = profile.thread_counts[index];
        const stats = try run_poll_series(thread_count, profile.iterations[index], contexts[0..]);
        try print_stats(
            writer,
            format,
            "NIP-88 poll_tally_reduce",
            thread_count,
            profile.iterations[index],
            stats,
        );
    }
}

fn measure_group(
    writer: *std.Io.Writer,
    format: OutputFormat,
    profile: ThreadProfile,
) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(profile.thread_counts.len == profile.iterations.len);

    var contexts: [max_threads]group_context_type = undefined;
    var index: usize = 0;

    while (index < profile.thread_counts.len) : (index += 1) {
        const thread_count = profile.thread_counts[index];
        const stats = try run_group_series(thread_count, profile.iterations[index], contexts[0..]);
        try print_stats(
            writer,
            format,
            "NIP-29 group_state_apply_events",
            thread_count,
            profile.iterations[index],
            stats,
        );
    }
}

fn measure_secret_key(
    writer: *std.Io.Writer,
    format: OutputFormat,
    profile: ThreadProfile,
) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(profile.thread_counts.len == profile.iterations.len);

    var contexts: [max_threads]support.Nip06Context = undefined;
    var index: usize = 0;

    while (index < profile.thread_counts.len) : (index += 1) {
        const thread_count = profile.thread_counts[index];
        const stats = try run_secret_key_series(
            thread_count,
            profile.iterations[index],
            contexts[0..],
        );
        try print_stats(
            writer,
            format,
            "NIP-06 derive_nostr_secret_key",
            thread_count,
            profile.iterations[index],
            stats,
        );
    }
}

fn print_stats(
    writer: *std.Io.Writer,
    format: OutputFormat,
    workload: []const u8,
    thread_count: u8,
    iterations: u32,
    stats: WaveStats,
) !void {
    std.debug.assert(@intFromPtr(writer) != 0);
    std.debug.assert(thread_count > 0);

    const ops_per_wave = @as(u64, thread_count) * iterations;
    const avg_total_ns = @divTrunc(stats.total_ns, wave_count);
    const avg_ns_per_op = @divTrunc(avg_total_ns, ops_per_wave);
    const min_ns_per_op = @divTrunc(stats.min_ns, ops_per_wave);
    const max_ns_per_op = @divTrunc(stats.max_ns, ops_per_wave);
    const ops_per_sec = @divTrunc(ops_per_wave * std.time.ns_per_s, avg_total_ns);

    switch (format) {
        .text => try writer.print(
            "  threads={d}, iterations/thread={d}: avg={d} ns/op, min={d}, max={d}, {d} ops/s\n",
            .{ thread_count, iterations, avg_ns_per_op, min_ns_per_op, max_ns_per_op, ops_per_sec },
        ),
        .csv => try writer.print(
            "{s},{d},{d},{d},{d},{d},{d}\n",
            .{ workload, thread_count, iterations, avg_ns_per_op, min_ns_per_op, max_ns_per_op, ops_per_sec },
        ),
        .markdown => try writer.print(
            "| `{s}` | `{d}` | `{d}` | `{d}` | `{d}` | `{d}` | `{d}` |\n",
            .{ workload, thread_count, iterations, avg_ns_per_op, min_ns_per_op, max_ns_per_op, ops_per_sec },
        ),
    }
}

fn run_poll_series(
    thread_count: u8,
    iterations: u32,
    contexts: []poll_context_type,
) !WaveStats {
    std.debug.assert(thread_count > 0);
    std.debug.assert(contexts.len >= thread_count);

    init_poll_contexts(contexts, thread_count);
    return run_poll_waves(thread_count, iterations, contexts);
}

fn run_group_series(
    thread_count: u8,
    iterations: u32,
    contexts: []group_context_type,
) !WaveStats {
    std.debug.assert(thread_count > 0);
    std.debug.assert(contexts.len >= thread_count);

    init_group_contexts(contexts, thread_count);
    return run_group_waves(thread_count, iterations, contexts);
}

fn run_secret_key_series(
    thread_count: u8,
    iterations: u32,
    contexts: []support.Nip06Context,
) !WaveStats {
    std.debug.assert(thread_count > 0);
    std.debug.assert(contexts.len >= thread_count);

    init_secret_key_contexts(contexts, thread_count);
    return run_secret_key_waves(thread_count, iterations, contexts);
}

fn init_poll_contexts(contexts: []poll_context_type, thread_count: u8) void {
    std.debug.assert(contexts.len >= thread_count);
    std.debug.assert(thread_count > 0);

    for (contexts[0..thread_count]) |*context| context.init();
}

fn init_group_contexts(contexts: []group_context_type, thread_count: u8) void {
    std.debug.assert(contexts.len >= thread_count);
    std.debug.assert(thread_count > 0);

    for (contexts[0..thread_count]) |*context| context.init();
}

fn init_secret_key_contexts(contexts: []support.Nip06Context, thread_count: u8) void {
    std.debug.assert(contexts.len >= thread_count);
    std.debug.assert(thread_count > 0);

    for (contexts[0..thread_count]) |*context| context.* = .{};
}

fn run_poll_waves(
    thread_count: u8,
    iterations: u32,
    contexts: []poll_context_type,
) !WaveStats {
    var stats = WaveStats.init();
    var wave: u32 = 0;

    while (wave < wave_count) : (wave += 1) {
        const elapsed_ns = try run_poll_wave(thread_count, iterations, contexts);
        stats.record(elapsed_ns);
    }
    return stats;
}

fn run_group_waves(
    thread_count: u8,
    iterations: u32,
    contexts: []group_context_type,
) !WaveStats {
    var stats = WaveStats.init();
    var wave: u32 = 0;

    while (wave < wave_count) : (wave += 1) {
        const elapsed_ns = try run_group_wave(thread_count, iterations, contexts);
        stats.record(elapsed_ns);
    }
    return stats;
}

fn run_secret_key_waves(
    thread_count: u8,
    iterations: u32,
    contexts: []support.Nip06Context,
) !WaveStats {
    var stats = WaveStats.init();
    var wave: u32 = 0;

    while (wave < wave_count) : (wave += 1) {
        const elapsed_ns = try run_secret_key_wave(thread_count, iterations, contexts);
        stats.record(elapsed_ns);
    }
    return stats;
}

fn run_poll_wave(thread_count: u8, iterations: u32, contexts: []poll_context_type) !u64 {
    var gate = ThreadGate{};
    var args: [max_threads]PollWorkerArgs = undefined;
    var threads: [max_threads]std.Thread = undefined;

    for (contexts[0..thread_count], 0..) |*context, index| {
        args[index] = .{ .gate = &gate, .context = context, .iterations = iterations };
        threads[index] = try std.Thread.spawn(.{}, poll_worker, .{&args[index]});
    }
    var timer = start_wave(thread_count, &gate);
    join_threads(threads[0..thread_count]);
    return timer.read();
}

fn run_group_wave(thread_count: u8, iterations: u32, contexts: []group_context_type) !u64 {
    var gate = ThreadGate{};
    var args: [max_threads]GroupWorkerArgs = undefined;
    var threads: [max_threads]std.Thread = undefined;

    for (contexts[0..thread_count], 0..) |*context, index| {
        args[index] = .{ .gate = &gate, .context = context, .iterations = iterations };
        threads[index] = try std.Thread.spawn(.{}, group_worker, .{&args[index]});
    }
    var timer = start_wave(thread_count, &gate);
    join_threads(threads[0..thread_count]);
    return timer.read();
}

fn run_secret_key_wave(
    thread_count: u8,
    iterations: u32,
    contexts: []support.Nip06Context,
) !u64 {
    var gate = ThreadGate{};
    var args: [max_threads]SecretKeyWorkerArgs = undefined;
    var threads: [max_threads]std.Thread = undefined;

    for (contexts[0..thread_count], 0..) |*context, index| {
        args[index] = .{ .gate = &gate, .context = context, .iterations = iterations };
        threads[index] = try std.Thread.spawn(.{}, secret_key_worker, .{&args[index]});
    }
    var timer = start_wave(thread_count, &gate);
    join_threads(threads[0..thread_count]);
    return timer.read();
}

fn start_wave(thread_count: u8, gate: *ThreadGate) std.time.Timer {
    std.debug.assert(thread_count > 0);
    std.debug.assert(@intFromPtr(gate) != 0);

    wait_until_ready(gate, thread_count);
    const timer = std.time.Timer.start() catch unreachable;
    gate.start.store(true, .seq_cst);
    return timer;
}

fn wait_until_ready(gate: *ThreadGate, thread_count: u8) void {
    std.debug.assert(thread_count > 0);
    std.debug.assert(@intFromPtr(gate) != 0);

    while (gate.ready.load(.seq_cst) < thread_count) {
        std.Thread.yield() catch unreachable;
    }
}

fn join_threads(threads: []std.Thread) void {
    std.debug.assert(threads.len > 0);
    std.debug.assert(threads.len <= max_threads);

    for (threads) |thread| thread.join();
}

fn poll_worker(args: *const PollWorkerArgs) void {
    var local_sink: u64 = 0;
    wait_for_start(args.gate);
    var index: u32 = 0;

    while (index < args.iterations) : (index += 1) {
        local_sink +%= run_poll_once(args.context) catch unreachable;
    }
    _ = benchmark_sink.fetchAdd(local_sink, .seq_cst);
}

fn group_worker(args: *const GroupWorkerArgs) void {
    var local_sink: u64 = 0;
    wait_for_start(args.gate);
    var index: u32 = 0;

    while (index < args.iterations) : (index += 1) {
        local_sink +%= run_group_once(args.context) catch unreachable;
    }
    _ = benchmark_sink.fetchAdd(local_sink, .seq_cst);
}

fn secret_key_worker(args: *const SecretKeyWorkerArgs) void {
    var local_sink: u64 = 0;
    wait_for_start(args.gate);
    var index: u32 = 0;

    while (index < args.iterations) : (index += 1) {
        local_sink +%= run_secret_key_once(args.context) catch unreachable;
    }
    _ = benchmark_sink.fetchAdd(local_sink, .seq_cst);
}

fn wait_for_start(gate: *ThreadGate) void {
    std.debug.assert(@intFromPtr(gate) != 0);
    std.debug.assert(!@inComptime());

    _ = gate.ready.fetchAdd(1, .seq_cst);
    while (!gate.start.load(.seq_cst)) {
        std.Thread.yield() catch unreachable;
    }
}

fn run_poll_once(context: *poll_context_type) !u64 {
    std.debug.assert(@intFromPtr(context) != 0);
    std.debug.assert(context.responses.len > 0);

    const tally = try nip88.poll_tally_reduce(
        &context.poll_event,
        context.responses[0..],
        context.latest[0..],
        context.tallies[0..],
    );
    return tally.counted_pubkey_count;
}

fn run_group_once(context: *group_context_type) !u64 {
    std.debug.assert(@intFromPtr(context) != 0);
    std.debug.assert(context.events.len > 0);

    context.state.reset();
    try nip29.group_state_apply_events(&context.state, context.events[0..]);
    return context.state.users.len;
}

fn run_secret_key_once(context: *support.Nip06Context) !u64 {
    std.debug.assert(@intFromPtr(context) != 0);
    std.debug.assert(context.secret_output.len == support.limits.nip06_secret_key_bytes);

    const secret = try nip06_mnemonic.derive_nostr_secret_key(
        context.secret_output[0..],
        context.mnemonic,
        context.passphrase,
        0,
    );
    return secret[0];
}

fn profile_for(workload: Workload, mode: RunMode) ThreadProfile {
    std.debug.assert(max_threads >= 8);
    std.debug.assert(wave_count > 0);

    return switch (mode) {
        .standard => switch (workload) {
            .poll => .{ .thread_counts = .{ 1, 4, 8 }, .iterations = .{ 120, 80, 60 } },
            .group => .{ .thread_counts = .{ 1, 4, 8 }, .iterations = .{ 120, 80, 60 } },
            .secret_key => .{ .thread_counts = .{ 1, 4, 8 }, .iterations = .{ 120, 40, 20 } },
        },
        .soak => switch (workload) {
            .poll => .{ .thread_counts = .{ 1, 4, 8 }, .iterations = .{ 2400, 1600, 1200 } },
            .group => .{ .thread_counts = .{ 1, 4, 8 }, .iterations = .{ 2400, 1600, 1200 } },
            .secret_key => .{ .thread_counts = .{ 1, 4, 8 }, .iterations = .{ 1200, 400, 200 } },
        },
    };
}

const Config = struct {
    mode: RunMode = .standard,
    format: OutputFormat = .text,
};

const OutputFormat = enum {
    text,
    csv,
    markdown,
};

const RunMode = enum {
    standard,
    soak,
};

const Workload = enum {
    poll,
    group,
    secret_key,
};

const ThreadProfile = struct {
    thread_counts: [3]u8,
    iterations: [3]u32,
};

const ThreadGate = struct {
    ready: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    start: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

const PollWorkerArgs = struct {
    gate: *ThreadGate,
    context: *poll_context_type,
    iterations: u32,
};

const GroupWorkerArgs = struct {
    gate: *ThreadGate,
    context: *group_context_type,
    iterations: u32,
};

const SecretKeyWorkerArgs = struct {
    gate: *ThreadGate,
    context: *support.Nip06Context,
    iterations: u32,
};

const WaveStats = struct {
    min_ns: u64,
    max_ns: u64,
    total_ns: u64,

    fn init() WaveStats {
        std.debug.assert(wave_count > 0);
        std.debug.assert(max_threads >= 8);

        return .{
            .min_ns = std.math.maxInt(u64),
            .max_ns = 0,
            .total_ns = 0,
        };
    }

    fn record(self: *WaveStats, elapsed_ns: u64) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(elapsed_ns > 0);

        self.min_ns = @min(self.min_ns, elapsed_ns);
        self.max_ns = @max(self.max_ns, elapsed_ns);
        self.total_ns +%= elapsed_ns;
    }
};

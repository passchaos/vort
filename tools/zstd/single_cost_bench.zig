const std = @import("std");
const zstd = @import("vort_zstd");
const provenance = @import("benchmark_provenance");

const Values = struct { prefix: usize, offset: usize, match: usize };
const Case = struct { name: []const u8, inputs: [64]Values };
const Round = struct { general_ns: u64, scalar_ns: u64, general_first: bool, mix: u64 };
const Sample = struct { ns: u64, mix: u64 };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |arg| try std.fmt.parseInt(usize, arg, 10) else 250_000;
    if (iterations == 0 or args.next() != null) return error.InvalidArguments;
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);
    var cases: [4]Case = undefined;
    for (&cases, 0..) |*case, shape| {
        case.name = switch (shape) {
            0 => "small_values",
            1 => "block64k_values",
            2 => "large_offsets",
            else => "invalid_lengths",
        };
        for (&case.inputs, 0..) |*input, index| input.* = switch (shape) {
            0 => .{ .prefix = index * 7 % 64, .offset = 1 + index * 5 % 128, .match = 3 + index * 11 % 128 },
            1 => .{ .prefix = index * 997 % 65536, .offset = 1 + index * 1013 % 65536, .match = 8 + index * 991 % 65528 },
            2 => .{ .prefix = index * 997 % 131072, .offset = (@as(usize, 1) << @intCast(24 + index % 8)) - 3, .match = 3 + index * 991 % 131072 },
            else => .{ .prefix = if (index % 2 == 0) 131072 else 0, .offset = if (index % 3 == 0) std.math.maxInt(usize) else 8, .match = if (index % 2 == 0) 3 else 2 },
        };
        for (&case.inputs) |*input| {
            const general = query(false, input);
            const scalar = query(true, input);
            if (general) |value| {
                if (try scalar != value) return error.CostMismatch;
            } else |expected| {
                if (scalar) |_| return error.CostMismatch else |actual| if (actual != expected) return error.CostMismatch;
            }
        }
    }
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.writeAll("{\"schema\":\"vort.zstd.single-sequence-cost-bench.v1\",\"provenance\":");
    try std.json.Stringify.value(info, .{}, &stdout.interface);
    try stdout.interface.print(",\"iterations\":{d},\"rows\":[", .{iterations});
    for (&cases, 0..) |*case, index| {
        if (index != 0) try stdout.interface.writeByte(',');
        var rounds: [5]Round = undefined;
        var general_times: [5]u64 = undefined;
        var scalar_times: [5]u64 = undefined;
        _ = try measure(false, init.io, case, 1000);
        _ = try measure(true, init.io, case, 1000);
        for (&rounds, 0..) |*round, r| {
            const a = if (r % 2 == 0) try measure(false, init.io, case, iterations) else try measure(true, init.io, case, iterations);
            const b = if (r % 2 == 0) try measure(true, init.io, case, iterations) else try measure(false, init.io, case, iterations);
            if (a.mix != b.mix) return error.CostMismatch;
            round.* = .{ .general_ns = if (r % 2 == 0) a.ns else b.ns, .scalar_ns = if (r % 2 == 0) b.ns else a.ns, .general_first = r % 2 == 0, .mix = a.mix };
            general_times[r] = round.general_ns;
            scalar_times[r] = round.scalar_ns;
        }
        std.mem.sort(u64, &general_times, {}, std.sort.asc(u64));
        std.mem.sort(u64, &scalar_times, {}, std.sort.asc(u64));
        try stdout.interface.print("{{\"case\":\"{s}\",\"general_median_ns\":{d},\"scalar_median_ns\":{d},\"general_min_ns\":{d},\"scalar_min_ns\":{d},\"rounds\":", .{ case.name, general_times[2], scalar_times[2], general_times[0], scalar_times[0] });
        try std.json.Stringify.value(rounds, .{}, &stdout.interface);
        try stdout.interface.writeByte('}');
    }
    try stdout.interface.writeAll("]}\n");
    try stdout.interface.flush();
}

noinline fn query(comptime scalar: bool, values: *const Values) zstd.Error!usize {
    return zstd.benchmarkSingleSequenceBaseLen(scalar, values.prefix, values.offset, values.match);
}

fn measure(comptime scalar: bool, io: std.Io, case: *const Case, iterations: usize) !Sample {
    var mix: u64 = 0;
    var state: u32 = 0x6a09_e667;
    const before = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        state = state *% 1_664_525 +% 1_013_904_223;
        if (query(scalar, &case.inputs[(state >> 16) & 63])) |value| mix +%= value else |err| mix +%= @intFromError(err);
    }
    const elapsed = before.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    std.mem.doNotOptimizeAway(mix);
    return .{ .ns = @intCast(elapsed), .mix = mix };
}

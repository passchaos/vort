//! Compare complete merge/count calls. All generated inputs and field equality
//! checks are prepared before each measured pass; output is caller-owned.
const std = @import("std");
const merge = @import("frequency_merge");
const provenance = @import("benchmark_provenance");
const Rows = [4][256]u32;
const Case = struct { name: []const u8, inputs: [64]Rows };
const Round = struct { scalar_ns: u64, merged_ns: u64, scalar_first: bool, mix: u64 };
const Sample = struct { ns: u64, mix: u64 };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |arg| try std.fmt.parseInt(usize, arg, 10) else 250_000;
    if (iterations == 0 or args.next() != null) return error.InvalidArguments;
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);
    const cases = try init.gpa.alloc(Case, 3);
    defer init.gpa.free(cases);
    for (cases, 0..) |*case, shape| {
        case.name = switch (shape) {
            0 => "medium_four_streams",
            1 => "dense_four_streams",
            else => "single_stream",
        };
        for (&case.inputs, 0..) |*input, step| {
            input.* = @splat(@splat(0));
            const active: usize = if (shape == 1) 256 else 77;
            const stream_count: usize = if (shape == 2) 1 else 4;
            for (input[0..stream_count], 0..) |*row, stream| {
                for (0..active) |index| row[(index * 149 + 41) % 256] = @intCast(1 + (index * 17 + step * 3 + stream * 11) % 63);
            }
        }
        var scalar: [256]u32 = undefined;
        var merged: [256]u32 = undefined;
        for (&case.inputs) |*input| {
            const a = query(true, input, &scalar);
            const b = query(false, input, &merged);
            if (a != b or !std.mem.eql(u32, &scalar, &merged)) return error.FrequencyMismatch;
        }
    }
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.writeAll("{\"schema\":\"vort.zstd.frequency-merge-bench.v1\",\"provenance\":");
    try std.json.Stringify.value(info, .{}, &stdout.interface);
    try stdout.interface.print(",\"iterations\":{d},\"rows\":[", .{iterations});
    for (cases, 0..) |*case, index| {
        if (index != 0) try stdout.interface.writeByte(',');
        var rounds: [5]Round = undefined;
        var scalar_times: [5]u64 = undefined;
        var merged_times: [5]u64 = undefined;
        _ = measure(true, init.io, case, 1000);
        _ = measure(false, init.io, case, 1000);
        for (&rounds, 0..) |*round, r| {
            const a = if (r % 2 == 0) measure(true, init.io, case, iterations) else measure(false, init.io, case, iterations);
            const b = if (r % 2 == 0) measure(false, init.io, case, iterations) else measure(true, init.io, case, iterations);
            if (a.mix != b.mix) return error.FrequencyMismatch;
            round.* = .{ .scalar_ns = if (r % 2 == 0) a.ns else b.ns, .merged_ns = if (r % 2 == 0) b.ns else a.ns, .scalar_first = r % 2 == 0, .mix = a.mix };
            scalar_times[r] = round.scalar_ns;
            merged_times[r] = round.merged_ns;
        }
        std.mem.sort(u64, &scalar_times, {}, std.sort.asc(u64));
        std.mem.sort(u64, &merged_times, {}, std.sort.asc(u64));
        try stdout.interface.print("{{\"case\":\"{s}\",\"scalar_median_ns\":{d},\"merged_median_ns\":{d},\"scalar_min_ns\":{d},\"merged_min_ns\":{d},\"rounds\":", .{ case.name, scalar_times[2], merged_times[2], scalar_times[0], merged_times[0] });
        try std.json.Stringify.value(rounds, .{}, &stdout.interface);
        try stdout.interface.writeByte('}');
    }
    try stdout.interface.writeAll("]}\n");
    try stdout.interface.flush();
}

noinline fn query(comptime scalar: bool, rows: *const Rows, out: *[256]u32) usize {
    return if (scalar) merge.scalarReference(rows, out) else merge.mergeActive(rows, out);
}

fn measure(comptime scalar: bool, io: std.Io, case: *const Case, iterations: usize) Sample {
    var output: [256]u32 = undefined;
    var mix: u64 = 0;
    var state: u32 = 0x6a09_e667;
    const before = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        state = state *% 1_664_525 +% 1_013_904_223;
        const active = query(scalar, &case.inputs[(state >> 16) & 63], &output);
        mix +%= active +% @as(u64, output[(state >> 8) & 255]);
    }
    std.mem.doNotOptimizeAway(&output);
    std.mem.doNotOptimizeAway(mix);
    const elapsed = before.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    return .{ .ns = @intCast(elapsed), .mix = mix };
}

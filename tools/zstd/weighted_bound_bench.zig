//! Same-process certificate analysis comparison. Input generation, initial
//! field/error equality checks and JSON output run outside each measured pass.
const std = @import("std");
const bound = @import("weighted_bound");
const provenance = @import("benchmark_provenance");
const Certificate = bound.Certificate(256, 11);

const Case = struct {
    name: []const u8,
    certificate: Certificate,
    inputs: [64][256]u32,
};
const Round = struct { scalar_ns: u64, vector_ns: u64, scalar_first: bool, mix: u64 };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 250_000;
    if (iterations == 0 or args.next() != null) return error.InvalidArguments;
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);
    const cases = try init.gpa.alloc(Case, 3);
    defer init.gpa.free(cases);
    for (cases, 0..) |*case, shape| {
        var frequencies: [256]u32 = @splat(0);
        const active: usize = if (shape == 0) 77 else 256;
        for (0..active) |index| frequencies[(index * 149 + 41) % 256] = @intCast(8 + index % 23);
        var total: u64 = 0;
        for (frequencies) |value| total += value;
        case.certificate = try Certificate.init(&frequencies, total);
        case.name = switch (shape) {
            0 => "medium_support",
            1 => "dense_support",
            else => "invalid_totals",
        };
        for (&case.inputs, 0..) |*input, index| {
            input.* = frequencies;
            if (shape == 2) {
                if (index % 3 == 0) input[0] = std.math.maxInt(u32) else if (index % 3 == 1) input.* = @splat(1 << 24) else input[0] = 131_072;
            } else {
                const symbol = (index * 149 + 41) % 256;
                input[symbol] +|= @intCast(1 + index % 7);
                if (index % 4 == 0) input[(index * 29 + 7) % 256] = 0;
            }
        }
        for (&case.inputs) |*input| {
            const scalar = query(true, &case.certificate, input);
            const vector = query(false, &case.certificate, input);
            if (scalar) |expected| {
                const actual = try vector;
                if (expected.same_support != actual.same_support or expected.current_total != actual.current_total or
                    expected.current_active_symbols != actual.current_active_symbols or expected.negative_delta != actual.negative_delta or
                    expected.bit_lower_bound != actual.bit_lower_bound) return error.AnalysisMismatch;
            } else |expected| {
                if (vector) |_| return error.AnalysisMismatch else |actual| if (actual != expected) return error.AnalysisMismatch;
            }
        }
    }
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.writeAll("{\"schema\":\"vort.zstd.weighted-bound-bench.v1\",\"provenance\":");
    try std.json.Stringify.value(info, .{}, &stdout.interface);
    try stdout.interface.print(",\"iterations\":{d},\"rows\":[", .{iterations});
    for (cases, 0..) |*case, index| {
        if (index != 0) try stdout.interface.writeByte(',');
        var rounds: [5]Round = undefined;
        var scalar_times: [5]u64 = undefined;
        var vector_times: [5]u64 = undefined;
        _ = try measure(true, init.io, case, 1000);
        _ = try measure(false, init.io, case, 1000);
        for (&rounds, 0..) |*round, r| {
            const a = if (r % 2 == 0) try measure(true, init.io, case, iterations) else try measure(false, init.io, case, iterations);
            const b = if (r % 2 == 0) try measure(false, init.io, case, iterations) else try measure(true, init.io, case, iterations);
            if (a.mix != b.mix) return error.AnalysisMismatch;
            round.* = .{ .scalar_ns = if (r % 2 == 0) a.ns else b.ns, .vector_ns = if (r % 2 == 0) b.ns else a.ns, .scalar_first = r % 2 == 0, .mix = a.mix };
            scalar_times[r] = round.scalar_ns;
            vector_times[r] = round.vector_ns;
        }
        std.mem.sort(u64, &scalar_times, {}, std.sort.asc(u64));
        std.mem.sort(u64, &vector_times, {}, std.sort.asc(u64));
        try stdout.interface.print("{{\"case\":\"{s}\",\"scalar_median_ns\":{d},\"vector_median_ns\":{d},\"scalar_min_ns\":{d},\"vector_min_ns\":{d},\"rounds\":", .{ case.name, scalar_times[2], vector_times[2], scalar_times[0], vector_times[0] });
        try std.json.Stringify.value(rounds, .{}, &stdout.interface);
        try stdout.interface.writeByte('}');
    }
    try stdout.interface.writeAll("]}\n");
    try stdout.interface.flush();
}

noinline fn query(comptime scalar: bool, certificate: *const Certificate, input: *const [256]u32) bound.Error!bound.Analysis {
    return if (scalar) certificate.analyzeReference(input) else certificate.analyze(input);
}

const Sample = struct { ns: u64, mix: u64 };
fn measure(comptime scalar: bool, io: std.Io, case: *const Case, iterations: usize) !Sample {
    var mix: u64 = 0;
    var state: u32 = 0x6a09_e667;
    const before = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        state = state *% 1_664_525 +% 1_013_904_223;
        const input = &case.inputs[(state >> 16) & 63];
        if (query(scalar, &case.certificate, input)) |result| {
            mix +%= result.current_total +% @as(u64, result.negative_delta) +% (result.bit_lower_bound orelse 0) +% result.current_active_symbols +% @intFromBool(result.same_support);
        } else |err| mix +%= @intFromError(err);
    }
    const elapsed = before.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    std.mem.doNotOptimizeAway(mix);
    return .{ .ns = @intCast(elapsed), .mix = mix };
}

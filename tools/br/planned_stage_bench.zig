const std = @import("std");
const vort = @import("vort");

const json_payload = "{\"kind\":\"event\",\"active\":true,\"values\":[1,2,3,5,8,13]}\n" ** 48;
const source_payload = "pub fn update(state: *State, value: u32) void { state.total += value; state.count += 1; }\n" ** 40;
const log_payload = "2026-08-21T02:00:00Z level=info service=vort request=compress status=ok bytes=4096\n" ** 40;
const Case = struct { name: []const u8, payload: []const u8 };
const Sample = struct { ns: u64, mix: usize };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var iterations: usize = 100;
    if (args.next()) |arg| iterations = try std.fmt.parseInt(usize, arg, 10);
    if (iterations == 0 or args.next() != null) return error.InvalidBlockPlan;
    const cases = [_]Case{ .{ .name = "json", .payload = json_payload }, .{ .name = "source", .payload = source_payload }, .{ .name = "log", .payload = log_payload } };
    var buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (cases) |case| {
        const parser = try measureParser(init.io, init.gpa, case.payload, iterations);
        const full = try measureFull(init.io, init.gpa, case.payload, iterations);
        try stdout.interface.print("{s}: iterations={d} parser_ns={d} full_ns={d} parser_share={d:.4} checksum={d}\n", .{ case.name, iterations, parser.ns, full.ns, @as(f64, @floatFromInt(parser.ns)) / @as(f64, @floatFromInt(full.ns)), parser.mix +% full.mix });
    }
    try stdout.interface.flush();
}

fn measureParser(io: std.Io, allocator: std.mem.Allocator, input: []const u8, iterations: usize) !Sample {
    var best = Sample{ .ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const plan = try vort.lz77.hashGreedyPlanAutoTinyAlloc(allocator, input, .{ .window_len = input.len, .max_chain = 64, .nice_len = 64, .max_candidates = 8, .min_match = 3, .max_match = vort.lz77.max_match_len });
            mix +%= plan.tokens.len + plan.stats.matched_bytes;
            plan.deinit(allocator);
        }
        const sample = Sample{ .ns = elapsed(start, io), .mix = mix };
        if (sample.ns < best.ns) best = sample;
    }
    return best;
}

fn measureFull(io: std.Io, allocator: std.mem.Allocator, input: []const u8, iterations: usize) !Sample {
    var best = Sample{ .ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const encoded = try vort.brEncodePlannedStreamAlloc(allocator, input);
            mix +%= encoded.len;
            allocator.free(encoded);
        }
        const sample = Sample{ .ns = elapsed(start, io), .mix = mix };
        if (sample.ns < best.ns) best = sample;
    }
    return best;
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

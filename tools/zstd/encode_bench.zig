const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");

const Case = struct { name: []const u8, payload: []const u8 };
const Options = struct { iterations: usize = 1, rounds: usize = 3, csv_path: ?[]const u8 = null };
const Sample = struct { ns: u64, mix: usize };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    var runtime = try libzstd.Runtime.open();
    defer runtime.deinit();

    var numbered_json: std.ArrayList(u8) = .empty;
    defer numbered_json.deinit(init.gpa);
    while (numbered_json.items.len < 32 * 1024) {
        var line: [128]u8 = undefined;
        const index = numbered_json.items.len / 64;
        const formatted = try std.fmt.bufPrint(&line, "{{\"id\":{d},\"service\":\"vort\",\"message\":\"structured zstd encode corpus\"}}\n", .{index});
        try numbered_json.appendSlice(init.gpa, formatted);
    }
    const binary = try init.gpa.alloc(u8, 32 * 1024);
    defer init.gpa.free(binary);
    var state: u32 = 0xfeed_beef;
    for (binary, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(state >> 16);
    }
    const cases = [_]Case{
        .{ .name = "text", .payload = "Zstandard encode benchmark text with repeated structure and punctuation.\n" ** 512 },
        .{ .name = "json", .payload = numbered_json.items },
        .{ .name = "binary", .payload = binary },
    };
    const levels = [_]c_int{ 1, 3, 9 };

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,reference_version,level,input_bytes,vort_bytes,reference_bytes,size_over_reference,iterations,rounds,vort_ns,reference_ns,vort_mib_s,reference_mib_s,vort_over_reference,checksum\n");
    for (cases) |case| for (levels) |level| {
        const vort_encoded = try vort.zstdEncodeFrameWithLevelAlloc(init.gpa, case.payload, level);
        defer init.gpa.free(vort_encoded);
        const reference_encoded = try runtime.encodeAlloc(init.gpa, case.payload, level);
        defer init.gpa.free(reference_encoded);
        try verifyBothDecoders(init.gpa, runtime, case.payload, vort_encoded, reference_encoded);
        const samples = try measureInterleaved(init.io, init.gpa, runtime, case.payload, level, options.iterations, options.rounds);
        const total_bytes = case.payload.len * options.iterations;
        const vort_rate = mibPerSecond(total_bytes, samples.vort.ns);
        const reference_rate = mibPerSecond(total_bytes, samples.reference.ns);
        try csv.writer.print("{s},{s},{d},{d},{d},{d},{d:.4},{d},{d},{d},{d},{d:.6},{d:.6},{d:.8},{d}\n", .{
            case.name,                                                                                  runtime.version(),          level,                                     case.payload.len, vort_encoded.len,     reference_encoded.len,
            @as(f64, @floatFromInt(vort_encoded.len)) / @as(f64, @floatFromInt(reference_encoded.len)), options.iterations,         options.rounds,                            samples.vort.ns,  samples.reference.ns, vort_rate,
            reference_rate,                                                                             vort_rate / reference_rate, samples.vort.mix +% samples.reference.mix,
        });
    };
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn verifyBothDecoders(allocator: std.mem.Allocator, runtime: libzstd.Runtime, payload: []const u8, vort_encoded: []const u8, reference_encoded: []const u8) !void {
    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    try runtime.decode(vort_encoded, output);
    if (!std.mem.eql(u8, payload, output)) return error.SizeMismatch;
    const written = try vort.zstdDecodeFrameInto(reference_encoded, output);
    if (written != payload.len or !std.mem.eql(u8, payload, output)) return error.SizeMismatch;
}

fn measureInterleaved(io: std.Io, allocator: std.mem.Allocator, runtime: libzstd.Runtime, payload: []const u8, level: c_int, iterations: usize, rounds: usize) !struct { vort: Sample, reference: Sample } {
    var best_vort = Sample{ .ns = std.math.maxInt(u64), .mix = 0 };
    var best_reference = best_vort;
    for (0..rounds) |round| {
        const vort_first = round & 1 == 0;
        const first = if (vort_first) try measureVort(io, allocator, payload, level, iterations) else try measureReference(io, allocator, runtime, payload, level, iterations);
        const second = if (vort_first) try measureReference(io, allocator, runtime, payload, level, iterations) else try measureVort(io, allocator, payload, level, iterations);
        const vort_sample = if (vort_first) first else second;
        const reference_sample = if (vort_first) second else first;
        if (vort_sample.ns < best_vort.ns) best_vort = vort_sample;
        if (reference_sample.ns < best_reference.ns) best_reference = reference_sample;
    }
    return .{ .vort = best_vort, .reference = best_reference };
}

fn measureVort(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, level: c_int, iterations: usize) !Sample {
    var mix: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try vort.zstdEncodeFrameWithLevelAlloc(allocator, payload, level);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn measureReference(io: std.Io, allocator: std.mem.Allocator, runtime: libzstd.Runtime, payload: []const u8, level: c_int, iterations: usize) !Sample {
    var mix: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try runtime.encodeAlloc(allocator, payload, level);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) / (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--rounds")) options.rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--csv")) options.csv_path = args.next() orelse return error.MissingCorpusPath else return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.rounds == 0) return error.InvalidBlockPlan;
    return options;
}

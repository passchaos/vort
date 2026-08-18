const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");

const Case = struct { name: []const u8, payload: []const u8 };
const Sample = struct { elapsed_ns: u64, mix: u64 };
const Options = struct { iterations: usize = 1000, csv_path: ?[]const u8 = null };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    var runtime = try libbrotli.Runtime.open();
    defer runtime.deinit();
    var random: [4096]u8 = undefined;
    var state: u32 = 0x1234_5678;
    for (&random) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 16);
    }
    const cases = [_]Case{
        .{ .name = "tiny", .payload = "hello brotli" },
        .{ .name = "text", .payload = "Brotli benchmark text payload. " ** 1024 },
        .{ .name = "structured", .payload = "{\"service\":\"vort\",\"codec\":\"brotli\",\"value\":12345}\n" ** 512 },
        .{ .name = "repetitive", .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 256 },
        .{ .name = "random4k", .payload = &random },
    };

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    const writer = &csv.writer;
    try writer.writeAll("case,reference_version,input_bytes,encoded_bytes,iterations,vort_ns,reference_ns,vort_mib_s,reference_mib_s,vort_over_reference,checksum,size_ns\n");
    for (&cases) |case| {
        const encoded = try runtime.encodeAlloc(init.gpa, case.payload, 0);
        defer init.gpa.free(encoded);
        const vort_output = try init.gpa.alloc(u8, case.payload.len);
        defer init.gpa.free(vort_output);
        const reference_output = try init.gpa.alloc(u8, case.payload.len);
        defer init.gpa.free(reference_output);
        const written = try vort.brDecodeStreamInto(encoded, vort_output);
        if (written != case.payload.len or !std.mem.eql(u8, case.payload, vort_output)) return error.SizeMismatch;
        try runtime.decode(encoded, reference_output);
        if (!std.mem.eql(u8, case.payload, reference_output)) return error.SizeMismatch;
        const vort_sample = try measure(init.io, .vort, runtime, encoded, vort_output, options.iterations);
        const reference_sample = try measure(init.io, .reference, runtime, encoded, reference_output, options.iterations);
        const size_sample = try measureSize(init.io, encoded, options.iterations);
        const vort_mib_s = mibPerSecond(case.payload.len * options.iterations, vort_sample.elapsed_ns);
        const reference_mib_s = mibPerSecond(case.payload.len * options.iterations, reference_sample.elapsed_ns);
        try writer.print(
            "{s},{x},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.4},{d},{d}\n",
            .{ case.name, runtime.version(), case.payload.len, encoded.len, options.iterations, vort_sample.elapsed_ns, reference_sample.elapsed_ns, vort_mib_s, reference_mib_s, vort_mib_s / reference_mib_s, vort_sample.mix +% reference_sample.mix, size_sample.elapsed_ns },
        );
    }
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var stdout_buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path = args.next() orelse return error.MissingCorpusPath;
        } else return error.UnknownArgument;
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    return options;
}

fn measureSize(io: std.Io, encoded: []const u8, iterations: usize) !Sample {
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| mix +%= try vort.brDecodedStreamSize(encoded);
        const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
        const elapsed: u64 = if (ns <= 0) 0 else @intCast(ns);
        if (elapsed < best.elapsed_ns) best = .{ .elapsed_ns = elapsed, .mix = mix };
    }
    return best;
}

const Codec = enum { vort, reference };

fn measure(io: std.Io, codec: Codec, runtime: libbrotli.Runtime, encoded: []const u8, output: []u8, iterations: usize) !Sample {
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            switch (codec) {
                .vort => mix +%= try vort.brDecodeStreamInto(encoded, output),
                .reference => {
                    try runtime.decode(encoded, output);
                    mix +%= output.len;
                },
            }
            if (output.len != 0) mix +%= output[0];
        }
        const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
        const elapsed: u64 = if (ns <= 0) 0 else @intCast(ns);
        if (elapsed < best.elapsed_ns) best = .{ .elapsed_ns = elapsed, .mix = mix };
    }
    return best;
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) /
        (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}

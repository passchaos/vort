const std = @import("std");
const vort = @import("vort");

const Case = struct {
    name: []const u8,
    payload: []const u8,
};

const builtins = [_]Case{
    .{ .name = "tiny", .payload = "hello rust deflate baselines" },
    .{ .name = "repetitive", .payload = "abcabcabcabc" ** 512 },
    .{ .name = "text", .payload = "the quick brown fox jumps over the lazy dog\n" ** 1024 },
    .{ .name = "structured", .payload = "{\"service\":\"vort\",\"level\":\"default\",\"message\":\"decode stage\"}\n" ** 512 },
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var file_cases: std.ArrayList(Case) = .empty;
    defer {
        for (file_cases.items) |case| init.gpa.free(case.payload);
        file_cases.deinit(init.gpa);
    }
    while (args.next()) |path| {
        const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        errdefer init.gpa.free(payload);
        try file_cases.append(init.gpa, .{ .name = path, .payload = payload });
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll("case,input_bytes,zlib_bytes,raw_bytes,iterations,raw_mib_s,zlib_mib_s,wrapper_time_ratio,mix\n");

    const cases = if (file_cases.items.len == 0) builtins[0..] else file_cases.items;
    for (cases) |case| try reportCase(init, stdout, case);
    try stdout.flush();
}

fn reportCase(init: std.process.Init, stdout: *std.Io.Writer, case: Case) !void {
    const options = vort.optionsForCompressionLevel(.default);
    const zlib_frame = try vort.encodeZlibBestAlloc(init.gpa, case.payload, options);
    defer init.gpa.free(zlib_frame);

    const raw = rawSliceFromZlib(zlib_frame);
    const iterations = iterationsFor(case.payload.len);

    var mix: u64 = 0;
    const raw_warmup = try vort.decodeRawDeflateAlloc(init.gpa, raw);
    init.gpa.free(raw_warmup);
    const raw_start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeRawDeflateAlloc(init.gpa, raw);
        defer init.gpa.free(decoded);
        if (decoded.len != case.payload.len) return error.DecodeLengthMismatch;
        mix +%= decoded.len;
        if (decoded.len != 0) mix +%= decoded[0];
    }
    const raw_ns = raw_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    const zlib_warmup = try vort.decodeZlibAlloc(init.gpa, zlib_frame);
    init.gpa.free(zlib_warmup);
    const zlib_start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeZlibAlloc(init.gpa, zlib_frame);
        defer init.gpa.free(decoded);
        if (decoded.len != case.payload.len) return error.DecodeLengthMismatch;
        mix +%= decoded.len;
        if (decoded.len != 0) mix +%= decoded[0];
    }
    const zlib_ns = zlib_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    try stdout.print("{s},{d},{d},{d},{d},{d:.2},{d:.2},{d:.4},{d}\n", .{
        case.name,
        case.payload.len,
        zlib_frame.len,
        raw.len,
        iterations,
        throughput(case.payload.len, iterations, raw_ns),
        throughput(case.payload.len, iterations, zlib_ns),
        ratioSigned(zlib_ns, raw_ns),
        mix,
    });
}

fn rawSliceFromZlib(frame: []const u8) []const u8 {
    std.debug.assert(frame.len >= 6);
    return frame[2 .. frame.len - 4];
}

fn iterationsFor(size: usize) usize {
    const target = 32 * 1024 * 1024;
    return @max(64, @min(10_000, target / @max(size, 1)));
}

fn throughput(size: usize, iterations: usize, elapsed_ns: i128) f64 {
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, std.time.ns_per_s);
    if (seconds == 0) return 0;
    const mib = (@as(f64, @floatFromInt(size)) * @as(f64, @floatFromInt(iterations))) / (1024.0 * 1024.0);
    return mib / seconds;
}

fn ratioSigned(numerator: i128, denominator: i128) f64 {
    if (denominator == 0) return 0;
    return @as(f64, @floatFromInt(numerator)) / @as(f64, @floatFromInt(denominator));
}

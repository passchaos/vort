const std = @import("std");
const vort = @import("vort");

const Case = struct {
    name: []const u8,
    data: []const u8,
};

pub fn main(init: std.process.Init) !void {
    const readme = try std.Io.Dir.cwd().readFileAlloc(init.io, "README.md", init.gpa, .limited(1 << 20));
    defer init.gpa.free(readme);
    const roadmap = try std.Io.Dir.cwd().readFileAlloc(init.io, "docs/roadmap.md", init.gpa, .limited(1 << 20));
    defer init.gpa.free(roadmap);

    const cases = [_]Case{
        .{ .name = "readme-text", .data = readme },
        .{ .name = "roadmap-text", .data = roadmap },
        .{ .name = "structured-jsonish", .data = "{\"name\":\"vort\",\"goal\":\"next-gen compression\",\"level\":1,\"ok\":true}\n" ** 4096 },
        .{ .name = "repetitive", .data = "abcdefghijklmnopqrstuvwxyz0123456789" ** 4096 },
        .{ .name = "deterministic-binary", .data = &deterministic_binary },
    };

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("case,input_bytes,raw_bytes,zlib_bytes,gzip_bytes,iterations,raw_decode_mib_s,zlib_decode_mib_s,gzip_decode_mib_s,mix\n", .{});

    for (cases) |case| {
        const iterations: usize = iterationsFor(case.data.len);
        const raw = try vort.encodeRawBestAlloc(init.gpa, case.data, vort.optionsForCompressionLevel(.fastest));
        defer init.gpa.free(raw);
        const zlib_frame = try vort.encodeZlibBestAlloc(init.gpa, case.data, vort.optionsForCompressionLevel(.fastest));
        defer init.gpa.free(zlib_frame);
        const gzip_frame = try vort.encodeGzipBestAlloc(init.gpa, case.data, vort.optionsForCompressionLevel(.fastest));
        defer init.gpa.free(gzip_frame);

        const raw_result = try timeRaw(init, raw, case.data, iterations);
        const zlib_result = try timeZlib(init, zlib_frame, case.data, iterations);
        const gzip_result = try timeGzip(init, gzip_frame, case.data, iterations);
        try stdout.print("{s},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.2},{d}\n", .{
            case.name,
            case.data.len,
            raw.len,
            zlib_frame.len,
            gzip_frame.len,
            iterations,
            throughput(case.data.len, iterations, raw_result.elapsed_ns),
            throughput(case.data.len, iterations, zlib_result.elapsed_ns),
            throughput(case.data.len, iterations, gzip_result.elapsed_ns),
            raw_result.mix ^ zlib_result.mix ^ gzip_result.mix,
        });
    }
    try stdout.flush();
}

const Timing = struct {
    elapsed_ns: i128,
    mix: u64,
};

fn timeRaw(init: std.process.Init, frame: []const u8, expected: []const u8, iterations: usize) !Timing {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeRawDeflateAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, expected, decoded)) return error.RoundTripMismatch;
        mix +%= vort.crc32(decoded);
    }
    return .{ .elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), .mix = mix };
}

fn timeZlib(init: std.process.Init, frame: []const u8, expected: []const u8, iterations: usize) !Timing {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeZlibAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, expected, decoded)) return error.RoundTripMismatch;
        mix +%= vort.crc32(decoded);
    }
    return .{ .elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), .mix = mix };
}

fn timeGzip(init: std.process.Init, frame: []const u8, expected: []const u8, iterations: usize) !Timing {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeGzipAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, expected, decoded)) return error.RoundTripMismatch;
        mix +%= vort.crc32(decoded);
    }
    return .{ .elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), .mix = mix };
}

fn throughput(input_len: usize, iterations: usize, elapsed_ns: i128) f64 {
    const mib = (@as(f64, @floatFromInt(input_len)) * @as(f64, @floatFromInt(iterations))) / (1024.0 * 1024.0);
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, std.time.ns_per_s);
    return if (seconds == 0) 0 else mib / seconds;
}

fn iterationsFor(input_len: usize) usize {
    const target_bytes: usize = 64 * 1024 * 1024;
    return @max(128, @min(20_000, target_bytes / @max(input_len, 1)));
}

const deterministic_binary = makeDeterministicBinary();

fn makeDeterministicBinary() [128 * 1024]u8 {
    @setEvalBranchQuota(200_000);
    var out: [128 * 1024]u8 = undefined;
    for (&out, 0..) |*byte, i| {
        const value = (i * 131 + (i >> 3) * 17 + 29) & 0xff;
        byte.* = @intCast(value);
    }
    return out;
}

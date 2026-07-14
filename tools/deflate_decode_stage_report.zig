const std = @import("std");
const vort = @import("vort");

const Case = struct {
    name: []const u8,
    payload: []const u8,
    mode: Mode = .best,

    const Mode = enum { best, dynamic_literal, stored };
};

const Row = struct {
    name: []const u8,
    input_bytes: usize,
    zlib_bytes: usize,
    gzip_bytes: usize,
    raw_bytes: usize,
    iterations: usize,
    raw_mib_s: f64,
    raw_into_mib_s: f64,
    zlib_mib_s: f64,
    zlib_into_mib_s: f64,
    gzip_mib_s: f64,
    gzip_into_mib_s: f64,
    zlib_wrapper_time_ratio: f64,
    zlib_wrapper_into_time_ratio: f64,
    gzip_wrapper_time_ratio: f64,
    gzip_wrapper_into_time_ratio: f64,
    raw_alloc_into_time_ratio: f64,
    zlib_alloc_into_time_ratio: f64,
    gzip_alloc_into_time_ratio: f64,
    mix: u64,
};

const binary_payload = blk: {
    @setEvalBranchQuota(200000);
    var data: [64 * 1024]u8 = undefined;
    for (&data, 0..) |*byte, i| byte.* = @intCast((i * 131 + (i >> 3) * 17 + 29) & 0xff);
    break :blk data;
};

const builtins = [_]Case{
    .{ .name = "tiny", .payload = "hello rust deflate baselines" },
    .{ .name = "repetitive", .payload = "abcabcabcabc" ** 512 },
    .{ .name = "overlap-rle", .payload = "a" ** 32768 },
    .{ .name = "distance-heavy", .payload = ("0123456789abcdef" ** 1024) ++ "----" ++ ("0123456789abcdef" ** 1024) },
    .{ .name = "text", .payload = "the quick brown fox jumps over the lazy dog\n" ** 1024 },
    .{ .name = "dynamic-literal", .payload = "literal-heavy dynamic huffman decode stage\n" ** 512, .mode = .dynamic_literal },
    .{ .name = "binary", .payload = &binary_payload },
    .{ .name = "stored-binary", .payload = &binary_payload, .mode = .stored },
    .{ .name = "structured", .payload = "{\"service\":\"vort\",\"level\":\"default\",\"message\":\"decode stage\"}\n" ** 512 },
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var markdown_path: ?[]const u8 = null;
    var iterations_override: ?usize = null;
    var file_cases: std.ArrayList(Case) = .empty;
    defer {
        for (file_cases.items) |case| init.gpa.free(case.payload);
        file_cases.deinit(init.gpa);
    }
    while (args.next()) |path| {
        if (std.mem.eql(u8, path, "--csv")) {
            csv_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.eql(u8, path, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.eql(u8, path, "--iterations")) {
            iterations_override = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
            if (iterations_override.? == 0) return error.InvalidBlockPlan;
            continue;
        }
        const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        errdefer init.gpa.free(payload);
        try file_cases.append(init.gpa, .{ .name = path, .payload = payload });
    }

    const cases = if (file_cases.items.len == 0) builtins[0..] else file_cases.items;
    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(init.gpa);
    for (cases) |case| try rows.append(init.gpa, try measureCase(init, case, iterations_override));

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, rows.items);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(csv.written());
    try stdout.flush();

    if (csv_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    if (markdown_path) |path| {
        var markdown = std.Io.Writer.Allocating.init(init.gpa);
        defer markdown.deinit();
        try writeMarkdown(&markdown.writer, rows.items);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = markdown.written() });
    }
}

fn measureCase(init: std.process.Init, case: Case, iterations_override: ?usize) !Row {
    const options = vort.optionsForCompressionLevel(.default);
    const zlib_frame = switch (case.mode) {
        .best => try vort.encodeZlibBestAlloc(init.gpa, case.payload, options),
        .dynamic_literal => try vort.encodeZlibDynamicLiteralAlloc(init.gpa, case.payload),
        .stored => try vort.encodeZlibStoredAlloc(init.gpa, case.payload),
    };
    defer init.gpa.free(zlib_frame);
    const gzip_frame = switch (case.mode) {
        .best => try vort.encodeGzipBestAlloc(init.gpa, case.payload, options),
        .dynamic_literal => try vort.encodeGzipDynamicLiteralAlloc(init.gpa, case.payload),
        .stored => try vort.encodeGzipStoredAlloc(init.gpa, case.payload),
    };
    defer init.gpa.free(gzip_frame);

    const raw = rawSliceFromZlib(zlib_frame);
    const iterations = iterations_override orelse iterationsFor(case.payload.len);

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

    const raw_scratch = try init.gpa.alloc(u8, case.payload.len);
    defer init.gpa.free(raw_scratch);
    const raw_into_warmup = try vort.decodeRawDeflate(raw, raw_scratch);
    if (raw_into_warmup.output_written != case.payload.len or !std.mem.eql(u8, raw_scratch, case.payload)) return error.DecodeLengthMismatch;
    const raw_into_start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeRawDeflate(raw, raw_scratch);
        if (decoded.output_written != case.payload.len) return error.DecodeLengthMismatch;
        mix +%= decoded.output_written;
        if (decoded.output_written != 0) mix +%= raw_scratch[0];
    }
    const raw_into_ns = raw_into_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

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

    const zlib_scratch = try init.gpa.alloc(u8, case.payload.len);
    defer init.gpa.free(zlib_scratch);
    const zlib_into_warmup = try vort.decodeZlib(zlib_frame, zlib_scratch);
    if (zlib_into_warmup != case.payload.len or !std.mem.eql(u8, zlib_scratch, case.payload)) return error.DecodeLengthMismatch;
    const zlib_into_start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeZlib(zlib_frame, zlib_scratch);
        if (decoded != case.payload.len) return error.DecodeLengthMismatch;
        mix +%= decoded;
        if (decoded != 0) mix +%= zlib_scratch[0];
    }
    const zlib_into_ns = zlib_into_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    const gzip_warmup = try vort.decodeGzipAlloc(init.gpa, gzip_frame);
    init.gpa.free(gzip_warmup);
    const gzip_start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeGzipAlloc(init.gpa, gzip_frame);
        defer init.gpa.free(decoded);
        if (decoded.len != case.payload.len) return error.DecodeLengthMismatch;
        mix +%= decoded.len;
        if (decoded.len != 0) mix +%= decoded[0];
    }
    const gzip_ns = gzip_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    const gzip_scratch = try init.gpa.alloc(u8, case.payload.len);
    defer init.gpa.free(gzip_scratch);
    const gzip_into_warmup = try vort.decodeGzip(gzip_frame, gzip_scratch);
    if (gzip_into_warmup != case.payload.len or !std.mem.eql(u8, gzip_scratch, case.payload)) return error.DecodeLengthMismatch;
    const gzip_into_start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeGzip(gzip_frame, gzip_scratch);
        if (decoded != case.payload.len) return error.DecodeLengthMismatch;
        mix +%= decoded;
        if (decoded != 0) mix +%= gzip_scratch[0];
    }
    const gzip_into_ns = gzip_into_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    return .{
        .name = case.name,
        .input_bytes = case.payload.len,
        .zlib_bytes = zlib_frame.len,
        .gzip_bytes = gzip_frame.len,
        .raw_bytes = raw.len,
        .iterations = iterations,
        .raw_mib_s = throughput(case.payload.len, iterations, raw_ns),
        .raw_into_mib_s = throughput(case.payload.len, iterations, raw_into_ns),
        .zlib_mib_s = throughput(case.payload.len, iterations, zlib_ns),
        .zlib_into_mib_s = throughput(case.payload.len, iterations, zlib_into_ns),
        .gzip_mib_s = throughput(case.payload.len, iterations, gzip_ns),
        .gzip_into_mib_s = throughput(case.payload.len, iterations, gzip_into_ns),
        .zlib_wrapper_time_ratio = ratioSigned(zlib_ns, raw_ns),
        .zlib_wrapper_into_time_ratio = ratioSigned(zlib_into_ns, raw_into_ns),
        .gzip_wrapper_time_ratio = ratioSigned(gzip_ns, raw_ns),
        .gzip_wrapper_into_time_ratio = ratioSigned(gzip_into_ns, raw_into_ns),
        .raw_alloc_into_time_ratio = ratioSigned(raw_ns, raw_into_ns),
        .zlib_alloc_into_time_ratio = ratioSigned(zlib_ns, zlib_into_ns),
        .gzip_alloc_into_time_ratio = ratioSigned(gzip_ns, gzip_into_ns),
        .mix = mix,
    };
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("case,input_bytes,zlib_bytes,gzip_bytes,raw_bytes,iterations,raw_mib_s,raw_into_mib_s,zlib_mib_s,zlib_into_mib_s,gzip_mib_s,gzip_into_mib_s,zlib_wrapper_time_ratio,zlib_wrapper_into_time_ratio,gzip_wrapper_time_ratio,gzip_wrapper_into_time_ratio,raw_alloc_into_time_ratio,zlib_alloc_into_time_ratio,gzip_alloc_into_time_ratio,mix\n");
    for (rows) |row| {
        try writer.print("{s},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.2},{d:.2},{d:.2},{d:.2},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d}\n", .{
            row.name,
            row.input_bytes,
            row.zlib_bytes,
            row.gzip_bytes,
            row.raw_bytes,
            row.iterations,
            row.raw_mib_s,
            row.raw_into_mib_s,
            row.zlib_mib_s,
            row.zlib_into_mib_s,
            row.gzip_mib_s,
            row.gzip_into_mib_s,
            row.zlib_wrapper_time_ratio,
            row.zlib_wrapper_into_time_ratio,
            row.gzip_wrapper_time_ratio,
            row.gzip_wrapper_into_time_ratio,
            row.raw_alloc_into_time_ratio,
            row.zlib_alloc_into_time_ratio,
            row.gzip_alloc_into_time_ratio,
            row.mix,
        });
    }
}

fn writeMarkdown(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll(
        \\# Deflate decode stage report
        \\
        \\| case | input bytes | zlib bytes | raw bytes | iterations | raw alloc MiB/s | raw into MiB/s | zlib alloc MiB/s | zlib into MiB/s | wrapper/raw time | into wrapper/raw time | raw alloc/into time | zlib alloc/into time |
        \\| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
        \\
    );
    for (rows) |row| {
        try writer.print("| {s} | {d} | {d} | {d} | {d} | {d} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {d:.3} | {d:.3} | {d:.3} | {d:.3} | {d:.3} | {d:.3} | {d:.3} |\n", .{
            row.name,
            row.input_bytes,
            row.zlib_bytes,
            row.gzip_bytes,
            row.raw_bytes,
            row.iterations,
            row.raw_mib_s,
            row.raw_into_mib_s,
            row.zlib_mib_s,
            row.zlib_into_mib_s,
            row.gzip_mib_s,
            row.gzip_into_mib_s,
            row.zlib_wrapper_time_ratio,
            row.zlib_wrapper_into_time_ratio,
            row.gzip_wrapper_time_ratio,
            row.gzip_wrapper_into_time_ratio,
            row.raw_alloc_into_time_ratio,
            row.zlib_alloc_into_time_ratio,
            row.gzip_alloc_into_time_ratio,
        });
    }
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

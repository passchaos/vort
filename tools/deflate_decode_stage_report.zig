const std = @import("std");
const vort = @import("vort");

const Case = struct {
    name: []const u8,
    payload: []const u8,
    mode: Mode = .best,

    const Mode = enum { best, dynamic_literal, dynamic_match, stored };
};

const Row = struct {
    name: []const u8,
    input_bytes: usize,
    zlib_bytes: usize,
    gzip_bytes: usize,
    raw_bytes: usize,
    iterations: usize,
    raw_mib_s: f64,
    raw_exact_mib_s: f64,
    raw_into_mib_s: f64,
    zlib_mib_s: f64,
    zlib_exact_mib_s: f64,
    zlib_into_mib_s: f64,
    gzip_mib_s: f64,
    gzip_exact_mib_s: f64,
    gzip_into_mib_s: f64,
    zlib_wrapper_time_ratio: f64,
    zlib_wrapper_exact_time_ratio: f64,
    zlib_wrapper_into_time_ratio: f64,
    gzip_wrapper_time_ratio: f64,
    gzip_wrapper_exact_time_ratio: f64,
    gzip_wrapper_into_time_ratio: f64,
    raw_alloc_exact_time_ratio: f64,
    raw_alloc_into_time_ratio: f64,
    zlib_alloc_exact_time_ratio: f64,
    zlib_alloc_into_time_ratio: f64,
    gzip_alloc_exact_time_ratio: f64,
    gzip_alloc_into_time_ratio: f64,
    mix: u64,
};

const Wrapper = enum { raw, zlib, gzip };

const ErrorCase = struct {
    name: []const u8,
    wrapper: Wrapper,
    input: []const u8,
    expected_error: anyerror,
};

const ErrorRow = struct {
    name: []const u8,
    wrapper: Wrapper,
    input_bytes: usize,
    expected_error: []const u8,
    actual_error: []const u8,
    matched: bool,
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
    .{ .name = "dynamic-literal-only", .payload = "literal-heavy dynamic huffman decode stage\n" ** 512, .mode = .dynamic_literal },
    .{ .name = "dynamic-match", .payload = "literal-heavy dynamic huffman decode stage\n" ** 512, .mode = .dynamic_match },
    .{ .name = "binary", .payload = &binary_payload },
    .{ .name = "stored-binary", .payload = &binary_payload, .mode = .stored },
    .{ .name = "structured", .payload = "{\"service\":\"vort\",\"level\":\"default\",\"message\":\"decode stage\"}\n" ** 512 },
};

// Use a final stored block for empty-wrapper boundary fixtures.  Stored blocks
// keep the bytes easy to audit by hand: BFINAL/BTYPE, LEN=0, and NLEN=~LEN.
const raw_empty_block = [_]u8{ 0x01, 0x00, 0x00, 0xff, 0xff };
const raw_empty_block_trailing = raw_empty_block ++ [_]u8{0x58};
const zlib_empty_frame = [_]u8{ 0x78, 0x01 } ++ raw_empty_block ++ [_]u8{ 0x00, 0x00, 0x00, 0x01 };
const zlib_missing_footer = [_]u8{ 0x78, 0x01 } ++ raw_empty_block;
const zlib_bad_adler = [_]u8{ 0x78, 0x01 } ++ raw_empty_block ++ [_]u8{ 0x00, 0x00, 0x00, 0x02 };
const zlib_empty_trailing = zlib_empty_frame ++ [_]u8{0x58};
const gzip_header = [_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03 };
const gzip_empty_member = gzip_header ++ raw_empty_block ++ [_]u8{
    0x00, 0x00, 0x00, 0x00, // CRC32 of the empty payload.
    0x00, 0x00, 0x00, 0x00, // ISIZE of the empty payload.
};
const gzip_missing_trailer = gzip_header ++ raw_empty_block;
const gzip_bad_crc_member = gzip_header ++ raw_empty_block ++ [_]u8{
    0x01, 0x00, 0x00, 0x00, // Deliberately wrong CRC32.
    0x00, 0x00, 0x00, 0x00,
};
const gzip_bad_isize_member = gzip_header ++ raw_empty_block ++ [_]u8{
    0x00, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x00, 0x00, // Deliberately wrong ISIZE.
};
const gzip_empty_trailing = gzip_empty_member ++ [_]u8{0x58};
const gzip_second_member_bad_crc = gzip_empty_member ++ gzip_bad_crc_member;
const gzip_second_member_truncated = gzip_empty_member ++ gzip_header;
const gzip_third_member_bad_crc = gzip_empty_member ++ gzip_empty_member ++ gzip_bad_crc_member;

const error_cases = [_]ErrorCase{
    .{ .name = "raw-empty", .wrapper = .raw, .input = "", .expected_error = error.TruncatedFrame },
    .{ .name = "raw-header-only", .wrapper = .raw, .input = &.{0x01}, .expected_error = error.TruncatedFrame },
    .{ .name = "raw-trailing-garbage", .wrapper = .raw, .input = &raw_empty_block_trailing, .expected_error = error.TrailingData },
    .{ .name = "zlib-empty", .wrapper = .zlib, .input = "", .expected_error = error.TruncatedFrame },
    .{ .name = "zlib-header-only", .wrapper = .zlib, .input = &.{ 0x78, 0x01 }, .expected_error = error.TruncatedFrame },
    .{ .name = "zlib-missing-footer", .wrapper = .zlib, .input = &zlib_missing_footer, .expected_error = error.TruncatedFrame },
    .{ .name = "zlib-bad-adler", .wrapper = .zlib, .input = &zlib_bad_adler, .expected_error = error.ChecksumMismatch },
    .{ .name = "zlib-trailing-garbage", .wrapper = .zlib, .input = &zlib_empty_trailing, .expected_error = error.TrailingData },
    .{ .name = "gzip-empty", .wrapper = .gzip, .input = "", .expected_error = error.TruncatedFrame },
    .{ .name = "gzip-header-only", .wrapper = .gzip, .input = &gzip_header, .expected_error = error.TruncatedFrame },
    .{ .name = "gzip-missing-trailer", .wrapper = .gzip, .input = &gzip_missing_trailer, .expected_error = error.TruncatedFrame },
    .{ .name = "gzip-bad-crc", .wrapper = .gzip, .input = &gzip_bad_crc_member, .expected_error = error.ChecksumMismatch },
    .{ .name = "gzip-bad-isize", .wrapper = .gzip, .input = &gzip_bad_isize_member, .expected_error = error.SizeMismatch },
    .{ .name = "gzip-trailing-garbage", .wrapper = .gzip, .input = &gzip_empty_trailing, .expected_error = error.TruncatedFrame },
    .{ .name = "gzip-second-member-bad-crc", .wrapper = .gzip, .input = &gzip_second_member_bad_crc, .expected_error = error.ChecksumMismatch },
    .{ .name = "gzip-second-member-truncated", .wrapper = .gzip, .input = &gzip_second_member_truncated, .expected_error = error.TruncatedFrame },
    .{ .name = "gzip-third-member-bad-crc", .wrapper = .gzip, .input = &gzip_third_member_bad_crc, .expected_error = error.ChecksumMismatch },
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var markdown_path: ?[]const u8 = null;
    var json_path: ?[]const u8 = null;
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
        if (std.mem.eql(u8, path, "--json")) {
            json_path = args.next() orelse return error.MissingCorpusPath;
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
    var error_rows: std.ArrayList(ErrorRow) = .empty;
    defer error_rows.deinit(init.gpa);
    for (&error_cases) |case| try error_rows.append(init.gpa, measureErrorCase(init.gpa, case));

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
        try writeMarkdown(&markdown.writer, rows.items, error_rows.items);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = markdown.written() });
    }
    if (json_path) |path| try writeJson(init, path, rows.items, error_rows.items);
    try assertErrorRowsMatched(error_rows.items);
}

fn measureErrorCase(allocator: std.mem.Allocator, case: ErrorCase) ErrorRow {
    const expected_error = @errorName(case.expected_error);
    const actual_error = decodeErrorName(allocator, case.wrapper, case.input);
    return .{
        .name = case.name,
        .wrapper = case.wrapper,
        .input_bytes = case.input.len,
        .expected_error = expected_error,
        .actual_error = actual_error,
        .matched = std.mem.eql(u8, actual_error, expected_error),
    };
}

fn decodeErrorName(allocator: std.mem.Allocator, wrapper: Wrapper, input: []const u8) []const u8 {
    const decoded = switch (wrapper) {
        .raw => vort.decodeRawDeflateAlloc(allocator, input) catch |err| return @errorName(err),
        .zlib => vort.decodeZlibAlloc(allocator, input) catch |err| return @errorName(err),
        .gzip => vort.decodeGzipConcatenatedAlloc(allocator, input) catch |err| return @errorName(err),
    };
    allocator.free(decoded);
    return "accepted";
}

fn assertErrorRowsMatched(error_rows: []const ErrorRow) !void {
    for (error_rows) |row| {
        if (!row.matched) return error.DecodeErrorSmokeMismatch;
    }
}

fn measureCase(init: std.process.Init, case: Case, iterations_override: ?usize) !Row {
    const options = vort.optionsForCompressionLevel(.default);
    const zlib_frame = switch (case.mode) {
        .best => try vort.encodeZlibBestAlloc(init.gpa, case.payload, options),
        .dynamic_literal => try vort.encodeZlibDynamicLiteralAlloc(init.gpa, case.payload),
        .dynamic_match => try vort.encodeZlibDynamicWithOptionsAlloc(init.gpa, case.payload, options),
        .stored => try vort.encodeZlibStoredAlloc(init.gpa, case.payload),
    };
    defer init.gpa.free(zlib_frame);
    const gzip_frame = switch (case.mode) {
        .best => try vort.encodeGzipBestAlloc(init.gpa, case.payload, options),
        .dynamic_literal => try vort.encodeGzipDynamicLiteralAlloc(init.gpa, case.payload),
        .dynamic_match => try vort.encodeGzipDynamicWithOptionsAlloc(init.gpa, case.payload, options),
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
        {
            defer init.gpa.free(decoded);
            if (decoded.len != case.payload.len) return error.DecodeLengthMismatch;
            mix +%= decoded.len;
            if (decoded.len != 0) mix +%= decoded[0];
        }
    }
    const raw_ns = raw_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    const raw_exact_warmup = try vort.decodeRawDeflateAllocExactSize(init.gpa, raw, case.payload.len);
    if (!std.mem.eql(u8, raw_exact_warmup, case.payload)) return error.DecodeLengthMismatch;
    init.gpa.free(raw_exact_warmup);
    const raw_exact_start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeRawDeflateAllocExactSize(init.gpa, raw, case.payload.len);
        {
            defer init.gpa.free(decoded);
            mix +%= decoded.len;
            if (decoded.len != 0) mix +%= decoded[0];
        }
    }
    const raw_exact_ns = raw_exact_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

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
        {
            defer init.gpa.free(decoded);
            if (decoded.len != case.payload.len) return error.DecodeLengthMismatch;
            mix +%= decoded.len;
            if (decoded.len != 0) mix +%= decoded[0];
        }
    }
    const zlib_ns = zlib_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    const zlib_exact_warmup = try vort.decodeZlibAllocExactSize(init.gpa, zlib_frame, case.payload.len);
    if (!std.mem.eql(u8, zlib_exact_warmup, case.payload)) return error.DecodeLengthMismatch;
    init.gpa.free(zlib_exact_warmup);
    const zlib_exact_start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeZlibAllocExactSize(init.gpa, zlib_frame, case.payload.len);
        {
            defer init.gpa.free(decoded);
            mix +%= decoded.len;
            if (decoded.len != 0) mix +%= decoded[0];
        }
    }
    const zlib_exact_ns = zlib_exact_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

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
        {
            defer init.gpa.free(decoded);
            if (decoded.len != case.payload.len) return error.DecodeLengthMismatch;
            mix +%= decoded.len;
            if (decoded.len != 0) mix +%= decoded[0];
        }
    }
    const gzip_ns = gzip_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    const gzip_exact_warmup = try vort.decodeGzipAllocExactSize(init.gpa, gzip_frame, case.payload.len);
    if (!std.mem.eql(u8, gzip_exact_warmup, case.payload)) return error.DecodeLengthMismatch;
    init.gpa.free(gzip_exact_warmup);
    const gzip_exact_start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const decoded = try vort.decodeGzipAllocExactSize(init.gpa, gzip_frame, case.payload.len);
        {
            defer init.gpa.free(decoded);
            mix +%= decoded.len;
            if (decoded.len != 0) mix +%= decoded[0];
        }
    }
    const gzip_exact_ns = gzip_exact_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

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
        .raw_exact_mib_s = throughput(case.payload.len, iterations, raw_exact_ns),
        .raw_into_mib_s = throughput(case.payload.len, iterations, raw_into_ns),
        .zlib_mib_s = throughput(case.payload.len, iterations, zlib_ns),
        .zlib_exact_mib_s = throughput(case.payload.len, iterations, zlib_exact_ns),
        .zlib_into_mib_s = throughput(case.payload.len, iterations, zlib_into_ns),
        .gzip_mib_s = throughput(case.payload.len, iterations, gzip_ns),
        .gzip_exact_mib_s = throughput(case.payload.len, iterations, gzip_exact_ns),
        .gzip_into_mib_s = throughput(case.payload.len, iterations, gzip_into_ns),
        .zlib_wrapper_time_ratio = ratioSigned(zlib_ns, raw_ns),
        .zlib_wrapper_exact_time_ratio = ratioSigned(zlib_exact_ns, raw_exact_ns),
        .zlib_wrapper_into_time_ratio = ratioSigned(zlib_into_ns, raw_into_ns),
        .gzip_wrapper_time_ratio = ratioSigned(gzip_ns, raw_ns),
        .gzip_wrapper_exact_time_ratio = ratioSigned(gzip_exact_ns, raw_exact_ns),
        .gzip_wrapper_into_time_ratio = ratioSigned(gzip_into_ns, raw_into_ns),
        .raw_alloc_exact_time_ratio = ratioSigned(raw_ns, raw_exact_ns),
        .raw_alloc_into_time_ratio = ratioSigned(raw_ns, raw_into_ns),
        .zlib_alloc_exact_time_ratio = ratioSigned(zlib_ns, zlib_exact_ns),
        .zlib_alloc_into_time_ratio = ratioSigned(zlib_ns, zlib_into_ns),
        .gzip_alloc_exact_time_ratio = ratioSigned(gzip_ns, gzip_exact_ns),
        .gzip_alloc_into_time_ratio = ratioSigned(gzip_ns, gzip_into_ns),
        .mix = mix,
    };
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("case,input_bytes,zlib_bytes,gzip_bytes,raw_bytes,iterations,raw_mib_s,raw_exact_mib_s,raw_into_mib_s,zlib_mib_s,zlib_exact_mib_s,zlib_into_mib_s,gzip_mib_s,gzip_exact_mib_s,gzip_into_mib_s,zlib_wrapper_time_ratio,zlib_wrapper_exact_time_ratio,zlib_wrapper_into_time_ratio,gzip_wrapper_time_ratio,gzip_wrapper_exact_time_ratio,gzip_wrapper_into_time_ratio,raw_alloc_exact_time_ratio,raw_alloc_into_time_ratio,zlib_alloc_exact_time_ratio,zlib_alloc_into_time_ratio,gzip_alloc_exact_time_ratio,gzip_alloc_into_time_ratio,mix\n");
    for (rows) |row| {
        try writer.print("{s},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.2},{d:.2},{d:.2},{d:.2},{d:.2},{d:.2},{d:.2},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d}\n", .{
            row.name,
            row.input_bytes,
            row.zlib_bytes,
            row.gzip_bytes,
            row.raw_bytes,
            row.iterations,
            row.raw_mib_s,
            row.raw_exact_mib_s,
            row.raw_into_mib_s,
            row.zlib_mib_s,
            row.zlib_exact_mib_s,
            row.zlib_into_mib_s,
            row.gzip_mib_s,
            row.gzip_exact_mib_s,
            row.gzip_into_mib_s,
            row.zlib_wrapper_time_ratio,
            row.zlib_wrapper_exact_time_ratio,
            row.zlib_wrapper_into_time_ratio,
            row.gzip_wrapper_time_ratio,
            row.gzip_wrapper_exact_time_ratio,
            row.gzip_wrapper_into_time_ratio,
            row.raw_alloc_exact_time_ratio,
            row.raw_alloc_into_time_ratio,
            row.zlib_alloc_exact_time_ratio,
            row.zlib_alloc_into_time_ratio,
            row.gzip_alloc_exact_time_ratio,
            row.gzip_alloc_into_time_ratio,
            row.mix,
        });
    }
}

fn writeMarkdown(writer: *std.Io.Writer, rows: []const Row, error_rows: []const ErrorRow) !void {
    try writer.writeAll(
        \\# Deflate decode stage report
        \\
        \\| case | input bytes | raw bytes | zlib bytes | gzip bytes | iterations | raw alloc MiB/s | raw exact MiB/s | raw into MiB/s | zlib alloc MiB/s | zlib exact MiB/s | zlib into MiB/s | gzip alloc MiB/s | gzip exact MiB/s | gzip into MiB/s | zlib/raw alloc time | zlib/raw exact time | zlib/raw into time | gzip/raw alloc time | gzip/raw exact time | gzip/raw into time | raw alloc/exact time | raw alloc/into time | zlib alloc/exact time | zlib alloc/into time | gzip alloc/exact time | gzip alloc/into time |
        \\| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
        \\
    );
    for (rows) |row| {
        try writer.print("| {s} | {d} | {d} | {d} | {d} | {d} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {d:.2} | {d:.3} | {d:.3} | {d:.3} | {d:.3} | {d:.3} | {d:.3} | {d:.3} | {d:.3} | {d:.3} | {d:.3} | {d:.3} | {d:.3} |\n", .{
            row.name,
            row.input_bytes,
            row.raw_bytes,
            row.zlib_bytes,
            row.gzip_bytes,
            row.iterations,
            row.raw_mib_s,
            row.raw_exact_mib_s,
            row.raw_into_mib_s,
            row.zlib_mib_s,
            row.zlib_exact_mib_s,
            row.zlib_into_mib_s,
            row.gzip_mib_s,
            row.gzip_exact_mib_s,
            row.gzip_into_mib_s,
            row.zlib_wrapper_time_ratio,
            row.zlib_wrapper_exact_time_ratio,
            row.zlib_wrapper_into_time_ratio,
            row.gzip_wrapper_time_ratio,
            row.gzip_wrapper_exact_time_ratio,
            row.gzip_wrapper_into_time_ratio,
            row.raw_alloc_exact_time_ratio,
            row.raw_alloc_into_time_ratio,
            row.zlib_alloc_exact_time_ratio,
            row.zlib_alloc_into_time_ratio,
            row.gzip_alloc_exact_time_ratio,
            row.gzip_alloc_into_time_ratio,
        });
    }
    try writer.writeAll(
        \\
        \\## Error path smoke
        \\
        \\These rows keep representative malformed/truncated/checksum wrapper inputs visible in the decode-stage dashboard without mixing them into throughput timings.
        \\
        \\| case | wrapper | input bytes | expected error | actual error | matched |
        \\| --- | --- | ---: | --- | --- | --- |
        \\
    );
    for (error_rows) |row| {
        try writer.print("| {s} | {s} | {d} | `{s}` | `{s}` | `{}` |\n", .{
            row.name,
            @tagName(row.wrapper),
            row.input_bytes,
            row.expected_error,
            row.actual_error,
            row.matched,
        });
    }
}

fn writeJson(init: std.process.Init, path: []const u8, rows: []const Row, error_rows: []const ErrorRow) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    const w = &writer.writer;
    var matched_error_rows: usize = 0;
    for (error_rows) |row| {
        if (row.matched) matched_error_rows += 1;
    }
    const unmatched_error_rows = error_rows.len - matched_error_rows;
    const ok = rows.len > 0 and matched_error_rows == error_rows.len;
    try w.print(
        "{{\n  \"schema\": \"vort.deflate_decode_stage_report\",\n  \"schema_version\": 1,\n  \"ok\": {},\n  \"rows\": {d},\n  \"error_rows\": {d},\n  \"matched_error_rows\": {d},\n  \"unmatched_error_rows\": {d},\n  \"items\": [\n",
        .{ ok, rows.len, error_rows.len, matched_error_rows, unmatched_error_rows },
    );
    for (rows, 0..) |row, i| {
        try w.writeAll("    {\"case\": ");
        try std.json.Stringify.value(row.name, .{}, w);
        try w.print(", \"input_bytes\": {d}, \"zlib_bytes\": {d}, \"gzip_bytes\": {d}, \"raw_bytes\": {d}, \"iterations\": {d}, \"raw_mib_s\": {d:.6}, \"raw_exact_mib_s\": {d:.6}, \"raw_into_mib_s\": {d:.6}, \"zlib_mib_s\": {d:.6}, \"zlib_exact_mib_s\": {d:.6}, \"zlib_into_mib_s\": {d:.6}, \"gzip_mib_s\": {d:.6}, \"gzip_exact_mib_s\": {d:.6}, \"gzip_into_mib_s\": {d:.6}, \"zlib_wrapper_time_ratio\": {d:.6}, \"zlib_wrapper_exact_time_ratio\": {d:.6}, \"zlib_wrapper_into_time_ratio\": {d:.6}, \"gzip_wrapper_time_ratio\": {d:.6}, \"gzip_wrapper_exact_time_ratio\": {d:.6}, \"gzip_wrapper_into_time_ratio\": {d:.6}, \"raw_alloc_exact_time_ratio\": {d:.6}, \"raw_alloc_into_time_ratio\": {d:.6}, \"zlib_alloc_exact_time_ratio\": {d:.6}, \"zlib_alloc_into_time_ratio\": {d:.6}, \"gzip_alloc_exact_time_ratio\": {d:.6}, \"gzip_alloc_into_time_ratio\": {d:.6}, \"mix\": {d}}}{s}\n", .{
            row.input_bytes,
            row.zlib_bytes,
            row.gzip_bytes,
            row.raw_bytes,
            row.iterations,
            row.raw_mib_s,
            row.raw_exact_mib_s,
            row.raw_into_mib_s,
            row.zlib_mib_s,
            row.zlib_exact_mib_s,
            row.zlib_into_mib_s,
            row.gzip_mib_s,
            row.gzip_exact_mib_s,
            row.gzip_into_mib_s,
            row.zlib_wrapper_time_ratio,
            row.zlib_wrapper_exact_time_ratio,
            row.zlib_wrapper_into_time_ratio,
            row.gzip_wrapper_time_ratio,
            row.gzip_wrapper_exact_time_ratio,
            row.gzip_wrapper_into_time_ratio,
            row.raw_alloc_exact_time_ratio,
            row.raw_alloc_into_time_ratio,
            row.zlib_alloc_exact_time_ratio,
            row.zlib_alloc_into_time_ratio,
            row.gzip_alloc_exact_time_ratio,
            row.gzip_alloc_into_time_ratio,
            row.mix,
            if (i + 1 == rows.len) "" else ",",
        });
    }
    try w.writeAll("  ],\n  \"error_items\": [\n");
    for (error_rows, 0..) |row, i| {
        try w.writeAll("    {\"case\": ");
        try std.json.Stringify.value(row.name, .{}, w);
        try w.print(", \"wrapper\": \"{s}\", \"input_bytes\": {d}, \"expected_error\": ", .{ @tagName(row.wrapper), row.input_bytes });
        try std.json.Stringify.value(row.expected_error, .{}, w);
        try w.writeAll(", \"actual_error\": ");
        try std.json.Stringify.value(row.actual_error, .{}, w);
        try w.print(", \"matched\": {}}}{s}\n", .{
            row.matched,
            if (i + 1 == error_rows.len) "" else ",",
        });
    }
    try w.writeAll("  ]\n}\n");
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
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

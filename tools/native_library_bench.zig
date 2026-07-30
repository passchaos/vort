const std = @import("std");
const vort = @import("vort");

const Codec = enum { lz4, zstd };
const Mode = enum { one_shot, incremental, incremental_direct };

const Case = struct {
    name: []const u8,
    payload: []const u8,
};

const Row = struct {
    codec: Codec,
    mode: Mode,
    case_name: []const u8,
    input_bytes: usize,
    encoded_bytes: usize,
    iterations: usize,
    encode_ns: u64,
    decode_ns: u64,
    encode_mib_s: f64,
    decode_mib_s: f64,
    checksum: u64,
};

const Options = struct {
    iterations: usize = 200,
    csv_path: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);

    const cases = [_]Case{
        .{ .name = "text", .payload = "Native library benchmark text payload. " ** 1024 },
        .{ .name = "structured", .payload = "{\"service\":\"vort\",\"codec\":\"native\",\"value\":12345}\n" ** 768 },
        .{ .name = "repetitive", .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 256 },
    };

    try smokeLz4LinkedDirectFallback(init.gpa);
    try smokeZstdMultiblockDirectFallback(init.gpa);

    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(init.gpa);
    for (cases) |case| {
        try rows.append(init.gpa, try lz4OneShotRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try lz4IncrementalRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try lz4IncrementalDirectRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try zstdOneShotRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try zstdIncrementalRow(init.io, init.gpa, case, options.iterations));
        try rows.append(init.gpa, try zstdIncrementalDirectRow(init.io, init.gpa, case, options.iterations));
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, rows.items);
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
        try stdout_writer.interface.writeAll(csv.written());
        try stdout_writer.interface.flush();
    }
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            const value = args.next() orelse return error.MissingIterationCount;
            options.iterations = try std.fmt.parseInt(usize, value, 10);
            if (options.iterations == 0) return error.InvalidIterationCount;
        } else if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path = args.next() orelse return error.MissingCsvPath;
        } else {
            return error.UnknownArgument;
        }
    }
    return options;
}

fn lz4OneShotRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.Lz4NativeFrameOptions = .{ .content_checksum = false, .block_checksum = true };
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.lz4DecodeNativeFrameInto(encoded, decoded), case.payload, decoded);

    const encode_result = try timeEncodeLz4(io, allocator, case.payload, options, iterations);
    const decode_result = try timeDecodeLz4OneShot(io, encoded, decoded, case.payload, iterations);
    return makeRow(.lz4, .one_shot, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4IncrementalRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.Lz4NativeFrameOptions = .{ .content_checksum = false, .block_checksum = true };
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try decodeLz4Incremental(allocator, encoded, decoded);
    if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;

    const decode_result = try timeDecodeLz4Incremental(io, allocator, encoded, decoded, case.payload, iterations);
    const encode_result = try timeEncodeLz4(io, allocator, case.payload, options, iterations);
    return makeRow(.lz4, .incremental, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn lz4IncrementalDirectRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.Lz4NativeFrameOptions = .{ .content_checksum = false, .block_checksum = true };
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try decodeLz4IncrementalDirect(allocator, encoded, decoded);
    if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;

    const decode_result = try timeDecodeLz4IncrementalDirect(io, allocator, encoded, decoded, case.payload, iterations);
    const encode_result = try timeEncodeLz4(io, allocator, case.payload, options, iterations);
    return makeRow(.lz4, .incremental_direct, case, encoded.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdOneShotRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.ZstdNativeFrameOptions = .{ .selection = .literal_only, .content_checksum = false };
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try expectRoundTrip(vort.zstdDecodeNativeFrameInto(encoded.frame, decoded), case.payload, decoded);

    const encode_result = try timeEncodeZstd(io, allocator, case.payload, options, iterations);
    const decode_result = try timeDecodeZstdOneShot(io, encoded.frame, decoded, case.payload, iterations);
    return makeRow(.zstd, .one_shot, case, encoded.frame.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdIncrementalRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.ZstdNativeFrameOptions = .{ .selection = .literal_only, .content_checksum = false };
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try decodeZstdIncremental(allocator, encoded.frame, decoded);
    if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;

    const decode_result = try timeDecodeZstdIncremental(io, allocator, encoded.frame, decoded, case.payload, iterations);
    const encode_result = try timeEncodeZstd(io, allocator, case.payload, options, iterations);
    return makeRow(.zstd, .incremental, case, encoded.frame.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

fn zstdIncrementalDirectRow(io: std.Io, allocator: std.mem.Allocator, case: Case, iterations: usize) !Row {
    const options: vort.ZstdNativeFrameOptions = .{ .selection = .literal_only, .content_checksum = false };
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, case.payload, options);
    defer allocator.free(encoded.frame);
    const decoded = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(decoded);
    try decodeZstdIncrementalDirect(allocator, encoded.frame, decoded);
    if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;

    const decode_result = try timeDecodeZstdIncrementalDirect(io, allocator, encoded.frame, decoded, case.payload, iterations);
    const encode_result = try timeEncodeZstd(io, allocator, case.payload, options, iterations);
    return makeRow(.zstd, .incremental_direct, case, encoded.frame.len, iterations, encode_result.elapsed_ns, decode_result.elapsed_ns, encode_result.checksum ^ decode_result.checksum);
}

const TimeResult = struct { elapsed_ns: u64, checksum: u64 };

fn timeEncodeLz4(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, options: vort.Lz4NativeFrameOptions, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
        checksum +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeEncodeZstd(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, options: vort.ZstdNativeFrameOptions, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
        checksum +%= encoded.frame.len;
        allocator.free(encoded.frame);
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4OneShot(io: std.Io, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try expectRoundTrip(vort.lz4DecodeNativeFrameInto(encoded, decoded), expected, decoded);
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdOneShot(io: std.Io, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try expectRoundTrip(vort.zstdDecodeNativeFrameInto(encoded, decoded), expected, decoded);
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4Incremental(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeLz4Incremental(allocator, encoded, decoded);
        if (!std.mem.eql(u8, expected, decoded)) return error.SizeMismatch;
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdIncremental(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeZstdIncremental(allocator, encoded, decoded);
        if (!std.mem.eql(u8, expected, decoded)) return error.SizeMismatch;
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeLz4IncrementalDirect(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeLz4IncrementalDirect(allocator, encoded, decoded);
        if (!std.mem.eql(u8, expected, decoded)) return error.SizeMismatch;
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn timeDecodeZstdIncrementalDirect(io: std.Io, allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8, expected: []const u8, iterations: usize) !TimeResult {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        try decodeZstdIncrementalDirect(allocator, encoded, decoded);
        if (!std.mem.eql(u8, expected, decoded)) return error.SizeMismatch;
        checksum +%= decoded[0];
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .checksum = checksum };
}

fn smokeLz4LinkedDirectFallback(allocator: std.mem.Allocator) !void {
    var payload: [64 * 1024 + 4096]u8 = undefined;
    var state: u32 = 0x1234_abcd;
    for (payload[0 .. 64 * 1024]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload[64 * 1024 ..], payload[60 * 1024 .. 64 * 1024]);
    const encoded = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, &payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_mode = .linked,
        .block_size_id = .max64kb,
    });
    defer allocator.free(encoded);

    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var decoded: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded, decoded[0..0]);
    if (initial.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const first = try decoder.step("", decoded[0 .. 64 * 1024]);
    if (first.status != .need_output or first.progress.output_written != 64 * 1024) return error.SizeMismatch;
    if (decoder.decoded_scratch.items.len != 0) return error.SizeMismatch;
    const partial = try decoder.step("", decoded[64 * 1024 ..][0..127]);
    if (partial.status != .need_output or partial.progress.output_written != 127) return error.SizeMismatch;
    if (decoder.decoded_scratch.items.len != payload.len) return error.SizeMismatch;
    const done = try decoder.step("", decoded[64 * 1024 + 127 ..]);
    if (done.status != .done) return error.SizeMismatch;
    if (!std.mem.eql(u8, &payload, &decoded)) return error.SizeMismatch;
}

fn smokeZstdMultiblockDirectFallback(allocator: std.mem.Allocator) !void {
    const payload = "a" ** 264;
    const encoded = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = true,
        .block_size_max = payload.len / 2,
    });
    defer allocator.free(encoded.frame);

    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var decoded: [payload.len]u8 = undefined;
    const first = try decoder.step(encoded.frame, decoded[0..0]);
    if (first.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const partial = try decoder.step("", decoded[0..17]);
    if (partial.status != .need_output or partial.progress.output_written != 17) return error.SizeMismatch;
    if (decoder.decoded_scratch.items.len != payload.len) return error.SizeMismatch;
    const done = try decoder.step("", decoded[17..]);
    if (done.status != .done) return error.SizeMismatch;
    if (!std.mem.eql(u8, payload, &decoded)) return error.SizeMismatch;
}

fn decodeLz4Incremental(allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8) !void {
    var decoder = vort.Lz4NativeIncrementalFrameDecoder.init(allocator);
    defer decoder.deinit();
    try drainIncremental(&decoder, encoded, decoded);
}

fn decodeZstdIncremental(allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8) !void {
    var decoder = vort.ZstdNativeIncrementalFrameDecoder.init(allocator);
    defer decoder.deinit();
    try drainIncremental(&decoder, encoded, decoded);
}

fn decodeLz4IncrementalDirect(allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8) !void {
    var decoder = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = decoded.len,
        .max_decoded_buffer_len = decoded.len,
    });
    defer decoder.deinit();
    const first = try decoder.step(encoded, decoded[0..0]);
    if (first.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const done = try decoder.step("", decoded);
    if (done.status != .done or done.progress.output_written != decoded.len) return error.SizeMismatch;
}

fn decodeZstdIncrementalDirect(allocator: std.mem.Allocator, encoded: []const u8, decoded: []u8) !void {
    var decoder = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
        .expected_output_len = decoded.len,
        .max_decoded_buffer_len = decoded.len,
    });
    defer decoder.deinit();
    const first = try decoder.step(encoded, decoded[0..0]);
    if (first.status != .need_output) return error.SizeMismatch;
    if (!std.mem.eql(u8, decoder.diagnostics().phase_name, "direct_output")) return error.SizeMismatch;
    const done = try decoder.step("", decoded);
    if (done.status != .done or done.progress.output_written != decoded.len) return error.SizeMismatch;
}

fn drainIncremental(decoder: anytype, encoded: []const u8, decoded: []u8) !void {
    const split = @max(@as(usize, 1), encoded.len / 3);
    var offset: usize = 0;
    var out_offset: usize = 0;
    while (offset < encoded.len) {
        const end = @min(encoded.len, offset + split);
        const result = try decoder.step(encoded[offset..end], decoded[out_offset..out_offset]);
        offset += result.progress.input_read;
        if (result.status == .need_output) break;
        if (result.status == .done) break;
    }
    while (true) {
        const end = @min(decoded.len, out_offset + 31);
        const result = try decoder.step("", decoded[out_offset..end]);
        out_offset += result.progress.output_written;
        if (result.status == .done) break;
        if (result.status != .need_output) return error.SizeMismatch;
    }
    if (out_offset != decoded.len) return error.SizeMismatch;
}

fn expectRoundTrip(written_result: anytype, expected: []const u8, decoded: []u8) !void {
    const written = try written_result;
    if (written != expected.len) return error.SizeMismatch;
    if (!std.mem.eql(u8, expected, decoded[0..written])) return error.SizeMismatch;
}

fn makeRow(codec: Codec, mode: Mode, case: Case, encoded_len: usize, iterations: usize, encode_ns: u64, decode_ns: u64, checksum: u64) Row {
    return .{
        .codec = codec,
        .mode = mode,
        .case_name = case.name,
        .input_bytes = case.payload.len,
        .encoded_bytes = encoded_len,
        .iterations = iterations,
        .encode_ns = encode_ns,
        .decode_ns = decode_ns,
        .encode_mib_s = mibPerSecond(case.payload.len * iterations, encode_ns),
        .decode_mib_s = mibPerSecond(case.payload.len * iterations, decode_ns),
        .checksum = checksum,
    };
}

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const elapsed = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (elapsed <= 0) 0 else @intCast(elapsed);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0.0;
    const mib = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0);
    const seconds = @as(f64, @floatFromInt(ns)) / 1_000_000_000.0;
    return mib / seconds;
}

fn codecName(codec: Codec) []const u8 {
    return switch (codec) {
        .lz4 => "lz4",
        .zstd => "zstd",
    };
}

fn modeName(mode: Mode) []const u8 {
    return switch (mode) {
        .one_shot => "one_shot",
        .incremental => "incremental",
        .incremental_direct => "incremental_direct",
    };
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("codec,mode,case,input_bytes,encoded_bytes,iterations,encode_ns,decode_ns,encode_mib_s,decode_mib_s,checksum\n");
    for (rows) |row| {
        try writer.print("{s},{s},{s},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d}\n", .{
            codecName(row.codec),
            modeName(row.mode),
            row.case_name,
            row.input_bytes,
            row.encoded_bytes,
            row.iterations,
            row.encode_ns,
            row.decode_ns,
            row.encode_mib_s,
            row.decode_mib_s,
            row.checksum,
        });
    }
}

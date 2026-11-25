//! One-shot raw Deflate encode comparison: Vort levels against zlib and
//! libdeflate on the same immutable prefix. Initial wires are fully decoded by
//! Vort and libdeflate before timing. Timed calls check output lengths and use
//! cold allocating one-shot state/output lifecycles on all three sides.
const std = @import("std");
const vort = @import("vort");
const zlib = @import("zlib");
const benchmark_provenance = @import("benchmark_provenance");
const encode_samples = @import("encode_samples.zig");

const c = @cImport({
    @cInclude("libdeflate.h");
});

const max_input_size = 256 * 1024 * 1024;

const Options = struct {
    input_path: ?[]const u8 = null,
    input_name: ?[]const u8 = null,
    level: u4 = 6,
    libdeflate_level: ?u4 = null,
    limit: usize = 128 * 1024,
    iterations: usize = 1,
    rounds: usize = encode_samples.default_rounds,
    warmup: usize = encode_samples.default_warmup,
    csv_path: ?[]const u8 = null,
    samples_json_path: ?[]const u8 = null,
};

const Sample = encode_samples.Sample;

const Encoders = struct {
    vort_wire: []u8,
    zlib_wire: []u8,
    libdeflate_wire: []u8,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    try validateOutputPaths(init.gpa, options.csv_path, options.samples_json_path);
    const input_path = options.input_path orelse return error.MissingCorpusPath;
    const name = options.input_name orelse std.fs.path.basename(input_path);
    if (name.len == 0 or std.mem.indexOfAny(u8, name, ",\r\n") != null)
        return error.InvalidCaseName;
    const provenance = try benchmark_provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer provenance.deinit(init.gpa);

    const full_input = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        input_path,
        init.gpa,
        .limited(max_input_size),
    );
    defer init.gpa.free(full_input);
    const input: []const u8 = full_input[0..@min(full_input.len, options.limit)];
    if (input.len == 0) return error.InputTooSmall;
    const input_sha256 = benchmark_provenance.sha256Hex(input);
    const timed_bytes = std.math.mul(usize, input.len, options.iterations) catch return error.InvalidOptions;

    const level: u4 = options.level;
    if (level > 9) return error.InvalidLevel;
    const libdeflate_level = options.libdeflate_level orelse level;
    const wires = Encoders{
        .vort_wire = try vort.encodeRawLevelAlloc(init.gpa, input, level),
        .zlib_wire = try zlibEncodeRaw(init.gpa, input, @intCast(level)),
        .libdeflate_wire = try libdeflateEncodeCold(init.gpa, input, libdeflate_level),
    };
    defer init.gpa.free(wires.vort_wire);
    defer init.gpa.free(wires.zlib_wire);
    defer init.gpa.free(wires.libdeflate_wire);

    const decompressor = c.libdeflate_alloc_decompressor() orelse return error.ReferenceUnavailable;
    defer c.libdeflate_free_decompressor(decompressor);
    try verifyWire(init.gpa, decompressor, input, wires.vort_wire);
    try verifyWire(init.gpa, decompressor, input, wires.zlib_wire);
    try verifyWire(init.gpa, decompressor, input, wires.libdeflate_wire);

    const wire_lengths: encode_samples.WireLengths = .{
        .vort_bytes = wires.vort_wire.len,
        .zlib_bytes = wires.zlib_wire.len,
        .libdeflate_bytes = wires.libdeflate_wire.len,
    };
    const wire_evidence: encode_samples.Wires = .{
        .vort_bytes = wires.vort_wire.len,
        .zlib_bytes = wires.zlib_wire.len,
        .libdeflate_bytes = wires.libdeflate_wire.len,
        .vort_sha256 = benchmark_provenance.sha256Hex(wires.vort_wire),
        .zlib_sha256 = benchmark_provenance.sha256Hex(wires.zlib_wire),
        .libdeflate_sha256 = benchmark_provenance.sha256Hex(wires.libdeflate_wire),
    };
    const samples = try measureInterleaved(init.io, init.gpa, input, level, libdeflate_level, options.iterations, options.rounds, options.warmup, wire_lengths);
    defer samples.deinit(init.gpa);
    if (!std.mem.eql(u8, &input_sha256, &benchmark_provenance.sha256Hex(input)))
        return error.InputChanged;
    try samples.validate(options.iterations, wire_lengths);
    const summary = try samples.summary(init.gpa);

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.print(
        "case,reference_version,level,input_bytes,input_sha256,vort_bytes,zlib_bytes,libdeflate_bytes,vort_ns,zlib_ns,libdeflate_ns,vort_mib_s,zlib_mib_s,libdeflate_mib_s,vort_over_zlib,vort_over_libdeflate,checksum,{s}\n",
        .{benchmark_provenance.csv_columns},
    );
    try csv.writer.print("{s},{s},{d},{d},{s},{d},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.2},{d:.4},{d:.4},{d}", .{
        name,
        c.LIBDEFLATE_VERSION_STRING,
        level,
        input.len,
        &input_sha256,
        wires.vort_wire.len,
        wires.zlib_wire.len,
        wires.libdeflate_wire.len,
        summary.vort_median_ns,
        summary.zlib_median_ns,
        summary.libdeflate_median_ns,
        mibPerSecond(timed_bytes, summary.vort_median_ns),
        mibPerSecond(timed_bytes, summary.zlib_median_ns),
        mibPerSecond(timed_bytes, summary.libdeflate_median_ns),
        @as(f64, @floatFromInt(summary.zlib_median_ns)) / @as(f64, @floatFromInt(summary.vort_median_ns)),
        @as(f64, @floatFromInt(summary.libdeflate_median_ns)) / @as(f64, @floatFromInt(summary.vort_median_ns)),
        samples.checksum(),
    });
    try provenance.writeCsvFields(&csv.writer);
    try csv.writer.writeByte('\n');

    if (options.samples_json_path) |path| {
        var json: std.Io.Writer.Allocating = .init(init.gpa);
        defer json.deinit();
        try encode_samples.write(&json.writer, .{
            .case = name,
            .input_bytes = input.len,
            .input_sha256 = input_sha256,
            .iterations = options.iterations,
            .measurements = samples,
            .summary = summary,
            .level = level,
            .libdeflate_level = libdeflate_level,
            .wires = wire_evidence,
        }, .{
            .{ .role = "zlib", .version = std.mem.span(zlib.zlibVersion()), .version_scope = "runtime_api" },
            .{ .role = "libdeflate", .version = c.LIBDEFLATE_VERSION_STRING, .version_scope = "compile_time_header" },
        }, provenance);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = json.written() });
    }

    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn verifyWire(allocator: std.mem.Allocator, decompressor: *c.libdeflate_decompressor, input: []const u8, wire: []const u8) !void {
    const output = try allocator.alloc(u8, input.len);
    defer allocator.free(output);
    const decoded = try vort.decodeRawDeflate(wire, output);
    if (decoded.input_read != wire.len or decoded.output_written != input.len or !std.mem.eql(u8, input, output))
        return error.SizeMismatch;

    var consumed: usize = 0;
    var actual: usize = 0;
    if (c.libdeflate_deflate_decompress_ex(
        decompressor,
        wire.ptr,
        wire.len,
        output.ptr,
        output.len,
        &consumed,
        &actual,
    ) != c.LIBDEFLATE_SUCCESS or consumed != wire.len or actual != input.len or !std.mem.eql(u8, input, output))
        return error.ReferenceDecodeFailed;
}

fn measureInterleaved(
    io: std.Io,
    allocator: std.mem.Allocator,
    input: []const u8,
    level: u4,
    libdeflate_level: u4,
    iterations: usize,
    rounds: usize,
    warmup: usize,
    wires: encode_samples.WireLengths,
) !encode_samples.Measurements {
    try encode_samples.validateCounts(iterations, rounds, warmup);
    const samples = try encode_samples.Measurements.init(allocator, rounds, warmup);
    errdefer samples.deinit(allocator);
    try measureRounds(io, allocator, input, level, libdeflate_level, iterations, wires, samples.warmup_rounds);
    try measureRounds(io, allocator, input, level, libdeflate_level, iterations, wires, samples.rounds);
    return samples;
}

fn measureRounds(io: std.Io, allocator: std.mem.Allocator, input: []const u8, level: u4, libdeflate_level: u4, iterations: usize, wires: encode_samples.WireLengths, rounds: []encode_samples.Round) !void {
    for (rounds, 0..) |*round, index| {
        round.* = .init(index);
        for (round.order) |encoder| {
            const sample = switch (encoder) {
                .vort => try measureVort(io, allocator, input, level, iterations, wires.vort_bytes),
                .zlib => try measureZlib(io, allocator, input, level, iterations, wires.zlib_bytes),
                .libdeflate => try measureLibdeflate(io, allocator, input, libdeflate_level, iterations, wires.libdeflate_bytes),
            };
            round.record(encoder, sample);
        }
    }
}

fn measureVort(io: std.Io, allocator: std.mem.Allocator, input: []const u8, level: u4, iterations: usize, expected_bytes: usize) !Sample {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try vort.encodeRawLevelAlloc(allocator, input, level);
        defer allocator.free(encoded);
        if (encoded.len != expected_bytes) return error.SampleWireMismatch;
        mix +%= encoded.len;
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .mix = mix };
}

fn measureZlib(io: std.Io, allocator: std.mem.Allocator, input: []const u8, level: u4, iterations: usize, expected_bytes: usize) !Sample {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try zlibEncodeRaw(allocator, input, @intCast(level));
        defer allocator.free(encoded);
        if (encoded.len != expected_bytes) return error.SampleWireMismatch;
        mix +%= encoded.len;
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .mix = mix };
}

fn measureLibdeflate(io: std.Io, allocator: std.mem.Allocator, input: []const u8, level: u4, iterations: usize, expected_bytes: usize) !Sample {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try libdeflateEncodeCold(allocator, input, level);
        defer allocator.free(encoded);
        if (encoded.len != expected_bytes) return error.SampleWireMismatch;
        mix +%= encoded.len;
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .mix = mix };
}

fn zlibEncodeRaw(allocator: std.mem.Allocator, input: []const u8, level: c_int) ![]u8 {
    var stream: zlib.z_stream = std.mem.zeroes(zlib.z_stream);
    if (zlib.deflateInit2_(
        &stream,
        level,
        zlib.Z_DEFLATED,
        -15,
        8,
        zlib.Z_DEFAULT_STRATEGY,
        zlib.ZLIB_VERSION,
        @sizeOf(zlib.z_stream),
    ) != zlib.Z_OK) return error.ZlibInit;
    defer _ = zlib.deflateEnd(&stream);

    stream.next_in = @constCast(input.ptr);
    stream.avail_in = @intCast(input.len);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var buffer: [64 * 1024]u8 = undefined;
    while (true) {
        stream.next_out = &buffer;
        stream.avail_out = buffer.len;
        const rc = zlib.deflate(&stream, zlib.Z_FINISH);
        const produced = buffer.len - stream.avail_out;
        try out.appendSlice(allocator, buffer[0..produced]);
        if (rc == zlib.Z_STREAM_END) break;
        if (rc != zlib.Z_OK) return error.ZlibDeflate;
    }
    return out.toOwnedSlice(allocator);
}

fn libdeflateEncodeCold(allocator: std.mem.Allocator, input: []const u8, level: u4) ![]u8 {
    const compressor = c.libdeflate_alloc_compressor(@intCast(level)) orelse return error.ReferenceUnavailable;
    defer c.libdeflate_free_compressor(compressor);
    return libdeflateEncode(allocator, compressor, input);
}

fn libdeflateEncode(allocator: std.mem.Allocator, compressor: *c.libdeflate_compressor, input: []const u8) ![]u8 {
    const bound = c.libdeflate_deflate_compress_bound(compressor, input.len);
    if (bound == 0) return error.ReferenceUnavailable;
    const out = try allocator.alloc(u8, bound);
    errdefer allocator.free(out);
    const written = c.libdeflate_deflate_compress(compressor, input.ptr, input.len, out.ptr, out.len);
    if (written == 0) return error.ReferenceEncodeFailed;
    return allocator.realloc(out, written);
}

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    return if (ns <= 0) 0 else @intCast(ns);
}

fn mibPerSecond(bytes: usize, elapsed_ns: u64) f64 {
    if (elapsed_ns == 0) return 0;
    const bytes_f: f64 = @floatFromInt(bytes);
    const ns_f: f64 = @floatFromInt(elapsed_ns);
    return bytes_f / (1024.0 * 1024.0) / (ns_f / std.time.ns_per_s);
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--input"))
            options.input_path = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--name"))
            options.input_name = args.next() orelse return error.MissingCaseName
        else if (std.mem.eql(u8, arg, "--level"))
            options.level = try std.fmt.parseInt(u4, args.next() orelse return error.MissingLevel, 10)
        else if (std.mem.eql(u8, arg, "--libdeflate-level"))
            options.libdeflate_level = try std.fmt.parseInt(u4, args.next() orelse return error.MissingLibdeflateLevel, 10)
        else if (std.mem.eql(u8, arg, "--limit"))
            options.limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingIterations, 10)
        else if (std.mem.eql(u8, arg, "--rounds"))
            options.rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingRounds, 10)
        else if (std.mem.eql(u8, arg, "--warmup"))
            options.warmup = try std.fmt.parseInt(usize, args.next() orelse return error.MissingWarmup, 10)
        else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.MissingCsvPath
        else if (std.mem.eql(u8, arg, "--samples-json"))
            options.samples_json_path = args.next() orelse return error.MissingSamplesJsonPath
        else if (std.mem.startsWith(u8, arg, "--samples-json="))
            options.samples_json_path = arg["--samples-json=".len..]
        else
            return error.UnknownArgument;
    }
    if (options.level > 9 or options.limit == 0)
        return error.InvalidOptions;
    if (options.libdeflate_level) |level| if (level > 12) return error.InvalidOptions;
    try encode_samples.validateCounts(options.iterations, options.rounds, options.warmup);
    if (options.samples_json_path) |path| if (path.len == 0) return error.InvalidOptions;
    return options;
}

fn validateOutputPaths(allocator: std.mem.Allocator, csv_path: ?[]const u8, samples_path: ?[]const u8) !void {
    const csv = csv_path orelse return;
    const samples = samples_path orelse return;
    const normalized_csv = try std.fs.path.resolve(allocator, &.{csv});
    defer allocator.free(normalized_csv);
    const normalized_samples = try std.fs.path.resolve(allocator, &.{samples});
    defer allocator.free(normalized_samples);
    if (std.mem.eql(u8, normalized_csv, normalized_samples)) return error.ConflictingOutputPaths;
}

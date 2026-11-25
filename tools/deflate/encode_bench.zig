//! One-shot raw Deflate encode comparison: Vort levels against zlib and
//! libdeflate on the same prefix. Every wire is decoded by both Vort and
//! libdeflate before timing, and the timed loop uses the ordinary allocating
//! one-shot APIs on all three sides.
const std = @import("std");
const vort = @import("vort");
const zlib = @import("zlib");
const benchmark_provenance = @import("benchmark_provenance");

const c = @cImport({
    @cInclude("libdeflate.h");
});

const max_input_size = 256 * 1024 * 1024;

const Options = struct {
    input_path: ?[]const u8 = null,
    input_name: ?[]const u8 = null,
    level: u4 = 6,
    limit: usize = 128 * 1024,
    iterations: usize = 1,
    rounds: usize = 5,
    csv_path: ?[]const u8 = null,
};

const Sample = struct { elapsed_ns: u64, mix: u64 };

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
    const input = full_input[0..@min(full_input.len, options.limit)];
    if (input.len == 0) return error.InputTooSmall;

    const level: u4 = options.level;
    if (level > 9) return error.InvalidLevel;
    const compressor = c.libdeflate_alloc_compressor(@intCast(level)) orelse return error.ReferenceUnavailable;
    defer c.libdeflate_free_compressor(compressor);

    const wires = Encoders{
        .vort_wire = try vort.encodeRawLevelAlloc(init.gpa, input, level),
        .zlib_wire = try zlibEncodeRaw(init.gpa, input, @intCast(level)),
        .libdeflate_wire = try libdeflateEncode(init.gpa, compressor, input),
    };
    defer init.gpa.free(wires.vort_wire);
    defer init.gpa.free(wires.zlib_wire);
    defer init.gpa.free(wires.libdeflate_wire);

    const decompressor = c.libdeflate_alloc_decompressor() orelse return error.ReferenceUnavailable;
    defer c.libdeflate_free_decompressor(decompressor);
    try verifyWire(init.gpa, decompressor, input, wires.vort_wire);
    try verifyWire(init.gpa, decompressor, input, wires.zlib_wire);
    try verifyWire(init.gpa, decompressor, input, wires.libdeflate_wire);

    const samples = try measureInterleaved(init.io, init.gpa, input, level, options.iterations, options.rounds);

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.print(
        "case,reference_version,level,input_bytes,input_sha256,vort_bytes,zlib_bytes,libdeflate_bytes,vort_ns,zlib_ns,libdeflate_ns,vort_mib_s,zlib_mib_s,libdeflate_mib_s,vort_over_zlib,vort_over_libdeflate,checksum,{s}\n",
        .{benchmark_provenance.csv_columns},
    );
    const input_sha256 = benchmark_provenance.sha256Hex(input);
    try csv.writer.print("{s},{s},{d},{d},{s},{d},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.2},{d:.4},{d:.4},{d}", .{
        name,
        c.LIBDEFLATE_VERSION_STRING,
        level,
        input.len,
        &input_sha256,
        wires.vort_wire.len,
        wires.zlib_wire.len,
        wires.libdeflate_wire.len,
        samples.vort.elapsed_ns,
        samples.zlib.elapsed_ns,
        samples.libdeflate.elapsed_ns,
        mibPerSecond(input.len * options.iterations, samples.vort.elapsed_ns),
        mibPerSecond(input.len * options.iterations, samples.zlib.elapsed_ns),
        mibPerSecond(input.len * options.iterations, samples.libdeflate.elapsed_ns),
        @as(f64, @floatFromInt(samples.zlib.elapsed_ns)) / @as(f64, @floatFromInt(samples.vort.elapsed_ns)),
        @as(f64, @floatFromInt(samples.libdeflate.elapsed_ns)) / @as(f64, @floatFromInt(samples.vort.elapsed_ns)),
        samples.vort.mix ^ samples.zlib.mix ^ samples.libdeflate.mix,
    });
    try provenance.writeCsvFields(&csv.writer);
    try csv.writer.writeByte('\n');

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
    const written = (try vort.decodeRawDeflate(wire, output)).output_written;
    if (written != input.len or !std.mem.eql(u8, input, output)) return error.SizeMismatch;

    var actual: usize = 0;
    if (c.libdeflate_deflate_decompress(
        decompressor,
        wire.ptr,
        wire.len,
        output.ptr,
        output.len,
        &actual,
    ) != c.LIBDEFLATE_SUCCESS or actual != input.len or !std.mem.eql(u8, input, output))
        return error.ReferenceDecodeFailed;
}

fn measureInterleaved(
    io: std.Io,
    allocator: std.mem.Allocator,
    input: []const u8,
    level: u4,
    iterations: usize,
    rounds: usize,
) !struct { vort: Sample, zlib: Sample, libdeflate: Sample } {
    var best_vort: Sample = .{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    var best_zlib: Sample = .{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    var best_libdeflate: Sample = .{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..rounds) |round| {
        // Rotate which encoder runs first so cache and frequency state do not
        // consistently favor one side.
        const order = [_]u8{ @intCast(round % 3), @intCast((round + 1) % 3), @intCast((round + 2) % 3) };
        for (order) |which| {
            const sample = switch (which) {
                0 => try measureVort(io, allocator, input, level, iterations),
                1 => try measureZlib(io, allocator, input, level, iterations),
                else => try measureLibdeflate(io, allocator, input, level, iterations),
            };
            switch (which) {
                0 => {
                    if (sample.elapsed_ns < best_vort.elapsed_ns) best_vort = sample;
                },
                1 => {
                    if (sample.elapsed_ns < best_zlib.elapsed_ns) best_zlib = sample;
                },
                else => {
                    if (sample.elapsed_ns < best_libdeflate.elapsed_ns) best_libdeflate = sample;
                },
            }
        }
    }
    return .{ .vort = best_vort, .zlib = best_zlib, .libdeflate = best_libdeflate };
}

fn measureVort(io: std.Io, allocator: std.mem.Allocator, input: []const u8, level: u4, iterations: usize) !Sample {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try vort.encodeRawLevelAlloc(allocator, input, level);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .mix = mix };
}

fn measureZlib(io: std.Io, allocator: std.mem.Allocator, input: []const u8, level: u4, iterations: usize) !Sample {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try zlibEncodeRaw(allocator, input, @intCast(level));
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .elapsed_ns = elapsedNs(io, start), .mix = mix };
}

fn measureLibdeflate(io: std.Io, allocator: std.mem.Allocator, input: []const u8, level: u4, iterations: usize) !Sample {
    const compressor = c.libdeflate_alloc_compressor(@intCast(level)) orelse return error.ReferenceUnavailable;
    defer c.libdeflate_free_compressor(compressor);
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try libdeflateEncode(allocator, compressor, input);
        mix +%= encoded.len;
        allocator.free(encoded);
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
        else if (std.mem.eql(u8, arg, "--limit"))
            options.limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingIterations, 10)
        else if (std.mem.eql(u8, arg, "--rounds"))
            options.rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingRounds, 10)
        else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.MissingCsvPath
        else
            return error.UnknownArgument;
    }
    if (options.level > 9 or options.limit == 0 or options.iterations == 0 or options.rounds == 0)
        return error.InvalidOptions;
    return options;
}

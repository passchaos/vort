const std = @import("std");
const vort = @import("vort");
const zlib = @import("zlib");
const benchmark_provenance = @import("benchmark_provenance");

const c = @cImport({
    @cInclude("libdeflate.h");
});
const Decompressor = c.libdeflate_decompressor;

const max_file_input_size = 256 * 1024 * 1024;

const Options = struct {
    input_path: ?[]const u8 = null,
    input_name: ?[]const u8 = null,
    level: c_int = 6,
    iterations: usize = 1000,
    rounds: usize = 5,
    csv_path: ?[]const u8 = null,
};

const Sample = struct { elapsed_ns: u64, mix: u64 };

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

    const input = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        input_path,
        init.gpa,
        .limited(max_file_input_size),
    );
    defer init.gpa.free(input);
    if (input.len == 0) return error.InputTooSmall;
    const encoded = try zlibEncodeRaw(init.gpa, input, options.level);
    defer init.gpa.free(encoded);

    const vort_output = try init.gpa.alloc(u8, input.len);
    defer init.gpa.free(vort_output);
    const written = (try vort.decodeRawDeflate(encoded, vort_output)).output_written;
    if (written != input.len or !std.mem.eql(u8, input, vort_output)) return error.SizeMismatch;

    const decompressor = c.libdeflate_alloc_decompressor() orelse return error.ReferenceUnavailable;
    defer c.libdeflate_free_decompressor(decompressor);
    const reference_output = try init.gpa.alloc(u8, input.len);
    defer init.gpa.free(reference_output);
    var actual: usize = 0;
    if (c.libdeflate_deflate_decompress(
        decompressor,
        encoded.ptr,
        encoded.len,
        reference_output.ptr,
        reference_output.len,
        &actual,
    ) != c.LIBDEFLATE_SUCCESS or actual != input.len or !std.mem.eql(u8, input, reference_output))
        return error.ReferenceDecodeFailed;

    const vort_sample = try measureVort(init.io, encoded, vort_output, options.iterations);
    const reference_sample = try measureReference(
        init.io,
        decompressor,
        encoded,
        reference_output,
        options.iterations,
    );

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.print(
        "case,reference_version,level,input_bytes,input_sha256,encoded_bytes,iterations,rounds,vort_ns,reference_ns,vort_mib_s,reference_mib_s,reference_over_vort_time,checksum,{s}\n",
        .{benchmark_provenance.csv_columns},
    );
    const input_sha256 = benchmark_provenance.sha256Hex(input);
    try csv.writer.print("{s},{s},{d},{d},{s},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.4},{d}", .{
        name,
        c.LIBDEFLATE_VERSION_STRING,
        options.level,
        input.len,
        &input_sha256,
        encoded.len,
        options.iterations,
        options.rounds,
        vort_sample.elapsed_ns,
        reference_sample.elapsed_ns,
        mibPerSecond(input.len * options.iterations, vort_sample.elapsed_ns),
        mibPerSecond(input.len * options.iterations, reference_sample.elapsed_ns),
        @as(f64, @floatFromInt(reference_sample.elapsed_ns)) / @as(f64, @floatFromInt(vort_sample.elapsed_ns)),
        vort_sample.mix ^ reference_sample.mix,
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

fn measureVort(
    io: std.Io,
    encoded: []const u8,
    output: []u8,
    iterations: usize,
) !Sample {
    var best: Sample = .{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            mix +%= (try vort.decodeRawDeflate(encoded, output)).output_written;
            if (output.len != 0) mix +%= output[0];
        }
        const elapsed = elapsedNs(io, start);
        if (elapsed < best.elapsed_ns) best = .{ .elapsed_ns = elapsed, .mix = mix };
    }
    return best;
}

fn measureReference(
    io: std.Io,
    decompressor: *Decompressor,
    encoded: []const u8,
    output: []u8,
    iterations: usize,
) !Sample {
    var best: Sample = .{ .elapsed_ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            var actual: usize = 0;
            if (c.libdeflate_deflate_decompress(
                decompressor,
                encoded.ptr,
                encoded.len,
                output.ptr,
                output.len,
                &actual,
            ) != c.LIBDEFLATE_SUCCESS) return error.ReferenceDecodeFailed;
            mix +%= actual;
            if (output.len != 0) mix +%= output[0];
        }
        const elapsed = elapsedNs(io, start);
        if (elapsed < best.elapsed_ns) best = .{ .elapsed_ns = elapsed, .mix = mix };
    }
    return best;
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--input"))
            options.input_path = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--name"))
            options.input_name = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--level"))
            options.level = try std.fmt.parseInt(c_int, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--rounds"))
            options.rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.MissingCorpusPath
        else
            return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.rounds == 0) return error.InvalidBlockPlan;
    return options;
}

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) / (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}

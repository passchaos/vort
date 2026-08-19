const std = @import("std");
const vort = @import("vort");
const zlib = @import("zlib");

const input_len: usize = 256 * 1024;
const block_len: usize = 32 * 1024;
const default_iterations: usize = 32;

const Case = struct { name: []const u8, input: []u8 };
const Row = struct {
    case_name: []const u8,
    mode: []const u8,
    input_bytes: usize,
    output_bytes: usize,
    iterations: usize,
    elapsed_ns: i96,
    mix: u64,

    fn throughput(self: Row) f64 {
        const mib = @as(f64, @floatFromInt(self.input_bytes * self.iterations)) / (1024.0 * 1024.0);
        return mib / (@as(f64, @floatFromInt(self.elapsed_ns)) / @as(f64, std.time.ns_per_s));
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else default_iterations;
    if (args.next() != null or iterations == 0) return error.InvalidBlockPlan;

    const cases = try buildCases(init.gpa);
    defer {
        for (cases) |case| init.gpa.free(case.input);
        init.gpa.free(cases);
    }
    const options = vort.optionsForCompressionLevel(.default);
    var persistent = vort.RawDeflateIncrementalBestEncoder.initWithOptions(init.gpa, .{
        .block_len = block_len,
        .compression = options,
    });
    defer persistent.deinit();

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll("case,mode,input_bytes,output_bytes,iterations,elapsed_s,throughput_mib_s,mix\n");
    for (cases) |case| {
        const compression = compressionForCase(case.name, options);
        persistent.options.compression = compression;
        const rows = [_]Row{
            try measurePersistent(init, &persistent, case, iterations),
            try measureRebuild(init, case, compression, iterations),
            try measureZlib(init, case, iterations),
        };
        for (rows) |result| try writeRow(stdout, result);
    }
    try stdout.flush();
}

fn compressionForCase(name: []const u8, defaults: vort.CompressionOptions) vort.CompressionOptions {
    if (std.mem.eql(u8, name, "binary")) {
        var fastest = vort.optionsForCompressionLevel(.fastest);
        fastest.block_selection = .stored_fixed_dynamic;
        return fastest;
    }
    return defaults;
}

fn writeRow(stdout: *std.Io.Writer, result: Row) !void {
    try stdout.print("{s},{s},{d},{d},{d},{d:.6},{d:.2},{d}\n", .{
        result.case_name,
        result.mode,
        result.input_bytes,
        result.output_bytes,
        result.iterations,
        @as(f64, @floatFromInt(result.elapsed_ns)) / @as(f64, std.time.ns_per_s),
        result.throughput(),
        result.mix,
    });
}

fn measurePersistent(init: std.process.Init, encoder: *vort.RawDeflateIncrementalBestEncoder, case: Case, iterations: usize) !Row {
    var mix: u64 = 0;
    var output_bytes: usize = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        encoder.reset();
        const encoded = try encodeIncremental(init.gpa, encoder, case.input);
        defer init.gpa.free(encoded);
        output_bytes = encoded.len;
        mix +%= vort.crc32(encoded);
    }
    return row(case, "persistent-lazy", iterations, output_bytes, start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), mix);
}

fn measureRebuild(init: std.process.Init, case: Case, options: vort.CompressionOptions, iterations: usize) !Row {
    var mix: u64 = 0;
    var output_bytes: usize = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const encoded = try vort.encodeRawBestSplitAlloc(init.gpa, case.input, block_len, options);
        defer init.gpa.free(encoded);
        output_bytes = encoded.len;
        mix +%= vort.crc32(encoded);
    }
    return row(case, "rebuild-lazy", iterations, output_bytes, start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), mix);
}

fn measureZlib(init: std.process.Init, case: Case, iterations: usize) !Row {
    const bound: usize = @intCast(zlib.compressBound(@intCast(case.input.len)));
    const output = try init.gpa.alloc(u8, bound);
    defer init.gpa.free(output);
    var mix: u64 = 0;
    var output_bytes: usize = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        output_bytes = try zlibRawDeflate(case.input, output);
        mix +%= vort.crc32(output[0..output_bytes]);
    }
    return row(case, zlib.VORT_ZLIB_BENCH_NAME, iterations, output_bytes, start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), mix);
}

fn zlibRawDeflate(input: []const u8, output: []u8) !usize {
    var stream: zlib.z_stream = std.mem.zeroes(zlib.z_stream);
    const init_result = zlib.deflateInit2_(
        &stream,
        6,
        zlib.Z_DEFLATED,
        -15,
        8,
        zlib.Z_DEFAULT_STRATEGY,
        zlib.ZLIB_VERSION,
        @sizeOf(zlib.z_stream),
    );
    if (init_result != zlib.Z_OK) return error.InvalidBlockPlan;
    defer _ = zlib.deflateEnd(&stream);
    stream.next_in = @constCast(input.ptr);
    stream.avail_in = @intCast(input.len);
    stream.next_out = output.ptr;
    stream.avail_out = @intCast(output.len);
    if (zlib.deflate(&stream, zlib.Z_FINISH) != zlib.Z_STREAM_END) return error.OutputTooSmall;
    return @intCast(stream.total_out);
}

fn row(case: Case, mode: []const u8, iterations: usize, output_bytes: usize, elapsed_ns: i96, mix: u64) Row {
    return .{
        .case_name = case.name,
        .mode = mode,
        .input_bytes = case.input.len,
        .output_bytes = output_bytes,
        .iterations = iterations,
        .elapsed_ns = elapsed_ns,
        .mix = mix,
    };
}

fn encodeIncremental(allocator: std.mem.Allocator, encoder: *vort.RawDeflateIncrementalBestEncoder, input: []const u8) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var scratch: [4096]u8 = undefined;
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    return encoded.toOwnedSlice(allocator);
}

fn buildCases(allocator: std.mem.Allocator) ![]Case {
    const cases = try allocator.alloc(Case, 5);
    errdefer allocator.free(cases);
    var built: usize = 0;
    errdefer for (cases[0..built]) |case| allocator.free(case.input);
    cases[0] = .{ .name = "json-log", .input = try repeatedPayload(allocator, input_len, "{\"time\":123456,\"level\":\"info\",\"message\":\"incremental lazy hash chain\",\"request\":\"abcdef0123456789\"}\n") };
    built += 1;
    cases[1] = .{ .name = "source", .input = try repeatedPayload(allocator, input_len, "pub fn update(value: usize) usize { var hash = value; inline for (0..16) |i| hash = (hash ^ i) *% 0x9e3779b1; return hash; }\n") };
    built += 1;
    cases[2] = .{ .name = "repetitive", .input = try repeatedPayload(allocator, input_len, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") };
    built += 1;
    cases[3] = .{ .name = "binary", .input = try binaryPayload(allocator, input_len) };
    built += 1;
    cases[4] = .{ .name = "cross-window", .input = try crossWindowPayload(allocator, input_len) };
    return cases;
}

fn repeatedPayload(allocator: std.mem.Allocator, len: usize, pattern: []const u8) ![]u8 {
    const output = try allocator.alloc(u8, len);
    for (output, 0..) |*byte, i| byte.* = pattern[i % pattern.len];
    return output;
}

fn binaryPayload(allocator: std.mem.Allocator, len: usize) ![]u8 {
    const output = try allocator.alloc(u8, len);
    var random = std.Random.DefaultPrng.init(0x4f0d_9a72_b813_c6e5);
    random.random().bytes(output);
    // Keep a deterministic mixed binary shape rather than pure random noise.
    @memcpy(output[64 * 1024 .. 96 * 1024], output[0 .. 32 * 1024]);
    @memcpy(output[160 * 1024 .. 192 * 1024], output[32 * 1024 .. 64 * 1024]);
    return output;
}

fn crossWindowPayload(allocator: std.mem.Allocator, len: usize) ![]u8 {
    const output = try allocator.alloc(u8, len);
    var random = std.Random.DefaultPrng.init(0x1357_9bdf_2468_ace0);
    random.random().bytes(output[0 .. 32 * 1024]);
    var offset: usize = 32 * 1024;
    while (offset < output.len) : (offset += 32 * 1024) {
        const n = @min(32 * 1024, output.len - offset);
        @memcpy(output[offset..][0..n], output[0..n]);
    }
    return output;
}

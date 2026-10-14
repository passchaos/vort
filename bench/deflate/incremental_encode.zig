const std = @import("std");
const vort = @import("vort");
const zlib = @import("zlib");
const stages = @import("incremental_encode/stages.zig");

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
    const case_filter = args.next();
    const cpu = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else null;
    // Perf needs a production-only loop: the normal matrix also executes the
    // rebuild, competitor, and staged reference paths, which otherwise dwarf
    // the samples from the incremental encoder being investigated.
    const mode_filter = args.next();
    if (args.next() != null or iterations == 0) return error.InvalidBlockPlan;
    if (mode_filter) |mode| {
        if (!std.mem.eql(u8, mode, "persistent-only")) return error.InvalidBlockPlan;
    }
    if (cpu) |index| try pinCurrentThread(index);
    try verifyFullFlushInterop(init.gpa);

    const cases = try buildCases(init.gpa);
    defer {
        for (cases) |case| init.gpa.free(case.input);
        init.gpa.free(cases);
    }
    const options = vort.optionsForCompressionLevel(.default);
    var persistent = vort.RawDeflateIncrementalBestEncoder.initWithOptions(init.gpa, .{
        .block_len = block_len,
        .low_entropy_block_len = input_len,
        .compression = options,
    });
    defer persistent.deinit();

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll("case,mode,input_bytes,output_bytes,iterations,elapsed_s,throughput_mib_s,mix\n");
    var matched_case = case_filter == null;
    for (cases) |case| {
        if (case_filter) |filter| {
            if (!std.mem.eql(u8, case.name, filter)) continue;
            matched_case = true;
        }
        const compression = compressionForCase(case.name, options);
        persistent.options.compression = compression;
        if (mode_filter != null) {
            try writeRow(stdout, try measurePersistent(init, &persistent, case, iterations));
            continue;
        }
        const rows = [_]Row{
            try measurePersistent(init, &persistent, case, iterations),
            try measureRebuild(init, case, compression, iterations),
            try measureZlib(init, case, iterations),
        };
        for (rows) |result| try writeRow(stdout, result);
        if (stages.supports(case.name)) {
            const profile = try measureStages(init, case, compression, iterations);
            if (profile.emit.output_bytes != rows[0].output_bytes) return error.InvalidBlockPlan;
            try writeRow(stdout, profile.matcher);
            try writeRow(stdout, profile.emit);
            try writeRow(stdout, profile.history);
            try writeRow(stdout, profile.pipeline);
            try writeRow(stdout, profile.reset);
        }
    }
    if (!matched_case) return error.InvalidBlockPlan;
    try stdout.flush();
}

fn pinCurrentThread(cpu: usize) !void {
    if (@import("builtin").os.tag != .linux) return error.InvalidBlockPlan;
    const linux = std.os.linux;
    if (cpu >= linux.CPU_SETSIZE * 8) return error.InvalidBlockPlan;
    var set: linux.cpu_set_t = @splat(0);
    const bits = @bitSizeOf(usize);
    set[cpu / bits] = @as(usize, 1) << @intCast(cpu % bits);
    try linux.sched_setaffinity(0, &set);
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
    var scratch: [4096]u8 = undefined;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(init.gpa);
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        encoder.reset();
        encoded.clearRetainingCapacity();
        try encodeIncremental(init.gpa, encoder, case.input, &scratch, &encoded);
        output_bytes = encoded.items.len;
        mix +%= vort.crc32(encoded.items);
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

const StageProfile = struct { matcher: Row, emit: Row, history: Row, pipeline: Row, reset: Row };

fn measureStages(init: std.process.Init, case: Case, compression: vort.CompressionOptions, iterations: usize) !StageProfile {
    const measurement = try stages.measure(init, case.input, compression, block_len, iterations);
    return .{
        .matcher = row(case, "matcher-lazy", iterations, 0, measurement.matcher_ns, measurement.token_mix),
        .emit = row(case, "tree-emit", iterations, measurement.output_bytes, measurement.emit_ns, measurement.token_mix),
        .history = row(case, "history-retain", iterations, 0, measurement.history_ns, measurement.token_mix),
        .pipeline = row(case, "staged-pipeline", iterations, measurement.output_bytes, measurement.pipeline_ns, measurement.token_mix),
        .reset = row(case, "stage-reset", iterations, 0, measurement.reset_ns, measurement.token_mix),
    };
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

/// Keep the benchmark's system-zlib dependency useful as a bidirectional
/// compatibility gate for the incremental encoder's Z_FULL_FLUSH semantics.
/// This runs once before timing and does not contribute to any benchmark row.
fn verifyFullFlushInterop(allocator: std.mem.Allocator) !void {
    const first = "vort and zlib full flush interop first segment\n" ** 16;
    const second = "vort and zlib full flush interop second segment\n" ** 19;
    const expected = first ++ second;

    var vort_encoder = vort.RawDeflateIncrementalBestEncoder.initWithOptions(allocator, .{ .block_len = 97 });
    defer vort_encoder.deinit();
    var vort_wire: std.ArrayList(u8) = .empty;
    defer vort_wire.deinit(allocator);
    var scratch: [13]u8 = undefined;
    try feedVortEncoder(allocator, &vort_encoder, first, &scratch, &vort_wire);
    vort_encoder.fullFlush();
    try drainVortFlush(allocator, &vort_encoder, &scratch, &vort_wire);
    const vort_boundary = vort_wire.items.len;
    try feedVortEncoder(allocator, &vort_encoder, second, &scratch, &vort_wire);
    vort_encoder.finish();
    try finishVortEncoder(allocator, &vort_encoder, &scratch, &vort_wire);

    const zlib_output = try allocator.alloc(u8, expected.len);
    defer allocator.free(zlib_output);
    const zlib_output_len = try zlibRawInflate(vort_wire.items, zlib_output);
    if (!std.mem.eql(u8, expected, zlib_output[0..zlib_output_len])) return error.DecodeMismatch;
    const zlib_suffix_len = try zlibRawInflate(vort_wire.items[vort_boundary..], zlib_output);
    if (!std.mem.eql(u8, second, zlib_output[0..zlib_suffix_len])) return error.DecodeMismatch;

    const zlib_bound: usize = @intCast(zlib.compressBound(@intCast(expected.len)) + 32);
    const zlib_wire = try allocator.alloc(u8, zlib_bound);
    defer allocator.free(zlib_wire);
    const zlib_result = try zlibRawDeflateFullFlush(first, second, zlib_wire);
    const vort_output = try vort.decodeRawDeflateAlloc(allocator, zlib_wire[0..zlib_result.len]);
    defer allocator.free(vort_output);
    if (!std.mem.eql(u8, expected, vort_output)) return error.DecodeMismatch;
    const vort_suffix = try vort.decodeRawDeflateAlloc(allocator, zlib_wire[zlib_result.boundary..zlib_result.len]);
    defer allocator.free(vort_suffix);
    if (!std.mem.eql(u8, second, vort_suffix)) return error.DecodeMismatch;
}

fn feedVortEncoder(
    allocator: std.mem.Allocator,
    encoder: *vort.RawDeflateIncrementalBestEncoder,
    input: []const u8,
    scratch: []u8,
    wire: *std.ArrayList(u8),
) !void {
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], scratch);
        try wire.appendSlice(allocator, scratch[0..result.progress.output_written]);
        offset += result.progress.input_read;
        if (result.progress.input_read == 0 and result.progress.output_written == 0) return error.NoProgress;
    }
}

fn drainVortFlush(
    allocator: std.mem.Allocator,
    encoder: *vort.RawDeflateIncrementalBestEncoder,
    scratch: []u8,
    wire: *std.ArrayList(u8),
) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try wire.appendSlice(allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) return;
        if (result.status == .done) return error.DecodeMismatch;
    }
}

fn finishVortEncoder(
    allocator: std.mem.Allocator,
    encoder: *vort.RawDeflateIncrementalBestEncoder,
    scratch: []u8,
    wire: *std.ArrayList(u8),
) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try wire.appendSlice(allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) return;
    }
}

fn zlibRawInflate(input: []const u8, output: []u8) !usize {
    var stream: zlib.z_stream = std.mem.zeroes(zlib.z_stream);
    if (zlib.inflateInit2_(&stream, -15, zlib.ZLIB_VERSION, @sizeOf(zlib.z_stream)) != zlib.Z_OK)
        return error.ZlibFailure;
    defer _ = zlib.inflateEnd(&stream);
    stream.next_in = @constCast(input.ptr);
    stream.avail_in = @intCast(input.len);
    stream.next_out = output.ptr;
    stream.avail_out = @intCast(output.len);
    if (zlib.inflate(&stream, zlib.Z_FINISH) != zlib.Z_STREAM_END) return error.ZlibFailure;
    if (stream.total_in != input.len) return error.DecodeMismatch;
    return @intCast(stream.total_out);
}

fn zlibRawDeflateFullFlush(first: []const u8, second: []const u8, output: []u8) !struct { len: usize, boundary: usize } {
    var stream: zlib.z_stream = std.mem.zeroes(zlib.z_stream);
    if (zlib.deflateInit2_(
        &stream,
        6,
        zlib.Z_DEFLATED,
        -15,
        8,
        zlib.Z_DEFAULT_STRATEGY,
        zlib.ZLIB_VERSION,
        @sizeOf(zlib.z_stream),
    ) != zlib.Z_OK) return error.ZlibFailure;
    defer _ = zlib.deflateEnd(&stream);
    stream.next_out = output.ptr;
    stream.avail_out = @intCast(output.len);
    stream.next_in = @constCast(first.ptr);
    stream.avail_in = @intCast(first.len);
    if (zlib.deflate(&stream, zlib.Z_FULL_FLUSH) != zlib.Z_OK or stream.avail_in != 0)
        return error.ZlibFailure;
    const boundary: usize = @intCast(stream.total_out);
    stream.next_in = @constCast(second.ptr);
    stream.avail_in = @intCast(second.len);
    if (zlib.deflate(&stream, zlib.Z_FINISH) != zlib.Z_STREAM_END or stream.avail_in != 0)
        return error.ZlibFailure;
    return .{ .len = @intCast(stream.total_out), .boundary = boundary };
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

fn encodeIncremental(
    allocator: std.mem.Allocator,
    encoder: *vort.RawDeflateIncrementalBestEncoder,
    input: []const u8,
    scratch: []u8,
    encoded: *std.ArrayList(u8),
) !void {
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
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

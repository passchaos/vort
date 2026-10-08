const std = @import("std");
const vort = @import("vort");
const zlib = @import("zlib");

const default_iterations: usize = 2_000;
const fragmented_input_len: usize = 7;
const fragmented_output_len: usize = 31;

const Case = struct {
    name: []const u8,
    plain: []u8,
    gzip: []u8,

    fn deinit(self: Case, allocator: std.mem.Allocator) void {
        allocator.free(self.gzip);
        allocator.free(self.plain);
    }
};

const Row = struct {
    case_name: []const u8,
    implementation: []const u8,
    chunking: []const u8,
    input_bytes: usize,
    output_bytes: usize,
    input_chunk: usize,
    output_chunk: usize,
    iterations: usize,
    elapsed_ns: i96,
    mix: u64,

    fn nsPerDecode(self: Row) i96 {
        return @divTrunc(self.elapsed_ns, @as(i96, @intCast(self.iterations)));
    }

    fn throughput(self: Row) f64 {
        const bytes = @as(f64, @floatFromInt(self.output_bytes * self.iterations));
        return bytes / (1024.0 * 1024.0) /
            (@as(f64, @floatFromInt(self.elapsed_ns)) / std.time.ns_per_s);
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        default_iterations;
    if (iterations == 0 or args.next() != null) return error.InvalidArgument;

    var cases = try buildCases(init.gpa);
    defer {
        for (&cases) |case| case.deinit(init.gpa);
    }

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(
        "case,implementation,chunking,input_bytes,output_bytes,input_chunk," ++
            "output_chunk,iterations,elapsed_ns,ns_per_decode," ++
            "throughput_mib_s,mix\n",
    );
    for (cases) |case| {
        const modes = [_]struct {
            name: []const u8,
            input_chunk: usize,
            output_chunk: usize,
        }{
            .{
                .name = "full",
                .input_chunk = case.gzip.len,
                .output_chunk = case.plain.len + 1,
            },
            .{
                .name = "fragmented-7x31",
                .input_chunk = fragmented_input_len,
                .output_chunk = fragmented_output_len,
            },
        };
        for (modes) |mode| {
            const vort_row = try measureVort(
                init,
                case,
                mode.name,
                mode.input_chunk,
                mode.output_chunk,
                iterations,
            );
            const zlib_row = try measureZlib(
                init,
                case,
                mode.name,
                mode.input_chunk,
                mode.output_chunk,
                iterations,
            );
            if (vort_row.mix != zlib_row.mix) return error.DecodeMismatch;
            try writeRow(stdout, vort_row);
            try writeRow(stdout, zlib_row);
        }
    }
    try stdout.flush();
}

fn measureVort(
    init: std.process.Init,
    case: Case,
    chunking: []const u8,
    input_chunk: usize,
    output_chunk: usize,
    iterations: usize,
) !Row {
    var history: [32 * 1024]u8 = undefined;
    var decoder = try vort.GzipIncrementalDecoder.init(.{
        .max_output_len = case.plain.len,
        .allow_concatenated = true,
    }, &history);
    const output = try init.gpa.alloc(u8, case.plain.len + 1);
    defer init.gpa.free(output);

    const warmup_len = try decodeVort(
        &decoder,
        case.gzip,
        output,
        input_chunk,
        output_chunk,
    );
    try verifyDecoded(case, output[0..warmup_len]);

    var mix: u64 = 0;
    const started = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |iteration| {
        const decoded_len = try decodeVort(
            &decoder,
            case.gzip,
            output,
            input_chunk,
            output_chunk,
        );
        if (decoded_len != case.plain.len) return error.DecodeMismatch;
        mix +%= output[iteration % decoded_len];
    }
    const elapsed = started.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    try verifyDecoded(case, output[0..case.plain.len]);
    return makeRow(
        case,
        "vort",
        chunking,
        input_chunk,
        output_chunk,
        iterations,
        elapsed,
        mix,
    );
}

fn decodeVort(
    decoder: *vort.GzipIncrementalDecoder,
    input: []const u8,
    output: []u8,
    input_chunk: usize,
    output_chunk: usize,
) !usize {
    decoder.reset();
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const input_end = @min(input.len, input_offset + input_chunk);
        const output_end = @min(output.len, output_offset + output_chunk);
        const step = try decoder.step(
            input[input_offset..input_end],
            output[output_offset..output_end],
        );
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
        if (step.status == .done) break;
        if (step.status == .need_input and input_offset == input.len) {
            try decoder.finish();
            break;
        }
        if (step.progress.input_read == 0 and
            step.progress.output_written == 0)
        {
            return error.NoProgress;
        }
    }
    if (input_offset != input.len) return error.DecodeMismatch;
    return output_offset;
}

fn measureZlib(
    init: std.process.Init,
    case: Case,
    chunking: []const u8,
    input_chunk: usize,
    output_chunk: usize,
    iterations: usize,
) !Row {
    var stream: zlib.z_stream = std.mem.zeroes(zlib.z_stream);
    if (zlib.inflateInit2_(
        &stream,
        15 + 16,
        zlib.ZLIB_VERSION,
        @sizeOf(zlib.z_stream),
    ) != zlib.Z_OK) return error.ZlibFailure;
    defer _ = zlib.inflateEnd(&stream);

    const output = try init.gpa.alloc(u8, case.plain.len + 1);
    defer init.gpa.free(output);
    const warmup_len = try decodeZlib(
        &stream,
        case.gzip,
        output,
        input_chunk,
        output_chunk,
    );
    try verifyDecoded(case, output[0..warmup_len]);

    var mix: u64 = 0;
    const started = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |iteration| {
        const decoded_len = try decodeZlib(
            &stream,
            case.gzip,
            output,
            input_chunk,
            output_chunk,
        );
        if (decoded_len != case.plain.len) return error.DecodeMismatch;
        mix +%= output[iteration % decoded_len];
    }
    const elapsed = started.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    try verifyDecoded(case, output[0..case.plain.len]);
    return makeRow(
        case,
        zlib.VORT_ZLIB_BENCH_NAME,
        chunking,
        input_chunk,
        output_chunk,
        iterations,
        elapsed,
        mix,
    );
}

fn decodeZlib(
    stream: *zlib.z_stream,
    input: []const u8,
    output: []u8,
    input_chunk: usize,
    output_chunk: usize,
) !usize {
    if (zlib.inflateReset(stream) != zlib.Z_OK) return error.ZlibFailure;
    stream.next_in = null;
    stream.avail_in = 0;
    stream.next_out = null;
    stream.avail_out = 0;
    var input_supplied: usize = 0;
    while (true) {
        if (stream.avail_in == 0 and input_supplied < input.len) {
            const n = @min(input_chunk, input.len - input_supplied);
            stream.next_in = @constCast(input[input_supplied..].ptr);
            stream.avail_in = @intCast(n);
            input_supplied += n;
        }
        if (stream.avail_out == 0) {
            const output_offset: usize = @intCast(stream.total_out);
            if (output_offset == output.len) return error.OutputTooSmall;
            const n = @min(output_chunk, output.len - output_offset);
            stream.next_out = output[output_offset..].ptr;
            stream.avail_out = @intCast(n);
        }
        const before_in = stream.total_in;
        const before_out = stream.total_out;
        const status = zlib.inflate(stream, zlib.Z_NO_FLUSH);
        if (status == zlib.Z_STREAM_END) break;
        if (status != zlib.Z_OK) return error.ZlibFailure;
        if (stream.total_in == before_in and stream.total_out == before_out)
            return error.NoProgress;
    }
    if (stream.total_in != input.len) return error.DecodeMismatch;
    return @intCast(stream.total_out);
}

fn writeRow(writer: *std.Io.Writer, row: Row) !void {
    try writer.print(
        "{s},{s},{s},{d},{d},{d},{d},{d},{d},{d},{d:.2},{d}\n",
        .{
            row.case_name,
            row.implementation,
            row.chunking,
            row.input_bytes,
            row.output_bytes,
            row.input_chunk,
            row.output_chunk,
            row.iterations,
            row.elapsed_ns,
            row.nsPerDecode(),
            row.throughput(),
            row.mix,
        },
    );
}

fn makeRow(
    case: Case,
    implementation: []const u8,
    chunking: []const u8,
    input_chunk: usize,
    output_chunk: usize,
    iterations: usize,
    elapsed_ns: i96,
    mix: u64,
) Row {
    return .{
        .case_name = case.name,
        .implementation = implementation,
        .chunking = chunking,
        .input_bytes = case.gzip.len,
        .output_bytes = case.plain.len,
        .input_chunk = input_chunk,
        .output_chunk = output_chunk,
        .iterations = iterations,
        .elapsed_ns = elapsed_ns,
        .mix = mix,
    };
}

fn verifyDecoded(case: Case, decoded: []const u8) !void {
    if (!std.mem.eql(u8, decoded, case.plain)) return error.DecodeMismatch;
}

fn buildCases(allocator: std.mem.Allocator) ![3]Case {
    var cases: [3]Case = undefined;
    var built: usize = 0;
    errdefer for (cases[0..built]) |case| case.deinit(allocator);
    cases[0] = try repeatedCase(
        allocator,
        "http-4k",
        4 * 1024,
        "content-encoding=bounded;cache=vort;",
    );
    built += 1;
    cases[1] = try repeatedCase(
        allocator,
        "json-32k",
        32 * 1024,
        "{\"time\":123456,\"level\":\"info\",\"message\":\"incremental decode\"}\n",
    );
    built += 1;
    cases[2] = try binaryCase(allocator, "binary-64k", 64 * 1024);
    return cases;
}

fn repeatedCase(
    allocator: std.mem.Allocator,
    name: []const u8,
    len: usize,
    pattern: []const u8,
) !Case {
    const plain = try allocator.alloc(u8, len);
    errdefer allocator.free(plain);
    for (plain, 0..) |*byte, index| byte.* = pattern[index % pattern.len];
    return .{
        .name = name,
        .plain = plain,
        .gzip = try vort.encodeGzipBestAlloc(
            allocator,
            plain,
            vort.optionsForCompressionLevel(.default),
        ),
    };
}

fn binaryCase(allocator: std.mem.Allocator, name: []const u8, len: usize) !Case {
    const plain = try allocator.alloc(u8, len);
    errdefer allocator.free(plain);
    var random = std.Random.DefaultPrng.init(0x4f0d_9a72_b813_c6e5);
    random.random().bytes(plain);
    @memcpy(plain[len / 2 ..][0 .. len / 4], plain[0 .. len / 4]);
    return .{
        .name = name,
        .plain = plain,
        .gzip = try vort.encodeGzipBestAlloc(
            allocator,
            plain,
            vort.optionsForCompressionLevel(.default),
        ),
    };
}

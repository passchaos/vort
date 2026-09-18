const std = @import("std");
const vort = @import("vort");
const benchmark_provenance = @import("benchmark_provenance");

const Options = struct {
    iterations: usize = 2,
    rounds: usize = 5,
    input_bytes: usize = 8 * 1024 * 1024,
    frame_size: usize = 256 * 1024,
    csv_path: ?[]const u8 = null,
};

const Sample = struct {
    ns: u64,
    mix: usize,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    const provenance = try benchmark_provenance.capture(init.io, init.gpa, init.minimal.args, "caller-worker-count");
    defer provenance.deinit(init.gpa);

    const payload = try init.gpa.alloc(u8, options.input_bytes);
    defer init.gpa.free(payload);
    fillPayload(payload);
    const encode_options = vort.ZstdNativeSeekableOptions{
        .frame_size = options.frame_size,
        .frame_options = .{ .selection = .fast_compressed, .content_checksum = false },
        .seek_checksums = true,
    };
    const serial_wire = try vort.zstdEncodeNativeSeekableStreamAlloc(init.gpa, payload, encode_options);
    defer init.gpa.free(serial_wire);
    const range_start = payload.len / 2 -| 1024;
    const range_len = @min(@as(usize, 4096), payload.len - range_start);
    const range = try vort.zstdDecodeNativeSeekableRangeAlloc(init.gpa, serial_wire, range_start, range_len);
    defer init.gpa.free(range);
    if (!std.mem.eql(u8, range, payload[range_start..][0..range_len])) return error.SizeMismatch;

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.print("workers,input_bytes,input_sha256,frame_size,frame_count,encoded_bytes,iterations,rounds,parallel_ns,serial_ns,parallel_mib_s,serial_mib_s,speedup,parallel_checksum,serial_checksum,{s}\n", .{benchmark_provenance.csv_columns});
    const input_sha256 = benchmark_provenance.sha256Hex(payload);
    const frame_count = try std.math.divCeil(usize, payload.len, options.frame_size);
    for ([_]usize{ 1, 2, 4, 8 }) |workers| {
        const candidate = try vort.zstdEncodeNativeSeekableStreamParallelAlloc(init.gpa, payload, encode_options, workers);
        defer init.gpa.free(candidate);
        if (!std.mem.eql(u8, serial_wire, candidate)) return error.SizeMismatch;

        const samples = try measureInterleaved(init.io, init.gpa, payload, encode_options, workers, options.iterations, options.rounds);
        const total_bytes = payload.len * options.iterations;
        const parallel_rate = mibPerSecond(total_bytes, samples.parallel.ns);
        const serial_rate = mibPerSecond(total_bytes, samples.serial.ns);
        try csv.writer.print("{d},{d},{s},{d},{d},{d},{d},{d},{d},{d},{d:.6},{d:.6},{d:.8},{d},{d}", .{
            workers,
            payload.len,
            &input_sha256,
            options.frame_size,
            frame_count,
            serial_wire.len,
            options.iterations,
            options.rounds,
            samples.parallel.ns,
            samples.serial.ns,
            parallel_rate,
            serial_rate,
            @as(f64, @floatFromInt(samples.serial.ns)) / @as(f64, @floatFromInt(samples.parallel.ns)),
            samples.parallel.mix,
            samples.serial.mix,
        });
        try provenance.writeCsvFields(&csv.writer);
        try csv.writer.writeByte('\n');
    }

    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn fillPayload(payload: []u8) void {
    var state: u32 = 0x6a09_e667;
    for (payload, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 128 < 96)
            @truncate(index *% 17 +% index / 4096)
        else
            @truncate(state >> 16);
    }
}

fn measureInterleaved(
    io: std.Io,
    allocator: std.mem.Allocator,
    payload: []const u8,
    options: vort.ZstdNativeSeekableOptions,
    workers: usize,
    iterations: usize,
    rounds: usize,
) !struct { parallel: Sample, serial: Sample } {
    var best_parallel = Sample{ .ns = std.math.maxInt(u64), .mix = 0 };
    var best_serial = best_parallel;
    for (0..rounds) |round| {
        const parallel_first = round & 1 == 0;
        const first = if (parallel_first)
            try measure(io, allocator, payload, options, workers, iterations)
        else
            try measure(io, allocator, payload, options, 1, iterations);
        const second = if (parallel_first)
            try measure(io, allocator, payload, options, 1, iterations)
        else
            try measure(io, allocator, payload, options, workers, iterations);
        const parallel_sample = if (parallel_first) first else second;
        const serial_sample = if (parallel_first) second else first;
        if (parallel_sample.ns < best_parallel.ns) best_parallel = parallel_sample;
        if (serial_sample.ns < best_serial.ns) best_serial = serial_sample;
    }
    return .{ .parallel = best_parallel, .serial = best_serial };
}

fn measure(
    io: std.Io,
    allocator: std.mem.Allocator,
    payload: []const u8,
    options: vort.ZstdNativeSeekableOptions,
    workers: usize,
    iterations: usize,
) !Sample {
    var mix: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try vort.zstdEncodeNativeSeekableStreamParallelAlloc(allocator, payload, options, workers);
        mix +%= encoded.len;
        mix +%= encoded[encoded.len / 2];
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) / (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--rounds"))
            options.rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--input-bytes"))
            options.input_bytes = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--frame-size"))
            options.frame_size = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.MissingCorpusPath
        else
            return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.rounds == 0 or options.input_bytes == 0 or options.frame_size == 0)
        return error.InvalidBlockPlan;
    const frame_count = try std.math.divCeil(usize, options.input_bytes, options.frame_size);
    if (frame_count < 8) return error.InvalidBlockPlan;
    return options;
}

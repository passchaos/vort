const std = @import("std");
const vort = @import("vort");

const Options = struct {
    iterations: usize = 1,
    rounds: usize = 5,
    csv_path: ?[]const u8 = null,
};

const Sample = struct { ns: u64, mix: usize };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);

    const payload = try init.gpa.alloc(u8, 129 * 1024);
    defer init.gpa.free(payload);
    var state: u32 = @truncate(0x9e37_79b9 +% 129 *% 0x10001 +% 16 *% 0x101 +% 23);
    for (payload, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(state >> 16);
    }
    const copy_len = payload.len / 4;
    @memcpy(payload[payload.len - copy_len ..], payload[payload.len / 4 ..][0..copy_len]);

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("level,input_bytes,encoded_bytes,iterations,rounds,parallel_ns,serial_ns,speedup,parallel_checksum,serial_checksum\n");
    for ([_]c_int{ 1, 2, 3 }) |level| {
        const parallel = try vort.zstdEncodeFrameWithLevelAlloc(init.gpa, payload, level);
        defer init.gpa.free(parallel);
        const serial = try encodeSerial(init.gpa, payload, level);
        defer init.gpa.free(serial);
        if (!std.mem.eql(u8, parallel, serial)) return error.SizeMismatch;
        const decoded = try init.gpa.alloc(u8, payload.len);
        defer init.gpa.free(decoded);
        if (try vort.zstdDecodeFrameInto(parallel, decoded) != payload.len or !std.mem.eql(u8, payload, decoded))
            return error.SizeMismatch;

        const samples = try measureInterleaved(init.io, init.gpa, payload, level, options);
        try csv.writer.print("{d},{d},{d},{d},{d},{d},{d},{d:.8},{d},{d}\n", .{
            level,               payload.len,       parallel.len,                                                                              options.iterations,   options.rounds,
            samples.parallel.ns, samples.serial.ns, @as(f64, @floatFromInt(samples.serial.ns)) / @as(f64, @floatFromInt(samples.parallel.ns)), samples.parallel.mix, samples.serial.mix,
        });
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

fn encodeSerial(allocator: std.mem.Allocator, input: []const u8, level: c_int) ![]u8 {
    const policy = try vort.zstd.nativeEncodeLevelDiagnostics(level, .{});
    var best = try vort.zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, policy.primary_options);
    errdefer allocator.free(best.frame);
    const larger_block_size = policy.adaptive_block_sizes[1];
    var adaptive_competitive = false;
    if (larger_block_size < input.len and larger_block_size != policy.primary_options.block_size_max) {
        var split_options = policy.primary_options;
        split_options.block_size_max = larger_block_size;
        split_options.match_search_budget = policy.adaptive_match_search_budget;
        split_options.rep_beam_search = false;
        const candidate = try vort.zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, split_options);
        adaptive_competitive = if (level >= 2 and level <= 5)
            candidate.frame.len <= std.math.add(usize, best.frame.len, 256) catch std.math.maxInt(usize)
        else
            candidate.frame.len <= best.frame.len;
        if (candidate.frame.len < best.frame.len) {
            allocator.free(best.frame);
            best = candidate;
        } else allocator.free(candidate.frame);
    }
    const smaller_block_size = policy.adaptive_block_sizes[0];
    if (adaptive_competitive and smaller_block_size < input.len and smaller_block_size != policy.primary_options.block_size_max) {
        var split_options = policy.primary_options;
        split_options.block_size_max = smaller_block_size;
        split_options.match_search_budget = policy.adaptive_match_search_budget;
        split_options.rep_beam_search = false;
        const candidate = try vort.zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, split_options);
        if (candidate.frame.len < best.frame.len) {
            allocator.free(best.frame);
            best = candidate;
        } else allocator.free(candidate.frame);
    }
    return best.frame;
}

fn measureInterleaved(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, level: c_int, options: Options) !struct { parallel: Sample, serial: Sample } {
    var best_parallel = Sample{ .ns = std.math.maxInt(u64), .mix = 0 };
    var best_serial = best_parallel;
    for (0..options.rounds) |round| {
        const parallel_first = round & 1 == 0;
        const first = if (parallel_first) try measureParallel(io, allocator, payload, level, options.iterations) else try measureSerial(io, allocator, payload, level, options.iterations);
        const second = if (parallel_first) try measureSerial(io, allocator, payload, level, options.iterations) else try measureParallel(io, allocator, payload, level, options.iterations);
        const parallel_sample = if (parallel_first) first else second;
        const serial_sample = if (parallel_first) second else first;
        if (parallel_sample.ns < best_parallel.ns) best_parallel = parallel_sample;
        if (serial_sample.ns < best_serial.ns) best_serial = serial_sample;
    }
    return .{ .parallel = best_parallel, .serial = best_serial };
}

fn measureParallel(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, level: c_int, iterations: usize) !Sample {
    var mix: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try vort.zstdEncodeFrameWithLevelAlloc(allocator, payload, level);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn measureSerial(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, level: c_int, iterations: usize) !Sample {
    var mix: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try encodeSerial(allocator, payload, level);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations"))
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

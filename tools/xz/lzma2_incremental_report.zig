const std = @import("std");
const vort = @import("vort");

const chunk_len: usize = 65_536;
const dictionary_len: usize = 4096;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |value|
        try std.fmt.parseInt(usize, value, 10)
    else
        3;
    if (iterations == 0 or args.next() != null) return error.InvalidArguments;

    const input = try makeBoundaryCorpus(init.gpa);
    defer init.gpa.free(input);
    const persistent = try encodePersistent(init.gpa, input);
    defer init.gpa.free(persistent);
    const reset = try encodeResetPerChunk(init.gpa, input);
    defer init.gpa.free(reset);
    if (persistent.len >= reset.len) return error.PersistentStateDidNotImproveSize;

    const persistent_ns = try measure(init, input, iterations, true);
    const reset_ns = try measure(init, input, iterations, false);
    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        "lzma2_incremental=input:{d} persistent:{d} reset:{d} savings:{d} " ++
            "persistent_mib_s:{d:.2} reset_mib_s:{d:.2} speed_ratio:{d:.3}\n",
        .{
            input.len,
            persistent.len,
            reset.len,
            reset.len - persistent.len,
            mibPerSecond(input.len * iterations, persistent_ns),
            mibPerSecond(input.len * iterations, reset_ns),
            @as(f64, @floatFromInt(reset_ns)) /
                @as(f64, @floatFromInt(persistent_ns)),
        },
    );
    try stdout.flush();
}

fn makeBoundaryCorpus(allocator: std.mem.Allocator) ![]u8 {
    const input = try allocator.alloc(u8, chunk_len * 4);
    var random: u32 = 0x9e37_79b9;
    for (input[0..chunk_len]) |*byte| {
        random = random *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(random >> 24);
    }
    for (1..4) |chunk_index| {
        const start = chunk_index * chunk_len;
        const previous_end = start;
        @memcpy(
            input[start..][0..dictionary_len],
            input[previous_end - dictionary_len .. previous_end],
        );
        for (input[start + dictionary_len .. start + chunk_len]) |*byte| {
            random = random *% 1_664_525 +% 1_013_904_223;
            byte.* = @truncate(random >> 24);
        }
    }
    return input;
}

fn encodePersistent(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var encoder = try vort.RawLzma2IncrementalEncoder.initExactSize(
        allocator,
        .{},
        input.len,
    );
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var input_offset: usize = 0;
    var output: [32 * 1024]u8 = undefined;
    while (input_offset < input.len) {
        const stepped = try encoder.step(input[input_offset..], &output);
        input_offset += stepped.progress.input_read;
        try encoded.appendSlice(allocator, output[0..stepped.progress.output_written]);
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
            return error.EncoderMadeNoProgress;
    }
    encoder.finish();
    while (true) {
        const stepped = try encoder.step(&.{}, &output);
        try encoded.appendSlice(allocator, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (stepped.progress.output_written == 0) return error.EncoderMadeNoProgress;
    }
    return encoded.toOwnedSlice(allocator);
}

fn encodeResetPerChunk(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        const end = @min(input.len, offset + chunk_len);
        _ = try vort.encodeRawLzma2Append(allocator, &encoded, input[offset..end]);
        if (encoded.items.len == 0 or encoded.items[encoded.items.len - 1] != 0)
            return error.InvalidLzma2Payload;
        encoded.items.len -= 1;
        offset = end;
    }
    try encoded.append(allocator, 0);
    return encoded.toOwnedSlice(allocator);
}

fn measure(
    init: std.process.Init,
    input: []const u8,
    iterations: usize,
    persistent: bool,
) !u64 {
    const start = std.Io.Clock.awake.now(init.io);
    var checksum: usize = 0;
    for (0..iterations) |_| {
        const encoded = if (persistent)
            try encodePersistent(init.gpa, input)
        else
            try encodeResetPerChunk(init.gpa, input);
        checksum +%= encoded.len;
        init.gpa.free(encoded);
    }
    std.mem.doNotOptimizeAway(checksum);
    return std.math.cast(
        u64,
        start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(),
    ) orelse error.InvalidElapsedTime;
}

fn mibPerSecond(bytes: usize, elapsed_ns: u64) f64 {
    if (elapsed_ns == 0) return 0;
    const mib = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0);
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) /
        @as(f64, std.time.ns_per_s);
    return mib / seconds;
}

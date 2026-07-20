const std = @import("std");
const vort = @import("vort");

const Row = struct {
    name: []const u8,
    throughput_mib_s: f64,
    elapsed_s: f64,
    digest_mix: u64,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var csv_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        return error.InvalidBlockPlan;
    }

    const len = 1 << 20;
    const iterations = 128;
    const input = try init.gpa.alloc(u8, len);
    defer init.gpa.free(input);

    for (input, 0..) |*byte, i| {
        byte.* = @truncate((i * 251 + 19) & 0xff);
    }

    const rows = [_]Row{
        measure("adler32", input, iterations, vort.adler32, init.io),
        measure("crc32-scalar", input, iterations, vort.crc32, init.io),
        measure("crc32-slice4", input, iterations, vort.crc32Slice4, init.io),
        measure("crc32-slice8", input, iterations, vort.crc32Slice8, init.io),
        measure("crc32-slice16", input, iterations, vort.crc32Slice16, init.io),
        measure("crc32-slice32", input, iterations, vort.crc32Slice32, init.io),
        measureCrc32Slice32Segmented("crc32-slice32-seg64", input, iterations, 64, init.io),
        measureCrc32Slice32Segmented("crc32-slice32-seg256", input, iterations, 256, init.io),
        measureCrc32Slice32Segmented("crc32-slice32-seg1024", input, iterations, 1024, init.io),
        measureCrc32Slice32Segmented("crc32-slice32-seg4096", input, iterations, 4096, init.io),
        measureCrc32Slice32SpanThreshold("crc32-slice32-span-threshold256", input, iterations, 256, init.io),
        measureCrc32Slice32SpanThreshold("crc32-slice32-span-threshold1024", input, iterations, 1024, init.io),
        measure("crc32-best", input, iterations, vort.crc32Best, init.io),
        measure("crc32c-scalar", input, iterations, vort.crc32c, init.io),
        measure("crc32c-slice8", input, iterations, vort.crc32cSlice8, init.io),
        measure("crc32c-slice16", input, iterations, vort.crc32cSlice16, init.io),
        measure("crc32c-slice32", input, iterations, vort.crc32cSlice32, init.io),
        measure("crc32c-best", input, iterations, vort.crc32cBest, init.io),
    };

    var mix: u64 = 0;
    var elapsed_s: f64 = 0;
    for (rows) |row| {
        mix +%= row.digest_mix;
        elapsed_s += row.elapsed_s;
    }
    const total_mib = (@as(f64, @floatFromInt(len)) * @as(f64, @floatFromInt(iterations)) * @as(f64, @floatFromInt(rows.len))) / (1024.0 * 1024.0);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("checksum smoke: bytes={d} iterations={d} streams={d} crc32_dispatch={s} crc32c_dispatch={s} elapsed_s={d:.6} throughput_mib_s={d:.2} mix={d}\n", .{
        len,
        iterations,
        rows.len,
        @tagName(vort.checksum.bestCrc32Dispatch()),
        @tagName(vort.checksum.bestCrc32CDispatch()),
        elapsed_s,
        total_mib / elapsed_s,
        mix,
    });
    try stdout.writeAll("algorithm,bytes,iterations,elapsed_s,throughput_mib_s,mix\n");
    for (rows) |row| {
        try writeCsvRow(stdout, row, len, iterations);
    }
    try stdout.flush();

    if (csv_path) |path| {
        var csv = std.Io.Writer.Allocating.init(init.gpa);
        defer csv.deinit();
        try csv.writer.writeAll("algorithm,bytes,iterations,elapsed_s,throughput_mib_s,mix\n");
        for (rows) |row| try writeCsvRow(&csv.writer, row, len, iterations);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    }
}

fn writeCsvRow(writer: *std.Io.Writer, row: Row, len: usize, iterations: usize) !void {
    try writer.print("{s},{d},{d},{d:.6},{d:.2},{d}\n", .{
        row.name,
        len,
        iterations,
        row.elapsed_s,
        row.throughput_mib_s,
        row.digest_mix,
    });
}

fn measure(name: []const u8, input: []u8, iterations: usize, comptime hash: fn ([]const u8) u32, io: std.Io) Row {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |iteration| {
        const index = (iteration * 4099) & (input.len - 1);
        input[index] +%= @truncate(iteration + 1);
        const digest = hash(input);
        std.mem.doNotOptimizeAway(digest);
        mix +%= digest;
        input[index] -%= @truncate(iteration + 1);
    }
    const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    const elapsed_ns: f64 = @floatFromInt(elapsed_ns_signed);
    const elapsed_s = elapsed_ns / @as(f64, std.time.ns_per_s);
    const mib = (@as(f64, @floatFromInt(input.len)) * @as(f64, @floatFromInt(iterations))) / (1024.0 * 1024.0);
    return .{
        .name = name,
        .throughput_mib_s = mib / elapsed_s,
        .elapsed_s = elapsed_s,
        .digest_mix = mix,
    };
}

fn measureCrc32Slice32Segmented(name: []const u8, input: []u8, iterations: usize, segment_len: usize, io: std.Io) Row {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |iteration| {
        const index = (iteration * 4099) & (input.len - 1);
        input[index] +%= @truncate(iteration + 1);

        var crc = vort.checksum.Crc32Slice32.init();
        var offset: usize = 0;
        while (offset < input.len) {
            const n = @min(segment_len, input.len - offset);
            crc.update(input[offset..][0..n]);
            offset += n;
        }
        const digest = crc.digest();
        std.mem.doNotOptimizeAway(digest);
        mix +%= digest;
        input[index] -%= @truncate(iteration + 1);
    }
    const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    const elapsed_ns: f64 = @floatFromInt(elapsed_ns_signed);
    const elapsed_s = elapsed_ns / @as(f64, std.time.ns_per_s);
    const mib = (@as(f64, @floatFromInt(input.len)) * @as(f64, @floatFromInt(iterations))) / (1024.0 * 1024.0);
    return .{
        .name = name,
        .throughput_mib_s = mib / elapsed_s,
        .elapsed_s = elapsed_s,
        .digest_mix = mix,
    };
}

const decoded_span_pattern = [_]usize{
    1,  1,  2,  3,   5,   8,   13, 21,
    34, 55, 89, 144, 233, 377, 8,  16,
    24, 32, 48, 64,  96,  128,
};

fn measureCrc32Slice32SpanThreshold(name: []const u8, input: []u8, iterations: usize, threshold: usize, io: std.Io) Row {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |iteration| {
        const index = (iteration * 4099) & (input.len - 1);
        input[index] +%= @truncate(iteration + 1);

        var crc = vort.checksum.Crc32Slice32.init();
        var pending_start: usize = 0;
        var pending_len: usize = 0;
        var offset: usize = 0;
        var pattern_index: usize = 0;
        while (offset < input.len) {
            const span_len = @min(decoded_span_pattern[pattern_index], input.len - offset);
            pending_len += span_len;
            offset += span_len;
            pattern_index = (pattern_index + 1) % decoded_span_pattern.len;

            // Benchmark-only model for a future gzip decoded-span CRC accumulator:
            // production inflate may emit many tiny literal/match spans, but CRC
            // should be updated only after enough adjacent decoded bytes have
            // accumulated to amortize the call overhead. The final digest is still
            // byte-exact because pending spans are contiguous slices of `input`.
            if (pending_len >= threshold) {
                crc.update(input[pending_start..][0..pending_len]);
                pending_start = offset;
                pending_len = 0;
            }
        }
        if (pending_len != 0) crc.update(input[pending_start..][0..pending_len]);

        const digest = crc.digest();
        std.mem.doNotOptimizeAway(digest);
        mix +%= digest;
        input[index] -%= @truncate(iteration + 1);
    }
    const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    const elapsed_ns: f64 = @floatFromInt(elapsed_ns_signed);
    const elapsed_s = elapsed_ns / @as(f64, std.time.ns_per_s);
    const mib = (@as(f64, @floatFromInt(input.len)) * @as(f64, @floatFromInt(iterations))) / (1024.0 * 1024.0);
    return .{
        .name = name,
        .throughput_mib_s = mib / elapsed_s,
        .elapsed_s = elapsed_s,
        .digest_mix = mix,
    };
}

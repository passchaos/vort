const std = @import("std");
const vort = @import("vort");

const ReaderKind = enum {
    buffered,
    chunked_4096,
    span_4096,
    chunked_64,
    span_64,
    chunked_1,
    span_1,

    fn label(self: ReaderKind) []const u8 {
        return switch (self) {
            .buffered => "buffered",
            .chunked_4096 => "chunked_4096",
            .span_4096 => "span_4096",
            .chunked_64 => "chunked_64",
            .span_64 => "span_64",
            .chunked_1 => "chunked_1",
            .span_1 => "span_1",
        };
    }
};

const CaseSpec = struct {
    name: []const u8,
    bits: u6,
    reads_per_iter: usize,
};

const MixedCaseSpec = struct {
    name: []const u8,
    pattern: []const u6,
    reads_per_iter: usize,
};

const Row = struct {
    case: []const u8,
    reader: []const u8,
    bits: u6,
    reads_per_iter: usize,
    iterations: usize,
    input_bytes: usize,
    elapsed_ns: i128,
    reads_per_s: f64,
    mib_per_s: f64,
    checksum: u64,
};

const cases = [_]CaseSpec{
    .{ .name = "extra-1", .bits = 1, .reads_per_iter = 128 * 1024 },
    .{ .name = "extra-3", .bits = 3, .reads_per_iter = 128 * 1024 },
    .{ .name = "extra-5", .bits = 5, .reads_per_iter = 96 * 1024 },
    .{ .name = "extra-9", .bits = 9, .reads_per_iter = 64 * 1024 },
    .{ .name = "extra-13", .bits = 13, .reads_per_iter = 48 * 1024 },
};

// Width distributions copied from the ReleaseFast dynamic profile rows for
// README.md and docs/roadmap.md. They preserve the actual mixed extra-bit
// cadence better than the single-width rows above, so reader changes can be
// screened against the text-heavy non-overlap workload before touching
// production distance/length decoding.
const readme_distance_width_pattern = makeWidthPattern(.{ 0, 4, 10, 27, 82, 138, 257, 188, 163, 164, 180, 121, 91, 75, 73 });
const roadmap_distance_width_pattern = makeWidthPattern(.{ 0, 3, 11, 36, 61, 238, 812, 726, 726, 870, 1012, 1123, 1200, 1392, 1435 });

const mixed_cases = [_]MixedCaseSpec{
    .{ .name = "mixed-readme-distance", .pattern = &readme_distance_width_pattern, .reads_per_iter = readme_distance_width_pattern.len * 64 },
    .{ .name = "mixed-roadmap-distance", .pattern = &roadmap_distance_width_pattern, .reads_per_iter = roadmap_distance_width_pattern.len * 16 },
};

const readers = [_]ReaderKind{ .buffered, .chunked_4096, .span_4096, .chunked_64, .span_64, .chunked_1, .span_1 };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var iterations_override: ?usize = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingReportPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--iterations")) {
            iterations_override = try std.fmt.parseInt(usize, args.next() orelse return error.MissingReportPath, 10);
            if (iterations_override.? == 0) return error.InvalidBlockPlan;
            continue;
        }
        return error.UnknownArgument;
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,reader,bits,reads_per_iter,iterations,input_bytes,elapsed_ns,reads_per_s,mib_per_s,checksum\n");

    for (cases) |case| {
        const iterations = iterations_override orelse iterationsFor(case);
        for (readers) |reader| {
            const row = try runCase(init, case, reader, iterations);
            try writeRow(&csv.writer, row);
        }
    }
    for (mixed_cases) |case| {
        const iterations = iterations_override orelse iterationsForMixed(case);
        for (readers) |reader| {
            const row = try runMixedCase(init, case, reader, iterations);
            try writeRow(&csv.writer, row);
        }
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(csv.written());
    try stdout.flush();

    if (csv_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
}

fn makeWidthPattern(comptime counts_by_width: anytype) [sumCounts(counts_by_width)]u6 {
    @setEvalBranchQuota(20000);
    var pattern: [sumCounts(counts_by_width)]u6 = undefined;
    var offset: usize = 0;
    inline for (counts_by_width, 0..) |count, width| {
        inline for (0..count) |_| {
            pattern[offset] = @intCast(width);
            offset += 1;
        }
    }
    return pattern;
}

fn sumCounts(comptime counts_by_width: anytype) usize {
    var total: usize = 0;
    inline for (counts_by_width) |count| total += count;
    return total;
}

fn runCase(init: std.process.Init, case: CaseSpec, reader_kind: ReaderKind, iterations: usize) !Row {
    const input_len = try bytesForReads(case.bits, case.reads_per_iter);
    const input = try init.gpa.alloc(u8, input_len);
    defer init.gpa.free(input);
    fillInput(input, case.bits);

    const chunks = if (reader_kind == .buffered)
        &[_][]const u8{}
    else
        try makeChunks(init.gpa, input, switch (reader_kind) {
            .chunked_4096, .span_4096 => 4096,
            .chunked_64, .span_64 => 64,
            .chunked_1, .span_1 => 1,
            .buffered => unreachable,
        });
    defer if (reader_kind != .buffered) init.gpa.free(chunks);

    const start = std.Io.Clock.awake.now(init.io);
    var checksum: u64 = 0;
    var iter: usize = 0;
    while (iter < iterations) : (iter += 1) {
        checksum +%= switch (reader_kind) {
            .buffered => try runBuffered(input, case.bits, case.reads_per_iter),
            .chunked_4096, .chunked_64, .chunked_1 => try runChunked(chunks, case.bits, case.reads_per_iter),
            .span_4096, .span_64, .span_1 => try runSpan(chunks, case.bits, case.reads_per_iter),
        };
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);

    return .{
        .case = case.name,
        .reader = reader_kind.label(),
        .bits = case.bits,
        .reads_per_iter = case.reads_per_iter,
        .iterations = iterations,
        .input_bytes = input.len * iterations,
        .elapsed_ns = elapsed_ns,
        .reads_per_s = readsPerSecond(case.reads_per_iter * iterations, elapsed_ns),
        .mib_per_s = mibPerSecond(input.len * iterations, elapsed_ns),
        .checksum = checksum,
    };
}

fn runMixedCase(init: std.process.Init, case: MixedCaseSpec, reader_kind: ReaderKind, iterations: usize) !Row {
    const input_len = try bytesForPattern(case.pattern, case.reads_per_iter);
    const input = try init.gpa.alloc(u8, input_len);
    defer init.gpa.free(input);
    fillInput(input, 17);

    const chunks = if (reader_kind == .buffered)
        &[_][]const u8{}
    else
        try makeChunks(init.gpa, input, switch (reader_kind) {
            .chunked_4096, .span_4096 => 4096,
            .chunked_64, .span_64 => 64,
            .chunked_1, .span_1 => 1,
            .buffered => unreachable,
        });
    defer if (reader_kind != .buffered) init.gpa.free(chunks);

    const start = std.Io.Clock.awake.now(init.io);
    var checksum: u64 = 0;
    var iter: usize = 0;
    while (iter < iterations) : (iter += 1) {
        checksum +%= switch (reader_kind) {
            .buffered => try runMixedBuffered(input, case.pattern, case.reads_per_iter),
            .chunked_4096, .chunked_64, .chunked_1 => try runMixedChunked(chunks, case.pattern, case.reads_per_iter),
            .span_4096, .span_64, .span_1 => try runMixedSpan(chunks, case.pattern, case.reads_per_iter),
        };
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);

    return .{
        .case = case.name,
        .reader = reader_kind.label(),
        .bits = 0,
        .reads_per_iter = case.reads_per_iter,
        .iterations = iterations,
        .input_bytes = input.len * iterations,
        .elapsed_ns = elapsed_ns,
        .reads_per_s = readsPerSecond(case.reads_per_iter * iterations, elapsed_ns),
        .mib_per_s = mibPerSecond(input.len * iterations, elapsed_ns),
        .checksum = checksum,
    };
}

fn runBuffered(input: []const u8, bits: u6, reads: usize) !u64 {
    var reader = vort.bitstream.BufferedBitReader.init(input);
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < reads) : (i += 1) sum +%= try reader.readBits(u16, bits);
    return sum;
}

fn runMixedBuffered(input: []const u8, pattern: []const u6, reads: usize) !u64 {
    var reader = vort.bitstream.BufferedBitReader.init(input);
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < reads) : (i += 1) {
        const bits = pattern[i % pattern.len];
        if (bits != 0) sum +%= try reader.readBits(u16, bits);
    }
    return sum;
}

fn runChunked(chunks: []const []const u8, bits: u6, reads: usize) !u64 {
    var reader = try vort.bitstream.ChunkedBitReader.init(chunks);
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < reads) : (i += 1) sum +%= try reader.readBits(u16, bits);
    return sum;
}

fn runMixedChunked(chunks: []const []const u8, pattern: []const u6, reads: usize) !u64 {
    var reader = try vort.bitstream.ChunkedBitReader.init(chunks);
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < reads) : (i += 1) {
        const bits = pattern[i % pattern.len];
        if (bits != 0) sum +%= try reader.readBits(u16, bits);
    }
    return sum;
}

fn runSpan(chunks: []const []const u8, bits: u6, reads: usize) !u64 {
    var reader = try vort.bitstream.ChunkedSpanBitReader.init(chunks);
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < reads) : (i += 1) sum +%= try reader.readBits(u16, bits);
    return sum;
}

fn runMixedSpan(chunks: []const []const u8, pattern: []const u6, reads: usize) !u64 {
    var reader = try vort.bitstream.ChunkedSpanBitReader.init(chunks);
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < reads) : (i += 1) {
        const bits = pattern[i % pattern.len];
        if (bits != 0) sum +%= try reader.readBits(u16, bits);
    }
    return sum;
}

fn bytesForReads(bits: u6, reads: usize) !usize {
    const total_bits = try std.math.mul(usize, bits, reads);
    return (total_bits + 7) / 8 + 8;
}

fn bytesForPattern(pattern: []const u6, reads: usize) !usize {
    var bits_per_pattern: usize = 0;
    for (pattern) |bits| bits_per_pattern += bits;
    const full_patterns = reads / pattern.len;
    const remainder = reads % pattern.len;
    var total_bits = try std.math.mul(usize, bits_per_pattern, full_patterns);
    for (pattern[0..remainder]) |bits| total_bits = try std.math.add(usize, total_bits, bits);
    return (total_bits + 7) / 8 + 8;
}

fn fillInput(input: []u8, bits: u6) void {
    for (input, 0..) |*byte, i| {
        byte.* = @truncate((i * 131 + @as(usize, bits) * 17 + (i >> 2)) & 0xff);
    }
}

fn makeChunks(allocator: std.mem.Allocator, input: []const u8, chunk_len: usize) ![][]const u8 {
    var chunks: std.ArrayList([]const u8) = .empty;
    errdefer chunks.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        const n = @min(chunk_len, input.len - offset);
        try chunks.append(allocator, input[offset..][0..n]);
        offset += n;
    }
    return chunks.toOwnedSlice(allocator);
}

fn iterationsFor(case: CaseSpec) usize {
    const target_reads: usize = 4 * 1024 * 1024;
    return @max(@as(usize, 8), @min(@as(usize, 512), target_reads / @max(case.reads_per_iter, 1)));
}

fn iterationsForMixed(case: MixedCaseSpec) usize {
    const target_reads: usize = 4 * 1024 * 1024;
    return @max(@as(usize, 8), @min(@as(usize, 512), target_reads / @max(case.reads_per_iter, 1)));
}

fn readsPerSecond(reads: usize, elapsed_ns: i128) f64 {
    if (elapsed_ns <= 0) return 0;
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    return @as(f64, @floatFromInt(reads)) / seconds;
}

fn mibPerSecond(bytes: usize, elapsed_ns: i128) f64 {
    if (elapsed_ns <= 0) return 0;
    const mib = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0);
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    return mib / seconds;
}

fn writeRow(writer: *std.Io.Writer, row: Row) !void {
    try writer.print("{s},{s},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d}\n", .{
        row.case,
        row.reader,
        row.bits,
        row.reads_per_iter,
        row.iterations,
        row.input_bytes,
        row.elapsed_ns,
        row.reads_per_s,
        row.mib_per_s,
        row.checksum,
    });
}

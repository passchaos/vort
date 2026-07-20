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

const DistanceKernel = enum {
    current,
    fused18,

    fn label(self: DistanceKernel) []const u8 {
        return switch (self) {
            .current => "current",
            .fused18 => "fused18",
        };
    }
};

const ExtraKernel = enum {
    current,
    staged,

    fn label(self: ExtraKernel) []const u8 {
        return switch (self) {
            .current => "current",
            .staged => "staged",
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

const DistanceCaseSpec = struct {
    name: []const u8,
    symbols: []const u6,
    reads_per_iter: usize,
};

const Row = struct {
    case: []const u8,
    reader: []const u8,
    kernel: []const u8,
    bits: u6,
    reads_per_iter: usize,
    iterations: usize,
    repeat: usize,
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
const readme_length_width_pattern = makeWidthPattern(.{ 1026, 216, 191, 125, 20, 2 });
const roadmap_length_width_pattern = makeWidthPattern(.{ 7435, 1982, 709, 291, 31, 0 });
const readme_distance_symbol_pattern = makeWidthPattern(.{ 2, 0, 1, 1, 5, 5, 11, 16, 37, 45, 78, 60, 152, 105, 100, 88, 93, 70, 82, 82, 101, 79, 79, 42, 52, 39, 52, 23, 73, 0 });
const roadmap_distance_symbol_pattern = makeWidthPattern(.{ 0, 0, 1, 2, 7, 4, 22, 14, 21, 40, 105, 133, 477, 335, 416, 310, 417, 309, 522, 348, 585, 427, 648, 475, 681, 519, 743, 649, 854, 581 });

const mixed_cases = [_]MixedCaseSpec{
    .{ .name = "mixed-readme-length", .pattern = &readme_length_width_pattern, .reads_per_iter = readme_length_width_pattern.len * 64 },
    .{ .name = "mixed-roadmap-length", .pattern = &roadmap_length_width_pattern, .reads_per_iter = roadmap_length_width_pattern.len * 16 },
    .{ .name = "mixed-readme-distance", .pattern = &readme_distance_width_pattern, .reads_per_iter = readme_distance_width_pattern.len * 64 },
    .{ .name = "mixed-roadmap-distance", .pattern = &roadmap_distance_width_pattern, .reads_per_iter = roadmap_distance_width_pattern.len * 16 },
};

const distance_cases = [_]DistanceCaseSpec{
    .{ .name = "distance-readme-symbol-extra", .symbols = &readme_distance_symbol_pattern, .reads_per_iter = readme_distance_symbol_pattern.len * 64 },
    .{ .name = "distance-roadmap-symbol-extra", .symbols = &roadmap_distance_symbol_pattern, .reads_per_iter = roadmap_distance_symbol_pattern.len * 16 },
};

const readers = [_]ReaderKind{ .buffered, .chunked_4096, .span_4096, .chunked_64, .span_64, .chunked_1, .span_1 };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var iterations_override: ?usize = null;
    var repeat: usize = 1;
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
        if (std.mem.eql(u8, arg, "--repeat")) {
            repeat = try std.fmt.parseInt(usize, args.next() orelse return error.MissingReportPath, 10);
            if (repeat == 0) return error.InvalidBlockPlan;
            continue;
        }
        return error.UnknownArgument;
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,reader,kernel,bits,reads_per_iter,iterations,repeat,input_bytes,elapsed_ns,reads_per_s,mib_per_s,checksum\n");

    for (cases) |case| {
        const iterations = iterations_override orelse iterationsFor(case);
        for (readers) |reader| {
            const row = try runCase(init, case, reader, iterations, repeat);
            try writeRow(&csv.writer, row);
        }
    }
    for (mixed_cases) |case| {
        const iterations = iterations_override orelse iterationsForMixed(case);
        for (readers) |reader| {
            if (std.mem.endsWith(u8, case.name, "-length")) {
                inline for (.{ ExtraKernel.current, ExtraKernel.staged }) |kernel| {
                    const row = try runMixedCase(init, case, reader, kernel, iterations, repeat);
                    try writeRow(&csv.writer, row);
                }
            } else {
                const row = try runMixedCase(init, case, reader, null, iterations, repeat);
                try writeRow(&csv.writer, row);
            }
        }
    }
    for (distance_cases) |case| {
        const iterations = iterations_override orelse iterationsForDistance(case);
        for (readers) |reader| {
            inline for (.{ DistanceKernel.current, DistanceKernel.fused18 }) |kernel| {
                const row = try runDistanceCase(init, case, reader, kernel, iterations, repeat);
                try writeRow(&csv.writer, row);
            }
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

fn runCase(init: std.process.Init, case: CaseSpec, reader_kind: ReaderKind, iterations: usize, repeat: usize) !Row {
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

    const timed = try runRepeated(init, repeat, struct {
        fn run(ctx: @TypeOf(.{ input, chunks, reader_kind, case.bits, case.reads_per_iter, iterations })) !u64 {
            const in = ctx[0];
            const ch = ctx[1];
            const kind = ctx[2];
            const bits = ctx[3];
            const reads = ctx[4];
            const iters = ctx[5];
            var checksum: u64 = 0;
            var iter: usize = 0;
            while (iter < iters) : (iter += 1) {
                checksum +%= switch (kind) {
                    .buffered => try runBuffered(in, bits, reads),
                    .chunked_4096, .chunked_64, .chunked_1 => try runChunked(ch, bits, reads),
                    .span_4096, .span_64, .span_1 => try runSpan(ch, bits, reads),
                };
            }
            return checksum;
        }
    }.run, .{ input, chunks, reader_kind, case.bits, case.reads_per_iter, iterations });

    return .{
        .case = case.name,
        .reader = reader_kind.label(),
        .kernel = "single",
        .bits = case.bits,
        .reads_per_iter = case.reads_per_iter,
        .iterations = iterations,
        .repeat = repeat,
        .input_bytes = input.len * iterations,
        .elapsed_ns = timed.elapsed_ns,
        .reads_per_s = readsPerSecond(case.reads_per_iter * iterations, timed.elapsed_ns),
        .mib_per_s = mibPerSecond(input.len * iterations, timed.elapsed_ns),
        .checksum = timed.checksum,
    };
}

fn runMixedCase(init: std.process.Init, case: MixedCaseSpec, reader_kind: ReaderKind, comptime kernel: ?ExtraKernel, iterations: usize, repeat: usize) !Row {
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

    const timed = try runRepeated(init, repeat, struct {
        fn run(ctx: @TypeOf(.{ input, chunks, reader_kind, case.pattern, case.reads_per_iter, iterations })) !u64 {
            const in = ctx[0];
            const ch = ctx[1];
            const kind = ctx[2];
            const pattern = ctx[3];
            const reads = ctx[4];
            const iters = ctx[5];
            var checksum: u64 = 0;
            var iter: usize = 0;
            while (iter < iters) : (iter += 1) {
                checksum +%= switch (kind) {
                    .buffered => try runMixedBuffered(in, pattern, reads, kernel),
                    .chunked_4096, .chunked_64, .chunked_1 => try runMixedChunked(ch, pattern, reads, kernel),
                    .span_4096, .span_64, .span_1 => try runMixedSpan(ch, pattern, reads, kernel),
                };
            }
            return checksum;
        }
    }.run, .{ input, chunks, reader_kind, case.pattern, case.reads_per_iter, iterations });

    return .{
        .case = case.name,
        .reader = reader_kind.label(),
        .kernel = if (kernel) |k| k.label() else "mixed-extra",
        .bits = 0,
        .reads_per_iter = case.reads_per_iter,
        .iterations = iterations,
        .repeat = repeat,
        .input_bytes = input.len * iterations,
        .elapsed_ns = timed.elapsed_ns,
        .reads_per_s = readsPerSecond(case.reads_per_iter * iterations, timed.elapsed_ns),
        .mib_per_s = mibPerSecond(input.len * iterations, timed.elapsed_ns),
        .checksum = timed.checksum,
    };
}

fn runDistanceCase(init: std.process.Init, case: DistanceCaseSpec, reader_kind: ReaderKind, kernel: DistanceKernel, iterations: usize, repeat: usize) !Row {
    const input_len = try bytesForDistanceSymbols(case.symbols, case.reads_per_iter);
    const input = try init.gpa.alloc(u8, input_len);
    defer init.gpa.free(input);
    fillDistanceInput(input, case.symbols, case.reads_per_iter);

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

    const timed = try runRepeated(init, repeat, struct {
        fn run(ctx: @TypeOf(.{ input, chunks, reader_kind, case.reads_per_iter, kernel, iterations })) !u64 {
            const in = ctx[0];
            const ch = ctx[1];
            const kind = ctx[2];
            const reads = ctx[3];
            const active_kernel = ctx[4];
            const iters = ctx[5];
            var checksum: u64 = 0;
            var iter: usize = 0;
            while (iter < iters) : (iter += 1) {
                checksum +%= switch (kind) {
                    .buffered => try runDistanceBuffered(in, reads, active_kernel),
                    .chunked_4096, .chunked_64, .chunked_1 => try runDistanceChunked(ch, reads, active_kernel),
                    .span_4096, .span_64, .span_1 => try runDistanceSpan(ch, reads, active_kernel),
                };
            }
            return checksum;
        }
    }.run, .{ input, chunks, reader_kind, case.reads_per_iter, kernel, iterations });

    return .{
        .case = case.name,
        .reader = reader_kind.label(),
        .kernel = kernel.label(),
        .bits = 0,
        .reads_per_iter = case.reads_per_iter,
        .iterations = iterations,
        .repeat = repeat,
        .input_bytes = input.len * iterations,
        .elapsed_ns = timed.elapsed_ns,
        .reads_per_s = readsPerSecond(case.reads_per_iter * iterations, timed.elapsed_ns),
        .mib_per_s = mibPerSecond(input.len * iterations, timed.elapsed_ns),
        .checksum = timed.checksum,
    };
}

const TimedResult = struct {
    elapsed_ns: i128,
    checksum: u64,
};

fn runRepeated(init: std.process.Init, repeat: usize, runFn: anytype, ctx: anytype) !TimedResult {
    const elapsed_samples = try init.gpa.alloc(i128, repeat);
    defer init.gpa.free(elapsed_samples);
    var checksum: ?u64 = null;
    for (elapsed_samples) |*elapsed| {
        const start = std.Io.Clock.awake.now(init.io);
        const sample_checksum = try runFn(ctx);
        elapsed.* = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        if (checksum) |expected| {
            if (sample_checksum != expected) return error.ChecksumMismatch;
        } else {
            checksum = sample_checksum;
        }
        std.mem.doNotOptimizeAway(sample_checksum);
    }
    std.mem.sort(i128, elapsed_samples, {}, comptime std.sort.asc(i128));
    return .{
        .elapsed_ns = elapsed_samples[repeat / 2],
        .checksum = checksum orelse 0,
    };
}

fn runBuffered(input: []const u8, bits: u6, reads: usize) !u64 {
    var reader = vort.bitstream.BufferedBitReader.init(input);
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < reads) : (i += 1) sum +%= try reader.readBits(u16, bits);
    return sum;
}

fn runMixedBuffered(input: []const u8, pattern: []const u6, reads: usize, comptime kernel: ?ExtraKernel) !u64 {
    var reader = vort.bitstream.BufferedBitReader.init(input);
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < reads) : (i += 1) {
        const bits = pattern[i % pattern.len];
        if (bits != 0) sum +%= try readMixedExtraBits(&reader, bits, kernel);
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

fn runMixedChunked(chunks: []const []const u8, pattern: []const u6, reads: usize, comptime kernel: ?ExtraKernel) !u64 {
    var reader = try vort.bitstream.ChunkedBitReader.init(chunks);
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < reads) : (i += 1) {
        const bits = pattern[i % pattern.len];
        if (bits != 0) sum +%= try readMixedExtraBits(&reader, bits, kernel);
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

fn runMixedSpan(chunks: []const []const u8, pattern: []const u6, reads: usize, comptime kernel: ?ExtraKernel) !u64 {
    var reader = try vort.bitstream.ChunkedSpanBitReader.init(chunks);
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < reads) : (i += 1) {
        const bits = pattern[i % pattern.len];
        if (bits != 0) sum +%= try readMixedExtraBits(&reader, bits, kernel);
    }
    return sum;
}

fn readMixedExtraBits(reader: anytype, bits: u6, comptime kernel: ?ExtraKernel) !u64 {
    const active_kernel = kernel orelse ExtraKernel.current;
    return switch (active_kernel) {
        .current => try reader.readBits(u16, bits),
        .staged => blk: {
            if (!reader.hasBits(bits)) return error.TruncatedFrame;
            const value = reader.peekBitsPadded(u16, bits);
            reader.advanceBitsStagedAssumeAvailable(bits);
            break :blk value;
        },
    };
}

fn runDistanceBuffered(input: []const u8, reads: usize, kernel: DistanceKernel) !u64 {
    var reader = vort.bitstream.BufferedBitReader.init(input);
    return runDistanceReads(&reader, reads, kernel);
}

fn runDistanceChunked(chunks: []const []const u8, reads: usize, kernel: DistanceKernel) !u64 {
    var reader = try vort.bitstream.ChunkedBitReader.init(chunks);
    return runDistanceReads(&reader, reads, kernel);
}

fn runDistanceSpan(chunks: []const []const u8, reads: usize, kernel: DistanceKernel) !u64 {
    var reader = try vort.bitstream.ChunkedSpanBitReader.init(chunks);
    return runDistanceReads(&reader, reads, kernel);
}

fn runDistanceReads(reader: anytype, reads: usize, kernel: DistanceKernel) !u64 {
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < reads) : (i += 1) {
        sum +%= switch (kernel) {
            .current => try readDistanceCurrent(reader),
            .fused18 => try readDistanceFused18(reader),
        };
    }
    return sum;
}

fn readDistanceCurrent(reader: anytype) !u64 {
    const symbol = try reader.readBits(u16, 5);
    if (symbol >= distance_extra_bits_by_symbol.len) return error.InvalidHuffmanCode;
    const extra_bits = distance_extra_bits_by_symbol[symbol];
    const extra = if (extra_bits == 0) 0 else try reader.readBits(u16, extra_bits);
    return symbol + extra;
}

fn readDistanceFused18(reader: anytype) !u64 {
    const symbol = try reader.readBits(u16, 5);
    if (symbol >= distance_extra_bits_by_symbol.len) return error.InvalidHuffmanCode;
    const extra_bits = distance_extra_bits_by_symbol[symbol];
    if (extra_bits == 0) return symbol;
    if (!reader.hasBits(extra_bits)) return error.TruncatedFrame;
    const extra = reader.peekBitsPadded(u16, extra_bits);
    reader.advanceBitsStagedAssumeAvailable(extra_bits);
    return symbol + extra;
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

fn bytesForDistanceSymbols(symbols: []const u6, reads: usize) !usize {
    var bits_per_pattern: usize = 0;
    for (symbols) |symbol| bits_per_pattern += 5 + distance_extra_bits_by_symbol[symbol];
    const full_patterns = reads / symbols.len;
    const remainder = reads % symbols.len;
    var total_bits = try std.math.mul(usize, bits_per_pattern, full_patterns);
    for (symbols[0..remainder]) |symbol| total_bits = try std.math.add(usize, total_bits, 5 + distance_extra_bits_by_symbol[symbol]);
    return (total_bits + 7) / 8 + 8;
}

fn fillInput(input: []u8, bits: u6) void {
    for (input, 0..) |*byte, i| {
        byte.* = @truncate((i * 131 + @as(usize, bits) * 17 + (i >> 2)) & 0xff);
    }
}

fn fillDistanceInput(input: []u8, symbols: []const u6, reads: usize) void {
    @memset(input, 0);
    var bit_pos: usize = 0;
    var i: usize = 0;
    while (i < reads) : (i += 1) {
        const symbol = symbols[i % symbols.len];
        writeBits(input, &bit_pos, symbol, 5);
        const extra_bits = distance_extra_bits_by_symbol[symbol];
        if (extra_bits != 0) {
            const mask = (@as(u16, 1) << @intCast(extra_bits)) - 1;
            const extra: u16 = @truncate((i * 131 + @as(usize, symbol) * 17) & mask);
            writeBits(input, &bit_pos, extra, extra_bits);
        }
    }
}

fn writeBits(output: []u8, bit_pos: *usize, value: u16, count: u6) void {
    var written: u6 = 0;
    while (written < count) : (written += 1) {
        if (((value >> @intCast(written)) & 1) != 0) {
            const absolute = bit_pos.* + written;
            output[absolute / 8] |= @as(u8, 1) << @intCast(absolute % 8);
        }
    }
    bit_pos.* += count;
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

fn iterationsForDistance(case: DistanceCaseSpec) usize {
    const target_reads: usize = 4 * 1024 * 1024;
    return @max(@as(usize, 8), @min(@as(usize, 512), target_reads / @max(case.reads_per_iter, 1)));
}

const distance_extra_bits_by_symbol = [_]u6{
    0,  0,  0,  0,
    1,  1,  2,  2,
    3,  3,  4,  4,
    5,  5,  6,  6,
    7,  7,  8,  8,
    9,  9,  10, 10,
    11, 11, 12, 12,
    13, 13,
};

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
    try writer.print("{s},{s},{s},{d},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d}\n", .{
        row.case,
        row.reader,
        row.kernel,
        row.bits,
        row.reads_per_iter,
        row.iterations,
        row.repeat,
        row.input_bytes,
        row.elapsed_ns,
        row.reads_per_s,
        row.mib_per_s,
        row.checksum,
    });
}

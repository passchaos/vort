const std = @import("std");
const vort = @import("vort");

const bitstream = vort.bitstream;
const huffman = vort.huffman;

const iterations_default: usize = 96;
const symbols_per_iter: usize = 128 * 1024;

const DecoderKind = enum {
    table,
    fast5,
    fast8,
    fast9,
    fast11,
    fast12,
    fixed_fast,

    fn label(self: DecoderKind) []const u8 {
        return switch (self) {
            .table => "table",
            .fast5 => "fast5",
            .fast8 => "fast8",
            .fast9 => "fast9",
            .fast11 => "fast11",
            .fast12 => "fast12",
            .fixed_fast => "fixed_fast",
        };
    }
};

const CaseKind = enum {
    fixed_literal,
    fixed_distance,
    dynamic_mixed,
    dynamic_long_tail,
    dynamic_distance,

    fn label(self: CaseKind) []const u8 {
        return switch (self) {
            .fixed_literal => "fixed-literal",
            .fixed_distance => "fixed-distance",
            .dynamic_mixed => "dynamic-mixed",
            .dynamic_long_tail => "dynamic-long-tail",
            .dynamic_distance => "dynamic-distance",
        };
    }
};

const Row = struct {
    case: []const u8,
    decoder: []const u8,
    lookup_bits: u8,
    symbols_per_iter: usize,
    iterations: usize,
    input_bytes: usize,
    elapsed_ns: i128,
    symbols_per_s: f64,
    mib_per_s: f64,
    checksum: u64,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var iterations = iterations_default;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingReportPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--iterations")) {
            iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingReportPath, 10);
            if (iterations == 0) return error.InvalidBlockPlan;
            continue;
        }
        return error.UnknownArgument;
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,decoder,lookup_bits,symbols_per_iter,iterations,input_bytes,elapsed_ns,symbols_per_s,mib_per_s,checksum\n");

    inline for (.{ CaseKind.fixed_literal, CaseKind.fixed_distance, CaseKind.dynamic_mixed, CaseKind.dynamic_long_tail, CaseKind.dynamic_distance }) |case| {
        try runCaseSet(init, &csv.writer, case, iterations);
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout_writer.interface.writeAll(csv.written());
    try stdout_writer.interface.flush();

    if (csv_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
}

fn runCaseSet(init: std.process.Init, writer: *std.Io.Writer, comptime case: CaseKind, iterations: usize) !void {
    var lengths: [288]u4 = @splat(0);
    switch (case) {
        .fixed_literal => {
            const fixed_lengths = huffman.fixedLiteralLengths();
            @memcpy(lengths[0..fixed_lengths.len], &fixed_lengths);
        },
        .fixed_distance => {
            const fixed_lengths = huffman.fixedDistanceLengths();
            @memcpy(lengths[0..fixed_lengths.len], &fixed_lengths);
        },
        .dynamic_mixed => fillDynamicMixedLengths(&lengths),
        .dynamic_long_tail => fillDynamicLongTailLengths(&lengths),
        .dynamic_distance => fillDynamicDistanceLengths(&lengths),
    }

    const table = try huffman.HuffmanTable(288).init(&lengths);
    const encoder = try huffman.HuffmanTable(288).Encoder.init(&lengths);
    const symbols = try init.gpa.alloc(u16, symbols_per_iter);
    defer init.gpa.free(symbols);
    fillSymbols(case, symbols, &lengths);
    const input = try encodeSymbols(init.gpa, &encoder, symbols);
    defer init.gpa.free(input);

    switch (case) {
        .fixed_literal => {
            try writeRow(writer, try runDecoder(init, case, .table, input, symbols, iterations, table));
            try writeRow(writer, try runDecoder(init, case, .fixed_fast, input, symbols, iterations, table));
            const fast9 = huffman.FastDecoder(288, 9).init(table);
            try writeRow(writer, try runFastDecoder(init, case, .fast9, input, symbols, iterations, &fast9));
        },
        .fixed_distance => {
            try writeRow(writer, try runDecoder(init, case, .table, input, symbols, iterations, table));
            try writeRow(writer, try runDecoder(init, case, .fixed_fast, input, symbols, iterations, table));
            const fast5 = huffman.FastDecoder(288, 5).init(table);
            try writeRow(writer, try runFastDecoder(init, case, .fast5, input, symbols, iterations, &fast5));
            const fast8 = huffman.FastDecoder(288, 8).init(table);
            try writeRow(writer, try runFastDecoder(init, case, .fast8, input, symbols, iterations, &fast8));
        },
        .dynamic_mixed, .dynamic_long_tail => {
            try writeRow(writer, try runDecoder(init, case, .table, input, symbols, iterations, table));
            const fast9 = huffman.FastDecoder(288, 9).init(table);
            const fast11 = huffman.FastDecoder(288, 11).init(table);
            const fast12 = huffman.FastDecoder(288, 12).init(table);
            try writeRow(writer, try runFastDecoder(init, case, .fast9, input, symbols, iterations, &fast9));
            try writeRow(writer, try runFastDecoder(init, case, .fast11, input, symbols, iterations, &fast11));
            try writeRow(writer, try runFastDecoder(init, case, .fast12, input, symbols, iterations, &fast12));
        },
        .dynamic_distance => {
            try writeRow(writer, try runDecoder(init, case, .table, input, symbols, iterations, table));
            const fast5 = huffman.FastDecoder(288, 5).init(table);
            const fast8 = huffman.FastDecoder(288, 8).init(table);
            try writeRow(writer, try runFastDecoder(init, case, .fast5, input, symbols, iterations, &fast5));
            try writeRow(writer, try runFastDecoder(init, case, .fast8, input, symbols, iterations, &fast8));
        },
    }
}

fn fillDynamicMixedLengths(lengths: *[288]u4) void {
    @memset(lengths, 0);
    for (0..144) |i| lengths[i] = 8;
    for (144..256) |i| lengths[i] = 9;
    lengths[256] = 7;
    for (257..286) |i| lengths[i] = 10;
}

fn fillDynamicLongTailLengths(lengths: *[288]u4) void {
    @memset(lengths, 0);
    for (0..32) |i| lengths[i] = 7;
    for (32..96) |i| lengths[i] = 10;
    for (96..256) |i| lengths[i] = 13;
    lengths[256] = 7;
    for (257..286) |i| lengths[i] = 15;
}

fn fillDynamicDistanceLengths(lengths: *[288]u4) void {
    @memset(lengths, 0);
    for (0..6) |i| lengths[i] = 4;
    for (6..18) |i| lengths[i] = 7;
    for (18..30) |i| lengths[i] = 10;
}

fn fillSymbols(comptime case: CaseKind, symbols: []u16, lengths: *const [288]u4) void {
    var active: [288]u16 = undefined;
    var active_len: usize = 0;
    for (lengths, 0..) |bits, symbol| {
        if (bits != 0) {
            active[active_len] = @intCast(symbol);
            active_len += 1;
        }
    }
    for (symbols, 0..) |*symbol, i| {
        symbol.* = switch (case) {
            .fixed_literal => @intCast((i * 37 + (i >> 3)) % 288),
            .fixed_distance => @intCast((i * 13 + (i >> 5)) % 32),
            .dynamic_mixed => active[(i * 53 + (i >> 4)) % active_len],
            .dynamic_long_tail => active[(i * 97 + (i >> 2) + 17) % active_len],
            .dynamic_distance => active[(i * 19 + (i >> 3)) % active_len],
        };
    }
}

fn encodeSymbols(allocator: std.mem.Allocator, encoder: *const huffman.HuffmanTable(288).Encoder, symbols: []const u16) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    for (symbols) |symbol| try encoder.writeSymbol(&writer, allocator, symbol);
    return writer.toOwnedSlice(allocator);
}

fn runDecoder(init: std.process.Init, comptime case: CaseKind, kind: DecoderKind, input: []const u8, expected: []const u16, iterations: usize, table: huffman.HuffmanTable(288)) !Row {
    const start = std.Io.Clock.awake.now(init.io);
    var checksum: u64 = 0;
    var iter: usize = 0;
    while (iter < iterations) : (iter += 1) {
        var reader = bitstream.BufferedBitReader.init(input);
        for (expected) |want| {
            const got = switch (kind) {
                .table => try table.decodeValue(&reader),
                .fixed_fast => if (case == .fixed_distance) try huffman.decodeFixedDistanceValueFast(&reader) else try huffman.decodeFixedLiteralValueFast(&reader),
                else => unreachable,
            };
            if (got != want) return error.DecodeLengthMismatch;
            checksum = checksum *% 131 +% got;
        }
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    return row(case, kind, input.len, elapsed_ns, iterations, checksum);
}

fn runFastDecoder(init: std.process.Init, comptime case: CaseKind, kind: DecoderKind, input: []const u8, expected: []const u16, iterations: usize, decoder: anytype) !Row {
    const start = std.Io.Clock.awake.now(init.io);
    var checksum: u64 = 0;
    var iter: usize = 0;
    while (iter < iterations) : (iter += 1) {
        var reader = bitstream.BufferedBitReader.init(input);
        for (expected) |want| {
            const got = try decoder.decodeValue(&reader);
            if (got != want) return error.DecodeLengthMismatch;
            checksum = checksum *% 131 +% got;
        }
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    return row(case, kind, input.len, elapsed_ns, iterations, checksum);
}

fn row(comptime case: CaseKind, kind: DecoderKind, input_len: usize, elapsed_ns: i128, iterations: usize, checksum: u64) Row {
    const lookup_bits: u8 = switch (kind) {
        .table => 0,
        .fast5 => 5,
        .fast8 => 8,
        .fast9, .fixed_fast => 9,
        .fast11 => 11,
        .fast12 => 12,
    };
    return .{
        .case = case.label(),
        .decoder = kind.label(),
        .lookup_bits = lookup_bits,
        .symbols_per_iter = symbols_per_iter,
        .iterations = iterations,
        .input_bytes = input_len * iterations,
        .elapsed_ns = elapsed_ns,
        .symbols_per_s = perSecond(symbols_per_iter * iterations, elapsed_ns),
        .mib_per_s = mibPerSecond(input_len * iterations, elapsed_ns),
        .checksum = checksum,
    };
}

fn writeRow(writer: *std.Io.Writer, r: Row) !void {
    try writer.print("{s},{s},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d}\n", .{
        r.case,
        r.decoder,
        r.lookup_bits,
        r.symbols_per_iter,
        r.iterations,
        r.input_bytes,
        r.elapsed_ns,
        r.symbols_per_s,
        r.mib_per_s,
        r.checksum,
    });
}

fn perSecond(count: usize, elapsed_ns: i128) f64 {
    if (elapsed_ns <= 0) return 0;
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    return @as(f64, @floatFromInt(count)) / seconds;
}

fn mibPerSecond(bytes: usize, elapsed_ns: i128) f64 {
    if (elapsed_ns <= 0) return 0;
    const mib = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0);
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    return mib / seconds;
}

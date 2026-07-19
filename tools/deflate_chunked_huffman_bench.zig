const std = @import("std");
const vort = @import("vort");

const bitstream = vort.bitstream;
const huffman = vort.huffman;

const symbols_per_iter: usize = 128 * 1024;
const iterations_default: usize = 64;

const ReaderKind = enum {
    buffered,
    chunked_4096,
    coalesced_4096,
    joined_4096,
    chunked_64,
    coalesced_64,
    joined_64,
    chunked_1,
    coalesced_1,
    joined_1,

    fn label(self: ReaderKind) []const u8 {
        return switch (self) {
            .buffered => "buffered",
            .chunked_4096 => "chunked_4096",
            .coalesced_4096 => "coalesced_4096",
            .joined_4096 => "joined_4096",
            .chunked_64 => "chunked_64",
            .coalesced_64 => "coalesced_64",
            .joined_64 => "joined_64",
            .chunked_1 => "chunked_1",
            .coalesced_1 => "coalesced_1",
            .joined_1 => "joined_1",
        };
    }

    fn isCoalesced(self: ReaderKind) bool {
        return switch (self) {
            .coalesced_4096, .coalesced_64, .coalesced_1 => true,
            else => false,
        };
    }

    fn isJoined(self: ReaderKind) bool {
        return switch (self) {
            .joined_4096, .joined_64, .joined_1 => true,
            else => false,
        };
    }
};

const CaseKind = enum {
    fixed_literal,
    dynamic_mixed,
    dynamic_long_tail,

    fn label(self: CaseKind) []const u8 {
        return switch (self) {
            .fixed_literal => "fixed-literal",
            .dynamic_mixed => "dynamic-mixed",
            .dynamic_long_tail => "dynamic-long-tail",
        };
    }

    fn lookupBits(self: CaseKind) u8 {
        return switch (self) {
            .fixed_literal => 9,
            .dynamic_mixed => 11,
            .dynamic_long_tail => 12,
        };
    }
};

const Row = struct {
    case: []const u8,
    reader: []const u8,
    decoder: []const u8,
    lookup_bits: u8,
    chunk_bytes: usize,
    chunk_count: usize,
    symbols_per_iter: usize,
    iterations: usize,
    input_bytes: usize,
    elapsed_ns: i128,
    symbols_per_s: f64,
    mib_per_s: f64,
    checksum: u64,
};

const readers = [_]ReaderKind{ .buffered, .chunked_4096, .coalesced_4096, .joined_4096, .chunked_64, .coalesced_64, .joined_64, .chunked_1, .coalesced_1, .joined_1 };

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
    try csv.writer.writeAll("case,reader,decoder,lookup_bits,chunk_bytes,chunk_count,symbols_per_iter,iterations,input_bytes,elapsed_ns,symbols_per_s,mib_per_s,checksum\n");

    inline for (.{ CaseKind.fixed_literal, CaseKind.dynamic_mixed, CaseKind.dynamic_long_tail }) |case| {
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
            const fixed = huffman.fixedLiteralLengths();
            @memcpy(lengths[0..fixed.len], &fixed);
        },
        .dynamic_mixed => fillDynamicMixedLengths(&lengths),
        .dynamic_long_tail => fillDynamicLongTailLengths(&lengths),
    }

    const table = try huffman.HuffmanTable(288).init(&lengths);
    const encoder = try huffman.HuffmanTable(288).Encoder.init(&lengths);
    const symbols = try init.gpa.alloc(u16, symbols_per_iter);
    defer init.gpa.free(symbols);
    fillSymbols(case, symbols, &lengths);
    const input = try encodeSymbols(init.gpa, &encoder, symbols);
    defer init.gpa.free(input);

    for (readers) |reader| {
        const result_row = switch (case) {
            .fixed_literal => try runFixedLiteral(init, reader, input, symbols, iterations),
            .dynamic_mixed => blk: {
                const decoder = huffman.FastDecoder(288, 11).init(table);
                break :blk try runFast(init, case, reader, input, symbols, iterations, &decoder, "fast11");
            },
            .dynamic_long_tail => blk: {
                const decoder = huffman.FastDecoder(288, 12).init(table);
                break :blk try runFast(init, case, reader, input, symbols, iterations, &decoder, "fast12");
            },
        };
        try writeRow(writer, result_row);
    }
}

fn runFixedLiteral(init: std.process.Init, reader_kind: ReaderKind, input: []const u8, expected: []const u16, iterations: usize) !Row {
    const chunks = try chunksForReader(init.gpa, reader_kind, input);
    defer if (reader_kind != .buffered) init.gpa.free(chunks);
    const coalesced = if (reader_kind.isCoalesced()) try coalesceChunks(init.gpa, chunks, input.len) else input;
    defer if (reader_kind.isCoalesced()) init.gpa.free(coalesced);
    const joined_scratch = if (reader_kind.isJoined()) try init.gpa.alloc(u8, input.len) else null;
    defer if (joined_scratch) |scratch| init.gpa.free(scratch);
    const start = std.Io.Clock.awake.now(init.io);
    var checksum: u64 = 0;
    for (0..iterations) |_| {
        switch (reader_kind) {
            .buffered, .coalesced_4096, .coalesced_64, .coalesced_1 => {
                var reader = bitstream.BufferedBitReader.init(coalesced);
                for (expected) |want| {
                    const got = try huffman.decodeFixedLiteralValueFast(&reader);
                    if (got != want) return error.DecodeLengthMismatch;
                    checksum = checksum *% 131 +% got;
                }
            },
            .joined_4096, .joined_64, .joined_1 => {
                const joined = try joinChunksInto(chunks, joined_scratch.?);
                var reader = bitstream.BufferedBitReader.init(joined);
                for (expected) |want| {
                    const got = try huffman.decodeFixedLiteralValueFast(&reader);
                    if (got != want) return error.DecodeLengthMismatch;
                    checksum = checksum *% 131 +% got;
                }
            },
            else => {
                var reader = try bitstream.ChunkedBitReader.init(chunks);
                for (expected) |want| {
                    const got = try huffman.decodeFixedLiteralValueFast(&reader);
                    if (got != want) return error.DecodeLengthMismatch;
                    checksum = checksum *% 131 +% got;
                }
            },
        }
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    return row(.fixed_literal, reader_kind, "fixed_fast", 9, chunks.len, input.len, elapsed_ns, iterations, checksum);
}

fn runFast(init: std.process.Init, comptime case: CaseKind, reader_kind: ReaderKind, input: []const u8, expected: []const u16, iterations: usize, decoder: anytype, decoder_name: []const u8) !Row {
    const chunks = try chunksForReader(init.gpa, reader_kind, input);
    defer if (reader_kind != .buffered) init.gpa.free(chunks);
    const coalesced = if (reader_kind.isCoalesced()) try coalesceChunks(init.gpa, chunks, input.len) else input;
    defer if (reader_kind.isCoalesced()) init.gpa.free(coalesced);
    const joined_scratch = if (reader_kind.isJoined()) try init.gpa.alloc(u8, input.len) else null;
    defer if (joined_scratch) |scratch| init.gpa.free(scratch);
    const start = std.Io.Clock.awake.now(init.io);
    var checksum: u64 = 0;
    for (0..iterations) |_| {
        switch (reader_kind) {
            .buffered, .coalesced_4096, .coalesced_64, .coalesced_1 => {
                var reader = bitstream.BufferedBitReader.init(coalesced);
                for (expected) |want| {
                    const got = try decoder.decodeValue(&reader);
                    if (got != want) return error.DecodeLengthMismatch;
                    checksum = checksum *% 131 +% got;
                }
            },
            .joined_4096, .joined_64, .joined_1 => {
                const joined = try joinChunksInto(chunks, joined_scratch.?);
                var reader = bitstream.BufferedBitReader.init(joined);
                for (expected) |want| {
                    const got = try decoder.decodeValue(&reader);
                    if (got != want) return error.DecodeLengthMismatch;
                    checksum = checksum *% 131 +% got;
                }
            },
            else => {
                var reader = try bitstream.ChunkedBitReader.init(chunks);
                for (expected) |want| {
                    const got = try decoder.decodeValue(&reader);
                    if (got != want) return error.DecodeLengthMismatch;
                    checksum = checksum *% 131 +% got;
                }
            },
        }
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    return row(case, reader_kind, decoder_name, case.lookupBits(), chunks.len, input.len, elapsed_ns, iterations, checksum);
}

fn chunksForReader(allocator: std.mem.Allocator, reader: ReaderKind, input: []const u8) ![]const []const u8 {
    return switch (reader) {
        .buffered => &.{},
        .chunked_4096, .coalesced_4096, .joined_4096 => makeChunks(allocator, input, 4096),
        .chunked_64, .coalesced_64, .joined_64 => makeChunks(allocator, input, 64),
        .chunked_1, .coalesced_1, .joined_1 => makeChunks(allocator, input, 1),
    };
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
            .dynamic_mixed => active[(i * 53 + (i >> 4)) % active_len],
            .dynamic_long_tail => active[(i * 97 + (i >> 2) + 17) % active_len],
        };
    }
}

fn encodeSymbols(allocator: std.mem.Allocator, encoder: *const huffman.HuffmanTable(288).Encoder, symbols: []const u16) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    for (symbols) |symbol| try encoder.writeSymbol(&writer, allocator, symbol);
    return writer.toOwnedSlice(allocator);
}

fn makeChunks(allocator: std.mem.Allocator, input: []const u8, chunk_len: usize) ![]const []const u8 {
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

fn coalesceChunks(allocator: std.mem.Allocator, chunks: []const []const u8, expected_len: usize) ![]u8 {
    const out = try allocator.alloc(u8, expected_len);
    errdefer allocator.free(out);
    return joinChunksInto(chunks, out);
}

fn joinChunksInto(chunks: []const []const u8, out: []u8) ![]u8 {
    var offset: usize = 0;
    for (chunks) |chunk| {
        if (offset > out.len or chunk.len > out.len - offset) return error.DecodeLengthMismatch;
        @memcpy(out[offset..][0..chunk.len], chunk);
        offset += chunk.len;
    }
    if (offset != out.len) return error.DecodeLengthMismatch;
    return out;
}

fn row(comptime case: CaseKind, reader: ReaderKind, decoder: []const u8, lookup_bits: u8, chunk_count: usize, input_len: usize, elapsed_ns: i128, iterations: usize, checksum: u64) Row {
    return .{
        .case = case.label(),
        .reader = reader.label(),
        .decoder = decoder,
        .lookup_bits = lookup_bits,
        .chunk_bytes = chunkBytes(reader),
        .chunk_count = chunk_count,
        .symbols_per_iter = symbols_per_iter,
        .iterations = iterations,
        .input_bytes = input_len * iterations,
        .elapsed_ns = elapsed_ns,
        .symbols_per_s = perSecond(symbols_per_iter * iterations, elapsed_ns),
        .mib_per_s = mibPerSecond(input_len * iterations, elapsed_ns),
        .checksum = checksum,
    };
}

fn chunkBytes(reader: ReaderKind) usize {
    return switch (reader) {
        .buffered => 0,
        .chunked_4096, .coalesced_4096, .joined_4096 => 4096,
        .chunked_64, .coalesced_64, .joined_64 => 64,
        .chunked_1, .coalesced_1, .joined_1 => 1,
    };
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

fn writeRow(writer: *std.Io.Writer, r: Row) !void {
    try writer.print("{s},{s},{s},{d},{d},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d}\n", .{
        r.case,
        r.reader,
        r.decoder,
        r.lookup_bits,
        r.chunk_bytes,
        r.chunk_count,
        r.symbols_per_iter,
        r.iterations,
        r.input_bytes,
        r.elapsed_ns,
        r.symbols_per_s,
        r.mib_per_s,
        r.checksum,
    });
}

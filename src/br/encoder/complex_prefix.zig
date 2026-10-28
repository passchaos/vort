const std = @import("std");
const huffman = @import("../../huffman.zig");
const code_length_huffman = @import("code_length_huffman.zig");
const code_length_rle = @import("code_length_rle.zig");
const small_huffman = @import("small_huffman.zig");

const code_length_order = [_]u5{ 1, 2, 3, 4, 0, 5, 17, 6, 16, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

pub const BitCostProfile = struct {
    calls: usize = 0,
    rle_tokens: usize = 0,
    code_length_active: usize = 0,
    input_lengths: usize = 0,
    zero_runs: usize = 0,
    nonzero_runs: usize = 0,
    zero_lengths: usize = 0,
    nonzero_lengths: usize = 0,
    literal_tokens: usize = 0,
    repeat16_tokens: usize = 0,
    repeat17_tokens: usize = 0,
    repeat_chain_buckets: [4]usize = @splat(0),
    rle_ns: u64 = 0,
    code_length_tree_ns: u64 = 0,
    header_ns: u64 = 0,
    encoder_ns: u64 = 0,
    payload_ns: u64 = 0,
    shape_ns: u64 = 0,
};

const BitCounter = struct {
    bits: usize = 0,

    pub fn writeBits(self: *@This(), _: std.mem.Allocator, _: u64, count: u6) !void {
        self.bits += count;
    }

    pub fn writeHuffmanBits(self: *@This(), _: std.mem.Allocator, _: u16, count: u4) !void {
        self.bits += count;
    }
};

/// Encode a Brotli complex prefix tree. Zero gaps use chained symbol-17 runs;
/// non-zero code lengths remain explicit for deterministic production output.
pub fn write(allocator: std.mem.Allocator, writer: anytype, alphabet_size: usize, lengths: []const u4) !void {
    if (lengths.len < alphabet_size) return error.InvalidBlockPlan;
    const stop_index = try code_length_rle.validatedStopIndex(lengths[0..alphabet_size]);
    return writeWithStopIndex(allocator, writer, alphabet_size, lengths, stop_index);
}

/// Encode a tree whose highest non-zero symbol is already known by the
/// caller. PrefixAlphabet maintains exactly that sparse symbol set, so its
/// wire path can avoid rescanning the complete dense code-length array.
pub fn writeWithStopIndex(allocator: std.mem.Allocator, writer: anytype, alphabet_size: usize, lengths: []const u4, stop_index: usize) !void {
    if (lengths.len < alphabet_size or stop_index == 0 or stop_index > alphabet_size or lengths[stop_index - 1] == 0) return error.InvalidBlockPlan;
    try writer.writeBits(allocator, 0, 2); // HSKIP=0, complex prefix.

    return if (alphabet_size <= 256)
        writeWithStorage(256, allocator, writer, lengths, stop_index)
    else if (alphabet_size <= 520)
        writeWithStorage(520, allocator, writer, lengths, stop_index)
    else
        writeWithStorage(704, allocator, writer, lengths, stop_index);
}

/// Exact number of bits produced by `writeWithStopIndex`, used to compare
/// alternate code-length plans without encoding the complete Brotli stream.
pub fn bitCost(allocator: std.mem.Allocator, alphabet_size: usize, lengths: []const u4, stop_index: usize) !usize {
    return bitCostInternal(false, allocator, alphabet_size, lengths, stop_index, {}, {});
}

pub fn bitCostProfiled(
    allocator: std.mem.Allocator,
    alphabet_size: usize,
    lengths: []const u4,
    stop_index: usize,
    io: std.Io,
    profile: *BitCostProfile,
) !usize {
    profile.calls += 1;
    return bitCostInternal(true, allocator, alphabet_size, lengths, stop_index, io, profile);
}

/// Exact complex-prefix bit cost for a byte alphabet whose non-zero code
/// lengths are already available in ascending symbol order. This is a
/// score-only path; the production writer retains its dense validated input.
pub fn bitCostSparse(
    allocator: std.mem.Allocator,
    lengths: []const u4,
    symbols: []const u8,
) !usize {
    return bitCostSparseInternal(false, allocator, lengths, symbols, {}, {});
}

pub fn bitCostSparseProfiled(
    allocator: std.mem.Allocator,
    lengths: []const u4,
    symbols: []const u8,
    io: std.Io,
    profile: *BitCostProfile,
) !usize {
    profile.calls += 1;
    return bitCostSparseInternal(true, allocator, lengths, symbols, io, profile);
}

fn bitCostInternal(
    comptime profiled: bool,
    allocator: std.mem.Allocator,
    alphabet_size: usize,
    lengths: []const u4,
    stop_index: usize,
    io: if (profiled) std.Io else void,
    profile: if (profiled) *BitCostProfile else void,
) !usize {
    if (lengths.len < alphabet_size or stop_index == 0 or stop_index > alphabet_size or lengths[stop_index - 1] == 0)
        return error.InvalidBlockPlan;
    var writer: BitCounter = .{};
    try writer.writeBits(allocator, 0, 2); // HSKIP=0, complex prefix.

    const rle_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    const summary = try code_length_rle.summarize(false, lengths, stop_index);
    if (profiled) {
        profile.rle_ns +%= elapsedNs(rle_start, io);
        try recordSummaryProfile(&summary, lengths, stop_index, io, profile);
    }

    return finishBitCost(profiled, allocator, &writer, &summary, io, profile);
}

fn bitCostSparseInternal(
    comptime profiled: bool,
    allocator: std.mem.Allocator,
    lengths: []const u4,
    symbols: []const u8,
    io: if (profiled) std.Io else void,
    profile: if (profiled) *BitCostProfile else void,
) !usize {
    if (symbols.len == 0) return error.InvalidBlockPlan;
    const stop_index = @as(usize, symbols[symbols.len - 1]) + 1;
    var writer: BitCounter = .{};
    try writer.writeBits(allocator, 0, 2); // HSKIP=0, complex prefix.

    const rle_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    const summary = try code_length_rle.summarizeSparse(false, lengths, symbols);
    if (profiled) {
        profile.rle_ns +%= elapsedNs(rle_start, io);
        try recordSummaryProfile(&summary, lengths, stop_index, io, profile);
    }

    return finishBitCost(profiled, allocator, &writer, &summary, io, profile);
}

fn recordSummaryProfile(
    summary: *const code_length_rle.Summary,
    lengths: []const u4,
    stop_index: usize,
    io: std.Io,
    profile: *BitCostProfile,
) !void {
    profile.rle_tokens += summary.token_count;
    for (summary.frequencies) |frequency|
        profile.code_length_active += @intFromBool(frequency != 0);
    const shape_start = std.Io.Clock.awake.now(io);
    const shape = try code_length_rle.summarize(true, lengths, stop_index);
    std.debug.assert(summary.token_count == shape.token_count);
    std.debug.assert(summary.repeat16_tokens == shape.repeat16_tokens);
    std.debug.assert(summary.repeat17_tokens == shape.repeat17_tokens);
    std.debug.assert(std.mem.eql(u32, &summary.frequencies, &shape.frequencies));
    profile.input_lengths += shape.input_lengths;
    profile.zero_runs += shape.zero_runs;
    profile.nonzero_runs += shape.nonzero_runs;
    profile.zero_lengths += shape.zero_lengths;
    profile.nonzero_lengths += shape.nonzero_lengths;
    profile.literal_tokens += shape.literal_tokens;
    profile.repeat16_tokens += shape.repeat16_tokens;
    profile.repeat17_tokens += shape.repeat17_tokens;
    for (&profile.repeat_chain_buckets, shape.repeat_chain_buckets) |*total, count|
        total.* += count;
    profile.shape_ns +%= elapsedNs(shape_start, io);
}

fn finishBitCost(
    comptime profiled: bool,
    allocator: std.mem.Allocator,
    writer: *BitCounter,
    summary: *const code_length_rle.Summary,
    io: if (profiled) std.Io else void,
    profile: if (profiled) *BitCostProfile else void,
) !usize {
    const code_length_tree_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    const code_length_lengths = codeLengthCodeLengths(&summary.frequencies);
    if (profiled) profile.code_length_tree_ns +%= elapsedNs(code_length_tree_start, io);

    const header_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    var space: i32 = 32;
    for (code_length_order) |symbol| {
        const length = code_length_lengths[symbol];
        try writeCodeLengthCodeLength(allocator, writer, length);
        if (length != 0) {
            space -= @intCast(@as(u32, 32) >> length);
            if (space < 0) return error.InvalidHuffmanCode;
            if (space == 0) break;
        }
    }
    if (space != 0) return error.InvalidHuffmanCode;
    if (profiled) profile.header_ns +%= elapsedNs(header_start, io);

    const payload_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    for (summary.frequencies, code_length_lengths) |frequency, length|
        writer.bits += @as(usize, frequency) * length;
    writer.bits += @as(usize, summary.repeat16_tokens) * 2;
    writer.bits += @as(usize, summary.repeat17_tokens) * 3;
    if (profiled) profile.payload_ns +%= elapsedNs(payload_start, io);
    return writer.bits;
}

test "bit cost matches emitted complex prefix" {
    const CountingWriter = struct {
        bits: usize = 0,
        pub fn writeBits(self: *@This(), _: std.mem.Allocator, _: u64, count: u6) !void {
            self.bits += count;
        }
        pub fn writeHuffmanBits(self: *@This(), _: std.mem.Allocator, _: u16, count: u4) !void {
            self.bits += count;
        }
    };
    var lengths: [256]u4 = @splat(0);
    lengths['a'] = 2;
    lengths['b'] = 2;
    lengths['c'] = 2;
    lengths['d'] = 2;
    var writer: CountingWriter = .{};
    try writeWithStopIndex(std.testing.allocator, &writer, lengths.len, &lengths, 'd' + 1);
    try std.testing.expectEqual(writer.bits, try bitCost(std.testing.allocator, lengths.len, &lengths, 'd' + 1));
}

test "summary bit cost matches emitted mixed prefix shapes" {
    const CountingWriter = struct {
        bits: usize = 0,
        pub fn writeBits(self: *@This(), _: std.mem.Allocator, _: u64, count: u6) !void {
            self.bits += count;
        }
        pub fn writeHuffmanBits(self: *@This(), _: std.mem.Allocator, _: u16, count: u4) !void {
            self.bits += count;
        }
    };
    var state: u32 = 0x9e37_79b9;
    for ([_]usize{ 256, 520, 704 }) |alphabet_size| {
        for (0..32) |_| {
            var lengths: [704]u4 = @splat(0);
            for (lengths[0..alphabet_size]) |*length| {
                state = state *% 1_664_525 +% 1_013_904_223;
                length.* = if (state & 7 < 5) 0 else @intCast(1 + (state >> 28) % 8);
            }
            lengths[alphabet_size - 1] = 3;
            var writer: CountingWriter = .{};
            try writeWithStopIndex(std.testing.allocator, &writer, alphabet_size, &lengths, alphabet_size);
            try std.testing.expectEqual(
                writer.bits,
                try bitCost(std.testing.allocator, alphabet_size, &lengths, alphabet_size),
            );
            if (alphabet_size == 256) {
                var symbols: [256]u8 = undefined;
                var symbol_count: usize = 0;
                for (lengths[0..alphabet_size], 0..) |length, symbol| {
                    if (length == 0) continue;
                    symbols[symbol_count] = @intCast(symbol);
                    symbol_count += 1;
                }
                try std.testing.expectEqual(
                    writer.bits,
                    try bitCostSparse(std.testing.allocator, lengths[0..alphabet_size], symbols[0..symbol_count]),
                );
            }
        }
    }
}

test "sparse bit cost preserves byte-alphabet boundaries" {
    var lengths: [256]u4 = @splat(0);
    lengths[0] = 2;
    lengths[1] = 2;
    lengths[2] = 2;
    lengths[127] = 3;
    lengths[255] = 3;
    const symbols = [_]u8{ 0, 1, 2, 127, 255 };
    try std.testing.expectEqual(
        try bitCost(std.testing.allocator, lengths.len, &lengths, lengths.len),
        try bitCostSparse(std.testing.allocator, &lengths, &symbols),
    );
}

test "post RLE frequencies preserve prefix scores but not wire bytes" {
    const BitWriter = @import("bit_writer.zig").Writer;
    const allocator = std.testing.allocator;
    var shapes: [2][2][256]u4 = @splat(@splat(@splat(0)));
    // Both trees satisfy Kraft equality, but repeat-16 extras differ.
    @memset(shapes[0][0][0..5], 3);
    @memset(shapes[0][0][5..11], 4);
    @memset(shapes[0][1][0..6], 3);
    @memset(shapes[0][1][6..10], 4);
    // The same tree after leading zero gaps 3 and 10 has different repeat-17
    // extras while retaining one repeat-17 token and identical frequencies.
    for ([_]usize{ 3, 10 }, 0..) |gap, index| {
        @memset(shapes[1][index][gap..][0..5], 3);
        @memset(shapes[1][index][gap + 5 ..][0..6], 4);
    }
    for (shapes, 0..) |pair, pair_index| {
        var summaries: [2]code_length_rle.Summary = undefined;
        var scores: [2]usize = undefined;
        var wires: [2]std.ArrayList(u8) = .{ .empty, .empty };
        defer for (&wires) |*wire| wire.deinit(allocator);
        for (&pair, 0..) |*lengths, index| {
            var symbols: [256]u8 = undefined;
            var count: usize = 0;
            var kraft: u32 = 0;
            for (lengths, 0..) |length, symbol| {
                if (length == 0) continue;
                symbols[count] = @intCast(symbol);
                count += 1;
                kraft += @as(u32, 1) << @intCast(15 - length);
            }
            try std.testing.expectEqual(@as(u32, 1 << 15), kraft);
            summaries[index] = try code_length_rle.summarizeSparse(false, lengths, symbols[0..count]);
            const summary = summaries[index];
            try std.testing.expectEqual(@as(usize, summary.frequencies[16]), summary.repeat16_tokens);
            try std.testing.expectEqual(@as(usize, summary.frequencies[17]), summary.repeat17_tokens);
            try std.testing.expectEqual(@as(u32, 2), summary.frequencies[16]);
            try std.testing.expectEqual(@as(u32, @intCast(pair_index)), summary.frequencies[17]);
            scores[index] = try bitCostSparse(allocator, lengths, symbols[0..count]);
            var writer: BitWriter = .{ .out = &wires[index] };
            const stop_index = @as(usize, symbols[count - 1]) + 1;
            try writeWithStopIndex(allocator, &writer, lengths.len, lengths, stop_index);
            try std.testing.expectEqual(@as(u64, scores[index]), writer.bitPosition());
        }
        try std.testing.expectEqual(summaries[0].frequencies, summaries[1].frequencies);
        try std.testing.expectEqual(scores[0], scores[1]);
        try std.testing.expect(!std.mem.eql(u8, wires[0].items, wires[1].items));
    }
}

fn writeWithStorage(
    comptime storage_len: usize,
    allocator: std.mem.Allocator,
    writer: anytype,
    lengths: []const u4,
    stop_index: usize,
) !void {
    var rle_storage: [storage_len]code_length_rle.Token = undefined;
    var code_length_freqs: [18]u32 = undefined;
    const rle_len = try code_length_rle.encodeIntoWithFrequencies(&rle_storage, lengths, stop_index, &code_length_freqs);
    const rle = rle_storage[0..rle_len];

    const code_length_lengths = codeLengthCodeLengths(&code_length_freqs);

    var space: i32 = 32;
    for (code_length_order) |symbol| {
        const length = code_length_lengths[symbol];
        try writeCodeLengthCodeLength(allocator, writer, length);
        if (length != 0) {
            space -= @intCast(@as(u32, 32) >> length);
            if (space < 0) return error.InvalidHuffmanCode;
            if (space == 0) break;
        }
    }
    if (space != 0) return error.InvalidHuffmanCode;

    const encoder = try huffman.HuffmanTable(18).Encoder.init(&code_length_lengths);
    for (rle) |token| {
        try writer.writeHuffmanBits(allocator, encoder.codes[token.symbol], encoder.bits[token.symbol]);
        if (token.symbol == 17) try writer.writeBits(allocator, token.extra, 3);
        if (token.symbol == 16) try writer.writeBits(allocator, token.extra, 2);
    }
}

fn elapsedNs(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

/// The code-length alphabet has at most 18 live symbols. Its dedicated builder
/// writes depths straight to the original symbols and reserves package merge
/// for the rare shape whose unbounded tree exceeds Brotli's five-bit limit.
fn codeLengthCodeLengths(frequencies: *const [18]u32) [18]u4 {
    return code_length_huffman.build(frequencies) orelse
        huffman.treeCodeLengths(18, frequencies, 5);
}

/// Previous production implementation retained as an exact test oracle. It
/// deliberately repeats the compact ordering and scatter that the dedicated
/// builder removes from the hot path.
fn codeLengthCodeLengthsReference(frequencies: *const [18]u32) [18]u4 {
    var symbols: [18]u16 = undefined;
    var compact_frequencies: [18]u32 = undefined;
    var active: usize = 0;
    for (frequencies, 0..) |frequency, symbol| {
        if (frequency == 0) continue;
        var index = active;
        while (index != 0 and frequency > compact_frequencies[index - 1]) : (index -= 1) {
            compact_frequencies[index] = compact_frequencies[index - 1];
            symbols[index] = symbols[index - 1];
        }
        compact_frequencies[index] = frequency;
        symbols[index] = @intCast(symbol);
        active += 1;
    }
    if (active == 0) return @splat(0);

    var compact_lengths: [18]u4 = undefined;
    if (small_huffman.build(18, compact_frequencies[0..active], &compact_lengths)) {
        for (compact_lengths[0..active]) |length| if (length > 5)
            return huffman.treeCodeLengths(18, frequencies, 5);
        var lengths: [18]u4 = @splat(0);
        for (symbols[0..active], compact_lengths[0..active]) |symbol, length| lengths[symbol] = length;
        return lengths;
    }
    return huffman.treeCodeLengths(18, frequencies, 5);
}

fn writeCodeLengthCodeLength(allocator: std.mem.Allocator, writer: anytype, length: u4) !void {
    switch (length) {
        0 => try writer.writeBits(allocator, 0b00, 2),
        1 => try writer.writeBits(allocator, 0b0111, 4),
        2 => try writer.writeBits(allocator, 0b011, 3),
        3 => try writer.writeBits(allocator, 0b10, 2),
        4 => try writer.writeBits(allocator, 0b01, 2),
        5 => try writer.writeBits(allocator, 0b1111, 4),
        else => return error.InvalidBlockPlan,
    }
}

test "precomputed complex prefix stop index is validated" {
    const TestWriter = struct {
        fn writeBits(_: *@This(), _: std.mem.Allocator, _: u64, _: u6) !void {}
        fn writeHuffmanBits(_: *@This(), _: std.mem.Allocator, _: u16, _: u4) !void {}
    };
    var writer = TestWriter{};
    var lengths: [8]u4 = @splat(0);
    lengths[0] = 1;
    try std.testing.expectError(error.InvalidBlockPlan, writeWithStopIndex(std.testing.allocator, &writer, lengths.len, &lengths, 0));
    try std.testing.expectError(error.InvalidBlockPlan, writeWithStopIndex(std.testing.allocator, &writer, lengths.len, &lengths, lengths.len + 1));
    try std.testing.expectError(error.InvalidBlockPlan, writeWithStopIndex(std.testing.allocator, &writer, lengths.len, &lengths, 2));
}

test "small code-length alphabet matches package-merge weighted cost" {
    var state: u32 = 0x4f1b_2c3d;
    for (0..1024) |_| {
        var frequencies: [18]u32 = @splat(0);
        for (&frequencies) |*frequency| {
            state = state *% 1_664_525 +% 1_013_904_223;
            frequency.* = if (state & 3 == 0) 0 else 1 + (state >> 24);
        }
        const actual = codeLengthCodeLengths(&frequencies);
        const reference = huffman.treeCodeLengths(18, &frequencies, 5);
        var actual_cost: u64 = 0;
        var reference_cost: u64 = 0;
        var actual_declaration_bits: usize = 0;
        var reference_declaration_bits: usize = 0;
        var actual_space: usize = 32;
        var reference_space: usize = 32;
        for (frequencies, actual, reference) |frequency, actual_length, reference_length| {
            try std.testing.expect(actual_length <= 5);
            actual_cost += @as(u64, frequency) * actual_length;
            reference_cost += @as(u64, frequency) * reference_length;
        }
        for (code_length_order) |symbol| {
            const actual_length = actual[symbol];
            actual_declaration_bits += codeLengthCodeLengthBits(actual_length);
            if (actual_length != 0) {
                actual_space -= @as(usize, 32) >> actual_length;
                if (actual_space == 0) break;
            }
        }
        for (code_length_order) |symbol| {
            const length = reference[symbol];
            reference_declaration_bits += codeLengthCodeLengthBits(length);
            if (length != 0) {
                reference_space -= @as(usize, 32) >> length;
                if (reference_space == 0) break;
            }
        }
        try std.testing.expectEqual(reference_cost, actual_cost);
        try std.testing.expectEqual(@as(usize, 0), actual_space);
        try std.testing.expectEqual(@as(usize, 0), reference_space);
        try std.testing.expect(actual_declaration_bits <= reference_declaration_bits);
    }
}

test "direct code-length builder exactly matches previous implementation" {
    const edge_cases = [_][18]u32{
        @splat(0),
        @splat(1),
        @splat(std.math.maxInt(u32)),
        .{ 1, 1, 2, 4, 8, 16, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9 },
    };
    for (edge_cases) |frequencies| {
        const actual = codeLengthCodeLengths(&frequencies);
        const expected = codeLengthCodeLengthsReference(&frequencies);
        try std.testing.expectEqualSlices(u4, &expected, &actual);
    }

    var state: u32 = 0x6a09_e667;
    for (0..16_384) |_| {
        var frequencies: [18]u32 = undefined;
        for (&frequencies) |*frequency| {
            state = state *% 1_664_525 +% 1_013_904_223;
            frequency.* = switch (state & 7) {
                0, 1 => 0,
                2, 3 => 1 + (state >> 29),
                4 => std.math.maxInt(u32) - (state >> 28),
                else => 1 + (state >> 8),
            };
        }
        const actual = codeLengthCodeLengths(&frequencies);
        const expected = codeLengthCodeLengthsReference(&frequencies);
        try std.testing.expectEqualSlices(u4, &expected, &actual);
    }
}

fn codeLengthCodeLengthBits(length: u4) usize {
    return switch (length) {
        0, 3, 4 => 2,
        2 => 3,
        1, 5 => 4,
        else => unreachable,
    };
}

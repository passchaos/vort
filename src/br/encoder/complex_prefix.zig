const std = @import("std");
const huffman = @import("../../huffman.zig");
const code_length_rle = @import("code_length_rle.zig");
const small_huffman = @import("small_huffman.zig");

const code_length_order = [_]u5{ 1, 2, 3, 4, 0, 5, 17, 6, 16, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

pub const BitCostProfile = struct {
    calls: usize = 0,
    rle_tokens: usize = 0,
    code_length_active: usize = 0,
    rle_ns: u64 = 0,
    code_length_tree_ns: u64 = 0,
    header_ns: u64 = 0,
    encoder_ns: u64 = 0,
    payload_ns: u64 = 0,
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
    return writeWithStopIndexInternal(false, allocator, writer, alphabet_size, lengths, stop_index, {}, {});
}

fn writeWithStopIndexInternal(
    comptime profiled: bool,
    allocator: std.mem.Allocator,
    writer: anytype,
    alphabet_size: usize,
    lengths: []const u4,
    stop_index: usize,
    io: if (profiled) std.Io else void,
    profile: if (profiled) *BitCostProfile else void,
) !void {
    if (lengths.len < alphabet_size or stop_index == 0 or stop_index > alphabet_size or lengths[stop_index - 1] == 0) return error.InvalidBlockPlan;
    try writer.writeBits(allocator, 0, 2); // HSKIP=0, complex prefix.

    return if (alphabet_size <= 256)
        writeWithStorage(256, profiled, allocator, writer, lengths, stop_index, io, profile)
    else if (alphabet_size <= 520)
        writeWithStorage(520, profiled, allocator, writer, lengths, stop_index, io, profile)
    else
        writeWithStorage(704, profiled, allocator, writer, lengths, stop_index, io, profile);
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

fn bitCostInternal(
    comptime profiled: bool,
    allocator: std.mem.Allocator,
    alphabet_size: usize,
    lengths: []const u4,
    stop_index: usize,
    io: if (profiled) std.Io else void,
    profile: if (profiled) *BitCostProfile else void,
) !usize {
    const CountingWriter = struct {
        bits: usize = 0,

        pub fn writeBits(self: *@This(), _: std.mem.Allocator, _: u64, count: u6) !void {
            self.bits += count;
        }

        pub fn writeHuffmanBits(self: *@This(), _: std.mem.Allocator, _: u16, count: u4) !void {
            self.bits += count;
        }
    };
    var writer: CountingWriter = .{};
    try writeWithStopIndexInternal(profiled, allocator, &writer, alphabet_size, lengths, stop_index, io, profile);
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

fn writeWithStorage(
    comptime storage_len: usize,
    comptime profiled: bool,
    allocator: std.mem.Allocator,
    writer: anytype,
    lengths: []const u4,
    stop_index: usize,
    io: if (profiled) std.Io else void,
    profile: if (profiled) *BitCostProfile else void,
) !void {
    const rle_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    var rle_storage: [storage_len]code_length_rle.Token = undefined;
    var code_length_freqs: [18]u32 = undefined;
    const rle_len = try code_length_rle.encodeIntoWithFrequencies(&rle_storage, lengths, stop_index, &code_length_freqs);
    const rle = rle_storage[0..rle_len];
    if (profiled) {
        profile.rle_ns +%= elapsedNs(rle_start, io);
        profile.rle_tokens += rle_len;
        for (code_length_freqs) |frequency|
            profile.code_length_active += @intFromBool(frequency != 0);
    }

    const code_length_tree_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    const code_length_lengths = codeLengthCodeLengths(&code_length_freqs);
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

    const encoder_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    const encoder = try huffman.HuffmanTable(18).Encoder.init(&code_length_lengths);
    if (profiled) profile.encoder_ns +%= elapsedNs(encoder_start, io);
    const payload_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    for (rle) |token| {
        try writer.writeHuffmanBits(allocator, encoder.codes[token.symbol], encoder.bits[token.symbol]);
        if (token.symbol == 17) try writer.writeBits(allocator, token.extra, 3);
        if (token.symbol == 16) try writer.writeBits(allocator, token.extra, 2);
    }
    if (profiled) profile.payload_ns +%= elapsedNs(payload_start, io);
}

fn elapsedNs(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

/// The code-length alphabet has at most 18 live symbols. Its common trees fit
/// Brotli's five-bit limit without length limiting, so reuse the linear small
/// Huffman builder and reserve package merge for the rare over-depth shape.
fn codeLengthCodeLengths(frequencies: *const [18]u32) [18]u4 {
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

fn codeLengthCodeLengthBits(length: u4) usize {
    return switch (length) {
        0, 3, 4 => 2,
        2 => 3,
        1, 5 => 4,
        else => unreachable,
    };
}

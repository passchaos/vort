const std = @import("std");
const bitstream = @import("bitstream.zig");
const checksum = @import("checksum.zig");
const huffman = @import("huffman.zig");

/// PNG-tuned zlib encoder compatible with fdeflate's ultra-fast format.
///
/// The format intentionally trades general LZ77 matching for a static Huffman
/// tree and distance-one runs of zero bytes. Filtered PNG rows contain enough
/// zero residuals for that restricted model to be useful, while eliminating
/// hash tables, predecessor chains, and per-input Huffman construction.
pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) ![]u8 {
    var writer = try ReservoirWriter.init(allocator, input.len);
    errdefer writer.deinit(allocator);
    try writeInput(allocator, &writer, input, true);
    try writeSymbol(allocator, &writer, 256);
    try writer.flush(allocator);

    const footer_offset = writer.bytes.items.len;
    try writer.bytes.appendNTimes(allocator, 0, 4);
    std.mem.writeInt(
        u32,
        writer.bytes.items[footer_offset..][0..4],
        checksum.adler32(input),
        .big,
    );
    return writer.toOwnedSlice(allocator);
}

const zlib_dynamic_header = [54]u8{
    120, 1,   237, 192, 3,   160, 36,  89,  150, 198, 241, 255, 119, 238,
    141, 200, 204, 167, 114, 75,  99,  174, 109, 219, 182, 109, 219, 182,
    109, 219, 182, 109, 105, 140, 158, 150, 74,  175, 158, 50,  51,  34,
    238, 249, 118, 183, 106, 122, 166, 135, 59,  107, 213, 15,
};

const literal_lengths = [286]u4{
    2,  3,  4,  5,  5,  6,  6,  7,  7,  7,  8,  8,  8,  8,  8,  9,
    9,  9,  9,  9,  9,  9,  10, 10, 10, 10, 10, 10, 10, 10, 10, 11,
    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11,
    10, 11, 10, 10, 10, 10, 10, 10, 10, 10, 10, 9,  9,  9,  9,  9,
    8,  9,  8,  8,  8,  8,  8,  7,  7,  7,  6,  6,  6,  5,  4,  3,
    12, 12, 12, 9,  9,  11, 10, 11, 11, 10, 11, 11, 11, 11, 11, 11,
    12, 11, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 9,
};

const literal_codes = makeCanonicalCodes(literal_lengths);
const literal_pairs = makeLiteralPairs();

/// Read-only syntax shared by the incremental encoder. One-shot emission and
/// its numeric tables remain the canonical PNG-trained format definition.
pub const incremental_syntax = struct {
    pub const header = zlib_dynamic_header;
    pub const lengths = literal_lengths;
    pub const codes = literal_codes;
    pub const length = lengthCode;
};

fn makeLiteralPairs() [1 << 16]u64 {
    @setEvalBranchQuota(1_000_000);
    var pairs: [1 << 16]u64 = undefined;
    for (&pairs, 0..) |*pair, index| {
        const b0: u8 = @truncate(index);
        const b1: u8 = @truncate(index >> 8);
        const n0: u6 = literal_lengths[b0];
        const n1: u6 = literal_lengths[b1];
        const bits = @as(u64, literal_codes[b0]) |
            (@as(u64, literal_codes[b1]) << n0);
        pair.* = bits | (@as(u64, n0 + n1) << 56);
    }
    return pairs;
}

const ReservoirWriter = struct {
    bytes: std.ArrayList(u8),
    buffer: u64,
    bit_count: u7,

    fn init(
        allocator: std.mem.Allocator,
        input_len: usize,
    ) !ReservoirWriter {
        var bytes = try std.ArrayList(u8).initCapacity(
            allocator,
            @max(zlib_dynamic_header.len + 4, input_len / 4),
        );
        bytes.appendSliceAssumeCapacity(zlib_dynamic_header[0..53]);
        return .{
            .bytes = bytes,
            .buffer = zlib_dynamic_header[53] & 0x1f,
            .bit_count = 5,
        };
    }

    fn deinit(self: *ReservoirWriter, allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
        self.* = undefined;
    }

    inline fn writeBits(
        self: *ReservoirWriter,
        allocator: std.mem.Allocator,
        bits: u64,
        count: u6,
    ) !void {
        std.debug.assert(count <= 56);
        const old_count = self.bit_count;
        self.buffer |= bits << @intCast(old_count);
        const total: u7 = old_count + count;
        if (total < 64) {
            self.bit_count = total;
            return;
        }

        var encoded: [8]u8 = undefined;
        std.mem.writeInt(u64, &encoded, self.buffer, .little);
        // Most flushes fit the initial/grown allocation. Avoid routing every
        // eight emitted bytes through ArrayList's generic capacity helper,
        // while retaining its exact growth and allocation-failure behavior.
        if (self.bytes.capacity - self.bytes.items.len >= encoded.len) {
            self.bytes.appendSliceAssumeCapacity(&encoded);
        } else {
            try self.bytes.appendSlice(allocator, &encoded);
        }
        self.bit_count = total - 64;

        // The low (64-old_count) bits were just emitted. A shift by 64 is
        // represented explicitly because Zig rejects an in-range u6 shift of
        // that value, while fdeflate's checked shift returns zero.
        const consumed_from_bits: u7 = 64 - old_count;
        self.buffer = if (consumed_from_bits == 64)
            0
        else
            bits >> @intCast(consumed_from_bits);
    }

    fn flush(self: *ReservoirWriter, allocator: std.mem.Allocator) !void {
        if (self.bit_count == 0) return;
        const byte_count: usize = (@as(usize, self.bit_count) + 7) / 8;
        var encoded: [8]u8 = undefined;
        std.mem.writeInt(u64, &encoded, self.buffer, .little);
        try self.bytes.appendSlice(allocator, encoded[0..byte_count]);
        self.buffer = 0;
        self.bit_count = 0;
    }

    fn toOwnedSlice(
        self: *ReservoirWriter,
        allocator: std.mem.Allocator,
    ) ![]u8 {
        const result = try self.bytes.toOwnedSlice(allocator);
        self.* = undefined;
        return result;
    }
};

fn makeCanonicalCodes(lengths: [286]u4) [286]u16 {
    @setEvalBranchQuota(100_000);
    var codes: [286]u16 = @splat(0);
    var code: u32 = 0;
    var bit_len: u5 = 1;
    while (bit_len <= 16) : (bit_len += 1) {
        for (lengths, 0..) |length, symbol| {
            if (length != bit_len) continue;
            const canonical: u16 = @intCast(code);
            codes[symbol] = @bitReverse(canonical) >> @intCast(16 - bit_len);
            code += 1;
        }
        code <<= 1;
    }
    std.debug.assert(code == (@as(u32, 2) << 16));
    return codes;
}

fn encodeAllocWithLiteralPolicy(
    allocator: std.mem.Allocator,
    input: []const u8,
    comptime batch_literals: bool,
) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);

    // Keep the same modest reserve as fdeflate. The trained tree can expand
    // adversarial data beyond this estimate; BitWriter remains growable.
    try writer.bytes.ensureTotalCapacity(
        allocator,
        @max(zlib_dynamic_header.len + 4, input.len / 4),
    );
    writer.bytes.appendSliceAssumeCapacity(zlib_dynamic_header[0..53]);
    writer.scratch = zlib_dynamic_header[53] & 0x1f;
    writer.bit_index = 5;

    try writeInput(allocator, &writer, input, batch_literals);
    try writeSymbol(allocator, &writer, 256);
    try writer.alignToByte(allocator);

    const footer_offset = writer.bytes.items.len;
    try writer.bytes.appendNTimes(allocator, 0, 4);
    std.mem.writeInt(
        u32,
        writer.bytes.items[footer_offset..][0..4],
        checksum.adler32(input),
        .big,
    );
    const encoded = try writer.bytes.toOwnedSlice(allocator);
    writer = .{};
    return encoded;
}

fn writeInput(
    allocator: std.mem.Allocator,
    writer: anytype,
    input: []const u8,
    comptime batch_literals: bool,
) !void {
    var run: usize = 0;
    const whole_len = input.len & ~@as(usize, 7);
    var offset: usize = 0;
    while (offset < whole_len) : (offset += 8) {
        const chunk = input[offset..][0..8];
        const word = std.mem.readInt(u64, chunk, .little);
        if (word == 0) {
            run += 8;
            continue;
        }
        if (run != 0) {
            const prefix_zeros = @ctz(word) / 8;
            try writeZeroRun(allocator, writer, run + prefix_zeros);
            run = 0;
            if (prefix_zeros != 0) {
                const suffix_zeros = @clz(word) / 8;
                if (batch_literals) {
                    const literal_count: u4 =
                        @intCast(8 - prefix_zeros - suffix_zeros);
                    try writeLiteralPrefix(
                        allocator,
                        writer,
                        word >> @intCast(prefix_zeros * 8),
                        literal_count,
                    );
                } else {
                    try writeLiterals(
                        allocator,
                        writer,
                        chunk[prefix_zeros .. 8 - suffix_zeros],
                        batch_literals,
                    );
                }
                run = suffix_zeros;
                continue;
            }
        }

        const suffix_zeros = @clz(word) / 8;
        if (suffix_zeros != 0) {
            if (batch_literals) {
                // Reuse the word loaded for run detection for every boundary
                // shape. Small PNGs have many words ending in two or more
                // zeros; pair/triple/quad combinations avoid reloading their
                // literal prefix and emitting its bytes one symbol at a time.
                try writeLiteralPrefix(
                    allocator,
                    writer,
                    word,
                    @intCast(8 - suffix_zeros),
                );
            } else {
                try writeLiterals(
                    allocator,
                    writer,
                    chunk[0 .. 8 - suffix_zeros],
                    batch_literals,
                );
            }
            run = suffix_zeros;
            continue;
        }
        if (batch_literals) {
            // The common PNG chunk has no boundary zero run. Reuse the word
            // already loaded for run detection instead of entering the
            // variable-slice literal helper and loading all eight bytes again.
            try writeLiteralQuad(
                allocator,
                writer,
                @truncate(word),
                @truncate(word >> 16),
            );
            try writeLiteralQuad(
                allocator,
                writer,
                @truncate(word >> 32),
                @truncate(word >> 48),
            );
        } else {
            try writeLiterals(allocator, writer, chunk, false);
        }
    }

    if (run != 0) try writeZeroRun(allocator, writer, run);
    try writeLiterals(
        allocator,
        writer,
        input[whole_len..],
        batch_literals,
    );
}

inline fn writeLiteralPrefix(
    allocator: std.mem.Allocator,
    writer: anytype,
    word: u64,
    literal_count: u4,
) !void {
    std.debug.assert(literal_count >= 1 and literal_count <= 7);
    const pair0: u16 = @truncate(word);
    const pair1: u16 = @truncate(word >> 16);
    switch (literal_count) {
        1 => try writeSymbol(allocator, writer, @as(u8, @truncate(word))),
        2 => try writeLiteralPair(allocator, writer, pair0),
        3 => try writeLiteralTriple(
            allocator,
            writer,
            pair0,
            @truncate(word >> 16),
        ),
        4 => try writeLiteralQuad(allocator, writer, pair0, pair1),
        5 => {
            try writeLiteralQuad(allocator, writer, pair0, pair1);
            try writeSymbol(
                allocator,
                writer,
                @as(u8, @truncate(word >> 32)),
            );
        },
        6 => {
            try writeLiteralQuad(allocator, writer, pair0, pair1);
            try writeLiteralPair(
                allocator,
                writer,
                @truncate(word >> 32),
            );
        },
        7 => {
            try writeLiteralQuad(allocator, writer, pair0, pair1);
            try writeLiteralTriple(
                allocator,
                writer,
                @truncate(word >> 32),
                @truncate(word >> 48),
            );
        },
        else => unreachable,
    }
}

fn writeLiterals(
    allocator: std.mem.Allocator,
    writer: anytype,
    bytes: []const u8,
    comptime batch_literals: bool,
) !void {
    var offset: usize = 0;
    if (batch_literals) {
        while (offset + 4 <= bytes.len) : (offset += 4) {
            const pair0_index = std.mem.readInt(
                u16,
                bytes[offset..][0..2],
                .little,
            );
            const pair1_index = std.mem.readInt(
                u16,
                bytes[offset + 2 ..][0..2],
                .little,
            );
            try writeLiteralQuad(
                allocator,
                writer,
                pair0_index,
                pair1_index,
            );
        }
    }
    while (offset < bytes.len) : (offset += 1) {
        try writeSymbol(allocator, writer, bytes[offset]);
    }
}

inline fn writeLiteralPair(
    allocator: std.mem.Allocator,
    writer: anytype,
    pair_index: u16,
) !void {
    const pair = literal_pairs[pair_index];
    const count: u6 = @truncate(pair >> 56);
    try writer.writeBits(
        allocator,
        pair & 0x00ff_ffff_ffff_ffff,
        count,
    );
}

inline fn writeLiteralQuad(
    allocator: std.mem.Allocator,
    writer: anytype,
    pair0_index: u16,
    pair1_index: u16,
) !void {
    const pair0 = literal_pairs[pair0_index];
    const pair1 = literal_pairs[pair1_index];
    const n0: u6 = @truncate(pair0 >> 56);
    const n1: u6 = @truncate(pair1 >> 56);
    const bits = (pair0 & 0x00ff_ffff_ffff_ffff) |
        ((pair1 & 0x00ff_ffff_ffff_ffff) << n0);
    try writer.writeBits(allocator, bits, n0 + n1);
}

inline fn writeLiteralTriple(
    allocator: std.mem.Allocator,
    writer: anytype,
    pair_index: u16,
    last: u8,
) !void {
    const pair = literal_pairs[pair_index];
    const pair_count: u6 = @truncate(pair >> 56);
    const last_count: u6 = literal_lengths[last];
    const bits = (pair & 0x00ff_ffff_ffff_ffff) |
        (@as(u64, literal_codes[last]) << pair_count);
    try writer.writeBits(allocator, bits, pair_count + last_count);
}

fn writeZeroRun(
    allocator: std.mem.Allocator,
    writer: anytype,
    run_len: usize,
) !void {
    std.debug.assert(run_len > 0);
    try writeSymbol(allocator, writer, 0);
    var remaining = run_len - 1;
    while (remaining >= 258) : (remaining -= 258) {
        // Length symbol 285 followed by the one-bit distance-zero code.
        try writer.writeBits(
            allocator,
            literal_codes[285],
            literal_lengths[285] + 1,
        );
    }
    if (remaining > 4) {
        const length = lengthCode(remaining);
        try writeSymbol(allocator, writer, length.symbol);
        // The length extra bits are followed by distance symbol zero.
        try writer.writeBits(
            allocator,
            length.extra,
            length.extra_bits + 1,
        );
    } else {
        var i: usize = 0;
        while (i < remaining) : (i += 1) {
            try writeSymbol(allocator, writer, 0);
        }
    }
}

const LengthCode = struct {
    symbol: u16,
    extra: u16,
    extra_bits: u4,
};

fn lengthCode(length: usize) LengthCode {
    std.debug.assert(length >= 3 and length <= 258);
    return length_code_table[length - 3];
}

const length_code_table = makeLengthCodeTable();

fn makeLengthCodeTable() [256]LengthCode {
    @setEvalBranchQuota(10_000);
    var table: [256]LengthCode = undefined;
    for (&table, 3..) |*entry, length| {
        entry.* = lengthCodeReference(length);
    }
    return table;
}

fn lengthCodeReference(length: usize) LengthCode {
    std.debug.assert(length >= 3 and length <= 258);
    const bases = [29]u16{
        3,  4,  5,  6,  7,  8,  9,  10, 11,  13,  15,  17,  19,  23,  27,
        31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
    };
    const extras = [29]u4{
        0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2,
        2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
    };
    for (bases, extras, 0..) |base, extra_bits, i| {
        const span: usize = if (extra_bits == 0)
            1
        else
            @as(usize, 1) << extra_bits;
        if (length >= base and length < @as(usize, base) + span) {
            return .{
                .symbol = @intCast(257 + i),
                .extra = @intCast(length - base),
                .extra_bits = extra_bits,
            };
        }
    }
    unreachable;
}

fn writeSymbol(
    allocator: std.mem.Allocator,
    writer: anytype,
    symbol: usize,
) !void {
    try writer.writeBits(
        allocator,
        literal_codes[symbol],
        literal_lengths[symbol],
    );
}

test "static PNG ultrafast header carries the trained tree" {
    try std.testing.expectEqualSlices(
        u8,
        &.{ 0x78, 0x01 },
        zlib_dynamic_header[0..2],
    );
    var reader = bitstream.BitReader.init(zlib_dynamic_header[2..]);
    const parsed = try huffman.parseDynamicLengths(&reader);
    try std.testing.expectEqual(@as(u16, 286), parsed.header.hlit);
    try std.testing.expectEqual(@as(u16, 1), parsed.header.hdist);
    try std.testing.expectEqualSlices(
        u4,
        &literal_lengths,
        &parsed.literal_lengths,
    );
    try std.testing.expectEqual(@as(u4, 1), parsed.distance_lengths[0]);
}

test "PNG ultrafast length lookup matches RFC range reference" {
    for (3..259) |length| {
        try std.testing.expectEqual(
            lengthCodeReference(length),
            lengthCode(length),
        );
    }
}

test "batched PNG ultrafast literals match scalar writer" {
    const inputs = [_][]const u8{
        "",
        "hello, world",
        &([_]u8{0} ** 600),
        &([_]u8{ 0, 1, 0, 2, 3, 0, 0, 4, 5, 6, 7, 8, 0 } ** 41),
    };
    for (inputs) |input| {
        const batched = try encodeAllocWithLiteralPolicy(
            std.testing.allocator,
            input,
            true,
        );
        defer std.testing.allocator.free(batched);
        const scalar = try encodeAllocWithLiteralPolicy(
            std.testing.allocator,
            input,
            false,
        );
        defer std.testing.allocator.free(scalar);
        try std.testing.expectEqualSlices(u8, scalar, batched);
    }
}

test "direct full PNG ultrafast chunks match scalar writer" {
    var input: [8 * 37 + 5]u8 = undefined;
    for (&input, 0..) |*byte, i| {
        // Keep every complete chunk off the boundary-zero paths while still
        // exercising short/long trained codes and a scalar tail.
        byte.* = @intCast((i * 73 + 19) % 255 + 1);
    }
    const encoded = try encodeAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(encoded);
    const scalar = try encodeAllocWithLiteralPolicy(
        std.testing.allocator,
        &input,
        false,
    );
    defer std.testing.allocator.free(scalar);
    try std.testing.expectEqualSlices(u8, scalar, encoded);
}

test "direct boundary literal prefixes match scalar writer" {
    const chunk_count = 255 * (1 + 2 + 3 + 4 + 5 + 6 + 7);
    var input: [8 * chunk_count]u8 = undefined;
    var chunk_index: usize = 0;
    for (1..8) |literal_count| {
        for (0..literal_count) |varied_position| {
            for (1..256) |value| {
                const chunk = input[chunk_index * 8 ..][0..8];
                @memset(chunk, 0);
                for (chunk[0..literal_count], 0..) |*byte, i| {
                    byte.* = @intCast(
                        (chunk_index * 29 + i * 47) % 255 + 1,
                    );
                }
                chunk[varied_position] = @intCast(value);
                chunk_index += 1;
            }
        }
    }
    try std.testing.expectEqual(chunk_count, chunk_index);
    const encoded = try encodeAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(encoded);
    const scalar = try encodeAllocWithLiteralPolicy(
        std.testing.allocator,
        &input,
        false,
    );
    defer std.testing.allocator.free(scalar);
    try std.testing.expectEqualSlices(u8, scalar, encoded);
}

test "direct literals after a carried zero run match scalar writer" {
    const chunk_count = comptime blk: {
        var count: usize = 0;
        for (1..8) |prefix_zeros| {
            for (0..8 - prefix_zeros) |suffix_zeros| {
                count += (8 - prefix_zeros - suffix_zeros) * 255;
            }
        }
        break :blk count;
    };
    var input: [16 * chunk_count]u8 = undefined;
    var chunk_index: usize = 0;
    for (1..8) |prefix_zeros| {
        for (0..8 - prefix_zeros) |suffix_zeros| {
            const literal_count = 8 - prefix_zeros - suffix_zeros;
            for (0..literal_count) |varied_position| {
                for (1..256) |value| {
                    const carried_zero_chunk =
                        input[chunk_index * 16 ..][0..8];
                    @memset(carried_zero_chunk, 0);
                    const boundary_chunk =
                        input[chunk_index * 16 + 8 ..][0..8];
                    @memset(boundary_chunk, 0);
                    for (
                        boundary_chunk[prefix_zeros .. prefix_zeros + literal_count],
                        0..,
                    ) |*byte, i| {
                        byte.* = @intCast(
                            (chunk_index * 31 + i * 43) % 255 + 1,
                        );
                    }
                    boundary_chunk[prefix_zeros + varied_position] =
                        @intCast(value);
                    chunk_index += 1;
                }
            }
        }
    }
    try std.testing.expectEqual(chunk_count, chunk_index);
    const encoded = try encodeAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(encoded);
    const scalar = try encodeAllocWithLiteralPolicy(
        std.testing.allocator,
        &input,
        false,
    );
    defer std.testing.allocator.free(scalar);
    try std.testing.expectEqualSlices(u8, scalar, encoded);
}

test "PNG ultrafast output matches fdeflate 0.3.7 goldens" {
    const Cases = struct {
        input: []const u8,
        hex: []const u8,
    };
    var mixed: [73]u8 = undefined;
    for (&mixed, 0..) |*byte, i| {
        byte.* = if (i % 7 < 3) 0 else @truncate(i * 37);
    }
    const cases = [_]Cases{
        .{
            .input = "",
            .hex = "7801edc003a0245996c6f1ff77ee8dc8cca7724b63ae6ddbb66ddbb66ddbb66d698c9e964aaf9e323322eef976b76a7aa6873b6bd5ef1f0100000001",
        },
        .{
            .input = "hello, world",
            .hex = "7801edc003a0245996c6f1ff77ee8dc8cca7724b63ae6ddbb66ddbb66ddbb66d698c9e964aaf9e323322eef976b76a7aa6873b6bd5ef833fe0c33ffca35efcc19ff4511ffbe1efff8f1d540489",
        },
        .{
            .input = &([_]u8{0} ** 300),
            .hex = "7801edc003a0245996c6f1ff77ee8dc8cca7724b63ae6ddbb66ddbb66ddbb66d698c9e964aaf9e323322eef976b76a7aa6873b6bd58fab5e2400ff08012c0001",
        },
        .{
            .input = &mixed,
            .hex = "7801edc003a0245996c6f1ff77ee8dc8cca7724b63ae6ddbb66ddbb66ddbb66d698c9e964aaf9e323322eef976b76a7aa6873b6bd50ff8a8afff95a7011ffb4dbffe0ce013bef5b7ee003ef93b7ef76ee0d3befb0fee033ef3fbfef83cf0393ff867bbc0e7ffc85fee035ff4e37f73047ce94ffdfd1af847eeca1c21",
        },
    };
    for (cases) |case| {
        const encoded = try encodeAlloc(std.testing.allocator, case.input);
        defer std.testing.allocator.free(encoded);
        try std.testing.expectEqual(case.hex.len / 2, encoded.len);
        const expected = try std.testing.allocator.alloc(u8, encoded.len);
        defer std.testing.allocator.free(expected);
        _ = try std.fmt.hexToBytes(expected, case.hex);
        try std.testing.expectEqualSlices(u8, expected, encoded);
    }
}

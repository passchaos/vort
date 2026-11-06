//! Independent RFC 1950/1951 test oracle. This deliberately does not use vort's
//! bit reader, Huffman tables, length/distance tables, decoder, or checksums.
const std = @import("std");

const Error = error{
    InvalidOracleDeflate,
    OracleOutputMismatch,
    OracleWindowViolation,
    OracleDictionaryIdMismatch,
    OracleChecksumMismatch,
};

pub const Stats = struct {
    blocks: [3]usize = @splat(0),
    literals: usize = 0,
    matches: usize = 0,
    matched_bytes: usize = 0,
    max_distance: usize = 0,
    max_length: usize = 0,
    dictionary_matches: usize = 0,
    cross_block_matches: usize = 0,
    target_matches: usize = 0,

    pub fn blockCount(self: Stats) usize {
        return self.blocks[0] + self.blocks[1] + self.blocks[2];
    }
};

const Bits = struct {
    bytes: []const u8,
    position: usize = 0,

    fn take(self: *Bits, count: u5) Error!usize {
        if (self.position > self.bytes.len * 8 or count > self.bytes.len * 8 - self.position)
            return error.InvalidOracleDeflate;
        var value: usize = 0;
        for (0..count) |i| {
            const bit = (self.bytes[self.position / 8] >> @as(u3, @intCast(self.position % 8))) & 1;
            value |= @as(usize, bit) << @as(std.math.Log2Int(usize), @intCast(i));
            self.position += 1;
        }
        return value;
    }

    fn byteAlign(self: *Bits) void {
        self.position = (self.position + 7) / 8 * 8;
    }
};

// Canonical-code decoding uses the received Huffman bits in MSB order. Numeric
// fields elsewhere in DEFLATE use the LSB order implemented by Bits.take.
const Huffman = struct {
    count: [16]u16 = @splat(0),
    first: [16]u16 = @splat(0),
    offset: [16]u16 = @splat(0),
    symbols: [288]u16 = undefined,

    fn init(lengths: []const u8) Error!Huffman {
        if (lengths.len > 288) return error.InvalidOracleDeflate;
        var self: Huffman = .{};
        for (lengths) |len| {
            if (len > 15) return error.InvalidOracleDeflate;
            if (len != 0) self.count[len] += 1;
        }
        var code: u32 = 0;
        var total: u16 = 0;
        for (1..16) |len| {
            code = (code + self.count[len - 1]) * 2;
            if (code + self.count[len] > @as(u32, 1) << @as(u5, @intCast(len)))
                return error.InvalidOracleDeflate;
            self.first[len] = @intCast(code);
            self.offset[len] = total;
            total += self.count[len];
        }
        var slots = self.offset;
        for (lengths, 0..) |len, index| {
            if (len == 0) continue;
            self.symbols[slots[len]] = @intCast(index);
            slots[len] += 1;
        }
        return self;
    }

    fn symbol(self: *const Huffman, bits: *Bits) Error!usize {
        var code: usize = 0;
        for (1..16) |len| {
            code = code * 2 + try bits.take(1);
            const first = self.first[len];
            if (code >= first and code - first < self.count[len])
                return self.symbols[self.offset[len] + code - first];
        }
        return error.InvalidOracleDeflate;
    }
};

const Trees = struct {
    literal: Huffman,
    distance: Huffman,

    fn fixed() Error!Trees {
        var literal_lengths: [288]u8 = undefined;
        @memset(literal_lengths[0..144], 8);
        @memset(literal_lengths[144..256], 9);
        @memset(literal_lengths[256..280], 7);
        @memset(literal_lengths[280..288], 8);
        const distance_lengths: [32]u8 = @splat(5);
        return .{
            .literal = try Huffman.init(&literal_lengths),
            .distance = try Huffman.init(&distance_lengths),
        };
    }

    fn dynamic(bits: *Bits) Error!Trees {
        const literal_count = 257 + try bits.take(5);
        const distance_count = 1 + try bits.take(5);
        const code_count = 4 + try bits.take(4);
        if (literal_count > 286) return error.InvalidOracleDeflate;
        const order = [_]u8{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
        var code_lengths: [19]u8 = @splat(0);
        for (order[0..code_count]) |index| code_lengths[index] = @intCast(try bits.take(3));
        const code_tree = try Huffman.init(&code_lengths);
        var lengths: [318]u8 = @splat(0);
        const total = literal_count + distance_count;
        var at: usize = 0;
        while (at < total) {
            const code = try code_tree.symbol(bits);
            if (code <= 15) {
                lengths[at] = @intCast(code);
                at += 1;
                continue;
            }
            const count = switch (code) {
                16 => 3 + try bits.take(2),
                17 => 3 + try bits.take(3),
                18 => 11 + try bits.take(7),
                else => return error.InvalidOracleDeflate,
            };
            if (count > total - at or (code == 16 and at == 0))
                return error.InvalidOracleDeflate;
            const value = if (code == 16) lengths[at - 1] else 0;
            @memset(lengths[at..][0..count], value);
            at += count;
        }
        if (lengths[256] == 0) return error.InvalidOracleDeflate;
        return .{
            .literal = try Huffman.init(lengths[0..literal_count]),
            .distance = try Huffman.init(lengths[literal_count..total]),
        };
    }
};

const length_base = [_]u16{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 };
const length_extra = [_]u5{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 };
const distance_base = [_]u16{ 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 };
const distance_extra = [_]u5{ 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 };

pub fn adler32(bytes: []const u8) u32 {
    var low: u32 = 1;
    var high: u32 = 0;
    for (bytes) |byte| {
        low = (low + byte) % 65521;
        high = (high + low) % 65521;
    }
    return high << 16 | low;
}

/// Validate every emitted token, including references whose source crosses a
/// block boundary or lies in the retained dictionary suffix. Replaying against
/// expected bytes makes correctness checks allocation-free and handles overlap.
pub fn raw(
    bytes: []const u8,
    expected: []const u8,
    dictionary: []const u8,
    window_len: usize,
    target_distance: usize,
) Error!Stats {
    const retained = dictionary[dictionary.len - @min(dictionary.len, window_len) ..];
    var bits: Bits = .{ .bytes = bytes };
    var stats: Stats = .{};
    var written: usize = 0;
    while (true) {
        const final = try bits.take(1);
        const kind = try bits.take(2);
        if (kind == 3) return error.InvalidOracleDeflate;
        stats.blocks[kind] += 1;
        const block_start = written;
        if (kind == 0) {
            bits.byteAlign();
            const len = try bits.take(16);
            const complement = try bits.take(16);
            if (len != (complement ^ 65535) or len > expected.len - written)
                return error.InvalidOracleDeflate;
            for (0..len) |_| {
                if (try bits.take(8) != expected[written]) return error.OracleOutputMismatch;
                stats.literals += 1;
                written += 1;
            }
        } else {
            const trees = if (kind == 1) try Trees.fixed() else try Trees.dynamic(&bits);
            while (true) {
                const symbol = try trees.literal.symbol(&bits);
                if (symbol < 256) {
                    if (written == expected.len or expected[written] != symbol)
                        return error.OracleOutputMismatch;
                    written += 1;
                    stats.literals += 1;
                    continue;
                }
                if (symbol == 256) break;
                if (symbol > 285) return error.InvalidOracleDeflate;
                // RFC 1951 symbol 285 has length 258 and zero extra bits. It is
                // intentionally independent from Deflate64's different rule.
                const len = length_base[symbol - 257] + try bits.take(length_extra[symbol - 257]);
                const distance_symbol = try trees.distance.symbol(&bits);
                if (distance_symbol >= 30) return error.InvalidOracleDeflate;
                const distance = distance_base[distance_symbol] + try bits.take(distance_extra[distance_symbol]);
                if (distance > window_len) return error.OracleWindowViolation;
                if (distance > retained.len + written or len > expected.len - written)
                    return error.InvalidOracleDeflate;
                stats.matches += 1;
                stats.matched_bytes += len;
                stats.max_distance = @max(stats.max_distance, distance);
                stats.max_length = @max(stats.max_length, len);
                if (distance > written) stats.dictionary_matches += 1;
                if (block_start != 0 and distance > written - block_start) stats.cross_block_matches += 1;
                if (distance == target_distance) stats.target_matches += 1;
                for (0..len) |i| {
                    const absolute = retained.len + written + i - distance;
                    const source = if (absolute < retained.len) retained[absolute] else expected[absolute - retained.len];
                    if (expected[written + i] != source) return error.OracleOutputMismatch;
                }
                written += len;
            }
        }
        if (final != 0) break;
    }
    if (written != expected.len or (bits.position + 7) / 8 != bytes.len)
        return error.InvalidOracleDeflate;
    return stats;
}

pub fn frame(
    bytes: []const u8,
    expected: []const u8,
    dictionary: ?[]const u8,
    window_bits: u8,
    target_distance: usize,
) Error!Stats {
    const prefix: usize = if (dictionary == null) 2 else 6;
    if (window_bits < 9 or window_bits > 15 or bytes.len < prefix + 6)
        return error.InvalidOracleDeflate;
    if (bytes[0] & 15 != 8 or bytes[0] >> 4 != window_bits - 8 or
        std.mem.readInt(u16, bytes[0..2], .big) % 31 != 0 or
        ((bytes[1] & 0x20) != 0) != (dictionary != null))
        return error.InvalidOracleDeflate;
    if (dictionary) |dict| {
        if (std.mem.readInt(u32, bytes[2..6], .big) != adler32(dict))
            return error.OracleDictionaryIdMismatch;
    }
    if (std.mem.readInt(u32, bytes[bytes.len - 4 ..][0..4], .big) != adler32(expected))
        return error.OracleChecksumMismatch;
    return raw(
        bytes[prefix .. bytes.len - 4],
        expected,
        dictionary orelse "",
        @as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(window_bits)),
        target_distance,
    );
}

/// Frozen CPython/libz fixtures verify the independent oracle itself, including
/// a dynamic tree and the RFC 1951 length-285 boundary.
pub fn controls() !void {
    const fixed = [_]u8{ 0x78, 0x9c, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0xc8, 0x40, 0x90, 0x00, 0x3a, 0x2e, 0x06, 0x7d };
    const fixed_stats = try frame(&fixed, "hello hello hello", null, 15, 6);
    try std.testing.expectEqual(@as(usize, 1), fixed_stats.blocks[1]);
    try std.testing.expect(fixed_stats.target_matches != 0);
    const length285 = [_]u8{ 0x78, 0x9c, 0x4b, 0x4c, 0x1c, 0x05, 0x00, 0x3c, 0x3c, 0x62, 0x85 };
    const long_stats = try frame(&length285, "a" ** 260, null, 15, 1);
    try std.testing.expectEqual(@as(usize, 258), long_stats.max_length);
    const dynamic = [_]u8{
        0x78, 0x9c, 0xed, 0xcb, 0xd1, 0x09, 0xc0, 0x30, 0x08, 0x05, 0xc0, 0x55, 0xde, 0x00, 0xa5, 0x93,
        0x64, 0x89, 0x60, 0x24, 0x08, 0x31, 0x06, 0x35, 0xfb, 0x77, 0x8f, 0xe2, 0xfd, 0x5f, 0x33, 0x67,
        0x85, 0x9c, 0xb8, 0x8a, 0x61, 0xcb, 0x1c, 0x21, 0x89, 0xae, 0x9c, 0x0f, 0xc8, 0x76, 0x30, 0x25,
        0xe7, 0x75, 0xf4, 0x21, 0x47, 0x82, 0x64, 0x4f, 0xf0, 0x92, 0x7c, 0xd1, 0x2a, 0x56, 0xac, 0x58,
        0xb1, 0x62, 0xc5, 0xff, 0xc6, 0x0f, 0x7a, 0x1a, 0xa2, 0xdf,
    };
    const dynamic_stats = try frame(&dynamic, "Lorem ipsum dolor sit amet, consectetur adipiscing elit. " ** 32, null, 15, 57);
    try std.testing.expectEqual(@as(usize, 1), dynamic_stats.blocks[2]);
    try std.testing.expect(dynamic_stats.target_matches != 0);
    try std.testing.expectError(error.OracleWindowViolation, raw(fixed[2 .. fixed.len - 4], "hello hello hello", "", 5, 0));
    try std.testing.expectError(error.OracleOutputMismatch, raw(fixed[2 .. fixed.len - 4], "hello hello hellx", "", 32768, 0));
}

test "zlib independent RFC token oracle controls" {
    try controls();
}

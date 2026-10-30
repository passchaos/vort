//! Compact literal-pair implementation for selected PNG ultrafast workloads.
//!
//! The canonical wide encoder remains in `png_ultrafast.zig` unchanged. This
//! module shares only its frozen syntax and keeps the alternate table and code
//! in a separate specialization so unselected callers retain their established
//! machine code.

const std = @import("std");
const checksum = @import("checksum.zig");
const wide = @import("png_ultrafast.zig");

const syntax = wide.incremental_syntax;
const literal_lengths = syntax.lengths;
const literal_codes = syntax.codes;
const zlib_dynamic_header = syntax.header;

const compact_literal_pairs: [1 << 16]u32 align(64) =
    makeCompactLiteralPairs();

pub const minimum_input_bytes: usize = 5 * 256 * 1024;
const pair_probe_words: usize = 64;
const pair_probe_zero_words: usize = pair_probe_words / 2;
const pair_probe_bloom_bits: usize = 140;

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) ![]u8 {
    var writer = try ReservoirWriter.init(allocator, input.len);
    errdefer writer.deinit(allocator);
    try writeInput(allocator, &writer, input);
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

fn makeCompactLiteralPairs() [1 << 16]u32 {
    @setEvalBranchQuota(1_000_000);
    var pairs: [1 << 16]u32 = undefined;
    for (&pairs, 0..) |*entry, index| {
        const b0: u8 = @truncate(index);
        const b1: u8 = @truncate(index >> 8);
        const n0: u6 = literal_lengths[b0];
        const n1: u6 = literal_lengths[b1];
        const bits = @as(u32, literal_codes[b0]) |
            (@as(u32, literal_codes[b1]) << n0);
        entry.* = bits | (@as(u32, n0 + n1) << 24);
    }
    return pairs;
}

pub fn prefersCompactPairs(input: []const u8) bool {
    if (input.len < minimum_input_bytes) return false;
    const word_count = input.len / @sizeOf(u64);
    std.debug.assert(word_count >= pair_probe_words);

    const step = word_count / pair_probe_words;
    const remainder = word_count % pair_probe_words;
    var zero_words: usize = 0;
    var pair_bloom: [4]u64 = @splat(0);
    for (0..pair_probe_words) |sample_index| {
        const word_index = sample_index * step +
            sample_index * remainder / pair_probe_words;
        const byte_index = word_index * @sizeOf(u64);
        const word = std.mem.readInt(
            u64,
            input[byte_index..][0..@sizeOf(u64)],
            .little,
        );
        zero_words += @intFromBool(word == 0);
        inline for (0..4) |pair_index| {
            const pair_value: u16 = @truncate(word >> (pair_index * 16));
            const bit: u8 = @truncate(
                (@as(u32, pair_value) *% 0x9e37) >> 8,
            );
            pair_bloom[bit / 64] |= @as(u64, 1) << @truncate(bit % 64);
        }
    }

    var distinct_pair_bits: usize = 0;
    for (pair_bloom) |bits| distinct_pair_bits += @popCount(bits);
    return zero_words >= pair_probe_zero_words or
        distinct_pair_bits >= pair_probe_bloom_bits;
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
        if (self.bytes.capacity - self.bytes.items.len >= encoded.len) {
            self.bytes.appendSliceAssumeCapacity(&encoded);
        } else {
            try self.bytes.appendSlice(allocator, &encoded);
        }
        self.bit_count = total - 64;
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

fn writeInput(
    allocator: std.mem.Allocator,
    writer: *ReservoirWriter,
    input: []const u8,
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
                try writeLiteralPrefix(
                    allocator,
                    writer,
                    word >> @intCast(prefix_zeros * 8),
                    @intCast(8 - prefix_zeros - suffix_zeros),
                );
                run = suffix_zeros;
                continue;
            }
        }

        const suffix_zeros = @clz(word) / 8;
        if (suffix_zeros != 0) {
            try writeLiteralPrefix(
                allocator,
                writer,
                word,
                @intCast(8 - suffix_zeros),
            );
            run = suffix_zeros;
            continue;
        }
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
    }

    if (run != 0) try writeZeroRun(allocator, writer, run);
    for (input[whole_len..]) |byte| try writeSymbol(allocator, writer, byte);
}

inline fn writeLiteralPrefix(
    allocator: std.mem.Allocator,
    writer: *ReservoirWriter,
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

inline fn lookupPair(pair_index: u16) struct { bits: u64, count: u6 } {
    const encoded = compact_literal_pairs[pair_index];
    return .{
        .bits = encoded & 0x00ff_ffff,
        .count = @truncate(encoded >> 24),
    };
}

inline fn writeLiteralPair(
    allocator: std.mem.Allocator,
    writer: *ReservoirWriter,
    pair_index: u16,
) !void {
    const encoded = lookupPair(pair_index);
    try writer.writeBits(allocator, encoded.bits, encoded.count);
}

inline fn writeLiteralQuad(
    allocator: std.mem.Allocator,
    writer: *ReservoirWriter,
    pair0_index: u16,
    pair1_index: u16,
) !void {
    const pair0 = lookupPair(pair0_index);
    const pair1 = lookupPair(pair1_index);
    try writer.writeBits(
        allocator,
        pair0.bits | (pair1.bits << pair0.count),
        pair0.count + pair1.count,
    );
}

inline fn writeLiteralTriple(
    allocator: std.mem.Allocator,
    writer: *ReservoirWriter,
    pair_index: u16,
    last: u8,
) !void {
    const encoded = lookupPair(pair_index);
    const last_count: u6 = literal_lengths[last];
    try writer.writeBits(
        allocator,
        encoded.bits | (@as(u64, literal_codes[last]) << encoded.count),
        encoded.count + last_count,
    );
}

fn writeZeroRun(
    allocator: std.mem.Allocator,
    writer: *ReservoirWriter,
    run_len: usize,
) !void {
    std.debug.assert(run_len > 0);
    try writeSymbol(allocator, writer, 0);
    var remaining = run_len - 1;
    while (remaining >= 258) : (remaining -= 258) {
        try writer.writeBits(
            allocator,
            literal_codes[285],
            literal_lengths[285] + 1,
        );
    }
    if (remaining > 4) {
        const length = syntax.length(remaining);
        const symbol_bits: u6 = literal_lengths[length.symbol];
        const bits = @as(u64, literal_codes[length.symbol]) |
            (@as(u64, length.extra) << symbol_bits);
        try writer.writeBits(
            allocator,
            bits,
            symbol_bits + length.extra_bits + 1,
        );
    } else {
        var index: usize = 0;
        while (index < remaining) : (index += 1)
            try writeSymbol(allocator, writer, 0);
    }
}

fn writeSymbol(
    allocator: std.mem.Allocator,
    writer: *ReservoirWriter,
    symbol: usize,
) !void {
    try writer.writeBits(
        allocator,
        literal_codes[symbol],
        literal_lengths[symbol],
    );
}

test "compact PNG ultrafast literal pairs match canonical syntax" {
    for (0..1 << 16) |index| {
        const b0: u8 = @truncate(index);
        const b1: u8 = @truncate(index >> 8);
        const n0: u6 = literal_lengths[b0];
        const n1: u6 = literal_lengths[b1];
        const expected_bits = @as(u64, literal_codes[b0]) |
            (@as(u64, literal_codes[b1]) << n0);
        const actual = lookupPair(@intCast(index));
        try std.testing.expectEqual(expected_bits, actual.bits);
        try std.testing.expectEqual(n0 + n1, actual.count);
    }
}

test "compact PNG ultrafast output matches canonical wide encoder" {
    var mixed: [8 * 257 + 5]u8 = undefined;
    for (&mixed, 0..) |*byte, index| {
        byte.* = if (index % 19 < 7) 0 else @truncate(index * 73 + 19);
    }
    inline for (.{
        "",
        "hello, world",
        &([_]u8{0} ** 600),
        &mixed,
    }) |input| {
        const compact = try encodeAlloc(std.testing.allocator, input);
        defer std.testing.allocator.free(compact);
        const canonical = try wide.encodeAlloc(std.testing.allocator, input);
        defer std.testing.allocator.free(canonical);
        try std.testing.expectEqualSlices(u8, canonical, compact);
    }
}

test "fixed-Up PNG ultrafast pair probe is bounded and byte exact" {
    const too_small = try std.testing.allocator.alloc(
        u8,
        minimum_input_bytes - 1,
    );
    defer std.testing.allocator.free(too_small);
    @memset(too_small, 0);
    try std.testing.expect(!prefersCompactPairs(too_small));

    const zero_dominant = try std.testing.allocator.alloc(
        u8,
        minimum_input_bytes,
    );
    defer std.testing.allocator.free(zero_dominant);
    @memset(zero_dominant, 0);
    try std.testing.expect(prefersCompactPairs(zero_dominant));

    const repeated = try std.testing.allocator.alloc(
        u8,
        minimum_input_bytes,
    );
    defer std.testing.allocator.free(repeated);
    @memset(repeated, 7);
    try std.testing.expect(!prefersCompactPairs(repeated));

    const diverse = try std.testing.allocator.alloc(
        u8,
        minimum_input_bytes,
    );
    defer std.testing.allocator.free(diverse);
    @memset(diverse, 7);
    const word_count = diverse.len / @sizeOf(u64);
    const step = word_count / pair_probe_words;
    const remainder = word_count % pair_probe_words;
    for (0..pair_probe_words) |sample_index| {
        const word_index = sample_index * step +
            sample_index * remainder / pair_probe_words;
        const word = diverse[word_index * 8 ..][0..8];
        inline for (0..4) |pair_index| {
            std.mem.writeInt(
                u16,
                word[pair_index * 2 ..][0..2],
                @intCast(sample_index * 4 + pair_index),
                .little,
            );
        }
    }
    try std.testing.expect(prefersCompactPairs(diverse));

    const selected = try encodeAlloc(std.testing.allocator, zero_dominant);
    defer std.testing.allocator.free(selected);
    const canonical = try wide.encodeAlloc(
        std.testing.allocator,
        zero_dominant,
    );
    defer std.testing.allocator.free(canonical);
    try std.testing.expectEqualSlices(u8, canonical, selected);
}

test "compact PNG ultrafast encoder releases every failed allocation" {
    var input: [4096]u8 = undefined;
    for (&input, 0..) |*byte, index| {
        byte.* = @truncate(index *% 73 + index / 11 + 19);
    }
    const Test = struct {
        fn run(allocator: std.mem.Allocator, bytes: []const u8) !void {
            const encoded = try encodeAlloc(allocator, bytes);
            defer allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{&input},
    );
}

const std = @import("std");
const core = @import("../../core.zig");
const tables = @import("tables.zig");

pub const Error = core.Error;

const uncompressed_block_type: u3 = 3;
const verbatim_block_type: u3 = 1;
const max_block_len: usize = 32 * 1024;
const literal_count: usize = 256;
const length_headers_per_slot: usize = 8;
const directly_encoded_lengths: usize = 7;
const length_symbol_count: usize = 249;
const max_main_symbols: usize = literal_count + 50 * length_headers_per_slot;
const max_code_bits: usize = 16;
const hash_bits: usize = 15;
const hash_size: usize = @as(usize, 1) << hash_bits;
const max_direct_match_len: usize = 8;
const wim_e8_file_size: i32 = 12_000_000;

/// Encodes one independent WIM LZX chunk using a deterministic verbatim block.
/// The reference matcher emits literals and 3..8-byte explicit-offset matches;
/// callers should retain a raw chunk when the returned representation is not
/// smaller. Every supported WIM LZX window size is accepted.
pub fn encodeWimChunkAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    window_bits: u5,
) ![]u8 {
    if (window_bits < tables.min_window_bits or window_bits > tables.max_window_bits)
        return error.InvalidBlockPlan;
    const window_size = @as(usize, 1) << @intCast(window_bits);
    if (input.len == 0 or input.len > window_size) return error.InvalidBlockPlan;

    const transformed = try allocator.dupe(u8, input);
    defer allocator.free(transformed);
    preprocessWimE8(transformed);

    const slot_count = tables.positionSlotCount(window_bits);
    var main_lengths: [max_main_symbols]u5 = @splat(0);
    buildMainLengths(main_lengths[0 .. literal_count + slot_count * length_headers_per_slot], slot_count);
    var main_codes: [max_main_symbols]u16 = @splat(0);
    try buildCanonicalCodes(
        main_lengths[0 .. literal_count + slot_count * length_headers_per_slot],
        &main_codes,
    );

    var writer = WordBitWriter{};
    errdefer writer.bytes.deinit(allocator);
    try writer.writeBits(allocator, verbatim_block_type, 3);
    if (input.len == max_block_len) {
        try writer.writeBits(allocator, 1, 1);
    } else {
        try writer.writeBits(allocator, 0, 1);
        if (window_bits >= 16)
            try writer.writeBits(allocator, input.len >> 16, 8);
        try writer.writeBits(allocator, input.len & 0xffff, 16);
    }
    try writeLengthRange(allocator, &writer, main_lengths[0..literal_count]);
    try writeLengthRange(
        allocator,
        &writer,
        main_lengths[literal_count .. literal_count + slot_count * length_headers_per_slot],
    );
    const empty_length_tree: [length_symbol_count]u5 = @splat(0);
    try writeLengthRange(allocator, &writer, &empty_length_tree);

    const heads = try allocator.alloc(u32, hash_size);
    defer allocator.free(heads);
    @memset(heads, std.math.maxInt(u32));
    var input_offset: usize = 0;
    while (input_offset < transformed.len) {
        const match = findMatch(transformed, input_offset, heads, slot_count, &main_lengths);
        if (match) |selected| {
            const main_symbol = literal_count +
                selected.slot * length_headers_per_slot +
                (selected.len - 2);
            try writer.writeBits(
                allocator,
                main_codes[main_symbol],
                main_lengths[main_symbol],
            );
            const extra_bits = tables.positionExtraBits(selected.slot);
            if (extra_bits != 0) {
                try writer.writeBits(
                    allocator,
                    selected.offset - tables.positionBase(selected.slot),
                    @intCast(extra_bits),
                );
            }
            indexInput(transformed, input_offset, selected.len, heads);
            input_offset += selected.len;
        } else {
            const literal = transformed[input_offset];
            try writer.writeBits(
                allocator,
                main_codes[literal],
                main_lengths[literal],
            );
            indexInput(transformed, input_offset, 1, heads);
            input_offset += 1;
        }
    }
    try writer.finish(allocator);
    return writer.bytes.toOwnedSlice(allocator);
}

const Match = struct {
    len: usize,
    offset: usize,
    slot: usize,
};

fn findMatch(
    input: []const u8,
    input_offset: usize,
    heads: []const u32,
    slot_count: usize,
    main_lengths: *const [max_main_symbols]u5,
) ?Match {
    if (input.len - input_offset < 3) return null;
    const previous_raw = heads[hash3(input[input_offset..][0..3])];
    if (previous_raw == std.math.maxInt(u32)) return null;
    const previous: usize = previous_raw;
    if (previous >= input_offset) return null;
    const offset = input_offset - previous;
    const slot = positionSlot(offset, slot_count) orelse return null;
    var match_len: usize = 0;
    const match_limit = @min(max_direct_match_len, input.len - input_offset);
    while (match_len < match_limit and
        input[previous + match_len] == input[input_offset + match_len])
    {
        match_len += 1;
    }
    if (match_len < 3) return null;

    const main_symbol = literal_count + slot * length_headers_per_slot + (match_len - 2);
    var literal_cost: usize = 0;
    for (input[input_offset..][0..match_len]) |literal|
        literal_cost += main_lengths[literal];
    const match_cost = @as(usize, main_lengths[main_symbol]) +
        tables.positionExtraBits(slot);
    if (match_cost >= literal_cost) return null;
    return .{ .len = match_len, .offset = offset, .slot = slot };
}

fn indexInput(input: []const u8, start: usize, len: usize, heads: []u32) void {
    for (start..start + len) |offset| {
        if (input.len - offset < 3) break;
        heads[hash3(input[offset..][0..3])] = @intCast(offset);
    }
}

fn hash3(bytes: *const [3]u8) usize {
    const value = @as(u32, bytes[0]) |
        (@as(u32, bytes[1]) << 8) |
        (@as(u32, bytes[2]) << 16);
    return @intCast((value *% 0x1e35_a7bd) >> @intCast(32 - hash_bits));
}

fn positionSlot(offset: usize, slot_count: usize) ?usize {
    for (3..slot_count) |slot| {
        const base = tables.positionBase(slot);
        const limit = base + (@as(usize, 1) << @intCast(tables.positionExtraBits(slot)));
        if (offset >= base and offset < limit) return slot;
    }
    return null;
}

fn buildMainLengths(lengths: []u5, slot_count: usize) void {
    const active_count = literal_count + (slot_count - 3) * directly_encoded_lengths;
    var long_bits: u5 = 1;
    var capacity: usize = 2;
    while (capacity < active_count) {
        capacity *= 2;
        long_bits += 1;
    }
    const short_count = capacity - active_count;
    const short_bits = long_bits - 1;
    var active_index: usize = 0;
    for (0..literal_count) |symbol| {
        lengths[symbol] = if (active_index < short_count) short_bits else long_bits;
        active_index += 1;
    }
    for (3..slot_count) |slot| {
        for (0..directly_encoded_lengths) |length_header| {
            const symbol = literal_count + slot * length_headers_per_slot + length_header;
            lengths[symbol] = if (active_index < short_count) short_bits else long_bits;
            active_index += 1;
        }
    }
    std.debug.assert(active_index == active_count);
}

fn buildCanonicalCodes(lengths: []const u5, codes: *[max_main_symbols]u16) !void {
    var counts: [max_code_bits + 1]u16 = @splat(0);
    for (lengths) |length| {
        if (length > max_code_bits) return error.InvalidBlockPlan;
        if (length != 0) counts[length] += 1;
    }
    var available: i32 = 1;
    var code: u32 = 0;
    var next: [max_code_bits + 1]u32 = @splat(0);
    for (1..max_code_bits + 1) |bits| {
        available = available * 2 - counts[bits];
        if (available < 0) return error.InvalidBlockPlan;
        code = (code + counts[bits - 1]) << 1;
        next[bits] = code;
    }
    if (available != 0) return error.InvalidBlockPlan;
    for (lengths, 0..) |length, symbol| {
        if (length == 0) continue;
        codes[symbol] = @intCast(next[length]);
        next[length] += 1;
    }
}

const pretree_lengths = blk: {
    var lengths: [20]u5 = @splat(0);
    lengths[0] = 2;
    lengths[7] = 3;
    lengths[8] = 2;
    lengths[9] = 3;
    lengths[18] = 2;
    break :blk lengths;
};

fn writeLengthRange(
    allocator: std.mem.Allocator,
    writer: *WordBitWriter,
    lengths: []const u5,
) !void {
    for (pretree_lengths) |length|
        try writer.writeBits(allocator, length, 4);
    var index: usize = 0;
    while (index < lengths.len) {
        if (lengths[index] != 0) {
            const delta: u5 = @intCast((17 - @as(usize, lengths[index])) % 17);
            try writePretreeSymbol(allocator, writer, delta);
            index += 1;
            continue;
        }
        var run_end = index + 1;
        while (run_end < lengths.len and lengths[run_end] == 0)
            run_end += 1;
        var remaining = run_end - index;
        while (remaining >= 20) {
            var count: usize = @min(remaining, 51);
            if (remaining > 51 and remaining - count < 20)
                count = remaining - 20;
            try writePretreeSymbol(allocator, writer, 18);
            try writer.writeBits(allocator, count - 20, 5);
            remaining -= count;
        }
        while (remaining != 0) : (remaining -= 1)
            try writePretreeSymbol(allocator, writer, 0);
        index = run_end;
    }
}

fn writePretreeSymbol(
    allocator: std.mem.Allocator,
    writer: *WordBitWriter,
    symbol: u5,
) !void {
    const code_and_bits: struct { code: u3, bits: u5 } = switch (symbol) {
        0 => .{ .code = 0, .bits = 2 },
        7 => .{ .code = 6, .bits = 3 },
        8 => .{ .code = 1, .bits = 2 },
        9 => .{ .code = 7, .bits = 3 },
        18 => .{ .code = 2, .bits = 2 },
        else => return error.InvalidBlockPlan,
    };
    try writer.writeBits(allocator, code_and_bits.code, code_and_bits.bits);
}

fn preprocessWimE8(bytes: []u8) void {
    if (bytes.len <= 10) return;
    const scan_end = bytes.len - 10;
    var index: usize = 0;
    while (index < scan_end) {
        if (bytes[index] != 0xe8) {
            index += 1;
            continue;
        }
        const target_offset = index + 1;
        const relative = std.mem.readInt(i32, bytes[target_offset..][0..4], .little);
        const position: i32 = @intCast(index);
        if (relative >= -position and relative < wim_e8_file_size) {
            const absolute = if (relative < wim_e8_file_size - position)
                relative + position
            else
                relative - wim_e8_file_size;
            std.mem.writeInt(i32, bytes[target_offset..][0..4], absolute, .little);
        }
        index += 5;
    }
}

/// Encodes one non-empty LZX uncompressed block. Blocks can be concatenated to
/// form one solid LZX stream. The first block carries the one-time Intel E8
/// header. Odd-sized blocks include their required alignment byte after the
/// payload, including the final block for broad decoder interoperability.
pub fn encodeUncompressedBlockAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    first_block: bool,
) ![]u8 {
    if (input.len == 0 or input.len > max_block_len) return error.InvalidBlockPlan;

    var writer = WordBitWriter{};
    errdefer writer.bytes.deinit(allocator);
    if (first_block) try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, uncompressed_block_type, 3);
    try writer.writeBits(allocator, input.len >> 8, 16);
    try writer.writeBits(allocator, input.len & 0xff, 8);
    try writer.alignForUncompressed(allocator);

    // Uncompressed block headers restore the three recent offsets.
    try appendU32(allocator, &writer.bytes, 1);
    try appendU32(allocator, &writer.bytes, 1);
    try appendU32(allocator, &writer.bytes, 1);
    try writer.bytes.appendSlice(allocator, input);
    if (input.len & 1 != 0) try writer.bytes.append(allocator, 0);
    return writer.bytes.toOwnedSlice(allocator);
}

const WordBitWriter = struct {
    bytes: std.ArrayList(u8) = .empty,
    word: u16 = 0,
    bit_count: u5 = 0,

    fn writeBits(
        self: *WordBitWriter,
        allocator: std.mem.Allocator,
        value: anytype,
        count: u5,
    ) !void {
        std.debug.assert(count > 0 and count <= 17);
        var remaining: usize = count;
        while (remaining != 0) {
            remaining -= 1;
            self.word = (self.word << 1) |
                @as(u1, @truncate(@as(u64, @intCast(value)) >> @intCast(remaining)));
            self.bit_count += 1;
            if (self.bit_count == 16) try self.flushWord(allocator);
        }
    }

    /// LZX uncompressed blocks discard 1..16 bits, so an already aligned
    /// header would require a complete padding word rather than zero bits.
    fn alignForUncompressed(self: *WordBitWriter, allocator: std.mem.Allocator) !void {
        if (self.bit_count == 0) {
            try appendU16(allocator, &self.bytes, 0);
        } else {
            self.word <<= @intCast(16 - @as(usize, self.bit_count));
            try self.flushWord(allocator);
        }
    }

    fn flushWord(self: *WordBitWriter, allocator: std.mem.Allocator) !void {
        try appendU16(allocator, &self.bytes, self.word);
        self.word = 0;
        self.bit_count = 0;
    }

    fn finish(self: *WordBitWriter, allocator: std.mem.Allocator) !void {
        if (self.bit_count == 0) return;
        self.word <<= @intCast(16 - @as(usize, self.bit_count));
        try self.flushWord(allocator);
    }
};

fn appendU16(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn appendU32(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

test "LZX uncompressed encoder concatenates odd blocks" {
    const lzx = @import("../lzx.zig");
    const allocator = std.testing.allocator;
    const first = try encodeUncompressedBlockAlloc(allocator, "abc", true);
    defer allocator.free(first);
    const second = try encodeUncompressedBlockAlloc(allocator, "defgh", false);
    defer allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(allocator);
    try stream.appendSlice(allocator, first);
    try stream.appendSlice(allocator, second);
    const decoded = try lzx.decodeAlloc(allocator, stream.items, 8, 15);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("abcdefgh", decoded);
}

test "LZX uncompressed encoder validates block contracts" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidBlockPlan,
        encodeUncompressedBlockAlloc(allocator, "", true),
    );
}

test "LZX WIM verbatim encoder round trips matches and E8 preprocessing" {
    const lzx = @import("../lzx.zig");
    const allocator = std.testing.allocator;
    var input: [32 * 1024]u8 = undefined;
    const phrase = "deterministic WIM LZX reference match payload\n";
    for (&input, 0..) |*byte, index|
        byte.* = phrase[index % phrase.len];
    for (128..input.len - 16) |index| {
        if (index % 4096 != 0) continue;
        input[index] = 0xe8;
        std.mem.writeInt(i32, input[index + 1 ..][0..4], @intCast(1024 - @as(i32, @intCast(index))), .little);
    }

    for (tables.min_window_bits..tables.max_window_bits + 1) |raw_window_bits| {
        const window_bits: u5 = @intCast(raw_window_bits);
        const encoded = try encodeWimChunkAlloc(allocator, &input, window_bits);
        defer allocator.free(encoded);
        try std.testing.expect(encoded.len < input.len);
        const decoded = try lzx.decodeAllocWithFormat(
            allocator,
            encoded,
            input.len,
            window_bits,
            .wim,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &input, decoded);
    }
}

test "LZX WIM verbatim encoder validates chunk geometry" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidBlockPlan,
        encodeWimChunkAlloc(allocator, "", 15),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        encodeWimChunkAlloc(allocator, "payload", 14),
    );
    const oversized = try allocator.alloc(u8, 32 * 1024 + 1);
    defer allocator.free(oversized);
    try std.testing.expectError(
        error.InvalidBlockPlan,
        encodeWimChunkAlloc(allocator, oversized, 15),
    );
}

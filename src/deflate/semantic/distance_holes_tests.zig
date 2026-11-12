//! Public raw-wire regressions for holes in long distance-code subtrees.
//! Api supplies only decodeRawDeflate. The wire encoder is independent of the
//! production bit writer/encoder; table inspection never reads semantic slots.
const std = @import("std");
const huffman = @import("../../huffman.zig");
const bits = @import("../../bitstream.zig");
const semantic = @import("decoder.zig");
const rle258 = @import("rle258.zig");

const guard_len = 64;
const sentinel: u8 = 0xa5;
const history_len = 128;
const output_len = 160;
const Token = enum { existing9, existing10, missing10 };

const Wire = struct {
    bytes: [512]u8 = @splat(0),
    bit_len: usize = 0,

    fn put(self: *Wire, value: u16, width: u5) void {
        std.debug.assert(self.bit_len + width <= self.bytes.len * 8);
        for (0..width) |i| {
            const bit: u8 = @intCast((value >> @intCast(i)) & 1);
            self.bytes[self.bit_len / 8] |= bit << @intCast(self.bit_len % 8);
            self.bit_len += 1;
        }
    }

    fn bare(self: *const Wire) []const u8 {
        return self.bytes[0 .. (self.bit_len + 7) / 8];
    }

    fn padded(self: *const Wire) []const u8 {
        return self.bytes[0 .. self.bare().len + 16];
    }
};

fn reverse(value: u16, width: u5) u16 {
    var result: u16 = 0;
    for (0..width) |i| result = (result << 1) | ((value >> @intCast(i)) & 1);
    return result;
}

fn canonicalCode(lengths: []const u4, symbol: usize) u16 {
    std.debug.assert(symbol < lengths.len and lengths[symbol] != 0);
    var counts: [16]u16 = @splat(0);
    for (lengths) |width| if (width != 0) {
        counts[width] += 1;
    };
    var next: [16]u16 = @splat(0);
    var code: u16 = 0;
    for (1..16) |width| {
        code = (code + counts[width - 1]) << 1;
        next[width] = code;
    }
    const width = lengths[symbol];
    for (lengths[0..symbol]) |previous| if (previous == width) {
        next[width] += 1;
    };
    return reverse(next[width], width);
}

fn literalLengths() [258]u4 {
    var lengths: [258]u4 = @splat(0);
    lengths['a'] = 1;
    for (0..8) |i| lengths[i] = @intCast(i + 2);
    lengths[256] = 10;
    lengths[257] = 10;
    return lengths;
}

fn completeDistances() [11]u4 {
    var lengths: [11]u4 = undefined;
    for (0..9) |i| lengths[i] = @intCast(i + 1);
    lengths[9] = 10;
    lengths[10] = 10;
    return lengths;
}

const incomplete_distances = [_]u4{ 9, 10 };

fn header(wire: *Wire, final: bool, distances: []const u4) void {
    wire.put(@intFromBool(final), 1);
    wire.put(2, 2);
    wire.put(1, 5); // HLIT258.
    wire.put(@intCast(distances.len - 1), 5);
    wire.put(15, 4); // HCLEN19, including all sixteen direct length symbols.
    const order = [_]u8{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
    for (order) |symbol| wire.put(if (symbol < 16) 4 else 0, 3);
    // CL symbols 0..15 have canonical code equal to their value, width four.
    for (literalLengths()) |width| wire.put(reverse(width, 4), 4);
    for (distances) |width| wire.put(reverse(width, 4), 4);
}

fn putLiteral(wire: *Wire, symbol: usize) void {
    const lengths = literalLengths();
    wire.put(canonicalCode(&lengths, symbol), lengths[symbol]);
}

fn makeWire(seed_block: bool, literal_count: usize, token: Token) Wire {
    var wire: Wire = .{};
    if (seed_block) {
        const distances = completeDistances();
        header(&wire, false, &distances);
        for (0..history_len) |_| putLiteral(&wire, 'a');
        putLiteral(&wire, 256);
    }
    header(&wire, true, &incomplete_distances);
    for (0..literal_count) |_| putLiteral(&wire, 'a');
    putLiteral(&wire, 257); // Length three, with no length extra bits.
    switch (token) {
        .existing9 => wire.put(canonicalCode(&incomplete_distances, 0), 9),
        .existing10 => wire.put(canonicalCode(&incomplete_distances, 1), 10),
        .missing10 => {
            wire.put(768, 10); // Prefix zero, secondary slot three: no code.
            // A stale symbol ten would consume these as distance extra bits,
            // producing distance 33 and incorrectly copying three history bytes.
            wire.put(0, 4);
        },
    }
    putLiteral(&wire, 256);
    return wire;
}

fn expectCode(table: anytype, symbol: u16, width: u4, code: u16) !void {
    for (table.entries[0..table.len]) |entry| {
        if (entry.symbol != symbol) continue;
        try std.testing.expectEqual(width, entry.bits);
        try std.testing.expectEqual(code, entry.code);
        return;
    }
    return error.TestExpectedEqual;
}

fn expectSecondaryShape(table: anytype, prefix: u16, expected: [4]?u16) !void {
    // Derive each ten-bit lookup's coverage from defined canonical entries.
    // The encoded symbol/width is what buildDistanceTable writes to a slot;
    // no semantic decoder is initialized or inspected here.
    var actual: [4]?u16 = @splat(null);
    for (table.entries[0..table.len]) |entry| {
        if (entry.bits <= 8 or (entry.code & 255) != prefix) continue;
        try std.testing.expect(entry.bits <= 10);
        for (0..4) |slot| {
            const lookup = prefix | (@as(u16, @intCast(slot)) << 8);
            const mask = (@as(u16, 1) << entry.bits) - 1;
            if ((lookup & mask) == entry.code) {
                try std.testing.expect(actual[slot] == null);
                actual[slot] = (entry.symbol << 4) | entry.bits;
            }
        }
    }
    for (actual, expected) |found, wanted| try std.testing.expectEqual(wanted, found);
}

fn expectHeader(reader: *bits.BufferedBitReader, final: bool, complete: bool) !void {
    const start = reader.bitPosition();
    const parsed = try huffman.parseDynamicLengths(reader);
    try std.testing.expectEqual(final, parsed.header.final);
    try std.testing.expectEqual(@as(u16, 258), parsed.header.hlit);
    try std.testing.expectEqual(@as(u16, if (complete) 11 else 2), parsed.header.hdist);
    try std.testing.expectEqual(@as(u8, 19), parsed.header.hclen);
    try std.testing.expectEqual(@as(u4, 10), parsed.literal_max_bits);
    try std.testing.expectEqual(@as(u4, 10), parsed.distance_max_bits);
    for (parsed.header.code_length_lengths, 0..) |width, symbol| {
        try std.testing.expectEqual(@as(u4, if (symbol < 16) 4 else 0), width);
    }
    for (parsed.code_length_symbol_histogram[16..]) |count| try std.testing.expectEqual(@as(u16, 0), count);
    try std.testing.expectEqualSlices(u4, &literalLengths(), parsed.literal_lengths[0..258]);
    const literal = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..258]);
    const distance = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
    try std.testing.expectEqual(@as(usize, 11), literal.len);
    try std.testing.expect(semantic.SemanticDynamicDecoder.treeIsComplete(286, &literal));
    try std.testing.expectEqual(complete, semantic.SemanticDynamicDecoder.treeIsComplete(30, &distance));
    try expectCode(literal, 'a', 1, 0);
    try expectCode(literal, 256, 10, 511);
    try expectCode(literal, 257, 10, 1023);
    // These shapes require LL11, have multiple distance symbols, and exclude
    // the LL12/DIST9 RLE258 and DIST>=12 non-overlap policies.
    try std.testing.expect(distance.len > 1);
    try std.testing.expect(!rle258.isCandidate(parsed));
    try std.testing.expect(!rle258.shouldUse(&literal, &distance));
    try std.testing.expect(rle258.compactPairLiteral(&literal, parsed) == null);
    if (complete) {
        try std.testing.expectEqualSlices(u4, &completeDistances(), parsed.distance_lengths[0..11]);
        try expectCode(distance, 8, 9, 255);
        try expectCode(distance, 9, 10, 511);
        try expectCode(distance, 10, 10, 1023);
        try expectSecondaryShape(distance, 255, .{ 137, 154, 137, 170 });
        try std.testing.expectEqual(@as(@TypeOf(start), 1150), reader.bitPosition() - start);
    } else {
        try std.testing.expectEqualSlices(u4, &incomplete_distances, parsed.distance_lengths[0..2]);
        try expectCode(distance, 0, 9, 0);
        try expectCode(distance, 1, 10, 256);
        try expectSecondaryShape(distance, 0, .{ 9, 26, 9, null });
        try std.testing.expectEqual(@as(@TypeOf(start), 1114), reader.bitPosition() - start);
    }
}

fn expectShape(wire: *const Wire, seed_block: bool, literal_count: usize, token: Token) !void {
    var reader = bits.BufferedBitReader.init(wire.padded());
    if (seed_block) {
        try expectHeader(&reader, false, true);
        for (0..history_len) |_| try std.testing.expectEqual(@as(u1, 0), try reader.readBits(u1, 1));
        try std.testing.expectEqual(@as(u16, 511), try reader.readBits(u16, 10));
        try std.testing.expectEqual(@as(@TypeOf(reader.bitPosition()), 1288), reader.bitPosition());
    }
    try expectHeader(&reader, true, false);
    for (0..literal_count) |_| try std.testing.expectEqual(@as(u1, 0), try reader.readBits(u1, 1));
    // Verify public hot-loop headroom at the match token, with padding inside
    // the input slice and guards outside it. Existing codes remain decodable.
    try std.testing.expect(reader.byte_index + 8 <= wire.padded().len);
    try std.testing.expect(@as(usize, if (seed_block) history_len else 0) + literal_count + 16 <= output_len);
    try std.testing.expectEqual(@as(u16, 1023), try reader.readBits(u16, 10));
    switch (token) {
        .existing9 => try std.testing.expectEqual(@as(u16, 0), try reader.readBits(u16, 9)),
        .existing10 => try std.testing.expectEqual(@as(u16, 256), try reader.readBits(u16, 10)),
        .missing10 => {
            try std.testing.expectEqual(@as(u16, 768), try reader.readBits(u16, 10));
            try std.testing.expectEqual(@as(u4, 0), try reader.readBits(u4, 4));
        },
    }
    try std.testing.expectEqual(@as(u16, 511), try reader.readBits(u16, 10));
    try std.testing.expectEqual(@as(@TypeOf(reader.bitPosition()), @intCast(wire.bit_len)), reader.bitPosition());
}

fn check(comptime Api: type, wire: *const Wire, expected_error: ?anyerror, expected_output_len: usize) !void {
    const a = std.testing.allocator;
    const input = wire.padded();
    const source = try a.alloc(u8, input.len + guard_len * 2);
    defer a.free(source);
    @memset(source, sentinel);
    const guarded_input = source[guard_len..][0..input.len];
    @memcpy(guarded_input, input);
    var storage: [output_len + guard_len * 2]u8 = @splat(sentinel);
    const output = storage[guard_len..][0..output_len];
    const result = Api.decodeRawDeflate(guarded_input, output);
    try std.testing.expectEqualSlices(u8, input, guarded_input);
    for (source[0..guard_len]) |byte| try std.testing.expectEqual(sentinel, byte);
    for (source[guard_len + input.len ..]) |byte| try std.testing.expectEqual(sentinel, byte);
    // Speculative stores inside the declared capacity have no rollback or
    // untouched-tail contract, including when public decoding returns an error.
    for (storage[0..guard_len]) |byte| try std.testing.expectEqual(sentinel, byte);
    for (storage[guard_len + output_len ..]) |byte| try std.testing.expectEqual(sentinel, byte);
    if (expected_error) |err| {
        try std.testing.expectError(err, result);
    } else {
        const decoded = try result;
        try std.testing.expectEqual(wire.bare().len, decoded.input_read);
        try std.testing.expectEqual(expected_output_len, decoded.output_written);
        for (output[0..decoded.output_written]) |byte| try std.testing.expectEqual(@as(u8, 'a'), byte);
    }
}

pub fn contracts(comptime Api: type) !void {
    // Incomplete distance trees are an existing supported contract. Both real
    // codes, including the ten-bit secondary entry, must remain usable.
    for ([_]bool{ false, true }) |seed_block| {
        for ([_]Token{ .existing9, .existing10 }) |token| {
            const literal_count: usize = if (seed_block) 0 else history_len;
            const wire = makeWire(seed_block, literal_count, token);
            try expectShape(&wire, seed_block, literal_count, token);
            try check(Api, &wire, null, history_len + 3);
        }
    }
    // Public two-block witness: first builds a defined symbol-ten slot three;
    // second leaves that reused slot absent. There is no private table poison.
    const stale_slot = makeWire(true, 0, .missing10);
    try std.testing.expectEqual(@as(usize, 2436), stale_slot.bit_len);
    try std.testing.expectEqual(@as(usize, 305), stale_slot.bare().len);
    try expectShape(&stale_slot, true, 0, .missing10);
    try check(Api, &stale_slot, error.InvalidHuffmanCode, 0);

    // A missing code is invalid before history validation even in a one-block
    // stream. Its expected error is independent of any undefined slot value.
    const no_history = makeWire(false, 0, .missing10);
    try expectShape(&no_history, false, 0, .missing10);
    try check(Api, &no_history, error.InvalidHuffmanCode, 0);
}

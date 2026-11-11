//! Public one-shot contracts with explicit generic semantic entry witnesses.
//!
//! Api supplies decodeRawDeflate plus two aliases to the existing private
//! selectors: literalLookupBits(parsed) and slicesOverlap(input, output).
//! Native callers select linear_entry.aligned; WASM selects its portable twin.
const std = @import("std");
const huffman = @import("../../huffman.zig");
const bits = @import("../../bitstream.zig");
const semantic = @import("decoder.zig");
const rle258 = @import("rle258.zig");

const osdb = @embedFile("../decoder/testdata/osdb-zlib6-64k.deflate");
const osdb_header_bits = 762;
const guard_len = 64;
const sentinel: u8 = 0xa5;

// Deliberately independent of the production bit writer and Huffman encoder.
const Wire = struct {
    bytes: [512]u8 = @splat(0),
    bit_len: usize = 0,

    fn put(self: *Wire, value: u16, count: u5) void {
        std.debug.assert(self.bit_len + count <= self.bytes.len * 8);
        for (0..count) |i| {
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

fn osdbHeader() Wire {
    var wire: Wire = .{};
    wire.put(1, 1); // The rewritten body is the final block.
    for (1..osdb_header_bits) |i| {
        wire.put((osdb[i / 8] >> @intCast(i % 8)) & 1, 1);
    }
    return wire;
}

fn osdbZeros(literal_count: usize) Wire {
    var wire = osdbHeader();
    for (0..literal_count) |_| wire.put(0, 5); // Literal zero.
    wire.put(16383, 14); // LL278: length 83 plus four extra bits.
    wire.put(0, 4);
    wire.put(127, 8); // Distance zero: distance one.
    wire.put(8191, 14); // EOB256.
    return wire;
}

fn osdbBadHistory(comptime large_distance: bool) Wire {
    var wire = osdbHeader();
    wire.put(16, 5); // LL257: length three, before any history exists.
    if (large_distance) {
        wire.put(31, 6); // Distance 29: 24577 plus thirteen extra bits.
        wire.put(8191, 13); // Distance 32768.
    } else {
        wire.put(127, 8); // Distance one, also invalid without history.
    }
    wire.put(8191, 14);
    return wire;
}

fn reverse(value: u16, width: u5) u16 {
    var result: u16 = 0;
    for (0..width) |i| result = (result << 1) | ((value >> @intCast(i)) & 1);
    return result;
}

fn invalidDistancePrefix() Wire {
    var wire: Wire = .{};
    wire.put(1, 1);
    wire.put(2, 2);
    wire.put(1, 5); // HLIT258.
    wire.put(29, 5); // HDIST30.
    wire.put(15, 4); // HCLEN19.
    const order = [_]u8{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
    for (order) |symbol| wire.put(if (symbol < 16) 4 else 0, 3);

    // Complete LL10 tree: one leaf at widths 1..9 and two at width 10.
    // The CL alphabet is the complete 0..15 dictionary, each at width four.
    var lengths: [258]u4 = @splat(0);
    lengths['a'] = 1;
    for (0..8) |i| lengths[i] = @intCast(i + 2);
    lengths[256] = 10;
    lengths[257] = 10;
    for (lengths) |length| wire.put(reverse(length, 4), 4);
    for (0..30) |symbol| wire.put(reverse(if (symbol == 0 or symbol == 29) 2 else 0, 4), 4);

    // This distance tree is intentionally incomplete: canonical wire prefixes
    // 00 and 10 exist, while 01 has no primary entry. Other decoders may reject
    // the tree at the header; Vort accepts it and must reject its missing code.
    for (0..256) |_| wire.put(0, 1); // Literal 'a', canonical code zero.
    wire.put(1023, 10); // LL257.
    wire.put(1, 2); // Missing distance prefix.
    for (0..512) |_| wire.put(0, 1); // Keep the failing token in the wide loop.
    wire.put(511, 10); // EOB256.
    return wire;
}

const Shape = enum { osdb, incomplete_distance };

fn expectCode(table: anytype, symbol: u16, width: u4, code: u16) !void {
    for (table.entries[0..table.len]) |entry| {
        if (entry.symbol != symbol) continue;
        try std.testing.expectEqual(width, entry.bits);
        try std.testing.expectEqual(code, entry.code);
        return;
    }
    return error.TestExpectedEqual;
}

fn expectEntry(
    comptime Api: type,
    input: []const u8,
    output: []u8,
    shape: Shape,
    hot: bool,
) !void {
    // Use the same buffered parser and private selector predicates as the
    // public facade. A descriptive test name or a deep private decoder call
    // would not establish which public entry this wire actually selects.
    try std.testing.expect(input.len != 0);
    try std.testing.expect(!Api.slicesOverlap(input, output));
    var reader = bits.BufferedBitReader.init(input);
    try std.testing.expectEqual(@as(u1, 1), try reader.readBits(u1, 1));
    try std.testing.expectEqual(@as(u2, 2), try reader.readBits(u2, 2));
    const parsed = try huffman.parseDynamicLengthsAfterHeader(true, &reader);
    try std.testing.expect(parsed.literal_max_bits > 9);
    try std.testing.expectEqual(@as(u4, 11), Api.literalLookupBits(parsed));
    try std.testing.expect(parsed.distance_max_bits < 12);
    const literal = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
    const distance = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
    try std.testing.expect(semantic.SemanticDynamicDecoder.treeIsComplete(286, &literal));
    try std.testing.expect(distance.len > 1); // Exclude single-distance and RLE1.
    try std.testing.expect(parsed.distance_lengths[0] != 0);
    try std.testing.expect(!rle258.isCandidate(parsed));
    try std.testing.expect(!rle258.shouldUse(&literal, &distance));
    try std.testing.expect(rle258.compactPairLiteral(&literal, parsed) == null);
    const dynamic_distance = semantic.DynamicDistanceDecoder.init(distance);
    try std.testing.expect(std.meta.activeTag(dynamic_distance) == .fast8);
    var decoder: semantic.SemanticDynamicDecoder = undefined;
    try std.testing.expect(decoder.initWithDynamicDistanceDecoder(&literal, &dynamic_distance));

    switch (shape) {
        .osdb => {
            try std.testing.expectEqual(@as(u16, 279), parsed.header.hlit);
            try std.testing.expectEqual(@as(u16, 30), parsed.header.hdist);
            try std.testing.expectEqual(@as(u4, 14), parsed.literal_max_bits);
            try std.testing.expectEqual(@as(u4, 9), parsed.distance_max_bits);
            try std.testing.expectEqual(@as(usize, 22), distance.len);
            try std.testing.expect(semantic.SemanticDynamicDecoder.treeIsComplete(30, &distance));
            try std.testing.expectEqual(@as(@TypeOf(reader.bitPosition()), osdb_header_bits), reader.bitPosition());
            try std.testing.expect(decoder.literal_secondary_len != 0);
            try std.testing.expect(decoder.distance_secondary_len != 0);
            const length_primary = decoder.literal[16383 & semantic.SemanticDynamicDecoder.literal_lookup_mask];
            const secondary_flags = semantic.SemanticDynamicDecoder.exceptional_flag | semantic.SemanticDynamicDecoder.secondary_flag;
            try std.testing.expectEqual(secondary_flags, length_primary & secondary_flags);
            try expectCode(literal, 0, 5, 0);
            try expectCode(literal, 257, 5, 16);
            try expectCode(literal, 278, 14, 16383);
            try expectCode(literal, 256, 14, 8191);
            try expectCode(distance, 0, 8, 127);
            try expectCode(distance, 29, 6, 31);
        },
        .incomplete_distance => {
            try std.testing.expectEqual(@as(u16, 258), parsed.header.hlit);
            try std.testing.expectEqual(@as(u16, 30), parsed.header.hdist);
            try std.testing.expectEqual(@as(u8, 19), parsed.header.hclen);
            try std.testing.expectEqual(@as(u4, 10), parsed.literal_max_bits);
            try std.testing.expectEqual(@as(u4, 2), parsed.distance_max_bits);
            try std.testing.expectEqual(@as(usize, 11), literal.len);
            try std.testing.expectEqual(@as(usize, 2), distance.len);
            try std.testing.expectEqual(@as(u4, 0), parsed.literal_lengths[285]);
            try std.testing.expectEqual(@as(@TypeOf(reader.bitPosition()), 1226), reader.bitPosition());
            try std.testing.expect(!semantic.SemanticDynamicDecoder.treeIsComplete(30, &distance));
            try expectCode(literal, 'a', 1, 0);
            try expectCode(literal, 256, 10, 511);
            try expectCode(literal, 257, 10, 1023);
            try expectCode(distance, 0, 2, 0);
            try expectCode(distance, 29, 2, 2);
            try std.testing.expectEqual(@as(u32, 0), decoder.distance[1]);
            // 256 one-bit literals precede the bad token and 512 follow it.
            // Even its token start retains wide-input and output headroom.
            try std.testing.expect(input.len * 8 >= 1226 + 256 + 12 + 512);
            try std.testing.expect(output.len >= 256 + 16);
        },
    }
    if (hot) {
        // These are the actual first-iteration conditions in the five-false
        // linear core. In the no-history cases the first token itself fails;
        // the secondary length/output case fails in that same hot iteration.
        try std.testing.expect(output.len >= 16);
        try std.testing.expect(reader.byte_index + 8 <= input.len);
    } else {
        // The public generic entry still runs, with only its bounded tail.
        try std.testing.expect(output.len < 16);
    }
}

fn check(
    comptime Api: type,
    input: []const u8,
    output_len: usize,
    comptime shape: ?Shape,
    expected_error: ?anyerror,
    expected_output_len: usize,
) !void {
    const a = std.testing.allocator;
    const source = try a.alloc(u8, input.len + guard_len * 2);
    defer a.free(source);
    @memset(source, sentinel);
    const guarded_input = source[guard_len..][0..input.len];
    @memcpy(guarded_input, input);
    const storage = try a.alloc(u8, output_len + guard_len * 2);
    defer a.free(storage);
    @memset(storage, sentinel);
    const output = storage[guard_len..][0..output_len];
    if (shape) |wire_shape| try expectEntry(Api, guarded_input, output, wire_shape, output_len >= 16);

    const result = Api.decodeRawDeflate(guarded_input, output);
    if (expected_error) |err| {
        try std.testing.expectError(err, result);
    } else {
        const decoded = try result;
        try std.testing.expectEqual(input.len - 16, decoded.input_read);
        try std.testing.expectEqual(expected_output_len, decoded.output_written);
        for (output[0..decoded.output_written]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    }
    try std.testing.expectEqualSlices(u8, input, guarded_input);
    for (source[0..guard_len]) |byte| try std.testing.expectEqual(sentinel, byte);
    for (source[guard_len + input.len ..]) |byte| try std.testing.expectEqual(sentinel, byte);
    // Public failures may leave speculative bytes inside the whole output
    // slice. Its committed prefix and scratch tail have no rollback contract.
    for (storage[0..guard_len]) |byte| try std.testing.expectEqual(sentinel, byte);
    for (storage[guard_len + output_len ..]) |byte| try std.testing.expectEqual(sentinel, byte);
}

pub fn contracts(comptime Api: type) !void {
    const valid = osdbZeros(1);
    try std.testing.expectEqual(@as(usize, 101), valid.bare().len);
    try check(Api, valid.padded(), 84, .osdb, null, 84);
    // One literal and a secondary LL278 length 83 exceed even a 16-byte
    // destination while the first generic fast iteration still has headroom.
    try check(Api, valid.padded(), 16, .osdb, error.OutputTooSmall, 0);
    try check(Api, valid.padded(), 83, .osdb, error.OutputTooSmall, 0);
    for (0..16) |short_len| try check(Api, valid.padded(), short_len, .osdb, error.OutputTooSmall, 0);

    const bad_history = osdbBadHistory(false);
    try std.testing.expectEqual(@as(usize, 99), bad_history.bare().len);
    try check(Api, bad_history.padded(), 16, .osdb, error.InvalidMatch, 0);
    const bad_distance29 = osdbBadHistory(true);
    try check(Api, bad_distance29.padded(), 32, .osdb, error.InvalidMatch, 0);

    const long = osdbZeros(128);
    try std.testing.expectEqual(@as(usize, 181), long.bare().len);
    try check(Api, long.padded(), 211, .osdb, null, 211);
    // No padding: plenty of literal payload admits real fast iterations, then
    // removing the length/distance/EOB tail forces exact bounded truncation.
    for (1..5) |cut| try check(Api, long.bare()[0 .. long.bare().len - cut], 211, .osdb, error.TruncatedFrame, 0);

    const invalid_prefix = invalidDistancePrefix();
    try check(Api, invalid_prefix.bare(), 1024, .incomplete_distance, error.InvalidHuffmanCode, 0);
}

// Exercise the library's root alias directly as well. The complete suite above
// establishes the shared OSDB header's selector and fast-iteration witnesses.
pub fn rootContracts(comptime Root: type) !void {
    const valid = osdbZeros(1);
    try check(Root, valid.padded(), 84, null, null, 84);
    const bad_history = osdbBadHistory(false);
    try check(Root, bad_history.padded(), 16, null, error.InvalidMatch, 0);
}

const std = @import("std");
const h = @import("helpers.zig");
const BitReader = @import("../../../../bitstream.zig").BitReader;
const syntax = @import("../../../../png_ultrafast.zig").incremental_syntax;
const Entry = struct { symbol: u16, bits: u4 };

// Reconstruct the canonical decode table from code lengths, independently
// of the encoder's codes, reservoir, zero-run batching and length mapper.
const table: [4096]Entry = blk: {
    @setEvalBranchQuota(200_000);
    var entries: [4096]Entry = undefined;
    var frequencies: [13]u16 = @splat(0);
    for (syntax.lengths) |length| frequencies[length] += 1;
    var next: [13]u16 = @splat(0);
    var code: u16 = 0;
    for (1..13) |bits| {
        code = (code + frequencies[bits - 1]) << 1;
        next[bits] = code;
    }
    for (syntax.lengths, 0..) |bits, symbol| {
        const reversed = @bitReverse(next[bits]) >> @as(u4, @intCast(16 - @as(u5, bits)));
        next[bits] += 1;
        for (0..@as(usize, 1) << @intCast(12 - bits)) |suffix|
            entries[reversed | (suffix << bits)] = .{ .symbol = @intCast(symbol), .bits = bits };
    }
    break :blk entries;
};

/// Validate every physically emitted token. A zero literal followed by
/// distance-one copies is a C-style expected-payload oracle: every generated
/// byte is known zero without allocating or walking a >4 GiB output buffer.
pub fn zeros(wire: []const u8, expected: h.Count) !void {
    try std.testing.expect(wire.len >= 60);
    try std.testing.expectEqualSlices(u8, syntax.header[0..2], wire[0..2]);
    try std.testing.expectEqual(syntax.header[2] & 0xfe, wire[2]);
    try std.testing.expectEqualSlices(u8, syntax.header[3..53], wire[3..53]);
    var reader = BitReader.init(wire[53..]);
    try std.testing.expectEqual(@as(u8, syntax.header[53] & 0x1f), try reader.readBits(u8, 5));
    const bases = [_]u16{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 };
    const extras = [_]u6{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 };
    var produced: h.Count = 0;
    var matches: h.Count = 0;
    while (true) {
        const entry = table[reader.peekBitsPadded(u12, 12)];
        try reader.skipBits(entry.bits);
        if (entry.symbol == 256) break;
        if (entry.symbol < 256) {
            try std.testing.expectEqual(@as(u16, 0), entry.symbol);
            produced = try h.counts.addLocal(produced, 1);
        } else {
            const index = entry.symbol - 257;
            try std.testing.expect(index < bases.len and produced != 0);
            const length = bases[index] + try reader.readBits(u16, extras[index]);
            // The trained distance alphabet has one-bit symbol 0, whose
            // RFC distance is one and which needs no extra bits.
            try std.testing.expectEqual(@as(u1, 0), try reader.readBits(u1, 1));
            produced = try h.counts.addLocal(produced, length);
            matches += 1;
        }
        try std.testing.expect(produced <= expected);
    }
    try std.testing.expectEqual(expected, produced);
    if (expected > 258) try std.testing.expect(matches != 0);
    try std.testing.expectEqual(@as(u3, 1), try reader.readBits(u3, 3));
    reader.alignToByte();
    try std.testing.expectEqual(@as(u16, 0), try reader.readAlignedInt(u16, .little));
    try std.testing.expectEqual(@as(u16, 0xffff), try reader.readAlignedInt(u16, .little));
    try std.testing.expectEqual(h.repeatedAdler(0, expected), try reader.readAlignedInt(u32, .big));
    try std.testing.expectEqual(wire.len - 53, reader.byteOffset());
}

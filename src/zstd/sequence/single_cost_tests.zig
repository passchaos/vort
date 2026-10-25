const std = @import("std");
const single = @import("single_cost.zig");

const ByteWriter = struct {
    bytes: [16]u8 = @splat(0),
    position: usize = 0,
    fn field(self: *ByteWriter, value: u64, width: u8) void {
        for (0..width) |bit| {
            const one: u8 = @intCast((value >> @as(u6, @intCast(bit))) & 1);
            self.bytes[self.position / 8] |= one << @as(u3, @intCast(self.position % 8));
            self.position += 1;
        }
    }
    fn finish(self: *ByteWriter) usize {
        self.field(1, 1);
        return self.position / 8 + @intFromBool(self.position % 8 != 0);
    }
};

fn scanCode(value: usize, bases: []const usize, bits: []const u8) error{CorruptFrame}!usize {
    var selected: ?usize = null;
    for (bases, bits, 0..) |base, width, code| {
        if (value < base) continue;
        if (@as(u64, value - base) >= (@as(u64, 1) << @as(u6, @intCast(width)))) continue;
        if (selected == null or base >= bases[selected.?]) selected = code;
    }
    return selected orelse error.CorruptFrame;
}

fn scanState(value: usize, symbols: anytype, minimum: u8) error{CorruptFrame}!usize {
    for (symbols, 0..) |symbol, state| {
        if (symbol.additional_bits < minimum or value < symbol.base) continue;
        if (@as(u64, value - symbol.base) < (@as(u64, 1) << @as(u6, @intCast(symbol.additional_bits)))) return state;
    }
    return error.CorruptFrame;
}

fn oracleRle(comptime Codec: type, prefix: usize, offset: usize, match: usize, section: usize) Codec.Rules.Error!usize {
    const literal = try scanCode(prefix, Codec.literal_bases[0..], Codec.Rules.literal_bits[0..]);
    const off = try scanCode(offset, Codec.offset_bases[0..], Codec.Rules.offset_bits[0..]);
    const ml = try scanCode(match, Codec.match_bases[0..], Codec.Rules.match_bits[0..]);
    var writer: ByteWriter = .{};
    writer.field(offset - Codec.offset_bases[off], Codec.Rules.offset_bits[off]);
    writer.field(match - Codec.match_bases[ml], Codec.Rules.match_bits[ml]);
    writer.field(prefix - Codec.literal_bases[literal], Codec.Rules.literal_bits[literal]);
    const stream_len = writer.finish();
    var length = std.math.add(usize, section, 1) catch return error.IntegerOverflow; // one sequence count
    length = std.math.add(usize, length, 4) catch return error.IntegerOverflow; // mode and three RLE symbols
    return std.math.add(usize, length, stream_len) catch error.IntegerOverflow;
}

fn oraclePredefined(comptime Codec: type, prefix: usize, offset: usize, match: usize, section: usize) Codec.Rules.Error!usize {
    // Scan the original decoded FSE state tables, independently of fast masks
    // or arithmetic code classifiers. One sequence chooses the lowest state.
    const literal = try scanState(prefix, Codec.literal_symbols[0..], 0);
    const off = try scanState(offset, Codec.offset_symbols[0..], 2);
    const ml = try scanState(match, Codec.match_symbols[0..], 0);
    const ls = Codec.literal_symbols[literal];
    const os = Codec.offset_symbols[off];
    const ms = Codec.match_symbols[ml];
    var writer: ByteWriter = .{};
    writer.field(literal, 6);
    writer.field(off, 5);
    writer.field(ml, 6);
    writer.field(offset - os.base, os.additional_bits);
    writer.field(match - ms.base, ms.additional_bits);
    writer.field(prefix - ls.base, ls.additional_bits);
    const stream_len = writer.finish();
    var length = std.math.add(usize, section, 1) catch return error.IntegerOverflow;
    length = std.math.add(usize, length, 1) catch return error.IntegerOverflow;
    return std.math.add(usize, length, stream_len) catch error.IntegerOverflow;
}

fn oracleBase(comptime Codec: type, prefix: usize, offset: usize, match: usize, section: usize) Codec.Rules.Error!usize {
    var best: ?usize = null;
    if (oracleRle(Codec, prefix, offset, match, section)) |cost| best = cost else |err| if (err != error.CorruptFrame) return err;
    if (oraclePredefined(Codec, prefix, offset, match, section)) |cost| {
        best = @min(best orelse cost, cost);
    } else |err| if (err != error.CorruptFrame) return err;
    return best orelse error.CorruptFrame;
}

fn equalResult(expected: anytype, actual: anytype) !void {
    if (expected) |value| try std.testing.expectEqual(value, try actual) else |err| try std.testing.expectError(err, actual);
}

fn check(comptime Codec: type, prefix: usize, offset: usize, match: usize, section: usize) !void {
    const Calc = single.Calculator(Codec.Rules);
    const rle = Calc.rlePayloadLen(prefix, offset, match, section);
    const predefined = Calc.predefinedPayloadLen(prefix, offset, match, section);
    const base = Calc.baseLen(prefix, offset, match, section);
    try equalResult(Codec.referenceRle(prefix, offset, match, section), rle);
    try equalResult(Codec.referencePredefined(prefix, offset, match, section), predefined);
    try equalResult(Codec.referenceBase(prefix, offset, match, section), base);
    try equalResult(oracleRle(Codec, prefix, offset, match, section), rle);
    try equalResult(oraclePredefined(Codec, prefix, offset, match, section), predefined);
    try equalResult(oracleBase(Codec, prefix, offset, match, section), base);
}

fn boundaries(comptime Codec: type) !void {
    const bases = .{ Codec.literal_bases[0..], Codec.offset_bases[0..], Codec.match_bases[0..] };
    const widths = .{ Codec.Rules.literal_bits[0..], Codec.Rules.offset_bits[0..], Codec.Rules.match_bits[0..] };
    inline for (0..3) |kind| {
        for (bases[kind], widths[kind]) |base, bits| {
            const end: u64 = @as(u64, base) + (@as(u64, 1) << @as(u6, @intCast(bits))) - 1;
            const points = [_]u64{ base, @as(u64, base) -| 1, @as(u64, base) + 1, end -| 1, end, end + 1 };
            for (points) |point| {
                if (point > std.math.maxInt(usize)) continue;
                var values = [3]usize{ 16, 8, 64 };
                values[kind] = @intCast(point);
                try check(Codec, values[0], values[1], values[2], 23);
            }
        }
    }
    for ([_]usize{ 0, 1, 2, 3 }) |offset| try check(Codec, 0, offset, 3, 0);
    for ([_]usize{ 131070, 131071, 131072, 131073, 131074, 131075 }) |value| {
        try check(Codec, value, 8, 3, 0);
        try check(Codec, 0, 8, value, 0);
    }
    for ([_]usize{ std.math.maxInt(u32) - 3, std.math.maxInt(u32) - 2, std.math.maxInt(u32) - 1, std.math.maxInt(u32), std.math.maxInt(usize) - 2, std.math.maxInt(usize) - 1, std.math.maxInt(usize) }) |offset|
        try check(Codec, 0, offset, 3, 0);
    if (@bitSizeOf(usize) > 32) {
        const wide: usize = @as(usize, 1) << 32;
        try check(Codec, wide, 8, 3, 0);
        try check(Codec, 0, wide, 3, 0);
        try check(Codec, 0, 8, wide, 0);
    }
}

fn packingAndOverflow(comptime Codec: type) !void {
    const Calc = single.Calculator(Codec.Rules);
    var residues: [8]bool = @splat(false);
    for ([_]usize{ 0, 16, 20, 22, 24, 25, 26, 27 }) |ll| {
        for (2..10) |off| {
            for ([_]usize{ 0, 32, 36, 38, 40, 42, 43, 44 }) |ml| {
                const prefix = Codec.literal_bases[ll];
                const offset = Codec.offset_bases[off];
                const match = Codec.match_bases[ml];
                const extra = @as(usize, Codec.Rules.literal_bits[ll]) + Codec.Rules.offset_bits[off] + Codec.Rules.match_bits[ml];
                residues[extra % 8] = true;
                try check(Codec, prefix, offset, match, 17);
                const rle = try Calc.rlePayloadLen(prefix, offset, match, 0);
                const predefined = try Calc.predefinedPayloadLen(prefix, offset, match, 0);
                if (extra % 8 == 7) try std.testing.expectEqual(rle, predefined) else try std.testing.expectEqual(rle - 1, predefined);
            }
        }
    }
    for (residues) |seen| try std.testing.expect(seen);
    const rle = try Calc.rlePayloadLen(0, 1, 3, 0);
    const predefined = try Calc.predefinedPayloadLen(0, 1, 3, 0);
    try std.testing.expectEqual(@as(usize, 6), rle);
    try std.testing.expectEqual(@as(usize, 5), predefined);
    const maximum = std.math.maxInt(usize);
    for ([_]usize{ 0, 1, 4096, maximum - 6, maximum - 5, maximum - 4, maximum }) |section| try check(Codec, 0, 1, 3, section);
    try std.testing.expectEqual(maximum, try Calc.predefinedPayloadLen(0, 1, 3, maximum - 5));
    try std.testing.expectError(error.IntegerOverflow, Calc.rlePayloadLen(0, 1, 3, maximum - 5));
    // Keep old error order: a fitting cheaper family cannot erase RLE overflow.
    try std.testing.expectError(error.IntegerOverflow, Calc.baseLen(0, 1, 3, maximum - 5));
    try check(Codec, 0, 0, 2, maximum);
}

fn clearMask(comptime original: anytype, comptime code: usize) [original.len]@TypeOf(original[0]) {
    var changed: [original.len]@TypeOf(original[0]) = undefined;
    @memcpy(&changed, original[0..]);
    changed[code] = 0;
    return changed;
}

fn HoleyRules(comptime Rules: type, comptime kind: enum { literal, offset, match }) type {
    return struct {
        pub const Error = Rules.Error;
        pub const literalCode = Rules.literalCode;
        pub const offsetCode = Rules.offsetCode;
        pub const matchCode = Rules.matchCode;
        pub const literal_bits = Rules.literal_bits;
        pub const offset_bits = Rules.offset_bits;
        pub const match_bits = Rules.match_bits;
        const literal_storage = clearMask(Rules.literal_masks, 0);
        const offset_storage = clearMask(Rules.offset_masks, 2);
        const match_storage = clearMask(Rules.match_masks, 0);
        pub const literal_masks = if (kind == .literal) &literal_storage else Rules.literal_masks;
        pub const offset_masks = if (kind == .offset) &offset_storage else Rules.offset_masks;
        pub const match_masks = if (kind == .match) &match_storage else Rules.match_masks;
        pub const contract = Rules.contract;
    };
}

fn holes(comptime Codec: type) !void {
    try std.testing.expect(Codec.Rules.literal_masks[0] != 0 and Codec.Rules.offset_masks[2] != 0 and Codec.Rules.match_masks[0] != 0);
    inline for (.{ .literal, .offset, .match }) |kind| {
        const Calc = single.Calculator(HoleyRules(Codec.Rules, kind));
        // Holey rules are intentionally a different policy. Compare their RLE
        // family to the true old codec, and require predefined to be unavailable.
        try equalResult(Codec.referenceRle(0, 1, 3, 23), Calc.rlePayloadLen(0, 1, 3, 23));
        try std.testing.expectError(error.CorruptFrame, Calc.predefinedPayloadLen(0, 1, 3, 23));
        try std.testing.expectEqual(try Calc.rlePayloadLen(0, 1, 3, 23), try Calc.baseLen(0, 1, 3, 23));
    }
}

fn randomCases(comptime Codec: type) !void {
    var state: u32 = 0x13198a2e;
    for (0..512) |index| {
        state = state *% 1664525 +% 1013904223;
        const prefix: usize = state % 200000;
        state = state *% 1664525 +% 1013904223;
        const offset: usize = if (index % 2 == 0) state % 4096 else state;
        state = state *% 1664525 +% 1013904223;
        const match: usize = state % 200000;
        const section: usize = if (index % 17 == 0) std.math.maxInt(usize) - @as(usize, state % 12) else state % 65536;
        try check(Codec, prefix, offset, match, section);
    }
}

pub fn contracts(comptime Codec: type) !void {
    try std.testing.expect(@sizeOf(single.Calculator(Codec.Rules)) <= 64);
    try boundaries(Codec);
    try packingAndOverflow(Codec);
    try holes(Codec);
    try randomCases(Codec);
}

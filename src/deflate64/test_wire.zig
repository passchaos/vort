//! Independent Deflate64 test decoder. No production Huffman tables, block
//! classifier, matcher, or decoder are used to inspect emitted wire tokens.
const std = @import("std");
const a = std.testing.allocator;

pub const Cursor = struct {
    bytes: []const u8,
    position: usize = 0,

    pub fn read(self: *Cursor, width: u6) !u32 {
        if (width > 32) return error.InvalidFieldWidth;
        if (@as(u128, self.position) + width > @as(u128, self.bytes.len) * 8) return error.TruncatedFrame;
        var value: u32 = 0;
        for (0..width) |bit| {
            const absolute = self.position + bit;
            value |= @as(u32, (self.bytes[absolute / 8] >> @as(u3, @intCast(absolute % 8))) & 1) << @as(u5, @intCast(bit));
        }
        self.position += width;
        return value;
    }

    pub fn alignToByte(self: *Cursor) void {
        self.position += (8 - self.position % 8) % 8;
    }
};

const Canonical = struct {
    counts: [16]u16 = @splat(0),
    first_code: [16]u16 = @splat(0),
    first_symbol: [16]u16 = @splat(0),
    symbols: [288]u16 = undefined,
    maximum: u5 = 0,

    fn init(lengths: []const u8, max_bits: u5, allow_empty: bool, require_complete: bool) !Canonical {
        if (lengths.len > 288) return error.InvalidHuffmanCode;
        var result: Canonical = .{};
        var used: usize = 0;
        for (lengths) |width| {
            if (width > max_bits) return error.InvalidHuffmanCode;
            if (width != 0) {
                result.counts[width] += 1;
                result.maximum = @max(result.maximum, @as(u5, @intCast(width)));
                used += 1;
            }
        }
        if (used == 0) {
            if (!allow_empty) return error.InvalidHuffmanCode;
            return result;
        }
        var left: i32 = 1;
        var code: u16 = 0;
        var offset: u16 = 0;
        for (1..@as(usize, max_bits) + 1) |width| {
            left = left * 2 - result.counts[width];
            if (left < 0) return error.InvalidHuffmanCode;
            code = (code + result.counts[width - 1]) << 1;
            result.first_code[width] = code;
            result.first_symbol[width] = offset;
            for (lengths, 0..) |length, code_symbol| if (length == width) {
                result.symbols[offset] = @intCast(code_symbol);
                offset += 1;
            };
        }
        // RFC1951 permits an incomplete data tree only for the single
        // one-bit code special case. Code-length trees must be complete.
        if (left != 0 and (require_complete or used != 1 or result.counts[1] != 1)) return error.InvalidHuffmanCode;
        return result;
    }

    fn symbol(self: *const Canonical, reader: *Cursor) !u16 {
        var value: u16 = 0;
        for (1..@as(usize, self.maximum) + 1) |width| {
            value = (value << 1) | @as(u16, @intCast(try reader.read(1)));
            const first = self.first_code[width];
            if (value >= first and value - first < self.counts[width])
                return self.symbols[self.first_symbol[width] + value - first];
        }
        return error.InvalidHuffmanCode;
    }
};

pub const DynamicHeader = struct {
    literal_symbols: usize,
    distance_symbols: usize,
    code_length_symbols: usize,
    repeat_16: usize = 0,
    repeat_17: usize = 0,
    repeat_18: usize = 0,
    bits: usize = 0,
    literal_lengths: [286]u8 = @splat(0),
    distance_lengths: [32]u8 = @splat(0),
};
const Tables = struct { literal: Canonical, distance: Canonical, header: ?DynamicHeader = null };

fn fixedTables() !Tables {
    var literal: [288]u8 = undefined;
    @memset(literal[0..144], 8);
    @memset(literal[144..256], 9);
    @memset(literal[256..280], 7);
    @memset(literal[280..], 8);
    return .{ .literal = try Canonical.init(&literal, 15, false, true), .distance = try Canonical.init(&([_]u8{5} ** 32), 15, false, true) };
}

fn dynamicTables(reader: *Cursor) !Tables {
    const start = reader.position;
    var header: DynamicHeader = .{
        .literal_symbols = 257 + @as(usize, try reader.read(5)),
        .distance_symbols = 1 + @as(usize, try reader.read(5)),
        .code_length_symbols = 4 + @as(usize, try reader.read(4)),
    };
    if (header.literal_symbols > 286 or header.distance_symbols > 32) return error.InvalidDynamicBlockHeader;
    const order = [_]u8{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
    var code_lengths: [19]u8 = @splat(0);
    for (order[0..header.code_length_symbols]) |symbol| code_lengths[symbol] = @intCast(try reader.read(3));
    const code_length_table = try Canonical.init(&code_lengths, 7, false, true);
    var lengths: [318]u8 = @splat(0);
    const count = header.literal_symbols + header.distance_symbols;
    var offset: usize = 0;
    while (offset < count) {
        const symbol = try code_length_table.symbol(reader);
        if (symbol <= 15) {
            lengths[offset] = @intCast(symbol);
            offset += 1;
            continue;
        }
        var repeated: u8 = 0;
        const repeat: usize = switch (symbol) {
            16 => blk: {
                if (offset == 0) return error.InvalidDynamicBlockHeader;
                repeated = lengths[offset - 1];
                header.repeat_16 += 1;
                break :blk 3 + @as(usize, try reader.read(2));
            },
            17 => blk: {
                header.repeat_17 += 1;
                break :blk 3 + @as(usize, try reader.read(3));
            },
            18 => blk: {
                header.repeat_18 += 1;
                break :blk 11 + @as(usize, try reader.read(7));
            },
            else => return error.InvalidDynamicBlockHeader,
        };
        if (repeat > count - offset) return error.InvalidDynamicBlockHeader;
        @memset(lengths[offset..][0..repeat], repeated);
        offset += repeat;
    }
    if (lengths[256] == 0) return error.InvalidDynamicBlockHeader;
    @memcpy(header.literal_lengths[0..header.literal_symbols], lengths[0..header.literal_symbols]);
    @memcpy(header.distance_lengths[0..header.distance_symbols], lengths[header.literal_symbols..count]);
    header.bits = reader.position - start;
    return .{ .literal = try Canonical.init(lengths[0..header.literal_symbols], 15, false, false), .distance = try Canonical.init(lengths[header.literal_symbols..count], 15, true, false), .header = header };
}

pub const Match = struct { block: usize, position: usize, length_code: u16, length: usize, distance_code: u16, distance: usize };
pub const Block = struct { kind: u2, final: bool, bit_start: usize, bit_end: usize, output_start: usize, output_end: usize, header: ?DynamicHeader };
pub const Inspection = struct {
    output: []u8,
    matches: std.ArrayList(Match) = .empty,
    blocks: std.ArrayList(Block) = .empty,
    fixed_blocks: usize = 0,
    stored_blocks: usize = 0,
    dynamic_blocks: usize = 0,
    literals: usize = 0,
    produced: usize = 0,
    bit_len: usize = 0,

    pub fn deinit(self: *Inspection) void {
        self.matches.deinit(a);
        self.blocks.deinit(a);
        a.free(self.output);
        self.* = undefined;
    }
};

/// The expected output bound is supplied by each real test fixture, rather
/// than inferred from the codec under test. Stored and matched output cannot
/// exceed this bound, including overlapping Deflate64 matches.
pub fn inspect(bytes: []const u8, output_len: usize) !Inspection {
    var result: Inspection = .{ .output = try a.alloc(u8, output_len) };
    errdefer result.deinit();
    var reader: Cursor = .{ .bytes = bytes };
    while (true) {
        const start = reader.position;
        const output_start = result.produced;
        const final = try reader.read(1) != 0;
        const kind: u2 = @intCast(try reader.read(2));
        var header: ?DynamicHeader = null;
        if (kind == 0) {
            result.stored_blocks += 1;
            reader.alignToByte();
            const count: u16 = @intCast(try reader.read(16));
            const complement: u16 = @intCast(try reader.read(16));
            if (count != ~complement) return error.StoredLengthMismatch;
            if (count > result.output.len - result.produced) return error.OutputTooSmall;
            for (result.output[result.produced..][0..count]) |*byte| byte.* = @intCast(try reader.read(8));
            result.produced += count;
        } else if (kind == 1 or kind == 2) {
            const tables = if (kind == 1) try fixedTables() else try dynamicTables(&reader);
            header = tables.header;
            if (kind == 1) result.fixed_blocks += 1 else result.dynamic_blocks += 1;
            while (true) {
                const symbol = try tables.literal.symbol(&reader);
                if (symbol < 256) {
                    if (result.produced == result.output.len) return error.OutputTooSmall;
                    result.output[result.produced] = @intCast(symbol);
                    result.produced += 1;
                    result.literals += 1;
                    continue;
                }
                if (symbol == 256) break;
                if (symbol > 285) return error.InvalidHuffmanCode;
                const length: usize = if (symbol <= 264)
                    symbol - 254
                else if (symbol == 285)
                    3 + @as(usize, try reader.read(16))
                else blk: {
                    const width: u6 = @intCast((symbol - 265) / 4 + 1);
                    const slot: usize = (symbol - 265) % 4;
                    const base = (@as(usize, 1) << @intCast(width + 2)) + 3 + slot * (@as(usize, 1) << @intCast(width));
                    break :blk base + try reader.read(width);
                };
                const distance_code = try tables.distance.symbol(&reader);
                if (distance_code > 31) return error.InvalidHuffmanCode;
                const distance: usize = if (distance_code < 4)
                    distance_code + 1
                else blk: {
                    const width: u6 = @intCast(distance_code / 2 - 1);
                    const base = ((2 + @as(usize, distance_code & 1)) << @intCast(width)) + 1;
                    break :blk base + try reader.read(width);
                };
                if (distance > result.produced or distance > 65_536) return error.InvalidMatch;
                if (length > result.output.len - result.produced) return error.OutputTooSmall;
                try result.matches.append(a, .{ .block = result.blocks.items.len, .position = result.produced, .length_code = symbol, .length = length, .distance_code = distance_code, .distance = distance });
                for (0..length) |_| {
                    result.output[result.produced] = result.output[result.produced - distance];
                    result.produced += 1;
                }
            }
        } else return error.InvalidDeflateBlockType;
        try result.blocks.append(a, .{ .kind = kind, .final = final, .bit_start = start, .bit_end = reader.position, .output_start = output_start, .output_end = result.produced, .header = header });
        if (final) break;
    }
    if (result.produced != output_len) return error.SizeMismatch;
    result.bit_len = reader.position;
    if (bytes.len != reader.position / 8 + @intFromBool(reader.position % 8 != 0)) return error.TrailingData;
    while (reader.position % 8 != 0) if (try reader.read(1) != 0) return error.NonzeroPadding;
    return result;
}

test "Deflate64 test wire canonical dynamic header handles all repeat symbols and rejects overruns" {
    // Independently hand-packed canonical header: literal A..H lengths four,
    // EOB length one, one-bit distance0, full32-distance declaration. CL17/18
    // lengths two; CL0/1/4/16 lengths three. Only literal A and EOB are data.
    const valid = [_]u8{ 0x05, 0xdf, 0x27, 0x0d, 0x00, 0x00, 0x0c, 0x00, 0x30, 0x6d, 0xfb, 0xf3, 0x2f, 0x86, 0xb7, 0x2a, 0x78, 0x00 };
    var parsed = try inspect(&valid, 1);
    defer parsed.deinit();
    try std.testing.expectEqualStrings("A", parsed.output);
    try std.testing.expectEqual(@as(usize, 1), parsed.dynamic_blocks);
    const header = parsed.blocks.items[0].header.?;
    try std.testing.expectEqual(@as(usize, 257), header.literal_symbols);
    try std.testing.expectEqual(@as(usize, 32), header.distance_symbols);
    try std.testing.expectEqual(@as(usize, 18), header.code_length_symbols);
    try std.testing.expectEqual(@as(usize, 1), header.repeat_16);
    try std.testing.expectEqual(@as(usize, 2), header.repeat_17);
    try std.testing.expectEqual(@as(usize, 4), header.repeat_18);
    // Same canonical/RLE layout with one declared distance symbol is also
    // accepted by independent RFC1951 zlib; Deflate64's full32 alphabet above
    // is separately required by this format's wire contract.
    const distance_one = [_]u8{ 0x05, 0xc0, 0x27, 0x0d, 0x00, 0x00, 0x0c, 0x00, 0x30, 0x6d, 0xfb, 0xf3, 0x2f, 0x86, 0xb7, 0x01 };
    var one = try inspect(&distance_one, 1);
    defer one.deinit();
    try std.testing.expectEqualStrings("A", one.output);
    try std.testing.expectEqual(@as(usize, 1), one.blocks.items[0].header.?.distance_symbols);
    const first_repeat = [_]u8{ 0x05, 0xdf, 0x27, 0x0d, 0x00, 0x00, 0x0c, 0x00, 0xb0, 0x03 };
    try std.testing.expectError(error.InvalidDynamicBlockHeader, inspect(&first_repeat, 1));
    const overrun = [_]u8{ 0x05, 0xdf, 0x27, 0x0d, 0x00, 0x00, 0x0c, 0x00, 0x30, 0xff, 0xfe, 0xfd, 0x03 };
    try std.testing.expectError(error.InvalidDynamicBlockHeader, inspect(&overrun, 1));
    try std.testing.expectError(error.TruncatedFrame, inspect(valid[0 .. valid.len - 1], 1));
    try std.testing.expectError(error.OutputTooSmall, inspect(&valid, 0));
}

test "Deflate64 test wire rejects incomplete multiple symbol trees and preserves legal singleton policy" {
    // CL0=0, CL1=10, CL2=11 form a complete canonical header alphabet.
    // First wire declares literal A and EOB with two-bit lengths (undersub).
    const literal_tree = [_]u8{ 0x05, 0xc0, 0x01, 0x04, 0x00, 0x00, 0x00, 0x80, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07 };
    try std.testing.expectError(error.InvalidHuffmanCode, inspect(&literal_tree, 1));
    // Second wire has a complete one-bit A/EOB tree, but two distance symbols
    // both have length two, leaving half of the distance code space unused.
    const distance_tree = [_]u8{ 0x05, 0xc1, 0x01, 0x04, 0x00, 0x00, 0x00, 0x80, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3d };
    try std.testing.expectError(error.InvalidHuffmanCode, inspect(&distance_tree, 1));
    // Two two-bit CL codes leave half their space unused. This must fail
    // before any literal/distance length operation is admitted.
    const code_length_tree = [_]u8{ 0x05, 0x00, 0x24, 0x00 };
    try std.testing.expectError(error.InvalidHuffmanCode, inspect(&code_length_tree, 0));
    _ = try Canonical.init(&.{1}, 15, false, false);
    _ = try Canonical.init(&.{0}, 15, true, false);
    try std.testing.expectError(error.InvalidHuffmanCode, Canonical.init(&.{2}, 15, false, false));
    try std.testing.expectError(error.InvalidHuffmanCode, Canonical.init(&.{1}, 7, false, true));
}

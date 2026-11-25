const std = @import("std");
const bitstream = @import("../../bitstream.zig");
const huffman = @import("../../huffman.zig");
const a = std.testing.allocator;

pub const Mode = enum { empty_distance, incomplete, incomplete_codes, singleton_eob, max_counts, match, empty_distance_use, empty_codes, empty_literal };
pub const Fixture = struct {
    raw: []u8,
    puff: []u8,
    exact_bits: u64,
    offset: u3,
    pub fn deinit(self: *Fixture) void {
        a.free(self.raw);
        a.free(self.puff);
    }
};

fn appendMetadata(output: *std.ArrayList(u8), metadata: []const u8) !void {
    var length: [2]u8 = undefined;
    std.mem.writeInt(u16, &length, @intCast(metadata.len - 1), .big);
    try output.appendSlice(a, &length);
    try output.appendSlice(a, metadata);
}

pub fn make(comptime mode: Mode, offset: u3) !Fixture {
    var literal: [286]u4 = @splat(0);
    literal['A'] = 1;
    literal[256] = 1;
    var distance: [30]u4 = @splat(0);
    var codes: [19]u4 = @splat(0);
    @memset(codes[0..16], 4);
    const hlit: usize = if (mode == .match or mode == .empty_distance_use) 258 else if (mode == .max_counts) 286 else 257;
    const hdist: usize = if (mode == .max_counts) 30 else 1;
    const hclen: usize = if (mode == .empty_codes) 4 else 19;
    switch (mode) {
        .incomplete_codes => @memset(codes[0..16], 5),
        .incomplete => {
            literal['A'] = 2;
            literal[256] = 2;
            distance[0] = 2;
        },
        .singleton_eob => {
            literal['A'] = 0;
            literal[256] = 7;
        },
        .match, .empty_distance_use => {
            literal = @splat(0);
            literal[256] = 1;
            literal[257] = 1;
            if (mode == .match) distance[0] = 1;
        },
        .empty_codes => codes = @splat(0),
        .empty_literal => literal = @splat(0),
        else => {},
    }
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(a);
    try writer.writeBits(a, 0, offset);
    const start = (@as(u64, @intCast(writer.bytes.items.len)) * 8 + writer.bit_index);
    try writer.writeBits(a, 5, 3);
    try writer.writeBits(a, @intCast(hlit - 257), 5);
    try writer.writeBits(a, @intCast(hdist - 1), 5);
    try writer.writeBits(a, @intCast(hclen - 4), 4);
    var metadata: std.ArrayList(u8) = .empty;
    defer metadata.deinit(a);
    try metadata.appendSlice(a, &.{ 0xc0, @intCast(hlit - 257), @intCast(hdist - 1), @intCast(hclen - 4) });
    for (0..hclen) |i| {
        const width = codes[huffman.code_length_order[i]];
        try writer.writeBits(a, width, 3);
        if (i % 2 == 0) try metadata.append(a, @as(u8, width) << 4) else metadata.items[metadata.items.len - 1] |= width;
    }
    if (mode != .empty_codes) {
        const code_encoder = try huffman.CodeLengthTable.Encoder.init(&codes);
        for (literal[0..hlit]) |width| {
            try code_encoder.writeSymbol(&writer, a, width);
            try metadata.append(a, width);
        }
        for (distance[0..hdist]) |width| {
            try code_encoder.writeSymbol(&writer, a, width);
            try metadata.append(a, width);
        }
    }
    var puff: std.ArrayList(u8) = .empty;
    errdefer puff.deinit(a);
    try appendMetadata(&puff, metadata.items);
    if (mode != .empty_literal and mode != .empty_codes) {
        const literal_encoder = try huffman.HuffmanTable(286).Encoder.init(literal[0..hlit]);
        if (mode == .match or mode == .empty_distance_use) {
            try literal_encoder.writeSymbol(&writer, a, 257);
            if (mode == .match) {
                const distance_encoder = try huffman.HuffmanTable(30).Encoder.init(distance[0..hdist]);
                try distance_encoder.writeSymbol(&writer, a, 0);
            }
            try puff.appendSlice(a, &.{ 0x80, 0, 0 }); // length 3, distance 1
        } else if (mode != .singleton_eob) {
            try literal_encoder.writeSymbol(&writer, a, 'A');
            try puff.appendSlice(a, &.{ 0, 'A' });
        }
        try literal_encoder.writeSymbol(&writer, a, 256);
    }
    try puff.appendSlice(a, &.{ 0xff, 0x81 });
    const exact_bits = (@as(u64, @intCast(writer.bytes.items.len)) * 8 + writer.bit_index) - start;
    return .{ .raw = try writer.toOwnedSlice(a), .puff = try puff.toOwnedSlice(a), .exact_bits = exact_bits, .offset = offset };
}

pub fn invalidFields(hlit: u8, hdist: u8, hclen: u8) ![]u8 {
    // A metadata-only dynamic block, padded with end token; invalid counts
    // must be rejected before any table/vector access in huff direction.
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(a);
    try appendMetadata(&output, &.{ 0xc0, hlit, hdist, hclen, 0, 0 });
    try output.appendSlice(a, &.{ 0xff, 0x81 });
    return output.toOwnedSlice(a);
}

pub fn rawInvalidFields(hlit: u8, hdist: u8) ![]u8 {
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(a);
    try writer.writeBits(a, 5, 3);
    try writer.writeBits(a, hlit, 5);
    try writer.writeBits(a, hdist, 5);
    try writer.writeBits(a, 0, 4);
    return writer.toOwnedSlice(a);
}

pub fn rawRepeatOverrun() ![]u8 {
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(a);
    try writer.writeBits(a, 5, 3);
    try writer.writeBits(a, 29, 5);
    try writer.writeBits(a, 29, 5);
    try writer.writeBits(a, 0, 4);
    // Assigned singleton CODES18 is a structural Puffin alphabet. The
    // overrun must fail at the vector span, without an inflate completeness
    // policy masking the 138+138+41 > 316 witness.
    inline for (.{ 0, 0, 1, 0 }) |width| try writer.writeBits(a, width, 3);
    inline for (.{ 127, 127, 30 }) |extra| {
        try writer.writeBits(a, 0, 1);
        try writer.writeBits(a, extra, 7);
    }
    return writer.toOwnedSlice(a);
}

pub fn puffRepeatOverrun() ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(a);
    try appendMetadata(&output, &.{ 0xc0, 29, 29, 0, 0, 0x10, 155, 155, 58 });
    try output.appendSlice(a, &.{ 0xff, 0x81 });
    return output.toOwnedSlice(a);
}

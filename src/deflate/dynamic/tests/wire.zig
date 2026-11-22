const std = @import("std");
const huffman = @import("../../../huffman.zig");
const bitstream = @import("../../../bitstream.zig");
const checksum = @import("../../../checksum.zig");
pub const Kind = enum {
    complete,
    deflate64_distance32,
    empty_distance,
    singleton_distance,
    singleton_literal,
    dictionary_match,
    incomplete_codes,
    incomplete_literal,
    long_literal_singleton,
    incomplete_distance,
    long_distance_singleton,
    oversubscribed_codes,
    oversubscribed_literal,
    oversubscribed_distance,
    missing_eob,
    empty_distance_match,
};
pub fn make(kind: Kind) ![]u8 {
    const a = std.testing.allocator;
    var literals: [286]u4 = @splat(0);
    literals['A'] = 1;
    literals[256] = 1;
    var distances: [32]u4 = @splat(0);
    distances[0] = 1;
    distances[1] = 1;
    var codes: [19]u4 = @splat(0);
    @memset(codes[0..16], 4);
    switch (kind) {
        .empty_distance => distances = @splat(0),
        .singleton_distance => distances[1] = 0,
        .singleton_literal => {
            literals['A'] = 0;
            distances = @splat(0);
        },
        .dictionary_match, .empty_distance_match => {
            literals = @splat(0);
            literals[256] = 1;
            literals[257] = 1;
            distances = @splat(0);
            if (kind == .dictionary_match) distances[0] = 1;
        },
        .incomplete_codes => codes[15] = 0,
        .incomplete_literal => {
            literals['A'] = 2;
            literals[256] = 2;
        },
        .long_literal_singleton => {
            literals['A'] = 0;
            literals[256] = 7;
        },
        .incomplete_distance => distances[1] = 3,
        .long_distance_singleton => {
            distances[0] = 7;
            distances[1] = 0;
        },
        .oversubscribed_codes => {
            codes = @splat(0);
            codes[0] = 1;
            codes[1] = 1;
            codes[2] = 1;
        },
        .oversubscribed_literal => literals['B'] = 1,
        .oversubscribed_distance => distances[2] = 1,
        .missing_eob => {
            literals[256] = 0;
            literals['B'] = 1;
        },
        .deflate64_distance32 => distances = @splat(5),
        .complete => {},
    }
    var hlit: usize = 257;
    for (literals, 0..) |width, i| if (width != 0) {
        hlit = @max(hlit, i + 1);
    };
    var hdist: usize = 1;
    for (distances, 0..) |width, i| if (width != 0) {
        hdist = @max(hdist, i + 1);
    };
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(a);
    try writer.writeBits(a, 1, 1);
    try writer.writeBits(a, 2, 2);
    try writer.writeBits(a, @intCast(hlit - 257), 5);
    try writer.writeBits(a, @intCast(hdist - 1), 5);
    try writer.writeBits(a, 15, 4);
    for (huffman.code_length_order) |symbol| try writer.writeBits(a, codes[symbol], 3);
    if (kind != .oversubscribed_codes) {
        const encoder = try huffman.CodeLengthTable.Encoder.init(&codes);
        for (literals[0..hlit]) |width| try encoder.writeSymbol(&writer, a, width);
        for (distances[0..hdist]) |width| try encoder.writeSymbol(&writer, a, width);
        if (kind != .oversubscribed_literal and kind != .missing_eob) {
            const lit = try huffman.HuffmanTable(286).Encoder.init(literals[0..hlit]);
            if (kind == .dictionary_match or kind == .empty_distance_match) {
                try lit.writeSymbol(&writer, a, 257);
                if (kind == .dictionary_match) {
                    const dist = try huffman.HuffmanTable(32).Encoder.init(distances[0..hdist]);
                    try dist.writeSymbol(&writer, a, 0);
                } else try writer.writeBits(a, 0, 15);
            } else if (kind != .singleton_literal and kind != .long_literal_singleton)
                try lit.writeSymbol(&writer, a, 'A');
            try lit.writeSymbol(&writer, a, 256);
        }
    }
    return writer.toOwnedSlice(a);
}
pub const Wrapper = enum { zlib, gzip };
pub fn wrap(comptime wrapper: Wrapper, raw: []const u8, plain: []const u8, dictionary: []const u8) ![]u8 {
    const a = std.testing.allocator;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(a);
    if (wrapper == .zlib) {
        try output.appendSlice(a, if (dictionary.len == 0) &.{ 0x78, 0x01 } else &.{ 0x78, 0x20 });
        if (dictionary.len != 0) {
            var id: [4]u8 = undefined;
            std.mem.writeInt(u32, &id, checksum.Adler32.hash(dictionary), .big);
            try output.appendSlice(a, &id);
        }
    } else try output.appendSlice(a, &.{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3 });
    try output.appendSlice(a, raw);
    if (wrapper == .zlib) {
        var footer: [4]u8 = undefined;
        std.mem.writeInt(u32, &footer, checksum.Adler32.hash(plain), .big);
        try output.appendSlice(a, &footer);
    } else {
        var footer: [8]u8 = undefined;
        std.mem.writeInt(u32, footer[0..4], checksum.Crc32.hash(plain), .little);
        std.mem.writeInt(u32, footer[4..8], @intCast(plain.len), .little);
        try output.appendSlice(a, &footer);
    }
    return output.toOwnedSlice(a);
}

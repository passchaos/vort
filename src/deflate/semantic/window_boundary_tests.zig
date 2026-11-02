//! A long match following two literal pairs must pause before the match when
//! only the nominal match-sized output window is available.
const std = @import("std");
const bitstream = @import("../../bitstream.zig");
const huffman = @import("../../huffman.zig");
const vectors = @import("long_match_vectors.zig");
const checksum = @import("../../checksum.zig");
const png = @import("../../png.zig");

pub fn verify(comptime Decoder: type, comptime initialize: anytype, comptime checked_window: anytype, comptime ordinary_window: anytype, comptime specialized_window: anytype) !void {
    const allocator = std.testing.allocator;
    const expected = try vectors.expectedAlloc(allocator);
    defer allocator.free(expected);
    const reference = try allocator.alloc(u8, expected.len);
    defer allocator.free(reference);
    const active = try allocator.alloc(u8, expected.len);
    defer allocator.free(active);
    const literals = try huffman.HuffmanTable(286).init(&vectors.literal_lengths);
    const distances = try huffman.HuffmanTable(30).init(&vectors.distance_lengths);
    var decoder: Decoder = undefined;
    try std.testing.expect(initialize(&decoder, &literals, &distances));
    inline for (.{ ordinary_window, specialized_window }) |decode| {
        for (258..267) |room| {
            const end = vectors.history_len + room;
            @memset(reference, 0xa5);
            @memset(active, 0xa5);
            @memcpy(reference[0..vectors.history_len], expected[0..vectors.history_len]);
            @memcpy(active[0..vectors.history_len], expected[0..vectors.history_len]);
            var checked = bitstream.BufferedBitReader.init(&vectors.symbol_stream);
            var reader = bitstream.BufferedBitReader.init(&vectors.symbol_stream);
            const wanted = try checked_window(&checked, &decoder, reference[0..end], vectors.history_len);
            const actual = try decode(&reader, active[0..end], vectors.history_len, &decoder);
            try std.testing.expectEqual(wanted, actual);
            try std.testing.expectEqual(checked.bitPosition(), reader.bitPosition());
            try std.testing.expectEqualSlices(u8, reference[0..wanted.output_written], active[0..actual.output_written]);
            for (active[end..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
            const done = try decode(&reader, active, actual.output_written, &decoder);
            const checked_done = try checked_window(&checked, &decoder, reference, wanted.output_written);
            try std.testing.expectEqual(checked_done, done);
            try std.testing.expectEqual(expected.len, done.output_written);
            try std.testing.expectEqual(checked.bitPosition(), reader.bitPosition());
            try std.testing.expectEqualSlices(u8, expected, active);
        }
    }
}

pub fn verifyPng(comptime decode: anytype) !void {
    const allocator = std.testing.allocator;
    const history_len: usize = 8 * 32768 - 258;
    const expected_len = history_len + 524;
    const info = try png.pngImageInfo(6560, 10, 8, .truecolor_alpha);
    try std.testing.expectEqual(expected_len, info.zlib_payload_len);
    const expected = try allocator.alloc(u8, expected_len);
    defer allocator.free(expected);
    for (expected[0..history_len], 0..) |*byte, i| byte.* = @truncate(i * 19 + i / 17);
    for (0..info.height) |y| expected[y * (info.row_len + 1)] = 0;
    var pos: usize = history_len;
    for (0..2) |_| {
        @memcpy(expected[pos..][0..4], "ABAB");
        pos += 4;
        @memcpy(expected[pos..][0..257], expected[pos - 32768 ..][0..257]);
        pos += 257;
    }
    @memcpy(expected[pos..][0..2], "AB");
    const suffix = vectors.encoded[5 + vectors.history_len ..];
    var encoded = std.ArrayList(u8).empty;
    defer encoded.deinit(allocator);
    try encoded.appendSlice(allocator, &.{ 0x78, 0x9c });
    pos = 0;
    while (pos < history_len) {
        const count: u16 = @intCast(@min(history_len - pos, 65535));
        var header: [5]u8 = undefined;
        header[0] = 0; // non-final stored block
        std.mem.writeInt(u16, header[1..3], count, .little);
        std.mem.writeInt(u16, header[3..5], ~count, .little);
        try encoded.appendSlice(allocator, &header);
        try encoded.appendSlice(allocator, expected[pos..][0..count]);
        pos += count;
    }
    try encoded.appendSlice(allocator, suffix);
    var adler: [4]u8 = undefined;
    std.mem.writeInt(u32, &adler, checksum.Adler32.hash(expected), .big);
    try encoded.appendSlice(allocator, &adler);
    const history = try allocator.alloc(u8, 8 * 32768);
    defer allocator.free(history);
    const output = try allocator.alloc(u8, try png.pngImageOutputLen(info));
    defer allocator.free(output);
    const result = try decode(encoded.items, history, info, .{}, output);
    try std.testing.expectEqual(encoded.items.len, result.zlib_input_read);
    try std.testing.expectEqual(output.len, result.output_written);
    for (0..info.height) |y| {
        const start = y * (info.row_len + 1) + 1;
        try std.testing.expectEqualSlices(u8, expected[start..][0..info.row_len], output[y * info.row_len ..][0..info.row_len]);
    }
}

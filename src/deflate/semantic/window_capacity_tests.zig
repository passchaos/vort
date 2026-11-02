const std = @import("std");
const huffman = @import("../../huffman.zig");
const bits = @import("../../bitstream.zig");
const Semantic = @import("decoder.zig");
const a = std.testing.allocator;

fn symbol(writer: *bits.BitWriter, encoder: anytype, value: usize) !void {
    try writer.writeBits(a, encoder.codes[value], encoder.bits[value]);
}

pub fn packedCapacity() !void {
    var lengths: [286]u4 = @splat(0);
    lengths['A'] = 2;
    lengths['B'] = 2;
    lengths['C'] = 3;
    lengths[256] = 3;
    lengths[261] = 3;
    lengths[285] = 3;
    var distance_lengths: [30]u4 = @splat(0);
    distance_lengths[0] = 1;
    const literal = try huffman.HuffmanTable(286).init(&lengths);
    const distance = try huffman.HuffmanTable(30).init(&distance_lengths);
    const le = try huffman.HuffmanTable(286).Encoder.init(&lengths);
    const de = try huffman.HuffmanTable(30).Encoder.init(&distance_lengths);
    var decoder: Semantic.SemanticDynamicDecoder = undefined;
    try std.testing.expect(decoder.init(&literal, &distance));
    var writer: bits.BitWriter = .{};
    defer writer.deinit(a);
    try symbol(&writer, &le, 'A');
    try symbol(&writer, &le, 261);
    try symbol(&writer, &de, 0);
    for (0..32502) |_| try symbol(&writer, &le, 'A');
    for ("BCA") |v| try symbol(&writer, &le, v);
    const before_match = writer.bytes.items.len * 8 + writer.bit_index;
    try symbol(&writer, &le, 285);
    try symbol(&writer, &de, 0);
    for (0..64) |_| try symbol(&writer, &le, 'A');
    try symbol(&writer, &le, 256);
    try writer.alignToByte(a);
    try writer.bytes.appendSlice(a, &([_]u8{0} ** 16));
    var storage: [32768 + 64]u8 = @splat(0xa5);
    const output = storage[32..][0..32768];
    var reader = bits.BufferedBitReader.init(writer.bytes.items);
    const pause = try Semantic.decodeDynamicBlockIntoWindow(&reader, output, 0, &decoder);
    try std.testing.expectEqual(Semantic.LinearStatus.need_output, pause.status);
    try std.testing.expectEqual(@as(usize, 32513), pause.output_written);
    try std.testing.expectEqual(@as(@TypeOf(reader.consumed_bits), before_match), reader.consumed_bits);
    for (output[0..32510]) |v| try std.testing.expectEqual(@as(u8, 'A'), v);
    try std.testing.expectEqualSlices(u8, "BCA", output[32510..32513]);
    for (storage[0..32]) |v| try std.testing.expectEqual(@as(u8, 0xa5), v);
    for (storage[32768 + 32 ..]) |v| try std.testing.expectEqual(@as(u8, 0xa5), v);
    const complete = try a.alloc(u8, 32835);
    defer a.free(complete);
    @memcpy(complete[0..pause.output_written], output[0..pause.output_written]);
    const end = try Semantic.decodeDynamicBlockIntoWindow(&reader, complete, pause.output_written, &decoder);
    try std.testing.expectEqual(Semantic.LinearStatus.end_of_block, end.status);
    try std.testing.expectEqual(complete.len, end.output_written);
    for (complete[32513..]) |v| try std.testing.expectEqual(@as(u8, 'A'), v);
    var full_reader = bits.BufferedBitReader.init(writer.bytes.items);
    const full = try a.alloc(u8, complete.len);
    defer a.free(full);
    const n = try Semantic.decodeDynamicBlockIntoLinearMode(false, false, false, false, false, &full_reader, full, 0, &decoder);
    try std.testing.expectEqual(complete.len, n);
    try std.testing.expectEqualSlices(u8, full, complete);
    try std.testing.expectEqual(full_reader.consumed_bits, reader.consumed_bits);
}

pub fn longToken() !void {
    var lengths: [286]u4 = @splat(0);
    var next: usize = 0;
    for (1..15) |length| {
        const selected: usize = if (length == 5) 'A' else if (length == 6) 'B' else blk: {
            const value = next;
            next += 1;
            break :blk value;
        };
        lengths[selected] = @intCast(length);
    }
    lengths[256] = 15;
    lengths[284] = 15;
    var distance_lengths: [30]u4 = @splat(0);
    for (0..14) |i| distance_lengths[i] = @intCast(i + 1);
    distance_lengths[14] = 15;
    distance_lengths[29] = 15;
    const literal = try huffman.HuffmanTable(286).init(&lengths);
    const distance = try huffman.HuffmanTable(30).init(&distance_lengths);
    const le = try huffman.HuffmanTable(286).Encoder.init(&lengths);
    const de = try huffman.HuffmanTable(30).Encoder.init(&distance_lengths);
    var decoder: Semantic.SemanticDynamicDecoder = undefined;
    try std.testing.expect(decoder.init(&literal, &distance));
    var writer: bits.BitWriter = .{};
    defer writer.deinit(a);
    for ("ABAB") |v| try symbol(&writer, &le, v);
    try symbol(&writer, &le, 284);
    try writer.writeBits(a, 30, 5);
    try symbol(&writer, &de, 29);
    try writer.writeBits(a, 8191, 13);
    try symbol(&writer, &le, 256);
    try writer.alignToByte(a);
    try writer.bytes.appendSlice(a, &([_]u8{0} ** 16));
    const output = try a.alloc(u8, 32768 + 512);
    defer a.free(output);
    for (output[0..32768], 0..) |*v, i| v.* = @truncate(i * 17 + i / 251);
    // Four bytes of padding admit the fast loop, but a middle-token refill
    // consumes its last wide-load opportunity. The next refill must use the
    // bounded tail rather than reading eight bytes beyond this input slice.
    const body_len = writer.bytes.items.len - 16;
    for (0..17) |padding| {
        var reader = bits.BufferedBitReader.init(writer.bytes.items[0 .. body_len + padding]);
        const done = try Semantic.decodeDynamicBlockIntoWindow(&reader, output, 32768, &decoder);
        try std.testing.expectEqual(Semantic.LinearStatus.end_of_block, done.status);
        try std.testing.expectEqual(@as(usize, 32768 + 261), done.output_written);
        try std.testing.expectEqualSlices(u8, "ABAB", output[32768..32772]);
        try std.testing.expectEqualSlices(u8, output[4..261], output[32772 .. 32768 + 261]);
        var full_reader = bits.BufferedBitReader.init(writer.bytes.items[0 .. body_len + padding]);
        const count = try Semantic.decodeDynamicBlockIntoLinearMode(false, false, false, false, false, &full_reader, output, 32768, &decoder);
        try std.testing.expectEqual(done.output_written, count);
        try std.testing.expectEqualSlices(u8, output[4..261], output[32772 .. 32768 + 261]);
        try std.testing.expectEqual(reader.consumed_bits, full_reader.consumed_bits);
    }
}

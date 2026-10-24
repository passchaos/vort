const std = @import("std");
const tables = @import("tables.zig");
const frame_size = tables.frame_size;
const min_window_bits = tables.min_window_bits;
const max_window_bits = tables.max_window_bits;
const Model = @import("model.zig").Model;
const ArithmeticDecoder = @import("arithmetic.zig").Decoder;
const BitReader = @import("bit_stream.zig").Reader;
const MsbBitWriter = @import("bit_stream.zig").Writer;
const ArithmeticEncoder = @import("arithmetic.zig").Encoder;
const LiteralEncoder = @import("literal_encoder.zig").LiteralEncoder;
const Decoder = @import("decoder.zig").Decoder;
const decodeAlloc = @import("decoder.zig").decodeAlloc;

test "Quantum bit reader uses byte-order MSB-first bits" {
    var reader = BitReader{ .input = &.{ 0x12, 0x34, 0xab } };
    try std.testing.expectEqual(@as(u32, 1), try reader.readBits(4));
    try std.testing.expectEqual(@as(u32, 0x234), try reader.readBits(12));
    try std.testing.expectEqual(@as(u32, 0xab), try reader.readBits(8));
}

test "Quantum rejects unsupported window sizes and truncated input" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.UnsupportedCabinetFeature,
        decodeAlloc(allocator, &.{}, 1, 9),
    );
    try std.testing.expectError(
        error.UnsupportedCabinetFeature,
        decodeAlloc(allocator, &.{}, 1, 22),
    );
    try std.testing.expectError(error.TruncatedFrame, decodeAlloc(allocator, &.{}, 1, 15));
}

test "Quantum decodes the libmspack fixed-match stream" {
    const compressed = [_]u8{
        0xd6, 0x06, 0x69, 0x0b, 0xcb, 0x47, 0xf0, 0x2c, 0x2a, 0x3a,
        0x8f, 0x2c, 0xab, 0xbb, 0x3c, 0xb9, 0x33, 0x01, 0x8b, 0xd8,
        0x58, 0x4b, 0x7b, 0x01, 0xba, 0x6f, 0x6d, 0x51, 0x6e, 0x3a,
        0xc3, 0x67, 0x42, 0x4b, 0xeb, 0x02, 0x36, 0x43, 0xd6, 0x66,
        0x56, 0xca, 0x9e, 0x72, 0xcc, 0x30, 0x00, 0x00, 0xff,
    };
    var output: [59]u8 = undefined;
    var decoder = Decoder.init(&compressed, &output, 18);
    try decoder.decode();
    try std.testing.expectEqualStrings(
        "If you can read this, the Quantum decompressor is working!\n",
        &output,
    );
}

test "Quantum decodes fixed and variable match selectors" {
    const allocator = std.testing.allocator;
    var writer = MsbBitWriter{};
    defer writer.bytes.deinit(allocator);
    var encoder = ArithmeticEncoder{ .writer = &writer };
    var selector_model = Model.init(0, 7);
    var literal_models = [4]Model{
        Model.init(0, 64),
        Model.init(64, 64),
        Model.init(128, 64),
        Model.init(192, 64),
    };
    var match3_model = Model.init(0, 24);
    var match4_model = Model.init(0, 36);
    var match_model = Model.init(0, 36);
    var length_model = Model.init(0, 27);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);

    encoder.startFrame();
    for ("abcdefgh") |byte| {
        const selector = byte >> 6;
        try encoder.encodeSymbol(allocator, &selector_model, selector);
        try encoder.encodeSymbol(allocator, &literal_models[selector], byte);
        try expected.append(allocator, byte);
    }

    try encoder.encodeSymbol(allocator, &selector_model, 4);
    try encoder.encodeSymbol(allocator, &match3_model, 0);
    try testAppendMatch(allocator, &expected, 1, 3);

    try encoder.encodeSymbol(allocator, &selector_model, 5);
    try encoder.encodeSymbol(allocator, &match4_model, 3);
    try testAppendMatch(allocator, &expected, 4, 4);

    try encoder.encodeSymbol(allocator, &selector_model, 6);
    try encoder.encodeSymbol(allocator, &length_model, 5);
    try encoder.encodeSymbol(allocator, &match_model, 3);
    try testAppendMatch(allocator, &expected, 4, 10);

    try encoder.finishFrame(allocator);
    try writer.alignToByte(allocator);
    try writer.bytes.appendNTimes(allocator, 0, 4);
    const decoded = try decodeAlloc(allocator, writer.bytes.items, expected.items.len, 18);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected.items, decoded);
}

test "Quantum retains adaptive models across frames for all window sizes" {
    const allocator = std.testing.allocator;
    const expected = try allocator.alloc(u8, frame_size + 257);
    defer allocator.free(expected);
    for (expected, 0..) |*byte, index| byte.* = @truncate(index *% 73 +% index / 11);

    var encoder = LiteralEncoder.init();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var offset: usize = 0;
    var first_trailer_offset: ?usize = null;
    while (offset < expected.len) {
        const end = @min(expected.len, offset + frame_size);
        const frame = try encoder.encodeFrameAlloc(allocator, expected[offset..end]);
        defer allocator.free(frame);
        try encoded.appendSlice(allocator, frame);
        if (first_trailer_offset == null) first_trailer_offset = encoded.items.len;
        try encoded.append(allocator, 0xff);
        offset = end;
    }
    for (min_window_bits..max_window_bits + 1) |window_bits| {
        const decoded = try decodeAlloc(
            allocator,
            encoded.items,
            expected.len,
            @intCast(window_bits),
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, expected, decoded);
    }

    encoded.items[first_trailer_offset.?] = 0xfe;
    try std.testing.expectError(
        error.InvalidQuantumStream,
        decodeAlloc(allocator, encoded.items, expected.len, 18),
    );
}

fn testAppendMatch(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    offset: usize,
    len: usize,
) !void {
    for (0..len) |_|
        try output.append(allocator, output.items[output.items.len - offset]);
}

test "Quantum literal allocation errors preserve reusable adaptive models" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, literalFailure, .{});
}

fn literalFailure(allocator: std.mem.Allocator) !void {
    var encoder = LiteralEncoder.init();
    const before = encoder;
    const bytes = encoder.encodeFrameAlloc(allocator, "Quantum reference recovery\n" ** 100) catch |err| {
        try std.testing.expectEqualDeep(before, encoder);
        return err;
    };
    defer allocator.free(bytes);
}

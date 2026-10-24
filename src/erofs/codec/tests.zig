const std = @import("std");
const codec = @import("../codec.zig");
const fixture = @import("../reader/tests/partial_helpers.zig");
const deflate = @import("../../deflate.zig");
const lzma = @import("../../lzma.zig");

test "EROFS prefix codecs match complete decoding across literal match and EOF boundaries" {
    const allocator = std.testing.allocator;
    for (fixture.algorithms, 0..) |algorithm, index| {
        var extent = try fixture.firstExtentAlloc(allocator, index);
        defer extent.deinit(allocator);
        for ([_]usize{ 0, 1, 2, 5, 17, 20, 33, 257, 258, 1000, 4095, 4096, extent.decoded.len }) |size| {
            const prefix = try codec.decodePrefixExtentAlloc(allocator, algorithm, extent.encoded, size, true);
            defer allocator.free(prefix);
            try std.testing.expectEqualSlices(u8, extent.decoded[0..size], prefix);
        }
    }
}

test "EROFS prefix codecs retain exact malformed header and required input errors" {
    const allocator = std.testing.allocator;
    for (fixture.algorithms) |algorithm| try std.testing.expectError(error.InvalidErofs, codec.decodePrefixExtentAlloc(allocator, algorithm, &.{ 0, 0 }, 1, true));
    try std.testing.expectError(error.InvalidDeflateBlockType, codec.decodePrefixExtentAlloc(allocator, .deflate, &.{6}, 1, false));
    try std.testing.expectError(error.InvalidMagic, codec.decodePrefixExtentAlloc(allocator, .zstandard, "invalid!", 1, false));
    try std.testing.expectError(error.InvalidLzmaHeader, codec.decodePrefixExtentAlloc(allocator, .lzma, &.{ 0x90, 0, 0, 0, 0 }, 1, false));
    try std.testing.expectError(error.InvalidMatch, codec.decodePrefixExtentAlloc(allocator, .lz4, &.{ 0x10, 'A', 0, 0 }, 2, false));
    try std.testing.expectError(error.TruncatedFrame, codec.decodePrefixExtentAlloc(allocator, .lz4, &.{ 0xf0, 255 }, 1, false));
    const inside_literal = try codec.decodePrefixExtentAlloc(allocator, .lz4, "\xf0\x00ABCDEFGHIJKLMNO", 1, false);
    defer allocator.free(inside_literal);
    try std.testing.expectEqualStrings("A", inside_literal);
    try std.testing.expectError(error.TruncatedFrame, codec.decodePrefixExtentAlloc(allocator, .lz4, &.{ 0xf0, 255, 0, 'A' }, 1, false));
    try std.testing.expectError(error.TruncatedFrame, codec.decodePrefixExtentAlloc(allocator, .lz4, &.{ 0xf0, 255, 0, 'A' }, 2, false));
}

test "EROFS prefix codecs release every allocation failure" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(work: std.mem.Allocator, index: usize, payload: []const u8, expected: []const u8) !void {
            const result = try codec.decodePrefixExtentAlloc(work, fixture.algorithms[index], payload, expected.len, true);
            defer work.free(result);
            try std.testing.expectEqualSlices(u8, expected, result);
        }
    };
    for (fixture.algorithms, 0..) |_, index| {
        var extent = try fixture.firstExtentAlloc(allocator, index);
        defer extent.deinit(allocator);
        try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ index, extent.encoded, extent.decoded[0..258] });
    }
}

test "EROFS Deflate prefix mode bounds large output slices and retains continuation" {
    const input = "\x01\x06\x00\xf9\xffABCDEFsuffix";
    var history: [32768]u8 = undefined;
    var decoder = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{ .max_output_len = 3, .stop_at_output_limit = true, .allow_trailing_data = true }, &history);
    var output: [64]u8 = @splat(0xa5);
    const first = try decoder.step(input, &output);
    try std.testing.expectEqual(@as(usize, 3), first.progress.output_written);
    try std.testing.expectEqualStrings("ABC", output[0..3]);
    try std.testing.expectEqual(@as(u8, 0xa5), output[3]);
    const stalled = try decoder.step(input[first.progress.input_read..], &output);
    try std.testing.expectEqual(@as(usize, 0), stalled.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), stalled.progress.output_written);
    decoder.options.max_output_len = 6;
    const second = try decoder.step(input[first.progress.input_read..], output[3..]);
    try std.testing.expectEqualStrings("ABCDEF", output[0..6]);
    try std.testing.expectEqual(@as(u8, 0xa5), output[6]);
    decoder.options.stop_at_output_limit = false;
    const final = try decoder.step(input[first.progress.input_read + second.progress.input_read ..], output[0..0]);
    try std.testing.expectEqual(.done, final.status);
    try decoder.finish();
    var strict = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{ .max_output_len = 3 }, &history);
    try std.testing.expectError(error.OutputLimitExceeded, strict.step(input, &output));
}

test "EROFS MicroLZMA prefix mode preserves default full-stream validation" {
    const allocator = std.testing.allocator;
    const image = try fixture.fixtureAlloc(allocator, 1);
    defer allocator.free(image);
    const payload = image[4096..8192];
    var offset: usize = 0;
    while (payload[offset] == 0) : (offset += 1) {}
    const prefix = try lzma.decodeMicroAllocWithOptions(allocator, payload[offset..], 1, .{ .allow_partial = true });
    defer allocator.free(prefix);
    try std.testing.expectEqualSlices(u8, &.{6}, prefix);
    try std.testing.expectError(error.InvalidLzmaStream, lzma.decodeMicroAllocWithOptions(allocator, payload[offset..], 1, .{}));
}

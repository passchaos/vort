const std = @import("std");
const decoder = @import("lzms/decoder.zig");
const tables = @import("lzms/tables.zig");

pub const Error = decoder.Error;
pub const Decoder = decoder.Decoder;
pub const maxBufferSize = tables.max_buffer_size;
pub const decodeInto = decoder.decodeInto;
pub const decodeAllocExactSize = decoder.decodeAllocExactSize;
pub const decodeAllocLimited = decoder.decodeAllocLimited;

test {
    _ = decoder;
    _ = tables;
}

test "LZMS rejects malformed raw blocks and output limits" {
    try std.testing.expectError(
        error.InvalidLzms,
        decodeAllocExactSize(std.testing.allocator, &.{ 0, 0, 0 }, 1),
    );
    try std.testing.expectError(
        error.InvalidLzms,
        decodeAllocExactSize(std.testing.allocator, &.{ 0, 0, 0, 0, 0 }, 1),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocLimited(std.testing.allocator, &.{}, 2, 1),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocExactSize(std.testing.allocator, &.{}, maxBufferSize + 1),
    );
    const empty = try decodeAllocExactSize(std.testing.allocator, &.{}, 0);
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
}

test "LZMS decodes pinned adaptive raw fixture" {
    const allocator = std.testing.allocator;
    const encoded_text = @embedFile("lzms/testdata/lzms-small.bin.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const encoded = try allocator.alloc(
        u8,
        base64.calcSizeUpperBound(encoded_text.len),
    );
    defer allocator.free(encoded);
    const encoded_len = try base64.decode(encoded, encoded_text);
    const expected = @embedFile("lzms/testdata/lzms-small.txt");
    const decoded = try decodeAllocExactSize(
        allocator,
        encoded[0..encoded_len],
        expected.len,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(expected, decoded);

    var reusable = try Decoder.init(allocator);
    defer reusable.deinit();
    @memset(decoded, 0);
    try reusable.decodeInto(encoded[0..encoded_len], decoded);
    try std.testing.expectEqualStrings(expected, decoded);
}

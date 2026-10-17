const std = @import("std");
const decoder = @import("lzms/decoder.zig");
const encoder = @import("lzms/encoder.zig");
const tables = @import("lzms/tables.zig");

pub const Error = decoder.Error || encoder.Error;
pub const Decoder = decoder.Decoder;
pub const maxBufferSize = tables.max_buffer_size;
pub const encodeAlloc = encoder.encodeAlloc;
pub const encodeAppend = encoder.encodeAppend;
pub const encodeInto = encoder.encodeInto;
pub const decodeInto = decoder.decodeInto;
pub const decodeAllocExactSize = decoder.decodeAllocExactSize;
pub const decodeAllocLimited = decoder.decodeAllocLimited;

test {
    _ = decoder;
    _ = encoder;
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

test "LZMS literal encoder compresses skewed input" {
    const allocator = std.testing.allocator;
    var input: [32 * 1024]u8 = undefined;
    const phrase = "LZMS adaptive literal reference encoder\n";
    for (&input, 0..) |*byte, index|
        byte.* = phrase[index % phrase.len];
    const encoded = try encodeAlloc(allocator, &input);
    defer allocator.free(encoded);
    try std.testing.expect(encoded.len < input.len);
    try std.testing.expect(encoded.len & 1 == 0);
    const decoded = try decodeAllocExactSize(allocator, encoded, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix");
    const appended_len = try encodeAppend(allocator, &appended, &input);
    try std.testing.expectEqual(encoded.len, appended_len);
    try std.testing.expectEqualStrings("prefix", appended.items[0..6]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items[6..]);

    const too_small = try allocator.alloc(u8, encoded.len - 1);
    defer allocator.free(too_small);
    @memset(too_small, 0xa5);
    try std.testing.expectError(
        error.OutputTooSmall,
        encodeInto(allocator, &input, too_small),
    );
    try std.testing.expect(std.mem.allEqual(u8, too_small, 0xa5));
    const into = try allocator.alloc(u8, encoded.len);
    defer allocator.free(into);
    const into_len = try encodeInto(allocator, &input, into);
    try std.testing.expectEqual(encoded.len, into_len);
    try std.testing.expectEqualSlices(u8, encoded, into);
}

test "LZMS literal encoder round trips high entropy input" {
    const allocator = std.testing.allocator;
    var input: [4096]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x4c5a_4d53);
    prng.random().bytes(&input);
    const encoded = try encodeAlloc(allocator, &input);
    defer allocator.free(encoded);
    const decoded = try decodeAllocExactSize(allocator, encoded, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "LZMS literal encoder round trips tiny inputs" {
    const allocator = std.testing.allocator;
    var input: [64]u8 = undefined;
    for (&input, 0..) |*byte, index|
        byte.* = @truncate(index * 73 + 19);
    for (0..input.len + 1) |len| {
        const encoded = try encodeAlloc(allocator, input[0..len]);
        defer allocator.free(encoded);
        try std.testing.expect(encoded.len & 1 == 0);
        const decoded = try decodeAllocExactSize(allocator, encoded, len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input[0..len], decoded);
    }
}

test "LZMS literal encoder is allocation failure safe" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const input = "LZMS allocation failure coverage\n" ** 64;
            const encoded = try encodeAlloc(allocator, input);
            defer allocator.free(encoded);
            const decoded = try decodeAllocExactSize(allocator, encoded, input.len);
            defer allocator.free(decoded);
            try std.testing.expectEqualStrings(input, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        AllocationTest.run,
        .{},
    );
}

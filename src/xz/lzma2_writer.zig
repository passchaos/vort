const std = @import("std");
const core = @import("../core.zig");

pub const max_uncompressed_chunk: usize = 65_536;

pub fn storedPayloadSize(input_len: usize) core.Error!usize {
    const chunk_count = if (input_len == 0) 0 else 1 + (input_len - 1) / max_uncompressed_chunk;
    const header_size = std.math.mul(usize, chunk_count, 3) catch return error.IntegerOverflow;
    const with_headers = std.math.add(usize, input_len, header_size) catch return error.IntegerOverflow;
    return std.math.add(usize, with_headers, 1) catch return error.IntegerOverflow;
}

/// Append a raw LZMA2 payload made of uncompressed chunks. The output is
/// transactional: allocation failure leaves `out.items` unchanged.
pub fn appendStoredPayload(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
) !usize {
    const encoded_size = try storedPayloadSize(input.len);
    try out.ensureUnusedCapacity(allocator, encoded_size);

    const start = out.items.len;
    var offset: usize = 0;
    while (offset < input.len) {
        const chunk_len = @min(max_uncompressed_chunk, input.len - offset);
        out.appendAssumeCapacity(if (offset == 0) 1 else 2);
        var size_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &size_bytes, @intCast(chunk_len - 1), .big);
        out.appendSliceAssumeCapacity(&size_bytes);
        out.appendSliceAssumeCapacity(input[offset..][0..chunk_len]);
        offset += chunk_len;
    }
    out.appendAssumeCapacity(0);
    std.debug.assert(out.items.len - start == encoded_size);
    return encoded_size;
}

test "raw LZMA2 stored payload splits chunks and terminates" {
    const input = try std.testing.allocator.alloc(u8, max_uncompressed_chunk + 1);
    defer std.testing.allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index);

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    const written = try appendStoredPayload(std.testing.allocator, &encoded, input);

    try std.testing.expectEqual(try storedPayloadSize(input.len), written);
    try std.testing.expectEqual(@as(u8, 1), encoded.items[0]);
    try std.testing.expectEqualSlices(u8, &.{ 0xff, 0xff }, encoded.items[1..3]);
    const second = 3 + max_uncompressed_chunk;
    try std.testing.expectEqual(@as(u8, 2), encoded.items[second]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, encoded.items[second + 1 ..][0..2]);
    try std.testing.expectEqual(@as(u8, 0), encoded.items[encoded.items.len - 1]);
}

test "raw LZMA2 empty stored payload is only an end marker" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), try appendStoredPayload(std.testing.allocator, &encoded, ""));
    try std.testing.expectEqualSlices(u8, &.{0}, encoded.items);
}

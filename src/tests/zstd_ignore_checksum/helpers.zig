const std = @import("std");
pub const memory = @import("../zstd_decode_memory/helpers.zig");
pub const wire = @import("../zstd_magicless_helpers.zig");
pub const a = std.testing.allocator;
pub const plain = "checksum opt-out keeps footer boundaries and safety constraints\n" ** 4;

pub fn corrupt(frame: []const u8) ![]u8 {
    const result = try a.dupe(u8, frame);
    result[result.len - 1] ^= 0x80;
    try std.testing.expectEqualSlices(u8, frame[0 .. frame.len - 4], result[0 .. result.len - 4]);
    return result;
}

pub fn join(first: []const u8, second: []const u8) ![]u8 {
    const result = try a.alloc(u8, first.len + second.len);
    @memcpy(result[0..first.len], first);
    @memcpy(result[first.len..], second);
    return result;
}

/// Empty chunks and a separate chunk per footer byte must not lose the suffix.
pub fn footerChunks(frame: []const u8) [7][]const u8 {
    const end = frame.len - 4;
    return .{ &.{}, frame[0..end], frame[end..][0..1], frame[end + 1 ..][0..1], &.{}, frame[end + 2 ..][0..1], frame[end + 3 ..] };
}

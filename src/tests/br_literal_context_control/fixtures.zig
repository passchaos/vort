const std = @import("std");

pub const text =
    "literal context control: {\"method\":\"update\",\"value\":12345}; " ++
    "abcdefghabcdefghXbcdefghYabcdefgh; dictionary compression context history.\n";
pub const repeated = text ** 24;
pub const dictionary_words = "compression dictionary international information transformation development";

pub fn heterogeneous(allocator: std.mem.Allocator) ![]u8 {
    const input = try allocator.alloc(u8, 8192);
    var random = std.Random.DefaultPrng.init(0xb947bd218);
    random.random().bytes(input);
    for (input, 0..) |*byte, i| byte.* = @as(u8, @intCast((i / 2048) * 64)) + (byte.* & 31);
    return input;
}

pub fn guards(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

//! Narrow the bounded lookup suffix, never the full 64-bit bit reservoir.
const std = @import("std");

pub inline fn suffix(bits: u64, comptime root_bits: u6, mask: usize) usize {
    return @intCast((bits >> root_bits) & @as(u64, mask));
}

test "deflate secondary lookup suffix discards high reservoir bits before narrowing" {
    const reservoirs = [_]u64{ 0, 0xffff_ffff_0000_0000, 0x1234_5678_9abc_def0, std.math.maxInt(u64) };
    inline for (.{ @as(u6, 8), @as(u6, 11) }) |root_bits| {
        for (reservoirs) |bits| {
            for ([_]usize{ 0, 1, 7, 15, 63, 255 }) |mask| {
                const expected: u32 = @intCast((bits >> root_bits) & @as(u64, mask));
                try std.testing.expectEqual(@as(usize, expected), suffix(bits, root_bits, mask));
            }
        }
    }
}

const std = @import("std");
const jumps = @import("../prefix_jumps.zig");

pub fn verify(comptime build: anytype) !void {
    var heads: std.ArrayList(u32) = .empty;
    defer heads.deinit(std.testing.allocator);
    var raw: std.ArrayList(u32) = .empty;
    defer raw.deinit(std.testing.allocator);
    var initialized: [512]u64 = undefined;
    var index = jumps.Index{};
    defer index.deinit(std.testing.allocator);
    const input = try std.testing.allocator.alloc(u8, 70018);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x199486fb;
    for (0..5) |kind| {
        for (input, 0..) |*byte, pos| {
            state = state *% 1664525 +% 1013904223;
            byte.* = switch (kind) {
                0 => 0,
                1 => @intCast(pos % 7),
                2 => if (pos % 31 < 25) 0 else @truncate(state >> 24),
                3 => if (pos >= 32773 and pos % 3 < 2) input[pos - 32773] else @truncate(state >> 24),
                else => @truncate(state >> 24),
            };
        }
        try build(std.testing.allocator, input, &heads, &raw, &initialized);
        if (kind == 0 or kind == 1) try std.testing.expect(jumps.useful(input, raw.items));
        if (kind == 4) try std.testing.expect(!jumps.useful(input, raw.items));
        try index.build(std.testing.allocator, input, raw.items);
        for ([_]usize{ 8, 9, 31, 32, 33, 257, 1024, 32767, 32768, 32769, 65535, 65536, 65537, input.len - 8 }) |pos| {
            var node = raw.items[pos];
            var raw_count: usize = 0;
            var prefix_count: usize = 0;
            while (node != std.math.maxInt(u32) and pos - @as(usize, node) <= 32768) {
                const candidate: usize = node;
                raw_count += 1;
                const equal = std.mem.eql(u8, input[candidate..][0..3], input[pos..][0..3]);
                if (equal) prefix_count += 1;
                try std.testing.expectEqual(raw_count, index.rawCount(pos, candidate));
                if (equal) try std.testing.expectEqual(prefix_count, index.prefixCount(pos, candidate));
                node = raw.items[candidate];
            }
        }
        const capacity = .{ index.raw_ranks.capacity, index.prefix_ranks.capacity };
        try index.build(std.testing.allocator, input[0..33], raw.items[0..33]);
        try std.testing.expectEqual(capacity, .{ index.raw_ranks.capacity, index.prefix_ranks.capacity });
        try std.testing.expectEqual(@as(usize, 4 * 33), index.bytes());
    }
}

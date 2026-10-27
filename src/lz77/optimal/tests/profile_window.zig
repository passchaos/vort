//! Standalone public profiling control: --dep lz77 -Mlz77=src/lz77.zig.
const std = @import("std");
const lz77 = @import("lz77");

test "optimal suffix profile retains tokens and every search diagnostic" {
    var input: [4097]u8 = undefined;
    for (0..3) |kind| {
        for (&input, 0..) |*byte, pos| byte.* = switch (kind) {
            0 => 0,
            1 => @intCast(pos % 7),
            else => if (pos % 97 < 89) 0 else @intCast(pos % 256),
        };
        const options: lz77.GreedyOptions = .{ .max_chain = 128, .max_candidates = 32 };
        var scratch: lz77.OptimalScratch = .{};
        defer scratch.deinit(std.testing.allocator);
        var full: lz77.OptimalSearchProfile = .{};
        var circular: lz77.OptimalSearchProfile = .{};
        const expected = try lz77.optimalPlanReuseProfiled(&scratch, std.testing.allocator, &input, options, std.testing.io, &full);
        const actual = try lz77.optimalPlanAllocProfiled(std.testing.allocator, &input, options, std.testing.io, &circular);
        defer actual.deinit(std.testing.allocator);
        try std.testing.expectEqual(expected, actual.stats);
        try std.testing.expectEqualSlices(lz77.Token, scratch.tokens.items, actual.tokens);
        inline for (@typeInfo(lz77.OptimalSearchProfile).@"struct".fields) |field| {
            if (comptime !std.mem.endsWith(u8, field.name, "_ns"))
                try std.testing.expectEqualDeep(@field(full, field.name), @field(circular, field.name));
        }
        try std.testing.expectEqual(@as(usize, input.len), circular.positions);
    }
}

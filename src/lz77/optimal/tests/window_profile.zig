//! Standalone public comparison through --dep lz77 -Mlz77=src/lz77.zig.
const std = @import("std");
const lz77 = @import("lz77");

test "optimal bounded index profile retains tokens and logical search diagnostics" {
    const input = try std.testing.allocator.alloc(u8, 256 * 1024 + 259);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x98351617;
    for (0..4) |kind| {
        for (input, 0..) |*byte, pos| {
            state = state *% 1664525 +% 1013904223;
            byte.* = switch (kind) {
                0 => 0,
                1 => @intCast(pos % 7),
                2 => if (pos % 97 < 89) 0 else @truncate(state >> 24),
                else => @truncate(state >> 24),
            };
        }
        for ([_]lz77.GreedyOptions{
            .{ .max_chain = 0 },
            .{ .max_chain = 16, .max_candidates = 8 },
            .{ .min_match = 5, .max_chain = 32, .max_candidates = 8 },
        }) |options| {
            var scratch: lz77.OptimalScratch = .{};
            defer scratch.deinit(std.testing.allocator);
            var full: lz77.OptimalSearchProfile = .{};
            var bounded: lz77.OptimalSearchProfile = .{};
            const before = try lz77.optimalPlanReuseProfiled(&scratch, std.testing.allocator, input, options, std.testing.io, &full);
            const after = try lz77.optimalPlanAllocProfiled(std.testing.allocator, input, options, std.testing.io, &bounded);
            defer after.deinit(std.testing.allocator);
            try std.testing.expectEqual(before, after.stats);
            try std.testing.expectEqualSlices(lz77.Token, scratch.tokens.items, after.tokens);
            inline for (@typeInfo(lz77.OptimalSearchProfile).@"struct".fields) |field| {
                if (comptime !std.mem.endsWith(u8, field.name, "_ns") and !std.mem.eql(u8, field.name, "index_bytes"))
                    try std.testing.expectEqualDeep(@field(full, field.name), @field(bounded, field.name));
            }
            try std.testing.expect(bounded.index_bytes < full.index_bytes);
        }
    }
}

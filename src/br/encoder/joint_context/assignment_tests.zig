//! Exact assignment tests independent of either candidate's dot-product kernel.
const std = @import("std");
const grouped = @import("assignment.zig");
const Histogram = @import("../histogram_model.zig").Histogram(256);
const Choice = struct { tree: usize, cost: u64 };

fn reference(counts: *const [256]u32, costs: []const [256]u16) Choice {
    var best: Choice = .{ .tree = 0, .cost = std.math.maxInt(u64) };
    for (0..costs.len) |tree| {
        var total: u64 = 0;
        for (0..256) |symbol| {
            const frequency = counts[symbol];
            // Zero frequencies need no price: inactive price cells may be undefined.
            if (frequency != 0) total +|= @as(u64, frequency) * costs[tree][symbol];
        }
        if (total < best.cost) best = .{ .tree = tree, .cost = total };
    }
    return best;
}

fn population(counts: *const [256]u32) u64 {
    var sum: u64 = 0;
    for (counts) |frequency| sum += frequency;
    return sum;
}

fn frequencies(profile: usize) [256]u32 {
    var counts: [256]u32 = @splat(0);
    var state: u32 = 0x9137abc1 +% @as(u32, @intCast(profile));
    for (&counts, 0..) |*frequency, symbol| {
        state = state *% 1664525 +% 1013904223;
        frequency.* = switch (profile) {
            0 => 0,
            1 => if (symbol == 255) std.math.maxInt(u32) else 0,
            2 => if (symbol % 17 == 0) state else 0,
            3 => state,
            4 => std.math.maxInt(u32),
            else => unreachable,
        };
    }
    return counts;
}

fn price(profile: usize, tree: usize, symbol: usize) u16 {
    if (profile == 4) return std.math.maxInt(u16);
    const mixed = (@as(u32, @intCast(tree)) *% 0x9e3779b9) ^
        (@as(u32, @intCast(symbol)) *% 0x85ebca6b) ^ @as(u32, @intCast(profile * 113));
    return @truncate(mixed ^ (mixed >> 13));
}

fn compare(counts: *const [256]u32, major: []const [256]u16, flat: []const u16, stride: usize) !void {
    const expected = reference(counts, major);
    const histogram: Histogram = .{ .counts = counts.*, .total = population(counts) };
    const four = grouped.chooseGrouped(&histogram, flat, major.len, stride);
    try std.testing.expectEqual(expected.tree, four.tree);
    try std.testing.expectEqual(expected.cost, four.cost);
    try std.testing.expectEqualSlices(u32, counts, &histogram.counts);
    try std.testing.expectEqual(population(counts), histogram.total);
}

test "joint assignment contract all tree counts supports strides extremes and inactive prices" {
    const major = try std.testing.allocator.alloc([256]u16, 256);
    defer std.testing.allocator.free(major);
    const storage = try std.testing.allocator.alloc(u16, 256 * 256 + 2);
    defer std.testing.allocator.free(storage);
    var comparisons: usize = 0;
    for (0..5) |profile| {
        const counts = frequencies(profile);
        for (1..257) |tree_count| {
            @memset(major, undefined);
            for (0..tree_count) |tree| {
                for (counts, 0..) |frequency, symbol| {
                    if (frequency != 0) major[tree][symbol] = price(profile, tree, symbol);
                }
            }
            for ([_]usize{ tree_count, 256 }) |stride| {
                const flat = storage[1 .. 1 + 256 * stride];
                @memset(flat, undefined);
                storage[0] = 0xc0de;
                storage[flat.len + 1] = 0xbeef;
                for (0..256) |symbol| {
                    if (counts[symbol] == 0) continue;
                    for (0..tree_count) |tree| flat[symbol * stride + tree] = major[tree][symbol];
                }
                errdefer std.debug.print("assignment profile={d} count={d} stride={d}\n", .{ profile, tree_count, stride });
                try compare(&counts, major[0..tree_count], flat, stride);
                try std.testing.expectEqual(@as(u16, 0xc0de), storage[0]);
                try std.testing.expectEqual(@as(u16, 0xbeef), storage[flat.len + 1]);
                for (0..tree_count) |tree| {
                    for (counts, 0..) |frequency, symbol| {
                        if (frequency == 0) continue;
                        try std.testing.expectEqual(price(profile, tree, symbol), major[tree][symbol]);
                        try std.testing.expectEqual(price(profile, tree, symbol), flat[symbol * stride + tree]);
                    }
                }
                comparisons += 1;
            }
        }
    }
    try std.testing.expectEqual(@as(usize, 2560), comparisons);
    std.debug.print("assignment scalar comparisons={d} supports=5 tree_counts=256 strides=count/256\n", .{comparisons});
}

test "joint assignment contract strict cross group tail ties and tail winners" {
    const major = try std.testing.allocator.alloc([256]u16, 256);
    defer std.testing.allocator.free(major);
    const storage = try std.testing.allocator.alloc(u16, 256 * 256 + 2);
    defer std.testing.allocator.free(storage);
    var counts: [256]u32 = @splat(0);
    counts[31] = std.math.maxInt(u32);
    for ([_]usize{ 1, 2, 3, 4, 5, 7, 8, 9, 63, 64, 65, 127, 128, 129, 255, 256 }) |tree_count| {
        const first = if (tree_count > 4) @as(usize, 3) else 0;
        for ([_]bool{ false, true }) |tail_wins| {
            @memset(major, undefined);
            for (major[0..tree_count]) |*row| row[31] = 20;
            major[first][31] = 7;
            major[tree_count - 1][31] = if (tail_wins) 5 else 7;
            const expected = reference(&counts, major[0..tree_count]);
            try std.testing.expectEqual(if (tail_wins) tree_count - 1 else first, expected.tree);
            for ([_]usize{ tree_count, 256 }) |stride| {
                const flat = storage[1 .. 1 + 256 * stride];
                @memset(flat, undefined);
                storage[0] = 0xc0de;
                storage[flat.len + 1] = 0xbeef;
                for (0..tree_count) |tree| flat[31 * stride + tree] = major[tree][31];
                try compare(&counts, major[0..tree_count], flat, stride);
                try std.testing.expectEqual(@as(u16, 0xc0de), storage[0]);
                try std.testing.expectEqual(@as(u16, 0xbeef), storage[flat.len + 1]);
            }
        }
    }
}

test "joint assignment contract prepare matches original model and leaves inactive columns unchanged" {
    const trees = try std.testing.allocator.alloc(Histogram, 256);
    defer std.testing.allocator.free(trees);
    const major = try std.testing.allocator.alloc([256]u16, 256);
    defer std.testing.allocator.free(major);
    const storage = try std.testing.allocator.alloc(u16, 256 * 256 + 2);
    defer std.testing.allocator.free(storage);
    for (trees, 0..) |*tree, index| {
        const counts = frequencies(index % 5);
        tree.* = .{ .counts = counts, .total = population(&counts) };
        const original: Histogram = .{ .counts = counts, .total = population(&counts) };
        major[index] = original.costModel().symbol_costs_q8;
    }
    const context = frequencies(3);
    var preparations: usize = 0;
    for ([_]usize{ 1, 2, 3, 4, 5, 63, 64, 65, 127, 128, 129, 255, 256 }) |tree_count| {
        for ([_]usize{ tree_count, 256 }) |stride| {
            const flat = storage[1 .. 1 + 256 * stride];
            @memset(flat, 0xa77a);
            storage[0] = 0xc0de;
            storage[flat.len + 1] = 0xbeef;
            grouped.prepare(trees[0..tree_count], flat, stride);
            for (0..256) |symbol| {
                for (0..stride) |tree| {
                    if (tree < tree_count) {
                        try std.testing.expectEqual(major[tree][symbol], flat[symbol * stride + tree]);
                    } else try std.testing.expectEqual(@as(u16, 0xa77a), flat[symbol * stride + tree]);
                }
            }
            for (trees[0..tree_count], 0..) |*tree, index| {
                const counts = frequencies(index % 5);
                try std.testing.expectEqualSlices(u32, &counts, &tree.counts);
                try std.testing.expectEqual(population(&counts), tree.total);
            }
            try compare(&context, major[0..tree_count], flat, stride);
            try std.testing.expectEqual(@as(u16, 0xc0de), storage[0]);
            try std.testing.expectEqual(@as(u16, 0xbeef), storage[flat.len + 1]);
            preparations += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 26), preparations);
    std.debug.print("assignment exact model preparations={d}\n", .{preparations});
}

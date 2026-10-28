//! Pick the existing prefix chain with the farthest newest predecessor.
const std = @import("std");
const access = @import("index_access.zig");

pub const Anchor = struct { offset: usize = 0, gap: usize = 0, predecessor: u32 = std.math.maxInt(u32) };

pub fn extend(prev: anytype, pos: usize, from: usize, through: usize, original: Anchor) Anchor {
    std.debug.assert(from <= through + 1 and pos + through < prev.len);
    var best_offset = original.offset;
    var best_gap = original.gap;
    for (from..through + 1) |offset| {
        const predecessor = access.at(prev, pos + offset);
        if (predecessor == std.math.maxInt(u32))
            return .{ .offset = offset, .gap = std.math.maxInt(usize), .predecessor = predecessor };
        const gap = pos + offset - predecessor;
        if (gap > best_gap) {
            best_offset = offset;
            best_gap = gap;
        }
    }
    // Only the final winner needs its predecessor. Carrying all three fields
    // through this inlined scan can spill the predecessor on every iteration.
    return .{ .offset = best_offset, .gap = best_gap, .predecessor = if (best_gap > original.gap) access.at(prev, pos + best_offset) else original.predecessor };
}

fn scalar(prev: []const u32, pos: usize, from: usize, through: usize, original: Anchor) Anchor {
    var best = original;
    for (from..through + 1) |offset| {
        const predecessor = prev[pos + offset];
        if (predecessor == std.math.maxInt(u32)) return .{ .offset = offset, .gap = std.math.maxInt(usize), .predecessor = predecessor };
        const gap = pos + offset - predecessor;
        if (gap > best.gap) best = .{ .offset = offset, .gap = gap, .predecessor = predecessor };
    }
    return best;
}

test "optimal rarest anchor final predecessor preserves original scalar fields and strict ties" {
    var prev: [544]u32 = undefined;
    for (&prev, 0..) |*value, pos| value.* = if (pos % 97 == 0) std.math.maxInt(u32) else @intCast(pos -| (pos % 53 + 1));
    for ([_]Anchor{ .{}, .{ .offset = 3, .gap = 19, .predecessor = 123 }, .{ .offset = 7, .gap = std.math.maxInt(usize), .predecessor = 9 } }) |original| {
        for (0..17) |from| for (from..259) |through| {
            try std.testing.expectEqual(scalar(&prev, 259, from, through, original), extend(&prev, 259, from, through, original));
        };
    }
}

test "optimal rarest anchor retains exact incremental choice and missing prefix boundaries" {
    var prev: [544]u32 = undefined;
    for (&prev, 0..) |*value, pos| value.* = @intCast(pos -| (1 + pos % 97));
    for (3..259) |length| {
        const direct = extend(&prev, 259, 0, length - 2, .{});
        var incremental = extend(&prev, 259, 0, 1, .{});
        incremental = extend(&prev, 259, 2, length - 2, incremental);
        try std.testing.expectEqual(direct, incremental);
        for (0..length - 1) |offset| try std.testing.expect(direct.gap >= 259 + offset - prev[259 + offset]);
    }
    prev[262] = std.math.maxInt(u32);
    const absent = extend(&prev, 259, 0, 7, .{});
    try std.testing.expectEqual(@as(usize, 3), absent.offset);
    try std.testing.expectEqual(std.math.maxInt(usize), absent.gap);
}

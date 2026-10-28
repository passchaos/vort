//! Standalone affine-address control: --dep index -Mindex=../window_index.zig.
const std = @import("std");
const index = @import("index");

fn unusedHash(_: []const u8, _: usize) ?usize {
    return null;
}

test "optimal read view preserves addresses across high coordinate wrap" {
    const View = index.Index(unusedHash).ReadView;
    var previous: [64]u32 = undefined;
    var raw: [64]u16 = undefined;
    var prefix: [64]u16 = undefined;
    for (&previous, &raw, &prefix, 0..) |*p, *r, *f, i| {
        p.* = @intCast(i * 7919);
        r.* = @truncate(65500 + i * 7);
        f.* = @truncate(65520 + i * 3);
    }
    for ([_]usize{ 0, 32767, 65536, 1 << 30, std.math.maxInt(usize) - 1024 }) |base| {
        const view: View = .{
            .previous_bias = @intFromPtr(&previous) -% (base *% @sizeOf(u32)),
            .raw_bias = @intFromPtr(&raw) -% (base *% @sizeOf(u16)),
            .prefix_bias = @intFromPtr(&prefix) -% (base *% @sizeOf(u16)),
            .base = base,
            .end = base + previous.len,
            .core = base,
            .len = base + previous.len,
        };
        for (0..previous.len) |position| {
            try std.testing.expectEqual(previous[position], view.get(base + position));
            for (0..position) |candidate| {
                try std.testing.expectEqual(@as(usize, raw[position] -% raw[candidate]), view.rawCount(base + position, base + candidate));
                try std.testing.expectEqual(@as(usize, prefix[position] -% prefix[candidate]), view.prefixCount(base + position, base + candidate));
            }
        }
    }
}

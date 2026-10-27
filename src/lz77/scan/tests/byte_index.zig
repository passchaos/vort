const std = @import("std");
const Index = @import("../byte_index.zig").Index;
const history = @import("../byte_index.zig").history_len;

fn compare(index: *const Index, input: []const u8, needle: u8, window: usize) !void {
    var iterator = index.candidates(needle, window);
    const start = input.len -| @min(window, history);
    var cursor = input.len;
    while (cursor > start) {
        cursor -= 1;
        if (input[cursor] == needle) try std.testing.expectEqual(@as(?usize, cursor), iterator.next());
    }
    try std.testing.expectEqual(@as(?usize, null), iterator.next());
}

test "bounded first-byte index preserves scalar anchor order across full history and wide positions" {
    const index = try std.testing.allocator.create(Index);
    defer std.testing.allocator.destroy(index);
    const data = try std.testing.allocator.alloc(u8, 3 * history + 257);
    defer std.testing.allocator.free(data);
    for (0..4) |kind| {
        index.* = .{};
        var state: u32 = 0x361f54a9;
        for (data, 0..) |*byte, pos| {
            state = state *% 1664525 +% 1013904223;
            byte.* = switch (kind) {
                0 => @truncate(state >> 24),
                1 => @intCast(pos % 7),
                2 => if (pos == 0 or pos == 2 * history + 7) 255 else 0,
                else => if (pos % 97 == 0) 255 else 0,
            };
            const inspect = pos < 65 or pos == history - 1 or pos == history or pos == history + 1 or
                pos == 2 * history - 1 or pos == 2 * history or pos == 2 * history + 1 or pos == 2 * history + 8 or pos == 3 * history;
            if (inspect) {
                for ([_]usize{ 0, 1, 31, 32, 33, 256, history - 1, history, history + 1 }) |window| {
                    for (0..256) |needle| try compare(index, data[0..pos], @intCast(needle), window);
                }
            }
            index.advance(data, pos + 1);
        }
        try std.testing.expectEqual(data.len, index.position);
    }
}

test "bounded first-byte index expires an anchor beyond one complete u16 position cycle" {
    const index = try std.testing.allocator.create(Index);
    defer std.testing.allocator.destroy(index);
    index.* = .{};
    var input: [70002]u8 = @splat(0);
    input[0] = 255;
    input[70001] = 255;
    index.advance(&input, 70001);
    var expired = index.candidates(255, history);
    try std.testing.expectEqual(@as(?usize, null), expired.next());
    index.advance(&input, input.len);
    var fresh = index.candidates(255, history);
    try std.testing.expectEqual(@as(?usize, 70001), fresh.next());
    try std.testing.expectEqual(@as(?usize, null), fresh.next());
    try std.testing.expect(@sizeOf(Index) <= 67 * 1024);
}

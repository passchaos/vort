const std = @import("std");
const index = @import("../../compression_index.zig");
const validation = @import("../index_validator.zig");

fn setPacked(data: []u8, item: usize, bits: usize, value: u32) void {
    for (0..bits) |i| {
        const bit = item * bits + i;
        const mask = @as(u8, 1) << @intCast(bit % 8);
        data[bit / 8] = (data[bit / 8] & ~mask) | (@as(u8, @truncate(value >> @intCast(i))) & 1) * mask;
    }
}

test "EROFS compact pack tails derive backtracking across heads counts and ordinary links" {
    for ([_]usize{ 8, 32 }) |size| {
        const count: usize = if (size == 8) 2 else 16;
        const bits = (size - 4) * 8 / count;
        const view = index.View{ .index_start = 0, .cluster_bits = 12, .advise = if (size == 32) 3 else 2, .block_size = 4096 };
        for ([_]u32{ 0x1000, 0x2803, 0x2007 }) |prior| {
            // The final lo is lookahead. Changing it does not change lookback.
            for ([_]u32{ 0, 1, 17, 0x7ff }) |lookahead| {
                var data: [32]u8 = @splat(0);
                setPacked(&data, count - 2, bits, prior);
                setPacked(&data, count - 1, bits, 0x2000 | lookahead);
                const record = try index.readCompact(&data, view, count - 1, count);
                const expected: usize = switch (prior) {
                    0x1000 => 1,
                    0x2803 => 2,
                    else => 8,
                };
                try std.testing.expectEqual(@as(?usize, expected), record.lookback);
                try std.testing.expectEqual(@as(?u32, null), record.compressed_blocks);
            }
        }
        var data: [32]u8 = @splat(0);
        setPacked(&data, count - 1, bits, 0x2803);
        const record = try index.readCompact(&data, view, count - 1, count);
        try std.testing.expectEqual(@as(?usize, 1), record.lookback);
        try std.testing.expectEqual(@as(?u32, 3), record.compressed_blocks);
    }
}

test "EROFS full and compact ordinary NONHEAD distances retain zero and overflow for validation" {
    const view = index.View{ .index_start = 0, .cluster_bits = 12, .advise = 2, .block_size = 4096 };
    for ([_]u16{ 0, 1, 7, 0x7ff, 0x800, 0x803 }) |delta| {
        var data: [8]u8 = @splat(0);
        std.mem.writeInt(u16, data[0..2], 2, .little);
        std.mem.writeInt(u16, data[4..6], delta, .little);
        const full = try index.readFull(&data, view, 0);
        @memset(&data, 0);
        setPacked(&data, 0, 16, 0x2000 | @as(u32, delta));
        const compact = try index.readCompact(&data, view, 0, 2);
        const expected: usize = if (delta & 0x800 != 0) 1 else delta;
        try std.testing.expectEqual(@as(?usize, expected), full.lookback);
        try std.testing.expectEqual(full.lookback, compact.lookback);
        try std.testing.expectEqual(full.compressed_blocks, compact.compressed_blocks);
    }
}

test "EROFS sequential index validation proves chains and resets the extent boundary" {
    const head = index.Index{ .kind = 1, .logical_offset = 0, .physical_block = 1 };
    const link = index.Index{ .kind = 2, .logical_offset = 0, .physical_block = 0, .lookback = 1 };
    var state = validation.Validator{ .cluster_size = 4096 };
    try std.testing.expectError(error.InvalidErofs, state.accept(0, link));
    try state.accept(0, head);
    var count = link;
    count.compressed_blocks = 3;
    try state.accept(1, count);
    try state.accept(2, link);
    var direct = link;
    direct.lookback = 3;
    try state.accept(3, direct);
    try state.accept(4, head);
    // A backward link into the previous extent cannot describe this head.
    try std.testing.expectError(error.InvalidErofs, state.accept(5, direct));
    try state.accept(5, link);
    try std.testing.expectError(error.InvalidErofs, state.accept(6, count));
    var zero = link;
    zero.lookback = 0;
    try std.testing.expectError(error.InvalidErofs, state.accept(6, zero));
    zero.lookback = null;
    try std.testing.expectError(error.InvalidErofs, state.accept(6, zero));
    var outside = head;
    outside.logical_offset = 4096;
    try std.testing.expectError(error.InvalidErofs, state.accept(6, outside));
    try std.testing.expectError(error.InvalidErofs, state.accept(7, head));
    try state.accept(6, link);
}

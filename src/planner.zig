const std = @import("std");

pub const Block = struct {
    input_offset: usize,
    input_len: usize,
    worker_index: usize,
};

pub const Options = struct {
    block_len: usize = 1 << 20,
    worker_count: usize = 1,
};

pub fn planBlocksAlloc(allocator: std.mem.Allocator, input_len: usize, options: Options) ![]Block {
    if (options.block_len == 0 or options.worker_count == 0) return error.InvalidBlockPlan;
    const count = if (input_len == 0) 0 else ((input_len - 1) / options.block_len) + 1;
    const blocks = try allocator.alloc(Block, count);
    errdefer allocator.free(blocks);
    for (blocks, 0..) |*block, i| {
        const offset = i * options.block_len;
        block.* = .{
            .input_offset = offset,
            .input_len = @min(options.block_len, input_len - offset),
            .worker_index = i % options.worker_count,
        };
    }
    return blocks;
}

test "block planner is deterministic and covers input" {
    const blocks = try planBlocksAlloc(std.testing.allocator, 10, .{ .block_len = 4, .worker_count = 2 });
    defer std.testing.allocator.free(blocks);
    try std.testing.expectEqual(@as(usize, 3), blocks.len);
    try std.testing.expectEqual(Block{ .input_offset = 0, .input_len = 4, .worker_index = 0 }, blocks[0]);
    try std.testing.expectEqual(Block{ .input_offset = 4, .input_len = 4, .worker_index = 1 }, blocks[1]);
    try std.testing.expectEqual(Block{ .input_offset = 8, .input_len = 2, .worker_index = 0 }, blocks[2]);
}

test "block planner rejects invalid options" {
    try std.testing.expectError(error.InvalidBlockPlan, planBlocksAlloc(std.testing.allocator, 10, .{ .block_len = 0 }));
    try std.testing.expectError(error.InvalidBlockPlan, planBlocksAlloc(std.testing.allocator, 10, .{ .worker_count = 0 }));
}

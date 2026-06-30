const std = @import("std");
const long_distance = @import("long_distance.zig");

pub const Block = struct {
    input_offset: usize,
    input_len: usize,
    worker_index: usize,
    ldm_candidates: usize = 0,
    ldm_longest: usize = 0,
    ldm_max_distance: usize = 0,
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

pub fn planBlocksWithLongDistanceAlloc(allocator: std.mem.Allocator, input: []const u8, options: Options, ldm_options: long_distance.Options) ![]Block {
    const blocks = try planBlocksAlloc(allocator, input.len, options);
    errdefer allocator.free(blocks);
    const candidates = try long_distance.findCandidatesAlloc(allocator, input, ldm_options);
    defer allocator.free(candidates);
    for (candidates) |candidate| {
        const block_i = findBlockForOffset(blocks, candidate.position) orelse continue;
        blocks[block_i].ldm_candidates += 1;
        blocks[block_i].ldm_longest = @max(blocks[block_i].ldm_longest, candidate.length);
        blocks[block_i].ldm_max_distance = @max(blocks[block_i].ldm_max_distance, candidate.distance);
    }
    return blocks;
}

fn findBlockForOffset(blocks: []const Block, offset: usize) ?usize {
    for (blocks, 0..) |block, i| {
        if (offset >= block.input_offset and offset < block.input_offset + block.input_len) return i;
    }
    return null;
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

test "long-distance-aware block planner annotates candidate blocks" {
    const prefix = "abcd" ** 9000;
    const input = prefix ++ "----" ++ prefix[0..64].*;
    const blocks = try planBlocksWithLongDistanceAlloc(std.testing.allocator, input, .{ .block_len = 8192, .worker_count = 2 }, .{ .min_distance = 32769, .min_length = 16 });
    defer std.testing.allocator.free(blocks);
    var annotated: usize = 0;
    for (blocks) |block| {
        if (block.ldm_candidates != 0) {
            annotated += 1;
            try std.testing.expect(block.ldm_longest >= 16);
            try std.testing.expect(block.ldm_max_distance >= 32769);
        }
    }
    try std.testing.expect(annotated > 0);
}

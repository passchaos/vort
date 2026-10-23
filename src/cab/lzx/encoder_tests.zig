const std = @import("std");
const encoder = @import("encoder.zig");
const decoder = @import("../lzx.zig");
const plan_mod = @import("block_plan.zig");
const tree = @import("encode_tree.zig");
const words = @import("word_writer.zig");
const reader = @import("bit_reader.zig");
const huffman = @import("huffman.zig");

test "LZX adaptive length headers reconstruct all deltas and run symbols" {
    const allocator = std.testing.allocator;
    var previous: [656]u5 = undefined;
    var next: [656]u5 = undefined;
    for (&previous, &next, 0..) |*before, *after, index| {
        before.* = @intCast(index % 17);
        after.* = if (index < 200) 0 else if (index < 450) 8 else @intCast((index * 7) % 17);
    }
    var writer = words.Writer{};
    defer writer.bytes.deinit(allocator);
    try tree.writeLengths(allocator, &writer, &previous, &next);
    try writer.finish(allocator);
    var input = reader.Reader{ .input = writer.bytes.items };
    var reconstructed = previous;
    try huffman.readLengths(&input, &reconstructed);
    try std.testing.expectEqualSlices(u5, &next, &reconstructed);
}

test "LZX greedy planner retains full lengths and every repeat rank" {
    const allocator = std.testing.allocator;
    const input = "repeat offset queue\n" ** 80;
    const offset = "repeat offset queue\n".len;
    for (0..3) |rank| {
        var reps: [3]u32 = .{ 1, 2, 3 };
        reps[rank] = offset;
        var plan = try plan_mod.Plan.init(allocator, input, offset, input.len, 15, reps);
        defer plan.deinit(allocator);
        try std.testing.expectEqual(@as(u16, 257), plan.items.items[0].len);
        try std.testing.expectEqual(rank, plan.items.items[0].slot);
        try std.testing.expect(plan.repeat_matches > 0);
        try std.testing.expect(plan.matched_bytes >= input.len - offset);
    }
    var reps: [3]u32 = .{ 11, 22, 33 };
    plan_mod.updateReps(&reps, 2, 33);
    try std.testing.expectEqual([3]u32{ 33, 22, 11 }, reps);
    plan_mod.updateReps(&reps, 1, 22);
    try std.testing.expectEqual([3]u32{ 22, 33, 11 }, reps);
    plan_mod.updateReps(&reps, 9, 700);
    try std.testing.expectEqual([3]u32{ 700, 22, 33 }, reps);
}

test "LZX CAB state survives compressed raw compressed block transitions" {
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, 3 * 32768 + 37);
    defer allocator.free(input);
    const phrase = "LZX long matches with recent offsets\n";
    for (input[0..32768], 0..) |*byte, index| byte.* = phrase[index % phrase.len];
    var random = std.Random.DefaultPrng.init(0x1cab);
    random.random().bytes(input[32768..65536]);
    @memcpy(input[65536..98304], input[0..32768]);
    @memcpy(input[98304..], input[0..37]);
    for (15..22) |bits| {
        var state = try encoder.CabinetEncoder.init(@intCast(bits));
        var stream: std.ArrayList(u8) = .empty;
        defer stream.deinit(allocator);
        var start: usize = 0;
        var block_index: usize = 0;
        while (start < input.len) : (block_index += 1) {
            const end = @min(input.len, start + 32768);
            var block = try state.encodeBlockWithSummaryAlloc(allocator, input, start, end);
            defer block.deinit(allocator);
            if (block_index == 1) try std.testing.expectEqual(encoder.BlockType.uncompressed, block.summary.block_type);
            if (block_index == 0 or block_index == 2) {
                try std.testing.expect(block.bytes.len < 1024);
                try std.testing.expect(block.summary.matched_bytes > 32000);
            }
            try stream.appendSlice(allocator, block.bytes);
            start = end;
        }
        const decoded = try decoder.decodeAlloc(allocator, stream.items, input.len, @intCast(bits));
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "LZX WIM full matches round trip tiny partial wide and E8 chunks" {
    const allocator = std.testing.allocator;
    for (15..22) |bits| {
        const limit = @as(usize, 1) << @intCast(bits);
        for ([_]usize{ 1, 2, 9, 257, 32768, @min(limit, 65536 + 37) }) |len| {
            const input = try allocator.alloc(u8, len);
            defer allocator.free(input);
            const phrase = "LZX e8 transform and arbitrary final sizes\n";
            for (input, 0..) |*byte, index| byte.* = phrase[index % phrase.len];
            if (len > 100) {
                input[64] = 0xe8;
                std.mem.writeInt(i32, input[65..69], 12000000 - 65, .little);
            }
            const encoded = try encoder.encodeWimChunkAlloc(allocator, input, @intCast(bits));
            defer allocator.free(encoded);
            const reference = try encoder.encodeWimReferenceChunkAlloc(allocator, input, @intCast(bits));
            defer allocator.free(reference);
            try std.testing.expect(encoded.len <= reference.len);
            if (len >= 32768) try std.testing.expect(encoded.len < 512);
            const decoded = try decoder.decodeAllocWithFormat(allocator, encoded, len, @intCast(bits), .wim);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, input, decoded);
        }
    }
}

test "LZX block allocation failures preserve state and clean all scratch" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationFailure, .{});
}

test "LZX aligned blocks encode biased low offset bits" {
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, 8192 + 512 * 24);
    defer allocator.free(input);
    var random = std.Random.DefaultPrng.init(0xa11eed);
    random.random().bytes(input[0..8192]);
    for (0..512) |row| {
        const source = ((row * 137) % 1020) * 8;
        @memcpy(input[8192 + row * 24 ..][0..24], input[source..][0..24]);
    }
    var state = try encoder.CabinetEncoder.init(15);
    var block = try state.encodeBlockWithSummaryAlloc(allocator, input, 0, input.len);
    defer block.deinit(allocator);
    try std.testing.expectEqual(encoder.BlockType.aligned, block.summary.block_type);
    try std.testing.expect(block.summary.matched_bytes >= 512 * 24);
    const decoded = try decoder.decodeAlloc(allocator, block.bytes, input.len, 15);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "LZX explicit offsets reach all window boundaries without expired history" {
    const allocator = std.testing.allocator;
    for (15..22) |bits| {
        const distance = (@as(usize, 1) << @intCast(bits)) - 3;
        const input = try allocator.alloc(u8, distance + 257);
        defer allocator.free(input);
        var random = std.Random.DefaultPrng.init(bits + 0xdead);
        random.random().bytes(input[0..distance]);
        @memcpy(input[distance..], input[0..257]);
        var plan = try plan_mod.Plan.init(allocator, input, distance, input.len, @intCast(bits), .{ 1, 1, 1 });
        defer plan.deinit(allocator);
        try std.testing.expectEqual(@as(u16, 257), plan.items.items[0].len);
        try std.testing.expectEqual(distance, plan.max_offset);
        var expired = try plan_mod.Plan.init(allocator, input, distance + 1, input.len, @intCast(bits), .{ 1, 1, 1 });
        defer expired.deinit(allocator);
        try std.testing.expect(expired.max_offset <= distance);
    }
}

test "LZX generated compressed streams reject every byte truncation" {
    const allocator = std.testing.allocator;
    const input = "LZX compressed stream truncation regression\n" ** 30;
    var state = try encoder.CabinetEncoder.init(15);
    const encoded = try state.encodeBlockAlloc(allocator, input, 0, input.len);
    defer allocator.free(encoded);
    for (0..encoded.len) |cut| {
        try std.testing.expectError(error.TruncatedFrame, decoder.decodeAlloc(allocator, encoded[0..cut], input.len, 15));
    }
}

test "LZX CAB block state rejects skipped input and continuation after a partial frame" {
    const allocator = std.testing.allocator;
    var state = try encoder.CabinetEncoder.init(15);
    try std.testing.expectError(error.InvalidBlockPlan, state.encodeBlockAlloc(allocator, "abcdef", 1, 6));
    const encoded = try state.encodeBlockAlloc(allocator, "abcdef", 0, 3);
    defer allocator.free(encoded);
    const before = state;
    try std.testing.expectError(error.InvalidBlockPlan, state.encodeBlockAlloc(allocator, "abcdef", 3, 6));
    try std.testing.expectEqualDeep(before, state);
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    var state = try encoder.CabinetEncoder.init(15);
    const before = state;
    var encoded = state.encodeBlockWithSummaryAlloc(allocator, "LZX allocation recovery\n" ** 50, 0, 1200) catch |err| {
        try std.testing.expectEqualDeep(before, state);
        return err;
    };
    defer encoded.deinit(allocator);
}

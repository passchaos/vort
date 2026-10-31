const std = @import("std");
const bt = @import("../bt_optimal.zig");
const frozen = @import("frozen.zig");
const lz77 = @import("../../lz77.zig");
const ref = @import("reference.zig");

test "bt frontier selected three byte records cover exact bounds and little endian bytes" {
    try std.testing.expectEqual(@as(usize, 3), @sizeOf(bt.Record));
    try std.testing.expectEqual(@as(usize, 1), @alignOf(bt.Record));
    try std.testing.expectEqualSlices(u8, &.{ 0xff, 0xff, 0x7f }, &bt.pack(258, 32768));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0 }, &bt.pack(3, 1));
    try std.testing.expectEqualSlices(u8, &.{ 1, 0x80, 0 }, &bt.pack(4, 2));
    for (3..259) |length| {
        for ([_]u16{ 1, 2, 4, 5, 255, 256, 257, 32767, 32768 }) |distance| {
            const record = bt.pack(@intCast(length), distance);
            try std.testing.expectEqualDeep(lz77.Token.Match{ .length = @intCast(length), .distance = distance }, bt.unpack(record));
            const word = frozen.pack(@intCast(length), distance);
            try std.testing.expectEqual(@as(u8, @truncate(word)), record[0]);
            try std.testing.expectEqual(@as(u8, @truncate(word >> 8)), record[1]);
            try std.testing.expectEqual(@as(u8, @truncate(word >> 16)), record[2]);
        }
    }
}

fn compareOwners(input: []const u8, options: lz77.GreedyOptions, model: lz77.OptimalCostModel) !void {
    var selected = try bt.Prepared.init(std.testing.allocator, input, options);
    defer selected.deinit(std.testing.allocator);
    var old = try frozen.Prepared.init(std.testing.allocator, input, options);
    defer old.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, old.counts, selected.counts);
    try std.testing.expectEqual(old.records.items.len, selected.records.items.len);
    for (old.records.items, selected.records.items) |word, record| try std.testing.expectEqualDeep(frozen.unpack(word), bt.unpack(record));
    const selected_fixed = try selected.planFixedAlloc(std.testing.allocator);
    defer selected_fixed.deinit(std.testing.allocator);
    const old_fixed = try old.planFixedAlloc(std.testing.allocator);
    defer old_fixed.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(lz77.Token, old_fixed.tokens, selected_fixed.tokens);
    try std.testing.expectEqualSlices(lz77.Token, old.steps, selected.steps);
    for (old.costs, selected.costs) |wide, narrow| try std.testing.expectEqual(wide, @as(usize, narrow));
    const selected_modeled = try selected.planModeledAlloc(std.testing.allocator, model);
    defer selected_modeled.deinit(std.testing.allocator);
    const old_modeled = try old.planModeledAlloc(std.testing.allocator, model);
    defer old_modeled.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(lz77.Token, old_modeled.tokens, selected_modeled.tokens);
    try std.testing.expectEqualSlices(lz77.Token, old.steps, selected.steps);
    for (old.costs, selected.costs) |wide, narrow| try std.testing.expectEqual(wide, @as(usize, narrow));
    const replay = try selected.planFixedAlloc(std.testing.allocator);
    defer replay.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(lz77.Token, old_fixed.tokens, replay.tokens);
}

test "bt frontier selected frozen covered graph all costs selected tokens and ties agree" {
    var input: [4096]u8 = undefined;
    ref.fill(&input, 0x714f5a03);
    var literal: [256]u16 = undefined;
    for (&literal, 0..) |*cost, byte| cost.* = @intCast(5 + byte % 19);
    var length: [259]u16 = @splat(1);
    for (3..259) |len| length[len] = @intCast(1 + len * 13 % 23);
    length[258] = 1;
    var distance: [32769]u16 = @splat(1);
    var start: usize = 1;
    for (bt.class_ends, 0..) |end, cls| {
        @memset(distance[start .. end + 1], @intCast(31 - cls));
        start = end + 1;
    }
    const model = lz77.OptimalCostModel{ .literal = &literal, .length = &length, .distance = &distance };
    for ([_]lz77.GreedyOptions{
        .{ .max_chain = 512, .max_candidates = 256 },
        .{ .max_chain = 3, .max_candidates = 2, .window_len = 511, .max_match = 29 },
        .{ .max_chain = 384, .max_candidates = 1, .min_match = 4 },
        .{ .max_chain = 0, .max_candidates = 0 },
        .{ .max_chain = 32, .min_match = 258, .max_match = 258 },
    }) |options| try compareOwners(&input, options, model);
    @memset(&input, 'a');
    try compareOwners(&input, .{}, model);
}

test "bt frontier selected maximum model finite suffix bound and literal endpoint" {
    const input = try std.testing.allocator.alloc(u8, 65536);
    defer std.testing.allocator.free(input);
    @memset(input, 'a');
    const literal: [256]u16 = @splat(65535);
    const length: [259]u16 = @splat(65535);
    const distance: [32769]u16 = @splat(65535);
    const model = lz77.OptimalCostModel{ .literal = &literal, .length = &length, .distance = &distance };
    try compareOwners(input, .{}, model);
    try compareOwners(input, .{ .max_chain = 0 }, model);
    var selected = try bt.Prepared.init(std.testing.allocator, input, .{ .max_chain = 0 });
    defer selected.deinit(std.testing.allocator);
    const plan = try selected.planModeledAlloc(std.testing.allocator, model);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u32, 4294901760), selected.costs[0]);
    try std.testing.expectEqual(@as(usize, 65536), plan.stats.literals);
    try std.testing.expectEqual(@as(u32, 4294836225), try std.math.add(u32, try std.math.mul(u32, 65536 - 3, 65535), 131070));
}

test "bt frontier selected owner recovers after result allocation failure" {
    const input = "abc" ** 1366;
    var selected = try bt.Prepared.init(std.testing.allocator, input, .{});
    defer selected.deinit(std.testing.allocator);
    const expected = try selected.planFixedAlloc(std.testing.allocator);
    defer expected.deinit(std.testing.allocator);
    var failure = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, selected.planFixedAlloc(failure.allocator()));
    const recovered = try selected.planFixedAlloc(std.testing.allocator);
    defer recovered.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(lz77.Token, expected.tokens, recovered.tokens);
    try ref.validatePlan(input, recovered);
}

test "bt frontier selected invalid model leaves owner reusable" {
    const input = "a" ** 4096;
    var selected = try bt.Prepared.init(std.testing.allocator, input, .{});
    defer selected.deinit(std.testing.allocator);
    var literal: [256]u16 = @splat(9);
    var length: [259]u16 = @splat(7);
    const distance: [32769]u16 = @splat(5);
    var model = lz77.OptimalCostModel{ .literal = &literal, .length = &length, .distance = distance[0..32768] };
    try std.testing.expectError(error.InvalidBlockPlan, selected.planModeledAlloc(std.testing.allocator, model));
    model.distance = &distance;
    literal[255] = 0;
    try std.testing.expectError(error.InvalidBlockPlan, selected.planModeledAlloc(std.testing.allocator, model));
    literal[255] = 9;
    length[258] = 0;
    try std.testing.expectError(error.InvalidBlockPlan, selected.planModeledAlloc(std.testing.allocator, model));
    length[258] = 7;
    const recovered = try selected.planModeledAlloc(std.testing.allocator, model);
    defer recovered.deinit(std.testing.allocator);
    try ref.validatePlan(input, recovered);
}

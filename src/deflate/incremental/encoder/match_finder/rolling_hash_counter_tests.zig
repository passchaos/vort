const std = @import("std");
const core = @import("../../../../core.zig");
const lz77 = @import("../../../../lz77.zig");
const hash = @import("hash.zig");
const Matcher = @import("rolling_hash.zig").Matcher;
const Count = core.StreamCount;

test "rolling matcher wide counters preserve native types and local indexes" {
    try std.testing.expect(@FieldType(Matcher, "head") == std.ArrayList(Count));
    try std.testing.expect(@FieldType(Matcher, "prev") == std.ArrayList(Count));
    try std.testing.expect(@FieldType(Matcher, "absolute_position") == Count);
    try std.testing.expect(@FieldType(Matcher, "indexed_positions") == Count);
    try std.testing.expect(@FieldType(Matcher.Snapshot, "absolute_position") == Count);
    try std.testing.expect(@FieldType(Matcher.Snapshot, "indexed_positions") == Count);
    try std.testing.expect(@FieldType(Matcher.Snapshot, "table_entries") == usize);
    try std.testing.expect(@FieldType(Matcher, "head_epoch") == std.ArrayList(u32));
    try std.testing.expect(@FieldType(Matcher, "epoch") == u32);
    if (@bitSizeOf(usize) == 64) {
        try std.testing.expect(Count == usize);
        try std.testing.expect(@FieldType(Matcher, "head") == std.ArrayList(usize));
        try std.testing.expect(@FieldType(Matcher, "prev") == std.ArrayList(usize));
    } else {
        try std.testing.expect(Count == u64);
    }
}

test "rolling matcher wide counters retain real chain nodes across four GiB" {
    const boundary: Count = @as(Count, 1) << 32;
    const repeated = "abcd" ** 16;
    const first = ("abcd" ** 15) ++ "abcX";
    for ([_]bool{ false, true }) |lazy| {
        var wide: Matcher = .{ .absolute_position = boundary - 8 };
        defer wide.deinit(std.testing.allocator);
        var local: Matcher = .{};
        defer local.deinit(std.testing.allocator);
        var wide_tokens: std.ArrayList(lz77.Token) = .empty;
        defer wide_tokens.deinit(std.testing.allocator);
        var local_tokens: std.ArrayList(lz77.Token) = .empty;
        defer local_tokens.deinit(std.testing.allocator);
        const options: lz77.GreedyOptions = .{ .nice_len = lz77.max_match_len };

        _ = try wide.plan(std.testing.allocator, &wide_tokens, first, repeated, options, lazy);
        _ = try local.plan(std.testing.allocator, &local_tokens, first, repeated, options, lazy);
        try std.testing.expectEqualDeep(local_tokens.items, wide_tokens.items);
        const head = wide.head.items[hash.block(repeated, 0, 3)];
        const previous = wide.prev.items[core.stream_count.ringIndex(head, lz77.default_window_len)];
        try std.testing.expect(head >= boundary);
        try std.testing.expect(previous < boundary);
        try std.testing.expect(previous >= boundary - repeated.len - 8);

        // The head above four GiB matches only "abc" before its X mismatch.
        // Follow its predecessor below four GiB to find the longer match.
        // Translating only the logical origin preserves the token choices.
        wide.indexed_positions = boundary - 2;
        const wide_plan = try wide.plan(std.testing.allocator, &wide_tokens, repeated, first, options, lazy);
        const local_plan = try local.plan(std.testing.allocator, &local_tokens, repeated, first, options, lazy);
        try std.testing.expectEqualDeep(local_plan.tokens, wide_plan.tokens);
        try std.testing.expectEqualDeep(local_plan.stats, wide_plan.stats);
        try std.testing.expectEqual(@as(u16, repeated.len - 1), wide_plan.tokens[0].match.length);
        try std.testing.expectEqual(@as(u16, repeated.len), wide_plan.tokens[0].match.distance);
        try std.testing.expect(wide.indexed_positions > boundary);
        try std.testing.expectEqual(boundary - 8 + 2 * repeated.len, wide.absolute_position);
    }
}

test "rolling matcher wide counters refuse overflow before token or index changes" {
    var matcher: Matcher = .{};
    defer matcher.deinit(std.testing.allocator);
    var tokens: std.ArrayList(lz77.Token) = .empty;
    defer tokens.deinit(std.testing.allocator);
    _ = try matcher.plan(std.testing.allocator, &tokens, "abcd", "", .{}, false);
    const prior_tokens = try std.testing.allocator.dupe(lz77.Token, tokens.items);
    defer std.testing.allocator.free(prior_tokens);
    const prior_stats = matcher.dynamic_stats;
    const prior_epoch = matcher.epoch;

    matcher.absolute_position = std.math.maxInt(Count) - 2;
    const prior = matcher.snapshot();
    try std.testing.expectError(error.IntegerOverflow, matcher.validateAdvance(3, 0));
    try std.testing.expectError(error.IntegerOverflow, matcher.plan(std.testing.allocator, &tokens, "abc", "", .{}, false));
    try std.testing.expectError(error.IntegerOverflow, matcher.observeUnindexedBlock(3, 0));
    try std.testing.expectEqualDeep(prior, matcher.snapshot());
    try std.testing.expectEqual(prior_epoch, matcher.epoch);
    try std.testing.expectEqualDeep(prior_stats, matcher.dynamic_stats);
    try std.testing.expectEqualDeep(prior_tokens, tokens.items);

    matcher.absolute_position = 4;
    matcher.indexed_positions = std.math.maxInt(Count);
    const indexed_prior = matcher.snapshot();
    try std.testing.expectError(error.IntegerOverflow, matcher.plan(std.testing.allocator, &tokens, "abc", "", .{}, false));
    try std.testing.expectEqualDeep(indexed_prior, matcher.snapshot());
    try std.testing.expectEqualDeep(prior_tokens, tokens.items);

    matcher.indexed_positions = 0;
    matcher.absolute_position = std.math.maxInt(Count) - 3;
    _ = try matcher.plan(std.testing.allocator, &tokens, "abc", "", .{}, false);
    try std.testing.expectEqual(std.math.maxInt(Count), matcher.absolute_position);
    try matcher.validateAdvance(0, 0);
    _ = try matcher.plan(std.testing.allocator, &tokens, "", "abc", .{}, false);
    try std.testing.expectEqual(std.math.maxInt(Count), matcher.absolute_position);

    // Seed dictionary anchors right up to the largest logical position. The
    // visible-range checks must avoid overflowing absolute + anchor_len.
    var seeded: Matcher = .{ .absolute_position = std.math.maxInt(Count) - 3 };
    defer seeded.deinit(std.testing.allocator);
    const dictionary_plan = try seeded.plan(std.testing.allocator, &tokens, "abc", "abcabc", .{}, false);
    try std.testing.expectEqual(@as(usize, 3), dictionary_plan.stats.matched_bytes);
    try std.testing.expectEqual(std.math.maxInt(Count), seeded.absolute_position);
}

test "rolling matcher wide counters recover logical position after token growth OOM" {
    const boundary: Count = @as(Count, 1) << 32;
    var matcher: Matcher = .{ .absolute_position = boundary - 8 };
    defer matcher.deinit(std.testing.allocator);
    var tokens: std.ArrayList(lz77.Token) = .empty;
    defer tokens.deinit(std.testing.allocator);
    const history = "abcdefgh";
    _ = try matcher.plan(std.testing.allocator, &tokens, history, "", .{}, false);
    const prior_position = matcher.absolute_position;
    var block: [8192]u8 = undefined;
    for (&block, 0..) |*byte, i| byte.* = @truncate(i * 37 + i / 11);

    // Tables are already allocated. The first allocation reserves the usual
    // token prefix; disable remaps so the next growth deterministically fails
    // after several thousand chain writes.
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{
        .fail_index = 1,
        .resize_fail_index = 0,
    });
    const options: lz77.GreedyOptions = .{ .max_chain = 0 };
    try std.testing.expectError(error.OutOfMemory, matcher.plan(failing.allocator(), &tokens, &block, history, options, false));
    try std.testing.expect(failing.has_induced_failure);
    try std.testing.expectEqual(prior_position, matcher.absolute_position);
    try std.testing.expect(!matcher.initialized);
    try std.testing.expectEqual(@as(Count, 0), matcher.indexed_positions);
    try std.testing.expectEqual(@as(usize, 0), tokens.items.len);

    const retried = try matcher.plan(std.testing.allocator, &tokens, &block, history, options, false);
    try std.testing.expectEqual(block.len, retried.stats.literals);
    for (retried.tokens, block) |token, byte| try std.testing.expectEqual(byte, token.literal);
    try std.testing.expectEqual(try core.stream_count.addLocal(prior_position, block.len), matcher.absolute_position);
}

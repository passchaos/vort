const std = @import("std");
const source_mod = @import("controlled_source.zig");

test "Zstd HQ controlled source checked arithmetic rejects overflow before byte access or heap" {
    const failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const huge: []const u8 = @as([*]const u8, @ptrFromInt(1))[0..std.math.maxInt(usize)];
    const overflow_prefix: source_mod.Source = .{ .dictionary = huge, .history = "x", .block = "", .window_len = std.math.maxInt(usize) };
    try std.testing.expectError(error.IntegerOverflow, overflow_prefix.checkedPrefixLen());
    try std.testing.expectError(error.IntegerOverflow, overflow_prefix.checkedTotalLen());
    try std.testing.expectError(error.IntegerOverflow, overflow_prefix.byteAtChecked(0));
    const overflow_total: source_mod.Source = .{ .dictionary = "x", .history = "", .block = huge, .window_len = 1 };
    try std.testing.expectEqual(@as(usize, 1), try overflow_total.checkedPrefixLen());
    try std.testing.expectError(error.IntegerOverflow, overflow_total.checkedTotalLen());
    try std.testing.expectError(error.IntegerOverflow, overflow_total.checkedBlockPosition(huge.len));
    try std.testing.expectError(error.IntegerOverflow, source_mod.Source.initChecked("x", "", huge, 1));
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
}

test "Zstd HQ controlled source retains prefix origin overlap and validates dedicated HQ parameters" {
    var record: source_mod.Record = .{ .literal_len = 0, .distance = 1, .match_len = 3, .match_end = 3 };
    try std.testing.expect(record.offset_value == null);
    record.offset_value = 4;
    try std.testing.expectEqual(@as(usize, 4), record.offset_value.?);
    try std.testing.expectEqual(@as(usize, 1), record.distance);
    const source = try source_mod.Source.initChecked("dictionary", "history", "abababab", 8);
    try std.testing.expectEqualStrings("y", source.dictionary);
    try std.testing.expectEqualStrings("history", source.history);
    try std.testing.expectEqual(@as(usize, 8), try source.checkedPrefixLen());
    try std.testing.expectEqual(@as(usize, 16), try source.checkedTotalLen());
    try std.testing.expectEqual(@as(usize, 10), try source.checkedBlockPosition(2));
    try std.testing.expectEqual(@as(u8, 'y'), try source.byteAtChecked(0));
    try std.testing.expectEqual(@as(u8, 'b'), try source.byteAtChecked(15));
    try std.testing.expectEqual(source_mod.Origin.history, source.origin(1));
    try std.testing.expectEqual(source_mod.Origin.block, source.origin(8));
    try std.testing.expectEqual(@as(usize, 6), source.match(2, 8, 3).length);
    try std.testing.expectError(error.InvalidBlockPlan, source.byteAtChecked(16));
    try std.testing.expectError(error.InvalidBlockPlan, source.checkedBlockPosition(9));
    const defaults = try (source_mod.Parameters{ .strategy = .btopt }).resolvedHq();
    try std.testing.expectEqual(@as(u32, 64), defaults.search_depth);
    const explicit = try (source_mod.Parameters{ .strategy = .btopt, .hq = .{ .search_depth = 999, .nice_len = 2048, .min_match = 5, .max_working_memory = 0 } }).resolvedHq();
    try std.testing.expectEqual(@as(u32, 999), explicit.search_depth);
    try std.testing.expectEqual(@as(usize, 0), explicit.max_working_memory);
    for ([_]source_mod.Parameters{
        .{ .strategy = .greedy, .hq = .{} },           .{ .strategy = .btopt, .acceleration = 2 },
        .{ .strategy = .btopt, .search_budget = 511 }, .{ .strategy = .btopt, .hq = .{ .min_match = 2 } },
    }) |parameters| try std.testing.expectError(error.InvalidBlockPlan, parameters.resolvedHq());
}

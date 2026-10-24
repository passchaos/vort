const std = @import("std");
const types = @import("../hq_types.zig");
const command_plan = @import("../command_plan.zig");
const command_encoding = @import("../command_encoding.zig");
const distance = @import("../distance.zig");

test "Brotli HQ source keeps ordinary past frame bytes and u64 absolute positions" {
    const source = try types.Source.init("abc", "abcxxx", 22, 3);
    try std.testing.expectEqual(@as(usize, 3), source.prefixLen());
    try std.testing.expectEqual(@as(usize, (1 << 22) - 16), source.window_len);
    try std.testing.expectEqual(@as(usize, 3), try source.maxBackward(0));
    try std.testing.expectEqual(@as(usize, 3), source.match(0, 0, 2).length);
    try std.testing.expectEqual(@as(usize, 3), source.match(0, 0, 2).distance);
    const overlap = try types.Source.init("", "ababab", 22, 0);
    try std.testing.expectEqual(@as(usize, 4), overlap.match(2, 0, 2).length);
    try std.testing.expectEqual(@as(usize, 2), try overlap.maxBackward(2));
    const old_frame = try types.Source.init("x", "yz", 22, (@as(u64, 1) << 32) + 123);
    try std.testing.expectEqual((@as(u64, 1) << 32) + 125, try old_frame.absolutePosition(2));
    try std.testing.expectEqual(old_frame.window_len, try old_frame.maxBackward(2));
    try std.testing.expectError(error.InvalidBlockPlan, types.Source.init("compound attachment", "x", 22, 0));
    try std.testing.expectError(error.InvalidBlockPlan, types.Source.init("", "x", 9, 0));
    try std.testing.expectError(error.InvalidBlockPlan, types.Source.init("", "x", 25, 0));
    try std.testing.expectError(error.IntegerOverflow, types.Source.init("", "x", 22, std.math.maxInt(u64)));
    try std.testing.expectError(error.InvalidBlockPlan, overlap.byteAtChecked(overlap.totalLen()));
    const huge: []const u8 = @as([*]const u8, @ptrFromInt(1))[0..std.math.maxInt(usize)];
    const hostile: types.Source = .{ .history = "x", .input = huge, .window_len = 1008, .frame_offset = 1 };
    try std.testing.expectError(error.IntegerOverflow, hostile.checkedTotalLen());
}

test "Brotli HQ exact encoding preserves semantic aliases and canonical terminal fields" {
    const implicit = command_encoding.forLengths(0, 2, true).?;
    const explicit = command_encoding.forLengths(0, 2, false).?;
    try (types.ExactEncoding{ .command_symbol = implicit.symbol }).validate(0, 2, true);
    try (types.ExactEncoding{ .command_symbol = explicit.symbol, .distance_code = 0, .distance_encoding = .{ .symbol = 0 } }).validate(0, 2, true);
    const parameters = distance.Parameters.init(1, 6);
    try (types.ExactEncoding{ .command_symbol = explicit.symbol, .distance_code = 123 + 15, .distance_encoding = distance.encodeWithParameters(123, parameters).?, .distance_parameters = parameters }).validate(0, 2, true);
    try std.testing.expectError(error.InvalidBlockPlan, (types.ExactEncoding{ .command_symbol = implicit.symbol, .distance_code = 1 }).validate(0, 2, true));
    try std.testing.expectError(error.InvalidBlockPlan, (types.ExactEncoding{ .command_symbol = explicit.symbol }).validate(0, 2, true));
    try std.testing.expectError(error.InvalidBlockPlan, (types.ExactEncoding{ .command_symbol = 704 }).validate(0, 2, false));
    const terminal = command_encoding.forLengths(2, 4, false).?;
    try (types.ExactEncoding{ .command_symbol = terminal.symbol }).validate(2, 4, false);
    try std.testing.expectError(error.InvalidBlockPlan, (types.ExactEncoding{ .command_symbol = terminal.symbol, .distance_encoding = .{ .symbol = 16 } }).validate(2, 4, false));
    try std.testing.expectError(error.InvalidBlockPlan, (types.ExactEncoding{ .command_symbol = terminal.symbol, .distance_code = 16 }).validate(2, 4, false));
    const aliases = [4]usize{ 16, 15, 4, 4 };
    try std.testing.expectEqual(@as(usize, 4), try types.resolveDistanceCode(0, &aliases));
    try std.testing.expectEqual(@as(usize, 4), try types.resolveDistanceCode(1, &aliases));
    try std.testing.expectEqualDeep(aliases, types.recentAfter(command_plan.Source.lz77, 0, 4, aliases));
    try std.testing.expectEqualDeep([4]usize{ 15, 4, 4, 4 }, types.recentAfter(command_plan.Source.lz77, 1, 4, aliases));
    try std.testing.expectEqualDeep(aliases, types.recentAfter(command_plan.Source.static, 19, 4, aliases));
    try std.testing.expectEqualDeep(aliases, types.recentAfter(command_plan.Source.compound, 0, 4, aliases));
    const command: command_plan.Command = .{ .insert_start = 0, .insert_len = 0, .copy_len = 2, .distance = 4, .has_copy = true, .hq_encoding = .{ .command_symbol = explicit.symbol, .distance_encoding = .{ .symbol = 0 } } };
    try std.testing.expect(!command.updatesRecentDistance());
    var legacy = command;
    legacy.hq_encoding = null;
    try std.testing.expect(legacy.updatesRecentDistance());
}

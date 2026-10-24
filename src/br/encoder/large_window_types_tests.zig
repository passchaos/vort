const std = @import("std");
const distance = @import("distance.zig");
const types = @import("hq_types.zig");
const options = @import("hq_options.zig");
const Mode = @import("quality_schedule.zig").Mode;
const commands = @import("command_encoding.zig");

test "Brotli large window authority Source enforces actual format and u64 frame positions" {
    for (10..31) |bits_value| {
        const bits: u8 = @intCast(bits_value);
        const large = try types.Source.initWithFormat("abc", "abcx", bits, (@as(u64, 1) << 32) + 3, .large_window);
        try large.validate();
        try std.testing.expectEqual(distance.Format.large_window, large.format);
        try std.testing.expectEqual((@as(usize, 1) << @intCast(bits)) - 16, large.window_len);
        try std.testing.expectEqual(large.window_len, try large.maxBackward(0));
        try std.testing.expectEqual(@as(usize, 3), large.match(0, 0, 2).length);
        if (bits > 24) {
            try std.testing.expectError(error.InvalidBlockPlan, types.Source.init("", "x", bits, 0));
            var wrong = large;
            wrong.format = .standard;
            try std.testing.expectError(error.InvalidBlockPlan, wrong.validate());
        } else {
            const normal = try types.Source.init("", "x", bits, 0);
            try std.testing.expectEqual(distance.Format.standard, normal.format);
        }
    }
    try std.testing.expectError(error.InvalidBlockPlan, types.Source.initWithFormat("", "", 9, 0, .large_window));
    try std.testing.expectError(error.InvalidBlockPlan, types.Source.initWithFormat("", "", 31, 0, .large_window));
    try std.testing.expectError(error.IntegerOverflow, types.Source.initWithFormat("", "x", 30, std.math.maxInt(u64), .large_window));
    try std.testing.expectError(error.InvalidBlockPlan, types.Source.initWithFormat("compound", "x", 30, 0, .large_window));
}

test "Brotli large window authority exact commands and resolved settings carry explicit format" {
    const raw: options.HqOptions = .{};
    const normal = try raw.resolve(10, Mode.generic);
    const large = try raw.resolveForFormat(10, Mode.generic, .large_window);
    try std.testing.expectEqual(distance.Format.standard, normal.format);
    try std.testing.expectEqual(distance.Format.large_window, large.format);
    try std.testing.expectEqual(normal.distance_parameters, large.distance_parameters);
    try std.testing.expectEqual(normal.search_depth, large.search_depth);
    try std.testing.expectError(error.InvalidBlockPlan, raw.resolveForFormat(9, Mode.generic, .large_window));
    const physical: usize = (1 << 29) + 11;
    const p = distance.Parameters.init(0, 0);
    const command = commands.forLengths(0, 2, false).?;
    var exact: types.ExactEncoding = .{ .command_symbol = command.symbol, .distance_code = physical + 15, .distance_encoding = distance.encodeWithFormat(physical, p, .large_window).?, .distance_parameters = p, .format = .large_window };
    try exact.validate(0, 2, true);
    exact.format = .standard;
    try std.testing.expectError(error.InvalidBlockPlan, exact.validate(0, 2, true));
    const cache: [4]usize = .{ 16, 15, 11, distance.safe_max_distance };
    const short: types.ExactEncoding = .{ .command_symbol = command.symbol, .distance_code = 0, .distance_encoding = .{ .symbol = 0 }, .distance_parameters = distance.Parameters.init(0, 1), .format = .large_window };
    try short.validate(0, 2, true);
    try std.testing.expectEqual(distance.safe_max_distance, try types.resolveDistanceCode(0, &cache));
    try std.testing.expectEqualDeep(cache, types.recentAfter(.lz77, 0, cache[3], cache));
}

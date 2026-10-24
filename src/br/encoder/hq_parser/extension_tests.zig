const std = @import("std");
const parser = @import("../hq_parser.zig");
const extension = @import("extension.zig");
const command_plan = @import("../command_plan.zig");
const command_lut = @import("../../command_lut.zig");
const distance = @import("../distance.zig");

test "BrHQ core extension prices command and literal terminal witness across 4096" {
    const input: [4098]u8 = @splat('a');
    const source = try parser.Source.init("", &input, 24, 0);
    var model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    model.command_prices = @splat(parser.prices.maximum_symbol_price);
    model.distance_prices = @splat(parser.prices.maximum_symbol_price);
    model.command_prices[488] = parser.prices.scale;
    model.command_prices[490] = parser.prices.maximum_symbol_price;
    model.command_prices[16] = parser.prices.scale;
    model.distance_prices[36] = 0;
    const choices = try model.commandCosts(4094, 2, 4094 + 15);
    try std.testing.expectEqual(@as(u16, 488), choices.items[0].encoding.command_symbol);
    const command: command_plan.Command = .{ .insert_start = 0, .insert_len = 4094, .copy_len = 2, .distance = 4094, .has_copy = true, .hq_encoding = choices.items[0].encoding };
    var prefix: [4099]u64 = undefined;
    for (&prefix, 0..) |*value, position| value.* = position * 8 * parser.prices.scale;
    const retained = try extension.choose(command, 4, source, &model, &prefix);
    try std.testing.expectEqual(@as(usize, 2), retained.length);
    try std.testing.expectEqual(@as(u16, 488), retained.encoding.command_symbol);
    const short_cost = choices.items[0].cost + 2 * 8 * parser.prices.scale + (try model.terminal(2)).cost;
    const literal_cost = 4 * 8 * parser.prices.scale + (try model.terminal(4098)).cost;
    try std.testing.expectEqual(@as(u64, 4 * parser.prices.scale), literal_cost - short_cost);
    model.command_prices[490] = 0;
    const longer = try extension.choose(command, 4, source, &model, &prefix);
    try std.testing.expectEqual(@as(usize, 4), longer.length);
    try std.testing.expectEqual(@as(u16, 490), longer.encoding.command_symbol);
    try std.testing.expectEqual(retained.encoding.distance_code, longer.encoding.distance_code);
}

test "BrHQ core extension charges explicit zero when the implicit command range ends" {
    const input: [70]u8 = @splat('q');
    const source = try parser.Source.init("qqqq", &input, 24, 4);
    var model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    model.command_prices = @splat(parser.prices.maximum_symbol_price);
    model.distance_prices = @splat(parser.prices.maximum_symbol_price);
    const short_choices = try model.commandCosts(0, 69, 0);
    var implicit: ?u16 = null;
    for (short_choices.slice()) |choice| if (command_lut.entries[choice.encoding.command_symbol].distance_code == 0) {
        implicit = choice.encoding.command_symbol;
    };
    model.command_prices[implicit.?] = parser.prices.scale;
    const longer_choices = try model.commandCosts(0, 70, 0);
    const explicit = longer_choices.items[0].encoding.command_symbol;
    model.command_prices[explicit] = 0;
    const terminal_choices = try model.commandCosts(1, 2, null);
    model.command_prices[terminal_choices.items[0].encoding.command_symbol] = parser.prices.scale;
    const command: command_plan.Command = .{ .insert_start = 0, .insert_len = 0, .copy_len = 69, .distance = 4, .has_copy = true, .hq_encoding = .{ .command_symbol = implicit.?, .distance_parameters = model.distance_parameters } };
    var prefix: [71]u64 = undefined;
    for (&prefix, 0..) |*value, position| value.* = position * 8 * parser.prices.scale;
    const kept = try extension.choose(command, 70, source, &model, &prefix);
    try std.testing.expectEqual(@as(usize, 69), kept.length);
    try std.testing.expect(kept.encoding.distance_encoding == null);
    model.distance_prices[0] = 0;
    const extended = try extension.choose(command, 70, source, &model, &prefix);
    try std.testing.expectEqual(@as(usize, 70), extended.length);
    try std.testing.expectEqual(@as(usize, 0), extended.encoding.distance_code);
    try std.testing.expectEqual(@as(u16, 0), extended.encoding.distance_encoding.?.symbol);
}

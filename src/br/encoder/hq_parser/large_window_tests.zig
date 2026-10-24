const std = @import("std");
const parser = @import("../hq_parser.zig");
const distance = @import("../distance.zig");
const provider_mod = @import("../hq_dictionary.zig");
const serialized = @import("../../serialized_dictionary.zig");
const builder = @import("../../serialized_dictionary_builder.zig");

test "BrHQ LargeWindow models price every active shape and preserve standard defaults" {
    try std.testing.expectEqual(@as(usize, 544), parser.prices.maximum_distance_alphabet_size);
    for (0..4) |postfix| for (0..16) |direct| {
        const parameters = distance.Parameters.init(@intCast(postfix), @intCast(direct));
        const standard = parser.Model.init(parameters, 0);
        const explicit_standard = parser.Model.initWithFormat(parameters, 0, .standard);
        try std.testing.expect(std.meta.eql(standard, explicit_standard));
        const large = parser.Model.initWithFormat(parameters, 0, .large_window);
        try large.validateWithFormat(parameters, 0, .large_window);
        const active = parameters.activeAlphabetSize(.large_window);
        try std.testing.expect(active <= 544 and active > parameters.alphabetSize());
        const maximum = parameters.maximumDistanceForFormat(.large_window);
        try std.testing.expect(maximum <= distance.safe_max_distance);
        const choices = try large.commandCosts(3, 2, maximum + 15);
        try std.testing.expect(choices.len != 0);
        for (choices.slice()) |choice| {
            try choice.encoding.validate(3, 2, true);
            try std.testing.expectEqual(distance.Format.large_window, choice.encoding.format);
            const encoded = choice.encoding.distance_encoding.?;
            try std.testing.expect(encoded.symbol < active);
            try std.testing.expect(encoded.extra_bits > 24 and encoded.extra_bits <= 29);
            try std.testing.expectEqual(maximum, distance.decodeWithFormat(encoded, parameters, .large_window));
        }
        try std.testing.expectEqual(@as(usize, 0), (try standard.commandCosts(3, 2, maximum + 15)).len);
        try std.testing.expectError(error.InvalidBlockPlan, large.validateWithFormat(parameters, 0, .standard));
        try std.testing.expect(distance.encodeWithFormat(maximum + 1, parameters, .large_window) == null);
    };
    const largest = distance.Parameters.init(3, 15);
    try std.testing.expectEqual(@as(usize, 1128), largest.wireAlphabetSize(.large_window));
    try std.testing.expectEqual(@as(usize, 544), largest.activeAlphabetSize(.large_window));
}

test "BrHQ LargeWindow cache accepts safe aliases above regular shape and rejects excess" {
    const parameters = distance.Parameters.init(3, 15);
    const safe = distance.safe_max_distance;
    try std.testing.expect(safe > parameters.maximumDistanceForFormat(.large_window));
    const cache: [4]usize = .{ 16, 15, 11, safe };
    const valid = try parser.rep.choicesWithFormat(cache, safe, parameters, .large_window, false);
    try std.testing.expectEqual(@as(usize, 1), valid.len);
    try std.testing.expectEqual(@as(usize, 0), valid.items[0].code);
    try std.testing.expectEqual(cache, valid.items[0].cache);
    const excess: [4]usize = .{ 16, 15, 11, safe + 1 };
    try std.testing.expectEqual(@as(usize, 0), (try parser.rep.choicesWithFormat(excess, safe + 1, parameters, .large_window, true)).len);
    const model = parser.Model.initWithFormat(parameters, 0, .large_window);
    var statistics: parser.Statistics = .{ .distance_parameters = parameters, .format = .large_window };
    const choice = (try model.commandCosts(0, 2, 0)).items[0];
    try statistics.addCommand(choice.encoding, true, 2);
    const refined = try model.refined(&statistics);
    try std.testing.expectEqual(distance.Format.large_window, refined.format);
    statistics.format = .standard;
    try std.testing.expectError(error.InvalidBlockPlan, model.refined(&statistics));
}

test "BrHQ LargeWindow actual static plan selects near one GiB distance with tiny workspace" {
    var bits: [32]u8 = @splat(0);
    bits[4] = 1;
    const encoded = try builder.serializeAlloc(std.testing.allocator, .{
        .word_lists = &.{.{ .size_bits_by_length = bits, .data = "cat!dog!" }},
        .transform_lists = &.{.{ .prefix_suffix = &.{0}, .transforms = &.{ 0, 0, 0 } }},
        .dictionaries = &.{.{ .word_list_index = 0, .transform_list_index = 0 }},
    });
    defer std.testing.allocator.free(encoded);
    const dictionary = try serialized.parse(encoded);
    var budget = parser.Budget.init(std.testing.allocator, 8 * 1024 * 1024);
    var provider = try provider_mod.Provider.init(&budget, .{ .serialized = &dictionary }, null);
    defer provider.deinit();
    const source = try parser.Source.initWithFormat("", "cat!", 30, @as(u64, 1) << 30, .large_window);
    const parameters = distance.Parameters.init(0, 0);
    var model = parser.Model.initWithFormat(parameters, 0, .large_window);
    model.literal_prices = @splat(@splat(parser.prices.maximum_symbol_price));
    var settings: parser.Parameters = .{ .budget = &budget };
    settings.resolved.format = .large_window;
    const plan = try parser.planAlloc(budget.allocator(), source, settings, &model, &provider);
    defer plan.deinit(budget.allocator());
    try std.testing.expectEqual(distance.Format.large_window, plan.format);
    try std.testing.expectEqual(@as(usize, 1), plan.commands.len);
    const command = plan.commands[0];
    try std.testing.expect(command.isStatic());
    const physical = command.hq_encoding.?.distance_code - 15;
    try std.testing.expectEqual((@as(usize, 1) << 30) - 15, physical);
    try std.testing.expect(physical > parameters.maximumDistance());
    try std.testing.expect(command.hq_encoding.?.distance_encoding.?.extra_bits > 24);
    try std.testing.expectEqual(distance.Format.large_window, command.hq_encoding.?.format);
    try std.testing.expectEqual(distance.Format.large_window, plan.statistics.format);
    try std.testing.expectEqual(source.recent, plan.final_recent_distances);
    try std.testing.expect(budget.peak < 8 * 1024 * 1024);
    try std.testing.expectEqualSlices(u8, "cat!", source.input);
}

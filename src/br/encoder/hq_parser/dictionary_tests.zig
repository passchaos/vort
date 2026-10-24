const std = @import("std");
const parser = @import("../hq_parser.zig");
const dictionary = @import("../hq_dictionary.zig");
const builder = @import("../../serialized_dictionary_builder.zig");
const serialized = @import("../../serialized_dictionary.zig");
const shared = @import("../../shared_dictionary.zig");
const distance = @import("../distance.zig");

pub fn makeDictionary(allocator: std.mem.Allocator, raw: []const u8, kind: u8, suffix: bool) ![]u8 {
    var bits: [32]u8 = @splat(0);
    bits[4] = 1;
    return builder.serializeAlloc(allocator, .{
        .raw_prefix = raw,
        .word_lists = &.{.{ .size_bits_by_length = bits, .data = "cat!dog!" }},
        .transform_lists = &.{.{ .prefix_suffix = if (suffix) &.{ 1, ' ', 0 } else &.{0}, .transforms = if (suffix) &.{ 1, kind, 0 } else &.{ 0, kind, 0 } }},
        .dictionaries = &.{.{ .word_list_index = 0, .transform_list_index = 0 }},
    });
}

test "BrHQ core atomic static command spills beyond the 4096 artificial window" {
    const encoded = try makeDictionary(std.testing.allocator, "", 0, true);
    defer std.testing.allocator.free(encoded);
    const parsed = try serialized.parse(encoded);
    var budget = parser.Budget.init(std.testing.allocator, 64 * 1024 * 1024);
    var provider = try dictionary.Provider.init(&budget, .{ .serialized = &parsed }, null);
    defer provider.deinit();
    var input: [4100]u8 = undefined;
    @memset(input[0..4095], 'x');
    @memcpy(input[4095..], "cat! ");
    const source = try parser.Source.init("", &input, 24, 0);
    const model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    const plan = try parser.planAlloc(budget.allocator(), source, .{ .budget = &budget }, &model, &provider);
    defer plan.deinit(budget.allocator());
    try std.testing.expectEqual(source.input.len, plan.consumed);
    var position: usize = 0;
    var found = false;
    for (plan.commands) |command| {
        position += command.insert_len;
        if (command.isStatic() and position == 4095) {
            found = true;
            try std.testing.expectEqual(@as(usize, 4), command.copy_len);
            try std.testing.expectEqual(@as(usize, 5), command.outputLen());
            try std.testing.expectEqual(@as(usize, 0), command.dictionary_address);
            var output: [8]u8 = undefined;
            const word = try (shared.Dictionary{ .serialized = &parsed }).staticWord(model.context(source, position, .{ 0, 0 }), command.dictionary_address, command.copy_len, &output);
            try std.testing.expectEqualSlices(u8, "cat! ", word);
        }
        position += command.outputLen();
    }
    try std.testing.expect(found);
    try std.testing.expectEqual(@as(usize, 4100), position);
}

test "BrHQ core static output one two three and compound semantic zero preserve raw lengths" {
    for ([_]u8{ 3, 2, 1 }) |omit| {
        const encoded = try makeDictionary(std.testing.allocator, "", omit, false);
        defer std.testing.allocator.free(encoded);
        const parsed = try serialized.parse(encoded);
        var budget = parser.Budget.init(std.testing.allocator, 8 * 1024 * 1024);
        var provider = try dictionary.Provider.init(&budget, .{ .serialized = &parsed }, null);
        defer provider.deinit();
        var output: [8]u8 = undefined;
        const descriptor: shared.Dictionary = .{ .serialized = &parsed };
        const word = try descriptor.staticWord(0, 0, 4, &output);
        const source = try parser.Source.init("", word, 24, 0);
        var model = parser.Model.init(distance.Parameters.init(0, 0), 0);
        model.literal_prices = @splat(@splat(parser.prices.maximum_symbol_price));
        const plan = try parser.planAlloc(budget.allocator(), source, .{ .budget = &budget }, &model, &provider);
        defer plan.deinit(budget.allocator());
        try std.testing.expectEqual(@as(usize, 4 - omit), plan.consumed);
        try std.testing.expectEqual(@as(usize, 1), plan.commands.len);
        try std.testing.expect(plan.commands[0].isStatic());
        try std.testing.expectEqual(@as(usize, 4), plan.commands[0].copy_len);
        try std.testing.expectEqual(word.len, plan.commands[0].outputLen());
        try std.testing.expectEqual(source.recent, plan.final_recent_distances);
    }
    const encoded = try makeDictionary(std.testing.allocator, "abcd", 0, false);
    defer std.testing.allocator.free(encoded);
    const parsed = try serialized.parse(encoded);
    var budget = parser.Budget.init(std.testing.allocator, 8 * 1024 * 1024);
    var provider = try dictionary.Provider.init(&budget, .{ .serialized = &parsed }, null);
    defer provider.deinit();
    const source = try parser.Source.init("", "abcd", 24, 0);
    const model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    const plan = try parser.planAlloc(budget.allocator(), source, .{ .budget = &budget }, &model, &provider);
    defer plan.deinit(budget.allocator());
    try std.testing.expectEqual(@as(usize, 1), plan.commands.len);
    try std.testing.expect(plan.commands[0].isCompound());
    try std.testing.expectEqual(@as(usize, 0), plan.commands[0].dictionary_address);
    try std.testing.expectEqual(@as(usize, 0), plan.commands[0].hq_encoding.?.distance_code);
    try std.testing.expectEqual(source.recent, plan.final_recent_distances);
}

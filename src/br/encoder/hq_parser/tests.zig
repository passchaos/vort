const std = @import("std");
const parser = @import("../hq_parser.zig");
const command_lut = @import("../../command_lut.zig");
const distance = @import("../distance.zig");
const types = @import("../hq_types.zig");
const length = @import("../../length.zig");

fn regularDistanceOracle(encoded: distance.Encoding, parameters: distance.Parameters) usize {
    const direct: usize = @as(usize, parameters.ndirect_high) << parameters.npostfix;
    if (encoded.symbol - 16 < direct) return encoded.symbol - 15;
    const xcode = @as(usize, encoded.symbol) - 16 - direct;
    const bits = 1 + (xcode >> @intCast(@as(u3, parameters.npostfix) + 1));
    const prefix = (xcode >> parameters.npostfix) & 1;
    const postfix = xcode & ((@as(usize, 1) << parameters.npostfix) - 1);
    return ((((@as(usize, 2) + prefix) << @intCast(bits)) - 4 + encoded.extra) << parameters.npostfix) + postfix + direct + 1;
}

test {
    _ = @import("oracle_tests.zig");
    _ = @import("dictionary_tests.zig");
    _ = @import("resource_tests.zig");
    _ = @import("extension_tests.zig");
    _ = @import("large_window_tests.zig");
    _ = @import("whole_block_tests.zig");
    _ = @import("command_storage_integration_tests.zig");
    _ = @import("complete_length_tests.zig");
}

test "Brotli HQ complete command price covers every one of 704 encodings" {
    const model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    for (command_lut.entries, 0..) |entry, symbol| {
        const choices = try model.commandCosts(entry.insert_base, entry.copy_base, if (entry.distance_code == 0) 0 else 4);
        var found = false;
        for (choices.slice()) |choice| {
            if (choice.encoding.command_symbol != symbol) continue;
            found = true;
            try choice.encoding.validate(entry.insert_base, entry.copy_base, true);
            var expected: u64 = model.command_prices[symbol] + (@as(u32, entry.insert_extra_bits) + entry.copy_extra_bits) * parser.prices.scale;
            if (entry.distance_code == -1) expected += model.distance_prices[4];
            try std.testing.expectEqual(expected, choice.cost);
        }
        try std.testing.expect(found);
    }
}

test "Brotli HQ all sixteen aliases preserve semantic zero and all 64 distance shapes" {
    const expected = [_]usize{ 4, 11, 15, 16, 3, 5, 2, 6, 1, 7, 10, 12, 9, 13, 8, 14 };
    for (expected, 0..) |physical, code| {
        try std.testing.expectEqual(physical, try parser.rep.resolve(code, types.initial_recent));
        const candidates = try parser.rep.choices(types.initial_recent, physical, distance.Parameters.init(0, 0), false);
        var found = false;
        for (candidates.slice()) |candidate| if (candidate.code == code) {
            found = true;
            try std.testing.expectEqual(if (code == 0) types.initial_recent else [4]usize{ 15, 11, 4, physical }, candidate.cache);
        };
        try std.testing.expect(found);
        try std.testing.expectEqual(types.initial_recent, parser.rep.after(types.initial_recent, physical, code, true));
    }
    for (0..4) |postfix| for (0..16) |direct| {
        const parameters = distance.Parameters.init(@intCast(postfix), @intCast(direct));
        const model = parser.Model.init(parameters, 0);
        try std.testing.expect(parameters.alphabetSize() <= 520);
        const physical: usize = 70000;
        const choices = try model.commandCosts(3, 70, physical + 15);
        for (choices.slice()) |choice| {
            try choice.encoding.validate(3, 70, true);
            try std.testing.expectEqual(physical, regularDistanceOracle(choice.encoding.distance_encoding.?, parameters));
        }
        try std.testing.expect(choices.len != 0);
    };
    const aliases = try parser.rep.choices(.{ 1, 2, 4, 4 }, 4, distance.Parameters.init(0, 0), false);
    var zero: ?[4]usize = null;
    var second: ?[4]usize = null;
    for (aliases.slice()) |alias| {
        if (alias.code == 0) zero = alias.cache;
        if (alias.code == 1) second = alias.cache;
    }
    try std.testing.expectEqual([4]usize{ 1, 2, 4, 4 }, zero.?);
    try std.testing.expectEqual([4]usize{ 2, 4, 4, 4 }, second.?);
}

test "Brotli HQ tiny command parse keeps exact encoding and logical offsets beyond four GiB" {
    const source = try parser.Source.init("abcd", "abcdabcd", 24, (@as(u64, 1) << 32) + 4);
    const model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    const plan = try parser.planAlloc(std.testing.allocator, source, .{}, &model, null);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(source.input.len, plan.consumed);
    try std.testing.expect(plan.commands.len != 0);
    try std.testing.expect(plan.statistics.copy_bytes != 0);
    for (plan.commands) |command| try command.hq_encoding.?.validate(command.insert_len, command.copy_len, command.has_copy);
    try std.testing.expectEqual([2]u8{ 'd', 'c' }, plan.final_previous);
    try std.testing.expectEqual((@as(u64, 1) << 32) + 12, try source.absolutePosition(plan.consumed));
    try std.testing.expectEqual(@as(?u5, 23), length.codeForValue(16 * 1024 * 1024, false));
}

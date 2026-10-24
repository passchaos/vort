const std = @import("std");
const parser = @import("../hq_parser.zig");
const distance = @import("../distance.zig");
const command_lut = @import("../../command_lut.zig");

fn short(code: usize, cache: [4]usize) ?usize {
    if (code < 4) return cache[3 - code];
    const deltas = [_]i8{ -1, 1, -2, 2, -3, 3 };
    const delta = deltas[(code - 4) % 6];
    const base = cache[if (code < 10) 3 else 2];
    if (delta < 0) return if (base <= @as(usize, @intCast(-delta))) null else base - @as(usize, @intCast(-delta));
    return std.math.add(usize, base, @intCast(delta)) catch null;
}
fn terminal(model: *const parser.Model, insert: usize) u64 {
    var best: u64 = std.math.maxInt(u64);
    for (command_lut.entries, 0..) |entry, symbol| {
        if (insert < entry.insert_base or insert - entry.insert_base >= (@as(usize, 1) << entry.insert_extra_bits)) continue;
        best = @min(best, model.command_prices[symbol] + (@as(u32, entry.insert_extra_bits) + entry.copy_extra_bits) * parser.prices.scale);
    }
    return best;
}
fn path(source: parser.Source, model: *const parser.Model, position: usize, pending: usize, recent: [4]usize) !u64 {
    if (position == source.input.len) return if (pending == 0) 0 else terminal(model, pending);
    var best = @as(u64, model.literalPrice(source, position, .{ 0, 0 })) + try path(source, model, position + 1, pending + 1, recent);
    const current = source.history.len + position;
    for (current - @min(current, source.window_len)..current) |candidate| {
        const match = source.match(position, candidate, 2);
        if (match.length < 2) continue;
        for (2..match.length + 1) |copy| {
            for (0..17) |selector| {
                const physical = match.distance;
                const encoding = if (selector < 16) blk: {
                    if (short(selector, recent) != physical) continue;
                    break :blk distance.Encoding{ .symbol = @intCast(selector) };
                } else distance.encodeWithParameters(physical, model.distance_parameters) orelse continue;
                var next = recent;
                if (selector != 0) next = .{ recent[1], recent[2], recent[3], physical };
                const suffix = try path(source, model, position + copy, 0, next);
                for (command_lut.entries, 0..) |entry, symbol| {
                    if (pending < entry.insert_base or pending - entry.insert_base >= (@as(usize, 1) << entry.insert_extra_bits) or
                        copy < entry.copy_base or copy - entry.copy_base >= (@as(usize, 1) << entry.copy_extra_bits)) continue;
                    if (entry.distance_code == 0 and selector != 0) continue;
                    var cost: u64 = model.command_prices[symbol] + (@as(u32, entry.insert_extra_bits) + entry.copy_extra_bits) * parser.prices.scale;
                    if (entry.distance_code == -1) cost += model.distance_prices[encoding.symbol] + @as(u32, encoding.extra_bits) * parser.prices.scale;
                    best = @min(best, cost + suffix);
                }
            }
        }
    }
    return best;
}

test "BrHQ core independent complete scalar path matches frozen command costs" {
    const source = try parser.Source.init("abcd", "abcdab", 10, 4);
    const model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    const expected = try path(source, &model, 0, 0, source.recent);
    const plan = try parser.planAlloc(std.testing.allocator, source, .{}, &model, null);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(expected, plan.estimated_cost);
    try std.testing.expectEqual(source.input.len, plan.consumed);
    try std.testing.expectEqual(source.recent, plan.final_recent_distances);
}

test "BrHQ core implicit and explicit zero have separate prices and identical nonpush state" {
    const source = try parser.Source.init("abcd", "abcd", 10, 4);
    var model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    model.command_prices = @splat(parser.prices.maximum_symbol_price);
    model.distance_prices = @splat(parser.prices.maximum_symbol_price);
    model.literal_prices = @splat(@splat(parser.prices.maximum_symbol_price));
    const candidates = try model.commandCosts(0, 4, 0);
    var explicit: ?u16 = null;
    for (candidates.slice()) |choice| {
        if (choice.encoding.distance_encoding != null) explicit = choice.encoding.command_symbol;
    }
    model.command_prices[explicit.?] = parser.prices.scale;
    model.distance_prices[0] = 0;
    const plan = try parser.planAlloc(std.testing.allocator, source, .{}, &model, null);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), plan.commands.len);
    try std.testing.expectEqual(explicit.?, plan.commands[0].hq_encoding.?.command_symbol);
    try std.testing.expectEqual(@as(usize, 0), plan.commands[0].hq_encoding.?.distance_code);
    try std.testing.expectEqual(@as(u16, 0), plan.commands[0].hq_encoding.?.distance_encoding.?.symbol);
    try std.testing.expectEqual(source.recent, plan.final_recent_distances);
    try std.testing.expectEqual(@as(u32, 1), plan.statistics.distance_counts[0]);
    try std.testing.expectEqual(@as(u64, parser.prices.scale), plan.estimated_cost);
}

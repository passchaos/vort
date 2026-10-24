const std = @import("std");
const parser = @import("../hq_parser.zig");
const distance = @import("../distance.zig");
const resources = @import("resources.zig");
const storage = @import("command_storage.zig");
const Ledger = @import("test_allocator_ledger.zig").Ledger;

test "BrHQ dynamic command storage keeps fifty exact commands and measured growth peak" {
    const input: [100]u8 = @splat('a');
    const source = try parser.Source.init("aaaa", &input, 24, 4);
    var model = parser.Model.init(distance.Parameters.init(0, 0), 0);
    model.command_prices = @splat(parser.prices.maximum_symbol_price);
    model.distance_prices = @splat(parser.prices.maximum_symbol_price);
    model.literal_prices = @splat(@splat(parser.prices.maximum_symbol_price));
    model.command_prices[0] = 0;
    model.distance_prices[0] = 0;
    var meter: Ledger = .{ .backing = std.testing.allocator, .forbid_remap = true };
    const lower = try parser.requiredWorkingMemory(source, .{}, &model, null);
    const plan = try parser.planAlloc(meter.allocator(), source, .{}, &model, null);
    try std.testing.expectEqual(@as(usize, 50), plan.commands.len);
    try std.testing.expectEqual(plan.commands.len, plan.command_storage.len);
    try std.testing.expectEqual(meter.peak, plan.peak_working_memory);
    try std.testing.expect(meter.peak > lower);
    for (plan.commands, 0..) |command, index| {
        try std.testing.expectEqual(index * 2, command.insert_start);
        try std.testing.expectEqual(@as(usize, 0), command.insert_len);
        try std.testing.expectEqual(@as(usize, 2), command.copy_len);
        try std.testing.expectEqual(@as(usize, 0), command.hq_encoding.?.distance_code);
    }
    try std.testing.expectEqual(source.recent, plan.final_recent_distances);
    plan.deinit(meter.allocator());
    try std.testing.expectEqual(@as(usize, 0), meter.live);
    const Test = struct {
        fn run(allocator: std.mem.Allocator, bytes: parser.Source, costs: *const parser.Model) !void {
            const result = try parser.planAlloc(allocator, bytes, .{}, costs, null);
            defer result.deinit(allocator);
            try std.testing.expectEqual(@as(usize, 50), result.commands.len);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{ source, &model });
}

test "BrHQ dynamic command lower bound grows with literal workspace rather than input commands" {
    const small_len = 4096;
    const large_len = 1024 * 1024;
    const synthetic = @as([*]const u8, @ptrFromInt(4096))[0..large_len];
    const small = try parser.Source.init("", synthetic[0..small_len], 24, 0);
    const large = try parser.Source.init("", synthetic, 24, 0);
    const a = try resources.ownBytes(small, .{}, false);
    const b = try resources.ownBytes(large, .{}, true);
    try std.testing.expectEqual(@as(usize, (large_len - small_len) * @sizeOf(u64)), b - a);
    try std.testing.expectEqual(@as(usize, 16), storage.initial_capacity);
}

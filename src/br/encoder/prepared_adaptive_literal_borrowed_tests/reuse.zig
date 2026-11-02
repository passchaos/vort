const std = @import("std");
const fixtures = @import("../prepared_adaptive_literal_tests/fixtures.zig");
const checks = @import("../context_primary_prepare_tests/support.zig");
const models = @import("models.zig");

pub fn check(comptime Codec: type) !void {
    const allocator = std.testing.allocator;
    const data = try fixtures.rich(allocator, 160);
    defer data.deinit(allocator);
    var options: Codec.Options = .{ .use_recent_distances = true, .adaptive_literal_split = &data.plan };
    var shared = try Codec.buildCommon(allocator, data.input, data.commands, options);
    const saved = shared;
    const length = data.literal_count;
    var alternate = try Codec.Plan.initCopy(allocator, &.{ @intCast(length / 2), @intCast(length - length / 2) }, &.{ 0, 1 }, 2, length, 0);
    defer alternate.deinit(allocator);
    for (0..4) |variant| {
        options.adaptive_literal_split = if (variant & 1 == 0) &data.plan else &alternate;
        var owned = try Codec.prepare(allocator, data.input, data.commands, options);
        defer owned.deinit(allocator);
        var borrowed = try Codec.prepareBorrowed(allocator, data.input, data.commands, options, &shared);
        defer borrowed.deinit(allocator);
        try models.same(Codec, &owned, &borrowed);
        var old_stats = fixtures.stats(Codec.Stats, data);
        const old_wire = try Codec.encode(allocator, data.input, data.commands, &old_stats, options);
        defer allocator.free(old_wire);
        var new_stats = fixtures.stats(Codec.Stats, data);
        const new_wire = try Codec.emit(allocator, data.input, data.commands, &new_stats, options, &borrowed);
        defer allocator.free(new_wire);
        try std.testing.expectEqualSlices(u8, old_wire, new_wire);
        try std.testing.expectEqualDeep(old_stats, new_stats);
        try checks.sameCommon(&saved, &shared, data.commands.len);
    }
}

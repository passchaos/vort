//! Independent old priced-node contracts for successful frontier memo reuse.
const std = @import("std");
const cases = @import("frontier_price_tests/cases.zig");

pub fn check(comptime Helper: type) !void {
    const metrics = try cases.check(Helper);
    std.debug.print("frontier price independent oracle: first_calls={d}, replay_calls={d}, errors={d}\n", .{ metrics.first_calls, metrics.replay_calls, metrics.errors });
}

//! Real prepared adaptive-literal contracts, bound to the private production codec.
const std = @import("std");
const parity = @import("prepared_adaptive_literal_tests/parity.zig");
const resources = @import("prepared_adaptive_literal_tests/resources.zig");
const negative = @import("prepared_adaptive_literal_tests/negative.zig");
const public_q8 = @import("prepared_adaptive_literal_tests/public_q8.zig");

pub fn check(comptime Codec: type) !void {
    var phase: []const u8 = "parity";
    errdefer |err| std.debug.print("adaptive literal failure phase={s}: {s}\n", .{ phase, @errorName(err) });
    try parity.check(Codec);
    phase = "resources";
    const metrics = try resources.check(Codec);
    phase = "negative";
    try negative.check(Codec);
    phase = "public q8";
    const calls = try public_q8.check(Codec);
    std.debug.print("adaptive literal real oracle: init_allocations={d}, init_oom={d}, emit_oom={d}, public_prepares={d}\n", .{ metrics.init_allocations, metrics.init_oom, metrics.emit_oom, calls });
}

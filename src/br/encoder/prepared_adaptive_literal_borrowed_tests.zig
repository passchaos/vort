//! Private adapters bind this new borrowed preparation oracle to real writers.
const std = @import("std");
const models = @import("prepared_adaptive_literal_borrowed_tests/models.zig");
const resources = @import("prepared_adaptive_literal_borrowed_tests/resources.zig");
const keys = @import("prepared_adaptive_literal_borrowed_tests/keys.zig");
const reuse = @import("prepared_adaptive_literal_borrowed_tests/reuse.zig");

pub fn check(comptime Codec: type) !void {
    var phase: []const u8 = "models";
    errdefer |err| std.debug.print("borrowed adaptive literal failed phase={s}: {s}\n", .{ phase, @errorName(err) });
    try models.check(Codec);
    phase = "resources";
    const metrics = try resources.check(Codec);
    phase = "keys";
    try keys.check(Codec);
    phase = "reuse";
    try reuse.check(Codec);
    std.debug.print("borrowed adaptive literal oracle: init_allocations={d}, init_oom={d}, emit_oom={d}\n", .{ metrics.init_allocations, metrics.init_oom, metrics.emit_oom });
}

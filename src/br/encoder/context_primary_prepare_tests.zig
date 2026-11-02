const std = @import("std");
const parity = @import("context_primary_prepare_tests/parity.zig");
const resources = @import("context_primary_prepare_tests/resources.zig");
const capture = @import("context_primary_prepare_tests/capture.zig");
const public_q8 = @import("context_primary_prepare_tests/public_q8.zig");

pub fn check(comptime Codec: type) !void {
    var phase: []const u8 = "parity";
    errdefer |err| std.debug.print("context primary failed phase={s} error={s}\n", .{ phase, @errorName(err) });
    std.debug.print("context primary phase: parity\n", .{});
    try parity.check(Codec);
    phase = "resources";
    std.debug.print("context primary phase: resources\n", .{});
    const failures = try resources.check(Codec);
    std.debug.print("context primary allocation sweep: count_allocations={d}, count_oom={d}, late_common_ready_oom={d}, emit_oom={d}\n", .{ failures.count_allocations, failures.count_oom, failures.late_common_ready_oom, failures.emit_oom });
    phase = "capture";
    std.debug.print("context primary phase: capture\n", .{});
    try capture.check(Codec);
    phase = "public q8";
    std.debug.print("context primary phase: public q8\n", .{});
    const selected = try public_q8.check(Codec);
    std.debug.print("context primary real oracle: count_allocations={d}, count_oom={d}, late_common_ready_oom={d}, emit_oom={d}, public_cold_successes={d}\n", .{ failures.count_allocations, failures.count_oom, failures.late_common_ready_oom, failures.emit_oom, selected });
}

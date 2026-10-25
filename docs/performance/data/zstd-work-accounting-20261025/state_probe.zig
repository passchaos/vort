const std = @import("std");
const zstd = @import("vort_zstd");
pub fn main() void {
    std.debug.print("{{\"tracked_bytes\":{d},\"untracked_bytes\":{d}}}\n", .{ zstd.benchmarkLiteralCostStateBytes(true), zstd.benchmarkLiteralCostStateBytes(false) });
}

const std = @import("std");
const cache = @import("cache");
const quality = @import("quality");
const LegacyEntry = struct { hash: u64, histogram: [256]u32, bit_cost: u64 };
const LegacyCache = struct { entries: [128]LegacyEntry = undefined, occupied: [2]u64 = @splat(0), hits: usize = 0, misses: usize = 0, cold_misses: usize = 0, conflict_misses: usize = 0 };
pub fn main() void {
 std.debug.print("pointer_bytes={d} legacy_cache_bytes={d} shared_cache_bytes={d} profile_bytes={d} quality_profile_bytes={d}\n", .{ @sizeOf(usize), @sizeOf(LegacyCache), @sizeOf(cache.Cache), @sizeOf(@TypeOf(@as(quality.ContextDetail, undefined).profile)), @sizeOf(quality.Profile) });
}

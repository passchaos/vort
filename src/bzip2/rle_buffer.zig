//! Incremental RLE1 storage with a per-buffer format capacity bound.
const std = @import("std");

pub const Error = std.mem.Allocator.Error || error{InvalidBzip2Stream};

/// Reserve additional bytes without changing the logical contents or length.
/// Existing capacity retained from a larger block limit remains reusable.
/// Growth requests are capped at limit; transient old/new allocations during
/// a moving growth are governed by the caller's allocator, not this bound.
pub fn ensure(allocator: std.mem.Allocator, block: *std.ArrayList(u8), additional: usize, limit: usize) Error!void {
    if (block.items.len > limit or additional > limit - block.items.len)
        return error.InvalidBzip2Stream;
    const needed = block.items.len + additional;
    if (needed <= block.capacity) return;
    const grown = block.capacity +| block.capacity / 2 +| 64;
    const target = @min(limit, @max(needed, grown));
    try block.ensureTotalCapacityPrecise(allocator, target);
}

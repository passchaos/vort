const std = @import("std");
const real = @import("real_sample.zig");
const t = std.testing;

pub fn contracts(comptime C: type) !void {
    try t.expectError(error.OutputLimitExceeded, C.puffDeflatePaddedAlloc(t.allocator, &real.raw, 0, real.raw.len * 8, real.puff.len - 1));
    try t.expectError(error.OutputLimitExceeded, C.puffDeflatePaddedAlloc(t.allocator, &real.raw, 0, real.raw.len * 8, 0));
    try t.expectError(error.TrailingData, C.puffDeflateAlloc(t.allocator, &real.raw, 0, real.raw.len * 8, 4096));
    try t.expectError(error.SizeMismatch, C.huffDeflateAlloc(t.allocator, &real.puff, 0, real.exact_bits + 1));
    try t.expectError(error.SizeMismatch, C.huffDeflateAlloc(t.allocator, &real.puff, 0, real.exact_bits - 1));
    try t.expectError(error.OutputTooSmall, C.huffDeflateAlloc(t.allocator, &real.puff, 0, 3));
    try t.expectError(error.IntegerOverflow, C.huffDeflateAlloc(t.allocator, &real.puff, 0, std.math.maxInt(u64)));
    try t.expectError(error.IntegerOverflow, C.huffDeflateAlloc(t.allocator, &real.puff, 1, std.math.maxInt(u64)));

    var baseline = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    const measured = try C.puffDeflatePaddedAlloc(baseline.allocator(), &real.raw, 0, real.raw.len * 8, real.puff.len);
    try t.expectEqualSlices(u8, &real.puff, measured.bytes);
    baseline.allocator().free(measured.bytes);
    try t.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
    for (0..baseline.alloc_index) |failure| {
        var heap = t.FailingAllocator.init(t.allocator, .{ .fail_index = failure, .resize_fail_index = 0 });
        try t.expectError(error.OutOfMemory, C.puffDeflatePaddedAlloc(heap.allocator(), &real.raw, 0, real.raw.len * 8, 4096));
        try t.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        const retry = try C.puffDeflatePaddedAlloc(t.allocator, &real.raw, 0, real.raw.len * 8, real.puff.len);
        defer t.allocator.free(retry.bytes);
        try t.expectEqualSlices(u8, &real.puff, retry.bytes);
    }
    var denied = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    try t.expectError(error.OutOfMemory, C.huffDeflateAlloc(denied.allocator(), &real.puff, 0, real.exact_bits));
    try t.expectEqual(denied.allocated_bytes, denied.freed_bytes);
    const retry = try C.huffDeflateAlloc(t.allocator, &real.puff, 0, real.exact_bits);
    defer t.allocator.free(retry);
    try t.expectEqualSlices(u8, &real.raw, retry);
}

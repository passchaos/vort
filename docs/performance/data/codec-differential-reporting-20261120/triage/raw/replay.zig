const std = @import("std");
const D = @import("deflate");
test "Raw captured strict suffix policy" {
    const t = std.testing;
    const cases = [_]struct { original: []const u8, mutated: []const u8 }{
        .{ .original = @embedFile("sample-0-original.bin"), .mutated = @embedFile("sample-0-mutated.bin") },
        .{ .original = @embedFile("sample-1-original.bin"), .mutated = @embedFile("sample-1-mutated.bin") },
    };
    for (cases) |case| {
        const original = try D.decodeRawAutoAlloc(t.allocator, case.original);
        defer t.allocator.free(original);
        try t.expectError(error.TrailingData, D.decodeRawAutoAlloc(t.allocator, case.mutated));
        const partial = try D.decodeRawAutoAllocPartial(t.allocator, case.mutated);
        defer partial.deinit(t.allocator);
        try t.expectEqual(case.original.len, partial.input_read);
        try t.expectEqualSlices(u8, original, partial.bytes);
    }
}

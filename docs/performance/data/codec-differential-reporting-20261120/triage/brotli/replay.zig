const std = @import("std");
const B = @import("br");
const t = std.testing;
test "Brotli captured strict suffix policy" {
    const streams = [_][]const u8{ @embedFile("replay-sample-0-mutated_wire.bin"), @embedFile("replay-sample-2-mutated_wire.bin") };
    for (streams) |wire| {
        try t.expectError(error.TrailingData, B.decodeStreamAlloc(t.allocator, wire));
        const prefix = try B.decodeStreamPrefixAlloc(t.allocator, wire);
        defer prefix.deinit(t.allocator);
        try t.expectEqual(@as(usize, 1), prefix.input_read);
        try t.expectEqual(@as(usize, 0), prefix.bytes.len);
    }
}
test "Brotli captured output headroom difference" {
    const wire = @embedFile("replay-sample-3-mutated_wire.bin");
    const expected = @embedFile("replay-sample-3-vort_output.bin");
    const decoded = try B.decodeStreamAlloc(t.allocator, wire);
    defer t.allocator.free(decoded);
    try t.expectEqualSlices(u8, expected, decoded);
    try t.expectEqual(@as(usize, 32775), decoded.len);
    try t.expectError(error.OutputLimitExceeded, B.decodeStreamAllocLimited(t.allocator, wire, 4097));
}
test "Brotli captured RAW attachment agrees with modern reference" {
    const dictionary = @embedFile("replay-sample-1-dictionary_raw.bin");
    const options: B.DecodeOptions = .{ .shared_dictionary = .{ .raw_prefixes = &.{dictionary} } };
    const original = try B.decodeStreamAllocWithOptions(t.allocator, @embedFile("replay-sample-1-original_wire.bin"), options);
    defer t.allocator.free(original);
    const changed = try B.decodeStreamAllocWithOptions(t.allocator, @embedFile("replay-sample-1-mutated_wire.bin"), options);
    defer t.allocator.free(changed);
    try t.expectEqualSlices(u8, @embedFile("replay-sample-1-source.bin"), original);
    try t.expectEqualSlices(u8, @embedFile("replay-sample-1-vort_output.bin"), changed);
    try t.expect(!std.mem.eql(u8, original, changed));
}

const std = @import("std");
const h = @import("helpers.zig");

pub fn contracts(comptime Z: type) !void {
    const expected = h.boundary + 3;
    for ([_]h.Tail{ .compressed, .window_edge }) |tail| {
        const wire = try h.wideAlloc(tail, expected, null);
        defer h.a.free(wire);
        try std.testing.expectEqual(expected, try Z.decodedFrameSize(wire));
        try std.testing.expectEqual(expected, try Z.decodedNativeFrameSize(wire));
        try std.testing.expectEqual(expected, try Z.decodedFrameSizeWithOptions(wire, .{ .expected_output_len = expected }));
        try std.testing.expectError(error.OutputLimitExceeded, Z.decodedFrameSizeLimited(wire, expected - 1));
    }
    const invalid = try h.wideAlloc(.beyond_window, expected, null);
    defer h.a.free(invalid);
    try std.testing.expectError(error.InvalidMatch, Z.decodedFrameSize(invalid));
    // Concatenation starts fresh history; a match-only second frame cannot
    // borrow the >4-GiB output from the first frame.
    var fresh: std.ArrayList(u8) = .empty;
    defer fresh.deinit(h.a);
    try h.header(&fresh, 3, null);
    try h.block(&fresh, 2, 7, true);
    try fresh.appendSlice(h.a, &.{ 0, 1, 0x54, 0, 2, 0, 7 });
    try std.testing.expectError(error.InvalidMatch, Z.decodedNativeFrameSize(fresh.items));
    const first = try h.wideAlloc(.compressed, expected, null);
    defer h.a.free(first);
    var concat: std.ArrayList(u8) = .empty;
    defer concat.deinit(h.a);
    try concat.appendSlice(h.a, first);
    try concat.appendSlice(h.a, fresh.items);
    try std.testing.expectError(error.InvalidMatch, Z.decodedNativeConcatenatedFrameSize(concat.items));

    // An external dictionary remains available before frame output fills
    // the window, including a single-segment FCS=3 with an offset of 4.
    const dictionary = Z.NativeDictionary.init(42, "abcd");
    const dictionary_frame = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0x01, 0, 42, 0x3d, 0, 0, 0, 1, 0x54, 0, 2, 0, 7 };
    try std.testing.expectEqual(@as(@import("../../core.zig").StreamCount, 3), try Z.decodedNativeFrameSizeWithDictionary(&dictionary_frame, dictionary));

    // Validate the exact compressed-block shape against an actual materialized
    // small decode, then parse 32K such blocks across the wide count boundary.
    const small_compressed = try h.compressedAlloc(1);
    defer h.a.free(small_compressed);
    const output = try Z.decodeFrameAllocWithOptions(h.a, small_compressed, .{});
    defer h.a.free(output);
    try std.testing.expectEqual(h.block_len + 1, output.len);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 'R'), byte);
    const all_compressed = try h.compressedAlloc(h.block_count);
    defer h.a.free(all_compressed);
    try std.testing.expectEqual(h.boundary + 1, try Z.decodedFrameSize(all_compressed));
    try std.testing.expectEqual(h.boundary + 1, try Z.decodedNativeFrameSizeLimited(all_compressed, h.boundary + 1));
    try std.testing.expectError(error.OutputLimitExceeded, Z.decodedNativeFrameSizeLimited(all_compressed, h.boundary));
}

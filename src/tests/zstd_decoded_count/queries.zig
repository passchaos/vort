const std = @import("std");
const Count = @import("../../core.zig").StreamCount;
const h = @import("helpers.zig");

pub fn contracts(comptime Z: type) !void {
    const expected = h.boundary + 3;
    const wire = try h.wideAlloc(.raw, null, null);
    defer h.a.free(wire);
    try std.testing.expect(wire.len < 132 * 1024);
    try std.testing.expect(@TypeOf(try Z.decodedFrameSize(wire)) == Count);
    try std.testing.expectEqual(expected, try Z.decodedFrameSize(wire));
    try std.testing.expectEqual(expected, try Z.decodedNativeFrameSize(wire));
    try std.testing.expectEqual(expected, try Z.decodedRawOrRleFrameSize(wire));
    try std.testing.expectEqual(expected, try Z.decodedFrameSizeLimited(wire, expected));
    try std.testing.expectEqual(expected, try Z.decodedNativeFrameSizeLimited(wire, expected));
    try std.testing.expectError(error.OutputLimitExceeded, Z.decodedFrameSizeLimited(wire, expected - 1));
    try std.testing.expectError(error.OutputLimitExceeded, Z.decodedNativeFrameSizeLimited(wire, expected - 1));
    var profile: Z.DecodeMemoryProfile = .{};
    const options: Z.FrameDecodeOptions = .{
        .max_output_len = expected,
        .expected_output_len = expected,
        .max_total_working_memory = 0,
        .memory_profile = &profile,
    };
    try std.testing.expectEqual(expected, try Z.decodedFrameSizeWithOptions(wire, options));
    try std.testing.expectEqual(expected, try Z.decodedFrameSizeWithOptions(wire[4..], .{ .format = .magicless, .max_output_len = expected, .expected_output_len = expected }));
    try std.testing.expectError(error.OutputLimitExceeded, Z.decodedFrameSizeWithOptions(wire, .{ .max_output_len = expected - 1 }));
    try std.testing.expectError(error.SizeMismatch, Z.decodedFrameSizeWithOptions(wire, .{ .expected_output_len = expected + 1 }));
    try std.testing.expect(!profile.available);

    var denied = std.testing.FailingAllocator.init(h.a, .{ .fail_index = 0 });
    var decoder = Z.NativeFrameDecoder.initWithOptions(denied.allocator(), options);
    defer decoder.deinit();
    try std.testing.expectEqual(expected, try decoder.decodedSize(wire));
    try std.testing.expectEqual(expected, try decoder.decodedSizeWithOptions(wire, options));
    try std.testing.expectEqual(expected, try decoder.decodedSizeLimited(wire, expected));
    try std.testing.expect(!decoder.memorySnapshot().available);
    try std.testing.expectEqual(@as(usize, 0), denied.alloc_index);
    try std.testing.expect(!profile.available);

    const chunks = [_][]const u8{ wire[0..7], wire[7 .. wire.len - 2], wire[wire.len - 2 ..] };
    const scratch = try h.a.alloc(u8, wire.len);
    defer h.a.free(scratch);
    try std.testing.expectEqual(expected, try Z.decodedFrameChunksSize(&chunks, scratch));
    try std.testing.expectEqual(expected, try Z.decodedNativeFrameChunksSize(&chunks, scratch));
    try std.testing.expectEqual(expected, try Z.decodedFrameChunksSizeLimited(&chunks, scratch, expected));
    try std.testing.expectEqual(expected, try decoder.decodedChunksSizeLimited(&chunks, scratch, expected));
    try std.testing.expectError(error.OutputLimitExceeded, Z.decodedFrameChunksSizeLimited(&chunks, scratch, expected - 1));
    try std.testing.expectError(error.OutputTooSmall, Z.decodedFrameChunksSize(&chunks, scratch[0 .. scratch.len - 1]));

    const small = try h.smallAlloc(null);
    defer h.a.free(small);
    var concatenated: std.ArrayList(u8) = .empty;
    defer concatenated.deinit(h.a);
    try concatenated.appendSlice(h.a, wire);
    try concatenated.appendSlice(h.a, &.{ 0x50, 0x2a, 0x4d, 0x18, 1, 0, 0, 0, 's' });
    try concatenated.appendSlice(h.a, small);
    const total = expected + 3;
    decoder.options.expected_output_len = total;
    try std.testing.expectEqual(total, try Z.decodedConcatenatedFrameSize(concatenated.items));
    try std.testing.expectEqual(total, try Z.decodedNativeConcatenatedFrameSize(concatenated.items));
    try std.testing.expectEqual(total, try Z.decodedConcatenatedFrameSizeLimited(concatenated.items, total));
    try std.testing.expectEqual(total, try decoder.decodedConcatenatedSizeLimited(concatenated.items, total));
    try std.testing.expectError(error.OutputLimitExceeded, Z.decodedConcatenatedFrameSizeLimited(concatenated.items, total - 1));
    const concat_chunks = [_][]const u8{ wire, concatenated.items[wire.len..] };
    const joined = try h.a.alloc(u8, concatenated.items.len);
    defer h.a.free(joined);
    try std.testing.expectEqual(total, try Z.decodedConcatenatedFrameChunksSizeLimited(&concat_chunks, joined, total));
    try std.testing.expectEqual(total, try decoder.decodedConcatenatedChunksSizeLimited(&concat_chunks, joined, total));
}

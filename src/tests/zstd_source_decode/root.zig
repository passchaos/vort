const std = @import("std");

fn buildFrame(buffer: []u8) []const u8 {
    const magic: u32 = 0xfd2f_b528;
    std.mem.writeInt(u32, buffer[0..4], magic, .little);
    buffer[4] = 0x00;
    buffer[5] = 0x00;
    const block: u64 = (@as(u64, 4) << 3) | 1;
    buffer[6] = @truncate(block);
    buffer[7] = @truncate(block >> 8);
    buffer[8] = @truncate(block >> 16);
    @memcpy(buffer[9..13], "root");
    return buffer[0..13];
}

pub fn contracts(comptime Support: type) !void {
    var frame_storage: [64]u8 = undefined;
    const frame = buildFrame(&frame_storage);
    var slice_source = Support.SliceByteSource{ .bytes = frame };
    const source = slice_source.source();

    const info = try Support.zstdInspectSourceFrame(source, .{});
    try std.testing.expectEqual(
        @as(?u64, 4),
        if (info.decoded_size) |size| @as(u64, @intCast(size)) else null,
    );
    try std.testing.expectEqual(@as(u64, 13), info.frame_end_offset);

    var history: [1024]u8 = undefined;
    var staging: [1024]u8 = undefined;
    var literal_page: [9]u8 = undefined;
    var sequence_page: [9]u8 = undefined;
    const workspace: Support.ZstdSourceFrameWorkspace = .{
        .history = &history,
        .staging = &staging,
        .literal_page = &literal_page,
        .sequence_page = &sequence_page,
    };

    var output: [4]u8 = undefined;
    const result = try Support.zstdDecodeSourceFrameInto(
        source,
        &output,
        workspace,
        .{},
    );
    try std.testing.expectEqual(
        @as(u64, 4),
        @as(u64, @intCast(result.decoded_len)),
    );
    try std.testing.expectEqualStrings("root", &output);

    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(std.testing.allocator);
    _ = try Support.zstdDecodeSourceFrameAppend(
        std.testing.allocator,
        source,
        workspace,
        &list,
        .{},
    );
    try std.testing.expectEqualStrings("root", list.items);

    const allocated = try Support.zstdDecodeSourceFrameAlloc(
        std.testing.allocator,
        source,
        workspace,
        .{},
    );
    defer std.testing.allocator.free(allocated);
    try std.testing.expectEqualStrings("root", allocated);

    try std.testing.expectEqual(
        @as(?u64, 4),
        if (try Support.zstdSourceFrameDecodedSize(source, .{})) |size|
            @as(u64, @intCast(size))
        else
            null,
    );
}

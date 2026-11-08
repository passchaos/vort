const std = @import("std");

fn buildFrame(buffer: []u8, payload: []const u8) []const u8 {
    const magic: u32 = 0xfd2f_b528;
    std.mem.writeInt(u32, buffer[0..4], magic, .little);
    buffer[4] = 0x00;
    buffer[5] = 0x00;
    const block: u64 = (@as(u64, payload.len) << 3) | 1;
    buffer[6] = @truncate(block);
    buffer[7] = @truncate(block >> 8);
    buffer[8] = @truncate(block >> 16);
    @memcpy(buffer[9..][0..payload.len], payload);
    return buffer[0 .. 9 + payload.len];
}

fn appendSkippable(buffer: []u8, payload: []const u8) usize {
    std.mem.writeInt(u32, buffer[0..4], 0x184d_2a52, .little);
    std.mem.writeInt(u32, buffer[4..8], @intCast(payload.len), .little);
    @memcpy(buffer[8..][0..payload.len], payload);
    return 8 + payload.len;
}

fn buildStream(buffer: []u8) []const u8 {
    var len: usize = 0;
    len += buildFrame(buffer[len..], "root").len;
    len += appendSkippable(buffer[len..], "s");
    len += buildFrame(buffer[len..], "tail").len;
    return buffer[0..len];
}

pub fn contracts(comptime Support: type) !void {
    var frame_storage: [64]u8 = undefined;
    const frame = buildFrame(&frame_storage, "root");
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

    var stream_storage: [128]u8 = undefined;
    const stream = buildStream(&stream_storage);
    var stream_source = Support.SliceByteSource{ .bytes = stream };
    const stream_view = stream_source.source();
    const stream_info = try Support.zstdInspectSourceStream(stream_view, .{});
    try std.testing.expectEqual(
        @as(?u64, 8),
        if (stream_info.total_decoded) |size| @as(u64, @intCast(size)) else null,
    );
    try std.testing.expectEqual(@as(usize, 2), stream_info.data_frames);
    try std.testing.expectEqual(@as(usize, 1), stream_info.skippable_frames);
    try std.testing.expectEqual(
        @as(u64, @intCast(stream.len)),
        stream_info.stream_end_offset,
    );

    var stream_output: [8]u8 = undefined;
    const stream_result = try Support.zstdDecodeSourceStreamInto(
        stream_view,
        &stream_output,
        workspace,
        .{},
    );
    try std.testing.expectEqual(
        @as(u64, 8),
        @as(u64, @intCast(stream_result.decoded_len)),
    );
    try std.testing.expectEqual(@as(usize, 2), stream_result.data_frames);
    try std.testing.expectEqual(@as(usize, 1), stream_result.skippable_frames);
    try std.testing.expectEqualStrings("roottail", &stream_output);

    const stream_allocated = try Support.zstdDecodeSourceStreamAlloc(
        std.testing.allocator,
        stream_view,
        workspace,
        .{},
    );
    defer std.testing.allocator.free(stream_allocated);
    try std.testing.expectEqualStrings("roottail", stream_allocated);

    var cursor_source = Support.SliceByteSource{ .bytes = stream };
    var cursor = try Support.ZstdSourceStreamCursor.init(
        cursor_source.source(),
        .standard,
    );
    var cursor_output: [8]u8 = undefined;
    var cursor_written: usize = 0;
    var cursor_skippables: usize = 0;
    while (try cursor.next()) |element| {
        switch (element) {
            .skippable => |skippable| {
                try std.testing.expectEqual(@as(u4, 2), skippable.skippable_id);
                try std.testing.expectEqual(@as(u64, 1), skippable.payload_len);
                cursor_skippables += 1;
            },
            .data => {
                const cursor_result = try cursor.decodeInto(
                    cursor_output[cursor_written..],
                    workspace,
                    .{},
                );
                cursor_written += @intCast(cursor_result.decoded_len);
            },
        }
    }
    try std.testing.expectEqual(@as(usize, 1), cursor_skippables);
    try std.testing.expectEqualStrings(
        "roottail",
        cursor_output[0..cursor_written],
    );
    try std.testing.expectEqual(
        @as(u64, @intCast(stream.len)),
        cursor.offset(),
    );
}

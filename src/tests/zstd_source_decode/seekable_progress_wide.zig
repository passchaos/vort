//! Exercise the public retry coordinates on 32-bit targets without large
//! allocations. Only the selected real frames and seek table are backed.
const std = @import("std");

const base: u64 = (1 << 32) + 8;
const first = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0x20, 3, 0x19, 0, 0, 'a', 'b', 'c' };
const second = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0x20, 3, 0x19, 0, 0, 'd', 'e', 'f' };

const SparseSource = struct {
    bytes: []const u8,
    read_from: usize = first.len + second.len,
    read_until: usize = std.math.maxInt(usize),

    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *SparseSource = @ptrCast(@alignCast(raw));
        if (offset < base) return error.SourceReadFailed;
        const start = std.math.cast(usize, offset - base) orelse return error.SourceReadFailed;
        const end = @min(self.bytes.len, self.read_until);
        if (start < self.read_from or start > end or output.len > end - start)
            return error.SourceReadFailed;
        @memcpy(output, self.bytes[start..][0..output.len]);
        return output.len;
    }
};

pub fn contracts(comptime Support: type) !void {
    const t = std.testing;
    const sizes = [_]Support.ZstdNativeSeekTableFrameSize{
        .{ .compressed_size = std.math.maxInt(u32), .decompressed_size = std.math.maxInt(u32) },
        .{ .compressed_size = 9, .decompressed_size = 9 },
        .{ .compressed_size = first.len, .decompressed_size = 3 },
        .{ .compressed_size = second.len, .decompressed_size = 3 },
    };
    const table_start = first.len + second.len;
    var tail: [table_start + 64]u8 = undefined;
    @memcpy(tail[0..first.len], &first);
    @memcpy(tail[first.len..table_start], &second);
    const table_len = try Support.zstdEncodeNativeSeekTableInto(&sizes, false, tail[table_start..]);
    var guarded: SparseSource = .{ .bytes = tail[0 .. table_start + table_len] };
    const source: Support.ByteSource = .{
        .context = &guarded,
        .len = base + guarded.bytes.len,
        .read_at = SparseSource.readAt,
        .max_read_size = 3,
    };
    const table = try Support.zstdOpenSourceSeekTable(source);
    var entries: [sizes.len]Support.ZstdNativeSeekTableEntry = undefined;
    const index = try table.buildIndex(&entries);

    var history: [3]u8 = undefined;
    var staging: [3]u8 = undefined;
    var literal_page: [9]u8 = undefined;
    var sequence_page: [9]u8 = undefined;
    const workspace: Support.ZstdSourceFrameWorkspace = .{
        .history = &history,
        .staging = &staging,
        .literal_page = &literal_page,
        .sequence_page = &sequence_page,
    };
    var scratch: [3]u8 = undefined;
    var output: [5]u8 = @splat(0xa5);
    const decode = Support.zstdDecodeSourceSeekableRangeIntoWithProgress;
    guarded.read_from = 0;
    guarded.read_until = first.len + 6; // second header readable, its first block isn't
    const rejected = switch (decode(index, base + 1, &output, workspace, &scratch, .{})) {
        .failed => |failure| failure,
        .complete => return error.TestUnexpectedResult,
    };
    try t.expectEqual(error.SourceReadFailed, rejected.err);
    try t.expectEqual(@as(usize, 2), rejected.progress.output_written);
    try t.expectEqual(base + 3, rejected.progress.next_decoded_offset);
    try t.expectEqual(@as(usize, 1), rejected.progress.frames_committed);
    const failed_frame = rejected.frame orelse return error.TestUnexpectedResult;
    try t.expectEqual(@as(u32, 3), failed_frame.frame_index);
    try t.expectEqual(base + first.len, failed_frame.compressed_offset);
    try t.expectEqual(@as(?u32, 0), failed_frame.dictionary_id);
    try t.expectEqualSlices(u8, &.{ 'b', 'c', 0xa5, 0xa5, 0xa5 }, &output);

    guarded.read_from = first.len;
    guarded.read_until = table_start;
    const resumed = switch (decode(index, rejected.progress.next_decoded_offset, output[rejected.progress.output_written..], workspace, &scratch, .{})) {
        .complete => |progress| progress,
        .failed => |failure| return failure.err,
    };
    try t.expectEqual(@as(usize, 3), resumed.output_written);
    try t.expectEqual(base + 6, resumed.next_decoded_offset);
    try t.expectEqual(@as(usize, 1), resumed.frames_committed);
    try t.expectEqualStrings("bcdef", &output);
}

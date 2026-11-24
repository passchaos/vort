const std = @import("std");
const t = std.testing;

// Stored 'A', an empty stored member, and fixed-Huffman 'B'.
const header = "\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff";
const first = header ++ "\x01\x01\x00\xfe\xffA\x8b\x9e\xd9\xd3\x01\x00\x00\x00";
const empty = header ++ "\x01\x00\x00\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00";
const last = header ++ "\x73\x02\x00\x31\xcf\xd0\x4a\x01\x00\x00\x00";
const members = first ++ empty ++ last;
const plain = "AB";
const zeros = "\x00" ** 17;
const padded = members ++ zeros;
// The last footer spans two pages, and the second page also contains padding.
// The source ends partway through a later page.
const page_len = 9;

const SourceContext = struct {
    bytes: []const u8,
    request_end: usize,
    max_return: usize = 1,
    delivered_end: usize = 0,
    require_sequential: bool = false,

    fn init(bytes: []const u8) SourceContext {
        return .{ .bytes = bytes, .request_end = bytes.len };
    }

    fn source(self: *SourceContext, comptime V: type, len: usize) V.ByteSource {
        return .{ .context = self, .len = len, .read_at = readAt };
    }

    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *SourceContext = @ptrCast(@alignCast(raw));
        const start = std.math.cast(usize, offset) orelse return error.SourceReadFailed;
        // Refuse requests extending beyond the boundary even for short reads.
        if (output.len > page_len or start > self.request_end or output.len > self.request_end - start)
            return error.SourceReadFailed;
        if (self.require_sequential and start != self.delivered_end) return error.SourceReadFailed;
        if (start >= self.bytes.len) return 0;
        const n = @min(self.max_return, output.len, self.bytes.len - start);
        @memcpy(output[0..n], self.bytes[start..][0..n]);
        self.delivered_end = @max(self.delivered_end, start + n);
        return n;
    }
};

pub fn contracts(comptime V: type) !void {
    var history: [32 * 1024]u8 = undefined;
    var page: [page_len]u8 = undefined;
    var discard: [1]u8 = undefined;
    const workspace: V.GzipSourceIndexWorkspace = .{ .history = &history, .input_page = &page, .discard = &discard };
    var entries: [2]V.GzipSourceIndexEntry = undefined;
    const options: V.GzipSourceIndexOptions = .{
        .allow_trailing_zero_padding = true,
        .checkpoint_spacing = 0,
        .max_members = 3,
        .max_output_len = plain.len,
        .max_header_metadata_len = 0,
    };

    try t.expect(!(V.GzipSourceIndexOptions{}).allow_trailing_zero_padding);
    var strict = SourceContext.init(padded);
    try t.expectError(error.BadGzipHeader, V.buildGzipSourceIndex(strict.source(V, padded.len), &entries, &.{}, workspace, .{}));

    var unpadded = SourceContext.init(members);
    const unpadded_index = try V.buildGzipSourceIndex(unpadded.source(V, members.len), &entries, &.{}, workspace, options);
    try expectIndex(V, unpadded_index, members.len);

    for ([_]usize{ 1, page_len }) |max_return| {
        // Bytes outside the declared source must not affect padding validation.
        var context: SourceContext = .{
            .bytes = padded ++ "!",
            .request_end = padded.len,
            .max_return = max_return,
            .require_sequential = true,
        };
        const index = try V.buildGzipSourceIndex(context.source(V, padded.len), &entries, &.{}, workspace, options);
        try expectIndex(V, index, padded.len);
        try t.expectEqual(padded.len, context.delivered_end);

        // Neither range API may request any padding, even as part of a page
        // ending beyond the final footer. Verified reads must reach that footer.
        context.request_end = members.len;
        context.require_sequential = false;
        context.delivered_end = 0;
        var output: [plain.len]u8 = undefined;
        try expectRange(V, index.decodeRangeInto(0, &output, workspace), &output);
        @memset(&output, 0xa5);
        var stage: [1]u8 = undefined;
        context.delivered_end = 0;
        try expectRange(V, index.decodeVerifiedRangeInto(0, &output, workspace, &stage), &output);
        try t.expectEqual(members.len, context.delivered_end);
    }

    try expectCheckpoint(V, &entries, workspace);
    try rejectedSuffixes(V, &entries, workspace, options);

    var empty_only = SourceContext.init(empty ++ zeros);
    const empty_options: V.GzipSourceIndexOptions = .{
        .allow_trailing_zero_padding = true,
        .max_members = 1,
        .max_output_len = 0,
        .max_header_metadata_len = 0,
    };
    const empty_index = try V.buildGzipSourceIndex(empty_only.source(V, empty_only.bytes.len), &.{}, &.{}, workspace, empty_options);
    try t.expectEqual(@as(V.StreamCount, 1), empty_index.members_verified);
    try t.expectEqual(@as(V.StreamCount, 0), empty_index.decoded_size);
    try t.expectEqual(@as(usize, 0), empty_index.entries.len);
    try t.expectEqual(empty_only.bytes.len, empty_only.delivered_end);
}

fn expectIndex(comptime V: type, index: V.GzipSourceIndex, source_len: V.StreamCount) !void {
    const Count = V.StreamCount;
    try t.expectEqual(source_len, index.source.len);
    try t.expectEqual(@as(Count, 3), index.members_verified);
    try t.expectEqual(@as(Count, plain.len), index.decoded_size);
    try t.expectEqual(@as(usize, 2), index.entries.len);
    try t.expectEqual(@as(usize, 0), index.checkpoint_history.len);
    for (index.entries, [_]Count{ 0, first.len + empty.len }, [_]Count{ first.len, members.len }, 0..) |entry, start, end, i| {
        try t.expect(entry.boundary == .member);
        try t.expectEqual(start, entry.compressedOffset());
        try t.expectEqual(end, entry.compressed_end);
        try t.expectEqual(@as(Count, @intCast(i)), entry.decodedOffset());
        try t.expectEqual(@as(Count, @intCast(i + 1)), entry.decoded_end);
    }
}

fn expectRange(comptime V: type, outcome: V.GzipSourceRangeOutcome, output: []const u8) !void {
    try t.expect(outcome == .complete);
    try t.expectEqual(plain.len, outcome.complete.output_written);
    try t.expectEqual(@as(V.StreamCount, plain.len), outcome.complete.next_decoded_offset);
    try t.expectEqualStrings(plain, output);
}

fn expectCheckpoint(comptime V: type, entries: []V.GzipSourceIndexEntry, workspace: V.GzipSourceIndexWorkspace) !void {
    const first_block = "\x00\x01\x00\xfe\xffA";
    const final_block = "\x01\x01\x00\xfe\xffB";
    const member = header ++ first_block ++ final_block ++ "\x07\x4c\x69\x30\x02\x00\x00\x00";
    var context = SourceContext.init(member ++ zeros);
    var saved: [1]u8 = undefined;
    const index = try V.buildGzipSourceIndex(context.source(V, context.bytes.len), entries, &saved, workspace, .{
        .allow_trailing_zero_padding = true,
        .checkpoint_spacing = 0,
        .max_members = 1,
        .max_output_len = plain.len,
    });
    try t.expectEqual(@as(usize, 2), index.entries.len);
    try t.expectEqual(@as(V.StreamCount, member.len), index.entries[1].compressed_end);
    try t.expectEqual(@as(V.StreamCount, header.len + first_block.len), index.entries[1].compressedOffset());
    try t.expect(index.entries[1].boundary == .block);
    try t.expectEqualStrings("A", index.entries[1].boundary.block.history);

    context.request_end = member.len - 8;
    var output: [1]u8 = undefined;
    const range = index.decodeRangeInto(1, &output, workspace);
    try t.expect(range == .complete);
    try t.expectEqualStrings("B", &output);
}

fn rejectedSuffixes(comptime V: type, entries: []V.GzipSourceIndexEntry, workspace: V.GzipSourceIndexWorkspace, options: V.GzipSourceIndexOptions) !void {
    const bad_successor = "\x1f\x8b\x00" ++ "\x00" ** 7;
    var corrupt_empty = (empty ++ zeros).*;
    corrupt_empty[empty.len - 8] ^= 1;
    for ([_]struct { bytes: []const u8, err: anyerror }{
        .{ .bytes = zeros, .err = error.BadGzipHeader },
        .{ .bytes = &corrupt_empty, .err = error.ChecksumMismatch },
        .{ .bytes = padded ++ "!", .err = error.TrailingData },
        .{ .bytes = first ++ zeros ++ last, .err = error.TrailingData },
        .{ .bytes = first ++ bad_successor ++ zeros, .err = error.BadGzipHeader },
    }) |case| {
        var context = SourceContext.init(case.bytes);
        try t.expectError(case.err, V.buildGzipSourceIndex(context.source(V, case.bytes.len), entries, &.{}, workspace, options));
    }

    // A failure or unexpected physical EOF late in the declared zero suffix
    // invalidates the build even though all members matched their limits.
    var fault: SourceContext = .{ .bytes = padded, .request_end = padded.len - 1 };
    try t.expectError(error.SourceReadFailed, V.buildGzipSourceIndex(fault.source(V, padded.len), entries, &.{}, workspace, options));
    var short: SourceContext = .{ .bytes = padded[0 .. padded.len - 1], .request_end = padded.len };
    try t.expectError(error.TruncatedFrame, V.buildGzipSourceIndex(short.source(V, padded.len), entries, &.{}, workspace, options));
}

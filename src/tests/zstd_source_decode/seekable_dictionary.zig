const std = @import("std");

// Full independent dictionaries and checksummed frames from upstream Zstd
// 1.6.0. tools/zstd/source_seekable_dictionary_fixture.c reproduces the bytes,
// verifies exact decoding, and rejects missing and ID-matched wrong dictionaries.
// BEGIN UPSTREAM FIXTURES
const plain_a = "alpha/warehouse/temperature=301.25K;pressure=1000hPa;" ** 3;
const header_a = 10;
const dict_a = [_]u8{
    0x37, 0xa4, 0x30, 0xec, 0x78, 0x56, 0x34, 0x12, 0x25, 0x10, 0x30, 0xbc,
    0xd1, 0x01, 0xf0, 0x17, 0x69, 0xc3, 0x5f, 0xa4, 0x0d, 0x7f, 0x91, 0x36,
    0xfc, 0x59, 0xf6, 0xdb, 0x6f, 0xbf, 0xfd, 0xf6, 0xdb, 0x3f, 0x48, 0xb3,
    0xf7, 0x96, 0x52, 0x4a, 0x29, 0x31, 0xed, 0xdd, 0x4c, 0x0d, 0xf3, 0x04,
    0x00, 0x00, 0x00, 0x34, 0xc5, 0xcd, 0x06, 0x00, 0x00, 0x04, 0x80, 0x8a,
    0x02, 0x80, 0x0f, 0xc0, 0xcc, 0xce, 0xc1, 0x14, 0x00, 0x30, 0x28, 0x00,
    0x00, 0x00, 0x00, 0x20, 0x71, 0x00, 0x00, 0x00, 0x80, 0x01, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xd4, 0x12, 0xeb, 0x23, 0x24, 0x39, 0x21, 0x84, 0x88, 0x88, 0x88, 0x88,
    0x88, 0x88, 0x88, 0x88, 0x24, 0x49, 0x92, 0x0e, 0x01, 0x00, 0x00, 0x00,
    0x04, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x65, 0x3d, 0x31, 0x30,
    0x30, 0x30, 0x68, 0x50, 0x61, 0x3b, 0x3a, 0x62, 0x75, 0x63, 0x6b, 0x65,
    0x74, 0x3d, 0x30, 0x3b, 0x73, 0x65, 0x72, 0x69, 0x61, 0x6c, 0x3d, 0x30,
    0x31, 0x37, 0x39, 0x36, 0x3b, 0x0a, 0x69, 0x64, 0x3d, 0x30, 0x39, 0x32,
    0x2f, 0x30, 0x34, 0x3b, 0x61, 0x6c, 0x70, 0x68, 0x61, 0x2f, 0x65, 0x3d,
    0x31, 0x30, 0x30, 0x30, 0x68, 0x50, 0x61, 0x3b, 0x3a, 0x62, 0x75, 0x63,
    0x6b, 0x65, 0x74, 0x3d, 0x33, 0x3b, 0x73, 0x65, 0x72, 0x69, 0x61, 0x6c,
    0x3d, 0x30, 0x31, 0x33, 0x32, 0x31, 0x3b, 0x0a, 0x69, 0x64, 0x3d, 0x30,
    0x36, 0x37, 0x2f, 0x30, 0x31, 0x3b, 0x61, 0x6c, 0x70, 0x68, 0x61, 0x2f,
    0x65, 0x3d, 0x31, 0x30, 0x30, 0x30, 0x68, 0x50, 0x61, 0x3b, 0x3a, 0x62,
    0x75, 0x63, 0x6b, 0x65, 0x74, 0x3d, 0x34, 0x3b, 0x73, 0x65, 0x72, 0x69,
    0x61, 0x6c, 0x3d, 0x30,
};
const frame_a = [_]u8{
    0x28, 0xb5, 0x2f, 0xfd, 0x27, 0x78, 0x56, 0x34, 0x12, 0x9f, 0x9d, 0x01,
    0x00, 0x34, 0x02, 0x77, 0x61, 0x72, 0x65, 0x68, 0x6f, 0x75, 0x73, 0x65,
    0x2f, 0x74, 0x65, 0x6d, 0x70, 0x65, 0x72, 0x61, 0x74, 0x75, 0x72, 0x65,
    0x3d, 0x33, 0x30, 0x31, 0x2e, 0x32, 0x35, 0x4b, 0x3b, 0x70, 0x72, 0x65,
    0x73, 0x73, 0x04, 0xf0, 0x07, 0x63, 0x52, 0x5e, 0x7f, 0xed, 0x88, 0xab,
    0x60, 0x39, 0xfe, 0x03, 0x4e, 0x7d, 0x2b, 0xc3,
};
const plain_b = "bravo/drive/events=write,append,commit;sector=65536;" ** 3;
const header_b = 10;
const dict_b = [_]u8{
    0x37, 0xa4, 0x30, 0xec, 0x89, 0x67, 0x45, 0x23, 0x25, 0x10, 0x30, 0xbc,
    0xd1, 0x01, 0xf0, 0x17, 0x69, 0xc3, 0x5f, 0xa4, 0x0d, 0x7f, 0x91, 0x36,
    0xfc, 0x59, 0xf6, 0xdb, 0x6f, 0xbf, 0xfd, 0xf6, 0xdb, 0x3f, 0x48, 0xb3,
    0xe5, 0x96, 0x52, 0x6e, 0x29, 0x31, 0xed, 0xdd, 0x4c, 0x0d, 0x13, 0x05,
    0x00, 0x00, 0x00, 0xb4, 0x45, 0x1d, 0x00, 0x00, 0x00, 0x04, 0xa0, 0x8a,
    0x02, 0x40, 0x0f, 0x00, 0xcb, 0x10, 0xd6, 0x00, 0x00, 0x00, 0x14, 0x00,
    0x00, 0x00, 0x20, 0x81, 0x00, 0x00, 0x00, 0x80, 0x01, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0xde, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xd4, 0x32, 0xeb, 0x23, 0x20, 0x39, 0x21, 0x84, 0x88, 0x88, 0x88, 0x88,
    0x88, 0x88, 0x88, 0x88, 0x24, 0x49, 0x92, 0x0e, 0x01, 0x00, 0x00, 0x00,
    0x04, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x74, 0x6f, 0x72, 0x3d,
    0x36, 0x35, 0x35, 0x33, 0x36, 0x3b, 0x3a, 0x62, 0x75, 0x63, 0x6b, 0x65,
    0x74, 0x3d, 0x32, 0x3b, 0x73, 0x65, 0x72, 0x69, 0x61, 0x6c, 0x3d, 0x30,
    0x31, 0x35, 0x36, 0x38, 0x3b, 0x0a, 0x69, 0x64, 0x3d, 0x30, 0x38, 0x30,
    0x2f, 0x30, 0x33, 0x3b, 0x62, 0x72, 0x61, 0x76, 0x6f, 0x2f, 0x74, 0x6f,
    0x72, 0x3d, 0x36, 0x35, 0x35, 0x33, 0x36, 0x3b, 0x3a, 0x62, 0x75, 0x63,
    0x6b, 0x65, 0x74, 0x3d, 0x33, 0x3b, 0x73, 0x65, 0x72, 0x69, 0x61, 0x6c,
    0x3d, 0x30, 0x31, 0x33, 0x32, 0x31, 0x3b, 0x0a, 0x69, 0x64, 0x3d, 0x30,
    0x36, 0x37, 0x2f, 0x30, 0x31, 0x3b, 0x62, 0x72, 0x61, 0x76, 0x6f, 0x2f,
    0x74, 0x6f, 0x72, 0x3d, 0x36, 0x35, 0x35, 0x33, 0x36, 0x3b, 0x3a, 0x62,
    0x75, 0x63, 0x6b, 0x65, 0x74, 0x3d, 0x31, 0x3b, 0x73, 0x65, 0x72, 0x69,
    0x61, 0x6c, 0x3d, 0x30,
};
const frame_b = [_]u8{
    0x28, 0xb5, 0x2f, 0xfd, 0x27, 0x89, 0x67, 0x45, 0x23, 0x9c, 0x95, 0x01,
    0x00, 0x44, 0x02, 0x64, 0x72, 0x69, 0x76, 0x65, 0x2f, 0x65, 0x76, 0x65,
    0x6e, 0x74, 0x73, 0x3d, 0x77, 0x72, 0x69, 0x74, 0x65, 0x2c, 0x61, 0x70,
    0x70, 0x65, 0x6e, 0x64, 0x2c, 0x63, 0x6f, 0x6d, 0x6d, 0x69, 0x74, 0x3b,
    0x73, 0x65, 0x63, 0x03, 0xf0, 0xe5, 0x62, 0x02, 0xc0, 0x04, 0xb0, 0x60,
    0x08, 0xfe, 0x03, 0x27, 0xce, 0xbb, 0x27,
};
// END UPSTREAM FIXTURES

const Span = struct {
    start: usize,
    end: usize,

    fn prefix(self: Span, len: usize) Span {
        return .{ .start = self.start, .end = self.start + len };
    }
};

const GuardedSource = struct {
    bytes: []const u8,
    allowed: []const Span = &.{},

    fn source(self: *GuardedSource, comptime Support: type) Support.ByteSource {
        return .{ .context = self, .len = self.bytes.len, .read_at = readAt, .max_read_size = 5 };
    }

    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *GuardedSource = @ptrCast(@alignCast(raw));
        const start = std.math.cast(usize, offset) orelse return error.SourceReadFailed;
        for (self.allowed) |span| {
            // Reject a request that crosses a frame boundary even when its
            // short return would have stayed inside the allowed span.
            if (start < span.start or start >= span.end or output.len > span.end - start) continue;
            const len = @min(2, output.len);
            @memcpy(output[0..len], self.bytes[start..][0..len]);
            return len;
        }
        return error.SourceReadFailed;
    }
};

pub fn contracts(comptime Support: type) !void {
    const allocator = std.testing.allocator;
    const a = (try Support.ZstdNativeDictionary.initFromStandardDictionary(&dict_a)).dictionary;
    const b = (try Support.ZstdNativeDictionary.initFromStandardDictionary(&dict_b)).dictionary;
    try std.testing.expectEqual(@as(u32, 0x1234_5678), a.id);
    try std.testing.expectEqual(@as(u32, 0x2345_6789), b.id);
    const catalog_ab = [_]Support.ZstdNativeDictionary{ b, a }; // not in frame order
    const catalog_a = [_]Support.ZstdNativeDictionary{a};
    const catalog_only: Support.ZstdSourceSeekableDecodeOptions = .{ .dictionary_set = Support.ZstdNativeDictionarySet.init(&catalog_ab) };
    const missing: Support.ZstdSourceSeekableDecodeOptions = .{ .dictionary_set = Support.ZstdNativeDictionarySet.init(&catalog_a) };
    var with_fallback = missing;
    with_fallback.dictionary = b;

    // Bracket the selected A and B with two real, unselected frames. Indexing
    // may only read the table and range operations may not touch either decoy.
    const Member = struct { wire: []const u8, plain: []const u8 };
    const members = [_]Member{
        .{ .wire = &frame_b, .plain = plain_b },
        .{ .wire = &frame_a, .plain = plain_a },
        .{ .wire = &frame_b, .plain = plain_b },
        .{ .wire = &frame_a, .plain = plain_a },
    };
    const table_start = 2 * (frame_a.len + frame_b.len);
    var bytes: [table_start + 17 + members.len * 12]u8 = undefined;
    var frame_sizes: [members.len]Support.ZstdNativeSeekTableFrameSize = undefined;
    var spans: [members.len]Span = undefined;
    var pos: usize = 0;
    for (members, &frame_sizes, &spans) |member, *entry, *span| {
        @memcpy(bytes[pos..][0..member.wire.len], member.wire);
        span.* = .{ .start = pos, .end = pos + member.wire.len };
        pos = span.end;
        entry.* = .{
            .compressed_size = @intCast(member.wire.len),
            .decompressed_size = @intCast(member.plain.len),
            .checksum = @truncate(std.hash.XxHash64.hash(0, member.plain)),
        };
    }
    const table_size = try Support.zstdEncodeNativeSeekTableInto(&frame_sizes, true, bytes[pos..]);
    const table_span = Span{ .start = pos, .end = pos + table_size };
    var guarded: GuardedSource = .{ .bytes = bytes[0..table_span.end], .allowed = &.{table_span} };
    const table = try Support.zstdOpenSourceSeekTable(guarded.source(Support));
    try std.testing.expect(table.has_checksums);
    var entries: [members.len]Support.ZstdNativeSeekTableEntry = undefined;
    const index = try table.buildIndex(&entries);

    const a_tail = plain_a[plain_a.len - 7 ..];
    const b_head = plain_b[0..19];
    const crossing = plain_b.len + plain_a.len - a_tail.len;
    const headers = [_]Span{ spans[1].prefix(header_a), spans[2].prefix(header_b) };
    guarded.allowed = &headers;
    const requirements = Support.zstdSourceSeekableRangeRequirements;
    const needed = try requirements(index, crossing, a_tail.len + b_head.len, catalog_only);
    try std.testing.expectEqualDeep(needed, try requirements(index, crossing, a_tail.len + b_head.len, with_fallback));
    try std.testing.expectEqual(@max(plain_a.len + a.content.len, plain_b.len + b.content.len), needed.history);
    try std.testing.expectEqual(b_head.len, needed.range_scratch);
    try std.testing.expectError(error.NeedDictionary, requirements(index, crossing, a_tail.len + b_head.len, missing));

    const history = try allocator.alloc(u8, needed.history);
    defer allocator.free(history);
    const staging = try allocator.alloc(u8, needed.staging);
    defer allocator.free(staging);
    const literal_page = try allocator.alloc(u8, needed.literal_page);
    defer allocator.free(literal_page);
    const sequence_page = try allocator.alloc(u8, needed.sequence_page);
    defer allocator.free(sequence_page);
    const workspace: Support.ZstdSourceFrameWorkspace = .{
        .history = history,
        .staging = staging,
        .literal_page = literal_page,
        .sequence_page = sequence_page,
    };
    const decode = Support.zstdDecodeSourceSeekableRangeInto;
    const sentinel: u8 = 0xa5;
    var storage: [a_tail.len + b_head.len + 2]u8 = undefined;
    const output = storage[1 .. storage.len - 1];
    var scratch: [b_head.len]u8 = undefined;
    const selected = [_]Span{ spans[1], spans[2] };
    for ([_]Support.ZstdSourceSeekableDecodeOptions{ catalog_only, with_fallback }) |options| {
        @memset(&storage, sentinel);
        guarded.allowed = &selected;
        try std.testing.expectEqual(output.len, try decode(index, crossing, output, workspace, &scratch, options));
        try std.testing.expectEqualStrings(a_tail ++ b_head, output);
        try std.testing.expectEqual(sentinel, storage[0]);
        try std.testing.expectEqual(sentinel, storage[storage.len - 1]);
    }

    // A verifies and commits. B must reject at its header, without fetching
    // a block or modifying any of the requested B bytes.
    @memset(&storage, sentinel);
    const missing_selection = [_]Span{ spans[1], headers[1] };
    guarded.allowed = &missing_selection;
    try std.testing.expectError(error.NeedDictionary, decode(index, crossing, output, workspace, &scratch, missing));
    try std.testing.expectEqualStrings(a_tail, output[0..a_tail.len]);
    try std.testing.expect(std.mem.allEqual(u8, output[a_tail.len..], sentinel));
    try std.testing.expectEqual(sentinel, storage[0]);
    try std.testing.expectEqual(sentinel, storage[storage.len - 1]);

    // Retry only the missing suffix with the same index, output, workspace,
    // and scratch. Reads of previously published A are now forbidden too.
    guarded.allowed = selected[1..];
    try std.testing.expectEqual(b_head.len, try decode(index, crossing + a_tail.len, output[a_tail.len..], workspace, &scratch, with_fallback));
    try std.testing.expectEqualStrings(a_tail ++ b_head, output);
    try std.testing.expectEqual(sentinel, storage[0]);
    try std.testing.expectEqual(sentinel, storage[storage.len - 1]);

    // Progress exposes both the missing dictionary and the retry coordinates.
    const decode_progress = Support.zstdDecodeSourceSeekableRangeIntoWithProgress;
    @memset(&storage, sentinel);
    guarded.allowed = &missing_selection;
    const failure = switch (decode_progress(index, crossing, output, workspace, &scratch, missing)) {
        .failed => |rejected| rejected,
        .complete => return error.TestUnexpectedResult,
    };
    try std.testing.expectEqual(error.NeedDictionary, failure.err);
    try std.testing.expectEqual(a_tail.len, failure.progress.output_written);
    try std.testing.expectEqual(@as(u64, plain_b.len + plain_a.len), failure.progress.next_decoded_offset);
    try std.testing.expectEqual(@as(usize, 1), failure.progress.frames_committed);
    const failed_frame = failure.frame orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u32, 2), failed_frame.frame_index);
    try std.testing.expectEqual(@as(u64, spans[2].start), failed_frame.compressed_offset);
    try std.testing.expectEqual(@as(?u32, b.id), failed_frame.dictionary_id);
    try std.testing.expectEqualStrings(a_tail, output[0..a_tail.len]);
    try std.testing.expect(std.mem.allEqual(u8, output[a_tail.len..], sentinel));
    try std.testing.expectEqual(sentinel, storage[0]);
    try std.testing.expectEqual(sentinel, storage[storage.len - 1]);

    guarded.allowed = selected[1..];
    const resumed = switch (decode_progress(index, failure.progress.next_decoded_offset, output[failure.progress.output_written..], workspace, &scratch, with_fallback)) {
        .complete => |progress| progress,
        .failed => |rejected| return rejected.err,
    };
    try std.testing.expectEqual(b_head.len, resumed.output_written);
    try std.testing.expectEqual(@as(u64, crossing + output.len), resumed.next_decoded_offset);
    try std.testing.expectEqual(@as(usize, 1), resumed.frames_committed);
    try std.testing.expectEqualStrings(a_tail ++ b_head, output);
    try std.testing.expectEqual(sentinel, storage[0]);
    try std.testing.expectEqual(sentinel, storage[storage.len - 1]);
}

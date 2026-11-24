const std = @import("std");
const t = std.testing;

// zlib 1.2.11: level 6, wbits=31, Z_FIXED. Feed five high literals, then
// three copies of them, then six copies and '!'; flush Z_BLOCK after the
// first two inputs and Z_FINISH after the third. The last two blocks reuse
// earlier plaintext, and their headers start at byte/bit 16:7 and 21:0.
const pattern = "\xc8\xc9\xca\xcb\xcc";
const middle_plain = pattern ** 10 ++ "!";
const middle_wire = [_]u8{
    0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03,
    0x3a, 0x71, 0xf2, 0xd4, 0xe9, 0x33, 0x00, 0x9d, 0x40, 0x25,
    0x00, 0xc3, 0x4f, 0x28, 0x02, 0x00, 0x02, 0x68, 0xf6, 0x26,
    0x33, 0x00, 0x00, 0x00,
};

const SourceContext = struct {
    bytes: []const u8,
    first_readable: u64 = 0,
    blocked: ?struct { start: u64, end: u64 } = null,

    fn readAt(context: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *SourceContext = @ptrCast(@alignCast(context));
        if (offset < self.first_readable) return error.SourceReadFailed;
        if (self.blocked) |gap| {
            if (offset >= gap.start and offset < gap.end) return error.SourceReadFailed;
        }
        if (offset >= self.bytes.len or output.len == 0) return 0;
        output[0] = self.bytes[@intCast(offset)];
        return 1;
    }
};

pub fn contracts(comptime V: type) !void {
    const Count = V.StreamCount;
    const first_plain = "earlier\n";
    const last_plain = "later member\n";
    const plain = first_plain ++ middle_plain ++ last_plain;
    const first = try V.encodeGzipFixedAlloc(t.allocator, first_plain);
    defer t.allocator.free(first);
    const empty = try V.encodeGzipFixedAlloc(t.allocator, "");
    defer t.allocator.free(empty);
    const last = try V.encodeGzipStoredWithHeaderAlloc(t.allocator, last_plain, .{ .filename = "later", .header_crc = true });
    defer t.allocator.free(last);
    const wire = try std.mem.concat(t.allocator, u8, &.{ first, &middle_wire, empty, last });
    defer t.allocator.free(wire);
    const middle_end = first.len + middle_wire.len;
    const last_start = middle_end + empty.len;

    var context = SourceContext{ .bytes = wire };
    const source: V.ByteSource = .{ .context = &context, .len = wire.len, .read_at = SourceContext.readAt };
    var history: [32 * 1024]u8 = undefined;
    var page: [3]u8 = undefined;
    var discard: [2]u8 = undefined;
    const workspace: V.GzipSourceIndexWorkspace = .{ .history = &history, .input_page = &page, .discard = &discard };
    var entries: [5]V.GzipSourceIndexEntry = undefined;
    var saved: [25]u8 = undefined;
    const options: V.GzipSourceIndexOptions = .{ .checkpoint_spacing = 0 };

    const index = try V.buildGzipSourceIndex(source, &entries, &saved, workspace, options);
    try t.expectEqual(@as(Count, plain.len), index.decoded_size);
    try t.expectEqual(@as(Count, 4), index.members_verified);
    try t.expectEqual(entries.len, index.entries.len);
    const compressed_starts = [_]usize{ 0, first.len, first.len + 16, first.len + 21, last_start };
    const decoded_starts = [_]usize{ 0, first_plain.len, first_plain.len + 5, first_plain.len + 20, first_plain.len + middle_plain.len };
    for (index.entries, compressed_starts, decoded_starts, 0..) |entry, compressed, decoded, i| {
        try t.expectEqual(@as(Count, compressed), entry.compressedOffset());
        try t.expectEqual(@as(Count, decoded), entry.decodedOffset());
        try t.expectEqual(@as(Count, if (i == 0) first.len else if (i == 4) wire.len else middle_end), entry.compressed_end);
        try t.expectEqual(@as(Count, if (i == 0) first_plain.len else if (i == 4) plain.len else decoded_starts[4]), entry.decoded_end);
        try t.expectEqual(i == 2 or i == 3, entry.boundary == .block);
    }
    for (index.entries[2..4], [_]u3{ 7, 0 }, [_]usize{ 5, 20 }) |entry, bit, history_len| {
        try t.expectEqual(bit, entry.boundary.block.position.compressed_bit_offset);
        try t.expectEqualSlices(u8, middle_plain[0..history_len], entry.boundary.block.history);
    }

    // Reuse the transient history workspace, allowing no source reads before
    // the exact restart offset (including the byte shared by the two blocks).
    @memset(&history, 0xa5);
    context.first_readable = compressed_starts[2];
    const unaligned_start = decoded_starts[2] + 1;
    var unaligned: [9]u8 = undefined;
    const restarted = index.decodeRangeInto(unaligned_start, &unaligned, workspace);
    try t.expect(restarted == .complete);
    try t.expectEqualSlices(u8, plain[unaligned_start..][0..unaligned.len], &unaligned);

    // Require the later checkpoint. A cross-member read must skip the middle
    // footer and intervening empty member; failing the next anchor leaves an
    // exact committed plaintext prefix, with the rest of the output untouched.
    context.first_readable = compressed_starts[3];
    const start = decoded_starts[3] + 2;
    const prefix_len = decoded_starts[4] - start;
    var output: [plain.len - start]u8 = @splat(0xa5);
    context.blocked = .{ .start = middle_end - 8, .end = wire.len };
    const fault = index.decodeRangeInto(start, &output, workspace);
    try t.expect(fault == .failed);
    try t.expectEqual(error.SourceReadFailed, fault.failed.err);
    try t.expectEqual(prefix_len, fault.failed.progress.output_written);
    try t.expectEqual(@as(Count, decoded_starts[4]), fault.failed.progress.next_decoded_offset);
    try t.expectEqualSlices(u8, plain[start..decoded_starts[4]], output[0..prefix_len]);
    for (output[prefix_len..]) |byte| try t.expectEqual(@as(u8, 0xa5), byte);

    context.blocked = .{ .start = middle_end - 8, .end = last_start };
    const completed = index.decodeRangeInto(start, &output, workspace);
    try t.expect(completed == .complete);
    try t.expectEqual(output.len, completed.complete.output_written);
    try t.expectEqual(@as(Count, plain.len), completed.complete.next_decoded_offset);
    try t.expectEqualSlices(u8, plain[start..], &output);

    context.first_readable = wire.len;
    const no_workspace: V.GzipSourceIndexWorkspace = .{ .history = &.{}, .input_page = &.{}, .discard = &.{} };
    const eof = index.decodeRangeInto(index.decoded_size, &.{}, no_workspace);
    try t.expect(eof == .complete);
    try t.expectEqual(@as(usize, 0), eof.complete.output_written);
    try t.expectEqual(index.decoded_size, eof.complete.next_decoded_offset);
    var refused: [1]u8 = @splat(0xa5);
    const past_end = index.decodeRangeInto(index.decoded_size, &refused, no_workspace);
    try t.expect(past_end == .failed);
    try t.expectEqual(error.RangeOutOfBounds, past_end.failed.err);
    try t.expectEqual(@as(u8, 0xa5), refused[0]);
    const aliased = index.decodeRangeInto(0, history[0..1], workspace);
    try t.expect(aliased == .failed);
    try t.expectEqual(error.InvalidBlockPlan, aliased.failed.err);
    try t.expectEqual(@as(usize, 0), aliased.failed.progress.output_written);

    var empty_context: SourceContext = .{ .bytes = empty };
    const only_empty = try V.buildGzipSourceIndex(.{
        .context = &empty_context,
        .len = empty.len,
        .read_at = SourceContext.readAt,
    }, &.{}, &.{}, workspace, .{ .max_output_len = 0 });
    try t.expectEqual(@as(Count, 1), only_empty.members_verified);
    try t.expectEqual(@as(Count, 0), only_empty.decoded_size);
    try t.expectEqual(@as(usize, 0), only_empty.entries.len);

    context.first_readable = 0;
    context.blocked = null;
    const sparse = try V.buildGzipSourceIndex(source, &entries, saved[0..20], workspace, .{ .checkpoint_spacing = 6 });
    try t.expectEqual(@as(usize, 4), sparse.entries.len);
    try t.expectEqual(@as(Count, decoded_starts[3]), sparse.entries[2].decodedOffset());

    var short_workspace = workspace;
    short_workspace.history = history[0 .. history.len - 1];
    try t.expectError(error.OutputTooSmall, V.buildGzipSourceIndex(source, &entries, &saved, short_workspace, options));
    try t.expectError(error.OutputTooSmall, V.buildGzipSourceIndex(source, entries[0..4], &saved, workspace, options));
    try t.expectError(error.OutputTooSmall, V.buildGzipSourceIndex(source, &entries, saved[0..24], workspace, options));
    try t.expectError(error.OutputLimitExceeded, V.buildGzipSourceIndex(source, &entries, &saved, workspace, .{ .max_output_len = plain.len - 1 }));
    try t.expectError(error.OutputLimitExceeded, V.buildGzipSourceIndex(source, &entries, &saved, workspace, .{ .max_members = 3 }));
    try t.expectError(error.OutputLimitExceeded, V.buildGzipSourceIndex(source, &entries, &saved, workspace, .{ .max_header_metadata_len = 5 }));

    // Neither a bad CRC in an omitted empty member nor a bad ISIZE in an
    // indexed member is permitted to yield a validated index.
    for ([_]usize{ last_start - 8, middle_end - 4 }, [_]anyerror{ error.ChecksumMismatch, error.SizeMismatch }) |offset, err| {
        wire[offset] ^= 1;
        defer wire[offset] ^= 1;
        try t.expectError(err, V.buildGzipSourceIndex(source, &entries, &saved, workspace, options));
    }
}

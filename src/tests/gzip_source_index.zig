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

const first_plain = "earlier\n";
const last_plain = "later member\n";
const plain = first_plain ++ middle_plain ++ last_plain;

const SourceContext = struct {
    bytes: []const u8,
    first_readable: u64 = 0,
    blocked: ?struct { start: u64, end: u64 } = null,
    read_calls: usize = 0,

    fn readAt(context: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *SourceContext = @ptrCast(@alignCast(context));
        self.read_calls += 1;
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

    try verifiedRanges(V, index, &context, workspace, wire, .{
        .start = first.len,
        .end = middle_end,
        .next_start = last_start,
    });

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

fn verifiedRanges(
    comptime V: type,
    index: V.GzipSourceIndex,
    context: *SourceContext,
    workspace: V.GzipSourceIndexWorkspace,
    wire: []u8,
    middle: struct { start: usize, end: usize, next_start: usize },
) !void {
    const Count = V.StreamCount;
    const boundary = first_plain.len + middle_plain.len;
    const middle_len = 4;
    const last_len = 7;
    const start = boundary - middle_len;
    const untouched: [middle_len + last_len]u8 = @splat(0xa5);
    var output = untouched;
    var scratch: [last_len]u8 = undefined;

    try verifiedRangePreflight(V, index, context, workspace, start, &output, &scratch);
    try t.expectEqualSlices(u8, &untouched, &output);

    // Stage only the larger intersection, not the whole range or either
    // member. Both the preceding member and intervening empty member are unreadable.
    context.first_readable = middle.start;
    context.blocked = .{ .start = middle.end, .end = middle.next_start };
    const crossed = index.decodeVerifiedRangeInto(start, &output, workspace, &scratch);
    try t.expect(crossed == .complete);
    try t.expectEqual(output.len, crossed.complete.output_written);
    try t.expectEqual(@as(Count, start + output.len), crossed.complete.next_decoded_offset);
    try t.expectEqualSlices(u8, plain[start..][0..output.len], &output);

    // Fault after the later member's selected bytes could have been decoded.
    // Its staged bytes must not escape, but the verified middle slice stays.
    context.blocked = .{ .start = wire.len - 8, .end = wire.len };
    output = untouched;
    try expectVerifiedFailure(V, index.decodeVerifiedRangeInto(start, &output, workspace, &scratch), error.SourceReadFailed, middle_len, boundary);
    try t.expectEqualSlices(u8, plain[start..boundary], output[0..middle_len]);
    try t.expectEqualSlices(u8, untouched[middle_len..], output[middle_len..]);

    context.blocked = null;
    for ([_]usize{ wire.len - 8, wire.len - 4 }, [_]anyerror{ error.ChecksumMismatch, error.SizeMismatch }) |trailer_byte, err| {
        wire[trailer_byte] ^= 1;
        defer wire[trailer_byte] ^= 1;
        output = untouched;
        try expectVerifiedFailure(V, index.decodeVerifiedRangeInto(start, &output, workspace, &scratch), err, middle_len, boundary);
        try t.expectEqualSlices(u8, plain[start..boundary], output[0..middle_len]);
        try t.expectEqualSlices(u8, untouched[middle_len..], output[middle_len..]);
    }

    // Even a one-byte selection after a raw checkpoint starts at the gzip
    // header and checks the late CRC. Neither neighboring member is readable.
    const tiny_start = first_plain.len + 6;
    var tiny: [1]u8 = @splat(0xa5);
    var tiny_scratch: [1]u8 = undefined;
    context.blocked = .{ .start = middle.end, .end = wire.len };
    context.first_readable = middle.start + 1;
    try expectVerifiedFailure(V, index.decodeVerifiedRangeInto(tiny_start, &tiny, workspace, &tiny_scratch), error.SourceReadFailed, 0, tiny_start);
    try t.expectEqual(@as(u8, 0xa5), tiny[0]);

    context.first_readable = middle.start;
    try t.expectEqual(tiny_scratch.len, try index.verifiedRangeScratchLen(tiny_start, tiny.len));
    const one = index.decodeVerifiedRangeInto(tiny_start, &tiny, workspace, &tiny_scratch);
    try t.expect(one == .complete);
    try t.expectEqual(tiny.len, one.complete.output_written);
    try t.expectEqual(@as(Count, tiny_start + 1), one.complete.next_decoded_offset);
    try t.expectEqual(plain[tiny_start], tiny[0]);

    tiny[0] = 0xa5;
    wire[middle.end - 8] ^= 1;
    defer wire[middle.end - 8] ^= 1;
    try expectVerifiedFailure(V, index.decodeVerifiedRangeInto(tiny_start, &tiny, workspace, &tiny_scratch), error.ChecksumMismatch, 0, tiny_start);
    try t.expectEqual(@as(u8, 0xa5), tiny[0]);
}

fn verifiedRangePreflight(
    comptime V: type,
    index: V.GzipSourceIndex,
    context: *SourceContext,
    workspace: V.GzipSourceIndexWorkspace,
    start: V.StreamCount,
    output: []u8,
    scratch: []u8,
) !void {
    context.first_readable = context.bytes.len;
    context.blocked = null;
    const calls_before = context.read_calls;
    try t.expectEqual(scratch.len, try index.verifiedRangeScratchLen(start, output.len));
    try t.expectEqual(@as(usize, 0), try index.verifiedRangeScratchLen(index.decoded_size, 0));
    try t.expectError(error.RangeOutOfBounds, index.verifiedRangeScratchLen(index.decoded_size, 1));
    try t.expectError(error.RangeOutOfBounds, index.verifiedRangeScratchLen(index.decoded_size + 1, 0));

    const no_workspace: V.GzipSourceIndexWorkspace = .{ .history = &.{}, .input_page = &.{}, .discard = &.{} };
    const eof = index.decodeVerifiedRangeInto(index.decoded_size, &.{}, no_workspace, &.{});
    try t.expect(eof == .complete);
    try t.expectEqual(@as(usize, 0), eof.complete.output_written);
    try t.expectEqual(index.decoded_size, eof.complete.next_decoded_offset);
    try expectVerifiedFailure(V, index.decodeVerifiedRangeInto(index.decoded_size, output, workspace, scratch), error.RangeOutOfBounds, 0, index.decoded_size);
    try expectVerifiedFailure(V, index.decodeVerifiedRangeInto(start, output, workspace, scratch[0 .. scratch.len - 1]), error.OutputTooSmall, 0, start);
    try expectVerifiedFailure(V, index.decodeVerifiedRangeInto(start, output, no_workspace, scratch), error.OutputTooSmall, 0, start);

    var aliased_workspace = workspace;
    aliased_workspace.discard = workspace.input_page[0..workspace.discard.len];
    for ([_]V.GzipSourceRangeOutcome{
        index.decodeVerifiedRangeInto(start, output, workspace, output[0..scratch.len]),
        index.decodeVerifiedRangeInto(start, output, workspace, workspace.history[0..scratch.len]),
        index.decodeVerifiedRangeInto(start, workspace.history[0..output.len], workspace, scratch),
        index.decodeVerifiedRangeInto(start, output, aliased_workspace, scratch),
    }) |result| try expectVerifiedFailure(V, result, error.InvalidBlockPlan, 0, start);
    try t.expectEqual(calls_before, context.read_calls);
}

fn expectVerifiedFailure(
    comptime V: type,
    outcome: V.GzipSourceRangeOutcome,
    err: anyerror,
    written: usize,
    next: V.StreamCount,
) !void {
    try t.expect(outcome == .failed);
    try t.expectEqual(err, outcome.failed.err);
    try t.expectEqual(written, outcome.failed.progress.output_written);
    try t.expectEqual(next, outcome.failed.progress.next_decoded_offset);
}

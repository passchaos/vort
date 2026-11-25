//! Contracts for publishing verified source-backed Zstd ranges to a Writer.
const std = @import("std");
const Writer = std.Io.Writer;
const t = std.testing;

const sentinel: u8 = 0xa5;
const header = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0x24 }; // single segment, frame checksum
const first = header ++ [_]u8{ 5, 0x29, 0, 0 } ++ "abcde".* ++ checksumBytes("abcde");
const empty = header ++ [_]u8{ 0, 1, 0, 0 } ++ checksumBytes("");
const second = header ++ [_]u8{ 6, 0x18, 0, 0 } ++ "fgh".* ++ [_]u8{ 0x19, 0, 0 } ++ "ijk".* ++ checksumBytes("fghijk");
const third = header ++ [_]u8{ 1, 9, 0, 0, 'l' } ++ checksumBytes("l");
const frames = first ++ empty ++ second ++ third;
const cross_offset = 2;
const cross_plain = "cdefghi";
const all_tail = "cdefghijkl";

const Span = struct { start: usize, end: usize };
const first_span: Span = .{ .start = 0, .end = first.len };
const second_span: Span = .{ .start = first.len + empty.len, .end = first.len + empty.len + second.len };
const selected_headers = [_]Span{
    .{ .start = first_span.start, .end = first_span.start + header.len + 1 },
    .{ .start = second_span.start, .end = second_span.start + header.len + 1 },
};
const selected_frames = [_]Span{ first_span, second_span };
const table_span: Span = .{ .start = frames.len, .end = std.math.maxInt(usize) };

const SourceProbe = struct {
    bytes: []const u8,
    base: u64 = 0,
    allowed: []const Span = &.{},
    calls: usize = 0,
    denied: usize = 0,

    fn allow(self: *SourceProbe, spans: []const Span) void {
        self.allowed = spans;
        self.calls = 0;
        self.denied = 0;
    }

    fn source(self: *SourceProbe, comptime Z: type) Z.ByteSource {
        return .{ .context = self, .len = self.base + self.bytes.len, .read_at = readAt, .max_read_size = 4 };
    }

    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *SourceProbe = @ptrCast(@alignCast(raw));
        self.calls += 1;
        if (offset >= self.base and offset - self.base < self.bytes.len) {
            const start: usize = @intCast(offset - self.base);
            for (self.allowed) |span| {
                // Validate the whole offered span before simulating a short read.
                const end = @min(span.end, self.bytes.len);
                if (start < span.start or start >= end or output.len > end - start) continue;
                const n = @min(2, output.len);
                @memcpy(output[0..n], self.bytes[start..][0..n]);
                return n;
            }
        }
        self.denied += 1;
        return error.SourceReadFailed;
    }
};

const WriterProbe = struct {
    writer: Writer = .{ .vtable = &.{ .drain = drain, .flush = flush }, .buffer = &.{} },
    expected: []const u8 = "",
    fail_after: usize = std.math.maxInt(usize),
    written: usize = 0,
    drain_calls: usize = 0,
    flush_calls: usize = 0,
    short_writes: usize = 0,
    unexpected: bool = false,

    fn drain(w: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
        const self: *WriterProbe = @fieldParentPtr("writer", w);
        self.drain_calls += 1;
        const offered = Writer.countSplat(data, splat);
        // Compare directly in the callback; no output-sized destination is
        // available and extra bytes from an unverified frame are unexpected.
        if (w.end != 0 or offered == 0 or offered > self.expected.len - self.written) return self.mismatch();
        if (self.written == self.fail_after) return error.WriteFailed;
        const n: usize = @min(offered, 2, self.fail_after - self.written);
        var remaining = n;
        for (data[0 .. data.len - 1]) |bytes| try self.consume(bytes, &remaining);
        for (0..splat) |_| {
            if (remaining == 0) break;
            try self.consume(data[data.len - 1], &remaining);
        }
        if (n < offered) self.short_writes += 1;
        return n;
    }

    fn consume(self: *WriterProbe, bytes: []const u8, remaining: *usize) Writer.Error!void {
        const n = @min(bytes.len, remaining.*);
        if (!std.mem.eql(u8, self.expected[self.written..][0..n], bytes[0..n])) return self.mismatch();
        self.written += n;
        remaining.* -= n;
    }

    fn mismatch(self: *WriterProbe) Writer.Error {
        self.unexpected = true;
        return error.WriteFailed;
    }

    fn flush(w: *Writer) Writer.Error!void {
        const self: *WriterProbe = @fieldParentPtr("writer", w);
        self.flush_calls += 1;
        return error.WriteFailed;
    }

    fn expectWritten(self: *const WriterProbe, n: usize) !void {
        try t.expectEqual(n, self.written);
        try t.expectEqual(@as(usize, 0), self.flush_calls);
        try t.expect(!self.unexpected);
    }
};

fn checksum(bytes: []const u8) u32 {
    return @truncate(std.hash.XxHash64.hash(0, bytes));
}

fn checksumBytes(bytes: []const u8) [4]u8 {
    var result: [4]u8 = undefined;
    std.mem.writeInt(u32, &result, checksum(bytes), .little);
    return result;
}

fn archive(comptime Z: type, comptime wide: bool, storage: []u8) ![]u8 {
    const entries = (if (wide) [_]Z.NativeSeekTableFrameSize{
        .{ .compressed_size = std.math.maxInt(u32), .decompressed_size = std.math.maxInt(u32), .checksum = 0 },
        .{ .compressed_size = 9, .decompressed_size = 9, .checksum = 0 },
    } else [_]Z.NativeSeekTableFrameSize{}) ++ [_]Z.NativeSeekTableFrameSize{
        .{ .compressed_size = first.len, .decompressed_size = 5, .checksum = checksum("abcde") },
        .{ .compressed_size = empty.len, .decompressed_size = 0, .checksum = checksum("") },
        .{ .compressed_size = second.len, .decompressed_size = 6, .checksum = checksum("fghijk") },
        .{ .compressed_size = third.len, .decompressed_size = 1, .checksum = checksum("l") },
    };
    @memcpy(storage[0..frames.len], &frames);
    const size = try Z.encodeNativeSeekTableInto(&entries, true, storage[frames.len..]);
    return storage[0 .. frames.len + size];
}

fn openIndex(comptime Z: type, source: *SourceProbe, entries: []Z.NativeSeekTableEntry) !Z.SourceSeekIndex {
    source.allow(&.{table_span});
    const table = try Z.openSourceSeekTable(source.source(Z));
    return table.buildIndex(entries);
}

pub fn contracts(comptime Z: type) !void {
    var history: [6]u8 = undefined;
    var staging: [6]u8 = undefined;
    var literal_page: [9]u8 = undefined;
    var sequence_page: [9]u8 = undefined;
    const workspace: Z.SourceFrameWorkspace = .{
        .history = &history,
        .staging = &staging,
        .literal_page = &literal_page,
        .sequence_page = &sequence_page,
    };
    var storage: [frames.len + 96]u8 = undefined;
    var source: SourceProbe = .{ .bytes = try archive(Z, false, &storage) };
    var entries: [4]Z.NativeSeekTableEntry = undefined;
    const index = try openIndex(Z, &source, &entries);

    try emptyAndBounds(Z, &source, index);
    try writeRanges(Z, &source, index, workspace);
    try aliases(Z, &source, index, &entries, workspace);
    try checksumFailures(Z, workspace);
    try wideRanges(Z, workspace);
}

fn emptyAndBounds(comptime Z: type, source: *SourceProbe, index: Z.SourceSeekIndex) !void {
    source.allow(&.{});
    const workspace: Z.SourceFrameWorkspace = .{ .history = &.{}, .staging = &.{}, .literal_page = &.{}, .sequence_page = &.{} };
    const opts: Z.SourceSeekableDecodeOptions = .{ .frame_decoded_max = 0, .max_window_size = 0 };
    const zero: Z.SourceSeekableRangeRequirements = .{};
    var sink: WriterProbe = .{};
    for ([_]u64{ 0, 5, index.decompressed_size }) |offset| {
        try t.expectEqualDeep(zero, try Z.sourceSeekableRangeRequirementsWide(index, offset, 0, opts));
        try t.expectEqual(@as(u64, 0), try Z.decodeSourceSeekableRangeToWriter(index, offset, 0, &sink.writer, workspace, &.{}, opts));
    }
    try t.expectError(error.RangeOutOfBounds, Z.sourceSeekableRangeRequirementsWide(index, index.decompressed_size + 1, 0, .{}));
    try t.expectError(error.RangeOutOfBounds, Z.sourceSeekableRangeRequirementsWide(index, 1, std.math.maxInt(u64), .{}));
    try t.expectError(error.RangeOutOfBounds, Z.decodeSourceSeekableRangeToWriter(index, 1, std.math.maxInt(u64), &sink.writer, workspace, &.{}, .{}));
    try t.expectEqual(@as(usize, 0), source.calls);
    try t.expectEqual(@as(usize, 0), sink.drain_calls);
    try sink.expectWritten(0);
}

fn writeRanges(comptime Z: type, source: *SourceProbe, index: Z.SourceSeekIndex, workspace: Z.SourceFrameWorkspace) !void {
    source.allow(&selected_headers);
    const needed = try Z.sourceSeekableRangeRequirementsWide(index, cross_offset, cross_plain.len, .{});
    try t.expectEqualDeep(try Z.sourceSeekableRangeRequirements(index, cross_offset, cross_plain.len, .{}), needed);
    try t.expectEqual(@as(usize, 4), needed.range_scratch);
    try t.expectEqual(workspace.history.len, needed.history);
    try t.expectEqual(workspace.staging.len, needed.staging);
    try t.expectEqual(workspace.literal_page.len, needed.literal_page);
    try t.expectEqual(workspace.sequence_page.len, needed.sequence_page);
    try t.expect(source.calls != 0);
    try t.expectEqual(@as(usize, 0), source.denied);

    var sink: WriterProbe = .{ .expected = cross_plain };
    const unchanged: [6]u8 = @splat(sentinel);
    var scratch_bytes = unchanged;
    const scratch = scratch_bytes[1..5];
    source.allow(&.{});
    try t.expectError(error.OutputTooSmall, Z.decodeSourceSeekableRangeToWriter(index, cross_offset, cross_plain.len, &sink.writer, workspace, scratch[0..3], .{}));
    try t.expectEqual(@as(usize, 0), source.calls);
    try t.expectEqual(@as(usize, 0), sink.drain_calls);
    try t.expectEqualSlices(u8, &unchanged, &scratch_bytes);

    source.allow(&selected_frames);
    try t.expectEqual(@as(u64, cross_plain.len), try Z.decodeSourceSeekableRangeToWriter(index, cross_offset, cross_plain.len, &sink.writer, workspace, scratch, .{}));
    try sink.expectWritten(cross_plain.len);
    try t.expect(sink.short_writes != 0);
    try t.expectEqual(@as(usize, 0), source.denied);
    try t.expectEqual(sentinel, scratch_bytes[0]);
    try t.expectEqual(sentinel, scratch_bytes[5]);

    source.allow(&.{first_span});
    var failing: WriterProbe = .{ .expected = "cde", .fail_after = 2 };
    try t.expectError(error.WriteFailed, Z.decodeSourceSeekableRangeToWriter(index, cross_offset, cross_plain.len, &failing.writer, workspace, scratch, .{}));
    try failing.expectWritten(2);
    try t.expect(failing.drain_calls > 1);
    try t.expectEqual(@as(usize, 0), source.denied);

    // Preserve existing buffered output and never ask the Writer to flush.
    var output: [5]u8 = @splat(sentinel);
    var buffered: WriterProbe = .{};
    buffered.writer.buffer = output[1..4];
    try buffered.writer.writeAll("!");
    try t.expectEqual(@as(u64, 2), try Z.decodeSourceSeekableRangeToWriter(index, 1, 2, &buffered.writer, workspace, scratch, .{}));
    try t.expectEqualStrings("!bc", buffered.writer.buffered());
    try t.expectEqual(@as(usize, 0), buffered.drain_calls);
    try buffered.expectWritten(0);
    try t.expectEqual(sentinel, output[0]);
    try t.expectEqual(sentinel, output[4]);
}

fn aliases(comptime Z: type, source: *SourceProbe, index: Z.SourceSeekIndex, entries: []Z.NativeSeekTableEntry, workspace: Z.SourceFrameWorkspace) !void {
    source.allow(&.{});
    var scratch: [1]u8 = @splat(sentinel);
    var dictionary: [1]u8 = @splat(sentinel);
    var sink: WriterProbe = .{};
    const decode = Z.decodeSourceSeekableRangeToWriter;
    for ([_][]u8{ &scratch, workspace.history, workspace.staging, workspace.literal_page, workspace.sequence_page, std.mem.sliceAsBytes(entries) }) |buffer| {
        sink.writer.buffer = buffer[0..1];
        try t.expectError(error.InvalidBlockPlan, decode(index, 0, 1, &sink.writer, workspace, &scratch, .{}));
    }
    sink.writer.buffer = &dictionary;
    try t.expectError(error.InvalidBlockPlan, decode(index, 0, 1, &sink.writer, workspace, &scratch, .{ .dictionary = .{ .id = 0, .content = &dictionary } }));
    // An unused catalog entry is still borrowed input.
    try t.expectError(error.InvalidBlockPlan, decode(index, 0, 1, &sink.writer, workspace, &scratch, .{ .dictionary_set = .{ .dictionaries = &.{.{ .id = 1, .content = &dictionary }} } }));

    // An unbuffered writer still has a mutable receiver; do not let decoder
    // scratch or workspace overwrite it, or its drain mutate dictionary bytes.
    sink.writer.buffer = &.{};
    const receiver = std.mem.asBytes(&sink.writer);
    try t.expectError(error.InvalidBlockPlan, decode(index, 0, 1, &sink.writer, workspace, receiver, .{}));
    var aliased = workspace;
    aliased.history = receiver;
    try t.expectError(error.InvalidBlockPlan, decode(index, 0, 1, &sink.writer, aliased, &scratch, .{}));
    try t.expectError(error.InvalidBlockPlan, decode(index, 0, 1, &sink.writer, workspace, &scratch, .{ .dictionary = .{ .id = 0, .content = receiver } }));
    try t.expectEqual(sentinel, scratch[0]);
    try t.expectEqual(sentinel, dictionary[0]);
    try t.expectEqual(@as(usize, 0), source.calls);
    try t.expectEqual(@as(usize, 0), sink.drain_calls);
    try sink.expectWritten(0);
}

fn checksumFailures(comptime Z: type, workspace: Z.SourceFrameWorkspace) !void {
    // Both the wire frame checksum and the checksum stored in the seek table
    // must succeed before the Writer receives any intersection from the frame.
    const second_table_checksum = frames.len + 8 + 2 * 12 + 8;
    for ([_]usize{ second_span.end - 1, second_table_checksum }) |damage| {
        var storage: [frames.len + 96]u8 = undefined;
        const bytes = try archive(Z, false, &storage);
        bytes[damage] ^= 1;
        var source: SourceProbe = .{ .bytes = bytes };
        var entries: [4]Z.NativeSeekTableEntry = undefined;
        const index = try openIndex(Z, &source, &entries);
        var scratch: [6]u8 = undefined;
        var sink: WriterProbe = .{ .expected = "cde" };
        source.allow(&selected_frames);
        try t.expectError(error.ChecksumMismatch, Z.decodeSourceSeekableRangeToWriter(index, cross_offset, all_tail.len, &sink.writer, workspace, &scratch, .{}));
        try sink.expectWritten(3);
        try t.expectEqual(@as(usize, 0), source.denied); // third frame was not read
    }
}

fn wideRanges(comptime Z: type, workspace: Z.SourceFrameWorkspace) !void {
    // The two prefix entries exist only in the table. Both compressed and
    // decoded offsets of the real frames lie above 4 GiB, even on 32-bit.
    const base: u64 = (1 << 32) + 8;
    var storage: [frames.len + 96]u8 = undefined;
    var source: SourceProbe = .{ .base = base, .bytes = try archive(Z, true, &storage) };
    var entries: [6]Z.NativeSeekTableEntry = undefined;
    const index = try openIndex(Z, &source, &entries);
    try t.expectEqual(base, index.entries[2].compressed_offset);
    try t.expectEqual(base, index.entries[2].decompressed_offset);

    var scratch: [4]u8 = undefined;
    var sink: WriterProbe = .{ .expected = cross_plain };
    source.allow(&.{});
    // Valid wide requests reach policy and scratch preflight, not the
    // zero- and one-byte paths suggested by their low 32 bits.
    const boundary: u64 = 1 << 32;
    try t.expectError(error.OutputLimitExceeded, Z.sourceSeekableRangeRequirementsWide(index, 0, boundary, .{ .frame_decoded_max = 6 }));
    try t.expectError(error.OutputTooSmall, Z.decodeSourceSeekableRangeToWriter(index, 0, boundary + 1, &sink.writer, workspace, &scratch, .{}));
    try t.expectEqual(@as(usize, 0), source.calls);
    try t.expectEqual(@as(usize, 0), sink.drain_calls);

    source.allow(&selected_headers);
    const needed = try Z.sourceSeekableRangeRequirementsWide(index, base + cross_offset, cross_plain.len, .{});
    try t.expectEqual(scratch.len, needed.range_scratch);
    source.allow(&selected_frames);
    try t.expectEqual(@as(u64, cross_plain.len), try Z.decodeSourceSeekableRangeToWriter(index, base + cross_offset, cross_plain.len, &sink.writer, workspace, &scratch, .{}));
    try sink.expectWritten(cross_plain.len);
    try t.expectEqual(@as(usize, 0), source.denied);
}

//! Public contracts for seekable Zstandard encoding from an unknown-length reader.
const std = @import("std");
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;
const t = std.testing;
const a = t.allocator;

const frame_size = 16;
const plain = "abcdefghijklmnop" ++ "zzzzzzzzzzzzzzzz" ++ "xyz";

const ReaderProbe = struct {
    reader: Reader = .{ .vtable = &.{ .stream = stream }, .buffer = &.{}, .seek = 0, .end = 0 },
    bytes: []const u8,
    fail_at_end: bool = false,
    consumed: usize = 0,
    calls: usize = 0,
    eof_calls: usize = 0,
    short_reads: usize = 0,

    fn stream(r: *Reader, w: *Writer, limit: std.Io.Limit) Reader.StreamError!usize {
        const self: *ReaderProbe = @fieldParentPtr("reader", r);
        self.calls += 1;
        // An initial zero-length read is not EOF.
        if (self.calls == 1) return 0;
        if (self.consumed == self.bytes.len) {
            if (self.fail_at_end) return error.ReadFailed;
            self.eof_calls += 1;
            return error.EndOfStream;
        }
        const data = limit.sliceConst(self.bytes[self.consumed..]);
        const n = try w.write(data[0..@min(3, data.len)]);
        if (n < data.len) self.short_reads += 1;
        self.consumed += n;
        return n;
    }
};

const WriterProbe = struct {
    writer: Writer = .{ .vtable = &.{ .drain = drain, .flush = flush }, .buffer = &.{} },
    bytes: []u8,
    written: usize = 0,
    drain_calls: usize = 0,
    flush_calls: usize = 0,
    short_writes: usize = 0,

    fn drain(w: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
        const self: *WriterProbe = @fieldParentPtr("writer", w);
        self.drain_calls += 1;
        // Buffered cases use a large enough buffer that a drain is unexpected.
        if (w.end != 0 or self.written == self.bytes.len) return error.WriteFailed;
        if (self.drain_calls == 1) return 0;
        const offered = Writer.countSplat(data, splat);
        const cap = @min(offered, 4, self.bytes.len - self.written);
        var dest = self.bytes[self.written..][0..cap];
        for (data[0 .. data.len - 1]) |bytes| copy(&dest, bytes);
        const last = data[data.len - 1];
        for (0..splat) |_| {
            if (dest.len == 0) break;
            copy(&dest, last);
        }
        self.written += cap;
        if (cap < offered) self.short_writes += 1;
        return cap;
    }

    fn copy(dest: *[]u8, bytes: []const u8) void {
        const n = @min(dest.len, bytes.len);
        @memcpy(dest.*[0..n], bytes[0..n]);
        dest.* = dest.*[n..];
    }

    fn flush(w: *Writer) Writer.Error!void {
        const self: *WriterProbe = @fieldParentPtr("writer", w);
        self.flush_calls += 1;
        return error.WriteFailed;
    }

    fn expectBytes(self: *const WriterProbe, expected: []const u8) !void {
        try t.expectEqualSlices(u8, expected, self.bytes[0..self.written]);
        try t.expectEqual(@as(usize, 0), self.flush_calls);
    }
};

pub fn contracts(comptime Z: type) !void {
    try equivalence(Z);
    try bufferedWriter(Z);
    try entryExhaustion(Z);
    try failures(Z);
    try preflight(Z);
    try dictionaryPrefix(Z);
}

fn equivalence(comptime Z: type) !void {
    for ([_]bool{ false, true }) |seek_checksums| {
        const options: Z.NativeSeekableOptions = .{
            .frame_size = frame_size,
            .frame_options = .{ .selection = .raw_or_rle, .content_checksum = !seek_checksums },
            .seek_checksums = seek_checksums,
        };
        // Give each case exactly as many entries as it needs, including the
        // empty frame and a full final frame requiring a separate EOF probe.
        for ([_][]const u8{ "", plain[0..3], plain[0..frame_size], plain[0 .. 2 * frame_size], plain }) |input| {
            const frame_count = if (input.len == 0) 1 else 1 + (input.len - 1) / frame_size;
            var expected: [256]u8 = undefined;
            const expected_len = try Z.encodeNativeSeekableStreamIntoSlice(a, input, options, &expected);
            var output: [256]u8 = undefined;
            var source: ReaderProbe = .{ .bytes = input };
            var sink: WriterProbe = .{ .bytes = &output };
            var frame_input: [frame_size]u8 = undefined;
            var entries: [3]Z.NativeSeekTableFrameSize = undefined;
            const result = try Z.encodeSeekableReaderToWriter(a, &source.reader, &sink.writer, .{
                .frame_input = &frame_input,
                .entries = entries[0..frame_count],
            }, options);
            try t.expectEqual(@as(u64, input.len), result.input_read);
            try t.expectEqual(@as(u64, expected_len), result.output_written);
            try t.expectEqual(frame_count, result.frame_count);
            try t.expectEqual(input.len, source.consumed);
            if (input.len % frame_size == 0) try t.expectEqual(@as(usize, 1), source.eof_calls);
            if (input.len >= frame_size) try t.expect(source.short_reads != 0);
            try t.expect(sink.short_writes != 0);
            try sink.expectBytes(expected[0..expected_len]);
        }
    }
}

fn bufferedWriter(comptime Z: type) !void {
    const options: Z.NativeSeekableOptions = .{ .frame_size = frame_size, .frame_options = .{ .selection = .raw_or_rle } };
    const prefix = "preexisting output";
    var source = Reader.fixed("skipped" ++ plain);
    source.toss("skipped".len);
    var buffer: [256]u8 = undefined;
    var sink: WriterProbe = .{ .bytes = &.{} };
    sink.writer.buffer = &buffer;
    try sink.writer.writeAll(prefix);

    var frame_input: [frame_size]u8 = undefined;
    var entries: [3]Z.NativeSeekTableFrameSize = undefined;
    const result = try Z.encodeSeekableReaderToWriter(a, &source, &sink.writer, .{
        .frame_input = &frame_input,
        .entries = &entries,
    }, options);
    var expected: [256]u8 = undefined;
    const expected_len = try Z.encodeNativeSeekableStreamIntoSlice(a, plain, options, &expected);
    try t.expectEqual(@as(u64, plain.len), result.input_read);
    try t.expectEqual(@as(u64, expected_len), result.output_written);
    const buffered = sink.writer.buffered();
    try t.expectEqualSlices(u8, prefix, buffered[0..prefix.len]);
    try t.expectEqualSlices(u8, expected[0..expected_len], buffered[prefix.len..]);
    try t.expectEqual(@as(usize, 0), sink.drain_calls);
    try t.expectEqual(@as(usize, 0), sink.flush_calls);
}

fn entryExhaustion(comptime Z: type) !void {
    const options: Z.NativeSeekableOptions = .{ .frame_size = frame_size, .frame_options = .{ .selection = .raw_or_rle } };
    const full_len = 2 * frame_size;
    const expected = try Z.encodeNativeSeekableStreamAlloc(a, plain[0..full_len], options);
    defer a.free(expected);
    const table = try Z.inspectNativeSeekTable(expected);
    var frame_input: [frame_size]u8 = undefined;
    var entries: [2]Z.NativeSeekTableFrameSize = undefined;
    var output: [256]u8 = undefined;

    // Both a partial-frame tail and a full extra frame must fail, without
    // consuming the whole tail or publishing a misleading or partial table.
    for ([_][]const u8{ plain[0 .. full_len + 1], plain, plain ++ "ABCDEFGHIJKLMNOP" }) |input| {
        var source: ReaderProbe = .{ .bytes = input };
        var sink: WriterProbe = .{ .bytes = &output };
        try t.expectError(error.OutputLimitExceeded, Z.encodeSeekableReaderToWriter(a, &source.reader, &sink.writer, .{
            .frame_input = &frame_input,
            .entries = &entries,
        }, options));
        const consumed = source.consumed;
        try t.expect(consumed >= full_len and consumed <= full_len + 1);
        try sink.expectBytes(expected[0..table.frame_offset]);
        if (consumed < input.len) {
            var next: [1]u8 = undefined;
            try source.reader.readSliceAll(&next);
            try t.expectEqual(input[consumed], next[0]);
        }
    }
}

fn failures(comptime Z: type) !void {
    const options: Z.NativeSeekableOptions = .{ .frame_size = frame_size, .frame_options = .{ .selection = .raw_or_rle } };
    const expected = try Z.encodeNativeSeekableStreamAlloc(a, plain, options);
    defer a.free(expected);
    const table = try Z.inspectNativeSeekTable(expected);
    const first_end: usize = @intCast((try table.entry(0)).compressed_size);
    const second_end = first_end + @as(usize, @intCast((try table.entry(1)).compressed_size));
    var frame_input: [frame_size]u8 = undefined;
    var entries: [3]Z.NativeSeekTableFrameSize = undefined;
    const workspace: Z.SourceSeekableEncodeWorkspace = .{ .frame_input = &frame_input, .entries = &entries };
    var output: [256]u8 = undefined;

    // Preserve read failures during a partially read frame and during the
    // single-byte probe when the entry log is full.
    for ([_]usize{ frame_size + 2, 2 * frame_size }, [_]usize{ first_end, second_end }) |input_len, output_len| {
        var source: ReaderProbe = .{ .bytes = plain[0..input_len], .fail_at_end = true };
        var sink: WriterProbe = .{ .bytes = &output };
        try t.expectError(error.ReadFailed, Z.encodeSeekableReaderToWriter(a, &source.reader, &sink.writer, .{
            .frame_input = &frame_input,
            .entries = entries[0..2],
        }, options));
        try sink.expectBytes(expected[0..output_len]);
    }
    // Fail while writing a frame or while writing the terminal table.
    for ([_]usize{ first_end + 2, table.frame_offset + 9 }) |fail_after| {
        var source: ReaderProbe = .{ .bytes = plain };
        var sink: WriterProbe = .{ .bytes = output[0..fail_after] };
        try t.expectError(error.WriteFailed, Z.encodeSeekableReaderToWriter(a, &source.reader, &sink.writer, workspace, options));
        try sink.expectBytes(expected[0..fail_after]);
    }
}

fn preflight(comptime Z: type) !void {
    const options: Z.NativeSeekableOptions = .{ .frame_size = frame_size };
    var frame_input: [frame_size]u8 = undefined;
    var entries: [2]Z.NativeSeekTableFrameSize = undefined;
    const workspace: Z.SourceSeekableEncodeWorkspace = .{ .frame_input = &frame_input, .entries = &entries };
    const allocator = t.failing_allocator;
    var source: ReaderProbe = .{ .bytes = "", .fail_at_end = true };
    var sink: WriterProbe = .{ .bytes = &.{} };

    try t.expectError(error.InvalidBlockPlan, Z.encodeSeekableReaderToWriter(allocator, &source.reader, &sink.writer, workspace, .{ .frame_size = 0 }));
    try t.expectError(error.OutputTooSmall, Z.encodeSeekableReaderToWriter(allocator, &source.reader, &sink.writer, .{
        .frame_input = frame_input[0 .. frame_size - 1],
        .entries = &entries,
    }, options));
    try t.expectError(error.OutputTooSmall, Z.encodeSeekableReaderToWriter(allocator, &source.reader, &sink.writer, .{
        .frame_input = &frame_input,
        .entries = entries[0..0],
    }, options));

    source.reader.buffer = frame_input[1..];
    try t.expectError(error.InvalidBlockPlan, Z.encodeSeekableReaderToWriter(allocator, &source.reader, &sink.writer, workspace, options));
    var shared: [32]u8 = undefined;
    source.reader.buffer = shared[0..20];
    sink.writer.buffer = shared[16..];
    try t.expectError(error.InvalidBlockPlan, Z.encodeSeekableReaderToWriter(allocator, &source.reader, &sink.writer, workspace, options));
    sink.writer.buffer = std.mem.asBytes(&source.reader);
    try t.expectError(error.InvalidBlockPlan, Z.encodeSeekableReaderToWriter(allocator, &source.reader, &sink.writer, workspace, options));

    try t.expectEqual(@as(usize, 0), source.calls);
    try t.expectEqual(@as(usize, 0), sink.drain_calls);
    try t.expectEqual(@as(usize, 0), sink.flush_calls);
    try t.expectEqual(@as(usize, 0), sink.writer.end);
}

fn dictionaryPrefix(comptime Z: type) !void {
    const h = @import("zstd_prefix_lifecycle/helpers.zig");
    // Reader storage must not alias the borrowed dictionary even when the
    // target's constant pool would share the identical input prefix.
    const input = try a.dupe(u8, h.prefix ** 2);
    defer a.free(input);
    const dictionary = Z.NativeDictionary.initRawContent(h.prefix);
    const options: Z.NativeSeekableOptions = .{
        .frame_size = h.prefix.len,
        .frame_options = .{ .selection = .literal_only, .dictionary_usage = .prefix },
    };
    const expected = try Z.encodeNativeSeekableStreamWithDictionaryAlloc(a, input, options, dictionary);
    defer a.free(expected);
    var source = Reader.fixed(input);
    var output: [2 * h.prefix.len + 128]u8 = undefined;
    var sink = Writer.fixed(&output);
    var frame_input: [h.prefix.len]u8 = undefined;
    var entries: [2]Z.NativeSeekTableFrameSize = undefined;
    const result = try Z.encodeSeekableReaderToWriterWithDictionary(a, &source, &sink, .{
        .frame_input = &frame_input,
        .entries = &entries,
    }, options, dictionary);
    try t.expectEqual(@as(u64, input.len), result.input_read);
    try t.expectEqual(@as(u64, expected.len), result.output_written);
    try t.expectEqual(@as(usize, 2), result.frame_count);
    try t.expectEqualSlices(u8, expected, sink.buffered());

    var members = Z.iterateNativeStream(sink.buffered());
    const first = (try members.next()).?.frame;
    const second = (try members.next()).?.frame;
    try h.missing(Z, first.bytes, .standard);
    try h.check(Z, first.bytes, h.prefix, .{ .dictionary = dictionary });
    try h.check(Z, second.bytes, h.prefix, .{});
}

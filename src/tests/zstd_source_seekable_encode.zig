//! Public contracts for source-to-sink Zstandard seekable encoding.
const std = @import("std");
const ByteSource = @import("../io/source.zig").Source;
const ByteSink = @import("../io/sink.zig").Sink;
const t = std.testing;
const a = t.allocator;

const frame_size = 16;
const plain = "abcdefghijklmnop" ++ "zzzzzzzzzzzzzzzz" ++ "xyz";
const frame_count = 3;

const SourceProbe = struct {
    bytes: []const u8,
    fail_at_end: bool = false,
    consumed: usize = 0,
    calls: usize = 0,
    short_reads: usize = 0,

    fn source(self: *SourceProbe, len: u64) ByteSource {
        return .{ .context = self, .len = len, .read_at = readAt, .max_read_size = 5 };
    }

    fn readAt(raw: *anyopaque, offset: u64, dest: []u8) error{SourceReadFailed}!usize {
        const self: *SourceProbe = @ptrCast(@alignCast(raw));
        self.calls += 1;
        // Reject rereads, gaps, and requests outside the configured cap.
        if (offset != self.consumed or dest.len == 0 or dest.len > 5)
            return error.SourceReadFailed;
        const remaining = self.bytes[self.consumed..];
        if (remaining.len == 0) return if (self.fail_at_end) error.SourceReadFailed else 0;
        const size = @min(3, remaining.len, dest.len);
        if (size < dest.len) self.short_reads += 1;
        @memcpy(dest[0..size], remaining[0..size]);
        self.consumed += size;
        return size;
    }
};

const SinkProbe = struct {
    bytes: []u8,
    fail_after: ?usize = null,
    fail_finish: bool = false,
    written: usize = 0,
    write_calls: usize = 0,
    short_writes: usize = 0,
    finish_calls: usize = 0,
    finish_length: ?u64 = null,

    fn sink(self: *SinkProbe) ByteSink {
        return .{ .context = self, .write_at = writeAt, .set_len = setLen, .max_write_size = 6 };
    }

    fn writeAt(raw: *anyopaque, offset: u64, input: []const u8) error{SinkWriteFailed}!usize {
        const self: *SinkProbe = @ptrCast(@alignCast(raw));
        self.write_calls += 1;
        if (offset != self.written or self.finish_calls != 0 or input.len == 0 or input.len > 6)
            return error.SinkWriteFailed;
        const limit = self.fail_after orelse self.bytes.len;
        if (self.written >= limit) return error.SinkWriteFailed;
        const size = @min(4, input.len, limit - self.written);
        if (size < input.len) self.short_writes += 1;
        @memcpy(self.bytes[self.written..][0..size], input[0..size]);
        self.written += size;
        return size;
    }

    fn setLen(raw: *anyopaque, len: u64) error{SinkWriteFailed}!void {
        const self: *SinkProbe = @ptrCast(@alignCast(raw));
        self.finish_calls += 1;
        self.finish_length = len;
        if (self.fail_finish or len != self.written) return error.SinkWriteFailed;
    }

    fn expectPrefix(self: *const SinkProbe, expected: []const u8) !void {
        try t.expectEqualSlices(u8, expected, self.bytes[0..self.written]);
    }
};

pub fn contracts(comptime Z: type) !void {
    try success(Z);
    try preflight(Z);
    try failures(Z);
    try dictionaryEquivalence(Z);
    try memoryBudget(Z);
}

fn success(comptime Z: type) !void {
    for ([_]bool{ false, true }) |with_checksums| {
        const options: Z.NativeSeekableOptions = .{
            .frame_size = frame_size,
            .frame_options = .{ .content_checksum = !with_checksums, .selection = .raw_or_rle },
            .seek_checksums = with_checksums,
        };
        // Empty, short single frame, exact multiple, and a three-byte tail.
        for ([_][]const u8{ "", plain[0..3], plain[0 .. frame_size * 2], plain }) |input| {
            var frame_input: [frame_size]u8 = undefined;
            var entries: [frame_count]Z.NativeSeekTableFrameSize = undefined;
            const expected_count: usize = if (input.len == 0) 1 else (input.len - 1) / frame_size + 1;
            const req = try Z.sourceSeekableEncodeRequirements(input.len, options);
            try t.expectEqual(@min(frame_size, input.len), req.frame_input_len);
            try t.expectEqual(expected_count, req.frame_count);

            const expected = try Z.encodeNativeSeekableStreamAlloc(a, input, options);
            defer a.free(expected);
            const encoded = try a.alloc(u8, expected.len);
            defer a.free(encoded);
            var source: SourceProbe = .{ .bytes = input };
            var sink: SinkProbe = .{ .bytes = encoded };
            const result = try Z.encodeSourceSeekableTo(a, source.source(input.len), sink.sink(), .{
                .frame_input = frame_input[0..req.frame_input_len],
                .entries = entries[0..req.frame_count],
            }, options);
            try t.expectEqual(@as(u64, input.len), result.input_read);
            try t.expectEqual(@as(u64, expected.len), result.output_written);
            try t.expectEqual(expected_count, result.frame_count);
            try t.expectEqual(input.len, source.consumed);
            if (input.len == 0) try t.expectEqual(@as(usize, 0), source.calls);
            if (input.len == plain.len) try t.expect(source.short_reads != 0);
            try t.expect(sink.short_writes != 0);
            try t.expectEqual(@as(usize, 1), sink.finish_calls);
            try t.expectEqual(@as(?u64, expected.len), sink.finish_length);
            try sink.expectPrefix(expected);

            const table = try Z.inspectNativeSeekTable(encoded);
            try t.expectEqual(@as(u32, @intCast(expected_count)), table.entry_count);
            try t.expectEqual(@as(u64, input.len), table.decompressed_size);
            try t.expectEqual(with_checksums, table.has_checksums);
            try t.expectEqual(table.frame_size, req.table_bytes);
            var iterator = table.iterator();
            var start: usize = 0;
            while (try iterator.next()) |entry| {
                const chunk = input[start..][0..@min(frame_size, input.len - start)];
                try t.expectEqual(@as(u64, start), entry.decompressed_offset);
                try t.expectEqual(@as(u32, @intCast(chunk.len)), entry.decompressed_size);
                const seek_checksum: ?u32 = if (with_checksums) @as(u32, @truncate(std.hash.XxHash64.hash(0, chunk))) else null;
                try t.expectEqual(seek_checksum, entry.checksum);
                start += chunk.len;
            }
            if (input.len == plain.len) {
                var decoded: [5]u8 = undefined;
                var scratch: [frame_size]u8 = undefined;
                const offset = 2 * frame_size - 2;
                const len = try Z.decodeNativeSeekableRangeInto(encoded, offset, &decoded, &scratch);
                try t.expectEqual(decoded.len, len);
                try t.expectEqualSlices(u8, plain[offset..], &decoded);
            }
        }
    }
}

fn preflight(comptime Z: type) !void {
    const options: Z.NativeSeekableOptions = .{ .frame_size = frame_size };
    var frame_input: [frame_size]u8 = undefined;
    var entries: [frame_count]Z.NativeSeekTableFrameSize = undefined;
    const workspace: Z.SourceSeekableEncodeWorkspace = .{ .frame_input = &frame_input, .entries = &entries };
    var source: SourceProbe = .{ .bytes = plain };
    var buffer: [256]u8 = undefined;
    var sink: SinkProbe = .{ .bytes = &buffer };
    const input = source.source(plain.len);
    const output = sink.sink();
    const allocator = t.failing_allocator;

    for ([_]Z.NativeSeekableOptions{
        .{ .frame_size = 0 },
        .{ .frame_size = 0x4000_0001 },
        .{ .frame_options = .{ .format = .magicless } },
        .{ .frame_options = .{ .dictionary_id = 1 } },
        .{ .frame_options = .{ .block_size_max = 0 } },
    }) |invalid| {
        try t.expectError(error.InvalidBlockPlan, Z.sourceSeekableEncodeRequirements(plain.len, invalid));
        try t.expectError(error.InvalidBlockPlan, Z.encodeSourceSeekableTo(allocator, input, output, workspace, invalid));
    }
    try t.expectError(error.OutputTooSmall, Z.encodeSourceSeekableTo(allocator, input, output, .{
        .frame_input = frame_input[0 .. frame_size - 1],
        .entries = &entries,
    }, options));
    try t.expectError(error.OutputTooSmall, Z.encodeSourceSeekableTo(allocator, input, output, .{
        .frame_input = &frame_input,
        .entries = entries[0 .. frame_count - 1],
    }, options));
    try t.expectError(error.InvalidBlockPlan, Z.encodeSourceSeekableTo(allocator, input, output, .{
        .frame_input = std.mem.sliceAsBytes(entries[0..])[1..][0..frame_size],
        .entries = &entries,
    }, options));

    // The source length is virtual: test a wide ceiling division, the seek
    // table's frame count cap, and u64 overflow without allocating payloads.
    const wide_options: Z.NativeSeekableOptions = .{ .frame_size = 0x1_0000 };
    const max_count = 0x0800_0000;
    const max_len: u64 = max_count * 0x1_0000;
    const req = try Z.sourceSeekableEncodeRequirements(max_len, wide_options);
    try t.expectEqual(@as(usize, 0x1_0000), req.frame_input_len);
    try t.expectEqual(@as(usize, max_count), req.frame_count);
    const wide = try Z.sourceSeekableEncodeRequirements(0x1_0000_0001, wide_options);
    try t.expectEqual(@as(usize, 0x1_0001), wide.frame_count);
    try t.expectError(error.InvalidBlockPlan, Z.sourceSeekableEncodeRequirements(max_len + 1, wide_options));
    try t.expectError(error.InvalidBlockPlan, Z.sourceSeekableEncodeRequirements(std.math.maxInt(u64), wide_options));
    try t.expectError(error.InvalidBlockPlan, Z.encodeSourceSeekableTo(allocator, source.source(max_len + 1), output, workspace, wide_options));
    try t.expectError(error.OutputTooSmall, Z.encodeSourceSeekableTo(allocator, source.source(max_len), output, workspace, wide_options));

    try t.expectEqual(@as(usize, 0), source.calls);
    try t.expectEqual(@as(usize, 0), sink.write_calls);
    try t.expectEqual(@as(usize, 0), sink.finish_calls);
}

fn failures(comptime Z: type) !void {
    const options: Z.NativeSeekableOptions = .{ .frame_size = frame_size, .frame_options = .{ .selection = .raw_or_rle } };
    const expected = try Z.encodeNativeSeekableStreamAlloc(a, plain, options);
    defer a.free(expected);
    const table = try Z.inspectNativeSeekTable(expected);
    const first_end: usize = @intCast((try table.entry(0)).compressed_size);

    var frame_input: [frame_size]u8 = undefined;
    var entries: [frame_count]Z.NativeSeekTableFrameSize = undefined;
    const workspace: Z.SourceSeekableEncodeWorkspace = .{ .frame_input = &frame_input, .entries = &entries };
    const buffer = try a.alloc(u8, expected.len);
    defer a.free(buffer);

    for ([_]bool{ false, true }) |explicit_error| {
        var source: SourceProbe = .{ .bytes = plain[0 .. frame_size + 2], .fail_at_end = explicit_error };
        var sink: SinkProbe = .{ .bytes = buffer };
        const err = if (explicit_error) error.SourceReadFailed else error.TruncatedFrame;
        try t.expectError(err, Z.encodeSourceSeekableTo(a, source.source(plain.len), sink.sink(), workspace, options));
        try sink.expectPrefix(expected[0..first_end]);
        try t.expectEqual(@as(usize, 0), sink.finish_calls);
    }

    // Accept some bytes of a data frame, then accept some bytes of the
    // terminal table in a separate run. Neither failure can commit length.
    for ([_]usize{ first_end + 2, table.frame_offset + 10 }) |fail_after| {
        var source: SourceProbe = .{ .bytes = plain };
        var sink: SinkProbe = .{ .bytes = buffer, .fail_after = fail_after };
        try t.expectError(error.SinkWriteFailed, Z.encodeSourceSeekableTo(a, source.source(plain.len), sink.sink(), workspace, options));
        try sink.expectPrefix(expected[0..fail_after]);
        try t.expectEqual(@as(usize, 0), sink.finish_calls);
    }

    var source: SourceProbe = .{ .bytes = plain };
    var sink: SinkProbe = .{ .bytes = buffer, .fail_finish = true };
    try t.expectError(error.SinkWriteFailed, Z.encodeSourceSeekableTo(a, source.source(plain.len), sink.sink(), workspace, options));
    try sink.expectPrefix(expected);
    try t.expectEqual(@as(usize, 1), sink.finish_calls);
    try t.expectEqual(@as(?u64, expected.len), sink.finish_length);
}

fn dictionaryEquivalence(comptime Z: type) !void {
    const dictionary = Z.NativeDictionary.init(0x1234, "dictionary with abcdefghijklmnopqrstuvwxyz");
    for ([_]Z.DictionaryUsage{ .persistent, .prefix }) |usage| {
        const options: Z.NativeSeekableOptions = .{
            .frame_size = frame_size,
            .frame_options = .{ .selection = .literal_only, .dictionary_usage = usage },
        };
        const expected = try Z.encodeNativeSeekableStreamWithDictionaryAlloc(a, plain, options, dictionary);
        defer a.free(expected);
        const encoded = try a.alloc(u8, expected.len);
        defer a.free(encoded);
        var source: SourceProbe = .{ .bytes = plain };
        var sink: SinkProbe = .{ .bytes = encoded };
        var frame_input: [frame_size]u8 = undefined;
        var entries: [frame_count]Z.NativeSeekTableFrameSize = undefined;
        const result = try Z.encodeSourceSeekableToWithDictionary(a, source.source(plain.len), sink.sink(), .{
            .frame_input = &frame_input,
            .entries = &entries,
        }, options, dictionary);
        try t.expectEqual(@as(u64, plain.len), result.input_read);
        try t.expectEqual(@as(u64, expected.len), result.output_written);
        try t.expectEqual(@as(usize, frame_count), result.frame_count);
        try t.expectEqual(@as(usize, 1), sink.finish_calls);
        try sink.expectPrefix(expected);
    }
}

fn memoryBudget(comptime Z: type) !void {
    var profile: Z.EncodeMemoryProfile = .{};
    var options: Z.NativeSeekableOptions = .{
        .frame_size = frame_size,
        .frame_options = .{ .selection = .raw_or_rle, .memory_profile = &profile },
    };
    var frame_input: [frame_size]u8 = undefined;
    var entries: [frame_count]Z.NativeSeekTableFrameSize = undefined;
    const workspace: Z.SourceSeekableEncodeWorkspace = .{ .frame_input = &frame_input, .entries = &entries };
    var buffer: [256]u8 = undefined;
    var source: SourceProbe = .{ .bytes = plain };
    var sink: SinkProbe = .{ .bytes = &buffer };
    _ = try Z.encodeSourceSeekableTo(a, source.source(plain.len), sink.sink(), workspace, options);
    try t.expect(profile.available and profile.peak_requested_bytes != 0);
    try t.expectEqual(@as(usize, 0), profile.live_requested_bytes);

    options.frame_options.max_total_working_memory = profile.peak_requested_bytes;
    source = .{ .bytes = plain };
    sink = .{ .bytes = &buffer };
    _ = try Z.encodeSourceSeekableTo(a, source.source(plain.len), sink.sink(), workspace, options);
    try t.expectEqual(@as(usize, 1), sink.finish_calls);

    options.frame_options.max_total_working_memory = 0;
    source = .{ .bytes = plain };
    sink = .{ .bytes = &buffer };
    try t.expectError(error.WorkingMemoryLimitExceeded, Z.encodeSourceSeekableTo(a, source.source(plain.len), sink.sink(), workspace, options));
    try t.expectEqual(@as(usize, 0), source.calls);
    try t.expectEqual(@as(usize, 0), sink.write_calls);
    try t.expectEqual(@as(usize, 0), sink.finish_calls);
}

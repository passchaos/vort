const std = @import("std");

// Generated with upstream Zstd 1.6.0 (01b7154f1172432f8abe9b3bb9909e14a1176b7d)
// at level 3, checksumFlag=1, contentSizeFlag=0. Independently compress
// "alpha-" x32, an empty frame, "bravo-" x32, and "delta-" x32, resetting
// the compression session between frames. Use ZSTD_compressStream2 with
// ZSTD_e_end, except for an extra ZSTD_e_flush after byte 96 of "bravo-".
// Use contrib/seekable_format's ZSTD_seekable_createFrameLog(1), logFrame
// with the low 32 bits of XXH64(plaintext, 0), and writeSeekTable.
const fixture = [_]u8{
    // alpha: one compressed block, then the normal frame checksum.
    0x28, 0xb5, 0x2f, 0xfd, 0x04, 0x00, 0x6d, 0x00, 0x00, 0x30, 0x61, 0x6c, 0x70,
    0x68, 0x61, 0x2d, 0x01, 0x00, 0xb7, 0x50, 0xa5, 0x08, 0xa7, 0x1e, 0xfa, 0x9f,
    // Empty frame between alpha and bravo, not at the end of the stream.
    0x28, 0xb5, 0x2f, 0xfd, 0x04, 0x00, 0x01, 0x00, 0x00, 0x99, 0xe9, 0xd8, 0x51,
    // bravo: two compressed blocks; its history crosses the block boundary.
    0x28, 0xb5, 0x2f, 0xfd, 0x04, 0x58, 0x6c, 0x00, 0x00, 0x30, 0x62, 0x72, 0x61,
    0x76, 0x6f, 0x2d, 0x01, 0x00, 0x97, 0xa9, 0x14, 0x01, 0x3d, 0x00, 0x00, 0x08,
    0x62, 0x01, 0x00, 0x3c, 0x01, 0x21, 0x81, 0x9c, 0x4d, 0xb2,
    // delta: one compressed block.
    0x28, 0xb5, 0x2f,
    0xfd, 0x04, 0x00, 0x6d, 0x00, 0x00, 0x30, 0x64, 0x65, 0x6c, 0x74, 0x61, 0x2d,
    0x01, 0x00, 0xb7, 0x50, 0xa5, 0x08, 0xa8, 0x76, 0xad, 0x21,
    // Terminal seekable table: skippable magic, payload size, four entries, footer.
    0x5e, 0x2a, 0x4d,
    0x18, 0x39, 0,    0,    0,    26,   0,    0,    0,    192,  0,    0,    0,
    0xa7, 0x1e, 0xfa, 0x9f, 13,   0,    0,    0,    0,    0,    0,    0,    0x99,
    0xe9, 0xd8, 0x51, 36,   0,    0,    0,    192,  0,    0,    0,    0x81, 0x9c,
    0x4d, 0xb2, 26,   0,    0,    0,    192,  0,    0,    0,    0xa8, 0x76, 0xad,
    0x21, 4,    0,    0,    0,    0x80, 0xb1, 0xea, 0x92, 0x8f,
};

const Span = struct { start: usize, end: usize };
const alpha = Span{ .start = 0, .end = 26 };
const bravo = Span{ .start = 39, .end = 75 };
const alpha_header = Span{ .start = alpha.start, .end = alpha.start + 6 };
const bravo_header = Span{ .start = bravo.start, .end = bravo.start + 6 };
const table_bytes = Span{ .start = 101, .end = fixture.len };
const entries_start = table_bytes.start + 8;
const entry_size = 12;
const frame_size = 192;
const cross_offset = frame_size - 3;
const cross_plain = "ha-bravo";
const sentinel: u8 = 0xa5;

const GuardedSource = struct {
    bytes: []const u8,
    allowed: []const Span = &.{},
    calls: usize = 0,
    denied: usize = 0,

    fn allow(self: *GuardedSource, spans: []const Span) void {
        self.allowed = spans;
        self.calls = 0;
        self.denied = 0;
    }

    fn source(self: *GuardedSource, comptime Support: type) Support.ByteSource {
        return .{ .context = self, .len = self.bytes.len, .read_at = readAt, .max_read_size = 5 };
    }

    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *GuardedSource = @ptrCast(@alignCast(raw));
        self.calls += 1;
        const start = std.math.cast(usize, offset) orelse return error.SourceReadFailed;
        // Check the whole request, not merely the bytes returned by this
        // deliberately short read. An accidental read-ahead also fails.
        for (self.allowed) |span| {
            if (start < span.start or start >= span.end or output.len > span.end - start) continue;
            const size = @min(2, output.len);
            @memcpy(output[0..size], self.bytes[start..][0..size]);
            return size;
        }
        self.denied += 1;
        return error.SourceReadFailed;
    }
};

pub fn contracts(comptime Support: type) !void {
    var guarded: GuardedSource = .{ .bytes = &fixture };
    guarded.allow(&.{table_bytes});
    const table = try Support.zstdOpenSourceSeekTable(guarded.source(Support));
    try std.testing.expectEqual(@as(u64, table_bytes.start), table.frame_offset);
    try std.testing.expectEqual(@as(u32, 4), table.entry_count);
    try std.testing.expect(table.has_checksums);

    var entries: [4]Support.ZstdNativeSeekTableEntry = undefined;
    try std.testing.expectError(error.OutputTooSmall, table.buildIndex(entries[0..3]));
    const index = try table.buildIndex(&entries);
    try std.testing.expectEqual(@as(usize, 4), index.entries.len);
    try std.testing.expectEqual(@as(u64, 3 * frame_size), index.decompressed_size);
    try std.testing.expectEqual(@as(u32, 0), index.entries[1].decompressed_size);
    try std.testing.expectEqual(@as(u64, bravo.start), index.entries[2].compressed_offset);
    try std.testing.expectEqual(@as(u64, frame_size), index.entries[2].decompressed_offset);

    try emptyAndBounds(Support, &guarded, index);

    // Only magic, descriptor, and window descriptor may be read. Both the
    // first block headers and all bytes of the empty/unselected frames are forbidden.
    guarded.allow(&.{ alpha_header, bravo_header });
    const needed = try Support.zstdSourceSeekableRangeRequirements(index, cross_offset, cross_plain.len, .{});
    try std.testing.expectEqual(@as(usize, 2 * 1024 * 1024), needed.history);
    try std.testing.expectEqual(@as(usize, 128 * 1024), needed.staging);
    try std.testing.expectEqual(@as(usize, 9), needed.literal_page);
    try std.testing.expectEqual(@as(usize, 9), needed.sequence_page);
    try std.testing.expectEqual(@as(usize, 5), needed.range_scratch);
    try std.testing.expect(guarded.calls > 0);
    try std.testing.expectEqual(@as(usize, 0), guarded.denied);
    try std.testing.expectError(error.OutputLimitExceeded, Support.zstdSourceSeekableRangeRequirements(index, cross_offset, cross_plain.len, .{ .max_window_size = 1024 }));
    try std.testing.expectError(error.OutputLimitExceeded, Support.zstdSourceSeekableRangeRequirements(index, cross_offset, 1, .{ .frame_decoded_max = frame_size - 1 }));

    // The exact reported buffers also exercise the compressed path. Keep large
    // window and block allocations off the native/Wasm test stack.
    const allocator = std.testing.allocator;
    const history = try allocator.alloc(u8, needed.history);
    defer allocator.free(history);
    const staging = try allocator.alloc(u8, needed.staging);
    defer allocator.free(staging);
    var literal_page: [9]u8 = undefined;
    var sequence_page: [9]u8 = undefined;
    const workspace: Support.ZstdSourceFrameWorkspace = .{
        .history = history,
        .staging = staging,
        .literal_page = &literal_page,
        .sequence_page = &sequence_page,
    };
    var scratch: [frame_size + 1]u8 = undefined;
    var guarded_output: [cross_plain.len + 2]u8 = @splat(sentinel);
    const output = guarded_output[1 .. guarded_output.len - 1];
    guarded.allow(&.{ alpha_header, bravo_header });
    try std.testing.expectError(error.OutputTooSmall, Support.zstdDecodeSourceSeekableRangeInto(index, cross_offset, output, workspace, scratch[0 .. needed.range_scratch - 1], .{}));
    try std.testing.expectEqual(@as(usize, 0), guarded.denied);
    try expectSentinel(&guarded_output);

    guarded.allow(&.{ alpha, bravo });
    try std.testing.expectEqual(output.len, try Support.zstdDecodeSourceSeekableRangeInto(index, cross_offset, output, workspace, scratch[0..needed.range_scratch], .{}));
    try std.testing.expectEqualStrings(cross_plain, output);
    try std.testing.expectEqual(sentinel, guarded_output[0]);
    try std.testing.expectEqual(sentinel, guarded_output[guarded_output.len - 1]);
    try std.testing.expectEqual(@as(usize, 0), guarded.denied);

    // Starting just after the empty entry selects only bravo. A second read
    // begins halfway through bravo and crosses both of its compressed blocks.
    guarded.allow(&.{bravo});
    var block_output: [18]u8 = undefined;
    for ([_]u64{ frame_size, frame_size + 90 }) |offset| {
        try std.testing.expectEqual(block_output.len, try Support.zstdDecodeSourceSeekableRangeInto(index, offset, &block_output, workspace, scratch[0..block_output.len], .{}));
        try std.testing.expectEqualStrings("bravo-" ** 3, &block_output);
    }
    try std.testing.expectEqual(@as(usize, 0), guarded.denied);

    guarded.allow(&.{});
    try aliasContracts(Support, index, &entries, workspace);
    try std.testing.expectEqual(@as(usize, 0), guarded.calls);
    try failureContracts(Support, workspace, &scratch);
}

fn emptyAndBounds(comptime Support: type, guarded: *GuardedSource, index: anytype) !void {
    guarded.allow(&.{});
    const workspace: Support.ZstdSourceFrameWorkspace = .{ .history = &.{}, .staging = &.{}, .literal_page = &.{}, .sequence_page = &.{} };
    const end = index.decompressed_size;
    for ([_]u64{ 0, frame_size, end }) |offset| {
        const needed = try Support.zstdSourceSeekableRangeRequirements(index, offset, 0, .{ .frame_decoded_max = 0, .max_window_size = 0 });
        try std.testing.expectEqual(@as(usize, 0), needed.history | needed.staging | needed.literal_page | needed.sequence_page | needed.range_scratch);
        try std.testing.expectEqual(@as(usize, 0), try Support.zstdDecodeSourceSeekableRangeInto(index, offset, &.{}, workspace, &.{}, .{ .frame_decoded_max = 0, .max_window_size = 0 }));
    }

    try std.testing.expectError(error.RangeOutOfBounds, Support.zstdSourceSeekableRangeRequirements(index, end + 1, 0, .{}));
    try std.testing.expectError(error.RangeOutOfBounds, Support.zstdSourceSeekableRangeRequirements(index, end - 1, 2, .{}));
    try std.testing.expectError(error.RangeOutOfBounds, Support.zstdDecodeSourceSeekableRangeInto(index, end + 1, &.{}, workspace, &.{}, .{}));
    var output: [2]u8 = @splat(sentinel);
    try std.testing.expectError(error.RangeOutOfBounds, Support.zstdDecodeSourceSeekableRangeInto(index, end - 1, &output, workspace, &.{}, .{}));
    try expectSentinel(&output);
    try std.testing.expectEqual(@as(usize, 0), guarded.calls);
}

fn aliasContracts(comptime Support: type, index: anytype, entries: []Support.ZstdNativeSeekTableEntry, workspace: Support.ZstdSourceFrameWorkspace) !void {
    var output: [1]u8 = @splat(sentinel);
    var scratch: [1]u8 = @splat(sentinel);
    const index_bytes = std.mem.sliceAsBytes(entries);
    const decode = Support.zstdDecodeSourceSeekableRangeInto;
    try std.testing.expectError(error.InvalidBlockPlan, decode(index, 0, &output, workspace, &output, .{}));
    try std.testing.expectError(error.InvalidBlockPlan, decode(index, 0, workspace.history[0..1], workspace, &scratch, .{}));
    try std.testing.expectError(error.InvalidBlockPlan, decode(index, 0, &output, workspace, workspace.staging[0..1], .{}));
    try std.testing.expectError(error.InvalidBlockPlan, decode(index, 0, index_bytes[0..1], workspace, &scratch, .{}));
    try std.testing.expectError(error.InvalidBlockPlan, decode(index, 0, &output, workspace, index_bytes[0..1], .{}));
    var aliased_workspace = workspace;
    aliased_workspace.literal_page = index_bytes[0..workspace.literal_page.len];
    try std.testing.expectError(error.InvalidBlockPlan, decode(index, 0, &output, aliased_workspace, &scratch, .{}));

    const direct: Support.ZstdSourceSeekableDecodeOptions = .{ .dictionary = .{ .id = 0, .content = &output } };
    try std.testing.expectError(error.InvalidBlockPlan, decode(index, 0, &output, workspace, &scratch, direct));
    // Even unused catalog entries must remain untouched by mutable storage.
    const catalog: Support.ZstdSourceSeekableDecodeOptions = .{ .dictionary_set = .{ .dictionaries = &.{.{ .id = 1, .content = &scratch }} } };
    try std.testing.expectError(error.InvalidBlockPlan, decode(index, 0, &output, workspace, &scratch, catalog));
    try expectSentinel(&output);
    try expectSentinel(&scratch);
}

fn failureContracts(comptime Support: type, workspace: Support.ZstdSourceFrameWorkspace, scratch: []u8) !void {
    const Fault = enum { frame_checksum, table_checksum, short_decoded_size, long_decoded_size, trailing_frame, skippable };
    const bravo_entry = entries_start + 2 * entry_size;
    for (std.enums.values(Fault)) |fault| {
        var bytes = fixture;
        // Preserve the total compressed extent when creating an entry that
        // claims two frames. Runtime size checks are exercised with a fixture
        // whose frame headers deliberately omit their decoded sizes.
        const expected: anyerror = switch (fault) {
            .frame_checksum => err: {
                bytes[bravo.end - 1] ^= 1;
                break :err error.ChecksumMismatch;
            },
            .table_checksum => err: {
                bytes[bravo_entry + 8] ^= 1;
                break :err error.ChecksumMismatch;
            },
            .short_decoded_size, .long_decoded_size => err: {
                bytes[bravo_entry + 4] = if (fault == .short_decoded_size) frame_size - 1 else frame_size + 1;
                break :err error.SizeMismatch;
            },
            .trailing_frame => err: {
                bytes[entries_start] = bravo.start;
                bytes[entries_start + entry_size] = 0;
                break :err error.SizeMismatch;
            },
            .skippable => err: {
                @memcpy(bytes[alpha.start..][0..4], &[_]u8{ 0x50, 0x2a, 0x4d, 0x18 });
                std.mem.writeInt(u32, bytes[alpha.start + 4 ..][0..4], alpha.end - 8, .little);
                break :err error.InvalidMagic;
            },
        };

        var guarded: GuardedSource = .{ .bytes = &bytes };
        guarded.allow(&.{table_bytes});
        const table = try Support.zstdOpenSourceSeekTable(guarded.source(Support));
        var entries: [4]Support.ZstdNativeSeekTableEntry = undefined;
        const index = try table.buildIndex(&entries);
        var output: [200]u8 = @splat(sentinel);
        switch (fault) {
            .trailing_frame, .skippable => {
                const claimed = Span{ .start = alpha.start, .end = if (fault == .trailing_frame) bravo.start else alpha.end };
                guarded.allow(&.{claimed});
                try std.testing.expectError(expected, Support.zstdDecodeSourceSeekableRangeInto(index, 9, output[0..8], workspace, scratch, .{}));
                try expectSentinel(&output);
            },
            else => {
                // The request reaches delta, but a failure in bravo must stop
                // before any delta I/O. Only alpha's three verified bytes publish.
                guarded.allow(&.{ alpha, bravo });
                try std.testing.expectError(expected, Support.zstdDecodeSourceSeekableRangeInto(index, cross_offset, &output, workspace, scratch, .{}));
                try std.testing.expectEqualStrings("ha-", output[0..3]);
                try expectSentinel(output[3..]);
            },
        }
        try std.testing.expectEqual(@as(usize, 0), guarded.denied);
    }
}

fn expectSentinel(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(sentinel, byte);
}

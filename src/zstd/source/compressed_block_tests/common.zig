const std = @import("std");

pub const compressed_block = @import("../compressed_block.zig");
pub const history_workspace = @import("../../decode/history_workspace.zig");
pub const source_frame = @import("../frame.zig");
pub const source_huffman = @import("../huffman.zig");
pub const source_input = @import("../input.zig");
pub const byte_source = @import("../../../io/source.zig");

pub const all_fse_raw_hex = @embedFile("../../testdata/libzstd-all-fse-raw.frame.hex");
pub const numbered_json_hex = @embedFile("../../testdata/libzstd-numbered-json.frame.hex");
pub const predefined_repeat_hex = @embedFile("../../testdata/decodecorpus-predefined-repeat.frame.hex");

pub const rle_literals_frame = [_]u8{
    0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x12, 0x4d, 0x00, 0x00,
    0x11, 0x61, 0x02, 0x00, 0x00, 0x60, 0x07, 0x10, 0x02,
};

pub const zero_sequence_frame = [_]u8{
    0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x05, 0x25, 0x00, 0x00,
    0x29, 'z',  0x80, 0x00,
};

pub const Mode = enum { normal, zero, excessive, fail };

pub const TrackingSource = struct {
    bytes: []const u8,
    mode: Mode = .normal,
    fault_call: ?usize = null,
    calls: usize = 0,
    bytes_returned: usize = 0,
    max_requested: usize = 0,

    pub fn source(self: *TrackingSource) byte_source.Source {
        return .{
            .context = self,
            .len = @intCast(self.bytes.len),
            .read_at = readAt,
        };
    }

    pub fn clearFault(self: *TrackingSource) void {
        self.mode = .normal;
        self.fault_call = null;
    }

    fn readAt(
        raw: *anyopaque,
        absolute: u64,
        output: []u8,
    ) error{SourceReadFailed}!usize {
        const self: *TrackingSource = @ptrCast(@alignCast(raw));
        self.calls += 1;
        self.max_requested = @max(self.max_requested, output.len);
        if (self.fault_call == null or self.fault_call.? == self.calls) {
            switch (self.mode) {
                .normal => {},
                .zero => return 0,
                .excessive => return output.len + 1,
                .fail => return error.SourceReadFailed,
            }
        }
        const offset = std.math.cast(usize, absolute) orelse
            return error.SourceReadFailed;
        if (offset >= self.bytes.len) return 0;
        const amount = @min(output.len, self.bytes.len - offset);
        @memcpy(output[0..amount], self.bytes[offset..][0..amount]);
        self.bytes_returned += amount;
        return amount;
    }
};

pub fn decodeHex(comptime encoded: []const u8) ![]u8 {
    const hex = std.mem.trim(u8, encoded, " \r\n\t");
    if (hex.len % 2 != 0) return error.TestUnexpectedResult;
    const bytes = try std.testing.allocator.alloc(u8, hex.len / 2);
    errdefer std.testing.allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, hex);
    return bytes;
}

pub fn parseFrame(source: *TrackingSource) !source_frame.DataFrameLayout {
    const available = try source_input.Range.init(
        source.source(),
        0,
        @intCast(source.bytes.len),
    );
    return source_frame.parseDataFrameHeader(available, .standard);
}

pub fn expectCompressed(block: source_frame.BlockLayout) !void {
    try std.testing.expectEqual(.compressed, block.header.kind);
    try std.testing.expectEqual(block.header.declared_len, block.header.wire_len);
}

pub fn limits(frame: source_frame.DataFrameLayout) compressed_block.Limits {
    return .{
        .block_decoded_max = frame.header.block_size_max,
        .frame_decoded_max = frame.header.content_size orelse std.math.maxInt(u64),
        .expected_frame_size = frame.header.content_size,
    };
}

pub fn initHistory(storage: []u8, window_size: u64) !history_workspace.Binding {
    var history = try history_workspace.Binding.init(storage);
    try history.beginFrame(window_size, 0);
    return history;
}

pub fn expectHistoryEqual(
    expected: history_workspace.Binding,
    actual: history_workspace.Binding,
) !void {
    try std.testing.expectEqual(expected.bound, actual.bound);
    try std.testing.expectEqual(expected.window, actual.window);
    try std.testing.expectEqual(expected.limit, actual.limit);
    try std.testing.expectEqual(expected.head, actual.head);
    try std.testing.expectEqual(expected.len, actual.len);
    try std.testing.expectEqualSlices(u8, expected.storage, actual.storage);
}

pub fn expectGuard(storage: []const u8, prefix: u8, suffix: u8) !void {
    try std.testing.expect(storage.len >= 2);
    try std.testing.expectEqual(prefix, storage[0]);
    try std.testing.expectEqual(suffix, storage[storage.len - 1]);
}

pub fn expectedError(mode: Mode) anyerror {
    return switch (mode) {
        .zero => error.TruncatedFrame,
        .excessive, .fail => error.SourceReadFailed,
        .normal => unreachable,
    };
}

pub fn expectEntropyCommit(
    comptime Support: type,
    before: Support.State,
    prepared: *const compressed_block.Prepared(
        Support.HuffmanCodec,
        Support.SequenceCodec,
    ),
    executor: *const compressed_block.Executor(
        Support.HuffmanCodec,
        Support.SequenceCodec,
    ),
    actual: Support.State,
) !void {
    if (prepared.pending_huffman) |pending| {
        if (pending.replace_on_block_success) {
            try std.testing.expect(actual.huffman != null);
            try Support.expectHuffmanEqual(&pending.table, &actual.huffman.?);
        } else {
            try std.testing.expect(before.huffman != null);
            try std.testing.expect(actual.huffman != null);
            try Support.expectHuffmanEqual(&before.huffman.?, &actual.huffman.?);
        }
    } else if (before.huffman) |previous| {
        try std.testing.expect(actual.huffman != null);
        try Support.expectHuffmanEqual(&previous, &actual.huffman.?);
    } else try std.testing.expect(actual.huffman == null);

    if (prepared.pending_sequences) |pending| {
        try std.testing.expect(actual.sequence_tables != null);
        try Support.expectSequenceTablesEqual(&pending.tables, &actual.sequence_tables.?);
        const cursor = executor.sequences orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(
            try cursor.finalRepeatedOffsets(),
            actual.repeated_offsets,
        );
    } else {
        try std.testing.expectEqual(before.repeated_offsets, actual.repeated_offsets);
        if (before.sequence_tables) |previous| {
            try std.testing.expect(actual.sequence_tables != null);
            try Support.expectSequenceTablesEqual(&previous, &actual.sequence_tables.?);
        } else try std.testing.expect(actual.sequence_tables == null);
    }
}

pub fn drainExpected(
    comptime Support: type,
    executor: anytype,
    expected: []const u8,
    expected_state: *const Support.State,
    actual_state: *const Support.State,
    expected_history: history_workspace.Binding,
    actual_history: *const history_workspace.Binding,
) !void {
    const output = try std.testing.allocator.alloc(u8, expected.len + 2);
    defer std.testing.allocator.free(output);
    @memset(output, 0xd8);
    output[0] = 0x51;
    output[output.len - 1] = 0xae;

    const capacities = [_]usize{ 0, 1, 2, 7, 3, 19 };
    var offset: usize = 0;
    var step: usize = 0;
    while (true) : (step += 1) {
        const capacity = @min(capacities[step % capacities.len], expected.len - offset);
        const result = try executor.drain(output[1 + offset ..][0..capacity]);
        try std.testing.expectEqual(capacity, result.written);
        offset += result.written;
        try std.testing.expectEqualSlices(u8, expected[0..offset], output[1..][0..offset]);
        try expectGuard(output, 0x51, 0xae);
        try std.testing.expectEqual(
            expected_state.frame_decoded,
            actual_state.frame_decoded,
        );
        try std.testing.expectEqual(
            expected_state.repeated_offsets,
            actual_state.repeated_offsets,
        );
        try std.testing.expectEqual(
            expected_state.huffman != null,
            actual_state.huffman != null,
        );
        try std.testing.expectEqual(
            expected_state.sequence_tables != null,
            actual_state.sequence_tables != null,
        );
        try std.testing.expectEqual(expected_history.head, actual_history.head);
        try std.testing.expectEqual(expected_history.len, actual_history.len);
        if (offset == expected.len) {
            try std.testing.expectEqual(.done, result.status);
            break;
        }
        try std.testing.expectEqual(.need_output, result.status);
    }
    const final = try executor.drain(&.{});
    try std.testing.expectEqual(@as(usize, 0), final.written);
    try std.testing.expectEqual(.done, final.status);
    try Support.expectStateEqual(expected_state, actual_state);
    try expectHistoryEqual(expected_history, actual_history.*);
}

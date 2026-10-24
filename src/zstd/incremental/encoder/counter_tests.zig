const std = @import("std");
const core = @import("../../../core.zig");
const frame = @import("frame.zig");
const history = @import("history.zig");
const total = @import("../../encode/total_budget.zig");
const Count = core.StreamCount;
const allocator = std.testing.allocator;
const boundary: Count = @as(Count, 1) << 32;

// The generic transaction boundary can be exercised without entropy planning,
// large payloads or wire-format dependencies. Public codec tests cover the
// actual Zstd frame bytes; these seed logical positions around counter limits.
const Codec = struct {
    pub const Error = core.Error || std.mem.Allocator.Error || total.Error;
    pub const Dictionary = struct { id: u32 };
    pub const HistoryView = history.View;
    pub const State = struct { writes: usize = 0, last_offset: Count = 0 };
    pub const Options = struct {
        selection: enum { raw_or_rle, literal_only, auto, fast_compressed } = .raw_or_rle,
        content_checksum: bool = false,
        include_content_size: bool = false,
        fail_checksum: bool = false,
        max_total_working_memory: ?usize = null,
        memory_profile: ?*total.EncodeMemoryProfile = null,
    };
    pub fn validate(options: Options, expected: ?Count, _: ?u32) Error!void {
        if (options.include_content_size != (expected != null)) return error.InvalidBlockPlan;
    }
    pub fn blockLen(_: Options) usize {
        return 4;
    }
    pub fn historyLen(_: Options) usize {
        return 16;
    }
    pub fn writeHeader(a: std.mem.Allocator, out: *std.ArrayList(u8), _: Options, expected: ?Count, _: ?u32) Error!void {
        try out.append(a, 'H');
        if (expected) |length| {
            var bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &bytes, length, .little);
            try out.appendSlice(a, &bytes);
        }
    }
    pub fn writeChecksum(a: std.mem.Allocator, out: *std.ArrayList(u8), options: Options, hasher: *@FieldType(Encoder, "hasher")) Error!void {
        if (!options.content_checksum) return;
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, hasher.final(), .little);
        try out.appendSlice(a, &bytes);
        if (options.fail_checksum) return error.OutputTooSmall;
    }
};

const Emitter = struct {
    pub fn write(a: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool, _: Codec.Options, state: *Codec.State, _: ?Codec.Dictionary, _: Codec.HistoryView, offset: Count) Codec.Error!void {
        state.writes += 1;
        state.last_offset = offset;
        try out.append(a, if (last) 'F' else 'B');
        try out.appendSlice(a, block);
    }
};

const Encoder = frame.Encoder(Codec, Emitter);

test "Zstd incremental encoder counters preserve cumulative and local public types" {
    try std.testing.expect(@FieldType(Encoder, "total_input") == Count);
    try std.testing.expect(@FieldType(Encoder, "total_output") == Count);
    try std.testing.expect(@FieldType(Encoder, "stream_input") == Count);
    try std.testing.expect(@FieldType(Encoder, "stream_output") == Count);
    try std.testing.expect(@FieldType(Encoder, "frame_count") == Count);
    try std.testing.expect(@FieldType(Encoder, "expected_input_len") == ?Count);
    try std.testing.expect(@FieldType(Encoder.Snapshot, "input_read") == Count);
    try std.testing.expect(@FieldType(Encoder.Snapshot, "output_written") == Count);
    try std.testing.expect(@FieldType(Encoder.Snapshot, "frame_input") == Count);
    try std.testing.expect(@FieldType(Encoder.Snapshot, "frame_output") == Count);
    try std.testing.expect(@FieldType(Encoder.Snapshot, "frame_count") == Count);
    try std.testing.expect(@FieldType(Encoder.Snapshot, "frame_index") == Count);
    try std.testing.expect(@FieldType(Encoder.Snapshot, "buffered_input") == usize);
    try std.testing.expect(@FieldType(Encoder.Snapshot, "pending_output") == usize);
    try std.testing.expect(@FieldType(core.Progress, "input_read") == usize);
    try std.testing.expect(@FieldType(core.Progress, "output_written") == usize);
    if (@bitSizeOf(usize) == 64) {
        try std.testing.expect(Count == usize);
        try std.testing.expect(@FieldType(Encoder, "hasher") == std.hash.XxHash64);
    }
}

test "Zstd incremental encoder counters cross 32-bit block input output and frame positions" {
    var encoder = try Encoder.init(allocator, .{});
    defer encoder.deinit();
    encoder.header_written = true;
    encoder.total_input = boundary - 2;
    encoder.stream_input = boundary - 2;
    encoder.total_output = boundary - 2;
    encoder.stream_output = boundary - 2;
    encoder.frame_count = boundary - 1;
    encoder.history.absolute_start = boundary - 2;
    encoder.history.absolute_end = boundary - 2;
    var empty: [0]u8 = .{};
    const accepted = try encoder.step("abcd", &empty);
    try std.testing.expectEqual(@as(usize, 4), accepted.progress.input_read);
    try std.testing.expectEqual(boundary + 2, encoder.total_input);
    const queued = try encoder.step("e", &empty);
    try std.testing.expectEqual(core.StepResult.Status.need_output, queued.status);
    try std.testing.expectEqual(@as(usize, 0), queued.progress.input_read);
    try std.testing.expectEqual(boundary - 2, encoder.codec_state.last_offset);
    try std.testing.expectEqual(boundary + 2, encoder.history.absolute_end);
    var output: [32]u8 = undefined;
    const drained = try encoder.step("e", &output);
    try std.testing.expectEqualSlices(u8, "Babcd", output[0..drained.progress.output_written]);
    try std.testing.expectEqual(@as(usize, 1), drained.progress.input_read);
    try std.testing.expectEqual(boundary + 3, encoder.stream_input);
    try std.testing.expectEqual(boundary + 3, encoder.stream_output);
    encoder.finish();
    const done = try encoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
    try std.testing.expectEqualSlices(u8, "Fe", output[0..done.progress.output_written]);
    const snapshot = encoder.snapshot();
    try std.testing.expectEqual(boundary, snapshot.frame_count);
    try std.testing.expectEqual(boundary - 1, snapshot.frame_index);
    try std.testing.expectEqual(boundary + 2, encoder.codec_state.last_offset);
    try std.testing.expectEqual(boundary + 5, snapshot.output_written);
}

test "Zstd incremental encoder counters refuse input overflow before allocation and hash commit" {
    for ([_]bool{ false, true }) |header_written| {
        for ([_]bool{ false, true }) |overflow_stream| {
            var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
            var encoder = try Encoder.init(failing.allocator(), .{ .content_checksum = true });
            defer encoder.deinit();
            encoder.header_written = header_written;
            if (overflow_stream) encoder.stream_input = std.math.maxInt(Count) - 2 else encoder.total_input = std.math.maxInt(Count) - 2;
            const before = encoder.snapshot();
            const hasher_before = encoder.hasher;
            var output = [_]u8{0xa5} ** 8;
            try std.testing.expectError(error.IntegerOverflow, encoder.step("abc", &output));
            try std.testing.expectEqualDeep(before, encoder.snapshot());
            try std.testing.expectEqualDeep(hasher_before, encoder.hasher);
            try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 8), &output);
            try std.testing.expectEqual(header_written, encoder.header_written);
            try std.testing.expectEqual(@as(usize, 0), encoder.pending.capacity);
            try std.testing.expectEqual(@as(usize, 0), encoder.block.capacity);
            try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
        }
    }
}

test "Zstd incremental encoder counters preflight all offered blocks before a fresh header" {
    var encoder = try Encoder.init(allocator, .{});
    defer encoder.deinit();
    // The first four-byte block fits, but later bytes in the same offered
    // slice would overflow. No header or first-block output may escape.
    encoder.stream_input = std.math.maxInt(Count) - 4;
    const before = encoder.snapshot();
    var output = [_]u8{0xa5} ** 32;
    try std.testing.expectError(error.IntegerOverflow, encoder.step("abcdefghi", &output));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 32), &output);
    try std.testing.expect(!encoder.header_written);
    try std.testing.expectEqual(@as(usize, 0), encoder.pending.capacity);
    try std.testing.expectEqual(@as(usize, 0), encoder.block.capacity);
}

test "Zstd incremental encoder counters preflight preserves actual partial input progress" {
    var encoder = try Encoder.init(allocator, .{});
    defer encoder.deinit();
    var tiny: [2]u8 = undefined;
    const first = try encoder.step("abcdefghi", &tiny);
    try std.testing.expectEqual(core.StepResult.Status.need_output, first.status);
    try std.testing.expectEqual(@as(usize, 4), first.progress.input_read);
    try std.testing.expectEqualSlices(u8, "HB", &tiny);
    try std.testing.expectEqual(@as(Count, 4), encoder.stream_input);
    try std.testing.expectEqual(@as(Count, 2), encoder.stream_output);
    const pending = try encoder.step("efghi", &tiny);
    try std.testing.expectEqual(core.StepResult.Status.need_output, pending.status);
    try std.testing.expectEqual(@as(usize, 0), pending.progress.input_read);
    try std.testing.expectEqualSlices(u8, "ab", &tiny);
    try std.testing.expectEqual(@as(Count, 4), encoder.stream_input);
    var output: [32]u8 = undefined;
    const resumed = try encoder.step("efghi", &output);
    try std.testing.expectEqual(@as(usize, 5), resumed.progress.input_read);
    try std.testing.expectEqualSlices(u8, "cdBefgh", output[0..resumed.progress.output_written]);
    try std.testing.expectEqual(@as(Count, 9), encoder.stream_input);
    try std.testing.expectEqual(@as(Count, 11), encoder.stream_output);
}

test "Zstd incremental encoder counters refuse output overflow before caller writes and retry" {
    for ([_]bool{ false, true }) |overflow_stream| {
        var encoder = try Encoder.init(allocator, .{});
        defer encoder.deinit();
        encoder.header_written = true;
        try encoder.pending.appendSlice(allocator, "abc");
        if (overflow_stream) encoder.stream_output = std.math.maxInt(Count) - 1 else encoder.total_output = std.math.maxInt(Count) - 1;
        const before = encoder.snapshot();
        var output = [_]u8{0xa5} ** 8;
        try std.testing.expectError(error.IntegerOverflow, encoder.step("x", &output));
        try std.testing.expectEqualDeep(before, encoder.snapshot());
        try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 8), &output);
        try std.testing.expectEqual(@as(usize, 0), encoder.pending_offset);
        encoder.total_output = 0;
        encoder.stream_output = 0;
        const retried = try encoder.step("x", &output);
        try std.testing.expectEqual(@as(usize, 1), retried.progress.input_read);
        try std.testing.expectEqualSlices(u8, "abc", output[0..retried.progress.output_written]);
        try std.testing.expectEqual(@as(Count, 3), encoder.stream_output);
    }
}

test "Zstd incremental encoder counters refuse frame overflow before draining final output" {
    var encoder = try Encoder.init(allocator, .{});
    defer encoder.deinit();
    encoder.header_written = true;
    var empty: [0]u8 = .{};
    _ = try encoder.step("abc", &empty);
    try encoder.pending.append(allocator, 'H');
    encoder.frame_count = std.math.maxInt(Count);
    encoder.finish();
    const before = encoder.snapshot();
    var output = [_]u8{0xa5} ** 8;
    try std.testing.expectError(error.IntegerOverflow, encoder.step("", &output));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 8), &output);
    try std.testing.expect(!encoder.final_written);
    encoder.frame_count -= 1;
    const retried = try encoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, retried.status);
    try std.testing.expectEqualSlices(u8, "HFabc", output[0..retried.progress.output_written]);
    try std.testing.expectEqual(std.math.maxInt(Count), encoder.snapshot().frame_count);
}

test "Zstd incremental encoder counters accept wide pledges and retain them through reset" {
    var encoder = try Encoder.initExactSize(allocator, .{ .include_content_size = true }, boundary + 3);
    defer encoder.deinit();
    encoder.total_input = boundary;
    encoder.stream_input = boundary;
    var output: [32]u8 = undefined;
    const accepted = try encoder.step("abc", &output);
    try std.testing.expectEqual(@as(usize, 3), accepted.progress.input_read);
    try std.testing.expectEqual(@as(u64, boundary + 3), std.mem.readInt(u64, output[1..9], .little));
    encoder.finish();
    try std.testing.expectEqual(core.StepResult.Status.done, (try encoder.step("", &output)).status);
    try encoder.nextFrameExactSize(encoder.options, boundary + 17);
    try std.testing.expectEqual(@as(?Count, boundary + 17), encoder.expected_input_len);
    try std.testing.expectEqual(@as(Count, 1), encoder.frame_count);
    encoder.reset();
    try std.testing.expectEqual(@as(?Count, boundary + 17), encoder.expected_input_len);
    try std.testing.expectEqual(@as(Count, 0), encoder.stream_input);
    try std.testing.expectEqual(@as(Count, 0), encoder.stream_output);
    try std.testing.expectEqual(@as(Count, 0), encoder.frame_count);
}

test "Zstd incremental encoder counters reject wide pledge mismatches before input commit" {
    var encoder = try Encoder.initExactSize(allocator, .{ .include_content_size = true, .content_checksum = true }, boundary + 2);
    defer encoder.deinit();
    encoder.header_written = true;
    encoder.total_input = boundary;
    encoder.stream_input = boundary;
    const before = encoder.snapshot();
    const hasher_before = encoder.hasher;
    var output = [_]u8{0xa5} ** 32;
    try std.testing.expectError(error.SizeMismatch, encoder.step("abc", &output));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualDeep(hasher_before, encoder.hasher);
    try std.testing.expectEqual(@as(usize, 0), encoder.block.capacity);
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 32), &output);
    encoder.expected_input_len = boundary + 4;
    _ = try encoder.step("abc", &output);
    encoder.finish();
    try std.testing.expectError(error.SizeMismatch, encoder.step("", &output));
    try std.testing.expectEqualSlices(u8, "abc", encoder.block.items);
    try std.testing.expect(!encoder.final_written);
    encoder.expected_input_len = boundary + 3;
    try std.testing.expectEqual(core.StepResult.Status.done, (try encoder.step("", &output)).status);
}

test "Zstd incremental encoder counters preserve final checksum transaction on retry" {
    var encoder = try Encoder.init(allocator, .{ .content_checksum = true, .fail_checksum = true });
    defer encoder.deinit();
    encoder.header_written = true;
    var empty: [0]u8 = .{};
    _ = try encoder.step("abc", &empty);
    encoder.finish();
    const before = encoder.snapshot();
    const codec_before = encoder.codec_state;
    const hasher_before = encoder.hasher;
    var output = [_]u8{0xa5} ** 32;
    try std.testing.expectError(error.OutputTooSmall, encoder.step("", &output));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualDeep(codec_before, encoder.codec_state);
    try std.testing.expectEqualDeep(hasher_before, encoder.hasher);
    try std.testing.expectEqualSlices(u8, "abc", encoder.block.items);
    try std.testing.expect(!encoder.final_written);
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 32), &output);
    encoder.options.fail_checksum = false;
    const retried = try encoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, retried.status);
    try std.testing.expectEqualSlices(u8, "Fabc", output[0..4]);
    try std.testing.expectEqual(std.hash.XxHash64.hash(0, "abc"), std.mem.readInt(u64, output[4..12], .little));
    try std.testing.expectEqual(@as(Count, 12), encoder.stream_output);
    try std.testing.expectEqual(@as(Count, 1), encoder.frame_count);
}

test "Zstd incremental encoder counters account for retained wide history index entries" {
    var encoder = try Encoder.init(allocator, .{});
    defer encoder.deinit();
    try encoder.history.prepareCompletedBlock(allocator, "abcdefgh", 16);
    encoder.history.appendCompletedBlock("abcdefgh", 16);
    encoder.done = true;
    const exact_io = encoder.block.capacity + encoder.pending.capacity + encoder.history.bytes.capacity +
        @sizeOf(Count) * (encoder.history.index.recent_entries.capacity + encoder.history.index.long_entries.capacity);
    const before = encoder.snapshot();
    var next = encoder.options;
    next.max_total_working_memory = total.control_bytes + exact_io - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.nextFrame(next));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    next.max_total_working_memory = total.control_bytes + exact_io;
    try encoder.nextFrame(next);
    try std.testing.expectEqual(total.control_bytes + exact_io, encoder.memorySnapshot().live_requested_bytes);
}

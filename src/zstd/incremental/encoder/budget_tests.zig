const std = @import("std");
const zstd = @import("../../../zstd.zig");
const total = @import("../../encode/total_budget.zig");
const allocator = std.testing.allocator;

test "Zstd incremental total budget default zero and physical control OOM" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    const defaults: zstd.NativeFrameOptions = .{ .include_content_size = false, .selection = .raw_or_rle };
    var plain = try zstd.NativeIncrementalFrameEncoder.init(failing.allocator(), defaults);
    plain.deinit();
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    var zero = defaults;
    zero.max_total_working_memory = 0;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, zstd.NativeIncrementalFrameEncoder.init(failing.allocator(), zero));
    var profile: total.EncodeMemoryProfile = .{};
    var tracked = defaults;
    tracked.memory_profile = &profile;
    try std.testing.expectError(error.OutOfMemory, zstd.NativeIncrementalFrameEncoder.init(failing.allocator(), tracked));
    try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
}

test "Zstd incremental total budget header refusal rolls back before input and retries" {
    var profile: total.EncodeMemoryProfile = .{};
    var encoder = try zstd.NativeIncrementalFrameEncoder.init(allocator, .{
        .include_content_size = false,
        .selection = .raw_or_rle,
        .max_total_working_memory = total.control_bytes,
        .memory_profile = &profile,
    });
    var output: [17]u8 = undefined;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.step("abc", &output));
    try std.testing.expect(!encoder.header_written);
    try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
    try std.testing.expectEqual(@as(usize, 0), encoder.total_input);
    encoder.options.max_total_working_memory = null;
    const frame = try encode(&encoder, "abc");
    defer allocator.free(frame);
    try expectDecoded(frame, "abc");
    encoder.deinit();
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

test "Zstd incremental total budget retains tiny storage for large advertised windows" {
    for ([_]u6{ 27, 41 }) |window_log| {
        var profile: total.EncodeMemoryProfile = .{};
        var encoder = try zstd.NativeIncrementalFrameEncoder.init(allocator, .{
            .include_content_size = false,
            .selection = .raw_or_rle,
            .window_log = window_log,
            .max_total_working_memory = total.control_bytes + 8192,
            .memory_profile = &profile,
        });
        const frame = try encode(&encoder, "tiny advertised-window frame");
        defer allocator.free(frame);
        try std.testing.expect(profile.peak_requested_bytes <= total.control_bytes + 8192);
        try std.testing.expect(encoder.block.capacity < 8192);
        try std.testing.expectEqual(@as(usize, 0), encoder.history.bytes.capacity);
        encoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}

test "Zstd incremental total budget next frame checks retained capacity before resetting" {
    var encoder = try zstd.NativeIncrementalFrameEncoder.init(allocator, .{
        .include_content_size = false,
        .selection = .literal_only,
        .block_size_max = 64,
        .window_log = 27,
    });
    defer encoder.deinit();
    const payload = "history-capacity-adoption" ** 8;
    const frame = try encode(&encoder, payload);
    defer allocator.free(frame);
    const exact_io = encoder.block.capacity + encoder.pending.capacity + encoder.history.bytes.capacity +
        @sizeOf(usize) * (encoder.history.index.recent_entries.capacity + encoder.history.index.long_entries.capacity);
    try std.testing.expect(exact_io > encoder.history.bytes.capacity);
    const before = encoder.snapshot();
    var next = encoder.options;
    next.max_total_working_memory = total.control_bytes + exact_io - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.nextFrame(next));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqual(@as(?usize, null), encoder.options.max_total_working_memory);
    try std.testing.expect(!encoder.memorySnapshot().available);
    var profile: total.EncodeMemoryProfile = .{};
    next.max_total_working_memory = total.control_bytes + exact_io;
    next.memory_profile = &profile;
    try encoder.nextFrame(next);
    try std.testing.expectEqual(total.control_bytes + exact_io, encoder.memorySnapshot().live_requested_bytes);
    try std.testing.expect(!encoder.done);
    // Existing allocation capacity is adopted, then cleared without growth.
    try std.testing.expectEqual(@as(usize, 0), encoder.block.items.len);
}

test "Zstd incremental total budget nonfinal history refusal keeps accepted block retryable" {
    var encoder = try zstd.NativeIncrementalFrameEncoder.init(allocator, .{
        .include_content_size = false,
        .selection = .literal_only,
        .block_size_max = 16,
        .max_total_working_memory = 8 * 1024 * 1024,
    });
    defer encoder.deinit();
    const payload = "transaction-data";
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(allocator);
    var output: [17]u8 = undefined;
    const accepted = try encoder.step(payload, &output);
    try std.testing.expectEqual(payload.len, accepted.progress.input_read);
    try frame.appendSlice(allocator, output[0..accepted.progress.output_written]);
    const codec_before = encoder.codec_state;
    const hasher_before = encoder.hasher;
    encoder.options.max_total_working_memory = encoder.memorySnapshot().live_requested_bytes;
    encoder.flush();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.step("", &output));
    try std.testing.expectEqualSlices(u8, payload, encoder.block.items);
    try std.testing.expectEqualDeep(codec_before, encoder.codec_state);
    try std.testing.expectEqualDeep(hasher_before, encoder.hasher);
    try std.testing.expectEqual(@as(usize, 0), encoder.history.bytes.items.len);
    try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
    encoder.options.max_total_working_memory = null;
    while (true) {
        const result = try encoder.step("", &output);
        try frame.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    try finish(&encoder, &frame);
    try expectDecoded(frame.items, payload);
}

test "Zstd incremental total budget final output refusal preserves block and checksum transaction" {
    var encoder = try zstd.NativeIncrementalFrameEncoder.init(allocator, .{
        .include_content_size = false,
        .selection = .raw_or_rle,
        .content_checksum = true,
        .max_total_working_memory = 1024 * 1024,
    });
    defer encoder.deinit();
    var payload: [4096]u8 = undefined;
    for (&payload, 0..) |*byte, i| byte.* = @truncate(i);
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(allocator);
    var output: [17]u8 = undefined;
    const accepted = try encoder.step(&payload, &output);
    try std.testing.expectEqual(payload.len, accepted.progress.input_read);
    try frame.appendSlice(allocator, output[0..accepted.progress.output_written]);
    const hasher_before = encoder.hasher;
    const codec_before = encoder.codec_state;
    encoder.options.max_total_working_memory = encoder.memorySnapshot().live_requested_bytes;
    encoder.finish();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.step("", &output));
    try std.testing.expect(!encoder.final_written);
    try std.testing.expectEqualSlices(u8, &payload, encoder.block.items);
    try std.testing.expectEqualDeep(hasher_before, encoder.hasher);
    try std.testing.expectEqualDeep(codec_before, encoder.codec_state);
    try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
    encoder.options.max_total_working_memory = null;
    try finish(&encoder, &frame);
    try expectDecoded(frame.items, &payload);
}

fn encode(encoder: anytype, payload: []const u8) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    var output: [17]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const result = try encoder.step(payload[offset..], &output);
        offset += result.progress.input_read;
        try frame.appendSlice(allocator, output[0..result.progress.output_written]);
    }
    try finish(encoder, &frame);
    return frame.toOwnedSlice(allocator);
}

fn finish(encoder: anytype, frame: *std.ArrayList(u8)) !void {
    encoder.finish();
    var output: [17]u8 = undefined;
    while (true) {
        const result = try encoder.step("", &output);
        try frame.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
}

fn expectDecoded(frame: []const u8, payload: []const u8) !void {
    const decoded = try zstd.decodeFrameAlloc(allocator, frame);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

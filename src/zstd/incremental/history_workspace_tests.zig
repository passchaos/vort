const std = @import("std");
const core = @import("../../core.zig");
const zstd = @import("../../zstd.zig");

const Decoder = zstd.NativeIncrementalFrameDecoder;

fn encode(
    allocator: std.mem.Allocator,
    payload: []const u8,
    window_log: u6,
    include_size: bool,
) ![]u8 {
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, payload, .{
        .selection = .fast_compressed,
        .block_size_max = 1024,
        .window_log = window_log,
        .content_checksum = true,
        .include_content_size = include_size,
    });
    return encoded.frame;
}

fn drive(
    decoder: *Decoder,
    frame: []const u8,
    expected: []const u8,
    input_chunk: usize,
    output_chunk: usize,
) !void {
    const output = try std.testing.allocator.alloc(u8, expected.len + 17);
    defer std.testing.allocator.free(output);
    @memset(output, 0xa5);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(frame.len, input_offset + input_chunk);
        const output_end = @min(expected.len, output_offset + output_chunk);
        const result = try decoder.step(frame[input_offset..input_end], output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expect(result.progress.input_read != 0 or
            result.progress.output_written != 0 or result.status == .done);
    }
    try decoder.finish();
    try std.testing.expectEqual(frame.len, input_offset);
    try std.testing.expectEqual(expected.len, output_offset);
    try std.testing.expectEqualSlices(u8, expected, output[0..expected.len]);
    for (output[expected.len..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

test "Zstd history workspace validates geometry aliases and reconfiguration" {
    const window = 1024;
    try std.testing.expectEqual(window, try Decoder.requiredHistoryWorkspaceLen(window, 0));
    var storage: [window + 18]u8 = @splat(0xa5);
    var decoder = Decoder.initWithOptions(std.testing.allocator, .{ .max_window_size = window });
    defer decoder.deinit();
    try std.testing.expectError(error.OutputTooSmall, decoder.bindHistoryWorkspace(storage[0 .. window - 1]));
    try decoder.bindHistoryWorkspace(storage[1 .. window + 1]);
    try std.testing.expect(decoder.usesHistoryWorkspace());
    try std.testing.expectEqual(window, decoder.historyWorkspaceCapacity());

    const payload = "history workspace alias geometry " ** 64;
    const frame = try encode(std.testing.allocator, payload, 10, false);
    defer std.testing.allocator.free(frame);
    @memcpy(storage[1..][0..frame.len], frame);
    var output: [payload.len]u8 = undefined;
    const before = decoder.snapshot();
    try std.testing.expectError(error.InvalidBlockPlan, decoder.step(storage[1..][0..frame.len], &output));
    try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
    try std.testing.expectError(error.InvalidBlockPlan, decoder.step(frame, storage[1..17]));
    try std.testing.expectError(error.InvalidBlockPlan, decoder.bindStableOutput(&output));
    var compressed: [Decoder.compressed_block_workspace_len]u8 = undefined;
    try decoder.bindCompressedBlockWorkspace(&compressed);
    try std.testing.expectError(error.InvalidBlockPlan, decoder.bindHistoryWorkspace(compressed[0..window]));
    try std.testing.expectError(
        error.InvalidBlockPlan,
        decoder.setDictionary(zstd.NativeDictionary.init(0x9917, storage[1..33])),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        decoder.resetWithOptions(.{ .max_window_size = window, .skippable_output = storage[1..17] }),
    );
    try std.testing.expectError(error.OutputTooSmall, decoder.resetWithOptions(.{ .max_window_size = 2048 }));
    try std.testing.expect(decoder.usesHistoryWorkspace());
    try std.testing.expectEqual(@as(core.StreamCount, window), decoder.options.max_window_size);

    decoder.reset();
    _ = try decoder.step(frame[0..1], &.{});
    try std.testing.expectError(error.InvalidStreamState, decoder.clearHistoryWorkspace());
    decoder.reset();
    try decoder.clearHistoryWorkspace();
    try std.testing.expect(!decoder.usesHistoryWorkspace());
    for (storage[window + 1 ..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

test "Zstd history workspace makes ordinary tiny output allocation free" {
    const window = 1024;
    const payload = "ordinary caller ring overlap abc" ** 384;
    const frame = try encode(std.testing.allocator, payload, 10, false);
    defer std.testing.allocator.free(frame);
    var compressed: [Decoder.compressed_block_workspace_len]u8 = undefined;
    var history: [window]u8 = undefined;
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var decoder = Decoder.initWithOptions(failing.allocator(), .{
        .max_window_size = window,
        .max_working_memory = 0,
        .expected_output_len = payload.len,
    });
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&compressed);
    try decoder.bindHistoryWorkspace(&history);
    try drive(&decoder, frame, payload, 1, 1);
    try std.testing.expect(!failing.has_induced_failure);
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
    try std.testing.expect(decoder.streamedSequenceBlockCount() > 0);

    decoder.reset();
    try drive(&decoder, frame, payload, 7, 2);
    try std.testing.expect(!failing.has_induced_failure);
}

test "Zstd history workspace streams raw and RLE with zero owned heap" {
    const window = 1024;
    var random_payload: [2048]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x5170_5170);
    random.random().bytes(&random_payload);
    const rle_payload = [_]u8{0x5a} ** 2048;
    for ([_][]const u8{ &random_payload, &rle_payload }) |payload| {
        const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
            .selection = .raw_or_rle,
            .block_size_max = 1024,
            .window_log = 10,
            .content_checksum = true,
            .include_content_size = false,
        });
        defer std.testing.allocator.free(encoded.frame);
        var compressed: [Decoder.compressed_block_workspace_len]u8 = undefined;
        var history: [window]u8 = undefined;
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
        var decoder = Decoder.initWithOptions(failing.allocator(), .{
            .max_window_size = window,
            .max_working_memory = 0,
            .expected_output_len = payload.len,
        });
        defer decoder.deinit();
        try decoder.bindCompressedBlockWorkspace(&compressed);
        try decoder.bindHistoryWorkspace(&history);
        try drive(&decoder, encoded.frame, payload, 1, 1);
        try std.testing.expect(!failing.has_induced_failure);
        try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
    }
}

test "Zstd history workspace max window rejects complete headers before payload" {
    const payload = "header window admission " ** 256;
    const standard = try encode(std.testing.allocator, payload, 12, false);
    defer std.testing.allocator.free(standard);
    const standard_header = try zstd.inspectNativeFrameHeader(standard);
    try std.testing.expectEqual(@as(u64, 4096), standard_header.window_size);
    const magicless = standard[4..];

    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        for ([_]struct { frame: []const u8, format: zstd.FrameFormat, header_len: usize }{
            .{ .frame = standard, .format = .standard, .header_len = standard_header.payload_offset },
            .{ .frame = magicless, .format = .magicless, .header_len = standard_header.payload_offset - 4 },
        }) |case| {
            var decoder = Decoder.initWithOptions(std.testing.allocator, .{
                .format = case.format,
                .input_policy = policy,
                .max_window_size = 4095,
            });
            defer decoder.deinit();
            var output: [payload.len]u8 = @splat(0xa5);
            try std.testing.expectError(error.OutputLimitExceeded, decoder.step(case.frame, &output));
            try std.testing.expectEqual(@as(core.StreamCount, case.header_len), decoder.snapshot().input_received);
            try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.snapshot().output_written);
            for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
            try std.testing.expectError(error.OutputLimitExceeded, decoder.step(case.frame, &output));
            try decoder.resetWithOptions(.{
                .format = case.format,
                .input_policy = policy,
                .max_window_size = 4096,
            });
            try drive(&decoder, case.frame, payload, 7, 3);
        }
    }
}

test "Zstd history workspace max window covers single segment and dictionary precedence" {
    const small = "single segment window cap";
    const single = try encode(std.testing.allocator, small, 10, true);
    defer std.testing.allocator.free(single);
    const single_header = try zstd.inspectNativeFrameHeader(single);
    try std.testing.expectEqual(@as(u64, small.len), single_header.window_size);
    var single_decoder = Decoder.initWithOptions(std.testing.allocator, .{
        .max_window_size = small.len - 1,
    });
    defer single_decoder.deinit();
    var small_output: [small.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, single_decoder.step(single, &small_output));
    try std.testing.expectEqual(@as(core.StreamCount, single_header.payload_offset), single_decoder.snapshot().input_received);

    const dictionary = zstd.NativeDictionary.init(0x5517, "window cap dictionary" ** 8);
    const payload = "dictionary window cap precedence " ** 128;
    const encoded = try zstd.encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .fast_compressed,
        .block_size_max = 1024,
        .window_log = 12,
        .content_checksum = true,
        .include_content_size = false,
    }, dictionary);
    defer std.testing.allocator.free(encoded.frame);
    const header = try zstd.inspectNativeFrameHeader(encoded.frame);
    var missing = Decoder.initWithOptions(std.testing.allocator, .{ .max_window_size = header.window_size - 1 });
    defer missing.deinit();
    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, missing.step(encoded.frame, &output));
    try std.testing.expectEqual(@as(?u32, null), missing.requiredDictionaryId());
    try std.testing.expectEqual(@as(core.StreamCount, header.payload_offset), missing.snapshot().input_received);
}

test "Zstd history workspace keeps dictionary borrowed outside the ring" {
    const window = 1024;
    const dictionary_bytes = "dictionary caller history abcdefghijklmnopqrstuvwxyz" ** 64;
    const dictionary = zstd.NativeDictionary.init(0x7812, dictionary_bytes);
    const payload = ("abcdefghijklmnopqrstuvwxyz" ** 32) ++ ("frame output after dictionary window " ** 96);
    const encoded = try zstd.encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .fast_compressed,
        .block_size_max = 1024,
        .window_log = 10,
        .content_checksum = true,
        .include_content_size = false,
    }, dictionary);
    defer std.testing.allocator.free(encoded.frame);
    var compressed: [Decoder.compressed_block_workspace_len]u8 = undefined;
    var history: [window + dictionary_bytes.len]u8 = undefined;
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var decoder = Decoder.initWithDictionaryAndOptions(failing.allocator(), dictionary, .{
        .max_window_size = window,
        .max_working_memory = 0,
        .expected_output_len = payload.len,
    });
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&compressed);
    try decoder.bindHistoryWorkspace(&history);
    try drive(&decoder, encoded.frame, payload, 3, 1);
    try std.testing.expect(!failing.has_induced_failure);
    try std.testing.expectEqual(window + dictionary_bytes.len, decoder.historyWorkspaceCapacity());
    try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
}

test "Zstd history workspace continues stopped and concatenated frames" {
    const window = 1024;
    const payload = "caller ring next frame " ** 96;
    const frame = try encode(std.testing.allocator, payload, 10, false);
    defer std.testing.allocator.free(frame);
    const stream = try std.mem.concat(std.testing.allocator, u8, &.{ frame, frame });
    defer std.testing.allocator.free(stream);
    var compressed: [Decoder.compressed_block_workspace_len]u8 = undefined;
    var history: [window]u8 = undefined;
    var decoder = Decoder.initWithOptions(std.testing.allocator, .{
        .max_window_size = window,
        .stop_after_first_frame = true,
        .max_output_len = 2 * payload.len,
    });
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&compressed);
    try decoder.bindHistoryWorkspace(&history);
    var first: [payload.len]u8 = undefined;
    const first_step = try decoder.step(stream, &first);
    try std.testing.expectEqual(core.StepResult.Status.done, first_step.status);
    try std.testing.expectEqualSlices(u8, payload, &first);
    var input_offset = first_step.progress.input_read;
    try decoder.nextStream();
    var second: [payload.len]u8 = undefined;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const result = try decoder.step(stream[input_offset..], second[output_offset..]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqual(stream.len, input_offset);
    try std.testing.expectEqualSlices(u8, payload, &second);
    try std.testing.expect(decoder.usesHistoryWorkspace());
    decoder.reset();
    try std.testing.expect(decoder.usesHistoryWorkspace());
    try drive(&decoder, frame, payload, 1, 1);
}

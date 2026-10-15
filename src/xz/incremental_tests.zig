const std = @import("std");
const container = @import("container.zig");
const core = @import("../core.zig");
const xz = @import("../xz.zig");

const payload = "hello xz\n" ** 20;
const crc32_frame_hex = "fd377a585a0000016922de36020021010c0000008f98419ce000b300105d00341949db855c63b22e4804b99cbc0000007e9b26fd000128b401000000379a51753e300d8b020000000001595a";
const crc64_frame_hex = "fd377a585a000004e6d6b446020021010c0000008f98419ce000b300105d00341949db855c63b22e4804b99cbc0000000c15e87bd2673c5600012cb40100000021d8c0eeb1c467fb020000000004595a";

test "XZ incremental decoder accepts byte input tiny output padding and concatenation" {
    const frame = crc32Frame();
    var concatenated: [frame.len * 2 + 4]u8 = @splat(0);
    @memcpy(concatenated[0..frame.len], &frame);
    @memcpy(concatenated[frame.len + 4 ..], &frame);

    var decoder = xz.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len * 2,
        .max_output_len = payload.len * 2,
        .max_dictionary_size = 256 * 1024,
        .max_compressed_block_len = 1024,
        .max_decoded_block_len = payload.len,
        .max_index_footer_len = 1024,
    });
    defer decoder.deinit();
    const decoded = try decodeSplit(&decoder, &concatenated, 1, 7);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload ++ payload, decoded);

    const snap = decoder.snapshot();
    try std.testing.expectEqual(xz.IncrementalDecoder.Phase.done, snap.phase);
    try std.testing.expectEqual(@as(usize, 2), snap.stream_count);
    try std.testing.expectEqual(@as(usize, 2), snap.block_count);
    try std.testing.expectEqual(payload.len * 2, snap.output_written);
    try std.testing.expectEqual(@as(usize, 4), snap.padding_bytes);

    decoder.reset();
    try std.testing.expectEqual(xz.IncrementalDecoder.Phase.stream_header, decoder.snapshot().phase);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().stream_count);
}

test "XZ incremental decoder stops after first stream and exposes buffered suffix" {
    const frame = crc32Frame();
    const suffix = "ZIP descriptor after XZ footer";
    const input = frame ++ suffix.*;
    var decoder = xz.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .stop_after_first_stream = true,
        .first_stream_footer_retry_granularity = 12,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const stepped = try decoder.step(input[input_offset..], output[output_offset..]);
        input_offset += stepped.progress.input_read;
        output_offset += stepped.progress.output_written;
        if (stepped.status == .done) break;
    }
    try std.testing.expectEqualSlices(u8, payload, &output);
    var recovered_suffix: [suffix.len]u8 = undefined;
    const buffered = decoder.trailingInput();
    @memcpy(recovered_suffix[0..buffered.len], buffered);
    @memcpy(recovered_suffix[buffered.len..], input[input_offset..]);
    try std.testing.expectEqualSlices(u8, suffix, &recovered_suffix);
    try std.testing.expectEqual(buffered.len, decoder.snapshot().trailing_input_bytes);
}

test "XZ incremental decoder handles filtered multi-block output" {
    const input = try std.testing.allocator.alloc(u8, 4099);
    defer std.testing.allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index *% 29 +% index / 17);
    const chain = [_]xz.Filter{
        xz.Filter.x86(0),
        try xz.Filter.delta(4),
    };
    const encoded = try xz.encodeAlloc(std.testing.allocator, input, .{
        .check = .sha256,
        .block_size = 1024,
        .filters = &chain,
    });
    defer std.testing.allocator.free(encoded);
    const first_header_len = (@as(usize, encoded[12]) + 1) * 4;
    const first_header = try container.parseIncrementalBlockHeader(encoded[12..][0..first_header_len]);
    try std.testing.expectEqual(@as(usize, 2), first_header.filter_count);
    try std.testing.expectEqual(xz.Filter.x86(0).kind, first_header.filters[0].kind);
    try std.testing.expectEqual((try xz.Filter.delta(4)).kind, first_header.filters[1].kind);

    var decoder = xz.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = input.len,
        .max_output_len = input.len,
        .max_dictionary_size = 8 * 1024 * 1024,
        .max_compressed_block_len = 4096,
        .max_decoded_block_len = 1024,
    });
    defer decoder.deinit();
    const decoded = try decodeSplit(&decoder, encoded, 3, 13);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expectEqual(@as(usize, 5), decoder.snapshot().block_count);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().stream_count);
}

test "XZ incremental decoder honors zero-output backpressure" {
    const frame = crc64Frame();
    var decoder = xz.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const accepted = try decoder.step(&frame, &.{});
    try std.testing.expectEqual(frame.len, accepted.progress.input_read);
    try std.testing.expectEqual(core.StepResult.Status.need_input, accepted.status);
    decoder.finish();

    const blocked = try decoder.step("", &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expectEqual(payload.len, decoder.snapshot().pending_output);
    var output: [payload.len]u8 = undefined;
    const done = try decoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "XZ incremental decoder verifies block checks before output" {
    var corrupt = crc64Frame();
    const stream_header = try container.parseStreamHeader(&corrupt);
    const block_header_len = (@as(usize, corrupt[12]) + 1) * 4;
    const block_header = try container.parseIncrementalBlockHeader(corrupt[12..][0..block_header_len]);
    const block = try container.decodeIncrementalBlockAlloc(
        std.testing.allocator,
        block_header,
        corrupt[12 + block_header_len ..],
        stream_header.check,
        payload.len,
    );
    defer block.deinit(std.testing.allocator);
    corrupt[12 + block_header_len + block.consumed - 1] ^= 1;

    var output: [payload.len]u8 = @splat(0xcc);
    var decoder = xz.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    _ = try decoder.step(&corrupt, &output);
    decoder.finish();
    try std.testing.expectError(error.ChecksumMismatch, decoder.step("", &output));
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
    try std.testing.expectEqualSlices(u8, &([_]u8{0xcc} ** payload.len), &output);
}

test "XZ incremental decoder validates Index Footer and stream padding" {
    var corrupt_footer = crc32Frame();
    corrupt_footer[corrupt_footer.len - 12] ^= 1;
    var output: [payload.len]u8 = undefined;
    var decoder = xz.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    _ = try decoder.step(&corrupt_footer, &output);
    decoder.finish();
    try std.testing.expectError(error.ChecksumMismatch, drainFinished(&decoder, &output));
    try std.testing.expectEqual(payload.len, decoder.snapshot().output_written);

    const frame = crc32Frame();
    var bad_padding: [frame.len + 2]u8 = undefined;
    @memcpy(bad_padding[0..frame.len], &frame);
    @memset(bad_padding[frame.len..], 0);
    var padding_decoder = xz.IncrementalDecoder.init(std.testing.allocator);
    defer padding_decoder.deinit();
    _ = try padding_decoder.step(&bad_padding, &output);
    padding_decoder.finish();
    try std.testing.expectError(error.InvalidXzStream, drainFinished(&padding_decoder, &output));
}

test "XZ incremental decoder enforces dictionary block index and output limits" {
    const frame = crc64Frame();
    var output: [payload.len]u8 = undefined;

    var dictionary_limited = xz.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_dictionary_size = 256 * 1024 - 1,
    });
    defer dictionary_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, dictionary_limited.step(&frame, &output));

    var compressed_limited = xz.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_compressed_block_len = 8,
    });
    defer compressed_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, compressed_limited.step(&frame, &output));

    var block_limited = xz.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_decoded_block_len = payload.len - 1,
    });
    defer block_limited.deinit();
    _ = try block_limited.step(&frame, &output);
    block_limited.finish();
    try std.testing.expectError(error.OutputLimitExceeded, block_limited.step("", &output));

    var count_limited = xz.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_block_count = 0,
    });
    defer count_limited.deinit();
    _ = try count_limited.step(&frame, &output);
    count_limited.finish();
    try std.testing.expectError(error.OutputLimitExceeded, count_limited.step("", &output));

    var index_limited = xz.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_index_footer_len = 8,
    });
    defer index_limited.deinit();
    _ = try index_limited.step(&frame, &output);
    index_limited.finish();
    try std.testing.expectError(error.OutputLimitExceeded, drainFinished(&index_limited, &output));

    var output_limited = xz.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_output_len = payload.len - 1,
    });
    defer output_limited.deinit();
    _ = try output_limited.step(&frame, &output);
    output_limited.finish();
    try std.testing.expectError(error.OutputLimitExceeded, output_limited.step("", &output));

    var exact_long = xz.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len + 1,
    });
    defer exact_long.deinit();
    _ = try exact_long.step(&frame, &output);
    exact_long.finish();
    try std.testing.expectError(error.SizeMismatch, drainFinished(&exact_long, &output));
}

test "XZ incremental decoder reports every truncated fixture prefix" {
    const frame = crc32Frame();
    var output: [31]u8 = undefined;
    for (0..frame.len) |cut| {
        var decoder = xz.IncrementalDecoder.init(std.testing.allocator);
        defer decoder.deinit();
        var offset: usize = 0;
        while (offset < cut) {
            const result = try decoder.step(frame[offset..cut], &output);
            offset += result.progress.input_read;
        }
        decoder.finish();
        try std.testing.expectError(error.TruncatedFrame, drainFinished(&decoder, &output));
        try std.testing.expectEqualStrings("truncated_input", decoder.diagnostics().recoverability_hint_name);
    }
}

test "XZ incremental decoder releases every allocation failure" {
    const frame = crc64Frame();
    const Test = struct {
        fn run(allocator: std.mem.Allocator, encoded: []const u8) !void {
            var decoder = xz.IncrementalDecoder.initWithOptions(allocator, .{
                .expected_output_len = payload.len,
            });
            defer decoder.deinit();
            const output = try allocator.alloc(u8, payload.len);
            defer allocator.free(output);
            _ = try decoder.step(encoded, output);
            decoder.finish();
            const done = try decoder.step("", output);
            try std.testing.expectEqual(core.StepResult.Status.done, done.status);
            try std.testing.expectEqualSlices(u8, payload, output);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{frame[0..]});
}

fn decodeSplit(
    decoder: *xz.IncrementalDecoder,
    encoded: []const u8,
    input_chunk_len: usize,
    output_chunk_len: usize,
) ![]u8 {
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(std.testing.allocator);
    const scratch = try std.testing.allocator.alloc(u8, output_chunk_len);
    defer std.testing.allocator.free(scratch);
    var input_offset: usize = 0;
    while (input_offset < encoded.len) {
        const input_end = @min(encoded.len, input_offset + input_chunk_len);
        const result = try decoder.step(encoded[input_offset..input_end], scratch);
        input_offset += result.progress.input_read;
        try decoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    decoder.finish();
    while (true) {
        const result = try decoder.step("", scratch);
        try decoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    return decoded.toOwnedSlice(std.testing.allocator);
}

fn drainFinished(decoder: *xz.IncrementalDecoder, output: []u8) !void {
    while (true) {
        const result = try decoder.step("", output);
        if (result.status == .done) return;
    }
}

fn crc32Frame() [crc32_frame_hex.len / 2]u8 {
    var bytes: [crc32_frame_hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, crc32_frame_hex) catch unreachable;
    return bytes;
}

fn crc64Frame() [crc64_frame_hex.len / 2]u8 {
    var bytes: [crc64_frame_hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, crc64_frame_hex) catch unreachable;
    return bytes;
}

const std = @import("std");
const deflate64 = @import("../deflate64.zig");

fn decodeFragmented(
    allocator: std.mem.Allocator,
    decoder: *deflate64.IncrementalDecoder,
    input: []const u8,
    input_chunk_len: usize,
    output_chunk_len: usize,
) !struct { bytes: []u8, input_read: usize } {
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    const scratch = try allocator.alloc(u8, output_chunk_len);
    defer allocator.free(scratch);
    var input_offset: usize = 0;
    while (true) {
        const input_end = @min(input.len, input_offset + input_chunk_len);
        const stepped = try decoder.step(input[input_offset..input_end], scratch);
        input_offset += stepped.progress.input_read;
        try decoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0) {
            if (stepped.status == .need_input and input_end < input.len) continue;
            return error.TestUnexpectedResult;
        }
    }
    return .{ .bytes = try decoded.toOwnedSlice(allocator), .input_read = input_offset };
}

test "Deflate64 incremental decoder streams extended distances and leaves suffix" {
    const allocator = std.testing.allocator;
    const prefix_len = 40 * 1024;
    const payload = try allocator.alloc(u8, prefix_len * 2);
    defer allocator.free(payload);
    var state: u32 = 0x64df_1a7e;
    for (payload[0..prefix_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(payload[prefix_len..], payload[0..prefix_len]);
    const encoded = try deflate64.encodeAlloc(allocator, payload, .{});
    defer allocator.free(encoded);
    try std.testing.expect(encoded.len < payload.len);
    const suffix = "ZIP descriptor";
    const input = try std.mem.concat(allocator, u8, &.{ encoded, suffix });
    defer allocator.free(input);
    var history: [deflate64.IncrementalDecoder.required_history_len]u8 = undefined;
    var decoder = try deflate64.IncrementalDecoder.initWithHistory(.{
        .expected_output_len = payload.len,
        .max_output_len = payload.len,
        .allow_trailing_data = true,
    }, &history);
    const decoded = try decodeFragmented(allocator, &decoder, input, 1, 1);
    defer allocator.free(decoded.bytes);
    try std.testing.expectEqualSlices(u8, payload, decoded.bytes);
    try std.testing.expectEqual(encoded.len, decoded.input_read);
}

test "Deflate64 incremental decoder handles backpressure limits and truncation" {
    const allocator = std.testing.allocator;
    const payload = "Deflate64 incremental limits" ** 64;
    const encoded = try deflate64.encodeAlloc(allocator, payload, .{});
    defer allocator.free(encoded);
    var history: [deflate64.IncrementalDecoder.required_history_len]u8 = undefined;
    var decoder = try deflate64.IncrementalDecoder.initWithHistory(.{
        .expected_output_len = payload.len,
        .max_output_len = payload.len,
    }, &history);
    const blocked = try decoder.step(encoded, &.{});
    try std.testing.expect(blocked.status == .need_input or blocked.status == .need_output);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);

    var limited = try deflate64.IncrementalDecoder.initWithHistory(.{
        .max_output_len = payload.len - 1,
    }, &history);
    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded, &output));

    var truncated = try deflate64.IncrementalDecoder.initWithHistory(.{}, &history);
    _ = try truncated.step(encoded[0 .. encoded.len - 1], &output);
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
}

test "Deflate64 incremental decoder accepts a 7-Zip reference stream" {
    const allocator = std.testing.allocator;
    const payload = "Deflate64 ZIP reference\n" ** 32;
    const compressed_hex = "e5c8a10d00200c4541cf141d8230010687c611f2aa08a261ff74907ff23a7ef7a7555b635ae004ef50e45ffe353e01";
    var compressed: [compressed_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&compressed, compressed_hex);
    var history: [deflate64.IncrementalDecoder.required_history_len]u8 = undefined;
    var decoder = try deflate64.IncrementalDecoder.initWithHistory(.{
        .expected_output_len = payload.len,
    }, &history);
    const decoded = try decodeFragmented(allocator, &decoder, &compressed, 1, 3);
    defer allocator.free(decoded.bytes);
    try std.testing.expectEqualSlices(u8, payload, decoded.bytes);
    try std.testing.expectEqual(compressed.len, decoded.input_read);
}

test "Deflate64 incremental decoder requires the complete history ring" {
    var short: [64 * 1024 - 1]u8 = undefined;
    try std.testing.expectError(
        error.OutputTooSmall,
        deflate64.IncrementalDecoder.initWithHistory(.{}, &short),
    );
}

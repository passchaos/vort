const std = @import("std");
const encoder = @import("encoder.zig");
const ppmd8 = @import("../ppmd8.zig");

fn decodeFragmented(
    allocator: std.mem.Allocator,
    decoder: *ppmd8.IncrementalDecoder,
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
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0 and
            stepped.status != .need_input)
            return error.TestUnexpectedResult;
    }
    return .{ .bytes = try decoded.toOwnedSlice(allocator), .input_read = input_offset };
}

test "PPMd8 incremental decoder streams restart and cut-off models" {
    const allocator = std.testing.allocator;
    const payload = "incremental PPMd8 payload\n" ** 96;
    inline for (.{ ppmd8.RestoreMethod.restart, .cut_off }) |restore_method| {
        const encoded = try encoder.encodeAlloc(
            allocator,
            payload,
            8,
            ppmd8.zip_min_memory_size,
            restore_method,
        );
        defer allocator.free(encoded);
        const suffix = "ZIP descriptor";
        const input = try std.mem.concat(allocator, u8, &.{ encoded, suffix });
        defer allocator.free(input);
        var decoder = try ppmd8.IncrementalDecoder.init(
            allocator,
            8,
            ppmd8.zip_min_memory_size,
            restore_method,
            .{ .expected_output_len = payload.len },
        );
        defer decoder.deinit();
        const decoded = try decodeFragmented(allocator, &decoder, input, 1, 1);
        defer allocator.free(decoded.bytes);
        try std.testing.expectEqualSlices(u8, payload, decoded.bytes);
        try std.testing.expectEqual(encoded.len, decoded.input_read);
    }
}

test "PPMd8 incremental decoder enforces limits truncation and reset" {
    const allocator = std.testing.allocator;
    const payload = "PPMd limits" ** 64;
    const encoded = try encoder.encodeAlloc(
        allocator,
        payload,
        8,
        ppmd8.zip_min_memory_size,
        .restart,
    );
    defer allocator.free(encoded);
    var blocked = try ppmd8.IncrementalDecoder.init(
        allocator,
        8,
        ppmd8.zip_min_memory_size,
        .restart,
        .{},
    );
    defer blocked.deinit();
    const blocked_step = try blocked.step(encoded, &.{});
    try std.testing.expectEqual(@as(usize, 0), blocked_step.progress.output_written);
    try std.testing.expectEqual(.need_output, blocked_step.status);

    var output: [payload.len]u8 = undefined;
    var compressed_limited = try ppmd8.IncrementalDecoder.init(
        allocator,
        8,
        ppmd8.zip_min_memory_size,
        .restart,
        .{ .max_compressed_buffer_len = 3 },
    );
    defer compressed_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, compressed_limited.step(encoded, &output));

    var limited = try ppmd8.IncrementalDecoder.init(
        allocator,
        8,
        ppmd8.zip_min_memory_size,
        .restart,
        .{ .max_output_len = payload.len - 1 },
    );
    defer limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded, &output));

    var truncated = try ppmd8.IncrementalDecoder.init(
        allocator,
        8,
        ppmd8.zip_min_memory_size,
        .restart,
        .{},
    );
    defer truncated.deinit();
    _ = try truncated.step(encoded[0 .. encoded.len - 1], &output);
    truncated.finish();
    try std.testing.expectError(error.TruncatedPpmdInput, truncated.step("", &output));

    var reusable = try ppmd8.IncrementalDecoder.init(
        allocator,
        8,
        ppmd8.zip_min_memory_size,
        .restart,
        .{ .expected_output_len = payload.len },
    );
    defer reusable.deinit();
    const first = try decodeFragmented(allocator, &reusable, encoded, 3, 7);
    defer allocator.free(first.bytes);
    try reusable.reset();
    const second = try decodeFragmented(allocator, &reusable, encoded, 5, 11);
    defer allocator.free(second.bytes);
    try std.testing.expectEqualSlices(u8, payload, second.bytes);
}

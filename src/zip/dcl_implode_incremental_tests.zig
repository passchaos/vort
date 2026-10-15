const std = @import("std");
const dcl = @import("dcl_implode.zig");

fn decodeFragmented(
    allocator: std.mem.Allocator,
    decoder: *dcl.IncrementalDecoder,
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

test "DCL Implode incremental decoder accepts blast reference and suffix" {
    const allocator = std.testing.allocator;
    const encoded = [_]u8{ 0x00, 0x04, 0x82, 0x24, 0x25, 0x8f, 0x80, 0x7f };
    const suffix = "ZIP descriptor";
    const input = encoded ++ suffix.*;
    var decoder = dcl.IncrementalDecoder.initWithOptions(.{
        .expected_output_len = 13,
        .allow_trailing_data = true,
    });
    const decoded = try decodeFragmented(allocator, &decoder, &input, 1, 1);
    defer allocator.free(decoded.bytes);
    try std.testing.expectEqualSlices(u8, "AIAIAIAIAIAIA", decoded.bytes);
    try std.testing.expectEqual(encoded.len, decoded.input_read);
}

test "DCL Implode incremental decoder streams literal and dictionary modes" {
    const allocator = std.testing.allocator;
    const payload = "DCL progressive payload\n" ** 173;
    inline for (.{ false, true }) |literal_coded| {
        inline for (std.meta.tags(dcl.Dictionary)) |dictionary| {
            const encoded = try dcl.encodeAlloc(allocator, payload, .{
                .literal_coded = literal_coded,
                .dictionary = dictionary,
            });
            defer allocator.free(encoded);
            var decoder = dcl.IncrementalDecoder.initWithOptions(.{
                .expected_output_len = payload.len,
            });
            const decoded = try decodeFragmented(allocator, &decoder, encoded, 1, 3);
            defer allocator.free(decoded.bytes);
            try std.testing.expectEqualSlices(u8, payload, decoded.bytes);
        }
    }
}

test "DCL Implode incremental decoder enforces backpressure limits truncation and reset" {
    const allocator = std.testing.allocator;
    const payload = "DCL limits" ** 64;
    const encoded = try dcl.encodeAlloc(allocator, payload, .{});
    defer allocator.free(encoded);
    var blocked = dcl.IncrementalDecoder.init();
    const blocked_step = try blocked.step(encoded, &.{});
    try std.testing.expectEqual(@as(usize, 0), blocked_step.progress.output_written);
    try std.testing.expect(blocked_step.status == .need_input or blocked_step.status == .need_output);

    var limited = dcl.IncrementalDecoder.initWithOptions(.{
        .max_output_len = payload.len - 1,
    });
    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded, &output));

    var truncated = dcl.IncrementalDecoder.init();
    _ = try truncated.step(encoded[0 .. encoded.len - 1], &output);
    try std.testing.expectError(error.TruncatedDclInput, truncated.finish());
    try std.testing.expectEqualStrings("TruncatedDclInput", truncated.diagnostics().last_error_name);

    var reusable = dcl.IncrementalDecoder.initWithOptions(.{
        .expected_output_len = payload.len,
    });
    const first = try decodeFragmented(allocator, &reusable, encoded, 3, 7);
    defer allocator.free(first.bytes);
    reusable.reset();
    const second = try decodeFragmented(allocator, &reusable, encoded, 5, 11);
    defer allocator.free(second.bytes);
    try std.testing.expectEqualSlices(u8, payload, second.bytes);
}

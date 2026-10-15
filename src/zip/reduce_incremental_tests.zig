const std = @import("std");
const reduce = @import("reduce.zig");

fn decodeFragmented(
    allocator: std.mem.Allocator,
    decoder: *reduce.IncrementalDecoder,
    input: []const u8,
    input_chunk_len: usize,
    output_chunk_len: usize,
) ![]u8 {
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    const scratch = try allocator.alloc(u8, output_chunk_len);
    defer allocator.free(scratch);
    var input_offset: usize = 0;
    var finish_requested = false;
    while (true) {
        const input_end = @min(input.len, input_offset + input_chunk_len);
        const stepped = try decoder.step(input[input_offset..input_end], scratch);
        input_offset += stepped.progress.input_read;
        try decoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (input_offset == input.len and !finish_requested) {
            decoder.finish();
            finish_requested = true;
        }
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0 and
            stepped.status != .need_input)
            return error.TestUnexpectedResult;
    }
    try std.testing.expectEqual(input.len, input_offset);
    return decoded.toOwnedSlice(allocator);
}

fn writeBits(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    reservoir: *u64,
    bit_count: *u8,
    value: u8,
    count: u4,
) !void {
    if (count == 0) return;
    reservoir.* |= @as(u64, value) << @intCast(bit_count.*);
    bit_count.* += count;
    while (bit_count.* >= 8) {
        try output.append(allocator, @truncate(reservoir.*));
        reservoir.* >>= 8;
        bit_count.* -= 8;
    }
}

fn finishBits(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    reservoir: *u64,
    bit_count: *u8,
) !void {
    if (bit_count.* != 0) try output.append(allocator, @truncate(reservoir.*));
    reservoir.* = 0;
    bit_count.* = 0;
}

test "Reduce incremental decoder streams every factor" {
    const allocator = std.testing.allocator;
    const payload = ("caller-output Reduce follower payload\x90\n" ** 257) ++
        ([_]u8{ 0, 1, 2, 3, 4, 5, 0xfe, 0xff } ** 193);
    inline for (std.meta.tags(reduce.Factor)) |factor| {
        const encoded = try reduce.encodeAlloc(allocator, payload, factor, .{});
        defer allocator.free(encoded);
        var workspace: reduce.IncrementalWorkspace = undefined;
        var decoder = reduce.IncrementalDecoder.initWithOptions(&workspace, factor, .{
            .expected_output_len = payload.len,
        });
        const decoded = try decodeFragmented(allocator, &decoder, encoded, 1, 3);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "Reduce incremental decoder handles implicit zero history and malformed followers" {
    const allocator = std.testing.allocator;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var reservoir: u64 = 0;
    var bit_count: u8 = 0;
    for (0..256) |_| try writeBits(&encoded, allocator, &reservoir, &bit_count, 0, 6);
    inline for (.{ @as(u8, 144), @as(u8, 1), @as(u8, 3) }) |byte|
        try writeBits(&encoded, allocator, &reservoir, &bit_count, byte, 8);
    try finishBits(&encoded, allocator, &reservoir, &bit_count);

    var workspace: reduce.IncrementalWorkspace = undefined;
    var decoder = reduce.IncrementalDecoder.initWithOptions(&workspace, .factor_1, .{
        .expected_output_len = 4,
    });
    const decoded = try decodeFragmented(allocator, &decoder, encoded.items, 1, 1);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, decoded);

    encoded.clearRetainingCapacity();
    reservoir = 0;
    bit_count = 0;
    var context: usize = 256;
    while (context != 0) {
        context -= 1;
        if (context == 0) {
            try writeBits(&encoded, allocator, &reservoir, &bit_count, 3, 6);
            inline for (.{ @as(u8, 'A'), @as(u8, 'B'), @as(u8, 'C') }) |byte|
                try writeBits(&encoded, allocator, &reservoir, &bit_count, byte, 8);
        } else {
            try writeBits(&encoded, allocator, &reservoir, &bit_count, 0, 6);
        }
    }
    try writeBits(&encoded, allocator, &reservoir, &bit_count, 0, 1);
    try writeBits(&encoded, allocator, &reservoir, &bit_count, 3, 2);
    try finishBits(&encoded, allocator, &reservoir, &bit_count);
    decoder.reset();
    var scratch: [4]u8 = undefined;
    try std.testing.expectError(error.InvalidReduceStream, decoder.step(encoded.items, &scratch));

    const ambiguous = try reduce.encodeAlloc(allocator, "AA", .factor_1, .{});
    defer allocator.free(ambiguous);
    var ambiguous_workspace: reduce.IncrementalWorkspace = undefined;
    var unpledged = reduce.IncrementalDecoder.init(&ambiguous_workspace, .factor_1);
    var ambiguous_output: [16]u8 = undefined;
    const ambiguous_step = try unpledged.step(ambiguous, &ambiguous_output);
    try std.testing.expect(ambiguous_step.progress.output_written > 2);
    try std.testing.expectEqualSlices(
        u8,
        "AA",
        ambiguous_output[0..2],
    );
}

test "Reduce incremental decoder enforces backpressure limits truncation and reset" {
    const allocator = std.testing.allocator;
    const payload = "Reduce incremental limits \x90" ** 113;
    const encoded = try reduce.encodeAlloc(allocator, payload, .factor_4, .{});
    defer allocator.free(encoded);

    var workspace: reduce.IncrementalWorkspace = undefined;
    var decoder = reduce.IncrementalDecoder.initWithOptions(&workspace, .factor_4, .{
        .expected_output_len = payload.len,
    });
    const blocked = try decoder.step(encoded, &.{});
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);
    try std.testing.expectEqual(.need_output, blocked.status);

    decoder.reset();
    const first = try decodeFragmented(allocator, &decoder, encoded, 5, 11);
    defer allocator.free(first);
    try std.testing.expectEqualSlices(u8, payload, first);
    decoder.reset();
    const second = try decodeFragmented(allocator, &decoder, encoded, 7, 13);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, payload, second);

    var limited_workspace: reduce.IncrementalWorkspace = undefined;
    var limited = reduce.IncrementalDecoder.initWithOptions(&limited_workspace, .factor_4, .{
        .max_output_len = payload.len - 1,
    });
    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded, output));

    var truncated_workspace: reduce.IncrementalWorkspace = undefined;
    var truncated = reduce.IncrementalDecoder.initWithOptions(&truncated_workspace, .factor_4, .{
        .expected_output_len = payload.len,
    });
    _ = try truncated.step(encoded[0 .. encoded.len - 1], output);
    truncated.finish();
    _ = truncated.step("", output) catch |err| {
        try std.testing.expect(err == error.TruncatedReduceInput or err == error.ReduceSizeMismatch);
        try std.testing.expect(truncated.diagnostics().last_error_name.len != 0);
        return;
    };
    return error.TestExpectedError;
}

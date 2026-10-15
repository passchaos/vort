const std = @import("std");
const shrink = @import("shrink.zig");

fn decodeFragmented(
    allocator: std.mem.Allocator,
    decoder: *shrink.IncrementalDecoder,
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

fn appendCode(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    reservoir: *u64,
    bit_count: *u8,
    value: u16,
    bits: u4,
) !void {
    reservoir.* |= @as(u64, value) << @intCast(bit_count.*);
    bit_count.* += bits;
    while (bit_count.* >= 8) {
        try output.append(allocator, @truncate(reservoir.*));
        reservoir.* >>= 8;
        bit_count.* -= 8;
    }
}

test "Shrink incremental decoder streams width growth and binary payloads" {
    const allocator = std.testing.allocator;
    const payload = ("caller-output Shrink LZW payload\n" ** 700) ++
        ([_]u8{ 0, 1, 2, 3, 0xfe, 0xff } ** 300);
    const encoded = try shrink.encodeAlloc(allocator, payload);
    defer allocator.free(encoded);
    var workspace: shrink.IncrementalWorkspace = undefined;
    var decoder = shrink.IncrementalDecoder.initWithOptions(&workspace, .{
        .expected_output_len = payload.len,
    });
    const decoded = try decodeFragmented(allocator, &decoder, encoded, 1, 3);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(decoder.snapshot().code_bits > 9);
}

test "Shrink incremental decoder preserves partial-clear state across chunks" {
    const allocator = std.testing.allocator;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var reservoir: u64 = 0;
    var bit_count: u8 = 0;
    inline for (.{ @as(u16, 'A'), @as(u16, 'B'), @as(u16, 256), @as(u16, 2), @as(u16, 'A') }) |code|
        try appendCode(&encoded, allocator, &reservoir, &bit_count, code, 9);
    if (bit_count != 0) try encoded.append(allocator, @truncate(reservoir));

    var workspace: shrink.IncrementalWorkspace = undefined;
    var decoder = shrink.IncrementalDecoder.initWithOptions(&workspace, .{
        .expected_output_len = 3,
    });
    const decoded = try decodeFragmented(allocator, &decoder, encoded.items, 1, 1);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ABA", decoded);

    var invalid: std.ArrayList(u8) = .empty;
    defer invalid.deinit(allocator);
    reservoir = 0;
    bit_count = 0;
    inline for (.{ @as(u16, 256), @as(u16, 3) }) |code|
        try appendCode(&invalid, allocator, &reservoir, &bit_count, code, 9);
    if (bit_count != 0) try invalid.append(allocator, @truncate(reservoir));
    decoder.reset();
    var scratch: [3]u8 = undefined;
    try std.testing.expectError(error.InvalidShrinkStream, decoder.step(invalid.items, &scratch));

    var truncated_workspace: shrink.IncrementalWorkspace = undefined;
    var truncated = shrink.IncrementalDecoder.init(&truncated_workspace);
    var control_only: std.ArrayList(u8) = .empty;
    defer control_only.deinit(allocator);
    reservoir = 0;
    bit_count = 0;
    try appendCode(&control_only, allocator, &reservoir, &bit_count, 256, 9);
    if (bit_count != 0) try control_only.append(allocator, @truncate(reservoir));
    _ = try truncated.step(control_only.items, &scratch);
    truncated.finish();
    try std.testing.expectError(error.TruncatedShrinkInput, truncated.step("", &scratch));
}

test "Shrink incremental decoder enforces backpressure limits padding and reset" {
    const allocator = std.testing.allocator;
    const payload = "Shrink incremental limits" ** 97;
    const encoded = try shrink.encodeAlloc(allocator, payload);
    defer allocator.free(encoded);

    var workspace: shrink.IncrementalWorkspace = undefined;
    var decoder = shrink.IncrementalDecoder.initWithOptions(&workspace, .{
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

    var limited_workspace: shrink.IncrementalWorkspace = undefined;
    var limited = shrink.IncrementalDecoder.initWithOptions(&limited_workspace, .{
        .max_output_len = payload.len - 1,
    });
    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded, &output));

    const one = try shrink.encodeAlloc(allocator, "A");
    defer allocator.free(one);
    var corrupt = try allocator.dupe(u8, one);
    defer allocator.free(corrupt);
    corrupt[corrupt.len - 1] |= 0x80;
    var corrupt_workspace: shrink.IncrementalWorkspace = undefined;
    var corrupt_decoder = shrink.IncrementalDecoder.initWithOptions(&corrupt_workspace, .{
        .expected_output_len = 1,
    });
    _ = try corrupt_decoder.step(corrupt, output[0..1]);
    corrupt_decoder.finish();
    try std.testing.expectError(error.ShrinkTrailingData, corrupt_decoder.step("", &.{}));

    var truncated_workspace: shrink.IncrementalWorkspace = undefined;
    var truncated = shrink.IncrementalDecoder.initWithOptions(&truncated_workspace, .{
        .expected_output_len = payload.len,
    });
    _ = try truncated.step(encoded[0 .. encoded.len - 1], &output);
    truncated.finish();
    try std.testing.expectError(error.ShrinkSizeMismatch, truncated.step("", &output));
    try std.testing.expectEqualStrings("ShrinkSizeMismatch", truncated.diagnostics().last_error_name);
}

const std = @import("std");
const implode = @import("implode.zig");

fn decodeFragmented(
    allocator: std.mem.Allocator,
    decoder: *implode.IncrementalDecoder,
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
    value: u16,
    count: u5,
) !void {
    reservoir.* |= @as(u64, value) << @intCast(bit_count.*);
    bit_count.* += @intCast(count);
    while (bit_count.* >= 8) {
        try output.append(allocator, @truncate(reservoir.*));
        reservoir.* >>= 8;
        bit_count.* -= 8;
    }
}

fn reverseBits(value: u16, count: u5) u16 {
    var source = value;
    var result: u16 = 0;
    for (0..count) |_| {
        result = (result << 1) | (source & 1);
        source >>= 1;
    }
    return result;
}

fn appendFixedTree(output: *std.ArrayList(u8), allocator: std.mem.Allocator, symbols: usize, bits: u8) !void {
    const records = symbols / 16;
    try output.append(allocator, @intCast(records - 1));
    try output.appendNTimes(allocator, 0xf0 | (bits - 1), records);
}

test "Legacy Implode incremental decoder streams every dictionary and literal mode" {
    const allocator = std.testing.allocator;
    const payload = ("caller-output Implode Shannon-Fano payload\n" ** 211) ++
        ([_]u8{ 0, 1, 2, 3, 4, 5, 0xfe, 0xff } ** 173);
    inline for (.{ implode.Dictionary.small_4k, .large_8k }) |dictionary| {
        inline for (.{ false, true }) |literal_tree| {
            const options = implode.Options{
                .dictionary = dictionary,
                .literal_tree = literal_tree,
            };
            const encoded = try implode.encodeAlloc(allocator, payload, options);
            defer allocator.free(encoded);
            var workspace: implode.IncrementalWorkspace = undefined;
            var decoder = implode.IncrementalDecoder.initWithOptions(
                &workspace,
                options.flags(),
                .{ .expected_output_len = payload.len },
            );
            const decoded = try decodeFragmented(allocator, &decoder, encoded, 1, 3);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, payload, decoded);
        }
    }
}

test "Legacy Implode incremental decoder handles implicit zero history and malformed trees" {
    const allocator = std.testing.allocator;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendFixedTree(&encoded, allocator, 64, 6);
    try appendFixedTree(&encoded, allocator, 64, 6);
    var reservoir: u64 = 0;
    var bit_count: u8 = 0;
    try writeBits(&encoded, allocator, &reservoir, &bit_count, 0, 1);
    try writeBits(&encoded, allocator, &reservoir, &bit_count, 3, 6);
    try writeBits(&encoded, allocator, &reservoir, &bit_count, reverseBits(63, 6), 6);
    try writeBits(&encoded, allocator, &reservoir, &bit_count, reverseBits(61, 6), 6);
    if (bit_count != 0) try encoded.append(allocator, @truncate(reservoir));

    const flags = (implode.Options{
        .dictionary = .small_4k,
        .literal_tree = false,
    }).flags();
    var workspace: implode.IncrementalWorkspace = undefined;
    var decoder = implode.IncrementalDecoder.initWithOptions(&workspace, flags, .{
        .expected_output_len = 4,
    });
    const decoded = try decodeFragmented(allocator, &decoder, encoded.items, 1, 1);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, decoded);

    var invalid_workspace: implode.IncrementalWorkspace = undefined;
    var invalid = implode.IncrementalDecoder.initWithOptions(&invalid_workspace, 0, .{
        .expected_output_len = 1,
    });
    var scratch: [1]u8 = undefined;
    try std.testing.expectError(error.InvalidImplodeStream, invalid.step(&.{ 0, 0 }, &scratch));
}

test "Legacy Implode incremental decoder enforces backpressure limits truncation and reset" {
    const allocator = std.testing.allocator;
    const payload = "Implode incremental limits" ** 127;
    const options = implode.Options{};
    const encoded = try implode.encodeAlloc(allocator, payload, options);
    defer allocator.free(encoded);

    var workspace: implode.IncrementalWorkspace = undefined;
    var decoder = implode.IncrementalDecoder.initWithOptions(&workspace, options.flags(), .{
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

    var limited_workspace: implode.IncrementalWorkspace = undefined;
    var limited = implode.IncrementalDecoder.initWithOptions(&limited_workspace, options.flags(), .{
        .max_output_len = payload.len - 1,
    });
    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded, output));

    var truncated_workspace: implode.IncrementalWorkspace = undefined;
    var truncated = implode.IncrementalDecoder.initWithOptions(&truncated_workspace, options.flags(), .{
        .expected_output_len = payload.len,
    });
    _ = try truncated.step(encoded[0 .. encoded.len - 1], output);
    truncated.finish();
    _ = truncated.step("", output) catch |err| {
        try std.testing.expect(err == error.TruncatedImplodeInput or err == error.ImplodeSizeMismatch);
        try std.testing.expect(truncated.diagnostics().last_error_name.len != 0);
        return;
    };
    return error.TestExpectedError;
}

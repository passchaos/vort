const std = @import("std");
const implode = @import("implode.zig");
const incremental = @import("implode/incremental_encoder.zig");

fn encodeFragmented(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: incremental.Encoder.Options,
    expected_size: ?usize,
    input_chunk_len: usize,
    output_chunk_len: usize,
) ![]u8 {
    var encoder = if (expected_size) |expected|
        try incremental.Encoder.initExactSize(allocator, options, expected)
    else
        try incremental.Encoder.initWithOptions(allocator, options);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    const scratch = try allocator.alloc(u8, output_chunk_len);
    defer allocator.free(scratch);

    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const input_end = @min(input.len, input_offset + input_chunk_len);
        while (input_offset < input_end) {
            const stepped = try encoder.step(input[input_offset..input_end], scratch);
            input_offset += stepped.progress.input_read;
            try encoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
            if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
                return error.TestUnexpectedResult;
        }
    }
    encoder.finish();
    while (true) {
        const stepped = try encoder.step("", scratch);
        try encoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (stepped.progress.output_written == 0) return error.TestUnexpectedResult;
    }
    return encoded.toOwnedSlice(allocator);
}

fn makePayload(allocator: std.mem.Allocator) ![]u8 {
    const prefix_len = 5000;
    const payload = try allocator.alloc(u8, prefix_len * 2 + 1);
    var state: u32 = 0x193a_72d5;
    for (payload[0..prefix_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    payload[prefix_len] = 0x42;
    @memcpy(payload[prefix_len + 1 ..], payload[0..prefix_len]);
    return payload;
}

test "Legacy Implode incremental encoder is byte exact in all modes" {
    const allocator = std.testing.allocator;
    const payload = try makePayload(allocator);
    defer allocator.free(payload);
    inline for (.{ implode.Dictionary.small_4k, .large_8k }) |dictionary| {
        inline for (.{ false, true }) |literal_tree| {
            const one_shot_options = implode.Options{
                .dictionary = dictionary,
                .literal_tree = literal_tree,
            };
            const expected = try implode.encodeAlloc(allocator, payload, one_shot_options);
            defer allocator.free(expected);
            const actual = try encodeFragmented(
                allocator,
                payload,
                .{
                    .dictionary = dictionary,
                    .literal_tree = literal_tree,
                },
                payload.len,
                3,
                1,
            );
            defer allocator.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
            const decoded = try allocator.alloc(u8, payload.len);
            defer allocator.free(decoded);
            try implode.decodeInto(actual, decoded, one_shot_options.flags());
            try std.testing.expectEqualSlices(u8, payload, decoded);
        }
    }
}

test "Legacy Implode incremental encoder preserves 8 KiB match reach" {
    const allocator = std.testing.allocator;
    const payload = try makePayload(allocator);
    defer allocator.free(payload);
    const small = try encodeFragmented(
        allocator,
        payload,
        .{ .dictionary = .small_4k, .literal_tree = false },
        null,
        521,
        7,
    );
    defer allocator.free(small);
    const large = try encodeFragmented(
        allocator,
        payload,
        .{ .dictionary = .large_8k, .literal_tree = false },
        null,
        521,
        7,
    );
    defer allocator.free(large);
    try std.testing.expect(large.len < small.len);
}

test "Legacy Implode incremental encoder handles backpressure limits and reset" {
    const allocator = std.testing.allocator;
    var encoder = try incremental.Encoder.init(allocator);
    defer encoder.deinit();
    const blocked = try encoder.step("payload", &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.input_read);

    var scratch: [64]u8 = undefined;
    _ = try encoder.step("abc", &scratch);
    encoder.finish();
    while ((try encoder.step("", &scratch)).status != .done) {}
    encoder.reset();

    var limited = try incremental.Encoder.initWithOptions(allocator, .{
        .max_input_len = 3,
    });
    defer limited.deinit();
    _ = try limited.step("abc", &scratch);
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("d", &scratch));

    var pledged = try incremental.Encoder.initExactSize(allocator, .{}, 4);
    defer pledged.deinit();
    _ = try pledged.step("abc", &scratch);
    pledged.finish();
    try std.testing.expectError(error.ImplodeSizeMismatch, pledged.step("", &scratch));

    try std.testing.expectError(
        error.InvalidImplodeOptions,
        incremental.Encoder.initWithOptions(allocator, .{ .max_chain = 0 }),
    );
}

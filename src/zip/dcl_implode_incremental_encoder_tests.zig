const std = @import("std");
const dcl = @import("dcl_implode.zig");
const incremental = @import("dcl_implode/incremental_encoder.zig");

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

fn makeLongDistancePayload(allocator: std.mem.Allocator) ![]u8 {
    const prefix_len = 3000;
    const payload = try allocator.alloc(u8, prefix_len * 2 + 1);
    var state: u32 = 0xdca1_0010;
    for (payload[0..prefix_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    payload[prefix_len] = 0x42;
    @memcpy(payload[prefix_len + 1 ..], payload[0..prefix_len]);
    return payload;
}

test "DCL Implode incremental encoder is byte exact in all header modes" {
    const allocator = std.testing.allocator;
    const payload = try makeLongDistancePayload(allocator);
    defer allocator.free(payload);

    inline for (.{ false, true }) |literal_coded| {
        inline for (std.meta.tags(dcl.Dictionary)) |dictionary| {
            const one_shot_options = dcl.Options{
                .literal_coded = literal_coded,
                .dictionary = dictionary,
            };
            const expected = try dcl.encodeAlloc(allocator, payload, one_shot_options);
            defer allocator.free(expected);
            const actual = try encodeFragmented(
                allocator,
                payload,
                .{
                    .literal_coded = literal_coded,
                    .dictionary = dictionary,
                },
                payload.len,
                3,
                1,
            );
            defer allocator.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
            const decoded = try allocator.alloc(u8, payload.len);
            defer allocator.free(decoded);
            try dcl.decodeInto(actual, decoded);
            try std.testing.expectEqualSlices(u8, payload, decoded);
        }
    }
}

test "DCL Implode incremental encoder preserves 4 KiB match reach" {
    const allocator = std.testing.allocator;
    const payload = try makeLongDistancePayload(allocator);
    defer allocator.free(payload);
    const two_k = try encodeFragmented(
        allocator,
        payload,
        .{ .literal_coded = false, .dictionary = .size_2k },
        null,
        521,
        7,
    );
    defer allocator.free(two_k);
    const four_k = try encodeFragmented(
        allocator,
        payload,
        .{ .literal_coded = false, .dictionary = .size_4k },
        null,
        521,
        7,
    );
    defer allocator.free(four_k);
    try std.testing.expect(four_k.len < two_k.len);
}

test "DCL Implode incremental encoder handles empty backpressure limits and reset" {
    const allocator = std.testing.allocator;
    var encoder = try incremental.Encoder.init(allocator);
    defer encoder.deinit();
    const blocked = try encoder.step("payload", &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.input_read);
    encoder.finish();
    var scratch: [16]u8 = undefined;
    while ((try encoder.step("", &scratch)).status != .done) {}
    encoder.reset();

    const first = try encoder.step("abc", &scratch);
    try std.testing.expectEqual(@as(usize, 3), first.progress.input_read);
    encoder.finish();
    while ((try encoder.step("", &scratch)).status != .done) {}

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
    try std.testing.expectError(error.DclSizeMismatch, pledged.step("", &scratch));

    try std.testing.expectError(
        error.InvalidDclOptions,
        incremental.Encoder.initWithOptions(allocator, .{ .max_chain = 0 }),
    );
}

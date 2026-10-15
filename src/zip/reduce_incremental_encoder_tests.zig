const std = @import("std");
const reduce = @import("reduce.zig");
const incremental = @import("reduce/incremental_encoder.zig");

fn encodeFragmented(
    allocator: std.mem.Allocator,
    input: []const u8,
    factor: reduce.Factor,
    options: incremental.Encoder.Options,
    expected_size: ?usize,
    input_chunk_len: usize,
    output_chunk_len: usize,
) ![]u8 {
    var encoder = if (expected_size) |expected|
        try incremental.Encoder.initExactSize(allocator, factor, options, expected)
    else
        try incremental.Encoder.initWithOptions(allocator, factor, options);
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
    const prefix_len = 3000;
    const payload = try allocator.alloc(u8, prefix_len * 2 + 3);
    var state: u32 = 0x4050_6074;
    for (payload[0..prefix_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    payload[prefix_len] = reduce.dle;
    payload[prefix_len + 1] = 0x42;
    payload[prefix_len + 2] = reduce.dle;
    @memcpy(payload[prefix_len + 3 ..], payload[0..prefix_len]);
    return payload;
}

test "Reduce incremental encoder matches trained one-shot wire for every factor" {
    const allocator = std.testing.allocator;
    const payload = try makePayload(allocator);
    defer allocator.free(payload);
    inline for (std.meta.tags(reduce.Factor)) |factor| {
        const followers = try reduce.trainFollowerTable(allocator, payload, factor, .{});
        const expected = try reduce.encodeAlloc(allocator, payload, factor, .{});
        defer allocator.free(expected);
        const actual = try encodeFragmented(
            allocator,
            payload,
            factor,
            .{ .followers = followers },
            payload.len,
            3,
            1,
        );
        defer allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
        const decoded = try allocator.alloc(u8, payload.len);
        defer allocator.free(decoded);
        try reduce.decodeInto(actual, decoded, factor);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "Reduce incremental encoder streams an untrained bounded pass" {
    const allocator = std.testing.allocator;
    const payload = "single-pass Reduce follower payload \x90\n" ** 257;
    inline for (std.meta.tags(reduce.Factor)) |factor| {
        const encoded = try encodeFragmented(
            allocator,
            payload,
            factor,
            .{},
            null,
            5,
            7,
        );
        defer allocator.free(encoded);
        const decoded = try allocator.alloc(u8, payload.len);
        defer allocator.free(decoded);
        try reduce.decodeInto(encoded, decoded, factor);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "Reduce incremental encoder handles backpressure limits reset and presets" {
    const allocator = std.testing.allocator;
    var encoder = try incremental.Encoder.init(allocator, .factor_4);
    defer encoder.deinit();
    const blocked = try encoder.step("payload", &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.input_read);

    var scratch: [256]u8 = undefined;
    var header_drained = false;
    while (!header_drained) {
        const stepped = try encoder.step("", &scratch);
        header_drained = stepped.status == .need_input;
    }
    _ = try encoder.step("abc", &scratch);
    encoder.finish();
    while ((try encoder.step("", &scratch)).status != .done) {}
    encoder.reset();

    var limited = try incremental.Encoder.initWithOptions(allocator, .factor_1, .{
        .max_input_len = 3,
    });
    defer limited.deinit();
    while ((try limited.step("", &scratch)).status != .need_input) {}
    _ = try limited.step("abc", &scratch);
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("d", &scratch));

    var pledged = try incremental.Encoder.initExactSize(allocator, .factor_2, .{}, 4);
    defer pledged.deinit();
    while ((try pledged.step("", &scratch)).status != .need_input) {}
    _ = try pledged.step("abc", &scratch);
    pledged.finish();
    try std.testing.expectError(error.ReduceSizeMismatch, pledged.step("", &scratch));

    var invalid_followers = reduce.FollowerTable{};
    invalid_followers.counts[0] = 33;
    try std.testing.expectError(
        error.InvalidReduceStream,
        incremental.Encoder.initWithOptions(allocator, .factor_3, .{
            .followers = invalid_followers,
        }),
    );
    try std.testing.expectError(
        error.InvalidReduceOptions,
        incremental.Encoder.initWithOptions(allocator, .factor_4, .{ .max_chain = 0 }),
    );
}

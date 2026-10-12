const std = @import("std");
const core = @import("../core.zig");
const lzma = @import("../lzma.zig");

test "LZMA incremental greedy encoder is byte exact across planning windows" {
    var input: [40_000]u8 = undefined;
    var state: u32 = 0x4c5a_4d41;
    for (input[0..10_000]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[10_000..20_000], input[0..10_000]);
    @memcpy(input[20_000..30_000], input[0..10_000]);
    @memcpy(input[30_000..40_000], input[0..10_000]);
    const options = lzma.EncodeOptions{
        .dictionary_size = 32 * 1024,
        .mode = .greedy,
        .size_mode = .end_marker,
    };
    const one_shot = try lzma.encodeAlloc(std.testing.allocator, &input, options);
    defer std.testing.allocator.free(one_shot);
    var encoder = try lzma.IncrementalEncoder.initExactSize(std.testing.allocator, .{
        .dictionary_size = options.dictionary_size,
        .mode = options.mode,
        .size_mode = options.size_mode,
        .input_buffer_len = 1024,
    }, input.len);
    defer encoder.deinit();
    const incremental = try encodeSplit(&encoder, &input, 1, 7);
    defer std.testing.allocator.free(incremental);
    try std.testing.expectEqualSlices(u8, one_shot, incremental);
    try std.testing.expect(encoder.snapshot().matches != 0);
    try std.testing.expect(encoder.snapshot().new_distance_matches != 0);
    try std.testing.expect(encoder.snapshot().repeat_matches != 0);
    const decoded = try lzma.decodeAlloc(std.testing.allocator, incremental);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "LZMA incremental literal encoder matches known-size one-shot" {
    var input: [2049]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @truncate(index *% 37 +% index / 11);
    const options = lzma.EncodeOptions{
        .dictionary_size = 4096,
        .mode = .literal_only,
        .size_mode = .known,
    };
    const one_shot = try lzma.encodeAlloc(std.testing.allocator, &input, options);
    defer std.testing.allocator.free(one_shot);
    var encoder = try lzma.IncrementalEncoder.initExactSize(std.testing.allocator, .{
        .dictionary_size = options.dictionary_size,
        .mode = options.mode,
        .size_mode = options.size_mode,
        .input_buffer_len = 257,
    }, input.len);
    defer encoder.deinit();
    const incremental = try encodeSplit(&encoder, &input, 3, 9);
    defer std.testing.allocator.free(incremental);
    try std.testing.expectEqualSlices(u8, one_shot, incremental);
    try std.testing.expectEqual(input.len, encoder.snapshot().literals);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().matches);
}

test "LZMA incremental encoder matches empty known and end-marker streams" {
    inline for (.{ lzma.SizeMode.known, lzma.SizeMode.end_marker }) |size_mode| {
        const one_shot = try lzma.encodeAlloc(std.testing.allocator, "", .{ .size_mode = size_mode });
        defer std.testing.allocator.free(one_shot);
        var encoder = try lzma.IncrementalEncoder.initExactSize(std.testing.allocator, .{
            .size_mode = size_mode,
        }, 0);
        defer encoder.deinit();
        const incremental = try encodeSplit(&encoder, "", 1, 1);
        defer std.testing.allocator.free(incremental);
        try std.testing.expectEqualSlices(u8, one_shot, incremental);
    }
}

test "LZMA incremental encoder honors zero-output backpressure" {
    var encoder = try lzma.IncrementalEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    const blocked = try encoder.step("payload", &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.input_read);
    try std.testing.expectEqual(@as(usize, 13), encoder.snapshot().pending_output);

    var header: [13]u8 = undefined;
    const accepted = try encoder.step("payload", &header);
    try std.testing.expectEqual(core.StepResult.Status.need_input, accepted.status);
    encoder.finish();
    var tail: [1024]u8 = undefined;
    const done = try encoder.step("", &tail);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
}

test "LZMA incremental encoder enforces options input and pledged sizes" {
    try std.testing.expectError(
        error.InvalidBlockPlan,
        lzma.IncrementalEncoder.initWithOptions(std.testing.allocator, .{ .size_mode = .known }),
    );
    try std.testing.expectError(
        error.InvalidLzmaOptions,
        lzma.IncrementalEncoder.initWithOptions(std.testing.allocator, .{ .input_buffer_len = 258 }),
    );
    try std.testing.expectError(
        error.InvalidLzmaOptions,
        lzma.IncrementalEncoder.initWithOptions(std.testing.allocator, .{ .max_pending_output_len = 0 }),
    );

    var pending_limited = try lzma.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .max_pending_output_len = 8,
    });
    defer pending_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, pending_limited.step("", &.{}));

    var input_limited = try lzma.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .max_input_len = 3,
        .input_buffer_len = 512,
    });
    defer input_limited.deinit();
    var scratch: [256]u8 = undefined;
    _ = try input_limited.step("abc", &scratch);
    try std.testing.expectError(error.OutputLimitExceeded, input_limited.step("d", &scratch));

    var exact_long = try lzma.IncrementalEncoder.initExactSize(std.testing.allocator, .{}, 4);
    defer exact_long.deinit();
    _ = try exact_long.step("abc", &scratch);
    exact_long.finish();
    try std.testing.expectError(error.SizeMismatch, exact_long.step("", &scratch));

    var exact_short = try lzma.IncrementalEncoder.initExactSize(std.testing.allocator, .{}, 3);
    defer exact_short.deinit();
    _ = try exact_short.step("abc", &scratch);
    try std.testing.expectError(error.SizeMismatch, exact_short.step("d", &scratch));
}

test "LZMA incremental encoder reset preserves deterministic output" {
    const input = "resettable incremental LZMA encoder" ** 64;
    var encoder = try lzma.IncrementalEncoder.initExactSize(std.testing.allocator, .{
        .input_buffer_len = 512,
    }, input.len);
    defer encoder.deinit();
    const first = try encodeSplit(&encoder, input, 17, 11);
    defer std.testing.allocator.free(first);
    encoder.reset();
    const second = try encodeSplit(&encoder, input, 7, 5);
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
}

test "LZMA incremental encoder releases every allocation failure" {
    const input = "allocation-safe LZMA incremental encoder" ** 32;
    const Test = struct {
        fn run(allocator: std.mem.Allocator, plain: []const u8) !void {
            var encoder = try lzma.IncrementalEncoder.initExactSize(allocator, .{
                .input_buffer_len = 512,
            }, plain.len);
            defer encoder.deinit();
            const output = try allocator.alloc(u8, plain.len * 2 + 1024);
            defer allocator.free(output);
            var input_offset: usize = 0;
            var output_offset: usize = 0;
            while (input_offset < plain.len) {
                const result = try encoder.step(plain[input_offset..], output[output_offset..]);
                input_offset += result.progress.input_read;
                output_offset += result.progress.output_written;
            }
            encoder.finish();
            while (true) {
                const result = try encoder.step("", output[output_offset..]);
                output_offset += result.progress.output_written;
                if (result.status == .done) break;
            }
            const decoded = try lzma.decodeAlloc(allocator, output[0..output_offset]);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, plain, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{input});
}

fn encodeSplit(
    encoder: *lzma.IncrementalEncoder,
    input: []const u8,
    input_chunk_len: usize,
    output_chunk_len: usize,
) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(std.testing.allocator);
    const scratch = try std.testing.allocator.alloc(u8, output_chunk_len);
    defer std.testing.allocator.free(scratch);
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const input_end = @min(input.len, input_offset + input_chunk_len);
        const result = try encoder.step(input[input_offset..input_end], scratch);
        input_offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    return encoded.toOwnedSlice(std.testing.allocator);
}

const std = @import("std");
const lzf = @import("../lzf.zig");

fn encodeSchedule(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lzf.IncrementalEncoder.Options,
    input_chunk: usize,
    output_chunk: usize,
) ![]u8 {
    var encoder = try lzf.IncrementalEncoder.initWithOptions(allocator, options);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const input_end = @min(input.len, input_offset + input_chunk);
        while (input_offset < input_end) {
            const stepped = try encoder.step(input[input_offset..input_end], output);
            input_offset += stepped.progress.input_read;
            try encoded.appendSlice(allocator, output[0..stepped.progress.output_written]);
            if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
                return error.TestUnexpectedResult;
        }
    }
    encoder.finish();
    while (true) {
        const stepped = try encoder.step("", output);
        try encoded.appendSlice(allocator, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
            return error.TestUnexpectedResult;
    }
    return encoded.toOwnedSlice(allocator);
}

test "LZF incremental encoder is byte exact for stored compressed and EOF blocks" {
    const allocator = std.testing.allocator;
    var input: [96 * 1024]u8 = undefined;
    var state: u32 = 0x7a_76_31_00;
    for (input[0 .. 32 * 1024]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memset(input[32 * 1024 .. 64 * 1024], 'A');
    @memcpy(input[64 * 1024 ..], input[0 .. 32 * 1024]);
    inline for (.{ false, true }) |eof_marker| {
        const frame_options: lzf.EncodeOptions = .{
            .block_size = 32 * 1024,
            .eof_marker = eof_marker,
        };
        const expected = try lzf.encodeAlloc(allocator, &input, frame_options);
        defer allocator.free(expected);
        const options: lzf.IncrementalEncoder.Options = .{
            .block_size = frame_options.block_size,
            .eof_marker = frame_options.eof_marker,
        };
        const one = try encodeSchedule(allocator, &input, options, 1, 1);
        defer allocator.free(one);
        const micro = try encodeSchedule(allocator, &input, options, 257, 31);
        defer allocator.free(micro);
        try std.testing.expectEqualSlices(u8, expected, one);
        try std.testing.expectEqualSlices(u8, expected, micro);
        const info = try lzf.inspect(one);
        try std.testing.expect(info.stored_block_count != 0);
        try std.testing.expect(info.compressed_block_count != 0);
    }
}

test "LZF incremental encoder handles empty exact size limits and backpressure" {
    const allocator = std.testing.allocator;
    inline for (.{ false, true }) |eof_marker| {
        const encoded = try encodeSchedule(
            allocator,
            "",
            .{ .eof_marker = eof_marker },
            1,
            1,
        );
        defer allocator.free(encoded);
        try std.testing.expectEqual(@as(usize, @intFromBool(eof_marker)), encoded.len);
    }

    var exact = try lzf.IncrementalEncoder.initExactSize(allocator, .{
        .block_size = 16,
    }, 3);
    defer exact.deinit();
    var output: [64]u8 = undefined;
    _ = try exact.step("ab", &output);
    exact.finish();
    try std.testing.expectError(error.SizeMismatch, exact.step("", &output));

    var limited = try lzf.IncrementalEncoder.initWithOptions(allocator, .{
        .block_size = 32,
        .max_input_len = 2,
    });
    defer limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("abc", &output));

    var pending_limited = try lzf.IncrementalEncoder.initWithOptions(allocator, .{
        .block_size = 32,
        .max_pending_output_len = 1,
    });
    defer pending_limited.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        pending_limited.step("A" ** 32, &output),
    );

    var blocked = try lzf.IncrementalEncoder.initWithOptions(allocator, .{
        .block_size = 8,
    });
    defer blocked.deinit();
    const first = try blocked.step("12345678", &.{});
    try std.testing.expectEqual(@import("../core.zig").StepResult.Status.need_output, first.status);
    const second = try blocked.step("", &.{});
    try std.testing.expectEqual(@import("../core.zig").StepResult.Status.need_output, second.status);
}

test "LZF incremental encoder releases every allocation failure path" {
    const allocator = std.testing.allocator;
    const input = "allocation failure LZF encoder" ** 1024;
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            const encoded = try encodeSchedule(
                failing_allocator,
                bytes,
                .{ .block_size = 4096 },
                17,
                29,
            );
            defer failing_allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{input});
}

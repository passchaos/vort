const std = @import("std");
const lz4_legacy = @import("../lz4_legacy.zig");

fn encodeSchedule(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz4_legacy.IncrementalEncoder.Options,
    input_chunk: usize,
    output_chunk: usize,
) ![]u8 {
    var encoder = try lz4_legacy.IncrementalEncoder.initWithOptions(allocator, options);
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

test "LZ4 legacy incremental encoder is byte exact across arbitrary schedules" {
    const allocator = std.testing.allocator;
    const input = "legacy LZ4 incremental encoder payload\n" ** 4096;
    const expected = try lz4_legacy.encodeAlloc(allocator, input, .{
        .block_size = 4096,
    });
    defer allocator.free(expected);
    const options: lz4_legacy.IncrementalEncoder.Options = .{
        .block_size = 4096,
    };
    const one = try encodeSchedule(allocator, input, options, 1, 1);
    defer allocator.free(one);
    const micro = try encodeSchedule(allocator, input, options, 257, 31);
    defer allocator.free(micro);
    try std.testing.expectEqualSlices(u8, expected, one);
    try std.testing.expectEqualSlices(u8, expected, micro);
    const archive = try lz4_legacy.parse(one);
    try std.testing.expect(archive.block_count > 2);
}

test "LZ4 legacy incremental encoder handles empty exact size limits and backpressure" {
    const allocator = std.testing.allocator;
    const empty = try encodeSchedule(allocator, "", .{}, 1, 1);
    defer allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &lz4_legacy.magic, empty);

    var exact = try lz4_legacy.IncrementalEncoder.initExactSize(allocator, .{
        .block_size = 16,
    }, 3);
    defer exact.deinit();
    var output: [128]u8 = undefined;
    _ = try exact.step("ab", &output);
    exact.finish();
    try std.testing.expectError(error.SizeMismatch, exact.step("", &output));

    var limited = try lz4_legacy.IncrementalEncoder.initWithOptions(allocator, .{
        .block_size = 32,
        .max_input_len = 2,
    });
    defer limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("abc", &output));

    var pending_limited = try lz4_legacy.IncrementalEncoder.initWithOptions(allocator, .{
        .block_size = 32,
        .max_pending_output_len = 4,
    });
    defer pending_limited.deinit();
    _ = try pending_limited.step("", &output);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        pending_limited.step("A" ** 32, &output),
    );

    var blocked = try lz4_legacy.IncrementalEncoder.initWithOptions(allocator, .{
        .block_size = 8,
    });
    defer blocked.deinit();
    const first = try blocked.step("12345678", &.{});
    try std.testing.expectEqual(@import("../core.zig").StepResult.Status.need_output, first.status);
    const second = try blocked.step("", &.{});
    try std.testing.expectEqual(@import("../core.zig").StepResult.Status.need_output, second.status);
}

test "LZ4 legacy incremental encoder releases every allocation failure path" {
    const allocator = std.testing.allocator;
    const input = "allocation failure legacy LZ4 encoder" ** 1024;
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

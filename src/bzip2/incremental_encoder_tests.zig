const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const core = @import("../core.zig");

test "Bzip2 incremental encoder is byte exact across tiny input and output" {
    const input = try std.testing.allocator.alloc(u8, 101_321);
    defer std.testing.allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index *% 73 +% index / 251);
    @memset(input[49_900..50_700], 0xa5);

    const one_shot = try bzip2.encodeAlloc(std.testing.allocator, input, .{ .block_size_100k = 1 });
    defer std.testing.allocator.free(one_shot);
    var encoder = try bzip2.IncrementalEncoder.initExactSize(std.testing.allocator, .{
        .block_size_100k = 1,
    }, input.len);
    defer encoder.deinit();
    const incremental = try encodeSplit(&encoder, input, 1, 7);
    defer std.testing.allocator.free(incremental);
    try std.testing.expectEqualSlices(u8, one_shot, incremental);
    try std.testing.expect(encoder.snapshot().block_count >= 2);

    const decoded = try bzip2.decodeAlloc(std.testing.allocator, incremental);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Bzip2 incremental encoder matches the canonical empty stream" {
    const one_shot = try bzip2.encodeAlloc(std.testing.allocator, "", .{ .block_size_100k = 9 });
    defer std.testing.allocator.free(one_shot);
    var encoder = try bzip2.IncrementalEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    const incremental = try encodeSplit(&encoder, "", 1, 1);
    defer std.testing.allocator.free(incremental);
    try std.testing.expectEqualSlices(u8, one_shot, incremental);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().block_count);
}

test "Bzip2 incremental encoder flushes deterministic blocks" {
    const first = "first flushed Bzip2 run " ** 128;
    const second = "second Bzip2 block after flush " ** 96;
    var encoder = try bzip2.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .block_size_100k = 1,
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [5]u8 = undefined;

    try feed(&encoder, &encoded, first, &scratch);
    encoder.flush();
    try drainFlush(&encoder, &encoded, &scratch);
    const first_flush_len = encoded.items.len;
    encoder.flush();
    try drainFlush(&encoder, &encoded, &scratch);
    try std.testing.expectEqual(first_flush_len, encoded.items.len);

    try feed(&encoder, &encoded, second, &scratch);
    encoder.flush();
    try drainFlush(&encoder, &encoded, &scratch);
    encoder.finish();
    try drainFinish(&encoder, &encoded, &scratch);
    try std.testing.expect(encoder.snapshot().block_count >= 2);

    const decoded = try bzip2.decodeAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
}

test "Bzip2 incremental encoder honors zero-output backpressure" {
    var encoder = try bzip2.IncrementalEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    const blocked = try encoder.step("payload", &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.input_read);
    try std.testing.expectEqual(@as(usize, 4), encoder.snapshot().pending_output);

    var header: [4]u8 = undefined;
    const accepted = try encoder.step("payload", &header);
    try std.testing.expectEqual(core.StepResult.Status.need_input, accepted.status);
    try std.testing.expectEqualSlices(u8, "BZh9", &header);
    encoder.finish();
    var tail: [1024]u8 = undefined;
    const done = try encoder.step("", &tail);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
}

test "Bzip2 incremental encoder enforces options input and pledged sizes" {
    try std.testing.expectError(
        error.InvalidBzip2Header,
        bzip2.IncrementalEncoder.initWithOptions(std.testing.allocator, .{ .block_size_100k = 0 }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        bzip2.IncrementalEncoder.initWithOptions(std.testing.allocator, .{ .max_pending_output_len = 0 }),
    );

    var pending_limited = try bzip2.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .max_pending_output_len = 3,
    });
    defer pending_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, pending_limited.step("", &.{}));

    var input_limited = try bzip2.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .max_input_len = 3,
    });
    defer input_limited.deinit();
    var scratch: [64]u8 = undefined;
    _ = try input_limited.step("abc", &scratch);
    try std.testing.expectError(error.OutputLimitExceeded, input_limited.step("d", &scratch));

    var exact_long = try bzip2.IncrementalEncoder.initExactSize(std.testing.allocator, .{}, 4);
    defer exact_long.deinit();
    _ = try exact_long.step("abc", &scratch);
    exact_long.finish();
    try std.testing.expectError(error.SizeMismatch, exact_long.step("", &scratch));

    var exact_short = try bzip2.IncrementalEncoder.initExactSize(std.testing.allocator, .{}, 3);
    defer exact_short.deinit();
    _ = try exact_short.step("abc", &scratch);
    try std.testing.expectError(error.SizeMismatch, exact_short.step("d", &scratch));
}

test "Bzip2 incremental encoder continues concatenated streams" {
    const first = "first incremental Bzip2 stream" ** 32;
    const second = "second incremental Bzip2 stream" ** 24;
    var encoder = try bzip2.IncrementalEncoder.initExactSize(std.testing.allocator, .{}, first.len);
    defer encoder.deinit();
    const first_frame = try encodeSplit(&encoder, first, 13, 11);
    defer std.testing.allocator.free(first_frame);
    try encoder.nextStreamExactSize(.{ .block_size_100k = 1 }, second.len);
    const second_frame = try encodeSplit(&encoder, second, 9, 7);
    defer std.testing.allocator.free(second_frame);

    var concatenated: std.ArrayList(u8) = .empty;
    defer concatenated.deinit(std.testing.allocator);
    try concatenated.appendSlice(std.testing.allocator, first_frame);
    try concatenated.appendSlice(std.testing.allocator, second_frame);
    const decoded = try bzip2.decodeConcatenatedAlloc(std.testing.allocator, concatenated.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().stream_count);
    try std.testing.expectEqual(first.len + second.len, encoder.snapshot().input_read);
}

test "Bzip2 incremental encoder releases every allocation failure" {
    const input = "allocation-safe Bzip2 incremental encoder" ** 32;
    const Test = struct {
        fn run(allocator: std.mem.Allocator, plain: []const u8) !void {
            var encoder = try bzip2.IncrementalEncoder.initExactSize(allocator, .{
                .block_size_100k = 1,
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
            const decoded = try bzip2.decodeAlloc(allocator, output[0..output_offset]);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, plain, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{input});
}

fn encodeSplit(
    encoder: *bzip2.IncrementalEncoder,
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

fn feed(
    encoder: *bzip2.IncrementalEncoder,
    encoded: *std.ArrayList(u8),
    input: []const u8,
    scratch: []u8,
) !void {
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
}

fn drainFlush(
    encoder: *bzip2.IncrementalEncoder,
    encoded: *std.ArrayList(u8),
    scratch: []u8,
) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) return;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
}

fn drainFinish(
    encoder: *bzip2.IncrementalEncoder,
    encoded: *std.ArrayList(u8),
    scratch: []u8,
) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) return;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
}

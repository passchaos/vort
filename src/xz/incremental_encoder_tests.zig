const std = @import("std");
const core = @import("../core.zig");
const xz = @import("../xz.zig");

test "XZ incremental compressed encoder is byte exact across tiny buffers" {
    const input = try std.testing.allocator.alloc(u8, 4099);
    defer std.testing.allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index *% 29 +% index / 17);
    const chain = [_]xz.Filter{
        xz.Filter.x86(0),
        try xz.Filter.delta(4),
    };
    const options = xz.EncodeOptions{
        .check = .sha256,
        .block_size = 1024,
        .dictionary_size = 128 * 1024,
        .filters = &chain,
    };
    const one_shot = try xz.encodeAlloc(std.testing.allocator, input, options);
    defer std.testing.allocator.free(one_shot);
    var encoder = try xz.IncrementalEncoder.initExactSize(std.testing.allocator, .{
        .check = options.check,
        .block_size = options.block_size,
        .dictionary_size = options.dictionary_size,
        .filters = options.filters,
    }, input.len);
    defer encoder.deinit();
    const incremental = try encodeSplit(&encoder, input, 1, 7);
    defer std.testing.allocator.free(incremental);
    try std.testing.expectEqualSlices(u8, one_shot, incremental);
    try std.testing.expectEqual(@as(usize, 5), encoder.snapshot().block_count);
    const decoded = try xz.decodeAlloc(std.testing.allocator, incremental);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    const lazy_options = xz.EncodeOptions{
        .check = options.check,
        .block_size = options.block_size,
        .dictionary_size = options.dictionary_size,
        .filters = options.filters,
    };
    const lazy_one_shot = try xz.encodeLazyAlloc(std.testing.allocator, input, lazy_options);
    defer std.testing.allocator.free(lazy_one_shot);
    var lazy_encoder = try xz.IncrementalEncoder.initExactSize(std.testing.allocator, .{
        .check = lazy_options.check,
        .block_size = lazy_options.block_size,
        .dictionary_size = lazy_options.dictionary_size,
        .parser = .lazy,
        .filters = lazy_options.filters,
    }, input.len);
    defer lazy_encoder.deinit();
    const lazy_incremental = try encodeSplit(&lazy_encoder, input, 3, 9);
    defer std.testing.allocator.free(lazy_incremental);
    try std.testing.expectEqualSlices(u8, lazy_one_shot, lazy_incremental);
}

test "XZ incremental stored encoder matches one-shot and empty streams" {
    var noise: [4097]u8 = undefined;
    var state: u32 = 0x585a_5354;
    for (&noise) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const options = xz.EncodeOptions{ .check = .crc32, .block_size = 1000 };
    const one_shot = try xz.encodeStoredAlloc(std.testing.allocator, &noise, options);
    defer std.testing.allocator.free(one_shot);
    var encoder = try xz.IncrementalEncoder.initExactSize(std.testing.allocator, .{
        .check = options.check,
        .block_size = options.block_size,
        .payload_encoding = .stored,
    }, noise.len);
    defer encoder.deinit();
    const incremental = try encodeSplit(&encoder, &noise, 3, 11);
    defer std.testing.allocator.free(incremental);
    try std.testing.expectEqualSlices(u8, one_shot, incremental);

    const empty_one_shot = try xz.encodeAlloc(std.testing.allocator, "", .{});
    defer std.testing.allocator.free(empty_one_shot);
    var empty = try xz.IncrementalEncoder.init(std.testing.allocator);
    defer empty.deinit();
    const empty_incremental = try encodeSplit(&empty, "", 1, 1);
    defer std.testing.allocator.free(empty_incremental);
    try std.testing.expectEqualSlices(u8, empty_one_shot, empty_incremental);
}

test "XZ incremental encoder flushes independent blocks" {
    const first = "first flushed XZ block " ** 64;
    const second = "second XZ block after flush " ** 48;
    var encoder = try xz.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .check = .crc64,
        .block_size = 16 * 1024,
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [7]u8 = undefined;
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
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().block_count);
    const decoded = try xz.decodeAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
}

test "XZ incremental encoder honors zero-output backpressure" {
    var encoder = try xz.IncrementalEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    const blocked = try encoder.step("payload", &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.input_read);
    try std.testing.expectEqual(@as(usize, 12), encoder.snapshot().pending_output);

    var header: [12]u8 = undefined;
    const accepted = try encoder.step("payload", &header);
    try std.testing.expectEqual(core.StepResult.Status.need_input, accepted.status);
    try std.testing.expectEqualSlices(u8, &.{ 0xfd, '7', 'z', 'X', 'Z', 0 }, header[0..6]);
    encoder.finish();
    var tail: [1024]u8 = undefined;
    const done = try encoder.step("", &tail);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
}

test "XZ incremental encoder enforces options input block and pending limits" {
    try std.testing.expectError(
        error.InvalidBlockPlan,
        xz.IncrementalEncoder.initWithOptions(std.testing.allocator, .{ .block_size = 0 }),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        xz.IncrementalEncoder.initWithOptions(std.testing.allocator, .{ .dictionary_size = 4095 }),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        xz.IncrementalEncoder.initWithOptions(std.testing.allocator, .{ .dictionary_size = 1024 * 1024 + 1 }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        xz.IncrementalEncoder.initWithOptions(std.testing.allocator, .{ .max_block_count = 0 }),
    );

    var pending_limited = try xz.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .max_pending_output_len = 8,
    });
    defer pending_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, pending_limited.step("", &.{}));

    var input_limited = try xz.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .max_input_len = 3,
    });
    defer input_limited.deinit();
    var scratch: [128]u8 = undefined;
    _ = try input_limited.step("abc", &scratch);
    try std.testing.expectError(error.OutputLimitExceeded, input_limited.step("d", &scratch));

    var block_limited = try xz.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .block_size = 3,
        .max_block_count = 1,
    });
    defer block_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, block_limited.step("abcdef", &scratch));

    var exact_long = try xz.IncrementalEncoder.initExactSize(std.testing.allocator, .{}, 4);
    defer exact_long.deinit();
    _ = try exact_long.step("abc", &scratch);
    exact_long.finish();
    try std.testing.expectError(error.SizeMismatch, exact_long.step("", &scratch));

    var exact_short = try xz.IncrementalEncoder.initExactSize(std.testing.allocator, .{}, 3);
    defer exact_short.deinit();
    _ = try exact_short.step("abc", &scratch);
    try std.testing.expectError(error.SizeMismatch, exact_short.step("d", &scratch));
}

test "XZ incremental encoder continues concatenated streams" {
    const first = "first incremental XZ stream" ** 32;
    const second = "second incremental XZ stream" ** 24;
    var encoder = try xz.IncrementalEncoder.initExactSize(std.testing.allocator, .{
        .check = .crc32,
        .block_size = 257,
    }, first.len);
    defer encoder.deinit();
    const first_frame = try encodeSplit(&encoder, first, 13, 11);
    defer std.testing.allocator.free(first_frame);
    try encoder.nextStreamExactSize(.{
        .check = .sha256,
        .block_size = 193,
        .dictionary_size = 128 * 1024,
        .payload_encoding = .stored,
    }, second.len);
    const second_frame = try encodeSplit(&encoder, second, 9, 7);
    defer std.testing.allocator.free(second_frame);

    var concatenated: std.ArrayList(u8) = .empty;
    defer concatenated.deinit(std.testing.allocator);
    try concatenated.appendSlice(std.testing.allocator, first_frame);
    try concatenated.appendSlice(std.testing.allocator, second_frame);
    const decoded = try xz.decodeConcatenatedAlloc(std.testing.allocator, concatenated.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().stream_count);
    try std.testing.expectEqual(first.len + second.len, encoder.snapshot().input_read);
}

test "XZ incremental encoder releases every allocation failure" {
    const input = "allocation-safe XZ incremental encoder" ** 32;
    const Test = struct {
        fn run(allocator: std.mem.Allocator, plain: []const u8) !void {
            var encoder = try xz.IncrementalEncoder.initExactSize(allocator, .{
                .check = .sha256,
                .block_size = 257,
            }, plain.len);
            defer encoder.deinit();
            const output = try allocator.alloc(u8, plain.len * 2 + 4096);
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
            const decoded = try xz.decodeAlloc(allocator, output[0..output_offset]);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, plain, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{input});
}

fn encodeSplit(
    encoder: *xz.IncrementalEncoder,
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
    encoder: *xz.IncrementalEncoder,
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
    encoder: *xz.IncrementalEncoder,
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
    encoder: *xz.IncrementalEncoder,
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

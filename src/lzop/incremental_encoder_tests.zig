const std = @import("std");
const core = @import("../core.zig");
const lzop = @import("../lzop.zig");

test "LZOP incremental compressed encoder is byte exact across tiny buffers" {
    var input: [8192]u8 = undefined;
    @memset(input[0..4096], 'A');
    var prng = std.Random.DefaultPrng.init(0x4c5a_4f50_494e_4352);
    prng.random().bytes(input[4096..]);
    const options = lzop.EncodeOptions{
        .block_size = 4096,
        .checksum = .crc32,
        .compressed_checksum = true,
        .header_checksum = .crc32,
        .filename = "payload.bin",
        .mode = 0o100640,
        .modified_time = 0x1020_3040,
    };
    const one_shot = try lzop.encodeAlloc(std.testing.allocator, &input, options);
    defer std.testing.allocator.free(one_shot);
    var encoder = try lzop.IncrementalEncoder.initExactSize(std.testing.allocator, .{
        .block_size = options.block_size,
        .checksum = options.checksum,
        .compressed_checksum = options.compressed_checksum,
        .header_checksum = options.header_checksum,
        .filename = options.filename,
        .mode = options.mode,
        .modified_time = options.modified_time,
    }, input.len);
    defer encoder.deinit();
    const incremental = try encodeSplit(&encoder, &input, 1, 7);
    defer std.testing.allocator.free(incremental);
    try std.testing.expectEqualSlices(u8, one_shot, incremental);
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().block_count);
    const info = try lzop.inspect(incremental);
    try std.testing.expectEqual(@as(usize, 1), info.compressed_block_count);
    try std.testing.expectEqual(@as(usize, 1), info.stored_block_count);
}

test "LZOP incremental stored encoder matches one-shot and empty streams" {
    var input: [4097]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @truncate(index *% 31 +% index / 13);
    const options = lzop.EncodeOptions{
        .block_size = 1000,
        .checksum = .adler32,
        .filename = "stored.bin",
    };
    const one_shot = try lzop.encodeStoredAlloc(std.testing.allocator, &input, options);
    defer std.testing.allocator.free(one_shot);
    var encoder = try lzop.IncrementalEncoder.initExactSize(std.testing.allocator, .{
        .block_size = options.block_size,
        .checksum = options.checksum,
        .filename = options.filename,
        .payload_mode = .stored,
    }, input.len);
    defer encoder.deinit();
    const incremental = try encodeSplit(&encoder, &input, 3, 11);
    defer std.testing.allocator.free(incremental);
    try std.testing.expectEqualSlices(u8, one_shot, incremental);

    const empty_one_shot = try lzop.encodeAlloc(std.testing.allocator, "", .{});
    defer std.testing.allocator.free(empty_one_shot);
    var empty = try lzop.IncrementalEncoder.init(std.testing.allocator);
    defer empty.deinit();
    const empty_incremental = try encodeSplit(&empty, "", 1, 1);
    defer std.testing.allocator.free(empty_incremental);
    try std.testing.expectEqualSlices(u8, empty_one_shot, empty_incremental);
}

test "LZOP incremental encoder flushes independent blocks" {
    const first = "first flushed LZOP block " ** 64;
    const second = "second LZOP block after flush " ** 48;
    var encoder = try lzop.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .block_size = 16 * 1024,
        .checksum = .crc32,
        .compressed_checksum = true,
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
    const decoded = try lzop.decodeAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
}

test "LZOP incremental encoder honors zero-output backpressure" {
    var encoder = try lzop.IncrementalEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    const blocked = try encoder.step("payload", &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.input_read);
    try std.testing.expect(encoder.snapshot().pending_output > 9);

    var header_bytes: [128]u8 = undefined;
    const accepted = try encoder.step("payload", &header_bytes);
    try std.testing.expectEqual(core.StepResult.Status.need_input, accepted.status);
    try std.testing.expectEqualSlices(u8, &lzop.header_magic, header_bytes[0..lzop.header_magic.len]);
    encoder.finish();
    var tail: [1024]u8 = undefined;
    const done = try encoder.step("", &tail);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
}

test "LZOP incremental encoder enforces options input block and pending limits" {
    try std.testing.expectError(
        error.InvalidLzopOptions,
        lzop.IncrementalEncoder.initWithOptions(std.testing.allocator, .{ .block_size = 0 }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        lzop.IncrementalEncoder.initWithOptions(std.testing.allocator, .{ .max_block_count = 0 }),
    );

    var pending_limited = try lzop.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .max_pending_output_len = 8,
    });
    defer pending_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, pending_limited.step("", &.{}));

    var input_limited = try lzop.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .max_input_len = 3,
    });
    defer input_limited.deinit();
    var scratch: [256]u8 = undefined;
    _ = try input_limited.step("abc", &scratch);
    try std.testing.expectError(error.OutputLimitExceeded, input_limited.step("d", &scratch));

    var block_limited = try lzop.IncrementalEncoder.initWithOptions(std.testing.allocator, .{
        .block_size = 3,
        .max_block_count = 1,
    });
    defer block_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, block_limited.step("abcdef", &scratch));

    var exact_long = try lzop.IncrementalEncoder.initExactSize(std.testing.allocator, .{}, 4);
    defer exact_long.deinit();
    _ = try exact_long.step("abc", &scratch);
    exact_long.finish();
    try std.testing.expectError(error.SizeMismatch, exact_long.step("", &scratch));

    var exact_short = try lzop.IncrementalEncoder.initExactSize(std.testing.allocator, .{}, 3);
    defer exact_short.deinit();
    _ = try exact_short.step("abc", &scratch);
    try std.testing.expectError(error.SizeMismatch, exact_short.step("d", &scratch));
}

test "LZOP incremental encoder continues concatenated streams" {
    const first = "first incremental LZOP stream" ** 32;
    const second = "second incremental LZOP stream" ** 24;
    var encoder = try lzop.IncrementalEncoder.initExactSize(std.testing.allocator, .{
        .checksum = .crc32,
        .block_size = 257,
        .filename = "first.bin",
    }, first.len);
    defer encoder.deinit();
    const first_frame = try encodeSplit(&encoder, first, 13, 11);
    defer std.testing.allocator.free(first_frame);
    try encoder.nextStreamExactSize(.{
        .checksum = .adler32,
        .block_size = 193,
        .filename = "second.bin",
        .payload_mode = .stored,
    }, second.len);
    const second_frame = try encodeSplit(&encoder, second, 9, 7);
    defer std.testing.allocator.free(second_frame);

    var concatenated: std.ArrayList(u8) = .empty;
    defer concatenated.deinit(std.testing.allocator);
    try concatenated.appendSlice(std.testing.allocator, first_frame);
    try concatenated.appendSlice(std.testing.allocator, second_frame);
    const decoded = try lzop.decodeAlloc(std.testing.allocator, concatenated.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().stream_count);
    try std.testing.expectEqual(first.len + second.len, encoder.snapshot().input_read);
}

test "LZOP incremental encoder releases every allocation failure" {
    const input = "allocation-safe LZOP incremental encoder" ** 32;
    const Test = struct {
        fn run(allocator: std.mem.Allocator, plain: []const u8) !void {
            var encoder = try lzop.IncrementalEncoder.initExactSize(allocator, .{
                .block_size = 257,
                .checksum = .crc32,
                .compressed_checksum = true,
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
            const decoded = try lzop.decodeAlloc(allocator, output[0..output_offset]);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, plain, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{input});
}

fn encodeSplit(
    encoder: *lzop.IncrementalEncoder,
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
    encoder: *lzop.IncrementalEncoder,
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
    encoder: *lzop.IncrementalEncoder,
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
    encoder: *lzop.IncrementalEncoder,
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

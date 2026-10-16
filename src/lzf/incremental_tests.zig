const std = @import("std");
const lzf = @import("../lzf.zig");

fn decodeSchedule(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    input_chunk: usize,
    output_chunk: usize,
) ![]u8 {
    var decoder = lzf.IncrementalDecoder.init(allocator);
    defer decoder.deinit();
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var finish_sent = false;
    var iterations: usize = 0;
    while (true) {
        iterations += 1;
        if (iterations > encoded.len * 8 + 1024) return error.TestUnexpectedResult;
        const input_end = @min(encoded.len, input_offset + input_chunk);
        const stepped = try decoder.step(encoded[input_offset..input_end], output);
        input_offset += stepped.progress.input_read;
        try decoded.appendSlice(allocator, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        var just_finished = false;
        if (!finish_sent and input_offset == encoded.len) {
            decoder.finish();
            finish_sent = true;
            just_finished = true;
        }
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0 and
            !(stepped.status == .need_input and (!finish_sent or just_finished)))
            return error.TestUnexpectedResult;
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    return decoded.toOwnedSlice(allocator);
}

test "LZF incremental decoder streams stored compressed and EOF-marker blocks" {
    const allocator = std.testing.allocator;
    var input: [96 * 1024]u8 = undefined;
    var state: u32 = 0x4c5a_4631;
    for (input[0 .. 32 * 1024]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memset(input[32 * 1024 .. 64 * 1024], 'A');
    @memcpy(input[64 * 1024 ..], input[0 .. 32 * 1024]);
    inline for (.{ false, true }) |eof_marker| {
        const encoded = try lzf.encodeAlloc(allocator, &input, .{
            .block_size = 32 * 1024,
            .eof_marker = eof_marker,
        });
        defer allocator.free(encoded);
        const tiny = try decodeSchedule(allocator, encoded, 1, 1);
        defer allocator.free(tiny);
        const micro = try decodeSchedule(allocator, encoded, 17, 31);
        defer allocator.free(micro);
        try std.testing.expectEqualSlices(u8, &input, tiny);
        try std.testing.expectEqualSlices(u8, &input, micro);
    }
}

test "LZF incremental decoder handles empty limits truncation and trailing data" {
    const allocator = std.testing.allocator;
    const empty = try decodeSchedule(allocator, "", 1, 1);
    defer allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
    const marked = try decodeSchedule(allocator, &.{0}, 1, 1);
    defer allocator.free(marked);
    try std.testing.expectEqual(@as(usize, 0), marked.len);

    const input = "bounded incremental LZF" ** 128;
    const encoded = try lzf.encodeAlloc(allocator, input, .{
        .block_size = 257,
        .eof_marker = true,
    });
    defer allocator.free(encoded);
    var limited = lzf.IncrementalDecoder.initWithOptions(allocator, .{
        .max_output_len = input.len - 1,
    });
    defer limited.deinit();
    var output: [512]u8 = undefined;
    var limited_offset: usize = 0;
    while (true) {
        const stepped = limited.step(encoded[limited_offset..], &output) catch |err| {
            try std.testing.expectEqual(error.OutputLimitExceeded, err);
            break;
        };
        limited_offset += stepped.progress.input_read;
    }

    var truncated = lzf.IncrementalDecoder.init(allocator);
    defer truncated.deinit();
    const short = encoded[0 .. encoded.len - 2];
    var truncated_offset: usize = 0;
    while (truncated_offset < short.len) {
        const partial = try truncated.step(short[truncated_offset..], &output);
        truncated_offset += partial.progress.input_read;
    }
    truncated.finish();
    while (true) {
        const stepped = truncated.step("", &output) catch |err| {
            try std.testing.expectEqual(error.TruncatedFrame, err);
            break;
        };
        if (stepped.status == .done) return error.TestUnexpectedResult;
    }

    var trailing = lzf.IncrementalDecoder.init(allocator);
    defer trailing.deinit();
    try std.testing.expectError(error.TrailingData, trailing.step(&.{ 0, 1 }, &output));
}

test "LZF incremental decoder releases every allocation failure path" {
    const allocator = std.testing.allocator;
    const input = "allocation failure LZF payload" ** 1024;
    const encoded = try lzf.encodeAlloc(allocator, input, .{ .block_size = 4096 });
    defer allocator.free(encoded);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            const decoded = try decodeSchedule(failing_allocator, bytes, 13, 19);
            defer failing_allocator.free(decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{encoded});
}

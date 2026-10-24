const std = @import("std");
const lz4_legacy = @import("../lz4_legacy.zig");

fn decodeSchedule(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    input_chunk: usize,
    output_chunk: usize,
) ![]u8 {
    var decoder = lz4_legacy.IncrementalDecoder.init(allocator);
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
        if (iterations > 16 * 1024 * 1024) return error.TestUnexpectedResult;
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

test "LZ4 legacy incremental decoder streams empty and multiple blocks" {
    const allocator = std.testing.allocator;
    const empty_encoded = try lz4_legacy.encodeAlloc(allocator, "", .{});
    defer allocator.free(empty_encoded);
    const empty = try decodeSchedule(allocator, empty_encoded, 1, 1);
    defer allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);

    const input = "legacy LZ4 incremental payload\n" ** 4096;
    const encoded = try lz4_legacy.encodeAlloc(allocator, input, .{ .block_size = 4096 });
    defer allocator.free(encoded);
    const tiny = try decodeSchedule(allocator, encoded, 1, 1);
    defer allocator.free(tiny);
    const micro = try decodeSchedule(allocator, encoded, 23, 31);
    defer allocator.free(micro);
    try std.testing.expectEqualSlices(u8, input, tiny);
    try std.testing.expectEqualSlices(u8, input, micro);
}

test "LZ4 legacy incremental decoder enforces limits and truncation" {
    const allocator = std.testing.allocator;
    const input = "bounded legacy LZ4" ** 256;
    const encoded = try lz4_legacy.encodeAlloc(allocator, input, .{ .block_size = 1024 });
    defer allocator.free(encoded);
    var output: [2048]u8 = undefined;

    var limited = lz4_legacy.IncrementalDecoder.initWithOptions(allocator, .{
        .max_output_len = input.len - 1,
    });
    defer limited.deinit();
    var input_offset: usize = 0;
    while (true) {
        const stepped = limited.step(encoded[input_offset..], &output) catch |err| {
            try std.testing.expectEqual(error.OutputLimitExceeded, err);
            break;
        };
        input_offset += stepped.progress.input_read;
    }

    var truncated = lz4_legacy.IncrementalDecoder.init(allocator);
    defer truncated.deinit();
    input_offset = 0;
    const short = encoded[0 .. encoded.len - 1];
    while (input_offset < short.len) {
        const stepped = try truncated.step(short[input_offset..], &output);
        input_offset += stepped.progress.input_read;
    }
    truncated.finish();
    try std.testing.expectError(error.TruncatedFrame, truncated.step("", &output));
}

test "LZ4 legacy incremental decoder releases every allocation failure path" {
    const allocator = std.testing.allocator;
    const input = "allocation failure legacy LZ4 payload" ** 1024;
    const encoded = try lz4_legacy.encodeAlloc(allocator, input, .{ .block_size = 4096 });
    defer allocator.free(encoded);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            const decoded = try decodeSchedule(failing_allocator, bytes, 17, 29);
            defer failing_allocator.free(decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{encoded});
}

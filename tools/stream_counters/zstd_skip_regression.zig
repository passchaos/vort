//! Tiny reproduction of concatenated skippable members under an exact zero
//! output pledge. No counters are seeded and only21 bytes are supplied.
const std = @import("std");
const vort = @import("vort");
const common = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    const headers = [_][]const u8{
        &.{ 0x50, 0x2a, 0x4d, 0x18, 3, 0, 0, 0 },
        "abc",
        &.{ 0x51, 0x2a, 0x4d, 0x18, 2, 0, 0, 0 },
        "de",
    };
    var results: [2]struct { policy: vort.core.CompressedInputPolicy, @"error": ?[]const u8, input_read: u64, snapshot: vort.zstd.NativeIncrementalFrameDecoder.Snapshot } = undefined;
    for ([_]vort.core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }, 0..) |policy, index| {
        var decoder = vort.zstd.NativeIncrementalFrameDecoder.initWithOptions(init.gpa, .{ .input_policy = policy, .max_output_len = 0, .expected_output_len = 0, .max_compressed_buffer_len = 64, .max_working_memory = 4096 });
        defer decoder.deinit();
        var read: u64 = 0;
        var failure: ?[]const u8 = null;
        var output: [1]u8 = undefined;
        for (headers) |input| {
            const result = decoder.step(input, &output) catch |err| {
                failure = @errorName(err);
                break;
            };
            read += result.progress.input_read;
            if (result.progress.output_written != 0) return error.UnexpectedOutput;
        }
        if (failure == null) decoder.finish() catch |err| {
            failure = @errorName(err);
        };
        results[index] = .{ .policy = policy, .@"error" = failure, .input_read = read, .snapshot = decoder.snapshot() };
    }
    try common.print(init, .{ .rows = results, .physical_input_bytes = 21, .physical_output_bytes = 0, .scope = "actual tiny skippable concat regression" });
    for (results) |result| if (result.@"error" != null or result.input_read != 21 or result.snapshot.skippable_total != 5 or result.snapshot.skippable_event_count != 2) return error.SkippableConcatenationRegression;
}

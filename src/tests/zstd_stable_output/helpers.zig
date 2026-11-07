const std = @import("std");
const core = @import("../../core.zig");
pub const memory = @import("../zstd_decode_memory/helpers.zig");
pub const wire = @import("../zstd_magicless_helpers.zig");
pub const a = std.testing.allocator;

pub fn published(decoder: anytype, buffer: []const u8, count: usize) !void {
    const D = @TypeOf(decoder.*);
    if (@hasDecl(D, "stableOutputWritten")) try std.testing.expectEqual(count, decoder.stableOutputWritten());
    if (@hasDecl(D, "stableOutput")) {
        const visible = decoder.stableOutput();
        try std.testing.expectEqual(count, visible.len);
        try std.testing.expectEqual(buffer.ptr, visible.ptr);
        try std.testing.expectEqualSlices(u8, buffer[0..count], visible);
    }
}

pub fn step(decoder: anytype, input: []const u8, buffer: []u8, count: *usize, expected: []const u8) !core.StepResult {
    return stepLimited(decoder, input, buffer, count, expected, null);
}

pub fn stepLimited(decoder: anytype, input: []const u8, buffer: []u8, count: *usize, expected: []const u8, maximum: ?usize) !core.StepResult {
    const old = try a.dupe(u8, buffer[0..count.*]);
    defer a.free(old);
    const result = if (maximum) |limit| try decoder.stepStableLimited(input, limit) else try decoder.stepStable(input);
    if (maximum) |limit| try std.testing.expect(result.progress.output_written <= limit);
    count.* += result.progress.output_written;
    try std.testing.expect(count.* <= expected.len);
    try std.testing.expectEqualSlices(u8, old, buffer[0..old.len]);
    try std.testing.expectEqualSlices(u8, expected[0..count.*], buffer[0..count.*]);
    try published(decoder, buffer, count.*);
    return result;
}

pub fn refused(decoder: anytype, input: []const u8, buffer: []u8, count: usize, comptime err: anyerror) !usize {
    const old = try a.dupe(u8, buffer[0..count]);
    defer a.free(old);
    const before = decoder.snapshot().output_written;
    try std.testing.expectError(err, decoder.stepStable(input));
    const after = decoder.snapshot();
    const emitted: usize = @intCast(after.output_written - before);
    try std.testing.expectEqual(emitted, after.last_step_progress.output_written);
    try std.testing.expectEqualSlices(u8, old, buffer[0..count]);
    try published(decoder, buffer, count + emitted);
    return count + emitted;
}

pub fn drive(decoder: anytype, frame: []const u8, buffer: []u8, count: *usize, expected: []const u8, chunk: usize) !usize {
    var read: usize = 0;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < frame.len * 4 + expected.len + 1024);
        const result = try step(decoder, frame[read..@min(frame.len, read + chunk)], buffer, count, expected);
        read += result.progress.input_read;
        if (decoder.snapshot().phase == .done and (read == frame.len or decoder.options.stop_after_first_frame)) break;
        if (result.status == .need_input and read == frame.len) return error.TruncatedFrame;
        try std.testing.expect(result.status != .need_output or count.* < buffer.len);
    }
    try decoder.finish();
    return read;
}

pub fn ordinary(decoder: anytype, frame: []const u8, expected: []const u8, chunk: usize) !void {
    var read: usize = 0;
    var written: usize = 0;
    var output: [4096]u8 = undefined;
    var calls: usize = 0;
    while (read != frame.len or decoder.snapshot().phase != .done) : (calls += 1) {
        try std.testing.expect(calls < frame.len * 4 + expected.len + 1024);
        const result = try decoder.step(frame[read..@min(frame.len, read + chunk)], &output);
        read += result.progress.input_read;
        try std.testing.expectEqualSlices(u8, expected[written..][0..result.progress.output_written], output[0..result.progress.output_written]);
        written += result.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqual(expected.len, written);
}

const std = @import("std");
const core = @import("../../../core.zig");
pub const xz = @import("../../../xz.zig");
pub const a = std.testing.allocator;
pub const old = @import("../../parallel/test_helpers.zig");
pub const wire = @import("../../block_sizes/test_helpers.zig");
pub const Tracker = old.TrackingAllocator;
pub const plain = "persistent incremental XZ jobs own accepted bytes and preserve wire order\n" ** 3;

pub fn options() xz.IncrementalEncoder.Options {
    return .{ .block_size = 128, .chunk_size = 128, .parser = .fast, .match_options = .{ .finder = .hc4, .nice_len = 32, .depth = 8 }, .parallel = .{ .io = std.testing.io, .max_inflight_blocks = 4, .max_inflight_bytes = 512 } };
}
pub fn serialOptions(opts: xz.IncrementalEncoder.Options) xz.EncodeOptions {
    var result = opts.writerOptions();
    result.parallel = null;
    return result;
}
pub fn baseline(input: []const u8, opts: xz.IncrementalEncoder.Options) ![]u8 {
    const serial = serialOptions(opts);
    return if (opts.payload_encoding == .stored) xz.encodeStoredAlloc(a, input, serial) else xz.encodeAlloc(a, input, serial);
}
pub fn bounds(observed: anytype, opts: xz.IncrementalEncoder.Options) !void {
    const p = observed.parallel;
    if (!p.enabled) return;
    try std.testing.expect(p.inflight_blocks <= opts.parallel.?.max_inflight_blocks);
    try std.testing.expect(p.inflight_bytes <= opts.parallel.?.max_inflight_bytes);
    try std.testing.expect(p.partial_input_bytes <= p.inflight_bytes);
    try std.testing.expect(p.delivered_blocks <= p.published_blocks);
    try std.testing.expect(p.published_blocks <= p.encoded_blocks);
    try std.testing.expect(p.encoded_blocks <= p.accepted_blocks);
    try std.testing.expect(p.live_requested_bytes <= opts.parallel.?.max_working_memory);
}
pub fn checked(encoder: *xz.IncrementalEncoder, input: []const u8, output: []u8) !core.StepResult {
    @memset(output, 0xa5);
    const before = encoder.snapshot();
    const step = try encoder.step(input, output);
    const after = encoder.snapshot();
    try std.testing.expectEqual(step.progress.input_read, after.input_read - before.input_read);
    try std.testing.expectEqual(step.progress.output_written, after.output_written - before.output_written);
    try old.untouched(output[step.progress.output_written..]);
    try bounds(after, encoder.options);
    return step;
}
pub fn failStep(encoder: *xz.IncrementalEncoder, input: []const u8, output: []u8, expected: anyerror) !void {
    @memset(output, 0xa5);
    const before = encoder.snapshot();
    try std.testing.expectError(expected, encoder.step(input, output));
    const after = encoder.snapshot();
    const progress = after.parallel.last_step_progress;
    try std.testing.expectEqual(progress.input_read, after.input_read - before.input_read);
    try std.testing.expectEqual(progress.output_written, after.output_written - before.output_written);
    try std.testing.expect(progress.input_read <= input.len and progress.output_written <= output.len);
    try old.untouched(output[progress.output_written..]);
}
pub fn header(encoder: *xz.IncrementalEncoder, encoded: *std.ArrayList(u8)) !void {
    var output: [12]u8 = undefined;
    const step = try checked(encoder, "", &output);
    try std.testing.expectEqual(@as(usize, 12), step.progress.output_written);
    try std.testing.expectEqual(@as(usize, 0), step.progress.input_read);
    try encoded.appendSlice(a, output[0..step.progress.output_written]);
}
pub fn feed(encoder: *xz.IncrementalEncoder, encoded: *std.ArrayList(u8), input: []const u8, output_quota: usize) !void {
    var offset: usize = 0;
    for (0..input.len * 32 + 16384) |_| {
        var borrowed: [32]u8 = @splat(0xa5);
        const length = @min(borrowed.len, input.len - offset);
        @memcpy(borrowed[0..length], input[offset..][0..length]);
        var output: [257]u8 = undefined;
        const step = try checked(encoder, borrowed[0..length], output[0..output_quota]);
        @memset(&borrowed, 0xdd);
        offset += step.progress.input_read;
        try encoded.appendSlice(a, output[0..step.progress.output_written]);
        if (offset == input.len and step.status == .need_input) return;
    }
    return error.TestUnexpectedResult;
}
pub fn drain(encoder: *xz.IncrementalEncoder, encoded: *std.ArrayList(u8), expected: core.StepResult.Status, output_quota: usize) !void {
    for (0..1024 * 1024) |_| {
        var output: [257]u8 = undefined;
        const step = try checked(encoder, "", output[0..output_quota]);
        try encoded.appendSlice(a, output[0..step.progress.output_written]);
        if (step.status == expected) return;
        try std.testing.expectEqual(.need_output, step.status);
    }
    return error.TestUnexpectedResult;
}
pub fn drive(encoder: *xz.IncrementalEncoder, input: []const u8, output_quota: usize) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(a);
    try feed(encoder, &encoded, input, output_quota);
    encoder.finish();
    try drain(encoder, &encoded, .done, output_quota);
    return encoded.toOwnedSlice(a);
}
pub fn finish(encoder: *xz.IncrementalEncoder, encoded: *std.ArrayList(u8), input: []const u8) !void {
    encoder.finish();
    try drain(encoder, encoded, .done, 3);
    const observed = encoder.snapshot();
    try std.testing.expectEqual(@as(usize, 0), observed.parallel.inflight_bytes);
    try std.testing.expectEqual(@as(usize, 0), observed.parallel.owned_input_bytes);
    try std.testing.expectEqual(observed.current_stream_blocks, observed.parallel.delivered_blocks);
    const decoded = try xz.decodeAlloc(a, encoded.items);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}
pub fn parity(input: []const u8, opts: xz.IncrementalEncoder.Options) !void {
    const expected = try baseline(input, opts);
    defer a.free(expected);
    var encoder = try xz.IncrementalEncoder.initExactSize(a, opts, input.len);
    defer encoder.deinit();
    const actual = try drive(&encoder, input, 3);
    defer a.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
    try wire.checkWire(actual, input, opts.include_block_sizes);
}
pub fn sticky(encoder: *xz.IncrementalEncoder, expected: anyerror) !void {
    const before = encoder.snapshot();
    try std.testing.expect(before.parallel.failed);
    try std.testing.expectEqual(@as(usize, 0), before.parallel.workers_live);
    var output: [17]u8 = @splat(0xa5);
    try failStep(encoder, "unconsumed", &output, expected);
    const after = encoder.snapshot();
    try std.testing.expectEqual(before.input_read, after.input_read);
    try std.testing.expectEqual(before.output_written, after.output_written);
    try std.testing.expectEqual(core.Progress{}, after.parallel.last_step_progress);
    try old.untouched(&output);
}
pub fn driveFailure(encoder: *xz.IncrementalEncoder, input: []const u8, expected: anyerror) !void {
    var offset: usize = 0;
    var finishing = false;
    for (0..input.len * 32 + 16384) |_| {
        if (offset == input.len and !finishing) {
            encoder.finish();
            finishing = true;
        }
        var output: [3]u8 = @splat(0xa5);
        const before = encoder.snapshot();
        const step = encoder.step(input[offset..@min(input.len, offset + 32)], &output) catch |err| {
            try std.testing.expectEqual(expected, err);
            const after = encoder.snapshot();
            try std.testing.expectEqual(after.input_read - before.input_read, after.parallel.last_step_progress.input_read);
            try std.testing.expectEqual(after.output_written - before.output_written, after.parallel.last_step_progress.output_written);
            try old.untouched(output[after.parallel.last_step_progress.output_written..]);
            try sticky(encoder, expected);
            return;
        };
        offset += step.progress.input_read;
        try std.testing.expect(step.status != .done);
    }
    return error.TestUnexpectedResult;
}

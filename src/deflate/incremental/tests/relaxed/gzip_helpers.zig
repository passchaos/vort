const std = @import("std");
const core = @import("../../../../core.zig");

pub fn step(decoder: anytype, input: []const u8, output: []u8) !core.StepResult {
    const before = decoder.snapshot();
    const stepped = try decoder.step(input, output);
    try progress(decoder, before, stepped.progress);
    return stepped;
}

pub fn boundary(decoder: anytype, input: []const u8, output: []u8) !core.StepResult {
    const before = decoder.snapshot();
    const stepped = try decoder.stepToBlockBoundary(input, output);
    try progress(decoder, before, stepped.progress);
    return stepped;
}

pub fn stepError(expected: anyerror, decoder: anytype, input: []const u8, output: []u8) !void {
    const before = decoder.snapshot();
    try std.testing.expectError(expected, decoder.step(input, output));
    const snapshot = decoder.snapshot();
    try progress(decoder, before, snapshot.last_step_progress);
    try std.testing.expectEqual(@as(?@TypeOf(snapshot.total_input), snapshot.total_input), snapshot.last_error_input_offset);
    try std.testing.expectEqual(@as(?@TypeOf(snapshot.total_output), snapshot.total_output), snapshot.last_error_output_offset);
    const diagnostics = decoder.diagnostics();
    try std.testing.expectEqual(@as(?core.StreamCount, snapshot.total_input), diagnostics.error_input_offset);
    try std.testing.expectEqual(@as(?core.StreamCount, snapshot.total_output), diagnostics.error_output_offset);
}

fn progress(decoder: anytype, before: anytype, advanced: core.Progress) !void {
    const after = decoder.snapshot();
    try std.testing.expectEqual(before.total_input + advanced.input_read, after.total_input);
    try std.testing.expectEqual(before.total_output + advanced.output_written, after.total_output);
    try std.testing.expectEqual(advanced, after.last_step_progress);
    const diagnostics = decoder.diagnostics();
    try std.testing.expectEqual(@as(?core.StreamCount, after.total_input), diagnostics.input_read);
    try std.testing.expectEqual(@as(?core.StreamCount, after.total_input), diagnostics.frame_input_read);
    try std.testing.expectEqual(@as(core.StreamCount, after.total_output), diagnostics.output_written);
    try std.testing.expectEqual(@as(?core.Progress, advanced), diagnostics.last_step_progress);
}

pub fn join(parts: []const []const u8) ![]u8 {
    return std.mem.concat(std.testing.allocator, u8, parts);
}

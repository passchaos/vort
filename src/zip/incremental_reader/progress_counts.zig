//! Wide persistent counts and local progress for one caller buffer pair.
const std = @import("std");
const core = @import("../../core.zig");
const Count = core.StreamCount;

pub const Before = struct {
    input: Count,
    output: Count,

    pub fn init(input: Count, output: Count) Before {
        return .{ .input = input, .output = output };
    }

    pub fn progress(self: Before, input: Count, output: Count) core.Error!core.Progress {
        return .{ .input_read = try core.stream_count.toLocal(input - self.input), .output_written = try core.stream_count.toLocal(output - self.output) };
    }
};

pub fn inputWindow(total: Count, input: []const u8) []const u8 {
    return input[0..core.stream_count.bounded(std.math.maxInt(Count) - total, input.len)];
}

pub fn outputWindow(total: Count, output: []u8) []u8 {
    return output[0..core.stream_count.bounded(std.math.maxInt(Count) - total, output.len)];
}

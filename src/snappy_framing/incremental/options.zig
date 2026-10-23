const std = @import("std");
const core = @import("../../core.zig");

pub const Options = struct {
    max_compressed_chunk_len: usize = 64 * 1024 * 1024,
    max_decoded_chunk_len: usize = 64 * 1024 * 1024,
    max_output_len: usize = std.math.maxInt(usize),
    max_working_memory: usize = std.math.maxInt(usize),
    expected_output_len: ?usize = null,

    pub fn validate(self: Options) core.Error!void {
        if (self.expected_output_len) |expected|
            if (expected > self.max_output_len) return error.InvalidBlockPlan;
    }
};

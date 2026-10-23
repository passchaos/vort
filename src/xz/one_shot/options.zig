const std = @import("std");
const core = @import("../../core.zig");

pub const Options = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_dictionary_size: usize = std.math.maxInt(usize),
    /// Live requested heap bytes, including retained codec workspaces,
    /// block/Index metadata, and any compressed copy needed for overlap.
    max_working_memory: usize = std.math.maxInt(usize),

    pub fn validate(self: Options) core.Error!void {
        // Zero limits permit empty streams and never require an allocation.
        _ = self;
    }
};

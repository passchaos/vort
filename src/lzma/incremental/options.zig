const std = @import("std");
const core = @import("../../core.zig");

pub const max_symbol_output: usize = 273;
pub const symbol_input_guard: usize = 64;

pub const Options = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_dictionary_size: usize = std.math.maxInt(usize),
    max_compressed_buffer_len: usize = 1024 * 1024,
    max_working_memory: usize = std.math.maxInt(usize),
    expected_output_len: ?usize = null,
    /// Stop after a validated unknown-size LZMA end marker. Known-size
    /// streams retain their existing remaining-range-byte consumption rule.
    stop_after_end_marker: bool = false,
    /// Preferred lookahead for locating EOS in an enclosing format. A short
    /// guard uses a read-only symbol transaction before changing probabilities.
    /// Zero preserves the ordinary 64-byte non-final symbol guard.
    end_marker_input_guard: usize = 0,

    pub fn validate(self: Options) core.Error!void {
        if (self.expected_output_len) |expected|
            if (expected > self.max_output_len) return error.InvalidBlockPlan;
    }
};

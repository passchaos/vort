const std = @import("std");
pub const max_history: usize = 262139;

pub const Options = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_history_len: usize = max_history,
    /// Actual retained reverse-FSE suffix bytes; unused payload prefixes are
    /// consumed directly. LZVN/raw input never needs a payload-sized buffer.
    max_compressed_buffer_len: usize = 128 * 1024,
    max_working_memory: usize = std.math.maxInt(usize),
    expected_output_len: ?usize = null,
    stop_after_end_marker: bool = false,

    pub fn validate(self: Options) !void {
        if (self.max_history_len > max_history or (self.expected_output_len != null and self.expected_output_len.? > self.max_output_len))
            return error.InvalidLzfseStream;
    }
};

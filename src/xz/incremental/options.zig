const std = @import("std");
const core = @import("../../core.zig");

pub const InputPolicy = enum { progressive_block, prevalidated_block };
pub const Options = struct {
    input_policy: InputPolicy = .progressive_block,
    max_output_len: usize = std.math.maxInt(usize),
    max_dictionary_size: usize = std.math.maxInt(usize),
    /// Cumulative block body bytes: LZMA2 payload, padding, and selected check.
    max_compressed_block_len: usize = 64 * 1024 * 1024,
    max_decoded_block_len: usize = 64 * 1024 * 1024,
    /// Combined retained outer input and nested raw compressed storage.
    max_compressed_buffer_len: usize = 128 * 1024,
    /// All heap-retained filter/staging/pending output, excluding LZMA history.
    /// Default progressive push sizes remain bounded independently of this cap.
    max_decoded_buffer_len: usize = std.math.maxInt(usize),
    max_working_memory: usize = std.math.maxInt(usize),
    max_index_footer_len: usize = 16 * 1024 * 1024,
    max_block_count: usize = 1024 * 1024,
    expected_output_len: ?usize = null,
    stop_after_first_stream: bool = false,
    /// Retained for source compatibility. Index/Footer now parse progressively.
    first_stream_footer_retry_granularity: usize = 0,

    pub fn validate(self: Options) core.Error!void {
        if (self.expected_output_len) |expected|
            if (expected > self.max_output_len) return error.InvalidBlockPlan;
    }
};

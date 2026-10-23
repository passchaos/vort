const std = @import("std");
const core = @import("../../core.zig");
pub const Options = struct {
    /// Cumulative plaintext ceiling across automatic and explicit members.
    max_output_len: usize = std.math.maxInt(usize),
    /// Retained compressed lookahead while locating a complete next block.
    max_compressed_block_len: usize = 4 * 1024 * 1024,
    /// Per-block plaintext ceiling checked by the allocation-free CRC pre-scan.
    max_decoded_block_len: usize = 64 * 1024 * 1024,
    /// Live requested heap bytes across input, transformed bytes and u32 links.
    /// Caller output and fixed entropy/cursor state are excluded.
    max_working_memory: usize = std.math.maxInt(usize),
    /// Exact logical output count, including members resumed by nextStream.
    expected_output_len: ?usize = null,
    /// Stop at a validated member; finish plus an empty step checks the pledge.
    stop_after_first_stream: bool = false,
    /// Zero uses geometric retries; otherwise bound first-member read-ahead.
    first_stream_retry_granularity: usize = 0,

    pub fn validate(self: Options) core.Error!void {
        if (self.expected_output_len) |expected|
            if (expected > self.max_output_len) return error.InvalidBlockPlan;
    }
};

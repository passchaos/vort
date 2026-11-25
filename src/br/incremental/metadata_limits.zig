//! Admit a complete metadata block before delivering any of it.
const std = @import("std");
const core = @import("../../core.zig");
const Count = core.StreamCount;

pub fn validate(total: Count, blocks: Count, body_len: usize, max_bytes: Count, max_blocks: Count) error{OutputLimitExceeded}!void {
    // The unlimited settings leave counter overflow handling in the existing
    // body/commit path, including its progress and error offsets.
    if (max_bytes != std.math.maxInt(Count) and
        (total > max_bytes or core.stream_count.fromLocal(body_len) > max_bytes - total))
        return error.OutputLimitExceeded;
    if (max_blocks != std.math.maxInt(Count) and blocks >= max_blocks)
        return error.OutputLimitExceeded;
}

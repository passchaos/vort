//! Caller policy for serialized and regenerated incremental Zstandard blocks.
const std = @import("std");
const wire = @import("../frame/block.zig");

pub const maximum = std.compress.zstd.block_size_max;

pub fn validate(configured_size: usize) error{InvalidBlockPlan}!void {
    if (configured_size == 0 or configured_size > maximum) return error.InvalidBlockPlan;
}

pub fn parseHeader(input: []const u8, frame_maximum: usize, limit: usize) wire.Error!wire.Header {
    const header = try wire.parse(input);
    try wire.validateSize(header, frame_maximum);
    try admit(header.declared_len, limit);
    return header;
}

/// Apply after the independent format maximum has been checked.
pub fn admit(size: usize, limit: usize) error{OutputLimitExceeded}!void {
    if (size > limit) return error.OutputLimitExceeded;
}

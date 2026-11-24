//! A shared admission policy for data and skippable frames in one stream.
const std = @import("std");
const Count = @import("../../core.zig").StreamCount;
const Error = error{OutputLimitExceeded};

pub const unlimited = std.math.maxInt(Count);

pub fn requireSlot(remaining: Count) Error!void {
    if (remaining == 0) return error.OutputLimitExceeded;
}

/// Commit a slot after the caller has successfully checked admission.
pub fn consume(remaining: *Count) void {
    if (remaining.* != unlimited) remaining.* -= 1;
}

/// Incremental decoders already count completed frames by type. Subtract
/// both counts without overflowing their sum or changing the counters during
/// partial headers, dictionary retries or output backpressure.
pub fn requireNext(maximum: Count, data_frames: Count, skippable_frames: Count) Error!void {
    if (maximum != unlimited) try requireSlot(maximum -| data_frames -| skippable_frames);
}

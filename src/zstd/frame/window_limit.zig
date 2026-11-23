//! Declared-window admission independent of physical buffer sizes.
const Count = @import("../../core.zig").StreamCount;

pub fn validate(window: u64, maximum: Count) error{OutputLimitExceeded}!void {
    if (window > maximum) return error.OutputLimitExceeded;
}

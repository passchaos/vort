const std = @import("std");

/// Cap dictionary growth before addition, including fully retained u32 windows.
pub fn needed(comptime Int: type, current: Int, limit: Int, additional: Int) Int {
    std.debug.assert(current <= limit);
    return current + @min(additional, limit - current);
}

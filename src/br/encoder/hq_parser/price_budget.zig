const std = @import("std");

/// Per-plan admission count for exact copy-command symbol evaluations. It
/// spans all bounded windows and is independent of cumulative work profiles.
/// Literal, terminal/continuation helper pricing, matching and I/O are outside
/// this edge budget. Metadata lookup does not read symbol prices.
pub const PriceBudget = struct {
    limit: ?u64,
    admitted: u64 = 0,

    pub fn admit(self: *PriceBudget) error{SearchLimitExceeded}!void {
        if (self.limit) |maximum| if (self.admitted >= maximum) return error.SearchLimitExceeded;
        self.admitted = std.math.add(u64, self.admitted, 1) catch return error.SearchLimitExceeded;
    }
};

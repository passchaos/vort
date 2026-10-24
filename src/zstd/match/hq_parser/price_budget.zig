const std = @import("std");
const controls = @import("../../encode/controls.zig");

/// One admission interval per actual DP plan, shared by all its windows and
/// extension comparisons. Matching, literals and result verification are free.
pub const PriceBudget = struct {
    limit: ?u64,
    admitted: u64 = 0,
    profile: ?*controls.Profile,

    pub fn init(limit: ?u64, profile: ?*controls.Profile) PriceBudget {
        return .{ .limit = limit, .profile = profile };
    }

    pub fn admit(self: *PriceBudget) error{SearchLimitExceeded}!void {
        if (self.limit) |maximum| if (self.admitted >= maximum) return self.refuse();
        self.admitted = std.math.add(u64, self.admitted, 1) catch return self.refuse();
    }

    fn refuse(self: *PriceBudget) error{SearchLimitExceeded} {
        if (self.profile) |profile| profile.add("price_limit_refusals", 1);
        return error.SearchLimitExceeded;
    }

    pub fn finish(self: *const PriceBudget) void {
        if (self.profile) |profile| profile.recordMaxPlanPrice(self.admitted);
    }
};

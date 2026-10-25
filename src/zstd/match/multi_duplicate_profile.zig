//! Work accounting for the unindexed bootstrap matcher diagnostic.
const literal_cost = @import("../literals/single_cost_cache.zig");
const winner_cost = @import("../literals/winner_cost_cache.zig");

pub const Profile = struct {
    finder_calls: u64 = 0,
    selected_matches: u64 = 0,
    cost: literal_cost.Work = .{},
    histogram_scanned_bytes: u64 = 0,
    histogram_updates: u64 = 0,
    cache_state_bytes: usize = 0,
    cost_bound: winner_cost.Work = .{},
};

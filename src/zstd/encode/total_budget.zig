//! Zstd's encoder-owned requested-heap policy uses the shared stable ledger.
//! Workspace-only HQ limits remain a separate inner policy.
const shared = @import("../../io/requested_heap_budget.zig");
pub const Lease = shared.Lease;
pub const Snapshot = shared.Snapshot;
pub const EncodeMemoryProfile = shared.EncodeMemoryProfile;
pub const ExternalReservation = shared.ExternalReservation;
pub const Error = shared.Error;
pub const control_bytes = shared.control_bytes;
pub const isTracked = shared.isTracked;
pub const Config = @import("total_budget/entry.zig").Config;
pub const config = @import("total_budget/entry.zig").config;
pub const forward = @import("total_budget/entry.zig").forward;
pub const Entry = @import("total_budget/entry.zig").Entry;
pub const Reusable = @import("total_budget/reusable.zig").Reusable;

test {
    _ = @import("total_budget/tests.zig");
}

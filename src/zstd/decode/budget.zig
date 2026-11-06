//! Whole-operation requested-heap policy for Zstd decoding. The default path
//! keeps the caller allocator and needs no additional control allocation.
const shared = @import("../../io/requested_heap_budget.zig");

pub const Lease = shared.Lease;
pub const Snapshot = shared.Snapshot;
pub const DecodeMemoryProfile = shared.EncodeMemoryProfile;
pub const Error = shared.Error;
pub const control_bytes = shared.control_bytes;
pub const isTracked = shared.isTracked;
pub const Config = @import("budget/entry.zig").Config;
pub const config = @import("budget/entry.zig").config;
pub const forward = @import("budget/entry.zig").forward;
pub const mapLeaseError = @import("budget/entry.zig").mapLeaseError;
pub const Entry = @import("budget/entry.zig").Entry;
pub const Owner = @import("budget/owner.zig").Owner;
pub const owner_bytes = @sizeOf(Owner);
pub const AppendScope = @import("budget/append.zig").AppendScope;
pub const append = @import("budget/append.zig").append;

test {
    _ = @import("budget/entry_tests.zig");
    _ = @import("budget/owner_tests.zig");
    _ = @import("budget/append_tests.zig");
}

//! Requested heap for one whole Brotli decode operation. Entropy tables and
//! caller-owned scratch remain outside this heap contract.
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
pub const AppendScope = @import("budget/append.zig").AppendScope;

pub fn requested(options: anytype) bool {
    const settings = config(options);
    return settings.limit != null or settings.profile != null;
}

/// Policy observation for paths whose entire operation uses automatic storage
/// and caller-owned buffers. No ledger or metadata allocation is necessary.
pub fn noHeap(options: anytype) void {
    const settings = config(options);
    if (settings.profile) |profile| profile.record(0, settings.limit);
}

/// Observe public preflight failures without allocating metadata or clearing an
/// inherited owner's live/profile state.
pub fn observeCaller(caller: @import("std").mem.Allocator, options: anytype) void {
    if (!isTracked(caller)) noHeap(options);
}

/// Requested heap bytes in one shared encoding ledger, not process RSS.
/// Automatic stack storage, OS resources that bypass the supplied allocator,
/// allocator bookkeeping and backing remap transients are excluded. Worker
/// stacks/control requested through the supplied allocator are counted.
/// Snapshot merges describe the same ledger in observation order.
pub const EncodeMemoryProfile = struct {
    available: bool = false,
    peak_requested_bytes: usize = 0,
    live_requested_bytes: usize = 0,
    limit: ?usize = null,

    pub fn reset(self: *EncodeMemoryProfile) void {
        self.* = .{};
    }
    pub fn record(self: *EncodeMemoryProfile, live: usize, limit: ?usize) void {
        self.available = true;
        self.live_requested_bytes = live;
        self.peak_requested_bytes = @max(self.peak_requested_bytes, live);
        self.limit = limit;
    }
    pub fn merge(self: *EncodeMemoryProfile, other: EncodeMemoryProfile) void {
        if (!other.available) return;
        self.available = true;
        self.live_requested_bytes = other.live_requested_bytes;
        self.peak_requested_bytes = @max(self.peak_requested_bytes, other.peak_requested_bytes);
        self.limit = other.limit;
    }
};

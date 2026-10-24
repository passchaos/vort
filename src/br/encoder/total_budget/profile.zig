/// Ordered snapshots of one shared total-encoding budget. Requested bytes
/// include the stable control allocation. They exclude allocator bookkeeping,
/// internal remap transients and RSS. Independent simultaneous owners should
/// share one lease rather than sum measurements with overlapping lifetimes.
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
    /// The latest snapshot supplies live bytes and policy; peak is a maximum.
    pub fn merge(self: *EncodeMemoryProfile, other: EncodeMemoryProfile) void {
        if (!other.available) return;
        self.available = true;
        self.live_requested_bytes = other.live_requested_bytes;
        self.peak_requested_bytes = @max(self.peak_requested_bytes, other.peak_requested_bytes);
        self.limit = other.limit;
    }
};

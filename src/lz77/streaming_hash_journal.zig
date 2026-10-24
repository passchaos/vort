const std = @import("std");

pub const Error = error{ InvalidBlockPlan, OutputTooSmall };

/// One original bucket and predecessor slot for each successful insertion.
/// Both indices fit u16: the head has 32768 slots and the largest ring 65536.
pub const Entry = struct {
    bucket: u16,
    slot: u16,
    head: i64,
    previous: i64,
};

/// Caller-owned undo storage for a batch of StreamingHashGreedy.next calls.
/// Reserve before begin, then commit on success or rollback every failure and
/// successful no-progress return. Records never allocate while a batch is open.
/// No state, self or allocator pointer is retained; owners may be moved.
pub const Journal = struct {
    entries: std.ArrayList(Entry) = .empty,
    active: bool = false,

    pub fn ensureCapacity(self: *Journal, allocator: std.mem.Allocator, max_positions: usize) !void {
        if (self.active) return error.InvalidBlockPlan;
        _ = std.math.mul(usize, max_positions, @sizeOf(Entry)) catch return error.IntegerOverflow;
        try self.entries.ensureTotalCapacityPrecise(allocator, max_positions);
    }

    pub fn reserve(self: *Journal, allocator: std.mem.Allocator, max_positions: usize) !void {
        return self.ensureCapacity(allocator, max_positions);
    }

    pub fn begin(self: *Journal) Error!void {
        if (self.active or self.entries.items.len != 0) return error.InvalidBlockPlan;
        self.active = true;
    }

    pub fn isActive(self: *const Journal) bool {
        return self.active;
    }

    /// Called before either state write. Capacity failure leaves the failing
    /// insertion untouched; earlier insertions remain fully logged for undo.
    pub fn record(self: *Journal, bucket: usize, slot: usize, head: i64, previous: i64) Error!void {
        if (!self.active) return error.InvalidBlockPlan;
        if (self.entries.items.len == self.entries.capacity) return error.OutputTooSmall;
        const recorded_bucket = std.math.cast(u16, bucket) orelse return error.InvalidBlockPlan;
        const recorded_slot = std.math.cast(u16, slot) orelse return error.InvalidBlockPlan;
        self.entries.appendAssumeCapacity(.{ .bucket = recorded_bucket, .slot = recorded_slot, .head = head, .previous = previous });
    }

    pub fn commit(self: *Journal) void {
        self.entries.clearRetainingCapacity();
        self.active = false;
    }

    /// Restore the same state/layout that produced these records. Inactive
    /// rollback is a no-op, so it is safe to defer and commit before returning.
    pub fn rollback(self: *Journal, state: anytype) void {
        if (!self.active) return;
        var index = self.entries.items.len;
        while (index != 0) {
            index -= 1;
            const entry = self.entries.items[index];
            state.head.items[entry.bucket] = entry.head;
            state.prev.items[entry.slot] = entry.previous;
        }
        self.commit();
    }

    pub fn deinit(self: *Journal, allocator: std.mem.Allocator) void {
        self.entries.deinit(allocator);
        self.* = .{};
    }
};

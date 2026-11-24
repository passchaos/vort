//! Prepare owned Brotli history at data meta-block boundaries.
const std = @import("std");
const core = @import("../../core.zig");
const WorkingAllocator = @import("../../io/working_allocator.zig").WorkingAllocator;

pub const Error = std.mem.Allocator.Error || error{OutputLimitExceeded};

/// Borrowed only for the duration of an owned decode step. The limit is fixed
/// for the frame; the storage may move but the reservation never escapes.
pub const Reservation = struct {
    storage: *std.ArrayList(u8),
    budget: *WorkingAllocator,
    limit: usize,

    pub fn admit(self: Reservation, produced: core.StreamCount, block_len: usize) Error![]u8 {
        std.debug.assert(block_len != 0);
        if (self.limit == 0) return error.OutputLimitExceeded;
        const retained = core.stream_count.bounded(produced, self.limit);
        const required = retained + @min(block_len, self.limit - retained);
        const current = self.storage.items.len;
        if (required <= current) return self.storage.items;

        // The ring only wraps once it reaches the frame's fixed limit. Until
        // then every committed byte is still at its original linear index, so
        // preservation does not require relinearizing or moving a suffix.
        std.debug.assert(produced <= current);
        const grown = @min(self.limit, current +| current / 2);
        const headroom = self.budget.limit -| self.budget.live;
        // Geometric spare capacity is optional. Admit the exact minimum when
        // spare space would not fit alongside the currently live allocation.
        const target = @max(required, @min(grown, headroom));
        try self.storage.ensureTotalCapacityPrecise(self.budget.allocator(), target);
        self.storage.items.len = target;
        return self.storage.items;
    }
};

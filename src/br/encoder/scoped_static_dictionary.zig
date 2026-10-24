//! Legacy longest-match indexes owned by a total-tracked planning operation.
const std = @import("std");
const matcher = @import("static_dictionary_matcher.zig");
const total_budget = @import("total_budget.zig");

test {
    _ = @import("scoped_static_dictionary_tests.zig");
}

/// Untracked legacy calls retain their process-wide caches. Tracked calls
/// construct each required legacy index once with the operation's allocator;
/// those retained and temporary bytes consequently share its complete cap.
/// No pointer into this movable owner is stored; getters form short-lived views.
pub const Indexes = struct {
    owned_compact: ?matcher.Index = null,
    owned_complete: ?matcher.CompleteIndex = null,
    shared_compact: ?*const matcher.Index = null,
    shared_complete: ?*const matcher.CompleteIndex = null,

    pub fn init(allocator: std.mem.Allocator, need_complete: bool) !Indexes {
        var result: Indexes = .{};
        errdefer result.deinit();
        if (total_budget.isTracked(allocator)) {
            result.owned_compact = try matcher.Index.init(allocator);
            if (need_complete) result.owned_complete = try matcher.CompleteIndex.init(allocator);
        } else {
            result.shared_compact = try matcher.Index.sharedIndex();
            if (need_complete) result.shared_complete = try matcher.CompleteIndex.sharedIndex();
        }
        return result;
    }

    pub fn compact(self: *const Indexes) *const matcher.Index {
        return if (self.owned_compact) |*index| index else self.shared_compact.?;
    }

    pub fn complete(self: *const Indexes) *const matcher.CompleteIndex {
        return if (self.owned_complete) |*index| index else self.shared_complete.?;
    }

    pub fn deinit(self: *Indexes) void {
        if (self.owned_complete) |*index| index.deinit();
        if (self.owned_compact) |*index| index.deinit();
        self.* = .{};
    }
};

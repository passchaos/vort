//! Single-slot proposal ownership for one complete, pruned chooser scope.
const std = @import("std");

/// Use only with the fixed complete chooseProposalsCore(prune=true) strategy,
/// never a mode, prefix, or reference chooser. Analysis owns inline integer
/// arrays named total/by_mode; Proposals contains complete value-owned results.
/// The caller still collects a fresh Analysis on every lookup. A hit borrows
/// that candidate without retaining it; only successful publish transfers it.
/// After publication, keep the retained Analysis immutable, do not copy this
/// owner, and use the same codec allocator through replacement and deinit.
pub fn Workspace(comptime Analysis: type, comptime Proposals: type) type {
    return struct {
        retained: ?*Analysis = null,
        cached: ?Proposals = null,

        const Self = @This();

        pub fn init() Self {
            return .{};
        }

        pub fn lookup(self: *const Self, candidate: *const Analysis) ?Proposals {
            const retained = self.retained orelse return null;
            const props = self.cached orelse return null;
            if (retained.literal_count != candidate.literal_count) return null;
            // These integer arrays have no padding. The Analysis struct can,
            // so its complete representation must never be compared.
            if (!std.mem.eql(u8, std.mem.asBytes(&retained.total), std.mem.asBytes(&candidate.total))) return null;
            if (!std.mem.eql(u8, std.mem.asBytes(&retained.by_mode), std.mem.asBytes(&candidate.by_mode))) return null;
            return props;
        }

        /// Transfer the already allocated fresh Analysis only after success.
        /// Failed chooser work must not publish, preserving the previous slot.
        pub fn publish(self: *Self, allocator: std.mem.Allocator, fresh: *Analysis, props: Proposals) void {
            if (self.retained) |previous|
                if (previous != fresh) allocator.destroy(previous);
            self.retained = fresh;
            self.cached = props;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            if (self.retained) |retained| allocator.destroy(retained);
            self.* = .{};
        }
    };
}

test {
    _ = @import("workspace_tests.zig");
}

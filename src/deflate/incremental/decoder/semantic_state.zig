//! History geometry and optional work accounting for semantic transactions.
//! The ordinary decoder has no work counters or per-token observation.
const std = @import("std");
const rolling = @import("../../semantic/rolling_window.zig");

pub const Mode = enum { linear, rolling };
pub const Work = struct {
    generated_bytes: u64 = 0,
    delivered_bytes: u64 = 0,
    discarded_bytes: u64 = 0,
    bootstrap_bytes: u64 = 0,
    bootstrap_calls: u64 = 0,
    normalization_bytes: u64 = 0,
    normalization_calls: u64 = 0,
    generation_wraps: u64 = 0,
    drain_wraps: u64 = 0,
    normalization_wraps: u64 = 0,
};

pub fn begin(comptime mode: Mode, comptime observed: bool, self: anytype) void {
    const len = self.history_len;
    self.semantic_prefix_start = 0;
    // A partial compact ring, or a full ring whose cursor is zero, is already
    // chronological. The linear reference deliberately retains both copies.
    if (len != 0 and (mode == .linear or (len == rolling.window and self.history_pos != 0))) {
        const temporary = self.semantic_scratch[rolling.window..][0..len];
        if (len == rolling.window) {
            const first = rolling.window - self.history_pos;
            @memcpy(temporary[0..first], self.history[self.history_pos..][0..first]);
            @memcpy(temporary[first..], self.history[0 .. len - first]);
        } else {
            std.debug.assert(self.history_pos == len);
            @memcpy(temporary, self.history[0..len]);
        }
        @memcpy(self.semantic_scratch[0..len], temporary);
        if (observed) {
            self.semantic_work.bootstrap_calls +|= 1;
            self.semantic_work.bootstrap_bytes +|= 2 * @as(u64, @intCast(len));
        }
    }
    self.history_pos = if (len == rolling.window) 0 else len;
    self.semantic_prefix_len = len;
    self.semantic_generated_end = len;
    self.semantic_delivered = len;
    self.semantic_end_of_block = false;
    self.semantic_blocks_started += 1;
}

pub inline fn window(self: anytype, output_limit: usize) rolling.Window {
    return .{
        .storage = self.semantic_scratch,
        .base = self.semantic_prefix_start,
        .prefix_len = self.semantic_prefix_len,
        .output_limit = output_limit,
    };
}

/// Release delivered generation while retaining the newest RFC history.
pub fn retain(comptime mode: Mode, comptime observed: bool, self: anytype) void {
    const keep = @min(rolling.window, self.semantic_generated_end);
    const start = self.semantic_generated_end - keep;
    if (mode == .linear) {
        if (keep != 0) {
            std.mem.copyForwards(u8, self.semantic_scratch[0..keep], self.semantic_scratch[start..][0..keep]);
            if (observed) {
                self.semantic_work.normalization_calls +|= 1;
                self.semantic_work.normalization_bytes +|= @intCast(keep);
            }
        }
    } else self.semantic_prefix_start = (self.semantic_prefix_start + start) & rolling.mask;
    self.history_len = keep;
    self.history_pos = if (keep == rolling.window) 0 else keep;
    self.semantic_prefix_len = keep;
    self.semantic_generated_end = keep;
    self.semantic_delivered = keep;
}

/// Compact decoding reads first32 as its ring. Normalize only when leaving
/// semantic mode; intermediate generations keep their logical circular base.
pub fn normalize(comptime mode: Mode, comptime observed: bool, self: anytype) void {
    if (mode == .linear or self.semantic_prefix_start == 0) return;
    const current = window(self, self.semantic_generated_end);
    const len = self.semantic_prefix_len;
    if (observed and len != 0) {
        self.semantic_work.normalization_calls +|= 1;
        self.semantic_work.normalization_bytes +|= @intCast(len);
        if (current.base + len > rolling.capacity) self.semantic_work.normalization_wraps +|= 1;
    }
    current.normalizeTail(0, len);
    self.semantic_prefix_start = 0;
}

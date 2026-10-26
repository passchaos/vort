//! Immutable bounded Job plaintext and its accepted-frame history prefix.
//! Local byte indices never stand in for the cumulative frame coordinate.
const core = @import("../../core.zig");
const std = @import("std");
const count = core.stream_count;
pub const Count = core.StreamCount;
pub const Error = error{ IntegerOverflow, InvalidBlockPlan };

pub const View = struct {
    bytes: []const u8,
    prefix_len: usize,
    frame_offset: Count,
    final: bool,
    window_limit: ?usize = null,

    pub fn plain(self: View) []const u8 {
        return self.bytes[self.prefix_len..];
    }

    pub fn prefix(self: View) []const u8 {
        return self.bytes[0..self.prefix_len];
    }

    pub fn validate(self: View) Error!void {
        if (self.prefix_len > self.bytes.len or count.fromLocal(self.prefix_len) > self.frame_offset)
            return error.InvalidBlockPlan;
        _ = try count.addLocal(self.frame_offset, self.bytes.len - self.prefix_len);
    }

    /// A missing accepted-frame prefix must never become dictionary content.
    pub fn validatePrefix(self: View, window: usize) Error!void {
        try self.validate();
        if (self.prefix_len < count.bounded(self.frame_offset, window))
            return error.InvalidBlockPlan;
    }

    pub fn globalPosition(self: View, local: usize) Error!Count {
        try self.validate();
        if (local > self.bytes.len - self.prefix_len) return error.InvalidBlockPlan;
        return count.addLocal(self.frame_offset, local);
    }

    pub fn historyBefore(self: View, local: usize, window: usize) Error![]const u8 {
        _ = try self.globalPosition(local);
        const end = self.prefix_len + local;
        return self.bytes[end - @min(end, window) .. end];
    }

    pub fn historyStart(self: View, local: usize, window: usize) Error!Count {
        const position = try self.globalPosition(local);
        const history = try self.historyBefore(local, window);
        return position - count.fromLocal(history.len);
    }

    /// Preserve the existing one-shot borrowed spans and global coordinates.
    pub fn oneShot(input: []const u8, start: usize, end: usize) Error!View {
        if (start > end or end > input.len) return error.InvalidBlockPlan;
        const view: View = .{
            .bytes = input[0..end],
            .prefix_len = start,
            .frame_offset = count.fromLocal(start),
            .final = end == input.len,
        };
        try view.validate();
        return view;
    }
};

test "Zstd parallel incremental bounded job view keeps wide positions and physical slices separate" {
    var bytes: [256]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index);
    const boundary: Count = @as(Count, 1) << 32;
    const view: View = .{ .bytes = &bytes, .prefix_len = 128, .frame_offset = boundary, .final = true };
    try view.validatePrefix(128);
    try std.testing.expectEqual(boundary + 64, try view.globalPosition(64));
    try std.testing.expectEqual(boundary - 64, try view.historyStart(64, 128));
    try std.testing.expectEqualSlices(u8, bytes[64..192], try view.historyBefore(64, 128));
    var missing = view;
    missing.prefix_len = 0;
    try std.testing.expectError(error.InvalidBlockPlan, missing.validatePrefix(128));
    const overflow: View = .{ .bytes = bytes[0..2], .prefix_len = 0, .frame_offset = std.math.maxInt(Count) - 1, .final = true };
    try std.testing.expectError(error.IntegerOverflow, overflow.validate());
}

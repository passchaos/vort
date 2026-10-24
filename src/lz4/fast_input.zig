const std = @import("std");

/// Difference-based interval comparison avoids pointer-end overflow.
pub fn overlaps(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or b.len == 0) return false;
    const left = @intFromPtr(a.ptr);
    const right = @intFromPtr(b.ptr);
    return if (left <= right) right - left < a.len else left - right < b.len;
}

/// Copies only source spans overlapping the complete destination allocation.
/// No borrowed source survives a move/overwrite of that allocation. Input and
/// effective history are independent owners; nonoverlapping spans stay borrowed.
pub const Snapshot = struct {
    input: []const u8,
    prefix: []const u8,
    owned_input: ?[]u8 = null,
    owned_prefix: ?[]u8 = null,

    pub fn init(allocator: std.mem.Allocator, destination: []const u8, input: []const u8, prefix: []const u8) std.mem.Allocator.Error!Snapshot {
        var result: Snapshot = .{ .input = input, .prefix = prefix };
        errdefer result.deinit(allocator);
        if (overlaps(destination, input)) {
            const owned = try allocator.dupe(u8, input);
            result.owned_input = owned;
            result.input = owned;
        }
        if (overlaps(destination, prefix)) {
            const owned = try allocator.dupe(u8, prefix);
            result.owned_prefix = owned;
            result.prefix = owned;
        }
        return result;
    }
    pub fn deinit(self: *Snapshot, allocator: std.mem.Allocator) void {
        if (self.owned_prefix) |bytes| allocator.free(bytes);
        if (self.owned_input) |bytes| allocator.free(bytes);
        self.* = undefined;
    }
};

const std = @import("std");

pub fn append(allocator: std.mem.Allocator, history: *std.ArrayList(u8), chunk: []const u8, limit: usize) std.mem.Allocator.Error!void {
    if (limit == 0) {
        history.clearRetainingCapacity();
        return;
    }
    const required = @min(limit, std.math.add(usize, history.items.len, chunk.len) catch limit);
    try history.ensureTotalCapacity(allocator, required);
    if (chunk.len >= limit) {
        history.clearRetainingCapacity();
        history.appendSliceAssumeCapacity(chunk[chunk.len - limit ..]);
        return;
    }
    const retained_len = @min(history.items.len, limit - chunk.len);
    const retained = history.items[history.items.len - retained_len ..];
    std.mem.copyForwards(u8, history.items[0..retained_len], retained);
    history.items.len = retained_len;
    history.appendSliceAssumeCapacity(chunk);
}

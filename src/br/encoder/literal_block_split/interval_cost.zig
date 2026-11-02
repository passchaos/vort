const std = @import("std");
const huffman = @import("../../../huffman.zig");

/// A search has at most seven split points plus its two outer endpoints.
/// Costs depend only on the immutable prefix histograms for that search.
pub fn Cache(comptime endpoint_count: usize) type {
    comptime std.debug.assert(endpoint_count >= 2 and endpoint_count <= 16);
    return struct {
        const Self = @This();
        values: [endpoint_count][endpoint_count]u64 = undefined,
        ready: [endpoint_count]u16 = @splat(0),

        pub fn seed(self: *Self, start: usize, end: usize, value: u64) void {
            std.debug.assert(start < end and end < endpoint_count);
            self.values[start][end] = value;
            self.ready[start] |= @as(u16, 1) << @intCast(end);
        }

        pub fn cost(self: *Self, start: usize, end: usize, frequencies: *const [256]u32) u64 {
            std.debug.assert(start < end and end < endpoint_count);
            const mask = @as(u16, 1) << @intCast(end);
            if (self.ready[start] & mask != 0) return self.values[start][end];
            const result = weightedCost(frequencies);
            self.seed(start, end, result);
            return result;
        }
    };
}

pub fn weightedCost(frequencies: *const [256]u32) u64 {
    const lengths = huffman.treeCodeLengths(256, frequencies, 15);
    var total: u64 = 0;
    for (frequencies, lengths) |frequency, bits| total += @as(u64, frequency) * bits;
    return total;
}

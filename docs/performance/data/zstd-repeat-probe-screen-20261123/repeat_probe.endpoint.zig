const std = @import("std");
const lz77 = @import("../../../lz77.zig");

pub const Match = struct {
    position: usize = 0,
    length: usize = 0,
    distance: usize = 0,
};

/// A repeat candidate shorter than the policy's replacement minimum cannot
/// win. Reject its endpoint before extending a potentially long shared prefix.
/// A successful probe still returns the complete, exact match length.
pub fn atLeast(input: []const u8, position: usize, distance: usize, options: lz77.GreedyOptions, minimum: usize) Match {
    if (distance == 0 or distance > position or distance > options.window_len) return .{};
    const maximum = @min(options.max_match, input.len - position);
    const required = @max(minimum, 4);
    if (maximum < required) return .{};
    const candidate = position - distance;
    if (input[candidate + required - 1] != input[position + required - 1] or
        !std.mem.eql(u8, input[candidate..][0..4], input[position..][0..4])) return .{};

    var length: usize = 0;
    while (length + 8 <= maximum) : (length += 8) {
        const left = std.mem.readInt(u64, input[candidate + length ..][0..8], .little);
        const right = std.mem.readInt(u64, input[position + length ..][0..8], .little);
        if (left != right) {
            length += @ctz(left ^ right) / 8;
            break;
        }
    } else {
        while (length < maximum and input[candidate + length] == input[position + length]) length += 1;
    }
    if (length < required) return .{};
    return .{ .position = position, .length = length, .distance = distance };
}

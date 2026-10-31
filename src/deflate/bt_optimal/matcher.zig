//! Three-byte-hash binary tree for bounded DEFLATE match discovery.
//! Coverage suppresses outgoing evidence after a full258-byte match while
//! every position still updates the tree with the same raw search budgets.
const std = @import("std");

pub const min_input_len = 4096;
pub const max_input_len = 65536;
pub const coverage_threshold: usize = 258;
pub const empty: u16 = 65535;
pub const hash_size = 1 << 15;
pub const class_ends = [_]u16{
    1,    2,    3,    4,    6,    8,    12,    16,    24,    32,
    48,   64,   96,   128,  192,  256,  384,   512,   768,   1024,
    1536, 2048, 3072, 4096, 6144, 8192, 12288, 16384, 24576, 32768,
};

pub fn distanceClass(distance: usize) usize {
    std.debug.assert(distance > 0 and distance <= 32768);
    if (distance <= 4) return distance - 1;
    const log: usize = std.math.log2_int(usize, distance - 1);
    return log * 2 + @as(usize, ((distance - 1) >> @intCast(log - 1)) & 1);
}
pub fn hashAt(input: []const u8, position: usize) usize {
    const word = @as(u32, input[position]) | (@as(u32, input[position + 1]) << 8) |
        (@as(u32, input[position + 2]) << 16);
    return (word *% 0x1e35_a7bd) >> 17;
}

// Portable extension from an already proven common prefix. Little-endian
// reads put the first mismatching byte at the least significant set bit.
// Both 8-byte reads are bounded by the current suffix maximum; the older
// candidate has at least as many available input bytes as the current suffix.
pub fn extendPortable(input: []const u8, candidate: usize, position: usize, start: usize, maximum: usize) usize {
    var length = start;
    while (maximum - length >= 8) : (length += 8) {
        const difference = std.mem.readInt(u64, input[candidate + length ..][0..8], .little) ^
            std.mem.readInt(u64, input[position + length ..][0..8], .little);
        if (difference != 0) return length + @ctz(difference) / 8;
    }
    while (length < maximum and input[candidate + length] == input[position + length]) : (length += 1) {}
    return length;
}

pub const Tree = struct {
    roots: []u16,
    children: [][2]u16,

    pub fn init(allocator: std.mem.Allocator, len: usize) !Tree {
        const roots = try allocator.alloc(u16, hash_size);
        errdefer allocator.free(roots);
        const children = try allocator.alloc([2]u16, len);
        @memset(roots, empty);
        // Every inserted node's two children are assigned before later use.
        return .{ .roots = roots, .children = children };
    }
    pub fn deinit(self: Tree, allocator: std.mem.Allocator) void {
        allocator.free(self.roots);
        allocator.free(self.children);
    }

    pub fn advance(
        self: *Tree,
        input: []const u8,
        position: usize,
        maximum: usize,
        minimum: usize,
        window: usize,
        depth_limit: usize,
        candidate_limit: usize,
        lengths: *[30]u16,
        distances: *[30]u16,
    ) void {
        const hash = hashAt(input, position);
        var node = self.roots[hash];
        self.roots[hash] = @intCast(position);
        var pending_lt = &self.children[position][0];
        var pending_gt = &self.children[position][1];
        var lt_prefix: usize = 0;
        var gt_prefix: usize = 0;
        var depth: usize = 0;
        var candidates: usize = 0;
        while (node != empty and depth < depth_limit and candidates < candidate_limit) : (depth += 1) {
            const candidate: usize = node;
            std.debug.assert(candidate < position);
            const distance = position - candidate;
            // The tree is a treap with newer positions above older positions.
            // An expired root therefore has no in-window descendants.
            if (distance > window) break;
            // Earlier comparisons establish both shared prefixes. Hash
            // equality alone never establishes even one matching byte.
            var length = @min(lt_prefix, gt_prefix);
            length = extendPortable(input, candidate, position, length, maximum);
            if (length >= minimum) {
                candidates += 1;
                const cls = distanceClass(distance);
                if (length > lengths[cls] or (length == lengths[cls] and distance < distances[cls])) {
                    lengths[cls] = @intCast(length);
                    distances[cls] = @intCast(distance);
                }
            }
            if (length == maximum) {
                pending_lt.* = self.children[candidate][0];
                pending_gt.* = self.children[candidate][1];
                return;
            }
            if (input[candidate + length] < input[position + length]) {
                pending_lt.* = node;
                pending_lt = &self.children[candidate][1];
                node = pending_lt.*;
                lt_prefix = length;
            } else {
                pending_gt.* = node;
                pending_gt = &self.children[candidate][0];
                node = pending_gt.*;
                gt_prefix = length;
            }
        }
        // A depth-limited split discards deeper evidence and subtrees. Search
        // budgets count raw BT nodes, including hash collisions.
        pending_lt.* = empty;
        pending_gt.* = empty;
    }
};

//! Positive-weight, optimal Huffman lengths for a Bzip2 alphabet.
const std = @import("std");

pub const max_symbols: usize = 258;
pub const max_bits: u5 = 20;
pub const Error = error{InvalidBzip2HuffmanLengths};

const max_tree_nodes = 2 * max_symbols - 1;
const max_package_nodes = max_symbols * @as(usize, max_bits);

/// Build a complete prefix code minimizing sum(max(frequency, 1) * length).
/// Equal weights prefer lower symbol indexes, then earlier-created nodes.
/// Invalid slice shapes leave lengths untouched. No allocator is used: the
/// natural-tree path has about 7 KiB of fixed scratch, and its noinline optimal
/// package-merge fallback has about 68 KiB. Frequencies may use the full u32
/// range; even the largest 20-level package weight fits comfortably in u64.
pub fn build(frequencies: []const u32, lengths: []u5) Error!void {
    if (frequencies.len != lengths.len or frequencies.len < 3 or frequencies.len > max_symbols)
        return error.InvalidBzip2HuffmanLengths;
    if (!naturalLengths(frequencies, lengths)) packageMerge(frequencies, lengths);
}

const Order = struct {
    weights: []const u64,

    fn less(self: Order, left: u16, right: u16) bool {
        return self.weights[left] < self.weights[right] or
            (self.weights[left] == self.weights[right] and left < right);
    }
};

/// The ordinary Huffman tree is also constrained-optimal when it fits.
fn naturalLengths(frequencies: []const u32, lengths: []u5) bool {
    var weights: [max_tree_nodes]u64 = undefined;
    var parents: [max_tree_nodes]u16 = undefined;
    var depths: [max_tree_nodes]u16 = undefined;
    var leaves: [max_symbols]u16 = undefined;
    const n = frequencies.len;
    for (frequencies, 0..) |frequency, symbol| {
        weights[symbol] = @max(frequency, 1);
        leaves[symbol] = @intCast(symbol);
    }
    std.mem.sort(u16, leaves[0..n], Order{ .weights = weights[0..n] }, Order.less);
    var leaf: usize = 0;
    var parent: usize = n;
    var used = n;
    while (used < 2 * n - 1) : (used += 1) {
        const left = popNode(weights[0..used], leaves[0..n], &leaf, &parent);
        const right = popNode(weights[0..used], leaves[0..n], &leaf, &parent);
        weights[used] = weights[left] + weights[right];
        parents[left] = @intCast(used);
        parents[right] = @intCast(used);
    }
    depths[used - 1] = 0;
    var index = used - 1;
    while (index != 0) {
        index -= 1;
        depths[index] = depths[parents[index]] + 1;
    }
    for (depths[0..n]) |depth| if (depth > max_bits) return false;
    for (lengths, depths[0..n]) |*length, depth| length.* = @intCast(depth);
    return true;
}

fn popNode(weights: []const u64, leaves: []const u16, leaf: *usize, parent: *usize) u16 {
    const take_leaf = parent.* == weights.len or
        (leaf.* < leaves.len and Order.less(.{ .weights = weights }, leaves[leaf.*], @intCast(parent.*)));
    if (take_leaf) {
        const result = leaves[leaf.*];
        leaf.* += 1;
        return result;
    }
    const result: u16 = @intCast(parent.*);
    parent.* += 1;
    return result;
}

/// Binary package merge, adapted from src/huffman.zig's back-reference
/// implementation. Pair adjacent sorted items and merge their packages with
/// fresh leaves at each denomination. Selecting the cheapest 2*n-2 items at
/// the final denomination minimizes cost under the maximum-length bound.
noinline fn packageMerge(frequencies: []const u32, lengths: []u5) void {
    var weights: [max_package_nodes]u64 = undefined;
    var children: [max_package_nodes][2]u16 = undefined;
    var multiplicities: [max_package_nodes]u8 = undefined;
    var leaves: [max_symbols]u16 = undefined;
    var current: [2 * max_symbols]u16 = undefined;
    var packages: [max_symbols]u16 = undefined;
    const n = frequencies.len;
    for (frequencies, 0..) |frequency, symbol| {
        weights[symbol] = @max(frequency, 1);
        leaves[symbol] = @intCast(symbol);
    }
    std.mem.sort(u16, leaves[0..n], Order{ .weights = weights[0..n] }, Order.less);
    var used = n;
    var count = n;
    @memcpy(current[0..n], leaves[0..n]);
    var depth: u5 = 1;
    while (depth < max_bits) : (depth += 1) {
        const package_count = count / 2;
        for (packages[0..package_count], 0..) |*package, index| {
            const left = current[2 * index];
            const right = current[2 * index + 1];
            std.debug.assert(used < weights.len);
            weights[used] = weights[left] + weights[right];
            children[used] = .{ left, right };
            package.* = @intCast(used);
            used += 1;
        }
        // Adjacent pair sums are nondecreasing; creation indexes break equal
        // weights in the same order, so packages need no additional sort.
        const order: Order = .{ .weights = weights[0..used] };
        var leaf: usize = 0;
        var package: usize = 0;
        count = 0;
        while (leaf < n or package < package_count) : (count += 1) {
            if (package == package_count or
                (leaf < n and order.less(leaves[leaf], packages[package])))
            {
                current[count] = leaves[leaf];
                leaf += 1;
            } else {
                current[count] = packages[package];
                package += 1;
            }
        }
    }
    const selected_count = 2 * n - 2;
    std.debug.assert(selected_count <= count);
    @memset(multiplicities[0..used], 0);
    for (current[0..selected_count]) |index| multiplicities[index] += 1;
    // Every parent refers to older nodes. Propagating occurrences backwards
    // recovers each symbol's length without repeatedly traversing a shared DAG.
    var index = used;
    while (index > n) {
        index -= 1;
        const occurrences = multiplicities[index];
        if (occurrences == 0) continue;
        for (children[index]) |child| {
            multiplicities[child] += occurrences;
            std.debug.assert(multiplicities[child] <= max_bits);
        }
    }
    for (lengths, multiplicities[0..n]) |*length, occurrences| {
        std.debug.assert(occurrences != 0 and occurrences <= max_bits);
        length.* = @intCast(occurrences);
    }
}

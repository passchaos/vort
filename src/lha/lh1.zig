const std = @import("std");
const core = @import("../core.zig");
const bit_stream = @import("bit_stream.zig");

pub const Error = core.Error || bit_stream.Error || error{
    InvalidLh1Stream,
};

const history_size: usize = 4096;
const reorder_limit: u16 = 32 * 1024;
const symbol_count: usize = 314;
const node_count: usize = symbol_count * 2 - 1;
const copy_threshold: usize = 3;

const Node = struct {
    leaf: bool = false,
    child_index: u16 = 0,
    parent: u16 = 0,
    freq: u16 = 0,
    group: u16 = 0,
};

const Model = struct {
    nodes: [node_count]Node = @splat(.{}),
    leaf_nodes: [symbol_count]u16 = @splat(0),
    groups: [node_count]u16 = @splat(0),
    group_count: usize = 0,
    group_leader: [node_count]u16 = @splat(0),

    fn init() Model {
        var self = Model{};
        self.initGroups();
        var node_index: isize = node_count - 1;
        const leaf_group = self.allocGroup();
        for (0..symbol_count) |symbol| {
            const index: usize = @intCast(node_index);
            self.nodes[index] = .{
                .leaf = true,
                .child_index = @intCast(symbol),
                .freq = 1,
                .group = leaf_group,
            };
            self.group_leader[leaf_group] = @intCast(index);
            self.leaf_nodes[symbol] = @intCast(index);
            node_index -= 1;
        }

        var child: usize = node_count - 1;
        while (node_index >= 0) {
            const index: usize = @intCast(node_index);
            self.nodes[index].leaf = false;
            self.nodes[index].child_index = @intCast(child);
            self.nodes[child].parent = @intCast(index);
            self.nodes[child - 1].parent = @intCast(index);
            self.nodes[index].freq = self.nodes[child].freq + self.nodes[child - 1].freq;
            if (self.nodes[index].freq == self.nodes[index + 1].freq) {
                self.nodes[index].group = self.nodes[index + 1].group;
            } else {
                self.nodes[index].group = self.allocGroup();
            }
            self.group_leader[self.nodes[index].group] = @intCast(index);
            node_index -= 1;
            child -= 2;
        }
        return self;
    }

    fn decodeCode(self: *Model, reader: *bit_stream.Reader) Error!u16 {
        var node_index: usize = 0;
        while (!self.nodes[node_index].leaf) {
            const bit = try reader.read(1);
            const first_child = self.nodes[node_index].child_index;
            if (first_child < bit) return error.InvalidLh1Stream;
            node_index = first_child - bit;
            if (node_index >= node_count) return error.InvalidLh1Stream;
        }
        const symbol = self.nodes[node_index].child_index;
        if (symbol >= symbol_count) return error.InvalidLh1Stream;
        self.incrementForCode(symbol);
        return symbol;
    }

    fn encodeCode(
        self: *Model,
        writer: *bit_stream.Writer,
        symbol: u16,
    ) Error!void {
        if (symbol >= symbol_count) return error.InvalidLh1Stream;
        var bits: [node_count]u1 = undefined;
        var count: usize = 0;
        var child = self.leaf_nodes[symbol];
        while (child != 0) {
            const parent = self.nodes[child].parent;
            const first_child = self.nodes[parent].child_index;
            bits[count] = if (child == first_child)
                0
            else if (child + 1 == first_child)
                1
            else
                return error.InvalidLh1Stream;
            count += 1;
            child = parent;
        }
        while (count != 0) {
            count -= 1;
            try writer.write(bits[count], 1);
        }
        self.incrementForCode(symbol);
    }

    fn incrementForCode(self: *Model, symbol: u16) void {
        if (self.nodes[0].freq >= reorder_limit) self.reconstruct();
        self.nodes[0].freq += 1;
        var node_index = self.leaf_nodes[symbol];
        while (node_index != 0) {
            node_index = self.makeGroupLeader(node_index);
            self.incrementNodeFrequency(node_index);
            node_index = self.nodes[node_index].parent;
        }
    }

    fn makeGroupLeader(self: *Model, node_index: u16) u16 {
        const group = self.nodes[node_index].group;
        const leader_index = self.group_leader[group];
        if (leader_index == node_index) return node_index;

        const leaf = self.nodes[leader_index].leaf;
        const child_index = self.nodes[leader_index].child_index;
        self.nodes[leader_index].leaf = self.nodes[node_index].leaf;
        self.nodes[leader_index].child_index = self.nodes[node_index].child_index;
        self.nodes[node_index].leaf = leaf;
        self.nodes[node_index].child_index = child_index;
        self.updateMovedNode(node_index);
        self.updateMovedNode(leader_index);
        return leader_index;
    }

    fn updateMovedNode(self: *Model, node_index: u16) void {
        const node = self.nodes[node_index];
        if (node.leaf) {
            self.leaf_nodes[node.child_index] = node_index;
        } else {
            self.nodes[node.child_index].parent = node_index;
            self.nodes[node.child_index - 1].parent = node_index;
        }
    }

    fn incrementNodeFrequency(self: *Model, node_index: u16) void {
        std.debug.assert(node_index != 0);
        self.nodes[node_index].freq += 1;
        const group = self.nodes[node_index].group;
        if (node_index < node_count - 1 and group == self.nodes[node_index + 1].group) {
            self.group_leader[group] += 1;
            if (self.nodes[node_index].freq == self.nodes[node_index - 1].freq) {
                self.nodes[node_index].group = self.nodes[node_index - 1].group;
            } else {
                const new_group = self.allocGroup();
                self.nodes[node_index].group = new_group;
                self.group_leader[new_group] = node_index;
            }
        } else if (self.nodes[node_index].freq == self.nodes[node_index - 1].freq) {
            self.freeGroup(group);
            self.nodes[node_index].group = self.nodes[node_index - 1].group;
        }
    }

    fn reconstruct(self: *Model) void {
        var leaf_write: usize = 0;
        for (0..node_count) |index| {
            if (self.nodes[index].leaf) {
                self.nodes[leaf_write].leaf = true;
                self.nodes[leaf_write].child_index = self.nodes[index].child_index;
                self.nodes[leaf_write].freq = (self.nodes[index].freq + 1) / 2;
                leaf_write += 1;
            }
        }
        std.debug.assert(leaf_write == symbol_count);

        var leaf_index: isize = symbol_count - 1;
        var child: isize = node_count - 1;
        var index: isize = node_count - 1;
        while (index >= 0) {
            while (child - index < 2) {
                const target: usize = @intCast(index);
                const source: usize = @intCast(leaf_index);
                self.nodes[target] = self.nodes[source];
                self.leaf_nodes[self.nodes[source].child_index] = @intCast(target);
                index -= 1;
                leaf_index -= 1;
            }

            const child_index: usize = @intCast(child);
            const frequency = @as(u32, self.nodes[child_index].freq) +
                self.nodes[child_index - 1].freq;
            while (leaf_index >= 0 and frequency >= self.nodes[@intCast(leaf_index)].freq) {
                const target: usize = @intCast(index);
                const source: usize = @intCast(leaf_index);
                self.nodes[target] = self.nodes[source];
                self.leaf_nodes[self.nodes[source].child_index] = @intCast(target);
                index -= 1;
                leaf_index -= 1;
            }

            const target: usize = @intCast(index);
            self.nodes[target] = .{
                .leaf = false,
                .freq = @intCast(frequency),
                .child_index = @intCast(child_index),
            };
            self.nodes[child_index].parent = @intCast(target);
            self.nodes[child_index - 1].parent = @intCast(target);
            index -= 1;
            child -= 2;
        }

        self.initGroups();
        var group = self.allocGroup();
        self.nodes[0].group = group;
        self.group_leader[group] = 0;
        for (1..node_count) |node_index| {
            if (self.nodes[node_index].freq == self.nodes[node_index - 1].freq) {
                self.nodes[node_index].group = self.nodes[node_index - 1].group;
            } else {
                group = self.allocGroup();
                self.nodes[node_index].group = group;
                self.group_leader[group] = @intCast(node_index);
            }
        }
    }

    fn initGroups(self: *Model) void {
        for (&self.groups, 0..) |*group, index| group.* = @intCast(index);
        self.group_count = 0;
    }

    fn allocGroup(self: *Model) u16 {
        const result = self.groups[self.group_count];
        self.group_count += 1;
        return result;
    }

    fn freeGroup(self: *Model, group: u16) void {
        self.group_count -= 1;
        self.groups[self.group_count] = group;
    }
};

pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    if (output.len == 0) {
        if (input.len != 0) return error.TrailingData;
        return;
    }
    var model = Model.init();
    var reader = bit_stream.Reader{ .input = input };
    var output_offset: usize = 0;
    while (output_offset < output.len) {
        const symbol = try model.decodeCode(&reader);
        if (symbol < 256) {
            output[output_offset] = @intCast(symbol);
            output_offset += 1;
        } else {
            const match_len = @as(usize, symbol) - 256 + copy_threshold;
            if (match_len > output.len - output_offset) return error.SizeMismatch;
            const high = try decodeOffsetHigh(&reader);
            const low = try reader.read(6);
            const distance = (@as(usize, high) << 6) + low + 1;
            copyMatch(output, &output_offset, distance, match_len);
        }
    }
    try reader.finish();
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
) Error![]u8 {
    return decodeAllocLimited(allocator, input, output_len, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
    max_output_len: usize,
) Error![]u8 {
    if (output_len > max_output_len) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    try decodeInto(input, output);
    return output;
}

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input);
    return output.toOwnedSlice(allocator);
}

/// Emit a deterministic literal-only LH1 stream while maintaining the full
/// adaptive tree, including its 32 KiB reconstruction transition.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    if (input.len == 0) return 0;
    var model = Model.init();
    var writer = bit_stream.Writer{ .allocator = allocator, .output = output };
    for (input) |literal| try model.encodeCode(&writer, literal);
    try writer.finish();
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn decodeOffsetHigh(reader: *bit_stream.Reader) Error!u8 {
    var code: u16 = @intCast(try reader.read(3));
    var first: u16 = 0;
    var symbol_base: u8 = 0;
    const counts = [_]u8{ 1, 3, 8, 12, 24, 16 };
    for (counts, 0..) |count, index| {
        if (code >= first and code - first < count)
            return symbol_base + @as(u8, @intCast(code - first));
        symbol_base += count;
        first = (first + count) << 1;
        if (index + 1 != counts.len)
            code = (code << 1) | @as(u16, @intCast(try reader.read(1)));
    }
    return error.InvalidLh1Stream;
}

fn copyMatch(output: []u8, output_offset: *usize, distance: usize, count: usize) void {
    std.debug.assert(distance >= 1 and distance <= history_size);
    for (0..count) |_| {
        output[output_offset.*] = if (distance > output_offset.*)
            ' '
        else
            output[output_offset.* - distance];
        output_offset.* += 1;
    }
}

test "LH1 literal writer round trips across tree reconstruction" {
    const allocator = std.testing.allocator;
    var input: [70 * 1024]u8 = undefined;
    var state: u32 = 0x1a11_0001;
    for (&input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const encoded = try encodeAlloc(allocator, &input);
    defer allocator.free(encoded);
    const caller_encoded = try allocator.alloc(u8, encoded.len);
    defer allocator.free(caller_encoded);
    try std.testing.expectEqual(encoded.len, try encodeInto(allocator, &input, caller_encoded));
    try std.testing.expectEqualSlices(u8, encoded, caller_encoded);
    const decoded = try decodeAlloc(allocator, encoded, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "LH1 decoder accepts implicit history matches" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var model = Model.init();
    var writer = bit_stream.Writer{ .allocator = std.testing.allocator, .output = &encoded };
    try model.encodeCode(&writer, 256);
    try writer.write(0, 3);
    try writer.write(0, 6);
    try writer.finish();
    var output: [3]u8 = undefined;
    try decodeInto(encoded.items, &output);
    try std.testing.expectEqualSlices(u8, "   ", &output);
}

test "LH1 decoder rejects truncation size mismatch and output limits" {
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto(&.{}, &output));
    const encoded = try encodeAlloc(std.testing.allocator, "ab");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectError(error.TrailingData, decodeInto(encoded, &output));
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocLimited(std.testing.allocator, encoded, 2, 1),
    );
}

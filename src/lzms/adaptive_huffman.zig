const std = @import("std");
const core = @import("../core.zig");
const huffman = @import("../huffman.zig");

pub const Error = core.Error || error{InvalidLzms};

pub fn AdaptiveCode(comptime max_symbols: usize) type {
    return struct {
        frequencies: [max_symbols]u32 = @splat(0),
        table: huffman.HuffmanTable(max_symbols) = .{},
        num_symbols: usize = 0,
        remaining: usize = 0,
        rebuild_frequency: usize = 0,

        const Self = @This();

        pub fn init(num_symbols: usize, rebuild_frequency: usize) Error!Self {
            if (num_symbols > max_symbols or rebuild_frequency == 0)
                return error.InvalidLzms;
            var self = Self{
                .num_symbols = num_symbols,
                .remaining = rebuild_frequency,
                .rebuild_frequency = rebuild_frequency,
            };
            @memset(self.frequencies[0..num_symbols], 1);
            try self.rebuild(false);
            return self;
        }

        pub fn decode(self: *Self, reader: anytype) Error!u16 {
            if (self.num_symbols == 0) return error.InvalidLzms;
            const symbol = try self.table.decodeValue(reader);
            if (symbol >= self.num_symbols) return error.InvalidLzms;
            self.frequencies[symbol] += 1;
            self.remaining -= 1;
            if (self.remaining == 0) try self.rebuild(true);
            return symbol;
        }

        fn rebuild(self: *Self, dilute: bool) Error!void {
            const lengths = try buildLengths(
                max_symbols,
                &self.frequencies,
                self.num_symbols,
            );
            self.table = try huffman.HuffmanTable(max_symbols).init(
                lengths[0..self.num_symbols],
            );
            self.remaining = self.rebuild_frequency;
            if (dilute) {
                for (self.frequencies[0..self.num_symbols]) |*frequency|
                    frequency.* = (frequency.* >> 1) + 1;
            }
        }
    };
}

pub fn AdaptiveEncoder(comptime max_symbols: usize) type {
    return struct {
        frequencies: [max_symbols]u32 = @splat(0),
        codes: [max_symbols]u16 = @splat(0),
        lengths: [max_symbols]u4 = @splat(0),
        num_symbols: usize = 0,
        remaining: usize = 0,
        rebuild_frequency: usize = 0,

        const Self = @This();

        pub fn init(num_symbols: usize, rebuild_frequency: usize) Error!Self {
            if (num_symbols == 0 or num_symbols > max_symbols or rebuild_frequency == 0)
                return error.InvalidLzms;
            var self = Self{
                .num_symbols = num_symbols,
                .remaining = rebuild_frequency,
                .rebuild_frequency = rebuild_frequency,
            };
            @memset(self.frequencies[0..num_symbols], 1);
            try self.rebuild(false);
            return self;
        }

        pub fn encode(self: *Self, writer: anytype, symbol: usize) !void {
            if (symbol >= self.num_symbols or self.lengths[symbol] == 0)
                return error.InvalidLzms;
            try writer.writeBits(self.codes[symbol], self.lengths[symbol]);
            self.frequencies[symbol] += 1;
            self.remaining -= 1;
            if (self.remaining == 0) try self.rebuild(true);
        }

        fn rebuild(self: *Self, dilute: bool) Error!void {
            self.lengths = try buildLengths(
                max_symbols,
                &self.frequencies,
                self.num_symbols,
            );
            var counts: [huffman.max_code_bits + 1]u16 = @splat(0);
            for (self.lengths[0..self.num_symbols]) |length| {
                if (length == 0 or length > huffman.max_code_bits)
                    return error.InvalidLzms;
                counts[length] += 1;
            }
            var code: u32 = 0;
            var next: [huffman.max_code_bits + 1]u32 = @splat(0);
            for (1..huffman.max_code_bits + 1) |bits| {
                code = (code + counts[bits - 1]) << 1;
                next[bits] = code;
            }
            for (self.lengths[0..self.num_symbols], 0..) |length, symbol| {
                self.codes[symbol] = @intCast(next[length]);
                next[length] += 1;
            }
            self.remaining = self.rebuild_frequency;
            if (dilute) {
                for (self.frequencies[0..self.num_symbols]) |*frequency|
                    frequency.* = (frequency.* >> 1) + 1;
            }
        }
    };
}

fn buildLengths(
    comptime max_symbols: usize,
    frequencies: *const [max_symbols]u32,
    num_symbols: usize,
) Error![max_symbols]u4 {
    var lengths: [max_symbols]u4 = @splat(0);
    if (num_symbols == 0) return lengths;
    if (num_symbols == 1) {
        lengths[0] = 1;
        return lengths;
    }

    const invalid = std.math.maxInt(u16);
    const Node = struct {
        weight: u64,
        symbol: u16 = invalid,
    };
    const Less = struct {
        nodes: []const Node,

        fn less(context: @This(), lhs: u16, rhs: u16) bool {
            const left = context.nodes[lhs];
            const right = context.nodes[rhs];
            return left.weight < right.weight or
                (left.weight == right.weight and left.symbol < right.symbol);
        }
    };

    var nodes: [2 * max_symbols - 1]Node = undefined;
    var parents: [2 * max_symbols - 1]u16 = undefined;
    var leaves: [max_symbols]u16 = undefined;
    for (0..num_symbols) |symbol| {
        if (frequencies[symbol] == 0) return error.InvalidLzms;
        nodes[symbol] = .{
            .weight = frequencies[symbol],
            .symbol = @intCast(symbol),
        };
        leaves[symbol] = @intCast(symbol);
    }
    std.mem.sort(
        u16,
        leaves[0..num_symbols],
        Less{ .nodes = nodes[0..num_symbols] },
        Less.less,
    );

    var leaf_index: usize = 0;
    var parent_index = num_symbols;
    var node_count = num_symbols;
    while (node_count < 2 * num_symbols - 1) {
        const first = popNode(Node, nodes[0..node_count], leaves[0..num_symbols], &leaf_index, &parent_index);
        const second = popNode(Node, nodes[0..node_count], leaves[0..num_symbols], &leaf_index, &parent_index);
        nodes[node_count] = .{ .weight = nodes[first].weight + nodes[second].weight };
        parents[first] = @intCast(node_count);
        parents[second] = @intCast(node_count);
        node_count += 1;
    }

    var depths: [2 * max_symbols - 1]u16 = undefined;
    depths[node_count - 1] = 0;
    var index = node_count - 1;
    while (index != 0) {
        index -= 1;
        depths[index] = depths[parents[index]] + 1;
    }
    for (0..num_symbols) |symbol| {
        const depth = depths[symbol];
        if (depth == 0 or depth > huffman.max_code_bits)
            return error.InvalidLzms;
        lengths[symbol] = @intCast(depth);
    }
    return lengths;
}

fn popNode(
    comptime Node: type,
    nodes: []const Node,
    leaves: []const u16,
    leaf_index: *usize,
    parent_index: *usize,
) u16 {
    if (leaf_index.* >= leaves.len) {
        const result: u16 = @intCast(parent_index.*);
        parent_index.* += 1;
        return result;
    }
    const leaf = leaves[leaf_index.*];
    if (parent_index.* >= nodes.len or
        nodes[leaf].weight <= nodes[parent_index.*].weight)
    {
        leaf_index.* += 1;
        return leaf;
    }
    const result: u16 = @intCast(parent_index.*);
    parent_index.* += 1;
    return result;
}

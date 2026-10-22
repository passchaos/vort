const std = @import("std");
const tree = @import("tree.zig");
const codec = @import("codec.zig");
const clusters = @import("clusters.zig");
const prefix = @import("prefix.zig");

pub const Error = clusters.Error;
pub const Group = struct { leading_zeroes: usize, bytes: []const u8, trailing_zeroes: usize };
const block_size = clusters.block_size;

/// A selected prefix and its codec/input buffers remain valid until next().
pub const Cursor = struct {
    allocator: std.mem.Allocator,
    node: *tree.Node,
    encoder: *codec.Encoder,
    extent_size: usize,
    max_pcluster_size: ?usize,
    length: usize,
    position: usize = 0,
    physical_bytes: usize = 0,
    input: ?[]u8 = null,

    pub fn init(allocator: std.mem.Allocator, node: *tree.Node, encoder: *codec.Encoder, extent_size: usize, max_pcluster_size: ?usize) Error!Cursor {
        if (extent_size < block_size or extent_size > clusters.max_extent_size or !std.math.isPowerOfTwo(extent_size) or node.compressed_data != null) return error.InvalidErofs;
        const length = try clusters.prefixLength(node);
        node.compressed_advise = if (extent_size > block_size or max_pcluster_size != null) 2 else 0;
        return .{
            .allocator = allocator,
            .node = node,
            .encoder = encoder,
            .extent_size = extent_size,
            .max_pcluster_size = max_pcluster_size,
            .length = length,
            .input = if (node.source != null and length != 0) try allocator.alloc(u8, @min(extent_size, length)) else null,
        };
    }

    pub fn deinit(self: *Cursor) void {
        if (self.input) |input| self.allocator.free(input);
        self.* = undefined;
    }

    pub fn next(self: *Cursor) Error!?Group {
        if (self.position == self.length) {
            self.node.compressed_block_count = self.physical_bytes / block_size;
            return null;
        }
        const indexes = self.node.compressed_indexes orelse return error.InvalidErofs;
        const window_end = self.position + @min(self.extent_size, self.length - self.position);
        const window = if (self.input) |input| data: {
            const part = input[0 .. window_end - self.position];
            try self.node.readContent(self.position, part);
            break :data part;
        } else self.node.content()[self.position..window_end];
        const selected = if (self.max_pcluster_size) |capacity| try self.encoder.encodePrefixScratch(window, capacity, block_size) else prefix.Result{ .bytes = try self.encoder.encodeScratch(window), .consumed = window.len };
        if (selected.consumed > window.len or (selected.consumed != window.len and selected.consumed % block_size != 0)) return error.InvalidErofs;
        const compressed = selected.consumed != 0 and selected.bytes.len != 0 and selected.bytes.len < selected.consumed;
        const end = if (compressed) self.position + selected.consumed else if (self.max_pcluster_size != null) self.position + @min(block_size, self.length - self.position) else window_end;
        const bytes = window[0 .. end - self.position];
        const count = try clusters.blocksFor(bytes.len);
        const first_index = self.position / block_size;
        if (first_index > indexes.len or count > indexes.len - first_index) return error.InvalidErofs;
        const first_block = self.physical_bytes / block_size;
        if (first_block > std.math.maxInt(u32)) return error.InvalidErofs;
        var group: Group = undefined;
        var physical_size: usize = undefined;
        if (compressed) {
            if (self.max_pcluster_size) |capacity| if (selected.bytes.len > capacity) return error.InvalidErofs;
            const physical_count = try clusters.blocksFor(selected.bytes.len);
            if (physical_count == 0 or physical_count > 256) return error.InvalidErofs;
            physical_size = std.math.mul(usize, physical_count, block_size) catch return error.IntegerOverflow;
            group = .{ .leading_zeroes = physical_size - selected.bytes.len, .bytes = selected.bytes, .trailing_zeroes = 0 };
            indexes[first_index] = .{ .kind = 1, .physical_block = @intCast(first_block) };
            for (1..count) |index| {
                const delta0: u32 = if (index == 1) 0x800 | @as(u32, @intCast(physical_count)) else @intCast(index);
                const delta1: u32 = @intCast(count - index);
                indexes[first_index + index] = .{ .kind = 2, .physical_block = delta0 | (delta1 << 16) };
            }
        } else {
            physical_size = std.math.mul(usize, count, block_size) catch return error.IntegerOverflow;
            group = .{ .leading_zeroes = 0, .bytes = bytes, .trailing_zeroes = physical_size - bytes.len };
            for (0..count) |index| {
                const physical = std.math.add(usize, first_block, index) catch return error.IntegerOverflow;
                if (physical > std.math.maxInt(u32)) return error.InvalidErofs;
                indexes[first_index + index] = .{ .kind = 0, .physical_block = @intCast(physical) };
            }
        }
        self.physical_bytes = std.math.add(usize, self.physical_bytes, physical_size) catch return error.IntegerOverflow;
        self.position = end;
        return group;
    }
};

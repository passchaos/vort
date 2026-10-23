const std = @import("std");
const tree = @import("tree.zig");
const format = @import("../format.zig");
const options = @import("options.zig");
const codec = @import("codec.zig");
const clusters = @import("clusters.zig");
const cluster_cursor = @import("cluster_cursor.zig");

pub const Error = cluster_cursor.Error || format.Error;
const block_size = clusters.block_size;

pub const Cursor = struct {
    node: *tree.Node,
    compressed: ?cluster_cursor.Cursor = null,
    group: ?cluster_cursor.Group = null,
    leading: usize = 0,
    bytes_read: usize = 0,
    trailing: usize = 0,
    content_size: usize = 0,
    padded_size: usize = 0,
    written: usize = 0,
    capacity: usize,

    pub fn init(allocator: std.mem.Allocator, node: *tree.Node, encoder: ?*codec.Encoder, settings: options.Options, capacity: usize) Error!Cursor {
        const layout = std.enums.fromInt(format.Layout, node.layout) orelse return error.InvalidErofs;
        var cursor = Cursor{ .node = node, .capacity = capacity };
        if (node.directory_in_metadata_zone) return cursor;
        if (layout == .compressed_full) {
            cursor.compressed = try cluster_cursor.Cursor.init(allocator, node, encoder orelse return error.InvalidErofs, settings.compression_extent_size, settings.max_pcluster_size);
        } else if (layout != .chunk_based) {
            cursor.content_size = if (layout == .flat_inline) node.contentSize() / block_size * block_size else node.contentSize();
            cursor.padded_size = std.math.mul(usize, try clusters.blocksFor(cursor.content_size), block_size) catch return error.IntegerOverflow;
            if (cursor.padded_size > capacity) return error.InvalidErofs;
        }
        return cursor;
    }

    pub fn deinit(self: *Cursor) void {
        if (self.compressed) |*cursor| cursor.deinit();
        self.* = undefined;
    }

    pub fn read(self: *Cursor, output: []u8) Error!?usize {
        if (output.len == 0) return 0;
        if (self.compressed) |*cursor| {
            while (true) {
                if (self.group == null) {
                    const group = try cursor.next() orelse {
                        if (self.written != cursor.physical_bytes) return error.InvalidErofs;
                        return null;
                    };
                    if (cursor.physical_bytes > self.capacity) return error.InvalidErofs;
                    self.group = group;
                    self.leading = group.leading_zeroes;
                    self.trailing = group.trailing_zeroes;
                    self.bytes_read = 0;
                }
                var size: usize = 0;
                if (self.leading != 0) {
                    size = @min(output.len, self.leading);
                    @memset(output[0..size], 0);
                    self.leading -= size;
                } else if (self.bytes_read < self.group.?.bytes.len) {
                    const bytes = self.group.?.bytes;
                    size = @min(output.len, bytes.len - self.bytes_read);
                    @memcpy(output[0..size], bytes[self.bytes_read..][0..size]);
                    self.bytes_read += size;
                } else if (self.trailing != 0) {
                    size = @min(output.len, self.trailing);
                    @memset(output[0..size], 0);
                    self.trailing -= size;
                } else {
                    self.group = null;
                    continue;
                }
                self.written += size;
                return size;
            }
        }
        if (self.written == self.padded_size) return null;
        var size: usize = undefined;
        if (self.written < self.content_size) {
            var buffer: [64 * 1024]u8 = undefined;
            size = @min(output.len, @min(buffer.len, self.content_size - self.written));
            try self.node.readContent(self.written, buffer[0..size]);
            @memcpy(output[0..size], buffer[0..size]);
        } else {
            size = @min(output.len, self.padded_size - self.written);
            @memset(output[0..size], 0);
        }
        self.written += size;
        return size;
    }
};

const std = @import("std");
const format = @import("../format.zig");
const wire = @import("../xattr.zig");
const input_module = @import("input.zig");
const context_module = @import("context.zig");
const stream = @import("stream.zig");
const segments = @import("segments/iterator.zig");

pub const Error = stream.Error || wire.Error;

pub fn isPrimary(header: format.Superblock) bool {
    return header.xattr_prefix_count == 0 or
        header.feature_compat & format.feature_compat_plain_xattr_prefixes != 0 or
        (header.metabox_nid == 0 and header.packed_nid == 0);
}

/// Plain/metabox tables borrow metadata. Packed tables own only their records,
/// with at most 128 * 260 bytes of storage and one temporary decoded extent.
pub const Table = struct {
    input: input_module.Input,
    start: u32,
    count: u8,
    owned: ?[]u8 = null,

    pub fn init(context: context_module.Context) Error!Table {
        const header = context.reader.superblock;
        if (isPrimary(header)) return .{
            .input = context.reader.primary,
            .start = header.xattr_prefix_start,
            .count = header.xattr_prefix_count,
        };
        if (header.metabox_nid != 0) return .{
            .input = context.reader.metabox orelse return error.ErofsMissingMetabox,
            .start = header.xattr_prefix_start,
            .count = header.xattr_prefix_count,
        };
        const value = try context.reader.inode(header.packed_nid);
        if (try value.fileType() != .regular or value.fragment_offset != null)
            return error.InvalidErofs;
        const start = std.math.mul(usize, header.xattr_prefix_start, 4) catch return error.IntegerOverflow;
        if (start > value.file_size) return error.TruncatedFrame;
        const capacity = std.math.mul(usize, header.xattr_prefix_count, 260) catch return error.IntegerOverflow;
        const storage = try context.allocator.alloc(u8, capacity);
        errdefer context.allocator.free(storage);
        var bounded = context;
        bounded.limits.max_decoded_extent_size = @min(bounded.limits.max_decoded_extent_size, bounded.limits.max_packed_extent_size);
        var reader = try stream.Reader.init(bounded, value, start, value.file_size - start);
        defer reader.deinit();
        var used: usize = 0;
        for (0..header.xattr_prefix_count) |index| {
            try readExact(&reader, storage[used..][0..2]);
            const payload: usize = format.readU16(storage, used);
            if (payload < 1 or payload > format.name_max + 1) return error.InvalidErofs;
            const size = (payload + 2 + 3) & ~@as(usize, 3);
            try readExact(&reader, storage[used + 2 ..][0..payload]);
            const padding = storage[used + 2 + payload ..][0 .. size - 2 - payload];
            if (index + 1 < header.xattr_prefix_count) {
                try readExact(&reader, padding);
            } else {
                // EROFS metadata pads before the next record, so the last
                // payload can end exactly at the packed inode's EOF.
                @memset(padding, 0);
            }
            try wire.validatePrefixTableInput(.{ .slice = storage[used..][0..size] }, 0, 1);
            used += size;
        }
        // Only record bytes were decoded. Finish metadata validation for that
        // exact range without reading or decompressing unrelated packed data.
        const logical_size = reader.position();
        var validation = try segments.Iterator.init(bounded, value, start, logical_size);
        var position: usize = 0;
        while (try validation.next()) |segment| {
            if (segment.start != position or segment.size == 0 or segment.size > logical_size - position)
                return error.InvalidErofs;
            position += segment.size;
        }
        if (position != logical_size) return error.InvalidErofs;
        return .{ .input = .{ .slice = storage[0..used] }, .start = 0, .count = header.xattr_prefix_count, .owned = storage };
    }

    pub fn deinit(self: *Table, allocator: std.mem.Allocator) void {
        if (self.owned) |bytes| allocator.free(bytes);
        self.* = undefined;
    }
};

fn readExact(reader: *stream.Reader, output: []u8) Error!void {
    var position: usize = 0;
    while (position < output.len) {
        const progress = try reader.read(output[position..]);
        if (progress.output_written == 0) return error.TruncatedFrame;
        position += progress.output_written;
    }
}

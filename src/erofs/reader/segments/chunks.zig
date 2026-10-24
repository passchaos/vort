const std = @import("std");
const context_module = @import("../context.zig");
const inode_module = @import("../types.zig");
const devices_module = @import("../devices.zig");
const format = @import("../../format.zig");
const spans = @import("types.zig");

pub const Error = spans.Error;
pub const Walker = struct {
    context: context_module.Context,
    inode: inode_module.Inode,
    chunk_size: usize,
    index: usize,
    end_index: usize,

    pub fn init(context: context_module.Context, inode: inode_module.Inode, start: usize, end: usize) Error!Walker {
        if (inode.chunk_bits >= @bitSizeOf(usize) or (inode.chunk_index_size != 4 and inode.chunk_index_size != 8)) return error.InvalidErofs;
        const size: usize = @as(usize, 1) << @intCast(inode.chunk_bits);
        return .{ .context = context, .inode = inode, .chunk_size = size, .index = start / size, .end_index = (end - 1) / size + 1 };
    }

    pub fn next(self: *Walker) Error!?spans.Whole {
        if (self.index == self.end_index) return null;
        const index = self.index;
        self.index += 1;
        const metadata = try self.context.reader.metadataInput(self.inode);
        const relative = std.math.mul(usize, index, self.inode.chunk_index_size) catch return error.IntegerOverflow;
        const position = try context_module.add(self.inode.chunk_index_start, relative);
        var record: [8]u8 = @splat(0);
        try metadata.read(position, record[0..self.inode.chunk_index_size]);
        var id: u16 = 0;
        var block: u64 = undefined;
        if (self.inode.chunk_index_size == 8) {
            const hi = format.readU16(&record, 0);
            const wide = self.inode.chunk_format & 0x40 != 0;
            if (wide and self.context.reader.superblock.feature_incompat & format.feature_incompat_48bit == 0) return error.InvalidErofs;
            if (!wide and hi != 0) return error.InvalidErofs;
            id = format.readU16(&record, 2) & try devices_module.idMask(self.context.reader.superblock.extra_devices);
            block = @as(u64, format.readU32(&record, 4)) | (if (wide) @as(u64, hi) << 32 else 0);
        } else block = format.readU32(&record, 0);
        const start = std.math.mul(usize, index, self.chunk_size) catch return error.IntegerOverflow;
        const end = @min(self.inode.file_size, try context_module.add(start, self.chunk_size));
        const null_block: u64 = if (self.inode.chunk_format & 0x40 != 0) (@as(u64, 1) << 48) - 1 else std.math.maxInt(u32);
        if (block == null_block) return .{ .start = start, .end = end, .content = .zero };
        const region = try self.context.devices.resolve(id, block, end - start);
        return .{ .start = start, .end = end, .content = .{ .raw = .{ .input = region.input, .start = region.start, .physical_size = end - start } } };
    }
};

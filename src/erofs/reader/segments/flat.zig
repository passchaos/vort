const std = @import("std");
const context_module = @import("../context.zig");
const inode_module = @import("../types.zig");
const format = @import("../../format.zig");
const spans = @import("types.zig");

pub const Error = spans.Error;
pub const Walker = struct {
    context: context_module.Context,
    inode: inode_module.Inode,
    phase: u2 = 0,

    pub fn next(self: *Walker) Error!?spans.Whole {
        const block_size = self.context.reader.superblock.block_size;
        const full = if (self.inode.layout == .flat_inline) self.inode.file_size / block_size * block_size else self.inode.file_size;
        if (self.phase == 0) {
            self.phase = 1;
            if (full != 0) {
                const null_block: u64 = if (self.context.reader.superblock.feature_incompat & format.feature_incompat_48bit != 0) (@as(u64, 1) << 48) - 1 else std.math.maxInt(u32);
                const content: spans.Content = if (self.inode.data_block == null_block) .zero else .{ .raw = .{ .start = std.math.mul(u64, self.inode.data_block, block_size) catch return error.IntegerOverflow, .physical_size = full } };
                return .{ .start = 0, .end = full, .content = content };
            }
        }
        if (self.phase == 1) {
            self.phase = 2;
            if (full != self.inode.file_size) {
                const metadata = try self.context.reader.metadataInput(self.inode);
                const start = try context_module.add(self.inode.location, try context_module.add(self.inode.inode_size, self.inode.xattr_size));
                const size = self.inode.file_size - full;
                const end = try metadata.end(start, size);
                if (start / block_size != (end - 1) / block_size) return error.InvalidErofs;
                return .{ .start = full, .end = self.inode.file_size, .content = .{ .raw = .{ .input = metadata, .start = start, .physical_size = size } } };
            }
        }
        return null;
    }
};

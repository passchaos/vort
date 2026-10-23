const std = @import("std");
const context_module = @import("../context.zig");
const inode_module = @import("../types.zig");
const spans = @import("types.zig");

pub const Error = spans.Error;
const Head = struct { start: usize, block: u32, kind: u2, blocks: u32, partial: bool };

pub const Walker = struct {
    context: context_module.Context,
    inode: inode_module.Inode,
    cluster_size: usize,
    count: usize,
    index: usize = 0,
    previous: ?Head = null,
    started: bool = false,
    finished: bool = false,

    pub fn init(context: context_module.Context, inode: inode_module.Inode) Error!Walker {
        _ = inode.compressed_algorithms[0] orelse return error.InvalidErofs;
        if (inode.compressed_cluster_bits >= @bitSizeOf(usize)) return error.UnsupportedErofsFeature;
        const cluster_size: usize = @as(usize, 1) << @intCast(inode.compressed_cluster_bits);
        return .{ .context = context, .inode = inode, .cluster_size = cluster_size, .count = (try context_module.add(inode.file_size, cluster_size - 1)) / cluster_size };
    }

    fn nextHead(self: *Walker) Error!?Head {
        while (self.index < self.count) {
            const index = self.index;
            self.index += 1;
            const record = if (self.inode.layout == .compressed_full) try self.context.reader.readFullIndex(self.inode, index) else try self.context.reader.readCompactIndex(self.inode, index, self.count);
            if (record.kind == 2) continue;
            if (record.logical_offset >= self.cluster_size) return error.InvalidErofs;
            const base = std.math.mul(usize, index, self.cluster_size) catch return error.IntegerOverflow;
            const logical = try context_module.add(base, record.logical_offset);
            return .{ .start = logical, .block = record.physical_block, .kind = record.kind, .partial = record.partial, .blocks = (try self.context.reader.compressedBlockCount(self.inode, index, self.count, logical, record.kind)) orelse 1 };
        }
        return null;
    }

    pub fn next(self: *Walker) Error!?spans.Whole {
        if (self.finished) return null;
        if (!self.started) {
            self.previous = try self.nextHead() orelse return error.InvalidErofs;
            self.started = true;
            if (self.previous.?.start != 0) return .{ .start = 0, .end = self.previous.?.start, .content = .zero };
        }
        const prior = self.previous orelse return error.InvalidErofs;
        const following = try self.nextHead();
        if (following) |head| if (head.start <= prior.start) return error.InvalidErofs;
        self.previous = following;
        self.finished = following == null;
        if (prior.start >= self.inode.file_size) return .{ .start = prior.start, .end = prior.start, .content = .zero };
        const end = @min(self.inode.file_size, if (following) |head| head.start else self.inode.file_size);
        if (end <= prior.start) return error.InvalidErofs;
        const block_size = self.context.reader.superblock.block_size;
        const start = std.math.mul(u64, prior.block, block_size) catch return error.IntegerOverflow;
        const physical_size = std.math.mul(usize, prior.blocks, block_size) catch return error.IntegerOverflow;
        const content: spans.Content = switch (prior.kind) {
            0 => .{ .raw = .{ .input = self.context.reader.primary, .start = start, .physical_size = physical_size, .rotation = if (self.inode.compressed_advise & 0x10 != 0) .{ .block_size = block_size, .start = prior.start % block_size } else null } },
            1, 3 => .{ .encoded = .{ .input = self.context.reader.primary, .start = start, .encoded_size = physical_size, .decoded_size = end - prior.start, .partial = prior.partial, .algorithm = self.inode.compressed_algorithms[if (prior.kind == 3) 1 else 0] orelse return error.InvalidErofs } },
            else => return error.UnsupportedErofsFeature,
        };
        return .{ .start = prior.start, .end = end, .content = content };
    }
};

const context_module = @import("../context.zig");
const inode_module = @import("../types.zig");
const format = @import("../../format.zig");
const extent = @import("../../extent.zig");
const spans = @import("types.zig");
const std = @import("std");

pub const Error = spans.Error || extent.Error;

pub const Walker = struct {
    context: context_module.Context,
    inode: inode_module.Inode,
    view: extent.View,
    cumulative: u64 = 0,
    index: usize = 0,
    previous: ?extent.Record = null,
    started: bool = false,
    finished: bool = false,

    pub fn init(context: context_module.Context, inode: inode_module.Inode) Walker {
        return .{ .context = context, .inode = inode, .view = .{ .file_size = inode.file_size, .advise = inode.compressed_advise, .cluster_bits = inode.compressed_cluster_bits, .record_start = inode.compressed_extent_start, .record_size = inode.compressed_extent_record_size, .record_count = inode.compressed_extent_count } };
    }

    fn nextRecord(self: *Walker) Error!?extent.Record {
        if (self.index == self.view.record_count) return null;
        const metadata = try self.context.reader.metadataInput(self.inode);
        const record = try extent.readRecordInput(metadata, self.view, self.index, &self.cumulative);
        self.index += 1;
        return record;
    }

    pub fn next(self: *Walker) Error!?spans.Whole {
        if (self.finished) return null;
        if (!self.started) {
            const metadata = try self.context.reader.metadataInput(self.inode);
            if (self.view.record_size == 4) self.cumulative = try metadata.integer(u64, self.view.record_start);
            self.previous = try self.nextRecord() orelse return error.InvalidErofs;
            self.started = true;
            if (self.previous.?.logical_start != 0) return .{ .start = 0, .end = self.previous.?.logical_start, .content = .zero };
        }
        const prior = self.previous orelse return error.InvalidErofs;
        const following = try self.nextRecord();
        const end = if (following) |record| record.logical_start else self.inode.file_size;
        if (end <= prior.logical_start or end > self.inode.file_size) return error.InvalidErofs;
        self.previous = following;
        self.finished = following == null;
        const block_size = self.context.reader.superblock.block_size;
        var content: spans.Content = undefined;
        if (prior.fragment_offset) |offset| {
            content = .{ .fragment = offset };
        } else if (prior.encoded_len == 0) {
            content = .zero;
        } else if (prior.format_code == 0) {
            if (end - prior.logical_start > prior.encoded_len) return error.InvalidErofs;
            content = .{ .raw = .{ .input = self.context.reader.primary, .start = prior.physical_start, .physical_size = prior.encoded_len, .rotation = if (self.inode.compressed_advise & 0x10 != 0 and prior.physical_start % block_size == 0 and prior.encoded_len % block_size == 0) .{ .block_size = block_size, .start = prior.logical_start % block_size } else null } };
        } else {
            const algorithm = std.enums.fromInt(format.Compression, @as(u8, prior.format_code - 1)) orelse return error.UnsupportedErofsCompression;
            content = .{ .encoded = .{ .input = self.context.reader.primary, .start = prior.physical_start, .encoded_size = prior.encoded_len, .decoded_size = end - prior.logical_start, .algorithm = algorithm, .partial = prior.partial } };
        }
        return .{ .start = prior.logical_start, .end = end, .content = content };
    }
};

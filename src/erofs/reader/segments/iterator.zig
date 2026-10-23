const std = @import("std");
const context_module = @import("../context.zig");
const inode_module = @import("../types.zig");
const format = @import("../../format.zig");
const spans = @import("types.zig");
const flat = @import("flat.zig");
const chunks = @import("chunks.zig");
const indexed = @import("indexed.zig");
const records = @import("records.zig");

pub const Error = spans.Error || records.Error;
const Child = struct { inode: inode_module.Inode, start: usize, size: usize, destination: usize, max_decoded: usize };
const Event = union(enum) { segment: spans.Segment, child: Child };

const Frame = struct {
    context: context_module.Context,
    inode: inode_module.Inode,
    start: usize,
    end: usize,
    destination: usize,
    max_decoded: usize,
    prefix_end: usize,
    mode: union(enum) { flat: flat.Walker, chunks: chunks.Walker, indexed: indexed.Walker, records: records.Walker, tail, done },

    fn init(context: context_module.Context, inode: inode_module.Inode, start: usize, size: usize, destination: usize, max_decoded: usize) Error!Frame {
        const end = try context_module.add(start, size);
        if (end > inode.file_size) return error.InvalidErofs;
        if (context.reader.superblock.block_size == 0) return error.InvalidErofs;
        var frame = Frame{ .context = context, .inode = inode, .start = start, .end = end, .destination = destination, .max_decoded = max_decoded, .prefix_end = inode.file_size, .mode = .done };
        if (size == 0) return frame;
        frame.mode = switch (inode.layout) {
            .flat_plain, .flat_inline => .{ .flat = .{ .context = context, .inode = inode } },
            .chunk_based => .{ .chunks = try chunks.Walker.init(context, inode, start, end) },
            .compressed_full, .compressed_compact => mode: {
                if (inode.compressed_extent_record_size != 0) break :mode .{ .records = records.Walker.init(context, inode) };
                if (inode.fragment_offset != null and inode.compressed_inline_size != 0) return error.InvalidErofs;
                frame.prefix_end = if (inode.compressed_inline_size != 0) inode.compressed_inline_logical_start else if (inode.fragment_offset != null) inode.fragment_logical_start else inode.file_size;
                if (frame.prefix_end > inode.file_size) return error.InvalidErofs;
                break :mode if (start < @min(end, frame.prefix_end)) .{ .indexed = try indexed.Walker.init(context, inode) } else .tail;
            },
        };
        return frame;
    }

    fn crop(self: *Frame, whole: spans.Whole, end: usize) Error!?Event {
        const segment = try spans.crop(whole, self.start, end, self.destination, self.max_decoded) orelse return null;
        if (segment.content == .fragment) {
            if (self.context.reader.superblock.feature_incompat & format.feature_incompat_fragments == 0 or self.context.reader.superblock.packed_nid == 0 or self.inode.nid == self.context.reader.superblock.packed_nid) return error.InvalidErofs;
            const packed_inode = try self.context.reader.inode(self.context.reader.superblock.packed_nid);
            if (try packed_inode.fileType() != .regular or packed_inode.fragment_offset != null or packed_inode.compressed_advise & 0x20 != 0) return error.InvalidErofs;
            if (packed_inode.layout == .chunk_based) return error.UnsupportedErofsLayout;
            return .{ .child = .{ .inode = packed_inode, .start = std.math.cast(usize, segment.content.fragment) orelse return error.IntegerOverflow, .size = segment.size, .destination = segment.start, .max_decoded = @min(segment.max_decoded, self.context.limits.max_packed_extent_size) } };
        }
        return .{ .segment = segment };
    }

    fn tail(self: *Frame) Error!?Event {
        if (self.end <= self.prefix_end) return null;
        if (self.inode.compressed_inline_size != 0) {
            const metadata = try self.context.reader.metadataInput(self.inode);
            _ = try metadata.end(self.inode.compressed_inline_start, self.inode.compressed_inline_size);
            const size = self.inode.file_size - self.prefix_end;
            var content: spans.Content = undefined;
            if (self.inode.compressed_inline_kind == 0) {
                if (size != self.inode.compressed_inline_size) return error.InvalidErofs;
                content = .{ .raw = .{ .input = metadata, .start = self.inode.compressed_inline_start, .physical_size = size } };
            } else {
                if (self.inode.compressed_inline_kind != 1 and self.inode.compressed_inline_kind != 3) return error.InvalidErofs;
                const algorithm = self.inode.compressed_algorithms[if (self.inode.compressed_inline_kind == 3) 1 else 0] orelse return error.InvalidErofs;
                content = .{ .encoded = .{ .input = metadata, .start = self.inode.compressed_inline_start, .encoded_size = self.inode.compressed_inline_size, .decoded_size = size, .algorithm = algorithm } };
            }
            return self.crop(.{ .start = self.prefix_end, .end = self.inode.file_size, .content = content }, self.end);
        }
        const fragment = self.inode.fragment_offset orelse return null;
        return self.crop(.{ .start = self.prefix_end, .end = self.inode.file_size, .content = .{ .fragment = fragment } }, self.end);
    }

    fn next(self: *Frame) Error!?Event {
        while (true) {
            switch (self.mode) {
                .flat => |*walker| {
                    if (try walker.next()) |whole| {
                        if (try self.crop(whole, self.end)) |event| return event;
                    } else {
                        self.mode = .done;
                    }
                },
                .chunks => |*walker| {
                    if (try walker.next()) |whole| {
                        if (try self.crop(whole, self.end)) |event| return event;
                    } else {
                        self.mode = .done;
                    }
                },
                .records => |*walker| {
                    if (try walker.next()) |whole| {
                        if (try self.crop(whole, self.end)) |event| return event;
                    } else {
                        self.mode = .done;
                    }
                },
                .indexed => |*walker| {
                    if (try walker.next()) |whole| {
                        if (try self.crop(whole, @min(self.end, self.prefix_end))) |event| return event;
                    } else {
                        self.mode = .tail;
                    }
                },
                .tail => {
                    self.mode = .done;
                    return self.tail();
                },
                .done => return null,
            }
        }
    }
};

pub const Iterator = struct {
    frames: [2]Frame = undefined,
    depth: usize = 0,

    pub fn init(context: context_module.Context, inode: inode_module.Inode, start: usize, size: usize) Error!Iterator {
        var iterator = Iterator{};
        iterator.frames[0] = try Frame.init(context, inode, start, size, 0, context.limits.max_decoded_extent_size);
        iterator.depth = 1;
        return iterator;
    }

    pub fn next(self: *Iterator) Error!?spans.Segment {
        while (self.depth != 0) {
            const event = try self.frames[self.depth - 1].next() orelse {
                self.depth -= 1;
                continue;
            };
            switch (event) {
                .segment => |segment| return segment,
                .child => |child| {
                    if (self.depth == self.frames.len) return error.InvalidErofs;
                    self.frames[self.depth] = try Frame.init(self.frames[self.depth - 1].context, child.inode, child.start, child.size, child.destination, child.max_decoded);
                    self.depth += 1;
                },
            }
        }
        return null;
    }
};

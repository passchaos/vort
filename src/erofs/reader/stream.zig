const std = @import("std");
const context_module = @import("context.zig");
const inode_module = @import("types.zig");
const iterator_module = @import("segments/iterator.zig");
const spans = @import("segments/types.zig");

pub const Error = iterator_module.Error;
pub const Progress = struct {
    output_written: usize,
    position: usize,
    status: enum { need_output, done },
};

/// One logical segment and one decoded extent survive between read calls.
/// A failing read never changes the caller's output; errors remain sticky.
pub const Reader = struct {
    context: context_module.Context,
    iterator: iterator_module.Iterator,
    size: usize,
    delivered: usize = 0,
    segment: ?spans.Segment = null,
    segment_read: usize = 0,
    cached: ?[]u8 = null,
    failed: ?Error = null,
    done: bool = false,

    pub fn init(context: context_module.Context, inode: inode_module.Inode, start: usize, size: usize) Error!Reader {
        return .{ .context = context, .iterator = try iterator_module.Iterator.init(context, inode, start, size), .size = size };
    }

    fn release(self: *Reader) void {
        if (self.cached) |bytes| self.context.allocator.free(bytes);
        self.cached = null;
    }

    pub fn position(self: *const Reader) usize {
        return self.delivered;
    }

    pub fn deinit(self: *Reader) void {
        self.release();
        self.* = undefined;
    }

    pub fn read(self: *Reader, output: []u8) Error!Progress {
        if (self.failed) |err| return err;
        return self.readInternal(output) catch |err| {
            self.release();
            self.failed = err;
            return err;
        };
    }

    fn readInternal(self: *Reader, output: []u8) Error!Progress {
        if (self.done) return .{ .output_written = 0, .position = self.delivered, .status = .done };
        if (self.delivered == self.size) {
            if (try self.iterator.next() != null) return error.InvalidErofs;
            self.done = true;
            self.release();
            return .{ .output_written = 0, .position = self.delivered, .status = .done };
        }
        if (output.len == 0) return .{ .output_written = 0, .position = self.delivered, .status = .need_output };
        if (self.segment == null) {
            const segment = try self.iterator.next() orelse return error.InvalidErofs;
            if (segment.start != self.delivered or segment.size == 0 or segment.size > self.size - self.delivered) return error.InvalidErofs;
            self.segment = segment;
            self.segment_read = 0;
            if (segment.content == .encoded) {
                const encoded = segment.content.encoded;
                var bounded = self.context;
                bounded.limits.max_decoded_extent_size = @min(bounded.limits.max_decoded_extent_size, segment.max_decoded);
                const input = encoded.input orelse return error.InvalidErofs;
                const bytes = if (encoded.partial) try bounded.decodePartial(encoded.algorithm, input, encoded.start, encoded.encoded_size, encoded.decoded_size) else try bounded.decode(encoded.algorithm, input, encoded.start, encoded.encoded_size, encoded.decoded_size);
                self.cached = bytes;
                if (bytes.len != encoded.decoded_size) return error.SizeMismatch;
            }
        }
        const segment = self.segment.?;
        var size = @min(output.len, segment.size - self.segment_read);
        switch (segment.content) {
            .fragment => return error.InvalidErofs,
            .zero => @memset(output[0..size], 0),
            .encoded => |encoded| {
                const start = try context_module.add(encoded.within, self.segment_read);
                const end = try context_module.add(start, size);
                const bytes = self.cached orelse return error.InvalidErofs;
                if (end > bytes.len) return error.SizeMismatch;
                @memcpy(output[0..size], bytes[start..end]);
            },
            .raw => |raw| {
                var within = try context_module.add(raw.skip, self.segment_read);
                if (raw.rotation) |rotation| {
                    within = (rotation.start + within) % rotation.block_size;
                    size = @min(size, rotation.block_size - within);
                }
                var scratch: [64 * 1024]u8 = undefined;
                size = @min(size, scratch.len);
                const input = raw.input orelse return error.InvalidErofs;
                try input.readAt(try context_module.offset(raw.start, within), scratch[0..size]);
                @memcpy(output[0..size], scratch[0..size]);
            },
        }
        self.delivered += size;
        self.segment_read += size;
        if (self.segment_read == segment.size) {
            self.release();
            self.segment = null;
        }
        return .{ .output_written = size, .position = self.delivered, .status = .need_output };
    }
};

const std = @import("std");
const context_module = @import("context.zig");
const types = @import("types.zig");
const directory = @import("directory.zig");
const stream = @import("stream.zig");

pub const Error = stream.Error || directory.Error || error{ErofsNotDirectory};
pub const Diagnostics = struct { bytes_read: usize, entries_yielded: usize, entry_offset: usize };

/// One decoded directory block is retained. Returned names borrow that block.
pub const Reader = struct {
    allocator: std.mem.Allocator,
    reader: stream.Reader,
    buffer: []u8,
    block_size: usize,
    size: usize,
    offset: usize = 0,
    block_start: usize = 0,
    block: ?directory.Block = null,
    validator: directory.Validator = .{},
    entries: usize = 0,
    entry_offset: usize = 0,
    done: bool = false,
    failed: ?Error = null,

    pub fn init(context: context_module.Context, inode: types.Inode, max_directory_size: usize) Error!Reader {
        if (try inode.fileType() != .directory) return error.ErofsNotDirectory;
        if (inode.file_size > max_directory_size) return error.OutputLimitExceeded;
        const block_size = context.reader.superblock.block_size;
        if (block_size == 0) return error.InvalidErofs;
        const bytes = try context.allocator.alloc(u8, @min(block_size, inode.file_size));
        errdefer context.allocator.free(bytes);
        return .{ .allocator = context.allocator, .reader = try stream.Reader.init(context, inode, 0, inode.file_size), .buffer = bytes, .block_size = block_size, .size = inode.file_size };
    }

    pub fn deinit(self: *Reader) void {
        self.reader.deinit();
        self.allocator.free(self.buffer);
        self.* = undefined;
    }

    pub fn diagnostics(self: *const Reader) Diagnostics {
        return .{ .bytes_read = self.reader.position(), .entries_yielded = self.entries, .entry_offset = self.entry_offset };
    }

    pub fn next(self: *Reader) Error!?types.DirectoryEntry {
        if (self.failed) |err| return err;
        return self.nextInternal() catch |err| {
            if (self.block) |block| self.entry_offset = self.block_start + block.attempt_offset;
            self.failed = err;
            return err;
        };
    }

    fn nextInternal(self: *Reader) Error!?types.DirectoryEntry {
        if (self.done) return null;
        while (true) {
            if (self.block) |*block| {
                self.entry_offset = self.block_start + block.index * 12;
                if (try block.next(&self.validator)) |entry| {
                    self.entry_offset = self.block_start + (block.index - 1) * 12;
                    self.entries = std.math.add(usize, self.entries, 1) catch return error.IntegerOverflow;
                    return entry;
                }
                self.block = null;
            }
            if (self.offset == self.size) {
                const progress = try self.reader.read(self.buffer[0..0]);
                if (progress.output_written != 0 or progress.status != .done) return error.SizeMismatch;
                self.done = true;
                return null;
            }
            self.block_start = self.offset;
            self.entry_offset = self.offset;
            const size = @min(self.block_size, self.size - self.offset);
            var received: usize = 0;
            while (received < size) {
                const progress = try self.reader.read(self.buffer[received..size]);
                if (progress.output_written == 0) return error.TruncatedFrame;
                received += progress.output_written;
            }
            self.offset += size;
            self.block = try directory.Block.init(self.buffer[0..size]);
        }
    }
};

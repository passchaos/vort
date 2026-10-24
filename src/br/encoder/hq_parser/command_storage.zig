//! Command storage grows with the selected parse, rather than with the input's
//! worst-case command count. Every request uses the caller's budget allocator.
const std = @import("std");
pub const Command = @import("../command_plan.zig").Command;
pub const Error = std.mem.Allocator.Error || error{IntegerOverflow};
pub const initial_capacity: usize = 16;

/// A movable owner of a contiguous command sequence. The allocator context
/// must outlive the owner; no pointer refers to this Builder's own address.
pub const Builder = struct {
    allocator: std.mem.Allocator,
    storage: []Command = &.{},
    len: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Builder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Builder) void {
        self.allocator.free(self.storage);
        self.* = .{ .allocator = self.allocator };
    }

    /// Failure retains the exact prior contents, length and allocation. No
    /// candidate command is dropped or silently replaced to satisfy a budget.
    pub fn append(self: *Builder, command: Command) Error!void {
        const needed = std.math.add(usize, self.len, 1) catch return error.IntegerOverflow;
        if (needed > self.storage.len) try self.grow(needed);
        self.storage[self.len] = command;
        self.len = needed;
    }

    /// Views can be mutated for traceback reversal and bounded tail extension.
    /// They are invalidated by successful growth, finishOwned, or deinit.
    pub fn items(self: *const Builder) []Command {
        return self.storage[0..self.len];
    }

    /// `start` is an index in this builder, including the empty suffix at len.
    pub fn reverseSuffix(self: *Builder, start: usize) void {
        std.debug.assert(start <= self.len);
        std.mem.reverse(Command, self.items()[start..]);
    }

    pub fn capacity(self: *const Builder) usize {
        return self.storage.len;
    }

    pub fn allocatedBytes(self: *const Builder) usize {
        // Every capacity passed to the allocator was checked by bytesFor.
        return self.storage.len * @sizeOf(Command);
    }

    /// Transfer an exact-size allocation to Plan.command_storage. The returned
    /// slice must be freed with this allocator and its returned length. A failed
    /// shrink/copy retains the original builder and its full allocation.
    pub fn finishOwned(self: *Builder) Error![]Command {
        if (self.len == 0) {
            self.allocator.free(self.storage);
            self.storage = &.{};
            return &.{};
        }
        const owned = if (self.len == self.storage.len) self.storage else blk: {
            if (self.allocator.remap(self.storage, self.len)) |exact| break :blk exact;
            _ = try bytesFor(self.len);
            const exact = try self.allocator.alloc(Command, self.len);
            @memcpy(exact, self.items());
            self.allocator.free(self.storage);
            break :blk exact;
        };
        self.storage = &.{};
        self.len = 0;
        return owned;
    }

    fn grow(self: *Builder, needed: usize) Error!void {
        const doubled = std.math.mul(usize, self.storage.len, 2) catch needed;
        const new_capacity = @max(initial_capacity, @max(needed, doubled));
        _ = try bytesFor(new_capacity);
        if (self.storage.len != 0) {
            if (self.allocator.remap(self.storage, new_capacity)) |grown| {
                self.storage = grown;
                return;
            }
        }
        const grown = try self.allocator.alloc(Command, new_capacity);
        @memcpy(grown[0..self.len], self.items());
        self.allocator.free(self.storage);
        self.storage = grown;
    }
};

/// Checked size for resource preflight. Growth and exact final allocation use
/// this same byte conversion, without assuming a platform's Command layout.
pub fn bytesFor(capacity: usize) Error!usize {
    return std.math.mul(usize, capacity, @sizeOf(Command)) catch error.IntegerOverflow;
}

test {
    _ = @import("command_storage_tests.zig");
}

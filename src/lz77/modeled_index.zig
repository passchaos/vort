//! Compact immutable four-anchor predecessors for bounded modeled parsing.
const std = @import("std");

pub const empty = std.math.maxInt(u32);
pub const head_count = 1 << 15;

pub const Index = struct {
    head: std.ArrayList(u32) = .empty,
    previous: std.ArrayList(u32) = .empty,

    pub fn init(comptime Hash: type, allocator: std.mem.Allocator, input: []const u8) !Index {
        if (input.len > empty) return error.InvalidBlockPlan;
        var self: Index = .{};
        errdefer self.deinit(allocator);
        try self.head.resize(allocator, head_count);
        try self.previous.resize(allocator, input.len);
        @memset(self.head.items, empty);
        for (self.previous.items, 0..) |*predecessor, position| {
            const bucket = Hash.at(input, position, head_count) orelse {
                predecessor.* = empty;
                continue;
            };
            predecessor.* = self.head.items[bucket];
            self.head.items[bucket] = @intCast(position);
        }
        return self;
    }

    pub fn releaseHead(self: *Index, allocator: std.mem.Allocator) void {
        self.head.deinit(allocator);
        self.head = .empty;
    }

    pub fn deinit(self: *Index, allocator: std.mem.Allocator) void {
        self.head.deinit(allocator);
        self.previous.deinit(allocator);
        self.* = .{};
    }
};

//! Reusable fixed sync-flush workspace. Output and arena backing ownership are
//! independent; only actual arena node requests participate in the heap ledger.
const std = @import("std");
const total = @import("total_budget.zig");
const budget = @import("arena_budget.zig");

pub fn Encoder(comptime C: type) type {
    return struct {
        allocator: std.mem.Allocator,
        arena: std.heap.ArenaAllocator,
        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator, .arena = .init(allocator) };
        }
        pub fn deinit(self: *Self) void {
            self.arena.deinit();
            self.* = undefined;
        }
        pub fn encodeAppend(self: *Self, output: *std.ArrayList(u8), input: []const u8, options: C.CompressionOptions) budget.Error!usize {
            return self.encode(output, input, options, false);
        }
        pub fn encodeChunksAppend(self: *Self, output: *std.ArrayList(u8), chunks: []const []const u8, options: C.CompressionOptions) budget.Error!usize {
            try C.validateChunks(chunks);
            return self.encode(output, chunks, options, true);
        }
        fn encode(self: *Self, output: *std.ArrayList(u8), input: anytype, options: C.CompressionOptions, comptime chunks: bool) budget.Error!usize {
            const function = if (chunks) C.chunksAppend else C.append;
            if (!total.requested(options) and !budget.isTracked(self.allocator) and
                !budget.isTracked(self.arena.child_allocator))
            {
                _ = self.arena.reset(.retain_capacity);
                return function(self.arena.allocator(), self.allocator, output, input, options) catch |err| return @errorCast(err);
            }
            var operation = try budget.Operation.init(self.arena, self.allocator, output.capacity, options);
            operation.bind(&self.arena);
            defer operation.deinit(&self.arena);
            const start = output.items.len;
            errdefer output.shrinkRetainingCapacity(start);
            try operation.beforePublish();
            if (!self.arena.reset(.retain_capacity)) return operation.mapError(error.OutOfMemory);
            try operation.beforePublish();
            const written = function(self.arena.allocator(), operation.outputAllocator(), output, input, total.forward(options)) catch |err| return operation.mapError(err);
            try operation.beforePublish();
            return written;
        }
    };
}

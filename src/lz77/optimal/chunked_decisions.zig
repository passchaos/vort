//! Source-bound decisions stored as independently coded distance/length planes.
const std = @import("std");
const storage = @import("storage.zig");
const runs = @import("plane_runs.zig");
pub const default_chunk = 128 * 1024;

pub fn Store(comptime Token: type) type {
    return struct {
        const Self = @This();
        const Record = struct {
            distance: runs.Plane = .{},
            length: runs.Plane = .{},
            count: usize = 0,
        };
        input: []const u8,
        chunk: usize = default_chunk,
        records: std.ArrayList(Record) = .empty,
        distances: std.ArrayList(u16) = .empty,
        lengths: std.ArrayList(u8) = .empty,
        active: ?usize = null,
        reading: ?usize = null,
        sealed: bool = false,

        pub fn reserve(self: *Self, allocator: std.mem.Allocator, length: usize) !void {
            if (length != self.input.len or self.chunk == 0) return error.InvalidBlockPlan;
            std.debug.assert(self.records.items.len == 0);
            const count = length / self.chunk + @intFromBool(length % self.chunk != 0);
            try storage.resizeFresh(&self.records, allocator, count);
            @memset(self.records.items, .{});
            const scratch = @min(self.chunk, length);
            try storage.resizeFresh(&self.distances, allocator, scratch);
            try storage.resizeFresh(&self.lengths, allocator, scratch);
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            for (self.records.items) |record| {
                record.distance.deinit(allocator);
                record.length.deinit(allocator);
            }
            self.records.deinit(allocator);
            self.distances.deinit(allocator);
            self.lengths.deinit(allocator);
        }

        pub fn startChunk(self: *Self, allocator: std.mem.Allocator, position: usize) !usize {
            std.debug.assert(!self.sealed and position < self.input.len);
            const current = position / self.chunk;
            if (self.active != current) {
                if (self.active) |active| {
                    if (current + 1 != active) return error.InvalidBlockPlan;
                } else if (current + 1 != self.records.items.len) return error.InvalidBlockPlan;
                try self.sealActive(allocator);
                self.active = current;
            }
            return current * self.chunk;
        }

        pub inline fn set(self: *Self, position: usize, token: Token) void {
            self.writer().set(position, token);
        }

        pub fn writer(self: *Self) Writer {
            const base = self.active.? * self.chunk;
            return .{
                .distance_bias = @intFromPtr(self.distances.items.ptr) -% (base *% 2),
                .length_bias = @intFromPtr(self.lengths.items.ptr) -% base,
                .input = self.input,
                .base = base,
                .end = @min(self.input.len, base +| self.chunk),
            };
        }

        fn sealActive(self: *Self, allocator: std.mem.Allocator) !void {
            const active = self.active orelse return;
            const base = active * self.chunk;
            const count = @min(self.chunk, self.input.len - base);
            const distance = try runs.encode(u16, allocator, self.distances.items[0..count]);
            errdefer distance.deinit(allocator);
            const length = try runs.encode(u8, allocator, self.lengths.items[0..count]);
            self.records.items[active] = .{ .distance = distance, .length = length, .count = count };
        }

        pub fn finish(self: *Self, allocator: std.mem.Allocator) !void {
            if (self.sealed) return error.InvalidBlockPlan;
            if (self.records.items.len != 0 and self.active != 0) return error.InvalidBlockPlan;
            try self.sealActive(allocator);
            self.active = null;
            self.sealed = true;
        }

        pub fn get(self: *Self, position: usize) Token {
            std.debug.assert(self.sealed and position < self.input.len);
            const current = position / self.chunk;
            if (self.reading != current) {
                const record = self.records.items[current];
                runs.decode(u16, record.distance, self.distances.items[0..record.count]) catch unreachable;
                runs.decode(u8, record.length, self.lengths.items[0..record.count]) catch unreachable;
                self.reading = current;
            }
            const slot = position - current * self.chunk;
            const distance = self.distances.items[slot];
            return if (distance == 0) .{ .literal = self.input[position] } else .{
                .match = .{ .distance = distance, .length = @as(u16, self.lengths.items[slot]) + 3 },
            };
        }

        pub fn bytes(self: *const Self) usize {
            var total = self.records.items.len * @sizeOf(Record) + self.distances.items.len * 2 + self.lengths.items.len;
            for (self.records.items) |record| total += record.distance.bytes.len + record.length.bytes.len;
            return total;
        }

        pub const Writer = struct {
            distance_bias: usize,
            length_bias: usize,
            input: []const u8,
            base: usize,
            end: usize,

            pub inline fn set(self: Writer, position: usize, token: Token) void {
                std.debug.assert(position >= self.base and position < self.end);
                const distance: *u16 = @ptrFromInt(self.distance_bias +% (position *% 2));
                const length: *u8 = @ptrFromInt(self.length_bias +% position);
                switch (token) {
                    .literal => |value| {
                        std.debug.assert(value == self.input[position]);
                        distance.* = 0;
                        length.* = 0;
                    },
                    .match => |match| {
                        std.debug.assert(match.distance > 0 and match.length >= 3 and match.length <= 258);
                        distance.* = match.distance;
                        length.* = @intCast(match.length - 3);
                    },
                }
            }
        };
    };
}

test "optimal chunked decisions preserve every source-bound value and cross-chunk read" {
    const Token = union(enum) { literal: u8, match: struct { length: u16, distance: u16 } };
    var input: [4099]u8 = undefined;
    for (&input, 0..) |*value, i| value.* = @truncate(i *% 7919);
    inline for ([_]usize{ 1, 127, 128, 257, 1024 }) |chunk| {
        var stored: Store(Token) = .{ .input = &input, .chunk = chunk };
        defer stored.deinit(std.testing.allocator);
        try stored.reserve(std.testing.allocator, input.len);
        var pos = input.len;
        while (pos > 0) {
            pos -= 1;
            _ = try stored.startChunk(std.testing.allocator, pos);
            const token: Token = if (pos % 3 == 0) .{ .literal = input[pos] } else .{
                .match = .{ .length = @intCast(3 + pos % 256), .distance = @intCast(1 + pos * 17 % 65535) },
            };
            stored.set(pos, token);
        }
        try stored.finish(std.testing.allocator);
        // Include backwards reads after the forward reconstruction order.
        for (0..2) |direction| for (0..input.len) |i| {
            const position = if (direction == 0) i else input.len - i - 1;
            const expected: Token = if (position % 3 == 0) .{ .literal = input[position] } else .{
                .match = .{ .length = @intCast(3 + position % 256), .distance = @intCast(1 + position * 17 % 65535) },
            };
            try std.testing.expectEqualDeep(expected, stored.get(position));
        };
    }
}

test "optimal chunked decisions empty owners checked geometry and allocation failures" {
    const Token = union(enum) { literal: u8, match: struct { length: u16, distance: u16 } };
    var empty: Store(Token) = .{ .input = "" };
    defer empty.deinit(std.testing.allocator);
    try empty.reserve(std.testing.allocator, 0);
    try empty.finish(std.testing.allocator);
    try std.testing.expectError(error.InvalidBlockPlan, empty.finish(std.testing.allocator));
    var invalid: Store(Token) = .{ .input = "x", .chunk = 0 };
    try std.testing.expectError(error.InvalidBlockPlan, invalid.reserve(std.testing.allocator, 1));
    const Check = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var input: [2049]u8 = @splat(17);
            var stored: Store(Token) = .{ .input = &input, .chunk = 256 };
            defer stored.deinit(allocator);
            try stored.reserve(allocator, input.len);
            var pos = input.len;
            while (pos > 0) {
                pos -= 1;
                _ = try stored.startChunk(allocator, pos);
                stored.set(pos, .{ .literal = input[pos] });
            }
            try stored.finish(allocator);
            for (0..input.len) |i| try std.testing.expectEqualDeep(@as(Token, .{ .literal = 17 }), stored.get(i));
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Check.run, .{});
}

test "optimal chunked decisions reject skipped reverse chunks before sealing" {
    const Token = union(enum) { literal: u8, match: struct { length: u16, distance: u16 } };
    const input = "abcdefgh";
    var stored: Store(Token) = .{ .input = input, .chunk = 3 };
    defer stored.deinit(std.testing.allocator);
    try stored.reserve(std.testing.allocator, input.len);
    try std.testing.expectError(error.InvalidBlockPlan, stored.startChunk(std.testing.allocator, 0));
    _ = try stored.startChunk(std.testing.allocator, 7);
    stored.set(7, .{ .literal = input[7] });
    stored.set(6, .{ .literal = input[6] });
    try std.testing.expectError(error.InvalidBlockPlan, stored.startChunk(std.testing.allocator, 2));
    try std.testing.expectError(error.InvalidBlockPlan, stored.finish(std.testing.allocator));
    var pos: usize = 6;
    while (pos > 0) {
        pos -= 1;
        _ = try stored.startChunk(std.testing.allocator, pos);
        stored.set(pos, .{ .literal = input[pos] });
    }
    try stored.finish(std.testing.allocator);
    for (input, 0..) |byte, i| try std.testing.expectEqualDeep(@as(Token, .{ .literal = byte }), stored.get(i));
}

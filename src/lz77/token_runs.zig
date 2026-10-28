//! Source-bound literal runs expanded backwards into the existing token owner.
const std = @import("std");

pub fn Store(comptime Token: type) type {
    return struct {
        const Self = @This();
        input: []const u8,
        symbols: std.ArrayList(Token) = .empty,
        pending: u16 = 0,
        position: usize = 0,
        count: usize = 0,
        expanded: bool = false,

        pub fn init(allocator: std.mem.Allocator, input: []const u8) !Self {
            return .{ .input = input, .symbols = try std.ArrayList(Token).initCapacity(allocator, @min(input.len, 4096)) };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.symbols.deinit(allocator);
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.symbols.clearRetainingCapacity();
            self.pending = 0;
            self.position = 0;
            self.count = 0;
            self.expanded = false;
        }

        inline fn record(self: *Self, allocator: std.mem.Allocator, token: Token) !void {
            if (self.symbols.items.len < self.symbols.capacity) self.symbols.appendAssumeCapacity(token) else try self.symbols.append(allocator, token);
        }

        fn flush(self: *Self, allocator: std.mem.Allocator) !void {
            if (self.pending == 0) return;
            // Zero distance is private to this owner and marks a literal run.
            // Real matches retain all u16 distances and lengths 3..258.
            try self.record(allocator, .{ .match = .{ .distance = 0, .length = self.pending } });
            self.pending = 0;
        }

        pub inline fn append(self: *Self, allocator: std.mem.Allocator, token: Token) !void {
            std.debug.assert(!self.expanded);
            switch (token) {
                .literal => |value| {
                    std.debug.assert(self.position < self.input.len and value == self.input[self.position]);
                    if (self.pending == std.math.maxInt(u16)) try self.flush(allocator);
                    self.pending += 1;
                    self.position += 1;
                },
                .match => |match| {
                    std.debug.assert(match.distance > 0 and match.length >= 3 and match.length <= 258 and match.length <= self.input.len - self.position);
                    try self.flush(allocator);
                    try self.record(allocator, token);
                    self.position += match.length;
                },
            }
            self.count += 1;
        }

        pub fn toOwnedSlice(self: *Self, allocator: std.mem.Allocator) ![]Token {
            if (self.expanded or self.position != self.input.len) return error.InvalidBlockPlan;
            try self.flush(allocator);
            const symbols_len = self.symbols.items.len;
            try self.symbols.ensureTotalCapacityPrecise(allocator, self.count);
            self.expanded = true;
            self.symbols.items.len = self.count;
            var source = self.input.len;
            var write = self.count;
            var read = symbols_len;
            while (read > 0) {
                read -= 1;
                const symbol = self.symbols.items[read].match;
                if (symbol.distance == 0) {
                    var remaining: usize = symbol.length;
                    while (remaining > 0) : (remaining -= 1) {
                        write -= 1;
                        source -= 1;
                        std.debug.assert(write >= read);
                        self.symbols.items[write] = .{ .literal = self.input[source] };
                    }
                } else {
                    write -= 1;
                    source -= symbol.length;
                    std.debug.assert(write >= read);
                    self.symbols.items[write] = .{ .match = symbol };
                }
            }
            std.debug.assert(source == 0 and write == 0);
            return self.symbols.toOwnedSlice(allocator);
        }
    };
}

test "literal token runs preserve long runs matches boundaries and owned results" {
    const Token = union(enum) { literal: u8, match: struct { length: u16, distance: u16 } };
    const input = try std.testing.allocator.alloc(u8, 131071);
    defer std.testing.allocator.free(input);
    for (input, 0..) |*value, i| value.* = @truncate(i *% 7919);
    const Check = struct {
        fn run(allocator: std.mem.Allocator, source: []const u8) !void {
            var stored = try Store(Token).init(allocator, source);
            defer stored.deinit(allocator);
            var expected: std.ArrayList(Token) = .empty;
            defer expected.deinit(std.testing.allocator);
            var position: usize = 0;
            while (position < source.len) {
                const token: Token = if ((position % 1024 == 513 or position == 65536) and source.len - position >= 258)
                    .{ .match = .{ .distance = @intCast(@min(position, 65535)), .length = 258 } }
                else
                    .{ .literal = source[position] };
                try stored.append(allocator, token);
                try expected.append(std.testing.allocator, token);
                position += switch (token) {
                    .literal => 1,
                    .match => |match| match.length,
                };
            }
            const tokens = try stored.toOwnedSlice(allocator);
            defer allocator.free(tokens);
            try std.testing.expectEqualSlices(Token, expected.items, tokens);
        }
    };
    for ([_]usize{ 0, 1, 2, 259, 1025, 65534, 65535, 65536, 131071 }) |length| try Check.run(std.testing.allocator, input[0..length]);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Check.run, .{input[0..4099]});
    var literals = try Store(Token).init(std.testing.allocator, input);
    defer literals.deinit(std.testing.allocator);
    for (input) |value| try literals.append(std.testing.allocator, .{ .literal = value });
    const tokens = try literals.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(tokens);
    @memset(input, 0);
    try std.testing.expectEqual(@as(u8, @truncate(@as(usize, 7919))), tokens[1].literal);
    try std.testing.expectError(error.InvalidBlockPlan, literals.toOwnedSlice(std.testing.allocator));
    literals.clearRetainingCapacity();
    try std.testing.expectError(error.InvalidBlockPlan, literals.toOwnedSlice(std.testing.allocator));
}

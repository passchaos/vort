//! Lossless three-byte decisions for one-shot optimal reconstruction.
const std = @import("std");
const storage = @import("storage.zig");

pub fn Views(comptime Token: type) type {
    return struct {
        pub const Full = struct {
            values: *std.ArrayList(Token),

            pub fn reserve(self: *Full, allocator: std.mem.Allocator, length: usize) !void {
                try storage.resizeFresh(self.values, allocator, length);
            }

            pub inline fn set(self: *Full, position: usize, token: Token) void {
                self.values.items[position] = token;
            }

            pub inline fn get(self: *const Full, position: usize) Token {
                return self.values.items[position];
            }
        };

        pub const Compact = struct {
            // Distance zero marks a literal. All nonzero u16 distances fit,
            // and match lengths 3..258 fit in one byte after subtracting 3.
            // An array avoids the four-byte ABI size of Zig's u24.
            values: std.ArrayList([3]u8) = .empty,

            pub fn deinit(self: *Compact, allocator: std.mem.Allocator) void {
                self.values.deinit(allocator);
                self.* = .{};
            }

            pub fn reserve(self: *Compact, allocator: std.mem.Allocator, length: usize) !void {
                try storage.resizeFresh(&self.values, allocator, length);
            }

            pub inline fn set(self: *Compact, position: usize, token: Token) void {
                self.values.items[position] = switch (token) {
                    .literal => |value| .{ 0, 0, value },
                    .match => |match| init: {
                        std.debug.assert(match.distance != 0 and match.length >= 3 and match.length <= 258);
                        break :init .{ @truncate(match.distance), @intCast(match.distance >> 8), @intCast(match.length - 3) };
                    },
                };
            }

            pub inline fn get(self: *const Compact, position: usize) Token {
                const bytes = self.values.items[position];
                const distance = @as(u16, bytes[0]) | (@as(u16, bytes[1]) << 8);
                return if (distance == 0) .{ .literal = bytes[2] } else .{
                    .match = .{ .distance = distance, .length = @as(u16, bytes[2]) + 3 },
                };
            }
        };

        /// Observe every decoded DP choice, including unreachable positions.
        pub const Audited = struct {
            compact: Compact = .{},
            observed: Full,

            pub fn deinit(self: *Audited, allocator: std.mem.Allocator) void {
                self.compact.deinit(allocator);
            }

            pub fn reserve(self: *Audited, allocator: std.mem.Allocator, length: usize) !void {
                try self.compact.reserve(allocator, length);
                try self.observed.reserve(allocator, length);
            }

            pub inline fn set(self: *Audited, position: usize, token: Token) void {
                self.compact.set(position, token);
                self.observed.set(position, self.compact.get(position));
            }

            pub inline fn get(self: *const Audited, position: usize) Token {
                return self.compact.get(position);
            }
        };
    };
}

test "optimal compact decisions preserve every literal length and distance" {
    const Token = union(enum) { literal: u8, match: struct { length: u16, distance: u16 } };
    var compact: Views(Token).Compact = .{};
    defer compact.deinit(std.testing.allocator);
    try compact.reserve(std.testing.allocator, 1);
    try std.testing.expectEqual(@as(usize, 3), @sizeOf(@TypeOf(compact.values.items[0])));
    for (0..256) |value| {
        const token: Token = .{ .literal = @intCast(value) };
        compact.set(0, token);
        try std.testing.expectEqualDeep(token, compact.get(0));
    }
    for (3..259) |length| {
        for (1..65536) |distance| {
            const token: Token = .{ .match = .{ .length = @intCast(length), .distance = @intCast(distance) } };
            compact.set(0, token);
            try std.testing.expectEqualDeep(token, compact.get(0));
        }
    }
}

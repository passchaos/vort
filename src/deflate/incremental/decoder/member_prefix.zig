//! Bounded recognition of a subsequent wrapper member. At most one byte is
//! accepted speculatively; a rejected current suffix stays with the caller.
const std = @import("std");

pub const Kind = enum { zlib, gzip };
pub const Decision = enum { need_input, member, trailing };
pub const Result = struct { accepted: usize = 0, decision: Decision };

pub fn recognizes(kind: Kind, input: []const u8) bool {
    if (input.len < 2) return false;
    return switch (kind) {
        .zlib => plausibleFirst(.zlib, input[0]) and
            ((@as(u16, input[0]) << 8) | input[1]) % 31 == 0,
        .gzip => input[0] == 0x1f and input[1] == 0x8b,
    };
}

fn plausibleFirst(kind: Kind, byte: u8) bool {
    return switch (kind) {
        .zlib => byte & 0x0f == 8 and byte >> 4 <= 7,
        .gzip => byte == 0x1f,
    };
}

pub const Prefix = struct {
    bytes: [2]u8 = undefined,
    received: u2 = 0,

    pub fn init() Prefix {
        return .{};
    }

    pub fn reset(self: *Prefix) void {
        self.received = 0;
    }

    pub fn probe(self: *Prefix, kind: Kind, input: []const u8) Result {
        if (self.received == 2) return .{ .decision = .member };
        if (input.len == 0) return .{ .decision = .need_input };
        if (self.received == 1) {
            const pair = [_]u8{ self.bytes[0], input[0] };
            if (!recognizes(kind, &pair)) return .{ .decision = .trailing };
            self.bytes = pair;
            self.received = 2;
            return .{ .accepted = 1, .decision = .member };
        }
        if (!plausibleFirst(kind, input[0])) return .{ .decision = .trailing };
        if (input.len >= 2) {
            if (!recognizes(kind, input)) return .{ .decision = .trailing };
            @memcpy(&self.bytes, input[0..2]);
            self.received = 2;
            return .{ .accepted = 2, .decision = .member };
        }
        self.bytes[0] = input[0];
        self.received = 1;
        return .{ .accepted = 1, .decision = .need_input };
    }
};

test "wrapper member prefix agrees with complete zlib header recognition" {
    for (0..256) |first| {
        for (0..256) |second| {
            const pair = [_]u8{ @intCast(first), @intCast(second) };
            const expected = first & 15 == 8 and first >> 4 <= 7 and
                (first * 256 + second) % 31 == 0;
            try std.testing.expectEqual(expected, recognizes(.zlib, &pair));
        }
    }
}

test "wrapper member prefix preserves rejected current suffix and accepted previous byte" {
    var prefix = Prefix.init();
    try std.testing.expectEqual(Decision.trailing, prefix.probe(.gzip, "tail").decision);
    try std.testing.expectEqual(@as(u2, 0), prefix.received);
    const first = prefix.probe(.gzip, &.{0x1f});
    try std.testing.expectEqual(@as(usize, 1), first.accepted);
    try std.testing.expectEqual(Decision.need_input, first.decision);
    const rejected = prefix.probe(.gzip, &.{ 0, 1, 2 });
    try std.testing.expectEqual(@as(usize, 0), rejected.accepted);
    try std.testing.expectEqual(Decision.trailing, rejected.decision);
    try std.testing.expectEqual(@as(u2, 1), prefix.received);
    try std.testing.expectEqual(@as(u8, 0x1f), prefix.bytes[0]);
    prefix.reset();
    _ = prefix.probe(.zlib, &.{0x78});
    const accepted = prefix.probe(.zlib, &.{ 0x01, 0, 0 });
    try std.testing.expectEqual(@as(usize, 1), accepted.accepted);
    try std.testing.expectEqual(Decision.member, accepted.decision);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x01 }, &prefix.bytes);
}

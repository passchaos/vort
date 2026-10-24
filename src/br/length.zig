const std = @import("std");

pub const Spec = struct {
    base: usize,
    extra_bits: u5,
};

pub fn insertSpec(code: u16) Spec {
    return switch (code) {
        0...5 => .{ .base = code, .extra_bits = 0 },
        6...7 => .{ .base = 6 + (@as(usize, code - 6) << 1), .extra_bits = 1 },
        8...9 => .{ .base = 10 + (@as(usize, code - 8) << 2), .extra_bits = 2 },
        10...11 => .{ .base = 18 + (@as(usize, code - 10) << 3), .extra_bits = 3 },
        12...13 => .{ .base = 34 + (@as(usize, code - 12) << 4), .extra_bits = 4 },
        14...15 => .{ .base = 66 + (@as(usize, code - 14) << 5), .extra_bits = 5 },
        16 => .{ .base = 130, .extra_bits = 6 },
        17 => .{ .base = 194, .extra_bits = 7 },
        18 => .{ .base = 322, .extra_bits = 8 },
        19 => .{ .base = 578, .extra_bits = 9 },
        20 => .{ .base = 1090, .extra_bits = 10 },
        21 => .{ .base = 2114, .extra_bits = 12 },
        22 => .{ .base = 6210, .extra_bits = 14 },
        23 => .{ .base = 22594, .extra_bits = 24 },
        else => unreachable,
    };
}

pub fn copySpec(code: u16) Spec {
    return switch (code) {
        0...7 => .{ .base = 2 + code, .extra_bits = 0 },
        8...9 => .{ .base = 10 + (@as(usize, code - 8) << 1), .extra_bits = 1 },
        10...11 => .{ .base = 14 + (@as(usize, code - 10) << 2), .extra_bits = 2 },
        12...13 => .{ .base = 22 + (@as(usize, code - 12) << 3), .extra_bits = 3 },
        14...15 => .{ .base = 38 + (@as(usize, code - 14) << 4), .extra_bits = 4 },
        16 => .{ .base = 70, .extra_bits = 5 },
        17 => .{ .base = 102, .extra_bits = 5 },
        18 => .{ .base = 134, .extra_bits = 6 },
        19 => .{ .base = 198, .extra_bits = 7 },
        20 => .{ .base = 326, .extra_bits = 8 },
        21 => .{ .base = 582, .extra_bits = 9 },
        22 => .{ .base = 1094, .extra_bits = 10 },
        23 => .{ .base = 2118, .extra_bits = 24 },
        else => unreachable,
    };
}

pub fn codeForValue(value: usize, comptime insert: bool) ?u5 {
    if (comptime insert) return switch (value) {
        0...5 => @intCast(value),
        6...9 => @intCast(6 + ((value - 6) >> 1)),
        10...17 => @intCast(8 + ((value - 10) >> 2)),
        18...33 => @intCast(10 + ((value - 18) >> 3)),
        34...65 => @intCast(12 + ((value - 34) >> 4)),
        66...129 => @intCast(14 + ((value - 66) >> 5)),
        130...193 => 16,
        194...321 => 17,
        322...577 => 18,
        578...1089 => 19,
        1090...2113 => 20,
        2114...6209 => 21,
        6210...22593 => 22,
        22594...16_799_809 => 23,
        else => null,
    };
    return switch (value) {
        2...9 => @intCast(value - 2),
        10...13 => @intCast(8 + ((value - 10) >> 1)),
        14...21 => @intCast(10 + ((value - 14) >> 2)),
        22...37 => @intCast(12 + ((value - 22) >> 3)),
        38...69 => @intCast(14 + ((value - 38) >> 4)),
        70...101 => 16,
        102...133 => 17,
        134...197 => 18,
        198...325 => 19,
        326...581 => 20,
        582...1093 => 21,
        1094...2117 => 22,
        2118...16_779_333 => 23,
        else => null,
    };
}

test "length codes cover every insert and copy range" {
    inline for (.{ true, false }) |insert| {
        var code: u5 = 0;
        while (code < 24) : (code += 1) {
            const spec = if (insert) insertSpec(code) else copySpec(code);
            const last = spec.base + ((@as(usize, 1) << spec.extra_bits) - 1);
            try std.testing.expectEqual(@as(?u5, code), codeForValue(spec.base, insert));
            try std.testing.expectEqual(@as(?u5, code), codeForValue(last, insert));
        }
    }
    try std.testing.expectEqual(@as(?u5, null), codeForValue(1, false));
    try std.testing.expectEqual(@as(?u5, null), codeForValue(16_799_810, true));
    try std.testing.expectEqual(@as(?u5, null), codeForValue(16_779_334, false));
}

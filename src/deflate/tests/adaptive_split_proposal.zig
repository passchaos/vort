const std = @import("std");

pub fn contracts(comptime C: type) !void {
    try observationClasses(C);
    try homogeneous(C);
    try literalDrift(C);
    try tokenBoundary(C);
    try midpointTokenBoundary(C);
    try repeatedDrift(C);
    try arithmetic(C);
}

fn midpointTokenBoundary(comptime C: type) !void {
    var tokens: [1537]C.Token = undefined;
    for (tokens[0..1024]) |*token| token.* = .{ .literal = 0x00 };
    for (tokens[1024..1535]) |*token|
        token.* = .{ .match = .{ .length = 17, .distance = 1 } };
    tokens[1535] = .{ .match = .{ .length = 16, .distance = 1 } };
    tokens[1536] = .{ .literal = 0xe1 };

    // The byte midpoint is 5375, inside a 17-byte match. The proposer must
    // move it to the nearest complete token boundary.
    const proposals = try C.proposeMany(&tokens, 9728, 1, 2);
    try std.testing.expectEqualSlices(usize, &.{5376}, proposals.slice());
}

fn observationClasses(comptime C: type) !void {
    try std.testing.expectEqual(@as(usize, 0), C.class(.{ .literal = 0x00 }));
    try std.testing.expectEqual(@as(usize, 1), C.class(.{ .literal = 0x01 }));
    try std.testing.expectEqual(@as(usize, 6), C.class(.{ .literal = 0xe0 }));
    try std.testing.expectEqual(@as(usize, 7), C.class(.{ .literal = 0xe1 }));
    try std.testing.expectEqual(@as(usize, 8), C.class(.{ .match = .{ .length = 8, .distance = 1 } }));
    try std.testing.expectEqual(@as(usize, 9), C.class(.{ .match = .{ .length = 9, .distance = 1 } }));
}

fn homogeneous(comptime C: type) !void {
    var tokens: [1536]C.Token = undefined;
    for (&tokens) |*token| token.* = .{ .literal = 'a' };
    try std.testing.expectEqual(
        @as(?usize, null),
        try C.propose(&tokens, tokens.len, 1),
    );
}

fn literalDrift(comptime C: type) !void {
    var tokens: [1537]C.Token = undefined;
    for (tokens[0..1024]) |*token| token.* = .{ .literal = 0x00 };
    for (tokens[1024..]) |*token| token.* = .{ .literal = 0xe1 };
    try std.testing.expectEqual(
        @as(?usize, 1024),
        try C.propose(&tokens, tokens.len, 1),
    );

    try std.testing.expectEqual(
        @as(?usize, null),
        try C.propose(&tokens, tokens.len, 769),
    );
}

fn tokenBoundary(comptime C: type) !void {
    var tokens: [1537]C.Token = undefined;
    for (tokens[0..1024]) |*token| token.* = .{ .literal = 0x00 };
    for (tokens[1024..1535]) |*token| token.* = .{ .literal = 0xe1 };
    tokens[1535] = .{ .match = .{ .length = 17, .distance = 1 } };
    tokens[1536] = .{ .literal = 0xe1 };
    try std.testing.expectEqual(
        @as(?usize, 1024),
        try C.propose(&tokens, 1553, 1),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        C.propose(&tokens, 1552, 1),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        C.propose(&tokens, std.math.maxInt(u16) + 1, 1),
    );
}

fn repeatedDrift(comptime C: type) !void {
    var tokens: [2561]C.Token = undefined;
    for (tokens[0..1024]) |*token| token.* = .{ .literal = 0x00 };
    for (tokens[1024..1536]) |*token| token.* = .{ .literal = 0xe1 };
    for (tokens[1536..2048]) |*token| token.* = .{ .literal = 0x00 };
    for (tokens[2048..]) |*token| token.* = .{ .literal = 0xe1 };
    const proposals = try C.proposeMany(&tokens, tokens.len, 1, 4);
    try std.testing.expectEqualSlices(
        usize,
        &.{ 1280, 1792, 2304 },
        proposals.slice(),
    );
    const two = try C.proposeMany(&tokens, tokens.len, 1, 2);
    try std.testing.expectEqualSlices(usize, &.{ 1280, 1792 }, two.slice());
}

fn arithmetic(comptime C: type) !void {
    var old: [10]u32 = @splat(0);
    var new: [10]u32 = @splat(0);
    old[0] = 512;
    new[0] = 312;
    new[1] = 200;
    try std.testing.expect(C.changed(old, 512, new, 512, 16_384));

    new = @splat(0);
    new[0] = 414;
    new[1] = 98;
    try std.testing.expect(C.changed(old, 512, new, 512, 16_384));
    new[0] = 415;
    new[1] = 97;
    try std.testing.expect(!C.changed(old, 512, new, 512, 16_384));
    new[0] = 412;
    new[1] = 100;
    try std.testing.expect(!C.changed(old, 512, new, 512, 4096));

    old = @splat(0);
    new = @splat(0);
    old[0] = std.math.maxInt(u32);
    new[1] = std.math.maxInt(u32);
    try std.testing.expect(C.changed(
        old,
        std.math.maxInt(u32),
        new,
        std.math.maxInt(u32),
        std.math.maxInt(usize),
    ));
}

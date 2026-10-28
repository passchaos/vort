//! Public one-shot ownership under a finite allocator budget.
const std = @import("std");

pub fn verify(comptime Options: type, comptime allocate: anytype) !void {
    var input: [32768]u8 = undefined;
    for (&input, 0..) |*byte, pos| byte.* = @truncate(pos *% 37);
    const memory = try std.testing.allocator.alloc(u8, 768 * 1024);
    defer std.testing.allocator.free(memory);
    var fixed = std.heap.FixedBufferAllocator.init(memory);
    // A zero search budget requires one owned literal per input byte. This
    // exercises the largest token result rather than an easy repeated match.
    const options: Options = .{ .max_chain = 0 };
    {
        const plan = try allocate(fixed.allocator(), &input, options);
        defer plan.deinit(fixed.allocator());
        try std.testing.expectEqual(input.len, plan.stats.literals);
        try std.testing.expectEqual(@as(usize, 0), plan.stats.matches);
        try std.testing.expectEqual(input.len, plan.tokens.len);
        for (plan.tokens, input) |token, byte| try std.testing.expectEqual(byte, token.literal);
    }

    var insufficient = std.heap.FixedBufferAllocator.init(memory[0 .. 128 * 1024]);
    try std.testing.expectError(error.OutOfMemory, allocate(insufficient.allocator(), &input, options));
}

pub fn chunked(comptime Options: type, comptime allocate: anytype) !void {
    const input = try std.testing.allocator.alloc(u8, 2 * 1024 * 1024);
    defer std.testing.allocator.free(input);
    @memset(input, 0);
    input[0] = 17;
    input[input.len - 1] = 19;
    const memory = try std.testing.allocator.alloc(u8, 2 * 1024 * 1024);
    defer std.testing.allocator.free(memory);
    var fixed = std.heap.FixedBufferAllocator.init(memory);
    // The old decision array alone needs 6 MiB. This budget covers the
    // bounded index, coded decisions and the complete owned token result.
    const options: Options = .{ .min_match = 5, .max_chain = 1, .max_candidates = 1 };
    const plan = try allocate(fixed.allocator(), input, options);
    defer plan.deinit(fixed.allocator());
    try std.testing.expectEqual(input.len, plan.stats.literals + plan.stats.matched_bytes);
    try std.testing.expect(plan.stats.matches > 0);
    var position: usize = 0;
    for (plan.tokens) |token| switch (token) {
        .literal => |value| {
            try std.testing.expectEqual(input[position], value);
            position += 1;
        },
        .match => |match| {
            try std.testing.expect(match.distance > 0 and match.distance <= position);
            try std.testing.expect(match.length >= 5 and match.length <= input.len - position);
            for (0..match.length) |offset| try std.testing.expectEqual(input[position + offset - match.distance], input[position + offset]);
            position += match.length;
        },
    };
    try std.testing.expectEqual(input.len, position);
    @memset(input, 255);
    try std.testing.expectEqual(@as(u8, 17), plan.tokens[0].literal);
    try std.testing.expectEqual(@as(u8, 19), plan.tokens[plan.tokens.len - 1].literal);

    var insufficient = std.heap.FixedBufferAllocator.init(memory[0 .. 128 * 1024]);
    try std.testing.expectError(error.OutOfMemory, allocate(insufficient.allocator(), input, options));
}

pub fn literalRuns(comptime Options: type, comptime allocate: anytype) !void {
    const input = try std.testing.allocator.alloc(u8, 1024 * 1024);
    defer std.testing.allocator.free(input);
    @memset(input, 17);
    const memory = try std.testing.allocator.alloc(u8, 15 * 512 * 1024);
    defer std.testing.allocator.free(memory);
    var fixed = std.heap.FixedBufferAllocator.init(memory);
    const plan = try allocate(fixed.allocator(), input, @as(Options, .{ .max_chain = 0 }));
    defer plan.deinit(fixed.allocator());
    try std.testing.expectEqual(input.len, plan.tokens.len);
    try std.testing.expectEqual(input.len, plan.stats.literals);
    try std.testing.expectEqual(@as(usize, 0), plan.stats.matches);
    for (plan.tokens) |token| try std.testing.expectEqual(@as(u8, 17), token.literal);
    @memset(input, 0);
    try std.testing.expectEqual(@as(u8, 17), plan.tokens[0].literal);
    try std.testing.expectEqual(@as(u8, 17), plan.tokens[plan.tokens.len - 1].literal);
}

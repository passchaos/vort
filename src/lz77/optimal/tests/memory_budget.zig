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

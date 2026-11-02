const std = @import("std");

pub fn check(comptime Command: type, comptime analyze: anytype) !void {
    const allocator = std.testing.allocator;
    var input: [256]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @truncate(index);
    const saved_input = input;
    var commands: [259]Command = undefined;
    for (0..130) |length| {
        for ([_]bool{ false, true }) |fragmented| {
            var used: usize = 0;
            if (fragmented) {
                for (0..length) |position| {
                    commands[used] = .{ .insert_start = position, .insert_len = 0 };
                    commands[used + 1] = .{ .insert_start = position, .insert_len = 1 };
                    used += 2;
                }
            } else {
                commands[0] = .{ .insert_start = 0, .insert_len = length };
                used = 1;
            }
            commands[used] = .{ .insert_start = input.len, .insert_len = 0 };
            used += 1;
            const saved_commands = commands;
            var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
            const result = analyze(failing.allocator(), &input, commands[0..used]);
            if (length < 128) {
                try std.testing.expectEqual(@as(@typeInfo(@TypeOf(result)).error_union.payload, null), try result);
                try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
                try std.testing.expect(!failing.has_induced_failure);
            } else {
                try std.testing.expectError(error.OutOfMemory, result);
                try std.testing.expect(failing.has_induced_failure);
            }
            const full = try analyze(allocator, &input, commands[0..used]);
            if (full) |analysis| {
                defer allocator.destroy(analysis);
                try std.testing.expectEqual(length, analysis.literal_count);
                for (analysis.total, 0..) |frequency, symbol|
                    try std.testing.expectEqual(@as(u32, @intFromBool(symbol < length)), frequency);
            } else try std.testing.expect(length < 128);
            try std.testing.expectEqualSlices(u8, &saved_input, &input);
            try std.testing.expectEqualDeep(saved_commands[0..used], commands[0..used]);
            try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
        }
    }
    // Invalid large spans retain the original checked rejection after the
    // eligibility gate, without indexing the caller's input.
    const invalid = [_]Command{.{ .insert_start = 200, .insert_len = 129 }};
    try std.testing.expectEqual(@as(@typeInfo(@TypeOf(analyze(allocator, &input, &invalid))).error_union.payload, null), try analyze(allocator, &input, &invalid));
}

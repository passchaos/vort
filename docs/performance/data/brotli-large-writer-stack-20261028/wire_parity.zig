const std = @import("std");
const baseline = @import("baseline");
const candidate = @import("candidate");

test "Brotli structural writer HEAD wire parity" {
    const allocator = std.testing.allocator;
    var random: [64]u8 = undefined;
    var state: u64 = 0x4098;
    for (&random) |*byte| {
        state = state *% 6364136223846793005 +% 1442695040888963407;
        byte.* = @truncate(state >> 32);
    }
    var cases: usize = 0;
    for ([_][]const u8{ "abcdefgh" ** 6, &random }) |input| {
        for ([_]u4{ 10, 11 }) |quality| {
            for (0..8) |flags| {
                const large = flags & 1 != 0;
                const whole = flags & 2 != 0;
                const complete = flags & 4 != 0;
                const expected = try baseline.encodePlannedStreamWithOptionsAlloc(allocator, input, .{
                    .quality = quality,
                    .window_bits = if (large) 25 else 16,
                    .large_window = large,
                    .hq = .{ .block_len = input.len, .beam_width = 1, .search_depth = 1, .iterations = 1,
                        .parse_mode = if (whole) .whole_block else .bounded,
                        .copy_lengths = if (complete) .complete else .sampled },
                });
                defer allocator.free(expected);
                const actual = try candidate.encodePlannedStreamWithOptionsAlloc(allocator, input, .{
                    .quality = quality,
                    .window_bits = if (large) 25 else 16,
                    .large_window = large,
                    .hq = .{ .block_len = input.len, .beam_width = 1, .search_depth = 1, .iterations = 1,
                        .parse_mode = if (whole) .whole_block else .bounded,
                        .copy_lengths = if (complete) .complete else .sampled },
                });
                defer allocator.free(actual);
                try std.testing.expectEqualSlices(u8, expected, actual);
                cases += 1;
            }
        }
    }
    std.debug.print("HEAD wire parity: {d} cases\n", .{cases});
}

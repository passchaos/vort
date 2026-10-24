const std = @import("std");
const br = @import("../../../br.zig");
const h = @import("../../../tests/br_hq_helpers.zig");
const allocator = std.testing.allocator;

test "Brotli HQ whole block public actual wire keeps complete bounded and corresponding q10 guards" {
    const input = try h.boundaryInput(allocator);
    defer allocator.free(input);
    for ([_]bool{ false, true }) |large| {
        var whole_lengths: [2]usize = undefined;
        for ([_]u4{ 10, 11 }, 0..) |quality, index| {
            var bounded_profile: br.HqProfile = .{};
            var options: br.PlannedEncodeOptions = .{
                .quality = quality,
                .window_bits = if (large) 30 else 16,
                .large_window = large,
                .metadata = "whole block arbitration",
                .hq = .{ .beam_width = 2, .search_depth = 2, .nice_len = 32, .block_len = 8192, .profile = &bounded_profile },
            };
            const bounded = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, options);
            defer allocator.free(bounded);
            var whole_profile: br.HqProfile = .{};
            options.hq.?.parse_mode = .whole_block;
            options.hq.?.profile = &whole_profile;
            const whole = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, options);
            defer allocator.free(whole);
            try std.testing.expect(whole.len <= bounded.len);
            try std.testing.expect(whole_profile.whole_block_passes > 0);
            try std.testing.expect(whole_profile.bounded_passes > 0);
            try std.testing.expect(whole_profile.max_parse_positions >= input.len);
            try std.testing.expectEqual(.whole_block, whole_profile.effective.?.parse_mode);
            try std.testing.expectEqual(quality, whole_profile.effective.?.quality);
            if (std.mem.eql(u8, bounded, whole))
                try std.testing.expectEqualDeep(bounded_profile.emitted(), whole_profile.emitted());
            const decoded = try br.decodeStreamAllocWithOptions(allocator, whole, .{ .allow_large_window = large });
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, input, decoded);
            whole_lengths[index] = whole.len;
        }
        try std.testing.expect(whole_lengths[1] <= whole_lengths[0]);
    }
}

test "Brotli HQ whole block workspace failure never returns the completed bounded candidate" {
    const input = try h.boundaryInput(allocator);
    defer allocator.free(input);
    var bounded_profile: br.HqProfile = .{};
    var options: br.PlannedEncodeOptions = .{
        .quality = 10,
        .hq = .{ .beam_width = 2, .search_depth = 2, .nice_len = 32, .block_len = 8192, .profile = &bounded_profile },
    };
    const bounded = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, options);
    defer allocator.free(bounded);
    var whole_profile: br.HqProfile = .{};
    options.hq.?.parse_mode = .whole_block;
    options.hq.?.profile = &whole_profile;
    options.hq.?.max_working_memory = bounded_profile.peak_working_memory;
    var output: [8192]u8 = @splat(0xa5);
    const before = whole_profile.emitted();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamWithOptionsInto(input, &output, options));
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqualDeep(before, whole_profile.emitted());
    try std.testing.expectEqual(.whole_block, whole_profile.effective.?.parse_mode);
}

test "Brotli HQ whole block total quota charges complete candidates and preserves publication on failure" {
    const input = h.legacy_plain[0..193];
    var profile: br.HqProfile = .{};
    var memory: br.EncodeMemoryProfile = .{};
    var options: br.PlannedEncodeOptions = .{
        .quality = 11,
        .memory_profile = &memory,
        .hq = .{ .parse_mode = .whole_block, .beam_width = 1, .iterations = 1, .search_depth = 1, .profile = &profile },
    };
    const baseline = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, options);
    defer allocator.free(baseline);
    const peak = memory.peak_requested_bytes;
    try std.testing.expect(peak > 0);
    try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
    options.max_total_working_memory = peak;
    profile.reset();
    const exact = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, options);
    defer allocator.free(exact);
    try std.testing.expectEqualSlices(u8, baseline, exact);
    try std.testing.expectEqual(peak, memory.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
    options.max_total_working_memory = peak - 1;
    profile.reset();
    const before = profile.emitted();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamWithOptionsAlloc(allocator, input, options));
    try std.testing.expectEqualDeep(before, profile.emitted());
    try std.testing.expectEqual(.whole_block, profile.effective.?.parse_mode);
    try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
}

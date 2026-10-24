const std = @import("std");
const br = @import("../../../br.zig");
const options_mod = @import("../hq_options.zig");
const allocator = std.testing.allocator;

test "Brotli HQ complete lengths actual public wire preserves matching sampled and q10 complete frames" {
    const input = "abcdefgh" ** 12 ++ "abcxyz";
    for ([_]options_mod.ParseMode{ .bounded, .whole_block }) |mode| {
        for ([_]bool{ false, true }) |large| {
            var lengths: [2]usize = undefined;
            for ([_]u4{ 10, 11 }, 0..) |quality, index| {
                var sampled_profile: br.HqProfile = .{};
                var options: br.PlannedEncodeOptions = .{
                    .quality = quality,
                    .window_bits = 16,
                    .large_window = large,
                    .metadata = "complete length arbitration",
                    .hq = .{ .parse_mode = mode, .beam_width = 1, .iterations = 1, .search_depth = 2, .nice_len = 32, .block_len = 128, .profile = &sampled_profile },
                };
                const sampled = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, options);
                defer allocator.free(sampled);
                var profile: br.HqProfile = .{};
                options.hq.?.copy_lengths = .complete;
                options.hq.?.profile = &profile;
                const complete = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, options);
                defer allocator.free(complete);
                try std.testing.expect(complete.len <= sampled.len);
                try std.testing.expect(profile.complete_length_passes > 0);
                try std.testing.expect(profile.sampled_length_passes > 0);
                try std.testing.expect(profile.max_copy_length_considered > 64);
                try std.testing.expectEqual(.complete, profile.effective.?.copy_lengths);
                try std.testing.expectEqual(mode, profile.effective.?.parse_mode);
                try std.testing.expectEqual(quality, profile.effective.?.quality);
                if (std.mem.eql(u8, sampled, complete))
                    try std.testing.expectEqualDeep(sampled_profile.emitted(), profile.emitted());
                const decoded = try br.decodeStreamAllocWithOptions(allocator, complete, .{ .allow_large_window = large });
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, input, decoded);
                lengths[index] = complete.len;
            }
            try std.testing.expect(lengths[1] <= lengths[0]);
        }
    }
}

test "Brotli HQ complete lengths exact per plan search cap succeeds and zero or one below preserves caller output" {
    for ([_]options_mod.ParseMode{ .bounded, .whole_block }) |mode| {
        try sampledGuardCannotMaskCompleteLimit(mode);
        var profile: br.HqProfile = .{};
        var memory: br.EncodeMemoryProfile = .{};
        var options: br.PlannedEncodeOptions = .{
            .quality = 10,
            .window_bits = 16,
            .memory_profile = &memory,
            .hq = .{ .parse_mode = mode, .copy_lengths = .complete, .beam_width = 1, .iterations = 1, .search_depth = 1, .nice_len = 32, .block_len = 128, .profile = &profile },
        };
        const unlimited = try br.encodePlannedStreamWithOptionsAlloc(allocator, "xxx", options);
        defer allocator.free(unlimited);
        const evaluations = profile.max_plan_price_evaluations;
        try std.testing.expect(evaluations > 0);
        options.hq.?.max_price_evaluations = evaluations;
        profile.reset();
        const exact = try br.encodePlannedStreamWithOptionsAlloc(allocator, "xxx", options);
        defer allocator.free(exact);
        try std.testing.expectEqualSlices(u8, unlimited, exact);
        try std.testing.expectEqual(evaluations, profile.max_plan_price_evaluations);
        // The cap applies independently to each guard/refinement plan.
        try std.testing.expect(profile.price_evaluations > evaluations);
        try std.testing.expect(profile.complete_length_passes > 0);
        try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
        for ([_]u64{ evaluations - 1, 0 }) |cap| {
            options.hq.?.max_price_evaluations = cap;
            profile.reset();
            const before = profile.emitted();
            var output: [32]u8 = @splat(0xa5);
            try std.testing.expectError(error.SearchLimitExceeded, br.encodePlannedStreamWithOptionsInto("xxx", &output, options));
            for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
            try std.testing.expectEqualDeep(before, profile.emitted());
            try std.testing.expectEqual(.complete, profile.effective.?.copy_lengths);
            try std.testing.expectEqual(mode, profile.effective.?.parse_mode);
            try std.testing.expectEqual(@as(?u64, cap), profile.effective.?.max_price_evaluations);
            try std.testing.expect(profile.max_plan_price_evaluations <= cap);
            try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
        }
    }
}

fn sampledGuardCannotMaskCompleteLimit(mode: options_mod.ParseMode) !void {
    const input = "abcdefgh" ** 9;
    var profile: br.HqProfile = .{};
    var memory: br.EncodeMemoryProfile = .{};
    var options: br.PlannedEncodeOptions = .{
        .quality = 10,
        .window_bits = 16,
        .memory_profile = &memory,
        .hq = .{ .parse_mode = mode, .beam_width = 1, .iterations = 1, .search_depth = 1, .nice_len = 32, .block_len = 128, .profile = &profile },
    };
    const sampled = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, options);
    defer allocator.free(sampled);
    const sampled_cap = profile.max_plan_price_evaluations;
    try std.testing.expect(sampled_cap > 0);
    options.hq.?.max_price_evaluations = sampled_cap;
    profile.reset();
    const admitted = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, options);
    defer allocator.free(admitted);
    try std.testing.expectEqualSlices(u8, sampled, admitted);
    options.hq.?.copy_lengths = .complete;
    options.hq.?.max_price_evaluations = null;
    profile.reset();
    const complete = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, options);
    defer allocator.free(complete);
    try std.testing.expect(profile.max_plan_price_evaluations > sampled_cap);
    options.hq.?.max_price_evaluations = sampled_cap;
    profile.reset();
    const before = profile.emitted();
    var output: [128]u8 = @splat(0xa5);
    try std.testing.expectError(error.SearchLimitExceeded, br.encodePlannedStreamWithOptionsInto(input, &output, options));
    try std.testing.expect(profile.complete_length_passes > 0);
    try std.testing.expect(profile.max_plan_price_evaluations <= sampled_cap);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqualDeep(before, profile.emitted());
    try std.testing.expectEqual(.complete, profile.effective.?.copy_lengths);
    try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
}

test "Brotli HQ complete lengths shared total quota charges all frames and rolls back emitted state" {
    const input = "abcdefgh" ** 8;
    var profile: br.HqProfile = .{};
    var memory: br.EncodeMemoryProfile = .{};
    var options: br.PlannedEncodeOptions = .{
        .quality = 11,
        .memory_profile = &memory,
        .hq = .{ .parse_mode = .whole_block, .copy_lengths = .complete, .beam_width = 1, .iterations = 1, .search_depth = 1, .block_len = 128, .profile = &profile },
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
    try std.testing.expectEqual(.complete, profile.effective.?.copy_lengths);
    try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
}

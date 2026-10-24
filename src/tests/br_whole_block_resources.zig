const std = @import("std");
const br = @import("../br.zig");
const parser = @import("../br/encoder/hq_parser.zig");
const h = @import("br_whole_block_helpers.zig");
const a = std.testing.allocator;

test "Brotli whole block full span workspace exact budget and one below reject without bounded fallback" {
    const input = try h.boundaryInput(a);
    defer a.free(input);
    var tracked = h.TrackingAllocator.init(a);
    var profile: br.HqProfile = .{};
    const source = try parser.Source.init("", input, 13, 0);
    const model: parser.Model = .{};
    var parameters = try parser.Parameters.init(.{ .parse_mode = .whole_block, .beam_width = 2, .profile = &profile }, 10, br.PlannedMode.generic);
    const plan = try parser.planAlloc(tracked.allocator(), source, parameters, &model, null);
    const peak = tracked.peak;
    try std.testing.expectEqual(peak, profile.peak_working_memory);
    try std.testing.expectEqual(input.len, profile.max_parse_positions);
    try std.testing.expectEqual(@as(u64, 1), profile.whole_block_passes);
    plan.deinit(tracked.allocator());
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    parameters.resolved.max_working_memory = peak;
    profile.reset();
    const exact = try parser.planAlloc(tracked.allocator(), source, parameters, &model, null);
    try std.testing.expectEqual(input.len, exact.consumed);
    exact.deinit(tracked.allocator());
    parameters.resolved.max_working_memory = peak - 1;
    profile.reset();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, parser.planAlloc(tracked.allocator(), source, parameters, &model, null));
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(@as(u64, 0), profile.bounded_passes);
}

test "Brotli whole block predecessor trace crosses unsigned sixteen positions and replays every selected copy" {
    const input = try a.alloc(u8, 66 * 1024);
    defer a.free(input);
    @memset(input, 'a');
    const source = try parser.Source.init("aaaa", input, 17, 4);
    var model: parser.Model = .{};
    for (&model.literal_prices) |*row| @memset(row, 64 * 256);
    @memset(&model.command_prices, 64 * 256);
    @memset(&model.distance_prices, 64 * 256);
    model.command_prices[128] = 0;
    model.distance_prices[0] = 0;
    var profile: br.HqProfile = .{};
    const parameters = try parser.Parameters.init(.{ .parse_mode = .whole_block, .beam_width = 1, .search_depth = 1, .nice_len = 2, .block_len = input.len, .profile = &profile }, 10, br.PlannedMode.generic);
    const plan = try parser.planAlloc(a, source, parameters, &model, null);
    defer plan.deinit(a);
    try std.testing.expectEqual(input.len, plan.consumed);
    try std.testing.expectEqual(@as(u64, 0), plan.estimated_cost);
    try std.testing.expectEqual(input.len / 2, plan.commands.len);
    try std.testing.expect(plan.commands[plan.commands.len - 1].insert_start > 65535);
    try std.testing.expectEqual(input.len, profile.max_parse_positions);
    try h.replayWithHistory(a, "aaaa", input, .{ 4, 11, 15, 16 }, plan);
}

test "Brotli whole block sixteen MiB metadata with zero budget rejects before reading or backing allocation" {
    // The zero cap must dominate every matcher/input read. Only length/address
    // metadata is offered; no large backing buffer is allocated for this test.
    const input: []const u8 = @as([*]const u8, @ptrFromInt(4096))[0 .. 16 * 1024 * 1024];
    const source = try parser.Source.init("", input, 24, 0);
    var tracked = h.TrackingAllocator.init(a);
    tracked.fail_alloc_after = 0;
    const parameters = try parser.Parameters.init(.{ .parse_mode = .whole_block, .beam_width = 32, .max_working_memory = 0, .block_len = input.len }, 10, br.PlannedMode.generic);
    const model: parser.Model = .{};
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, parser.planAlloc(tracked.allocator(), source, parameters, &model, null));
    try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}

test "Brotli whole block shared nested HQ and total heap profiles match independent requested allocations" {
    for ([_]bool{ false, true }) |large| {
        var tracked = h.TrackingAllocator.init(a);
        tracked.force_moving_growth = true;
        var total: br.EncodeMemoryProfile = .{};
        var workspace: br.HqProfile = .{};
        var options: br.PlannedEncodeOptions = .{ .quality = 10, .large_window = large, .window_bits = if (large) 25 else 16, .hq = .{ .parse_mode = .whole_block, .beam_width = 2, .iterations = 1, .profile = &workspace }, .memory_profile = &total };
        const bytes = try br.encodePlannedStreamWithOptionsAlloc(tracked.allocator(), h.plain, options);
        const expected = try a.dupe(u8, bytes);
        defer a.free(expected);
        const total_peak = tracked.peak;
        const workspace_peak = workspace.peak_working_memory;
        try std.testing.expectEqual(total_peak, total.peak_requested_bytes);
        try std.testing.expect(total_peak > workspace_peak and workspace_peak > 0);
        try std.testing.expect(workspace.whole_block_passes > 0 and workspace.bounded_passes > 0);
        tracked.allocator().free(bytes);
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(@as(usize, 0), total.live_requested_bytes);
        total.reset();
        workspace.reset();
        tracked.beginMeasurement();
        options.max_total_working_memory = total_peak;
        options.hq.?.max_working_memory = workspace_peak;
        const exact = try br.encodePlannedStreamWithOptionsAlloc(tracked.allocator(), h.plain, options);
        try std.testing.expectEqualSlices(u8, expected, exact);
        tracked.allocator().free(exact);
        options.max_total_working_memory = total_peak - 1;
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamWithOptionsAlloc(tracked.allocator(), h.plain, options));
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(@as(usize, 0), total.live_requested_bytes);
    }
}

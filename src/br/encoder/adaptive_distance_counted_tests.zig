const std = @import("std");
const command_plan = @import("command_plan.zig");
const block_split_plan = @import("block_split_plan.zig");
const contexts = @import("literal_context_split.zig");
const literal_context = @import("literal_context.zig");
const prepared_literal = @import("prepared_literal.zig");
const quality_profile = @import("quality_profile.zig");

const seed_len = 64 * 1024;
const copy_len = 4;
const distance_values = [6][8]usize{
    .{ 1, 5, 9, 13, 17, 21, 25, 29 },
    .{ 64, 96, 128, 160, 192, 224, 256, 288 },
    .{ 1024, 1536, 2048, 2560, 3072, 3584, 4096, 4608 },
    .{ 32_768, 36_864, 40_960, 45_056, 49_152, 53_248, 57_344, 61_440 },
    .{ 8192, 9216, 10_240, 11_264, 12_288, 13_312, 14_336, 15_360 },
    .{ 16_384, 18_432, 20_480, 22_528, 24_576, 26_624, 28_672, 30_720 },
};

pub fn contracts(comptime C: type) !void {
    try exactSelection(C);
    try allocationFailures(C);
}

fn exactSelection(comptime C: type) !void {
    const command_count = 8192;
    const boundaries = [_]usize{ 901, 2305, 5179, 7001 };
    const region_types = [_]usize{ 0, 3, 0, 5, 0 };
    const payload = try std.testing.allocator.alloc(u8, seed_len + command_count * copy_len);
    defer std.testing.allocator.free(payload);
    const commands = try std.testing.allocator.alloc(command_plan.Command, command_count);
    defer std.testing.allocator.free(commands);
    fill(payload, commands, &boundaries, &region_types);

    var initial_stats: C.Stats = .{};
    const primary = contexts.Candidate.suffix(literal_context.mode_utf8, 56, 0);
    const primary_wire = try C.encode(std.testing.allocator, payload, commands, &initial_stats, primary, null);
    const proposals = try contexts.chooseProposals(std.testing.allocator, payload, commands);
    var alternates: [3]contexts.Candidate = undefined;
    var alternate_count: usize = 0;
    for ([3]?contexts.Candidate{ proposals.suffix, proposals.up_to_16, proposals.full }) |optional| {
        const candidate = optional orelse continue;
        if (contexts.Candidate.eql(candidate, primary)) continue;
        alternates[alternate_count] = candidate;
        alternate_count += 1;
    }
    try std.testing.expect(alternate_count != 0);
    var preferred = C.preferred(primary_wire, primary, alternates[0..alternate_count], true);
    defer std.testing.allocator.free(preferred.encoded);
    const split = try C.chooseSplit(std.testing.allocator, commands);
    defer split.deinit(std.testing.allocator);
    var shared = try C.prepareShared(std.testing.allocator, commands, &split);
    defer C.deinitShared(std.testing.allocator, &shared);

    const Choice = struct { context: ?contexts.Candidate, bytes: usize };
    var choices: [5]Choice = undefined;
    var choice_count: usize = 0;
    choices[choice_count] = .{ .context = preferred.literal_context_candidate, .bytes = 0 };
    choice_count += 1;
    for (preferred.alternate_literal_context_candidates[0..preferred.alternate_literal_context_count]) |candidate| {
        choices[choice_count] = .{ .context = candidate, .bytes = 0 };
        choice_count += 1;
    }
    if (preferred.alternate_plain_literals) {
        choices[choice_count] = .{ .context = null, .bytes = 0 };
        choice_count += 1;
    }
    var best_index: usize = 0;
    var worst_index: usize = 0;
    for (choices[0..choice_count], 0..) |*choice, index| {
        var stats = initial_stats;
        const wire = try C.encode(std.testing.allocator, payload, commands, &stats, choice.context, &split);
        choice.bytes = wire.len;
        std.testing.allocator.free(wire);
        var counted_stats = initial_stats;
        var state: prepared_literal.State = undefined;
        const counted = try C.prepare(std.testing.allocator, payload, commands, &counted_stats, choice.context, &split, &state);
        try std.testing.expectEqual(choice.bytes, counted.bytes);
        try std.testing.expectEqual(choice.bytes, state.wire_len);
        var shared_stats = initial_stats;
        var shared_state: prepared_literal.State = undefined;
        const shared_counted = try C.countShared(
            std.testing.allocator,
            payload,
            commands,
            &shared_stats,
            choice.context,
            &split,
            &shared,
            &shared_state,
        );
        try std.testing.expectEqual(choice.bytes, shared_counted.bytes);
        try std.testing.expectEqual(choice.bytes, shared_state.wire_len);
        try std.testing.expectEqualDeep(counted_stats, shared_stats);
        if (choice.bytes < choices[best_index].bytes) best_index = index;
        if (choice.bytes > choices[worst_index].bytes) worst_index = index;
    }
    try std.testing.expect(choices[best_index].bytes < choices[worst_index].bytes);
    preferred = C.preferred(primary_wire, choices[worst_index].context, &.{}, false);
    if (choices[best_index].context) |candidate| {
        preferred.alternate_literal_context_candidates[0] = candidate;
        preferred.alternate_literal_context_count = 1;
    } else preferred.alternate_plain_literals = true;

    C.disable(true);
    defer C.disable(false);
    var old_stats = initial_stats;
    const old = try C.select(std.testing.allocator, payload, commands, &old_stats, preferred, &split);
    defer std.testing.allocator.free(old);
    C.disable(false);
    C.resetSharedCounters();
    var new_stats = initial_stats;
    const new = try C.select(std.testing.allocator, payload, commands, &new_stats, preferred, &split);
    defer std.testing.allocator.free(new);
    const counters = C.sharedCounters();
    try std.testing.expectEqual(@as(usize, 1), counters.group.prepares);
    try std.testing.expectEqual(
        @as(usize, 1) + preferred.alternate_literal_context_count + @intFromBool(preferred.alternate_plain_literals),
        counters.group.literal_counts,
    );
    try std.testing.expectEqual(@as(usize, 1), counters.group.physical_emits);
    try std.testing.expectEqual(@as(usize, 1), counters.common.command_scans);
    try std.testing.expectEqual(@as(usize, 1), counters.common.distance_histogram_passes);
    try std.testing.expectEqual(@as(usize, 1), counters.common.distance_tree_build_passes);
    try std.testing.expectEqual(@as(usize, split.type_count), counters.common.distance_trees_built);
    try std.testing.expectEqual(@as(usize, 1), counters.common.split_code_builds);
    try std.testing.expectEqualSlices(u8, old, new);
    try std.testing.expectEqualDeep(old_stats, new_stats);
    const decoded = try C.decode(std.testing.allocator, new, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var profile: quality_profile.Profile = .{};
    var traced_stats = initial_stats;
    const traced = try C.selectTraced(std.testing.allocator, payload, commands, &traced_stats, preferred, &split, &profile);
    defer std.testing.allocator.free(traced);
    try std.testing.expectEqualSlices(u8, old, traced);
    var evaluations: usize = 0;
    var physical_wires: usize = 0;
    var linked: usize = 0;
    for (profile.recordedEvents()) |event| {
        if (!event.config.adaptive_distance_split) continue;
        try std.testing.expectEqual(@as(usize, split.type_count), event.config.distance_type_count);
        evaluations += @intFromBool(event.stage == .evaluate and event.evaluated_wire_bytes != null);
        physical_wires += @intFromBool(event.stage == .wire and event.wire_bytes != null);
        if (event.stage == .wire and event.evaluation_event_id != null) {
            linked += 1;
            try std.testing.expectEqual(event.wire_bytes, event.evaluated_wire_bytes);
        }
    }
    const expected_evaluations: usize = 1 + preferred.alternate_literal_context_count +
        @intFromBool(preferred.alternate_plain_literals);
    try std.testing.expectEqual(expected_evaluations, evaluations);
    try std.testing.expectEqual(expected_evaluations, profile.evaluation_attempts);
    try std.testing.expectEqual(@as(usize, 1), physical_wires);
    try std.testing.expectEqual(@as(usize, 1), linked);

    var primary_preferred = C.preferred(preferred.encoded, choices[best_index].context, &.{}, false);
    if (choices[worst_index].context) |candidate| {
        primary_preferred.alternate_literal_context_candidates[0] = candidate;
        primary_preferred.alternate_literal_context_count = 1;
    } else primary_preferred.alternate_plain_literals = true;
    var primary_profile: quality_profile.Profile = .{};
    var primary_stats = initial_stats;
    C.resetSharedCounters();
    const primary_selected = try C.selectTraced(
        std.testing.allocator,
        payload,
        commands,
        &primary_stats,
        primary_preferred,
        &split,
        &primary_profile,
    );
    defer std.testing.allocator.free(primary_selected);
    try std.testing.expectEqualSlices(u8, old, primary_selected);
    try std.testing.expectEqualDeep(old_stats, primary_stats);
    var primary_evaluations: usize = 0;
    var primary_wires: usize = 0;
    var primary_links: usize = 0;
    for (primary_profile.recordedEvents()) |event| {
        if (!event.config.adaptive_distance_split) continue;
        primary_evaluations += @intFromBool(event.stage == .evaluate and event.evaluated_wire_bytes != null);
        primary_wires += @intFromBool(event.stage == .wire and event.wire_bytes != null);
        primary_links += @intFromBool(event.stage == .wire and event.evaluation_event_id != null);
    }
    try std.testing.expectEqual(@as(usize, 2), primary_evaluations);
    try std.testing.expectEqual(@as(usize, 2), primary_profile.evaluation_attempts);
    try std.testing.expectEqual(@as(usize, 1), primary_wires);
    try std.testing.expectEqual(@as(usize, 1), primary_links);
    const primary_shared = C.sharedCounters();
    try std.testing.expectEqual(@as(usize, 1), primary_shared.group.prepares);
    try std.testing.expectEqual(@as(usize, 1), primary_shared.group.physical_emits);

    var measured = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var measured_stats = initial_stats;
    const output = try C.select(measured.allocator(), payload, commands, &measured_stats, preferred, &split);
    measured.allocator().free(output);
    try std.testing.expect(measured.alloc_index > 1);
    for ([_]usize{ 0, measured.alloc_index - 1 }) |fail_index| {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = fail_index });
        var stats = initial_stats;
        try std.testing.expectError(error.OutOfMemory, C.select(failing.allocator(), payload, commands, &stats, preferred, &split));
        try std.testing.expectEqualDeep(initial_stats, stats);
    }
}

fn allocationFailures(comptime C: type) !void {
    const command_count = 32;
    const boundaries = [_]usize{ 5, 13, 22 };
    const region_types = [_]usize{ 0, 5, 3, 5 };
    const payload = try std.testing.allocator.alloc(u8, seed_len + command_count * copy_len);
    defer std.testing.allocator.free(payload);
    const commands = try std.testing.allocator.alloc(command_plan.Command, command_count);
    defer std.testing.allocator.free(commands);
    fill(payload, commands, &boundaries, &region_types);
    const lengths = [_]u32{ 5, 8, 9, 10 };
    const types = [_]u8{ 0, 2, 1, 2 };
    const split = try block_split_plan.Plan.initCopy(std.testing.allocator, &lengths, &types, 3, command_count, 0);
    defer split.deinit(std.testing.allocator);
    const Run = struct {
        fn run(allocator: std.mem.Allocator, input: []const u8, command_stream: []const command_plan.Command, plan: *const block_split_plan.Plan) !void {
            const primary = contexts.Candidate.suffix(literal_context.mode_utf8, 56, 0);
            var stats: C.Stats = .{};
            const baseline = try C.encode(allocator, input, command_stream, &stats, primary, null);
            defer allocator.free(baseline);
            const alternate = contexts.Candidate.suffix(literal_context.mode_lsb6, 40, 0);
            const preferred = C.preferred(baseline, primary, &.{alternate}, true);
            const before = stats;
            const encoded = C.select(allocator, input, command_stream, &stats, preferred, plan) catch |err| {
                try std.testing.expectEqualDeep(before, stats);
                return err;
            };
            allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Run.run, .{ payload, commands, &split });
}

fn fill(payload: []u8, commands: []command_plan.Command, boundaries: []const usize, region_types: []const usize) void {
    std.debug.assert(payload.len == seed_len + commands.len * copy_len);
    @memset(payload, 'a');
    var region: usize = 0;
    for (commands, 0..) |*command, index| {
        if (region < boundaries.len and index == boundaries[region]) region += 1;
        command.* = .{
            .insert_start = if (index == 0) 0 else seed_len + index * copy_len,
            .insert_len = if (index == 0) seed_len else 0,
            .copy_len = copy_len,
            .distance = distance_values[region_types[region]][index & 7],
            .has_copy = true,
        };
    }
    const phrase = "the quick brown fox jumps over the lazy dog; structured context payload 0123456789\n";
    for (payload[0..seed_len], 0..) |*byte, index| byte.* = phrase[(index + (index / 251) * 17) % phrase.len];
    for (commands) |command| {
        const start = command.insert_start + command.insert_len;
        for (0..command.copy_len) |offset| payload[start + offset] = payload[start + offset - command.distance];
    }
}

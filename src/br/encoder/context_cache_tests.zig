//! Compare complete proposals with the unchanged per-mode/suffix reference.
//! No imports of the caller module; input/context fixtures are independent.
const std = @import("std");
const command_plan = @import("command_plan.zig");
const literal_context = @import("literal_context.zig");

fn candidateEqual(expected: anytype, actual: @TypeOf(expected), max_trees: usize) !void {
    try std.testing.expectEqual(expected == null, actual == null);
    if (expected) |reference| {
        const value = actual.?;
        try std.testing.expectEqual(reference.mode, value.mode);
        try std.testing.expectEqual(reference.tree_count, value.tree_count);
        try std.testing.expectEqualSlices(u8, &reference.context_map, &value.context_map);
        try std.testing.expectEqual(reference.savings_bits, value.savings_bits);
        try std.testing.expect(value.tree_count >= 2 and value.tree_count <= max_trees);
        for (value.context_map) |tree| try std.testing.expect(tree < value.tree_count);
    }
}

fn proposalsEqual(expected: anytype, actual: @TypeOf(expected)) !void {
    try candidateEqual(expected.suffix, actual.suffix, 2);
    try candidateEqual(expected.up_to_16, actual.up_to_16, 16);
    try candidateEqual(expected.full, actual.full, 64);
}

fn literalStats(input: []const u8, commands: []const command_plan.Command) struct { count: usize, active: usize } {
    var frequencies: [256]u32 = @splat(0);
    var count: usize = 0;
    for (commands) |command| {
        for (input[command.insert_start..][0..command.insert_len]) |byte| frequencies[byte] += 1;
        count += command.insert_len;
    }
    var active: usize = 0;
    for (frequencies) |frequency| active += @intFromBool(frequency != 0);
    return .{ .count = count, .active = active };
}

fn validateCounts(profile: anytype) !void {
    var scoped_requests: usize = 0;
    var scoped_hits: usize = 0;
    var scoped_misses: usize = 0;
    for (profile.tree_score_scope_counts) |counts| {
        try std.testing.expectEqual(counts.requests, counts.hits + counts.misses);
        try std.testing.expectEqual(counts.misses, counts.cold_misses + counts.conflict_misses);
        try std.testing.expect(counts.cross_scope_hits <= counts.hits);
        try std.testing.expect(counts.cross_mode_hits <= counts.hits);
        scoped_requests += counts.requests;
        scoped_hits += counts.hits;
        scoped_misses += counts.misses;
    }
    try std.testing.expectEqual(profile.tree_score_cache_hits, scoped_hits);
    try std.testing.expectEqual(profile.tree_score_cache_misses, scoped_misses);
    try std.testing.expectEqual(scoped_requests, scoped_hits + scoped_misses);
    try std.testing.expectEqual(profile.tree_score_calls, profile.tree_score_cache_misses + profile.tree_score_uncached_calls);
    var uncached_scopes: usize = 0;
    for (profile.tree_score_uncached_scope_calls) |calls| uncached_scopes += calls;
    try std.testing.expectEqual(profile.tree_score_uncached_calls, uncached_scopes);
    try std.testing.expectEqual(@as(usize, 1), profile.tree_score_uncached_scope_calls[0]);
    try std.testing.expectEqual(profile.suffix_payload_scores * 2, profile.tree_score_uncached_scope_calls[1]);
    try std.testing.expectEqual(@as(usize, 0), profile.tree_score_uncached_scope_calls[2]);
    // Baseline and suffix score directly; one shared cache serves all four
    // modes' clustering, so an entry published by one mode may be reused by
    // another. Lower-bound pruning never reaches the cache.
    for (profile.tree_score_scope_counts[0..2]) |counts| {
        try std.testing.expectEqual(@as(usize, 0), counts.requests);
        try std.testing.expectEqual(@as(usize, 0), counts.cross_mode_hits);
    }
    for (profile.tree_score_scope_counts) |counts| {
        try std.testing.expectEqual(@as(usize, 0), counts.cross_scope_hits);
        try std.testing.expect(counts.cross_mode_hits <= counts.hits);
    }
    try std.testing.expect(profile.cluster_maps_pruned <= profile.cluster_lb_checks);
    try std.testing.expect(profile.cluster_lb_checks <= profile.score_cache_misses);
    try std.testing.expect(profile.cluster_tree_scores_pruned <= profile.cluster_lb_checks - profile.cluster_maps_pruned);
    const complete_maps = profile.score_cache_misses - profile.cluster_maps_pruned - profile.cluster_tree_scores_pruned;
    // Full maps request at least two trees; each partial map already requested
    // at least one. These disjoint categories cannot reuse the same requests.
    try std.testing.expect(scoped_requests >= 2 * complete_maps + profile.cluster_tree_scores_pruned);
    var mode_cross_mode: usize = 0;
    for (profile.tree_score_mode_counts) |scopes| {
        try std.testing.expectEqual(@as(usize, 0), scopes[0].requests);
        try std.testing.expectEqual(@as(usize, 0), scopes[1].requests);
        for (scopes) |counts| {
            try std.testing.expectEqual(counts.requests, counts.hits + counts.misses);
            try std.testing.expectEqual(@as(usize, 0), counts.cross_scope_hits);
            mode_cross_mode += counts.cross_mode_hits;
        }
    }
    try std.testing.expectEqual(profile.tree_score_scope_counts[2].cross_mode_hits, mode_cross_mode);
    var uncached_modes: usize = 0;
    for (profile.tree_score_uncached_mode_calls) |scopes| {
        // The one baseline is global; it must not be attributed four times.
        try std.testing.expectEqual(@as(usize, 0), scopes[0]);
        try std.testing.expectEqual(@as(usize, 0), scopes[2]);
        for (scopes) |calls| uncached_modes += calls;
    }
    try std.testing.expectEqual(profile.tree_score_uncached_calls, uncached_modes + 1);
}

fn runCase(comptime Codec: type, input: []const u8, commands: []const command_plan.Command) !Codec.Proposals {
    const input_before = try std.testing.allocator.dupe(u8, input);
    defer std.testing.allocator.free(input_before);
    const commands_before = try std.testing.allocator.dupe(command_plan.Command, commands);
    defer std.testing.allocator.free(commands_before);
    var reference_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var cached_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var profile_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const expected = try Codec.chooseProposalsReference(reference_heap.allocator(), input, commands);
    const actual = try Codec.chooseProposals(cached_heap.allocator(), input, commands);
    var profile: Codec.Profile = .{};
    const observed = try Codec.chooseProposalsProfiled(profile_heap.allocator(), input, commands, std.testing.io, &profile);
    try proposalsEqual(expected, actual);
    try proposalsEqual(expected, observed);
    try std.testing.expectEqual(reference_heap.allocated_bytes, reference_heap.freed_bytes);
    try std.testing.expectEqual(cached_heap.allocated_bytes, cached_heap.freed_bytes);
    try std.testing.expectEqual(profile_heap.allocated_bytes, profile_heap.freed_bytes);
    try std.testing.expectEqualSlices(u8, input_before, input);
    try std.testing.expectEqualDeep(commands_before, commands);
    const stats = literalStats(input, commands);
    if (stats.count >= 128) {
        try std.testing.expectEqual(input.len, profile.input_bytes);
        try std.testing.expectEqual(stats.count, profile.literal_count);
        try std.testing.expectEqual(stats.active, profile.active_symbols);
        try validateCounts(profile);
    } else {
        try std.testing.expectEqual(@as(?Codec.Candidate, null), actual.suffix);
        try std.testing.expectEqual(@as(?Codec.Candidate, null), actual.up_to_16);
        try std.testing.expectEqual(@as(?Codec.Candidate, null), actual.full);
    }
    return actual;
}

fn simpleAndThresholds(comptime Codec: type) !void {
    const bytes = "a small threshold test " ** 8;
    for ([_]usize{ 0, 1, 63, 64, 127, 128, 129, bytes.len }) |length| {
        const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = length }};
        _ = try runCase(Codec, bytes[0..length], &commands);
    }
    const stationary = "aaaaaaaa" ** 512;
    _ = try runCase(Codec, stationary, &.{.{ .insert_start = 0, .insert_len = stationary.len }});
    const predictive = ("the quick brown fox jumps over the lazy dog\n" ** 16) ++ ("THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\n" ** 16);
    const result = try runCase(Codec, predictive, &.{.{ .insert_start = 0, .insert_len = predictive.len }});
    try std.testing.expect(result.full != null);
    var random: [4096]u8 = undefined;
    var state: u32 = 0x243f6a88;
    for (&random) |*byte| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @truncate(state >> 24);
    }
    _ = try runCase(Codec, &random, &.{.{ .insert_start = 0, .insert_len = random.len }});
    @memset(&random, 255);
    _ = try runCase(Codec, &random, &.{.{ .insert_start = 0, .insert_len = random.len }});
}

fn modeContexts(comptime Codec: type) !void {
    const seconds = [_]u8{ 0, 8, 32, 80, 128, 200, 244, 255 };
    const literal_count = 256 * seconds.len;
    const a = std.testing.allocator;
    const input = try a.alloc(u8, literal_count * 3);
    defer a.free(input);
    const commands = try a.alloc(command_plan.Command, literal_count);
    defer a.free(commands);
    for (0..4) |mode| {
        for ([_]usize{ 0, 1 }) |variant| {
            var command_index: usize = 0;
            for (0..256) |previous| {
                for (seconds) |second_previous| {
                    const position = command_index * 3 + 2;
                    input[position - 2] = second_previous;
                    input[position - 1] = @intCast(previous);
                    const context = literal_context.value(@intCast(mode), @intCast(previous), second_previous);
                    // Identical context group mapping, different full byte
                    // histograms: cache keys cannot use the map alone.
                    const group: u8 = if (context < 32) 0 else 128;
                    const symbol: u8 = @intCast(command_index % (if (variant == 0) @as(usize, 16) else 64));
                    input[position] = group + symbol;
                    commands[command_index] = .{ .insert_start = position, .insert_len = 1 };
                    command_index += 1;
                }
            }
            _ = try runCase(Codec, input, commands);
        }
    }
    // All 256 literal bytes with high-byte contexts and zero-length commands
    // exercise complete histogram clearing and context support holes.
    for (input, 0..) |*byte, index| byte.* = @truncate(index *% 149);
    const scattered = [_]command_plan.Command{
        .{ .insert_start = 3, .insert_len = 0 },
        .{ .insert_start = 0, .insert_len = 256 },
        .{ .insert_start = 512, .insert_len = 1024 },
        .{ .insert_start = input.len - 512, .insert_len = 512 },
    };
    _ = try runCase(Codec, input, &scattered);
}

/// Stress the lower-bound pruning proof: across many distributions the
/// pruned production search must return byte-identical proposals to the
/// exhaustive reference, including the bounded-16 slot under strong >16-tree
/// incumbents.
fn randomizedEquivalence(comptime Codec: type) !void {
    const lengths = [_]usize{ 128, 129, 200, 511, 1024, 4095, 4096, 8192 };
    const case_count = 16 * lengths.len;
    var state: u32 = 0x9e37_79b9;
    const case_inputs = [_]struct { commands: u8 }{
        .{ .commands = 1 },
        .{ .commands = 1 },
        .{ .commands = 3 },
    };
    for (0..case_count) |case| {
        const distribution: u2 = @intCast(case % 4);
        const length = lengths[(case / 4) % lengths.len];
        const input = try std.testing.allocator.alloc(u8, length);
        defer std.testing.allocator.free(input);
        var previous: u8 = 0;
        for (input, 0..) |*byte, index| {
            state = state *% 1664525 +% 1013904223;
            const random = @as(u8, @truncate(state >> 24));
            byte.* = switch (distribution) {
                0 => random,
                1 => @as(u8, @truncate(@as(u32, random) *% 6 >> 8)),
                2 => blk: {
                    state = state *% 1664525 +% 1013904223;
                    previous +%= @as(u8, @truncate(state >> 28));
                    break :blk previous;
                },
                3 => blk: {
                    if (index % 17 == 0) {
                        previous = random & 0x07;
                    } else {
                        state = state *% 1664525 +% 1013904223;
                        previous = 32 +% (@as(u8, @truncate(state >> 27)) % 26);
                    }
                    break :blk previous;
                },
            };
        }
        const layout = case_inputs[case % case_inputs.len];
        var commands_storage: [3]command_plan.Command = undefined;
        var boundaries: [4]usize = .{ 0, 0, 0, length };
        for (1..layout.commands) |part| {
            state = state *% 1664525 +% 1013904223;
            boundaries[part] = (length * (@as(usize, @truncate(state >> 24)) + part * 255) /
                (@as(usize, layout.commands) * 256));
        }
        boundaries[0] = 0;
        boundaries[layout.commands] = length;
        for (0..layout.commands) |part| {
            commands_storage[part] = .{
                .insert_start = boundaries[part],
                .insert_len = boundaries[part + 1] - boundaries[part],
            };
        }
        _ = try runCase(Codec, input, commands_storage[0..layout.commands]);
    }
}

fn allocationFailures(comptime Codec: type) !void {
    const input = ("the quick brown fox jumps over the lazy dog\n" ** 16) ++ ("THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\n" ** 16);
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const Route = enum { reference, cached, profiled };
    inline for (std.enums.values(Route)) |route| {
        var baseline = std.testing.FailingAllocator.init(std.testing.allocator, .{});
        var baseline_profile: Codec.Profile = .{};
        const expected = switch (route) {
            .reference => try Codec.chooseProposalsReference(baseline.allocator(), input, &commands),
            .cached => try Codec.chooseProposals(baseline.allocator(), input, &commands),
            .profiled => try Codec.chooseProposalsProfiled(baseline.allocator(), input, &commands, std.testing.io, &baseline_profile),
        };
        try std.testing.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
        try std.testing.expect(baseline.alloc_index > 0);
        for (0..baseline.alloc_index) |failure| {
            var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
            var failed_profile: Codec.Profile = .{};
            const result = switch (route) {
                .reference => Codec.chooseProposalsReference(heap.allocator(), input, &commands),
                .cached => Codec.chooseProposals(heap.allocator(), input, &commands),
                .profiled => Codec.chooseProposalsProfiled(heap.allocator(), input, &commands, std.testing.io, &failed_profile),
            };
            if (result) |actual| {
                try proposalsEqual(expected, actual);
                if (failure == 0) return error.TestExpectedError;
            } else |err| try std.testing.expectEqual(error.OutOfMemory, err);
            try std.testing.expect(heap.has_induced_failure);
            try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        }
    }
}

fn partialPruning(comptime Codec: type) !void {
    var input: [4096]u8 = undefined;
    var state: u32 = 0x243f6a88;
    for (&input) |*byte| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @truncate(state >> 24);
    }
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const expected = try runCase(Codec, &input, &commands);
    var profile: Codec.Profile = .{};
    const actual = try Codec.chooseProposalsProfiled(std.testing.allocator, &input, &commands, std.testing.io, &profile);
    try proposalsEqual(expected, actual);
    // Make the differential test exercise the new cutoff, even if other
    // proposal fixtures happen to reject maps before any exact tree score.
    try std.testing.expect(profile.cluster_tree_scores_pruned > 0);
    try validateCounts(profile);
}

pub fn contracts(comptime Codec: type) !void {
    try simpleAndThresholds(Codec);
    try modeContexts(Codec);
    try randomizedEquivalence(Codec);
    try partialPruning(Codec);
    try allocationFailures(Codec);
}

const std = @import("std");
const fixtures = @import("fixtures.zig");
const oracle = @import("oracle.zig");
const distance = @import("../distance.zig");
const command_encoding = @import("../command_encoding.zig");
const quality = @import("../quality_profile.zig");
const resources = @import("resources.zig");

fn config(event: quality.Event, options: anytype) !void {
    try std.testing.expectEqual(options.window_bits, event.config.window_bits);
    try std.testing.expectEqual(options.large_window, event.config.large_window);
    try std.testing.expectEqual(options.use_recent_distances, event.config.use_recent_distances);
    try std.testing.expectEqual(@as(u8, options.distance_parameters.npostfix), event.config.npostfix);
    try std.testing.expectEqual(@as(u8, options.distance_parameters.ndirect_high), event.config.ndirect_high);
    try std.testing.expectEqual(options.optimize_same_last_distance, event.config.optimize_same_last_distance);
}

fn selection(event: quality.Event, candidate: usize, incumbent: usize, candidate_id: ?usize, incumbent_id: ?usize) !void {
    try std.testing.expect(event.stage == .selection);
    try std.testing.expectEqual(@as(?usize, candidate), event.wire_bytes);
    try std.testing.expectEqual(@as(?usize, incumbent), event.incumbent_bytes);
    try std.testing.expectEqual(@as(?bool, candidate < incumbent), event.accepted);
    try std.testing.expectEqual(if (candidate < incumbent) incumbent - candidate else 0, event.gain_bytes);
    try std.testing.expectEqual(candidate_id, event.candidate_event_id);
    try std.testing.expectEqual(incumbent_id, event.incumbent_event_id);
}

fn profileResult(comptime C: type, profile: *const C.Profile, local: *const oracle.LocalWinner(C), data: fixtures.Fixture, options: C.Options, incumbent_len: usize, limit: usize) !void {
    const has_alt = local.parameters != null;
    const emitted = local.wire().len < incumbent_len;
    const evaluations: usize = if (has_alt) 2 else 1;
    const event_count: usize = (if (has_alt) @as(usize, 5) else 3) + @intFromBool(emitted);
    try std.testing.expectEqual(@as(usize, 1), profile.parameter_pairs);
    try std.testing.expectEqual(evaluations, profile.parameter_counted_candidates);
    try std.testing.expectEqual(@as(usize, @intFromBool(emitted)), profile.parameter_physical_emits);
    try std.testing.expectEqual(@as(usize, @intFromBool(!emitted)), profile.parameter_skipped_pair_emits);
    try std.testing.expectEqual(evaluations, profile.evaluation_attempts);
    try std.testing.expectEqual(@as(usize, @intFromBool(emitted)), profile.wire_attempts);
    try std.testing.expectEqual(event_count, profile.events_total);
    try std.testing.expectEqual(@as(usize, 0), profile.depth);
    if (limit == 0) {
        try std.testing.expectEqual(@as(usize, 0), profile.event_count);
        try std.testing.expect(profile.events_truncated);
        return;
    }
    try std.testing.expect(!profile.events_truncated);
    const events = profile.recordedEvents();
    try std.testing.expectEqual(event_count, events.len);
    try std.testing.expect(events[0].stage == .distance_parameters);
    try std.testing.expectEqual(@as(?usize, null), events[0].parent_id);
    for (events[1..], 1..) |event, id| {
        try std.testing.expectEqual(id, event.id);
        try std.testing.expectEqual(@as(?usize, 0), event.parent_id);
        try std.testing.expectEqualStrings("", event.error_name);
    }
    try std.testing.expect(events[1].stage == .evaluate);
    try std.testing.expectEqual(@as(?usize, local.baseline.len), events[1].evaluated_wire_bytes);
    try std.testing.expectEqual(@as(?usize, null), events[1].wire_bytes);
    try std.testing.expectEqual(data.input.len, events[1].input_bytes);
    try std.testing.expectEqual(data.commands.len, events[1].command_count);
    try config(events[1], options);
    var outer: usize = 2;
    if (local.parameters) |parameters| {
        try std.testing.expect(events[2].stage == .evaluate);
        try std.testing.expectEqual(@as(?usize, local.alternate.?.len), events[2].evaluated_wire_bytes);
        try std.testing.expectEqual(@as(?usize, null), events[2].wire_bytes);
        var alternate_options = options;
        alternate_options.distance_parameters = parameters;
        alternate_options.optimize_same_last_distance = false;
        try config(events[2], alternate_options);
        try selection(events[3], local.alternate.?.len, local.baseline.len, 2, 1);
        outer = 4;
    }
    const selected_id: usize = if (local.selected_alternate) 2 else 1;
    try selection(events[outer], local.wire().len, incumbent_len, selected_id, null);
    if (emitted) {
        const event = events[outer + 1];
        try std.testing.expect(event.stage == .wire);
        try std.testing.expectEqual(@as(?usize, selected_id), event.evaluation_event_id);
        try std.testing.expectEqual(@as(?usize, local.wire().len), event.evaluated_wire_bytes);
        try std.testing.expectEqual(@as(?usize, local.wire().len), event.wire_bytes);
        var selected_options = options;
        if (local.selected_alternate) {
            selected_options.distance_parameters = local.parameters.?;
            selected_options.optimize_same_last_distance = false;
        }
        try config(event, selected_options);
    }
}

fn matrix(comptime C: type, data: fixtures.Fixture, options: C.Options, expected_alt: bool, expected_tie: bool) !void {
    const allocator = std.testing.allocator;
    const local = try oracle.LocalWinner(C).init(allocator, data, options);
    defer local.deinit(allocator);
    try std.testing.expectEqual(expected_alt, local.selected_alternate);
    if (expected_tie) try std.testing.expectEqual(local.baseline.len, local.alternate.?.len);
    const before = try allocator.dupe(u8, data.input);
    defer allocator.free(before);
    const commands = try allocator.dupe(fixtures.Command, data.commands);
    defer allocator.free(commands);
    for ([_]usize{ local.wire().len - 1, local.wire().len, local.wire().len + 1 }) |incumbent_len| {
        const guarded = try allocator.alloc(u8, incumbent_len + 2);
        defer allocator.free(guarded);
        @memset(guarded, 0x63);
        guarded[0] = 0xb7;
        guarded[guarded.len - 1] = 0x9d;
        const incumbent = guarded[1 .. guarded.len - 1];
        var stats = fixtures.stats(C.Stats, data);
        const actual = try C.against(allocator, data.input, data.commands, &stats, options, incumbent);
        if (actual) |wire| {
            defer allocator.free(wire);
            try std.testing.expect(local.wire().len < incumbent_len);
            try std.testing.expect(wire.ptr != incumbent.ptr);
            try std.testing.expectEqualSlices(u8, local.wire(), wire);
        } else try std.testing.expect(local.wire().len >= incumbent_len);
        try std.testing.expectEqualDeep(local.stats(), stats);
        for ([_]usize{ quality.event_capacity, 0 }) |limit| {
            var profile: C.Profile = .{ .request = .{ .event_limit = limit } };
            stats = fixtures.stats(C.Stats, data);
            const profiled = try C.againstProfile(std.testing.io, allocator, data.input, data.commands, &stats, options, incumbent, &profile);
            if (profiled) |wire| {
                defer allocator.free(wire);
                try std.testing.expect(local.wire().len < incumbent_len);
                try std.testing.expectEqualSlices(u8, local.wire(), wire);
            } else try std.testing.expect(local.wire().len >= incumbent_len);
            try std.testing.expectEqualDeep(local.stats(), stats);
            try profileResult(C, &profile, &local, data, options, incumbent_len, limit);
        }
        try std.testing.expectEqual(@as(u8, 0xb7), guarded[0]);
        try std.testing.expectEqual(@as(u8, 0x9d), guarded[guarded.len - 1]);
        for (incumbent) |byte| try std.testing.expectEqual(@as(u8, 0x63), byte);
        try data.checkGuards();
        try std.testing.expectEqualSlices(u8, before, data.input);
        for (commands, data.commands) |old, current| try std.testing.expectEqualDeep(old, current);
    }
}

fn fallbacks(comptime C: type) !void {
    const allocator = std.testing.allocator;
    const data = try fixtures.small(allocator, 1);
    defer data.deinit(allocator);
    const initial = fixtures.stats(C.Stats, data);
    for ([_]C.Options{
        .{ .use_recent_distances = false, .distance_parameters = distance.Parameters.init(0, 0) },
        .{ .use_recent_distances = true, .distance_parameters = distance.Parameters.init(0, 15) },
    }) |options| {
        var stats = initial;
        if (C.against(allocator, data.input, data.commands, &stats, options, &@as([128]u8, @splat(0)))) |wire| {
            if (wire) |bytes| allocator.free(bytes);
            return error.TestUnexpectedResult;
        } else |err| try std.testing.expectEqual(error.InvalidBlockPlan, err);
        try std.testing.expectEqualDeep(initial, stats);
        var profile: C.Profile = .{};
        stats = initial;
        try std.testing.expectError(error.InvalidBlockPlan, C.againstProfile(std.testing.io, allocator, data.input, data.commands, &stats, options, &@as([128]u8, @splat(0)), &profile));
        try std.testing.expectEqualDeep(initial, stats);
        try std.testing.expectEqual(@as(usize, 0), profile.parameter_pairs);
        try std.testing.expectEqual(@as(usize, 0), profile.depth);
    }
    const exact = try fixtures.literalOnly(allocator, 4);
    defer exact.deinit(allocator);
    const item = &exact.commands[0];
    item.hq_encoding = .{ .command_symbol = command_encoding.forLengths(item.insert_len, item.copy_len, false).?.symbol };
    const options: C.Options = .{ .use_recent_distances = true, .distance_parameters = distance.Parameters.init(0, 0) };
    const local = try oracle.LocalWinner(C).init(allocator, exact, options);
    defer local.deinit(allocator);
    var stats = fixtures.stats(C.Stats, exact);
    var profile: C.Profile = .{};
    const wire = (try C.againstProfile(std.testing.io, allocator, exact.input, exact.commands, &stats, options, &@as([128]u8, @splat(0)), &profile)).?;
    defer allocator.free(wire);
    try std.testing.expectEqualSlices(u8, local.wire(), wire);
    try std.testing.expectEqualDeep(local.stats(), stats);
    try std.testing.expectEqual(@as(usize, 0), profile.parameter_pairs);
    try std.testing.expectEqual(@as(usize, 0), profile.parameter_counted_candidates);
    try std.testing.expectEqual(@as(usize, 1), profile.wire_attempts);
    try exact.checkGuards();
}

pub fn check(comptime C: type) !void {
    const allocator = std.testing.allocator;
    const options: C.Options = .{ .use_recent_distances = true, .distance_parameters = distance.Parameters.init(0, 0), .window_bits = 16 };
    const small = try fixtures.small(allocator, 1);
    defer small.deinit(allocator);
    try matrix(C, small, options, false, false);
    const rich = try fixtures.rich(allocator, 129, true);
    defer rich.deinit(allocator);
    try matrix(C, rich, options, true, false);
    const tied = try fixtures.dictionary(allocator, .static);
    defer tied.deinit(allocator);
    var dictionary_options = options;
    dictionary_options.compound_dictionary_size = 8;
    try matrix(C, tied, dictionary_options, false, true);
    try fallbacks(C);
    try resources.against(C);
}

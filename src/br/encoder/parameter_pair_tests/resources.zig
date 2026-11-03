const std = @import("std");
const fixtures = @import("fixtures.zig");
const oracle = @import("oracle.zig");
const distance = @import("../distance.zig");
const WorkingAllocator = @import("../../../io/working_allocator.zig").WorkingAllocator;

fn graph(comptime C: type, allocator: std.mem.Allocator, data: fixtures.Fixture, base_options: C.Options, expected_base: []const u8, expected_alt: []const u8, expected_base_stats: C.Stats, expected_alt_stats: C.Stats) !void {
    var common = C.Common.init(base_options, data.commands);
    var literal: C.Literal = .{};
    var baseline_stats = fixtures.stats(C.Stats, data);
    _ = try C.prepareBase(allocator, data.input, data.commands, &baseline_stats, base_options, &common, &literal);
    const base = try C.emitBase(allocator, data.input, data.commands, &baseline_stats, base_options, &common, &literal);
    defer allocator.free(base);
    try std.testing.expectEqualSlices(u8, expected_base, base);
    try std.testing.expectEqualDeep(expected_base_stats, baseline_stats);
    var options = base_options;
    options.distance_parameters = distance.Parameters.init(3, 15);
    options.optimize_same_last_distance = false;
    var state: C.State = .{};
    var alternate_stats = fixtures.stats(C.Stats, data);
    _ = try C.prepareAlt(allocator, data.input, data.commands, &alternate_stats, options, &common, &literal, &state);
    const alt = try C.emitAlt(allocator, data.input, data.commands, &alternate_stats, options, &common, &literal, &state);
    defer allocator.free(alt);
    try std.testing.expectEqualSlices(u8, expected_alt, alt);
    try std.testing.expectEqualDeep(expected_alt_stats, alternate_stats);
    try data.checkGuards();
}

pub fn check(comptime C: type) !void {
    const allocator = std.testing.allocator;
    const data = try fixtures.rich(allocator, 129, true);
    defer data.deinit(allocator);
    var session: oracle.Session(C) = undefined;
    try session.init(allocator, data, .{ .window_bits = 16 });
    defer session.deinit(allocator);
    const options = session.altOptions(distance.Parameters.init(3, 15));
    var expected_stats = fixtures.stats(C.Stats, data);
    const expected = try oracle.physical(C, allocator, data, &expected_stats, options);
    defer allocator.free(expected);
    const initial = fixtures.stats(C.Stats, data);
    const common_frequencies = session.common.value.command_frequencies;
    const common_lengths = session.common.value.command_lengths;
    const old_distance_frequencies = session.common.value.distance_frequencies;
    const old_distance_lengths = session.common.value.distance_lengths;
    const old_payload = session.literal.value.payload_bits;
    const old_header = session.literal.value.header_bits;
    var state: oracle.Guarded(C.State) = .{ .value = .{} };
    var stats = initial;
    var probe = std.testing.FailingAllocator.init(allocator, .{});
    _ = try C.prepareAlt(probe.allocator(), data.input, data.commands, &stats, options, &session.common.value, &session.literal.value, &state.value);
    try std.testing.expectEqual(expected.len, state.value.wire_len);
    try std.testing.expectEqual(probe.allocated_bytes, probe.freed_bytes);
    const init_allocations = probe.alloc_index;
    var init_oom: usize = 0;
    for (0..init_allocations + 1) |fail_index| {
        var heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index });
        var failed: oracle.Guarded(C.State) = .{ .value = state.value };
        var measured = initial;
        if (C.prepareAlt(heap.allocator(), data.input, data.commands, &measured, options, &session.common.value, &session.literal.value, &failed.value)) |size| {
            try std.testing.expectEqual(expected.len, size);
            try std.testing.expect(failed.value.matches(data.input, data.commands, options));
        } else |err| {
            try std.testing.expectEqual(error.OutOfMemory, err);
            try std.testing.expect(heap.has_induced_failure);
            try std.testing.expect(!failed.value.ready);
            try std.testing.expectEqualDeep(initial, measured);
            init_oom += 1;
        }
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        try failed.check();
        try session.unchanged(data);
    }
    const prepared_stats = stats;
    var emission_probe = std.testing.FailingAllocator.init(allocator, .{});
    {
        var measured = prepared_stats;
        const wire = try C.emitAlt(emission_probe.allocator(), data.input, data.commands, &measured, options, &session.common.value, &session.literal.value, &state.value);
        emission_probe.allocator().free(wire);
        try std.testing.expectEqualDeep(expected_stats, measured);
    }
    try std.testing.expectEqual(emission_probe.allocated_bytes, emission_probe.freed_bytes);
    var emit_oom: usize = 0;
    for (0..emission_probe.alloc_index + 1) |fail_index| {
        var heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index });
        var measured = prepared_stats;
        if (C.emitAlt(heap.allocator(), data.input, data.commands, &measured, options, &session.common.value, &session.literal.value, &state.value)) |wire| {
            try std.testing.expectEqualSlices(u8, expected, wire);
            try std.testing.expectEqualDeep(expected_stats, measured);
            heap.allocator().free(wire);
        } else |err| {
            try std.testing.expectEqual(error.OutOfMemory, err);
            try std.testing.expect(heap.has_induced_failure);
            try std.testing.expectEqualDeep(prepared_stats, measured);
            emit_oom += 1;
        }
        try std.testing.expect(state.value.matches(data.input, data.commands, options));
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        try state.check();
        try session.unchanged(data);
    }
    try std.testing.expect(emit_oom > 0);
    // Probe the complete base+alternate graph, including simultaneous output
    // ownership. Its observed peak is the quota oracle, not a size formula.
    var graph_probe = std.testing.FailingAllocator.init(allocator, .{});
    try graph(C, graph_probe.allocator(), data, session.options, session.physical_baseline, expected, session.baseline_stats, expected_stats);
    try std.testing.expectEqual(graph_probe.allocated_bytes, graph_probe.freed_bytes);
    var graph_oom: usize = 0;
    for (0..graph_probe.alloc_index + 1) |fail_index| {
        var heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index });
        graph(C, heap.allocator(), data, session.options, session.physical_baseline, expected, session.baseline_stats, expected_stats) catch |err| {
            try std.testing.expectEqual(error.OutOfMemory, err);
            try std.testing.expect(heap.has_induced_failure);
            graph_oom += 1;
        };
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        try session.unchanged(data);
    }
    var unrestricted = WorkingAllocator.init(allocator, std.math.maxInt(usize));
    try graph(C, unrestricted.allocator(), data, session.options, session.physical_baseline, expected, session.baseline_stats, expected_stats);
    try std.testing.expectEqual(@as(usize, 0), unrestricted.live);
    const peak = unrestricted.peak;
    try std.testing.expect(peak > 0);
    var exact = WorkingAllocator.init(allocator, peak);
    try graph(C, exact.allocator(), data, session.options, session.physical_baseline, expected, session.baseline_stats, expected_stats);
    try std.testing.expectEqual(peak, exact.peak);
    try std.testing.expectEqual(@as(usize, 0), exact.live);
    try std.testing.expect(!exact.hit_limit);
    var short = WorkingAllocator.init(allocator, peak - 1);
    try std.testing.expectError(error.OutOfMemory, graph(C, short.allocator(), data, session.options, session.physical_baseline, expected, session.baseline_stats, expected_stats));
    try std.testing.expect(short.hit_limit);
    try std.testing.expect(short.peak < peak);
    try std.testing.expectEqual(@as(usize, 0), short.live);
    try std.testing.expectEqualSlices(u32, &common_frequencies, &session.common.value.command_frequencies);
    try std.testing.expectEqualSlices(u4, &common_lengths, &session.common.value.command_lengths);
    try std.testing.expectEqualSlices(u32, &old_distance_frequencies, &session.common.value.distance_frequencies);
    try std.testing.expectEqualSlices(u4, &old_distance_lengths, &session.common.value.distance_lengths);
    try std.testing.expectEqual(old_payload, session.literal.value.payload_bits);
    try std.testing.expectEqual(old_header, session.literal.value.header_bits);
    try session.unchanged(data);
    std.debug.print("parameter_pair resources init_allocations={d} init_oom={d} emit_allocations={d} emit_oom={d} graph_allocations={d} graph_oom={d} peak={d}\n", .{ init_allocations, init_oom, emission_probe.alloc_index, emit_oom, graph_probe.alloc_index, graph_oom, peak });
}

fn againstGraph(comptime C: type, allocator: std.mem.Allocator, data: fixtures.Fixture, options: C.Options, incumbent: []const u8, local: *const oracle.LocalWinner(C)) !void {
    const initial = fixtures.stats(C.Stats, data);
    var stats = initial;
    const result = C.against(allocator, data.input, data.commands, &stats, options, incumbent) catch |err| {
        try std.testing.expectEqualDeep(initial, stats);
        return err;
    };
    const wire = result orelse return error.TestUnexpectedResult;
    defer allocator.free(wire);
    try std.testing.expectEqualSlices(u8, local.wire(), wire);
    try std.testing.expectEqualDeep(local.stats(), stats);
}

pub fn against(comptime C: type) !void {
    const allocator = std.testing.allocator;
    const data = try fixtures.rich(allocator, 129, true);
    defer data.deinit(allocator);
    const options: C.Options = .{ .use_recent_distances = true, .distance_parameters = distance.Parameters.init(0, 0), .window_bits = 16 };
    const local = try oracle.LocalWinner(C).init(allocator, data, options);
    defer local.deinit(allocator);
    const incumbent = try allocator.alloc(u8, local.wire().len + 1);
    defer allocator.free(incumbent);
    @memset(incumbent, 0x47);
    const input_before = try allocator.dupe(u8, data.input);
    defer allocator.free(input_before);
    const commands_before = try allocator.dupe(fixtures.Command, data.commands);
    defer allocator.free(commands_before);
    var probe = std.testing.FailingAllocator.init(allocator, .{});
    try againstGraph(C, probe.allocator(), data, options, incumbent, &local);
    try std.testing.expectEqual(probe.allocated_bytes, probe.freed_bytes);
    try std.testing.expect(probe.alloc_index > 0);
    var oom: usize = 0;
    for (0..probe.alloc_index) |fail_index| {
        for ([_]usize{ 512, 0 }) |event_limit| {
            var heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index });
            var profile: C.Profile = .{ .request = .{ .event_limit = event_limit } };
            const initial = fixtures.stats(C.Stats, data);
            var stats = initial;
            if (C.againstProfile(std.testing.io, heap.allocator(), data.input, data.commands, &stats, options, incumbent, &profile)) |result| {
                if (result) |wire| heap.allocator().free(wire);
                return error.TestUnexpectedResult;
            } else |err| try std.testing.expectEqual(error.OutOfMemory, err);
            try std.testing.expect(heap.has_induced_failure);
            try std.testing.expectEqualDeep(initial, stats);
            try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
            try std.testing.expectEqual(@as(usize, 0), profile.depth);
            try std.testing.expectEqual(@as(usize, 1), profile.parameter_pairs);
            try std.testing.expectEqual(@as(usize, 0), profile.parameter_physical_emits);
            try std.testing.expectEqual(@as(usize, 0), profile.parameter_skipped_pair_emits);
            try std.testing.expect(profile.parameter_counted_candidates <= profile.evaluation_attempts);
            if (event_limit == 0) {
                try std.testing.expectEqual(@as(usize, 0), profile.event_count);
                try std.testing.expect(profile.events_truncated);
            } else {
                const recorded_error = for (profile.recordedEvents()) |event| {
                    if (std.mem.eql(u8, event.error_name, "OutOfMemory")) break true;
                } else false;
                try std.testing.expect(recorded_error);
            }
            try data.checkGuards();
            try std.testing.expectEqualSlices(u8, input_before, data.input);
            for (commands_before, data.commands) |old, current| try std.testing.expectEqualDeep(old, current);
            oom += 1;
        }
    }
    var unrestricted = WorkingAllocator.init(allocator, std.math.maxInt(usize));
    try againstGraph(C, unrestricted.allocator(), data, options, incumbent, &local);
    const peak = unrestricted.peak;
    try std.testing.expect(peak > 0);
    try std.testing.expectEqual(@as(usize, 0), unrestricted.live);
    var exact = WorkingAllocator.init(allocator, peak);
    try againstGraph(C, exact.allocator(), data, options, incumbent, &local);
    try std.testing.expectEqual(peak, exact.peak);
    try std.testing.expectEqual(@as(usize, 0), exact.live);
    try std.testing.expect(!exact.hit_limit);
    var short = WorkingAllocator.init(allocator, peak - 1);
    var profile: C.Profile = .{ .request = .{ .max_total_working_memory = peak - 1 } };
    const initial = fixtures.stats(C.Stats, data);
    var stats = initial;
    try std.testing.expectError(error.OutOfMemory, C.againstProfile(std.testing.io, short.allocator(), data.input, data.commands, &stats, options, incumbent, &profile));
    try std.testing.expectEqualDeep(initial, stats);
    try std.testing.expect(short.hit_limit);
    try std.testing.expectEqual(@as(usize, 0), short.live);
    try std.testing.expectEqual(@as(usize, 0), profile.depth);
    try data.checkGuards();
    try std.testing.expectEqualSlices(u8, input_before, data.input);
    for (commands_before, data.commands) |old, current| try std.testing.expectEqualDeep(old, current);
    for (incumbent) |byte| try std.testing.expectEqual(@as(u8, 0x47), byte);
    std.debug.print("parameter_pair against allocations={d} profiled_oom={d} peak={d}\n", .{ probe.alloc_index, oom, peak });
}

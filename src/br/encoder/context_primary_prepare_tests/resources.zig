const std = @import("std");
const fixtures = @import("fixtures.zig");
const S = @import("support.zig");

pub const Metrics = struct {
    count_allocations: usize = 0,
    count_oom: usize = 0,
    late_common_ready_oom: usize = 0,
    emit_oom: usize = 0,
};

fn sweep(comptime Codec: type, data: fixtures.Fixture, metrics: *Metrics) !void {
    const allocator = std.testing.allocator;
    const saved_input = try allocator.dupe(u8, data.input);
    defer allocator.free(saved_input);
    const saved_commands = try allocator.dupe(Codec.Command, data.commands);
    defer allocator.free(saved_commands);
    var options: Codec.Options = .{ .use_recent_distances = true, .optimize_literal_tree_wire = true };
    var expected_common = Codec.Prepared.init(options, data.commands);
    options.prepared_common = &expected_common;
    var expected_state: Codec.State = .{};
    var expected_stats = S.initialStats(Codec.Stats, data.input, data.commands);
    try Codec.prepare(allocator, data.input, data.commands, &expected_stats, options, &expected_state);
    var plain_options = options;
    plain_options.prepared_common = null;
    var plain_stats = S.initialStats(Codec.Stats, data.input, data.commands);
    const expected_wire = try Codec.encode(allocator, data.input, data.commands, &plain_stats, plain_options);
    defer allocator.free(expected_wire);
    try std.testing.expectEqualDeep(plain_stats, expected_stats);
    for ([_]bool{ false, true }) |warm| {
        var probe = std.testing.FailingAllocator.init(allocator, .{});
        var probe_common = if (warm) expected_common else Codec.Prepared.init(options, data.commands);
        var probe_options = options;
        probe_options.prepared_common = &probe_common;
        var probe_state: Codec.State = .{};
        var probe_stats = S.initialStats(Codec.Stats, data.input, data.commands);
        try Codec.prepare(probe.allocator(), data.input, data.commands, &probe_stats, probe_options, &probe_state);
        try std.testing.expectEqualDeep(expected_stats, probe_stats);
        try std.testing.expectEqual(probe.allocated_bytes, probe.freed_bytes);
        metrics.count_allocations += probe.alloc_index;
        for (0..probe.alloc_index + 1) |fail_index| {
            var heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index });
            var common = if (warm) expected_common else Codec.Prepared.init(options, data.commands);
            if (!warm) S.poison(&common);
            var current = options;
            current.prepared_common = &common;
            var state: Codec.State = .{};
            state.copyFrom(&expected_state);
            var stats = S.initialStats(Codec.Stats, data.input, data.commands);
            if (Codec.prepare(heap.allocator(), data.input, data.commands, &stats, current, &state)) |_| {
                try std.testing.expect(!heap.has_induced_failure);
                try std.testing.expect(state.matches(data.input, current));
                try std.testing.expectEqualDeep(expected_stats, stats);
            } else |err| {
                try std.testing.expect(err == error.OutOfMemory);
                try std.testing.expect(heap.has_induced_failure);
                try std.testing.expect(!state.ready);
                metrics.count_oom += 1;
                if (!warm and common.ready) metrics.late_common_ready_oom += 1;
            }
            try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
            if (warm) try std.testing.expect(common.ready);
            if (common.ready) try S.sameCommon(&expected_common, &common, data.commands.len);
            // Recover using the same descriptor after either an early cold
            // failure or a late failure with valid common data already ready.
            stats = S.initialStats(Codec.Stats, data.input, data.commands);
            try Codec.prepare(allocator, data.input, data.commands, &stats, current, &state);
            try std.testing.expect(state.matches(data.input, current));
            try std.testing.expectEqualDeep(expected_stats, stats);
            try S.sameCommon(&expected_common, &common, data.commands.len);
            try S.immutable(saved_input, data.input, saved_commands, data.commands);
        }
    }
    var probe = std.testing.FailingAllocator.init(allocator, .{});
    const held_common = expected_common;
    var probe_stats = expected_stats;
    const probe_wire = try Codec.emit(probe.allocator(), data.input, data.commands, &probe_stats, options, &expected_state);
    try std.testing.expectEqualSlices(u8, expected_wire, probe_wire);
    probe.allocator().free(probe_wire);
    try std.testing.expectEqual(probe.allocated_bytes, probe.freed_bytes);
    for (0..probe.alloc_index + 1) |fail_index| {
        var heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index });
        var stats = expected_stats;
        if (Codec.emit(heap.allocator(), data.input, data.commands, &stats, options, &expected_state)) |wire| {
            defer heap.allocator().free(wire);
            try std.testing.expectEqualSlices(u8, expected_wire, wire);
            try std.testing.expect(!heap.has_induced_failure);
            try std.testing.expectEqualDeep(expected_stats, stats);
        } else |err| {
            try std.testing.expect(err == error.OutOfMemory);
            try std.testing.expect(heap.has_induced_failure);
            metrics.emit_oom += 1;
        }
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        try std.testing.expect(expected_state.matches(data.input, options));
        try S.sameCommon(&held_common, &expected_common, data.commands.len);
        try S.immutable(saved_input, data.input, saved_commands, data.commands);
    }
}

fn negative(comptime Codec: type) !void {
    const allocator = std.testing.allocator;
    const data = try fixtures.tiny(allocator, 5);
    defer data.deinit(allocator);
    const saved_input = try allocator.dupe(u8, data.input);
    defer allocator.free(saved_input);
    const saved_commands = try allocator.dupe(Codec.Command, data.commands);
    defer allocator.free(saved_commands);
    const base: Codec.Options = .{ .use_recent_distances = true };
    var good_common = Codec.Prepared.init(base, data.commands);
    var good = base;
    good.prepared_common = &good_common;
    var state: Codec.State = .{};
    var stats = S.initialStats(Codec.Stats, data.input, data.commands);
    try Codec.prepare(allocator, data.input, data.commands, &stats, good, &state);
    const saved_common = good_common;
    var ready: Codec.State = .{};
    ready.copyFrom(&state);
    for (0..4) |kind| {
        var bad = data.commands[0];
        if (kind == 0) bad.insert_start = data.input.len + 1;
        if (kind == 1) bad.insert_len = data.input.len + 1;
        if (kind == 2) bad.hq_encoding = .{ .command_symbol = 704, .distance_parameters = base.distance_parameters };
        var options = base;
        if (kind == 3) {
            options.initial_output_pos = std.math.maxInt(@TypeOf(options.initial_output_pos));
            bad.insert_start = data.input.len + 1;
        }
        var commands = [_]Codec.Command{bad};
        const immutable_bad = commands;
        var common = Codec.Prepared.init(options, &commands);
        options.prepared_common = &common;
        state.copyFrom(&ready);
        stats = .{};
        const expected = if (kind == 3) error.IntegerOverflow else error.InvalidBlockPlan;
        try std.testing.expectError(expected, Codec.prepare(allocator, data.input, &commands, &stats, options, &state));
        try std.testing.expect(!state.ready and !common.ready);
        try std.testing.expectEqualDeep(immutable_bad, commands);
        try S.sameCommon(&saved_common, &good_common, data.commands.len);
    }
    var empty_common = Codec.Prepared.init(base, &.{});
    var empty_options = base;
    empty_options.prepared_common = &empty_common;
    try std.testing.expectError(error.InvalidBlockPlan, Codec.prepare(allocator, "", &.{}, &stats, empty_options, &state));
    try std.testing.expect(!empty_common.ready and !state.ready);
    inline for (.{ "window_bits", "initial_output_pos", "compound_dictionary_size" }) |field| {
        var changed = good;
        @field(changed, field) += 1;
        state.copyFrom(&ready);
        try std.testing.expectError(error.InvalidBlockPlan, Codec.prepare(allocator, data.input, data.commands, &stats, changed, &state));
        try std.testing.expect(!state.ready);
        try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, changed, &ready));
        try S.sameCommon(&saved_common, &good_common, data.commands.len);
    }
    inline for (.{ "use_recent_distances", "optimize_same_last_distance", "write_stream_prefix", "final_meta_block" }) |field| {
        var changed = good;
        @field(changed, field) = !@field(changed, field);
        state.copyFrom(&ready);
        try std.testing.expectError(error.InvalidBlockPlan, Codec.prepare(allocator, data.input, data.commands, &stats, changed, &state));
        try std.testing.expect(!state.ready);
        try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, changed, &ready));
    }
    for (0..4) |index| {
        var changed = good;
        changed.starting_last_distances[index] += 1;
        state.copyFrom(&ready);
        try std.testing.expectError(error.InvalidBlockPlan, Codec.prepare(allocator, data.input, data.commands, &stats, changed, &state));
        try std.testing.expect(!state.ready);
        try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, changed, &ready));
    }
    for (0..4) |kind| {
        var changed = good;
        if (kind == 0) changed.distance_parameters = @import("../distance.zig").Parameters.init(0, 0);
        if (kind == 1) changed.metadata = "invalid counted metadata";
        if (kind == 2) changed.prepared_common = null;
        if (kind == 3) changed.large_window = true;
        state.copyFrom(&ready);
        try std.testing.expectError(error.InvalidBlockPlan, Codec.prepare(allocator, data.input, data.commands, &stats, changed, &state));
        try std.testing.expect(!state.ready);
        try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, changed, &ready));
    }
    const other_commands = try allocator.dupe(Codec.Command, data.commands);
    defer allocator.free(other_commands);
    state.copyFrom(&ready);
    try std.testing.expectError(error.InvalidBlockPlan, Codec.prepare(allocator, data.input, other_commands, &stats, good, &state));
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, other_commands, &stats, good, &ready));
    const other_input = try allocator.dupe(u8, data.input);
    defer allocator.free(other_input);
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, other_input, data.commands, &stats, good, &ready));
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input[0..4], data.commands, &stats, good, &ready));
    state.copyFrom(&ready);
    try std.testing.expectError(error.InvalidBlockPlan, Codec.prepare(allocator, data.input[0..4], data.commands, &stats, good, &state));
    try std.testing.expect(!state.ready);
    state.ready = false;
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, good, &state));
    try S.sameCommon(&saved_common, &good_common, data.commands.len);
    try S.immutable(saved_input, data.input, saved_commands, data.commands);
}

pub fn check(comptime Codec: type) !Metrics {
    const allocator = std.testing.allocator;
    var metrics: Metrics = .{};
    const simple = try fixtures.ordinary(allocator, 4, true);
    defer simple.deinit(allocator);
    try sweep(Codec, simple, &metrics);
    const complex = try fixtures.ordinary(allocator, 160, false);
    defer complex.deinit(allocator);
    try sweep(Codec, complex, &metrics);
    const exact = try fixtures.exact(allocator, 160);
    defer exact.deinit(allocator);
    try sweep(Codec, exact, &metrics);
    try negative(Codec);
    return metrics;
}

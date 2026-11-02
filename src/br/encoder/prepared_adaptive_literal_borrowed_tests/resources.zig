const std = @import("std");
const fixtures = @import("../prepared_adaptive_literal_tests/fixtures.zig");
const checks = @import("../context_primary_prepare_tests/support.zig");

pub const Metrics = struct { init_allocations: usize = 0, init_oom: usize = 0, emit_oom: usize = 0 };

pub fn check(comptime Codec: type) !Metrics {
    const allocator = std.testing.allocator;
    const data = try fixtures.rich(allocator, 160);
    defer data.deinit(allocator);
    const options: Codec.Options = .{ .use_recent_distances = true, .adaptive_literal_split = &data.plan };
    var shared = try Codec.buildCommon(allocator, data.input, data.commands, options);
    const saved_shared = shared;
    const saved_input = try allocator.dupe(u8, data.input);
    defer allocator.free(saved_input);
    const saved_commands = try allocator.dupe(Codec.Command, data.commands);
    defer allocator.free(saved_commands);
    const saved_lengths = try allocator.dupe(u32, data.plan.lengths);
    defer allocator.free(saved_lengths);
    const saved_types = try allocator.dupe(u8, data.plan.types);
    defer allocator.free(saved_types);
    var prior = try Codec.prepareBorrowed(allocator, data.input, data.commands, options, &shared);
    defer prior.deinit(allocator);
    var expected_stats = fixtures.stats(Codec.Stats, data);
    const expected = try Codec.encode(allocator, data.input, data.commands, &expected_stats, options);
    defer allocator.free(expected);
    var probe = std.testing.FailingAllocator.init(allocator, .{});
    {
        var state = try Codec.prepareBorrowed(probe.allocator(), data.input, data.commands, options, &shared);
        defer state.deinit(probe.allocator());
        try std.testing.expectEqual(expected.len, state.wire_len);
        try std.testing.expect(state.commonPlan() == &shared);
    }
    try std.testing.expect(probe.alloc_index > 0);
    try std.testing.expectEqual(probe.allocated_bytes, probe.freed_bytes);
    var metrics: Metrics = .{ .init_allocations = probe.alloc_index };
    for (0..probe.alloc_index + 1) |index| {
        var heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = index });
        if (Codec.prepareBorrowed(heap.allocator(), data.input, data.commands, options, &shared)) |value| {
            var state = value;
            defer state.deinit(heap.allocator());
            try std.testing.expect(!heap.has_induced_failure);
            try std.testing.expect(state.commonPlan() == &shared);
        } else |err| {
            try std.testing.expect(err == error.OutOfMemory and heap.has_induced_failure);
            metrics.init_oom += 1;
        }
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        try checks.sameCommon(&saved_shared, &shared, data.commands.len);
        try std.testing.expect(prior.commonPlan() == &shared and prior.key.matches(data.input, data.commands, options));
    }
    var emit_probe = std.testing.FailingAllocator.init(allocator, .{});
    {
        var stats = fixtures.stats(Codec.Stats, data);
        const wire = try Codec.emit(emit_probe.allocator(), data.input, data.commands, &stats, options, &prior);
        defer emit_probe.allocator().free(wire);
        try std.testing.expectEqualSlices(u8, expected, wire);
    }
    for (0..emit_probe.alloc_index + 1) |index| {
        var heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = index });
        var stats = fixtures.stats(Codec.Stats, data);
        if (Codec.emit(heap.allocator(), data.input, data.commands, &stats, options, &prior)) |wire| {
            defer heap.allocator().free(wire);
            try std.testing.expectEqualSlices(u8, expected, wire);
            try std.testing.expectEqualDeep(expected_stats, stats);
        } else |err| {
            try std.testing.expect(err == error.OutOfMemory and heap.has_induced_failure);
            metrics.emit_oom += 1;
        }
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        try checks.sameCommon(&saved_shared, &shared, data.commands.len);
    }
    try std.testing.expectEqualSlices(u8, saved_input, data.input);
    try std.testing.expectEqualSlices(u32, saved_lengths, data.plan.lengths);
    try std.testing.expectEqualSlices(u8, saved_types, data.plan.types);
    for (saved_commands, data.commands) |before, after| try std.testing.expectEqualDeep(before, after);
    return metrics;
}

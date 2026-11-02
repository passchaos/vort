const std = @import("std");
const fixtures = @import("fixtures.zig");

pub const Metrics = struct { init_allocations: usize = 0, init_oom: usize = 0, emit_oom: usize = 0 };

pub fn check(comptime Codec: type) !Metrics {
    const allocator = std.testing.allocator;
    const data = try fixtures.rich(allocator, 160);
    defer data.deinit(allocator);
    const input = try allocator.dupe(u8, data.input);
    defer allocator.free(input);
    const commands = try allocator.dupe(Codec.Command, data.commands);
    defer allocator.free(commands);
    const lengths = try allocator.dupe(u32, data.plan.lengths);
    defer allocator.free(lengths);
    const types = try allocator.dupe(u8, data.plan.types);
    defer allocator.free(types);
    const options: Codec.Options = .{ .use_recent_distances = true, .adaptive_literal_split = &data.plan };
    var expected_stats = fixtures.stats(Codec.Stats, data);
    const expected = try Codec.encode(allocator, data.input, data.commands, &expected_stats, options);
    defer allocator.free(expected);
    var prior = try Codec.prepare(allocator, data.input, data.commands, options);
    defer prior.deinit(allocator);
    const prior_key = prior.key;
    const prior_symbols = try allocator.dupe(u16, prior.split_code.type_model.symbols);
    defer allocator.free(prior_symbols);

    var probe = std.testing.FailingAllocator.init(allocator, .{});
    {
        var state = try Codec.prepare(probe.allocator(), data.input, data.commands, options);
        defer state.deinit(probe.allocator());
        try std.testing.expectEqual(expected.len, state.wire_len);
    }
    try std.testing.expect(probe.alloc_index > 0);
    try std.testing.expectEqual(probe.allocated_bytes, probe.freed_bytes);
    var metrics: Metrics = .{ .init_allocations = probe.alloc_index };
    for (0..probe.alloc_index + 1) |fail_index| {
        var heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index });
        if (Codec.prepare(heap.allocator(), data.input, data.commands, options)) |value| {
            var state = value;
            defer state.deinit(heap.allocator());
            try std.testing.expect(!heap.has_induced_failure);
            try std.testing.expectEqual(expected.len, state.wire_len);
        } else |err| {
            try std.testing.expect(err == error.OutOfMemory);
            try std.testing.expect(heap.has_induced_failure);
            metrics.init_oom += 1;
        }
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        try std.testing.expect(prior.common.ready);
        try std.testing.expectEqualDeep(prior_key, prior.key);
        try std.testing.expectEqualSlices(u16, prior_symbols, prior.split_code.type_model.symbols);
    }
    var emit_probe = std.testing.FailingAllocator.init(allocator, .{});
    {
        var stats = fixtures.stats(Codec.Stats, data);
        const wire = try Codec.emit(emit_probe.allocator(), data.input, data.commands, &stats, options, &prior);
        defer emit_probe.allocator().free(wire);
        try std.testing.expectEqualSlices(u8, expected, wire);
        try std.testing.expectEqualDeep(expected_stats, stats);
    }
    try std.testing.expectEqual(emit_probe.allocated_bytes, emit_probe.freed_bytes);
    for (0..emit_probe.alloc_index + 1) |fail_index| {
        var heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index });
        var stats = fixtures.stats(Codec.Stats, data);
        if (Codec.emit(heap.allocator(), data.input, data.commands, &stats, options, &prior)) |wire| {
            defer heap.allocator().free(wire);
            try std.testing.expect(!heap.has_induced_failure);
            try std.testing.expectEqualSlices(u8, expected, wire);
            try std.testing.expectEqualDeep(expected_stats, stats);
        } else |err| {
            try std.testing.expect(err == error.OutOfMemory);
            try std.testing.expect(heap.has_induced_failure);
            metrics.emit_oom += 1;
        }
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
        try std.testing.expect(prior.common.ready and prior.key.matches(data.input, data.commands, options));
    }
    try std.testing.expectEqualSlices(u8, input, data.input);
    try std.testing.expectEqualSlices(u32, lengths, data.plan.lengths);
    try std.testing.expectEqualSlices(u8, types, data.plan.types);
    for (commands, data.commands) |before, after| try std.testing.expectEqualDeep(before, after);
    return metrics;
}

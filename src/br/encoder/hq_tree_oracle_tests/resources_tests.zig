const std = @import("std");
const tree = @import("../hq_tree.zig");
const scalar = @import("oracle.zig");
const WorkingAllocator = @import("../../../io/working_allocator.zig").WorkingAllocator;
const allocator = std.testing.allocator;

test "Brotli HQ BT oracle exact cold quota move and independent fork requested bytes" {
    const input = "abcd" ** 8;
    const source = try tree.Source.init("", input, 10, 0);
    var options: tree.HqOptions = .{ .search_depth = 8, .nice_len = 64 };
    const expected = scalar.coldBytes(0, input.len, 1008, 8);
    try std.testing.expectEqual(expected, try tree.requiredWorkingMemory(source, options));
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    options.max_working_memory = expected - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, tree.Matcher.init(failing.allocator(), source, options, null));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    options.max_working_memory = expected;
    var budget = WorkingAllocator.init(allocator, expected);
    var profile: tree.HqProfile = .{};
    var original = try tree.Matcher.init(budget.allocator(), source, options, &profile);
    var moved = original;
    original = undefined;
    defer moved.deinit(budget.allocator());
    try std.testing.expectEqual(expected, budget.live);
    try std.testing.expectEqual(expected, budget.peak);
    try std.testing.expectEqual(expected, profile.peak_working_memory);
    try moved.advanceTo(8);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, moved.fork(failing.allocator(), 2 * expected - 1, null));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    budget.limit = 2 * expected;
    {
        var clone = try moved.fork(budget.allocator(), 2 * expected, null);
        defer clone.deinit(budget.allocator());
        try std.testing.expectEqual(2 * expected, budget.live);
        try std.testing.expectEqual(2 * expected, budget.peak);
        try std.testing.expect(clone.nodes.ptr != moved.nodes.ptr and clone.heads2.ptr != moved.heads2.ptr and clone.candidates.ptr != moved.candidates.ptr);
        const left = try moved.getMatches();
        const right = try clone.getMatches();
        try std.testing.expectEqualDeep(left.slice(), right.slice());
        try (scalar.Data{ .history = "", .input = input, .window = 1008, .frame_offset = 0 }).validateFrontier(8, left.slice());
        _ = try clone.getMatches();
        try std.testing.expectEqual(@as(usize, 9), moved.position());
        try std.testing.expectEqual(@as(usize, 10), clone.position());
    }
    try std.testing.expectEqual(expected, budget.live);
    _ = try moved.getMatches();
}

test "Brotli HQ BT oracle rebind peak below quota OOM detached checkpoint and poisoned old source" {
    var old_bytes: [32]u8 = undefined;
    @memcpy(&old_bytes, "abcd" ** 8);
    const retained = old_bytes;
    const input = "abcd" ** 64;
    const head_bytes = 3 * 65536 * 4;
    const record_bytes = 2 * @sizeOf(usize);
    const initial_bytes = head_bytes + 32 * 16 + 17 * record_bytes;
    const final_bytes = head_bytes + 512 * 16 + 255 * record_bytes;
    // Nodes grow first, with old nodes resident; frontier then grows while its
    // old allocation is still resident. Freeze this public allocation ordering.
    const expected_peak = @max(initial_bytes + 512 * 16, head_bytes + 512 * 16 + 17 * record_bytes + 255 * record_bytes);
    var budget = WorkingAllocator.init(allocator, expected_peak);
    var profile: tree.HqProfile = .{};
    var options: tree.HqOptions = .{ .search_depth = 8, .nice_len = 64, .max_working_memory = initial_bytes };
    var matcher = try tree.Matcher.init(budget.allocator(), try tree.Source.init("", &old_bytes, 10, 0), options, &profile);
    defer matcher.deinit(budget.allocator());
    try matcher.advanceTo(old_bytes.len);
    matcher.detachSource();
    @memset(&old_bytes, 0xa5);
    const next = try tree.Source.init(&retained, input, 10, retained.len);
    options.search_depth = 128;
    options.nice_len = 257;
    options.max_working_memory = expected_peak - 1;
    var failing = std.testing.FailingAllocator.init(budget.allocator(), .{ .fail_index = 0 });
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, matcher.rebindSource(failing.allocator(), next, options, &profile));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    try std.testing.expectEqual(initial_bytes, matcher.workingBytes());
    try std.testing.expectEqual(@as(usize, 32), matcher.position());
    try std.testing.expectError(error.InvalidBlockPlan, matcher.getMatches());
    options.max_working_memory = expected_peak;
    try std.testing.expectError(error.OutOfMemory, matcher.rebindSource(failing.allocator(), next, options, &profile));
    try std.testing.expectEqual(initial_bytes, matcher.workingBytes());
    try std.testing.expectError(error.InvalidBlockPlan, matcher.getMatches());
    try matcher.rebindSource(budget.allocator(), next, options, &profile);
    try std.testing.expectEqual(final_bytes, matcher.workingBytes());
    try std.testing.expectEqual(final_bytes, budget.live);
    try std.testing.expectEqual(expected_peak, budget.peak);
    try std.testing.expectEqual(expected_peak, profile.peak_working_memory);
    const actual = try matcher.getMatches();
    const data: scalar.Data = .{ .history = &retained, .input = input, .window = 1008, .frame_offset = retained.len };
    const expected = data.best(0);
    try data.validateFrontier(0, actual.slice());
    try std.testing.expectEqual(expected.length, actual.best().length);
    try std.testing.expectEqual(expected.distance, actual.best().distance);
    try std.testing.expectEqual(@as(u64, 0), profile.history_seed_positions);
}

const AllocationGraph = struct {
    fn run(backing: std.mem.Allocator) !void {
        const first = "abcd" ** 8;
        const second = "abcd" ** 64;
        var options: tree.HqOptions = .{ .search_depth = 8, .nice_len = 64 };
        var matcher = try tree.Matcher.init(backing, try tree.Source.init("", first, 10, 0), options, null);
        defer matcher.deinit(backing);
        try matcher.advanceTo(8);
        {
            var fork = try matcher.fork(backing, 2 * matcher.workingBytes(), null);
            defer fork.deinit(backing);
            const left = try matcher.getMatches();
            const right = try fork.getMatches();
            try std.testing.expectEqualDeep(left.slice(), right.slice());
        }
        try matcher.advanceTo(first.len);
        options.search_depth = 128;
        options.nice_len = 257;
        try matcher.rebindSource(backing, try tree.Source.init(first, second, 10, first.len), options, null);
        const actual = try matcher.getMatches();
        try (scalar.Data{ .history = first, .input = second, .window = 1008, .frame_offset = first.len }).validateFrontier(0, actual.slice());
    }
};

test "Brotli HQ BT oracle every bounded init fork and rebind allocation failure releases storage" {
    try std.testing.checkAllAllocationFailures(allocator, AllocationGraph.run, .{});
}

const std = @import("std");
const tree = @import("../hq_tree.zig");
const types = @import("types.zig");

test "Brotli HQ Large Window resource geometry rejects unrepresentable or zero-budget storage before allocation" {
    // Metadata-only spans are never read: requirement calculation examines
    // lengths, and the zero budget must reject init before its first allocation.
    const bytes: [*]const u8 = @ptrFromInt(1);
    for (25..31) |bits| {
        const window: usize = (@as(usize, 1) << @intCast(bits)) - 16;
        const source = try tree.Source.initWithFormat(bytes[0..window], bytes[0..types.max_input_len], @intCast(bits), window, .large_window);
        const expected: u64 = (@as(u64, 1) << @intCast(bits)) * 16 + 3 * 65536 * 4 + 17 * @sizeOf(tree.Match);
        const options: tree.HqOptions = .{ .search_depth = 8, .max_working_memory = 0 };
        if (expected > std.math.maxInt(usize)) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, tree.requiredWorkingMemory(source, options));
        } else {
            try std.testing.expectEqual(@as(usize, @intCast(expected)), try tree.requiredWorkingMemory(source, options));
        }
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, tree.Matcher.init(failing.allocator(), source, options, null));
        try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    }
}

test "Brotli HQ Large Window small sources retain small rings and explicit format across rebind" {
    const first = "abcdefghabcdefgh";
    const second = "abcdefgh" ** 32;
    for (25..31) |bits| {
        const source = try tree.Source.initWithFormat("", first, @intCast(bits), 0, .large_window);
        const options: tree.HqOptions = .{ .search_depth = 64, .nice_len = 257 };
        const required = try tree.requiredWorkingMemory(source, options);
        try std.testing.expectEqual(@as(usize, 3 * 65536 * 4 + 16 * 16 + 15 * @sizeOf(tree.Match)), required);
        var matcher = try tree.Matcher.init(std.testing.allocator, source, options, null);
        defer matcher.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 16), matcher.cycle);
        try matcher.advanceTo(first.len);
        try matcher.rebindSource(std.testing.allocator, try tree.Source.initWithFormat(first, second, @intCast(bits), first.len, .large_window), options, null);
        const best = (try matcher.find()).best();
        try std.testing.expectEqual(second.len, best.length);
        try std.testing.expectEqual(@as(usize, 8), best.distance);
    }
    var matcher = try tree.Matcher.init(std.testing.allocator, try tree.Source.init("", first, 10, 0), tree.HqOptions{}, null);
    defer matcher.deinit(std.testing.allocator);
    try matcher.advanceTo(first.len);
    try std.testing.expectError(error.InvalidBlockPlan, matcher.rebindSource(std.testing.allocator, try tree.Source.initWithFormat(first, second, 10, first.len, .large_window), tree.HqOptions{}, null));
    try std.testing.expectError(error.InvalidBlockPlan, matcher.find());
}

test "Brotli HQ Large Window standard source cannot borrow a large-format window" {
    var source = try tree.Source.initWithFormat("", "abcdabcd", 25, 0, .large_window);
    source.format = .standard;
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidBlockPlan, tree.Matcher.init(failing.allocator(), source, tree.HqOptions{}, null));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
}

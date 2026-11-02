//! Explicit ordinal-array failure sites and retained-workspace transitions.
const std = @import("std");

fn expectPlan(comptime Codec: type, expected: *const Codec.OptimalScratch, actual: *const Codec.OptimalScratch) !void {
    try std.testing.expectEqualSlices(Codec.Token, expected.tokens.items, actual.tokens.items);
    try std.testing.expectEqualSlices(Codec.Token, expected.steps.items, actual.steps.items);
    try std.testing.expectEqualSlices(usize, expected.costs.items, actual.costs.items);
}

fn makeAdmitted(allocator: std.mem.Allocator) ![]u8 {
    const input = try allocator.alloc(u8, 16384);
    for (0..input.len / 8) |record| {
        const position = record * 8;
        @memcpy(input[position..][0..3], "abc");
        input[position + 3] = @intCast(record % 251);
        @memcpy(input[position + 4 ..][0..4], "ZZZZ");
    }
    return input;
}

fn arrayFailures(comptime Codec: type) !void {
    const input = try makeAdmitted(std.testing.allocator);
    defer std.testing.allocator.free(input);
    const before = try std.testing.allocator.dupe(u8, input);
    defer std.testing.allocator.free(before);
    const options: Codec.GreedyOptions = .{ .window_len = input.len, .min_match = 4, .max_chain = 128, .max_candidates = 8 };
    var original: Codec.OptimalScratch = .{};
    defer original.deinit(std.testing.allocator);
    const expected_stats = try Codec.original(&original, std.testing.allocator, input, options);
    var ordinals_failed = false;
    var four_prev_failed = false;
    for (0..10) |failure_index| {
        var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure_index });
        var current: Codec.OptimalScratch = .{};
        var deinitialized = false;
        defer if (!deinitialized) current.deinit(heap.allocator());
        if (Codec.optimized(&current, heap.allocator(), input, options)) |stats| {
            try std.testing.expectEqualDeep(expected_stats, stats);
            try expectPlan(Codec, &original, &current);
        } else |err| {
            try std.testing.expectEqual(error.OutOfMemory, err);
            try std.testing.expect(heap.has_induced_failure);
            if (current.compact_prev.items.len == input.len) {
                if (current.ordinal.ordinals.capacity == 0) ordinals_failed = true;
                if (current.ordinal.ordinals.items.len == input.len and current.ordinal.four_prev.capacity == 0) four_prev_failed = true;
            }
        }
        heap.fail_index = std.math.maxInt(usize);
        const retry = try Codec.optimized(&current, heap.allocator(), input, options);
        try std.testing.expectEqual(input.len, current.ordinal.ordinals.items.len);
        try std.testing.expectEqual(input.len, current.ordinal.four_prev.items.len);
        try std.testing.expectEqualDeep(expected_stats, retry);
        try expectPlan(Codec, &original, &current);
        try std.testing.expectEqualSlices(u8, before, input);
        current.deinit(heap.allocator());
        deinitialized = true;
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
    }
    try std.testing.expect(ordinals_failed and four_prev_failed);
}

fn admissionReuse(comptime Codec: type) !void {
    const admitted = try makeAdmitted(std.testing.allocator);
    defer std.testing.allocator.free(admitted);
    const before = try std.testing.allocator.dupe(u8, admitted);
    defer std.testing.allocator.free(before);
    const declined = "a" ** 256;
    var original: Codec.OptimalScratch = .{};
    defer original.deinit(std.testing.allocator);
    var current: Codec.OptimalScratch = .{};
    defer current.deinit(std.testing.allocator);
    const options: Codec.GreedyOptions = .{ .window_len = 32768, .min_match = 4, .max_chain = 128, .max_candidates = 8 };
    var capacities: [2]usize = undefined;
    var pointers: [2]usize = undefined;
    for ([_][]const u8{ admitted, declined, admitted }, 0..) |input, round| {
        const expected = try Codec.original(&original, std.testing.allocator, input, options);
        const actual = try Codec.optimized(&current, std.testing.allocator, input, options);
        try std.testing.expectEqualDeep(expected, actual);
        try expectPlan(Codec, &original, &current);
        var warm_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0, .resize_fail_index = 0 });
        try std.testing.expectEqualDeep(expected, try Codec.original(&original, warm_heap.allocator(), input, options));
        try std.testing.expectEqualDeep(expected, try Codec.optimized(&current, warm_heap.allocator(), input, options));
        try expectPlan(Codec, &original, &current);
        try std.testing.expectEqual(@as(usize, 0), warm_heap.alloc_index);
        try std.testing.expectEqual(@as(usize, 0), warm_heap.resize_index);
        try std.testing.expect(!warm_heap.has_induced_failure);
        try std.testing.expectEqualSlices(u8, before, admitted);
        if (round == 0) {
            try std.testing.expectEqual(input.len, current.ordinal.ordinals.items.len);
            try std.testing.expectEqual(input.len, current.ordinal.four_prev.items.len);
            try std.testing.expectEqual(@as(u16, 1), current.ordinal.ordinals.items[0]);
            capacities = .{ current.ordinal.ordinals.capacity, current.ordinal.four_prev.capacity };
            pointers = .{ @intFromPtr(current.ordinal.ordinals.items.ptr), @intFromPtr(current.ordinal.four_prev.items.ptr) };
        } else {
            try std.testing.expectEqual(capacities[0], current.ordinal.ordinals.capacity);
            try std.testing.expectEqual(capacities[1], current.ordinal.four_prev.capacity);
            try std.testing.expectEqual(pointers[0], @intFromPtr(current.ordinal.ordinals.items.ptr));
            try std.testing.expectEqual(pointers[1], @intFromPtr(current.ordinal.four_prev.items.ptr));
            if (round == 1) {
                @memset(current.ordinal.ordinals.items, std.math.maxInt(u16));
                @memset(current.ordinal.four_prev.items, std.math.maxInt(u16));
            } else {
                try std.testing.expectEqual(input.len, current.ordinal.ordinals.items.len);
                try std.testing.expectEqual(input.len, current.ordinal.four_prev.items.len);
                // The last three bytes have no complete anchor and may retain
                // the sentinel. At least the repeated first anchor is rebuilt.
                try std.testing.expectEqual(@as(u16, 1), current.ordinal.ordinals.items[0]);
            }
        }
    }
}

pub fn check(comptime Codec: type) !void {
    try arrayFailures(Codec);
    try admissionReuse(Codec);
}

const std = @import("std");
const lazy2 = @import("../lazy2.zig");
const source_mod = @import("../controlled_source.zig");
const rep = @import("rep.zig");
const controls = @import("../../encode/controls.zig");
const chain = @import("chain.zig");

pub fn replay(allocator: std.mem.Allocator, source: source_mod.Source, plan: anytype, initial: rep.Repeats) ![]u8 {
    const output = try allocator.alloc(u8, source.block.len);
    errdefer allocator.free(output);
    var end: usize = 0;
    var repeats = initial;
    for (plan.records, plan.offset_values) |record, value| {
        const start = end + record.literal_len;
        @memcpy(output[end..start], source.block[end..start]);
        const choice = try rep.resolve(record.literal_len, value, repeats);
        try std.testing.expectEqual(record.distance, choice.distance);
        for (0..record.match_len) |i| {
            const absolute = source.prefixLen() + start + i - record.distance;
            output[start + i] = if (absolute < source.prefixLen()) source.byteAt(absolute) else output[absolute - source.prefixLen()];
        }
        end = start + record.match_len;
        try std.testing.expectEqual(record.match_end, end);
        repeats = choice.repeats;
    }
    @memcpy(output[end..], source.block[end..]);
    try std.testing.expectEqual(plan.final_repeated_offsets, repeats);
    return output;
}

test "Zstd HQ lazy2 actually defers by two bytes under sequence costs" {
    const source = source_mod.Source.init("abcQcdefgh", "", "abcdefgh", 1024);
    var profile: controls.Profile = .{};
    const parameters: lazy2.Parameters = .{ .strategy = .lazy2, .profile = &profile };
    const plan = try lazy2.planAlloc(std.testing.allocator, source, parameters);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), plan.records.len);
    try std.testing.expectEqual(@as(usize, 2), plan.records[0].literal_len);
    try std.testing.expectEqual(@as(usize, 6), plan.records[0].match_len);
    try std.testing.expectEqual(@as(u64, 2), profile.lazy_deferrals);
    const decoded = try replay(std.testing.allocator, source, plan, rep.initial_repeats);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, source.block, decoded);
}

test "Zstd HQ lazy2 exact budget below budget and allocation failures are bounded" {
    const source = source_mod.Source.init("abcQcdefgh", "", "abcdefgh", 1024);
    var parameters: lazy2.Parameters = .{ .strategy = .lazy2 };
    const required = try lazy2.requiredWorkingMemory(source, parameters);
    parameters.hq_options.max_working_memory = required;
    const plan = try lazy2.planAlloc(std.testing.allocator, source, parameters);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(required, plan.peak_working_memory);
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    parameters.hq_options.max_working_memory = required - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, lazy2.planAlloc(failing.allocator(), source, parameters));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    const Test = struct {
        fn run(allocator: std.mem.Allocator, bytes: source_mod.Source) !void {
            const result = try lazy2.planAlloc(allocator, bytes, .{ .strategy = .lazy2 });
            defer result.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{source});
}

fn growingPrefixes(dictionary: []u8, input: []const u8) usize {
    var end: usize = 0;
    var length = input.len;
    while (length >= 3) : (length -= 1) {
        @memcpy(dictionary[end..][0..length], input[0..length]);
        end += length;
        dictionary[end] = 255;
        end += 1;
    }
    return end;
}

test "Zstd HQ chain dynamic frontier preserves thirty second thirty third and nice forty records" {
    var input: [40]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @intCast(i + 1);
    var dictionary: [855]u8 = undefined;
    for ([_]usize{ 34, 35, 40 }) |maximum| {
        const dictionary_len = growingPrefixes(&dictionary, input[0..maximum]);
        const source = source_mod.Source.init(dictionary[0..dictionary_len], "", input[0..maximum], 1024);
        var profile: controls.Profile = .{};
        const original = try chain.Matcher.init(std.testing.allocator, source, .{ .search_depth = 64, .nice_len = @intCast(maximum) }, &profile);
        var moved = original;
        defer moved.deinit(std.testing.allocator);
        const matches = try moved.find();
        try std.testing.expectEqual(maximum - 2, matches.slice().len);
        var candidate: usize = 0;
        var length = maximum;
        while (length >= 3) : (length -= 1) {
            const expected = source.match(0, candidate, 3);
            const actual = matches.slice()[length - 3];
            try std.testing.expectEqual(expected.length, actual.length);
            try std.testing.expectEqual(expected.distance, actual.distance);
            candidate += length + 1;
        }
        try std.testing.expectEqual(maximum, matches.slice()[matches.len - 1].length);
        try std.testing.expectEqual(@as(u64, 1), profile.nice_stops);
    }
    const dictionary_len = growingPrefixes(&dictionary, &input);
    const source = source_mod.Source.init(dictionary[0..dictionary_len], "", &input, 1024);
    var limited = try chain.Matcher.init(std.testing.allocator, source, .{ .search_depth = 33, .nice_len = 40 }, null);
    defer limited.deinit(std.testing.allocator);
    const shorter = try limited.find();
    try std.testing.expectEqual(@as(usize, 33), shorter.len);
    try std.testing.expectEqual(@as(usize, 35), shorter.slice()[32].length);
}

test "Zstd HQ chain dynamic frontier exact quota below quota OOM and lazy cache include all records" {
    var input: [40]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @intCast(i + 1);
    var dictionary: [855]u8 = undefined;
    const dictionary_len = growingPrefixes(&dictionary, &input);
    const source = source_mod.Source.init(dictionary[0..dictionary_len], "", &input, 1024);
    var options: controls.HqOptions = .{ .search_depth = 64, .nice_len = 40 };
    const required = try chain.Matcher.requiredWorkingMemory(source, options);
    options.max_working_memory = required;
    var matcher = try chain.Matcher.init(std.testing.allocator, source, options, null);
    defer matcher.deinit(std.testing.allocator);
    try std.testing.expectEqual(required, matcher.workingBytes());
    try std.testing.expectEqual(@as(usize, 38), (try matcher.find()).len);
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    options.max_working_memory -= 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, chain.Matcher.init(failing.allocator(), source, options, null));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    const Test = struct {
        fn run(allocator: std.mem.Allocator, bytes: source_mod.Source) !void {
            var owner = try chain.Matcher.init(allocator, bytes, .{ .search_depth = 64, .nice_len = 40 }, null);
            defer owner.deinit(allocator);
            try std.testing.expectEqual(@as(usize, 38), (try owner.find()).len);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{source});
    var parameters: lazy2.Parameters = .{ .strategy = .lazy2, .hq_options = .{ .search_depth = 64, .nice_len = 40 } };
    const total = try lazy2.requiredWorkingMemory(source, parameters);
    parameters.hq_options.max_working_memory = total;
    const plan = try lazy2.planAlloc(std.testing.allocator, source, parameters);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(total, plan.peak_working_memory);
    try std.testing.expectEqual(@as(usize, 40), plan.records[0].match_len);
    try std.testing.expectEqual(@as(usize, 855), plan.records[0].distance);
    const decoded = try replay(std.testing.allocator, source, plan, rep.initial_repeats);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
    parameters.hq_options.max_working_memory = total - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, lazy2.planAlloc(failing.allocator(), source, parameters));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
}

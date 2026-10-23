const std = @import("std");
const block_plan = @import("block_plan.zig");
const limits = @import("../encode_options.zig");
const allocator = std.testing.allocator;
const Plan = block_plan.Plan;
const Record = block_plan.Record;

test "LZFSE plan splits long L and M into legal records with canonical dummy distances" {
    var literals: [40000]u8 = undefined;
    for (&literals, 0..) |*byte, index| byte.* = @truncate(index *% 73);
    for ([_]usize{ 1, 314, 315, 316, 630, 631, 40000 }) |literal_len| {
        for ([_]usize{ 0, 1, 2359, 2360, 4718, 4719, 7078 }) |match_len| {
            var plan = Plan.init(7);
            defer plan.deinit(allocator);
            try plan.append(allocator, literals[0..literal_len], match_len, if (match_len == 0) 1 else 7);
            try plan.validate();
            try std.testing.expectEqual(literal_len + match_len, plan.raw_size);
            try std.testing.expectEqualSlices(u8, literals[0..literal_len], plan.literals.items);
            var literal_count: usize = 0;
            var match_count: usize = 0;
            for (plan.records.items) |record| {
                try std.testing.expect(record.literal_len <= 315 and record.match_len <= 2359);
                try std.testing.expect(record.literal_len != 0 or record.match_len != 0);
                try std.testing.expectEqual(@as(u32, if (record.match_len == 0) 1 else 7), record.distance);
                literal_count += record.literal_len;
                match_count += record.match_len;
            }
            try std.testing.expectEqual(literal_len, literal_count);
            try std.testing.expectEqual(match_len, match_count);
        }
    }
    var plan = Plan.init(1);
    defer plan.deinit(allocator);
    try plan.append(allocator, &.{}, 2 * 2359 + 1, 1);
    try std.testing.expectEqualSlices(Record, &.{
        .{ .literal_len = 0, .match_len = 2359, .distance = 1 },
        .{ .literal_len = 0, .match_len = 2359, .distance = 1 },
        .{ .literal_len = 0, .match_len = 1, .distance = 1 },
    }, plan.records.items);
    try plan.validate();
}

test "LZFSE plan rejects invalid append fields and reach without consuming input" {
    var plan = Plan.init(0);
    defer plan.deinit(allocator);
    try plan.appendLiterals(allocator, "a");
    for ([_]struct { literals: []const u8, match_len: usize, distance: u32 }{
        .{ .literals = "", .match_len = 0, .distance = 1 },
        .{ .literals = "a", .match_len = 0, .distance = 0 },
        .{ .literals = "a", .match_len = 0, .distance = 2 },
        .{ .literals = "", .match_len = 4, .distance = 0 },
        .{ .literals = "", .match_len = 4, .distance = 2 },
        .{ .literals = "", .match_len = 4, .distance = limits.max_distance + 1 },
    }) |invalid| {
        try std.testing.expectError(error.InvalidLzfseStream, plan.append(allocator, invalid.literals, invalid.match_len, invalid.distance));
        try std.testing.expectEqual(@as(usize, 1), plan.raw_size);
        try std.testing.expectEqual(@as(usize, 1), plan.records.items.len);
        try std.testing.expectEqualStrings("a", plan.literals.items);
        try plan.validate();
    }
}

test "LZFSE plan validation rejects illegal record ranges dummy D and empty pairs" {
    for ([_]Record{
        .{ .literal_len = 316, .match_len = 0, .distance = 1 },
        .{ .literal_len = 1, .match_len = 2360, .distance = 1 },
        .{ .literal_len = 0, .match_len = 0, .distance = 1 },
        .{ .literal_len = 1, .match_len = 0, .distance = 0 },
        .{ .literal_len = 1, .match_len = 0, .distance = 2 },
        .{ .literal_len = 1, .match_len = 4, .distance = 0 },
        .{ .literal_len = 1, .match_len = 4, .distance = limits.max_distance + 1 },
        .{ .literal_len = 1, .match_len = 4, .distance = 2 },
    }) |record| {
        var plan = Plan.init(0);
        defer plan.deinit(allocator);
        try plan.records.append(allocator, record);
        try plan.literals.appendNTimes(allocator, 7, record.literal_len);
        plan.raw_size = @max(1, @as(usize, record.literal_len) + record.match_len);
        try std.testing.expectError(error.InvalidLzfseStream, plan.validate());
    }
    var empty = Plan.init(0);
    defer empty.deinit(allocator);
    try std.testing.expectError(error.InvalidLzfseStream, empty.validate());
}

test "LZFSE plan checks real maximum distance and history after preceding literals" {
    var plan = Plan.init(limits.max_distance - 1);
    defer plan.deinit(allocator);
    try plan.append(allocator, "a", 4, limits.max_distance);
    try plan.validate();
    plan.history_len -= 1;
    try std.testing.expectError(error.InvalidLzfseStream, plan.validate());
    plan.history_len = std.math.maxInt(usize);
    try plan.validate();
    try std.testing.expectError(error.InvalidLzfseStream, plan.append(allocator, &.{}, 4, limits.max_distance + 1));
    var overlap = Plan.init(0);
    defer overlap.deinit(allocator);
    try overlap.append(allocator, "z", 2359, 1);
    try overlap.validate();
}

test "LZFSE plan keeps padded literals within the exact 40000 byte cap" {
    const literals = [_]u8{7} ** 40001;
    for (39997..40001) |length| {
        var plan = Plan.init(0);
        defer plan.deinit(allocator);
        try plan.appendLiterals(allocator, literals[0..length]);
        try plan.validate();
        try std.testing.expectEqual(@as(usize, 40000), std.mem.alignForward(usize, plan.literals.items.len, 4));
    }
    var plan = Plan.init(0);
    defer plan.deinit(allocator);
    try plan.appendLiterals(allocator, literals[0..40000]);
    try std.testing.expectError(error.BlockPlanLimitExceeded, plan.appendLiterals(allocator, literals[40000..]));
    try std.testing.expectEqual(@as(usize, 40000), plan.raw_size);
    try plan.validate();
    var too_many = Plan.init(0);
    defer too_many.deinit(allocator);
    try std.testing.expectError(error.BlockPlanLimitExceeded, too_many.appendLiterals(allocator, &literals));
    try std.testing.expectEqual(@as(usize, 0), too_many.raw_size);
    try std.testing.expectEqual(@as(usize, 0), too_many.records.items.len);
}

test "LZFSE plan supports exactly 10000 records and the complete maximum raw size" {
    var plan = Plan.init(0);
    defer plan.deinit(allocator);
    for (0..10000) |_| try plan.append(allocator, "abcd", 2359, 1);
    try plan.validate();
    try std.testing.expectEqual(@as(usize, 10000), plan.records.items.len);
    try std.testing.expectEqual(@as(usize, 40000), plan.literals.items.len);
    try std.testing.expectEqual(limits.max_plan_raw_size, plan.raw_size);
    try std.testing.expectError(error.BlockPlanLimitExceeded, plan.append(allocator, &.{}, 1, 1));
    try plan.validate();
    plan.raw_size -= 1;
    try std.testing.expectError(error.InvalidLzfseStream, plan.validate());
    plan.raw_size = limits.max_plan_raw_size + 1;
    try std.testing.expectError(error.BlockPlanLimitExceeded, plan.validate());
    plan.raw_size = limits.max_plan_raw_size;
    try plan.records.append(allocator, .{ .literal_len = 0, .match_len = 1, .distance = 1 });
    try std.testing.expectError(error.BlockPlanLimitExceeded, plan.validate());
}

test "LZFSE plan record exhaustion and arithmetic limits preserve existing records" {
    var plan = Plan.init(1);
    defer plan.deinit(allocator);
    try plan.append(allocator, &.{}, 10000 * 2359, 1);
    try plan.validate();
    try std.testing.expectError(error.BlockPlanLimitExceeded, plan.appendLiterals(allocator, "x"));
    try std.testing.expectError(error.BlockPlanLimitExceeded, plan.append(allocator, &.{}, std.math.maxInt(usize), 1));
    try std.testing.expectEqual(@as(usize, 10000 * 2359), plan.raw_size);
    try std.testing.expectEqual(@as(usize, 10000), plan.records.items.len);
    try std.testing.expectEqual(@as(usize, 0), plan.literals.items.len);
    try plan.validate();
}

test "LZFSE plan validation checks exact raw and literal accounting" {
    var plan = Plan.init(0);
    defer plan.deinit(allocator);
    try plan.append(allocator, "abc", 4, 3);
    try plan.validate();
    plan.raw_size += 1;
    try std.testing.expectError(error.InvalidLzfseStream, plan.validate());
    plan.raw_size -= 1;
    plan.literals.items.len -= 1;
    try std.testing.expectError(error.InvalidLzfseStream, plan.validate());
    plan.literals.items.len += 1;
    try plan.validate();
}

test "LZFSE plan allocation failures preserve logical contents" {
    try std.testing.checkAllAllocationFailures(allocator, appendFailure, .{});
}

fn appendFailure(failing_allocator: std.mem.Allocator) !void {
    var plan = Plan.init(0);
    defer plan.deinit(failing_allocator);
    try plan.appendLiterals(failing_allocator, "prefix");
    const first = plan.records.items[0];
    const literals = [_]u8{7} ** 20000;
    plan.append(failing_allocator, &literals, 3 * 2359 + 1, 1) catch |err| {
        try std.testing.expectEqual(@as(usize, 6), plan.raw_size);
        try std.testing.expectEqual(@as(usize, 1), plan.records.items.len);
        try std.testing.expectEqualDeep(first, plan.records.items[0]);
        try std.testing.expectEqualStrings("prefix", plan.literals.items);
        try plan.validate();
        return err;
    };
    try plan.validate();
}

test "LZFSE plan retries the same adapted plan after allocator recovery" {
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    const wrapped = failing.allocator();
    var plan = Plan.init(0);
    defer plan.deinit(wrapped);
    try plan.appendLiterals(wrapped, "prefix");
    failing.fail_index = failing.alloc_index;
    const literals = [_]u8{7} ** 20000;
    try std.testing.expectError(error.OutOfMemory, plan.append(wrapped, &literals, 3 * 2359 + 1, 1));
    try std.testing.expectEqual(@as(usize, 6), plan.raw_size);
    try std.testing.expectEqual(@as(usize, 1), plan.records.items.len);
    try std.testing.expectEqualStrings("prefix", plan.literals.items);
    try plan.validate();
    failing.fail_index = std.math.maxInt(usize);
    try plan.append(wrapped, &literals, 3 * 2359 + 1, 1);
    try plan.validate();
    try std.testing.expectEqual(@as(usize, 6 + 20000 + 3 * 2359 + 1), plan.raw_size);
}

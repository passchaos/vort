const std = @import("std");
const finder = @import("match_finder.zig");
const limits = @import("../encode_options.zig");
const working = @import("../../io/working_allocator.zig");
const allocator = std.testing.allocator;

fn expectInput(plan: finder.Plan, input: []const u8, start: usize) !void {
    try plan.validate();
    try std.testing.expect(plan.raw_size > 0 and plan.raw_size <= input.len - start);
    const actual = try allocator.alloc(u8, plan.raw_size);
    defer allocator.free(actual);
    var written: usize = 0;
    var literal_offset: usize = 0;
    for (plan.records.items) |record| {
        @memcpy(actual[written..][0..record.literal_len], plan.literals.items[literal_offset..][0..record.literal_len]);
        written += record.literal_len;
        literal_offset += record.literal_len;
        for (0..record.match_len) |_| {
            actual[written] = if (record.distance <= written)
                actual[written - record.distance]
            else
                input[start + written - record.distance];
            written += 1;
        }
    }
    try std.testing.expectEqual(plan.raw_size, written);
    try std.testing.expectEqualSlices(u8, input[start..][0..plan.raw_size], actual);
}

fn deBruijn4Alloc() ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    var symbols: [5]u8 = @splat(0);
    try deBruijn(1, 1, &symbols, &bytes);
    try std.testing.expectEqual(@as(usize, 65536), bytes.items.len);
    return bytes.toOwnedSlice(allocator);
}

fn deBruijn(t: usize, p: usize, symbols: *[5]u8, bytes: *std.ArrayList(u8)) !void {
    if (t > 4) {
        if (4 % p == 0) try bytes.appendSlice(allocator, symbols[1 .. p + 1]);
    } else {
        symbols[t] = symbols[t - p];
        try deBruijn(t + 1, p, symbols, bytes);
        var value = symbols[t - p] + 1;
        while (value < 16) : (value += 1) {
            symbols[t] = value;
            try deBruijn(t + 1, t, symbols, bytes);
        }
    }
}

test "LZFSE matcher makes positive progress for tiny frames and starts matches at four" {
    const input = "aaaaa";
    for (1..6) |length| {
        var plan = try finder.planAlloc(allocator, input, 0, length, .{});
        defer plan.deinit(allocator);
        try std.testing.expectEqual(length, plan.raw_size);
        try expectInput(plan, input[0..length], 0);
        if (length < 5) {
            try std.testing.expectEqual(length, plan.literals.items.len);
        } else {
            try std.testing.expectEqual(@as(usize, 1), plan.records.items.len);
            try std.testing.expectEqual(@as(u16, 1), plan.records.items[0].literal_len);
            try std.testing.expectEqual(@as(u16, 4), plan.records.items[0].match_len);
            try std.testing.expectEqual(@as(u32, 1), plan.records.items[0].distance);
        }
    }
    try std.testing.expectError(error.InvalidLzfseStream, finder.planAlloc(allocator, input, 0, 0, .{}));
    try std.testing.expectError(error.InvalidLzfseStream, finder.planAlloc(allocator, input, 2, 1, .{}));
    try std.testing.expectError(error.InvalidLzfseStream, finder.planAlloc(allocator, input, 0, 6, .{}));
    try std.testing.expectError(error.InvalidLzfseStream, finder.planAlloc(allocator, input, 0, input.len, .{ .hash_log = 7 }));
    try std.testing.expectError(error.InvalidLzfseStream, finder.planAlloc(allocator, input, 0, input.len, .{ .hash_log = 21 }));
    try std.testing.expectError(error.InvalidLzfseStream, finder.planAlloc(allocator, input, 0, input.len, .{ .max_match_distance = 0 }));
}

test "LZFSE matcher preserves the default 64 KiB block and larger compressible requests" {
    for ([_]usize{ 65536, 1024 * 1024 }) |length| {
        const input = try allocator.alloc(u8, length);
        defer allocator.free(input);
        @memset(input, 'a');
        var plan = try finder.planAlloc(allocator, input, 0, input.len, .{ .block_size = length });
        defer plan.deinit(allocator);
        try std.testing.expectEqual(length, plan.raw_size);
        try std.testing.expectEqual(@as(usize, 1), plan.literals.items.len);
        try std.testing.expectEqual(@as(u16, 2359), plan.records.items[0].match_len);
        for (plan.records.items) |record| {
            try std.testing.expect(record.match_len >= 4 and record.match_len <= 2359);
            try std.testing.expectEqual(@as(u32, 1), record.distance);
        }
        try expectInput(plan, input, 0);
    }
}

test "LZFSE matcher cuts at 10000 records and records only the consumed large prefix" {
    const input = try allocator.alloc(u8, limits.max_plan_raw_size + 4096);
    defer allocator.free(input);
    @memset(input, 'a');
    var first = try finder.planAlloc(allocator, input, 0, input.len, .{ .block_size = input.len, .hash_log = 8 });
    defer first.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 10000), first.records.items.len);
    try std.testing.expectEqual(@as(usize, 1 + 10000 * 2359), first.raw_size);
    try std.testing.expect(first.raw_size < input.len);
    try expectInput(first, input, 0);
    var second = try finder.planAlloc(allocator, input, first.raw_size, input.len, .{ .block_size = input.len, .hash_log = 8 });
    defer second.deinit(allocator);
    try std.testing.expectEqual(input.len - first.raw_size, second.raw_size);
    try std.testing.expectEqual(@as(usize, limits.max_distance), second.history_len);
    try expectInput(second, input, first.raw_size);
}

test "LZFSE matcher reserves its last record for pending literals without consuming the next byte" {
    const prefix_len = 1 + 9999 * limits.max_match_length;
    const input = try allocator.alloc(u8, prefix_len + 316);
    defer allocator.free(input);
    @memset(input[0..prefix_len], 'a');
    var random = std.Random.DefaultPrng.init(0x9999);
    random.random().bytes(input[prefix_len..]);
    input[prefix_len] = 0x7e;
    // This tail is strictly literal, including joins to the preceding run.
    for (prefix_len..input.len - 3) |position| {
        try std.testing.expect(!std.mem.eql(u8, input[position..][0..4], "aaaa"));
        for (prefix_len - 3..position) |previous|
            try std.testing.expect(!std.mem.eql(u8, input[position..][0..4], input[previous..][0..4]));
    }
    var plan = try finder.planAlloc(allocator, input, 0, input.len, .{ .hash_log = 8, .block_size = input.len });
    defer plan.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 10000), plan.records.items.len);
    try std.testing.expectEqual(prefix_len + 315, plan.raw_size);
    try std.testing.expectEqual(@as(usize, 316), plan.literals.items.len);
    const final_record: @import("block_plan.zig").Record = .{ .literal_len = 315, .match_len = 0, .distance = 1 };
    try std.testing.expectEqualDeep(final_record, plan.records.items[9999]);
    try std.testing.expectEqualSlices(u8, input[prefix_len..][0..315], plan.literals.items[1..]);
    try expectInput(plan, input, 0);
}

test "LZFSE matcher cuts incompressible input at exactly 40000 literals and flushes pending bytes" {
    const input = try deBruijn4Alloc();
    defer allocator.free(input);
    var first = try finder.planAlloc(allocator, input, 0, input.len, .{ .hash_log = 8 });
    defer first.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 40000), first.raw_size);
    try std.testing.expectEqual(@as(usize, 40000), first.literals.items.len);
    try std.testing.expectEqual(@as(usize, 127), first.records.items.len);
    try std.testing.expectEqual(@as(u16, 310), first.records.items[first.records.items.len - 1].literal_len);
    for (first.records.items) |record| {
        try std.testing.expectEqual(@as(u16, 0), record.match_len);
        try std.testing.expectEqual(@as(u32, 1), record.distance);
    }
    try expectInput(first, input, 0);
    var second = try finder.planAlloc(allocator, input, first.raw_size, input.len, .{ .hash_log = 8 });
    defer second.deinit(allocator);
    try std.testing.expectEqual(input.len - first.raw_size, second.raw_size);
    try expectInput(second, input, first.raw_size);
}

test "LZFSE matcher combines a full 315 literal run with the following match" {
    var input: [315 + 8]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x315);
    random.random().bytes(input[0..315]);
    @memcpy(input[315..], input[0..8]);
    // Verify the joining bytes do not introduce an earlier four-byte match;
    // this fixture must contain exactly 315 literals before the eight-byte copy.
    for (0..315) |position| {
        for (0..position) |previous|
            try std.testing.expect(!std.mem.eql(u8, input[position..][0..4], input[previous..][0..4]));
    }
    var plan = try finder.planAlloc(allocator, &input, 0, input.len, .{ .hash_log = 20 });
    defer plan.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), plan.records.items.len);
    try std.testing.expectEqual(@as(u16, 315), plan.records.items[0].literal_len);
    try std.testing.expectEqual(@as(u16, 8), plan.records.items[0].match_len);
    try std.testing.expectEqual(@as(u32, 315), plan.records.items[0].distance);
    try expectInput(plan, &input, 0);
}

test "LZFSE matcher reaches distance 262139 and rejects the next distance" {
    for ([_]usize{ limits.max_distance, limits.max_distance + 1 }) |distance| {
        const input = try allocator.alloc(u8, distance + limits.max_match_length);
        defer allocator.free(input);
        @memset(input, 0x55);
        var random = std.Random.DefaultPrng.init(0xd15a7);
        random.random().bytes(input[0..limits.max_match_length]);
        @memcpy(input[distance..], input[0..limits.max_match_length]);
        var plan = try finder.planAlloc(allocator, input, distance, input.len, .{ .hash_log = 20 });
        defer plan.deinit(allocator);
        try std.testing.expectEqual(limits.max_match_length, plan.raw_size);
        if (distance == limits.max_distance) {
            try std.testing.expectEqual(@as(usize, 1), plan.records.items.len);
            try std.testing.expectEqual(@as(u16, 0), plan.records.items[0].literal_len);
            try std.testing.expectEqual(@as(u16, 2359), plan.records.items[0].match_len);
            try std.testing.expectEqual(@as(u32, limits.max_distance), plan.records.items[0].distance);
        } else {
            try std.testing.expectEqual(limits.max_match_length, plan.literals.items.len);
        }
        try expectInput(plan, input, distance);
    }
}

test "LZFSE matcher rolls a caller distance bound while retaining overlap and borrowed history" {
    const input = "01234567" ** 20000;
    var plan = try finder.planAlloc(allocator, input, 65536, input.len, .{ .max_match_distance = 8 });
    defer plan.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 8), plan.history_len);
    try std.testing.expectEqual(@as(usize, 0), plan.literals.items.len);
    for (plan.records.items) |record| try std.testing.expectEqual(@as(u32, 8), record.distance);
    try expectInput(plan, input, 65536);
}

test "LZFSE matcher deterministically reconstructs mixed and random input across count cuts" {
    const input = try allocator.alloc(u8, 150000);
    defer allocator.free(input);
    var random = std.Random.DefaultPrng.init(0xa55a);
    random.random().bytes(input);
    @memcpy(input[50000..100000], input[0..50000]);
    @memset(input[120000..], 'x');
    for ([_]u8{ 8, 15, 20 }) |hash_log| {
        var start: usize = 0;
        while (start < input.len) {
            var plan = try finder.planAlloc(allocator, input, start, input.len, .{ .hash_log = hash_log });
            defer plan.deinit(allocator);
            var repeated = try finder.planAlloc(allocator, input, start, input.len, .{ .hash_log = hash_log });
            defer repeated.deinit(allocator);
            try std.testing.expectEqual(plan.raw_size, repeated.raw_size);
            try std.testing.expectEqualDeep(plan.records.items, repeated.records.items);
            try std.testing.expectEqualSlices(u8, plan.literals.items, repeated.literals.items);
            try expectInput(plan, input, start);
            start += plan.raw_size;
        }
        try std.testing.expectEqual(input.len, start);
    }
}

test "LZFSE matcher working allocations stay bounded independently of borrowed input and history" {
    const input = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(input);
    @memset(input, 'a');
    var budget = working.WorkingAllocator.init(allocator, 65536);
    var plan = try finder.planAlloc(budget.allocator(), input, 600000, input.len, .{ .hash_log = 8 });
    defer plan.deinit(budget.allocator());
    try std.testing.expectEqual(limits.max_distance, plan.history_len);
    try std.testing.expectEqual(input.len - 600000, plan.raw_size);
    try std.testing.expect(budget.peak < 16384);
    try expectInput(plan, input, 600000);
    var insufficient = working.WorkingAllocator.init(allocator, 8 * 256 - 1);
    try std.testing.expectError(error.OutOfMemory, finder.planAlloc(insufficient.allocator(), input, 600000, input.len, .{ .hash_log = 8 }));
    try std.testing.expectEqual(@as(usize, 0), insufficient.live);
    try std.testing.expect(insufficient.last_failure_was_limit);
}

test "LZFSE matcher releases every allocation failure and the same input remains reusable" {
    const input = try deBruijn4Alloc();
    defer allocator.free(input);
    const before = try allocator.dupe(u8, input);
    defer allocator.free(before);
    try std.testing.checkAllAllocationFailures(allocator, matchFailure, .{ input, before });
}

fn matchFailure(failing_allocator: std.mem.Allocator, input: []const u8, before: []const u8) !void {
    var plan = finder.planAlloc(failing_allocator, input, 0, input.len, .{ .hash_log = 8 }) catch |err| {
        try std.testing.expectEqualSlices(u8, before, input);
        var retry = try finder.planAlloc(allocator, input, 0, input.len, .{ .hash_log = 8 });
        defer retry.deinit(allocator);
        try expectInput(retry, input, 0);
        return err;
    };
    defer plan.deinit(failing_allocator);
    try std.testing.expectEqualSlices(u8, before, input);
    try expectInput(plan, input, 0);
}

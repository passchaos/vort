const std = @import("std");
const search = @import("controlled_search.zig");
const controls = @import("../encode/controls.zig");
const Source = search.Source;
const Record = search.Record;
const strategies = [_]controls.Strategy{ .greedy, .lazy, .optimal };

test "controlled search vector mismatch lanes agree with scalar dictionary oracle" {
    const allocator = std.testing.allocator;
    var dictionary: [96]u8 = undefined;
    for (&dictionary, 0..) |*byte, i| byte.* = @intCast(i + 32);
    for (3..67) |mismatch| {
        var block = dictionary;
        block[mismatch] ^= 0x80;
        const source = Source.init(&dictionary, "", &block, 256);
        var actual: std.ArrayList(Record) = .empty;
        defer actual.deinit(allocator);
        var expected: std.ArrayList(Record) = .empty;
        defer expected.deinit(allocator);
        try search.planReuse(&actual, allocator, source, .{ .strategy = .greedy });
        try scalarGreedy(&expected, source);
        try std.testing.expectEqualSlices(Record, expected.items, actual.items);
        try std.testing.expectEqual(mismatch, actual.items[0].match_len);
        try verifyPlan(source, actual.items);
    }
}

test "controlled search scalar greedy oracle covers virtual spans and overlap" {
    const gpa = std.testing.allocator;
    var actual: std.ArrayList(Record) = .empty;
    defer actual.deinit(gpa);
    var expected: std.ArrayList(Record) = .empty;
    defer expected.deinit(gpa);
    var random = std.Random.DefaultPrng.init(0x839ea26b);
    var dictionary: [47]u8 = undefined;
    var history: [31]u8 = undefined;
    var block: [117]u8 = undefined;
    for (0..96) |iteration| {
        for (&dictionary) |*byte| byte.* = 'a' + random.random().uintLessThan(u8, 5);
        for (&history) |*byte| byte.* = 'a' + random.random().uintLessThan(u8, 5);
        for (&block) |*byte| byte.* = 'a' + random.random().uintLessThan(u8, 5);
        if (iteration % 3 == 0) @memset(block[13..], block[12]);
        if (iteration % 3 == 1) {
            @memcpy(block[0..15], dictionary[32..]);
            @memcpy(block[15..46], &history);
        }
        const source = Source.init(&dictionary, &history, &block, 192);
        try search.planReuse(&actual, gpa, source, .{ .strategy = .greedy });
        try scalarGreedy(&expected, source);
        try std.testing.expectEqualSlices(Record, expected.items, actual.items);
        try verifyPlan(source, actual.items);
    }
}

test "controlled bounded optimal agrees with exhaustive scalar prices on tiny inputs" {
    const gpa = std.testing.allocator;
    var records: std.ArrayList(Record) = .empty;
    defer records.deinit(gpa);
    var block: [10]u8 = undefined;
    for (0..256) |bits| {
        for (&block, 0..) |*byte, i| byte.* = 'a' + @as(u8, @intCast((bits >> @intCast(i % 8)) & 1));
        const source = Source.init("abba", "baab", &block, 32);
        try search.planReuse(&records, gpa, source, .{ .strategy = .optimal });
        try verifyPlan(source, records.items);
        var best: u32 = @intCast(block.len * 8);
        exhaustive(source, 0, 0, .{ 1, 4, 8 }, 0, &best);
        try std.testing.expectEqual(best, planPrice(source, records.items, .{ 1, 4, 8 }));
    }
}

test "controlled lazy defers and optimal improves the greedy trap" {
    const gpa = std.testing.allocator;
    const source = Source.init("abcXbcdefgh", "", "abcdefgh", 32);
    var greedy: std.ArrayList(Record) = .empty;
    defer greedy.deinit(gpa);
    var lazy: std.ArrayList(Record) = .empty;
    defer lazy.deinit(gpa);
    var optimal: std.ArrayList(Record) = .empty;
    defer optimal.deinit(gpa);
    var profile: controls.Profile = .{};
    try search.planReuse(&greedy, gpa, source, .{ .strategy = .greedy });
    try search.planReuse(&lazy, gpa, source, .{ .strategy = .lazy, .profile = &profile });
    try search.planReuse(&optimal, gpa, source, .{ .strategy = .optimal });
    try std.testing.expectEqual(@as(usize, 3), greedy.items[0].match_len);
    try std.testing.expectEqual(@as(usize, 1), lazy.items[0].literal_len);
    try std.testing.expectEqual(@as(usize, 7), lazy.items[0].match_len);
    try std.testing.expectEqual(@as(u64, 1), profile.lazy_deferrals);
    try std.testing.expect(planPrice(source, lazy.items, .{ 1, 4, 8 }) < planPrice(source, greedy.items, .{ 1, 4, 8 }));
    try std.testing.expect(planPrice(source, optimal.items, .{ 1, 4, 8 }) < planPrice(source, greedy.items, .{ 1, 4, 8 }));
    var best: u32 = @intCast(source.block.len * 8);
    exhaustive(source, 0, 0, .{ 1, 4, 8 }, 0, &best);
    try std.testing.expectEqual(best, planPrice(source, optimal.items, .{ 1, 4, 8 }));
    try verifyPlan(source, greedy.items);
    try verifyPlan(source, lazy.items);
    try verifyPlan(source, optimal.items);
}

test "controlled sequence prices agree with format tables and literal sensitive selectors" {
    const literal_lengths = [_]usize{ 0, 1, 15, 16, 23, 24, 31, 32, 47, 48, 63, 64, 127, 128, 32768, 65536, 131071 };
    const match_lengths = [_]usize{ 3, 4, 34, 35, 42, 43, 50, 51, 66, 67, 98, 99, 130, 131, 258, 259, 32770, 32771, 65538, 65539, 131072 };
    for (literal_lengths) |literal_len| {
        for (match_lengths) |match_len| {
            for ([_]usize{ 1, 2, 3, 4, 7, 8, 9, 70000 }) |distance| {
                for ([_][3]usize{ .{ 1, 4, 8 }, .{ 9, 1, 70000 }, .{ 4, 4, 4 } }) |reps|
                    try std.testing.expectEqual(scalarPrice(literal_len, match_len, distance, reps), search.sequencePrice(literal_len, match_len, distance, reps));
            }
        }
    }
}

test "controlled search budget binds probes and optimal transitions including rejected window nodes" {
    const gpa = std.testing.allocator;
    var records: std.ArrayList(Record) = .empty;
    defer records.deinit(gpa);
    const dictionary = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const block = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    for (strategies) |strategy| {
        for ([_]usize{ 0, 1, 2, 3, 7, 16, 96, 512 }) |budget| {
            var profile: controls.Profile = .{};
            const source: Source = .{ .dictionary = dictionary, .history = "", .block = block, .window_len = 2 };
            try search.planReuse(&records, gpa, source, .{ .strategy = strategy, .search_budget = budget, .profile = &profile });
            try verifyPlan(source, records.items);
            try std.testing.expect(profile.candidate_checks + profile.optimal_transitions <= profile.positions_tested * budget);
            try std.testing.expectEqual(profile.candidate_checks, profile.rep_probes + profile.short_hash_probes);
            if (budget == 0) try std.testing.expectEqual(@as(usize, 0), records.items.len);
        }
    }
}

test "controlled search preserves full distances and bounded prefix seeding" {
    const gpa = std.testing.allocator;
    const prefix = try gpa.alloc(u8, 70000);
    defer gpa.free(prefix);
    var random = std.Random.DefaultPrng.init(0x76ae903);
    random.random().bytes(prefix);
    var block: [111]u8 = undefined;
    @memcpy(&block, prefix[0..block.len]);
    var records: std.ArrayList(Record) = .empty;
    defer records.deinit(gpa);
    for (strategies) |strategy| {
        var profile: controls.Profile = .{};
        const source = Source.init(prefix[0..10000], prefix[10000..], &block, prefix.len);
        try search.planReuse(&records, gpa, source, .{ .strategy = strategy, .profile = &profile });
        try verifyPlan(source, records.items);
        try std.testing.expect(records.items.len > 0);
        try std.testing.expectEqual(@as(usize, 70000), records.items[0].distance);
        try std.testing.expectEqual(block.len, records.items[0].match_len);
        try std.testing.expect(profile.dictionary_seed_positions + profile.history_seed_positions <= 65536);
    }
}

test "controlled search acceleration samples positions and profiles saturate" {
    const gpa = std.testing.allocator;
    var records: std.ArrayList(Record) = .empty;
    defer records.deinit(gpa);
    var block: [128]u8 = undefined;
    for (&block, 0..) |*byte, i| byte.* = @intCast(i);
    for (strategies) |strategy| {
        var profile: controls.Profile = .{};
        const source = Source.init("", "", &block, 128);
        try search.planReuse(&records, gpa, source, .{ .strategy = strategy, .acceleration = 7, .profile = &profile });
        try verifyPlan(source, records.items);
        try std.testing.expect(profile.skipped_positions > 0);
        try std.testing.expect(profile.positions_tested < block.len / 2);
        profile.positions_tested = std.math.maxInt(u64);
        profile.candidate_checks = std.math.maxInt(u64);
        profile.short_hash_probes = std.math.maxInt(u64);
        try search.planReuse(&records, gpa, Source.init("abcdef", "", "abcdefabcdef", 32), .{ .strategy = strategy, .profile = &profile });
        try std.testing.expectEqual(std.math.maxInt(u64), profile.positions_tested);
        try std.testing.expectEqual(std.math.maxInt(u64), profile.candidate_checks);
        try std.testing.expectEqual(std.math.maxInt(u64), profile.short_hash_probes);
    }
}

test "controlled search empty tiny and exactly three byte matches" {
    const gpa = std.testing.allocator;
    var records: std.ArrayList(Record) = .empty;
    defer records.deinit(gpa);
    for (strategies) |strategy| {
        for ([_][]const u8{ "", "a", "ab" }) |block| {
            try search.planReuse(&records, gpa, Source.init("abc", "", block, 32), .{ .strategy = strategy });
            try std.testing.expectEqual(@as(usize, 0), records.items.len);
        }
        const source = Source.init("abc", "", "abc", 32);
        try search.planReuse(&records, gpa, source, .{ .strategy = strategy });
        try std.testing.expectEqual(@as(usize, 1), records.items.len);
        try std.testing.expectEqual(@as(usize, 3), records.items[0].match_len);
        try verifyPlan(source, records.items);
    }
}

fn verifyPlan(source: Source, records: []const Record) !void {
    var previous_end: usize = 0;
    for (records) |record| {
        const start = previous_end + record.literal_len;
        try std.testing.expectEqual(start + record.match_len, record.match_end);
        try std.testing.expect(record.match_len >= 3 and record.match_end <= source.block.len);
        try std.testing.expect(record.distance > 0 and record.distance <= source.window_len);
        const absolute = source.prefixLen() + start;
        try std.testing.expect(record.distance <= absolute);
        const match = source.match(start, absolute - record.distance, 3);
        try std.testing.expect(match.length >= record.match_len);
        previous_end = record.match_end;
    }
}

fn scalarGreedy(records: *std.ArrayList(Record), source: Source) !void {
    records.clearRetainingCapacity();
    var position: usize = 0;
    var anchor: usize = 0;
    var reps: [3]usize = .{ 1, 4, 8 };
    while (position + 3 <= source.block.len) {
        var best_length: usize = 0;
        var best_distance: usize = 0;
        var best_price: u32 = std.math.maxInt(u32);
        const absolute = source.prefixLen() + position;
        for (absolute - @min(absolute, source.window_len)..absolute) |candidate| {
            const match = source.match(position, candidate, 3);
            if (match.length == 0) continue;
            const price = scalarPrice(position - anchor, match.length, match.distance, reps);
            if (match.length > best_length or (match.length == best_length and (price < best_price or (price == best_price and match.distance < best_distance)))) {
                best_length = match.length;
                best_distance = match.distance;
                best_price = price;
            }
        }
        if (best_length == 0) {
            position += 1;
            continue;
        }
        try records.append(std.testing.allocator, .{ .literal_len = position - anchor, .match_len = best_length, .distance = best_distance, .match_end = position + best_length });
        reps = scalarOffset(position - anchor, best_distance, reps).reps;
        position += best_length;
        anchor = position;
    }
}

fn exhaustive(source: Source, position: usize, literal_len: usize, reps: [3]usize, cost: u32, best: *u32) void {
    if (cost >= best.*) return;
    if (position == source.block.len) {
        best.* = cost;
        return;
    }
    exhaustive(source, position + 1, literal_len + 1, reps, cost + 8, best);
    const absolute = source.prefixLen() + position;
    for (absolute - @min(absolute, source.window_len)..absolute) |candidate| {
        const match = source.match(position, candidate, 3);
        if (match.length < 3) continue;
        const next_reps = scalarOffset(literal_len, match.distance, reps).reps;
        for (3..match.length + 1) |length|
            exhaustive(source, position + length, 0, next_reps, cost + scalarPrice(literal_len, length, match.distance, reps), best);
    }
}

fn planPrice(source: Source, records: []const Record, initial: [3]usize) u32 {
    var reps = initial;
    var price: u32 = 0;
    var end: usize = 0;
    for (records) |record| {
        price += @as(u32, @intCast(record.literal_len * 8)) + scalarPrice(record.literal_len, record.match_len, record.distance, reps);
        reps = scalarOffset(record.literal_len, record.distance, reps).reps;
        end = record.match_end;
    }
    return price + @as(u32, @intCast((source.block.len - end) * 8));
}

const ll_base = [_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 28, 32, 40, 48, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536 };
const ll_bits = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
const ml_base = [_]usize{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 37, 39, 41, 43, 47, 51, 59, 67, 83, 99, 131, 259, 515, 1027, 2051, 4099, 8195, 16387, 32771, 65539 };
const ml_bits = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };

fn scalarPrice(literal_len: usize, match_len: usize, distance: usize, reps: [3]usize) u32 {
    return 16 + extra(literal_len, &ll_base, &ll_bits) + extra(match_len, &ml_base, &ml_bits) + scalarOffset(literal_len, distance, reps).bits;
}

fn extra(value: usize, bases: []const usize, bits: []const u8) u32 {
    var result: u32 = 0;
    for (bases, bits) |base, width| {
        if (value < base) break;
        result = width;
    }
    return result;
}

fn scalarOffset(literal_len: usize, distance: usize, reps: [3]usize) struct { bits: u32, reps: [3]usize } {
    for (1..4) |selector| {
        const repeat_index = selector - 1 + @intFromBool(literal_len == 0);
        const selected = if (repeat_index == 3) reps[0] -| 1 else reps[repeat_index];
        if (selected == 0 or selected != distance) continue;
        var next = reps;
        if (repeat_index != 0) {
            next[0] = selected;
            next[1] = reps[0];
            next[2] = if (repeat_index == 1) reps[2] else reps[1];
        }
        return .{ .bits = if (selector == 1) 0 else 1, .reps = next };
    }
    var value = distance + 3;
    var width: u32 = 0;
    while (value > 1) : (value >>= 1) width += 1;
    return .{ .bits = width, .reps = .{ distance, reps[0], reps[1] } };
}

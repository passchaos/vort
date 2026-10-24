const std = @import("std");
const fast = @import("controlled_fast.zig");
const controls = @import("../encode/controls.zig");
const a = std.testing.allocator;

fn oldByte(source: fast.Source, rebuilt: []const u8, absolute: usize) u8 {
    if (absolute < source.dictionary.len) return source.dictionary[absolute];
    const position = absolute - source.dictionary.len;
    if (position < source.history.len) return source.history[position];
    return rebuilt[position - source.history.len];
}

fn longest(source: fast.Source, position: usize) usize {
    const prefix = source.dictionary.len + source.history.len;
    const absolute = prefix + position;
    var best: usize = 0;
    for (absolute - @min(absolute, source.window_len)..absolute) |candidate| {
        var length: usize = 0;
        while (position + length < source.block.len) : (length += 1) {
            const at = candidate + length;
            const byte = if (at < source.dictionary.len) source.dictionary[at] else if (at < prefix)
                source.history[at - source.dictionary.len]
            else
                source.block[at - prefix];
            if (byte != source.block[position + length]) break;
        }
        best = @max(best, length);
    }
    return best;
}

fn rebuild(source: fast.Source, records: []const fast.Record, oracle: bool) !void {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(a);
    try output.ensureTotalCapacityPrecise(a, source.block.len);
    const prefix = source.dictionary.len + source.history.len;
    for (records) |record| {
        const position = output.items.len + record.literal_len;
        try std.testing.expect(position <= source.block.len);
        try std.testing.expect(record.match_len >= 4 and record.distance > 0);
        try std.testing.expect(record.distance <= prefix + position and record.distance <= source.window_len);
        try std.testing.expectEqual(position + record.match_len, record.match_end);
        try std.testing.expect(record.match_end <= source.block.len);
        if (oracle) try std.testing.expect(record.match_len <= longest(source, position));
        try output.appendSlice(a, source.block[output.items.len..position]);
        for (0..record.match_len) |_| {
            const byte = oldByte(source, output.items, prefix + output.items.len - record.distance);
            try std.testing.expectEqual(source.block[output.items.len], byte);
            output.appendAssumeCapacity(byte);
        }
    }
    try output.appendSlice(a, source.block[output.items.len..]);
    try std.testing.expectEqualSlices(u8, source.block, output.items);
}

test "Zstd controlled fast small lengths scalar reconstruction and exhaustive match oracle" {
    var bytes: [256]u8 = undefined;
    var rng = std.Random.DefaultPrng.init(0xc071fa57);
    for (0..2) |pattern| {
        if (pattern == 0) rng.random().bytes(&bytes) else for (&bytes, 0..) |*byte, i| {
            byte.* = @intCast((i + i / 31) % 7);
        }
        for (0..bytes.len + 1) |length| {
            const split = length / 3;
            const source = fast.Source.init(bytes[0..split], bytes[split .. 2 * split], bytes[0..length], 1024);
            inline for (.{ controls.Strategy.fast, controls.Strategy.double_fast }) |strategy| {
                inline for (.{ 1, 7, 131072 }) |acceleration| {
                    var records: std.ArrayList(fast.Record) = .empty;
                    defer records.deinit(a);
                    try fast.planReuse(&records, a, source, .{ .strategy = strategy, .acceleration = acceleration });
                    try rebuild(source, records.items, true);
                }
            }
        }
    }
}

test "Zstd controlled fast dictionary history overlap and standard repeated distances" {
    const block = "cdefcdefcdefcdef";
    inline for (.{ controls.Strategy.fast, controls.Strategy.double_fast }) |strategy| {
        inline for (.{ 1, 19, 131072 }) |acceleration| {
            var records: std.ArrayList(fast.Record) = .empty;
            defer records.deinit(a);
            const crossing = fast.Source.init("abc", "def", block, 1024);
            try fast.planReuse(&records, a, crossing, .{ .strategy = strategy, .acceleration = acceleration });
            try rebuild(crossing, records.items, true);
            try std.testing.expectEqual(@as(usize, 1), records.items.len);
            try std.testing.expectEqual(@as(usize, 4), records.items[0].distance);
            try std.testing.expectEqual(block.len, records.items[0].match_len);
        }
        var records: std.ArrayList(fast.Record) = .empty;
        defer records.deinit(a);
        const zero_literal = fast.Source.init("a" ** 32, "", "a" ** 16, 1024);
        try fast.planReuse(&records, a, zero_literal, .{ .strategy = strategy, .initial_repeated_offsets = .{ 8, 4, 16 } });
        try std.testing.expectEqual(@as(usize, 4), records.items[0].distance);
        const one_literal = fast.Source.init("a" ** 32, "", "x" ++ "a" ** 8, 1024);
        try fast.planReuse(&records, a, one_literal, .{ .strategy = strategy, .initial_repeated_offsets = .{ 16, 4, 8 } });
        try std.testing.expectEqual(@as(usize, 1), records.items[0].literal_len);
        try std.testing.expectEqual(@as(usize, 16), records.items[0].distance);
        try rebuild(one_literal, records.items, true);
    }
}

test "Zstd controlled fast dual long hash preserves independent short-prefix collision" {
    const dictionary = "abcd11112222----abcd33334444--------";
    const block = "abcd11112222";
    const source = fast.Source.init(dictionary, "", block, 1024);
    var single: std.ArrayList(fast.Record) = .empty;
    defer single.deinit(a);
    var dual: std.ArrayList(fast.Record) = .empty;
    defer dual.deinit(a);
    var single_profile = controls.Profile{};
    var dual_profile = controls.Profile{};
    try fast.planReuse(&single, a, source, .{ .strategy = .fast, .profile = &single_profile });
    try fast.planReuse(&dual, a, source, .{ .strategy = .double_fast, .profile = &dual_profile });
    try rebuild(source, single.items, true);
    try rebuild(source, dual.items, true);
    try std.testing.expectEqual(@as(usize, 4), single.items[0].match_len);
    try std.testing.expectEqual(block.len, dual.items[0].match_len);
    try std.testing.expectEqual(@as(u64, 0), single_profile.long_hash_probes);
    try std.testing.expect(dual_profile.long_hash_probes > 0);
}

test "Zstd controlled fast acceleration changes real seed and miss probes deterministically" {
    var dictionary: [4096]u8 = undefined;
    var block: [8192]u8 = undefined;
    var rng = std.Random.DefaultPrng.init(0xc071a11e);
    rng.random().bytes(&dictionary);
    rng.random().bytes(&block);
    inline for (.{ controls.Strategy.fast, controls.Strategy.double_fast }) |strategy| {
        var profiles: [3]controls.Profile = @splat(.{});
        var previous: std.ArrayList(fast.Record) = .empty;
        defer previous.deinit(a);
        for ([_]u32{ 1, 8, 131072 }, 0..) |acceleration, index| {
            var records: std.ArrayList(fast.Record) = .empty;
            defer records.deinit(a);
            const source = fast.Source.init(&dictionary, "", &block, 16384);
            const parameters = fast.Parameters{ .strategy = strategy, .acceleration = acceleration, .profile = &profiles[index] };
            try fast.planReuse(&records, a, source, parameters);
            try rebuild(source, records.items, false);
            try previous.ensureTotalCapacityPrecise(a, records.items.len);
            previous.clearRetainingCapacity();
            try previous.appendSlice(a, records.items);
            var replay: std.ArrayList(fast.Record) = .empty;
            defer replay.deinit(a);
            try fast.planReuse(&replay, a, source, .{ .strategy = strategy, .acceleration = acceleration });
            try std.testing.expectEqualDeep(previous.items, replay.items);
        }
        try std.testing.expect(profiles[0].short_hash_probes > profiles[1].short_hash_probes);
        try std.testing.expect(profiles[1].short_hash_probes > profiles[2].short_hash_probes);
        try std.testing.expect(profiles[0].dictionary_seed_positions > profiles[1].dictionary_seed_positions);
        try std.testing.expect(profiles[1].dictionary_seed_positions > profiles[2].dictionary_seed_positions);
        try std.testing.expect(profiles[2].skipped_positions > profiles[0].skipped_positions);
        try std.testing.expect(profiles[0].rep_probes > profiles[2].rep_probes);
    }
}

test "Zstd controlled fast 128 KiB blocks windows and distances beyond 16 bits" {
    const dictionary = try a.alloc(u8, 96 * 1024);
    defer a.free(dictionary);
    @memset(dictionary, 0xff);
    var rng = std.Random.DefaultPrng.init(0xc0717000);
    rng.random().bytes(dictionary[0..512]);
    const large = try a.alloc(u8, 128 * 1024);
    defer a.free(large);
    for (large, 0..) |*byte, i| byte.* = dictionary[i % 512];
    inline for (.{ controls.Strategy.fast, controls.Strategy.double_fast }) |strategy| {
        for ([_]usize{ 1024, 65536, 128 * 1024, 64 * 1024 * 1024 }) |window| {
            var records: std.ArrayList(fast.Record) = .empty;
            defer records.deinit(a);
            const source = fast.Source.init(dictionary, "", large, window);
            try fast.planReuse(&records, a, source, .{ .strategy = strategy });
            try rebuild(source, records.items, false);
            if (window >= dictionary.len) try std.testing.expect(records.items[0].distance > 65535);
        }
    }
}

test "Zstd controlled fast 64 MiB prefix uses bounded sampled tables and retained records only" {
    const dictionary = try a.alloc(u8, 64 * 1024 * 1024);
    defer a.free(dictionary);
    @memset(dictionary, 0xff);
    const block = "a full-window starting anchor remains reachable";
    @memcpy(dictionary[0..block.len], block);
    inline for (.{ controls.Strategy.fast, controls.Strategy.double_fast }) |strategy| {
        var failing = std.testing.FailingAllocator.init(a, .{});
        var records: std.ArrayList(fast.Record) = .empty;
        defer records.deinit(failing.allocator());
        try records.ensureTotalCapacityPrecise(failing.allocator(), 4);
        failing.fail_index = failing.alloc_index;
        failing.resize_fail_index = failing.resize_index;
        var profile = controls.Profile{};
        const source = fast.Source.init(dictionary, "", block, dictionary.len);
        try fast.planReuse(&records, failing.allocator(), source, .{ .strategy = strategy, .profile = &profile });
        try rebuild(source, records.items, false);
        try std.testing.expectEqual(dictionary.len, records.items[0].distance);
        try std.testing.expect(profile.dictionary_seed_positions <= 2 * 65536 + 10);
        try std.testing.expect(!failing.has_induced_failure);
    }
}

test "Zstd controlled fast allocation failures active record moves and source moves" {
    var bytes: [8192]u8 = undefined;
    var rng = std.Random.DefaultPrng.init(0xc0710a11);
    rng.random().bytes(&bytes);
    for (0..bytes.len / 128) |i| @memcpy(bytes[i * 128 + 64 ..][0..64], bytes[i * 128 ..][0..64]);
    const Test = struct {
        fn run(allocator: std.mem.Allocator, borrowed: fast.Source, strategy: controls.Strategy) !void {
            var records: std.ArrayList(fast.Record) = .empty;
            defer records.deinit(allocator);
            var source = borrowed;
            try fast.planReuse(&records, allocator, source, .{ .strategy = strategy });
            try rebuild(source, records.items, false);
            var moved = records;
            const moved_source = source;
            source = undefined;
            records = undefined;
            fast.planReuse(&moved, allocator, moved_source, .{ .strategy = strategy }) catch |err| {
                records = moved;
                return err;
            };
            records = moved;
            try rebuild(moved_source, records.items, false);
        }
    };
    const source = fast.Source.init(bytes[0..257], bytes[257..511], bytes[511..], 16384);
    inline for (.{ controls.Strategy.fast, controls.Strategy.double_fast }) |strategy|
        try std.testing.checkAllAllocationFailures(a, Test.run, .{ source, strategy });
}

test "Zstd controlled fast rejects invalid controls before altering retained records" {
    var records: std.ArrayList(fast.Record) = .empty;
    defer records.deinit(a);
    try records.append(a, .{ .literal_len = 2, .distance = 1, .match_len = 4, .match_end = 6 });
    const source = fast.Source.init("", "", "abcdef", 1024);
    for ([_]fast.Parameters{
        .{ .strategy = .auto },
        .{ .strategy = .greedy },
        .{ .strategy = .fast, .acceleration = 0 },
        .{ .strategy = .double_fast, .acceleration = controls.max_acceleration + 1 },
        .{ .strategy = .fast, .search_budget = controls.legacy_search_budget - 1 },
    }) |parameters| try std.testing.expectError(error.InvalidBlockPlan, fast.planReuse(&records, a, source, parameters));
    var bad_source = source;
    bad_source.window_len = 0;
    try std.testing.expectError(error.InvalidBlockPlan, fast.planReuse(&records, a, bad_source, .{ .strategy = .fast }));
    bad_source.window_len = 64 * 1024 * 1024 + 1;
    try std.testing.expectError(error.InvalidBlockPlan, fast.planReuse(&records, a, bad_source, .{ .strategy = .double_fast }));
    try std.testing.expectEqual(@as(usize, 1), records.items.len);
    try std.testing.expectEqual(@as(usize, 6), records.items[0].match_end);
}

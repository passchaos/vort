const std = @import("std");
const tree = @import("../hq_tree.zig");
const view = @import("view.zig");
const controls = @import("../../encode/controls.zig");
const working = @import("../../../io/working_allocator.zig");
const a = std.testing.allocator;

test "Zstd HQ tree full-depth frontier agrees with scalar oracle at min lengths three through seven" {
    var random = std.Random.DefaultPrng.init(0x27ac931);
    var dictionary: [29]u8 = undefined;
    var history: [19]u8 = undefined;
    var block: [113]u8 = undefined;
    for (0..28) |iteration| {
        for (&dictionary) |*byte| byte.* = 'a' + random.random().uintLessThan(u8, 4);
        for (&history) |*byte| byte.* = 'a' + random.random().uintLessThan(u8, 4);
        for (&block) |*byte| byte.* = 'a' + random.random().uintLessThan(u8, 4);
        if (iteration % 3 == 0) @memset(block[9..], 'a');
        if (iteration % 3 == 1) {
            @memcpy(block[0..8], dictionary[21..]);
            @memcpy(block[8..27], &history);
        }
        for (3..8) |minimum| {
            const source = tree.Source.init(&dictionary, &history, &block, if (iteration % 2 == 0) 31 else 256);
            var matcher = try tree.Matcher.init(a, source, .{ .search_depth = 512, .nice_len = 131072, .min_match = @intCast(minimum) }, null);
            defer matcher.deinit(a);
            for (0..block.len) |position| {
                const matches = try matcher.find();
                try verify(source, position, matches, minimum);
                const absolute = source.prefixLen() + position;
                var longest: usize = 0;
                for (absolute - @min(absolute, source.window_len)..absolute) |candidate|
                    longest = @max(longest, source.match(position, candidate, minimum).length);
                try std.testing.expectEqual(longest, matches.best().length);
            }
        }
    }
}

test "Zstd HQ tree vector and word extension use scalar lane order across all virtual spans" {
    const dictionary = [_]u8{'a'} ** 32;
    const history = [_]u8{'a'} ** 16;
    var block: [64]u8 = undefined;
    for (0..65) |mismatch| {
        @memset(&block, 'a');
        if (mismatch < block.len) block[mismatch] = 'b';
        const source = tree.Source.init(&dictionary, &history, &block, 512);
        for ([_]usize{ 0, @min(@as(usize, 17), mismatch) }) |start| {
            var compared: usize = 0;
            const actual = view.extend(source, 0, source.prefixLen(), start, block.len, &compared);
            try std.testing.expectEqual(mismatch, actual);
            try std.testing.expect(compared <= block.len - start);
        }
    }
}

test "Zstd HQ tree depth and nice change actual visits and the selected match" {
    var dictionary: [96 * 16]u8 = undefined;
    for (0..96) |segment| {
        const position = segment * 16;
        @memcpy(dictionary[position..][0..4], "abcd");
        @memset(dictionary[position + 4 .. position + 16], @intCast(segment));
    }
    var block: [32]u8 = undefined;
    @memcpy(block[0..16], dictionary[0..16]);
    @memset(block[16..], 255);
    const source = tree.Source.init(&dictionary, "", &block, dictionary.len);
    var shallow_profile: controls.Profile = .{};
    var deep_profile: controls.Profile = .{};
    var nice_profile: controls.Profile = .{};
    var shallow = try tree.Matcher.init(a, source, .{ .search_depth = 1, .nice_len = 32 }, &shallow_profile);
    defer shallow.deinit(a);
    var deep = try tree.Matcher.init(a, source, .{ .search_depth = 512, .nice_len = 32 }, &deep_profile);
    defer deep.deinit(a);
    var nice = try tree.Matcher.init(a, source, .{ .search_depth = 512, .nice_len = 4 }, &nice_profile);
    defer nice.deinit(a);
    const short = try shallow.find();
    const long = try deep.find();
    const fast = try nice.find();
    try std.testing.expectEqual(@as(usize, 16), long.best().length);
    try std.testing.expect(long.best().length > short.best().length);
    try std.testing.expect(long.best().length > fast.best().length);
    try std.testing.expect(deep_profile.tree_nodes > shallow_profile.tree_nodes);
    try std.testing.expect(deep_profile.byte_comparisons > nice_profile.byte_comparisons);
    try std.testing.expect(shallow_profile.depth_stops > 0);
    try std.testing.expectEqual(deep_profile.tree_nodes + deep_profile.short_hash_probes, deep_profile.candidate_checks);
    try std.testing.expectEqual(@as(u64, 0), deep_profile.rep_probes);
}

test "Zstd HQ tree preserves more than 256 increasing length frontier choices" {
    var dictionary = [_]u8{'a'} ** 401;
    dictionary[400] = 'b';
    const block = [_]u8{'a'} ** 600;
    const source = tree.Source.init(&dictionary, "", &block, 1024);
    var matcher = try tree.Matcher.init(a, source, .{ .search_depth = 512, .nice_len = 131072 }, null);
    defer matcher.deinit(a);
    const matches = try matcher.find();
    try std.testing.expect(matches.items.len > 256);
    try std.testing.expectEqual(@as(usize, 400), matches.best().length);
    try verify(source, 0, matches, 3);
}

test "Zstd HQ tree indexes every prefix byte and finds odd-position wide distances" {
    const prefix = try a.alloc(u8, 70003);
    defer a.free(prefix);
    var random = std.Random.DefaultPrng.init(0x108fde73);
    random.random().bytes(prefix);
    const block = prefix[1..74];
    var profile: controls.Profile = .{};
    const source = tree.Source.init(prefix[0..12001], prefix[12001..], block, 131072);
    var matcher = try tree.Matcher.init(a, source, .{ .search_depth = 256 }, &profile);
    defer matcher.deinit(a);
    const matches = try matcher.find();
    try std.testing.expectEqual(@as(usize, 70002), matches.best().distance);
    try std.testing.expectEqual(block.len, matches.best().length);
    try std.testing.expectEqual(@as(u64, 12001), profile.dictionary_seed_positions);
    try std.testing.expectEqual(@as(u64, 58002), profile.history_seed_positions);
    try std.testing.expectEqual(@as(u64, 0), profile.hq_passes);
    try std.testing.expectEqual(@as(u64, 0), profile.shared_seed_reuses);
}

test "Zstd HQ tree cyclic generations skip fork and moved owners preserve deterministic frontiers" {
    var block: [777]u8 = undefined;
    for (&block, 0..) |*byte, position| byte.* = 'a' + @as(u8, @intCast(position % 3));
    const source = tree.Source.init("abcabc", "abc", &block, 17);
    var every = try tree.Matcher.init(a, source, .{ .search_depth = 128, .nice_len = 48 }, null);
    defer every.deinit(a);
    var owner: ?tree.Matcher = try tree.Matcher.init(a, source, .{ .search_depth = 128, .nice_len = 48 }, null);
    defer if (owner) |*value| value.deinit(a);
    for (0..block.len) |position| {
        const expected = try every.find();
        if (position % 11 != 0) {
            try owner.?.skip(1);
            continue;
        }
        const actual = try owner.?.find();
        try verify(source, position, actual, 3);
        try std.testing.expectEqualSlices(tree.Match, expected.slice(), actual.slice());
        if (position == 22) {
            var fork_profile: controls.Profile = .{};
            var clone = try owner.?.fork(a, std.math.maxInt(usize), &fork_profile);
            defer clone.deinit(a);
            var next_reference = try every.fork(a, std.math.maxInt(usize), null);
            defer next_reference.deinit(a);
            try std.testing.expectEqualSlices(tree.Match, (try next_reference.find()).slice(), (try clone.find()).slice());
            try std.testing.expectEqual(@as(u64, 1), fork_profile.shared_seed_reuses);
        }
    }
    var moved = owner.?;
    owner = null;
    defer moved.deinit(a);
    try std.testing.expectError(error.InvalidBlockPlan, moved.advanceTo(0));
    const retained = moved.workingBytes();
    moved.reset();
    try std.testing.expectEqual(retained, moved.workingBytes());
    try std.testing.expectError(error.InvalidBlockPlan, moved.find());
    try moved.prepare(a, source, .{ .search_depth = 128, .nice_len = 48 }, null);
    try std.testing.expectEqual(@as(usize, 0), moved.position());
}

test "Zstd HQ tree exact cold and old-new workspace growth peaks enforce actual quota" {
    const first = tree.Source.init("abcabc", "abc", "abcabcabcabc", 64);
    const second = tree.Source.init("abcabc", "abc", "abcabcabcabc/other-content/abcabcabcabc" ** 9, 512);
    var ledger = working.WorkingAllocator.init(a, std.math.maxInt(usize));
    var profile: controls.Profile = .{};
    var baseline = try tree.Matcher.init(ledger.allocator(), first, .{}, &profile);
    try std.testing.expectEqual(try tree.Matcher.requiredWorkingMemory(first, .{}), baseline.workingBytes());
    try std.testing.expectEqual(baseline.workingBytes(), ledger.live);
    try baseline.prepare(ledger.allocator(), second, .{ .search_depth = 128 }, &profile);
    const peak = ledger.peak;
    try std.testing.expectEqual(peak, profile.peak_working_memory);
    baseline.deinit(ledger.allocator());
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    inline for (.{ false, true }) |below| {
        var limited = try tree.Matcher.init(a, first, .{}, null);
        defer limited.deinit(a);
        const options = tree.HqOptions{ .search_depth = 128, .max_working_memory = peak - @intFromBool(below) };
        if (below) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, limited.prepare(a, second, options, null));
            try std.testing.expectEqual(@as(usize, 0), limited.position());
        } else try limited.prepare(a, second, options, null);
    }
}

test "Zstd HQ tree failed growth and fork allocations leave the old checkpoint usable" {
    const source = tree.Source.init("abcabc", "abc", "abcabcabc/other/abcabcabc", 128);
    var failing = std.testing.FailingAllocator.init(a, .{});
    var owner = try tree.Matcher.init(failing.allocator(), source, .{}, null);
    defer owner.deinit(failing.allocator());
    _ = try owner.find();
    var reference = try owner.fork(a, std.math.maxInt(usize), null);
    defer reference.deinit(a);
    failing.fail_index = failing.alloc_index;
    const bigger = tree.Source.init("abcabc", "abc", "abcabcabc/other/abcabcabc" ** 20, 1024);
    try std.testing.expectError(error.OutOfMemory, owner.prepare(failing.allocator(), bigger, .{ .search_depth = 256 }, null));
    try std.testing.expectEqualSlices(tree.Match, (try reference.find()).slice(), (try owner.find()).slice());
    // The replacement nodes succeed, then candidate-buffer allocation fails.
    // The old modulo/generations and checkpoint must still remain usable.
    failing.fail_index = failing.alloc_index + 1;
    try std.testing.expectError(error.OutOfMemory, owner.prepare(failing.allocator(), bigger, .{ .search_depth = 256 }, null));
    try std.testing.expectEqualSlices(tree.Match, (try reference.find()).slice(), (try owner.find()).slice());
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, owner.fork(failing.allocator(), std.math.maxInt(usize), null));
    failing.fail_index = std.math.maxInt(usize);
    try std.testing.expectEqualSlices(tree.Match, (try reference.find()).slice(), (try owner.find()).slice());
    try std.testing.checkAllAllocationFailures(a, allocationCase, .{});
}

test "Zstd HQ tree malformed metadata tiny tails zero memory and saturation preserve behavior" {
    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    const empty = tree.Source.init("", "", "", 1);
    var zero = try tree.Matcher.init(failing.allocator(), empty, .{ .max_working_memory = 0 }, null);
    zero.deinit(failing.allocator());
    const huge: []const u8 = @as([*]const u8, @ptrFromInt(1))[0..std.math.maxInt(usize)];
    const malformed: tree.Source = .{ .dictionary = huge, .history = "a", .block = "abc", .window_len = 64 * 1024 * 1024 };
    try std.testing.expectError(error.IntegerOverflow, tree.Matcher.init(failing.allocator(), malformed, .{}, null));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, tree.Matcher.init(failing.allocator(), tree.Source.init("a", "", "aaaa", 4), .{ .max_working_memory = 0 }, null));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    for (3..8) |minimum| for ([_][]const u8{ "", "a", "aa", "aaa", "aaaa", "aaaaaaa" }) |block| {
        var profile: controls.Profile = .{ .tree_nodes = std.math.maxInt(u64), .byte_comparisons = std.math.maxInt(u64) };
        const source = tree.Source.init("aaaaaaa", "a", block, 8);
        var matcher = try tree.Matcher.init(a, source, .{ .min_match = @intCast(minimum), .nice_len = @intCast(minimum) }, &profile);
        defer matcher.deinit(a);
        for (0..block.len) |position| {
            const matches = try matcher.getMatches();
            const expected = if (block.len - position >= minimum) block.len - position else 0;
            try std.testing.expectEqual(expected, matches.best().length);
            try verify(source, position, matches, minimum);
        }
        try std.testing.expectEqual(std.math.maxInt(u64), profile.tree_nodes);
        try std.testing.expectEqual(std.math.maxInt(u64), profile.byte_comparisons);
    };
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    const source = tree.Source.init("abcabc", "abc", "abcabcabc/other/abcabcabc", 128);
    var owner: ?tree.Matcher = try tree.Matcher.init(allocator, source, .{}, null);
    defer if (owner) |*value| value.deinit(allocator);
    _ = try owner.?.find();
    var clone = try owner.?.fork(allocator, std.math.maxInt(usize), null);
    defer clone.deinit(allocator);
    try std.testing.expectEqualSlices(tree.Match, (try owner.?.find()).slice(), (try clone.find()).slice());
    var moved = owner.?;
    owner = null;
    defer moved.deinit(allocator);
    try moved.prepare(allocator, tree.Source.init("abcabc", "abc", "abcabcabc/other/abcabcabc" ** 20, 1024), .{ .search_depth = 256 }, null);
    _ = try moved.find();
}

fn verify(source: tree.Source, position: usize, matches: tree.Matches, minimum: usize) !void {
    var previous = minimum - 1;
    var iterator = matches.iterator();
    for (matches.slice()) |match| {
        try std.testing.expectEqualDeep(match, iterator.next().?);
        try std.testing.expect(match.length > previous);
        const absolute = source.prefixLen() + position;
        try std.testing.expect(match.distance != 0 and match.distance <= @min(source.window_len, absolute));
        try std.testing.expect(source.match(position, absolute - match.distance, minimum).length >= match.length);
        previous = match.length;
    }
    try std.testing.expectEqual(@as(?tree.Match, null), iterator.next());
}

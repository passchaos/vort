const std = @import("std");
const mf = @import("../match_finder.zig");
const settings = @import("../encode_options.zig");
const finders = [_]mf.MatchFinder{ .hc3, .hc4, .bt2, .bt3, .bt4 };

test "LZMA matcher vector extension matches scalar first mismatch at every lane" {
    const dictionary = [_]u8{'a'} ** 64;
    var input: [64]u8 = undefined;
    for (0..65) |mismatch| {
        @memset(&input, 'a');
        if (mismatch < input.len) input[mismatch] = 'b';
        const source = mf.Source.init(&dictionary, &input, 128);
        const expected = source.matchLength(0, dictionary.len, 64);
        for ([_]usize{ 0, @min(@as(usize, 17), mismatch) }) |start| {
            var compared: usize = 0;
            try std.testing.expectEqual(expected, source.extend(0, dictionary.len, start, 64, &compared));
            try std.testing.expect(compared <= 64 - start);
        }
    }
}

test "LZMA matcher deep searches agree with brute force across virtual spans and short tails" {
    var random = std.Random.DefaultPrng.init(0xe7ab3d89);
    var dictionary: [47]u8 = undefined;
    var input: [83]u8 = undefined;
    for (0..24) |iteration| {
        for (&dictionary) |*byte| byte.* = 'a' + random.random().uintLessThan(u8, 4);
        for (&input) |*byte| byte.* = 'a' + random.random().uintLessThan(u8, 4);
        if (iteration % 3 == 0) @memset(input[12..], 'a');
        if (iteration % 3 == 1) @memcpy(input[0..30], dictionary[17..]);
        for (finders) |finder| {
            const source = mf.Source.init(&dictionary, &input, if (iteration % 2 == 0) 31 else 256);
            var matcher = try mf.Matcher.init(std.testing.allocator, source, .{ .finder = finder, .nice_len = 273, .depth = 512 });
            defer matcher.deinit(std.testing.allocator);
            for (0..input.len) |position| {
                const matches = try matcher.find();
                try verify(source, position, &matches);
                const absolute = source.prefixLen() + position;
                var longest: usize = 0;
                for (absolute - @min(absolute, source.window_len)..absolute) |candidate|
                    longest = @max(longest, source.matchLength(candidate, absolute, 273));
                try std.testing.expectEqual(if (longest >= 2) longest else 0, @as(usize, matches.best().length));
            }
        }
    }
}

test "LZMA matcher nice and depth change actual chain and tree traversal" {
    var dictionary: [64 * 16]u8 = undefined;
    for (0..64) |segment| {
        const at = segment * 16;
        @memcpy(dictionary[at..][0..4], "abcd");
        @memset(dictionary[at + 4 .. at + 16], @intCast(segment));
    }
    var input: [32]u8 = undefined;
    @memcpy(input[0..16], dictionary[0..16]);
    @memset(input[16..], 255);
    for (finders) |finder| {
        var shallow_profile: settings.EncodeWorkProfile = .{};
        var deep_profile: settings.EncodeWorkProfile = .{};
        var nice_profile: settings.EncodeWorkProfile = .{};
        const source = mf.Source.init(&dictionary, &input, dictionary.len);
        var shallow = try mf.Matcher.init(std.testing.allocator, source, .{ .finder = finder, .nice_len = 32, .depth = 1, .profile = &shallow_profile });
        defer shallow.deinit(std.testing.allocator);
        var deep = try mf.Matcher.init(std.testing.allocator, source, .{ .finder = finder, .nice_len = 32, .depth = 512, .profile = &deep_profile });
        defer deep.deinit(std.testing.allocator);
        var nice = try mf.Matcher.init(std.testing.allocator, source, .{ .finder = finder, .nice_len = 4, .depth = 512, .profile = &nice_profile });
        defer nice.deinit(std.testing.allocator);
        const short_matches = try shallow.find();
        const deep_matches = try deep.find();
        const nice_matches = try nice.find();
        try verify(source, 0, &short_matches);
        try verify(source, 0, &deep_matches);
        try verify(source, 0, &nice_matches);
        try std.testing.expectEqual(@as(u16, 16), deep_matches.best().length);
        try std.testing.expect(deep_matches.best().length > short_matches.best().length);
        try std.testing.expect(deep_matches.best().length > nice_matches.best().length);
        if (finder.isBinaryTree()) {
            try std.testing.expect(deep_profile.mf_tree_steps > shallow_profile.mf_tree_steps);
            try std.testing.expectEqual(@as(u64, 0), deep_profile.mf_chain_steps);
        } else {
            try std.testing.expect(deep_profile.mf_chain_steps > shallow_profile.mf_chain_steps);
            try std.testing.expectEqual(@as(u64, 0), deep_profile.mf_tree_steps);
        }
        try std.testing.expect(deep_profile.mf_compared_bytes > nice_profile.mf_compared_bytes);
    }
}

test "LZMA matcher skips retain identical indexes through cyclic reuse and overlapping copies" {
    var input: [777]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = 'a' + @as(u8, @intCast(i % 3));
    for (finders) |finder| {
        var profile: settings.EncodeWorkProfile = .{};
        const source = mf.Source.init("abcabc", &input, 17);
        var every = try mf.Matcher.init(std.testing.allocator, source, .{ .finder = finder, .nice_len = 48, .depth = 64 });
        defer every.deinit(std.testing.allocator);
        var skipped = try mf.Matcher.init(std.testing.allocator, source, .{ .finder = finder, .nice_len = 48, .depth = 64, .profile = &profile });
        defer skipped.deinit(std.testing.allocator);
        for (0..input.len) |position| {
            const reference = try every.find();
            if (position % 13 != 0) {
                try skipped.skip(1);
                continue;
            }
            const actual = try skipped.find();
            try verify(source, position, &actual);
            try std.testing.expectEqualSlices(mf.Match, reference.slice(), actual.slice());
            if (position + 273 <= input.len) try std.testing.expectEqual(@as(u16, 273), actual.best().length);
        }
        try std.testing.expect(profile.mf_skipped_positions > 0);
        try std.testing.expectEqual(input.len, skipped.position());
        try std.testing.expectError(error.InvalidBlockPlan, skipped.advanceTo(0));
        try std.testing.expectError(error.InvalidBlockPlan, skipped.skip(1));
    }
}

test "LZMA matcher preserves distances beyond sixteen bits from seeded dictionary" {
    const dictionary = try std.testing.allocator.alloc(u8, 70000);
    defer std.testing.allocator.free(dictionary);
    var random = std.Random.DefaultPrng.init(0x62fed3);
    random.random().bytes(dictionary);
    const input = dictionary[0..37];
    for (finders) |finder| {
        var profile: settings.EncodeWorkProfile = .{};
        const source = mf.Source.init(dictionary, input, 131072);
        var matcher = try mf.Matcher.init(std.testing.allocator, source, .{ .finder = finder, .nice_len = 32, .depth = 512, .profile = &profile });
        defer matcher.deinit(std.testing.allocator);
        const matches = try matcher.find();
        try verify(source, 0, &matches);
        try std.testing.expectEqual(@as(u32, 70000), matches.best().distance);
        try std.testing.expectEqual(@as(u16, 37), matches.best().length);
        try std.testing.expectEqual(@as(u64, 70000), profile.mf_seed_positions);
        try std.testing.expectEqual(@as(u64, 70001), profile.mf_positions);
    }
}

test "LZMA matcher resources exact fixed heap quota and every allocation failure" {
    for (finders) |finder| {
        const source = mf.Source.init("abcabc", "abcabcabcabc", 64);
        var baseline = try mf.Matcher.init(std.testing.allocator, source, .{ .finder = finder });
        const bytes = baseline.workingBytes();
        baseline.deinit(std.testing.allocator);
        var exact = try mf.Matcher.init(std.testing.allocator, source, .{ .finder = finder, .max_working_memory = bytes });
        exact.deinit(std.testing.allocator);
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, mf.Matcher.init(failing.allocator(), source, .{ .finder = finder, .max_working_memory = bytes - 1 }));
        try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
        try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationCase, .{finder});
        var empty = try mf.Matcher.init(failing.allocator(), mf.Source.init("", "", 64), .{ .finder = finder, .max_working_memory = 0 });
        empty.deinit(failing.allocator());
    }
}

test "LZMA matcher tiny tails and profile saturation preserve candidates" {
    for (finders) |finder| {
        for ([_][]const u8{ "", "a", "aa", "aaa", "aaaa" }) |input| {
            var profile: settings.EncodeWorkProfile = .{ .mf_positions = std.math.maxInt(u64), .mf_candidate_probes = std.math.maxInt(u64) };
            const source = mf.Source.init("aaaa", input, 4);
            var matcher = try mf.Matcher.init(std.testing.allocator, source, .{ .finder = finder, .nice_len = 2, .depth = 1, .profile = &profile });
            defer matcher.deinit(std.testing.allocator);
            for (0..input.len) |position| {
                const matches = try matcher.find();
                try verify(source, position, &matches);
                const expected = @min(input.len - position, 273);
                try std.testing.expectEqual(if (expected >= 2) expected else 0, @as(usize, matches.best().length));
            }
            try std.testing.expectEqual(std.math.maxInt(u64), profile.mf_positions);
            try std.testing.expectEqual(std.math.maxInt(u64), profile.mf_candidate_probes);
        }
    }
}

fn allocationCase(allocator: std.mem.Allocator, finder: mf.MatchFinder) !void {
    var owner: ?mf.Matcher = try mf.Matcher.init(allocator, mf.Source.init("abcabc", "abcabcabcabcabc", 8), .{ .finder = finder });
    defer if (owner) |*value| value.deinit(allocator);
    _ = try owner.?.find();
    try owner.?.advanceTo(8);
    var moved = owner.?;
    owner = null;
    defer moved.deinit(allocator);
    _ = try moved.find();
}

fn verify(source: mf.Source, position: usize, matches: *const mf.Matches) !void {
    var previous: usize = 1;
    for (matches.slice()) |match| {
        try std.testing.expect(match.length > previous and match.length <= 273);
        try std.testing.expect(match.distance > 0 and match.distance <= source.window_len);
        const absolute = source.prefixLen() + position;
        try std.testing.expect(match.distance <= absolute);
        try std.testing.expect(source.matchLength(absolute - match.distance, absolute, match.length) == match.length);
        previous = match.length;
    }
}

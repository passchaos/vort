const std = @import("std");
const Codec = @import("adaptive_tree.zig");
const policy = @import("hq_tree/policy.zig");
const controls = @import("../encode/controls.zig");
const working = @import("../../io/working_allocator.zig");
const a = std.testing.allocator;

fn verify(source: Codec.Source, position: usize, matches: Codec.Matches, minimum: usize) !void {
    var previous = minimum - 1;
    var iterator = matches.iterator();
    const absolute = source.prefixLen() + position;
    for (matches.slice()) |match| {
        try std.testing.expectEqualDeep(match, iterator.next().?);
        try std.testing.expect(match.length > previous);
        try std.testing.expect(match.distance > 0 and match.distance <= @min(source.window_len, absolute));
        // Independent scalar source oracle checks every emitted match byte,
        // including dictionary/history crossings and overlapping references.
        try std.testing.expect(source.match(position, absolute - match.distance, minimum).length >= match.length);
        previous = match.length;
    }
    try std.testing.expectEqual(@as(?Codec.Match, null), iterator.next());
}

test "Zstd adaptive matcher sized heads and retained masks charge exact workspace" {
    for ([_]usize{ 0, 1, 2, 3, 4, 255, 256, 257, 511, 512, 513, 4096, 65535, 65536, 65537 }) |total| {
        for ([_]usize{ 1, 255, 256, 511, 4095, 65536 }) |window| {
            const count = policy.headCount(total, window, true);
            const desired = @max(@as(usize, 256), @min(@as(usize, 65536), @min(total, window + 1)));
            try std.testing.expect(count >= desired and count <= 65536);
            try std.testing.expect(count & (count - 1) == 0);
            if (count > 256) try std.testing.expect(count / 2 < desired);
        }
    }
    const large_source = Codec.Source.init("", "", "abcd" ** 1024, 8192);
    const small_source = Codec.Source.init("abca", "", "abcabcabc", 64);
    var ledger = working.WorkingAllocator.init(a, std.math.maxInt(usize));
    var owner = try Codec.Matcher.init(ledger.allocator(), large_source, .{}, null);
    defer owner.deinit(ledger.allocator());
    try std.testing.expectEqual(try Codec.requiredWorkingMemory(large_source, .{}), owner.workingBytes());
    try std.testing.expectEqual(owner.workingBytes(), ledger.live);
    const short_capacity = owner.short_heads.len;
    const bytes = owner.workingBytes();
    try owner.prepare(ledger.allocator(), small_source, .{}, null);
    try std.testing.expectEqual(short_capacity, owner.short_heads.len);
    try std.testing.expectEqual(bytes, owner.workingBytes());
    const active = policy.headCount(small_source.totalLen(), small_source.window_len, Codec.sized_heads);
    try std.testing.expectEqual(active - 1, owner.metadata.short_mask);
    try std.testing.expectEqual(active - 1, owner.metadata.long_mask);
    // Poison old inactive heads: find must use the active masks, not capacity.
    @memset(owner.short_heads[active..], std.math.maxInt(u32) - 1);
    @memset(owner.long_heads[active..], std.math.maxInt(u32) - 1);
    try verify(small_source, 0, try owner.find(), 3);
    var clone = try owner.fork(ledger.allocator(), std.math.maxInt(usize), null);
    defer clone.deinit(ledger.allocator());
    try std.testing.expectEqual(active, clone.short_heads.len);
    try std.testing.expectEqual(owner.metadata.short_mask, clone.metadata.short_mask);
    try std.testing.expectEqualSlices(Codec.Match, (try owner.find()).slice(), (try clone.find()).slice());
}

test "Zstd adaptive matcher dense prefix and real matches agree with independent longest oracle" {
    var dictionary: [31]u8 = undefined;
    var history: [19]u8 = undefined;
    var block: [113]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x29137abc);
    for (0..16) |seed| {
        for (&dictionary) |*byte| byte.* = 'a' + random.random().uintLessThan(u8, 4);
        for (&history) |*byte| byte.* = 'a' + random.random().uintLessThan(u8, 4);
        for (&block) |*byte| byte.* = 'a' + random.random().uintLessThan(u8, 4);
        if (seed % 3 == 0) @memset(block[27..], 'a');
        for ([_]u8{ 3, 4, 7 }) |minimum| {
            const source = Codec.Source.init(&dictionary, &history, &block, if (seed % 2 == 0) 31 else 256);
            var profile: controls.Profile = .{};
            var owner = try Codec.Matcher.init(a, source, .{ .search_depth = 512, .nice_len = 131072, .min_match = minimum }, &profile);
            defer owner.deinit(a);
            try std.testing.expectEqual(@as(u64, source.dictionary.len), profile.dictionary_seed_positions);
            try std.testing.expectEqual(@as(u64, source.history.len), profile.history_seed_positions);
            for (0..block.len) |position| {
                const matches = try owner.find();
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

test "Zstd adaptive matcher explicit block sparse skips preserve progress dense tails and valid generations" {
    for ([_]Codec.Source{ Codec.Source.init("abca" ** 16, "abca" ** 8, "abca" ** 512, 4096), Codec.Source.init("", "", "abca" ** 512, 4096) }) |source| {
        for ([_]usize{ 0, 1, 127, 128, 129, 256, 1024 }) |span| {
            var profile: controls.Profile = .{};
            var owner = try Codec.Matcher.init(a, source, .{}, &profile);
            defer owner.deinit(a);
            const initial = owner.indexed_positions;
            try owner.skip(span);
            try std.testing.expectEqual(span, owner.position());
            try std.testing.expectEqual(@as(u64, span), profile.skipped_positions);
            const inserted = if (Codec.sparse_skip and source.prefixLen() == 0 and span > 128) (span - 64 + 7) / 8 + 64 else span;
            try std.testing.expectEqual(initial + inserted, owner.indexed_positions);
            const end = source.prefixLen() + span;
            if (span > 64) for (end - 64..end) |absolute|
                try std.testing.expectEqual(@as(u32, @intCast(absolute)), owner.nodes[absolute % owner.cycle_size].position);
            try verify(source, span, try owner.find(), 3);
            try std.testing.expectEqual(@as(u64, source.dictionary.len), profile.dictionary_seed_positions);
            try std.testing.expectEqual(@as(u64, source.history.len), profile.history_seed_positions);
        }
    }
    const cycle_source = Codec.Source.init("abcabc", "abc", "abc" ** 1024, 17);
    var owner = try Codec.Matcher.init(a, cycle_source, .{ .search_depth = 128, .nice_len = 48 }, null);
    defer owner.deinit(a);
    for ([_]usize{ 129, 258, 777, 999, 1888, 2500 }) |position| {
        try owner.advanceTo(position);
        try verify(cycle_source, position, try owner.find(), 3);
    }
    // Inject a stale generation which superficially looks like a usable head.
    // The candidate points to a node with another stamp and must be ignored.
    const stale: u32 = @intCast(owner.cursor - 3);
    @memset(owner.short_heads[0 .. owner.metadata.short_mask + 1], stale);
    @memset(owner.long_heads[0 .. owner.metadata.long_mask + 1], stale);
    owner.nodes[stale % owner.cycle_size].position = std.math.maxInt(u32);
    const next_position = owner.position();
    const rejected = try owner.find();
    try std.testing.expectEqual(@as(usize, 0), rejected.slice().len);
    try verify(cycle_source, next_position, rejected, 3);
}

test "Zstd adaptive matcher deterministic prepare reset fork and moved ownership" {
    const source = Codec.Source.init("abcdXabcdY", "abcd", "abcdXabcdY/abcdXabcdY/" ** 16, 1024);
    var owner = try Codec.Matcher.init(a, source, .{ .nice_len = 48 }, null);
    defer owner.deinit(a);
    var second = try Codec.Matcher.init(a, source, .{ .nice_len = 48 }, null);
    defer second.deinit(a);
    for ([_]usize{ 0, 1, 64, 197, 280 }) |position| {
        try owner.advanceTo(position);
        try second.advanceTo(position);
        const first = try owner.find();
        const next = try second.find();
        try std.testing.expectEqualSlices(Codec.Match, first.slice(), next.slice());
        try verify(source, position, first, 3);
    }
    const retained = owner.workingBytes();
    owner.reset();
    try std.testing.expectEqual(retained, owner.workingBytes());
    try std.testing.expectError(error.InvalidBlockPlan, owner.find());
    try owner.prepare(a, source, .{ .nice_len = 48 }, null);
    try second.prepare(a, source, .{ .nice_len = 48 }, null);
    try std.testing.expectEqualSlices(Codec.Match, (try owner.find()).slice(), (try second.find()).slice());
    var clone = try owner.fork(a, std.math.maxInt(usize), null);
    var moved = clone;
    clone = undefined;
    defer moved.deinit(a);
    try std.testing.expectEqualSlices(Codec.Match, (try owner.find()).slice(), (try moved.find()).slice());
}

test "Zstd adaptive matcher exact zero below growth and allocation failures preserve old state" {
    const first = Codec.Source.init("abcabc", "abc", "abcabcabcabc", 64);
    const large = Codec.Source.init("abcabc", "abc", "abcabcabc/other/" ** 100, 4096);
    const required = try Codec.requiredWorkingMemory(first, .{});
    var exact = try Codec.Matcher.init(a, first, .{ .max_working_memory = required }, null);
    exact.deinit(a);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Codec.Matcher.init(a, first, .{ .max_working_memory = required - 1 }, null));
    var profile: controls.Profile = .{};
    var ledger = working.WorkingAllocator.init(a, std.math.maxInt(usize));
    var measured = try Codec.Matcher.init(ledger.allocator(), first, .{}, &profile);
    try measured.prepare(ledger.allocator(), large, .{ .search_depth = 256 }, &profile);
    const peak = ledger.peak;
    try std.testing.expectEqual(peak, profile.peak_working_memory);
    measured.deinit(ledger.allocator());
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    for ([_]bool{ false, true }) |below| {
        var owner = try Codec.Matcher.init(a, first, .{}, null);
        defer owner.deinit(a);
        const options: Codec.HqOptions = .{ .search_depth = 256, .max_working_memory = peak - @intFromBool(below) };
        if (below) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.prepare(a, large, options, null));
            try std.testing.expectEqual(@as(usize, 0), owner.position());
        } else try owner.prepare(a, large, options, null);
    }
    // Measure this policy's actual prepare allocations instead of assuming
    // that head buffers grow. Unsized heads retain their initial full tables.
    const allocation_count = measured: {
        var counting = std.testing.FailingAllocator.init(a, .{});
        var initial = try Codec.Matcher.init(counting.allocator(), first, .{}, null);
        const begin = counting.alloc_index;
        try initial.prepare(counting.allocator(), large, .{ .search_depth = 256 }, null);
        const count = counting.alloc_index - begin;
        initial.deinit(counting.allocator());
        try std.testing.expectEqual(counting.allocated_bytes, counting.freed_bytes);
        break :measured count;
    };
    try std.testing.expect(allocation_count > 0);
    for (0..allocation_count + 1) |offset| {
        var failing = std.testing.FailingAllocator.init(a, .{});
        {
            var owner = try Codec.Matcher.init(failing.allocator(), first, .{}, null);
            defer owner.deinit(failing.allocator());
            _ = try owner.find();
            var reference = try owner.fork(a, std.math.maxInt(usize), null);
            defer reference.deinit(a);
            const checkpoint = owner.position();
            const old_source = owner.source;
            const old_cycle = owner.cycle_size;
            const old_short_mask = owner.metadata.short_mask;
            const old_long_mask = owner.metadata.long_mask;
            const begin = failing.alloc_index;
            failing.fail_index = begin + offset;
            if (offset < allocation_count) {
                try std.testing.expectError(error.OutOfMemory, owner.prepare(failing.allocator(), large, .{ .search_depth = 256 }, null));
                try std.testing.expect(failing.has_induced_failure);
                try std.testing.expectEqual(offset, failing.alloc_index - begin);
                try std.testing.expectEqual(checkpoint, owner.position());
                try std.testing.expectEqualDeep(old_source, owner.source);
                try std.testing.expectEqual(old_cycle, owner.cycle_size);
                try std.testing.expectEqual(old_short_mask, owner.metadata.short_mask);
                try std.testing.expectEqual(old_long_mask, owner.metadata.long_mask);
                try std.testing.expectEqualSlices(Codec.Match, (try owner.find()).slice(), (try reference.find()).slice());
            } else {
                try owner.prepare(failing.allocator(), large, .{ .search_depth = 256 }, null);
                try std.testing.expect(!failing.has_induced_failure);
                try std.testing.expectEqual(allocation_count, failing.alloc_index - begin);
                try std.testing.expectEqual(@as(usize, 0), owner.position());
                try std.testing.expectEqualDeep(large, owner.source);
                var fresh = try Codec.Matcher.init(a, large, .{ .search_depth = 256 }, null);
                defer fresh.deinit(a);
                const matches = try owner.find();
                try verify(large, 0, matches, 3);
                try std.testing.expectEqualSlices(Codec.Match, matches.slice(), (try fresh.find()).slice());
            }
        }
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
    std.debug.print("adaptive_prepare_allocation_count={d} true_failure_prefixes={d} final_success+checkpoint+cleanup=pass\n", .{ allocation_count, allocation_count });
    try std.testing.checkAllAllocationFailures(a, allocationCase, .{});
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    const source = Codec.Source.init("abcd", "abcd", "abcdabcdabcd/abcdabcd", 256);
    var owner = try Codec.Matcher.init(allocator, source, .{}, null);
    defer owner.deinit(allocator);
    try owner.skip(1);
    var clone = try owner.fork(allocator, std.math.maxInt(usize), null);
    defer clone.deinit(allocator);
    try owner.prepare(allocator, Codec.Source.init("abcd", "abcd", "abcd/xyz" ** 128, 4096), .{ .search_depth = 256 }, null);
    _ = try owner.find();
}

test "Zstd adaptive matcher immutable sources tiny metadata and preflight arithmetic" {
    var prefix: [31]u8 = @splat('a');
    var block: [257]u8 = @splat('a');
    const prefix_before = prefix;
    const block_before = block;
    var owner = try Codec.Matcher.init(a, Codec.Source.init(&prefix, "", &block, 1024), .{}, null);
    defer owner.deinit(a);
    try owner.skip(129);
    _ = try owner.find();
    try std.testing.expectEqualSlices(u8, &prefix_before, &prefix);
    try std.testing.expectEqualSlices(u8, &block_before, &block);
    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    var empty = try Codec.Matcher.init(failing.allocator(), Codec.Source.init("", "", "", 1), .{ .max_working_memory = 0 }, null);
    empty.deinit(failing.allocator());
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Codec.Matcher.init(failing.allocator(), Codec.Source.init("a", "", "aaaa", 4), .{ .max_working_memory = 0 }, null));
    const fake: []const u8 = @as([*]const u8, @ptrFromInt(1))[0..std.math.maxInt(usize)];
    const invalid: Codec.Source = .{ .dictionary = fake, .history = "x", .block = "aaa", .window_len = 1024 };
    try std.testing.expectError(error.IntegerOverflow, Codec.Matcher.init(failing.allocator(), invalid, .{}, null));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    for ([_][]const u8{ "", "a", "aa", "aaa", "aaaaaaa" }) |tiny| {
        var matcher = try Codec.Matcher.init(a, Codec.Source.init("aaaa", "", tiny, 8), .{}, null);
        defer matcher.deinit(a);
        for (0..tiny.len) |position| try verify(matcher.source, position, try matcher.find(), 3);
    }
}

test "Zstd adaptive matcher local parser replay and measured finite cap are deterministic" {
    const parser = @import("hq_parser/frontier_parser.zig");
    const state = @import("hq_parser/state.zig");
    const resources = @import("hq_parser/resources.zig");
    const repeats = @import("hq_parser/rep.zig");
    const source = Codec.Source.init("abc123abc123", "Xabc123", "abc123abc123Xabc123Y" ** 32, 2048);
    var profile: controls.Profile = .{};
    var parameters: state.Parameters = .{ .strategy = .btopt, .profile = &profile, .hq_options = .{ .nice_len = 32 } };
    var budget = resources.WorkingAllocator.init(a, std.math.maxInt(usize));
    const first = try parser.plan(budget.allocator(), &budget, source, parameters, Codec.Matcher);
    defer first.deinit(budget.allocator());
    const cap = profile.max_plan_price_evaluations;
    try std.testing.expect(cap > 0 and first.records.len > 0);
    const output = try a.alloc(u8, source.block.len);
    defer a.free(output);
    var written: usize = 0;
    var history = repeats.initial_repeats;
    for (first.records, first.offset_values) |record, offset| {
        @memcpy(output[written..][0..record.literal_len], source.block[written..][0..record.literal_len]);
        written += record.literal_len;
        const choice = try repeats.resolve(record.literal_len, offset, history);
        try std.testing.expectEqual(choice.distance, record.distance);
        history = choice.repeats;
        for (0..record.match_len) |_| {
            try std.testing.expect(record.distance > 0 and record.distance <= source.prefixLen() + written);
            const candidate = source.prefixLen() + written - record.distance;
            output[written] = if (candidate < source.prefixLen()) source.byteAt(candidate) else output[candidate - source.prefixLen()];
            written += 1;
        }
        try std.testing.expectEqual(record.match_end, written);
    }
    @memcpy(output[written..], source.block[written..]);
    try std.testing.expectEqualSlices(u8, source.block, output);
    try std.testing.expectEqualDeep(first.final_repeated_offsets, history);
    parameters.hq_options.max_price_evaluations = cap;
    profile.reset();
    var exact_budget = resources.WorkingAllocator.init(a, std.math.maxInt(usize));
    const exact = try parser.plan(exact_budget.allocator(), &exact_budget, source, parameters, Codec.Matcher);
    defer exact.deinit(exact_budget.allocator());
    try std.testing.expectEqualDeep(first.records, exact.records);
    try std.testing.expectEqualSlices(u32, first.offset_values, exact.offset_values);
    try std.testing.expectEqual(first.estimated_cost, exact.estimated_cost);
    try std.testing.expectEqual(cap, profile.max_plan_price_evaluations);
    parameters.hq_options.max_price_evaluations = cap - 1;
    profile.reset();
    var refused_budget = resources.WorkingAllocator.init(a, std.math.maxInt(usize));
    try std.testing.expectError(error.SearchLimitExceeded, parser.plan(refused_budget.allocator(), &refused_budget, source, parameters, Codec.Matcher));
    try std.testing.expectEqual(@as(usize, 0), refused_budget.live);
    try std.testing.expectEqual(cap - 1, profile.max_plan_price_evaluations);
}

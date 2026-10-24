const std = @import("std");
const builtin = @import("builtin");
const settings = @import("encode_options.zig");
const mf = @import("match_finder.zig");
const wide = @import("wide_match.zig");
const encoder = @import("encoder.zig");
const range_encoder = @import("range_encoder.zig");
const finders = [_]settings.MatchFinder{ .hc3, .hc4, .bt2, .bt3, .bt4 };

test "LZMA large dictionary core authority preserves presets and clips actual allocations" {
    try std.testing.expectEqual(@as(usize, 1610612736), settings.max_dictionary_size);
    try std.testing.expectEqual(settings.max_dictionary_size, encoder.max_dictionary_size);
    try std.testing.expectEqual(settings.max_dictionary_size, wide.max_window_len);
    try std.testing.expectEqual(settings.max_dictionary_size, mf.max_window_len);
    try std.testing.expectEqual(@as(usize, 2 * 1024 * 1024), settings.max_lzma2_chunk_plain);
    try encoder.validateOptions(.{ .dictionary_size = settings.max_dictionary_size });
    try std.testing.expectError(error.InvalidLzmaOptions, encoder.validateOptions(.{ .dictionary_size = settings.max_dictionary_size + 1 }));
    const dictionaries = [_]u32{ 256 * 1024, 1024 * 1024, 2 * 1024 * 1024, 4 * 1024 * 1024, 4 * 1024 * 1024, 8 * 1024 * 1024, 8 * 1024 * 1024, 16 * 1024 * 1024, 32 * 1024 * 1024, 64 * 1024 * 1024 };
    for (dictionaries, 0..) |size, level| {
        for ([_]bool{ false, true }) |extreme|
            try std.testing.expectEqual(size, (try settings.resolvePreset(@intCast(level), extreme)).dictionary_size);
    }
    const source = mf.Source.init("abcabc", "abcabcabcabc", settings.max_dictionary_size);
    for (finders) |finder| {
        const required = try mf.requiredWorkingMemory(source, .{ .finder = finder });
        try std.testing.expect(required < 2 * 1024 * 1024);
        var matcher = try mf.Matcher.init(std.testing.allocator, source, .{ .finder = finder, .max_working_memory = required });
        defer matcher.deinit(std.testing.allocator);
        try std.testing.expectEqual(source.totalLen(), matcher.cycle_size);
        try std.testing.expectEqual(required, matcher.workingBytes());
        try std.testing.expectEqual(@as(u16, 12), (try matcher.find()).best().length);
    }
    var stream = try wide.StreamPlanner.init(std.testing.allocator, settings.max_dictionary_size, 12);
    defer stream.deinit();
    try std.testing.expectEqual(@as(usize, 16), stream.previous.items.len);
    try std.testing.expect(stream.workingBytes() < 1024 * 1024);
}

test "LZMA large dictionary core source bounds and overflow reject before sample access" {
    const synthetic: []const u8 = @as([*]const u8, @ptrFromInt(4096))[0 .. std.math.maxInt(usize) - 1];
    const bad: mf.Source = .{ .dictionary = "aa", .input = synthetic, .window_len = settings.max_dictionary_size };
    try std.testing.expectError(error.InvalidBlockPlan, bad.checkedTotalLen());
    try std.testing.expectEqual(@as(usize, 0), bad.totalLen());
    try std.testing.expectError(error.InvalidBlockPlan, mf.requiredWorkingMemory(bad, .{}));
    try std.testing.expectEqual(@as(usize, 0), bad.matchLength(0, 2, 64));
    var compared: usize = 0;
    try std.testing.expectEqual(@as(usize, 0), bad.extend(0, 2, 0, 64, &compared));
    const source = mf.Source.init("abc", "abcabc", 16);
    try std.testing.expectEqual(@as(usize, 6), source.extend(0, 3, 0, std.math.maxInt(usize), &compared));
    try std.testing.expectEqual(@as(usize, 0), source.extend(0, 3, std.math.maxInt(usize), std.math.maxInt(usize), &compared));
    try std.testing.expectEqual(@as(usize, 0), source.extend(0, std.math.maxInt(usize), 0, 64, &compared));
    try std.testing.expectEqual(@as(usize, 0), source.matchLength(0, std.math.maxInt(usize), 64));
    try std.testing.expectEqual(@as(usize, 0), source.extend(3, 3, 0, 64, &compared));
}

test "LZMA large dictionary core budgets and signed index limits precede allocations" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const source = mf.Source.init("abc", "abcabc", settings.max_dictionary_size);
    const required = try mf.requiredWorkingMemory(source, .{});
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, mf.Matcher.init(failing.allocator(), source, .{ .max_working_memory = required - 1 }));
    const stream_bytes = try wide.StreamPlanner.requiredWorkingMemory(settings.max_dictionary_size, 9);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, wide.StreamPlanner.initWithLimit(failing.allocator(), settings.max_dictionary_size, 9, stream_bytes - 1));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, wide.planAlloc(failing.allocator(), "abcabc", "abc", .{ .window_len = settings.max_dictionary_size, .max_working_memory = 0 }));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    try std.testing.expectError(error.InvalidBlockPlan, wide.requiredPlanWorkingMemory(std.math.maxInt(i32), 1, .{ .window_len = settings.max_dictionary_size }));
    if (@bitSizeOf(usize) > 63)
        try std.testing.expectError(error.InvalidBlockPlan, wide.StreamPlanner.requiredWorkingMemory(settings.max_dictionary_size, @as(usize, std.math.maxInt(i64)) + 1));
    const synthetic: []const u8 = @as([*]const u8, @ptrFromInt(4096))[0 .. 64 * 1024 * 1024 + 1];
    const large_source = mf.Source.init(synthetic, "abcdefgh", synthetic.len);
    const large_bytes = try mf.requiredWorkingMemory(large_source, .{ .finder = .bt4 });
    try std.testing.expect(large_bytes > 1024 * 1024 * 1024);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, mf.Matcher.init(failing.allocator(), large_source, .{ .finder = .bt4, .max_working_memory = 8 * 1024 * 1024 }));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
}

test "LZMA large dictionary core two MiB streaming plans replay greedy and lazy" {
    const input = try std.testing.allocator.alloc(u8, settings.max_lzma2_chunk_plain + 1);
    defer std.testing.allocator.free(input);
    for (input, 0..) |*byte, i| byte.* = @truncate(i % 251);
    for ([_]bool{ false, true }) |lazy| {
        var planner = try wide.StreamPlanner.init(std.testing.allocator, settings.max_dictionary_size, input.len);
        defer planner.deinit();
        try std.testing.expectError(error.InvalidBlockPlan, planner.planChunk(input, 0, input.len));
        const plan = if (lazy) try planner.planChunkLazy(input, 0, settings.max_lzma2_chunk_plain) else try planner.planChunk(input, 0, settings.max_lzma2_chunk_plain);
        const output = try std.testing.allocator.alloc(u8, settings.max_lzma2_chunk_plain);
        defer std.testing.allocator.free(output);
        var position: usize = 0;
        for (plan.tokens) |token| switch (token) {
            .literal => |byte| {
                output[position] = byte;
                position += 1;
            },
            .match => |match| for (0..match.length) |_| {
                output[position] = output[position - match.distance];
                position += 1;
            },
        };
        try std.testing.expectEqual(settings.max_lzma2_chunk_plain, position);
        try std.testing.expectEqualSlices(u8, input[0..position], output);
        try std.testing.expectEqual(position, plan.stats.literals + plan.stats.matched_bytes);
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(std.testing.allocator);
        const options: encoder.EncodeOptions = .{ .dictionary_size = settings.max_dictionary_size, .mode = if (lazy) .lazy else .greedy };
        var model = try encoder.initModel(options);
        const payload_len = try encoder.encodeChunkAppendWithModelLimit(std.testing.allocator, &encoded, input[0..position], "", 0, options, plan, &model, 65_536);
        try std.testing.expect(payload_len < 65_536);
        _ = try planner.planChunk(input, position, input.len);
        try std.testing.expectEqual(input.len, planner.next_position);
    }
}

test "LZMA large dictionary core streaming growth budget preserves planner on failure" {
    const input = try std.testing.allocator.alloc(u8, 131_073);
    defer std.testing.allocator.free(input);
    @memset(input, 'a');
    const required = try wide.StreamPlanner.requiredWorkingMemory(settings.max_dictionary_size, input.len);
    var planner = try wide.StreamPlanner.initWithLimit(std.testing.allocator, settings.max_dictionary_size, input.len, required);
    defer planner.deinit();
    _ = try planner.planChunk(input, 0, 65_536);
    const position = planner.next_position;
    const indexed = planner.indexed_positions;
    const before = try std.testing.allocator.dupe(wide.Token, planner.tokens.items);
    defer std.testing.allocator.free(before);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, planner.planChunk(input, position, input.len));
    try std.testing.expectEqual(position, planner.next_position);
    try std.testing.expectEqual(indexed, planner.indexed_positions);
    try std.testing.expectEqualSlices(wide.Token, before, planner.tokens.items);
}

test "LZMA large dictionary core payload limit retains exact flush and old bytes" {
    for ([_]encoder.Mode{ .literal_only, .greedy, .lazy, .fast, .normal }) |mode| {
        const options: encoder.EncodeOptions = .{ .dictionary_size = settings.max_dictionary_size, .mode = mode, .match_options = if (mode == .fast or mode == .normal) .{ .finder = .bt2 } else null };
        var original: std.ArrayList(u8) = .empty;
        defer original.deinit(std.testing.allocator);
        var expected_model = try encoder.initModel(options);
        _ = try encoder.encodeChunkAppendWithModel(std.testing.allocator, &original, "abcabcabcabcabcabcabcabc", "", 0, options, null, &expected_model);
        var bounded: std.ArrayList(u8) = .empty;
        defer bounded.deinit(std.testing.allocator);
        var model = try encoder.initModel(options);
        _ = try encoder.encodeChunkAppendWithModelLimit(std.testing.allocator, &bounded, "abcabcabcabcabcabcabcabc", "", 0, options, null, &model, original.items.len);
        try std.testing.expectEqualSlices(u8, original.items, bounded.items);
        try std.testing.expect(std.meta.eql(expected_model, model));
        bounded.clearRetainingCapacity();
        try bounded.appendSlice(std.testing.allocator, "sentinel");
        model = try encoder.initModel(options);
        const before = model;
        try std.testing.expectError(error.CompressedPayloadLimitExceeded, encoder.encodeChunkAppendWithModelLimit(std.testing.allocator, &bounded, "abcabcabcabcabcabcabcabc", "", 0, options, null, &model, original.items.len - 1));
        try std.testing.expectEqualSlices(u8, "sentinel", bounded.items);
        try std.testing.expect(std.meta.eql(before, model));
    }
    var empty: std.ArrayList(u8) = .empty;
    defer empty.deinit(std.testing.allocator);
    var range = range_encoder.Encoder.initWithLimit(std.testing.allocator, &empty, 5);
    try range.finish();
    try std.testing.expectEqual(@as(usize, 5), empty.items.len);
    try std.testing.expect(empty.capacity <= 5);
}

test "LZMA large dictionary core advanced payload cap covers consecutive prefix transactions" {
    var input: [5000]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0xbeef);
    random.random().bytes(&input);
    const options: encoder.EncodeOptions = .{ .dictionary_size = settings.max_dictionary_size, .mode = .fast, .match_options = .{ .finder = .bt2 } };
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(std.testing.allocator);
    var expected_model = try encoder.initModel(options);
    _ = try encoder.encodeChunkAppendWithModel(std.testing.allocator, &expected, &input, "", 0, options, null, &expected_model);
    var bounded: std.ArrayList(u8) = .empty;
    defer bounded.deinit(std.testing.allocator);
    var model = try encoder.initModel(options);
    _ = try encoder.encodeChunkAppendWithModelLimit(std.testing.allocator, &bounded, &input, "", 0, options, null, &model, expected.items.len);
    try std.testing.expectEqualSlices(u8, expected.items, bounded.items);
    try std.testing.expect(std.meta.eql(expected_model, model));
    bounded.clearRetainingCapacity();
    model = try encoder.initModel(options);
    const before = model;
    try std.testing.expectError(error.CompressedPayloadLimitExceeded, encoder.encodeChunkAppendWithModelLimit(std.testing.allocator, &bounded, &input, "", 0, options, null, &model, expected.items.len - 1));
    try std.testing.expectEqual(@as(usize, 0), bounded.items.len);
    try std.testing.expect(std.meta.eql(before, model));
}

test "LZMA large dictionary core bounded prefix retains range model stats and allocation cap" {
    var input: [70_000]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x98765);
    random.random().bytes(&input);
    const options: encoder.EncodeOptions = .{ .dictionary_size = settings.max_dictionary_size, .mode = .fast, .match_options = .{ .finder = .bt2 } };
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    var range = range_encoder.Encoder.initWithLimit(std.testing.allocator, &output, 65_536);
    var model = try encoder.initModel(options);
    var stats: encoder.EncodeStats = .{ .input_bytes = 0, .output_bytes = 0, .literals = 0, .matches = 0, .matched_bytes = 0, .repeat_matches = 0, .new_distance_matches = 0 };
    var position: usize = 0;
    while (position < input.len) {
        const before_model = model;
        const before_range = range;
        const before_stats = stats;
        const before_length = output.items.len;
        const consumed = encoder.encodeAdvancedPrefix(std.testing.allocator, &model, &range, input[0..position], input[position..], position, options, true, &stats) catch |err| {
            try std.testing.expectEqual(error.CompressedPayloadLimitExceeded, err);
            try std.testing.expect(position > encoder.advanced_window_len);
            try std.testing.expectEqual(before_length, output.items.len);
            try std.testing.expect(std.meta.eql(before_model, model));
            try std.testing.expect(std.meta.eql(before_range, range));
            try std.testing.expect(std.meta.eql(before_stats, stats));
            try std.testing.expect(output.capacity <= 65_536);
            return;
        };
        position += consumed;
        try std.testing.expect(output.capacity <= 65_536);
        try std.testing.expect(try range.finishedSize() <= 65_536);
    }
    return error.TestUnexpectedResult;
}

test "LZMA large dictionary core payload cap stops actual attempts and preserves OOM errors" {
    var input: [70_000]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x1234);
    random.random().bytes(&input);
    var profile: settings.EncodeWorkProfile = .{};
    const options: encoder.EncodeOptions = .{ .dictionary_size = settings.max_dictionary_size, .mode = .literal_only, .match_options = .{ .profile = &profile } };
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    var model = try encoder.initModel(options);
    const before = model;
    try std.testing.expectError(error.CompressedPayloadLimitExceeded, encoder.encodeChunkAppendWithModelLimit(std.testing.allocator, &output, &input, "", 0, options, null, &model, 65_536));
    try std.testing.expect(profile.literals > 0 and profile.literals < input.len);
    try std.testing.expectEqual(@as(usize, 0), output.items.len);
    try std.testing.expect(std.meta.eql(before, model));
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, encoder.encodeChunkAppendWithModelLimit(failing.allocator(), &output, "abc", "", 0, options, null, &model, 65_536));
    try std.testing.expect(std.meta.eql(before, model));
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(allocator);
            const opts: encoder.EncodeOptions = .{ .dictionary_size = settings.max_dictionary_size, .mode = .greedy };
            var state = try encoder.initModel(opts);
            _ = try encoder.encodeChunkAppendWithModelLimit(allocator, &bytes, "abcabcabcabc", "", 0, opts, null, &state, 65_536);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}

test "LZMA bounded payload short repeat checks unnormalized flush tail before prefix commit" {
    const allocator = std.testing.allocator;
    const seed_options: encoder.EncodeOptions = .{ .dictionary_size = 4096, .mode = .fast, .match_options = .{ .finder = .bt2 } };
    var seed_output: std.ArrayList(u8) = .empty;
    defer seed_output.deinit(allocator);
    var retained_model = try encoder.initModel(seed_options);
    _ = try encoder.encodeChunkAppendWithModel(allocator, &seed_output, "abcabc", "", 0, seed_options, null, &retained_model);
    try std.testing.expectEqual(@as(usize, 7), retained_model.state);
    try std.testing.expectEqual(@as(usize, 2), retained_model.reps[0]);
    var profile: settings.EncodeWorkProfile = .{};
    var options = seed_options;
    options.match_options.?.profile = &profile;
    const initial_stats: encoder.EncodeStats = .{ .input_bytes = 13, .output_bytes = 7, .literals = 9, .matches = 2, .matched_bytes = 4, .repeat_matches = 1, .new_distance_matches = 1 };
    for ([_]usize{ 4, 5 }) |limit| {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(allocator);
        var range = range_encoder.Encoder.initWithLimit(allocator, &output, limit);
        var model = retained_model;
        var stats = initial_stats;
        const before_range = range;
        profile.reset();
        if (limit == 4) {
            try std.testing.expectError(error.CompressedPayloadLimitExceeded, encoder.encodeAdvancedPrefix(allocator, &model, &range, "abc", "a", 6, options, true, &stats));
            try std.testing.expect(std.meta.eql(retained_model, model));
            try std.testing.expect(std.meta.eql(before_range, range));
            try std.testing.expect(std.meta.eql(initial_stats, stats));
            try std.testing.expectEqual(@as(usize, 0), output.items.len);
            try std.testing.expectEqual(@as(usize, 0), output.capacity);
            try std.testing.expectEqual(@as(u64, 1), profile.short_reps);
        } else {
            try std.testing.expectEqual(@as(usize, 1), try encoder.encodeAdvancedPrefix(allocator, &model, &range, "abc", "a", 6, options, true, &stats));
            try std.testing.expectEqual(@as(usize, 0), output.items.len);
            try std.testing.expectEqual(@as(usize, 5), try range.finishedSize());
            try std.testing.expectEqual(initial_stats.input_bytes + 1, stats.input_bytes);
            try std.testing.expectEqual(initial_stats.repeat_matches + 1, stats.repeat_matches);
            try std.testing.expectEqual(@as(u64, 1), profile.short_reps);
            try range.finish();
            try std.testing.expectEqual(@as(usize, 5), output.items.len);
            try std.testing.expect(output.capacity <= limit);
        }

        // Calls that consume no symbols leave retained coding state untouched.
        output.clearAndFree(allocator);
        range = range_encoder.Encoder.initWithLimit(allocator, &output, limit);
        model = retained_model;
        stats = initial_stats;
        const waiting_range = range;
        profile.reset();
        try std.testing.expectEqual(@as(usize, 0), try encoder.encodeAdvancedPrefix(allocator, &model, &range, "abc", "", 6, options, true, &stats));
        try std.testing.expectEqual(@as(usize, 0), try encoder.encodeAdvancedPrefix(allocator, &model, &range, "abc", "a", 6, options, false, &stats));
        try std.testing.expect(std.meta.eql(retained_model, model));
        try std.testing.expect(std.meta.eql(waiting_range, range));
        try std.testing.expect(std.meta.eql(initial_stats, stats));
        try std.testing.expectEqual(@as(u64, 0), profile.short_reps);
        try std.testing.expectEqual(@as(u64, 0), profile.parser_windows);
    }
}

test "Large dictionary actual distance exceeds sixty four MiB ReleaseFast fixture" {
    if (builtin.mode != .ReleaseFast) return error.SkipZigTest;
    const allocator = std.heap.page_allocator;
    const dictionary_len = 64 * 1024 * 1024 + 1;
    const dictionary = try allocator.alloc(u8, dictionary_len);
    defer allocator.free(dictionary);
    @memset(dictionary, 0);
    for (dictionary[0..64], 0..) |*byte, i| byte.* = @intCast(i + 1);
    const input = dictionary[0..64];
    const source = mf.Source.init(dictionary, input, dictionary_len);
    for ([_]settings.MatchFinder{ .hc3, .bt4 }) |finder| {
        var profile: settings.EncodeWorkProfile = .{};
        var matcher = try mf.Matcher.init(allocator, source, .{ .finder = finder, .nice_len = 64, .depth = 64, .profile = &profile });
        defer matcher.deinit(allocator);
        const match = (try matcher.find()).best();
        try std.testing.expectEqual(@as(u32, dictionary_len), match.distance);
        try std.testing.expectEqual(@as(u16, 64), match.length);
        try std.testing.expectEqual(@as(u64, dictionary_len), profile.mf_seed_positions);
        std.debug.print("large-distance finder={s} window={} distance={} length={} matcher_heap={} dictionary_heap={} seeded={}\n", .{ @tagName(finder), dictionary_len, match.distance, match.length, matcher.workingBytes(), dictionary.len, profile.mf_seed_positions });
    }
    var plan = try wide.planAlloc(allocator, input, dictionary, .{ .window_len = dictionary_len });
    defer plan.deinit(allocator);
    try std.testing.expectEqual(@as(u32, dictionary_len), plan.tokens[0].match.distance);
    try std.testing.expectEqual(@as(u16, 64), plan.tokens[0].match.length);
    const options: encoder.EncodeOptions = .{ .dictionary_size = dictionary_len };
    var model = try encoder.initModel(options);
    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    _ = try encoder.encodeChunkAppendWithModelLimit(allocator, &payload, input, dictionary, dictionary.len, options, .{ .tokens = plan.tokens, .stats = plan.stats }, &model, 65_536);
    try std.testing.expectEqual(@as(usize, dictionary_len - 1), model.reps[0]);
    var advanced_model = try encoder.initModel(.{ .dictionary_size = dictionary_len, .mode = .fast });
    const advanced = try encoder.advancedPlanPrefix(allocator, &advanced_model, dictionary, input, dictionary.len, .{ .dictionary_size = dictionary_len, .mode = .fast, .match_options = .{ .finder = .hc3, .nice_len = 64, .depth = 64 } }, true);
    defer advanced.deinit(allocator);
    try std.testing.expectEqual(@as(u32, dictionary_len), advanced.tokens[0].match.distance);
    try std.testing.expectEqual(@as(u16, 64), advanced.tokens[0].match.length);
    std.debug.print("large-distance legacy_and_advanced distance={} consumed={} legacy_peak_bound={} payload_bytes={} model_rep0={}\n", .{ dictionary_len, advanced.consumed, try wide.requiredPlanWorkingMemory(input.len, dictionary.len, .{ .window_len = dictionary_len }), payload.items.len, model.reps[0] });
}

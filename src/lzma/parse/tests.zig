const std = @import("std");
const encoder = @import("../encoder.zig");
const decoder = @import("../decoder.zig");
const range_encoder = @import("../range_encoder.zig");
const matcher = @import("../match_finder.zig");
const types = @import("types.zig");
const prices = @import("prices.zig");
const a = std.testing.allocator;

fn emptyStats() encoder.EncodeStats {
    return .{ .input_bytes = 0, .output_bytes = 0, .literals = 0, .matches = 0, .matched_bytes = 0, .repeat_matches = 0, .new_distance_matches = 0 };
}
fn brute(model: *const encoder.Model, lengths: *const prices.Lengths, source: matcher.Source, position: usize, state: types.State) u32 {
    if (position == source.input.len) return 0;
    var best = prices.literal(model, source, position, 0, state) + brute(model, lengths, source, position + 1, state.after(.{}));
    const absolute = source.prefixLen() + position;
    for (1..@min(absolute, source.window_len) + 1) |distance| {
        const length = source.matchLength(absolute - distance, absolute, source.input.len - position);
        if (distance == state.reps[0] + 1 and length >= 1) {
            const decision = types.Decision{ .distance = @intCast(distance) };
            best = @min(best, prices.decision(model, lengths, source, position, 0, state, decision) + brute(model, lengths, source, position + 1, state.after(decision)));
        }
        if (length >= 2) for (2..length + 1) |n| {
            const decision = types.Decision{ .length = @intCast(n), .distance = @intCast(distance) };
            best = @min(best, prices.decision(model, lengths, source, position, 0, state, decision) + brute(model, lengths, source, position + n, state.after(decision)));
        };
    }
    return best;
}
fn planCost(model: *const encoder.Model, history: []const u8, input: []const u8, plan: encoder.AdvancedPlan) u32 {
    const source = matcher.Source.init(history, input, model.dictionary_size);
    const lengths = prices.Lengths.init(model);
    var state = types.State.fromModel(model);
    var position: usize = 0;
    var cost: u32 = 0;
    for (plan.tokens) |token| {
        const decision: types.Decision = switch (token) {
            .literal => .{},
            .match => |m| .{ .length = m.length, .distance = m.distance },
        };
        cost += prices.decision(model, &lengths, source, position, 0, state, decision);
        state = state.after(decision);
        position += decision.length;
    }
    return cost;
}

test "LZMA advanced normal uniform range prices and exhaustive short path oracle" {
    const model = try encoder.initModel(.{ .mode = .normal });
    const source = matcher.Source.init("aaaa", "aaaa", 4096);
    const lengths = prices.Lengths.init(&model);
    const initial = types.State.fromModel(&model);
    try std.testing.expectEqual(@as(u32, 64), prices.bit(1024, false));
    try std.testing.expectEqual(@as(u32, 64), prices.bit(1024, true));
    try std.testing.expectEqual(@as(u32, 704), prices.bit(1, false));
    try std.testing.expectEqual(@as(u32, 576), prices.literal(&model, source, 0, 0, initial));
    try std.testing.expectEqual(@as(u32, 256), prices.decision(&model, &lengths, source, 0, 0, initial, .{ .distance = 1 }));
    try std.testing.expectEqual(@as(u32, 512), prices.decision(&model, &lengths, source, 0, 0, initial, .{ .distance = 1, .length = 2 }));
    const cases = [_][]const u8{ "a", "aa", "aaa", "aaaa", "abaa", "abab", "baab", "abcd" };
    for (cases) |input| {
        const history = "abaa";
        const plan = try encoder.advancedPlanPrefix(a, &model, history, input, history.len, .{ .mode = .normal, .match_options = .{ .finder = .bt2, .depth = 512, .nice_len = 273 } }, true);
        defer plan.deinit(a);
        const oracle_source = matcher.Source.init(history, input, 4096);
        try std.testing.expectEqual(brute(&model, &lengths, oracle_source, 0, initial), planCost(&model, history, input, plan));
    }
}

test "LZMA advanced normal short rep and two byte match encode valid wire" {
    const input = "aa";
    var model = try encoder.initModel(.{ .mode = .normal });
    const plan = try encoder.advancedPlanPrefix(a, &model, "", input, 0, .{ .mode = .normal }, true);
    defer plan.deinit(a);
    try std.testing.expectEqual(@as(usize, 2), plan.tokens.len);
    try std.testing.expectEqual(@as(u16, 1), plan.tokens[1].match.length);
    try std.testing.expectEqual(@as(u32, 1), plan.tokens[1].match.distance);
    var raw: std.ArrayList(u8) = .empty;
    defer raw.deinit(a);
    const stats = try encoder.encodeChunkAppendWithStats(a, &raw, input, .{ .mode = .normal, .end_marker = true });
    try std.testing.expectEqual(@as(usize, 1), stats.repeat_matches);
    var wrapped: std.ArrayList(u8) = .empty;
    defer wrapped.deinit(a);
    try wrapped.appendSlice(a, &.{ 0x5d, 0, 0x10, 0, 0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff });
    try wrapped.appendSlice(a, raw.items);
    const decoded = try decoder.decodeAlloc(a, wrapped.items);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    const len2 = try encoder.advancedPlanPrefix(a, &model, "xy", "xy", 2, .{ .mode = .normal, .match_options = .{ .finder = .bt2, .nice_len = 2 } }, true);
    defer len2.deinit(a);
    try std.testing.expectEqual(@as(u16, 2), len2.tokens[0].match.length);
}

test "LZMA advanced prefix leaves state output and statistics unchanged on every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator, mode: encoder.Mode) !void {
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(allocator);
            try output.appendSlice(allocator, "prior-output");
            var model = try encoder.initModel(.{ .mode = mode });
            const original = model;
            var range = range_encoder.Encoder.init(allocator, &output);
            const initial_range = range;
            var stats = emptyStats();
            const consumed = encoder.encodeAdvancedPrefix(allocator, &model, &range, "", "aa bb aa bb aa bb", 0, .{ .mode = mode }, true, &stats) catch |err| {
                try std.testing.expectEqualDeep(original, model);
                try std.testing.expectEqual(initial_range.low, range.low);
                try std.testing.expectEqual(initial_range.range, range.range);
                try std.testing.expectEqual(initial_range.cache, range.cache);
                try std.testing.expectEqual(initial_range.cache_size, range.cache_size);
                try std.testing.expectEqualSlices(u8, "prior-output", output.items);
                try std.testing.expectEqualDeep(emptyStats(), stats);
                return err;
            };
            try std.testing.expectEqual(@as(usize, 17), consumed);
            try std.testing.expectEqual(consumed, stats.literals + stats.matched_bytes);
        }
    };
    inline for (.{ encoder.Mode.fast, encoder.Mode.normal }) |mode| try std.testing.checkAllAllocationFailures(a, Test.run, .{mode});
}

test "LZMA advanced parser working budget and nonfinal guard are authoritative" {
    var model = try encoder.initModel(.{ .mode = .normal });
    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    const waiting = try encoder.advancedPlanPrefix(failing.allocator(), &model, "", "aa", 0, .{ .mode = .normal }, false);
    defer waiting.deinit(failing.allocator());
    try std.testing.expectEqual(@as(usize, 0), waiting.consumed);
    try std.testing.expect(!failing.has_induced_failure);
    var profile = encoder.EncodeWorkProfile{};
    const options = encoder.EncodeOptions{ .mode = .normal, .match_options = .{ .profile = &profile } };
    const input = "normal bounded cost state and reps";
    const plan = try encoder.advancedPlanPrefix(a, &model, "", input, 0, options, true);
    plan.deinit(a);
    try std.testing.expect(profile.price_evaluations > 0);
    try std.testing.expect(profile.peak_working_memory > profile.mf_peak_working_memory);
    var exact = options;
    exact.match_options.?.profile = null;
    exact.match_options.?.max_working_memory = profile.peak_working_memory;
    const same = try encoder.advancedPlanPrefix(a, &model, "", input, 0, exact, true);
    same.deinit(a);
    exact.match_options.?.max_working_memory -= 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.advancedPlanPrefix(a, &model, "", input, 0, exact, true));
}

fn streamed(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8, options: encoder.EncodeOptions) !void {
    var model = try encoder.initModel(options);
    var range = range_encoder.Encoder.init(allocator, output);
    var pending: std.ArrayList(u8) = .empty;
    defer pending.deinit(allocator);
    var history: std.ArrayList(u8) = .empty;
    defer history.deinit(allocator);
    var stats = emptyStats();
    var accepted: usize = 0;
    var encoded: usize = 0;
    const schedule = [_]usize{ 1, 7, 71, 4096, 3, 29 };
    var step: usize = 0;
    while (accepted < input.len or pending.items.len != 0) {
        if (accepted < input.len) {
            const amount = @min(input.len - accepted, schedule[step % schedule.len]);
            try pending.appendSlice(allocator, input[accepted..][0..amount]);
            accepted += amount;
            step += 1;
        }
        const consumed = try encoder.encodeAdvancedPrefix(allocator, &model, &range, history.items, pending.items, encoded, options, accepted == input.len, &stats);
        if (consumed == 0) continue;
        if (consumed >= options.dictionary_size) {
            history.clearRetainingCapacity();
            try history.appendSlice(allocator, pending.items[consumed - options.dictionary_size .. consumed]);
        } else {
            const kept = @min(history.items.len, options.dictionary_size - consumed);
            std.mem.copyForwards(u8, history.items[0..kept], history.items[history.items.len - kept ..]);
            history.items.len = kept;
            try history.appendSlice(allocator, pending.items[0..consumed]);
        }
        encoded += consumed;
        std.mem.copyForwards(u8, pending.items[0 .. pending.items.len - consumed], pending.items[consumed..]);
        pending.items.len -= consumed;
    }
    try std.testing.expectEqual(input.len, encoded);
    try std.testing.expectEqual(input.len, stats.input_bytes);
    if (options.end_marker) try model.encodeEndMarker(&range, encoded);
    try range.finish();
}

test "LZMA advanced full normal window stable prefixes match whole one shot across fragments" {
    var input: [9001]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x1a2a4096);
    random.random().bytes(&input);
    @memcpy(input[1000..1512], input[0..512]);
    @memcpy(input[5000..5512], input[4000..4512]);
    const options = encoder.EncodeOptions{ .mode = .normal, .properties = .{ .lc = 2, .lp = 2, .pb = 4 }, .end_marker = true };
    var whole: std.ArrayList(u8) = .empty;
    defer whole.deinit(a);
    _ = try encoder.encodeChunkAppend(a, &whole, &input, options);
    var incremental: std.ArrayList(u8) = .empty;
    defer incremental.deinit(a);
    try streamed(a, &incremental, &input, options);
    try std.testing.expectEqualSlices(u8, whole.items, incremental.items);
}

test "LZMA advanced literal only never matches with explicit matcher options" {
    const input = "aaaaaaaaaaaaaaaaaaaaaaaa";
    var old: std.ArrayList(u8) = .empty;
    defer old.deinit(a);
    var explicit: std.ArrayList(u8) = .empty;
    defer explicit.deinit(a);
    _ = try encoder.encodeChunkAppend(a, &old, input, .{ .mode = .literal_only, .end_marker = true });
    const stats = try encoder.encodeChunkAppendWithStats(a, &explicit, input, .{ .mode = .literal_only, .end_marker = true, .match_options = .{ .finder = .bt4, .max_working_memory = 0 } });
    try std.testing.expectEqualSlices(u8, old.items, explicit.items);
    try std.testing.expectEqual(@as(usize, 0), stats.matches);
    try std.testing.expectEqual(input.len, stats.literals);
}

test "LZMA advanced empty and waiting profile settings update without fictional work" {
    var profile = encoder.EncodeWorkProfile{ .finder = .hc4, .effective_nice_len = 273, .effective_depth = 512, .mf_positions = 123, .parser_windows = 7 };
    const options = encoder.EncodeOptions{ .mode = .normal, .match_options = .{ .finder = .bt3, .nice_len = 2, .depth = 0, .max_working_memory = 0, .profile = &profile } };
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(a);
    _ = try encoder.encodeChunkAppend(a, &output, "", options);
    try std.testing.expectEqual(@as(u16, 3), profile.effective_nice_len);
    try std.testing.expectEqual(@as(u32, 17), profile.effective_depth);
    try std.testing.expectEqual(@as(u64, 123), profile.mf_positions);
    try std.testing.expectEqual(@as(u64, 7), profile.parser_windows);
    profile.finder = .hc4;
    profile.effective_nice_len = 273;
    const model = try encoder.initModel(options);
    const waiting = try encoder.advancedPlanPrefix(a, &model, "", "aa", 0, options, false);
    defer waiting.deinit(a);
    try std.testing.expectEqual(@as(usize, 0), waiting.consumed);
    try std.testing.expectEqual(@as(u16, 3), profile.effective_nice_len);
    try std.testing.expectEqual(@as(u64, 123), profile.mf_positions);
    try std.testing.expectEqual(@as(u64, 7), profile.parser_windows);
}

test "LZMA advanced statistics overflow does not partially commit encoded symbols" {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(a);
    var range = range_encoder.Encoder.init(a, &output);
    var model = try encoder.initModel(.{ .mode = .normal });
    const original = model;
    const original_range = range;
    var stats = emptyStats();
    stats.input_bytes = std.math.maxInt(usize);
    const original_stats = stats;
    try std.testing.expectError(error.IntegerOverflow, encoder.encodeAdvancedPrefix(a, &model, &range, "", "aa", 0, .{ .mode = .normal }, true, &stats));
    try std.testing.expectEqualDeep(original, model);
    try std.testing.expectEqualDeep(original_stats, stats);
    try std.testing.expectEqual(original_range.low, range.low);
    try std.testing.expectEqual(original_range.range, range.range);
    try std.testing.expectEqual(@as(usize, 0), output.items.len);
}

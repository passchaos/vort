const std = @import("std");
const encoder = @import("encoder.zig");
const decoder = @import("decoder.zig");
const range_encoder = @import("range_encoder.zig");
const matcher = @import("match_finder.zig");
const settings = @import("encode_options.zig");
const fast = @import("parse/fast.zig");
const prices = @import("parse/prices.zig");
const types = @import("parse/types.zig");
const working = @import("../io/working_allocator.zig");
const a = std.testing.allocator;

test "LZMA fast parser next main match branches from local greedy" {
    const model = try encoder.initModel(.{ .mode = .fast });
    const original = model;
    var profile: settings.EncodeWorkProfile = .{};
    const history = "abcXbcdefgh";
    const input = "abcdefgh";
    const greedy = try parse(a, &model, history, input, input.len, .greedy, .{});
    defer greedy.deinit(a);
    const selected = try parse(a, &model, history, input, input.len, .fast, .{ .profile = &profile });
    defer selected.deinit(a);
    try std.testing.expectEqual(@as(u16, 3), greedy.tokens[0].match.length);
    try std.testing.expectEqual(@as(u8, 'a'), selected.tokens[0].literal);
    try std.testing.expectEqual(@as(u16, 7), selected.tokens[1].match.length);
    try std.testing.expectEqual(@as(u32, 8), selected.tokens[1].match.distance);
    try std.testing.expectEqual(@as(u64, history.len + input.len), profile.mf_positions);
    try std.testing.expect(profile.rep_probes > 0);
    try verifyAndWrite(&model, history, input, greedy);
    try verifyAndWrite(&model, history, input, selected);
    try std.testing.expectEqualDeep(original, model);
}

test "LZMA fast parser next position probes all four reps beyond the bounded main match" {
    const history = "bcdefghQbcdeZQabcdeX";
    const input = "abcdefgh";
    for (0..4) |repeat_index| {
        var model = try encoder.initModel(.{ .mode = .fast });
        model.reps = @splat(200);
        // This distance is unavailable at the current byte, then becomes valid
        // at the next byte. HC depth 1 exposes only the nearby four-byte match.
        model.reps[repeat_index] = history.len;
        var profile: settings.EncodeWorkProfile = .{};
        const opts: settings.MatchOptions = .{ .finder = .hc4, .depth = 1, .nice_len = 64, .profile = &profile };
        const greedy = try parse(a, &model, history, input, input.len, .greedy, opts);
        defer greedy.deinit(a);
        const selected = try parse(a, &model, history, input, input.len, .fast, opts);
        defer selected.deinit(a);
        try std.testing.expectEqual(@as(u16, 5), greedy.tokens[0].match.length);
        try std.testing.expectEqual(@as(u8, 'a'), selected.tokens[0].literal);
        try std.testing.expectEqual(@as(u16, 7), selected.tokens[1].match.length);
        try std.testing.expectEqual(@as(u32, history.len + 1), selected.tokens[1].match.distance);
        try std.testing.expectEqual(@as(u32, history.len), selected.final_state.reps[0]);
        try std.testing.expect(profile.rep_probes > 0);
        try verifyAndWrite(&model, history, input, selected);
    }
}

test "LZMA fast parser lazy delays a shorter next match only when actual model prices favor it" {
    const history = "abcdeX";
    const input = "abcdef";
    for ([_]usize{ 0, 7 }) |initial_state| {
        var model = try encoder.initModel(.{ .mode = .lazy });
        model.state = initial_state;
        const after_literal_state: usize = if (initial_state == 7) 4 else 0;
        model.is_match[(initial_state << 4) + (history.len & 3)] = 2047;
        model.is_match[(initial_state << 4) + ((history.len + 1) & 3)] = 2047;
        model.is_match[(after_literal_state << 4) + ((history.len + 1) & 3)] = 1;
        const source = matcher.Source.init(history, input, model.dictionary_size);
        const state = types.State.fromModel(&model);
        const lengths = prices.Lengths.init(&model);
        const now = prices.decision(&model, &lengths, source, 0, history.len, state, .{ .length = 5, .distance = 6 });
        const delayed = prices.literal(&model, source, 0, history.len, state) +
            prices.decision(&model, &lengths, source, 1, history.len, state.after(.{}), .{ .length = 4, .distance = 6 });
        try std.testing.expect(delayed < now);
        var profile: settings.EncodeWorkProfile = .{};
        const local = try parse(a, &model, history, input, input.len, .greedy, .{});
        defer local.deinit(a);
        const quick = try parse(a, &model, history, input, input.len, .fast, .{});
        defer quick.deinit(a);
        const lazy = try parse(a, &model, history, input, input.len, .lazy, .{ .profile = &profile });
        defer lazy.deinit(a);
        try std.testing.expectEqual(@as(u16, 5), local.tokens[0].match.length);
        try std.testing.expectEqual(@as(u16, 5), quick.tokens[0].match.length);
        try std.testing.expectEqual(@as(u8, 'a'), lazy.tokens[0].literal);
        try std.testing.expectEqual(@as(u16, 4), lazy.tokens[1].match.length);
        try std.testing.expect(profile.price_evaluations > 0);
        try verifyAndWrite(&model, history, input, lazy);
    }
}

test "LZMA fast parser two byte matches short rep zero EOF and complete symbol goals" {
    const model = try encoder.initModel(.{ .mode = .fast });
    inline for (.{ settings.Mode.greedy, settings.Mode.fast, settings.Mode.lazy }) |mode| {
        const two = try parse(a, &model, "xy", "xy", 2, mode, .{ .finder = .bt2, .nice_len = 2 });
        defer two.deinit(a);
        try std.testing.expectEqual(@as(u16, 2), two.tokens[0].match.length);
        try std.testing.expectEqual(@as(u32, 2), two.tokens[0].match.distance);
        try verifyAndWrite(&model, "xy", "xy", two);
        const tail = try parse(a, &model, "", "a", 1, mode, .{});
        defer tail.deinit(a);
        try std.testing.expectEqual(@as(u8, 'a'), tail.tokens[0].literal);
        const completed = try parse(a, &model, "abcdefgh", "abcdefgh!rest", 1, mode, .{});
        defer completed.deinit(a);
        try std.testing.expectEqual(@as(usize, 8), completed.consumed);
        try verifyAndWrite(&model, "abcdefgh", "abcdefgh!rest", completed);
    }
    inline for (.{ settings.Mode.fast, settings.Mode.lazy }) |mode| {
        const short = try parse(a, &model, "a", "a", 1, mode, .{});
        defer short.deinit(a);
        try std.testing.expectEqual(@as(u16, 1), short.tokens[0].match.length);
        try std.testing.expectEqual(@as(u32, 1), short.tokens[0].match.distance);
        try verifyAndWrite(&model, "a", "a", short);
    }
    // A historical rep that would match at p+1 lies outside the current window.
    // The parser must exclude it even though its bytes remain in caller history.
    var small_window = try encoder.initModel(.{ .mode = .fast, .dictionary_size = 2 });
    small_window.reps = @splat(2);
    inline for (.{ settings.Mode.greedy, settings.Mode.fast, settings.Mode.lazy }) |mode| {
        const bounded = try parse(a, &small_window, "abc", "abc", 3, mode, .{});
        defer bounded.deinit(a);
        try std.testing.expectEqual(@as(usize, 3), bounded.tokens.len);
        for (bounded.tokens, "abc") |token, byte| try std.testing.expectEqual(byte, token.literal);
        try verifyAndWrite(&small_window, "abc", "abc", bounded);
    }
}

test "LZMA fast parser working quota OOM and empty input preserve the model" {
    inline for (.{ settings.Mode.greedy, settings.Mode.fast, settings.Mode.lazy }) |mode| {
        try std.testing.checkAllAllocationFailures(a, allocationCase, .{mode});
        const model = try encoder.initModel(.{ .mode = mode });
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, parse(a, &model, "", "abcabc", 6, mode, .{ .max_working_memory = 0 }));
        var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
        const empty = try parse(failing.allocator(), &model, "", "", 0, mode, .{ .max_working_memory = 0 });
        defer empty.deinit(failing.allocator());
        try std.testing.expectEqual(@as(usize, 0), empty.consumed);
        try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    }
}

test "LZMA fast parser frozen prefix decisions produce identical wire across input fragments" {
    var input: [6000]u8 = undefined;
    const pattern = "abcdeXbcdefgh/abababX/abcXbcdefgh/";
    for (&input, 0..) |*byte, index| byte.* = pattern[index % pattern.len];
    @memcpy(input[input.len - 9 ..], "tail:done");
    inline for (.{ settings.Mode.fast, settings.Mode.lazy }) |mode| {
        const whole = try wire(&input, mode, false);
        defer a.free(whole);
        const fragments = try wire(&input, mode, true);
        defer a.free(fragments);
        try std.testing.expectEqualSlices(u8, whole, fragments);
        const decoded = try decoder.decodeAlloc(a, whole);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, &input, decoded);
    }
}

fn parse(allocator: std.mem.Allocator, model: *const encoder.Model, history: []const u8, input: []const u8, goal: usize, mode: settings.Mode, options: settings.MatchOptions) !types.Plan {
    var budget = working.WorkingAllocator.init(allocator, options.max_working_memory);
    defer if (options.profile) |p| {
        p.peak_working_memory = @max(p.peak_working_memory, budget.peak);
    };
    return fast.plan(budget.allocator(), &budget, model, matcher.Source.init(history, input, model.dictionary_size), history.len, goal, options, mode) catch |err| {
        if (err == error.OutOfMemory and budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        return err;
    };
}

fn verifyAndWrite(model: *const encoder.Model, history: []const u8, input: []const u8, plan: types.Plan) !void {
    var shadow = model.*;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(a);
    var range = range_encoder.Encoder.init(a, &output);
    var stats = emptyStats();
    try std.testing.expectEqual(plan.consumed, try shadow.encodeTokensWithDictionary(&range, input[0..plan.consumed], history, plan.tokens, history.len, &stats));
    try std.testing.expectEqualDeep(plan.final_state, types.State.fromModel(&shadow));
}

fn allocationCase(allocator: std.mem.Allocator, mode: settings.Mode) !void {
    const model = try encoder.initModel(.{ .mode = mode });
    const snapshot = model;
    const selected = parse(allocator, &model, "abcdeXbcdefgh", "abcdefgh aa", 11, mode, .{}) catch |err| {
        try std.testing.expectEqualDeep(snapshot, model);
        return err;
    };
    defer selected.deinit(allocator);
    try std.testing.expectEqualDeep(snapshot, model);
}

fn wire(input: []const u8, mode: settings.Mode, fragmented: bool) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(a);
    try output.appendSlice(a, &.{ 0x5d, 0, 0x10, 0, 0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff });
    var range = range_encoder.Encoder.init(a, &output);
    const options: encoder.EncodeOptions = .{ .mode = mode, .match_options = .{ .finder = .hc4, .nice_len = 64, .depth = 64 } };
    var model = try encoder.initModel(options);
    var stats = emptyStats();
    var position: usize = 0;
    var offered: usize = if (fragmented) 0 else input.len;
    while (position < input.len) {
        if (fragmented) offered += @min(@as(usize, 137), input.len - offered);
        const history = input[position - @min(position, options.dictionary_size) .. position];
        const consumed = try encoder.encodeAdvancedPrefix(a, &model, &range, history, input[position..offered], position, options, offered == input.len, &stats);
        if (consumed == 0) {
            try std.testing.expect(offered < input.len);
            continue;
        }
        position += consumed;
    }
    try model.encodeEndMarker(&range, input.len);
    try range.finish();
    return output.toOwnedSlice(a);
}

fn emptyStats() encoder.EncodeStats {
    return .{ .input_bytes = 0, .output_bytes = 0, .literals = 0, .matches = 0, .matched_bytes = 0, .repeat_matches = 0, .new_distance_matches = 0 };
}

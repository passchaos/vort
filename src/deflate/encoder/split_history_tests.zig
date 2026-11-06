const std = @import("std");
const history = @import("split_history.zig");

pub const Mode = enum { fixed, dynamic, best, adaptive };
pub const Framing = enum { raw, zlib, gzip };
pub const BestMode = enum { one_shot, split, adaptive };
const modes = std.meta.tags(Mode);

pub fn contracts(comptime C: type) !void {
    try borrowedViews();
    try repeatedBlocks(C);
    try residualDictionary(C);
    try expiredDictionary(C);
    try dictionarySeams(C);
    try strategiesAndWindows(C);
    try adaptiveDictionaryScores(C);
    try publicFrontends(C);
    try allocationFailures(C);
}

fn options(comptime C: type) C.Options {
    var result = C.options(.default);
    result.parser = .hash;
    result.lz77_options.window_len = 1024;
    result.lz77_options.max_chain = 256;
    result.lz77_options.max_candidates = 64;
    result.lz77_options.nice_len = 258;
    result.lz77_options.min_match = 4;
    result.lz77_options.min_savings_bits = 0;
    return result;
}

fn borrowedViews() !void {
    const input = "abcdefgh";
    const dict = "0123456789";
    const first = try history.View.init(input, dict, 0, 3, 6);
    try std.testing.expectEqualStrings("456789", first.dictionary);
    try std.testing.expectEqualStrings("abc", first.input);
    const residual = try history.View.init(input, dict, 4, 3, 6);
    try std.testing.expectEqualStrings("89", residual.dictionary);
    try std.testing.expectEqualStrings("abcdefg", residual.input);
    try std.testing.expectEqual(@as(usize, 4), residual.input_history_len);
    const expired = try history.View.init(input, dict, 7, 1, 6);
    try std.testing.expectEqual(@as(usize, 0), expired.dictionary.len);
    try std.testing.expectEqualStrings("bcdefgh", expired.input);
    const no_window = try history.View.init(input, dict, 4, 3, 0);
    try std.testing.expectEqual(@as(usize, 0), no_window.dictionary.len);
    try std.testing.expectEqualStrings("efg", no_window.input);
    const huge_window = try history.View.init(input, dict, 4, 3, std.math.maxInt(usize));
    try std.testing.expectEqualStrings(dict, huge_window.dictionary);
    try std.testing.expectEqualStrings("abcdefg", huge_window.input);
    const large_dictionary = try std.testing.allocator.alloc(u8, 70_000);
    defer std.testing.allocator.free(large_dictionary);
    const capped = try history.View.init(input, large_dictionary, 4, 3, std.math.maxInt(usize));
    try std.testing.expectEqual(@as(usize, 65535 - 4), capped.dictionary.len);
    try std.testing.expect(capped.dictionary.ptr == large_dictionary.ptr + (70_000 - (65535 - 4)));
    try std.testing.expectError(error.InvalidBlockPlan, history.View.init(input, dict, input.len + 1, 0, 6));
    try std.testing.expectError(error.InvalidBlockPlan, history.View.init(input, dict, 1, std.math.maxInt(usize), 6));
}

fn roundTrip(comptime C: type, mode: Mode, input: []const u8, dictionary: ?[]const u8, block_len: usize, config: C.Options) ![]u8 {
    const raw = try C.encode(std.testing.allocator, mode, input, dictionary, block_len, config);
    errdefer std.testing.allocator.free(raw);
    const decoded = try C.decode(std.testing.allocator, raw, dictionary orelse "");
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    return raw;
}

fn repeatedBlocks(comptime C: type) !void {
    var input: [4096]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x8ab56d);
    random.random().bytes(input[0..1024]);
    for (1..4) |i| @memcpy(input[i * 1024 ..][0..1024], input[0..1024]);
    const config = options(C);
    const plan = try C.plan(std.testing.allocator, &input, null, 1024, 256, config);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.stats.matched_bytes >= 240);
    for (modes) |mode| {
        const raw = try roundTrip(C, mode, &input, null, 256, config);
        defer std.testing.allocator.free(raw);
        // Independently random blocks cannot achieve this size unless later
        // blocks actually reference the preceding plaintext window.
        try std.testing.expect(raw.len < input.len / 2);
    }
    var short_window = config;
    short_window.lz77_options.window_len = 1023;
    const short_plan = try C.plan(std.testing.allocator, &input, null, 1024, 256, short_window);
    defer short_plan.deinit(std.testing.allocator);
    try std.testing.expect(short_plan.stats.matched_bytes < 32);
}

fn residualDictionary(comptime C: type) !void {
    const dictionary = try std.testing.allocator.alloc(u8, 40_000);
    defer std.testing.allocator.free(dictionary);
    var random = std.Random.DefaultPrng.init(0x16c71ef);
    random.random().bytes(dictionary);
    var input: [512]u8 = undefined;
    random.random().bytes(input[0..256]);
    @memcpy(input[256..], dictionary[dictionary.len - 256 ..]);
    const config = options(C);
    const plan = try C.plan(std.testing.allocator, &input, dictionary, 256, 256, config);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.stats.matched_bytes >= 240);
    var refers_to_dictionary = false;
    var position: usize = 0;
    for (plan.tokens) |token| switch (token) {
        .literal => position += 1,
        .match => |match| {
            refers_to_dictionary = refers_to_dictionary or match.distance > 256 + position;
            position += match.length;
        },
    };
    try std.testing.expect(refers_to_dictionary);
    for (modes) |mode| {
        const raw = try roundTrip(C, mode, &input, dictionary, 256, config);
        defer std.testing.allocator.free(raw);
        try std.testing.expect(raw.len < 400);
        try std.testing.expectError(error.InvalidMatch, C.decode(std.testing.allocator, raw, ""));
        const suffix_raw = try C.encode(std.testing.allocator, mode, &input, dictionary[dictionary.len - 1024 ..], 256, config);
        defer std.testing.allocator.free(suffix_raw);
        try std.testing.expectEqualSlices(u8, raw, suffix_raw);
    }
}

fn expiredDictionary(comptime C: type) !void {
    var dictionary: [512]u8 = undefined;
    var input: [512]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x789de3);
    random.random().bytes(&dictionary);
    for (&dictionary) |*byte| byte.* &= 0x7f;
    random.random().bytes(input[0..256]);
    for (input[0..256]) |*byte| byte.* |= 0x80;
    @memcpy(input[256..], dictionary[256..]);
    var config = options(C);
    config.lz77_options.window_len = 256;
    const plan = try C.plan(std.testing.allocator, &input, &dictionary, 256, 256, config);
    defer plan.deinit(std.testing.allocator);
    // This chunk repeats dictionary bytes that are already outside the window.
    try std.testing.expectEqual(@as(usize, 0), plan.stats.matches);
    for (modes) |mode| {
        const raw = try roundTrip(C, mode, &input, &dictionary, 256, config);
        defer std.testing.allocator.free(raw);
        const without_dictionary = try C.decode(std.testing.allocator, raw, "");
        defer std.testing.allocator.free(without_dictionary);
        try std.testing.expectEqualSlices(u8, &input, without_dictionary);
    }
}

fn dictionarySeams(comptime C: type) !void {
    const config = options(C);
    for ([_][]const u8{ "a", "xy" }) |dict| {
        var input: [1024]u8 = undefined;
        for (&input, 0..) |*byte, i| byte.* = dict[i % dict.len];
        const plan = try C.plan(std.testing.allocator, &input, dict, 0, input.len, config);
        defer plan.deinit(std.testing.allocator);
        try std.testing.expect(plan.stats.matched_bytes >= 1020);
        switch (plan.tokens[0]) {
            .match => |match| try std.testing.expectEqual(dict.len, match.distance),
            .literal => return error.TestUnexpectedResult,
        }
        for (modes) |mode| {
            const raw = try roundTrip(C, mode, &input, dict, 256, config);
            defer std.testing.allocator.free(raw);
            try std.testing.expect(raw.len < 150);
        }
    }
    var rle = config;
    rle.strategy = .rle;
    const input = "a" ** 128;
    for ([_]usize{ 0, 32 }) |offset| {
        const plan = try C.plan(std.testing.allocator, input, "a", offset, 32, rle);
        defer plan.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 32), plan.stats.matched_bytes);
        try std.testing.expectEqual(@as(u16, 1), plan.tokens[0].match.distance);
    }
}

fn strategiesAndWindows(comptime C: type) !void {
    const input = "abcabcabcabcdefghabcdefgh" ** 4;
    var config = options(C);
    for ([_]usize{ 0, 1, 2, 7, 256, 32768 }) |window| {
        config.lz77_options.window_len = window;
        inline for (.{ .default, .filtered, .huffman_only, .rle }) |strategy| {
            config.strategy = strategy;
            const plan = try C.plan(std.testing.allocator, input, "xyzabcabc", 17, 17, config);
            defer plan.deinit(std.testing.allocator);
            if (strategy == .huffman_only)
                try std.testing.expectEqual(@as(usize, 0), plan.stats.matches);
            for (modes) |mode| {
                const raw = try roundTrip(C, mode, input, "xyzabcabc", 17, config);
                defer std.testing.allocator.free(raw);
            }
        }
    }
    config = options(C);
    inline for (.{ .hash, .greedy, .lazy, .optimal }) |parser| {
        config.parser = parser;
        for (modes) |mode| {
            const raw = try roundTrip(C, mode, input, null, 17, config);
            defer std.testing.allocator.free(raw);
            const with_dictionary = try roundTrip(C, mode, input, "xyzabcabc", 17, config);
            defer std.testing.allocator.free(with_dictionary);
            const empty_dictionary = try C.encode(std.testing.allocator, mode, input, "", 17, config);
            defer std.testing.allocator.free(empty_dictionary);
            try std.testing.expectEqualSlices(u8, raw, empty_dictionary);
            const empty_input = try roundTrip(C, mode, "", "dictionary", 17, config);
            defer std.testing.allocator.free(empty_input);
        }
    }
    const empty_plan = try C.plan(std.testing.allocator, input, "dictionary", input.len, 0, config);
    defer empty_plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), empty_plan.tokens.len);
    try std.testing.expectError(error.InvalidBlockPlan, C.plan(std.testing.allocator, input, null, input.len, 1, config));
}

fn adaptiveDictionaryScores(comptime C: type) !void {
    const dictionary = "abcdefghijklmnopqrstuvwxyz" ** 8;
    const input = ("Q" ** 32) ++ dictionary[0..96];
    const config = options(C);
    const score = try C.score(std.testing.allocator, input, dictionary, 32, 96, config);
    const no_dictionary = try C.score(std.testing.allocator, input, null, 32, 96, config);
    try std.testing.expect(score < no_dictionary);
    const chosen = try C.choose(std.testing.allocator, input, dictionary, 0, 32, input.len, 8, 32, config);
    var expected_len: usize = input.len;
    var expected_score = try C.scoreAt(std.testing.allocator, input, dictionary, 0, input.len, input.len, config);
    var candidate: usize = 32;
    while (candidate < input.len) : (candidate += 32) {
        const candidate_score = try C.scoreAt(std.testing.allocator, input, dictionary, 0, input.len, candidate, config);
        if (candidate_score < expected_score) {
            expected_score = candidate_score;
            expected_len = candidate;
        }
    }
    // The low-entropy heuristic proposes 32, already covered by the grid.
    try std.testing.expectEqual(expected_len, chosen);
}

fn publicFrontends(comptime C: type) !void {
    var random = std.Random.DefaultPrng.init(0x327dab);
    var input: [8192]u8 = undefined;
    random.random().bytes(input[0..4096]);
    @memcpy(input[4096..], input[0..4096]);
    var config = options(C);
    config.lz77_options.window_len = 8192;
    try std.testing.expect(C.storedFastPath(&input, config));
    for (std.meta.tags(Framing)) |framing| {
        for ([_]BestMode{ .split, .adaptive }) |mode| {
            const raw = try C.encodePublic(std.testing.allocator, framing, mode, &input, null, 1024, config);
            defer std.testing.allocator.free(raw);
            try std.testing.expect(raw.len < 5000);
            const decoded = try C.decodePublic(std.testing.allocator, framing, raw, "");
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, &input, decoded);
        }
    }
    const large = try std.testing.allocator.alloc(u8, 70_000);
    defer std.testing.allocator.free(large);
    for (large, 0..) |*byte, i| byte.* = input[i % 1024];
    try std.testing.expect(C.storedFastPath(large, config));
    for (std.meta.tags(Framing)) |framing| {
        const raw = try C.encodePublic(std.testing.allocator, framing, .adaptive, large, null, 65535, config);
        defer std.testing.allocator.free(raw);
        // Full-size production blocks still need the split planner once the
        // input exceeds one block, even if the one-shot sample appears random.
        try std.testing.expect(raw.len < 10_000);
        const decoded = try C.decodePublic(std.testing.allocator, framing, raw, "");
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, large, decoded);
    }
    var dictionary: [16384]u8 = undefined;
    random.random().bytes(&dictionary);
    random.random().bytes(input[0..1024]);
    @memcpy(input[1024..], dictionary[dictionary.len - 7168 ..]);
    try std.testing.expect(C.storedFastPath(&input, config));
    for ([_]Framing{ .raw, .zlib }) |framing| {
        for (std.meta.tags(BestMode)) |mode| {
            const raw = try C.encodePublic(std.testing.allocator, framing, mode, &input, &dictionary, 1024, config);
            defer std.testing.allocator.free(raw);
            try std.testing.expect(raw.len < 2000);
            const decoded = try C.decodePublic(std.testing.allocator, framing, raw, &dictionary);
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, &input, decoded);
        }
    }
}

fn allocationFailures(comptime C: type) !void {
    const Run = struct {
        fn run(allocator: std.mem.Allocator, mode: Mode) !void {
            const input = ("Q" ** 16) ++ ("abcdefgh" ** 4);
            const raw = try C.encode(allocator, mode, input, "0123456789abcdefgh", 16, options(C));
            allocator.free(raw);
        }
    };
    for (modes) |mode|
        try std.testing.checkAllAllocationFailures(std.testing.allocator, Run.run, .{mode});
    const Public = struct {
        fn run(allocator: std.mem.Allocator, framing: Framing, mode: BestMode) !void {
            const input = ("Q" ** 16) ++ ("abcdefgh" ** 4);
            const raw = try C.encodePublic(allocator, framing, mode, input, "0123456789abcdefgh", 16, options(C));
            allocator.free(raw);
        }
    };
    for ([_]Framing{ .raw, .zlib }) |framing| {
        for ([_]BestMode{ .split, .adaptive }) |mode|
            try std.testing.checkAllAllocationFailures(std.testing.allocator, Public.run, .{ framing, mode });
    }
    const Plan = struct {
        fn run(allocator: std.mem.Allocator, optimal: bool) !void {
            var config = options(C);
            if (optimal) config.parser = .optimal;
            const plan = try C.plan(allocator, "0123456789abcdef", "xyz0123456789abcdef", 5, 8, config);
            plan.deinit(allocator);
        }
    };
    for ([_]bool{ false, true }) |optimal|
        try std.testing.checkAllAllocationFailures(std.testing.allocator, Plan.run, .{optimal});
}

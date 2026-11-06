//! Inspect the actual otherwise-discarded best/adaptive candidate wires through
//! a private codec adapter. Counters come only from the independent RFC oracle.
const std = @import("std");
const oracle = @import("frame_window_oracle.zig");
const a = std.testing.allocator;

const source_fixture =
    \\const std = @import("std");
    \\pub fn update(state: *State, input: []const u8) !usize {
    \\    var consumed: usize = 0;
    \\    for (input) |byte| {
    \\        state.checksum = state.checksum *% 33 + byte;
    \\        consumed += 1;
    \\    }
    \\    return consumed;
    \\}
    \\
** 24;

const Counts = struct {
    fallbacks: usize = 0,
    refined_seeds: usize = 0,
    refined_candidates: usize = 0,
    history_candidates: usize = 0,
    history_blocks: usize = 0,
    adaptive_candidates: usize = 0,
    adaptive_blocks: usize = 0,
    matches: usize = 0,
    dictionary_matches: usize = 0,
    cross_block_matches: usize = 0,
    max_distance: usize = 0,

    fn record(self: *Counts, stats: oracle.Stats) void {
        self.matches += stats.matches;
        self.dictionary_matches += stats.dictionary_matches;
        self.cross_block_matches += stats.cross_block_matches;
        self.max_distance = @max(self.max_distance, stats.max_distance);
    }
};

pub fn contracts(comptime D: type, comptime A: type) !void {
    var counts: Counts = .{};
    // The final chunk must also meet BT's 4096-byte minimum. A 512-byte
    // tail plus a narrow history correctly declines this optional optimizer.
    const history = try a.alloc(u8, 69_632);
    defer a.free(history);
    var random = std.Random.DefaultPrng.init(0xda94b15);
    random.random().bytes(history[0..1024]);
    @memset(history[0..32], 'q');
    @memset(history[128..256], 'q');
    @memset(history[1000..1024], 'q');
    for (1024..history.len) |i| history[i] = history[i % 1024];

    for ([_]usize{ 127, 512, 1024 }) |cap| {
        var options = D.optionsForLevel(.best);
        options.lz77_options.window_len = cap;
        options.lz77_options.max_chain = 16;
        options.lz77_options.max_candidates = 4;
        const fallbacks = A.fallbacks(options);
        try std.testing.expectEqual(@as(usize, 2), fallbacks.len);
        for (fallbacks.items[0..fallbacks.len]) |fallback| {
            try std.testing.expect(fallback.lz77_options.window_len <= cap);
            for ([_]?[]const u8{ null, "", history[0..2048] }) |dictionary| {
                const encoded = if (dictionary) |dict|
                    try D.encodeRawBestWithDictionaryAlloc(a, history[0..8192], dict, fallback)
                else
                    try D.encodeRawBestAlloc(a, history[0..8192], fallback);
                defer a.free(encoded);
                counts.record(try oracle.raw(encoded, history[0..8192], dictionary orelse "", cap, 1024));
                counts.fallbacks += 1;
            }
        }

        const refined = try A.refinedCandidatesAlloc(a, source_fixture, options);
        defer a.free(refined.seed);
        const seed_stats = try oracle.raw(refined.seed, source_fixture, "", cap, 0);
        try std.testing.expect(seed_stats.matches != 0);
        counts.record(seed_stats);
        counts.refined_seeds += 1;
        if (refined.candidate) |candidate| {
            defer a.free(candidate);
            counts.record(try oracle.raw(candidate, source_fixture, "", cap, 0));
            counts.refined_candidates += 1;
        }

        const history_candidate = (try A.refinedHistoryAlloc(a, history, options)) orelse {
            var offset: usize = 0;
            while (offset < history.len) {
                const length = @min(@as(usize, 32768), history.len - offset);
                const wire = A.refinedHistoryChunkAlloc(a, history, offset, length, 32768, options) catch |err| {
                    std.debug.print("history candidate planning failed cap={d} offset={d} length={d}: {s}\n", .{ cap, offset, length, @errorName(err) });
                    return err;
                };
                defer a.free(wire);
                _ = try oracle.raw(wire, history[offset..][0..length], history[offset - @min(offset, cap) .. offset], cap, 0);
                offset += length;
            }
            return error.TestUnexpectedResult;
        };
        defer a.free(history_candidate);
        const history_stats = try oracle.raw(history_candidate, history, "", cap, 1024);
        try std.testing.expectEqual(@as(usize, 3), history_stats.blockCount());
        try std.testing.expect(history_stats.cross_block_matches != 0);
        counts.record(history_stats);
        counts.history_candidates += 1;
        counts.history_blocks += history_stats.blockCount();
    }

    var input: [4096]u8 = undefined;
    random.random().bytes(input[0..512]);
    @memset(input[128..256], 'z');
    for (512..input.len) |i| input[i] = input[i % 512];
    const dictionary = try a.alloc(u8, 40_000);
    defer a.free(dictionary);
    random.random().bytes(dictionary);
    @memcpy(dictionary[dictionary.len - 512 ..], input[0..512]);
    for ([_]usize{ 127, 512, 1024 }) |cap| {
        var options = D.optionsForLevel(.best);
        options.lz77_options.window_len = cap;
        options.lz77_options.max_chain = 16;
        options.lz77_options.max_candidates = 4;
        for ([_]?[]const u8{ null, "", dictionary }) |dict| {
            const adaptive = try A.adaptiveRawAlloc(a, &input, dict, options, .{
                .min_block_len = 256,
                .max_block_len = 256,
                .sample_len = 64,
                .search_step = 256,
            });
            defer a.free(adaptive);
            const stats = try oracle.raw(adaptive, &input, dict orelse "", cap, 512);
            try std.testing.expectEqual(@as(usize, 16), stats.blockCount());
            if (cap >= 512) {
                try std.testing.expect(stats.cross_block_matches != 0);
                if (dict != null and dict.?.len != 0)
                    try std.testing.expect(stats.dictionary_matches != 0);
            }
            counts.record(stats);
            counts.adaptive_candidates += 1;
            counts.adaptive_blocks += stats.blockCount();
        }
    }
    try std.testing.expect(counts.refined_candidates != 0);
    try std.testing.expect(counts.dictionary_matches != 0 and counts.cross_block_matches != 0);
    std.debug.print("zlib candidate token audit: fallback_wires={d} refined_seeds={d} refined_candidates={d} history_candidates={d} history_blocks={d} adaptive_candidates={d} adaptive_blocks={d} matches={d} dictionary_matches={d} cross_block_matches={d} max_distance={d}\n", .{
        counts.fallbacks,           counts.refined_seeds,  counts.refined_candidates,
        counts.history_candidates,  counts.history_blocks, counts.adaptive_candidates,
        counts.adaptive_blocks,     counts.matches,        counts.dictionary_matches,
        counts.cross_block_matches, counts.max_distance,
    });
}

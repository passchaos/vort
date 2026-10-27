//! Complete wire regressions for best-parser arbitration and caller limits.
const std = @import("std");

fn pairedInput(output: []u8, seed: usize) void {
    var state: u64 = seed + 1;
    for (output, 0..) |*byte, i| {
        state = state *% 6364136223846793005 +% 1;
        byte.* = switch (i % 5) {
            0, 1 => 0,
            2 => @intCast(((i / 5 / 2) * 47 + seed) % 254 + 1),
            3 => @intCast((i / 5 / 2) / 254 + 1),
            else => @truncate(state >> 40),
        };
    }
}

pub fn pairs(comptime API: type) !void {
    var input: [4096]u8 = undefined;
    for (0..32) |seed| {
        pairedInput(&input, seed);
        const best_options = API.optionsForLevel(.best);
        var filtered_options = best_options;
        filtered_options.strategy = .filtered;
        const best = try API.encodeRawBestAlloc(std.testing.allocator, &input, best_options);
        defer std.testing.allocator.free(best);
        const ordinary = try API.encodeRawBestAlloc(std.testing.allocator, &input, API.optionsForLevel(.default));
        defer std.testing.allocator.free(ordinary);
        const filtered = try API.encodeRawBestAlloc(std.testing.allocator, &input, filtered_options);
        defer std.testing.allocator.free(filtered);
        try std.testing.expect(best.len <= ordinary.len and best.len <= filtered.len);
        const decoded = try API.decodeRawAutoAlloc(std.testing.allocator, best);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &input, decoded);
    }
}

pub fn fixed(comptime API: type) !void {
    var input: [512]u8 = undefined;
    var state: u64 = 17;
    for (&input) |*byte| {
        state = state *% 6364136223846793005 +% 1;
        byte.* = @intCast((state >> 32) % 16);
    }
    var options = API.optionsForLevel(.best);
    options.block_selection = .stored_fixed;
    const raw = try API.encodeRawBestAlloc(std.testing.allocator, &input, options);
    defer std.testing.allocator.free(raw);
    const zlib = try API.encodeZlibBestAlloc(std.testing.allocator, &input, options);
    defer std.testing.allocator.free(zlib);
    const gzip = try API.encodeGzipBestAlloc(std.testing.allocator, &input, options);
    defer std.testing.allocator.free(gzip);
    for ([_][]const u8{ raw, zlib[2 .. zlib.len - 4], gzip[10 .. gzip.len - 8] }) |payload| {
        // This short input has one final block. Checking BFINAL and BTYPE
        // proves the complete payload obeys stored/fixed-only selection.
        try std.testing.expectEqual(@as(u8, 1), payload[0] & 1);
        try std.testing.expect(((payload[0] >> 1) & 3) != 2);
        const decoded = try API.decodeRawAutoAlloc(std.testing.allocator, payload);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &input, decoded);
    }
}

pub fn dictionary(comptime API: type) !void {
    var history: [1024]u8 = @splat(255);
    var input: [128]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @intCast(i);
    @memcpy(history[0..128], &input);
    var options = API.optionsForLevel(.best);
    options.lz77_options.window_len = 64;
    const raw = try API.encodeRawBestWithDictionaryAlloc(std.testing.allocator, &input, &history, options);
    defer std.testing.allocator.free(raw);
    const zlib = try API.encodeZlibBestWithDictionaryAlloc(std.testing.allocator, &input, &history, options);
    defer std.testing.allocator.free(zlib);
    // All matching dictionary bytes are more than 64 bytes back. Neither
    // candidate may reference them; raw decoding needs no dictionary at all.
    for ([_][]const u8{ raw, zlib[6 .. zlib.len - 4] }) |payload| {
        const decoded = try API.decodeRawAutoAlloc(std.testing.allocator, payload);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &input, decoded);
    }
    const wrapped = try API.decodeZlibAllocWithDictionary(std.testing.allocator, zlib, &history);
    defer std.testing.allocator.free(wrapped);
    try std.testing.expectEqualSlices(u8, &input, wrapped);
}

pub fn bounds(comptime API: type) !void {
    const candidates = @import("../best_candidates.zig");
    var options = API.optionsForLevel(.best);
    options.block_selection = .stored_fixed;
    options.lz77_options = .{ .window_len = 64, .max_chain = 3, .nice_len = 12, .max_candidates = 2, .lazy_min_gain = 7, .min_match = 4, .max_match = 12, .min_savings_bits = 18, .new_distance_penalty_bits = 4 };
    options.split_options = .{ .min_block_len = 32, .max_block_len = 512, .sample_len = 64, .search_step = 16 * 1024 };
    const all = candidates.build(options, API.optionsForLevel(.default));
    try std.testing.expectEqual(@as(usize, 2), all.len);
    for (all.slice()) |candidate| {
        const selected = API.normalizeOptionsForStrategy(candidate);
        try std.testing.expectEqual(options.block_selection, selected.block_selection);
        try std.testing.expect(selected.lz77_options.window_len <= options.lz77_options.window_len);
        try std.testing.expect(selected.lz77_options.max_chain <= options.lz77_options.max_chain);
        try std.testing.expect(selected.lz77_options.max_candidates <= options.lz77_options.max_candidates);
        try std.testing.expect(selected.lz77_options.min_match >= options.lz77_options.min_match);
        try std.testing.expect(selected.lz77_options.max_match <= options.lz77_options.max_match);
        try std.testing.expect(selected.lz77_options.min_savings_bits >= options.lz77_options.min_savings_bits);
        try std.testing.expectEqual(options.lz77_options.new_distance_penalty_bits, selected.lz77_options.new_distance_penalty_bits);
        try std.testing.expect(selected.split_options.max_block_len <= options.split_options.max_block_len);
        try std.testing.expect(selected.split_options.sample_len <= options.split_options.sample_len);
    }
}

pub fn ownership(comptime API: type) !void {
    const Runner = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var input: [96]u8 = undefined;
            pairedInput(&input, 1);
            const encoded = try API.encodeRawBestAlloc(allocator, &input, API.optionsForLevel(.best));
            defer allocator.free(encoded);
            const decoded = try API.decodeRawAutoAlloc(allocator, encoded);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, &input, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Runner.run, .{});
}

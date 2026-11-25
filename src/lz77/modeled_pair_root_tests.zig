const std = @import("std");

pub fn run(comptime Root: type) !void {
    const a = std.testing.allocator;
    var literals: [2][256]u16 = undefined;
    var contexts: [2][Root.literal_context_class_count * 256]u16 = undefined;
    var lengths: [2][Root.max_match_len + 1]u16 = undefined;
    for (0..2) |side| {
        for (&literals[side], 0..) |*price, i| price.* = @intCast(256 + (i * 37 + side * 113) % 2048);
        for (&contexts[side], 0..) |*price, i| price.* = @intCast(256 + (i * 17 + side * 97) % 2048);
        for (&lengths[side], 0..) |*price, i| price.* = @intCast(128 + (i * 23 + side * 41) % 1024);
    }
    const fixture_lengths = [_]usize{ 0, 1, 3, 4, 7, 16, 33, 255, 512, 4096, 8192, 65535, 65536, 65537 };
    for (fixture_lengths, 0..) |size, fixture| {
        const input = try a.alloc(u8, size);
        defer a.free(input);
        var state: u32 = 0x243f6a88;
        for (input, 0..) |*byte, i| {
            state = state *% 1664525 +% 1013904223;
            byte.* = switch (fixture % 3) {
                0 => @truncate(state >> 24),
                1 => @intCast('a' + i % 3),
                else => @intCast('a' + (state >> 24) % 8),
            };
        }
        if (size > 512 and fixture % 3 == 0) @memcpy(input[size / 2 ..][0 .. size / 4], input[0 .. size / 4]);
        const window: usize = @min(size, 32768);
        const distances = try a.alloc(u16, 2 * (window + 1));
        defer a.free(distances);
        const distance_tables = [2][]u16{ distances[0 .. window + 1], distances[window + 1 ..] };
        for (0..2) |side| {
            for (distance_tables[side], 0..) |*price, d|
                price.* = @intCast(64 + (d * 31 + side * 191) % 1536);
        }
        const models = [2]Root.OptimalCostModel{
            .{ .literal = &literals[0], .literal_context = &contexts[0], .length = &lengths[0], .distance = distance_tables[0] },
            .{ .literal = &literals[1], .length = &lengths[1], .distance = distance_tables[1] },
        };
        const Provider = struct {
            length: usize,
            fn find(context: *anyopaque, position: usize) ?Root.DictionaryMatch {
                const self: *const @This() = @ptrCast(@alignCast(context));
                if (position % 11 != 0 or position + 8 > self.length) return null;
                return .{ .output_len = 8, .copy_len = 4, .address = @intCast(position % 2048) };
            }
        };
        var provider: Provider = .{ .length = size };
        const options: Root.GreedyOptions = .{
            .window_len = window,
            .min_match = 4,
            .max_chain = if (fixture < 10) fixture % 7 else 12,
            .max_candidates = 1 + fixture % 8,
            .nice_len = 7 + fixture % 32,
            .dictionary = if (fixture % 2 == 0) .{ .context = &provider, .find = Provider.find } else null,
            .dictionary_cost = 128,
        };
        const paired = try Root.optimalPlanPairWithCostModelsAlloc(a, input, options, models);
        defer paired[0].deinit(a);
        defer paired[1].deinit(a);
        for (0..2) |side| {
            const scalar = try Root.optimalPlanAllocWithCostModel(a, input, options, models[side]);
            defer scalar.deinit(a);
            try std.testing.expectEqualDeep(scalar.stats, paired[side].stats);
            try std.testing.expectEqualDeep(scalar.tokens, paired[side].tokens);
            const bounded = try Root.optimalPlanAllocWithCostModelBounded(a, input, options, models[side]);
            defer bounded.deinit(a);
            try std.testing.expectEqualDeep(scalar.stats, bounded.stats);
            try std.testing.expectEqualDeep(scalar.tokens, bounded.tokens);
        }
        if (size <= 65536) try std.testing.expect(Root.supportsOptimalModeledPair(input, options, models));
        if (size == 65537) try std.testing.expect(!Root.supportsOptimalModeledPair(input, options, models));

        if (size == 512) {
            const Failure = struct {
                fn run(heap: std.mem.Allocator, bytes: []const u8, opts: Root.GreedyOptions, prices: [2]Root.OptimalCostModel) !void {
                    const plans = try Root.optimalPlanPairWithCostModelsAlloc(heap, bytes, opts, prices);
                    defer plans[0].deinit(heap);
                    defer plans[1].deinit(heap);
                }
            };
            try std.testing.checkAllAllocationFailures(a, Failure.run, .{ input, options, models });
        }
    }
}

const std = @import("std");
const h = @import("helpers.zig");
const a = std.testing.allocator;

fn run(source: h.source_mod.Source, options: h.Options, cap: usize) !void {
    const model: h.prices.EntropyModel = .{};
    var budget = h.resources.WorkingAllocator.init(a, cap);
    const parameters: h.state.Parameters = .{
        .strategy = options.strategy,
        .entropy = &model,
        .hq_options = .{
            .search_depth = 8,
            .nice_len = 16,
            .min_match = 3,
            .parse_mode = if (options.whole) .whole_block else .bounded,
            .match_lengths = if (options.complete) .complete else .sampled,
            .max_working_memory = cap,
        },
    };
    defer std.testing.expectEqual(@as(usize, 0), budget.live) catch @panic("tagged DP leaked requested bytes");
    const plan = try h.dp.plan(budget.allocator(), &budget, source, parameters, h.tree.Matcher);
    defer plan.deinit(budget.allocator());
}

pub fn contracts() !void {
    const source = h.source_mod.Source.init("", "", "abcaabca", 1024);
    inline for (.{ false, true }) |whole| {
        inline for (.{ false, true }) |complete| {
            for ([_]h.Options{ .{}, .{ .strategy = .btultra } }) |selected| {
                var options = selected;
                options.whole = whole;
                options.complete = complete;
                const full = try h.compare(source, options);
                for (0..@as(usize, @intCast(full.admitted)) + 2) |limit| {
                    options.quota = @intCast(limit);
                    const result = try h.compare(source, options);
                    const want: ?anyerror = if (limit < full.admitted) error.SearchLimitExceeded else null;
                    try std.testing.expectEqual(want, result.failure);
                }
                try run(source, options, full.peak);
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, run(source, options, full.old_peak));
                try std.testing.expectError(error.OutOfMemory, run(source, options, 0));
            }
        }
    }
    // Validate large whole/bounded tag accounting without allocating a table.
    const storage = try a.alloc(u8, 131072);
    defer a.free(storage);
    for ([_]usize{ 0, 2, 3, 4096, 4097, 131072 }) |len| {
        const virtual_source: h.source_mod.Source = .{ .dictionary = "", .history = "", .block = storage[0..len], .window_len = 131072 };
        inline for (.{ false, true }) |whole| {
            const parameters: h.state.Parameters = .{ .strategy = .btopt, .hq_options = .{ .parse_mode = if (whole) .whole_block else .bounded } };
            const extra: usize = if (len < 3) 0 else @as(usize, 16) * (1 + @as(usize, if (whole) len else @min(len, 4096)));
            try std.testing.expectEqual(try h.Frozen.ownWorkingBytes(virtual_source, parameters) + extra, try h.dp.ownWorkingBytes(virtual_source, parameters));
            if (len == 131072 and whole) try std.testing.expectEqual(@as(usize, 2097168), extra);
        }
    }
    try @import("public_budget.zig").contracts();
}

const std = @import("std");
const zstd = @import("vort_zstd");
const pair = @import("encode_bench_pair.zig");
const samples = @import("encode_samples.zig");

test "Zstd benchmark primary follows effective public speed-first levels" {
    for ([_]c_int{ 1, 2, 3, 8, 19 }) |level| {
        const actual = try pair.resolvePrimaryOptions(level, null);
        const public = try zstd.nativeEncodeLevelDiagnostics(level, .{});
        try std.testing.expectEqualDeep(public.primary_options, actual);
    }
    const level3 = try pair.resolvePrimaryOptions(3, null);
    try std.testing.expectEqual(zstd.Strategy.greedy, level3.strategy);
    try std.testing.expectEqual(@as(usize, 24), level3.match_search_budget);
    try std.testing.expect(!level3.rep_beam_search);
    const level1 = try samples.ResolvedOptions.capture(try pair.resolvePrimaryOptions(1, null));
    const level2 = try samples.ResolvedOptions.capture(try pair.resolvePrimaryOptions(2, null));
    try std.testing.expectEqual(zstd.FastParserSelection.single_table, level1.fast_parser);
    try std.testing.expectEqual(zstd.FastParserSelection.double_fast, level2.fast_parser);
}

test "Zstd benchmark primary preserves explicit native options" {
    const requested: zstd.NativeFrameOptions = .{
        .selection = .fast_compressed,
        .strategy = .lazy,
        .match_search_budget = 41,
        .rep_beam_search = false,
        .content_checksum = true,
        .window_log = 18,
    };
    try std.testing.expectEqualDeep(requested, try pair.resolvePrimaryOptions(3, requested));
}

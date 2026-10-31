const std = @import("std");
const parser = @import("../hq_parser.zig");
const controls = @import("../../encode/controls.zig");
const a = std.testing.allocator;

test "Zstd HQ parser engines preserve explicit choice quota and actual metadata" {
    const source = parser.Source.init("", "", "abcd" ** 64, 1024);
    var peaks: [2]usize = undefined;
    for ([_]controls.HqParserEngine{ .local_optimal, .beam }, 0..) |engine, index| {
        var profile: controls.Profile = .{};
        var parameters: parser.Parameters = .{ .strategy = .btopt, .profile = &profile, .hq_options = .{ .parser_engine = engine } };
        const ordinary = try parser.planAlloc(a, source, parameters);
        defer ordinary.deinit(a);
        try std.testing.expectEqual(engine, profile.effective_hq_parser_engine.?);
        peaks[index] = profile.peak_working_memory;
        const cap = profile.max_plan_price_evaluations;
        try std.testing.expect(cap > 0);
        parameters.hq_options.max_price_evaluations = cap;
        profile.reset();
        const limited = try parser.planAlloc(a, source, parameters);
        defer limited.deinit(a);
        try std.testing.expectEqualDeep(ordinary.records, limited.records);
        try std.testing.expectEqualDeep(ordinary.offset_values, limited.offset_values);
        try std.testing.expectEqualDeep(ordinary.statistics, limited.statistics);
        try std.testing.expectEqual(cap, profile.max_plan_price_evaluations);
        try std.testing.expectEqual(peaks[index], profile.peak_working_memory);
        parameters.hq_options.max_price_evaluations = cap - 1;
        profile.reset();
        try std.testing.expectError(error.SearchLimitExceeded, parser.planAlloc(a, source, parameters));
        try std.testing.expectEqual(@as(u64, 1), profile.price_limit_refusals);
    }
    try std.testing.expect(peaks[0] < peaks[1]);
}

test "Zstd HQ expanded coverage resolves to beam while local is the bounded sampled default" {
    try std.testing.expectEqual(controls.HqParserEngine.local_optimal, (controls.HqOptions{}).effectiveParserEngine());
    for ([_]controls.HqParseMode{ .bounded, .whole_block }) |mode| for ([_]controls.HqMatchLengthPolicy{ .sampled, .complete }) |lengths| {
        var profile: controls.Profile = .{};
        const parameters: parser.Parameters = .{ .strategy = .btopt, .profile = &profile, .hq_options = .{ .parse_mode = mode, .match_lengths = lengths } };
        const plan = try parser.planAlloc(a, parser.Source.init("", "", "abcd" ** 4, 1024), parameters);
        defer plan.deinit(a);
        try std.testing.expectEqual(parameters.hq_options.effectiveParserEngine(), profile.effective_hq_parser_engine.?);
        if (mode == .whole_block or lengths == .complete) try std.testing.expectEqual(controls.HqParserEngine.beam, profile.effective_hq_parser_engine.?);
    };
}

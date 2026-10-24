const std = @import("std");
const vort = @import("vort");
const cli = @import("brotli_controls.zig");
const Args = struct {
    values: []const []const u8,
    index: usize = 0,
    pub fn next(self: *Args) ?[]const u8 {
        if (self.index == self.values.len) return null;
        defer self.index += 1;
        return self.values[self.index];
    }
};
fn parse(values: []const []const u8) !cli.Controls {
    var args = Args{ .values = values };
    return cli.parse(&args);
}

test "Brotli CLI HQ is opt-in and preserves null public defaults" {
    const control = try parse(&.{});
    const options = try control.resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expectEqualDeep(vort.br.PlannedEncodeOptions{}, options);
    const stream = try control.resolve(vort.br.PlannedStreamChunksOptions, null);
    try std.testing.expectEqualDeep(vort.br.PlannedStreamChunksOptions{}, stream);
    _ = try vort.br.encodedPlannedStreamBoundWithOptions(0, options);
    _ = try vort.br.encodedPlannedStreamChunksBoundWithOptions(&.{}, stream);
    const quality = try (try parse(&.{"--quality=11"})).resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expect(quality.hq == null);
    try std.testing.expectError(error.BrotliProfileRequiresHq, (try parse(&.{ "--quality=11", "--profile" })).resolve(vort.br.PlannedEncodeOptions, null));
}

test "Brotli CLI HQ equal and value flags resolve independent of order" {
    const a = try parse(&.{ "--quality=11", "--hq", "--mode=font", "--window-bits=16", "--hq-depth=65536", "--hq-nice-len=16777216", "--hq-beam-width=32", "--hq-iterations=8", "--hq-block-len=16777216", "--hq-memory=0", "--hq-npostfix=3", "--hq-ndirect-high=15" });
    const b = try parse(&.{ "--hq-ndirect-high", "15", "--hq-npostfix", "3", "--hq-memory", "0", "--hq-block-len", "16777216", "--hq-iterations", "8", "--hq-beam-width", "32", "--hq-nice-len", "16777216", "--hq-depth", "65536", "--window-bits", "16", "--mode", "font", "--hq", "--quality", "11" });
    try std.testing.expectEqualDeep(a, b);
    const resolved = try a.resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expectEqual(@as(u32, 65536), resolved.hq.?.search_depth);
    try std.testing.expectEqual(@as(u2, 3), resolved.hq.?.distance_parameters.?.npostfix);
    try std.testing.expectEqual(@as(u4, 15), resolved.hq.?.distance_parameters.?.ndirect_high);
}

test "Brotli CLI HQ preserves quality auto controls and font distance defaults" {
    inline for (.{ "10", "11" }) |name| {
        const controls = try parse(&.{ "--quality=" ++ name, "--hq", "--mode=font" });
        var options = try controls.resolve(vort.br.PlannedEncodeOptions, null);
        const quality = options.quality.?;
        const resolved = try options.hq.?.resolve(quality, options.mode);
        try std.testing.expectEqual(@as(u8, if (quality == 10) 8 else 16), resolved.beam_width);
        try std.testing.expectEqual(@as(u8, if (quality == 10) 1 else 2), resolved.iterations);
        try std.testing.expectEqual(@as(u2, 1), resolved.distance_parameters.npostfix);
        try std.testing.expectEqual(@as(u4, 6), resolved.distance_parameters.ndirect_high);
        var profile: vort.BrotliHqProfile = .{};
        var instrumented = controls;
        instrumented.profile = true;
        const profiled = try instrumented.resolve(vort.br.PlannedEncodeOptions, &profile);
        options.hq.?.profile = &profile;
        try std.testing.expectEqualDeep(options, profiled);
    }
    const a = try (try parse(&.{ "--quality=10", "--mode=font", "--hq-npostfix=2" })).resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expectEqual(@as(u4, 6), a.hq.?.distance_parameters.?.ndirect_high);
    const b = try (try parse(&.{ "--quality=11", "--mode=font", "--hq-ndirect-high=4" })).resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expectEqual(@as(u2, 1), b.hq.?.distance_parameters.?.npostfix);
}

test "Brotli CLI HQ public validation rejects bounds and invalid selectors" {
    inline for (.{ "--hq-depth=0", "--hq-depth=65537", "--hq-nice-len=1", "--hq-nice-len=16777217", "--hq-beam-width=33", "--hq-iterations=9", "--hq-block-len=0", "--hq-block-len=16777217" }) |flag|
        try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{ "--quality=10", flag })).resolve(vort.br.PlannedEncodeOptions, null));
    inline for (.{ "0", "9", "12" }) |quality|
        try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{ "--quality=" ++ quality, "--hq" })).resolve(vort.br.PlannedEncodeOptions, null));
    try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{"--hq"})).resolve(vort.br.PlannedEncodeOptions, null));
    const invalid_quality = try (try parse(&.{"--quality=12"})).resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expectError(error.InvalidBlockPlan, vort.br.encodedPlannedStreamBoundWithOptions(0, invalid_quality));
    const invalid_window = try (try parse(&.{"--window-bits=9"})).resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expectError(error.InvalidBlockPlan, vort.br.encodedPlannedStreamBoundWithOptions(0, invalid_window));
    try std.testing.expectError(error.Overflow, parse(&.{"--hq-npostfix=4"}));
    try std.testing.expectError(error.Overflow, parse(&.{"--hq-ndirect-high=16"}));
}

test "Brotli CLI HQ parser rejects duplicate unknown and extra arguments" {
    inline for (.{ "--quality=10", "--mode=text", "--window-bits=16", "--hq-depth=64", "--hq-nice-len=128", "--hq-beam-width=0", "--hq-iterations=0", "--hq-block-len=262144", "--hq-memory=1024", "--hq-npostfix=1", "--hq-ndirect-high=6", "--hq", "--profile" }) |flag|
        try std.testing.expectError(error.DuplicateBrotliOption, parse(&.{ flag, flag }));
    try std.testing.expectError(error.UnknownBrotliOption, parse(&.{"--hq-unknown=1"}));
    try std.testing.expectError(error.MissingBrotliOptionValue, parse(&.{"--hq-depth"}));
    try std.testing.expectError(error.UnexpectedBrotliArgument, parse(&.{ "10", "text", "16", "extra" }));
    try std.testing.expectError(error.InvalidBrotliMode, parse(&.{"--mode=unknown"}));
    try std.testing.expectError(error.DuplicateBrotliOption, parse(&.{ "10", "--quality=10" }));
}

test "Brotli CLI total memory controls preserve defaults without selecting HQ" {
    const empty = try parse(&.{});
    const defaults = try empty.resolveWithMemoryProfile(vort.br.PlannedEncodeOptions, null, null);
    try std.testing.expectEqualDeep(vort.br.PlannedEncodeOptions{}, defaults);
    const capped = try parse(&.{"--max-total-memory=0"});
    try std.testing.expect(!capped.hqSelected());
    const options = try capped.resolveWithMemoryProfile(vort.br.PlannedEncodeOptions, null, null);
    try std.testing.expectEqual(@as(?usize, 0), options.max_total_working_memory);
    try std.testing.expect(options.hq == null and options.memory_profile == null);
    var profile: vort.BrotliEncodeMemoryProfile = .{};
    const tracked = try parse(&.{"--memory-profile"});
    try std.testing.expect(!tracked.hqSelected());
    inline for (.{ vort.br.PlannedEncodeOptions, vort.br.PlannedStreamChunksOptions }) |Options| {
        const mapped = try tracked.resolveWithMemoryProfile(Options, null, &profile);
        try std.testing.expect(mapped.memory_profile == &profile);
        try std.testing.expect(mapped.hq == null and mapped.max_total_working_memory == null);
    }
    try std.testing.expectEqualDeep(vort.BrotliEncodeMemoryProfile{}, profile);
}

test "Brotli CLI total memory flags are independent and reject invalid arguments" {
    const a = try parse(&.{ "--quality=11", "--hq", "--hq-memory=8192", "--profile", "--max-total-memory=65536", "--memory-profile" });
    const b = try parse(&.{ "--memory-profile", "--max-total-memory", "65536", "--profile", "--hq-memory", "8192", "--hq", "--quality", "11" });
    try std.testing.expectEqualDeep(a, b);
    var hq_profile: vort.BrotliHqProfile = .{};
    var memory_profile: vort.BrotliEncodeMemoryProfile = .{};
    const options = try a.resolveWithMemoryProfile(vort.br.PlannedEncodeOptions, &hq_profile, &memory_profile);
    try std.testing.expectEqual(@as(?usize, 65536), options.max_total_working_memory);
    try std.testing.expectEqual(@as(usize, 8192), options.hq.?.max_working_memory);
    try std.testing.expect(options.hq.?.profile == &hq_profile and options.memory_profile == &memory_profile);
    try std.testing.expectError(error.DuplicateBrotliOption, parse(&.{ "--max-total-memory=1", "--max-total-memory=2" }));
    try std.testing.expectError(error.DuplicateBrotliOption, parse(&.{ "--memory-profile", "--memory-profile" }));
    try std.testing.expectError(error.MissingBrotliOptionValue, parse(&.{"--max-total-memory"}));
    try std.testing.expectError(error.InvalidCharacter, parse(&.{"--max-total-memory="}));
    try std.testing.expectError(error.Overflow, parse(&.{"--max-total-memory=-1"}));
}

test "Brotli CLI Large Window explicitly maps both public options without selecting HQ" {
    const a = try parse(&.{ "--large-window", "--quality=11", "--hq", "--window-bits=30" });
    const b = try parse(&.{ "--window-bits=30", "--hq", "--quality=11", "--large-window" });
    try std.testing.expectEqualDeep(a, b);
    inline for (.{ vort.br.PlannedEncodeOptions, vort.br.PlannedStreamChunksOptions }) |Options| {
        const options = try a.resolve(Options, null);
        try std.testing.expect(options.large_window and options.hq != null);
        if (Options == vort.br.PlannedEncodeOptions) try std.testing.expectEqual(@as(?u5, 30), options.window_bits) else try std.testing.expectEqual(@as(u5, 30), options.window_bits);
    }
    const selected_only = try parse(&.{"--large-window"});
    try std.testing.expect(!selected_only.hqSelected());
    try std.testing.expect((try selected_only.resolve(vort.br.PlannedEncodeOptions, null)).hq == null);
    const defaults = try (try parse(&.{})).resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expect(!defaults.large_window);
    try std.testing.expectEqualDeep(vort.br.PlannedEncodeOptions{}, defaults);
}

test "Brotli CLI Large Window public bounds require HQ and enforce each format range" {
    inline for (.{ "16", "25", "30" }) |width| {
        const controls = try parse(&.{ "--large-window", "--quality=10", "--hq", "--window-bits=" ++ width });
        const one = try controls.resolve(vort.br.PlannedEncodeOptions, null);
        const stream = try controls.resolve(vort.br.PlannedStreamChunksOptions, null);
        _ = try vort.br.encodedPlannedStreamBoundWithOptions(0, one);
        _ = try vort.br.encodedPlannedStreamChunksBoundWithOptions(&.{}, stream);
    }
    inline for (.{
        &.{"--large-window"},
        &.{ "--large-window", "--quality=10" },
        &.{ "--quality=11", "--hq", "--window-bits=25" },
        &.{ "--large-window", "--quality=11", "--hq", "--window-bits=31" },
        &.{ "--large-window", "--quality=11", "--hq", "--window-bits=9" },
    }) |args| {
        const controls = try parse(args);
        const one = try controls.resolve(vort.br.PlannedEncodeOptions, null);
        const stream = try controls.resolve(vort.br.PlannedStreamChunksOptions, null);
        try std.testing.expectError(error.InvalidBlockPlan, vort.br.encodedPlannedStreamBoundWithOptions(0, one));
        try std.testing.expectError(error.InvalidBlockPlan, vort.br.encodedPlannedStreamChunksBoundWithOptions(&.{}, stream));
    }
    try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{ "--large-window", "--quality=9", "--hq" })).resolve(vort.br.PlannedEncodeOptions, null));
    try std.testing.expectError(error.DuplicateBrotliOption, parse(&.{ "--large-window", "--large-window" }));
}

test "Brotli CLI whole-block mode is an explicit HQ override with stable bounded defaults" {
    const unselected = try parse(&.{});
    try std.testing.expect(!unselected.hqSelected());
    const defaults = try unselected.resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expectEqualDeep(vort.br.PlannedEncodeOptions{}, defaults);
    const a = try parse(&.{ "--quality=11", "--hq-parse-mode=whole_block" });
    const b = try parse(&.{ "--hq-parse-mode", "whole_block", "--quality", "11" });
    try std.testing.expectEqualDeep(a, b);
    try std.testing.expect(a.hqSelected());
    inline for (.{ vort.br.PlannedEncodeOptions, vort.br.PlannedStreamChunksOptions }) |Options| {
        const mapped = try a.resolve(Options, null);
        try std.testing.expectEqual(.whole_block, mapped.hq.?.parse_mode);
    }
    const implicit = try (try parse(&.{ "--quality=10", "--hq" })).resolve(vort.br.PlannedEncodeOptions, null);
    const explicit = try (try parse(&.{ "--quality=10", "--hq", "--hq-parse-mode=bounded" })).resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expectEqualDeep(implicit, explicit);
    try std.testing.expectEqual(.bounded, implicit.hq.?.parse_mode);
}

test "Brotli CLI whole-block validation and profiling preserve requested mode" {
    inline for (.{ "10", "11" }) |quality| {
        var profile: vort.BrotliHqProfile = .{};
        const controls = try parse(&.{ "--quality=" ++ quality, "--hq-parse-mode=whole_block", "--profile" });
        const one = try controls.resolve(vort.br.PlannedEncodeOptions, &profile);
        const stream = try controls.resolve(vort.br.PlannedStreamChunksOptions, &profile);
        _ = try vort.br.encodedPlannedStreamBoundWithOptions(0, one);
        _ = try vort.br.encodedPlannedStreamChunksBoundWithOptions(&.{}, stream);
        const resolved = try one.hq.?.resolve(one.quality.?, one.mode);
        try std.testing.expectEqual(.whole_block, resolved.parse_mode);
        try std.testing.expect(one.hq.?.profile == &profile);
        try std.testing.expectEqualDeep(vort.BrotliHqProfile{}, profile);
    }
    try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{"--hq-parse-mode=whole_block"})).resolve(vort.br.PlannedEncodeOptions, null));
    try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{ "--quality=9", "--hq-parse-mode=whole_block" })).resolve(vort.br.PlannedEncodeOptions, null));
    try std.testing.expectError(error.InvalidBrotliParseMode, parse(&.{"--hq-parse-mode=optimal"}));
    try std.testing.expectError(error.InvalidBrotliParseMode, parse(&.{"--hq-parse-mode="}));
    try std.testing.expectError(error.MissingBrotliOptionValue, parse(&.{"--hq-parse-mode"}));
    try std.testing.expectError(error.DuplicateBrotliOption, parse(&.{ "--hq-parse-mode=bounded", "--hq-parse-mode=whole_block" }));
}

test "Brotli CLI complete copy lengths independently map both public HQ option fields" {
    const unselected = try parse(&.{});
    const defaults = try unselected.resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expectEqualDeep(vort.br.PlannedEncodeOptions{}, defaults);
    const implicit = try (try parse(&.{ "--quality=10", "--hq" })).resolve(vort.br.PlannedEncodeOptions, null);
    const explicit = try (try parse(&.{ "--quality=10", "--hq-copy-lengths=sampled" })).resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expectEqualDeep(implicit, explicit);
    try std.testing.expectEqual(.sampled, implicit.hq.?.copy_lengths);
    try std.testing.expect(implicit.hq.?.max_price_evaluations == null);
    const a = try parse(&.{ "--quality=11", "--hq-copy-lengths=complete", "--hq-max-price-evaluations=0" });
    const b = try parse(&.{ "--hq-max-price-evaluations", "0", "--hq-copy-lengths", "complete", "--quality", "11" });
    try std.testing.expectEqualDeep(a, b);
    try std.testing.expect(a.hqSelected());
    inline for (.{ vort.br.PlannedEncodeOptions, vort.br.PlannedStreamChunksOptions }) |Options| {
        const mapped = try a.resolve(Options, null);
        try std.testing.expectEqual(.complete, mapped.hq.?.copy_lengths);
        try std.testing.expectEqual(@as(?u64, 0), mapped.hq.?.max_price_evaluations);
        try std.testing.expectEqual(.bounded, mapped.hq.?.parse_mode);
    }
    const independent = try (try parse(&.{ "--quality=11", "--hq-copy-lengths=complete", "--hq-parse-mode=whole_block" })).resolve(vort.br.PlannedEncodeOptions, null);
    try std.testing.expectEqual(.whole_block, independent.hq.?.parse_mode);
    try std.testing.expectEqual(.complete, independent.hq.?.copy_lengths);
}

test "Brotli CLI complete length controls keep public validation and distinct profiling" {
    inline for (.{ "10", "11" }) |quality| {
        var profile: vort.BrotliHqProfile = .{};
        const control = try parse(&.{ "--quality=" ++ quality, "--hq-copy-lengths=complete", "--hq-max-price-evaluations=18446744073709551615", "--profile" });
        const one = try control.resolve(vort.br.PlannedEncodeOptions, &profile);
        const stream = try control.resolve(vort.br.PlannedStreamChunksOptions, &profile);
        _ = try vort.br.encodedPlannedStreamBoundWithOptions(0, one);
        _ = try vort.br.encodedPlannedStreamChunksBoundWithOptions(&.{}, stream);
        const resolved = try one.hq.?.resolve(one.quality.?, one.mode);
        try std.testing.expectEqual(.complete, resolved.copy_lengths);
        try std.testing.expectEqual(@as(?u64, std.math.maxInt(u64)), resolved.max_price_evaluations);
        try std.testing.expect(one.hq.?.profile == &profile);
        try std.testing.expectEqualDeep(vort.BrotliHqProfile{}, profile);
    }
    try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{"--hq-copy-lengths=complete"})).resolve(vort.br.PlannedEncodeOptions, null));
    try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{ "--quality=9", "--hq-copy-lengths=complete" })).resolve(vort.br.PlannedEncodeOptions, null));
    try std.testing.expectError(error.InvalidBlockPlan, (try parse(&.{ "--quality=9", "--hq-max-price-evaluations=10" })).resolve(vort.br.PlannedEncodeOptions, null));
    try std.testing.expectError(error.InvalidBrotliCopyLengths, parse(&.{"--hq-copy-lengths=literal"}));
    try std.testing.expectError(error.DuplicateBrotliOption, parse(&.{ "--hq-copy-lengths=sampled", "--hq-copy-lengths=complete" }));
    try std.testing.expectError(error.DuplicateBrotliOption, parse(&.{ "--hq-max-price-evaluations=1", "--hq-max-price-evaluations=2" }));
    try std.testing.expectError(error.MissingBrotliOptionValue, parse(&.{"--hq-max-price-evaluations"}));
    try std.testing.expectError(error.InvalidCharacter, parse(&.{"--hq-max-price-evaluations="}));
    try std.testing.expectError(error.Overflow, parse(&.{"--hq-max-price-evaluations=-1"}));
}

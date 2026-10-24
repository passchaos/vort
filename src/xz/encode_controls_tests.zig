const std = @import("std");
const xz = @import("../xz.zig");
const h = @import("../lzma/encode_controls_helpers.zig");
const allocator = std.testing.allocator;

test "XZ encode controls preserve pre-controls default greedy and lazy wire bytes" {
    const plain = h.legacyPlain();
    const greedy_wire = h.hexBytes(h.xz_greedy_hex);
    const lazy_wire = h.hexBytes(h.xz_lazy_hex);
    const encoded = try xz.encodeAlloc(allocator, &plain, .{});
    defer allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &greedy_wire, encoded);
    const lazy = try xz.encodeLazyAlloc(allocator, &plain, .{});
    defer allocator.free(lazy);
    try std.testing.expectEqualSlices(u8, &lazy_wire, lazy);
    for ([_][]const u8{ encoded, lazy }) |frame| {
        const decoded = try xz.decodeAlloc(allocator, frame);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &plain, decoded);
    }
}

fn expectRoundTrip(input: []const u8, options: xz.EncodeOptions) ![]u8 {
    const encoded = try xz.encodeAlloc(allocator, input, options);
    errdefer allocator.free(encoded);
    const decoded = try xz.decodeAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    return encoded;
}

fn expectLatestProfile(previous: xz.EncodeWorkProfile, actual: xz.EncodeWorkProfile, finder: xz.MatchFinder, nice_len: u16, depth: u32) !void {
    var expected = previous;
    expected.finder = finder;
    expected.effective_nice_len = nice_len;
    expected.effective_depth = depth;
    try std.testing.expectEqualDeep(expected, actual);
}

test "XZ encode controls all twenty presets and public streaming constructors resolve independent rows" {
    const input = "XZ preset: " ++ h.len2_plain;
    for (h.preset_cases) |expected| {
        const options = try xz.EncodeOptions.fromPreset(expected.level, expected.extreme);
        const incremental = try xz.IncrementalEncoder.Options.fromPreset(expected.level, expected.extreme);
        const raw = try xz.RawLzma2EncodeOptions.fromPreset(expected.level, expected.extreme);
        const raw_incremental = try xz.RawLzma2IncrementalEncoder.Options.fromPreset(expected.level, expected.extreme);
        try std.testing.expectEqual(expected.dictionary_size, options.dictionary_size);
        try std.testing.expectEqualStrings(expected.mode, @tagName(options.parser));
        try std.testing.expectEqualStrings(expected.finder, @tagName(options.match_options.?.finder));
        try std.testing.expectEqual(expected.nice_len, options.match_options.?.nice_len);
        try std.testing.expectEqual(expected.depth, options.match_options.?.depth);
        try std.testing.expectEqualDeep(options.lzma2Options(), raw);
        try std.testing.expectEqualDeep(options, incremental.writerOptions());
        try std.testing.expectEqualDeep(raw, raw_incremental.chunkOptions());
        const encoded = try expectRoundTrip(input, options);
        defer allocator.free(encoded);
        const info = try xz.inspect(allocator, encoded);
        try std.testing.expectEqual(@as(u64, expected.dictionary_size), info.max_dictionary_size);
    }
    var overridden = try xz.EncodeOptions.fromPreset(9, true);
    overridden.dictionary_size = 4096;
    overridden.parser = .fast;
    overridden.check = .none;
    overridden.block_size = 128;
    overridden.properties = .{ .lc = 2, .lp = 1, .pb = 1 };
    overridden.match_options.?.finder = .hc3;
    overridden.match_options.?.nice_len = 2;
    overridden.match_options.?.depth = 1;
    const encoded = try expectRoundTrip(input, overridden);
    defer allocator.free(encoded);
    const info = try xz.inspect(allocator, encoded);
    try std.testing.expectEqual(@as(u64, 4096), info.max_dictionary_size);
    try std.testing.expectEqual(xz.Check.none, info.check);
}

test "XZ encode controls all five finders execute fast normal searches and variable properties" {
    const input = h.legacyPlain();
    for ([_]xz.Parser{ .fast, .normal }) |parser| {
        for ([_]xz.MatchFinder{ .hc3, .hc4, .bt2, .bt3, .bt4 }) |finder| {
            var profile: xz.EncodeWorkProfile = .{};
            const options: xz.EncodeOptions = .{
                .parser = parser,
                .dictionary_size = 4096,
                .properties = .{ .lc = 2, .lp = 1, .pb = 1 },
                .match_options = .{ .finder = finder, .nice_len = 2, .depth = 1, .profile = &profile },
            };
            const encoded = try expectRoundTrip(&input, options);
            defer allocator.free(encoded);
            try std.testing.expectEqual(finder, profile.finder);
            try std.testing.expectEqual(finder.hashBytes(), profile.effective_nice_len);
            try std.testing.expectEqual(@as(u32, 1), profile.effective_depth);
            try std.testing.expect(profile.mf_hash_probes > 0 and profile.mf_candidate_probes > 0);
            try std.testing.expect(profile.mf_matches > 0 and profile.matches > 0);
            try std.testing.expectEqual(@as(u64, input.len), profile.literals + profile.matched_bytes);
            if (finder.isBinaryTree()) {
                try std.testing.expect(profile.mf_tree_steps > 0);
                try std.testing.expectEqual(@as(u64, 0), profile.mf_chain_steps);
            } else {
                try std.testing.expect(profile.mf_chain_steps > 0);
                try std.testing.expectEqual(@as(u64, 0), profile.mf_tree_steps);
            }
            if (parser == .normal) try std.testing.expect(profile.price_evaluations > 0);
            var unprofiled = options;
            unprofiled.match_options.?.profile = null;
            const repeated = try xz.encodeAlloc(allocator, &input, unprofiled);
            defer allocator.free(repeated);
            try std.testing.expectEqualSlices(u8, encoded, repeated);
        }
    }
    const boundary = try expectRoundTrip(&input, .{ .parser = .normal, .properties = .{ .lc = 0, .lp = 4, .pb = 4 }, .match_options = .{ .finder = .bt4 } });
    defer allocator.free(boundary);
}

test "XZ encode controls zero and short tails round trip across modern parsers" {
    for ([_][]const u8{ "", "x", "xy", "xyz", "xyxy" }) |input| {
        for ([_]xz.Parser{ .fast, .normal }) |parser| {
            const encoded = try expectRoundTrip(input, .{ .parser = parser, .match_options = .{ .finder = .bt4, .nice_len = 2 } });
            defer allocator.free(encoded);
        }
    }
    var profile: xz.EncodeWorkProfile = .{};
    const first = try xz.encodeAlloc(allocator, h.len2_plain, .{ .parser = .normal, .match_options = .{ .finder = .bt4, .nice_len = 64, .profile = &profile } });
    defer allocator.free(first);
    const previous = profile;
    const options: xz.EncodeOptions = .{ .parser = .fast, .match_options = .{ .finder = .bt2, .nice_len = 2, .depth = 3, .profile = &profile } };
    try options.validate();
    try std.testing.expectEqualDeep(previous, profile);
    const empty = try expectRoundTrip("", options);
    defer allocator.free(empty);
    try expectLatestProfile(previous, profile, .bt2, 2, 3);
    var raw_append: std.ArrayList(u8) = .empty;
    defer raw_append.deinit(allocator);
    try raw_append.appendSlice(allocator, "prefix:");
    _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &raw_append, "", .{ .parser = .normal, .match_options = .{ .finder = .hc3, .nice_len = 2, .depth = 7, .profile = &profile } });
    try std.testing.expectEqualStrings("prefix:\x00", raw_append.items);
    try expectLatestProfile(previous, profile, .hc3, 3, 7);
    var raw_encoder = try xz.RawLzma2IncrementalEncoder.init(allocator, .{ .parser = .fast, .match_options = .{ .finder = .hc4, .nice_len = 2, .depth = 5, .profile = &profile } });
    defer raw_encoder.deinit();
    const raw_streamed = try h.driveEncode(xz.RawLzma2IncrementalEncoder, allocator, &raw_encoder, "", 1, 1);
    defer allocator.free(raw_streamed);
    try std.testing.expectEqualSlices(u8, &.{0}, raw_streamed);
    try expectLatestProfile(previous, profile, .hc4, 4, 5);
    var encoder = try xz.IncrementalEncoder.initWithOptions(allocator, .{ .parser = .normal, .match_options = .{ .finder = .bt3, .nice_len = 2, .depth = 9, .profile = &profile } });
    defer encoder.deinit();
    const streamed = try h.driveEncode(xz.IncrementalEncoder, allocator, &encoder, "", 1, 1);
    defer allocator.free(streamed);
    try expectLatestProfile(previous, profile, .bt3, 3, 9);
    const decoded = try xz.decodeAlloc(allocator, streamed);
    defer allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);
}

test "XZ encode controls chunk1 zero output reused caller bytes preserve all finder parser streams" {
    const input = h.legacyPlain();
    for ([_]xz.Parser{ .fast, .normal }) |parser| {
        for ([_]xz.MatchFinder{ .hc3, .hc4, .bt2, .bt3, .bt4 }) |finder| {
            const options: xz.EncodeOptions = .{ .parser = parser, .dictionary_size = 4096, .properties = .{ .lc = 2, .lp = 1, .pb = 1 }, .match_options = .{ .finder = finder, .nice_len = 16, .depth = 8 } };
            const expected = try xz.encodeAlloc(allocator, &input, options);
            defer allocator.free(expected);
            var encoder = try xz.IncrementalEncoder.initExactSize(allocator, .{ .parser = options.parser, .dictionary_size = options.dictionary_size, .properties = options.properties, .match_options = options.match_options }, input.len);
            defer encoder.deinit();
            const actual = try h.driveEncode(xz.IncrementalEncoder, allocator, &encoder, &input, 1, 1);
            defer allocator.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
            var raw_expected: std.ArrayList(u8) = .empty;
            defer raw_expected.deinit(allocator);
            _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &raw_expected, &input, options.lzma2Options());
            var raw = try xz.RawLzma2IncrementalEncoder.initExactSize(allocator, .{ .parser = parser, .dictionary_size = options.dictionary_size, .properties = options.properties, .match_options = options.match_options }, input.len);
            defer raw.deinit();
            const raw_actual = try h.driveEncode(xz.RawLzma2IncrementalEncoder, allocator, &raw, &input, 1, 1);
            defer allocator.free(raw_actual);
            try std.testing.expectEqualSlices(u8, raw_expected.items, raw_actual);
        }
    }
}

test "XZ encode controls independent blocks final tail reset and poisoned owned move" {
    const input = h.planningPlain();
    var profile: xz.EncodeWorkProfile = .{};
    var options = try xz.IncrementalEncoder.Options.fromPreset(6, false);
    options.dictionary_size = 8192;
    options.block_size = 4096;
    options.match_options.?.profile = &profile;
    const expected = try xz.encodeAlloc(allocator, &input, options.writerOptions());
    defer allocator.free(expected);
    profile.reset();
    var original = try xz.IncrementalEncoder.initExactSize(allocator, options, input.len);
    var transferred = false;
    defer if (!transferred) original.deinit();
    const first = try h.driveEncode(xz.IncrementalEncoder, allocator, &original, &input, 1, 7);
    defer allocator.free(first);
    try std.testing.expectEqualSlices(u8, expected, first);
    try std.testing.expectEqual(@as(usize, 2), original.snapshot().block_count);
    try std.testing.expect(profile.parser_windows >= 2);
    try std.testing.expectEqual(@as(u64, input.len), profile.literals + profile.matched_bytes);
    original.reset();
    profile.reset();
    var moved = original;
    transferred = true;
    original = undefined;
    defer moved.deinit();
    const second = try h.driveEncode(xz.IncrementalEncoder, allocator, &moved, &input, 257, 31);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, expected, second);
}

test "LZMA2 encode controls stored fallback preserves wide history properties and probability reset" {
    const input = try h.mixedPlain(allocator);
    defer allocator.free(input);
    var profile: xz.EncodeWorkProfile = .{};
    const options: xz.RawLzma2EncodeOptions = .{ .dictionary_size = 131072, .parser = .fast, .properties = .{ .lc = 2, .lp = 1, .pb = 1 }, .match_options = .{ .finder = .hc4, .nice_len = 32, .profile = &profile } };
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    _ = try xz.encodeRawLzma2AppendWithOptions(allocator, &expected, input, options);
    const chunks = try h.inspectLzma2Chunks(expected.items);
    try std.testing.expectEqual(@as(usize, 1), chunks.stored);
    try std.testing.expectEqual(@as(usize, 1), chunks.compressed);
    try std.testing.expectEqual(input.len, chunks.uncompressed_size);
    try std.testing.expectEqual(@as(usize, 1), chunks.property_count);
    try std.testing.expectEqual(@as(?u8, 56), chunks.property_byte);
    try std.testing.expectEqual(@as(?u8, 0xc0), chunks.first_compressed_control);
    try std.testing.expect(profile.mf_seed_positions >= 65536);
    var raw = try xz.RawLzma2IncrementalEncoder.initExactSize(allocator, .{ .dictionary_size = options.dictionary_size, .parser = options.parser, .properties = options.properties, .match_options = options.match_options }, input.len);
    var transferred = false;
    defer if (!transferred) raw.deinit();
    const actual = try h.driveEncode(xz.RawLzma2IncrementalEncoder, allocator, &raw, input, 257, 31);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected.items, actual);
    try std.testing.expect(raw.history.items.len > 65535);
    var moved = raw;
    raw = undefined;
    transferred = true;
    defer moved.deinit();
    try std.testing.expectEqual(@as(usize, 0), (try moved.step("", &.{})).progress.output_written);
    var decoder = try xz.RawLzma2IncrementalDecoder.init(allocator, .{ .dictionary_property = 10, .max_output_len = input.len });
    defer decoder.deinit();
    const decoded = try h.driveEncode(xz.RawLzma2IncrementalDecoder, allocator, &decoder, actual, 1, 31);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "XZ encode controls Into append overlap and invalid options preserve caller output" {
    const input = h.legacyPlain();
    const options: xz.EncodeOptions = .{ .parser = .normal, .match_options = .{ .finder = .bt4, .nice_len = 32 } };
    const expected = try xz.encodeAlloc(allocator, &input, options);
    defer allocator.free(expected);
    var output: [1024]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutputTooSmall, xz.encodeInto(allocator, &input, output[0 .. expected.len - 1], options));
    try h.expectSentinel(&output);
    try std.testing.expectEqual(expected.len, try xz.encodeInto(allocator, &input, &output, options));
    try std.testing.expectEqualSlices(u8, expected, output[0..expected.len]);
    try h.expectSentinel(output[expected.len..]);
    @memcpy(output[0..input.len], &input);
    try std.testing.expectEqual(expected.len, try xz.encodeInto(allocator, output[0..input.len], &output, options));
    try std.testing.expectEqualSlices(u8, expected, output[0..expected.len]);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, &input);
    _ = try xz.encodeAppend(allocator, &appended, appended.items, options);
    try std.testing.expectEqualSlices(u8, &input, appended.items[0..input.len]);
    try std.testing.expectEqualSlices(u8, expected, appended.items[input.len..]);
    appended.clearRetainingCapacity();
    try appended.appendSlice(allocator, "prefix:");
    for ([_]xz.EncodeOptions{
        .{ .dictionary_size = 4095 },
        .{ .dictionary_size = 64 * 1024 * 1024 + 1 },
        .{ .properties = .{ .lc = 4, .lp = 1, .pb = 2 } },
        .{ .parser = .fast, .match_options = .{ .nice_len = 1 } },
        .{ .parser = .normal, .match_options = .{ .nice_len = 274 } },
    }, 0..) |invalid, index| {
        const expected_error = if (index < 2) error.InvalidBlockPlan else error.InvalidLzmaOptions;
        @memset(&output, 0xa5);
        try std.testing.expectError(expected_error, xz.encodeInto(allocator, &input, &output, invalid));
        try h.expectSentinel(&output);
        try std.testing.expectError(expected_error, xz.encodeAppend(allocator, &appended, &input, invalid));
        try std.testing.expectEqualStrings("prefix:", appended.items);
    }
}

test "XZ encode controls exact and below matcher parser memory caps leave caller output intact" {
    const input = h.legacyPlain();
    for ([_]xz.Parser{ .fast, .normal }) |parser| {
        var profile: xz.EncodeWorkProfile = .{};
        var options: xz.EncodeOptions = .{ .parser = parser, .match_options = .{ .finder = if (parser == .fast) .hc4 else .bt4, .nice_len = 32, .profile = &profile } };
        const expected = try xz.encodeAlloc(allocator, &input, options);
        defer allocator.free(expected);
        const peak = profile.peak_working_memory;
        try std.testing.expect(profile.mf_peak_working_memory > 0);
        try std.testing.expect(peak >= profile.mf_peak_working_memory);
        if (parser == .normal) try std.testing.expect(peak > profile.mf_peak_working_memory);
        options.match_options.?.max_working_memory = peak;
        profile.reset();
        const exact = try xz.encodeAlloc(allocator, &input, options);
        defer allocator.free(exact);
        try std.testing.expectEqualSlices(u8, expected, exact);
        try std.testing.expectEqual(peak, profile.peak_working_memory);
        options.match_options.?.max_working_memory = peak - 1;
        var output: [1024]u8 = @splat(0xa5);
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, xz.encodeInto(allocator, &input, &output, options));
        try h.expectSentinel(&output);
        var appended: std.ArrayList(u8) = .empty;
        defer appended.deinit(allocator);
        try appended.appendSlice(allocator, "prefix:");
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, xz.encodeAppend(allocator, &appended, &input, options));
        try std.testing.expectEqualStrings("prefix:", appended.items);
        var raw: std.ArrayList(u8) = .empty;
        defer raw.deinit(allocator);
        try raw.appendSlice(allocator, "prefix:");
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, xz.encodeRawLzma2AppendWithOptions(allocator, &raw, &input, options.lzma2Options()));
        try std.testing.expectEqualStrings("prefix:", raw.items);
    }
}

fn AllocationGraph(comptime parser: xz.Parser, comptime append: bool) type {
    return struct {
        pub fn run(backing: std.mem.Allocator, expected: []const u8) !void {
            const options: xz.EncodeOptions = .{ .parser = parser, .match_options = .{ .finder = if (parser == .fast) .hc4 else .bt4, .nice_len = 16 } };
            if (append) {
                var output: std.ArrayList(u8) = .empty;
                defer output.deinit(backing);
                try output.appendSlice(backing, h.len2_plain);
                _ = xz.encodeAppend(backing, &output, output.items, options) catch |err| {
                    try std.testing.expectEqualStrings(h.len2_plain, output.items);
                    return err;
                };
                try std.testing.expectEqualStrings(h.len2_plain, output.items[0..h.len2_plain.len]);
                try std.testing.expectEqualSlices(u8, expected, output.items[h.len2_plain.len..]);
            } else {
                var output: [256]u8 = @splat(0xa5);
                @memcpy(output[0..h.len2_plain.len], h.len2_plain);
                const original = output;
                const written = xz.encodeInto(backing, output[0..h.len2_plain.len], &output, options) catch |err| {
                    try std.testing.expectEqualSlices(u8, &original, &output);
                    return err;
                };
                try std.testing.expectEqualSlices(u8, expected, output[0..written]);
                try std.testing.expectEqualSlices(u8, original[written..], output[written..]);
            }
        }
    };
}

test "XZ encode controls every allocation failure preserves Into append caller bytes" {
    inline for (.{ xz.Parser.fast, xz.Parser.normal }) |parser| {
        const expected = try xz.encodeAlloc(allocator, h.len2_plain, .{ .parser = parser, .match_options = .{ .finder = if (parser == .fast) .hc4 else .bt4, .nice_len = 16 } });
        defer allocator.free(expected);
        try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(parser, false).run, .{expected});
        try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(parser, true).run, .{expected});
    }
}

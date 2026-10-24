const std = @import("std");
const lzma = @import("../lzma.zig");
const h = @import("encode_controls_helpers.zig");
const allocator = std.testing.allocator;

test "LZMA preset validation matches all twenty independent liblzma 5.8.4 rows" {
    for (h.preset_cases) |expected| {
        const actual = try lzma.resolvePreset(expected.level, expected.extreme);
        try std.testing.expectEqual(expected.dictionary_size, actual.dictionary_size);
        try std.testing.expectEqualStrings(expected.mode, @tagName(actual.mode));
        try std.testing.expectEqualStrings(expected.finder, @tagName(actual.match_options.finder));
        try std.testing.expectEqual(expected.nice_len, actual.match_options.nice_len);
        try std.testing.expectEqual(expected.depth, actual.match_options.depth);
        try std.testing.expectEqual(@as(u4, 3), actual.properties.lc);
        try std.testing.expectEqual(@as(u3, 0), actual.properties.lp);
        try std.testing.expectEqual(@as(u3, 2), actual.properties.pb);
        try std.testing.expectEqual(std.math.maxInt(usize), actual.match_options.max_working_memory);
        try std.testing.expectEqual(@as(?*lzma.EncodeWorkProfile, null), actual.match_options.profile);
    }
    for ([_]u32{ 10, std.math.maxInt(u32) }) |invalid| {
        try std.testing.expectError(error.InvalidLzmaOptions, lzma.resolvePreset(invalid, false));
        try std.testing.expectError(error.InvalidLzmaOptions, lzma.resolvePreset(invalid, true));
    }
}

test "LZMA preset validation nice length hash floor explicit depth and profile reset" {
    for ([_]struct { finder: lzma.MatchFinder, width: u16, depth: u32 }{
        .{ .finder = .hc3, .width = 3, .depth = 4 },
        .{ .finder = .hc4, .width = 4, .depth = 5 },
        .{ .finder = .bt2, .width = 2, .depth = 17 },
        .{ .finder = .bt3, .width = 3, .depth = 17 },
        .{ .finder = .bt4, .width = 4, .depth = 18 },
    }) |sample| {
        var options: lzma.MatchOptions = .{ .finder = sample.finder, .nice_len = 2 };
        try options.validate();
        try std.testing.expectEqual(sample.width, options.effectiveNiceLen());
        try std.testing.expectEqual(sample.depth, options.effectiveDepth());
        options.depth = std.math.maxInt(u32);
        try std.testing.expectEqual(std.math.maxInt(u32), options.effectiveDepth());
        options.nice_len = 273;
        try options.validate();
        try std.testing.expectEqual(@as(u16, 273), options.effectiveNiceLen());
    }
    for ([_]u16{ 0, 1, 274, std.math.maxInt(u16) }) |invalid| {
        try std.testing.expectError(error.InvalidLzmaOptions, (lzma.MatchOptions{ .nice_len = invalid }).validate());
    }
    var profile: lzma.EncodeWorkProfile = .{ .finder = .bt4 };
    inline for (@typeInfo(lzma.EncodeWorkProfile).@"struct".fields) |field| {
        if (@typeInfo(field.type) == .int) @field(profile, field.name) = 1;
    }
    profile.reset();
    try std.testing.expectEqualDeep(lzma.EncodeWorkProfile{}, profile);
}

test "LZMA encode controls preserve pre-controls default greedy and lazy wire bytes" {
    const plain = h.legacyPlain();
    const greedy_wire = h.hexBytes(h.lzma_greedy_hex);
    const lazy_wire = h.hexBytes(h.lzma_lazy_hex);
    const noncanonical_greedy = h.hexBytes(h.lzma_greedy_5000_hex);
    const noncanonical_lazy = h.hexBytes(h.lzma_lazy_5000_hex);
    for ([_]struct { options: lzma.EncodeOptions, expected: []const u8 }{
        .{ .options = .{}, .expected = &greedy_wire },
        .{ .options = .{ .mode = .greedy }, .expected = &greedy_wire },
        .{ .options = .{ .mode = .lazy }, .expected = &lazy_wire },
        .{ .options = .{ .dictionary_size = 5000, .mode = .greedy }, .expected = &noncanonical_greedy },
        .{ .options = .{ .dictionary_size = 5000, .mode = .lazy }, .expected = &noncanonical_lazy },
    }) |sample| {
        const encoded = try lzma.encodeAlloc(allocator, &plain, sample.options);
        defer allocator.free(encoded);
        try std.testing.expectEqualSlices(u8, sample.expected, encoded);
        const decoded = try lzma.decodeAlloc(allocator, encoded);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &plain, decoded);
    }
}

fn expectRoundTrip(input: []const u8, options: lzma.EncodeOptions) ![]u8 {
    const encoded = try lzma.encodeAlloc(allocator, input, options);
    errdefer allocator.free(encoded);
    const decoded = try lzma.decodeAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    return encoded;
}

test "LZMA encode controls all twenty presets encode short content with explicit overrides" {
    const input = "preset round trip: " ++ h.len2_plain;
    for (h.preset_cases) |expected| {
        var options = try lzma.EncodeOptions.fromPreset(expected.level, expected.extreme);
        try std.testing.expectEqual(expected.dictionary_size, options.dictionary_size);
        try std.testing.expectEqualStrings(expected.mode, @tagName(options.mode));
        try std.testing.expectEqualStrings(expected.finder, @tagName(options.match_options.?.finder));
        try std.testing.expectEqual(expected.nice_len, options.match_options.?.nice_len);
        try std.testing.expectEqual(expected.depth, options.match_options.?.depth);
        options.size_mode = .known;
        const encoded = try expectRoundTrip(input, options);
        defer allocator.free(encoded);
        const header = try lzma.parseHeader(encoded);
        try std.testing.expectEqual(expected.dictionary_size, header.dictionary_size);
        try std.testing.expectEqual(@as(?u64, input.len), header.uncompressed_size);
    }
    var overridden = try lzma.EncodeOptions.fromPreset(9, true);
    overridden.dictionary_size = 4096;
    overridden.mode = .fast;
    overridden.properties = .{ .lc = 2, .lp = 1, .pb = 1 };
    overridden.match_options.?.finder = .hc3;
    overridden.match_options.?.nice_len = 2;
    overridden.match_options.?.depth = 1;
    const encoded = try expectRoundTrip(input, overridden);
    defer allocator.free(encoded);
    const header = try lzma.parseHeader(encoded);
    try std.testing.expectEqual(@as(u32, 4096), header.dictionary_size);
    try std.testing.expectEqual(@as(u8, 56), encoded[0]);
}

test "LZMA encode controls all five finders execute fast normal short matches and short rep0" {
    const input = h.legacyPlain();
    for ([_]lzma.EncodeMode{ .fast, .normal }) |mode| {
        for ([_]lzma.MatchFinder{ .hc3, .hc4, .bt2, .bt3, .bt4 }) |finder| {
            var profile: lzma.EncodeWorkProfile = .{};
            const options: lzma.EncodeOptions = .{
                .mode = mode,
                .dictionary_size = 4096,
                .match_options = .{ .finder = finder, .nice_len = 2, .depth = 1, .profile = &profile },
            };
            const encoded = try expectRoundTrip(&input, options);
            defer allocator.free(encoded);
            try std.testing.expectEqual(finder, profile.finder);
            try std.testing.expectEqual(finder.hashBytes(), profile.effective_nice_len);
            try std.testing.expectEqual(@as(u32, 1), profile.effective_depth);
            try std.testing.expect(profile.mf_hash_probes > 0 and profile.mf_candidate_probes > 0);
            try std.testing.expect(profile.mf_compared_bytes > 0 and profile.mf_matches > 0);
            try std.testing.expect(profile.matches > 0);
            try std.testing.expectEqual(@as(u64, input.len), profile.literals + profile.matched_bytes);
            if (finder.isBinaryTree()) {
                try std.testing.expect(profile.mf_tree_steps > 0);
                try std.testing.expectEqual(@as(u64, 0), profile.mf_chain_steps);
            } else {
                try std.testing.expect(profile.mf_chain_steps > 0);
                try std.testing.expectEqual(@as(u64, 0), profile.mf_tree_steps);
            }
            if (mode == .normal) try std.testing.expect(profile.price_evaluations > 0);
            var unprofiled = options;
            unprofiled.match_options.?.profile = null;
            const repeated = try lzma.encodeAlloc(allocator, &input, unprofiled);
            defer allocator.free(repeated);
            try std.testing.expectEqualSlices(u8, encoded, repeated);

            profile.reset();
            const short = try expectRoundTrip(h.len2_plain, options);
            defer allocator.free(short);
            try std.testing.expect(profile.matches > 0);
            try std.testing.expectEqual(@as(u64, 0), profile.short_reps);
            try std.testing.expectEqual(profile.matches * 2, profile.matched_bytes);
            profile.reset();
            const rep = try expectRoundTrip(h.short_rep_plain, options);
            defer allocator.free(rep);
            try std.testing.expect(profile.short_reps > 0);
            try std.testing.expect(profile.repeat_matches >= profile.short_reps);
        }
    }
}

test "LZMA encode controls zero and short tails allow literal mode without matcher heap" {
    for ([_][]const u8{ "", "x", "xy", "xyz", "xyxy", h.short_rep_plain }) |input| {
        for ([_]lzma.EncodeMode{ .fast, .normal, .literal_only }) |mode| {
            const encoded = try expectRoundTrip(input, .{ .mode = mode, .match_options = .{ .finder = .bt4, .nice_len = 2, .max_working_memory = if (mode == .literal_only) 0 else std.math.maxInt(usize) } });
            defer allocator.free(encoded);
        }
    }
}

test "LZMA encode controls chunk1 zero output and reused input preserve all finder parser wires" {
    const input = h.legacyPlain();
    for ([_]lzma.EncodeMode{ .fast, .normal }) |mode| {
        for ([_]lzma.MatchFinder{ .hc3, .hc4, .bt2, .bt3, .bt4 }) |finder| {
            const options: lzma.EncodeOptions = .{ .mode = mode, .dictionary_size = 4096, .properties = .{ .lc = 2, .lp = 1, .pb = 1 }, .match_options = .{ .finder = finder, .nice_len = 16, .depth = 8 } };
            const expected = try lzma.encodeAlloc(allocator, &input, options);
            defer allocator.free(expected);
            var encoder = try lzma.IncrementalEncoder.initExactSize(allocator, .{ .mode = options.mode, .dictionary_size = options.dictionary_size, .properties = options.properties, .match_options = options.match_options }, input.len);
            defer encoder.deinit();
            const actual = try h.driveEncode(lzma.IncrementalEncoder, allocator, &encoder, &input, 1, 1);
            defer allocator.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
            try std.testing.expectEqual(input.len, encoder.snapshot().input_encoded);
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().buffered_input);
        }
    }
}

test "LZMA encode controls complete normal planning window final tail reset and poisoned owner move" {
    const input = h.planningPlain();
    var profile: lzma.EncodeWorkProfile = .{};
    var options = try lzma.IncrementalEncoder.Options.fromPreset(6, false);
    options.dictionary_size = 8192;
    options.size_mode = .known;
    options.match_options.?.profile = &profile;
    const expected = try lzma.encodeAlloc(allocator, &input, .{ .dictionary_size = options.dictionary_size, .mode = options.mode, .size_mode = options.size_mode, .match_options = options.match_options });
    defer allocator.free(expected);
    profile.reset();
    var encoder = try lzma.IncrementalEncoder.initExactSize(allocator, options, input.len);
    var transferred = false;
    defer if (!transferred) encoder.deinit();
    const first = try h.driveEncode(lzma.IncrementalEncoder, allocator, &encoder, &input, 1, 7);
    defer allocator.free(first);
    try std.testing.expectEqualSlices(u8, expected, first);
    try std.testing.expect(profile.parser_windows >= 2);
    try std.testing.expect(profile.price_evaluations >= 4096);
    try std.testing.expectEqual(@as(u64, input.len), profile.literals + profile.matched_bytes);
    encoder.reset();
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().input_read);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().history_bytes);
    profile.reset();
    var moved = encoder;
    transferred = true;
    encoder = undefined;
    defer moved.deinit();
    const second = try h.driveEncode(lzma.IncrementalEncoder, allocator, &moved, &input, 257, 31);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, expected, second);
}

test "LZMA encode controls append Into overlap and invalid settings are transactional" {
    const input = h.legacyPlain();
    const options: lzma.EncodeOptions = .{ .mode = .normal, .match_options = .{ .finder = .bt4, .nice_len = 32 } };
    const expected = try lzma.encodeAlloc(allocator, &input, options);
    defer allocator.free(expected);
    var output: [1024]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutputTooSmall, lzma.encodeInto(allocator, &input, output[0 .. expected.len - 1], options));
    try h.expectSentinel(&output);
    try std.testing.expectEqual(expected.len, try lzma.encodeInto(allocator, &input, &output, options));
    try std.testing.expectEqualSlices(u8, expected, output[0..expected.len]);
    try h.expectSentinel(output[expected.len..]);
    @memset(&output, 0xa5);
    @memcpy(output[0..input.len], &input);
    try std.testing.expectEqual(expected.len, try lzma.encodeInto(allocator, output[0..input.len], &output, options));
    try std.testing.expectEqualSlices(u8, expected, output[0..expected.len]);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, &input);
    try std.testing.expectEqual(expected.len, try lzma.encodeAppend(allocator, &appended, appended.items, options));
    try std.testing.expectEqualSlices(u8, &input, appended.items[0..input.len]);
    try std.testing.expectEqualSlices(u8, expected, appended.items[input.len..]);
    appended.clearRetainingCapacity();
    try appended.appendSlice(allocator, "prefix:");
    for ([_]lzma.EncodeOptions{
        .{ .dictionary_size = 4095 },
        .{ .dictionary_size = @intCast(lzma.max_encode_dictionary_size + 1) },
        .{ .properties = .{ .lc = 4, .lp = 1, .pb = 2 } },
        .{ .mode = .fast, .match_options = .{ .nice_len = 1 } },
        .{ .mode = .normal, .match_options = .{ .nice_len = 274 } },
    }) |invalid| {
        @memset(&output, 0xa5);
        try std.testing.expectError(error.InvalidLzmaOptions, lzma.encodeInto(allocator, &input, &output, invalid));
        try h.expectSentinel(&output);
        try std.testing.expectError(error.InvalidLzmaOptions, lzma.encodeAppend(allocator, &appended, &input, invalid));
        try std.testing.expectEqualStrings("prefix:", appended.items);
    }
}

test "LZMA encode controls exact and below matcher parser working caps preserve output" {
    const input = h.legacyPlain();
    for ([_]lzma.EncodeMode{ .fast, .normal }) |mode| {
        var profile: lzma.EncodeWorkProfile = .{};
        var options: lzma.EncodeOptions = .{ .mode = mode, .dictionary_size = 4096, .match_options = .{ .finder = if (mode == .fast) .hc4 else .bt4, .nice_len = 32, .profile = &profile } };
        const expected = try lzma.encodeAlloc(allocator, &input, options);
        defer allocator.free(expected);
        const peak = profile.peak_working_memory;
        try std.testing.expect(profile.mf_peak_working_memory > 0);
        try std.testing.expect(peak >= profile.mf_peak_working_memory);
        if (mode == .normal) try std.testing.expect(peak > profile.mf_peak_working_memory);
        options.match_options.?.max_working_memory = peak;
        profile.reset();
        const exact = try lzma.encodeAlloc(allocator, &input, options);
        defer allocator.free(exact);
        try std.testing.expectEqualSlices(u8, expected, exact);
        try std.testing.expectEqual(peak, profile.peak_working_memory);
        options.match_options.?.max_working_memory = peak - 1;
        var output: [1024]u8 = @splat(0xa5);
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, lzma.encodeInto(allocator, &input, &output, options));
        try h.expectSentinel(&output);
        var appended: std.ArrayList(u8) = .empty;
        defer appended.deinit(allocator);
        try appended.appendSlice(allocator, "prefix:");
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, lzma.encodeAppend(allocator, &appended, &input, options));
        try std.testing.expectEqualStrings("prefix:", appended.items);
    }
}

fn AllocationGraph(comptime mode: lzma.EncodeMode, comptime append: bool) type {
    return struct {
        pub fn run(backing: std.mem.Allocator, expected: []const u8) !void {
            const options: lzma.EncodeOptions = .{ .mode = mode, .match_options = .{ .finder = if (mode == .fast) .hc4 else .bt4, .nice_len = 16 } };
            if (append) {
                var output: std.ArrayList(u8) = .empty;
                defer output.deinit(backing);
                try output.appendSlice(backing, h.len2_plain);
                _ = lzma.encodeAppend(backing, &output, output.items, options) catch |err| {
                    try std.testing.expectEqualStrings(h.len2_plain, output.items);
                    return err;
                };
                try std.testing.expectEqualStrings(h.len2_plain, output.items[0..h.len2_plain.len]);
                try std.testing.expectEqualSlices(u8, expected, output.items[h.len2_plain.len..]);
            } else {
                var output: [256]u8 = @splat(0xa5);
                @memcpy(output[0..h.len2_plain.len], h.len2_plain);
                const original = output;
                const written = lzma.encodeInto(backing, output[0..h.len2_plain.len], &output, options) catch |err| {
                    try std.testing.expectEqualSlices(u8, &original, &output);
                    return err;
                };
                try std.testing.expectEqualSlices(u8, expected, output[0..written]);
                try std.testing.expectEqualSlices(u8, original[written..], output[written..]);
            }
        }
    };
}

test "LZMA encode controls every allocation failure preserves Into append caller bytes" {
    inline for (.{ lzma.EncodeMode.fast, lzma.EncodeMode.normal }) |mode| {
        const expected = try lzma.encodeAlloc(allocator, h.len2_plain, .{ .mode = mode, .match_options = .{ .finder = if (mode == .fast) .hc4 else .bt4, .nice_len = 16 } });
        defer allocator.free(expected);
        try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(mode, false).run, .{expected});
        try std.testing.checkAllAllocationFailures(allocator, AllocationGraph(mode, true).run, .{expected});
    }
}

test "LZMA encode controls wide history above u16 improves size and persists in streaming" {
    const input = try h.widePlain(allocator);
    defer allocator.free(input);
    for ([_]lzma.EncodeMode{ .fast, .normal }) |mode| {
        const options: lzma.EncodeOptions = .{ .dictionary_size = 131072, .mode = mode, .match_options = .{ .finder = if (mode == .fast) .hc4 else .bt4, .nice_len = 32, .depth = 8 } };
        const wide = try expectRoundTrip(input, options);
        defer allocator.free(wide);
        var limited = options;
        limited.dictionary_size = 65536;
        const narrow = try expectRoundTrip(input, limited);
        defer allocator.free(narrow);
        try std.testing.expect(wide.len + 2048 < narrow.len);
        var encoder = try lzma.IncrementalEncoder.initExactSize(allocator, .{ .dictionary_size = options.dictionary_size, .mode = options.mode, .match_options = options.match_options }, input.len);
        defer encoder.deinit();
        const streamed = try h.driveEncode(lzma.IncrementalEncoder, allocator, &encoder, input, 257, 31);
        defer allocator.free(streamed);
        try std.testing.expectEqualSlices(u8, wide, streamed);
        try std.testing.expect(encoder.snapshot().history_bytes > 65535);
    }
}

test "LZMA encode controls profile saturation preserves bytes and default buffers validate" {
    const options: lzma.EncodeOptions = .{ .mode = .normal, .match_options = .{ .finder = .bt4, .nice_len = 16 } };
    const expected = try lzma.encodeAlloc(allocator, h.len2_plain, options);
    defer allocator.free(expected);
    var profile: lzma.EncodeWorkProfile = .{
        .mf_positions = std.math.maxInt(u64),
        .mf_candidate_probes = std.math.maxInt(u64),
        .matches = std.math.maxInt(u64),
        .matched_bytes = std.math.maxInt(u64),
        .literals = std.math.maxInt(u64),
        .price_evaluations = std.math.maxInt(u64),
        .peak_working_memory = std.math.maxInt(usize),
        .mf_peak_working_memory = std.math.maxInt(usize),
    };
    var profiled = options;
    profiled.match_options.?.profile = &profile;
    const actual = try lzma.encodeAlloc(allocator, h.len2_plain, profiled);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
    try std.testing.expectEqual(std.math.maxInt(u64), profile.mf_positions);
    try std.testing.expectEqual(std.math.maxInt(u64), profile.matches);
    try std.testing.expectEqual(std.math.maxInt(u64), profile.price_evaluations);
    for ([_]lzma.EncodeMode{ .fast, .normal }) |mode| {
        try (lzma.IncrementalEncoder.Options{ .mode = mode }).validate();
        try std.testing.expectError(error.InvalidLzmaOptions, (lzma.IncrementalEncoder.Options{ .mode = mode, .input_buffer_len = 4368 }).validate());
    }
}

test "LZMA encode controls empty calls update latest profile settings without additional work" {
    var profile: lzma.EncodeWorkProfile = .{};
    const first = try lzma.encodeAlloc(allocator, h.len2_plain, .{ .mode = .normal, .match_options = .{ .finder = .bt4, .nice_len = 64, .profile = &profile } });
    defer allocator.free(first);
    const previous = profile;
    const options: lzma.EncodeOptions = .{ .mode = .fast, .match_options = .{ .finder = .bt2, .nice_len = 2, .depth = 3, .profile = &profile } };
    try options.validate();
    try std.testing.expectEqualDeep(previous, profile);
    const empty = try lzma.encodeAlloc(allocator, "", options);
    defer allocator.free(empty);
    var expected = previous;
    expected.finder = .bt2;
    expected.effective_nice_len = 2;
    expected.effective_depth = 3;
    try std.testing.expectEqualDeep(expected, profile);
    const decoded = try lzma.decodeAlloc(allocator, empty);
    defer allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);
    var encoder = try lzma.IncrementalEncoder.initWithOptions(allocator, .{ .mode = .normal, .match_options = .{ .finder = .hc3, .nice_len = 2, .depth = 7, .profile = &profile } });
    defer encoder.deinit();
    const streamed = try h.driveEncode(lzma.IncrementalEncoder, allocator, &encoder, "", 1, 1);
    defer allocator.free(streamed);
    expected.finder = .hc3;
    expected.effective_nice_len = 3;
    expected.effective_depth = 7;
    try std.testing.expectEqualDeep(expected, profile);
    const streamed_decoded = try lzma.decodeAlloc(allocator, streamed);
    defer allocator.free(streamed_decoded);
    try std.testing.expectEqual(@as(usize, 0), streamed_decoded.len);
}

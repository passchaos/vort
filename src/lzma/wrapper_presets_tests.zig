const std = @import("std");
const writer = @import("writer.zig");
const micro = @import("micro_writer.zig");
const limited = @import("micro_limited_writer.zig");
const incremental = @import("incremental_encoder.zig");
const decoder = @import("decoder.zig");
const settings = @import("encode_options.zig");
const fixtures = @import("encode_controls_helpers.zig");
const allocator = std.testing.allocator;

fn stream(options: incremental.Encoder.Options, input: []const u8, input_chunk: usize, output_chunk: usize) ![]u8 {
    var encoder = if (options.size_mode == .known) try incremental.Encoder.initExactSize(allocator, options, input.len) else try incremental.Encoder.initWithOptions(allocator, options);
    defer encoder.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var scratch: [257]u8 = undefined;
    var accepted: usize = 0;
    while (accepted < input.len) {
        const end = @min(input.len, accepted + input_chunk);
        const step = try encoder.step(input[accepted..end], scratch[0..output_chunk]);
        accepted += step.progress.input_read;
        try output.appendSlice(allocator, scratch[0..step.progress.output_written]);
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
        try std.testing.expect(encoder.snapshot().buffered_input <= options.input_buffer_len);
        try std.testing.expect(encoder.snapshot().history_bytes <= options.dictionary_size);
    }
    encoder.finish();
    while (true) {
        const step = try encoder.step(&.{}, scratch[0..output_chunk]);
        try output.appendSlice(allocator, scratch[0..step.progress.output_written]);
        if (step.status == .done) break;
        try std.testing.expect(step.progress.output_written != 0);
    }
    try std.testing.expectEqual(input.len, encoder.snapshot().input_encoded);
    return output.toOwnedSlice(allocator);
}
fn sentinel(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

test "LZMA wrapper presets concrete settings validate and encode every standard extreme preset" {
    const input = "preset settings exercise literal and repeated bytes";
    for (0..10) |level| inline for (.{ false, true }) |extreme| {
        const options = try writer.EncodeOptions.fromPreset(@intCast(level), extreme);
        try options.validate();
        try (try writer.ZipEncodeOptions.fromPreset(@intCast(level), extreme)).validate();
        const micro_options = try micro.Options.fromPreset(@intCast(level), extreme);
        try micro_options.validate();
        try (try incremental.Encoder.Options.fromPreset(@intCast(level), extreme)).validate();
        _ = try limited.Options.fromPreset(@intCast(level), extreme);
        const frame = try writer.encodeAlloc(allocator, input, options);
        defer allocator.free(frame);
        const decoded = try decoder.decodeAlloc(allocator, frame);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        const compact = try micro.encodeAlloc(allocator, input, micro_options);
        defer allocator.free(compact);
        const micro_decoded = try decoder.decodeMicroAllocExactSize(allocator, compact, input.len, micro_options.dictionary_size);
        defer allocator.free(micro_decoded);
        try std.testing.expectEqualSlices(u8, input, micro_decoded);
    };
}

test "LZMA wrapper presets fixed parsing windows preserve byte wire for chunk one output one" {
    const input = "streamable modern LZMA parser literal context and matching\n" ** 170;
    inline for (.{ @as(u32, 0), @as(u32, 6) }) |level| inline for (.{ writer.SizeMode.known, writer.SizeMode.end_marker }) |size_mode| {
        var options = try writer.EncodeOptions.fromPreset(level, false);
        options.dictionary_size = 128 * 1024;
        options.size_mode = size_mode;
        const expected = try writer.encodeAlloc(allocator, input, options);
        defer allocator.free(expected);
        var streaming = try incremental.Encoder.Options.fromPreset(level, false);
        streaming.dictionary_size = options.dictionary_size;
        streaming.size_mode = size_mode;
        streaming.input_buffer_len = 4369;
        const bytes = try stream(streaming, input, 1, 1);
        defer allocator.free(bytes);
        try std.testing.expectEqualSlices(u8, expected, bytes);
        streaming.input_buffer_len = 16 * 1024;
        const wide = try stream(streaming, input, input.len, 257);
        defer allocator.free(wide);
        try std.testing.expectEqualSlices(u8, expected, wide);
    };
}

test "LZMA wrapper presets custom wide dictionary advertises canonical Alone shape and exact ZIP size" {
    const input = "custom wide dictionary and stable modern greedy parsing\n" ** 180;
    const options: writer.EncodeOptions = .{ .dictionary_size = 70000, .mode = .greedy, .size_mode = .known };
    const frame = try writer.encodeAlloc(allocator, input, options);
    defer allocator.free(frame);
    try std.testing.expectEqual(@as(u32, 98304), (try decoder.parseHeader(frame)).dictionary_size);
    const decoded = try decoder.decodeAlloc(allocator, frame);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    const streamed = try stream(.{ .dictionary_size = 70000, .mode = .greedy, .size_mode = .known, .input_buffer_len = 4369 }, input, 1, 1);
    defer allocator.free(streamed);
    try std.testing.expectEqualSlices(u8, frame, streamed);
    const zip = try writer.encodeZipPayloadAlloc(allocator, input, .{ .dictionary_size = 70000 });
    defer allocator.free(zip);
    try std.testing.expectEqual(@as(u32, 70000), std.mem.readInt(u32, zip[5..9], .little));
    const zip_decoded = try decoder.decodeZipPayloadAllocLimited(allocator, zip, input.len, 70000, true);
    defer allocator.free(zip_decoded);
    try std.testing.expectEqualSlices(u8, input, zip_decoded);
}

test "LZMA wrapper presets Micro full bounded and aligned output use the same modern planner" {
    const input = "modern MicroLZMA bounded prefix alignment literals and repeats\n" ** 150;
    inline for (.{ @as(u32, 0), @as(u32, 6) }) |level| {
        var options = try micro.Options.fromPreset(level, false);
        options.dictionary_size = 128 * 1024;
        const encoded = try micro.encodeAlloc(allocator, input, options);
        defer allocator.free(encoded);
        var full = try micro.encodeDestSizeAlloc(allocator, input, encoded.len + 16, options);
        defer full.deinit(allocator);
        try std.testing.expectEqual(input.len, full.consumed);
        try std.testing.expectEqualSlices(u8, encoded, full.bytes);
        var aligned = try micro.encodeAlignedDestSizeAlloc(allocator, input, 64, 32, options);
        defer aligned.deinit(allocator);
        try std.testing.expect(aligned.bytes.len <= 64);
        try std.testing.expect(aligned.consumed == input.len or aligned.consumed % 32 == 0);
        const decoded = try decoder.decodeMicroAllocExactSize(allocator, aligned.bytes, aligned.consumed, options.dictionary_size);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input[0..aligned.consumed], decoded);
    }
}

test "LZMA wrapper presets invalid scalar settings are rejected before allocation or caller mutation" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidLzmaOptions, writer.EncodeOptions.fromPreset(10, false));
    try std.testing.expectError(error.InvalidLzmaOptions, micro.Options.fromPreset(std.math.maxInt(u32), true));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.appendSlice(allocator, "prefix");
    const invalid = [_]writer.EncodeOptions{
        .{ .dictionary_size = 4095 },                            .{ .dictionary_size = @intCast(@import("encode_options.zig").max_dictionary_size + 1) },
        .{ .mode = .fast, .match_options = .{ .nice_len = 1 } }, .{ .mode = .normal, .match_options = .{ .nice_len = 274 } },
    };
    var buffer: [128]u8 = @splat(0xa5);
    for (invalid) |options| {
        try std.testing.expectError(error.InvalidLzmaOptions, writer.encodeAppend(failing.allocator(), &out, "input", options));
        try std.testing.expectEqualStrings("prefix", out.items);
        try std.testing.expectError(error.InvalidLzmaOptions, writer.encodeInto(failing.allocator(), "input", &buffer, options));
        try sentinel(&buffer);
    }
    try std.testing.expectError(error.InvalidLzmaOptions, incremental.Encoder.initWithOptions(failing.allocator(), .{ .mode = .normal, .input_buffer_len = 4368 }));
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
}

const AllocationCase = struct {
    pub fn run(gpa: std.mem.Allocator) !void {
        var options = try writer.EncodeOptions.fromPreset(0, false);
        options.dictionary_size = 128 * 1024;
        var output: [512]u8 = @splat(0xa5);
        _ = writer.encodeInto(gpa, "bounded allocation graph and caller atomic output\n" ** 3, &output, options) catch |err| {
            try sentinel(&output);
            return err;
        };
    }
};
test "LZMA wrapper presets owned output allocation failures preserve caller and release all buffers" {
    try std.testing.checkAllAllocationFailures(allocator, AllocationCase.run, .{});
}

test "LZMA wrapper presets explicit greedy lazy controls preserve incremental bytes" {
    const input = "abcabcyabcabcxabcyabcabcx" ** 12;
    inline for (.{ settings.Mode.greedy, settings.Mode.lazy }) |mode| {
        const options: writer.EncodeOptions = .{ .mode = mode, .dictionary_size = 4096, .size_mode = .known, .match_options = .{ .finder = .bt2, .nice_len = 2, .depth = 1 } };
        const expected = try writer.encodeAlloc(allocator, input, options);
        defer allocator.free(expected);
        const actual = try stream(.{ .mode = mode, .dictionary_size = options.dictionary_size, .size_mode = .known, .match_options = options.match_options, .input_buffer_len = 4369 }, input, 1, 1);
        defer allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
        const decoded = try decoder.decodeAlloc(allocator, actual);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "LZMA wrapper presets Micro modern short reps remain valid at every aligned tiny capacity" {
    const input = "abcabcyabcabcxabcyabcabcx" ** 3;
    inline for (.{ settings.Mode.fast, settings.Mode.normal }) |mode| {
        var profile: settings.EncodeWorkProfile = .{};
        const options: micro.Options = .{ .mode = mode, .dictionary_size = 4096, .properties = .{ .lc = 0, .lp = 4, .pb = 0 }, .match_options = .{ .finder = .bt2, .nice_len = 2, .depth = 1, .profile = &profile } };
        for (6..33) |capacity| for ([_]usize{ 1, 2, 3, 16 }) |alignment| {
            profile.reset();
            var encoded = try micro.encodeAlignedDestSizeAlloc(allocator, input, capacity, alignment, options);
            defer encoded.deinit(allocator);
            try std.testing.expect(encoded.bytes.len <= capacity);
            try std.testing.expect(encoded.consumed == input.len or encoded.consumed % alignment == 0);
            const decoded = try decoder.decodeMicroAllocExactSize(allocator, encoded.bytes, encoded.consumed, options.dictionary_size);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, input[0..encoded.consumed], decoded);
            try std.testing.expect(profile.literals + profile.matched_bytes >= encoded.consumed);
            try std.testing.expect(profile.repeat_matches <= profile.matches);
            try std.testing.expect(profile.short_reps <= profile.repeat_matches);
        };
    }
}

test "LZMA wrapper presets incremental failed planning or pending cap can retry the same buffered prefix" {
    var input: [4369]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x938d1f0a2b4c6e8f);
    prng.random().bytes(&input);
    inline for (.{ false, true }) |pending_failure| {
        var profile: settings.EncodeWorkProfile = .{};
        const options: incremental.Encoder.Options = .{ .mode = .fast, .dictionary_size = 4096, .size_mode = .known, .input_buffer_len = 4369, .max_pending_output_len = if (pending_failure) 13 else 1024 * 1024, .match_options = .{ .finder = .hc3, .nice_len = 16, .depth = 1, .max_working_memory = if (pending_failure) std.math.maxInt(usize) else 0, .profile = &profile } };
        var encoder = try incremental.Encoder.initExactSize(allocator, options, input.len);
        defer encoder.deinit();
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(allocator);
        var scratch: [257]u8 = undefined;
        const header = try encoder.step(&.{}, &scratch);
        try output.appendSlice(allocator, scratch[0..header.progress.output_written]);
        try std.testing.expectEqual(@as(usize, 13), output.items.len);
        const model_before = encoder.model;
        const range_before = .{ encoder.range_low, encoder.range_value, encoder.range_cache, encoder.range_cache_size };
        try std.testing.expectError(if (pending_failure) error.OutputLimitExceeded else error.WorkingMemoryLimitExceeded, encoder.step(&input, &scratch));
        try std.testing.expectEqualDeep(model_before, encoder.model);
        try std.testing.expectEqualDeep(range_before, .{ encoder.range_low, encoder.range_value, encoder.range_cache, encoder.range_cache_size });
        const failed = encoder.snapshot();
        try std.testing.expectEqual(input.len, failed.input_read);
        try std.testing.expectEqual(input.len, failed.buffered_input);
        try std.testing.expectEqual(@as(usize, 0), failed.input_encoded);
        try std.testing.expectEqual(@as(usize, 0), failed.pending_output);
        try std.testing.expectEqual(@as(usize, 0), failed.history_bytes);
        try std.testing.expectEqual(@as(usize, 0), failed.literals + failed.matched_bytes);
        const attempted_bytes = profile.literals + profile.matched_bytes;
        if (pending_failure)
            try std.testing.expect(attempted_bytes > 0 and attempted_bytes <= input.len)
        else
            try std.testing.expectEqual(@as(u64, 0), attempted_bytes);

        encoder.options.max_pending_output_len = 1024 * 1024;
        encoder.options.match_options.?.max_working_memory = std.math.maxInt(usize);
        encoder.finish();
        while (true) {
            const step = try encoder.step(&.{}, &scratch);
            try output.appendSlice(allocator, scratch[0..step.progress.output_written]);
            if (step.status == .done) break;
            try std.testing.expect(step.progress.output_written != 0);
        }
        const expected = try writer.encodeAlloc(allocator, &input, .{ .mode = options.mode, .dictionary_size = options.dictionary_size, .size_mode = options.size_mode, .match_options = .{ .finder = .hc3, .nice_len = 16, .depth = 1 } });
        defer allocator.free(expected);
        try std.testing.expectEqualSlices(u8, expected, output.items);
        try std.testing.expectEqual(@as(u64, input.len) + attempted_bytes, profile.literals + profile.matched_bytes);
    }
}

test "LZMA wrapper presets legacy narrow noncanonical dictionary retains golden header and payload" {
    const input = fixtures.legacyPlain();
    inline for (.{ settings.Mode.greedy, settings.Mode.lazy }) |mode| {
        // The frozen pre-controls fixture fits completely within either
        // dictionary. Only its explicit historical dictionary header differs.
        var expected = fixtures.hexBytes(if (mode == .greedy) fixtures.lzma_greedy_hex else fixtures.lzma_lazy_hex);
        std.mem.writeInt(u32, expected[1..5], 5000, .little);
        const encoded = try writer.encodeAlloc(allocator, &input, .{ .mode = mode, .dictionary_size = 5000 });
        defer allocator.free(encoded);
        try std.testing.expectEqualSlices(u8, &expected, encoded);
        if (mode == .greedy) {
            const streamed = try stream(.{ .mode = mode, .dictionary_size = 5000 }, &input, 1, 1);
            defer allocator.free(streamed);
            try std.testing.expectEqualSlices(u8, &expected, streamed);
        }
    }
    const literal = try writer.encodeAlloc(allocator, "literal legacy header", .{ .mode = .literal_only, .dictionary_size = 5000 });
    defer allocator.free(literal);
    try std.testing.expectEqual(@as(u32, 5000), std.mem.readInt(u32, literal[1..5], .little));
    inline for (.{ settings.Mode.fast, settings.Mode.normal, settings.Mode.greedy, settings.Mode.lazy, settings.Mode.literal_only }) |mode| {
        const modern = try writer.encodeAlloc(allocator, "modern canonical header", .{ .mode = mode, .dictionary_size = 5000, .match_options = .{} });
        defer allocator.free(modern);
        try std.testing.expectEqual(@as(u32, 6144), std.mem.readInt(u32, modern[1..5], .little));
    }
}

test "LZMA wrapper presets empty bounded constructor step reset record only effective metadata" {
    var profile: settings.EncodeWorkProfile = .{ .mf_positions = 7, .matches = 3, .literals = 13, .matched_bytes = 5, .price_evaluations = 11, .peak_working_memory = 24, .finder = .hc4, .effective_nice_len = 99, .effective_depth = 55 };
    var expected = profile;
    const compact_options: micro.Options = .{ .mode = .fast, .dictionary_size = 4096, .match_options = .{ .finder = .bt2, .nice_len = 2, .profile = &profile } };
    try compact_options.validate();
    try std.testing.expectEqualDeep(expected, profile);
    var invalid_compact = compact_options;
    invalid_compact.match_options.?.nice_len = 1;
    try std.testing.expectError(error.InvalidLzmaOptions, invalid_compact.validate());
    try std.testing.expectEqualDeep(expected, profile);
    var empty = try micro.encodeAlignedDestSizeAlloc(allocator, "", 6, 16, compact_options);
    defer empty.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), empty.consumed);
    expected.finder = .bt2;
    expected.effective_nice_len = 2;
    expected.effective_depth = 17;
    try std.testing.expectEqualDeep(expected, profile);

    const options: incremental.Encoder.Options = .{ .mode = .normal, .dictionary_size = 4096, .size_mode = .known, .match_options = .{ .finder = .bt4, .nice_len = 2, .profile = &profile } };
    try options.validate();
    try std.testing.expectEqualDeep(expected, profile);
    var invalid = options;
    invalid.input_buffer_len = 4368;
    try std.testing.expectError(error.InvalidLzmaOptions, invalid.validate());
    try std.testing.expectEqualDeep(expected, profile);
    var encoder = try incremental.Encoder.initExactSize(allocator, options, 0);
    defer encoder.deinit();
    expected.finder = .bt4;
    expected.effective_nice_len = 4;
    expected.effective_depth = 18;
    try std.testing.expectEqualDeep(expected, profile);

    const other_match: settings.MatchOptions = .{ .finder = .hc3, .nice_len = 2, .depth = 123, .profile = &profile };
    other_match.recordEffectiveSettings();
    const blocked = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqualDeep(expected, profile);
    other_match.recordEffectiveSettings();
    encoder.reset();
    try std.testing.expectEqualDeep(expected, profile);
    encoder.finish();
    var scratch: [32]u8 = undefined;
    try std.testing.expectEqual(.done, (try encoder.step("", &scratch)).status);
    try std.testing.expectEqualDeep(expected, profile);

    var other = try incremental.Encoder.initWithOptions(allocator, .{ .mode = .literal_only, .match_options = other_match });
    defer other.deinit();
    try std.testing.expectEqual(settings.MatchFinder.hc3, profile.finder);
    try std.testing.expectEqual(@as(u16, 3), profile.effective_nice_len);
    try std.testing.expectEqual(@as(u32, 123), profile.effective_depth);
    try std.testing.expectEqual(.done, (try encoder.step("", &.{})).status);
    try std.testing.expectEqualDeep(expected, profile);
}

test "LZMA wrapper presets header and range finish pending limits preserve retry wire" {
    inline for (.{ settings.Mode.literal_only, settings.Mode.greedy, settings.Mode.fast, settings.Mode.normal }) |mode| inline for (.{ writer.SizeMode.known, writer.SizeMode.end_marker }) |size_mode| {
        const options: incremental.Encoder.Options = .{ .mode = mode, .dictionary_size = 4096, .size_mode = size_mode, .max_pending_output_len = 12, .match_options = if (mode == .fast or mode == .normal) .{ .finder = .bt2, .nice_len = 2 } else null };
        const expected = try writer.encodeAlloc(allocator, "", .{ .mode = options.mode, .dictionary_size = options.dictionary_size, .size_mode = size_mode, .match_options = options.match_options });
        defer allocator.free(expected);
        var encoder = if (size_mode == .known) try incremental.Encoder.initExactSize(allocator, options, 0) else try incremental.Encoder.initWithOptions(allocator, options);
        defer encoder.deinit();
        var scratch: [64]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutputLimitExceeded, encoder.step("", &scratch));
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().output_written);
        try std.testing.expect(!encoder.header_written);
        try sentinel(&scratch);

        encoder.options.max_pending_output_len = 64;
        const header = try encoder.step("", &scratch);
        try std.testing.expectEqual(@as(usize, 13), header.progress.output_written);
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(allocator);
        try output.appendSlice(allocator, scratch[0..header.progress.output_written]);
        @memset(&scratch, 0xa5);
        const model_before = encoder.model;
        const range_before = .{ encoder.range_low, encoder.range_value, encoder.range_cache, encoder.range_cache_size };
        const stats_before = encoder.stats;
        encoder.options.max_pending_output_len = 4;
        encoder.finish();
        try std.testing.expectError(error.OutputLimitExceeded, encoder.step("", &scratch));
        try std.testing.expectEqualDeep(model_before, encoder.model);
        try std.testing.expectEqualDeep(range_before, .{ encoder.range_low, encoder.range_value, encoder.range_cache, encoder.range_cache_size });
        try std.testing.expectEqualDeep(stats_before, encoder.stats);
        try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
        try std.testing.expectEqual(@as(usize, 13), encoder.snapshot().output_written);
        try std.testing.expect(!encoder.range_finished);
        try sentinel(&scratch);

        encoder.options.max_pending_output_len = 64;
        const tail = try encoder.step("", &scratch);
        try std.testing.expectEqual(.done, tail.status);
        try output.appendSlice(allocator, scratch[0..tail.progress.output_written]);
        try std.testing.expectEqualSlices(u8, expected, output.items);
        try std.testing.expectEqual(expected.len, encoder.snapshot().output_written);
    };
}

test "LZMA wrapper presets header and range finish allocation failures leave retryable state" {
    inline for (.{ writer.SizeMode.known, writer.SizeMode.end_marker }) |size_mode| {
        const options: incremental.Encoder.Options = .{ .mode = .normal, .dictionary_size = 4096, .size_mode = size_mode };
        const expected = try writer.encodeAlloc(allocator, "", .{ .mode = options.mode, .dictionary_size = options.dictionary_size, .size_mode = size_mode });
        defer allocator.free(expected);
        var fail_index: usize = 0;
        while (true) : (fail_index += 1) {
            var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = fail_index });
            var encoder = if (size_mode == .known) try incremental.Encoder.initExactSize(failing.allocator(), options, 0) else try incremental.Encoder.initWithOptions(failing.allocator(), options);
            defer encoder.deinit();
            var scratch: [64]u8 = @splat(0xa5);
            var induced_failure = false;
            const header = encoder.step("", &scratch) catch |err| blk: {
                try std.testing.expectEqual(error.OutOfMemory, err);
                try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
                try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().output_written);
                try std.testing.expect(!encoder.header_written);
                try sentinel(&scratch);
                induced_failure = true;
                failing.fail_index = std.math.maxInt(usize);
                break :blk try encoder.step("", &scratch);
            };
            try std.testing.expectEqual(@as(usize, 13), header.progress.output_written);
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(allocator);
            try output.appendSlice(allocator, scratch[0..header.progress.output_written]);
            @memset(&scratch, 0xa5);
            const model_before = encoder.model;
            const range_before = .{ encoder.range_low, encoder.range_value, encoder.range_cache, encoder.range_cache_size };
            const stats_before = encoder.stats;
            encoder.finish();
            const tail = encoder.step("", &scratch) catch |err| blk: {
                try std.testing.expectEqual(error.OutOfMemory, err);
                try std.testing.expectEqualDeep(model_before, encoder.model);
                try std.testing.expectEqualDeep(range_before, .{ encoder.range_low, encoder.range_value, encoder.range_cache, encoder.range_cache_size });
                try std.testing.expectEqualDeep(stats_before, encoder.stats);
                try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
                try std.testing.expectEqual(@as(usize, 13), encoder.snapshot().output_written);
                try std.testing.expect(!encoder.range_finished);
                try sentinel(&scratch);
                induced_failure = true;
                failing.fail_index = std.math.maxInt(usize);
                break :blk try encoder.step("", &scratch);
            };
            try std.testing.expectEqual(.done, tail.status);
            try output.appendSlice(allocator, scratch[0..tail.progress.output_written]);
            try std.testing.expectEqualSlices(u8, expected, output.items);
            if (!induced_failure) break;
        }
    }
}

test "LZMA wrapper presets legacy literal greedy pending and allocation failures preserve matcher coding progress" {
    var input: [512]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x84a7c512b09df63e);
    prng.random().bytes(&input);
    inline for (.{ settings.Mode.literal_only, settings.Mode.greedy }) |mode| {
        const plain = input[0..if (mode == .literal_only) 64 else 512];
        inline for (.{ false, true }) |profiled| {
            if (profiled and mode == .greedy) continue;
            var profile: settings.EncodeWorkProfile = .{};
            const options: incremental.Encoder.Options = .{ .mode = mode, .dictionary_size = 4096, .size_mode = .known, .input_buffer_len = plain.len, .match_options = if (profiled) .{ .finder = .bt4, .nice_len = 2, .profile = &profile } else null };
            const expected = try writer.encodeAlloc(allocator, plain, .{ .mode = mode, .dictionary_size = options.dictionary_size, .size_mode = .known });
            defer allocator.free(expected);
            inline for (.{ false, true }) |allocation_failure| {
                var fail_index: usize = 0;
                while (true) : (fail_index += 1) {
                    profile.reset();
                    var failing = std.testing.FailingAllocator.init(allocator, .{});
                    var encoder = try incremental.Encoder.initExactSize(failing.allocator(), options, plain.len);
                    defer encoder.deinit();
                    var output: [2048]u8 = undefined;
                    const header = try encoder.step("", &output);
                    var written = header.progress.output_written;
                    try std.testing.expectEqual(@as(usize, 13), written);
                    if (allocation_failure) {
                        failing.fail_index = failing.alloc_index + fail_index;
                        failing.resize_fail_index = 0;
                    } else encoder.options.max_pending_output_len = 13;
                    var scratch: [1024]u8 = @splat(0xa5);
                    const model_before = encoder.model;
                    const range_before = .{ encoder.range_low, encoder.range_value, encoder.range_cache, encoder.range_cache_size };
                    const stats_before = encoder.stats;
                    var failed = false;
                    var accepted: usize = 0;
                    if (encoder.step(plain, &scratch)) |step| {
                        accepted = step.progress.input_read;
                        @memcpy(output[written..][0..step.progress.output_written], scratch[0..step.progress.output_written]);
                        written += step.progress.output_written;
                    } else |err| {
                        try std.testing.expectEqual(if (allocation_failure) error.OutOfMemory else error.OutputLimitExceeded, err);
                        failed = true;
                        const snapshot = encoder.snapshot();
                        accepted = snapshot.input_read;
                        try std.testing.expect(accepted == 0 or accepted == plain.len);
                        try std.testing.expectEqual(accepted, snapshot.buffered_input);
                        try std.testing.expectEqual(@as(usize, 0), snapshot.input_encoded);
                        try std.testing.expectEqual(@as(usize, 0), snapshot.pending_output);
                        try std.testing.expectEqual(@as(usize, 0), snapshot.history_bytes);
                        try std.testing.expectEqual(@as(usize, 13), snapshot.output_written);
                        try std.testing.expectEqualDeep(model_before, encoder.model);
                        try std.testing.expectEqualDeep(range_before, .{ encoder.range_low, encoder.range_value, encoder.range_cache, encoder.range_cache_size });
                        try std.testing.expectEqualDeep(stats_before, encoder.stats);
                        if (encoder.greedy) |greedy| {
                            for (greedy.head.items) |position| try std.testing.expectEqual(@as(i64, -1), position);
                            for (greedy.prev.items) |position| try std.testing.expectEqual(@as(i64, -1), position);
                        }
                        try sentinel(&scratch);
                        failing.fail_index = std.math.maxInt(usize);
                        encoder.options.max_pending_output_len = 1024 * 1024;
                        const resumed = try encoder.step(plain[accepted..], output[written..]);
                        accepted += resumed.progress.input_read;
                        written += resumed.progress.output_written;
                    }
                    try std.testing.expectEqual(plain.len, accepted);
                    failing.fail_index = std.math.maxInt(usize);
                    encoder.finish();
                    while (true) {
                        const step = try encoder.step("", output[written..]);
                        written += step.progress.output_written;
                        if (step.status == .done) break;
                    }
                    try std.testing.expectEqualSlices(u8, expected, output[0..written]);
                    try std.testing.expectEqual(plain.len, encoder.snapshot().input_encoded);
                    try std.testing.expectEqual(plain.len, encoder.snapshot().literals + encoder.snapshot().matched_bytes);
                    if (profiled) {
                        try std.testing.expect(profile.literals >= plain.len);
                        if (!allocation_failure) try std.testing.expectEqual(@as(u64, plain.len * 2), profile.literals);
                        try std.testing.expectEqual(@as(u64, 0), profile.matches);
                        try std.testing.expectEqual(@as(u64, 0), profile.mf_positions);
                        try std.testing.expectEqual(@as(u64, 0), profile.parser_windows);
                    }
                    if (!allocation_failure or !failed) break;
                }
            }
        }
    }
}

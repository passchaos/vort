const std = @import("std");
const writer = @import("writer.zig");
const micro = @import("micro_writer.zig");
const limited = @import("micro_limited_writer.zig");
const incremental = @import("incremental_encoder.zig");
const decoder = @import("decoder.zig");
const settings = @import("encode_options.zig");
const working = @import("../io/working_allocator.zig");
const allocator = std.testing.allocator;
// Independent LZMA1/Alone/Micro limit; LZMA2 dictionary properties have a
// different range. The preset table still tops out at 64 MiB.
const largest_dictionary: u32 = 1_610_612_736;
const plain = "ab0ab1ab2ab3ab4ab5 ab0ab1ab2ab3ab4ab5 big requested window";

fn sentinel(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn encodeSplit(a: std.mem.Allocator, input: []const u8, options: writer.EncodeOptions) ![]u8 {
    var encoder = try incremental.Encoder.initExactSize(a, .{ .properties = options.properties, .dictionary_size = options.dictionary_size, .mode = options.mode, .size_mode = .known, .match_options = options.match_options, .input_buffer_len = 4369 }, input.len);
    defer encoder.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(a);
    var input_staging: [3]u8 = undefined;
    var scratch: [1]u8 = undefined;
    var position: usize = 0;
    var finishing = false;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < 4096 + input.len * 8);
        if (position == input.len and !finishing) {
            encoder.finish();
            finishing = true;
        }
        const take = @min(input_staging.len, input.len - position);
        @memcpy(input_staging[0..take], input[position..][0..take]);
        const step = try encoder.step(input_staging[0..take], &scratch);
        position += step.progress.input_read;
        @memset(&input_staging, 0xa5);
        try output.appendSlice(a, scratch[0..step.progress.output_written]);
        const snapshot = encoder.snapshot();
        try std.testing.expect(snapshot.buffered_input <= input.len);
        try std.testing.expect(snapshot.history_bytes <= input.len);
        try std.testing.expect(snapshot.retained_history_capacity <= input.len);
        if (step.status == .done) break;
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try std.testing.expectEqual(input.len, encoder.snapshot().input_encoded);
    return output.toOwnedSlice(a);
}

test "LZMA large dictionary wrappers validate shared bounds and initialize without heap" {
    try std.testing.expectEqual(@as(usize, largest_dictionary), settings.max_dictionary_size);
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    for ([_]settings.Mode{ .literal_only, .greedy, .lazy, .fast, .normal }) |mode| {
        for ([_]settings.MatchFinder{ .hc3, .hc4, .bt2, .bt3, .bt4 }) |finder| {
            var profile: settings.EncodeWorkProfile = .{};
            const match: settings.MatchOptions = .{ .finder = finder, .nice_len = 2, .profile = &profile };
            const options: incremental.Encoder.Options = .{ .mode = mode, .dictionary_size = largest_dictionary, .match_options = match };
            try options.validate();
            try std.testing.expectEqualDeep(settings.EncodeWorkProfile{}, profile);
            var encoder = try incremental.Encoder.initWithOptions(failing.allocator(), options);
            defer encoder.deinit();
            try std.testing.expectEqual(@as(usize, largest_dictionary), encoder.model.dictionary_size);
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().retained_input_capacity);
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().retained_history_capacity);
            try std.testing.expectEqual(@as(u64, 0), profile.mf_positions + profile.parser_windows + profile.literals);
        }
    }
    var null_greedy = try incremental.Encoder.initWithOptions(failing.allocator(), .{ .dictionary_size = largest_dictionary });
    defer null_greedy.deinit();
    try std.testing.expect(null_greedy.greedy == null);
    var destination: [128]u8 = @splat(0xa5);
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "prefix");
    for ([_]u32{ 0, 4095, largest_dictionary + 1, std.math.maxInt(u32) }) |invalid| {
        try std.testing.expectError(error.InvalidLzmaOptions, writer.encodeInto(failing.allocator(), plain, &destination, .{ .dictionary_size = invalid }));
        try std.testing.expectError(error.InvalidLzmaOptions, writer.encodeZipPayloadAppend(failing.allocator(), &output, plain, .{ .dictionary_size = invalid }));
        try std.testing.expectError(error.InvalidLzmaOptions, micro.encodeInto(failing.allocator(), plain, &destination, .{ .dictionary_size = invalid }));
        try std.testing.expectError(error.InvalidLzmaOptions, limited.encodeAlignedAlloc(failing.allocator(), plain, 64, 4, .{ .dictionary_size = invalid }));
        try std.testing.expectError(error.InvalidLzmaOptions, incremental.Encoder.initWithOptions(failing.allocator(), .{ .dictionary_size = invalid }));
        try sentinel(&destination);
        try std.testing.expectEqualStrings("prefix", output.items);
    }
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
}

test "LZMA large dictionary wrappers Alone canonical shapes and ZIP exact raw dictionary" {
    var budget = working.WorkingAllocator.init(allocator, 1024 * 1024);
    const a = budget.allocator();
    for ([_]struct { requested: u32, advertised: u32 }{
        .{ .requested = 64 * 1024 * 1024 + 1, .advertised = 96 * 1024 * 1024 },
        .{ .requested = 96 * 1024 * 1024 + 1, .advertised = 128 * 1024 * 1024 },
        .{ .requested = 1 << 30, .advertised = 1 << 30 },
        .{ .requested = (1 << 30) + 1, .advertised = largest_dictionary },
        .{ .requested = largest_dictionary - 1, .advertised = largest_dictionary },
        .{ .requested = largest_dictionary, .advertised = largest_dictionary },
    }) |sample| {
        const encoded = try writer.encodeAlloc(a, "x", .{ .dictionary_size = sample.requested, .mode = .literal_only, .size_mode = .known });
        defer a.free(encoded);
        try std.testing.expectEqual(sample.advertised, (try decoder.parseHeader(encoded)).dictionary_size);
        const decoded = try decoder.decodeAllocWithOptions(a, encoded, .{ .max_output_len = 1, .max_dictionary_size = largest_dictionary });
        defer a.free(decoded);
        try std.testing.expectEqualStrings("x", decoded);
        const zip = try writer.encodeZipPayloadAlloc(a, "x", .{ .dictionary_size = sample.requested, .mode = .literal_only });
        defer a.free(zip);
        try std.testing.expectEqual(sample.requested, std.mem.readInt(u32, zip[5..9], .little));
        const zip_decoded = try decoder.decodeZipPayloadAllocLimited(a, zip, 1, largest_dictionary, true);
        defer a.free(zip_decoded);
        try std.testing.expectEqualStrings("x", zip_decoded);
    }
    const legacy = try writer.encodeAlloc(a, "x", .{ .dictionary_size = 5000, .mode = .literal_only, .size_mode = .known });
    defer a.free(legacy);
    try std.testing.expectEqual(@as(u32, 5000), (try decoder.parseHeader(legacy)).dictionary_size);
    try std.testing.expect(!budget.hit_limit);
}

test "LZMA large dictionary wrappers all five finders use tiny actual memory and every output trait" {
    var budget = working.WorkingAllocator.init(allocator, 8 * 1024 * 1024);
    const a = budget.allocator();
    for ([_]settings.Mode{ .fast, .normal }) |mode| for ([_]settings.MatchFinder{ .hc3, .hc4, .bt2, .bt3, .bt4 }) |finder| {
        var profile: settings.EncodeWorkProfile = .{};
        const options: writer.EncodeOptions = .{ .mode = mode, .dictionary_size = largest_dictionary, .size_mode = .known, .properties = .{ .lc = 0, .lp = 4, .pb = 4 }, .match_options = .{ .finder = finder, .nice_len = 2, .depth = 2, .max_working_memory = 4 * 1024 * 1024, .profile = &profile } };
        const encoded = try writer.encodeAlloc(a, plain, options);
        defer a.free(encoded);
        const decoded = try decoder.decodeAllocWithOptions(a, encoded, .{ .max_output_len = plain.len, .max_dictionary_size = largest_dictionary });
        defer a.free(decoded);
        try std.testing.expectEqualStrings(plain, decoded);
        const streamed = try encodeSplit(a, plain, options);
        defer a.free(streamed);
        try std.testing.expectEqualSlices(u8, encoded, streamed);
        const zip = try writer.encodeZipPayloadAlloc(a, plain, .{ .properties = options.properties, .dictionary_size = largest_dictionary, .mode = mode, .match_options = options.match_options });
        defer a.free(zip);
        const zip_decoded = try decoder.decodeZipPayloadAllocLimited(a, zip, plain.len, largest_dictionary, true);
        defer a.free(zip_decoded);
        try std.testing.expectEqualStrings(plain, zip_decoded);
        const compact_options: micro.Options = .{ .properties = options.properties, .dictionary_size = largest_dictionary, .mode = mode, .match_options = options.match_options };
        const compact = try micro.encodeAlloc(a, plain, compact_options);
        defer a.free(compact);
        const compact_decoded = try decoder.decodeMicroAllocExactSize(a, compact, plain.len, largest_dictionary);
        defer a.free(compact_decoded);
        try std.testing.expectEqualStrings(plain, compact_decoded);
        var full_prefix = try micro.encodeDestSizeAlloc(a, plain, compact.len + 8, compact_options);
        defer full_prefix.deinit(a);
        try std.testing.expectEqual(plain.len, full_prefix.consumed);
        try std.testing.expectEqualSlices(u8, compact, full_prefix.bytes);
        var aligned = try micro.encodeAlignedDestSizeAlloc(a, plain, 14, 3, compact_options);
        defer aligned.deinit(a);
        try std.testing.expect(aligned.consumed == plain.len or aligned.consumed % 3 == 0);
        const prefix_decoded = try decoder.decodeMicroAllocExactSize(a, aligned.bytes, aligned.consumed, largest_dictionary);
        defer a.free(prefix_decoded);
        try std.testing.expectEqualSlices(u8, plain[0..aligned.consumed], prefix_decoded);
        try std.testing.expect(profile.mf_candidate_probes > 0);
        try std.testing.expect(profile.peak_working_memory <= 4 * 1024 * 1024);
    };
    try std.testing.expect(!budget.hit_limit);
    try std.testing.expect(budget.peak < 8 * 1024 * 1024);
}

test "LZMA large dictionary wrappers null greedy lazy paths consume the requested wide window" {
    var budget = working.WorkingAllocator.init(allocator, 8 * 1024 * 1024);
    const a = budget.allocator();
    for ([_]settings.Mode{ .greedy, .lazy }) |mode| {
        const options: writer.EncodeOptions = .{ .mode = mode, .dictionary_size = largest_dictionary, .size_mode = .known };
        const encoded = try writer.encodeAlloc(a, plain, options);
        defer a.free(encoded);
        const decoded = try decoder.decodeAllocWithOptions(a, encoded, .{ .max_output_len = plain.len, .max_dictionary_size = largest_dictionary });
        defer a.free(decoded);
        try std.testing.expectEqualStrings(plain, decoded);
        const zip = try writer.encodeZipPayloadAlloc(a, plain, .{ .mode = mode, .dictionary_size = largest_dictionary });
        defer a.free(zip);
        const zip_decoded = try decoder.decodeZipPayloadAllocLimited(a, zip, plain.len, largest_dictionary, true);
        defer a.free(zip_decoded);
        try std.testing.expectEqualStrings(plain, zip_decoded);
        const compact_options: micro.Options = .{ .mode = mode, .dictionary_size = largest_dictionary };
        const compact = try micro.encodeAlloc(a, plain, compact_options);
        defer a.free(compact);
        var prefix = try micro.encodeDestSizeAlloc(a, plain, compact.len + 8, compact_options);
        defer prefix.deinit(a);
        try std.testing.expectEqual(plain.len, prefix.consumed);
        try std.testing.expectEqualSlices(u8, compact, prefix.bytes);
        const compact_decoded = try decoder.decodeMicroAllocExactSize(a, compact, plain.len, largest_dictionary);
        defer a.free(compact_decoded);
        try std.testing.expectEqualStrings(plain, compact_decoded);
        var aligned = try micro.encodeAlignedDestSizeAlloc(a, plain, 14, 3, compact_options);
        defer aligned.deinit(a);
        const aligned_decoded = try decoder.decodeMicroAllocExactSize(a, aligned.bytes, aligned.consumed, largest_dictionary);
        defer a.free(aligned_decoded);
        try std.testing.expectEqualSlices(u8, plain[0..aligned.consumed], aligned_decoded);
        if (mode == .greedy) {
            const streamed = try encodeSplit(a, plain, options);
            defer a.free(streamed);
            try std.testing.expectEqualSlices(u8, encoded, streamed);
        } else {
            // Null lazy incremental encoding was already unsupported.
            try std.testing.expectError(error.InvalidLzmaOptions, incremental.Encoder.initWithOptions(a, .{ .mode = mode, .dictionary_size = largest_dictionary }));
        }
    }
    try std.testing.expect(!budget.hit_limit);
}

test "LZMA large dictionary wrappers invalid properties and exhausted budgets preserve destinations" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var destination: [256]u8 = @splat(0xa5);
    for ([_]settings.Properties{ .{ .lc = 4, .lp = 1 }, .{ .pb = 5 } }) |properties| {
        try std.testing.expectError(error.InvalidLzmaOptions, writer.encodeInto(failing.allocator(), plain, &destination, .{ .dictionary_size = largest_dictionary, .properties = properties }));
        try std.testing.expectError(error.InvalidLzmaOptions, micro.encodeAlignedDestSizeInto(failing.allocator(), plain, &destination, 3, .{ .dictionary_size = largest_dictionary, .properties = properties }));
        try sentinel(&destination);
    }
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "prefix");
    const options: writer.EncodeOptions = .{ .dictionary_size = largest_dictionary, .mode = .normal, .match_options = .{ .max_working_memory = 0 } };
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, writer.encodeInto(allocator, plain, &destination, options));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, writer.encodeAppend(allocator, &output, plain, options));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, writer.encodeZipPayloadAppend(allocator, &output, plain, .{ .dictionary_size = largest_dictionary, .mode = options.mode, .match_options = options.match_options }));
    const compact: micro.Options = .{ .dictionary_size = largest_dictionary, .mode = options.mode, .match_options = options.match_options };
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, micro.encodeInto(allocator, plain, &destination, compact));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, micro.encodeDestSizeInto(allocator, plain, &destination, compact));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, micro.encodeAlignedDestSizeInto(allocator, plain, &destination, 3, compact));
    try sentinel(&destination);
    try std.testing.expectEqualStrings("prefix", output.items);
}

test "LZMA large dictionary wrappers overlapping Into and append inputs preserve wire" {
    const options: writer.EncodeOptions = .{ .dictionary_size = largest_dictionary, .mode = .fast, .size_mode = .known, .match_options = .{ .finder = .hc3, .nice_len = 4, .depth = 2 } };
    const expected = try writer.encodeAlloc(allocator, plain, options);
    defer allocator.free(expected);
    var storage: [512]u8 = @splat(0xa5);
    @memcpy(storage[0..plain.len], plain);
    const written = try writer.encodeInto(allocator, storage[0..plain.len], &storage, options);
    try std.testing.expectEqualSlices(u8, expected, storage[0..written]);
    const compact_options: micro.Options = .{ .dictionary_size = largest_dictionary, .mode = options.mode, .match_options = options.match_options };
    const compact = try micro.encodeAlloc(allocator, plain, compact_options);
    defer allocator.free(compact);
    @memcpy(storage[0..plain.len], plain);
    const result = try micro.encodeDestSizeInto(allocator, storage[0..plain.len], &storage, compact_options);
    try std.testing.expectEqual(plain.len, result.consumed);
    try std.testing.expectEqualSlices(u8, compact, storage[0..result.written]);
    @memcpy(storage[0..plain.len], plain);
    const aligned = try micro.encodeAlignedDestSizeInto(allocator, storage[0..plain.len], storage[0..14], 3, compact_options);
    const decoded = try decoder.decodeMicroAllocExactSize(allocator, storage[0..aligned.written], aligned.consumed, largest_dictionary);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, plain[0..aligned.consumed], decoded);
    var output: std.ArrayList(u8) = .{ .items = try allocator.dupe(u8, plain), .capacity = plain.len };
    defer output.deinit(allocator);
    const zip_options: writer.ZipEncodeOptions = .{ .dictionary_size = largest_dictionary, .mode = options.mode, .match_options = options.match_options };
    const zip = try writer.encodeZipPayloadAlloc(allocator, plain, zip_options);
    defer allocator.free(zip);
    _ = try writer.encodeZipPayloadAppend(allocator, &output, output.items, zip_options);
    try std.testing.expectEqualSlices(u8, plain, output.items[0..plain.len]);
    try std.testing.expectEqualSlices(u8, zip, output.items[plain.len..]);
}

test "LZMA large dictionary wrappers incremental budget and header limits retry bounded actual history" {
    const options: incremental.Encoder.Options = .{ .dictionary_size = largest_dictionary, .mode = .fast, .size_mode = .known, .input_buffer_len = 4369, .max_pending_output_len = 12, .match_options = .{ .finder = .hc3, .nice_len = 4, .depth = 2, .max_working_memory = 0 } };
    var encoder = try incremental.Encoder.initExactSize(allocator, options, plain.len);
    defer encoder.deinit();
    var scratch: [256]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutputLimitExceeded, encoder.step("", &scratch));
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
    try sentinel(&scratch);
    encoder.options.max_pending_output_len = scratch.len;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    const accepted = try encoder.step(plain, &scratch);
    try std.testing.expectEqual(plain.len, accepted.progress.input_read);
    try output.appendSlice(allocator, scratch[0..accepted.progress.output_written]);
    const model_before = encoder.model;
    const stats_before = encoder.stats;
    @memset(&scratch, 0xa5);
    encoder.finish();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.step("", &scratch));
    try std.testing.expectEqualDeep(model_before, encoder.model);
    try std.testing.expectEqualDeep(stats_before, encoder.stats);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().input_encoded);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().history_bytes);
    try std.testing.expect(encoder.snapshot().retained_history_capacity <= plain.len);
    try sentinel(&scratch);
    encoder.options.match_options.?.max_working_memory = 4 * 1024 * 1024;
    while (true) {
        const step = try encoder.step("", &scratch);
        try output.appendSlice(allocator, scratch[0..step.progress.output_written]);
        if (step.status == .done) break;
    }
    const expected = try writer.encodeAlloc(allocator, plain, .{ .dictionary_size = largest_dictionary, .mode = options.mode, .size_mode = .known, .match_options = encoder.options.match_options });
    defer allocator.free(expected);
    try std.testing.expectEqualSlices(u8, expected, output.items);
    try std.testing.expectEqual(plain.len, encoder.snapshot().history_bytes);
    try std.testing.expect(encoder.snapshot().retained_history_capacity <= plain.len);
}

const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    try std.testing.expect((Z.FrameOptions{}).include_dictionary_id);
    try std.testing.expect((Z.NativeFrameOptions{}).include_dictionary_id);
    for ([_]u32{ 0, 1, 256, 65536, std.math.maxInt(u32) }) |identity| {
        const dictionary = Z.NativeDictionary.init(identity, h.plain);
        for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
            const options: Z.NativeFrameOptions = .{ .format = format, .selection = .literal_only, .window_log = 10, .block_size_max = 128 };
            const kept = try Z.encodeNativeFrameWithDictionaryAlloc(a, h.plain, options, dictionary);
            defer a.free(kept.frame);
            var omitted_options = options;
            omitted_options.include_dictionary_id = false;
            const omitted = try Z.encodeNativeFrameWithDictionaryAlloc(a, h.plain, omitted_options, dictionary);
            defer a.free(omitted.frame);
            try h.pair(kept.frame, omitted.frame, format, identity);
            try std.testing.expectEqual(kept.mode, omitted.mode);
            try h.check(Z, omitted.frame, h.plain, format, dictionary);
            try std.testing.expectEqual(identity, dictionary.id);
            try std.testing.expectEqual(@as(u32, 0), options.dictionary_id);
            const bound = try Z.encodedNativeFrameBoundWithDictionary(h.plain.len, options, dictionary);
            const omitted_bound = try Z.encodedNativeFrameBoundWithDictionary(h.plain.len, omitted_options, dictionary);
            try std.testing.expect(kept.frame.len <= bound and omitted.frame.len <= omitted_bound);
            try std.testing.expectEqual(kept.frame.len - omitted.frame.len, bound - omitted_bound);
        }
    }
    try publications(Z);
    try levels(Z);
    try fullDictionary(Z);
    try fallback(Z);
}

fn fallback(comptime Z: type) !void {
    const dictionary = Z.NativeDictionary.init(h.id, h.plain);
    for ([_][]const u8{ "", "x" }) |input| {
        const kept = try Z.encodeNativeFrameWithDictionaryAlloc(a, input, .{}, dictionary);
        defer a.free(kept.frame);
        const omitted = try Z.encodeNativeFrameWithDictionaryAlloc(a, input, .{ .include_dictionary_id = false }, dictionary);
        defer a.free(omitted.frame);
        try std.testing.expectEqual(Z.NativeFrameMode.raw_or_rle, kept.mode);
        try std.testing.expectEqual(kept.mode, omitted.mode);
        try h.pair(kept.frame, omitted.frame, Z.FrameFormat.standard, dictionary.id);
        try h.check(Z, omitted.frame, input, .standard, dictionary);
    }
}

fn publications(comptime Z: type) !void {
    const dictionary = Z.NativeDictionary.init(h.id, h.plain);
    const entries = [_]Z.NativeDictionary{ Z.NativeDictionary.init(7, "wrong entry"), dictionary };
    const set = Z.NativeDictionarySet.init(&entries);
    const repeated = [_]u8{'R'} ** 512;
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        for ([_]struct { input: []const u8, selection: Z.NativeFrameSelection }{
            .{ .input = h.plain, .selection = .raw_or_rle },
            .{ .input = &repeated, .selection = .raw_or_rle },
            .{ .input = h.plain, .selection = .literal_only },
        }) |sample| {
            const options: Z.NativeFrameOptions = .{ .format = format, .dictionary_id = dictionary.id, .include_dictionary_id = false, .selection = sample.selection, .block_size_max = 128 };
            const encoded = try Z.encodeNativeFrameWithDictionaryAlloc(a, sample.input, options, dictionary);
            defer a.free(encoded.frame);
            try std.testing.expectEqual(@as(u32, 0), (try h.wire.header(encoded.frame, format == .magicless)).dictionary_id);
            const selected = try Z.encodeNativeFrameWithDictionarySetAlloc(a, sample.input, options, set, dictionary.id);
            defer a.free(selected.frame);
            try std.testing.expectEqualSlices(u8, encoded.frame, selected.frame);
            const output = try a.alloc(u8, encoded.frame.len + 17);
            defer a.free(output);
            @memset(output, 0xa5);
            const into = try Z.encodeNativeFrameIntoSliceWithDictionary(a, sample.input, options, dictionary, output[0..encoded.frame.len]);
            try std.testing.expectEqualSlices(u8, encoded.frame, output[0..into.written]);
            try h.wire.untouched(output[into.written..]);
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(a);
            try out.appendSlice(a, "prefix");
            _ = try Z.encodeNativeFrameAppendWithDictionarySet(a, &out, sample.input, options, set, dictionary.id);
            try std.testing.expectEqualSlices(u8, encoded.frame, out.items[6..]);
            var encoder = Z.NativeFrameEncoder.init(a);
            defer encoder.deinit();
            const scratch = try encoder.encodeScratchWithDictionarySet(sample.input, options, set, dictionary.id);
            try std.testing.expectEqualSlices(u8, encoded.frame, scratch.frame);
            const owned = try encoder.encodeWithDictionaryAlloc(sample.input, options, dictionary);
            defer a.free(owned.frame);
            try std.testing.expectEqualSlices(u8, encoded.frame, owned.frame);
            const reusable_into = try encoder.encodeIntoSliceWithDictionarySet(sample.input, options, set, dictionary.id, output);
            try std.testing.expectEqualSlices(u8, encoded.frame, output[0..reusable_into.written]);
            out.shrinkRetainingCapacity(6);
            _ = try encoder.encodeAppendWithDictionary(&out, sample.input, options, dictionary);
            try std.testing.expectEqualSlices(u8, encoded.frame, out.items[6..]);
            try h.check(Z, encoded.frame, sample.input, format, dictionary);
            var decoder = Z.NativeFrameDecoder.initWithOptions(a, .{ .format = format, .dictionary = dictionary });
            defer decoder.deinit();
            const chunks = [_][]const u8{ &.{}, encoded.frame[0..1], encoded.frame[1 .. encoded.frame.len - 1], encoded.frame[encoded.frame.len - 1 ..] };
            const compressed_scratch = try a.alloc(u8, encoded.frame.len);
            defer a.free(compressed_scratch);
            try std.testing.expectEqualSlices(u8, sample.input, try decoder.decodeChunksScratch(&chunks, compressed_scratch));
            const chunk_output = try decoder.decodeChunksAlloc(&chunks, compressed_scratch);
            defer a.free(chunk_output);
            try std.testing.expectEqualSlices(u8, sample.input, chunk_output);
            if (sample.selection == .raw_or_rle) {
                const raw = try Z.encodeRawOrRleFrameWithOptionsAlloc(a, sample.input, options);
                defer a.free(raw);
                try std.testing.expectEqualSlices(u8, encoded.frame, raw);
                out.shrinkRetainingCapacity(6);
                try Z.encodeRawOrRleFrameAppend(a, &out, sample.input, options);
                try std.testing.expectEqualSlices(u8, raw, out.items[6..]);
                const count = try Z.encodeRawOrRleFrameIntoSlice(a, sample.input, options, output);
                try std.testing.expectEqualSlices(u8, raw, output[0..count]);
            }
        }
    }
}

fn levels(comptime Z: type) !void {
    const dictionary = Z.NativeDictionary.init(h.id, h.plain);
    for ([_]c_int{ -3, 0, 1, 3 }) |level| {
        for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
            const options: Z.FrameOptions = .{ .format = format, .include_dictionary_id = false, .content_checksum = true };
            const mapped = try Z.nativeFrameOptionsForLevel(level, options);
            try std.testing.expect(!mapped.include_dictionary_id);
            const omitted = try Z.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(a, h.plain, level, options, dictionary);
            defer a.free(omitted);
            var kept_options = options;
            kept_options.include_dictionary_id = true;
            const kept = try Z.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(a, h.plain, level, kept_options, dictionary);
            defer a.free(kept);
            try h.pair(kept, omitted, format, dictionary.id);
            try h.check(Z, omitted, h.plain, format, dictionary);
            const output = try a.alloc(u8, omitted.len + 17);
            defer a.free(output);
            @memset(output, 0xa5);
            const count = try Z.encodeFrameIntoSliceWithLevelAndOptionsAndDictionary(a, h.plain, level, options, dictionary, output);
            try std.testing.expectEqualSlices(u8, omitted, output[0..count]);
            try h.wire.untouched(output[count..]);
        }
    }
}

fn fullDictionary(comptime Z: type) !void {
    const dictionary_bytes = try h.memory.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.dict.hex"));
    defer a.free(dictionary_bytes);
    const reference = try h.memory.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.frame.hex"));
    defer a.free(reference);
    const dictionary = (try Z.NativeDictionary.initFromStandardDictionary(dictionary_bytes)).dictionary;
    var prepared = try Z.PreparedDecodeDictionary.init(dictionary);
    const payload = try Z.decodeFrameAllocWithOptions(a, reference, .{ .dictionary = prepared.handle() });
    defer a.free(payload);
    const reference_without_id = try h.omitReferenceId(reference);
    defer a.free(reference_without_id);
    try h.pair(reference, reference_without_id, Z.FrameFormat.standard, dictionary.id);
    try h.check(Z, reference_without_id, payload, .standard, prepared.handle());
    // The external fixture uses the full initial entropy state, not just history.
    if (Z.decodeFrameAllocWithOptions(a, reference_without_id, .{ .dictionary = Z.NativeDictionary.initRawContent(dictionary.content) })) |unexpected| {
        a.free(unexpected);
        return error.ExpectedStandardDictionaryDependency;
    } else |err| try std.testing.expect(err != error.OutOfMemory);
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        for ([_]Z.NativeDictionary{ dictionary, prepared.handle() }) |preset| {
            const options: Z.NativeFrameOptions = .{ .format = format, .selection = .literal_only, .block_size_max = 128, .match_search_budget = 0 };
            const kept = try Z.encodeNativeFrameWithDictionaryAlloc(a, payload, options, preset);
            defer a.free(kept.frame);
            var omitted_options = options;
            omitted_options.include_dictionary_id = false;
            const omitted = try Z.encodeNativeFrameWithDictionaryAlloc(a, payload, omitted_options, preset);
            defer a.free(omitted.frame);
            try h.pair(kept.frame, omitted.frame, format, dictionary.id);
            try h.check(Z, omitted.frame, payload, format, preset);
            try std.testing.expectEqual(dictionary.id, preset.id);
            try std.testing.expectEqualSlices(u8, dictionary_bytes, preset.standard_bytes.?);
        }
    }
}

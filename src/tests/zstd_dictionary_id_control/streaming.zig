const std = @import("std");
const core = @import("../../core.zig");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    const dictionary = Z.NativeDictionary.init(h.id, h.plain);
    const dictionaries = [_]Z.NativeDictionary{ Z.NativeDictionary.init(1, "not selected"), dictionary };
    const set = Z.NativeDictionarySet.init(&dictionaries);
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        for ([_]bool{ false, true }) |known| {
            const options: Z.NativeFrameOptions = .{ .format = format, .dictionary_id = dictionary.id, .include_content_size = known, .selection = .literal_only, .block_size_max = 128, .window_log = 10 };
            var kept = if (known)
                try Z.NativeIncrementalFrameEncoder.initExactSizeWithPresetDictionary(a, options, h.plain.len, dictionary)
            else
                try Z.NativeIncrementalFrameEncoder.initWithPresetDictionary(a, options, dictionary);
            defer kept.deinit();
            const before = try h.wire.encodeDrive(a, &kept, h.plain);
            defer a.free(before);
            var omitted_options = options;
            omitted_options.include_dictionary_id = false;
            var omitted = if (known)
                try Z.NativeIncrementalFrameEncoder.initExactSizeWithDictionarySet(a, omitted_options, h.plain.len, set, dictionary.id)
            else
                try Z.NativeIncrementalFrameEncoder.initWithDictionarySet(a, omitted_options, set, dictionary.id);
            defer omitted.deinit();
            try std.testing.expectEqual(@as(?u32, dictionary.id), omitted.dictionary_id);
            try std.testing.expectEqual(dictionary.id, omitted.dictionary.?.id);
            const after = try h.wire.encodeDrive(a, &omitted, h.plain);
            defer a.free(after);
            try h.pair(before, after, format, dictionary.id);
            try h.check(Z, after, h.plain, format, dictionary);
            for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
                var decoder = Z.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(a, dictionary, .{ .format = format, .input_policy = policy });
                defer decoder.deinit();
                const decoded = try h.wire.drive(a, &decoder, after, h.plain.len, 1, 7);
                defer a.free(decoded.output);
                try decoder.finish();
                try std.testing.expectEqualSlices(u8, h.plain, decoded.output);
            }
            try std.testing.expectEqual(@as(core.StreamCount, h.plain.len), omitted.snapshot().input_read);
            try std.testing.expectEqual(@as(core.StreamCount, after.len), omitted.snapshot().output_written);
        }
    }
    try metadata(Z, dictionary);
    try parallel(Z, dictionary, set);
}

fn metadata(comptime Z: type, dictionary: Z.NativeDictionary) !void {
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        for ([_]bool{ false, true }) |known| {
            const options: Z.NativeFrameOptions = .{ .format = format, .dictionary_id = dictionary.id, .include_content_size = known, .selection = .raw_or_rle, .block_size_max = 128, .window_log = 10 };
            var kept = if (known)
                try Z.NativeIncrementalFrameEncoder.initExactSizeWithDictionary(a, options, h.plain.len, dictionary.id)
            else
                try Z.NativeIncrementalFrameEncoder.initWithDictionary(a, options, dictionary.id);
            defer kept.deinit();
            const before = try h.wire.encodeDrive(a, &kept, h.plain);
            defer a.free(before);
            var omitted_options = options;
            omitted_options.include_dictionary_id = false;
            var omitted = if (known)
                try Z.NativeIncrementalFrameEncoder.initExactSizeWithDictionary(a, omitted_options, h.plain.len, dictionary.id)
            else
                try Z.NativeIncrementalFrameEncoder.initWithDictionary(a, omitted_options, dictionary.id);
            defer omitted.deinit();
            try std.testing.expectEqual(dictionary.id, omitted.options.dictionary_id);
            try std.testing.expectEqual(@as(?u32, dictionary.id), omitted.dictionary_id);
            try std.testing.expect(omitted.dictionary == null);
            const after = try h.wire.encodeDrive(a, &omitted, h.plain);
            defer a.free(after);
            try h.pair(before, after, format, dictionary.id);
            try h.check(Z, after, h.plain, format, dictionary);
        }
    }
}

fn parallel(comptime Z: type, dictionary: Z.NativeDictionary, set: Z.NativeDictionarySet) !void {
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        for ([_]bool{ false, true }) |known| {
            for ([_]usize{ 1, 2 }) |workers| {
                const options: Z.NativeIncrementalParallelFrameEncoder.Options = .{
                    .frame = .{ .format = format, .include_content_size = known, .block_size_max = 128, .window_log = 10, .strategy = .fast },
                    .parallel = .{ .io = std.testing.io, .worker_count = workers, .job_size = 256, .max_inflight_jobs = 2, .max_inflight_bytes = 512, .max_working_memory = 32 * 1024 * 1024 },
                };
                var kept = if (known)
                    try Z.NativeIncrementalParallelFrameEncoder.initExactSizeWithPresetDictionary(a, options, h.plain.len, dictionary)
                else
                    try Z.NativeIncrementalParallelFrameEncoder.initWithPresetDictionary(a, options, dictionary);
                defer kept.deinit();
                const before = try h.wire.encodeDrive(a, &kept, h.plain);
                defer a.free(before);
                var omitted_options = options;
                omitted_options.frame.include_dictionary_id = false;
                var omitted = if (known)
                    try Z.NativeIncrementalParallelFrameEncoder.initExactSizeWithDictionarySet(a, omitted_options, h.plain.len, set, dictionary.id)
                else
                    try Z.NativeIncrementalParallelFrameEncoder.initWithDictionarySet(a, omitted_options, set, dictionary.id);
                defer omitted.deinit();
                try std.testing.expectEqual(dictionary.id, omitted.options.frame.dictionary_id);
                const after = try h.wire.encodeDrive(a, &omitted, h.plain);
                defer a.free(after);
                try h.pair(before, after, format, dictionary.id);
                try h.check(Z, after, h.plain, format, dictionary);
                try std.testing.expectEqual(@as(core.StreamCount, h.plain.len), omitted.snapshot().input_read);
                try std.testing.expectEqual(@as(core.StreamCount, after.len), omitted.snapshot().output_written);
                try std.testing.expectEqual(@as(core.StreamCount, 2), omitted.snapshot().parallel.profile.delivered_jobs);
            }
        }
    }
}

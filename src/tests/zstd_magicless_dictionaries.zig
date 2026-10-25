//! Dictionary IDs, full metadata and header-only missing-dictionary progress.
const std = @import("std");
const core = @import("../core.zig");
const h = @import("zstd_magicless_helpers.zig");
const a = std.testing.allocator;

pub fn contracts(comptime Z: type) !void {
    const Cases = Suite(Z);
    for ([_]u32{ 0, 1, 256, 65536, std.math.maxInt(u32) }) |id| {
        try Cases.dictionary(Z.NativeDictionary.init(id, h.plain));
        if (id != 0) {
            const owned = try Z.standardDictionaryFromContentAlloc(a, h.plain, id);
            defer owned.deinit(a);
            try Cases.dictionary(owned.asDictionary());
        }
    }
    var denied = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidDictionaryMetadata, Z.standardDictionaryFromContentAlloc(denied.allocator(), h.plain, 0));
    try std.testing.expectEqual(@as(usize, 0), denied.alloc_index);
    try std.testing.expect(!denied.has_induced_failure);
}
fn Suite(comptime Z: type) type {
    return struct {
        fn dictionary(dict: Z.NativeDictionary) !void {
            errdefer std.debug.print("magicless dictionary id={d} kind={s}\n", .{ dict.id, @tagName(dict.kind()) });
            const payload = h.plain ** 2;
            const options: Z.NativeFrameOptions = .{ .format = .magicless, .selection = .literal_only, .content_checksum = true, .block_size_max = 128, .window_log = 10 };
            const encoded = try Z.encodeNativeFrameWithDictionaryAlloc(a, payload, options, dict);
            defer a.free(encoded.frame);
            var normal_options = options;
            normal_options.format = .standard;
            const normal = try Z.encodeNativeFrameWithDictionaryAlloc(a, payload, normal_options, dict);
            defer a.free(normal.frame);
            try std.testing.expectEqualSlices(u8, normal.frame[4..], encoded.frame);
            const header = try h.header(encoded.frame, true);
            try std.testing.expectEqual(dict.id, header.dictionary_id);
            try std.testing.expectEqual(dict.id, (try Z.inspectNativeFrameHeaderWithFormat(encoded.frame, .magicless)).dictionary_id);
            const opts: Z.FrameDecodeOptions = .{ .format = .magicless, .dictionary = dict, .expected_output_len = payload.len };
            try h.check(Z, a, encoded.frame, payload, opts);
            var reusable = Z.NativeFrameDecoder.initWithOptions(a, opts);
            defer reusable.deinit();
            try std.testing.expectEqualSlices(u8, payload, try reusable.decodeScratch(encoded.frame));
            try std.testing.expectEqual(payload.len, try reusable.decodedSize(encoded.frame));
            if (dict.id == 0) return; // An ID-less frame cannot select a catalog entry.
            try std.testing.expectError(error.NeedDictionary, Z.decodedFrameSizeWithOptions(encoded.frame, .{ .format = .magicless }));
            const wrong = Z.NativeDictionary.init(if (dict.id == 1) 2 else 1, dict.content);
            try std.testing.expectError(error.NeedDictionary, Z.decodeFrameAllocWithOptions(a, encoded.frame, .{ .format = .magicless, .dictionary = wrong }));
            const entries = [_]Z.NativeDictionary{dict};
            const catalog = Z.NativeDictionarySet.init(&entries);
            try h.check(Z, a, encoded.frame, payload, .{ .format = .magicless, .dictionary_set = catalog, .expected_output_len = payload.len });
            const missing_entries = [_]Z.NativeDictionary{wrong};
            const missing = Z.NativeDictionarySet.init(&missing_entries);
            try std.testing.expectError(error.NeedDictionary, Z.decodedFrameSizeWithOptions(encoded.frame, .{ .format = .magicless, .dictionary_set = missing }));
            for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
                // ID=1 has a three-byte complete header. A four-byte minimum
                // would accept payload before the dictionary suspension.
                var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .format = .magicless, .input_policy = policy, .expected_output_len = payload.len, .max_compressed_buffer_len = header.payload_offset });
                defer decoder.deinit();
                try std.testing.expectError(error.NeedDictionary, decoder.step(encoded.frame, &.{}));
                const accepted = decoder.last_step_progress.input_read;
                try std.testing.expectEqual(header.payload_offset, accepted);
                try std.testing.expectEqual(@as(core.StreamCount, accepted), decoder.snapshot().input_received);
                try std.testing.expectEqual(@as(?u32, dict.id), decoder.requiredDictionaryId());
                try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.snapshot().output_written);
                const before = decoder.snapshot();
                try std.testing.expectError(error.NeedDictionary, decoder.step("unconsumed", &.{}));
                try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
                try std.testing.expectEqual(core.Progress{}, decoder.last_step_progress);
                try std.testing.expectError(error.DictionaryMismatch, decoder.provideDictionary(wrong));
                try std.testing.expectEqual(@as(?u32, dict.id), decoder.requiredDictionaryId());
                try decoder.provideDictionary(dict);
                try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
                try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
                decoder.options.max_compressed_buffer_len = encoded.frame.len;
                const restored = try h.drive(a, &decoder, encoded.frame[accepted..], payload.len, 3, 1);
                defer a.free(restored.output);
                try std.testing.expectEqual(encoded.frame.len - accepted, restored.consumed);
                try std.testing.expectEqualSlices(u8, payload, restored.output);
                try std.testing.expectEqual(@as(core.StreamCount, encoded.frame.len), decoder.snapshot().input_received);
                try decoder.finish();
            }
        }
    };
}

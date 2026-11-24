const std = @import("std");
const core = @import("../../core.zig");
const a = std.testing.allocator;

pub fn contracts(comptime Z: type) !void {
    const hex = std.mem.trim(u8, @embedFile("../../zstd/testdata/libzstd-trained-repeat.dict.hex"), " \r\n\t");
    const bytes = try a.alloc(u8, hex.len / 2);
    defer a.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, hex);
    const parsed = try Z.NativeDictionary.initFromStandardDictionary(bytes);
    const good = parsed.dictionary;
    const payload = "stable";
    const encoded = try Z.encodeNativeFrameWithDictionaryAlloc(a, payload, .{
        .selection = .raw_or_rle,
        .content_checksum = true,
    }, good);
    defer a.free(encoded.frame);
    const header = try Z.inspectNativeFrameHeader(encoded.frame);
    try std.testing.expectEqual(good.id, header.dictionary_id);

    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        for ([_]bool{ false, true }) |metadata_only| {
            // Both descriptors are valid and have the requested ID. The
            // standard case overlaps only metadata, not dictionary history.
            const copy = try a.dupe(u8, bytes);
            defer a.free(copy);
            var raw: [payload.len + 1]u8 = @splat(0xa5);
            const output: []u8 = if (metadata_only) copy[0 .. payload.len + 1] else &raw;
            try std.testing.expect(parsed.view.content_offset >= output.len);
            const aliased = if (metadata_only)
                (try Z.NativeDictionary.initFromStandardDictionary(copy)).dictionary
            else
                Z.NativeDictionary.init(good.id, output);
            const before_bytes = output[0 .. payload.len + 1].*;
            var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{
                .input_policy = policy,
                .expected_output_len = payload.len,
            });
            defer decoder.deinit();
            try decoder.bindStableOutput(output);
            try std.testing.expectError(error.NeedDictionary, decoder.stepStable(encoded.frame));
            const before = decoder.snapshot();
            try std.testing.expectEqual(header.payload_offset, before.last_step_progress.input_read);
            try std.testing.expectEqual(@as(?u32, good.id), before.required_dictionary_id);

            try std.testing.expectError(error.InvalidBlockPlan, decoder.provideDictionary(aliased));
            const catalog = try Z.NativeDictionarySet.initChecked(&.{aliased});
            try std.testing.expectError(error.InvalidBlockPlan, decoder.provideDictionarySet(catalog));
            const refused = decoder.snapshot();
            try std.testing.expectEqual(before.required_dictionary_id, refused.required_dictionary_id);
            try std.testing.expectEqual(before.input_received, refused.input_received);
            try std.testing.expectEqual(before.output_written, refused.output_written);
            try std.testing.expectEqual(before.working_bytes, refused.working_bytes);
            try std.testing.expectEqual(before.peak_working_bytes, refused.peak_working_bytes);
            try std.testing.expectEqualDeep(core.Progress{}, refused.last_step_progress);
            try std.testing.expectEqualSlices(u8, &before_bytes, output);
            try std.testing.expectEqual(@as(usize, 0), decoder.stableOutput().len);

            const body = encoded.frame[header.payload_offset..];
            try std.testing.expectError(error.NeedDictionary, decoder.stepStable(body));
            try decoder.provideDictionary(good);
            const step = try decoder.stepStable(body);
            try std.testing.expectEqual(.done, step.status);
            try std.testing.expectEqual(body.len, step.progress.input_read);
            try decoder.finish();
            try std.testing.expectEqualStrings(payload, decoder.stableOutput());
            try std.testing.expectEqual(before_bytes[payload.len], output[payload.len]);
        }
    }
}

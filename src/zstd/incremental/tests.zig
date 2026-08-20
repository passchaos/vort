const std = @import("std");
const zstd = @import("../../zstd.zig");

test "Zstd incremental frame encoder round trips split raw RLE input" {
    const payload = ("incremental Zstd raw RLE payload " ** 5000) ++ ([_]u8{0} ** 256);
    var encoder = try zstd.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{
        .include_content_size = false,
        .content_checksum = true,
        .selection = .raw_or_rle,
        .block_size_max = 4096,
    });
    defer encoder.deinit();
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    var input_offset: usize = 0;
    var scratch: [17]u8 = undefined;
    while (input_offset < payload.len) {
        const end = @min(payload.len, input_offset + 211);
        const result = try encoder.step(payload[input_offset..end], &scratch);
        input_offset += result.progress.input_read;
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try zstd.decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    encoder.reset();
}

test "Zstd incremental frame encoder requires raw no-size mode" {
    try std.testing.expectError(error.InvalidBlockPlan, zstd.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{ .include_content_size = true }));
}

test "Zstd incremental frame encoder supports pledged content size" {
    const payload = "pledged Zstd content size" ** 80;
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(std.testing.allocator, .{ .include_content_size = true, .selection = .raw_or_rle }, payload.len);
    defer encoder.deinit();
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    var scratch: [41]u8 = undefined;
    var input_offset: usize = 0;
    while (input_offset < payload.len) {
        const result = try encoder.step(payload[input_offset..], &scratch);
        input_offset += result.progress.input_read;
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const header = try zstd.inspectNativeFrameHeader(frame.items);
    try std.testing.expectEqual(@as(?u64, payload.len), header.content_size);

    var mismatch = try zstd.NativeIncrementalFrameEncoder.initExactSize(std.testing.allocator, .{ .include_content_size = true, .selection = .raw_or_rle }, payload.len + 1);
    defer mismatch.deinit();
    input_offset = 0;
    while (input_offset < payload.len) {
        const result = try mismatch.step(payload[input_offset..], &scratch);
        input_offset += result.progress.input_read;
    }
    mismatch.finish();
    while (true) {
        if (mismatch.step("", &scratch)) |result| {
            try std.testing.expect(result.status == .need_output);
        } else |err| {
            try std.testing.expectEqual(error.SizeMismatch, err);
            break;
        }
    }
}

test "Zstd incremental frame encoder emits Dictionary ID metadata" {
    const payload = "dictionary-tagged Zstd stream" ** 32;
    const id: u32 = 0x1234abcd;
    var encoder = try zstd.NativeIncrementalFrameEncoder.initWithDictionary(std.testing.allocator, .{ .include_content_size = false, .selection = .raw_or_rle, .dictionary_id = id }, id);
    defer encoder.deinit();
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    var scratch: [43]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const result = try encoder.step(payload[offset..], &scratch);
        offset += result.progress.input_read;
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const header = try zstd.inspectNativeFrameHeader(frame.items);
    try std.testing.expectEqual(id, header.dictionary_id);
    const decoded = try zstd.decodeFrameAllocWithDictionary(std.testing.allocator, frame.items, zstd.NativeDictionary.init(id, "unused raw history"));
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "Zstd incremental frame encoder resolves dictionary set" {
    const dictionary = zstd.NativeDictionary.init(0x10203040, "dictionary-set metadata");
    const set = try zstd.NativeDictionarySet.initChecked(&.{dictionary});
    var encoder = try zstd.NativeIncrementalFrameEncoder.initWithDictionarySet(std.testing.allocator, .{ .include_content_size = false, .selection = .literal_only, .dictionary_id = dictionary.id }, set, dictionary.id);
    defer encoder.deinit();
    try std.testing.expectError(error.NeedDictionary, zstd.NativeIncrementalFrameEncoder.initWithDictionarySet(std.testing.allocator, .{ .include_content_size = false, .selection = .raw_or_rle, .dictionary_id = 7 }, set, 7));
    const payload = "prefix-dictionary-set metadata-suffix";
    const frame = try encodeSplit(&encoder, payload);
    defer std.testing.allocator.free(frame);
    const decoded = try zstd.decodeFrameAllocWithDictionarySet(std.testing.allocator, frame, set);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    encoder.reset();
}

test "Zstd incremental frame encoder emits entropy-coded blocks" {
    const payload = ("entropy entropy entropy: abcdefghijklmnopqrstuvwxyz\n" ** 96);
    var encoder = try zstd.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{
        .include_content_size = false,
        .content_checksum = true,
        .selection = .auto,
        .block_size_max = 1024,
    });
    defer encoder.deinit();
    const frame = try encodeSplit(&encoder, payload);
    defer std.testing.allocator.free(frame);

    var blocks = try zstd.iterateNativeFrameBlocks(frame);
    var compressed_count: usize = 0;
    while (try blocks.next()) |block| {
        if (block.block_type == .compressed) compressed_count += 1;
    }
    try std.testing.expect(compressed_count != 0);
    const decoded = try zstd.decodeFrameAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "Zstd incremental frame encoder references preset dictionary history" {
    const dictionary = zstd.NativeDictionary.init(0x5566_7788, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-tail";
    var encoder = try zstd.NativeIncrementalFrameEncoder.initWithPresetDictionary(std.testing.allocator, .{
        .include_content_size = false,
        .content_checksum = true,
        .selection = .literal_only,
        .dictionary_id = dictionary.id,
    }, dictionary);
    defer encoder.deinit();
    const frame = try encodeSplit(&encoder, payload);
    defer std.testing.allocator.free(frame);

    const first_block = try zstd.inspectNativeFrameFirstBlock(frame);
    try std.testing.expectEqual(zstd.NativeBlockType.compressed, first_block.block_type);
    const modes = try zstd.inspectNativeFrameBlockSequenceModes(frame, first_block);
    try std.testing.expect(modes.sequence_count != 0);
    const decoded = try zstd.decodeFrameAllocWithDictionary(std.testing.allocator, frame, dictionary);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "Zstd incremental frame encoder matches previous blocks" {
    const first = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@";
    const payload = first ++ first;
    var encoder = try zstd.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{
        .include_content_size = false,
        .content_checksum = true,
        .selection = .literal_only,
        .block_size_max = first.len,
    });
    defer encoder.deinit();
    const frame = try encodeSplit(&encoder, payload);
    defer std.testing.allocator.free(frame);

    var blocks = try zstd.iterateNativeFrameBlocks(frame);
    const first_block = (try blocks.next()).?;
    const second_block = (try blocks.next()).?;
    try std.testing.expectEqual(zstd.NativeBlockType.compressed, second_block.block_type);
    const modes = try zstd.inspectNativeFrameBlockSequenceModes(frame, second_block);
    try std.testing.expect(modes.sequence_count != 0);
    try std.testing.expect(second_block.payload_len < first_block.payload_len);
    try std.testing.expect((try blocks.next()) == null);

    const decoded = try zstd.decodeFrameAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    encoder.reset();
    const reset_frame = try encodeSplit(&encoder, first);
    defer std.testing.allocator.free(reset_frame);
    const reset_decoded = try zstd.decodeFrameAlloc(std.testing.allocator, reset_frame);
    defer std.testing.allocator.free(reset_decoded);
    try std.testing.expectEqualSlices(u8, first, reset_decoded);
}

test "Zstd incremental frame encoder emits multiple non-prefix history matches" {
    const first = "alpha-0123456789-omega-ABCDEFGHIJK-tail-1234567890";
    const second = "pfx-0123456789-mid-ABCDEFGHIJK-end-uvwxyz-XYZ-QWER";
    comptime std.debug.assert(first.len == second.len);
    const payload = first ++ second;
    var encoder = try zstd.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{
        .include_content_size = false,
        .content_checksum = false,
        .selection = .literal_only,
        .block_size_max = first.len,
    });
    defer encoder.deinit();
    const frame = try encodeSplit(&encoder, payload);
    defer std.testing.allocator.free(frame);

    var blocks = try zstd.iterateNativeFrameBlocks(frame);
    _ = (try blocks.next()).?;
    const second_block = (try blocks.next()).?;
    const modes = try zstd.inspectNativeFrameBlockSequenceModes(frame, second_block);
    try std.testing.expectEqual(@as(usize, 2), modes.sequence_count);
    const decoded = try zstd.decodeFrameAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "Zstd incremental frame encoder flushes and resumes through tiny output" {
    const first = "first flushed Zstd segment with repeated repeated text";
    const second = "second segment after flush reuses repeated repeated text";
    var encoder = try zstd.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{
        .include_content_size = false,
        .content_checksum = true,
        .selection = .literal_only,
        .block_size_max = 96,
    });
    defer encoder.deinit();
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    var scratch: [7]u8 = undefined;

    var result = try encoder.step(first, &scratch);
    try std.testing.expectEqual(first.len, result.progress.input_read);
    try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
        try std.testing.expectEqual(.need_output, result.status);
    }
    // The flushed prefix is a valid non-final frame prefix: its first block is
    // available for inspection even though finish has not written a last block.
    const first_block = try zstd.inspectNativeFrameFirstBlock(frame.items);
    try std.testing.expect(!first_block.last);

    var second_offset: usize = 0;
    while (second_offset < second.len) {
        result = try encoder.step(second[second_offset..], &scratch);
        second_offset += result.progress.input_read;
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    // An empty repeated flush must not add an empty block.
    const len_after_flush = frame.items.len;
    encoder.flush();
    result = try encoder.step("", &scratch);
    try std.testing.expectEqual(.need_input, result.status);
    try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
    try std.testing.expectEqual(len_after_flush, frame.items.len);

    encoder.finish();
    while (true) {
        result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try zstd.decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);

    encoder.reset();
    const reset_frame = try encodeSplit(&encoder, "after flush reset");
    defer std.testing.allocator.free(reset_frame);
    const reset_decoded = try zstd.decodeFrameAlloc(std.testing.allocator, reset_frame);
    defer std.testing.allocator.free(reset_decoded);
    try std.testing.expectEqualSlices(u8, "after flush reset", reset_decoded);
}

test "Zstd incremental encoder continues mixed dictionary frames" {
    const first = "first entropy Zstd frame alpha beta gamma" ** 32;
    const dictionary = zstd.NativeDictionary.init(0x5172_93a4, "second-zstd-dictionary-prefix");
    const second = "second-zstd-dictionary-prefix payload" ** 24;
    const first_options: zstd.NativeFrameOptions = .{
        .include_content_size = true,
        .content_checksum = true,
        .selection = .auto,
        .block_size_max = 1024,
    };
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(std.testing.allocator, first_options, first.len);
    defer encoder.deinit();
    const first_frame = try encodeSplit(&encoder, first);
    defer std.testing.allocator.free(first_frame);
    var second_options = first_options;
    second_options.selection = .literal_only;
    second_options.dictionary_id = dictionary.id;
    try encoder.nextFrameExactSizeWithPresetDictionary(second_options, second.len, dictionary);
    const second_frame = try encodeSplit(&encoder, second);
    defer std.testing.allocator.free(second_frame);
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().frame_count);
    try std.testing.expectEqual(first.len + second.len, encoder.snapshot().input_read);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first_frame);
    try stream.appendSlice(std.testing.allocator, second_frame);
    const set = try zstd.NativeDictionarySet.initChecked(&.{dictionary});
    const decoded = try zstd.decodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(
        std.testing.allocator,
        stream.items,
        set,
        first.len + second.len,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
}

fn encodeSplit(encoder: *zstd.NativeIncrementalFrameEncoder, payload: []const u8) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(std.testing.allocator);
    var scratch: [19]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const end = @min(payload.len, offset + 37);
        const result = try encoder.step(payload[offset..end], &scratch);
        offset += result.progress.input_read;
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    return try frame.toOwnedSlice(std.testing.allocator);
}

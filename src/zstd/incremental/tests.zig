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
    try std.testing.expectError(error.InvalidBlockPlan, zstd.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{}));
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
    var encoder = try zstd.NativeIncrementalFrameEncoder.initWithDictionarySet(std.testing.allocator, .{ .include_content_size = false, .selection = .raw_or_rle, .dictionary_id = dictionary.id }, set, dictionary.id);
    defer encoder.deinit();
    try std.testing.expectError(error.NeedDictionary, zstd.NativeIncrementalFrameEncoder.initWithDictionarySet(std.testing.allocator, .{ .include_content_size = false, .selection = .raw_or_rle, .dictionary_id = 7 }, set, 7));
    encoder.reset();
}

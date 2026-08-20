const std = @import("std");
const core = @import("../../core.zig");
const lz4 = @import("../../lz4.zig");

test "LZ4 incremental frame encoder round trips split linked input" {
    const payload = "incremental linked LZ4 encode payload " ** 3000;
    var encoder = try lz4.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{
        .include_content_size = false,
        .block_size_id = .max64kb,
        .block_mode = .linked,
        .block_checksum = true,
        .content_checksum = true,
    });
    defer encoder.deinit();
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    var input_offset: usize = 0;
    var scratch: [13]u8 = undefined;
    while (input_offset < payload.len) {
        const end = @min(payload.len, input_offset + 257);
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
    const decoded = try lz4.decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    encoder.reset();
}

test "LZ4 incremental frame encoder requires unknown content size" {
    try std.testing.expectError(error.InvalidBlockPlan, lz4.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{}));
}

test "LZ4 incremental frame encoder supports pledged content size" {
    const payload = "pledged LZ4 content size" ** 64;
    var encoder = try lz4.NativeIncrementalFrameEncoder.initExactSize(std.testing.allocator, .{ .include_content_size = true }, payload.len);
    defer encoder.deinit();
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    var scratch: [37]u8 = undefined;
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
    const header = try lz4.inspectNativeFrameHeader(frame.items);
    try std.testing.expectEqual(@as(?u64, payload.len), header.expected_content_size);

    var mismatch = try lz4.NativeIncrementalFrameEncoder.initExactSize(std.testing.allocator, .{ .include_content_size = true }, payload.len + 1);
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

test "LZ4 incremental frame encoder supports preset dictionary" {
    const dictionary = "shared LZ4 dictionary phrase " ** 32;
    const payload = dictionary ++ "payload";
    const id: u32 = 0x1234abcd;
    var encoder = try lz4.NativeIncrementalFrameEncoder.initWithDictionary(std.testing.allocator, .{ .include_content_size = false, .dictionary_id = id }, id, dictionary);
    defer encoder.deinit();
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    var scratch: [29]u8 = undefined;
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
    const decoded = try lz4.decodeNativeFrameAllocWithDictionary(std.testing.allocator, frame.items, lz4.NativeDictionary.init(id, dictionary));
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "LZ4 incremental frame encoder resolves dictionary set" {
    const dictionary = lz4.NativeDictionary.init(0x10203040, "dictionary-set prefix");
    const set = try lz4.NativeDictionarySet.initChecked(&.{dictionary});
    var encoder = try lz4.NativeIncrementalFrameEncoder.initWithDictionarySet(std.testing.allocator, .{ .include_content_size = false, .dictionary_id = dictionary.id }, set, dictionary.id);
    defer encoder.deinit();
    var missing_options: lz4.NativeFrameOptions = .{ .include_content_size = false, .dictionary_id = 7 };
    try std.testing.expectError(error.NeedDictionary, lz4.NativeIncrementalFrameEncoder.initWithDictionarySet(std.testing.allocator, missing_options, set, 7));
    missing_options.dictionary_id = dictionary.id;
    encoder.reset();
}

test "LZ4 incremental encoder continues mixed dictionary frames" {
    const first = "first independent LZ4 frame" ** 32;
    const dictionary = lz4.NativeDictionary.init(0x31415926, "second-frame-dictionary-prefix");
    const second = "second-frame-dictionary-prefix payload" ** 24;
    const first_options: lz4.NativeFrameOptions = .{
        .include_content_size = true,
        .block_mode = .independent,
        .content_checksum = true,
    };
    var encoder = try lz4.NativeIncrementalFrameEncoder.initExactSize(std.testing.allocator, first_options, first.len);
    defer encoder.deinit();
    const first_frame = try encodeIncrementalLz4FrameTest(&encoder, first);
    defer std.testing.allocator.free(first_frame);
    var second_options = first_options;
    second_options.block_mode = .linked;
    second_options.block_checksum = true;
    second_options.dictionary_id = dictionary.id;
    try encoder.nextFrameExactSizeWithDictionary(second_options, second.len, dictionary.id, dictionary.content);
    const second_frame = try encodeIncrementalLz4FrameTest(&encoder, second);
    defer std.testing.allocator.free(second_frame);
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().frame_count);
    try std.testing.expectEqual(first.len + second.len, encoder.snapshot().input_read);

    var concatenated: std.ArrayList(u8) = .empty;
    defer concatenated.deinit(std.testing.allocator);
    try concatenated.appendSlice(std.testing.allocator, first_frame);
    try concatenated.appendSlice(std.testing.allocator, second_frame);
    const set = try lz4.NativeDictionarySet.initChecked(&.{dictionary});
    const decoded = try lz4.decodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(
        std.testing.allocator,
        concatenated.items,
        set,
        first.len + second.len,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
}

fn encodeIncrementalLz4FrameTest(encoder: *lz4.NativeIncrementalFrameEncoder, payload: []const u8) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(std.testing.allocator);
    var scratch: [19]u8 = undefined;
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
    return frame.toOwnedSlice(std.testing.allocator);
}

test "LZ4 incremental frame encoder flushes and resumes" {
    const first = "first linked LZ4 flush segment repeated repeated";
    const second = "second linked segment reuses repeated repeated";
    var encoder = try lz4.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{
        .include_content_size = false,
        .block_size_id = .max64kb,
        .block_mode = .linked,
        .block_checksum = true,
        .content_checksum = true,
    });
    defer encoder.deinit();
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    var scratch: [7]u8 = undefined;

    var first_offset: usize = 0;
    var result: core.StepResult = undefined;
    while (first_offset < first.len) {
        result = try encoder.step(first[first_offset..], &scratch);
        first_offset += result.progress.input_read;
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
        try std.testing.expectEqual(.need_output, result.status);
    }
    const first_block = (try lz4.inspectNativeFrameFirstBlock(frame.items)).?;
    try std.testing.expect(first_block.payload_offset < frame.items.len);

    var offset: usize = 0;
    while (offset < second.len) {
        result = try encoder.step(second[offset..], &scratch);
        offset += result.progress.input_read;
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    const flushed_len = frame.items.len;
    encoder.flush();
    result = try encoder.step("", &scratch);
    try std.testing.expectEqual(.need_input, result.status);
    try std.testing.expectEqual(flushed_len, frame.items.len);

    encoder.finish();
    while (true) {
        result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try lz4.decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
    encoder.reset();
}

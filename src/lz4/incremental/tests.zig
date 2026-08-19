const std = @import("std");
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

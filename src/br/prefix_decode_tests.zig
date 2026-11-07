const std = @import("std");

const allocator = std.testing.allocator;

pub fn contracts(comptime B: type) !void {
    try firstStreamAndStrictRegression(B);
    try incrementalBoundaryOracle(B);
    try exactLimitedAndAppend(B);
    try chunkedPrefixes(B);
    try publicSurfaceMatrix(B);
    try corruptionAndTruncation(B);
    try metadataLargeAndDictionary(B);
}

fn publicSurfaceMatrix(comptime B: type) !void {
    const plain = "prefix surface";
    const wire = try B.encodeStoredStreamAlloc(allocator, plain);
    defer allocator.free(wire);
    const joined = try std.mem.concat(allocator, u8, &.{ wire, "tail" });
    defer allocator.free(joined);
    var output: [plain.len]u8 = undefined;

    const into_options = try B.decodeStreamPrefixIntoWithOptions(joined, &output, .{});
    const into_limited_options = try B.decodeStreamPrefixIntoLimitedWithOptions(joined, &output, plain.len, .{});
    const into_exact_options = try B.decodeStreamPrefixIntoExactSizeWithOptions(joined, &output, plain.len, .{});
    try std.testing.expectEqual(wire.len, into_options.input_read);
    try std.testing.expectEqual(into_options, into_limited_options);
    try std.testing.expectEqual(into_options, into_exact_options);

    const size_options = try B.decodedStreamPrefixSizeWithOptions(joined, .{});
    const size_limited_options = try B.decodedStreamPrefixSizeLimitedWithOptions(joined, plain.len, .{});
    try std.testing.expectEqual(size_options, size_limited_options);

    const owned_options = try B.decodeStreamPrefixAllocWithOptions(allocator, joined, .{});
    defer owned_options.deinit(allocator);
    const owned_limited = try B.decodeStreamPrefixAllocLimited(allocator, joined, plain.len);
    defer owned_limited.deinit(allocator);
    const owned_limited_options = try B.decodeStreamPrefixAllocLimitedWithOptions(allocator, joined, plain.len, .{});
    defer owned_limited_options.deinit(allocator);
    const owned_exact_options = try B.decodeStreamPrefixAllocExactSizeWithOptions(allocator, joined, plain.len, .{});
    defer owned_exact_options.deinit(allocator);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    _ = try B.decodeStreamPrefixAppendWithOptions(allocator, &appended, joined, .{});
    appended.clearRetainingCapacity();
    _ = try B.decodeStreamPrefixAppendExactSize(allocator, &appended, joined, plain.len);
    appended.clearRetainingCapacity();
    _ = try B.decodeStreamPrefixAppendExactSizeWithOptions(allocator, &appended, joined, plain.len, .{});

    const chunks = [_][]const u8{ joined[0..1], joined[1..wire.len], joined[wire.len..] };
    const scratch = try allocator.alloc(u8, joined.len);
    defer allocator.free(scratch);
    _ = try B.decodeStreamPrefixChunksIntoWithOptions(&chunks, scratch, &output, .{});
    _ = try B.decodeStreamPrefixChunksIntoLimited(&chunks, scratch, &output, plain.len);
    _ = try B.decodeStreamPrefixChunksIntoLimitedWithOptions(&chunks, scratch, &output, plain.len, .{});
    _ = try B.decodeStreamPrefixChunksIntoExactSizeWithOptions(&chunks, scratch, &output, plain.len, .{});
    _ = try B.decodedStreamPrefixChunksSizeWithOptions(&chunks, scratch, .{});
    _ = try B.decodedStreamPrefixChunksSizeLimited(&chunks, scratch, plain.len);
    _ = try B.decodedStreamPrefixChunksSizeLimitedWithOptions(&chunks, scratch, plain.len, .{});
    const chunk_owned_options = try B.decodeStreamPrefixChunksAllocWithOptions(allocator, &chunks, scratch, .{});
    defer chunk_owned_options.deinit(allocator);
    const chunk_owned_limited = try B.decodeStreamPrefixChunksAllocLimited(allocator, &chunks, scratch, plain.len);
    defer chunk_owned_limited.deinit(allocator);
    const chunk_owned_limited_options = try B.decodeStreamPrefixChunksAllocLimitedWithOptions(allocator, &chunks, scratch, plain.len, .{});
    defer chunk_owned_limited_options.deinit(allocator);
    const chunk_owned_exact_options = try B.decodeStreamPrefixChunksAllocExactSizeWithOptions(allocator, &chunks, scratch, plain.len, .{});
    defer chunk_owned_exact_options.deinit(allocator);
    appended.clearRetainingCapacity();
    _ = try B.decodeStreamPrefixChunksAppendWithOptions(allocator, &appended, &chunks, scratch, .{});
    appended.clearRetainingCapacity();
    _ = try B.decodeStreamPrefixChunksAppendLimited(allocator, &appended, &chunks, scratch, plain.len);
    appended.clearRetainingCapacity();
    _ = try B.decodeStreamPrefixChunksAppendLimitedWithOptions(allocator, &appended, &chunks, scratch, plain.len, .{});
    appended.clearRetainingCapacity();
    _ = try B.decodeStreamPrefixChunksAppendExactSize(allocator, &appended, &chunks, scratch, plain.len);
    appended.clearRetainingCapacity();
    _ = try B.decodeStreamPrefixChunksAppendExactSizeWithOptions(allocator, &appended, &chunks, scratch, plain.len, .{});
}

fn firstStreamAndStrictRegression(comptime B: type) !void {
    const first_plain = "first Brotli member";
    const second_plain = "second compressed Brotli member " ** 8;
    const first = try B.encodeStoredStreamAlloc(allocator, first_plain);
    defer allocator.free(first);
    const second = try B.encodePlannedStreamAlloc(allocator, second_plain);
    defer allocator.free(second);
    const joined = try std.mem.concat(allocator, u8, &.{ first, second, "\xaa\xbb" });
    defer allocator.free(joined);

    var output: [second_plain.len]u8 = @splat(0xa5);
    const first_result = try B.decodeStreamPrefixInto(joined, &output);
    try std.testing.expectEqual(first.len, first_result.input_read);
    try std.testing.expectEqual(first_plain.len, first_result.output_written);
    try std.testing.expectEqualStrings(first_plain, output[0..first_result.output_written]);
    try std.testing.expectEqual(@as(u8, 0xa5), output[first_result.output_written]);
    try std.testing.expectError(error.TrailingData, B.decodeStreamInto(joined, &output));
    const strict_owned = B.decodeStreamAlloc(allocator, joined);
    if (strict_owned) |bytes| {
        allocator.free(bytes);
        return error.ExpectedTrailingData;
    } else |err| try std.testing.expectEqual(error.TrailingData, err);

    const second_result = try B.decodeStreamPrefixInto(joined[first_result.input_read..], &output);
    try std.testing.expectEqual(second.len, second_result.input_read);
    try std.testing.expectEqual(second_plain.len, second_result.output_written);
    try std.testing.expectEqualStrings(second_plain, output[0..second_result.output_written]);

    const size = try B.decodedStreamPrefixSize(joined);
    try std.testing.expectEqual(first.len, size.input_read);
    try std.testing.expectEqual(@as(B.Counter, first_plain.len), size.decoded_bytes);

    const owned = try B.decodeStreamPrefixAlloc(allocator, joined);
    defer owned.deinit(allocator);
    try std.testing.expectEqual(first.len, owned.input_read);
    try std.testing.expectEqual(owned.bytes.len, owned.output_written);
    try std.testing.expectEqualStrings(first_plain, owned.bytes);

    const sentinel = try std.mem.concat(allocator, u8, &.{ first, "\xffinvalid suffix" });
    defer allocator.free(sentinel);
    const sentinel_result = try B.decodeStreamPrefixInto(sentinel, &output);
    try std.testing.expectEqual(first.len, sentinel_result.input_read);
    try std.testing.expectEqualStrings(first_plain, output[0..sentinel_result.output_written]);

    const empty = try B.encodeStoredStreamAlloc(allocator, "");
    defer allocator.free(empty);
    const empty_joined = try std.mem.concat(allocator, u8, &.{ empty, second });
    defer allocator.free(empty_joined);
    var no_output: [0]u8 = .{};
    const empty_result = try B.decodeStreamPrefixInto(empty_joined, &no_output);
    try std.testing.expectEqual(empty.len, empty_result.input_read);
    try std.testing.expectEqual(@as(usize, 0), empty_result.output_written);
}

fn incrementalBoundaryOracle(comptime B: type) !void {
    const plain = "incremental Brotli boundary oracle" ** 3;
    const wire = try B.encodePlannedStreamAlloc(allocator, plain);
    defer allocator.free(wire);
    const suffix = "NEXT-BROTLI-MEMBER";
    const joined = try std.mem.concat(allocator, u8, &.{ wire, suffix });
    defer allocator.free(joined);
    var history: [65_520]u8 = undefined;
    var decoder = B.IncrementalCopyStreamDecoder.initWithOptions(&history, .{
        .expected_output_len = plain.len,
        .allow_trailing_data = true,
    });
    var output: [plain.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const output_end = @min(output.len, output_offset + 5);
        const step = try decoder.step(joined[input_offset..], output[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
        if (step.status == .done) break;
    }
    const retained = decoder.trailingInput();
    const semantic_input_read = input_offset - retained.len;
    const one_shot = try B.decodeStreamPrefixInto(joined, &output);
    try std.testing.expectEqual(semantic_input_read, one_shot.input_read);
    try std.testing.expectEqual(wire.len, semantic_input_read);
}

fn exactLimitedAndAppend(comptime B: type) !void {
    const plain = "Brotli prefix output policies" ** 6;
    const wire = try B.encodePlannedStreamAlloc(allocator, plain);
    defer allocator.free(wire);
    const joined = try std.mem.concat(allocator, u8, &.{ wire, "suffix" });
    defer allocator.free(joined);
    var output: [plain.len + 3]u8 = @splat(0xa5);

    const exact = try B.decodeStreamPrefixIntoExactSize(joined, &output, plain.len);
    try std.testing.expectEqual(wire.len, exact.input_read);
    try std.testing.expectEqual(plain.len, exact.output_written);
    try std.testing.expectError(error.SizeMismatch, B.decodeStreamPrefixIntoExactSize(joined, &output, plain.len + 1));
    try std.testing.expectError(error.SizeMismatch, B.decodeStreamPrefixIntoExactSize(joined, &output, plain.len - 1));
    try std.testing.expectError(error.OutputTooSmall, B.decodeStreamPrefixIntoExactSize(joined, output[0 .. plain.len - 1], plain.len));

    @memset(&output, 0xa5);
    try std.testing.expectError(error.OutputLimitExceeded, B.decodeStreamPrefixIntoLimited(joined, &output, plain.len - 1));
    try std.testing.expect(std.mem.allEqual(u8, &output, 0xa5));
    const limited = try B.decodeStreamPrefixIntoLimited(joined, &output, plain.len);
    try std.testing.expectEqual(wire.len, limited.input_read);
    try std.testing.expectEqualStrings(plain, output[0..limited.output_written]);
    @memset(&output, 0xa5);
    try std.testing.expectError(error.OutputTooSmall, B.decodeStreamPrefixIntoLimited(joined, output[0 .. plain.len - 1], plain.len));
    try std.testing.expect(std.mem.allEqual(u8, &output, 0xa5));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "saved:");
    const append_result = try B.decodeStreamPrefixAppend(allocator, &appended, joined);
    try std.testing.expectEqual(wire.len, append_result.input_read);
    try std.testing.expectEqualStrings("saved:" ++ plain, appended.items);
    const saved_len = appended.items.len;
    try std.testing.expectError(error.OutputLimitExceeded, B.decodeStreamPrefixAppendLimited(allocator, &appended, joined, plain.len - 1));
    try std.testing.expectEqual(saved_len, appended.items.len);
    try std.testing.expectError(error.TrailingData, B.decodeStreamAppend(allocator, &appended, joined));
    try std.testing.expectEqual(saved_len, appended.items.len);

    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, B.decodeStreamPrefixAlloc(failing.allocator(), joined));
}

fn chunkedPrefixes(comptime B: type) !void {
    const first_plain = "chunked first Brotli stream" ** 3;
    const second_plain = "second";
    const first = try B.encodePlannedStreamAlloc(allocator, first_plain);
    defer allocator.free(first);
    const second = try B.encodeStoredStreamAlloc(allocator, second_plain);
    defer allocator.free(second);
    const joined = try std.mem.concat(allocator, u8, &.{ first, second });
    defer allocator.free(joined);

    const chunks = try byteChunks(joined);
    defer allocator.free(chunks);
    const scratch = try allocator.alloc(u8, joined.len);
    defer allocator.free(scratch);
    var output: [first_plain.len]u8 = undefined;
    const result = try B.decodeStreamPrefixChunksInto(chunks, scratch, &output);
    try std.testing.expectEqual(first.len, result.input_read);
    try std.testing.expectEqualStrings(first_plain, output[0..result.output_written]);

    const size = try B.decodedStreamPrefixChunksSize(chunks, scratch);
    try std.testing.expectEqual(first.len, size.input_read);
    try std.testing.expectEqual(@as(B.Counter, first_plain.len), size.decoded_bytes);
    const owned = try B.decodeStreamPrefixChunksAllocExactSize(allocator, chunks, scratch, first_plain.len);
    defer owned.deinit(allocator);
    try std.testing.expectEqualStrings(first_plain, owned.bytes);
    try std.testing.expectError(error.OutputTooSmall, B.decodeStreamPrefixChunksInto(chunks, scratch[0 .. scratch.len - 1], &output));
    try std.testing.expectError(error.TrailingData, B.decodeStreamChunksInto(chunks, scratch, &output));
}

fn corruptionAndTruncation(comptime B: type) !void {
    const plain = "truncated Brotli prefix";
    const wire = try B.encodeStoredStreamAlloc(allocator, plain);
    defer allocator.free(wire);
    var output: [plain.len]u8 = undefined;
    for (0..wire.len) |cut| {
        try std.testing.expectError(error.TruncatedFrame, B.decodeStreamPrefixInto(wire[0..cut], &output));
    }

    const corrupt = try allocator.dupe(u8, wire);
    defer allocator.free(corrupt);
    corrupt[corrupt.len - 1] |= 0x80;
    try std.testing.expectError(error.CorruptFrame, B.decodeStreamPrefixInto(corrupt, &output));

    const corrupt_with_valid = try std.mem.concat(allocator, u8, &.{ corrupt, wire });
    defer allocator.free(corrupt_with_valid);
    try std.testing.expectError(error.CorruptFrame, B.decodeStreamPrefixInto(corrupt_with_valid, &output));
}

fn metadataLargeAndDictionary(comptime B: type) !void {
    const metadata_plain = "metadata prefix payload" ** 4;
    const metadata_wire = try B.encodeStoredStreamWithOptionsAlloc(allocator, metadata_plain, .{ .metadata = "metadata-before-payload" });
    defer allocator.free(metadata_wire);
    const metadata_joined = try std.mem.concat(allocator, u8, &.{ metadata_wire, "tail" });
    defer allocator.free(metadata_joined);
    var metadata_output: [metadata_plain.len]u8 = undefined;
    const metadata_result = try B.decodeStreamPrefixInto(metadata_joined, &metadata_output);
    try std.testing.expectEqual(metadata_wire.len, metadata_result.input_read);
    try std.testing.expectEqualStrings(metadata_plain, &metadata_output);

    const large = try allocator.alloc(u8, 24 * 1024);
    defer allocator.free(large);
    const pattern = "large Brotli prefix threshold\n";
    for (large, 0..) |*byte, index| byte.* = pattern[index % pattern.len];
    const large_wire = try B.encodeStoredStreamAlloc(allocator, large);
    defer allocator.free(large_wire);
    const large_joined = try std.mem.concat(allocator, u8, &.{ large_wire, "tail" });
    defer allocator.free(large_joined);
    const large_output = try allocator.alloc(u8, large.len);
    defer allocator.free(large_output);
    const large_result = try B.decodeStreamPrefixInto(large_joined, large_output);
    try std.testing.expectEqual(large_wire.len, large_result.input_read);
    try std.testing.expectEqualSlices(u8, large, large_output);

    const wide_wire = try B.encodeStoredStreamWithOptionsAlloc(allocator, "wide", .{ .large_window = true, .window_bits = 25 });
    defer allocator.free(wide_wire);
    const wide_joined = try std.mem.concat(allocator, u8, &.{ wide_wire, "tail" });
    defer allocator.free(wide_joined);
    var wide_output: [4]u8 = undefined;
    try std.testing.expectError(error.CorruptFrame, B.decodeStreamPrefixInto(wide_joined, &wide_output));
    const wide_result = try B.decodeStreamPrefixIntoWithOptions(wide_joined, &wide_output, .{ .allow_large_window = true });
    try std.testing.expectEqual(wide_wire.len, wide_result.input_read);
    try std.testing.expectEqualStrings("wide", &wide_output);

    var dictionary_bytes: [512]u8 = undefined;
    var state: u32 = 0x9e37_79b9;
    for (&dictionary_bytes) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const prefixes = [_][]const u8{ dictionary_bytes[0..173], dictionary_bytes[173..] };
    const dictionary = B.SharedDictionary{ .raw_prefixes = &prefixes };
    const dictionary_wire = try B.encodePlannedStreamWithOptionsAlloc(allocator, &dictionary_bytes, .{ .level = .fast, .shared_dictionary = dictionary });
    defer allocator.free(dictionary_wire);
    const dictionary_joined = try std.mem.concat(allocator, u8, &.{ dictionary_wire, "tail" });
    defer allocator.free(dictionary_joined);
    var dictionary_output: [dictionary_bytes.len]u8 = undefined;
    try std.testing.expectError(error.UnsupportedBrotliFeature, B.decodeStreamPrefixInto(dictionary_joined, &dictionary_output));
    const dictionary_result = try B.decodeStreamPrefixIntoWithOptions(dictionary_joined, &dictionary_output, .{ .shared_dictionary = dictionary });
    try std.testing.expectEqual(dictionary_wire.len, dictionary_result.input_read);
    try std.testing.expectEqualSlices(u8, &dictionary_bytes, &dictionary_output);
}

fn byteChunks(bytes: []const u8) ![][]const u8 {
    const chunks = try allocator.alloc([]const u8, bytes.len * 2 + 1);
    var index: usize = 0;
    for (bytes, 0..) |_, byte_index| {
        chunks[index] = bytes[byte_index .. byte_index + 1];
        chunks[index + 1] = bytes[byte_index + 1 .. byte_index + 1];
        index += 2;
    }
    chunks[index] = bytes[bytes.len..];
    return chunks;
}

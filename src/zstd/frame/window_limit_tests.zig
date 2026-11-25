const std = @import("std");
const Count = @import("../../core.zig").StreamCount;
const testing = std.testing;
const a = testing.allocator;

const magic = "\x28\xb5\x2f\xfd";
const narrow_payload = "one";
const narrow_frame = magic ++ "\x20\x03\x19\x00\x00" ++ narrow_payload;
const wide_payload = "large";
const wide_block = "\x29\x00\x00" ++ wide_payload;
// Non-single-segment, no content size: the descriptor is 1 KiB plus 1/8.
const wide_window = 1152;
const wide_header = magic ++ "\x00\x01";
const wide_frame = wide_header ++ wide_block;
// The complete header includes the dictionary ID (7) and four-byte FCS (5).
const dictionary_header = magic ++ "\x81\x01\x07\x05\x00\x00\x00";
const dictionary_frame = dictionary_header ++ wide_block;
const seed = "seed";
const canary: u8 = 0xa5;

// The skippable payload itself looks like an oversized data header. A cap of
// zero still admits it, and a later data frame must be checked independently.
const skippable = "\x5d\x2a\x4d\x18\x06\x00\x00\x00" ++ wide_header;
const concatenated = narrow_frame ++ skippable ++ wide_frame;

pub fn contracts(comptime Z: type) !void {
    try testing.expectEqual(std.math.maxInt(Count), (Z.FrameDecodeOptions{}).max_window_size);
    try contiguousAdmission(Z);
    try concatenatedAndLegacy(Z);
    try wideSingleSegment(Z);
    try reusableAdmission(Z);
    try prefixLifetime(Z);
    try chunkAdmission(Z);
}

fn failingAllocator() testing.FailingAllocator {
    return testing.FailingAllocator.init(a, .{ .fail_index = 0, .resize_fail_index = 0 });
}

fn expectNoAllocation(failing: testing.FailingAllocator) !void {
    try testing.expect(!failing.has_induced_failure);
    try testing.expectEqual(@as(usize, 0), failing.allocations);
}

fn seededList() !std.ArrayList(u8) {
    var out: std.ArrayList(u8) = .empty;
    try out.ensureTotalCapacityPrecise(a, seed.len + narrow_payload.len + wide_payload.len);
    out.appendSliceAssumeCapacity(seed);
    @memset(out.unusedCapacitySlice(), canary);
    return out;
}

fn expectUnchangedList(before: std.ArrayList(u8), after: std.ArrayList(u8)) !void {
    try testing.expectEqual(before.items.ptr, after.items.ptr);
    try testing.expectEqual(before.capacity, after.capacity);
    try testing.expectEqualStrings(seed, after.items);
    try testing.expect(std.mem.allEqual(u8, after.unusedCapacitySlice(), canary));
}

fn expectRejected(comptime Z: type, expected: Z.Error, frame: []const u8, options: Z.FrameDecodeOptions) !void {
    var failing = failingAllocator();
    const no_alloc = failing.allocator();
    var output: [narrow_payload.len + wide_payload.len]u8 = @splat(canary);
    var out = try seededList();
    defer out.deinit(a);
    const before = out;

    try testing.expectError(expected, Z.decodedFrameSizeWithOptions(frame, options));
    try testing.expectError(expected, Z.decodeFrameAllocWithOptions(no_alloc, frame, options));
    try testing.expectError(expected, Z.decodeFrameIntoWithOptions(no_alloc, frame, &output, options));
    try testing.expectError(expected, Z.decodeFrameAppendWithOptions(no_alloc, &out, frame, options));
    try testing.expect(std.mem.allEqual(u8, &output, canary));
    try expectUnchangedList(before, out);
    try expectNoAllocation(failing);
}

fn contiguousAdmission(comptime Z: type) !void {
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        const start: usize = if (format == .magicless) magic.len else 0;
        const capped: Z.FrameDecodeOptions = .{ .format = format, .max_window_size = wide_window - 1 };
        const exact: Z.FrameDecodeOptions = .{ .format = format, .max_window_size = wide_window, .max_output_len = wide_payload.len };

        // Missing dictionary and missing block bytes cannot mask a complete,
        // oversized header. An incomplete header must still report truncation.
        try expectRejected(Z, error.OutputLimitExceeded, dictionary_header[start..], capped);
        try expectRejected(Z, error.TruncatedFrame, dictionary_header[start .. dictionary_header.len - 1], capped);
        try testing.expectError(error.NeedDictionary, Z.decodedFrameSizeWithOptions(dictionary_header[start..], exact));
        try testing.expectError(error.TruncatedFrame, Z.decodedFrameSizeWithOptions(wide_header[start..], exact));

        try expectRejected(Z, error.OutputLimitExceeded, wide_frame[start..], capped);
        try testing.expectEqual(@as(Count, wide_payload.len), try Z.decodedFrameSizeWithOptions(wide_frame[start..], exact));
        const owned = try Z.decodeFrameAllocWithOptions(a, wide_frame[start..], exact);
        defer a.free(owned);
        try testing.expectEqualStrings(wide_payload, owned);
        var output: [wide_payload.len + 1]u8 = @splat(canary);
        try testing.expectEqual(@as(usize, wide_payload.len), try Z.decodeFrameIntoWithOptions(a, wide_frame[start..], &output, exact));
        try testing.expectEqualStrings(wide_payload, output[0..wide_payload.len]);
        try testing.expectEqual(canary, output[wide_payload.len]);
        var out = try seededList();
        defer out.deinit(a);
        try testing.expectEqual(@as(usize, wide_payload.len), try Z.decodeFrameAppendWithOptions(a, &out, wide_frame[start..], exact));
        try testing.expectEqualStrings(seed ++ wide_payload, out.items);

        var single = exact;
        single.max_window_size = narrow_payload.len;
        const payload = try Z.decodeFrameAllocWithOptions(a, narrow_frame[start..], single);
        defer a.free(payload);
        try testing.expectEqualStrings(narrow_payload, payload);
        single.max_window_size -= 1;
        try expectRejected(Z, error.OutputLimitExceeded, narrow_frame[start..], single);
    }
}

fn concatenatedAndLegacy(comptime Z: type) !void {
    try expectRejected(Z, error.OutputLimitExceeded, concatenated, .{ .max_window_size = narrow_payload.len });
    try testing.expectEqual(@as(Count, 0), try Z.decodedFrameSizeWithOptions(skippable, .{ .max_window_size = 0 }));
    const empty_single_segment = magic ++ "\x20\x00\x01\x00\x00";
    try testing.expectEqual(@as(Count, 0), try Z.decodedFrameSizeWithOptions(empty_single_segment, .{ .max_window_size = 0 }));
    try testing.expectEqual(@as(Count, 2 * narrow_payload.len), try Z.decodedFrameSizeWithOptions(narrow_frame ++ skippable ++ narrow_frame, .{ .max_window_size = narrow_payload.len }));

    const expected = narrow_payload ++ wide_payload;
    const decoded = try Z.decodeFrameAllocWithOptions(a, concatenated, .{ .max_window_size = wide_window });
    defer a.free(decoded);
    try testing.expectEqualStrings(expected, decoded);

    // No window restriction is introduced by legacy output-length APIs.
    const legacy = try Z.decodeFrameAllocLimited(a, concatenated, expected.len);
    defer a.free(legacy);
    try testing.expectEqualStrings(expected, legacy);
    try testing.expectEqual(@as(Count, expected.len), try Z.decodedFrameSize(concatenated));
    var output: [expected.len]u8 = undefined;
    try testing.expectEqual(@as(usize, expected.len), try Z.decodeFrameInto(concatenated, &output));
    try testing.expectEqualStrings(expected, &output);
}

fn wideSingleSegment(comptime Z: type) !void {
    // Eight-byte single-segment FCS advertises a 4 GiB window, greater than
    // maxInt(usize) on 32-bit x86. Do not allocate or narrow it to compare it.
    const advertised: Count = @as(Count, 1) << 32;
    const header = magic ++ "\xe0\x00\x00\x00\x00\x01\x00\x00\x00";
    try expectRejected(Z, error.OutputLimitExceeded, header, .{ .max_window_size = advertised - 1 });
    try testing.expectError(error.TruncatedFrame, Z.decodedFrameSizeWithOptions(header, .{ .max_window_size = advertised }));
}

fn reusableAdmission(comptime Z: type) !void {
    var failing = failingAllocator();
    var decoder = Z.NativeFrameDecoder.initWithOptions(failing.allocator(), .{ .max_window_size = wide_window - 1 });
    defer decoder.deinit();
    var output: [wide_payload.len]u8 = @splat(canary);
    var out = try seededList();
    defer out.deinit(a);
    const before = out;

    // The window cap is the only configured option. These calls must not
    // silently use the fast legacy path that accepts this complete raw frame.
    try testing.expectError(error.OutputLimitExceeded, decoder.decodedSize(wide_frame));
    try testing.expectError(error.OutputLimitExceeded, decoder.decodeAlloc(wide_frame));
    try testing.expectError(error.OutputLimitExceeded, decoder.decodeIntoSlice(wide_frame, &output));
    try testing.expectError(error.OutputLimitExceeded, decoder.decodeAppend(&out, wide_frame));
    try testing.expectError(error.OutputLimitExceeded, decoder.decodeScratch(wide_frame));
    try testing.expect(std.mem.allEqual(u8, &output, canary));
    try expectUnchangedList(before, out);
    try expectNoAllocation(failing);

    // Allow allocation for a normal retry on the same decoder.
    failing.fail_index = std.math.maxInt(usize);
    try testing.expectEqual(@as(usize, narrow_payload.len), try decoder.decodeIntoSlice(narrow_frame, &output));
    try testing.expectEqualStrings(narrow_payload, output[0..narrow_payload.len]);
    try testing.expectError(error.OutputLimitExceeded, decoder.decodedSize(wide_frame));
}

fn prefixLifetime(comptime Z: type) !void {
    const exact: Z.FrameDecodeOptions = .{ .max_window_size = wide_window };
    const capped: Z.FrameDecodeOptions = .{ .max_window_size = wide_window - 1 };
    const prefix = Z.NativeDictionary.init(7, "borrowed dictionary history");
    var decoder = Z.NativeFrameDecoder.initWithOptions(a, exact);
    defer decoder.deinit();
    var output: [wide_payload.len]u8 = @splat(canary);
    try decoder.setPrefixWithDictionary(prefix);

    try testing.expectError(error.OutputLimitExceeded, decoder.decodedSizeWithOptions(dictionary_header, capped));
    try testing.expect(decoder.prefixSnapshot().pending);
    // An explicit contiguous decode call, unlike a size query, consumes the
    // prefix even when it fails before decoding blocks.
    try testing.expectError(error.OutputLimitExceeded, decoder.decodeIntoSliceWithOptions(dictionary_header, &output, capped));
    try testing.expectEqual(Z.PrefixPhase.none, decoder.prefixSnapshot().phase);
    try testing.expect(decoder.prefixSnapshot().setter_eligible);
    try testing.expect(std.mem.allEqual(u8, &output, canary));
    try testing.expectError(error.NeedDictionary, decoder.decodeIntoSlice(dictionary_frame, &output));

    try decoder.setPrefixWithDictionary(prefix);
    try testing.expectEqual(@as(usize, wide_payload.len), try decoder.decodeIntoSlice(dictionary_frame, &output));
    try testing.expectEqualStrings(wide_payload, &output);
    try testing.expectEqual(Z.PrefixPhase.none, decoder.prefixSnapshot().phase);
}

fn byteChunks(comptime bytes: []const u8) [2 * bytes.len][]const u8 {
    var chunks: [2 * bytes.len][]const u8 = undefined;
    for (0..bytes.len) |i| {
        chunks[2 * i] = &.{};
        chunks[2 * i + 1] = bytes[i..][0..1];
    }
    return chunks;
}

fn expectChunkRejected(comptime Z: type, expected: Z.Error, chunks: []const []const u8, scratch: []u8, options: Z.FrameDecodeOptions) !void {
    var failing = failingAllocator();
    const no_alloc = failing.allocator();
    var output: [narrow_payload.len + wide_payload.len]u8 = @splat(canary);
    var out = try seededList();
    defer out.deinit(a);
    const before = out;

    try testing.expectError(expected, Z.decodedFrameChunksSizeWithOptions(chunks, scratch, options));
    try testing.expectError(expected, Z.decodeFrameChunksAllocWithOptions(no_alloc, chunks, scratch, options));
    try testing.expectError(expected, Z.decodeFrameChunksIntoWithOptions(no_alloc, chunks, scratch, &output, options));
    try testing.expectError(expected, Z.decodeFrameChunksAppendWithOptions(no_alloc, &out, chunks, scratch, options));
    try testing.expect(std.mem.allEqual(u8, scratch, canary));
    try testing.expect(std.mem.allEqual(u8, &output, canary));
    try expectUnchangedList(before, out);
    try expectNoAllocation(failing);
}

fn chunkAdmission(comptime Z: type) !void {
    const chunks = byteChunks(concatenated);
    var guarded: [concatenated.len + 2]u8 = @splat(canary);
    const scratch = guarded[1 .. guarded.len - 1];
    const capped: Z.FrameDecodeOptions = .{ .max_window_size = narrow_payload.len };
    const exact: Z.FrameDecodeOptions = .{ .max_window_size = wide_window };

    // Split every magic byte and header field, including the skippable size.
    // Both a tiny buffer and a usable buffer must survive the scan untouched.
    try expectChunkRejected(Z, error.OutputLimitExceeded, &chunks, scratch[0..1], capped);
    try expectChunkRejected(Z, error.OutputLimitExceeded, &chunks, scratch, capped);
    const magicless = byteChunks(dictionary_header[magic.len..]);
    try expectChunkRejected(Z, error.OutputLimitExceeded, &magicless, scratch[0..1], .{ .format = .magicless, .max_window_size = wide_window - 1 });
    try expectChunkRejected(Z, error.TruncatedFrame, magicless[0 .. magicless.len - 2], scratch[0..1], .{ .format = .magicless, .max_window_size = wide_window - 1 });
    try testing.expect(std.mem.allEqual(u8, &guarded, canary));

    var failing = failingAllocator();
    var decoder = Z.NativeFrameDecoder.initWithOptions(failing.allocator(), capped);
    defer decoder.deinit();
    var out = try seededList();
    defer out.deinit(a);
    const before = out;
    var output: [narrow_payload.len + wide_payload.len]u8 = @splat(canary);
    for ([_][]u8{ scratch[0..1], scratch }) |buffer| {
        try testing.expectError(error.OutputLimitExceeded, decoder.decodedChunksSize(&chunks, buffer));
        try testing.expectError(error.OutputLimitExceeded, decoder.decodeChunksAlloc(&chunks, buffer));
        try testing.expectError(error.OutputLimitExceeded, decoder.decodeChunksIntoSlice(&chunks, buffer, &output));
        try testing.expectError(error.OutputLimitExceeded, decoder.decodeChunksAppend(&out, &chunks, buffer));
        try testing.expectError(error.OutputLimitExceeded, decoder.decodeChunksScratch(&chunks, buffer));
    }
    try testing.expect(std.mem.allEqual(u8, &output, canary));
    try testing.expect(std.mem.allEqual(u8, &guarded, canary));
    try expectUnchangedList(before, out);
    try expectNoAllocation(failing);

    const small_chunks = byteChunks(narrow_frame);
    try decoder.setPrefix("borrowed history");
    try testing.expectError(error.OutputTooSmall, decoder.decodeChunksIntoSlice(&small_chunks, scratch[0..1], &output));
    try testing.expect(decoder.prefixSnapshot().pending);
    failing.fail_index = std.math.maxInt(usize);
    try testing.expectEqual(@as(usize, narrow_payload.len), try decoder.decodeChunksIntoSlice(&small_chunks, scratch, &output));
    try testing.expectEqualStrings(narrow_payload, output[0..narrow_payload.len]);
    try testing.expectEqual(Z.PrefixPhase.none, decoder.prefixSnapshot().phase);

    const expected = narrow_payload ++ wide_payload;
    try testing.expectEqual(@as(Count, expected.len), try Z.decodedFrameChunksSizeWithOptions(&chunks, scratch, exact));
    const owned = try Z.decodeFrameChunksAllocWithOptions(a, &chunks, scratch, exact);
    defer a.free(owned);
    try testing.expectEqualStrings(expected, owned);
    try testing.expectEqual(@as(usize, expected.len), try Z.decodeFrameChunksIntoWithOptions(a, &chunks, scratch, &output, exact));
    try testing.expectEqualStrings(expected, &output);
    try testing.expectEqual(@as(usize, expected.len), try Z.decodeFrameChunksAppendWithOptions(a, &out, &chunks, scratch, exact));
    try testing.expectEqualStrings(seed ++ expected, out.items);

    try testing.expectError(error.OutputTooSmall, Z.decodedFrameChunksSize(&chunks, scratch[0..1]));
    try testing.expectEqual(@as(usize, expected.len), try Z.decodeFrameChunksInto(&chunks, scratch, &output));
    try testing.expectEqualStrings(expected, &output);
    try testing.expectEqual(canary, guarded[0]);
    try testing.expectEqual(canary, guarded[guarded.len - 1]);
}

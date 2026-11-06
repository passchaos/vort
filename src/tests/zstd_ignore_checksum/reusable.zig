const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    const raw = try h.wire.rawAlloc(a, h.plain, true);
    defer a.free(raw);
    const frame = try h.wire.standardAlloc(a, raw);
    defer a.free(frame);
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        try sampleContracts(Z, if (format == .standard) frame else raw, h.plain, .{ .format = format });
        try concatenation(Z, if (format == .standard) frame else raw, .{ .format = format });
    }
}

pub fn sampleContracts(comptime Z: type, frame: []const u8, payload: []const u8, base: Z.FrameDecodeOptions) !void {
    const bad = try h.corrupt(frame);
    defer a.free(bad);
    var options = base;
    options.ignore_content_checksum = true;
    var decoder = Z.NativeFrameDecoder.initWithOptions(a, options);
    defer decoder.deinit();
    const owned = try decoder.decodeAlloc(bad);
    defer a.free(owned);
    try std.testing.expectEqualSlices(u8, payload, owned);
    const output = try a.alloc(u8, payload.len + 17);
    defer a.free(output);
    @memset(output, 0xa5);
    try std.testing.expectEqual(payload.len, try decoder.decodeIntoSlice(bad, output[0..payload.len]));
    try std.testing.expectEqualSlices(u8, payload, output[0..payload.len]);
    try h.wire.untouched(output[payload.len..]);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, "caller-prefix");
    try std.testing.expectEqual(payload.len, try decoder.decodeAppend(&out, bad));
    try std.testing.expectEqualSlices(u8, payload, out.items[13..]);
    const previous = try decoder.decodeScratch(bad);
    try std.testing.expectEqualSlices(u8, payload, previous);
    const pointer = previous.ptr;
    const capacity = decoder.scratch.capacity;
    var strict = options;
    strict.ignore_content_checksum = false;
    try std.testing.expectError(error.ChecksumMismatch, decoder.decodeScratchWithOptions(bad, strict));
    try std.testing.expectEqual(pointer, decoder.scratch.items.ptr);
    try std.testing.expectEqual(capacity, decoder.scratch.capacity);
    try std.testing.expectEqualSlices(u8, payload, decoder.scratch.items);
    options.max_total_working_memory = 0;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.decodeScratchWithOptions(bad, options));
    try std.testing.expectEqual(pointer, decoder.scratch.items.ptr);
    try std.testing.expectEqualSlices(u8, payload, decoder.scratch.items);
    options.max_total_working_memory = null;
    try std.testing.expectEqualSlices(u8, payload, try decoder.decodeScratchWithOptions(bad, options));

    const chunks = h.footerChunks(bad);
    const scratch = try a.alloc(u8, bad.len);
    defer a.free(scratch);
    try std.testing.expectEqual(payload.len, try decoder.decodedChunksSize(&chunks, scratch));
    const joined = try decoder.decodeChunksAllocExactSize(&chunks, scratch, payload.len);
    defer a.free(joined);
    try std.testing.expectEqualSlices(u8, payload, joined);
    try std.testing.expectEqualSlices(u8, payload, try decoder.decodeChunksScratch(&chunks, scratch));
    try std.testing.expectEqual(payload.len, try decoder.decodeChunksIntoSliceLimited(&chunks, scratch, output[0..payload.len], payload.len));
    out.shrinkRetainingCapacity(13);
    try std.testing.expectEqual(payload.len, try decoder.decodeChunksAppendExactSize(&out, &chunks, scratch, payload.len));
    try std.testing.expectEqualSlices(u8, payload, out.items[13..]);
    try std.testing.expectError(error.SizeMismatch, decoder.decodeChunksAllocExactSize(&chunks, scratch, payload.len + 1));
    try std.testing.expectError(error.OutputLimitExceeded, decoder.decodeChunksIntoSliceLimited(&chunks, scratch, output, payload.len - 1));
    decoder.options = strict;
    try std.testing.expectError(error.ChecksumMismatch, decoder.decodeChunksAlloc(&chunks, scratch));
    decoder.options = options;
    const retry = try decoder.decodeChunksAlloc(&chunks, scratch);
    defer a.free(retry);
    try std.testing.expectEqualSlices(u8, payload, retry);
}

fn concatenation(comptime Z: type, frame: []const u8, base: Z.FrameDecodeOptions) !void {
    const bad = try h.corrupt(frame);
    defer a.free(bad);
    const stream = try h.join(frame, bad);
    defer a.free(stream);
    const payload = h.plain ** 2;
    var strict = base;
    strict.ignore_content_checksum = false;
    var ignore = base;
    ignore.ignore_content_checksum = true;
    var guarded: [payload.len + 17]u8 = @splat(0xa5);
    try std.testing.expectError(error.ChecksumMismatch, Z.decodeFrameIntoWithOptions(a, stream, guarded[0..payload.len], strict));
    try h.wire.untouched(&guarded);
    try std.testing.expectEqual(payload.len, try Z.decodeFrameIntoWithOptions(a, stream, guarded[0..payload.len], ignore));
    try std.testing.expectEqualSlices(u8, payload, guarded[0..payload.len]);
    try h.wire.untouched(guarded[payload.len..]);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, "caller-prefix");
    try std.testing.expectError(error.ChecksumMismatch, Z.decodeFrameAppendWithOptions(a, &out, stream, strict));
    try std.testing.expectEqualStrings("caller-prefix", out.items);
    try std.testing.expectEqual(payload.len, try Z.decodeFrameAppendWithOptions(a, &out, stream, ignore));
    try std.testing.expectEqualSlices(u8, payload, out.items[13..]);
    var decoder = Z.NativeFrameDecoder.initWithOptions(a, ignore);
    defer decoder.deinit();
    const decoded = try decoder.decodeConcatenatedAllocExactSize(stream, payload.len);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const chunks = h.footerChunks(stream);
    const scratch = try a.alloc(u8, stream.len);
    defer a.free(scratch);
    try std.testing.expectEqualSlices(u8, payload, try decoder.decodeConcatenatedChunksScratch(&chunks, scratch));
    const pointer = decoder.scratch.items.ptr;
    // Keep configured publication active when switching back to strict mode.
    strict.max_output_len = payload.len;
    decoder.options = strict;
    try std.testing.expectError(error.ChecksumMismatch, decoder.decodeConcatenatedChunksScratch(&chunks, scratch));
    try std.testing.expectEqual(pointer, decoder.scratch.items.ptr);
    try std.testing.expectEqualSlices(u8, payload, decoder.scratch.items);
}

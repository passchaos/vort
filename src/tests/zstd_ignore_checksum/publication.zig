const std = @import("std");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    try std.testing.expect(!(Z.FrameDecodeOptions{}).ignore_content_checksum);
    const raw = try h.wire.rawAlloc(a, h.plain, true);
    defer a.free(raw);
    const standard = try h.wire.standardAlloc(a, raw);
    defer a.free(standard);
    const repeated = [_]u8{'R'} ** 512;
    const rle = try h.memory.rleAlloc(&repeated, false);
    defer a.free(rle);
    const compressed = try h.memory.compressedAlloc();
    defer a.free(compressed);
    const compressed_plain = try h.memory.compressedPlainAlloc();
    defer a.free(compressed_plain);
    for ([_]struct { frame: []const u8, payload: []const u8 }{
        .{ .frame = standard, .payload = h.plain },
        .{ .frame = rle, .payload = &repeated },
        .{ .frame = compressed, .payload = compressed_plain },
    }) |sample| {
        for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
            const frame = if (format == .standard) sample.frame else sample.frame[4..];
            try sampleContracts(Z, frame, sample.payload, .{ .format = format });
        }
    }
    try safety(Z, standard);
    try heapTransaction(Z, compressed, compressed_plain);
    const no_footer = try h.wire.rawAlloc(a, h.plain, false);
    defer a.free(no_footer);
    const standard_no_footer = try h.wire.standardAlloc(a, no_footer);
    defer a.free(standard_no_footer);
    try h.wire.check(Z, a, no_footer, h.plain, .{ .format = .magicless, .ignore_content_checksum = true });
    try h.wire.check(Z, a, standard_no_footer, h.plain, .{ .ignore_content_checksum = true });
}

pub fn sampleContracts(comptime Z: type, frame: []const u8, payload: []const u8, base: Z.FrameDecodeOptions) !void {
    const bad = try h.corrupt(frame);
    defer a.free(bad);
    var strict = base;
    strict.ignore_content_checksum = false;
    var ignore = base;
    ignore.ignore_content_checksum = true;
    try h.wire.check(Z, a, frame, payload, strict);
    try std.testing.expectError(error.ChecksumMismatch, Z.decodeFrameAllocWithOptions(a, bad, strict));
    const guarded = try a.alloc(u8, payload.len + 17);
    defer a.free(guarded);
    @memset(guarded, 0xa5);
    try std.testing.expectError(error.ChecksumMismatch, Z.decodeFrameIntoWithOptions(a, bad, guarded[0..payload.len], strict));
    try h.wire.untouched(guarded);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, "caller-prefix");
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    try std.testing.expectError(error.ChecksumMismatch, Z.decodeFrameAppendWithOptions(a, &out, bad, strict));
    try std.testing.expectEqualStrings("caller-prefix", out.items);
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(capacity, out.capacity);
    try h.wire.check(Z, a, bad, payload, ignore);
    for (0..4) |footer_bytes| {
        try std.testing.expectError(error.TruncatedFrame, Z.decodeFrameAllocWithOptions(a, bad[0 .. bad.len - 4 + footer_bytes], ignore));
    }
}

fn safety(comptime Z: type, frame: []const u8) !void {
    const bad = try h.corrupt(frame);
    defer a.free(bad);
    const ignore: Z.FrameDecodeOptions = .{ .ignore_content_checksum = true };
    try std.testing.expectError(error.OutputLimitExceeded, Z.decodeFrameAllocWithOptions(a, bad, .{ .ignore_content_checksum = true, .max_output_len = h.plain.len - 1 }));
    try std.testing.expectError(error.SizeMismatch, Z.decodeFrameAllocWithOptions(a, bad, .{ .ignore_content_checksum = true, .expected_output_len = h.plain.len + 1 }));
    var guarded: [h.plain.len]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutputTooSmall, Z.decodeFrameIntoWithOptions(a, bad, guarded[0 .. guarded.len - 1], ignore));
    try h.wire.untouched(&guarded);

    // Change the advertised FCS independently of the actual payload/footer.
    const wrong_size = try a.dupe(u8, bad);
    defer a.free(wrong_size);
    const parsed = try h.wire.header(wrong_size, false);
    wrong_size[parsed.payload_offset - parsed.content_width] ^= 1;
    try std.testing.expectError(error.SizeMismatch, Z.decodeFrameAllocWithOptions(a, wrong_size, ignore));
    const corrupt_block = try a.dupe(u8, bad);
    defer a.free(corrupt_block);
    corrupt_block[parsed.payload_offset] |= 6; // Reserved block kind.
    try std.testing.expectError(error.CorruptFrame, Z.decodeFrameAllocWithOptions(a, corrupt_block, ignore));
    const short_suffix = try h.join(bad, &.{0x28});
    defer a.free(short_suffix);
    try std.testing.expectError(error.TruncatedFrame, Z.decodeFrameAllocWithOptions(a, short_suffix, ignore));
    const invalid_suffix = try h.join(bad, "junk");
    defer a.free(invalid_suffix);
    try std.testing.expectError(error.InvalidMagic, Z.decodeFrameAllocWithOptions(a, invalid_suffix, ignore));

    // A valid payload mutation is accepted as its actual decoded bytes.
    const changed = try a.dupe(u8, frame);
    defer a.free(changed);
    changed[parsed.payload_offset + 3] ^= 0x20;
    try std.testing.expectError(error.ChecksumMismatch, Z.decodeFrameAllocWithOptions(a, changed, .{}));
    const decoded = try Z.decodeFrameAllocWithOptions(a, changed, ignore);
    defer a.free(decoded);
    try std.testing.expectEqual(h.plain[0] ^ @as(u8, 0x20), decoded[0]);
    try std.testing.expectEqualSlices(u8, h.plain[1..], decoded[1..]);
}

fn heapTransaction(comptime Z: type, frame: []const u8, payload: []const u8) !void {
    const bad = try h.corrupt(frame);
    defer a.free(bad);
    var tracker = h.memory.Tracker.init(a);
    const heap = tracker.allocator();
    var profile: Z.DecodeMemoryProfile = .{};
    var options: Z.FrameDecodeOptions = .{ .ignore_content_checksum = true, .memory_profile = &profile };
    const decoded = try Z.decodeFrameAllocWithOptions(heap, bad, options);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try h.memory.profileMatches(profile, &tracker, 0);
    const peak = tracker.peak;
    heap.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
    options.max_total_working_memory = peak - 1;
    tracker.begin();
    profile.reset();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.decodeFrameAllocWithOptions(heap, bad, options));
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
    try std.testing.expect(tracker.peak <= peak - 1);
    options.max_total_working_memory = peak;
    const exact = try Z.decodeFrameAllocWithOptions(heap, bad, options);
    defer heap.free(exact);
    try std.testing.expectEqualSlices(u8, payload, exact);

    const guarded = try a.alloc(u8, payload.len + 17);
    defer a.free(guarded);
    @memset(guarded, 0xa5);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.decodeFrameIntoWithOptions(a, bad, guarded[0..payload.len], .{ .ignore_content_checksum = true, .max_total_working_memory = 0 }));
    try h.wire.untouched(guarded);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, "caller-prefix");
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.decodeFrameAppendWithOptions(a, &out, bad, .{ .ignore_content_checksum = true, .max_total_working_memory = 0 }));
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(capacity, out.capacity);
    try std.testing.expectEqualStrings("caller-prefix", out.items);
    var failed = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, Z.decodeFrameIntoWithOptions(failed.allocator(), bad, guarded[0..payload.len], .{ .ignore_content_checksum = true }));
    try h.wire.untouched(guarded);
}

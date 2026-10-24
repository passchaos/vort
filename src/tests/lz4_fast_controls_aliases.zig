const std = @import("std");
const lz4 = @import("../lz4.zig");
const h = @import("lz4_fast_controls_helpers.zig");
const a = std.testing.allocator;

fn seed(output: *std.ArrayList(u8), backing: std.mem.Allocator) !void {
    try output.resize(backing, 128);
    @memcpy(output.items, h.plain[0..128]);
}

test "LZ4 fast controls aliases survive raw prefix scratch and frame output relocation with poisoned old memory" {
    const input = h.plain[0..128];
    const prefix = h.prefix[0..64];
    const block_options: lz4.BlockEncodeOptions = .{ .acceleration = 8 };
    const expected_raw = try lz4.encodeBlockWithOptionsAlloc(a, input, block_options);
    defer a.free(expected_raw);
    const expected_prefix = try lz4.encodeBlockWithPrefixAndOptionsAlloc(a, input, prefix, block_options);
    defer a.free(expected_prefix);
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_copy_reallocation = true;
    tracked.poison_before_free = true;
    const backing = tracked.allocator();
    {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(backing);
        try seed(&output, backing);
        const old = try a.dupe(u8, output.items);
        defer a.free(old);
        const size = try lz4.encodeBlockWithOptionsAppend(backing, &output, output.items, block_options);
        try std.testing.expectEqualSlices(u8, old, output.items[0..old.len]);
        try std.testing.expectEqualSlices(u8, expected_raw, output.items[old.len..]);
        try std.testing.expectEqual(expected_raw.len, size);
        output.clearRetainingCapacity();
        try output.resize(backing, 128);
        @memcpy(output.items, input);
        const with_prefix = try lz4.encodeBlockWithPrefixAndOptionsAppend(backing, &output, output.items, output.items[0..64], block_options);
        try std.testing.expectEqualSlices(u8, expected_prefix, output.items[output.items.len - with_prefix ..]);
    }
    {
        var encoder = try lz4.BlockEncoder.init(backing);
        defer encoder.deinit();
        try seed(&encoder.output_scratch, backing);
        const result = try encoder.encodeScratchWithOptions(encoder.output_scratch.items, block_options);
        try std.testing.expectEqualSlices(u8, expected_raw, result);
        try seed(&encoder.output_scratch, backing);
        const prefixed = try encoder.encodeWithPrefixAndOptionsScratch(encoder.output_scratch.items, encoder.output_scratch.items[0..64], block_options);
        try std.testing.expectEqualSlices(u8, expected_prefix, prefixed);
    }
    {
        // Logical output is eight bytes, but initialized input lives in its
        // retained tail. A full-capacity overlap must still be recognized.
        var output = std.ArrayList(u8).fromOwnedSlice(try backing.alloc(u8, 144));
        defer output.deinit(backing);
        @memset(output.items, 0xa5);
        output.shrinkRetainingCapacity(8);
        // ArrayList shrink poisons discarded bytes in safety builds. Prepare
        // borrowed retained-tail bytes only after shrinking the logical slice.
        @memcpy(output.items.ptr[16..144], input);
        const borrowed = output.items.ptr[16..144];
        const size = try lz4.encodeBlockWithOptionsAppend(backing, &output, borrowed, block_options);
        try h.untouched(output.items[0..8]);
        try std.testing.expectEqualSlices(u8, expected_raw, output.items[8..]);
        try std.testing.expectEqual(expected_raw.len, size);
    }
    const frame_options: lz4.NativeFrameOptions = .{ .acceleration = 8 };
    const expected_frame = try lz4.encodePureFrameWithOptionsAlloc(a, input, frame_options);
    defer a.free(expected_frame);
    const dictionary: lz4.NativeDictionary = .{ .id = 42, .content = prefix };
    const expected_dictionary = try lz4.encodeNativeFrameWithDictionaryAlloc(a, input, frame_options, dictionary);
    defer a.free(expected_dictionary);
    {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(backing);
        try seed(&output, backing);
        const old = try a.dupe(u8, output.items);
        defer a.free(old);
        try lz4.encodePureFrameAppend(backing, &output, output.items, frame_options);
        try std.testing.expectEqualSlices(u8, old, output.items[0..old.len]);
        try std.testing.expectEqualSlices(u8, expected_frame, output.items[old.len..]);
        try seed(&output, backing);
        try lz4.encodeNativeFrameAppendWithDictionary(backing, &output, output.items, frame_options, .{ .id = 42, .content = output.items[0..64] });
        try std.testing.expectEqualSlices(u8, input, output.items[0..input.len]);
        try std.testing.expectEqualSlices(u8, expected_dictionary, output.items[input.len..]);
    }
    {
        var encoder = try lz4.NativeFrameEncoder.init(backing);
        defer encoder.deinit();
        try seed(&encoder.output_scratch, backing);
        const frame = try encoder.encodeScratch(encoder.output_scratch.items, frame_options);
        try std.testing.expectEqualSlices(u8, expected_frame, frame);
        try seed(&encoder.output_scratch, backing);
        const attached = try encoder.encodeScratchWithDictionary(encoder.output_scratch.items, frame_options, .{ .id = 42, .content = encoder.output_scratch.items[0..64] });
        try std.testing.expectEqualSlices(u8, expected_dictionary, attached);
    }
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
}

const AliasOperation = enum { raw, dictionary_frame };

fn operation(tracked: *h.TrackingAllocator, kind: AliasOperation, failure: ?usize) !usize {
    const backing = tracked.allocator();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(backing);
    try seed(&output, backing);
    const before = try a.dupe(u8, output.items);
    defer a.free(before);
    const first = tracked.alloc_attempts;
    if (failure) |index| tracked.fail_alloc_after = first + index;
    const result = switch (kind) {
        .raw => lz4.encodeBlockWithPrefixAndOptionsAppend(backing, &output, output.items, output.items[0..64], .{ .acceleration = 8 }),
        .dictionary_frame => mapped: {
            lz4.encodeNativeFrameAppendWithDictionary(backing, &output, output.items, .{ .acceleration = 8 }, .{ .id = 42, .content = output.items[0..64] }) catch |err| break :mapped @as(lz4.Error!usize, err);
            break :mapped @as(lz4.Error!usize, output.items.len - before.len);
        },
    };
    if (failure != null) {
        try std.testing.expectError(error.OutOfMemory, result);
        try std.testing.expectEqualSlices(u8, before, output.items);
    } else {
        _ = try result;
    }
    tracked.clearFailures();
    return tracked.alloc_attempts - first;
}

test "LZ4 fast controls aliases six allocation refusals preserve caller bytes and release snapshots" {
    for ([_]AliasOperation{ .raw, .dictionary_frame }) |kind| {
        var baseline = h.TrackingAllocator.init(a);
        baseline.force_copy_reallocation = true;
        baseline.poison_before_free = true;
        const count = try operation(&baseline, kind, null);
        try std.testing.expectEqual(@as(usize, 0), baseline.live);
        try std.testing.expect(count >= 3);
        for ([_]usize{ 0, count / 2, count - 1 }) |failure| {
            var tracked = h.TrackingAllocator.init(a);
            tracked.force_copy_reallocation = true;
            tracked.poison_before_free = true;
            _ = try operation(&tracked, kind, failure);
            try std.testing.expectEqual(@as(usize, 0), tracked.live);
            try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
        }
    }
}

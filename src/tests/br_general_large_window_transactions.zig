const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_general_large_window_helpers.zig");
const a = std.testing.allocator;

test "Brotli general large window q0 q1 and command streams flush metadata and continue across reset" {
    for ([_]u4{ 0, 1, 4, 11 }) |quality| {
        const options: br.IncrementalPlannedStreamEncoder.Options = .{ .stream = .{ .quality = quality, .window_bits = 25, .large_window = true, .block_len = 32, .adaptive_blocks = false }, .block_len = 0 };
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(a, options);
        defer encoder.deinit();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(a);
        try h.feed(a, &encoder, &wire, h.plain[0..57]);
        encoder.flush();
        try h.drain(a, &encoder, &wire, .need_input);
        try encoder.writeMetadata("in stream metadata");
        try h.drain(a, &encoder, &wire, .need_input);
        try h.feed(a, &encoder, &wire, h.plain[57..]);
        try encoder.finish();
        try h.drain(a, &encoder, &wire, .done);
        const summary = try h.checkExtended(a, wire.items, h.plain, 25, .{});
        try std.testing.expectEqual(@as(usize, 1), summary.metadata_meta_block_count);
        const completed = encoder.snapshot().stream_count;
        var standard = options;
        standard.stream.large_window = false;
        standard.stream.window_bits = 16;
        try encoder.nextStream(standard);
        const first = try h.drive(a, &encoder, h.plain, 1, 1);
        defer a.free(first);
        const decoded = try br.decodeStreamAllocExactSize(a, first, h.plain.len);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, h.plain, decoded);
        try std.testing.expectEqual(completed + 1, encoder.snapshot().stream_count);
        try encoder.nextStream(options);
        const next = try h.drive(a, &encoder, h.plain, 7, 3);
        defer a.free(next);
        encoder.reset();
        const reset = try h.drive(a, &encoder, h.plain, 1, 1);
        defer a.free(reset);
        try std.testing.expectEqualSlices(u8, next, reset);
        _ = try h.checkExtended(a, next, h.plain, 25, .{});
    }
}

test "Brotli general large window incremental final OOM retains accepted source and extension tail" {
    for ([_]u4{ 0, 1, 4 }) |quality| {
        var ledger = h.TrackingAllocator.init(a);
        ledger.force_moving_growth = true;
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(ledger.allocator(), .{ .stream = .{ .quality = quality, .window_bits = 30, .large_window = true }, .block_len = 256 });
        defer encoder.deinit();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(a);
        try h.feed(a, &encoder, &wire, h.plain);
        try encoder.finish();
        const before = encoder.snapshot();
        const pending = try a.dupe(u8, encoder.pending.items);
        defer a.free(pending);
        ledger.fail_alloc_after = ledger.alloc_attempts;
        var output: [3]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutOfMemory, encoder.step("", &output));
        try std.testing.expectEqual(before.input_read, encoder.snapshot().input_read);
        try std.testing.expectEqual(before.output_written, encoder.snapshot().output_written);
        try std.testing.expectEqual(before.buffered_input, encoder.snapshot().buffered_input);
        try std.testing.expectEqualSlices(u8, pending, encoder.pending.items);
        try h.untouched(&output);
        ledger.clearFailures();
        try h.drain(a, &encoder, &wire, .done);
        _ = try h.checkExtended(a, wire.items, h.plain, 30, .{});
    }
}

test "Brotli general large window reusable output aliases source and dictionary descriptors safely" {
    for ([_]u4{ 0, 1, 4, 11 }) |quality| {
        var ledger = h.TrackingAllocator.init(a);
        ledger.force_moving_growth = true;
        var reusable = br.PlannedStreamEncoder.init(ledger.allocator());
        defer reusable.deinit();
        try reusable.output.resize(ledger.allocator(), 256);
        @memset(reusable.output.items, 0xa5);
        @memcpy(reusable.output.items[128..][0..64], h.plain[0..64]);
        const chunks: *[2][]const u8 = @ptrCast(@alignCast(reusable.output.items.ptr));
        chunks.* = .{ reusable.output.items[128..160], reusable.output.items[160..192] };
        const raw: *[1][]const u8 = @ptrCast(@alignCast(reusable.output.items.ptr + 32));
        raw.* = .{reusable.output.items[128..192]};
        const options: br.PlannedStreamChunksOptions = .{ .quality = quality, .large_window = true, .window_bits = 30, .shared_dictionary = .{ .raw_prefixes = raw } };
        const actual = try reusable.encodeChunksScratchWithOptions(chunks, options);
        _ = try h.checkExtended(a, actual, h.plain[0..64], 30, .{ .raw_prefixes = &.{h.plain[0..64]} });
        var independent = options;
        independent.shared_dictionary = .{ .raw_prefixes = &.{h.plain[0..64]} };
        const expected = try br.encodePlannedStreamChunksWithOptionsAlloc(a, &.{ h.plain[0..32], h.plain[32..64] }, independent);
        defer a.free(expected);
        try std.testing.expectEqualSlices(u8, expected, actual);
    }
    var stored = br.StoredStreamEncoder.init(a);
    defer stored.deinit();
    try stored.scratch.appendSlice(a, h.plain);
    const wire = try stored.encodeScratchWithOptions(stored.scratch.items, .{ .window_bits = 30, .large_window = true });
    _ = try h.checkExtended(a, wire, h.plain, 30, .{});
}

test "Brotli general large window Into refuses insufficient storage before touching caller bytes" {
    for ([_]u4{ 0, 1, 4, 11 }) |quality| {
        const options: br.PlannedEncodeOptions = .{ .quality = quality, .window_bits = 25, .large_window = true };
        var output: [512]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutOfMemory, br.encodePlannedStreamWithOptionsInto(h.plain, output[0..1], options));
        try h.untouched(&output);
        const written = try br.encodePlannedStreamWithOptionsInto(h.plain, &output, options);
        _ = try h.checkExtended(a, output[0..written], h.plain, 25, .{});
        try h.untouched(output[written..]);
    }
}

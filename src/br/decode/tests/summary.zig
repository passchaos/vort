const std = @import("std");
const h = @import("helpers.zig");
const Writer = @import("../../encoder/bit_writer.zig").Writer;
const command = @import("../../encoder/command_encoding.zig");
const distance = @import("../../encoder/distance.zig");

pub fn contracts(comptime B: type) !void {
    const gap = 65537;
    const plain = try h.a.alloc(u8, gap + 3);
    defer h.a.free(plain);
    @memset(plain, 'a');
    plain[1] = 'b';
    @memcpy(plain[gap..], "abc");
    const stored = try B.encodeStoredStreamWithOptionsAlloc(h.a, plain[0..gap], .{ .window_bits = 17 });
    defer h.a.free(stored);
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.a);
    try wire.appendSlice(h.a, stored[0 .. stored.len - 1]); // Replace final empty block.
    var writer: Writer = .{ .out = &wire };
    try writer.writeBits(h.a, 1, 1); // Final compressed block.
    try writer.writeBits(h.a, 0, 1);
    try writer.writeBits(h.a, 0, 2);
    try writer.writeBits(h.a, 2, 16); // Three decoded bytes.
    try writer.writeBits(h.a, 0, 3); // One literal, command and distance block type.
    try writer.writeBits(h.a, 0, 2); // NPOSTFIX.
    try writer.writeBits(h.a, 0, 4); // NDIRECT.
    try writer.writeBits(h.a, 0, 2); // LSB6 context mode.
    try writer.writeBits(h.a, 1, 1);
    try writer.writeBits(h.a, 0, 3); // Two literal trees.
    try writer.writeBits(h.a, 0, 1); // Context-map RLE disabled.
    try writer.writeBits(h.a, 1, 2);
    try writer.writeBits(h.a, 1, 2);
    try writer.writeBits(h.a, 0, 1);
    try writer.writeBits(h.a, 1, 1); // Two-symbol context-map tree.
    for (0..64) |context| try writer.writeBits(h.a, @intFromBool(context == ('b' & 63)), 1);
    try writer.writeBits(h.a, 0, 1); // IMTF disabled.
    try writer.writeBits(h.a, 0, 1); // One distance tree.
    try single(&writer, 'd', 8);
    try single(&writer, 'c', 8);
    const copied = command.forLengths(0, 2, false).?;
    const tail = command.forLengths(1, 2, true).?;
    try writer.writeBits(h.a, 1, 2);
    try writer.writeBits(h.a, 1, 2);
    try writer.writeBits(h.a, copied.symbol, 10);
    try writer.writeBits(h.a, tail.symbol, 10);
    const dist = distance.encode(gap, 0).?;
    try single(&writer, dist.symbol, 6);
    try writer.writeBits(h.a, @intFromBool(copied.symbol > tail.symbol), 1);
    try writer.writeBits(h.a, dist.extra, dist.extra_bits);
    try writer.writeBits(h.a, @intFromBool(tail.symbol > copied.symbol), 1);
    writer.alignToByte();

    try std.testing.expectError(error.UnsupportedBrotliFeature, B.summarizeStream(wire.items));
    const history = try h.a.alloc(u8, gap);
    defer h.a.free(history);
    const oracle = try B.summarizeStreamWithHistory(wire.items, history);
    try std.testing.expectEqual(@as(B.Counter, plain.len), oracle.decoded_bytes);
    try std.testing.expectEqual(gap, oracle.max_lz77_distance);
    try preflightContracts(B, wire.items, plain, history);
    const decoded = try B.decodeStreamAllocExactSize(h.a, wire.items, plain.len);
    defer h.a.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);

    var tracker = h.CountingAllocator.init(h.a);
    const heap = tracker.allocator();
    var profile: B.DecodeMemoryProfile = .{};
    var options: B.DecodeOptions = .{ .memory_profile = &profile };
    const result = try B.summarizeStreamAllocLimitedWithOptions(heap, wire.items, plain.len, options);
    try std.testing.expectEqualDeep(oracle, result);
    const peak = tracker.peak;
    try std.testing.expect(peak > plain.len);
    try h.profileMatches(profile, &tracker);
    profile.reset();
    tracker.begin();
    options.max_total_working_memory = peak;
    try std.testing.expectEqualDeep(oracle, try B.summarizeStreamAllocLimitedWithOptions(heap, wire.items, plain.len, options));
    try h.profileMatches(profile, &tracker);
    profile.reset();
    tracker.begin();
    options.max_total_working_memory = peak - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, B.summarizeStreamAllocLimitedWithOptions(heap, wire.items, plain.len, options));
    try h.profileMatches(profile, &tracker);
    try std.testing.expectEqual(@as(usize, 0), tracker.failures);
    profile.reset();
    tracker.begin();
    options.max_total_working_memory = peak;
    tracker.fail_at = 1; // Control succeeds; actual history allocation fails.
    try std.testing.expectError(error.OutOfMemory, B.summarizeStreamAllocLimitedWithOptions(heap, wire.items, plain.len, options));
    try std.testing.expect(tracker.failures != 0);
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
}

fn preflightContracts(comptime B: type, wire: []u8, plain: []const u8, history: []u8) !void {
    const n = plain.len;
    // Adjacent independent borrows are valid, and bytes past the result are
    // never published. Use the same history across all successes and retries.
    const backing = try h.a.alloc(u8, n + 1 + history.len);
    defer h.a.free(backing);
    const output = backing[0 .. n + 1];
    const joined = try std.mem.concat(h.a, u8, &.{ wire, "tail" });
    defer h.a.free(joined);
    var profile: B.DecodeMemoryProfile = .{};
    const opts: B.DecodePreflightOptions = .{
        .history = backing[n + 1 ..],
        .max_output_len = n,
        .expected_output_len = n,
        .decode = .{ .max_total_working_memory = 0, .memory_profile = &profile },
    };
    @memset(output, 0xa5);
    try std.testing.expectEqual(@as(B.Counter, n), try B.decodedStreamSizeWithPreflight(wire, opts));
    const size = try B.decodedStreamPrefixSizeWithPreflight(joined, opts);
    try std.testing.expectEqual(wire.len, size.input_read);
    try std.testing.expectEqual(@as(B.Counter, n), size.decoded_bytes);
    try std.testing.expectError(error.TrailingData, B.decodedStreamSizeWithPreflight(joined, opts));
    try std.testing.expectError(error.TrailingData, B.decodeStreamIntoWithPreflight(joined, output, opts));

    var refused = opts;
    refused.history = refused.history[0 .. refused.history.len - 1];
    try std.testing.expectError(error.PreflightHistoryTooSmall, B.decodedStreamSizeWithPreflight(wire, refused));
    try std.testing.expectError(error.PreflightHistoryTooSmall, B.decodeStreamIntoWithPreflight(wire, output, refused));
    refused = opts;
    refused.max_output_len -= 1; // Only the second meta-block exceeds the limit.
    try std.testing.expectError(error.OutputLimitExceeded, B.decodeStreamIntoWithPreflight(wire, output, refused));
    refused = opts;
    refused.expected_output_len = n + 1;
    try std.testing.expectError(error.SizeMismatch, B.decodeStreamPrefixIntoWithPreflight(joined, output, refused));
    try std.testing.expectError(error.OutputTooSmall, B.decodeStreamIntoWithPreflight(wire, output[0 .. n - 1], opts));
    try std.testing.expectError(error.TruncatedFrame, B.decodeStreamIntoWithPreflight(wire[0 .. wire.len - 1], output, opts));
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamIntoWithPreflight(wire, opts.history, opts));
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamIntoWithPreflight(wire, wire, opts));
    refused = opts;
    refused.history = wire;
    try std.testing.expectError(error.InvalidBlockPlan, B.decodedStreamSizeWithPreflight(wire, refused));
    refused.history = std.mem.asBytes(&profile);
    try std.testing.expectError(error.InvalidBlockPlan, B.decodedStreamSizeWithPreflight(wire, refused));
    refused = opts;
    refused.decode.shared_dictionary = .{ .raw_prefixes = &.{opts.history[0..5]} };
    try std.testing.expectError(error.InvalidBlockPlan, B.decodedStreamSizeWithPreflight(wire, refused));
    try std.testing.expect(std.mem.allEqual(u8, output, 0xa5));

    const result = try B.decodeStreamPrefixIntoWithPreflight(joined, output, opts);
    try std.testing.expectEqual(wire.len, result.input_read);
    try std.testing.expectEqual(n, result.output_written);
    try std.testing.expectEqualSlices(u8, plain, output[0..n]);
    try std.testing.expectEqual(@as(u8, 0xa5), output[n]);
    try std.testing.expectEqual(n, try B.decodeStreamIntoWithPreflight(wire, output, opts));
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);

    var decoder = try B.StreamDecoder.initWithPreflight(wire, output, opts);
    var initial: [3]u8 = undefined;
    const step = try decoder.step(&initial);
    try std.testing.expectEqual(@as(usize, initial.len), step.progress.output_written);
    try std.testing.expectEqualSlices(u8, plain[0..initial.len], &initial);
    refused = opts;
    refused.history = output;
    try std.testing.expectError(error.InvalidBlockPlan, decoder.resetWithPreflight(wire, &.{}, refused));
    refused = opts;
    refused.expected_output_len = n + 1;
    try std.testing.expectError(error.SizeMismatch, decoder.resetWithPreflight(wire, output, refused));
    try std.testing.expectEqual(@as(usize, initial.len), decoder.snapshot().output_written);
    try std.testing.expectEqualStrings("SizeMismatch", decoder.snapshot().last_error_name);
    try std.testing.expectEqualSlices(u8, plain, output[0..n]);
    try decoder.resetWithPreflight(wire, output, opts);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
    try std.testing.expectEqualStrings("", decoder.snapshot().last_error_name);
}

fn single(writer: *Writer, symbol: u16, bits: u6) !void {
    try writer.writeBits(h.a, 1, 2);
    try writer.writeBits(h.a, 0, 2);
    try writer.writeBits(h.a, symbol, bits);
}

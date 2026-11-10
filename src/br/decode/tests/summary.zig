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

fn single(writer: *Writer, symbol: u16, bits: u6) !void {
    try writer.writeBits(h.a, 1, 2);
    try writer.writeBits(h.a, 0, 2);
    try writer.writeBits(h.a, symbol, bits);
}

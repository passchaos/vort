//! Pull readers retain wide source coordinates across borrowed and file parts.
const std = @import("std");
const core = @import("../../core.zig");
const fixture = @import("../split/wide_fixture.zig");
const Count = core.StreamCount;

pub fn contracts(comptime Codec: type) !void {
    const allocator = std.testing.allocator;
    const boundary: Count = @as(Count, 1) << 32;
    const tile = fixture.tile();

    // Every borrowed part is addressable, while the ordered aggregate is wider
    // than a 32-bit pointer. The directory selects the final tile's member.
    const part_count = 65537;
    const tail = fixture.tail(part_count, part_count - 1, 4, &tile);
    const parts = try allocator.alloc([]const u8, part_count + 1);
    defer allocator.free(parts);
    @memset(parts[0..part_count], tile[0..]);
    parts[part_count] = &tail;
    var slices = try Codec.SplitIncrementalReader.initAlloc(allocator, parts, .{ .input_buffer_size = 4096 });
    defer slices.deinit();
    try drain(&slices, &tile, boundary + 4);

    // A callback part may itself exceed address space. Only its requested
    // window is generated, and the callback observes an absolute part offset.
    const source_tail = fixture.tail(1, 0, boundary + 4, &tile);
    var callback: fixture.Callback = .{ .tile_bytes = &tile, .tail_bytes = &source_tail };
    const lengths = [_]Count{ boundary + fixture.tile_len, source_tail.len };
    var source = try Codec.SplitIncrementalReader.initSourceAlloc(allocator, .{
        .context = &callback,
        .part_lengths = &lengths,
        .read_at = fixture.Callback.read,
    }, .{ .input_buffer_size = 4096 });
    defer source.deinit();
    try drain(&source, &tile, boundary + 4);
    try std.testing.expect(callback.largest_offset > std.math.maxInt(u32));
}

fn drain(reader: anytype, tile: []const u8, initial: Count) !void {
    try std.testing.expectEqual(initial, reader.inner.options.initial_offset);
    try std.testing.expectEqual(initial, reader.source_offset);
    try std.testing.expect(reader.normalizedLength() > std.math.maxInt(u32));
    const expected = tile[fixture.data_offset..];
    var output: [1024]u8 = undefined;
    var written: usize = 0;
    var headers: usize = 0;
    var completions: usize = 0;
    var attempts: usize = 0;
    while (reader.snapshot().phase != .done) : (attempts += 1) {
        try std.testing.expect(attempts < 100);
        const stepped = try reader.step(&output);
        const produced = stepped.progress.output_written;
        try std.testing.expect(produced <= expected.len - written);
        try std.testing.expectEqualSlices(u8, expected[written..][0..produced], output[0..produced]);
        written += produced;
        if (stepped.status == .entry_header) headers += 1;
        if (stepped.status == .entry_done) completions += 1;
    }
    try reader.finish();
    try std.testing.expectEqual(expected.len, written);
    try std.testing.expectEqual(@as(usize, 1), headers);
    try std.testing.expectEqual(@as(usize, 1), completions);
    try std.testing.expectEqual(reader.normalizedLength(), reader.source_offset);
    try std.testing.expectEqual(reader.normalizedLength() - initial, reader.snapshot().input_read);
    try std.testing.expectEqual(@as(Count, expected.len), reader.snapshot().output_written);
    try std.testing.expectEqual(@as(Count, 1), reader.snapshot().completed_entries);
    try std.testing.expectEqual(initial, reader.entryAt(0).?.local_header_offset);
    try std.testing.expectEqual(@as(?Count, expected.len), reader.entryAt(0).?.uncompressed_size);
    try std.testing.expectEqual(@as(?u32, std.hash.Crc32.hash(expected)), reader.entryAt(0).?.crc32);
}

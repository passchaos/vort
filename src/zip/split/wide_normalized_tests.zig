const std = @import("std");
const normalized = @import("normalized_stream.zig");
const source = @import("source.zig");
const fixture = @import("wide_fixture.zig");
const Count = source.Count;
const count = source.count;

test "ZIP split logical stream preserves native count types and physical capacities" {
    try std.testing.expect(@FieldType(normalized.Stream, "total_len") == Count);
    try std.testing.expect(@FieldType(normalized.Stream, "first_record_offset") == Count);
    try std.testing.expect(@FieldType(normalized.Stream, "bases") == []Count);
    try std.testing.expect(@FieldType(normalized.SourceStream, "part_lengths") == []Count);
    try std.testing.expect(@FieldType(normalized.Options, "max_archive_size") == Count);
    try std.testing.expect(@FieldType(normalized.Options, "max_parts") == usize);
    try std.testing.expect(@FieldType(normalized.Options, "max_entries") == usize);
    try std.testing.expect(@FieldType(normalized.PartSource, "part_lengths") == []const Count);
    if (@bitSizeOf(usize) == 64) {
        try std.testing.expect(Count == usize);
    } else try std.testing.expect(Count == u64);
}

test "ZIP split logical stream borrows real tiles beyond four GiB and patches across parts" {
    const boundary: Count = @as(Count, 1) << 32;
    const body_count: usize = 65537;
    var tile = fixture.tile();
    const tail = fixture.tail(body_count, body_count - 1, 4, &tile);
    const tail_base = try count.addLocal(boundary, fixture.tile_len);
    const local = try count.addLocal(boundary, 4);
    const expected = try fixture.normalized(tail, tail_base, local);
    const parts = try std.testing.allocator.alloc([]const u8, body_count + 1);
    defer std.testing.allocator.free(parts);
    @memset(parts[0..body_count], &tile);
    parts[body_count] = &tail;
    var stream = try normalized.Stream.initAlloc(std.testing.allocator, parts, .{});
    defer stream.deinit();
    try std.testing.expectEqual(try count.addLocal(tail_base, tail.len), stream.len());
    try std.testing.expectEqual(local, stream.firstRecordOffset());
    try std.testing.expect(stream.patchCount() > 0);
    try checkTail(&stream, tail_base, &expected);

    var guard: [40]u8 = @splat(0xa5);
    const written = try stream.readAt(boundary - 7, guard[4..36]);
    try std.testing.expectEqual(@as(usize, 32), written);
    try std.testing.expectEqualSlices(u8, tile[tile.len - 7 ..], guard[4..11]);
    try std.testing.expectEqualSlices(u8, tile[0..25], guard[11..36]);
    try guards(&guard, 32);
    guard = @splat(0xa5);
    try std.testing.expectEqual(@as(usize, 32), try stream.readAt(tail_base - 8, guard[4..36]));
    try std.testing.expectEqualSlices(u8, tile[tile.len - 8 ..], guard[4..12]);
    try std.testing.expectEqualSlices(u8, expected[0..24], guard[12..36]);
    try guards(&guard, 32);

    // Compare the normalized tail with the ordinary small two-part model.
    const compact_tail = fixture.tail(1, 0, 4, &tile);
    const compact_parts = [_][]const u8{ &tile, &compact_tail };
    var compact = try normalized.Stream.initAlloc(std.testing.allocator, &compact_parts, .{});
    defer compact.deinit();
    var compact_bytes: [fixture.tail_len]u8 = undefined;
    try std.testing.expectEqual(compact_bytes.len, try compact.readAt(tile.len, &compact_bytes));
    fixture.put(u64, &compact_bytes, fixture.local_patch_offset, local);
    fixture.put(u64, &compact_bytes, fixture.zip64_offset + 48, tail_base);
    fixture.put(u64, &compact_bytes, fixture.locator_offset + 8, try count.addLocal(tail_base, fixture.zip64_offset));
    try std.testing.expectEqualSlices(u8, &expected, &compact_bytes);

    // Descriptors are copied; payload bytes remain borrowed.
    parts[0] = &.{};
    guard = @splat(0xa5);
    _ = try stream.readAt(0, guard[4..8]);
    try std.testing.expectEqualSlices(u8, tile[0..4], guard[4..8]);
    tile[100] ^= 0x5a;
    _ = try stream.readAt(100, guard[4..5]);
    try std.testing.expectEqual(tile[100], guard[4]);
    try std.testing.expectError(error.OutputLimitExceeded, normalized.Stream.initAlloc(std.testing.allocator, stream.parts, .{ .max_archive_size = stream.len() - 1 }));
    try std.testing.expectError(error.OutputLimitExceeded, normalized.Stream.initAlloc(std.testing.allocator, stream.parts, .{ .max_parts = body_count }));
}

test "ZIP split logical source supports wide part offsets short reads and copied lengths" {
    const boundary: Count = @as(Count, 1) << 32;
    var tile = fixture.tile();
    const tail = fixture.tail(1, 0, boundary + 4, &tile);
    const first_len = try count.addLocal(boundary, fixture.tile_len);
    var lengths = [_]Count{ first_len, tail.len };
    var context: fixture.Callback = .{ .tile_bytes = &tile, .tail_bytes = &tail };
    var stream = try normalized.SourceStream.initAlloc(std.testing.allocator, .{
        .context = &context,
        .part_lengths = &lengths,
        .read_at = fixture.Callback.read,
    }, .{});
    defer stream.deinit();
    lengths = @splat(0);
    const expected = try fixture.normalized(tail, first_len, boundary + 4);
    try checkTail(&stream, first_len, &expected);
    var guard: [40]u8 = @splat(0xa5);
    try std.testing.expectEqual(@as(usize, 32), try stream.readAt(boundary - 7, guard[4..36]));
    try std.testing.expectEqualSlices(u8, tile[tile.len - 7 ..], guard[4..11]);
    try std.testing.expectEqualSlices(u8, tile[0..25], guard[11..36]);
    try guards(&guard, 32);
    try std.testing.expect(context.largest_offset > boundary);
    try std.testing.expectEqual(boundary + 4, stream.firstRecordOffset());

    guard = @splat(0xa5);
    const reads = context.reads;
    try std.testing.expectError(error.RangeOutOfBounds, stream.readAt(try count.addLocal(stream.len(), 1), guard[4..36]));
    try std.testing.expectEqual(reads, context.reads);
    try guards(&guard, 0);
    context.fail = true;
    try std.testing.expectError(error.PartSourceReadFailed, stream.readAt(boundary + 4, guard[4..36]));
    context.fail = false;
    context.invalid_amount = true;
    try std.testing.expectError(error.InvalidZipArchive, stream.readAt(boundary + 4, guard[4..36]));
    try guards(&guard, 0);
}

test "ZIP split logical source refuses total overflow and honors the largest count" {
    var tile = fixture.tile();
    var tail = fixture.tail(1, 0, 4, &tile);
    var context: fixture.Callback = .{ .tile_bytes = &tile, .tail_bytes = &tail };
    var lengths = [_]Count{ std.math.maxInt(Count), 1 };
    const input: normalized.PartSource = .{
        .context = &context,
        .part_lengths = &lengths,
        .read_at = fixture.Callback.read,
    };
    try std.testing.expectError(error.IntegerOverflow, normalized.SourceStream.initAlloc(std.testing.allocator, input, .{}));
    try std.testing.expectEqual(@as(usize, 0), context.reads);

    const base: Count = std.math.maxInt(Count) - count.fromLocal(fixture.tail_len);
    const local = (base & ~@as(Count, fixture.tile_len - 1)) + 4;
    tail = fixture.tail(1, 0, local, &tile);
    lengths = .{ base, tail.len };
    try std.testing.expectError(error.OutputLimitExceeded, normalized.SourceStream.initAlloc(std.testing.allocator, input, .{ .max_archive_size = std.math.maxInt(Count) - 1 }));
    try std.testing.expectEqual(@as(usize, 0), context.reads);
    var stream = try normalized.SourceStream.initAlloc(std.testing.allocator, input, .{});
    defer stream.deinit();
    try std.testing.expectEqual(std.math.maxInt(Count), stream.len());
    try std.testing.expectEqual(local, stream.firstRecordOffset());
    const expected = try fixture.normalized(tail, base, local);
    try checkTail(&stream, base, &expected);
}

test "ZIP split logical plans release owned descriptors on allocation failures" {
    const tile = fixture.tile();
    const tail = fixture.tail(1, 0, 4, &tile);
    const parts = [_][]const u8{ &tile, &tail };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationAttempt, .{&parts});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, sourceAllocationAttempt, .{&parts});
}

fn allocationAttempt(allocator: std.mem.Allocator, parts: []const []const u8) !void {
    var stream = try normalized.Stream.initAlloc(allocator, parts, .{});
    defer stream.deinit();
    var scratch: [8]u8 = undefined;
    _ = try stream.readAt(0, &scratch);
}

fn sourceAllocationAttempt(allocator: std.mem.Allocator, parts: []const []const u8) !void {
    const lengths = [_]Count{ count.fromLocal(parts[0].len), count.fromLocal(parts[1].len) };
    var context: fixture.Callback = .{ .tile_bytes = parts[0], .tail_bytes = parts[1] };
    var stream = try normalized.SourceStream.initAlloc(allocator, .{
        .context = &context,
        .part_lengths = &lengths,
        .read_at = fixture.Callback.read,
    }, .{});
    defer stream.deinit();
    var scratch: [8]u8 = undefined;
    _ = try stream.readAt(0, &scratch);
}

fn checkTail(stream: anytype, base: Count, expected: []const u8) !void {
    for (0..expected.len + 1) |start| {
        var guard: [40]u8 = @splat(0xa5);
        const take = @min(@as(usize, 32), expected.len - start);
        try std.testing.expectEqual(take, try stream.readAt(try count.addLocal(base, start), guard[4..36]));
        try std.testing.expectEqualSlices(u8, expected[start..][0..take], guard[4..][0..take]);
        try guards(&guard, take);
    }
}

fn guards(bytes: *const [40]u8, written: usize) !void {
    for (bytes[0..4]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    for (bytes[4 + written ..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

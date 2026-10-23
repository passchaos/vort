const std = @import("std");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const writer = @import("../../writer.zig");
const format = @import("../../format.zig");
const helpers = @import("helpers.zig");

fn fixtureAlloc(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const data = try allocator.alloc(u8, decoder.calcSizeUpperBound(text.len));
    errdefer allocator.free(data);
    return allocator.realloc(data, try decoder.decode(data, text));
}

fn refresh(bytes: []u8) void {
    std.mem.writeInt(u32, bytes[1028..1032], format.computeSuperblockChecksum(bytes[1024..4096]), .little);
}

fn compactLink(bytes: []u8, pack_start: usize, item: usize, lo: u16) void {
    const value = @as(u16, 0x2000) | lo;
    for (0..14) |i| {
        const bit = item * 14 + i;
        const mask = @as(u8, 1) << @intCast(bit % 8);
        const byte = &bytes[pack_start + bit / 8];
        byte.* = (byte.* & ~mask) | (@as(u8, @truncate(value >> @intCast(i))) & 1) * mask;
    }
}

fn expectBadRange(bytes: []const u8, nid: u64, start: usize) !void {
    const allocator = std.testing.allocator;
    const archive = try archive_module.Archive.init(bytes);
    const inode = try archive.inode(nid);
    var slice = try archive.initRangeExtractor(allocator, inode, start, 31, .{ .max_output_len = 31 });
    defer slice.deinit();
    var output: [31]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidErofs, slice.read(&output));
    try std.testing.expectError(error.InvalidErofs, slice.read(&output));
    try std.testing.expectEqual(@as(usize, 0), slice.position());
    var input = helpers.Input{ .bytes = bytes, .fail_from_offset = 4096 };
    var source = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 0 });
    defer source.deinit();
    var reader = try source.initRangeExtractor(try source.inode(nid), start, 31, .{ .max_output_len = 31 });
    defer reader.deinit();
    try std.testing.expectError(error.InvalidErofs, reader.read(&output));
    try std.testing.expectError(error.InvalidErofs, reader.read(output[0..0]));
    try std.testing.expectEqual(@as(usize, 0), reader.position());
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    var sink = helpers.Counting{};
    try std.testing.expectError(error.InvalidErofs, source.readRangeToSink(inode, start, 31, sink.sink(), .{ .max_output_len = 31 }));
    try std.testing.expectEqual(@as(usize, 0), sink.calls);
    try std.testing.expect(!sink.finished);
    try std.testing.expectEqual(@as(usize, 0), source.working.live);
    try std.testing.expectEqual(@as(usize, 0), source.peakWorkingBytes());
}

test "EROFS full and compact bad NONHEAD chains fail before decoding or writing ranges" {
    const allocator = std.testing.allocator;
    inline for (.{ "full", "compact" }) |layout| {
        const original = try fixtureAlloc(allocator, @embedFile("../../testdata/lz4-" ++ layout ++ "-final-big.erofs.b64"));
        defer allocator.free(original);
        const base = try archive_module.Archive.init(original);
        const inode = try base.inode(40);
        const full = std.mem.eql(u8, layout, "full");
        for ([_]u16{ 0, 3, 0x7ff, 0x803 }) |invalid| {
            const bytes = try allocator.dupe(u8, original);
            defer allocator.free(bytes);
            const offset = inode.compressed_index_start + (if (full) @as(usize, 20) else 8);
            std.mem.writeInt(u16, bytes[offset..][0..2], invalid | (if (full) @as(u16, 0) else 0x2000), .little);
            refresh(bytes);
            try expectBadRange(bytes, inode.nid, 12288);
        }
        if (full) {
            const bytes = try allocator.dupe(u8, original);
            defer allocator.free(bytes);
            std.mem.writeInt(u16, bytes[inode.compressed_index_start + 28 ..][0..2], 0, .little);
            refresh(bytes);
            try expectBadRange(bytes, inode.nid, 12288);
        }
    }
}

test "EROFS full and compact linked NONHEAD chains preserve whole and boundary range bytes" {
    const allocator = std.testing.allocator;
    inline for (.{ "full", "compact" }) |layout| {
        const bytes = try fixtureAlloc(allocator, @embedFile("../../testdata/lz4-" ++ layout ++ "-final-big.erofs.b64"));
        defer allocator.free(bytes);
        const archive = try archive_module.Archive.init(bytes);
        const inode = try archive.inode(40);
        const expected = try archive.readFlatAllocLimited(allocator, inode, inode.file_size);
        defer allocator.free(expected);
        const full = std.mem.eql(u8, layout, "full");
        const offset = inode.compressed_index_start + (if (full) @as(usize, 20) else 8);
        std.mem.writeInt(u16, bytes[offset..][0..2], if (full) 1 else 0x2001, .little);
        if (full) std.mem.writeInt(u16, bytes[inode.compressed_index_start + 28 ..][0..2], 1, .little);
        refresh(bytes);
        var input = helpers.Input{ .bytes = bytes };
        var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
        defer source.deinit();
        for ([_]usize{ 0, 4093, 8192, 12288 }) |start| {
            var sink = helpers.Counting{ .expected = expected[start..][0..31] };
            _ = try source.readRangeToSink(inode, start, 31, sink.sink(), .{ .max_output_len = 31 });
            try std.testing.expect(sink.finished);
            try std.testing.expectEqual(@as(u64, 31), sink.length);
        }
        const decoded = try archive.readFlatAllocLimited(allocator, inode, inode.file_size);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, expected, decoded);
    }
}

test "EROFS two-byte compact pack boundary ranges reject broken derived lookbacks" {
    const allocator = std.testing.allocator;
    const original = try fixtureAlloc(allocator, @embedFile("../../testdata/lz4-compact-big.erofs.b64"));
    defer allocator.free(original);
    const archive = try archive_module.Archive.init(original);
    const inode = try archive.inode(39);
    try std.testing.expectEqual(@as(usize, 1288), inode.compressed_index_start);
    const expected = try archive.readFlatAllocLimited(allocator, inode, inode.file_size);
    defer allocator.free(expected);
    var input = helpers.Input{ .bytes = original };
    var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer source.deinit();
    // The first six indexes are four-byte items. The next sixteen occupy
    // a 32-byte pack, followed by more two-byte packs and a four-byte tail.
    for ([_]usize{ 6 * 4096 - 3, 21 * 4096, 22 * 4096 - 3, 53 * 4096, 54 * 4096 - 3 }) |start| {
        var sink = helpers.Counting{ .expected = expected[start..][0..31] };
        _ = try source.readRangeToSink(inode, start, 31, sink.sink(), .{ .max_output_len = 31 });
        try std.testing.expect(sink.finished);
    }
    for ([_]u16{ 0, 0x7ff }) |delta| {
        const bytes = try allocator.dupe(u8, original);
        defer allocator.free(bytes);
        compactLink(bytes, 1312, 14, delta);
        refresh(bytes);
        try expectBadRange(bytes, inode.nid, 21 * 4096);
    }
}

test "EROFS full heads reject out of cluster offsets and leading NONHEAD records" {
    const allocator = std.testing.allocator;
    const original = try fixtureAlloc(allocator, @embedFile("../../testdata/lz4-full-final-big.erofs.b64"));
    defer allocator.free(original);
    const archive = try archive_module.Archive.init(original);
    const inode = try archive.inode(40);
    for ([_]bool{ false, true }) |leading| {
        const bytes = try allocator.dupe(u8, original);
        defer allocator.free(bytes);
        if (leading) {
            std.mem.writeInt(u16, bytes[inode.compressed_index_start..][0..2], 2, .little);
        } else {
            std.mem.writeInt(u16, bytes[inode.compressed_index_start + 2 ..][0..2], 4096, .little);
        }
        refresh(bytes);
        try expectBadRange(bytes, inode.nid, 12288);
    }
}

test "EROFS index errors after an earlier extent preserve delivered position and release caches" {
    const allocator = std.testing.allocator;
    const payload = "indexed extent boundary bytes 0123456789\n" ** 1000;
    const bytes = try writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = payload }}, .{ .compression = .lz4, .compression_extent_size = 16384 });
    defer allocator.free(bytes);
    const archive = try archive_module.Archive.init(bytes);
    const inode = try archive.lookup(allocator, "file", payload.len, 4096);
    const offset = inode.compressed_index_start + 7 * 8 + 4;
    try std.testing.expectEqual(@as(u16, 2), format.readU16(bytes, offset - 4));
    std.mem.writeInt(u16, bytes[offset..][0..2], 0, .little);
    refresh(bytes);
    var input = helpers.Input{ .bytes = bytes };
    var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer source.deinit();
    var reader = try source.initExtractor(inode, .{ .max_output_len = payload.len });
    defer reader.deinit();
    var prefix: [16384]u8 = undefined;
    try std.testing.expectEqual(prefix.len, (try reader.read(&prefix)).output_written);
    try std.testing.expectEqualSlices(u8, payload[0..prefix.len], &prefix);
    var output: [31]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidErofs, reader.read(&output));
    try std.testing.expectError(error.InvalidErofs, reader.read(&output));
    try std.testing.expectEqual(prefix.len, reader.position());
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqual(@as(usize, 0), source.working.live);
    var sink = helpers.Counting{ .expected = payload };
    try std.testing.expectError(error.InvalidErofs, source.readToSink(inode, sink.sink(), .{ .max_output_len = payload.len }));
    try std.testing.expectEqual(@as(u64, prefix.len), sink.length);
    try std.testing.expect(!sink.finished);
}

test "EROFS inline and fragment inode tail scans reject corrupted earlier NONHEAD chains" {
    const allocator = std.testing.allocator;
    const payload = "indexed tail validation bytes\n" ** 600;
    for ([_]writer.TailPacking{ .fragments, .compressed_inline }) |tail| {
        const bytes = try writer.encodeAlloc(allocator, &.{.{ .path = "file", .data = payload }}, .{ .compression = .lz4, .compression_extent_size = 16384, .tail_packing = tail });
        defer allocator.free(bytes);
        const archive = try archive_module.Archive.init(bytes);
        const inode = try archive.lookup(allocator, "file", payload.len, 4096);
        try std.testing.expect(inode.compressed_advise & 0x28 != 0);
        const offset = inode.compressed_index_start + 2 * 8 + 4;
        try std.testing.expectEqual(@as(u16, 2), format.readU16(bytes, offset - 4));
        std.mem.writeInt(u16, bytes[offset..][0..2], 0, .little);
        refresh(bytes);
        try std.testing.expectError(error.InvalidErofs, archive.inode(inode.nid));
        var input = helpers.Input{ .bytes = bytes, .fail_from_offset = 4096 };
        var source = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 0 });
        defer source.deinit();
        try std.testing.expectError(error.InvalidErofs, source.inode(inode.nid));
        try std.testing.expectEqual(@as(usize, 0), source.peakWorkingBytes());
    }
}

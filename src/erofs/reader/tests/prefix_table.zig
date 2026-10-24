const std = @import("std");
const writer = @import("../../writer.zig");
const archive_module = @import("../../archive.zig");
const source_archive = @import("../../source_archive.zig");
const format = @import("../../format.zig");
const xattr = @import("../../xattr.zig");
const helpers = @import("helpers.zig");

const expected_data = "packed prefix interoperability payload\n" ** 2000;
const fixtures = [_][]const u8{
    @embedFile("../../testdata/packed-prefix-stored.erofs.b64"),
    @embedFile("../../testdata/packed-prefix-lz4.erofs.b64"),
    @embedFile("../../testdata/packed-prefix-lzma.erofs.b64"),
    @embedFile("../../testdata/packed-prefix-deflate.erofs.b64"),
    @embedFile("../../testdata/packed-prefix-zstd.erofs.b64"),
};

fn fixtureAlloc(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(u8, decoder.calcSizeUpperBound(encoded.len));
    errdefer allocator.free(bytes);
    return allocator.realloc(bytes, try decoder.decode(bytes, encoded));
}

fn refreshChecksum(image: []u8) void {
    std.mem.writeInt(u32, image[1028..1032], format.computeSuperblockChecksum(image[1024..4096]), .little);
}

fn verifyAttributes(attrs: xattr.Attributes) !void {
    try std.testing.expectEqual(@as(usize, 2), attrs.entries.len);
    try std.testing.expectEqualStrings("file-value", attrs.find("user.vort.repeat").?.value);
    try std.testing.expectEqualStrings("other-value", attrs.find("user.other.detail").?.value);
}

test "EROFS packed xattr prefixes match erofs-utils stored and all compressed codecs" {
    const allocator = std.testing.allocator;
    for (fixtures) |encoded| {
        const image = try fixtureAlloc(allocator, encoded);
        defer allocator.free(image);
        const slice = try archive_module.Archive.init(image);
        try std.testing.expect(slice.superblock.packed_nid != 0);
        try std.testing.expectEqual(@as(u32, 0), slice.superblock.feature_compat & format.feature_compat_plain_xattr_prefixes);
        const inode = try slice.lookup(allocator, "file", expected_data.len, 4096);
        var attrs = try slice.readXattrsAllocLimited(allocator, inode, 2, 128);
        defer attrs.deinit();
        try verifyAttributes(attrs);
        const data = try slice.readFlatAllocLimited(allocator, inode, expected_data.len);
        defer allocator.free(data);
        try std.testing.expectEqualStrings(expected_data, data);
        var input = helpers.Input{ .bytes = image };
        var source = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 2 * 1024 * 1024 });
        defer source.deinit();
        const source_inode = try source.lookup("file", expected_data.len, 4096);
        var source_attrs = try source.readXattrsAllocLimited(allocator, source_inode, 2, 128);
        defer source_attrs.deinit();
        try verifyAttributes(source_attrs);
        var root_attrs = try source.readXattrsAllocLimited(allocator, try source.rootInode(), 1, 128);
        defer root_attrs.deinit();
        try std.testing.expectEqualStrings("root-value", root_attrs.find("user.vort.root").?.value);
        const source_data = try source.readFlatAllocLimited(allocator, source_inode, expected_data.len);
        defer allocator.free(source_data);
        try std.testing.expectEqualStrings(expected_data, source_data);
        try std.testing.expectEqual(@as(usize, 0), source.working.live);
        try std.testing.expect(input.max_request <= 31);
    }
}

fn synthetic(allocator: std.mem.Allocator, prefixes: []const []const u8, start: usize, size: usize, compression: writer.Compression) ![]u8 {
    return syntheticWithPattern(allocator, prefixes, start, size, compression, false);
}

fn syntheticWithPattern(allocator: std.mem.Allocator, prefixes: []const []const u8, start: usize, size: usize, compression: writer.Compression, random: bool) ![]u8 {
    const data = try allocator.alloc(u8, size);
    defer allocator.free(data);
    @memset(data, 'P');
    if (random) {
        var state: u32 = 0x9183_571a;
        for (data) |*byte| {
            state ^= state << 13;
            state ^= state >> 17;
            state ^= state << 5;
            byte.* = @truncate(state);
        }
    }
    const table_size = try xattr.prefixTableSize(prefixes);
    try xattr.writePrefixTable(data[start..][0..table_size], prefixes);
    const attrs = [_]writer.Xattr{.{ .name = prefixes[prefixes.len - 1], .value = "last-prefix" }};
    const image = try writer.encodeAlloc(allocator, &.{
        .{ .path = "file", .xattrs = &attrs },
        .{ .path = "packed", .data = data },
    }, .{ .compression = compression, .xattr_prefixes = prefixes, .force_48bit = true, .compression_extent_size = if (compression == .stored) 4096 else 32768 });
    errdefer allocator.free(image);
    const original = try archive_module.Archive.init(image);
    const packed_inode = try original.lookup(allocator, "packed", size, 4096);
    std.mem.writeInt(u32, image[1032..1036], original.superblock.feature_compat & ~format.feature_compat_plain_xattr_prefixes, .little);
    std.mem.writeInt(u32, image[1104..1108], original.superblock.feature_incompat | format.feature_incompat_fragments, .little);
    std.mem.writeInt(u32, image[1116..1120], @intCast(start / 4), .little);
    std.mem.writeInt(u64, image[1120..1128], packed_inode.nid, .little);
    refreshChecksum(image);
    return image;
}

test "EROFS packed prefix records cross blocks at nonzero offsets with maximum names" {
    const allocator = std.testing.allocator;
    const maximum = "M" ** 255;
    const prefixes = [_][]const u8{ "user.vort.", "user.other.", maximum };
    for ([_]writer.Compression{ .stored, .lz4, .lzma, .deflate, .zstandard }) |compression| {
        const image = try synthetic(allocator, &prefixes, 4092, 32768, compression);
        defer allocator.free(image);
        const slice = try archive_module.Archive.init(image);
        const inode = try slice.lookup(allocator, "file", 0, 4096);
        var attrs = try slice.readXattrsAllocLimited(allocator, inode, 1, 512);
        defer attrs.deinit();
        try std.testing.expectEqualStrings("last-prefix", attrs.find(maximum).?.value);
        var input = helpers.Input{ .bytes = image };
        var source = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 2 * 1024 * 1024 });
        defer source.deinit();
        var source_attrs = try source.readXattrsAllocLimited(allocator, inode, 1, 512);
        defer source_attrs.deinit();
        try std.testing.expectEqualStrings("last-prefix", source_attrs.find(maximum).?.value);
        try std.testing.expectEqual(@as(usize, 0), source.working.live);
    }
}

test "EROFS packed prefix reading avoids unrelated stored payload and fits bounded heaps" {
    const allocator = std.testing.allocator;
    var names: [128][32]u8 = undefined;
    var prefixes: [128][]const u8 = undefined;
    for (&prefixes, 0..) |*prefix, index| prefix.* = try std.fmt.bufPrint(&names[index], "user.vort.{d:03}.", .{index});
    const image = try synthetic(allocator, &prefixes, 4092, 4 * 1024 * 1024, .stored);
    defer allocator.free(image);
    const slice = try archive_module.Archive.init(image);
    const inode = try slice.lookup(allocator, "file", 0, 4096);
    const packed_inode = try slice.inode(slice.superblock.packed_nid);
    const last_start = @as(usize, @intCast(packed_inode.data_block)) * 4096 + 4092 + try xattr.prefixTableSize(prefixes[0..127]);
    const table_end = last_start + 2 + format.readU16(image, last_start);
    var input = helpers.Input{ .bytes = image, .fail_from_offset = table_end };
    var source = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 64 * 1024 });
    defer source.deinit();
    var attrs = try source.readXattrsAllocLimited(allocator, inode, 1, 128);
    defer attrs.deinit();
    try std.testing.expectEqualStrings("last-prefix", attrs.find(prefixes[127]).?.value);
    try std.testing.expect(source.peakWorkingBytes() < 64 * 1024);
    try std.testing.expectEqual(@as(usize, 0), source.working.live);
    var small = try source_archive.SourceArchive.init(allocator, input.source(), .{ .max_working_memory = 32 * 1024 });
    defer small.deinit();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, small.readXattrsAllocLimited(allocator, inode, 1, 128));
    try std.testing.expectEqual(@as(usize, 0), small.working.live);
    var storage: [40 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var slice_attrs = try slice.readXattrsAllocLimited(fixed.allocator(), inode, 1, 128);
    defer slice_attrs.deinit();
    try std.testing.expectEqualStrings("last-prefix", slice_attrs.find(prefixes[127]).?.value);
}

test "EROFS packed prefix truncation invalid records and missing inodes have exact errors" {
    const allocator = std.testing.allocator;
    const original = try synthetic(allocator, &.{"user.vort."}, 4092, 8192, .stored);
    defer allocator.free(original);
    const base = try archive_module.Archive.init(original);
    const packed_inode = try base.inode(base.superblock.packed_nid);
    const inode = try base.lookup(allocator, "file", 0, 4096);
    const record = @as(usize, @intCast(packed_inode.data_block)) * 4096 + 4092;
    const Mutation = struct { offset: usize, bytes: []const u8, err: anyerror };
    for ([_]Mutation{
        .{ .offset = 1116, .bytes = &.{ 255, 255, 255, 255 }, .err = error.TruncatedFrame },
        .{ .offset = packed_inode.location + 8, .bytes = &.{ 253, 15, 0, 0 }, .err = error.TruncatedFrame },
        .{ .offset = packed_inode.location + 4, .bytes = &.{ 0, 64 }, .err = error.InvalidErofs },
        .{ .offset = record, .bytes = &.{ 0, 0 }, .err = error.InvalidErofs },
        .{ .offset = record, .bytes = &.{ 1, 1 }, .err = error.InvalidErofs },
        .{ .offset = record + 2, .bytes = &.{7}, .err = error.UnsupportedErofsFeature },
        .{ .offset = record + 3, .bytes = &.{0}, .err = error.InvalidErofs },
        .{ .offset = 1120, .bytes = &.{ 255, 255, 255, 255, 255, 255, 255, 127 }, .err = error.IntegerOverflow },
    }) |mutation| {
        const image = try allocator.dupe(u8, original);
        defer allocator.free(image);
        @memcpy(image[mutation.offset..][0..mutation.bytes.len], mutation.bytes);
        refreshChecksum(image);
        const slice = try archive_module.Archive.init(image);
        try std.testing.expectError(mutation.err, slice.readXattrsAllocLimited(allocator, inode, 1, 128));
        var input = helpers.Input{ .bytes = image };
        var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
        defer source.deinit();
        try std.testing.expectError(mutation.err, source.readXattrsAllocLimited(allocator, inode, 1, 128));
        try std.testing.expectEqual(@as(usize, 0), source.working.live);
    }
}

test "EROFS packed prefix source decoder output and allocation limits remain independent" {
    const allocator = std.testing.allocator;
    const image = try fixtureAlloc(allocator, fixtures[1]);
    defer allocator.free(image);
    const slice = try archive_module.Archive.init(image);
    const inode = try slice.lookup(allocator, "file", expected_data.len, 4096);
    for ([_]source_archive.Limits{ .{ .max_working_memory = 1 }, .{ .max_encoded_extent_size = 1 }, .{ .max_decoded_extent_size = 1 } }, 0..) |limits, index| {
        var input = helpers.Input{ .bytes = image };
        var source = try source_archive.SourceArchive.init(allocator, input.source(), limits);
        defer source.deinit();
        try std.testing.expectError(if (index == 0) error.WorkingMemoryLimitExceeded else error.OutputLimitExceeded, source.readXattrsAllocLimited(allocator, inode, 2, 128));
        try std.testing.expectEqual(@as(usize, 0), source.working.live);
    }
    var input = helpers.Input{ .bytes = image };
    var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer source.deinit();
    const packed_limit = archive_module.XattrReadLimits{ .max_count = 2, .max_total_bytes = 128, .max_packed_extent_len = 1 };
    try std.testing.expectError(error.OutputLimitExceeded, slice.readXattrsAllocWithLimits(allocator, inode, packed_limit));
    try std.testing.expectError(error.OutputLimitExceeded, source.readXattrsAllocWithLimits(allocator, inode, packed_limit));
    input.fail_from_offset = 4096;
    try std.testing.expectError(error.SourceReadFailed, source.readXattrsAllocLimited(allocator, inode, 2, 128));
    input.fail_from_offset = null;
    try std.testing.expectError(error.OutputLimitExceeded, source.readXattrsAllocLimited(allocator, inode, 1, 128));
    try std.testing.expectError(error.OutputLimitExceeded, source.readXattrsAllocLimited(allocator, inode, 2, 1));
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, source.readXattrsAllocLimited(failing.allocator(), inode, 2, 128));
    var attrs = try source.readXattrsAllocLimited(allocator, inode, 2, 128);
    defer attrs.deinit();
    try verifyAttributes(attrs);
    try std.testing.expectEqual(@as(usize, 0), source.working.live);
}

test "EROFS packed prefix reading releases every Source and slice allocation failure" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(work: std.mem.Allocator, image: []const u8, source_mode: bool) !void {
            if (source_mode) {
                var input = helpers.Input{ .bytes = image };
                var source = try source_archive.SourceArchive.init(work, input.source(), .{});
                defer source.deinit();
                const inode = try source.lookup("file", expected_data.len, 4096);
                var attrs = try source.readXattrsAllocLimited(work, inode, 2, 128);
                defer attrs.deinit();
                try verifyAttributes(attrs);
            } else {
                const slice = try archive_module.Archive.init(image);
                const inode = try slice.lookup(work, "file", expected_data.len, 4096);
                var attrs = try slice.readXattrsAllocLimited(work, inode, 2, 128);
                defer attrs.deinit();
                try verifyAttributes(attrs);
            }
        }
    };
    for (fixtures) |encoded| {
        const image = try fixtureAlloc(allocator, encoded);
        defer allocator.free(image);
        try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ image, true });
        try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ image, false });
    }
}

test "EROFS packed prefixes validate modern extent metadata after the selected records" {
    const allocator = std.testing.allocator;
    const image = try syntheticWithPattern(allocator, &.{"user.vort."}, 0, 32768, .lz4, true);
    defer allocator.free(image);
    const original = try archive_module.Archive.init(image);
    const value = try original.inode(original.superblock.packed_nid);
    const inode = try original.lookup(allocator, "file", 0, 4096);
    try std.testing.expectEqual(@as(u16, 0), format.readU16(image, value.compressed_index_start) & 3);
    const physical = format.readU32(image, value.compressed_index_start + 4) * @as(u32, 4096);
    const header = value.compressed_header_start;
    const record = std.mem.alignForward(usize, header + 8, 16);
    std.mem.writeInt(u32, image[header..][0..4], 1, .little);
    std.mem.writeInt(u16, image[header + 4 ..][0..2], 5, .little);
    std.mem.writeInt(u16, image[header + 6 ..][0..2], 0, .little);
    @memset(image[record..][0..48], 0);
    std.mem.writeInt(u32, image[record..][0..4], 32768, .little);
    std.mem.writeInt(u32, image[record + 4 ..][0..4], physical, .little);
    refreshChecksum(image);
    const slice = try archive_module.Archive.init(image);
    var attrs = try slice.readXattrsAllocLimited(allocator, inode, 1, 128);
    defer attrs.deinit();
    try std.testing.expectEqualStrings("last-prefix", attrs.find("user.vort.").?.value);
    var input = helpers.Input{ .bytes = image };
    var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer source.deinit();
    var source_attrs = try source.readXattrsAllocLimited(allocator, inode, 1, 128);
    defer source_attrs.deinit();
    try std.testing.expectEqualStrings("last-prefix", source_attrs.find("user.vort.").?.value);
    // The selected first range remains readable, but later duplicate logical
    // starts must fail metadata validation before returning any attributes.
    std.mem.writeInt(u32, image[header..][0..4], 3, .little);
    std.mem.writeInt(u32, image[record..][0..4], 4096, .little);
    for (1..3) |index| {
        std.mem.writeInt(u32, image[record + index * 16 ..][0..4], 4096, .little);
        std.mem.writeInt(u32, image[record + index * 16 + 4 ..][0..4], physical + 4096, .little);
        std.mem.writeInt(u32, image[record + index * 16 + 12 ..][0..4], 4096, .little);
    }
    try std.testing.expectError(error.InvalidErofs, slice.readXattrsAllocLimited(allocator, inode, 1, 128));
    try std.testing.expectError(error.InvalidErofs, source.readXattrsAllocLimited(allocator, inode, 1, 128));
    try std.testing.expectEqual(@as(usize, 0), source.working.live);
}

test "EROFS metabox prefix priority and invalid table loading preserve ownership" {
    const allocator = std.testing.allocator;
    const image = try fixtureAlloc(allocator, @embedFile("../../testdata/metabox-xattr.erofs.b64"));
    defer allocator.free(image);
    const original = try archive_module.Archive.init(image);
    std.mem.writeInt(u32, image[1104..1108], original.superblock.feature_incompat | format.feature_incompat_fragments, .little);
    std.mem.writeInt(u64, image[1120..1128], std.math.maxInt(u64) >> 1, .little);
    refreshChecksum(image);
    const slice = try archive_module.Archive.init(image);
    var loaded = try slice.loadMetaboxAllocLimited(allocator, 1024 * 1024, 1024 * 1024);
    defer loaded.deinit();
    const inode = try loaded.archive.lookup(allocator, "a", 0, 4096);
    var attrs = try loaded.archive.readXattrsAllocLimited(allocator, inode, 2, 128);
    defer attrs.deinit();
    try std.testing.expectEqualStrings("value", attrs.find("user.vort.repeat").?.value);
    var input = helpers.Input{ .bytes = image };
    var source = try source_archive.SourceArchive.init(allocator, input.source(), .{});
    defer source.deinit();
    var source_attrs = try source.readXattrsAllocLimited(allocator, inode, 2, 128);
    defer source_attrs.deinit();
    try std.testing.expectEqualStrings("value", source_attrs.find("user.vort.repeat").?.value);
    std.mem.writeInt(u32, image[1116..1120], std.math.maxInt(u32), .little);
    refreshChecksum(image);
    const bad_slice = try archive_module.Archive.init(image);
    try std.testing.expectError(error.TruncatedFrame, bad_slice.loadMetaboxAllocLimited(allocator, 1024 * 1024, 1024 * 1024));
    var deferred = try source_archive.SourceArchive.init(allocator, input.source(), .{ .load_metabox = false });
    defer deferred.deinit();
    try std.testing.expectError(error.TruncatedFrame, deferred.loadMetabox());
    try std.testing.expectEqual(@as(usize, 0), deferred.working.live);
    try std.testing.expectError(error.TruncatedFrame, source_archive.SourceArchive.init(allocator, input.source(), .{}));
}

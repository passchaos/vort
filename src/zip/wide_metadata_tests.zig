const std = @import("std");
const core = @import("../core.zig");
const checksum = @import("../checksum.zig");
const records = @import("records.zig");
const wire = @import("wire.zig");
const zstd = @import("../zstd.zig");
const frame_fixture = @import("../tests/zstd_decoded_count/helpers.zig");
const a = std.testing.allocator;
const Count = core.StreamCount;
const boundary: Count = @as(Count, 1) << 32;
pub const wide_size: Count = boundary + 3;
const sentinel = std.math.maxInt(u32);
const tiny_name = "tiny.bin";
const wide_name = "wide-rle.zst";

fn repeatedCrc(byte: u8, size: Count) u32 {
    var left = size;
    var result: u32 = 0;
    var power = checksum.Crc32.hash(&.{byte});
    var power_len: u64 = 1;
    while (left != 0) {
        if (left & 1 != 0) result = checksum.crc32Combine(result, power, power_len);
        left >>= 1;
        if (left != 0) {
            power = checksum.crc32Combine(power, power, power_len);
            power_len *= 2;
        }
    }
    return result;
}

pub const Fixture = struct {
    bytes: []u8,
    local_offset: usize,
    data_offset: usize,
    compressed_size: usize,
    central_offset: usize,
    central_extra_offset: usize,
    local_extra_offset: usize,
    crc: u32,

    pub fn deinit(self: *Fixture) void {
        a.free(self.bytes);
        self.* = undefined;
    }
};

/// A complete addressable archive: a tiny stored member followed by a real
/// Zstandard frame of 32K 128-KiB RLE blocks and the literal suffix "abc".
/// ZIP64 carries the >4-GiB output size; every archive span fits local memory.
pub fn fixtureAlloc() !Fixture {
    const frame = try frame_fixture.wideAlloc(.raw, wide_size, null);
    defer a.free(frame);
    @memcpy(frame[frame.len - 3 ..], "abc");
    try std.testing.expectEqual(wide_size, try zstd.decodedFrameSize(frame));
    const crc = checksum.crc32Combine(repeatedCrc('R', boundary), checksum.Crc32.hash("abc"), 3);
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(a);
    const tiny = wire.EncodedEntry{
        .name = tiny_name,
        .comment = "",
        .method = .stored,
        .flags = 0,
        .crc32 = checksum.Crc32.hash("abc"),
        .compressed_size = 3,
        .uncompressed_size = 3,
        .local_header_offset = 0,
        .zip64 = false,
    };
    try wire.appendLocalHeader(a, &bytes, tiny, .{});
    try bytes.appendSlice(a, "abc");
    const local_offset = bytes.items.len;
    const wide = wire.EncodedEntry{
        .name = wide_name,
        .comment = "logical ZIP64 size",
        .method = .zstandard,
        .flags = 0,
        .crc32 = crc,
        .compressed_size = frame.len,
        .uncompressed_size = wide_size,
        .local_header_offset = local_offset,
        .zip64 = true,
    };
    try wire.appendLocalHeader(a, &bytes, wide, .{});
    const data_offset = bytes.items.len;
    try bytes.appendSlice(a, frame);
    const directory_offset = bytes.items.len;
    try wire.appendCentralHeader(a, &bytes, tiny);
    const central_offset = bytes.items.len;
    try wire.appendCentralHeader(a, &bytes, wide);
    const directory_size = bytes.items.len - directory_offset;
    try wire.appendZip64End(a, &bytes, 0, 2, directory_size, directory_offset, "addressable ZIP64");
    return .{
        .bytes = try bytes.toOwnedSlice(a),
        .local_offset = local_offset,
        .data_offset = data_offset,
        .compressed_size = frame.len,
        .central_offset = central_offset,
        .central_extra_offset = central_offset + wire.central_file_header_len + wide_name.len,
        .local_extra_offset = local_offset + wire.local_file_header_len + wide_name.len,
        .crc = crc,
    };
}

fn proveCrcAndFrame() !void {
    var payload: [1027]u8 = @splat('R');
    for ([_]usize{ 0, 1, 2, 17, 1024 }) |n| {
        @memset(&payload, 'R');
        @memcpy(payload[n..][0..3], "abc");
        const crc = checksum.crc32Combine(repeatedCrc('R', n), checksum.Crc32.hash("abc"), 3);
        try std.testing.expectEqual(checksum.Crc32.hash(payload[0 .. n + 3]), crc);
    }
    var small: std.ArrayList(u8) = .empty;
    defer small.deinit(a);
    try frame_fixture.header(&small, 1027, null);
    try frame_fixture.block(&small, 1, 1024, false);
    try small.append(a, 'R');
    try frame_fixture.block(&small, 0, 3, true);
    try small.appendSlice(a, "abc");
    @memset(payload[0..1024], 'R');
    @memcpy(payload[1024..], "abc");
    var output: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try zstd.decodeFrameInto(small.items, &output));
    try std.testing.expectEqualSlices(u8, &payload, &output);
}

fn metadata(comptime Z: type, f: Fixture) !void {
    const archive = try Z.parse(f.bytes);
    try std.testing.expect(archive.zip64);
    try std.testing.expectEqual(@as(usize, 2), archive.entry_count);
    try std.testing.expectEqualStrings("addressable ZIP64", archive.comment);
    const entry = try archive.entryAt(1);
    try std.testing.expect(entry.zip64);
    try std.testing.expectEqual(wide_size, entry.uncompressed_size);
    try std.testing.expectEqual(f.compressed_size, entry.compressed_size);
    try std.testing.expectEqual(f.local_offset, entry.local_header_offset);
    try std.testing.expectEqual(f.central_offset, entry.central_header_offset);
    try std.testing.expectEqual(f.crc, entry.crc32);
    try std.testing.expectEqual(Z.CompressionMethod.zstandard, entry.method);
    try std.testing.expectEqualDeep(entry, (try archive.find(wide_name)).?);
    try std.testing.expectEqualDeep(entry, (try archive.findRaw(wide_name)).?);
    try std.testing.expectEqual(@as(?Z.Entry, null), try archive.find("absent"));
    try std.testing.expectError(error.RangeOutOfBounds, archive.entryAt(2));
    var iterator = archive.iterator();
    const tiny = (try iterator.next()).?;
    try std.testing.expectEqualStrings(tiny_name, tiny.name);
    try std.testing.expect(!tiny.zip64);
    try std.testing.expectEqualDeep(entry, (try iterator.next()).?);
    try std.testing.expectEqual(@as(?Z.Entry, null), try iterator.next());
    const listed = try archive.entriesAlloc(a);
    defer a.free(listed);
    try std.testing.expectEqual(@as(usize, 2), listed.len);
    try std.testing.expectEqualDeep(entry, listed[1]);
    inline for (.{ "compressedData", "rawEntryData" }) |method| {
        const compressed = try @field(@TypeOf(archive), method)(archive, entry);
        try std.testing.expectEqual(f.compressed_size, compressed.len);
        try std.testing.expectEqual(@intFromPtr(f.bytes.ptr) + f.data_offset, @intFromPtr(compressed.ptr));
        try std.testing.expectEqual(wide_size, try zstd.decodedFrameSize(compressed));
    }
    var tiny_output: [3]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 3), try archive.extractInto(tiny, &tiny_output));
    try std.testing.expectEqualSlices(u8, "abc", &tiny_output);
    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    var guard: [32]u8 = @splat(0x5a);
    for ([_]Count{ wide_size - 1, 3 }) |forged_size| {
        var forged = entry;
        forged.uncompressed_size = forged_size;
        try std.testing.expectError(error.InvalidZipArchive, archive.compressedData(forged));
        try std.testing.expectError(error.InvalidZipArchive, archive.rawEntryData(forged));
        try std.testing.expectError(error.InvalidZipArchive, archive.extractInto(forged, &guard));
        try std.testing.expectError(error.InvalidZipArchive, archive.extractIntoWithOptions(failing.allocator(), forged, &guard, .{ .max_output_len = 2 }));
        try std.testing.expectError(error.InvalidZipArchive, archive.extractAlloc(failing.allocator(), forged));
        try std.testing.expectError(error.InvalidZipArchive, archive.extractAllocLimited(failing.allocator(), forged, 2));
        for (guard) |byte| try std.testing.expectEqual(@as(u8, 0x5a), byte);
        try std.testing.expect(!failing.has_induced_failure);
        try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
        try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    }
}

fn physicalOutput(comptime Z: type, f: Fixture) !void {
    const archive = try Z.parse(f.bytes);
    const entry = try archive.entryAt(1);
    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    var guard: [32]u8 = @splat(0x5a);
    try std.testing.expectError(error.OutputTooSmall, archive.extractInto(entry, &guard));
    try std.testing.expectError(error.OutputTooSmall, archive.extractIntoWithAllocator(failing.allocator(), entry, &guard));
    try std.testing.expectError(error.OutputTooSmall, Z.extractEntryInto(f.bytes, 1, &guard));
    try std.testing.expectError(error.OutputLimitExceeded, archive.extractIntoWithOptions(failing.allocator(), entry, &guard, .{ .max_output_len = boundary }));
    try std.testing.expectError(error.OutputTooSmall, archive.extractIntoWithOptions(failing.allocator(), entry, &guard, .{ .max_output_len = wide_size }));
    try std.testing.expectError(error.OutputLimitExceeded, archive.extractAllocLimited(failing.allocator(), entry, boundary));
    try std.testing.expectError(error.OutputLimitExceeded, archive.extractByNameAllocLimited(failing.allocator(), wide_name, boundary));
    for (guard) |byte| try std.testing.expectEqual(@as(u8, 0x5a), byte);
    try std.testing.expect(!failing.has_induced_failure);
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    if (@bitSizeOf(usize) < 64) {
        // Conversion fails before attempting any physical allocation.
        try std.testing.expectError(error.IntegerOverflow, archive.extractAlloc(failing.allocator(), entry));
        try std.testing.expectError(error.IntegerOverflow, archive.extractAllocLimited(failing.allocator(), entry, wide_size));
        try std.testing.expectError(error.IntegerOverflow, archive.extractByNameAllocLimited(failing.allocator(), wide_name, wide_size));
        try std.testing.expect(!failing.has_induced_failure);
    } else {
        // The native length is representable; an intentional first-allocation
        // failure proves the request reaches the allocator without allocating.
        try std.testing.expectError(error.OutOfMemory, archive.extractAlloc(failing.allocator(), entry));
        try std.testing.expect(failing.has_induced_failure);
        try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    }
}

fn extraValues(output: Count, compressed: Count, offset: Count) [28]u8 {
    var extra: [28]u8 = undefined;
    std.mem.writeInt(u16, extra[0..2], wire.zip64_extra_id, .little);
    std.mem.writeInt(u16, extra[2..4], 24, .little);
    std.mem.writeInt(u64, extra[4..12], output, .little);
    std.mem.writeInt(u64, extra[12..20], compressed, .little);
    std.mem.writeInt(u64, extra[20..28], offset, .little);
    return extra;
}

fn resolverContracts() !void {
    const extra = extraValues(boundary + 17, boundary + 11, boundary + 23);
    const logical = try records.resolveCentralEntryLogical(&extra, sentinel, sentinel, sentinel, 0);
    try std.testing.expectEqual(boundary + 17, logical.uncompressed_size);
    try std.testing.expectEqual(boundary + 11, logical.compressed_size);
    try std.testing.expectEqual(boundary + 23, logical.local_header_offset);
    try std.testing.expect(logical.zip64);
    const local = try records.resolveLocalSizesLogical(&extra, sentinel, sentinel);
    try std.testing.expectEqual(logical.uncompressed_size, local.uncompressed_size);
    try std.testing.expectEqual(logical.compressed_size, local.compressed_size);
    if (@bitSizeOf(usize) < 64) {
        try std.testing.expectError(error.UnsupportedZipFeature, records.resolveCentralEntry(&extra, sentinel, sentinel, sentinel, 0));
        try std.testing.expectError(error.UnsupportedZipFeature, records.resolveLocalSizes(&extra, sentinel, sentinel));
        const offset_only = extraValues(boundary + 17, 77, boundary + 23);
        try std.testing.expectError(error.UnsupportedZipFeature, records.resolveCentralEntry(&offset_only, sentinel, sentinel, sentinel, 0));
    } else {
        const physical = try records.resolveCentralEntry(&extra, sentinel, sentinel, sentinel, 0);
        try std.testing.expectEqual(logical.compressed_size, physical.compressed_size);
        try std.testing.expectEqual(logical.local_header_offset, physical.local_header_offset);
    }
    const addressable = extraValues(boundary + 17, 77, 9);
    const physical = try records.resolveCentralEntry(&addressable, sentinel, sentinel, sentinel, 0);
    try std.testing.expectEqual(boundary + 17, physical.uncompressed_size);
    try std.testing.expectEqual(@as(usize, 77), physical.compressed_size);
    try std.testing.expectEqual(@as(usize, 9), physical.local_header_offset);
    try std.testing.expectEqual(boundary + 17, (try records.resolveLocalSizes(&addressable, sentinel, sentinel)).uncompressed_size);
    // ZIP64 stores only fields whose legacy values are sentinels, in order.
    const output_only = addressable[0..12].*;
    var one = output_only;
    std.mem.writeInt(u16, one[2..4], 8, .little);
    const ordered = try records.resolveCentralEntryLogical(&one, 77, sentinel, 9, 0);
    try std.testing.expectEqual(boundary + 17, ordered.uncompressed_size);
    try std.testing.expectEqual(@as(Count, 77), ordered.compressed_size);
    try std.testing.expectEqual(@as(Count, 9), ordered.local_header_offset);
    const maximum = extraValues(std.math.maxInt(Count), std.math.maxInt(Count), std.math.maxInt(Count));
    const largest = try records.resolveCentralEntryLogical(&maximum, sentinel, sentinel, sentinel, 0);
    try std.testing.expectEqual(@as(Count, std.math.maxInt(Count)), largest.uncompressed_size);
    try std.testing.expectEqual(largest.uncompressed_size, largest.compressed_size);
    try std.testing.expectEqual(largest.uncompressed_size, largest.local_header_offset);
    for ([_][]const u8{ "", extra[0..3], extra[0..27] }) |invalid| {
        try std.testing.expectError(error.InvalidZipArchive, records.resolveCentralEntryLogical(invalid, sentinel, sentinel, sentinel, 0));
        try std.testing.expectError(error.InvalidZipArchive, records.resolveLocalSizesLogical(invalid, sentinel, sentinel));
    }
    const duplicate = extra ++ extra;
    try std.testing.expectError(error.InvalidZipArchive, records.resolveCentralEntryLogical(&duplicate, sentinel, sentinel, sentinel, 0));
    try std.testing.expectError(error.InvalidZipArchive, records.resolveLocalSizesLogical(&duplicate, sentinel, sentinel));
}

fn malformedArchive(comptime Z: type, f: Fixture) !void {
    const mutations = [_]struct { offset: usize, value: u64 }{
        .{ .offset = f.local_extra_offset + 4, .value = wide_size - 1 },
        .{ .offset = f.local_extra_offset + 12, .value = f.compressed_size - 1 },
        .{ .offset = f.central_extra_offset + 4, .value = wide_size + 1 },
        .{ .offset = f.central_extra_offset + 12, .value = f.compressed_size + 1 },
    };
    for (mutations) |mutation| {
        const bad = try a.dupe(u8, f.bytes);
        defer a.free(bad);
        std.mem.writeInt(u64, bad[mutation.offset..][0..8], mutation.value, .little);
        const archive = try Z.parse(bad);
        const entry = try archive.entryAt(1);
        try std.testing.expectError(error.InvalidZipArchive, archive.rawEntryData(entry));
        try std.testing.expectError(error.InvalidZipArchive, archive.compressedData(entry));
    }
    for ([_]struct { offset: usize, value: u16 }{
        .{ .offset = f.central_extra_offset + 2, .value = 23 },
        .{ .offset = f.central_extra_offset, .value = 2 },
        .{ .offset = f.local_offset + 28, .value = 19 },
    }) |mutation| {
        const bad = try a.dupe(u8, f.bytes);
        defer a.free(bad);
        std.mem.writeInt(u16, bad[mutation.offset..][0..2], mutation.value, .little);
        const archive = try Z.parse(bad);
        try std.testing.expectError(error.InvalidZipArchive, archive.entryAt(1));
    }
    try std.testing.expectError(error.InvalidZipArchive, Z.parse(f.bytes[0 .. f.bytes.len - 1]));
    try std.testing.expectError(error.InvalidZipArchive, Z.parse(f.bytes[0..f.central_offset]));
    for ([_]usize{ f.central_extra_offset + 12, f.central_extra_offset + 20 }) |offset| {
        const bad = try a.dupe(u8, f.bytes);
        defer a.free(bad);
        std.mem.writeInt(u64, bad[offset..][0..8], boundary + 31, .little);
        const archive = try Z.parse(bad);
        if (@bitSizeOf(usize) < 64) {
            try std.testing.expectError(error.UnsupportedZipFeature, archive.entryAt(1));
        } else if (offset == f.central_extra_offset + 20) {
            try std.testing.expectError(error.InvalidZipArchive, archive.entryAt(1));
        } else {
            const entry = try archive.entryAt(1);
            try std.testing.expectError(error.InvalidZipArchive, archive.rawEntryData(entry));
        }
    }
}

pub fn contracts(comptime Z: type) !void {
    try std.testing.expectEqual(if (@bitSizeOf(usize) < 64) u64 else usize, Count);
    try std.testing.expectEqual(Count, @FieldType(Z.Entry, "uncompressed_size"));
    try std.testing.expectEqual(Count, @FieldType(Z.DecodeOptions, "max_output_len"));
    inline for (.{ "compressed_size", "local_header_offset", "central_header_offset" }) |field|
        try std.testing.expectEqual(usize, @FieldType(Z.Entry, field));
    inline for (.{ "entry_count", "central_directory_offset", "central_directory_size" }) |field|
        try std.testing.expectEqual(usize, @FieldType(Z.Archive, field));
    inline for (.{ "compressed_size", "uncompressed_size", "local_header_offset" }) |field|
        try std.testing.expectEqual(Count, @FieldType(records.LogicalCentralEntryValues, field));
    inline for (.{ "compressed_size", "uncompressed_size" }) |field|
        try std.testing.expectEqual(Count, @FieldType(records.LogicalLocalSizes, field));
    try std.testing.expectEqual(Count, @FieldType(records.CentralEntryValues, "uncompressed_size"));
    try std.testing.expectEqual(Count, @FieldType(records.LocalSizes, "uncompressed_size"));
    try std.testing.expectEqual(usize, @FieldType(records.LocalSizes, "compressed_size"));
    try proveCrcAndFrame();
    try resolverContracts();
    var f = try fixtureAlloc();
    defer f.deinit();
    try metadata(Z, f);
    try physicalOutput(Z, f);
    try malformedArchive(Z, f);
}

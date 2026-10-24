//! Caller-ordered WIM/SWM part-set routing.

const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const metadata = @import("metadata.zig");
const solid = @import("solid.zig");

pub const Error = archive_mod.Error || metadata.Error || solid.Error ||
    std.mem.Allocator.Error || error{InvalidWimSet};

pub const ArchiveSet = struct {
    /// Borrowed archives in exact part-number order. Their bytes and this slice
    /// remain stable for the lifetime of the set.
    parts: []const archive_mod.Archive,

    pub fn init(parts: []const archive_mod.Archive) Error!ArchiveSet {
        if (parts.len == 0 or parts.len > std.math.maxInt(u16))
            return error.InvalidWimSet;
        const first = parts[0].header;
        if (first.part_number != 1 or first.total_parts != parts.len)
            return error.InvalidWimSet;
        for (parts, 0..) |part, index| {
            const header = part.header;
            if (header.part_number != index + 1 or
                header.total_parts != first.total_parts or
                header.pipable != first.pipable or
                !std.mem.eql(u8, &header.guid, &first.guid) or
                header.version != first.version or
                header.compression != first.compression or
                header.chunk_size != first.chunk_size or
                header.image_count != first.image_count or
                header.boot_index != first.boot_index)
                return error.InvalidWimSet;
        }
        return .{ .parts = parts };
    }

    pub fn primary(self: ArchiveSet) archive_mod.Archive {
        return self.parts[0];
    }

    pub fn readXmlAllocLimited(
        self: ArchiveSet,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        return self.primary().readXmlAllocLimited(allocator, max_output_len);
    }

    pub fn readLookupTableAlloc(
        self: ArchiveSet,
        allocator: std.mem.Allocator,
        max_entries: usize,
        max_table_bytes: usize,
    ) Error!archive_mod.LookupTable {
        const lookup = try self.readLookupTablesAlloc(
            allocator,
            max_entries,
            max_table_bytes,
        );
        return lookup;
    }

    fn readLookupTablesAlloc(
        self: ArchiveSet,
        allocator: std.mem.Allocator,
        max_entries: usize,
        max_table_bytes: usize,
    ) Error!archive_mod.LookupTable {
        var bytes: std.ArrayList(u8) = .empty;
        defer bytes.deinit(allocator);
        var entries: std.ArrayList(archive_mod.LookupEntry) = .empty;
        defer entries.deinit(allocator);
        for (self.parts) |part| {
            var part_lookup = try part.readLookupTableRawAlloc(
                allocator,
                max_entries - entries.items.len,
                max_table_bytes - bytes.items.len,
            );
            defer part_lookup.deinit();
            for (part_lookup.entries) |entry| {
                if (entry.part_number != part.header.part_number)
                    return error.InvalidWim;
                if (part.header.pipable and entry.resource.isSolid())
                    return error.InvalidWim;
            }
            try solid.resolveEntries(
                allocator,
                part.bytes,
                part.header.version,
                part_lookup.entries,
            );
            try bytes.appendSlice(allocator, part_lookup.bytes);
            try entries.appendSlice(allocator, part_lookup.entries);
        }
        const owned_bytes = try bytes.toOwnedSlice(allocator);
        errdefer allocator.free(owned_bytes);
        return .{
            .allocator = allocator,
            .bytes = owned_bytes,
            .entries = try entries.toOwnedSlice(allocator),
        };
    }

    pub fn extractBySha1AllocLimited(
        self: ArchiveSet,
        allocator: std.mem.Allocator,
        sha1: *const [20]u8,
        max_output_len: usize,
        max_lookup_entries: usize,
        max_lookup_bytes: usize,
    ) Error![]u8 {
        var lookup = try self.readLookupTableAlloc(
            allocator,
            max_lookup_entries,
            max_lookup_bytes,
        );
        defer lookup.deinit();
        const entry = lookup.find(sha1) orelse return error.WimResourceNotFound;
        return self.extractEntryAllocLimitedWithSolidLimit(
            allocator,
            entry,
            max_output_len,
            max_output_len,
        );
    }

    pub fn readImageMetadataAlloc(
        self: ArchiveSet,
        allocator: std.mem.Allocator,
        image_index: u32,
        limits: archive_mod.PathLimits,
    ) Error!metadata.ImageMetadata {
        var lookup = try self.readLookupTableAlloc(
            allocator,
            limits.max_lookup_entries,
            limits.max_lookup_bytes,
        );
        defer lookup.deinit();
        const entry = try self.imageMetadataEntry(lookup, image_index);
        const bytes = try self.extractEntryAllocLimitedWithSolidLimit(
            allocator,
            entry,
            limits.max_metadata_bytes,
            limits.max_solid_chunk_bytes,
        );
        return metadata.ImageMetadata.fromOwnedBytes(allocator, bytes);
    }

    pub fn extractByPathAllocLimited(
        self: ArchiveSet,
        allocator: std.mem.Allocator,
        image_index: u32,
        path: []const u8,
        max_output_len: usize,
        limits: archive_mod.PathLimits,
    ) Error![]u8 {
        return self.extractPathStreamAllocLimited(
            allocator,
            image_index,
            path,
            .default,
            max_output_len,
            limits,
        );
    }

    pub fn extractNamedStreamByPathAllocLimited(
        self: ArchiveSet,
        allocator: std.mem.Allocator,
        image_index: u32,
        path: []const u8,
        stream_name: []const u8,
        max_output_len: usize,
        limits: archive_mod.PathLimits,
    ) Error![]u8 {
        return self.extractPathStreamAllocLimited(
            allocator,
            image_index,
            path,
            .{ .named = stream_name },
            max_output_len,
            limits,
        );
    }

    pub fn extractReparseDataByPathAllocLimited(
        self: ArchiveSet,
        allocator: std.mem.Allocator,
        image_index: u32,
        path: []const u8,
        max_output_len: usize,
        limits: archive_mod.PathLimits,
    ) Error![]u8 {
        return self.extractPathStreamAllocLimited(
            allocator,
            image_index,
            path,
            .reparse,
            max_output_len,
            limits,
        );
    }

    /// Extracts the opaque EFSRPC raw stream from its owning SWM part.
    pub fn extractEncryptedRawByPathAllocLimited(
        self: ArchiveSet,
        allocator: std.mem.Allocator,
        image_index: u32,
        path: []const u8,
        max_output_len: usize,
        limits: archive_mod.PathLimits,
    ) Error![]u8 {
        return self.extractPathStreamAllocLimited(
            allocator,
            image_index,
            path,
            .encrypted_raw,
            max_output_len,
            limits,
        );
    }

    pub fn extractEntryAllocLimitedWithSolidLimit(
        self: ArchiveSet,
        allocator: std.mem.Allocator,
        entry: archive_mod.LookupEntry,
        max_output_len: usize,
        max_solid_chunk_bytes: usize,
    ) Error![]u8 {
        const part = try self.partAt(entry.part_number);
        return part.extractEntryAllocLimitedWithSolidLimit(
            allocator,
            entry,
            max_output_len,
            max_solid_chunk_bytes,
        );
    }

    fn extractPathStreamAllocLimited(
        self: ArchiveSet,
        allocator: std.mem.Allocator,
        image_index: u32,
        path: []const u8,
        stream: archive_mod.StreamSelector,
        max_output_len: usize,
        limits: archive_mod.PathLimits,
    ) Error![]u8 {
        var lookup = try self.readLookupTableAlloc(
            allocator,
            limits.max_lookup_entries,
            limits.max_lookup_bytes,
        );
        defer lookup.deinit();
        const metadata_entry = try self.imageMetadataEntry(lookup, image_index);
        const metadata_bytes = try self.extractEntryAllocLimitedWithSolidLimit(
            allocator,
            metadata_entry,
            limits.max_metadata_bytes,
            limits.max_solid_chunk_bytes,
        );
        var image = try metadata.ImageMetadata.fromOwnedBytes(allocator, metadata_bytes);
        defer image.deinit();
        const dentry = try image.lookup(
            allocator,
            path,
            limits.max_directory_entries,
            limits.max_path_depth,
        );
        const hash = try archive_mod.selectDentryStreamSha1Alloc(
            allocator,
            dentry,
            stream,
        );
        if (std.mem.allEqual(u8, &hash, 0)) return allocator.alloc(u8, 0);
        const entry = lookup.findData(&hash) orelse return error.WimResourceNotFound;
        return self.extractEntryAllocLimitedWithSolidLimit(
            allocator,
            entry,
            max_output_len,
            limits.max_solid_chunk_bytes,
        );
    }

    fn imageMetadataEntry(
        self: ArchiveSet,
        lookup: archive_mod.LookupTable,
        image_index: u32,
    ) Error!archive_mod.LookupEntry {
        const header = self.primary().header;
        if (image_index == 0 or image_index > header.image_count)
            return error.WimImageNotFound;
        var count: u32 = 0;
        var selected: ?archive_mod.LookupEntry = null;
        for (lookup.entries) |entry| {
            if (!entry.resource.isMetadata() or entry.reference_count == 0) continue;
            if (entry.reference_count != 1 or entry.hashIsZero() or
                entry.resource.isSolid() or entry.resource.isSpanned())
                return error.InvalidWim;
            _ = try self.partAt(entry.part_number);
            count = std.math.add(u32, count, 1) catch return error.IntegerOverflow;
            if (count == image_index) selected = entry;
        }
        if (count != header.image_count) return error.InvalidWim;
        return selected orelse error.WimImageNotFound;
    }

    fn partAt(self: ArchiveSet, part_number: u16) Error!archive_mod.Archive {
        if (part_number == 0 or part_number > self.parts.len)
            return error.InvalidWimSet;
        return self.parts[part_number - 1];
    }

    const PartContext = struct {
        set: ArchiveSet,

        fn bytesForPart(context: *anyopaque, part_number: u16) solid.Error![]const u8 {
            const self: *@This() = @ptrCast(@alignCast(context));
            const part = self.set.partAt(part_number) catch return error.InvalidWim;
            return part.bytes;
        }
    };
};

fn fixtureAlloc(allocator: std.mem.Allocator, encoded_base64: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(
        u8,
        decoder.calcSizeUpperBound(encoded_base64.len),
    );
    errdefer allocator.free(bytes);
    const written = try decoder.decode(bytes, encoded_base64);
    return allocator.realloc(bytes, written);
}

test "WIM archive set validates order and routes cross-part resources" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/xpress-small.wim.b64"),
    );
    defer allocator.free(bytes);
    var first = try archive_mod.Archive.init(bytes);
    first.header.part_number = 1;
    first.header.total_parts = 2;
    var second = try archive_mod.Archive.init(bytes);
    second.header.part_number = 2;
    second.header.total_parts = 2;
    second.header.lookup_table = .{
        .size_in_wim = 0,
        .flags = 0,
        .offset_in_wim = 0,
        .uncompressed_size = 0,
    };
    const parts = [_]archive_mod.Archive{ first, second };
    const set = try ArchiveSet.init(&parts);
    var lookup = try set.readLookupTableAlloc(allocator, 16, 4096);
    defer lookup.deinit();
    try std.testing.expectEqual(@as(usize, 2), lookup.entries.len);
    var file_entry = lookup.entries[0];
    if (file_entry.resource.isMetadata()) file_entry = lookup.entries[1];
    file_entry.part_number = 2;
    try std.testing.expectError(
        error.WimResourceInOtherPart,
        first.extractEntryAllocLimited(allocator, file_entry, 1024),
    );
    const output = try set.extractEntryAllocLimitedWithSolidLimit(
        allocator,
        file_entry,
        1024,
        1024,
    );
    defer allocator.free(output);
    try std.testing.expectEqualStrings("hello WIM XPRESS payload\n", output);
    const by_path = try set.extractByPathAllocLimited(
        allocator,
        1,
        "/nested/file.txt",
        1024,
        .{
            .max_metadata_bytes = 4096,
            .max_lookup_entries = 16,
            .max_lookup_bytes = 4096,
            .max_directory_entries = 16,
            .max_path_depth = 8,
        },
    );
    defer allocator.free(by_path);
    try std.testing.expectEqualSlices(u8, output, by_path);

    const reversed = [_]archive_mod.Archive{ second, first };
    try std.testing.expectError(error.InvalidWimSet, ArchiveSet.init(&reversed));
    try std.testing.expectError(error.InvalidWimSet, ArchiveSet.init(parts[0..1]));
    var wrong_guid = second;
    wrong_guid.header.guid[0] ^= 1;
    const mismatched = [_]archive_mod.Archive{ first, wrong_guid };
    try std.testing.expectError(error.InvalidWimSet, ArchiveSet.init(&mismatched));
}

test "WIM archive set merges per-part pipable lookup tables" {
    const allocator = std.testing.allocator;
    const first_bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/pipable-xpress.wim.b64"),
    );
    defer allocator.free(first_bytes);
    const second_bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/pipable-xpress.wim.b64"),
    );
    defer allocator.free(second_bytes);
    var first = try archive_mod.Archive.init(first_bytes);
    first.header.total_parts = 2;
    first.header.lookup_table = .{
        .size_in_wim = 0,
        .flags = 0,
        .offset_in_wim = 0,
        .uncompressed_size = 0,
    };
    var second = try archive_mod.Archive.init(second_bytes);
    second.header.part_number = 2;
    second.header.total_parts = 2;
    const lookup_start: usize = @intCast(second.header.lookup_table.offset_in_wim);
    const lookup_len: usize = @intCast(second.header.lookup_table.uncompressed_size);
    try std.testing.expectEqual(@as(usize, 0), lookup_len % format.lookup_entry_size);
    for (0..lookup_len / format.lookup_entry_size) |index| {
        const part_offset = lookup_start + index * format.lookup_entry_size + 24;
        std.mem.writeInt(u16, second_bytes[part_offset..][0..2], 2, .little);
    }
    const parts = [_]archive_mod.Archive{ first, second };
    const set = try ArchiveSet.init(&parts);
    var lookup = try set.readLookupTableAlloc(allocator, 16, 4096);
    defer lookup.deinit();
    try std.testing.expectEqual(@as(usize, 2), lookup.entries.len);
    for (lookup.entries) |entry|
        try std.testing.expectEqual(@as(u16, 2), entry.part_number);
    const expected = @embedFile("../lzms/testdata/lzms-small.txt");
    const output = try set.extractByPathAllocLimited(
        allocator,
        1,
        "/nested/payload.txt",
        expected.len,
        .{
            .max_metadata_bytes = 4096,
            .max_lookup_entries = 16,
            .max_lookup_bytes = 4096,
            .max_directory_entries = 16,
            .max_path_depth = 8,
        },
    );
    defer allocator.free(output);
    try std.testing.expectEqualStrings(expected, output);
}

test "WIM archive set releases lookup and routed extraction failures" {
    const bytes = try fixtureAlloc(
        std.testing.allocator,
        @embedFile("testdata/xpress-small.wim.b64"),
    );
    defer std.testing.allocator.free(bytes);
    var first = try archive_mod.Archive.init(bytes);
    first.header.part_number = 1;
    first.header.total_parts = 2;
    var second = try archive_mod.Archive.init(bytes);
    second.header.part_number = 2;
    second.header.total_parts = 2;
    second.header.lookup_table = .{
        .size_in_wim = 0,
        .flags = 0,
        .offset_in_wim = 0,
        .uncompressed_size = 0,
    };
    const parts = [_]archive_mod.Archive{ first, second };

    const FailureTest = struct {
        fn run(failure_allocator: std.mem.Allocator, archives: []const archive_mod.Archive) !void {
            const set = try ArchiveSet.init(archives);
            const output = try set.extractByPathAllocLimited(
                failure_allocator,
                1,
                "/nested/file.txt",
                1024,
                .{
                    .max_metadata_bytes = 4096,
                    .max_lookup_entries = 16,
                    .max_lookup_bytes = 4096,
                    .max_directory_entries = 16,
                    .max_path_depth = 8,
                },
            );
            defer failure_allocator.free(output);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        FailureTest.run,
        .{parts[0..]},
    );
}

test "WIM archive set resolves solid resources from their owning part" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/lzms-small.esd.b64"),
    );
    defer allocator.free(bytes);
    var first = try archive_mod.Archive.init(bytes);
    first.header.part_number = 1;
    first.header.total_parts = 2;
    var second = try archive_mod.Archive.init(bytes);
    second.header.part_number = 2;
    second.header.total_parts = 2;
    second.header.lookup_table = .{
        .size_in_wim = 0,
        .flags = 0,
        .offset_in_wim = 0,
        .uncompressed_size = 0,
    };
    const parts = [_]archive_mod.Archive{ first, second };
    const set = try ArchiveSet.init(&parts);
    var lookup = try first.readLookupTableRawAlloc(allocator, 16, 4096);
    defer lookup.deinit();
    for (lookup.entries) |*entry| {
        if (entry.resource.isSolid()) entry.part_number = 2;
    }
    var context = ArchiveSet.PartContext{ .set = set };
    try solid.resolveEntriesFromParts(
        allocator,
        first.header.version,
        lookup.entries,
        .{
            .context = &context,
            .bytes_for_part = ArchiveSet.PartContext.bytesForPart,
        },
    );
    const blob = for (lookup.entries) |entry| {
        if (entry.kind == .solid_blob) break entry;
    } else return error.TestUnexpectedResult;
    const output = try set.extractEntryAllocLimitedWithSolidLimit(
        allocator,
        blob,
        4096,
        4096,
    );
    defer allocator.free(output);
    try std.testing.expectEqualSlices(
        u8,
        @embedFile("../lzms/testdata/lzms-small.txt"),
        output,
    );
}

test "WIM archive set keeps adjacent solid runs partitioned by part" {
    const allocator = std.testing.allocator;
    const first_bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/lzms-small.esd.b64"),
    );
    defer allocator.free(first_bytes);
    const second_bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/lzms-small.esd.b64"),
    );
    defer allocator.free(second_bytes);
    var first = try archive_mod.Archive.init(first_bytes);
    first.header.total_parts = 2;
    var second = try archive_mod.Archive.init(second_bytes);
    second.header.part_number = 2;
    second.header.total_parts = 2;
    try std.testing.expect(!second.header.lookup_table.isCompressed());
    const lookup_start: usize = @intCast(second.header.lookup_table.offset_in_wim);
    const lookup_len: usize = @intCast(second.header.lookup_table.uncompressed_size);
    try std.testing.expectEqual(@as(usize, 0), lookup_len % format.lookup_entry_size);
    for (0..lookup_len / format.lookup_entry_size) |index| {
        const part_offset = lookup_start + index * format.lookup_entry_size + 24;
        std.mem.writeInt(u16, second_bytes[part_offset..][0..2], 2, .little);
    }
    const parts = [_]archive_mod.Archive{ first, second };
    const set = try ArchiveSet.init(&parts);
    var lookup = try set.readLookupTableAlloc(allocator, 16, 4096);
    defer lookup.deinit();
    try std.testing.expectEqual(@as(usize, 6), lookup.entries.len);
    var marker_count: usize = 0;
    var blob_count: usize = 0;
    var second_blob: ?archive_mod.LookupEntry = null;
    for (lookup.entries) |entry| switch (entry.kind) {
        .standalone => {},
        .solid_resource => marker_count += 1,
        .solid_blob => {
            blob_count += 1;
            if (entry.part_number == 2) second_blob = entry;
        },
    };
    try std.testing.expectEqual(@as(usize, 2), marker_count);
    try std.testing.expectEqual(@as(usize, 2), blob_count);
    const expected = @embedFile("../lzms/testdata/lzms-small.txt");
    const output = try set.extractEntryAllocLimitedWithSolidLimit(
        allocator,
        second_blob orelse return error.TestUnexpectedResult,
        expected.len,
        4096,
    );
    defer allocator.free(output);
    try std.testing.expectEqualSlices(u8, expected, output);
}

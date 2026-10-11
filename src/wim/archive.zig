const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const codec = @import("codec.zig");
const image_metadata = @import("metadata.zig");

pub const Error = core.Error || format.Error || codec.Error || image_metadata.Error ||
    std.mem.Allocator.Error || error{
    InvalidWim,
    WimImageNotFound,
    WimResourceNotFound,
    WimResourceInOtherPart,
    UnsupportedWimFeature,
};

pub const PathLimits = struct {
    max_metadata_bytes: usize = 256 * 1024 * 1024,
    max_lookup_entries: usize = 4 * 1024 * 1024,
    max_lookup_bytes: usize = 256 * 1024 * 1024,
    max_directory_entries: usize = 1024 * 1024,
    max_path_depth: usize = 256,
};

pub const LookupEntry = struct {
    resource: format.ResourceHeader,
    part_number: u16,
    reference_count: u32,
    sha1: [20]u8,

    pub fn hashIsZero(self: LookupEntry) bool {
        return std.mem.allEqual(u8, &self.sha1, 0);
    }
};

pub const LookupTable = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    entries: []LookupEntry,

    pub fn deinit(self: *LookupTable) void {
        self.allocator.free(self.entries);
        self.allocator.free(self.bytes);
        self.* = undefined;
    }

    pub fn find(self: LookupTable, sha1: *const [20]u8) ?LookupEntry {
        for (self.entries) |entry|
            if (std.mem.eql(u8, &entry.sha1, sha1)) return entry;
        return null;
    }

    pub fn findData(self: LookupTable, sha1: *const [20]u8) ?LookupEntry {
        for (self.entries) |entry|
            if (!entry.resource.isMetadata() and std.mem.eql(u8, &entry.sha1, sha1))
                return entry;
        return null;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    header: format.Header,

    pub fn init(bytes: []const u8) Error!Archive {
        return .{ .bytes = bytes, .header = try format.parseHeader(bytes) };
    }

    pub fn readXmlAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        if (self.header.xml_data.isZero()) return allocator.alloc(u8, 0);
        return self.readResourceAllocLimited(
            allocator,
            self.header.xml_data,
            max_output_len,
        );
    }

    pub fn readLookupTableAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        max_entries: usize,
        max_table_bytes: usize,
    ) Error!LookupTable {
        if (self.header.lookup_table.isZero()) {
            return .{
                .allocator = allocator,
                .bytes = try allocator.alloc(u8, 0),
                .entries = try allocator.alloc(LookupEntry, 0),
            };
        }
        const bytes = try self.readResourceAllocLimited(
            allocator,
            self.header.lookup_table,
            max_table_bytes,
        );
        errdefer allocator.free(bytes);
        if (bytes.len % format.lookup_entry_size != 0) return error.InvalidWim;
        const count = bytes.len / format.lookup_entry_size;
        if (count > max_entries) return error.OutputLimitExceeded;
        const entries = try allocator.alloc(LookupEntry, count);
        errdefer allocator.free(entries);
        for (entries, 0..) |*entry, index| {
            const record = bytes[index * format.lookup_entry_size ..][0..format.lookup_entry_size];
            const part_number = format.readU16(record, 24);
            if (part_number == 0 or part_number > self.header.total_parts)
                return error.InvalidWim;
            var sha1: [20]u8 = undefined;
            @memcpy(&sha1, record[30..50]);
            entry.* = .{
                .resource = try format.parseResourceHeader(record, 0),
                .part_number = part_number,
                .reference_count = format.readU32(record, 26),
                .sha1 = sha1,
            };
        }
        return .{ .allocator = allocator, .bytes = bytes, .entries = entries };
    }

    pub fn extractBySha1AllocLimited(
        self: Archive,
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
        return self.extractEntryAllocLimited(allocator, entry, max_output_len);
    }

    pub fn readImageMetadataAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        image_index: u32,
        limits: PathLimits,
    ) Error!image_metadata.ImageMetadata {
        var lookup = try self.readLookupTableAlloc(
            allocator,
            limits.max_lookup_entries,
            limits.max_lookup_bytes,
        );
        defer lookup.deinit();
        const entry = try self.imageMetadataEntry(lookup, image_index);
        const bytes = try self.extractEntryAllocLimited(
            allocator,
            entry,
            limits.max_metadata_bytes,
        );
        return image_metadata.ImageMetadata.fromOwnedBytes(allocator, bytes);
    }

    pub fn extractByPathAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        image_index: u32,
        path: []const u8,
        max_output_len: usize,
        limits: PathLimits,
    ) Error![]u8 {
        var lookup = try self.readLookupTableAlloc(
            allocator,
            limits.max_lookup_entries,
            limits.max_lookup_bytes,
        );
        defer lookup.deinit();
        const metadata_entry = try self.imageMetadataEntry(lookup, image_index);
        const metadata_bytes = try self.extractEntryAllocLimited(
            allocator,
            metadata_entry,
            limits.max_metadata_bytes,
        );
        var parsed_metadata = try image_metadata.ImageMetadata.fromOwnedBytes(
            allocator,
            metadata_bytes,
        );
        defer parsed_metadata.deinit();
        const dentry = try parsed_metadata.lookup(
            allocator,
            path,
            limits.max_directory_entries,
            limits.max_path_depth,
        );
        if (dentry.isDirectory()) return error.WimNotRegularFile;
        if (dentry.isEncrypted() or dentry.isReparsePoint() or
            try dentry.hasNamedStreams())
            return error.UnsupportedWimFile;
        const hash = try dentry.defaultDataSha1() orelse
            return error.WimNotRegularFile;
        if (std.mem.allEqual(u8, &hash, 0)) return allocator.alloc(u8, 0);
        const entry = lookup.findData(&hash) orelse {
            if (self.header.total_parts > 1) return error.WimResourceInOtherPart;
            return error.WimResourceNotFound;
        };
        return self.extractEntryAllocLimited(allocator, entry, max_output_len);
    }

    pub fn extractEntryAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: LookupEntry,
        max_output_len: usize,
    ) Error![]u8 {
        if (entry.part_number != self.header.part_number)
            return error.WimResourceInOtherPart;
        const output = try self.readResourceAllocLimited(
            allocator,
            entry.resource,
            max_output_len,
        );
        errdefer allocator.free(output);
        if (!entry.hashIsZero()) {
            var actual: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
            std.crypto.hash.Sha1.hash(output, &actual, .{});
            if (!std.mem.eql(u8, &actual, &entry.sha1)) return error.ChecksumMismatch;
        }
        return output;
    }

    pub fn readResourceAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        resource: format.ResourceHeader,
        max_output_len: usize,
    ) Error![]u8 {
        if (resource.isSolid() or resource.isSpanned())
            return error.UnsupportedWimFeature;
        const output_len = std.math.cast(usize, resource.uncompressed_size) orelse
            return error.IntegerOverflow;
        if (output_len > max_output_len) return error.OutputLimitExceeded;
        const stored_len = std.math.cast(usize, resource.size_in_wim) orelse
            return error.IntegerOverflow;
        const resource_start = std.math.cast(usize, resource.offset_in_wim) orelse
            return error.IntegerOverflow;
        const resource_end = try checkedEnd(resource_start, stored_len, self.bytes.len);
        const stored = self.bytes[resource_start..resource_end];
        if (!resource.isCompressed()) {
            if (stored_len != output_len) return error.InvalidWim;
            return allocator.dupe(u8, stored);
        }
        if (self.header.compression == .none or self.header.chunk_size == 0)
            return error.InvalidWim;
        if (output_len == 0) {
            if (stored_len != 0) return error.InvalidWim;
            return allocator.alloc(u8, 0);
        }
        const chunk_count = (std.math.add(
            usize,
            output_len,
            self.header.chunk_size - 1,
        ) catch return error.IntegerOverflow) / self.header.chunk_size;
        const entry_size: usize = if (resource.uncompressed_size <= std.math.maxInt(u32)) 4 else 8;
        const table_size = std.math.mul(usize, chunk_count - 1, entry_size) catch
            return error.IntegerOverflow;
        if (table_size > stored.len) return error.InvalidWim;
        const chunk_data = stored[table_size..];
        const output = try allocator.alloc(u8, output_len);
        errdefer allocator.free(output);
        var previous_offset: usize = 0;
        var output_offset: usize = 0;
        for (0..chunk_count) |chunk_index| {
            const next_offset = if (chunk_index + 1 == chunk_count)
                chunk_data.len
            else blk: {
                const table_offset = chunk_index * entry_size;
                const value = if (entry_size == 4)
                    @as(u64, format.readU32(stored, table_offset))
                else
                    format.readU64(stored, table_offset);
                break :blk std.math.cast(usize, value) orelse return error.IntegerOverflow;
            };
            if (next_offset <= previous_offset or next_offset > chunk_data.len)
                return error.InvalidWim;
            const decoded_len = @min(self.header.chunk_size, output_len - output_offset);
            const encoded_chunk = chunk_data[previous_offset..next_offset];
            const decoded_chunk = output[output_offset..][0..decoded_len];
            if (encoded_chunk.len == decoded_len) {
                @memcpy(decoded_chunk, encoded_chunk);
            } else {
                if (encoded_chunk.len > decoded_len) return error.InvalidWim;
                try codec.decodeChunkInto(
                    allocator,
                    self.header.compression,
                    encoded_chunk,
                    decoded_chunk,
                    self.header.chunk_size,
                );
            }
            previous_offset = next_offset;
            output_offset += decoded_len;
        }
        if (output_offset != output.len) return error.SizeMismatch;
        return output;
    }

    fn imageMetadataEntry(
        self: Archive,
        lookup: LookupTable,
        image_index: u32,
    ) Error!LookupEntry {
        if (image_index == 0 or image_index > self.header.image_count)
            return error.WimImageNotFound;
        if (self.header.part_number != 1) return error.WimResourceInOtherPart;
        var metadata_count: u32 = 0;
        var selected: ?LookupEntry = null;
        for (lookup.entries) |entry| {
            if (!entry.resource.isMetadata() or entry.reference_count == 0) continue;
            if (entry.reference_count != 1 or entry.hashIsZero() or
                entry.part_number != 1 or entry.resource.isSolid() or
                entry.resource.isSpanned())
                return error.InvalidWim;
            metadata_count = std.math.add(u32, metadata_count, 1) catch
                return error.IntegerOverflow;
            if (metadata_count == image_index) selected = entry;
        }
        if (metadata_count != self.header.image_count) return error.InvalidWim;
        return selected orelse error.WimImageNotFound;
    }
};

fn checkedEnd(start: usize, length: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, length) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

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

fn parseSha1(text: []const u8) ![20]u8 {
    var hash: [20]u8 = undefined;
    _ = try std.fmt.hexToBytes(&hash, text);
    return hash;
}

test "WIM reads XPRESS lookup XML metadata and stored blobs" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/xpress-small.wim.b64"),
    );
    defer allocator.free(bytes);
    const archive = try Archive.init(bytes);
    try std.testing.expectEqual(format.Compression.xpress, archive.header.compression);
    try std.testing.expectEqual(@as(u32, 1), archive.header.image_count);
    var lookup = try archive.readLookupTableAlloc(allocator, 16, 4096);
    defer lookup.deinit();
    try std.testing.expectEqual(@as(usize, 2), lookup.entries.len);
    const file_hash = try parseSha1("a541b150d52c83c6e19004c5239d228ccdad70ba");
    const file = try archive.extractBySha1AllocLimited(
        allocator,
        &file_hash,
        1024,
        16,
        4096,
    );
    defer allocator.free(file);
    try std.testing.expectEqualStrings("hello WIM XPRESS payload\n", file);
    const metadata_hash = try parseSha1("c5071b9147d869a9e7b5efc3e64e7e536e3d64fd");
    const metadata = try archive.extractBySha1AllocLimited(
        allocator,
        &metadata_hash,
        4096,
        16,
        4096,
    );
    defer allocator.free(metadata);
    try std.testing.expectEqual(@as(usize, 376), metadata.len);
    const xml = try archive.readXmlAllocLimited(allocator, 4096);
    defer allocator.free(xml);
    try std.testing.expect(std.mem.indexOf(u8, xml, &.{ '<', 0, 'W', 0, 'I', 0, 'M', 0 }) != null);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.readXmlAllocLimited(allocator, 761),
    );

    var image = try archive.readImageMetadataAlloc(allocator, 1, .{
        .max_metadata_bytes = 4096,
        .max_lookup_entries = 16,
        .max_lookup_bytes = 4096,
        .max_directory_entries = 16,
        .max_path_depth = 8,
    });
    defer image.deinit();
    try std.testing.expectEqual(@as(usize, 8), image.security.total_length);
    var root = try image.readDirectoryAlloc(allocator, image.root, 16);
    defer root.deinit();
    try std.testing.expectEqual(@as(usize, 1), root.entries.len);
    const nested_name = try root.entries[0].nameUtf8Alloc(allocator);
    defer allocator.free(nested_name);
    try std.testing.expectEqualStrings("nested", nested_name);
    const nested_file = try image.lookup(allocator, "/nested/file.txt", 16, 8);
    try std.testing.expect(!nested_file.isDirectory());
    try std.testing.expectEqual(file_hash, (try nested_file.defaultDataSha1()).?);
    try std.testing.expectError(
        error.InvalidWimPath,
        image.lookup(allocator, "nested//file.txt", 16, 8),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        image.lookup(allocator, "nested/file.txt", 16, 1),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        image.readDirectoryAlloc(allocator, image.root, 0),
    );
    const by_path = try archive.extractByPathAllocLimited(
        allocator,
        1,
        "nested/file.txt",
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
    try std.testing.expectEqualStrings("hello WIM XPRESS payload\n", by_path);
    try std.testing.expectError(
        error.WimPathNotFound,
        archive.extractByPathAllocLimited(
            allocator,
            1,
            "nested/missing.txt",
            1024,
            .{
                .max_metadata_bytes = 4096,
                .max_lookup_entries = 16,
                .max_lookup_bytes = 4096,
                .max_directory_entries = 16,
                .max_path_depth = 8,
            },
        ),
    );
    try std.testing.expectError(
        error.WimNotRegularFile,
        archive.extractByPathAllocLimited(
            allocator,
            1,
            "nested",
            1024,
            .{
                .max_metadata_bytes = 4096,
                .max_lookup_entries = 16,
                .max_lookup_bytes = 4096,
                .max_directory_entries = 16,
                .max_path_depth = 8,
            },
        ),
    );
}

test "WIM reads LZX metadata resources" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/lzx-small.wim.b64"),
    );
    defer allocator.free(bytes);
    const archive = try Archive.init(bytes);
    try std.testing.expectEqual(format.Compression.lzx, archive.header.compression);
    const metadata_hash = try parseSha1("3704af6c8817d8ee046fdee1bab5549c8c96a42e");
    const metadata = try archive.extractBySha1AllocLimited(
        allocator,
        &metadata_hash,
        4096,
        16,
        4096,
    );
    defer allocator.free(metadata);
    try std.testing.expectEqual(@as(usize, 376), metadata.len);
    const file = try archive.extractByPathAllocLimited(
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
    defer allocator.free(file);
    try std.testing.expectEqualStrings("hello WIM XPRESS payload\n", file);
}

test "WIM metadata rejects corrupt security names offsets and terminators" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/xpress-small.wim.b64"),
    );
    defer allocator.free(bytes);
    const archive = try Archive.init(bytes);
    const metadata_hash = try parseSha1("c5071b9147d869a9e7b5efc3e64e7e536e3d64fd");
    const original = try archive.extractBySha1AllocLimited(
        allocator,
        &metadata_hash,
        4096,
        16,
        4096,
    );
    defer allocator.free(original);

    const bad_security = try allocator.dupe(u8, original);
    std.mem.writeInt(u32, bad_security[0..4], 9, .little);
    try std.testing.expectError(
        error.InvalidWimMetadata,
        image_metadata.ImageMetadata.fromOwnedBytes(allocator, bad_security),
    );

    const odd_name = try allocator.dupe(u8, original);
    std.mem.writeInt(u16, odd_name[220..222], 1, .little);
    var odd_image = try image_metadata.ImageMetadata.fromOwnedBytes(allocator, odd_name);
    defer odd_image.deinit();
    try std.testing.expectError(
        error.InvalidWimMetadata,
        odd_image.readDirectoryAlloc(allocator, odd_image.root, 16),
    );

    const cyclic = try allocator.dupe(u8, original);
    std.mem.writeInt(u64, cyclic[136..144], 120, .little);
    var cyclic_image = try image_metadata.ImageMetadata.fromOwnedBytes(allocator, cyclic);
    defer cyclic_image.deinit();
    try std.testing.expectError(
        error.InvalidWimMetadata,
        cyclic_image.readDirectoryAlloc(allocator, cyclic_image.root, 16),
    );

    const bad_terminator = try allocator.dupe(u8, original);
    std.mem.writeInt(u64, bad_terminator[240..248], 1, .little);
    var terminated_image = try image_metadata.ImageMetadata.fromOwnedBytes(
        allocator,
        bad_terminator,
    );
    defer terminated_image.deinit();
    try std.testing.expectError(
        error.InvalidWimMetadata,
        terminated_image.readDirectoryAlloc(allocator, terminated_image.root, 16),
    );

    const dot_name = try allocator.dupe(u8, original);
    std.mem.writeInt(u16, dot_name[220..222], 2, .little);
    dot_name[222] = '.';
    dot_name[223] = 0;
    dot_name[224] = 0;
    dot_name[225] = 0;
    var dot_image = try image_metadata.ImageMetadata.fromOwnedBytes(allocator, dot_name);
    defer dot_image.deinit();
    try std.testing.expectError(
        error.InvalidWimMetadata,
        dot_image.readDirectoryAlloc(allocator, dot_image.root, 16),
    );

    const duplicate = try allocator.alloc(u8, 368);
    @memset(duplicate, 0);
    @memcpy(duplicate[0..240], original[0..240]);
    @memcpy(duplicate[240..360], original[120..240]);
    var duplicate_image = try image_metadata.ImageMetadata.fromOwnedBytes(
        allocator,
        duplicate,
    );
    defer duplicate_image.deinit();
    try std.testing.expectError(
        error.InvalidWimMetadata,
        duplicate_image.readDirectoryAlloc(allocator, duplicate_image.root, 16),
    );
}

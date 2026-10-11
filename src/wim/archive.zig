const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const codec = @import("codec.zig");

pub const Error = core.Error || format.Error || codec.Error || std.mem.Allocator.Error || error{
    InvalidWim,
    WimResourceNotFound,
    WimResourceInOtherPart,
    UnsupportedWimFeature,
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
}

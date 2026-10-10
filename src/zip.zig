const std = @import("std");
const bzip2 = @import("bzip2.zig");
const core = @import("core.zig");
const checksum = @import("checksum.zig");
const deflate = @import("deflate.zig");
const deflate64 = @import("deflate64.zig");
const lzma = @import("lzma.zig");
const implode = @import("zip/implode.zig");
const ppmd8 = @import("ppmd8.zig");
const xz = @import("xz.zig");
const zstd = @import("zstd.zig");
const records = @import("zip/records.zig");
const shrink = @import("zip/shrink.zig");
pub const writer = @import("zip/writer.zig");

pub const Error = writer.Error || bzip2.Error || deflate64.Error || implode.Error || lzma.Error || ppmd8.Error || shrink.Error || xz.Error || zstd.Error || error{
    InvalidZipArchive,
    UnsupportedZipFeature,
    EncryptedZipEntry,
    UnsupportedZipCompressionMethod,
    ZipEntryNotFound,
    ZipEntryRequiresAllocator,
};

const local_file_signature: u32 = 0x0403_4b50;
const central_file_signature: u32 = 0x0201_4b50;
const end_of_central_signature: u32 = 0x0605_4b50;
const end_of_central_len: usize = 22;

pub const CompressionMethod = writer.CompressionMethod;
pub const Zip64Mode = writer.Zip64Mode;
pub const EncodeEntry = writer.EncodeEntry;
pub const EncodeOptions = writer.EncodeOptions;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;

pub const DecodeOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_dictionary_size: usize = 64 * 1024 * 1024,
};

pub const Entry = struct {
    name: []const u8,
    method: CompressionMethod,
    flags: u16,
    crc32: u32,
    compressed_size: usize,
    uncompressed_size: usize,
    local_header_offset: usize,
    central_header_offset: usize,
    zip64: bool,

    pub fn isDirectory(self: Entry) bool {
        return self.name.len != 0 and self.name[self.name.len - 1] == '/';
    }

    pub fn isEncrypted(self: Entry) bool {
        return self.flags & 1 != 0;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    entry_count: usize,
    central_directory_offset: usize,
    central_directory_size: usize,
    comment: []const u8,
    zip64: bool,

    pub fn iterator(self: Archive) Iterator {
        return .{
            .archive = self,
            .offset = self.central_directory_offset,
            .remaining = self.entry_count,
        };
    }

    pub fn entryAt(self: Archive, index: usize) Error!Entry {
        if (index >= self.entry_count) return error.RangeOutOfBounds;
        var it = self.iterator();
        var current: usize = 0;
        while (try it.next()) |entry| : (current += 1)
            if (current == index) return entry;
        return error.InvalidZipArchive;
    }

    pub fn find(self: Archive, name: []const u8) Error!?Entry {
        var it = self.iterator();
        while (try it.next()) |entry|
            if (std.mem.eql(u8, entry.name, name)) return entry;
        return null;
    }

    pub fn entriesAlloc(self: Archive, allocator: std.mem.Allocator) ![]Entry {
        const entries = try allocator.alloc(Entry, self.entry_count);
        errdefer allocator.free(entries);
        var it = self.iterator();
        var index: usize = 0;
        while (try it.next()) |entry| : (index += 1) entries[index] = entry;
        if (index != entries.len) return error.InvalidZipArchive;
        return entries;
    }

    pub fn extractInto(self: Archive, entry: Entry, output: []u8) Error!usize {
        return self.extractIntoOptionalAllocator(null, entry, output, .{}) catch |err| switch (err) {
            error.OutOfMemory => unreachable,
            else => |zip_error| return zip_error,
        };
    }

    pub fn extractIntoWithAllocator(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        output: []u8,
    ) !usize {
        return self.extractIntoOptionalAllocator(allocator, entry, output, .{});
    }

    pub fn extractIntoWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        output: []u8,
        options: DecodeOptions,
    ) !usize {
        return self.extractIntoOptionalAllocator(allocator, entry, output, options);
    }

    fn extractIntoOptionalAllocator(
        self: Archive,
        allocator: ?std.mem.Allocator,
        entry: Entry,
        output: []u8,
        options: DecodeOptions,
    ) !usize {
        const parsed = try parseCentralEntry(self, entry.central_header_offset);
        const canonical = parsed.entry;
        if (canonical.uncompressed_size > options.max_output_len)
            return error.OutputLimitExceeded;
        if (output.len < canonical.uncompressed_size) return error.OutputTooSmall;
        if (canonical.isEncrypted()) return error.EncryptedZipEntry;

        const compressed = try localCompressedData(self, canonical);
        const target = output[0..canonical.uncompressed_size];
        switch (canonical.method) {
            .stored => {
                if (canonical.compressed_size != canonical.uncompressed_size) return error.InvalidZipArchive;
                @memcpy(target, compressed);
            },
            .shrink => try shrink.decodeInto(compressed, target),
            .implode => try implode.decodeInto(compressed, target, canonical.flags),
            .deflate => {
                const decoded = try deflate.decodeRawAuto(compressed, target);
                if (decoded.input_read != compressed.len) return error.InvalidZipArchive;
                if (decoded.output_written != target.len) return error.SizeMismatch;
            },
            .deflate64 => {
                const decoded = try deflate64.decodeInto(compressed, target);
                if (decoded.input_read != compressed.len) return error.InvalidZipArchive;
                if (decoded.output_written != target.len) return error.SizeMismatch;
            },
            .bzip2 => {
                const scratch_allocator = allocator orelse return error.ZipEntryRequiresAllocator;
                const written = try bzip2.decodeInto(scratch_allocator, compressed, target);
                if (written != target.len) return error.SizeMismatch;
            },
            .lzma => {
                const scratch_allocator = allocator orelse return error.ZipEntryRequiresAllocator;
                const written = try lzma.decodeZipPayloadInto(
                    scratch_allocator,
                    compressed,
                    target.len,
                    target,
                    options.max_dictionary_size,
                    canonical.flags & 0x0002 != 0,
                );
                if (written != target.len) return error.SizeMismatch;
            },
            .xz => {
                const scratch_allocator = allocator orelse return error.ZipEntryRequiresAllocator;
                const written = try xz.decodeInto(scratch_allocator, compressed, target);
                if (written != target.len) return error.SizeMismatch;
            },
            .ppmd => {
                const scratch_allocator = allocator orelse return error.ZipEntryRequiresAllocator;
                try ppmd8.decodeZipInto(
                    scratch_allocator,
                    compressed,
                    target,
                    options.max_dictionary_size,
                );
            },
            .zstandard_legacy, .zstandard => {
                const written = try zstd.decodeFrameIntoExactSize(compressed, target, target.len);
                if (written != target.len) return error.SizeMismatch;
            },
            else => return error.UnsupportedZipCompressionMethod,
        }
        if (checksum.crc32Best(target) != canonical.crc32) return error.ChecksumMismatch;
        return target.len;
    }

    pub fn extractAlloc(self: Archive, allocator: std.mem.Allocator, entry: Entry) ![]u8 {
        return self.extractAllocLimited(allocator, entry, std.math.maxInt(usize));
    }

    pub fn extractAllocLimited(self: Archive, allocator: std.mem.Allocator, entry: Entry, max_output_len: usize) ![]u8 {
        return self.extractAllocWithOptions(allocator, entry, .{ .max_output_len = max_output_len });
    }

    pub fn extractAllocWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        options: DecodeOptions,
    ) ![]u8 {
        if (entry.uncompressed_size > options.max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, entry.uncompressed_size);
        errdefer allocator.free(output);
        const written = try self.extractIntoWithOptions(allocator, entry, output, options);
        if (written != output.len) return error.SizeMismatch;
        return output;
    }

    pub fn extractByNameAlloc(self: Archive, allocator: std.mem.Allocator, name: []const u8) ![]u8 {
        return self.extractByNameAllocLimited(allocator, name, std.math.maxInt(usize));
    }

    pub fn extractByNameAllocLimited(self: Archive, allocator: std.mem.Allocator, name: []const u8, max_output_len: usize) ![]u8 {
        const entry = (try self.find(name)) orelse return error.ZipEntryNotFound;
        return self.extractAllocLimited(allocator, entry, max_output_len);
    }

    pub fn extractByNameAllocWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        options: DecodeOptions,
    ) ![]u8 {
        const entry = (try self.find(name)) orelse return error.ZipEntryNotFound;
        return self.extractAllocWithOptions(allocator, entry, options);
    }
};

pub const Iterator = struct {
    archive: Archive,
    offset: usize,
    remaining: usize,

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.remaining == 0) return null;
        const parsed = try parseCentralEntry(self.archive, self.offset);
        self.offset = parsed.next_offset;
        self.remaining -= 1;
        return parsed.entry;
    }
};

pub fn parse(bytes: []const u8) Error!Archive {
    const directory = try records.parseDirectory(bytes);
    return .{
        .bytes = bytes,
        .entry_count = directory.entry_count,
        .central_directory_offset = directory.central_directory_offset,
        .central_directory_size = directory.central_directory_size,
        .comment = directory.comment,
        .zip64 = directory.zip64,
    };
}

pub fn extractEntryInto(bytes: []const u8, index: usize, output: []u8) Error!usize {
    const archive = try parse(bytes);
    return archive.extractInto(try archive.entryAt(index), output);
}

pub fn extractEntryIntoWithAllocator(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    index: usize,
    output: []u8,
) !usize {
    const archive = try parse(bytes);
    return archive.extractIntoWithAllocator(allocator, try archive.entryAt(index), output);
}

pub fn extractEntryIntoWithOptions(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    index: usize,
    output: []u8,
    options: DecodeOptions,
) !usize {
    const archive = try parse(bytes);
    return archive.extractIntoWithOptions(allocator, try archive.entryAt(index), output, options);
}

pub fn extractEntryAlloc(allocator: std.mem.Allocator, bytes: []const u8, index: usize) ![]u8 {
    const archive = try parse(bytes);
    return archive.extractAlloc(allocator, try archive.entryAt(index));
}

pub fn extractEntryAllocLimited(allocator: std.mem.Allocator, bytes: []const u8, index: usize, max_output_len: usize) ![]u8 {
    const archive = try parse(bytes);
    return archive.extractAllocLimited(allocator, try archive.entryAt(index), max_output_len);
}

pub fn extractEntryAllocWithOptions(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    index: usize,
    options: DecodeOptions,
) ![]u8 {
    const archive = try parse(bytes);
    return archive.extractAllocWithOptions(allocator, try archive.entryAt(index), options);
}

pub fn extractByNameAlloc(allocator: std.mem.Allocator, bytes: []const u8, name: []const u8) ![]u8 {
    return (try parse(bytes)).extractByNameAlloc(allocator, name);
}

pub fn extractByNameAllocLimited(allocator: std.mem.Allocator, bytes: []const u8, name: []const u8, max_output_len: usize) ![]u8 {
    return (try parse(bytes)).extractByNameAllocLimited(allocator, name, max_output_len);
}

pub fn extractByNameAllocWithOptions(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    name: []const u8,
    options: DecodeOptions,
) ![]u8 {
    return (try parse(bytes)).extractByNameAllocWithOptions(allocator, name, options);
}

const ParsedCentralEntry = struct { entry: Entry, next_offset: usize };

fn parseCentralEntry(archive: Archive, offset: usize) Error!ParsedCentralEntry {
    const central_end = try checkedEnd(archive.central_directory_offset, archive.central_directory_size, archive.bytes.len);
    if (offset < archive.central_directory_offset or offset >= central_end) return error.InvalidZipArchive;
    if (try readU32(archive.bytes, offset) != central_file_signature) return error.InvalidZipArchive;
    _ = try checkedEnd(offset, 46, central_end);

    const flags = try readU16(archive.bytes, offset + 8);
    const version_needed = try readU16(archive.bytes, offset + 6);
    const method_raw = try readU16(archive.bytes, offset + 10);
    const method: CompressionMethod = @enumFromInt(method_raw);
    const crc = try readU32(archive.bytes, offset + 16);
    const compressed_u32 = try readU32(archive.bytes, offset + 20);
    const uncompressed_u32 = try readU32(archive.bytes, offset + 24);
    const name_len: usize = try readU16(archive.bytes, offset + 28);
    const extra_len: usize = try readU16(archive.bytes, offset + 30);
    const comment_len: usize = try readU16(archive.bytes, offset + 32);
    const disk_start_u16 = try readU16(archive.bytes, offset + 34);
    const local_offset_u32 = try readU32(archive.bytes, offset + 42);

    const name_start = offset + 46;
    const name_end = try checkedEnd(name_start, name_len, central_end);
    const extra_end = try checkedEnd(name_end, extra_len, central_end);
    const next_offset = try checkedEnd(extra_end, comment_len, central_end);
    const values = try records.resolveCentralEntry(
        archive.bytes[name_end..extra_end],
        compressed_u32,
        uncompressed_u32,
        local_offset_u32,
        disk_start_u16,
    );
    if (values.zip64 and version_needed < 45) return error.InvalidZipArchive;
    if (method == .bzip2 and version_needed < 46) return error.InvalidZipArchive;
    if (method == .lzma and version_needed < 63) return error.InvalidZipArchive;
    if (method == .ppmd and version_needed < 63) return error.InvalidZipArchive;
    if (isZstandardMethod(method) and version_needed < 63)
        return error.InvalidZipArchive;
    if (values.local_header_offset >= archive.central_directory_offset) return error.InvalidZipArchive;

    return .{
        .entry = .{
            .name = archive.bytes[name_start..name_end],
            .method = method,
            .flags = flags,
            .crc32 = crc,
            .compressed_size = values.compressed_size,
            .uncompressed_size = values.uncompressed_size,
            .local_header_offset = values.local_header_offset,
            .central_header_offset = offset,
            .zip64 = values.zip64,
        },
        .next_offset = next_offset,
    };
}

fn localCompressedData(archive: Archive, entry: Entry) Error![]const u8 {
    const offset = entry.local_header_offset;
    if (try readU32(archive.bytes, offset) != local_file_signature) return error.InvalidZipArchive;
    _ = try checkedEnd(offset, 30, archive.central_directory_offset);
    const local_flags = try readU16(archive.bytes, offset + 6);
    const local_version_needed = try readU16(archive.bytes, offset + 4);
    const local_method = try readU16(archive.bytes, offset + 8);
    const local_crc = try readU32(archive.bytes, offset + 14);
    const local_compressed = try readU32(archive.bytes, offset + 18);
    const local_uncompressed = try readU32(archive.bytes, offset + 22);
    const name_len: usize = try readU16(archive.bytes, offset + 26);
    const extra_len: usize = try readU16(archive.bytes, offset + 28);
    if (local_method != @intFromEnum(entry.method)) return error.InvalidZipArchive;
    const compared_flags: u16 = 0x0009 | switch (entry.method) {
        .lzma => @as(u16, 0x0002),
        .implode => @as(u16, 0x0006),
        else => @as(u16, 0),
    };
    if ((local_flags ^ entry.flags) & compared_flags != 0) return error.InvalidZipArchive;
    if (local_flags & 1 != 0) return error.EncryptedZipEntry;

    const name_start = offset + 30;
    const name_end = try checkedEnd(name_start, name_len, archive.central_directory_offset);
    if (!std.mem.eql(u8, archive.bytes[name_start..name_end], entry.name)) return error.InvalidZipArchive;
    const data_start = try checkedEnd(name_end, extra_len, archive.central_directory_offset);
    const data_end = try checkedEnd(data_start, entry.compressed_size, archive.central_directory_offset);
    if ((local_compressed == std.math.maxInt(u32) or local_uncompressed == std.math.maxInt(u32)) and
        local_version_needed < 45) return error.InvalidZipArchive;
    if (entry.method == .bzip2 and local_version_needed < 46) return error.InvalidZipArchive;
    if (entry.method == .lzma and local_version_needed < 63) return error.InvalidZipArchive;
    if (entry.method == .ppmd and local_version_needed < 63) return error.InvalidZipArchive;
    if (isZstandardMethod(entry.method) and local_version_needed < 63)
        return error.InvalidZipArchive;
    if (local_flags & 0x0008 == 0) {
        const local_sizes = try records.resolveLocalSizes(
            archive.bytes[name_end..data_start],
            local_compressed,
            local_uncompressed,
        );
        if (local_crc != entry.crc32 or
            local_sizes.compressed_size != entry.compressed_size or
            local_sizes.uncompressed_size != entry.uncompressed_size)
            return error.InvalidZipArchive;
    }
    return archive.bytes[data_start..data_end];
}

fn readU16(bytes: []const u8, offset: usize) Error!u16 {
    _ = try checkedEnd(offset, 2, bytes.len);
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn isZstandardMethod(method: CompressionMethod) bool {
    return method == .zstandard_legacy or method == .zstandard;
}

fn readU32(bytes: []const u8, offset: usize) Error!u32 {
    _ = try checkedEnd(offset, 4, bytes.len);
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, len) catch return error.InvalidZipArchive;
    if (end > limit) return error.InvalidZipArchive;
    return end;
}

const TestEntry = struct {
    name: []const u8,
    payload: []const u8,
    compressed: []const u8,
    method: u16,
    flags: u16,
    local_offset: usize,
};

fn appendU16(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn appendU32(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn appendTestLocal(out: *std.ArrayList(u8), allocator: std.mem.Allocator, entry: *TestEntry) !void {
    entry.local_offset = out.items.len;
    const descriptor = entry.flags & 0x0008 != 0;
    try appendU32(out, allocator, local_file_signature);
    try appendU16(out, allocator, 20);
    try appendU16(out, allocator, entry.flags);
    try appendU16(out, allocator, entry.method);
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU32(out, allocator, if (descriptor) 0 else checksum.crc32(entry.payload));
    try appendU32(out, allocator, if (descriptor) 0 else @intCast(entry.compressed.len));
    try appendU32(out, allocator, if (descriptor) 0 else @intCast(entry.payload.len));
    try appendU16(out, allocator, @intCast(entry.name.len));
    try appendU16(out, allocator, 0);
    try out.appendSlice(allocator, entry.name);
    try out.appendSlice(allocator, entry.compressed);
    if (descriptor) {
        try appendU32(out, allocator, 0x0807_4b50);
        try appendU32(out, allocator, checksum.crc32(entry.payload));
        try appendU32(out, allocator, @intCast(entry.compressed.len));
        try appendU32(out, allocator, @intCast(entry.payload.len));
    }
}

fn appendTestCentral(out: *std.ArrayList(u8), allocator: std.mem.Allocator, entry: TestEntry) !void {
    try appendU32(out, allocator, central_file_signature);
    try appendU16(out, allocator, 20);
    try appendU16(out, allocator, 20);
    try appendU16(out, allocator, entry.flags);
    try appendU16(out, allocator, entry.method);
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU32(out, allocator, checksum.crc32(entry.payload));
    try appendU32(out, allocator, @intCast(entry.compressed.len));
    try appendU32(out, allocator, @intCast(entry.payload.len));
    try appendU16(out, allocator, @intCast(entry.name.len));
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU32(out, allocator, 0);
    try appendU32(out, allocator, @intCast(entry.local_offset));
    try out.appendSlice(allocator, entry.name);
}

test "ZIP parses and extracts stored and descriptor-backed deflate entries" {
    const allocator = std.testing.allocator;
    const stored_payload = "hello zip";
    const deflated_payload = "deflated payload " ** 32;
    const compressed = try deflate.encodeRawFixedAlloc(allocator, deflated_payload);
    defer allocator.free(compressed);
    var entries = [_]TestEntry{
        .{ .name = "hello.txt", .payload = stored_payload, .compressed = stored_payload, .method = 0, .flags = 0, .local_offset = 0 },
        .{ .name = "data.bin", .payload = deflated_payload, .compressed = compressed, .method = 8, .flags = 0x0008, .local_offset = 0 },
    };
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(allocator);
    for (&entries) |*entry| try appendTestLocal(&bytes, allocator, entry);
    const central_offset = bytes.items.len;
    for (entries) |entry| try appendTestCentral(&bytes, allocator, entry);
    const central_size = bytes.items.len - central_offset;
    try appendU32(&bytes, allocator, end_of_central_signature);
    try appendU16(&bytes, allocator, 0);
    try appendU16(&bytes, allocator, 0);
    try appendU16(&bytes, allocator, entries.len);
    try appendU16(&bytes, allocator, entries.len);
    try appendU32(&bytes, allocator, @intCast(central_size));
    try appendU32(&bytes, allocator, @intCast(central_offset));
    try appendU16(&bytes, allocator, 4);
    try bytes.appendSlice(allocator, "test");

    const archive = try parse(bytes.items);
    try std.testing.expectEqual(@as(usize, 2), archive.entry_count);
    try std.testing.expectEqualStrings("test", archive.comment);
    const listed = try archive.entriesAlloc(allocator);
    defer allocator.free(listed);
    try std.testing.expectEqualStrings("hello.txt", listed[0].name);
    try std.testing.expectEqual(CompressionMethod.stored, listed[0].method);
    try std.testing.expectEqualStrings("data.bin", listed[1].name);
    try std.testing.expectEqual(CompressionMethod.deflate, listed[1].method);

    var stored_output: [stored_payload.len]u8 = undefined;
    try std.testing.expectEqual(stored_payload.len, try archive.extractInto(listed[0], &stored_output));
    try std.testing.expectEqualSlices(u8, stored_payload, &stored_output);
    const decoded = try archive.extractByNameAlloc(allocator, "data.bin");
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, deflated_payload, decoded);
    try std.testing.expectError(error.OutputTooSmall, archive.extractInto(listed[1], stored_output[0..]));
    try std.testing.expectError(error.OutputLimitExceeded, archive.extractAllocLimited(allocator, listed[1], deflated_payload.len - 1));
    try std.testing.expectError(error.ZipEntryNotFound, archive.extractByNameAlloc(allocator, "missing"));
    try std.testing.expectError(error.RangeOutOfBounds, archive.entryAt(2));

    var corrupt = try allocator.dupe(u8, bytes.items);
    defer allocator.free(corrupt);
    corrupt[listed[1].central_header_offset + 16] ^= 1;
    const corrupt_archive = try parse(corrupt);
    const corrupt_entry = try corrupt_archive.entryAt(1);
    var corrupt_output: [deflated_payload.len]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, corrupt_archive.extractInto(corrupt_entry, &corrupt_output));

    var encrypted = try allocator.dupe(u8, bytes.items);
    defer allocator.free(encrypted);
    encrypted[entries[0].local_offset + 6] |= 1;
    encrypted[listed[0].central_header_offset + 8] |= 1;
    const encrypted_archive = try parse(encrypted);
    const encrypted_entry = try encrypted_archive.entryAt(0);
    var encrypted_output: [stored_payload.len]u8 = undefined;
    try std.testing.expectError(error.EncryptedZipEntry, encrypted_archive.extractInto(encrypted_entry, &encrypted_output));

    var unsupported = try allocator.dupe(u8, bytes.items);
    defer allocator.free(unsupported);
    std.mem.writeInt(u16, unsupported[entries[0].local_offset + 8 ..][0..2], 99, .little);
    std.mem.writeInt(u16, unsupported[listed[0].central_header_offset + 10 ..][0..2], 99, .little);
    const unsupported_archive = try parse(unsupported);
    const unsupported_entry = try unsupported_archive.entryAt(0);
    try std.testing.expectError(error.UnsupportedZipCompressionMethod, unsupported_archive.extractInto(unsupported_entry, &encrypted_output));

    var zip64 = try allocator.dupe(u8, bytes.items);
    defer allocator.free(zip64);
    std.mem.writeInt(u32, zip64[listed[0].central_header_offset + 20 ..][0..4], std.math.maxInt(u32), .little);
    const zip64_archive = try parse(zip64);
    try std.testing.expectError(error.InvalidZipArchive, zip64_archive.entryAt(0));

    var mismatched_name = try allocator.dupe(u8, bytes.items);
    defer allocator.free(mismatched_name);
    mismatched_name[entries[0].local_offset + 30] ^= 1;
    const mismatch_archive = try parse(mismatched_name);
    const mismatch_entry = try mismatch_archive.entryAt(0);
    try std.testing.expectError(error.InvalidZipArchive, mismatch_archive.extractInto(mismatch_entry, &encrypted_output));
}

test "ZIP rejects unsupported archive and entry features" {
    try std.testing.expectError(error.InvalidZipArchive, parse("not a zip"));

    var empty: [end_of_central_len]u8 = @splat(0);
    std.mem.writeInt(u32, empty[0..4], end_of_central_signature, .little);
    const archive = try parse(&empty);
    try std.testing.expectEqual(@as(usize, 0), archive.entry_count);

    std.mem.writeInt(u16, empty[4..6], 1, .little);
    try std.testing.expectError(error.UnsupportedZipFeature, parse(&empty));
}

test "ZIP writer deterministically round trips multiple stored and deflate entries" {
    const allocator = std.testing.allocator;
    const deflated_payload = "deterministic ZIP writer payload\n" ** 64;
    const lzma_payload = "deterministic ZIP LZMA payload\n" ** 64;
    const entries = [_]EncodeEntry{
        .{ .name = "plain.bin", .data = "\x00stored\xff", .method = .stored, .comment = "stored entry" },
        .{ .name = "utf8-目录/data.txt", .data = deflated_payload, .method = .deflate },
        .{ .name = "lzma.txt", .data = lzma_payload, .method = .lzma },
        .{ .name = "empty/", .data = "", .method = .stored },
    };
    const options = EncodeOptions{
        .archive_comment = "vort deterministic archive",
        .data_descriptor = true,
    };
    const first = try encodeAlloc(allocator, &entries, options);
    defer allocator.free(first);
    const second = try encodeAlloc(allocator, &entries, options);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);

    const archive = try parse(first);
    try std.testing.expectEqual(@as(usize, entries.len), archive.entry_count);
    try std.testing.expectEqualStrings(options.archive_comment, archive.comment);
    var it = archive.iterator();
    var index: usize = 0;
    while (try it.next()) |entry| : (index += 1) {
        try std.testing.expectEqualStrings(entries[index].name, entry.name);
        try std.testing.expectEqual(entries[index].method, entry.method);
        try std.testing.expect(entry.flags & 0x0008 != 0);
        try std.testing.expect(entry.flags & 0x0800 != 0);
        if (entry.method == .lzma) {
            try std.testing.expect(entry.flags & 0x0002 != 0);
            try std.testing.expectEqual(@as(u16, 63), try readU16(first, entry.local_header_offset + 4));
        }
        try std.testing.expectEqual(@as(u16, 0), try readU16(first, entry.local_header_offset + 10));
        try std.testing.expectEqual(@as(u16, 0x0021), try readU16(first, entry.local_header_offset + 12));
        const decoded = try archive.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, entries[index].data, decoded);
    }
    try std.testing.expectEqual(entries.len, index);
}

test "ZIP writer appends a valid archive after a prefix and rejects inputs transactionally" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{
        .{ .name = "payload.txt", .data = "prefixed archive", .method = .stored },
    };
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.appendSlice(allocator, "MZ-prefix");
    const prefix_len = out.items.len;
    const written = try encodeAppend(allocator, &out, &entries, .{ .utf8 = false });
    try std.testing.expectEqual(out.items.len - prefix_len, written);

    const archive = try parse(out.items);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(prefix_len, entry.local_header_offset);
    try std.testing.expectEqual(@as(u16, 0), entry.flags & 0x0808);
    const decoded = try archive.extractAlloc(allocator, entry);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(entries[0].data, decoded);

    const before = try allocator.dupe(u8, out.items);
    defer allocator.free(before);
    const invalid_name = [_]EncodeEntry{.{ .name = "", .data = "invalid" }};
    try std.testing.expectError(error.InvalidZipEntryName, encodeAppend(allocator, &out, &invalid_name, .{}));
    try std.testing.expectEqualSlices(u8, before, out.items);

    const invalid_utf8_name = [_]u8{0xff};
    const invalid_utf8 = [_]EncodeEntry{.{ .name = &invalid_utf8_name, .data = "invalid" }};
    try std.testing.expectError(error.InvalidZipTextEncoding, encodeAppend(allocator, &out, &invalid_utf8, .{}));
    try std.testing.expectEqualSlices(u8, before, out.items);

    const unsupported = [_]EncodeEntry{.{
        .name = "unsupported.bin",
        .data = "invalid",
        .method = @enumFromInt(99),
    }};
    try std.testing.expectError(error.UnsupportedZipCompressionMethod, encodeAppend(allocator, &out, &unsupported, .{}));
    try std.testing.expectEqualSlices(u8, before, out.items);
}

test "ZIP writer emits and parses an empty archive" {
    const bytes = try encodeAlloc(std.testing.allocator, &.{}, .{});
    defer std.testing.allocator.free(bytes);
    const archive = try parse(bytes);
    try std.testing.expectEqual(@as(usize, 0), archive.entry_count);
    try std.testing.expectEqual(@as(usize, 0), archive.central_directory_size);
}

test "ZIP64 writer emits forced records and round trips descriptor and header sizes" {
    const allocator = std.testing.allocator;
    const payload = "forced ZIP64 payload " ** 32;
    const entries = [_]EncodeEntry{
        .{ .name = "stored.bin", .data = "zip64 stored", .method = .stored },
        .{ .name = "compressed.txt", .data = payload, .method = .deflate },
    };

    inline for (.{ false, true }) |descriptor| {
        const bytes = try encodeAlloc(allocator, &entries, .{
            .archive_comment = "zip64",
            .data_descriptor = descriptor,
            .zip64 = .always,
        });
        defer allocator.free(bytes);
        const archive = try parse(bytes);
        try std.testing.expect(archive.zip64);
        try std.testing.expectEqual(entries.len, archive.entry_count);
        try std.testing.expectEqualStrings("zip64", archive.comment);

        var it = archive.iterator();
        var index: usize = 0;
        while (try it.next()) |entry| : (index += 1) {
            try std.testing.expect(entry.zip64);
            try std.testing.expectEqual(std.math.maxInt(u32), try readU32(bytes, entry.central_header_offset + 20));
            try std.testing.expectEqual(std.math.maxInt(u32), try readU32(bytes, entry.central_header_offset + 24));
            try std.testing.expectEqual(std.math.maxInt(u32), try readU32(bytes, entry.central_header_offset + 42));
            const decoded = try archive.extractAlloc(allocator, entry);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entries[index].data, decoded);
        }
        try std.testing.expectEqual(entries.len, index);

        const eocd_offset = bytes.len - end_of_central_len - archive.comment.len;
        try std.testing.expectEqual(@as(u32, 0x0706_4b50), try readU32(bytes, eocd_offset - 20));
        const zip64_record_offset: usize = @intCast(std.mem.readInt(u64, bytes[eocd_offset - 12 ..][0..8], .little));
        try std.testing.expectEqual(@as(u32, 0x0606_4b50), try readU32(bytes, zip64_record_offset));
        try std.testing.expectEqual(std.math.maxInt(u16), try readU16(bytes, eocd_offset + 10));
        try std.testing.expectEqual(std.math.maxInt(u32), try readU32(bytes, eocd_offset + 12));
        try std.testing.expectEqual(std.math.maxInt(u32), try readU32(bytes, eocd_offset + 16));
    }
}

test "ZIP writer auto promotes the ZIP32 entry-count sentinel" {
    const allocator = std.testing.allocator;
    const entries = try allocator.alloc(EncodeEntry, std.math.maxInt(u16));
    defer allocator.free(entries);
    for (entries) |*entry| entry.* = .{ .name = "x", .data = "", .method = .stored };

    const bytes = try encodeAlloc(allocator, entries, .{});
    defer allocator.free(bytes);
    const archive = try parse(bytes);
    try std.testing.expect(archive.zip64);
    try std.testing.expectEqual(entries.len, archive.entry_count);
    const first = try archive.entryAt(0);
    const last = try archive.entryAt(entries.len - 1);
    try std.testing.expect(!first.zip64);
    try std.testing.expect(!last.zip64);
    try std.testing.expectEqualStrings("x", last.name);
}

test "ZIP method 1 Shrink writer round trips without extraction scratch" {
    const allocator = std.testing.allocator;
    const payload = "Shrunk ZIP entry with legacy LZW.\n" ** 256;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-shrink.txt",
        .data = payload,
        .method = .shrink,
    }};
    const bytes = try encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
    defer allocator.free(bytes);
    const archive = try parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(CompressionMethod.shrink, entry.method);
    try std.testing.expect(entry.compressed_size < entry.uncompressed_size);
    var output: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try archive.extractInto(entry, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "ZIP method 1 extracts an Apache Commons Compress Shrink fixture" {
    const allocator = std.testing.allocator;
    // Apache Commons Compress src/test/resources/SHRUNK.ZIP.
    // SHA-256: 7403088a3219165f6de8d76abd2daf03bdcf72458dfa14713fc2b34d0293fb4e.
    const fixture_hex = std.mem.trim(
        u8,
        @embedFile("zip/testdata/commons-compress-shrunk.zip.hex"),
        "\r\n \t",
    );
    const fixture = try allocator.alloc(u8, fixture_hex.len / 2);
    defer allocator.free(fixture);
    _ = try std.fmt.hexToBytes(fixture, fixture_hex);
    const archive = try parse(fixture);
    try std.testing.expectEqual(@as(usize, 2), archive.entry_count);
    const expected = [_][]const u8{
        "<?xml version = '1.0'?>\n<!DOCTYPE connections>\n<connections>\n</connections>\n",
        "<?xml version = '1.0'?>\n<!DOCTYPE connections>\n<meinxml>\n    <leer />\n</meinxml>\n",
    };
    for (expected, 0..) |payload, index| {
        const entry = try archive.entryAt(index);
        try std.testing.expectEqual(CompressionMethod.shrink, entry.method);
        const decoded = try archive.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "ZIP method 6 Implode writer round trips all flag modes" {
    const allocator = std.testing.allocator;
    const payload = "Imploded ZIP entry with Shannon-Fano trees.\n" ** 256;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-implode.txt",
        .data = payload,
        .method = .implode,
    }};
    inline for (.{ implode.Dictionary.small_4k, .large_8k }) |dictionary| {
        inline for (.{ false, true }) |literal_tree| {
            const options = EncodeOptions{
                .data_descriptor = true,
                .implode_options = .{
                    .dictionary = dictionary,
                    .literal_tree = literal_tree,
                },
            };
            const bytes = try encodeAlloc(allocator, &entries, options);
            defer allocator.free(bytes);
            const archive = try parse(bytes);
            const entry = try archive.entryAt(0);
            try std.testing.expectEqual(CompressionMethod.implode, entry.method);
            try std.testing.expectEqual(options.implode_options.flags(), entry.flags & 0x0006);
            try std.testing.expect(entry.compressed_size < entry.uncompressed_size);
            var output: [payload.len]u8 = undefined;
            try std.testing.expectEqual(payload.len, try archive.extractInto(entry, &output));
            try std.testing.expectEqualSlices(u8, payload, &output);
        }
    }
}

test "ZIP method 6 extracts Apache Commons Compress Implode fixtures" {
    const allocator = std.testing.allocator;
    const Fixture = struct {
        encoded: []const u8,
        name: []const u8,
        size: usize,
        flags: u16,
    };
    const fixtures = [_]Fixture{
        .{
            // src/test/resources/imploding-4Kdict-2trees.zip
            // SHA-256: cde0fbf261fb6f18339b2159c530462bc91220d9b43cd090b303d5b663b3f0bb.
            .encoded = @embedFile("zip/testdata/commons-compress-implode-4k-2trees.zip.b64"),
            .name = "HEADER.TXT",
            .size = 818,
            .flags = 0,
        },
        .{
            // src/test/resources/imploding-8Kdict-3trees.zip
            // SHA-256: 88d2bf6cf1e2f9604be7639ab67218e9a6ed946d0919b29cfff699c5bbc6c5fa.
            .encoded = @embedFile("zip/testdata/commons-compress-implode-8k-3trees.zip.b64"),
            .name = "LICENSE.TXT",
            .size = 11_560,
            .flags = 0x0006,
        },
    };
    const decoder = std.base64.standard.decoderWithIgnore("\r\n \t");
    for (fixtures) |fixture| {
        const encoded_size = decoder.calcSizeUpperBound(fixture.encoded.len);
        const storage = try allocator.alloc(u8, encoded_size);
        defer allocator.free(storage);
        const decoded_size = try decoder.decode(storage, fixture.encoded);
        const archive = try parse(storage[0..decoded_size]);
        const entry = (try archive.find(fixture.name)).?;
        try std.testing.expectEqual(CompressionMethod.implode, entry.method);
        try std.testing.expectEqual(fixture.flags, entry.flags & 0x0006);
        try std.testing.expectEqual(fixture.size, entry.uncompressed_size);
        const payload = try archive.extractAlloc(allocator, entry);
        defer allocator.free(payload);
        try std.testing.expectEqual(fixture.size, payload.len);
    }
}

test "ZIP method 12 round trips through the allocating Bzip2 extraction path" {
    const allocator = std.testing.allocator;
    const payload = "Bzip2-compressed ZIP entry " ** 128;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-bzip2.txt",
        .data = payload,
        .method = .bzip2,
    }};
    const bytes = try encodeAlloc(allocator, &entries, .{
        .data_descriptor = true,
        .bzip2_options = .{ .block_size_100k = 1 },
    });
    defer allocator.free(bytes);

    const archive = try parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(CompressionMethod.bzip2, entry.method);
    try std.testing.expectEqual(@as(u16, 46), try readU16(bytes, entry.local_header_offset + 4));
    try std.testing.expectEqual(@as(u16, 46), try readU16(bytes, entry.central_header_offset + 6));

    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.ZipEntryRequiresAllocator, archive.extractInto(entry, &output));
    try std.testing.expectEqual(payload.len, try archive.extractIntoWithAllocator(allocator, entry, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);

    const allocated = try archive.extractAlloc(allocator, entry);
    defer allocator.free(allocated);
    try std.testing.expectEqualSlices(u8, payload, allocated);
}

test "ZIP method 9 extracts a 7-Zip Deflate64 reference entry" {
    const allocator = std.testing.allocator;
    const payload = "Deflate64 ZIP reference\n" ** 32;
    const compressed_hex = "e5c8a10d00200c4541cf141d8230010687c611f2aa08a261ff74907ff23a7ef7a7555b635ae004ef50e45ffe353e01";
    var compressed: [compressed_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&compressed, compressed_hex);
    var entry = TestEntry{
        .name = "reference.txt",
        .payload = payload,
        .compressed = &compressed,
        .method = @intFromEnum(CompressionMethod.deflate64),
        .flags = 0,
        .local_offset = 0,
    };
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(allocator);
    try appendTestLocal(&bytes, allocator, &entry);
    const central_offset = bytes.items.len;
    try appendTestCentral(&bytes, allocator, entry);
    const central_size = bytes.items.len - central_offset;
    try appendU32(&bytes, allocator, end_of_central_signature);
    try appendU16(&bytes, allocator, 0);
    try appendU16(&bytes, allocator, 0);
    try appendU16(&bytes, allocator, 1);
    try appendU16(&bytes, allocator, 1);
    try appendU32(&bytes, allocator, @intCast(central_size));
    try appendU32(&bytes, allocator, @intCast(central_offset));
    try appendU16(&bytes, allocator, 0);

    const archive = try parse(bytes.items);
    const parsed = try archive.entryAt(0);
    try std.testing.expectEqual(CompressionMethod.deflate64, parsed.method);
    var output: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try archive.extractInto(parsed, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "ZIP method 9 writer emits Deflate64 and round trips without extraction scratch" {
    const allocator = std.testing.allocator;
    const payload = "Deflate64-compressed ZIP entry " ** 128;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-deflate64.txt",
        .data = payload,
        .method = .deflate64,
    }};
    const bytes = try encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
    defer allocator.free(bytes);

    const archive = try parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(CompressionMethod.deflate64, entry.method);
    try std.testing.expectEqual(@as(u16, 21), try readU16(bytes, entry.local_header_offset + 4));
    try std.testing.expectEqual(@as(u16, 21), try readU16(bytes, entry.central_header_offset + 6));
    try std.testing.expect(entry.compressed_size < entry.uncompressed_size);

    var output: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try archive.extractInto(entry, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "ZIP method 14 writer round trips through the allocating LZMA path" {
    const allocator = std.testing.allocator;
    const payload = "LZMA-compressed ZIP entry " ** 128;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-lzma.txt",
        .data = payload,
        .method = .lzma,
    }};
    const bytes = try encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
    defer allocator.free(bytes);

    const archive = try parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(CompressionMethod.lzma, entry.method);
    try std.testing.expect(entry.flags & 0x0002 != 0);
    try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.local_header_offset + 4));
    try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.central_header_offset + 6));

    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.ZipEntryRequiresAllocator, archive.extractInto(entry, &output));
    try std.testing.expectEqual(payload.len, try archive.extractIntoWithAllocator(allocator, entry, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "ZIP method 98 PPMd writer round trips restore modes and memory limits" {
    const allocator = std.testing.allocator;
    const payload = "PPMd8-compressed ZIP entry " ** 256;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-ppmd.txt",
        .data = payload,
        .method = .ppmd,
    }};
    inline for (.{ ppmd8.RestoreMethod.restart, .cut_off }) |restore_method| {
        const bytes = try encodeAlloc(allocator, &entries, .{
            .data_descriptor = true,
            .ppmd_options = .{
                .order = if (restore_method == .restart) 8 else 12,
                .memory_size = 1024 * 1024,
                .restore_method = restore_method,
            },
        });
        defer allocator.free(bytes);
        const archive = try parse(bytes);
        const entry = try archive.entryAt(0);
        try std.testing.expectEqual(CompressionMethod.ppmd, entry.method);
        try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.local_header_offset + 4));
        try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.central_header_offset + 6));
        var output: [payload.len]u8 = undefined;
        try std.testing.expectError(error.ZipEntryRequiresAllocator, archive.extractInto(entry, &output));
        try std.testing.expectEqual(
            payload.len,
            try archive.extractIntoWithOptions(allocator, entry, &output, .{
                .max_dictionary_size = 1024 * 1024,
            }),
        );
        try std.testing.expectEqualSlices(u8, payload, &output);
        try std.testing.expectError(
            error.OutputLimitExceeded,
            archive.extractIntoWithOptions(allocator, entry, &output, .{
                .max_dictionary_size = 1024 * 1024 - 1,
            }),
        );
    }
}

test "ZIP method 95 writer round trips through the allocating XZ path" {
    const allocator = std.testing.allocator;
    const payload = "XZ-compressed ZIP entry " ** 128;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-xz.txt",
        .data = payload,
        .method = .xz,
    }};
    const bytes = try encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
    defer allocator.free(bytes);

    const archive = try parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(CompressionMethod.xz, entry.method);
    try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.local_header_offset + 4));
    try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.central_header_offset + 6));

    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.ZipEntryRequiresAllocator, archive.extractInto(entry, &output));
    try std.testing.expectEqual(payload.len, try archive.extractIntoWithAllocator(allocator, entry, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "ZIP methods 20 and 93 round trip through the caller-owned Zstandard path" {
    const allocator = std.testing.allocator;
    const payload = "Zstandard-compressed ZIP entry " ** 128;
    inline for (.{ CompressionMethod.zstandard_legacy, .zstandard }) |method| {
        const entries = [_]EncodeEntry{.{
            .name = "compressed-with-zstd.txt",
            .data = payload,
            .method = method,
        }};
        const bytes = try encodeAlloc(allocator, &entries, .{
            .data_descriptor = true,
            .zstd_level = 3,
            .zstd_options = .{ .content_checksum = true },
        });
        defer allocator.free(bytes);

        const archive = try parse(bytes);
        const entry = try archive.entryAt(0);
        try std.testing.expectEqual(method, entry.method);
        try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.local_header_offset + 4));
        try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.central_header_offset + 6));
        var output: [payload.len]u8 = undefined;
        try std.testing.expectEqual(payload.len, try archive.extractInto(entry, &output));
        try std.testing.expectEqualSlices(u8, payload, &output);

        if (method == .zstandard_legacy) {
            const bad_central_version = try allocator.dupe(u8, bytes);
            defer allocator.free(bad_central_version);
            std.mem.writeInt(u16, bad_central_version[entry.central_header_offset + 6 ..][0..2], 62, .little);
            const bad_central_archive = try parse(bad_central_version);
            try std.testing.expectError(error.InvalidZipArchive, bad_central_archive.entryAt(0));

            const bad_local_version = try allocator.dupe(u8, bytes);
            defer allocator.free(bad_local_version);
            std.mem.writeInt(u16, bad_local_version[entry.local_header_offset + 4 ..][0..2], 62, .little);
            const bad_local_archive = try parse(bad_local_version);
            const bad_local_entry = try bad_local_archive.entryAt(0);
            try std.testing.expectError(error.InvalidZipArchive, bad_local_archive.extractInto(bad_local_entry, &output));
        }
    }
}

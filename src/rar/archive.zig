const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const rar15 = @import("rar15.zig");
const rar20 = @import("rar20.zig");
const rar29 = @import("rar29.zig");

pub const Error = core.Error || rar15.Error || rar20.Error || rar29.Error || error{
    InvalidRarArchive,
    UnsupportedRarCompression,
    UnsupportedRarEntry,
    UnsupportedRarFeature,
    EncryptedRarEntry,
    EncryptedRarHeaders,
    SplitRarEntry,
    RarEntryNotFound,
};

pub const Version = enum { rar4, rar5 };

pub const DecodeOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_ppmd_memory: usize = rar29.default_max_ppmd_memory,
    max_vm_instructions: usize = rar29.default_max_vm_instructions,
};

pub const Method = enum {
    stored,
    rar15,
    rar20,
    rar29,
    rar50,
    unsupported,
};

pub const Name = struct {
    bytes: []const u8,

    pub fn len(self: Name) usize {
        return self.bytes.len;
    }

    pub fn writeInto(self: Name, output: []u8) Error!usize {
        if (output.len < self.bytes.len) return error.OutputTooSmall;
        for (self.bytes, 0..) |byte, index| output[index] = normalizedSeparator(byte);
        return self.bytes.len;
    }

    pub fn alloc(self: Name, allocator: std.mem.Allocator) ![]u8 {
        const output = try allocator.alloc(u8, self.bytes.len);
        errdefer allocator.free(output);
        _ = try self.writeInto(output);
        return output;
    }

    pub fn eql(self: Name, expected: []const u8) bool {
        if (self.bytes.len != expected.len) return false;
        for (self.bytes, expected) |actual, wanted|
            if (normalizedSeparator(actual) != normalizedSeparator(wanted)) return false;
        return true;
    }
};

pub const Entry = struct {
    name: Name,
    version: Version,
    method: Method,
    method_id: u8,
    compression_version: u8,
    crc32: ?u32,
    compressed_size: usize,
    uncompressed_size: usize,
    header_offset: usize,
    header_size: usize,
    data_offset: usize,
    next_offset: usize,
    host_os: u64,
    attributes: u64,
    mtime: ?u32,
    directory: bool,
    encrypted: bool,
    solid: bool,
    split_before: bool,
    split_after: bool,
    unknown_size: bool,
    redirection: bool,
    safe_path: bool,

    pub fn isDirectory(self: Entry) bool {
        return self.directory;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    version: Version,
    entry_count: usize,
    prefix_size: usize,
    entries_offset: usize,
    archive_end: usize,
    trailer_size: usize,
    multi_volume: bool,
    solid: bool,
    locked: bool,

    pub fn iterator(self: Archive) Iterator {
        return .{ .archive = self, .offset = self.entries_offset, .remaining = self.entry_count };
    }

    pub fn entryAt(self: Archive, wanted: usize) Error!Entry {
        if (wanted >= self.entry_count) return error.RangeOutOfBounds;
        var it = self.iterator();
        var index: usize = 0;
        while (try it.next()) |entry| : (index += 1)
            if (index == wanted) return entry;
        return error.InvalidRarArchive;
    }

    pub fn find(self: Archive, name: []const u8) Error!?Entry {
        var it = self.iterator();
        while (try it.next()) |entry|
            if (entry.name.eql(name)) return entry;
        return null;
    }

    pub fn extractInto(self: Archive, entry: Entry, output: []u8) Error!usize {
        return self.extractIntoOptionalAllocator(null, entry, output, .{});
    }

    pub fn extractIntoWithAllocator(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        output: []u8,
    ) Error!usize {
        return self.extractIntoOptionalAllocator(allocator, entry, output, .{});
    }

    pub fn extractIntoWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        output: []u8,
        options: DecodeOptions,
    ) Error!usize {
        return self.extractIntoOptionalAllocator(allocator, entry, output, options);
    }

    fn extractIntoOptionalAllocator(
        self: Archive,
        allocator: ?std.mem.Allocator,
        entry: Entry,
        output: []u8,
        options: DecodeOptions,
    ) Error!usize {
        const canonical = try self.extractableEntry(entry);
        if (canonical.uncompressed_size > options.max_output_len)
            return error.OutputLimitExceeded;
        if (output.len < canonical.uncompressed_size) return error.OutputTooSmall;
        const data_end = try checkedEnd(
            canonical.data_offset,
            canonical.compressed_size,
            self.bytes.len,
        );
        const data = self.bytes[canonical.data_offset..data_end];
        const target = output[0..canonical.uncompressed_size];
        switch (canonical.method) {
            .stored => @memcpy(target, data),
            .rar15 => try rar15.decodeInto(data, target),
            .rar20 => try rar20.decodeInto(data, target),
            .rar29 => if (allocator) |scratch|
                try rar29.decodeIntoWithOptions(scratch, data, target, .{
                    .max_output_len = options.max_output_len,
                    .max_ppmd_memory = options.max_ppmd_memory,
                    .max_vm_instructions = options.max_vm_instructions,
                })
            else
                try rar29.decodeInto(data, target),
            else => unreachable,
        }
        if (canonical.crc32) |expected|
            if (checksum.crc32(target) != expected) return error.ChecksumMismatch;
        return target.len;
    }

    pub fn extractAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
    ) ![]u8 {
        return self.extractAllocLimited(allocator, entry, std.math.maxInt(usize));
    }

    pub fn extractAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        max_output_len: usize,
    ) ![]u8 {
        return self.extractAllocWithOptions(
            allocator,
            entry,
            .{ .max_output_len = max_output_len },
        );
    }

    pub fn extractAllocWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        options: DecodeOptions,
    ) ![]u8 {
        const canonical = try self.extractableEntry(entry);
        if (canonical.uncompressed_size > options.max_output_len)
            return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, canonical.uncompressed_size);
        errdefer allocator.free(output);
        const written = try self.extractIntoWithOptions(allocator, entry, output, options);
        if (written != output.len) return error.SizeMismatch;
        return output;
    }

    pub fn extractByNameAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        max_output_len: usize,
    ) ![]u8 {
        const entry = (try self.find(name)) orelse return error.RarEntryNotFound;
        return self.extractAllocLimited(allocator, entry, max_output_len);
    }

    pub fn extractByNameAllocWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        options: DecodeOptions,
    ) ![]u8 {
        const entry = (try self.find(name)) orelse return error.RarEntryNotFound;
        return self.extractAllocWithOptions(allocator, entry, options);
    }

    fn canonicalEntry(self: Archive, entry: Entry) Error!Entry {
        const block = switch (self.version) {
            .rar4 => try parseRar4Block(self.bytes, entry.header_offset),
            .rar5 => try parseRar5Block(self.bytes, entry.header_offset),
        };
        const canonical = block.entry orelse return error.InvalidRarArchive;
        if (!sameEntry(canonical, entry)) return error.InvalidRarArchive;
        return canonical;
    }

    fn extractableEntry(self: Archive, entry: Entry) Error!Entry {
        const canonical = try self.canonicalEntry(entry);
        if (canonical.directory) return error.UnsupportedRarEntry;
        if (canonical.encrypted) return error.EncryptedRarEntry;
        if (canonical.split_before or canonical.split_after) return error.SplitRarEntry;
        if (canonical.redirection or canonical.unknown_size) return error.UnsupportedRarFeature;
        if (canonical.solid and canonical.method != .stored) return error.UnsupportedRarFeature;
        if (canonical.method != .stored and canonical.method != .rar15 and
            canonical.method != .rar20 and canonical.method != .rar29)
            return error.UnsupportedRarCompression;
        if (canonical.method == .stored and canonical.compressed_size != canonical.uncompressed_size)
            return error.SizeMismatch;
        return canonical;
    }
};

pub const Iterator = struct {
    archive: Archive,
    offset: usize,
    remaining: usize,

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.remaining == 0) return null;
        while (self.offset < self.archive.archive_end) {
            const block = switch (self.archive.version) {
                .rar4 => try parseRar4Block(self.archive.bytes, self.offset),
                .rar5 => try parseRar5Block(self.archive.bytes, self.offset),
            };
            self.offset = block.next_offset;
            if (block.end_archive) return error.InvalidRarArchive;
            if (block.entry) |entry| {
                self.remaining -= 1;
                return entry;
            }
        }
        return error.InvalidRarArchive;
    }
};

pub fn parse(bytes: []const u8) Error!Archive {
    const signature = try findSignature(bytes);
    return switch (signature.version) {
        .rar4 => parseRar4Archive(bytes, signature.offset),
        .rar5 => parseRar5Archive(bytes, signature.offset),
    };
}

const Signature = struct { version: Version, offset: usize };

fn findSignature(bytes: []const u8) Error!Signature {
    const max_offset = @min(bytes.len, max_sfx_size);
    var offset: usize = 0;
    while (offset <= max_offset and offset < bytes.len) : (offset += 1) {
        if (bytes.len - offset >= rar5_signature.len and
            std.mem.eql(u8, bytes[offset .. offset + rar5_signature.len], rar5_signature))
            return .{ .version = .rar5, .offset = offset };
        if (bytes.len - offset >= rar4_signature.len and
            std.mem.eql(u8, bytes[offset .. offset + rar4_signature.len], rar4_signature))
            return .{ .version = .rar4, .offset = offset };
    }
    return if (bytes.len < rar4_signature.len) error.TruncatedFrame else error.InvalidMagic;
}

fn parseRar4Archive(bytes: []const u8, prefix: usize) Error!Archive {
    const main_offset = try checkedAdd(prefix, rar4_signature.len);
    const main = try parseRar4RawBlock(bytes, main_offset);
    if (main.header_type != rar4_main_header or main.header_size < 13)
        return error.InvalidRarArchive;
    if (main.data_size != 0) return error.InvalidRarArchive;
    if (main.flags & rar4_main_password != 0) return error.EncryptedRarHeaders;
    var offset = main.next_offset;
    var count: usize = 0;
    var end_offset: ?usize = null;
    while (offset < bytes.len) {
        const block = try parseRar4Block(bytes, offset);
        if (block.entry != null) count += 1;
        offset = block.next_offset;
        if (block.end_archive) {
            end_offset = offset;
            break;
        }
    }
    // ENDARC is optional in ordinary unencrypted RAR 1.5-4.x archives. EOF
    // immediately after a complete block is therefore a clean terminator.
    const archive_end = end_offset orelse if (offset == bytes.len)
        offset
    else
        return error.TruncatedFrame;
    return .{
        .bytes = bytes,
        .version = .rar4,
        .entry_count = count,
        .prefix_size = prefix,
        .entries_offset = main.next_offset,
        .archive_end = archive_end,
        .trailer_size = bytes.len - archive_end,
        .multi_volume = main.flags & rar4_main_volume != 0,
        .solid = main.flags & rar4_main_solid != 0,
        .locked = main.flags & rar4_main_locked != 0,
    };
}

fn parseRar5Archive(bytes: []const u8, prefix: usize) Error!Archive {
    const main_offset = try checkedAdd(prefix, rar5_signature.len);
    const main = try parseRar5RawBlock(bytes, main_offset);
    if (main.header_type == rar5_crypt_header) return error.EncryptedRarHeaders;
    if (main.header_type != rar5_main_header) return error.InvalidRarArchive;
    if (main.data_size != 0) return error.InvalidRarArchive;
    var cursor = main.type_specific_start;
    const archive_flags = try readVint(bytes, &cursor, main.type_specific_end);
    if (archive_flags & rar5_main_volume_number != 0)
        _ = try readVint(bytes, &cursor, main.type_specific_end);
    var offset = main.next_offset;
    var count: usize = 0;
    var end_offset: ?usize = null;
    var end_flags: u64 = 0;
    while (offset < bytes.len) {
        const block = try parseRar5Block(bytes, offset);
        if (block.entry != null) count += 1;
        offset = block.next_offset;
        if (block.end_archive) {
            var end_cursor = block.type_specific_start;
            end_flags = try readVint(bytes, &end_cursor, block.type_specific_end);
            end_offset = offset;
            break;
        }
    }
    const archive_end = end_offset orelse return error.TruncatedFrame;
    return .{
        .bytes = bytes,
        .version = .rar5,
        .entry_count = count,
        .prefix_size = prefix,
        .entries_offset = main.next_offset,
        .archive_end = archive_end,
        .trailer_size = bytes.len - archive_end,
        .multi_volume = archive_flags & rar5_main_volume != 0 or end_flags & 1 != 0,
        .solid = archive_flags & rar5_main_solid != 0,
        .locked = archive_flags & rar5_main_locked != 0,
    };
}

const ParsedBlock = struct {
    entry: ?Entry,
    next_offset: usize,
    end_archive: bool,
    type_specific_start: usize = 0,
    type_specific_end: usize = 0,
};

const Rar4RawBlock = struct {
    header_type: u8,
    flags: u16,
    header_size: usize,
    header_end: usize,
    data_size: usize,
    next_offset: usize,
};

fn parseRar4RawBlock(bytes: []const u8, offset: usize) Error!Rar4RawBlock {
    _ = try checkedEnd(offset, 7, bytes.len);
    const expected_crc = readLe16(bytes, offset);
    const header_type = bytes[offset + 2];
    const flags = readLe16(bytes, offset + 3);
    const header_size: usize = readLe16(bytes, offset + 5);
    if (header_size < 7) return error.InvalidRarArchive;
    const header_end = try checkedEnd(offset, header_size, bytes.len);
    const has_data_size = flags & rar4_long_block != 0 or header_type == rar4_file_header;
    if (has_data_size and header_size < 11) return error.InvalidRarArchive;
    const data_size: usize = if (has_data_size) readLe32(bytes, offset + 7) else 0;
    const crc_end = try rar4HeaderCrcEnd(bytes, offset, header_type, flags, header_end);
    if (header_type != 0x76 and header_type != 0x79) {
        const actual_crc: u16 = @truncate(checksum.crc32(bytes[offset + 2 .. crc_end]));
        if (actual_crc != expected_crc) return error.ChecksumMismatch;
    }
    return .{
        .header_type = header_type,
        .flags = flags,
        .header_size = header_size,
        .header_end = header_end,
        .data_size = data_size,
        .next_offset = try checkedEnd(header_end, data_size, bytes.len),
    };
}

fn rar4HeaderCrcEnd(
    bytes: []const u8,
    offset: usize,
    header_type: u8,
    flags: u16,
    header_end: usize,
) Error!usize {
    if ((header_type == rar4_main_header and flags & 0x0002 != 0) or
        header_type == 0x75) return @min(header_end, offset + 13);
    if (header_type == rar4_file_header and flags & rar4_file_comment != 0) {
        _ = try checkedEnd(offset, 32, bytes.len);
        var end = offset + 32;
        if (flags & rar4_file_large != 0) end = try checkedAdd(end, 8);
        end = try checkedAdd(end, readLe16(bytes, offset + 26));
        if (flags & rar4_file_salt != 0) end = try checkedAdd(end, 8);
        if (end > header_end) return error.InvalidRarArchive;
        return end;
    }
    return header_end;
}

fn parseRar4Block(bytes: []const u8, offset: usize) Error!ParsedBlock {
    const raw = try parseRar4RawBlock(bytes, offset);
    if (raw.header_type == rar4_end_header) {
        if (raw.data_size != 0) return error.InvalidRarArchive;
        return .{ .entry = null, .next_offset = raw.next_offset, .end_archive = true };
    }
    if (raw.header_type != rar4_file_header)
        return .{ .entry = null, .next_offset = raw.next_offset, .end_archive = false };
    if (raw.header_size < 32) return error.InvalidRarArchive;
    const pack_low = readLe32(bytes, offset + 7);
    const unp_low = readLe32(bytes, offset + 11);
    var cursor = offset + 32;
    var packed_size_u64: u64 = pack_low;
    var unpacked: u64 = unp_low;
    if (raw.flags & rar4_file_large != 0) {
        _ = try checkedEnd(cursor, 8, raw.header_end);
        packed_size_u64 |= @as(u64, readLe32(bytes, cursor)) << 32;
        unpacked |= @as(u64, readLe32(bytes, cursor + 4)) << 32;
        cursor += 8;
    }
    const name_size: usize = readLe16(bytes, offset + 26);
    const name_end = try checkedEnd(cursor, name_size, raw.header_end);
    var name_bytes = bytes[cursor..name_end];
    if (raw.flags & rar4_file_unicode != 0) {
        if (std.mem.indexOfScalar(u8, name_bytes, 0)) |ansi_end|
            name_bytes = name_bytes[0..ansi_end];
    }
    if (name_bytes.len == 0) return error.InvalidRarArchive;
    const packed_size = std.math.cast(usize, packed_size_u64) orelse return error.IntegerOverflow;
    const unpacked_size = std.math.cast(usize, unpacked) orelse return error.IntegerOverflow;
    const data_offset = raw.header_end;
    const next_offset = try checkedEnd(data_offset, packed_size, bytes.len);
    const compression_version = bytes[offset + 24];
    const method_id = bytes[offset + 25];
    const directory = raw.flags & rar4_directory_mask == rar4_directory_mask or
        ((bytes[offset + 15] == 0 or bytes[offset + 15] == 2) and readLe32(bytes, offset + 28) & 0x10 != 0);
    if (directory and (packed_size != 0 or unpacked_size != 0)) return error.InvalidRarArchive;
    const method = rar4Method(method_id, compression_version);
    if (method == .stored and raw.flags & rar4_file_password == 0 and packed_size != unpacked_size)
        return error.InvalidRarArchive;
    return .{
        .entry = .{
            .name = .{ .bytes = name_bytes },
            .version = .rar4,
            .method = method,
            .method_id = method_id,
            .compression_version = compression_version,
            .crc32 = readLe32(bytes, offset + 16),
            .compressed_size = packed_size,
            .uncompressed_size = unpacked_size,
            .header_offset = offset,
            .header_size = raw.header_size,
            .data_offset = data_offset,
            .next_offset = next_offset,
            .host_os = bytes[offset + 15],
            .attributes = readLe32(bytes, offset + 28),
            .mtime = readLe32(bytes, offset + 20),
            .directory = directory,
            .encrypted = raw.flags & rar4_file_password != 0,
            .solid = raw.flags & rar4_file_solid != 0,
            .split_before = raw.flags & rar4_file_split_before != 0,
            .split_after = raw.flags & rar4_file_split_after != 0,
            .unknown_size = false,
            .redirection = false,
            .safe_path = isSafePath(name_bytes),
        },
        .next_offset = next_offset,
        .end_archive = false,
    };
}

fn rar4Method(method_id: u8, version: u8) Method {
    if (method_id == 0x30) return .stored;
    if (method_id < 0x31 or method_id > 0x35) return .unsupported;
    if (version <= 15) return .rar15;
    if (version == 20 or version == 26) return .rar20;
    if (version >= 29) return .rar29;
    return .unsupported;
}

const Rar5RawBlock = struct {
    header_type: u64,
    flags: u64,
    extra_start: usize,
    extra_end: usize,
    data_size: usize,
    data_offset: usize,
    next_offset: usize,
    type_specific_start: usize,
    type_specific_end: usize,
    header_size: usize,
};

fn parseRar5RawBlock(bytes: []const u8, offset: usize) Error!Rar5RawBlock {
    _ = try checkedEnd(offset, 5, bytes.len);
    const expected_crc = readLe32(bytes, offset);
    var cursor = offset + 4;
    const header_body_size_u64 = try readVint(bytes, &cursor, bytes.len);
    const header_body_size = std.math.cast(usize, header_body_size_u64) orelse return error.IntegerOverflow;
    if (header_body_size > rar5_max_header_size) return error.InvalidRarArchive;
    const header_end = try checkedEnd(cursor, header_body_size, bytes.len);
    if (checksum.crc32(bytes[offset + 4 .. header_end]) != expected_crc)
        return error.ChecksumMismatch;
    const header_type = try readVint(bytes, &cursor, header_end);
    const flags = try readVint(bytes, &cursor, header_end);
    const extra_size_u64 = if (flags & rar5_header_extra != 0)
        try readVint(bytes, &cursor, header_end)
    else
        0;
    const data_size_u64 = if (flags & rar5_header_data != 0)
        try readVint(bytes, &cursor, header_end)
    else
        0;
    const extra_size = std.math.cast(usize, extra_size_u64) orelse return error.IntegerOverflow;
    const data_size = std.math.cast(usize, data_size_u64) orelse return error.IntegerOverflow;
    if (extra_size > header_end - cursor) return error.InvalidRarArchive;
    const extra_start = header_end - extra_size;
    const data_offset = header_end;
    return .{
        .header_type = header_type,
        .flags = flags,
        .extra_start = extra_start,
        .extra_end = header_end,
        .data_size = data_size,
        .data_offset = data_offset,
        .next_offset = try checkedEnd(data_offset, data_size, bytes.len),
        .type_specific_start = cursor,
        .type_specific_end = extra_start,
        .header_size = header_end - offset,
    };
}

fn parseRar5Block(bytes: []const u8, offset: usize) Error!ParsedBlock {
    const raw = try parseRar5RawBlock(bytes, offset);
    if (raw.header_type == rar5_end_header) {
        if (raw.data_size != 0) return error.InvalidRarArchive;
        return .{
            .entry = null,
            .next_offset = raw.next_offset,
            .end_archive = true,
            .type_specific_start = raw.type_specific_start,
            .type_specific_end = raw.type_specific_end,
        };
    }
    if (raw.header_type == rar5_crypt_header) return error.EncryptedRarHeaders;
    if (raw.header_type != rar5_file_header)
        return .{ .entry = null, .next_offset = raw.next_offset, .end_archive = false };

    var cursor = raw.type_specific_start;
    const file_flags = try readVint(bytes, &cursor, raw.type_specific_end);
    const unpacked_u64 = try readVint(bytes, &cursor, raw.type_specific_end);
    const attributes = try readVint(bytes, &cursor, raw.type_specific_end);
    const mtime = if (file_flags & rar5_file_mtime != 0) blk: {
        _ = try checkedEnd(cursor, 4, raw.type_specific_end);
        const value = readLe32(bytes, cursor);
        cursor += 4;
        break :blk value;
    } else null;
    const data_crc = if (file_flags & rar5_file_crc32 != 0) blk: {
        _ = try checkedEnd(cursor, 4, raw.type_specific_end);
        const value = readLe32(bytes, cursor);
        cursor += 4;
        break :blk value;
    } else null;
    const compression_info = try readVint(bytes, &cursor, raw.type_specific_end);
    const host_os = try readVint(bytes, &cursor, raw.type_specific_end);
    const name_size_u64 = try readVint(bytes, &cursor, raw.type_specific_end);
    const name_size = std.math.cast(usize, name_size_u64) orelse return error.IntegerOverflow;
    const name_end = try checkedEnd(cursor, name_size, raw.type_specific_end);
    const name_bytes = bytes[cursor..name_end];
    if (name_bytes.len == 0) return error.InvalidRarArchive;
    const method_id: u8 = @intCast((compression_info >> 7) & 7);
    const compression_version: u8 = @intCast(compression_info & 0x3f);
    const unpacked_size = std.math.cast(usize, unpacked_u64) orelse return error.IntegerOverflow;
    const directory = file_flags & rar5_file_directory != 0;
    const encrypted = try rar5ExtraHasType(bytes, raw.extra_start, raw.extra_end, 1);
    const redirection = try rar5ExtraHasType(bytes, raw.extra_start, raw.extra_end, 5);
    if (directory and (raw.data_size != 0 or unpacked_size != 0)) return error.InvalidRarArchive;
    const method: Method = if (compression_version > 1)
        .unsupported
    else if (method_id == 0)
        .stored
    else if (method_id <= 5)
        .rar50
    else
        .unsupported;
    if (method == .stored and !encrypted and raw.data_size != unpacked_size)
        return error.InvalidRarArchive;
    return .{
        .entry = .{
            .name = .{ .bytes = name_bytes },
            .version = .rar5,
            .method = method,
            .method_id = method_id,
            .compression_version = compression_version,
            .crc32 = data_crc,
            .compressed_size = raw.data_size,
            .uncompressed_size = unpacked_size,
            .header_offset = offset,
            .header_size = raw.header_size,
            .data_offset = raw.data_offset,
            .next_offset = raw.next_offset,
            .host_os = host_os,
            .attributes = attributes,
            .mtime = mtime,
            .directory = directory,
            .encrypted = encrypted,
            .solid = compression_info & 0x40 != 0,
            .split_before = raw.flags & rar5_header_split_before != 0,
            .split_after = raw.flags & rar5_header_split_after != 0,
            .unknown_size = file_flags & rar5_file_unknown_size != 0,
            .redirection = redirection,
            .safe_path = isSafePath(name_bytes),
        },
        .next_offset = raw.next_offset,
        .end_archive = false,
    };
}

fn rar5ExtraHasType(
    bytes: []const u8,
    start: usize,
    end: usize,
    wanted: u64,
) Error!bool {
    var cursor = start;
    while (cursor < end) {
        const record_size_u64 = try readVint(bytes, &cursor, end);
        const record_size = std.math.cast(usize, record_size_u64) orelse return error.IntegerOverflow;
        if (record_size == 0) return error.InvalidRarArchive;
        const record_end = try checkedEnd(cursor, record_size, end);
        const record_type = try readVint(bytes, &cursor, record_end);
        if (record_type == wanted) return true;
        cursor = record_end;
    }
    return false;
}

fn readVint(bytes: []const u8, cursor: *usize, limit: usize) Error!u64 {
    var value: u64 = 0;
    var shift: u6 = 0;
    var count: usize = 0;
    while (count < 10) : (count += 1) {
        if (cursor.* >= limit or cursor.* >= bytes.len) return error.TruncatedFrame;
        const byte = bytes[cursor.*];
        cursor.* += 1;
        if (shift == 63 and byte & 0x7e != 0) return error.IntegerOverflow;
        value |= @as(u64, byte & 0x7f) << shift;
        if (byte & 0x80 == 0) return value;
        if (shift > 56) return error.IntegerOverflow;
        shift += 7;
    }
    return error.InvalidRarArchive;
}

pub fn isSafePath(path: []const u8) bool {
    if (path.len == 0 or path[0] == '/' or path[0] == '\\') return false;
    var component_start: usize = 0;
    for (path, 0..) |byte, index| {
        if (byte != '/' and byte != '\\') continue;
        if (!safeComponent(path[component_start..index])) return false;
        component_start = index + 1;
    }
    return safeComponent(path[component_start..]);
}

fn safeComponent(component: []const u8) bool {
    return component.len != 0 and !std.mem.eql(u8, component, ".") and
        !std.mem.eql(u8, component, "..");
}

fn sameEntry(a: Entry, b: Entry) bool {
    return a.version == b.version and a.method == b.method and a.method_id == b.method_id and
        a.compression_version == b.compression_version and a.crc32 == b.crc32 and
        a.compressed_size == b.compressed_size and a.uncompressed_size == b.uncompressed_size and
        a.header_offset == b.header_offset and a.header_size == b.header_size and
        a.data_offset == b.data_offset and a.next_offset == b.next_offset and
        a.host_os == b.host_os and a.attributes == b.attributes and a.mtime == b.mtime and
        a.directory == b.directory and a.encrypted == b.encrypted and a.solid == b.solid and
        a.split_before == b.split_before and a.split_after == b.split_after and
        a.unknown_size == b.unknown_size and a.redirection == b.redirection and
        a.safe_path == b.safe_path and std.mem.eql(u8, a.name.bytes, b.name.bytes);
}

fn normalizedSeparator(byte: u8) u8 {
    return if (byte == '\\') '/' else byte;
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = try checkedAdd(start, len);
    if (end > limit) return error.TruncatedFrame;
    return end;
}

fn readLe16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readLe32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

pub const rar4_signature = "Rar!\x1a\x07\x00";
pub const rar5_signature = "Rar!\x1a\x07\x01\x00";
pub const max_sfx_size: usize = 1024 * 1024;

const rar4_main_header: u8 = 0x73;
const rar4_file_header: u8 = 0x74;
const rar4_end_header: u8 = 0x7b;
const rar4_long_block: u16 = 0x8000;
const rar4_main_volume: u16 = 0x0001;
const rar4_main_locked: u16 = 0x0004;
const rar4_main_solid: u16 = 0x0008;
const rar4_main_password: u16 = 0x0080;
const rar4_file_split_before: u16 = 0x0001;
const rar4_file_split_after: u16 = 0x0002;
const rar4_file_password: u16 = 0x0004;
const rar4_file_comment: u16 = 0x0008;
const rar4_file_solid: u16 = 0x0010;
const rar4_file_large: u16 = 0x0100;
const rar4_file_unicode: u16 = 0x0200;
const rar4_file_salt: u16 = 0x0400;
const rar4_directory_mask: u16 = 0x00e0;

const rar5_main_header: u64 = 1;
const rar5_file_header: u64 = 2;
const rar5_crypt_header: u64 = 4;
const rar5_end_header: u64 = 5;
const rar5_header_extra: u64 = 0x0001;
const rar5_header_data: u64 = 0x0002;
const rar5_header_split_before: u64 = 0x0008;
const rar5_header_split_after: u64 = 0x0010;
const rar5_main_volume: u64 = 0x0001;
const rar5_main_volume_number: u64 = 0x0002;
const rar5_main_solid: u64 = 0x0004;
const rar5_main_locked: u64 = 0x0010;
const rar5_file_directory: u64 = 0x0001;
const rar5_file_mtime: u64 = 0x0002;
const rar5_file_crc32: u64 = 0x0004;
const rar5_file_unknown_size: u64 = 0x0008;
const rar5_max_header_size: usize = 2 * 1024 * 1024;

test "RAR path safety rejects traversal and absolute paths" {
    try std.testing.expect(isSafePath("safe/path"));
    try std.testing.expect(!isSafePath("../escape"));
    try std.testing.expect(!isSafePath("safe/../escape"));
    try std.testing.expect(!isSafePath("/absolute"));
}

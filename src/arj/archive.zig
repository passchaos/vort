const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const lha = @import("../lha.zig");
const method4 = @import("method4.zig");
const arj_crypto = @import("vail_archive_crypto").arj;

pub const Error = core.Error || lha.Error || method4.Error || arj_crypto.Error || error{
    InvalidArjArchive,
    UnsupportedArjMethod,
    UnsupportedArjFeature,
    EncryptedArjEntry,
    UnsupportedArjEncryption,
    ArjEntryNotFound,
};

pub const Encryption = enum {
    garble,
    gost40,
    gost256,
};

pub const DecodeOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    password: ?[]const u8 = null,
};

pub const Method = enum {
    stored,
    method_1,
    method_2,
    method_3,
    method_4,
    no_data,
    unsupported,
};

pub const Name = struct {
    bytes: []const u8,

    pub fn len(self: Name) usize {
        return self.bytes.len;
    }

    pub fn writeInto(self: Name, output: []u8) Error!usize {
        if (output.len < self.bytes.len) return error.OutputTooSmall;
        for (self.bytes, 0..) |byte, index|
            output[index] = if (byte == '\\') '/' else byte;
        return self.bytes.len;
    }

    pub fn alloc(self: Name, allocator: std.mem.Allocator) ![]u8 {
        const result = try allocator.alloc(u8, self.bytes.len);
        errdefer allocator.free(result);
        _ = try self.writeInto(result);
        return result;
    }

    pub fn eql(self: Name, expected: []const u8) bool {
        if (self.bytes.len != expected.len) return false;
        for (self.bytes, expected) |actual, wanted|
            if ((if (actual == '\\') '/' else actual) != wanted) return false;
        return true;
    }
};

pub const Entry = struct {
    name: Name,
    method: Method,
    method_id: u8,
    file_type: u8,
    flags: u8,
    password_modifier: u8,
    encryption: ?Encryption,
    crc32: u32,
    compressed_size: usize,
    uncompressed_size: usize,
    extended_file_position: usize,
    total_uncompressed_size: ?usize,
    header_offset: usize,
    data_offset: usize,

    pub fn isDirectory(self: Entry) bool {
        return self.file_type == 3;
    }

    pub fn isEncrypted(self: Entry) bool {
        return self.encryption != null;
    }

    pub fn splitBefore(self: Entry) bool {
        return self.flags & 0x08 != 0;
    }

    pub fn splitAfter(self: Entry) bool {
        return self.flags & 0x04 != 0;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    entry_count: usize,
    prefix_size: usize,
    entries_offset: usize,
    name: []const u8,
    comment: []const u8,
    flags: u8,
    encryption_version: u8,

    pub fn iterator(self: Archive) Iterator {
        return .{
            .archive = self,
            .offset = self.entries_offset,
            .remaining = self.entry_count,
        };
    }

    pub fn entryAt(self: Archive, wanted: usize) Error!Entry {
        if (wanted >= self.entry_count) return error.RangeOutOfBounds;
        var it = self.iterator();
        var index: usize = 0;
        while (try it.next()) |entry| : (index += 1)
            if (index == wanted) return entry;
        return error.InvalidArjArchive;
    }

    pub fn find(self: Archive, name: []const u8) Error!?Entry {
        var it = self.iterator();
        while (try it.next()) |entry|
            if (entry.name.eql(name)) return entry;
        return null;
    }

    pub fn extractInto(self: Archive, entry: Entry, output: []u8) Error!usize {
        return self.extractIntoOptionalAllocator(null, entry, output, .{}, false);
    }

    pub fn extractIntoWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        output: []u8,
        options: DecodeOptions,
    ) Error!usize {
        return self.extractIntoOptionalAllocator(allocator, entry, output, options, false);
    }

    pub fn extractFragmentIntoWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        output: []u8,
        options: DecodeOptions,
    ) Error!usize {
        return self.extractIntoOptionalAllocator(allocator, entry, output, options, true);
    }

    fn extractIntoOptionalAllocator(
        self: Archive,
        allocator: ?std.mem.Allocator,
        entry: Entry,
        output: []u8,
        options: DecodeOptions,
        allow_split: bool,
    ) Error!usize {
        const parsed = try parseLocalEntry(
            self.bytes,
            entry.header_offset,
            self.encryption_version,
        );
        const canonical = parsed.entry;
        if (!sameEntry(canonical, entry)) return error.InvalidArjArchive;
        if (canonical.uncompressed_size > options.max_output_len)
            return error.OutputLimitExceeded;
        if (output.len < canonical.uncompressed_size) return error.OutputTooSmall;
        if (!allow_split and (self.flags & 0x04 != 0 or canonical.flags & 0x0c != 0))
            return error.UnsupportedArjFeature;
        const target = output[0..canonical.uncompressed_size];
        const compressed_end = try checkedEnd(
            canonical.data_offset,
            canonical.compressed_size,
            self.bytes.len,
        );
        const wire_data = self.bytes[canonical.data_offset..compressed_end];
        const decrypted: ?[]u8 = if (canonical.encryption) |encryption| blk: {
            if (encryption != .garble) return error.UnsupportedArjEncryption;
            const password = options.password orelse return error.EncryptedArjEntry;
            const scratch = allocator orelse return error.EncryptedArjEntry;
            const bytes = try scratch.dupe(u8, wire_data);
            errdefer scratch.free(bytes);
            try arj_crypto.crypt(bytes, password, canonical.password_modifier);
            break :blk bytes;
        } else null;
        defer if (decrypted) |bytes| {
            std.crypto.secureZero(u8, bytes);
            allocator.?.free(bytes);
        };
        const compressed = decrypted orelse wire_data;
        switch (canonical.method) {
            .stored => {
                if (compressed.len != target.len) return error.SizeMismatch;
                @memcpy(target, compressed);
            },
            .method_1, .method_2, .method_3 => try lha.decodeLhInto(
                compressed,
                target,
                .lh6,
            ),
            .method_4 => try method4.decodeInto(compressed, target),
            .no_data => if (compressed.len != 0 or target.len != 0)
                return error.SizeMismatch,
            .unsupported => return error.UnsupportedArjMethod,
        }
        if (!canonical.isDirectory() and canonical.method != .no_data and
            checksum.crc32Best(target) != canonical.crc32)
            return error.ChecksumMismatch;
        return target.len;
    }

    pub fn extractAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
    ) ![]u8 {
        return self.extractAllocWithOptions(allocator, entry, .{});
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
        if (entry.uncompressed_size > options.max_output_len)
            return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, entry.uncompressed_size);
        errdefer allocator.free(output);
        const written = try self.extractIntoWithOptions(
            allocator,
            entry,
            output,
            options,
        );
        if (written != output.len) return error.SizeMismatch;
        return output;
    }

    pub fn extractByNameAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        max_output_len: usize,
    ) ![]u8 {
        const entry = (try self.find(name)) orelse return error.ArjEntryNotFound;
        return self.extractAllocLimited(allocator, entry, max_output_len);
    }

    pub fn extractByNameAllocWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        options: DecodeOptions,
    ) ![]u8 {
        const entry = (try self.find(name)) orelse return error.ArjEntryNotFound;
        return self.extractAllocWithOptions(allocator, entry, options);
    }
};

pub const Iterator = struct {
    archive: Archive,
    offset: usize,
    remaining: usize,

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.remaining == 0) return null;
        const parsed = try parseLocalEntry(
            self.archive.bytes,
            self.offset,
            self.archive.encryption_version,
        );
        self.offset = parsed.next_offset;
        self.remaining -= 1;
        return parsed.entry;
    }
};

pub fn parse(bytes: []const u8) Error!Archive {
    var candidate: usize = 0;
    var attempts: usize = 0;
    var first_error: ?Error = null;
    while (candidate < bytes.len) : (candidate += 1) {
        if (bytes.len - candidate < 4) break;
        if (bytes[candidate] != 0x60 or bytes[candidate + 1] != 0xea) continue;
        attempts += 1;
        if (attempts > 256) return error.InvalidArjArchive;
        const archive = parseAt(bytes, candidate) catch |err| {
            if (first_error == null) first_error = err;
            continue;
        };
        return archive;
    }
    if (first_error) |err| return err;
    return error.InvalidMagic;
}

fn parseAt(bytes: []const u8, offset: usize) Error!Archive {
    const main = try parseHeader(bytes, offset);
    if (main.end_marker or main.data.len < 30) return error.InvalidArjArchive;
    if (main.data[6] != 2) return error.InvalidArjArchive;
    const first_size = main.data[0];
    if (first_size < 30 or first_size > main.data.len) return error.InvalidArjArchive;
    const strings = try parseStrings(main.data, first_size);
    const encryption_version = main.data[28];

    var cursor = main.next_offset;
    var entry_count: usize = 0;
    while (true) {
        const header = try parseHeader(bytes, cursor);
        if (header.end_marker) {
            if (header.next_offset != bytes.len) return error.TrailingData;
            break;
        }
        const parsed = try parseLocalEntryFromHeader(
            bytes,
            cursor,
            header,
            encryption_version,
        );
        cursor = parsed.next_offset;
        entry_count += 1;
    }
    return .{
        .bytes = bytes,
        .entry_count = entry_count,
        .prefix_size = offset,
        .entries_offset = main.next_offset,
        .name = strings.name,
        .comment = strings.comment,
        .flags = main.data[4],
        .encryption_version = encryption_version,
    };
}

const ParsedHeader = struct {
    data: []const u8,
    next_offset: usize,
    end_marker: bool,
};

fn parseHeader(bytes: []const u8, offset: usize) Error!ParsedHeader {
    _ = try checkedEnd(offset, 4, bytes.len);
    if (bytes[offset] != 0x60 or bytes[offset + 1] != 0xea)
        return error.InvalidMagic;
    const size = readLe16(bytes, offset + 2);
    if (size == 0) return .{
        .data = "",
        .next_offset = offset + 4,
        .end_marker = true,
    };
    if (size > 2600) return error.InvalidArjArchive;
    const data_start = offset + 4;
    const data_end = try checkedEnd(data_start, size, bytes.len);
    const crc_end = try checkedEnd(data_end, 4, bytes.len);
    if (checksum.crc32Best(bytes[data_start..data_end]) != readLe32(bytes, data_end))
        return error.ChecksumMismatch;

    var cursor = crc_end;
    while (true) {
        _ = try checkedEnd(cursor, 2, bytes.len);
        const extension_size = readLe16(bytes, cursor);
        cursor += 2;
        if (extension_size == 0) break;
        if (extension_size > 2600) return error.InvalidArjArchive;
        const extension_end = try checkedEnd(cursor, extension_size, bytes.len);
        const extension_crc_end = try checkedEnd(extension_end, 4, bytes.len);
        if (checksum.crc32Best(bytes[cursor..extension_end]) != readLe32(bytes, extension_end))
            return error.ChecksumMismatch;
        cursor = extension_crc_end;
    }
    return .{
        .data = bytes[data_start..data_end],
        .next_offset = cursor,
        .end_marker = false,
    };
}

const Strings = struct { name: []const u8, comment: []const u8 };

fn parseStrings(data: []const u8, start: usize) Error!Strings {
    if (start > data.len) return error.InvalidArjArchive;
    const name_end = std.mem.indexOfScalarPos(u8, data, start, 0) orelse
        return error.InvalidArjArchive;
    const comment_start = name_end + 1;
    const comment_end = std.mem.indexOfScalarPos(u8, data, comment_start, 0) orelse
        return error.InvalidArjArchive;
    return .{
        .name = data[start..name_end],
        .comment = data[comment_start..comment_end],
    };
}

const ParsedEntry = struct { entry: Entry, next_offset: usize };

fn parseLocalEntry(
    bytes: []const u8,
    offset: usize,
    encryption_version: u8,
) Error!ParsedEntry {
    const header = try parseHeader(bytes, offset);
    if (header.end_marker) return error.InvalidArjArchive;
    return parseLocalEntryFromHeader(bytes, offset, header, encryption_version);
}

fn parseLocalEntryFromHeader(
    bytes: []const u8,
    offset: usize,
    header: ParsedHeader,
    encryption_version: u8,
) Error!ParsedEntry {
    if (header.data.len < 30) return error.InvalidArjArchive;
    const first_size = header.data[0];
    if (first_size < 30 or first_size > header.data.len) return error.InvalidArjArchive;
    const strings = try parseStrings(header.data, first_size);
    if (strings.name.len == 0) return error.InvalidArjArchive;
    const compressed_size: usize = readLe32(header.data, 12);
    const uncompressed_size: usize = readLe32(header.data, 16);
    if (first_size > 30 and first_size < 34) return error.InvalidArjArchive;
    const extended_file_position: usize = if (first_size >= 34)
        readLe32(header.data, 30)
    else
        0;
    const total_uncompressed_size: ?usize = if (first_size >= 46)
        readLe32(header.data, 42)
    else
        null;
    const data_end = try checkedEnd(header.next_offset, compressed_size, bytes.len);
    const method_id = header.data[5];
    const flags = header.data[4];
    return .{
        .entry = .{
            .name = .{ .bytes = strings.name },
            .method = methodFromId(method_id),
            .method_id = method_id,
            .file_type = header.data[6],
            .flags = flags,
            .password_modifier = header.data[7],
            .encryption = encryptionFromVersion(flags & 1 != 0, encryption_version),
            .crc32 = readLe32(header.data, 20),
            .compressed_size = compressed_size,
            .uncompressed_size = uncompressed_size,
            .extended_file_position = extended_file_position,
            .total_uncompressed_size = total_uncompressed_size,
            .header_offset = offset,
            .data_offset = header.next_offset,
        },
        .next_offset = data_end,
    };
}

fn encryptionFromVersion(encrypted: bool, version: u8) ?Encryption {
    if (!encrypted) return null;
    return switch (version) {
        0, 1 => .garble,
        2 => .gost40,
        else => .gost256,
    };
}

fn methodFromId(id: u8) Method {
    return switch (id) {
        0 => .stored,
        1 => .method_1,
        2 => .method_2,
        3 => .method_3,
        4 => .method_4,
        8, 9 => .no_data,
        else => .unsupported,
    };
}

fn sameEntry(a: Entry, b: Entry) bool {
    return a.header_offset == b.header_offset and
        a.data_offset == b.data_offset and
        a.compressed_size == b.compressed_size and
        a.uncompressed_size == b.uncompressed_size and
        a.extended_file_position == b.extended_file_position and
        a.total_uncompressed_size == b.total_uncompressed_size and
        a.crc32 == b.crc32 and
        a.method_id == b.method_id and
        a.file_type == b.file_type and
        a.flags == b.flags and
        a.password_modifier == b.password_modifier and
        a.encryption == b.encryption and
        eqlNormalized(a.name, b.name);
}

fn eqlNormalized(a: Name, b: Name) bool {
    if (a.bytes.len != b.bytes.len) return false;
    for (a.bytes, b.bytes) |left, right|
        if ((if (left == '\\') '/' else left) !=
            (if (right == '\\') '/' else right)) return false;
    return true;
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, len) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

fn readLe16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readLe32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

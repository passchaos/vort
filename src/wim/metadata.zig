const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidWimMetadata,
    InvalidWimPath,
    WimPathNotFound,
    WimNotDirectory,
    WimNotRegularFile,
    UnsupportedWimFile,
};

pub const dentry_fixed_size: usize = 102;
pub const extra_stream_fixed_size: usize = 38;

pub const file_attribute_directory: u32 = 0x0000_0010;
pub const file_attribute_reparse_point: u32 = 0x0000_0400;
pub const file_attribute_encrypted: u32 = 0x0000_4000;

pub const SecurityData = struct {
    total_length: usize,
    descriptor_count: u32,
};

pub const ExtraStream = struct {
    hash: [20]u8,
    name_utf16le: []const u8,

    pub fn isNamed(self: ExtraStream) bool {
        return self.name_utf16le.len != 0;
    }

    pub fn nameUtf8Alloc(
        self: ExtraStream,
        allocator: std.mem.Allocator,
    ) Error![]u8 {
        return utf16LeBytesToUtf8Alloc(allocator, self.name_utf16le);
    }
};

pub const ExtraStreamIterator = struct {
    bytes: []const u8,
    offset: usize,
    remaining: usize,

    pub fn next(self: *ExtraStreamIterator) Error!?ExtraStream {
        if (self.remaining == 0) return null;
        const parsed = try parseExtraStream(self.bytes, self.offset);
        self.offset = parsed.next_offset;
        self.remaining -= 1;
        return parsed.stream;
    }
};

pub const Dentry = struct {
    metadata_bytes: []const u8,
    offset: usize,
    length: usize,
    next_offset: usize,
    attributes: u32,
    security_id: u32,
    subdir_offset: usize,
    creation_time: u64,
    last_access_time: u64,
    last_write_time: u64,
    main_hash: [20]u8,
    reparse_or_hard_link: u64,
    extra_stream_count: u16,
    extra_stream_offset: usize,
    name_utf16le: []const u8,
    short_name_utf16le: []const u8,

    pub fn isDirectory(self: Dentry) bool {
        return self.attributes & file_attribute_directory != 0;
    }

    pub fn isReparsePoint(self: Dentry) bool {
        return self.attributes & file_attribute_reparse_point != 0;
    }

    pub fn isEncrypted(self: Dentry) bool {
        return self.attributes & file_attribute_encrypted != 0;
    }

    pub fn nameUtf8Alloc(
        self: Dentry,
        allocator: std.mem.Allocator,
    ) Error![]u8 {
        return utf16LeBytesToUtf8Alloc(allocator, self.name_utf16le);
    }

    pub fn shortNameUtf8Alloc(
        self: Dentry,
        allocator: std.mem.Allocator,
    ) Error![]u8 {
        return utf16LeBytesToUtf8Alloc(allocator, self.short_name_utf16le);
    }

    pub fn extraStreams(self: Dentry) ExtraStreamIterator {
        return .{
            .bytes = self.metadata_bytes,
            .offset = self.extra_stream_offset,
            .remaining = self.extra_stream_count,
        };
    }

    pub fn hasNamedStreams(self: Dentry) Error!bool {
        var streams = self.extraStreams();
        while (try streams.next()) |stream|
            if (stream.isNamed()) return true;
        return false;
    }

    /// Returns the SHA-1 of the ordinary unnamed data stream. A zero digest
    /// denotes an empty stream. Directories and reparse points without an
    /// ordinary data stream return null.
    pub fn defaultDataSha1(self: Dentry) Error!?[20]u8 {
        if (self.isEncrypted()) return error.UnsupportedWimFile;
        if (self.isDirectory()) return null;

        var found_reparse = false;
        var data_hash: ?[20]u8 = null;
        if (!hashIsZero(&self.main_hash)) {
            if (self.isReparsePoint()) {
                found_reparse = true;
            } else {
                data_hash = self.main_hash;
            }
        }

        var streams = self.extraStreams();
        while (try streams.next()) |stream| {
            if (stream.isNamed()) continue;
            if (self.isReparsePoint() and !found_reparse) {
                found_reparse = true;
            } else if (data_hash == null) {
                data_hash = stream.hash;
            }
        }

        if (!found_reparse and data_hash == null) {
            if (!self.isReparsePoint()) {
                data_hash = self.main_hash;
            }
        }
        return data_hash;
    }
};

pub const Directory = struct {
    allocator: std.mem.Allocator,
    entries: []Dentry,

    pub fn deinit(self: *Directory) void {
        self.allocator.free(self.entries);
        self.* = undefined;
    }

    pub fn findUtf8(
        self: Directory,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) Error!?Dentry {
        if (!validPathComponent(name)) return error.InvalidWimPath;
        const units = std.unicode.utf8ToUtf16LeAlloc(allocator, name) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.InvalidUtf8 => return error.InvalidWimPath,
        };
        defer allocator.free(units);
        for (self.entries) |entry|
            if (utf16LeBytesEqualUnits(entry.name_utf16le, units)) return entry;
        return null;
    }
};

pub const ImageMetadata = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    security: SecurityData,
    root: Dentry,
    directories_start: usize,

    /// Takes ownership of `bytes`, including when parsing fails.
    pub fn fromOwnedBytes(
        allocator: std.mem.Allocator,
        bytes: []u8,
    ) Error!ImageMetadata {
        errdefer allocator.free(bytes);
        const security = try parseSecurityData(bytes);
        const parsed_root = try parseDentry(bytes, security.total_length, security.descriptor_count);
        const root = parsed_root.dentry;
        if (!root.isDirectory() or root.name_utf16le.len != 0 or
            root.short_name_utf16le.len != 0)
            return error.InvalidWimMetadata;
        const terminator_end = try checkedEnd(parsed_root.next_offset, 8, bytes.len);
        if (readU64(bytes, parsed_root.next_offset) != 0)
            return error.InvalidWimMetadata;
        if (root.subdir_offset != 0) {
            if (root.subdir_offset < terminator_end or
                root.subdir_offset >= bytes.len or
                root.subdir_offset & 7 != 0)
                return error.InvalidWimMetadata;
        }
        return .{
            .allocator = allocator,
            .bytes = bytes,
            .security = security,
            .root = root,
            .directories_start = terminator_end,
        };
    }

    pub fn deinit(self: *ImageMetadata) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }

    pub fn readDirectoryAlloc(
        self: ImageMetadata,
        allocator: std.mem.Allocator,
        directory: Dentry,
        max_entries: usize,
    ) Error!Directory {
        if (directory.metadata_bytes.ptr != self.bytes.ptr or
            directory.metadata_bytes.len != self.bytes.len)
            return error.InvalidWimMetadata;
        if (!directory.isDirectory()) return error.WimNotDirectory;
        if (directory.subdir_offset == 0) {
            return .{
                .allocator = allocator,
                .entries = try allocator.alloc(Dentry, 0),
            };
        }
        if (directory.subdir_offset < self.directories_start or
            directory.subdir_offset & 7 != 0 or
            directory.subdir_offset >= self.bytes.len)
            return error.InvalidWimMetadata;

        var entries: std.ArrayList(Dentry) = .empty;
        errdefer entries.deinit(allocator);
        var seen_names: std.StringHashMapUnmanaged(void) = .empty;
        defer seen_names.deinit(allocator);
        var offset = directory.subdir_offset;
        var list_end: usize = undefined;
        while (true) {
            _ = try checkedEnd(offset, 8, self.bytes.len);
            const raw_length = readU64(self.bytes, offset);
            if (raw_length == 0) {
                list_end = try checkedEnd(offset, 8, self.bytes.len);
                break;
            }
            if (raw_length <= 8) return error.InvalidWimMetadata;
            if (entries.items.len >= max_entries) return error.OutputLimitExceeded;
            const parsed = try parseDentry(self.bytes, offset, self.security.descriptor_count);
            const entry = parsed.dentry;
            if (!validDentryName(entry.name_utf16le)) return error.InvalidWimMetadata;
            if (entry.subdir_offset != 0 and !entry.isDirectory())
                return error.InvalidWimMetadata;
            const name_result = try seen_names.getOrPut(allocator, entry.name_utf16le);
            if (name_result.found_existing) return error.InvalidWimMetadata;
            try entries.append(allocator, entry);
            offset = parsed.next_offset;
        }
        for (entries.items) |entry| {
            if (entry.subdir_offset != 0 and
                (entry.subdir_offset < self.directories_start or
                    entry.subdir_offset >= self.bytes.len or
                    entry.subdir_offset & 7 != 0 or
                    (entry.subdir_offset >= directory.subdir_offset and
                        entry.subdir_offset < list_end)))
                return error.InvalidWimMetadata;
        }
        return .{
            .allocator = allocator,
            .entries = try entries.toOwnedSlice(allocator),
        };
    }

    pub fn lookup(
        self: ImageMetadata,
        allocator: std.mem.Allocator,
        path: []const u8,
        max_directory_entries: usize,
        max_depth: usize,
    ) Error!Dentry {
        if (path.len == 0 or std.mem.eql(u8, path, "/")) return self.root;
        if (std.mem.indexOfScalar(u8, path, 0) != null or
            std.mem.indexOfScalar(u8, path, '\\') != null)
            return error.InvalidWimPath;
        var relative = path;
        if (relative[0] == '/') relative = relative[1..];
        if (relative.len == 0 or relative[relative.len - 1] == '/')
            return error.InvalidWimPath;

        var current = self.root;
        var components = std.mem.splitScalar(u8, relative, '/');
        var depth: usize = 0;
        while (components.next()) |component| {
            if (!validPathComponent(component)) return error.InvalidWimPath;
            if (depth >= max_depth) return error.OutputLimitExceeded;
            depth += 1;
            var directory = try self.readDirectoryAlloc(
                allocator,
                current,
                max_directory_entries,
            );
            defer directory.deinit();
            current = try directory.findUtf8(allocator, component) orelse
                return error.WimPathNotFound;
        }
        return current;
    }
};

const ParsedDentry = struct {
    dentry: Dentry,
    next_offset: usize,
};

fn parseSecurityData(bytes: []const u8) Error!SecurityData {
    if (bytes.len < 8) return error.InvalidWimMetadata;
    const stored_total = readU32(bytes, 0);
    const descriptor_count = readU32(bytes, 4);
    if (descriptor_count > 0x8000_0000) return error.InvalidWimMetadata;
    const total_length = if (stored_total == 0)
        @as(usize, 8)
    else
        try align8(stored_total);
    if (total_length > bytes.len) return error.InvalidWimMetadata;
    const sizes_bytes = std.math.mul(usize, descriptor_count, 8) catch
        return error.IntegerOverflow;
    var descriptor_offset = std.math.add(usize, 8, sizes_bytes) catch
        return error.IntegerOverflow;
    if (descriptor_offset > total_length) return error.InvalidWimMetadata;
    for (0..descriptor_count) |index| {
        const size_u64 = readU64(bytes, 8 + index * 8);
        if (size_u64 > std.math.maxInt(u32)) return error.InvalidWimMetadata;
        const size = std.math.cast(usize, size_u64) orelse return error.IntegerOverflow;
        descriptor_offset = std.math.add(usize, descriptor_offset, size) catch
            return error.IntegerOverflow;
        if (descriptor_offset > total_length) return error.InvalidWimMetadata;
    }
    if (try align8(descriptor_offset) != total_length)
        return error.InvalidWimMetadata;
    return .{
        .total_length = total_length,
        .descriptor_count = descriptor_count,
    };
}

fn parseDentry(
    bytes: []const u8,
    offset: usize,
    descriptor_count: u32,
) Error!ParsedDentry {
    if (offset & 7 != 0) return error.InvalidWimMetadata;
    _ = try checkedEnd(offset, 8, bytes.len);
    const raw_length = readU64(bytes, offset);
    if (raw_length <= 8) return error.InvalidWimMetadata;
    const length = try align8(raw_length);
    if (length < dentry_fixed_size) return error.InvalidWimMetadata;
    const dentry_end = try checkedEnd(offset, length, bytes.len);
    const security_id = readU32(bytes, offset + 12);
    if (security_id != std.math.maxInt(u32) and security_id >= descriptor_count)
        return error.InvalidWimMetadata;
    const short_name_bytes: usize = readU16(bytes, offset + 98);
    const name_bytes: usize = readU16(bytes, offset + 100);
    if (short_name_bytes & 1 != 0 or name_bytes & 1 != 0)
        return error.InvalidWimMetadata;

    var name_offset = offset + dentry_fixed_size;
    const name_end = try checkedEnd(name_offset, name_bytes, dentry_end);
    const name = bytes[name_offset..name_end];
    if (name_bytes != 0) {
        const terminator_end = try checkedEnd(name_end, 2, dentry_end);
        if (readU16(bytes, name_end) != 0) return error.InvalidWimMetadata;
        name_offset = terminator_end;
    }
    const short_name_end = try checkedEnd(name_offset, short_name_bytes, dentry_end);
    const short_name = bytes[name_offset..short_name_end];
    if (short_name_bytes != 0) {
        _ = try checkedEnd(short_name_end, 2, dentry_end);
        if (readU16(bytes, short_name_end) != 0) return error.InvalidWimMetadata;
    }
    if (containsUtf16Unit(name, 0) or containsUtf16Unit(short_name, 0))
        return error.InvalidWimMetadata;

    const extra_stream_count = readU16(bytes, offset + 96);
    var next_offset = dentry_end;
    for (0..extra_stream_count) |_| {
        const parsed = try parseExtraStream(bytes, next_offset);
        next_offset = parsed.next_offset;
    }
    var main_hash: [20]u8 = undefined;
    @memcpy(&main_hash, bytes[offset + 64 .. offset + 84]);
    return .{
        .dentry = .{
            .metadata_bytes = bytes,
            .offset = offset,
            .length = length,
            .next_offset = next_offset,
            .attributes = readU32(bytes, offset + 8),
            .security_id = security_id,
            .subdir_offset = std.math.cast(usize, readU64(bytes, offset + 16)) orelse
                return error.IntegerOverflow,
            .creation_time = readU64(bytes, offset + 40),
            .last_access_time = readU64(bytes, offset + 48),
            .last_write_time = readU64(bytes, offset + 56),
            .main_hash = main_hash,
            .reparse_or_hard_link = readU64(bytes, offset + 88),
            .extra_stream_count = extra_stream_count,
            .extra_stream_offset = dentry_end,
            .name_utf16le = name,
            .short_name_utf16le = short_name,
        },
        .next_offset = next_offset,
    };
}

const ParsedExtraStream = struct {
    stream: ExtraStream,
    next_offset: usize,
};

fn parseExtraStream(bytes: []const u8, offset: usize) Error!ParsedExtraStream {
    if (offset & 7 != 0) return error.InvalidWimMetadata;
    _ = try checkedEnd(offset, 8, bytes.len);
    const length = try align8(readU64(bytes, offset));
    if (length < extra_stream_fixed_size) return error.InvalidWimMetadata;
    const stream_end = try checkedEnd(offset, length, bytes.len);
    const name_bytes: usize = readU16(bytes, offset + 36);
    if (name_bytes & 1 != 0) return error.InvalidWimMetadata;
    const name_offset = offset + extra_stream_fixed_size;
    const name_end = try checkedEnd(name_offset, name_bytes, stream_end);
    if (name_bytes != 0) {
        _ = try checkedEnd(name_end, 2, stream_end);
        if (readU16(bytes, name_end) != 0) return error.InvalidWimMetadata;
    }
    const name = bytes[name_offset..name_end];
    if (containsUtf16Unit(name, 0)) return error.InvalidWimMetadata;
    var hash: [20]u8 = undefined;
    @memcpy(&hash, bytes[offset + 16 .. offset + 36]);
    return .{
        .stream = .{ .hash = hash, .name_utf16le = name },
        .next_offset = stream_end,
    };
}

fn validDentryName(name: []const u8) bool {
    if (name.len == 0 or containsUtf16Unit(name, 0) or
        containsUtf16Unit(name, '/') or containsUtf16Unit(name, '\\'))
        return false;
    if (name.len == 2 and readU16(name, 0) == '.') return false;
    if (name.len == 4 and readU16(name, 0) == '.' and readU16(name, 2) == '.')
        return false;
    return true;
}

fn validPathComponent(name: []const u8) bool {
    if (name.len == 0 or std.mem.eql(u8, name, ".") or
        std.mem.eql(u8, name, ".."))
        return false;
    return std.mem.indexOfAny(u8, name, "/\\\x00") == null;
}

fn containsUtf16Unit(bytes: []const u8, unit: u16) bool {
    var offset: usize = 0;
    while (offset < bytes.len) : (offset += 2)
        if (readU16(bytes, offset) == unit) return true;
    return false;
}

fn utf16LeBytesEqualUnits(bytes: []const u8, units: []const u16) bool {
    if (bytes.len != units.len * 2) return false;
    for (units, 0..) |unit, index|
        if (readU16(bytes, index * 2) != unit) return false;
    return true;
}

fn utf16LeBytesToUtf8Alloc(
    allocator: std.mem.Allocator,
    bytes: []const u8,
) Error![]u8 {
    const units = try allocator.alloc(u16, bytes.len / 2);
    defer allocator.free(units);
    for (units, 0..) |*unit, index| unit.* = readU16(bytes, index * 2);
    return std.unicode.utf16LeToUtf8Alloc(allocator, units) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidWimMetadata,
    };
}

fn hashIsZero(hash: *const [20]u8) bool {
    return std.mem.allEqual(u8, hash, 0);
}

fn align8(value: anytype) Error!usize {
    const usize_value = std.math.cast(usize, value) orelse return error.IntegerOverflow;
    const added = std.math.add(usize, usize_value, 7) catch return error.IntegerOverflow;
    return added & ~@as(usize, 7);
}

fn checkedEnd(start: usize, length: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, length) catch return error.IntegerOverflow;
    if (end > limit) return error.InvalidWimMetadata;
    return end;
}

fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn readU64(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .little);
}

test "WIM metadata assigns unnamed and named streams" {
    const allocator = std.testing.allocator;
    const bytes = try allocator.alloc(u8, 328);
    @memset(bytes, 0);
    std.mem.writeInt(u32, bytes[0..4], 8, .little);

    std.mem.writeInt(u64, bytes[8..16], 104, .little);
    std.mem.writeInt(u32, bytes[16..20], file_attribute_directory, .little);
    std.mem.writeInt(u32, bytes[20..24], std.math.maxInt(u32), .little);
    std.mem.writeInt(u64, bytes[24..32], 120, .little);

    const file_offset: usize = 120;
    std.mem.writeInt(u64, bytes[file_offset..][0..8], 112, .little);
    std.mem.writeInt(u32, bytes[file_offset + 8 ..][0..4], 0x80, .little);
    std.mem.writeInt(u32, bytes[file_offset + 12 ..][0..4], std.math.maxInt(u32), .little);
    std.mem.writeInt(u16, bytes[file_offset + 96 ..][0..2], 2, .little);
    std.mem.writeInt(u16, bytes[file_offset + 100 ..][0..2], 2, .little);
    bytes[file_offset + 102] = 'a';

    const data_stream_offset: usize = 232;
    std.mem.writeInt(u64, bytes[data_stream_offset..][0..8], 40, .little);
    var data_hash: [20]u8 = @splat(0x5a);
    @memcpy(bytes[data_stream_offset + 16 .. data_stream_offset + 36], &data_hash);

    const named_stream_offset: usize = 272;
    std.mem.writeInt(u64, bytes[named_stream_offset..][0..8], 48, .little);
    @memset(bytes[named_stream_offset + 16 .. named_stream_offset + 36], 0xa5);
    std.mem.writeInt(u16, bytes[named_stream_offset + 36 ..][0..2], 2, .little);
    bytes[named_stream_offset + 38] = 'x';

    var image = try ImageMetadata.fromOwnedBytes(allocator, bytes);
    defer image.deinit();
    var directory = try image.readDirectoryAlloc(allocator, image.root, 4);
    defer directory.deinit();
    try std.testing.expectEqual(@as(usize, 1), directory.entries.len);
    const file = directory.entries[0];
    try std.testing.expect(try file.hasNamedStreams());
    try std.testing.expectEqual(data_hash, (try file.defaultDataSha1()).?);

    var reparse = file;
    reparse.attributes |= file_attribute_reparse_point;
    std.mem.writeInt(u16, image.bytes[named_stream_offset + 36 ..][0..2], 0, .little);
    const reparse_data_hash: [20]u8 = @splat(0xa5);
    try std.testing.expectEqual(reparse_data_hash, (try reparse.defaultDataSha1()).?);

    var encrypted = file;
    encrypted.attributes |= file_attribute_encrypted;
    try std.testing.expectError(error.UnsupportedWimFile, encrypted.defaultDataSha1());

    std.mem.writeInt(u16, image.bytes[file_offset + 96 ..][0..2], 3, .little);
    try std.testing.expectError(
        error.InvalidWimMetadata,
        image.readDirectoryAlloc(allocator, image.root, 4),
    );
}

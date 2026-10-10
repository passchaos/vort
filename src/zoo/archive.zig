const std = @import("std");
const core = @import("../core.zig");
const crc16 = @import("../lha/crc16.zig");
const lh_new = @import("../lha/lh_new.zig");
const lzd = @import("lzd.zig");

pub const Error = core.Error || lh_new.Error || lzd.Error || error{
    InvalidZooArchive,
    UnsupportedZooMethod,
    UnsupportedZooStructure,
    DeletedZooEntry,
    ZooEntryNotFound,
};

pub const Method = enum {
    stored,
    lzd,
    lh5,
    unsupported,
};

pub const Name = struct {
    directory: []const u8 = "",
    base: []const u8,

    pub fn len(self: Name) usize {
        return self.directory.len + @intFromBool(self.directory.len != 0) + self.base.len;
    }

    pub fn writeInto(self: Name, output: []u8) Error!usize {
        if (output.len < self.len()) return error.OutputTooSmall;
        var offset: usize = 0;
        for (self.directory) |byte| {
            output[offset] = normalizedSeparator(byte);
            offset += 1;
        }
        if (self.directory.len != 0) {
            output[offset] = '/';
            offset += 1;
        }
        for (self.base) |byte| {
            output[offset] = normalizedSeparator(byte);
            offset += 1;
        }
        return offset;
    }

    pub fn alloc(self: Name, allocator: std.mem.Allocator) ![]u8 {
        const result = try allocator.alloc(u8, self.len());
        errdefer allocator.free(result);
        _ = try self.writeInto(result);
        return result;
    }

    pub fn eql(self: Name, expected: []const u8) bool {
        if (self.len() != expected.len) return false;
        var offset: usize = 0;
        for (self.directory) |byte| {
            if (normalizedSeparator(byte) != expected[offset]) return false;
            offset += 1;
        }
        if (self.directory.len != 0) {
            if (expected[offset] != '/') return false;
            offset += 1;
        }
        for (self.base) |byte| {
            if (normalizedSeparator(byte) != expected[offset]) return false;
            offset += 1;
        }
        return true;
    }
};

pub const Entry = struct {
    name: Name,
    short_name: []const u8,
    method: Method,
    method_id: u8,
    crc16: u16,
    dos_date: u16,
    dos_time: u16,
    required_major_version: u8,
    required_minor_version: u8,
    compressed_size: usize,
    uncompressed_size: usize,
    header_offset: usize,
    header_size: usize,
    data_offset: usize,
    next_offset: usize,
    entry_type: u8,
    deleted: bool,
    structure: u8,
    timezone: u8,
    directory_crc: ?u16,
    comment: []const u8,
    system_id: ?u16,
    attributes: ?u32,
    version_flags: ?u8,
    version_number: ?u16,
};

pub const Archive = struct {
    bytes: []const u8,
    entry_count: usize,
    first_directory_offset: usize,
    major_version: u8,
    minor_version: u8,
    header_type: u8,
    version_data: u8,
    comment: []const u8,

    pub fn iterator(self: Archive) Iterator {
        return .{
            .archive = self,
            .offset = self.first_directory_offset,
            .remaining = self.entry_count,
        };
    }

    pub fn entryAt(self: Archive, wanted: usize) Error!Entry {
        if (wanted >= self.entry_count) return error.RangeOutOfBounds;
        var it = self.iterator();
        var index: usize = 0;
        while (try it.next()) |entry| : (index += 1)
            if (index == wanted) return entry;
        return error.InvalidZooArchive;
    }

    pub fn find(self: Archive, name: []const u8) Error!?Entry {
        var it = self.iterator();
        while (try it.next()) |entry|
            if (!entry.deleted and entry.name.eql(name)) return entry;
        return null;
    }

    pub fn extractInto(self: Archive, entry: Entry, output: []u8) Error!usize {
        const canonical = try parseEntry(self.bytes, entry.header_offset);
        if (!sameEntry(canonical, entry)) return error.InvalidZooArchive;
        if (canonical.deleted) return error.DeletedZooEntry;
        if (canonical.structure != 0) return error.UnsupportedZooStructure;
        if (output.len < canonical.uncompressed_size) return error.OutputTooSmall;
        const target = output[0..canonical.uncompressed_size];
        const compressed_end = try checkedEnd(
            canonical.data_offset,
            canonical.compressed_size,
            self.bytes.len,
        );
        const compressed = self.bytes[canonical.data_offset..compressed_end];
        switch (canonical.method) {
            .stored => {
                if (compressed.len != target.len) return error.SizeMismatch;
                @memcpy(target, compressed);
            },
            .lzd => try lzd.decodeInto(compressed, target),
            .lh5 => try decodeZooLh5(compressed, target),
            .unsupported => return error.UnsupportedZooMethod,
        }
        if (crc16.compute(target) != canonical.crc16) return error.ChecksumMismatch;
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
        if (entry.uncompressed_size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, entry.uncompressed_size);
        errdefer allocator.free(output);
        const written = try self.extractInto(entry, output);
        if (written != output.len) return error.SizeMismatch;
        return output;
    }

    pub fn extractByNameAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        max_output_len: usize,
    ) ![]u8 {
        const entry = (try self.find(name)) orelse return error.ZooEntryNotFound;
        return self.extractAllocLimited(allocator, entry, max_output_len);
    }
};

pub const Iterator = struct {
    archive: Archive,
    offset: usize,
    remaining: usize,

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.remaining == 0) return null;
        const entry = try parseEntry(self.archive.bytes, self.offset);
        self.offset = entry.next_offset;
        self.remaining -= 1;
        return entry;
    }
};

const Header = struct {
    first_directory_offset: usize,
    major_version: u8,
    minor_version: u8,
    header_type: u8,
    version_data: u8,
    comment: []const u8,
};

pub fn parse(bytes: []const u8) Error!Archive {
    const header = try parseHeader(bytes);
    var offset = header.first_directory_offset;
    var entry_count: usize = 0;
    const maximum_entries = bytes.len / 10 + 1;

    while (true) {
        if (entry_count > maximum_entries) return error.InvalidZooArchive;
        const next = try validateDirectory(bytes, offset);
        if (next == 0) break;
        if (next <= offset) return error.InvalidZooArchive;
        _ = try parseEntry(bytes, offset);
        offset = next;
        entry_count += 1;
    }

    return .{
        .bytes = bytes,
        .entry_count = entry_count,
        .first_directory_offset = header.first_directory_offset,
        .major_version = header.major_version,
        .minor_version = header.minor_version,
        .header_type = header.header_type,
        .version_data = header.version_data,
        .comment = header.comment,
    };
}

fn parseHeader(bytes: []const u8) Error!Header {
    if (bytes.len < 34) return error.TruncatedFrame;
    if (readLe32(bytes, 20) != zoo_tag) return error.InvalidMagic;
    const start_u32 = readLe32(bytes, 24);
    if (readLe32(bytes, 28) != 0 -% start_u32) return error.InvalidZooArchive;
    const start = std.math.cast(usize, start_u32) orelse return error.IntegerOverflow;
    if (start < 34) return error.InvalidZooArchive;
    if (start >= bytes.len) return error.TruncatedFrame;

    var header_type: u8 = 0;
    var version_data: u8 = 0;
    var comment: []const u8 = "";
    if (start != 34) {
        if (bytes.len < header_size) return error.TruncatedFrame;
        header_type = bytes[34];
        if (header_type > 1) return error.InvalidZooArchive;
        version_data = bytes[41];
        const comment_offset = std.math.cast(usize, readLe32(bytes, 35)) orelse
            return error.IntegerOverflow;
        const comment_len: usize = readLe16(bytes, 39);
        if (comment_len != 0) {
            const comment_end = try checkedEnd(comment_offset, comment_len, bytes.len);
            comment = bytes[comment_offset..comment_end];
        } else if (comment_offset != 0) {
            return error.InvalidZooArchive;
        }
    }
    return .{
        .first_directory_offset = start,
        .major_version = bytes[32],
        .minor_version = bytes[33],
        .header_type = header_type,
        .version_data = version_data,
        .comment = comment,
    };
}

fn parseEntry(bytes: []const u8, offset: usize) Error!Entry {
    const next = try validateDirectory(bytes, offset);
    if (next == 0) return error.InvalidZooArchive;
    const entry_type = bytes[offset + 4];
    const extent = try directoryExtent(bytes, offset, entry_type);
    const data_offset = std.math.cast(usize, readLe32(bytes, offset + 10)) orelse
        return error.IntegerOverflow;
    const compressed_size = std.math.cast(usize, readLe32(bytes, offset + 24)) orelse
        return error.IntegerOverflow;
    const uncompressed_size = std.math.cast(usize, readLe32(bytes, offset + 20)) orelse
        return error.IntegerOverflow;
    _ = try checkedEnd(data_offset, compressed_size, bytes.len);
    if (data_offset < file_leader.len or
        !std.mem.eql(u8, bytes[data_offset - file_leader.len .. data_offset], file_leader))
    {
        return error.InvalidZooArchive;
    }

    const comment_offset = std.math.cast(usize, readLe32(bytes, offset + 32)) orelse
        return error.IntegerOverflow;
    const comment_len: usize = readLe16(bytes, offset + 36);
    const comment = if (comment_len != 0) blk: {
        const comment_end = try checkedEnd(comment_offset, comment_len, bytes.len);
        break :blk bytes[comment_offset..comment_end];
    } else if (comment_offset != 0) {
        return error.InvalidZooArchive;
    } else "";

    const short_field = bytes[offset + 38 .. offset + 51];
    const short_len = std.mem.indexOfScalar(u8, short_field, 0) orelse short_field.len;
    const short_name = short_field[0..short_len];
    var base = short_name;
    var directory: []const u8 = "";
    var timezone: u8 = no_timezone;
    var directory_crc: ?u16 = null;
    var system_id: ?u16 = null;
    var attributes: ?u32 = null;
    var version_flags: ?u8 = null;
    var version_number: ?u16 = null;

    if (entry_type == 2) {
        timezone = bytes[offset + 53];
        directory_crc = readLe16(bytes, offset + 54);
        const variable_len: usize = readLe16(bytes, offset + 51);
        const variable = bytes[offset + type_2_fixed_size .. extent.end];
        std.debug.assert(variable.len == variable_len);
        if (variable_len >= 1) {
            const long_len: usize = variable[0];
            if (variable_len < 2) {
                if (long_len != 0) return error.InvalidZooArchive;
            } else {
                const directory_len: usize = variable[1];
                const names_len = std.math.add(usize, long_len, directory_len) catch
                    return error.IntegerOverflow;
                const metadata_offset = std.math.add(usize, 2, names_len) catch
                    return error.IntegerOverflow;
                if (metadata_offset > variable_len) return error.InvalidZooArchive;
                const long_name = try storedString(variable[2 .. 2 + long_len]);
                directory = sanitizeDirectory(try storedString(variable[2 + long_len .. metadata_offset]));
                if (long_name.len != 0) base = long_name;
                const metadata = variable[metadata_offset..];
                if (metadata.len >= 2) system_id = std.mem.readInt(u16, metadata[0..2], .little);
                if (metadata.len >= 5) {
                    attributes = @as(u32, metadata[2]) |
                        (@as(u32, metadata[3]) << 8) |
                        (@as(u32, metadata[4]) << 16);
                }
                if (metadata.len >= 8) {
                    version_flags = metadata[5];
                    version_number = std.mem.readInt(u16, metadata[6..8], .little);
                }
            }
        }
    }
    if (!safeComponent(base) or hasSeparator(base)) return error.InvalidZooArchive;

    return .{
        .name = .{ .directory = directory, .base = base },
        .short_name = short_name,
        .method = methodFromId(bytes[offset + 5]),
        .method_id = bytes[offset + 5],
        .crc16 = readLe16(bytes, offset + 18),
        .dos_date = readLe16(bytes, offset + 14),
        .dos_time = readLe16(bytes, offset + 16),
        .required_major_version = bytes[offset + 28],
        .required_minor_version = bytes[offset + 29],
        .compressed_size = compressed_size,
        .uncompressed_size = uncompressed_size,
        .header_offset = offset,
        .header_size = extent.end - offset,
        .data_offset = data_offset,
        .next_offset = next,
        .entry_type = entry_type,
        .deleted = bytes[offset + 30] != 0,
        .structure = bytes[offset + 31],
        .timezone = timezone,
        .directory_crc = directory_crc,
        .comment = comment,
        .system_id = system_id,
        .attributes = attributes,
        .version_flags = version_flags,
        .version_number = version_number,
    };
}

const DirectoryExtent = struct { end: usize };

fn validateDirectory(bytes: []const u8, offset: usize) Error!usize {
    _ = try checkedEnd(offset, 10, bytes.len);
    if (readLe32(bytes, offset) != zoo_tag) return error.InvalidMagic;
    const entry_type = bytes[offset + 4];
    const extent = try directoryExtent(bytes, offset, entry_type);
    if (entry_type == 2) {
        const expected = readLe16(bytes, offset + 54);
        if (directoryCrc(bytes[offset..extent.end]) != expected)
            return error.ChecksumMismatch;
    }
    const next = std.math.cast(usize, readLe32(bytes, offset + 6)) orelse
        return error.IntegerOverflow;
    if (next == 0) {
        if (bytes[offset + 5] != 0 or readLe32(bytes, offset + 10) != 0 or
            readLe32(bytes, offset + 20) != 0 or readLe32(bytes, offset + 24) != 0)
        {
            return error.InvalidZooArchive;
        }
    }
    return next;
}

fn directoryExtent(bytes: []const u8, offset: usize, entry_type: u8) Error!DirectoryExtent {
    return switch (entry_type) {
        1 => .{ .end = try checkedEnd(offset, type_1_size, bytes.len) },
        2 => blk: {
            _ = try checkedEnd(offset, type_2_fixed_size, bytes.len);
            const variable_len: usize = readLe16(bytes, offset + 51);
            break :blk .{ .end = try checkedEnd(
                offset,
                try checkedAdd(type_2_fixed_size, variable_len),
                bytes.len,
            ) };
        },
        else => error.InvalidZooArchive,
    };
}

fn directoryCrc(directory: []const u8) u16 {
    std.debug.assert(directory.len >= type_2_fixed_size);
    var value = crc16.update(0, directory[0..54]);
    value = crc16.update(value, &.{ 0, 0 });
    return crc16.update(value, directory[56..]);
}

fn decodeZooLh5(input: []const u8, output: []u8) Error!void {
    lh_new.decodeInto(input, output, .lh5) catch |err| switch (err) {
        error.TrailingData => {
            if (input.len < 2 or input[input.len - 2] != 0 or input[input.len - 1] != 0)
                return err;
            try lh_new.decodeInto(input[0 .. input.len - 2], output, .lh5);
        },
        else => return err,
    };
}

fn methodFromId(id: u8) Method {
    return switch (id) {
        0 => .stored,
        1 => .lzd,
        2 => .lh5,
        else => .unsupported,
    };
}

fn storedString(field: []const u8) Error![]const u8 {
    if (field.len == 0) return "";
    const content = if (field[field.len - 1] == 0) field[0 .. field.len - 1] else field;
    if (std.mem.indexOfScalar(u8, content, 0) != null) return error.InvalidZooArchive;
    return content;
}

fn sanitizeDirectory(path: []const u8) []const u8 {
    if (path.len == 0 or hasSeparatorAt(path, 0) or hasSeparatorAt(path, path.len - 1))
        return "";
    var component_start: usize = 0;
    for (path, 0..) |byte, index| {
        if (byte != '/' and byte != '\\') continue;
        if (!safeComponent(path[component_start..index])) return "";
        component_start = index + 1;
    }
    if (!safeComponent(path[component_start..])) return "";
    return path;
}

fn safeComponent(component: []const u8) bool {
    return component.len != 0 and !std.mem.eql(u8, component, ".") and
        !std.mem.eql(u8, component, "..");
}

fn hasSeparatorAt(path: []const u8, index: usize) bool {
    return path[index] == '/' or path[index] == '\\';
}

fn sameEntry(a: Entry, b: Entry) bool {
    return a.header_offset == b.header_offset and
        a.header_size == b.header_size and
        a.data_offset == b.data_offset and
        a.next_offset == b.next_offset and
        a.compressed_size == b.compressed_size and
        a.uncompressed_size == b.uncompressed_size and
        a.crc16 == b.crc16 and
        a.dos_date == b.dos_date and
        a.dos_time == b.dos_time and
        a.required_major_version == b.required_major_version and
        a.required_minor_version == b.required_minor_version and
        a.method_id == b.method_id and
        a.entry_type == b.entry_type and
        a.deleted == b.deleted and
        a.structure == b.structure and
        std.mem.eql(u8, a.comment, b.comment) and
        eqlName(a.name, b.name);
}

fn eqlName(a: Name, b: Name) bool {
    return std.mem.eql(u8, a.directory, b.directory) and std.mem.eql(u8, a.base, b.base);
}

fn normalizedSeparator(byte: u8) u8 {
    return if (byte == '\\') '/' else byte;
}

fn hasSeparator(bytes: []const u8) bool {
    return std.mem.indexOfAny(u8, bytes, "/\\") != null;
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

pub const zoo_tag: u32 = 0xfdc4_a7dc;
pub const header_size: usize = 42;
pub const type_1_size: usize = 51;
pub const type_2_fixed_size: usize = 56;
pub const file_leader = "@)#(\x00";
pub const no_timezone: u8 = 127;

test "ZOO directory CRC uses a zeroed stored CRC field" {
    var directory: [type_2_fixed_size]u8 = @splat(0);
    std.mem.writeInt(u32, directory[0..4], zoo_tag, .little);
    directory[4] = 2;
    const checksum = directoryCrc(&directory);
    std.mem.writeInt(u16, directory[54..56], checksum, .little);
    try std.testing.expectEqual(checksum, directoryCrc(&directory));
}

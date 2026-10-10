const std = @import("std");
const core = @import("../core.zig");
const crc16 = @import("crc16.zig");
const lh_new = @import("lh_new.zig");

pub const Error = core.Error || lh_new.Error || error{
    InvalidLhaArchive,
    UnsupportedLhaHeaderLevel,
    UnsupportedLhaMethod,
    LhaEntryNotFound,
};

pub const Method = enum {
    stored,
    lh5,
    lh6,
    lh7,
    directory,
    unsupported,
};

pub const Name = struct {
    path: []const u8 = "",
    base: []const u8,
    insert_separator: bool = false,

    pub fn len(self: Name) usize {
        return self.path.len + @intFromBool(self.insert_separator) + self.base.len;
    }

    pub fn writeInto(self: Name, output: []u8) Error!usize {
        if (output.len < self.len()) return error.OutputTooSmall;
        var offset: usize = 0;
        for (self.path) |byte| {
            output[offset] = normalizedSeparator(byte);
            offset += 1;
        }
        if (self.insert_separator) {
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
        for (self.path) |byte| {
            if (normalizedSeparator(byte) != expected[offset]) return false;
            offset += 1;
        }
        if (self.insert_separator) {
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
    method: Method,
    method_id: [5]u8,
    crc16: u16,
    compressed_size: usize,
    uncompressed_size: usize,
    header_offset: usize,
    data_offset: usize,
    header_level: u8,
    os_type: u8,

    pub fn isDirectory(self: Entry) bool {
        return self.method == .directory;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    entry_count: usize,

    pub fn iterator(self: Archive) Iterator {
        return .{ .archive = self, .remaining = self.entry_count };
    }

    pub fn entryAt(self: Archive, wanted: usize) Error!Entry {
        if (wanted >= self.entry_count) return error.RangeOutOfBounds;
        var it = self.iterator();
        var index: usize = 0;
        while (try it.next()) |entry| : (index += 1)
            if (index == wanted) return entry;
        return error.InvalidLhaArchive;
    }

    pub fn find(self: Archive, name: []const u8) Error!?Entry {
        var it = self.iterator();
        while (try it.next()) |entry|
            if (entry.name.eql(name)) return entry;
        return null;
    }

    pub fn extractInto(self: Archive, entry: Entry, output: []u8) Error!usize {
        const parsed = try parseEntry(self.bytes, entry.header_offset);
        const canonical = parsed.entry;
        if (!sameEntry(canonical, entry)) return error.InvalidLhaArchive;
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
            .lh5 => try lh_new.decodeInto(compressed, target, .lh5),
            .lh6 => try lh_new.decodeInto(compressed, target, .lh6),
            .lh7 => try lh_new.decodeInto(compressed, target, .lh7),
            .directory => if (target.len != 0 or compressed.len != 0)
                return error.SizeMismatch,
            .unsupported => return error.UnsupportedLhaMethod,
        }
        if (!canonical.isDirectory() and crc16.compute(target) != canonical.crc16)
            return error.ChecksumMismatch;
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
        const entry = (try self.find(name)) orelse return error.LhaEntryNotFound;
        return self.extractAllocLimited(allocator, entry, max_output_len);
    }
};

pub const Iterator = struct {
    archive: Archive,
    offset: usize = 0,
    remaining: usize = 0,

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.remaining == 0) return null;
        if (self.offset >= self.archive.bytes.len or self.archive.bytes[self.offset] == 0) {
            self.remaining = 0;
            return null;
        }
        const parsed = try parseEntry(self.archive.bytes, self.offset);
        self.offset = parsed.next_offset;
        self.remaining -= 1;
        return parsed.entry;
    }
};

pub fn parse(bytes: []const u8) Error!Archive {
    var offset: usize = 0;
    var entry_count: usize = 0;
    while (offset < bytes.len) {
        if (bytes[offset] == 0) {
            if (offset + 1 != bytes.len) return error.TrailingData;
            offset += 1;
            break;
        }
        const parsed = try parseEntry(bytes, offset);
        offset = parsed.next_offset;
        entry_count += 1;
    }
    if (offset != bytes.len) return error.TrailingData;
    return .{ .bytes = bytes, .entry_count = entry_count };
}

const ParsedEntry = struct { entry: Entry, next_offset: usize };

const ExtensionState = struct {
    path: []const u8 = "",
    name: ?[]const u8 = null,
    compressed_size_64: ?u64 = null,
    uncompressed_size_64: ?u64 = null,
    common_crc: ?u16 = null,
    common_crc_offset: ?usize = null,
};

fn parseEntry(bytes: []const u8, offset: usize) Error!ParsedEntry {
    _ = try checkedEnd(offset, 22, bytes.len);
    const level = bytes[offset + 20];
    var method_id: [5]u8 = undefined;
    @memcpy(&method_id, bytes[offset + 2 .. offset + 7]);
    var compressed_size: u64 = readLe32(bytes, offset + 7);
    var uncompressed_size: u64 = readLe32(bytes, offset + 11);
    var data_offset: usize = undefined;
    var crc: u16 = undefined;
    var os_type: u8 = 0;
    var name = Name{ .base = "" };
    var extensions = ExtensionState{};

    switch (level) {
        0, 1 => {
            const header_size = bytes[offset];
            const total_size = @as(usize, header_size) + 2;
            const base_end = try checkedEnd(offset, total_size, bytes.len);
            const min_size: usize = if (level == 0) 22 else 25;
            if (header_size < min_size) return error.InvalidLhaArchive;
            var sum: u8 = 0;
            for (bytes[offset + 2 .. base_end]) |byte| sum +%= byte;
            if (sum != bytes[offset + 1]) return error.ChecksumMismatch;
            const name_len = bytes[offset + 21];
            if (@as(usize, name_len) + min_size > header_size)
                return error.InvalidLhaArchive;
            const name_start = offset + 22;
            const name_end = name_start + name_len;
            const base_name = bytes[name_start..name_end];
            try validateNamePart(base_name);
            crc = readLe16(bytes, name_end);
            name = .{ .base = base_name };

            if (level == 0) {
                data_offset = base_end;
            } else {
                os_type = bytes[name_end + 2];
                var next_size = readLe16(bytes, base_end - 2);
                var cursor = base_end;
                var extension_bytes: usize = 0;
                while (next_size != 0) {
                    if (next_size < 3) return error.InvalidLhaArchive;
                    const extension_end = try checkedEnd(cursor, next_size, bytes.len);
                    try parseExtension(
                        bytes[cursor],
                        bytes[cursor + 1 .. extension_end - 2],
                        cursor + 1,
                        &extensions,
                    );
                    next_size = readLe16(bytes, extension_end - 2);
                    extension_bytes = std.math.add(usize, extension_bytes, extension_end - cursor) catch
                        return error.IntegerOverflow;
                    cursor = extension_end;
                }
                data_offset = cursor;
                if (extensions.compressed_size_64 == null) {
                    if (compressed_size < extension_bytes) return error.InvalidLhaArchive;
                    compressed_size -= extension_bytes;
                }
            }
        },
        2 => {
            const header_size = readLe16(bytes, offset);
            if (header_size < 26) return error.InvalidLhaArchive;
            const header_end = try checkedEnd(offset, header_size, bytes.len);
            crc = readLe16(bytes, offset + 21);
            os_type = bytes[offset + 23];
            var cursor = offset + 24;
            var terminated = false;
            while (cursor < header_end) {
                if (header_end - cursor < 2) return error.TruncatedFrame;
                const extension_size = readLe16(bytes, cursor);
                if (extension_size == 0) {
                    cursor += 2;
                    terminated = true;
                    break;
                }
                if (extension_size < 3) return error.InvalidLhaArchive;
                const extension_end = try checkedEnd(cursor, extension_size, header_end);
                try parseExtension(
                    bytes[cursor + 2],
                    bytes[cursor + 3 .. extension_end],
                    cursor + 3,
                    &extensions,
                );
                cursor = extension_end;
            }
            if (!terminated or cursor != header_end) return error.InvalidLhaArchive;
            data_offset = header_end;
        },
        else => return error.UnsupportedLhaHeaderLevel,
    }

    if (extensions.compressed_size_64) |size| compressed_size = size;
    if (extensions.uncompressed_size_64) |size| uncompressed_size = size;
    if (extensions.name) |base| name.base = base;
    if (extensions.path.len != 0) {
        name.path = extensions.path;
        const last = extensions.path[extensions.path.len - 1];
        name.insert_separator = last != 0xff and last != '/' and last != '\\';
    }
    if (name.base.len == 0 and methodFromId(method_id) != .directory)
        return error.InvalidLhaArchive;

    if (extensions.common_crc) |expected| {
        const zero_offset = extensions.common_crc_offset.?;
        var actual = crc16.update(0, bytes[offset..zero_offset]);
        actual = crc16.update(actual, &.{ 0, 0 });
        actual = crc16.update(actual, bytes[zero_offset + 2 .. data_offset]);
        if (actual != expected) return error.ChecksumMismatch;
    }

    const compressed_len = std.math.cast(usize, compressed_size) orelse
        return error.IntegerOverflow;
    const uncompressed_len = std.math.cast(usize, uncompressed_size) orelse
        return error.IntegerOverflow;
    const next_offset = try checkedEnd(data_offset, compressed_len, bytes.len);
    return .{
        .entry = .{
            .name = name,
            .method = methodFromId(method_id),
            .method_id = method_id,
            .crc16 = crc,
            .compressed_size = compressed_len,
            .uncompressed_size = uncompressed_len,
            .header_offset = offset,
            .data_offset = data_offset,
            .header_level = level,
            .os_type = os_type,
        },
        .next_offset = next_offset,
    };
}

fn parseExtension(
    extension_type: u8,
    data: []const u8,
    data_offset: usize,
    state: *ExtensionState,
) Error!void {
    switch (extension_type) {
        0x00 => {
            if (data.len < 2 or state.common_crc != null) return error.InvalidLhaArchive;
            state.common_crc = std.mem.readInt(u16, data[0..2], .little);
            state.common_crc_offset = data_offset;
        },
        0x01 => {
            try validateNamePart(data);
            state.name = data;
        },
        0x02 => {
            try validateNamePart(data);
            state.path = data;
        },
        0x42 => {
            if (data.len < 16 or state.compressed_size_64 != null)
                return error.InvalidLhaArchive;
            state.compressed_size_64 = std.mem.readInt(u64, data[0..8], .little);
            state.uncompressed_size_64 = std.mem.readInt(u64, data[8..16], .little);
        },
        else => {},
    }
}

fn validateNamePart(bytes: []const u8) Error!void {
    if (std.mem.indexOfScalar(u8, bytes, 0) != null) return error.InvalidLhaArchive;
}

fn normalizedSeparator(byte: u8) u8 {
    return if (byte == 0xff or byte == '\\') '/' else byte;
}

fn methodFromId(id: [5]u8) Method {
    if (std.mem.eql(u8, &id, "-lh0-")) return .stored;
    if (std.mem.eql(u8, &id, "-lh5-")) return .lh5;
    if (std.mem.eql(u8, &id, "-lh6-")) return .lh6;
    if (std.mem.eql(u8, &id, "-lh7-")) return .lh7;
    if (std.mem.eql(u8, &id, "-lhd-")) return .directory;
    return .unsupported;
}

fn sameEntry(a: Entry, b: Entry) bool {
    return a.header_offset == b.header_offset and
        a.data_offset == b.data_offset and
        a.compressed_size == b.compressed_size and
        a.uncompressed_size == b.uncompressed_size and
        a.crc16 == b.crc16 and
        a.method == b.method and
        a.header_level == b.header_level and
        a.os_type == b.os_type and
        std.mem.eql(u8, &a.method_id, &b.method_id) and
        eqlName(a.name, b.name);
}

fn eqlName(a: Name, b: Name) bool {
    if (a.len() != b.len()) return false;
    for (0..a.len()) |index|
        if (nameByte(a, index) != nameByte(b, index)) return false;
    return true;
}

fn nameByte(name: Name, index: usize) u8 {
    if (index < name.path.len) return normalizedSeparator(name.path[index]);
    var relative = index - name.path.len;
    if (name.insert_separator) {
        if (relative == 0) return '/';
        relative -= 1;
    }
    return normalizedSeparator(name.base[relative]);
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

test "LHA Name composes level-two path components" {
    const name = Name{ .path = "folder\xffnested\xff", .base = "file.txt" };
    var output: ["folder/nested/file.txt".len]u8 = undefined;
    try std.testing.expectEqual(output.len, try name.writeInto(&output));
    try std.testing.expectEqualSlices(u8, "folder/nested/file.txt", &output);
    try std.testing.expect(name.eql("folder/nested/file.txt"));
}

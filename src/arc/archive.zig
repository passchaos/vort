const std = @import("std");
const core = @import("../core.zig");
const crushed = @import("crushed.zig");
const distilled = @import("distilled.zig");
const lzw = @import("lzw.zig");
const old_crunch = @import("old_crunch.zig");
const rle = @import("rle.zig");
const squeeze = @import("squeeze.zig");

pub const Error = core.Error || crushed.Error || distilled.Error || lzw.Error || old_crunch.Error || rle.Error || squeeze.Error || error{
    InvalidArcArchive,
    UnsupportedArcMethod,
    ArcEntryNotFound,
};

pub const Method = enum {
    stored_1,
    stored_2,
    packed_rle,
    squeezed,
    crunched_5,
    crunched_6,
    crunched_7,
    crunched_8,
    squashed,
    crushed,
    distilled,
    unsupported,
};

pub const Entry = struct {
    name: []const u8,
    method: Method,
    method_id: u8,
    crc16: u16,
    compressed_size: usize,
    uncompressed_size: usize,
    header_offset: usize,
    data_offset: usize,
};

pub const Archive = struct {
    bytes: []const u8,
    entry_count: usize,
    prefix_size: usize,
    trailer_size: usize,

    pub fn iterator(self: Archive) Iterator {
        return .{
            .archive = self,
            .offset = self.prefix_size,
            .remaining = self.entry_count,
        };
    }

    pub fn entryAt(self: Archive, wanted: usize) Error!Entry {
        if (wanted >= self.entry_count) return error.RangeOutOfBounds;
        var it = self.iterator();
        var index: usize = 0;
        while (try it.next()) |entry| : (index += 1)
            if (index == wanted) return entry;
        return error.InvalidArcArchive;
    }

    pub fn find(self: Archive, name: []const u8) Error!?Entry {
        var it = self.iterator();
        while (try it.next()) |entry|
            if (std.mem.eql(u8, entry.name, name)) return entry;
        return null;
    }

    pub fn extractInto(self: Archive, entry: Entry, output: []u8) Error!usize {
        const parsed = try parseEntry(self.bytes, entry.header_offset);
        const canonical = parsed.entry;
        if (!sameEntry(canonical, entry)) return error.InvalidArcArchive;
        if (output.len < canonical.uncompressed_size) return error.OutputTooSmall;
        const target = output[0..canonical.uncompressed_size];
        const compressed_end = try checkedEnd(
            canonical.data_offset,
            canonical.compressed_size,
            self.bytes.len,
        );
        const compressed = self.bytes[canonical.data_offset..compressed_end];
        switch (canonical.method) {
            .stored_1, .stored_2 => {
                if (compressed.len != target.len) return error.SizeMismatch;
                @memcpy(target, compressed);
            },
            .packed_rle => try rle.decodeInto(compressed, target),
            .squeezed => try squeeze.decodeInto(compressed, target),
            .crunched_5 => try old_crunch.decodeInto(compressed, target, .method_5),
            .crunched_6 => try old_crunch.decodeInto(compressed, target, .method_6),
            .crunched_7 => try old_crunch.decodeInto(compressed, target, .method_7),
            .crunched_8 => try lzw.decodeInto(compressed, target, .crunched),
            .squashed => try lzw.decodeInto(compressed, target, .squashed),
            .crushed => try crushed.decodeInto(compressed, target),
            .distilled => try distilled.decodeInto(compressed, target),
            .unsupported => return error.UnsupportedArcMethod,
        }
        if (crc16(target) != canonical.crc16) return error.ChecksumMismatch;
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
        const entry = (try self.find(name)) orelse return error.ArcEntryNotFound;
        return self.extractAllocLimited(allocator, entry, max_output_len);
    }
};

pub const Iterator = struct {
    archive: Archive,
    offset: usize,
    remaining: usize,

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.remaining == 0) return null;
        const parsed = try parseEntry(self.archive.bytes, self.offset);
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
        if (bytes[candidate] != 0x1a) continue;
        attempts += 1;
        if (attempts > 256) return error.InvalidArcArchive;
        const scanned = scanArchive(bytes, candidate) catch |err| {
            if (first_error == null) first_error = err;
            continue;
        };
        if (scanned.entry_count == 0 and candidate != 0) continue;
        return .{
            .bytes = bytes,
            .entry_count = scanned.entry_count,
            .prefix_size = candidate,
            .trailer_size = bytes.len - scanned.archive_end,
        };
    }
    if (first_error) |err| return err;
    return error.InvalidMagic;
}

const ScanResult = struct { entry_count: usize, archive_end: usize };

fn scanArchive(bytes: []const u8, start: usize) Error!ScanResult {
    var offset = start;
    var count: usize = 0;
    while (true) {
        _ = try checkedEnd(offset, 2, bytes.len);
        if (bytes[offset] != 0x1a) return error.InvalidMagic;
        if (bytes[offset + 1] == 0) {
            return .{ .entry_count = count, .archive_end = offset + 2 };
        }
        const parsed = try parseEntry(bytes, offset);
        offset = parsed.next_offset;
        count += 1;
    }
}

const ParsedEntry = struct { entry: Entry, next_offset: usize };

fn parseEntry(bytes: []const u8, offset: usize) Error!ParsedEntry {
    _ = try checkedEnd(offset, 25, bytes.len);
    if (bytes[offset] != 0x1a or bytes[offset + 1] == 0) return error.InvalidArcArchive;
    const method_id = bytes[offset + 1];
    const name_field = bytes[offset + 2 .. offset + 15];
    const name_len = std.mem.indexOfScalar(u8, name_field, 0) orelse name_field.len;
    if (name_len == 0) return error.InvalidArcArchive;
    const compressed_size: usize = readLe32(bytes, offset + 15);
    const header_size: usize = if (method_id == 1) 25 else 29;
    _ = try checkedEnd(offset, header_size, bytes.len);
    const uncompressed_size: usize = if (method_id == 1)
        compressed_size
    else
        readLe32(bytes, offset + 25);
    const data_offset = offset + header_size;
    const next_offset = try checkedEnd(data_offset, compressed_size, bytes.len);
    return .{
        .entry = .{
            .name = name_field[0..name_len],
            .method = methodFromId(method_id),
            .method_id = method_id,
            .crc16 = readLe16(bytes, offset + 23),
            .compressed_size = compressed_size,
            .uncompressed_size = uncompressed_size,
            .header_offset = offset,
            .data_offset = data_offset,
        },
        .next_offset = next_offset,
    };
}

fn methodFromId(id: u8) Method {
    return switch (id) {
        1 => .stored_1,
        2 => .stored_2,
        3 => .packed_rle,
        4 => .squeezed,
        5 => .crunched_5,
        6 => .crunched_6,
        7 => .crunched_7,
        8 => .crunched_8,
        9 => .squashed,
        10 => .crushed,
        11 => .distilled,
        else => .unsupported,
    };
}

fn sameEntry(a: Entry, b: Entry) bool {
    return a.header_offset == b.header_offset and
        a.data_offset == b.data_offset and
        a.compressed_size == b.compressed_size and
        a.uncompressed_size == b.uncompressed_size and
        a.crc16 == b.crc16 and
        a.method_id == b.method_id and
        std.mem.eql(u8, a.name, b.name);
}

pub fn crc16(bytes: []const u8) u16 {
    var crc: u16 = 0;
    for (bytes) |byte| {
        crc ^= byte;
        for (0..8) |_| crc = if (crc & 1 != 0) (crc >> 1) ^ 0xa001 else crc >> 1;
    }
    return crc;
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

test "ARC CRC-16 matches the standard check vector" {
    try std.testing.expectEqual(@as(u16, 0xbb3d), crc16("123456789"));
}

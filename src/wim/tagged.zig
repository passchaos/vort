const std = @import("std");
const core = @import("../core.zig");

pub const object_id_tag: u32 = 0x0000_0001;
pub const xattrs_tag: u32 = 0x0000_0002;
pub const wimlib_unix_data_tag: u32 = 0x337d_d873;
pub const wimlib_linux_xattrs_tag: u32 = 0x337d_d874;

pub const ReadError = core.Error || error{InvalidWimMetadata};
pub const EncodeError = core.Error || std.mem.Allocator.Error || error{InvalidWimEntry};

pub const Item = struct {
    tag: u32,
    data: []const u8,
};

pub const Iterator = struct {
    bytes: []const u8,
    offset: usize,
    end: usize,

    pub fn init(bytes: []const u8) Iterator {
        return .{ .bytes = bytes, .offset = 0, .end = bytes.len };
    }

    pub fn next(self: *Iterator) ReadError!?Item {
        if (self.offset == self.end) return null;
        const parsed = try parseItem(self.bytes, self.offset, self.end);
        self.offset = parsed.next_offset;
        return parsed.item;
    }
};

pub const UnixMetadata = struct {
    uid: u32,
    gid: u32,
    mode: u32,
    rdev: u32,
};

pub const ObjectId = struct {
    object_id: [16]u8,
    birth_volume_id: [16]u8 = @splat(0),
    birth_object_id: [16]u8 = @splat(0),
    domain_id: [16]u8 = @splat(0),
};

pub const Xattr = struct {
    name: []const u8,
    value: []const u8,
    need_ea: bool = false,
};

pub const XattrIterator = struct {
    bytes: []const u8,
    offset: usize = 0,

    pub fn next(self: *XattrIterator) ReadError!?Xattr {
        if (self.offset == self.bytes.len) return null;
        if (self.bytes.len - self.offset < 4) return error.InvalidWimMetadata;
        const value_len: usize = readU16(self.bytes, self.offset);
        const name_len: usize = self.bytes[self.offset + 2];
        const flags = self.bytes[self.offset + 3];
        if (name_len == 0 or (flags != 0 and flags != 0x80))
            return error.InvalidWimMetadata;
        const name_offset = self.offset + 4;
        const terminator = try checkedEnd(name_offset, name_len, self.bytes.len);
        const value_offset = try checkedEnd(terminator, 1, self.bytes.len);
        if (self.bytes[terminator] != 0 or
            std.mem.indexOfScalar(u8, self.bytes[name_offset..terminator], 0) != null)
            return error.InvalidWimMetadata;
        const end = try checkedEnd(value_offset, value_len, self.bytes.len);
        const entry: Xattr = .{
            .name = self.bytes[name_offset..terminator],
            .value = self.bytes[value_offset..end],
            .need_ea = flags == 0x80,
        };
        self.offset = end;
        return entry;
    }
};

pub fn validateItems(bytes: []const u8) ReadError!void {
    var items = Iterator.init(bytes);
    while (try items.next()) |_| {}
}

pub fn encodeUnixMetadata(value: UnixMetadata) [16]u8 {
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u32, bytes[0..4], value.uid, .little);
    std.mem.writeInt(u32, bytes[4..8], value.gid, .little);
    std.mem.writeInt(u32, bytes[8..12], value.mode, .little);
    std.mem.writeInt(u32, bytes[12..16], value.rdev, .little);
    return bytes;
}

pub fn decodeUnixMetadata(bytes: []const u8) ReadError!UnixMetadata {
    if (bytes.len < 16) return error.InvalidWimMetadata;
    return .{
        .uid = readU32(bytes, 0),
        .gid = readU32(bytes, 4),
        .mode = readU32(bytes, 8),
        .rdev = readU32(bytes, 12),
    };
}

pub fn encodeObjectId(value: ObjectId) [64]u8 {
    return value.object_id ++ value.birth_volume_id ++
        value.birth_object_id ++ value.domain_id;
}

pub fn decodeObjectId(bytes: []const u8) ReadError!ObjectId {
    if (bytes.len < 16) return error.InvalidWimMetadata;
    var normalized: [64]u8 = @splat(0);
    const copy_len = @min(bytes.len, normalized.len);
    @memcpy(normalized[0..copy_len], bytes[0..copy_len]);
    return .{
        .object_id = normalized[0..16].*,
        .birth_volume_id = normalized[16..32].*,
        .birth_object_id = normalized[32..48].*,
        .domain_id = normalized[48..64].*,
    };
}

pub fn encodeXattrsAlloc(
    allocator: std.mem.Allocator,
    entries: []const Xattr,
) EncodeError![]u8 {
    if (entries.len == 0) return error.InvalidWimEntry;
    var total: usize = 0;
    for (entries) |entry| {
        try validateXattrForEncode(entry);
        const length = std.math.add(
            usize,
            5,
            std.math.add(usize, entry.name.len, entry.value.len) catch
                return error.IntegerOverflow,
        ) catch return error.IntegerOverflow;
        total = std.math.add(usize, total, length) catch
            return error.IntegerOverflow;
    }
    for (entries, 0..) |entry, index|
        for (entries[0..index]) |prior|
            if (std.mem.eql(u8, entry.name, prior.name))
                return error.InvalidWimEntry;
    if (total > std.math.maxInt(u32)) return error.InvalidWimEntry;
    const output = try allocator.alloc(u8, total);
    errdefer allocator.free(output);
    var offset: usize = 0;
    for (entries) |entry| {
        std.mem.writeInt(u16, output[offset..][0..2], @intCast(entry.value.len), .little);
        output[offset + 2] = @intCast(entry.name.len);
        output[offset + 3] = if (entry.need_ea) 0x80 else 0;
        @memcpy(output[offset + 4 ..][0..entry.name.len], entry.name);
        offset += 4 + entry.name.len;
        output[offset] = 0;
        offset += 1;
        @memcpy(output[offset..][0..entry.value.len], entry.value);
        offset += entry.value.len;
    }
    std.debug.assert(offset == output.len);
    return output;
}

pub fn validateXattrs(bytes: []const u8) ReadError!void {
    if (bytes.len == 0) return error.InvalidWimMetadata;
    var iterator = XattrIterator{ .bytes = bytes };
    var count: usize = 0;
    while (try iterator.next()) |_| count += 1;
    if (count == 0) return error.InvalidWimMetadata;
    var outer = XattrIterator{ .bytes = bytes };
    var index: usize = 0;
    while (try outer.next()) |entry| : (index += 1) {
        var inner = XattrIterator{ .bytes = bytes };
        for (0..index) |_| {
            const prior = (try inner.next()) orelse
                return error.InvalidWimMetadata;
            if (std.mem.eql(u8, entry.name, prior.name))
                return error.InvalidWimMetadata;
        }
    }
}

fn validateXattrForEncode(entry: Xattr) EncodeError!void {
    if (entry.name.len == 0 or entry.name.len > std.math.maxInt(u8) or
        entry.value.len > std.math.maxInt(u16) or
        std.mem.indexOfScalar(u8, entry.name, 0) != null)
        return error.InvalidWimEntry;
}

const ParsedItem = struct {
    item: Item,
    next_offset: usize,
};

fn parseItem(bytes: []const u8, offset: usize, end: usize) ReadError!ParsedItem {
    if (offset & 7 != 0 or end > bytes.len or offset > end)
        return error.InvalidWimMetadata;
    const data_offset = try checkedEnd(offset, 8, end);
    const data_length: usize = readU32(bytes, offset + 4);
    const data_end = try checkedEnd(data_offset, data_length, end);
    const next_offset = try checkedEnd(data_offset, try align8(data_length), end);
    return .{
        .item = .{
            .tag = readU32(bytes, offset),
            .data = bytes[data_offset..data_end],
        },
        .next_offset = next_offset,
    };
}

fn align8(value: usize) ReadError!usize {
    const with_padding = std.math.add(usize, value, 7) catch
        return error.IntegerOverflow;
    return with_padding & ~@as(usize, 7);
}

fn checkedEnd(start: usize, length: usize, limit: usize) ReadError!usize {
    const end = std.math.add(usize, start, length) catch
        return error.IntegerOverflow;
    if (end > limit) return error.InvalidWimMetadata;
    return end;
}

fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

test "WIM tagged helpers encode typed metadata" {
    const unix: UnixMetadata = .{ .uid = 1, .gid = 2, .mode = 3, .rdev = 4 };
    const encoded_unix = encodeUnixMetadata(unix);
    try std.testing.expectEqual(unix, try decodeUnixMetadata(&encoded_unix));

    const object: ObjectId = .{
        .object_id = @splat(1),
        .birth_volume_id = @splat(2),
        .birth_object_id = @splat(3),
        .domain_id = @splat(4),
    };
    const encoded_object = encodeObjectId(object);
    try std.testing.expectEqual(object, try decodeObjectId(&encoded_object));
    const partial = try decodeObjectId(encoded_object[0..20]);
    try std.testing.expectEqualSlices(u8, &.{ 2, 2, 2, 2 }, partial.birth_volume_id[0..4]);
    try std.testing.expect(std.mem.allEqual(u8, partial.birth_volume_id[4..], 0));

    const encoded = try encodeXattrsAlloc(std.testing.allocator, &.{
        .{ .name = "user.one", .value = "1" },
        .{ .name = "user.empty", .value = &.{}, .need_ea = true },
    });
    defer std.testing.allocator.free(encoded);
    try validateXattrs(encoded);
    var iterator = XattrIterator{ .bytes = encoded };
    try std.testing.expectEqualStrings("user.one", (try iterator.next()).?.name);
    const second = (try iterator.next()).?;
    try std.testing.expectEqualStrings("user.empty", second.name);
    try std.testing.expect(second.need_ea);
    try std.testing.expect((try iterator.next()) == null);
    try std.testing.expectError(
        error.InvalidWimEntry,
        encodeXattrsAlloc(std.testing.allocator, &.{
            .{ .name = "user.same", .value = "a" },
            .{ .name = "user.same", .value = "b" },
        }),
    );
}

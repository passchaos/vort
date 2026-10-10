const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidRpmHeader,
    InvalidRpmTagType,
};

pub const ValueType = enum(u32) {
    null = 0,
    char = 1,
    int8 = 2,
    int16 = 3,
    int32 = 4,
    int64 = 5,
    string = 6,
    binary = 7,
    string_array = 8,
    i18n_string = 9,
};

pub const Index = struct {
    tag: u32,
    value_type: ValueType,
    offset: u32,
    count: u32,
};

pub const Header = struct {
    bytes: []const u8,
    offset: usize,
    index_count: usize,
    index_offset: usize,
    data_offset: usize,
    data_size: usize,
    next_offset: usize,

    pub fn iterator(self: Header) Iterator {
        return .{ .header = self };
    }

    pub fn find(self: Header, tag: u32) Error!?Index {
        var iterator_value = self.iterator();
        while (try iterator_value.next()) |index|
            if (index.tag == tag) return index;
        return null;
    }

    pub fn string(self: Header, tag: u32) Error!?[]const u8 {
        const index = (try self.find(tag)) orelse return null;
        if (index.value_type != .string and index.value_type != .i18n_string)
            return error.InvalidRpmTagType;
        const start = try self.valueStart(index);
        const tail = self.bytes[start..self.next_offset];
        const end = std.mem.indexOfScalar(u8, tail, 0) orelse return error.InvalidRpmHeader;
        return tail[0..end];
    }

    pub fn int32(self: Header, tag: u32) Error!?u32 {
        const index = (try self.find(tag)) orelse return null;
        if (index.value_type != .int32 or index.count == 0) return error.InvalidRpmTagType;
        const start = try self.valueStart(index);
        return std.mem.readInt(u32, self.bytes[start..][0..4], .big);
    }

    pub fn binary(self: Header, tag: u32) Error!?[]const u8 {
        const index = (try self.find(tag)) orelse return null;
        if (index.value_type != .binary) return error.InvalidRpmTagType;
        const start = try self.valueStart(index);
        return self.bytes[start..][0..index.count];
    }

    pub fn strings(self: Header, tag: u32) Error!?StringIterator {
        const index = (try self.find(tag)) orelse return null;
        if (index.value_type != .string_array and index.value_type != .i18n_string)
            return error.InvalidRpmTagType;
        return .{
            .bytes = self.bytes,
            .position = try self.valueStart(index),
            .limit = self.next_offset,
            .remaining = index.count,
        };
    }

    fn valueStart(self: Header, index: Index) Error!usize {
        if (isRegionTrailer(index)) return error.InvalidRpmTagType;
        const relative: usize = index.offset;
        if (relative > self.data_size) return error.InvalidRpmHeader;
        return std.math.add(usize, self.data_offset, relative) catch error.IntegerOverflow;
    }
};

pub const Iterator = struct {
    header: Header,
    position: usize = 0,

    pub fn next(self: *Iterator) Error!?Index {
        if (self.position == self.header.index_count) return null;
        const offset = self.header.index_offset + self.position * 16;
        self.position += 1;
        return @as(?Index, try parseIndex(self.header.bytes[offset..][0..16]));
    }
};

pub const StringIterator = struct {
    bytes: []const u8,
    position: usize,
    limit: usize,
    remaining: u32,

    pub fn next(self: *StringIterator) Error!?[]const u8 {
        if (self.remaining == 0) return null;
        if (self.position >= self.limit) return error.InvalidRpmHeader;
        const tail = self.bytes[self.position..self.limit];
        const length = std.mem.indexOfScalar(u8, tail, 0) orelse return error.InvalidRpmHeader;
        const value = tail[0..length];
        self.position += length + 1;
        self.remaining -= 1;
        return value;
    }
};

pub const Parsed = struct { header: Header, next_offset: usize };

pub fn parse(bytes: []const u8, offset: usize) Error!Parsed {
    const prefix_end = try checkedEnd(offset, 16, bytes.len);
    const prefix = bytes[offset..prefix_end];
    if (!std.mem.eql(u8, prefix[0..3], &.{ 0x8e, 0xad, 0xe8 }) or prefix[3] != 1)
        return error.InvalidRpmHeader;
    for (prefix[4..8]) |byte| if (byte != 0) return error.InvalidRpmHeader;
    const index_count_u32 = std.mem.readInt(u32, prefix[8..12], .big);
    const data_size_u32 = std.mem.readInt(u32, prefix[12..16], .big);
    const index_count: usize = index_count_u32;
    const data_size: usize = data_size_u32;
    const index_bytes = std.math.mul(usize, index_count, 16) catch
        return error.IntegerOverflow;
    const index_offset = prefix_end;
    const data_offset = try checkedEnd(index_offset, index_bytes, bytes.len);
    const next_offset = try checkedEnd(data_offset, data_size, bytes.len);
    const result = Header{
        .bytes = bytes,
        .offset = offset,
        .index_count = index_count,
        .index_offset = index_offset,
        .data_offset = data_offset,
        .data_size = data_size,
        .next_offset = next_offset,
    };
    var iterator_value = result.iterator();
    while (try iterator_value.next()) |index| try validateIndex(result, index);
    return .{ .header = result, .next_offset = next_offset };
}

fn parseIndex(bytes: []const u8) Error!Index {
    const raw_type = std.mem.readInt(u32, bytes[4..8], .big);
    const value_type = std.enums.fromInt(ValueType, raw_type) orelse
        return error.InvalidRpmHeader;
    return .{
        .tag = std.mem.readInt(u32, bytes[0..4], .big),
        .value_type = value_type,
        .offset = std.mem.readInt(u32, bytes[8..12], .big),
        .count = std.mem.readInt(u32, bytes[12..16], .big),
    };
}

fn validateIndex(header: Header, index: Index) Error!void {
    if (isRegionTrailer(index)) return;
    const start: usize = index.offset;
    if (start > header.data_size) return error.InvalidRpmHeader;
    switch (index.value_type) {
        .null => if (index.count != 0) return error.InvalidRpmHeader,
        .char, .int8, .binary => try validateFixed(header, start, index.count, 1),
        .int16 => try validateFixed(header, start, index.count, 2),
        .int32 => try validateFixed(header, start, index.count, 4),
        .int64 => try validateFixed(header, start, index.count, 8),
        .string => {
            if (index.count != 1) return error.InvalidRpmHeader;
            try validateStrings(header, start, 1);
        },
        .string_array, .i18n_string => try validateStrings(header, start, index.count),
    }
}

fn validateFixed(header: Header, start: usize, count: u32, width: usize) Error!void {
    const size = std.math.mul(usize, count, width) catch return error.IntegerOverflow;
    if (size > header.data_size - start) return error.InvalidRpmHeader;
}

fn validateStrings(header: Header, start: usize, count: u32) Error!void {
    var position = start;
    for (0..count) |_| {
        if (position >= header.data_size) return error.InvalidRpmHeader;
        const tail = header.bytes[header.data_offset + position .. header.next_offset];
        const length = std.mem.indexOfScalar(u8, tail, 0) orelse return error.InvalidRpmHeader;
        position = std.math.add(usize, position, length + 1) catch return error.IntegerOverflow;
    }
}

fn isRegionTrailer(index: Index) bool {
    return index.tag >= 61 and index.tag <= 64 and index.value_type == .binary and
        index.count == 16 and index.offset & 0x8000_0000 != 0;
}

fn checkedEnd(start: usize, size: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

test "RPM header parser rejects bad magic and truncated indexes" {
    try std.testing.expectError(error.TruncatedFrame, parse("", 0));
    var prefix: [16]u8 = @splat(0);
    prefix[0..4].* = .{ 0x8e, 0xad, 0xe8, 1 };
    std.mem.writeInt(u32, prefix[8..12], 1, .big);
    try std.testing.expectError(error.TruncatedFrame, parse(&prefix, 0));
}

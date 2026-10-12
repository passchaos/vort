const std = @import("std");

pub const Error = error{
    InvalidProtobuf,
    UnsupportedProtobufWireType,
    IntegerOverflow,
    TruncatedFrame,
};

pub const WireType = enum(u3) {
    varint = 0,
    fixed64 = 1,
    bytes = 2,
    start_group = 3,
    end_group = 4,
    fixed32 = 5,
};

pub const Field = struct {
    number: u32,
    wire_type: WireType,
    value: union(WireType) {
        varint: u64,
        fixed64: u64,
        bytes: []const u8,
        start_group: void,
        end_group: void,
        fixed32: u32,
    },
};

pub const Reader = struct {
    bytes: []const u8,
    offset: usize = 0,

    pub fn init(bytes: []const u8) Reader {
        return .{ .bytes = bytes };
    }

    pub fn next(self: *Reader) Error!?Field {
        if (self.offset == self.bytes.len) return null;
        const tag = try readVarint(self.bytes, &self.offset);
        const number64 = tag >> 3;
        if (number64 == 0 or number64 > 0x1fff_ffff)
            return error.InvalidProtobuf;
        const wire_type = std.enums.fromInt(WireType, @as(u3, @truncate(tag))) orelse
            return error.UnsupportedProtobufWireType;
        const number: u32 = @intCast(number64);
        return switch (wire_type) {
            .varint => .{
                .number = number,
                .wire_type = wire_type,
                .value = .{ .varint = try readVarint(self.bytes, &self.offset) },
            },
            .fixed64 => blk: {
                const bytes = try take(self.bytes, &self.offset, 8);
                break :blk .{
                    .number = number,
                    .wire_type = wire_type,
                    .value = .{ .fixed64 = std.mem.readInt(u64, bytes[0..8], .little) },
                };
            },
            .bytes => blk: {
                const length64 = try readVarint(self.bytes, &self.offset);
                const length = std.math.cast(usize, length64) orelse
                    return error.IntegerOverflow;
                break :blk .{
                    .number = number,
                    .wire_type = wire_type,
                    .value = .{ .bytes = try take(self.bytes, &self.offset, length) },
                };
            },
            .fixed32 => blk: {
                const bytes = try take(self.bytes, &self.offset, 4);
                break :blk .{
                    .number = number,
                    .wire_type = wire_type,
                    .value = .{ .fixed32 = std.mem.readInt(u32, bytes[0..4], .little) },
                };
            },
            .start_group, .end_group => error.UnsupportedProtobufWireType,
        };
    }
};

pub fn expectVarint(field: Field) Error!u64 {
    if (field.wire_type != .varint) return error.InvalidProtobuf;
    return field.value.varint;
}

pub fn expectBytes(field: Field) Error![]const u8 {
    if (field.wire_type != .bytes) return error.InvalidProtobuf;
    return field.value.bytes;
}

pub fn appendVarintField(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    number: u32,
    value: u64,
) (Error || std.mem.Allocator.Error)!void {
    try appendKey(allocator, output, number, .varint);
    try appendVarint(allocator, output, value);
}

pub fn appendBytesField(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    number: u32,
    bytes: []const u8,
) (Error || std.mem.Allocator.Error)!void {
    try appendKey(allocator, output, number, .bytes);
    try appendVarint(allocator, output, bytes.len);
    try output.appendSlice(allocator, bytes);
}

pub fn appendMessageField(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    number: u32,
    message: []const u8,
) (Error || std.mem.Allocator.Error)!void {
    return appendBytesField(allocator, output, number, message);
}

pub fn appendVarint(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u64,
) std.mem.Allocator.Error!void {
    var remaining = value;
    while (remaining >= 0x80) : (remaining >>= 7)
        try output.append(allocator, @as(u8, @truncate(remaining)) | 0x80);
    try output.append(allocator, @truncate(remaining));
}

fn appendKey(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    number: u32,
    wire_type: WireType,
) (Error || std.mem.Allocator.Error)!void {
    if (number == 0 or number > 0x1fff_ffff) return error.InvalidProtobuf;
    const tag = (@as(u64, number) << 3) | @intFromEnum(wire_type);
    try appendVarint(allocator, output, tag);
}

fn readVarint(bytes: []const u8, offset: *usize) Error!u64 {
    var value: u64 = 0;
    var shift: u6 = 0;
    for (0..10) |index| {
        if (offset.* >= bytes.len) return error.TruncatedFrame;
        const byte = bytes[offset.*];
        offset.* += 1;
        if (index == 9 and byte > 1) return error.InvalidProtobuf;
        value |= @as(u64, byte & 0x7f) << shift;
        if (byte & 0x80 == 0) return value;
        if (index != 9) shift += 7;
    }
    return error.InvalidProtobuf;
}

fn take(bytes: []const u8, offset: *usize, length: usize) Error![]const u8 {
    if (length > bytes.len - offset.*) return error.TruncatedFrame;
    const result = bytes[offset.*..][0..length];
    offset.* += length;
    return result;
}

test "Android OTA protobuf reads and writes supported wire values" {
    const allocator = std.testing.allocator;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendVarintField(allocator, &encoded, 1, std.math.maxInt(u64));
    try appendBytesField(allocator, &encoded, 13, "partition");
    var reader = Reader.init(encoded.items);
    const first = (try reader.next()).?;
    try std.testing.expectEqual(@as(u32, 1), first.number);
    try std.testing.expectEqual(std.math.maxInt(u64), try expectVarint(first));
    const second = (try reader.next()).?;
    try std.testing.expectEqual(@as(u32, 13), second.number);
    try std.testing.expectEqualSlices(u8, "partition", try expectBytes(second));
    try std.testing.expect((try reader.next()) == null);
}

test "Android OTA protobuf rejects truncated and overlong values" {
    var reader = Reader.init(&.{0x80});
    try std.testing.expectError(error.TruncatedFrame, reader.next());
    reader = Reader.init(&.{ 0x08, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x02 });
    try std.testing.expectError(error.InvalidProtobuf, reader.next());
}

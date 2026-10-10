const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidRar50Stream,
};

pub const Kind = enum { delta, e8, e8e9, arm };

pub const Filter = struct {
    start: usize,
    length: usize,
    kind: Kind,
    channels: usize = 0,
};

pub fn applyAll(
    allocator: std.mem.Allocator,
    output: []u8,
    filters: []const Filter,
) Error!void {
    for (filters) |filter| {
        const end = std.math.add(usize, filter.start, filter.length) catch
            return error.IntegerOverflow;
        if (end > output.len) return error.SizeMismatch;
        const data = output[filter.start..end];
        switch (filter.kind) {
            .delta => try decodeDelta(allocator, data, filter.channels),
            .e8 => decodeE8E9(data, @truncate(filter.start), false),
            .e8e9 => decodeE8E9(data, @truncate(filter.start), true),
            .arm => decodeArm(data, @truncate(filter.start)),
        }
    }
}

fn decodeDelta(allocator: std.mem.Allocator, data: []u8, channels: usize) Error!void {
    if (channels == 0 or channels > 32) return error.InvalidRar50Stream;
    const decoded = try allocator.alloc(u8, data.len);
    defer allocator.free(decoded);
    var source: usize = 0;
    for (0..channels) |channel| {
        var previous: u8 = 0;
        var destination = channel;
        while (destination < decoded.len) : (destination += channels) {
            if (source == data.len) return error.TruncatedFrame;
            previous -%= data[source];
            source += 1;
            decoded[destination] = previous;
        }
    }
    if (source != data.len) return error.InvalidRar50Stream;
    @memcpy(data, decoded);
}

const x86_file_size: u32 = 0x0100_0000;

fn decodeE8E9(data: []u8, file_offset: u32, include_e9: bool) void {
    if (data.len <= 4) return;
    const compare_mask: u8 = if (include_e9) 0xfe else 0xff;
    var position: usize = 0;
    while (position < data.len - 4) {
        position += 1;
        if (data[position - 1] & compare_mask != 0xe8) continue;
        const offset = (file_offset +% @as(u32, @truncate(position))) % x86_file_size;
        const address = std.mem.readInt(u32, data[position..][0..4], .little);
        const decoded: ?u32 = if (address & 0x8000_0000 != 0)
            if (address +% offset & 0x8000_0000 == 0)
                address +% x86_file_size
            else
                null
        else if (address -% x86_file_size & 0x8000_0000 != 0)
            address -% offset
        else
            null;
        if (decoded) |value|
            std.mem.writeInt(u32, data[position..][0..4], value, .little);
        position += 4;
    }
}

fn decodeArm(data: []u8, file_offset: u32) void {
    var position: usize = 0;
    while (position + 3 < data.len) : (position += 4) {
        if (data[position + 3] != 0xeb) continue;
        var offset = @as(u32, data[position]) |
            (@as(u32, data[position + 1]) << 8) |
            (@as(u32, data[position + 2]) << 16);
        offset -%= (file_offset +% @as(u32, @truncate(position))) / 4;
        data[position] = @truncate(offset);
        data[position + 1] = @truncate(offset >> 8);
        data[position + 2] = @truncate(offset >> 16);
    }
}

test "RAR50 Delta filter reconstructs interleaved bytes" {
    var encoded = [_]u8{ 246, 255, 236, 254, 226, 253 };
    try decodeDelta(std.testing.allocator, &encoded, 3);
    try std.testing.expectEqualSlices(u8, &.{ 10, 20, 30, 11, 22, 33 }, &encoded);
}

test "RAR50 ARM filter decodes branch offsets" {
    var encoded = [_]u8{ 4, 0, 0, 0xeb };
    decodeArm(&encoded, 0);
    try std.testing.expectEqualSlices(u8, &.{ 4, 0, 0, 0xeb }, &encoded);
    decodeArm(&encoded, 16);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0xeb }, &encoded);
}

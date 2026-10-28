//! Private run-coded u8/u16 planes with exact-size raw fallback.
const std = @import("std");
const endian = @import("builtin").target.cpu.arch.endian();

pub const Plane = struct {
    bytes: []u8 = &.{},
    runs: bool = false,

    pub fn deinit(self: Plane, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

fn varintBytes(value: usize) usize {
    var n = value;
    var count: usize = 1;
    while (n >= 128) : (n >>= 7) count += 1;
    return count;
}

fn putVarint(bytes: []u8, position: *usize, value: usize) void {
    var n = value;
    while (n >= 128) : (n >>= 7) {
        bytes[position.*] = @as(u8, @truncate(n)) | 128;
        position.* += 1;
    }
    bytes[position.*] = @intCast(n);
    position.* += 1;
}

fn putValue(comptime T: type, bytes: []u8, position: *usize, value: T) void {
    if (T == u8) bytes[position.*] = value else std.mem.writeInt(u16, bytes[position.*..][0..2], value, .little);
    position.* += @sizeOf(T);
}

fn runEnd(comptime T: type, values: []const T, start: usize) usize {
    var end = start + 1;
    if (end == values.len or values[end] != values[start]) return end;
    end += 1;
    const lanes = 8 / @sizeOf(T);
    const repeated = @as(u64, values[start]) * (if (T == u8) @as(u64, 0x0101010101010101) else 0x0001000100010001);
    while (values.len - end >= lanes) : (end += lanes) {
        const word = std.mem.readInt(u64, std.mem.sliceAsBytes(values[end..][0..lanes])[0..8], endian);
        const difference = word ^ repeated;
        if (difference != 0) return end + (if (endian == .little) @ctz(difference) else @clz(difference)) / @bitSizeOf(T);
    }
    while (end < values.len and values[end] == values[start]) end += 1;
    return end;
}

pub fn encode(comptime T: type, allocator: std.mem.Allocator, values: []const T) !Plane {
    comptime std.debug.assert(T == u8 or T == u16);
    const raw_bytes = std.math.mul(usize, values.len, @sizeOf(T)) catch return error.InvalidBlockPlan;
    var encoded_bytes: usize = 0;
    var start: usize = 0;
    while (start < values.len) {
        const end = runEnd(T, values, start);
        encoded_bytes = std.math.add(usize, encoded_bytes, varintBytes(end - start) + @sizeOf(T)) catch return error.InvalidBlockPlan;
        if (encoded_bytes >= raw_bytes) break;
        start = end;
    }
    const runs = encoded_bytes < raw_bytes;
    const bytes = try allocator.alloc(u8, if (runs) encoded_bytes else raw_bytes);
    var position: usize = 0;
    if (runs) {
        start = 0;
        while (start < values.len) {
            const end = runEnd(T, values, start);
            putVarint(bytes, &position, end - start);
            putValue(T, bytes, &position, values[start]);
            start = end;
        }
    } else for (values) |value| putValue(T, bytes, &position, value);
    std.debug.assert(position == bytes.len);
    return .{ .bytes = bytes, .runs = runs };
}

fn takeValue(comptime T: type, bytes: []const u8, position: *usize) !T {
    if (bytes.len - position.* < @sizeOf(T)) return error.InvalidBlockPlan;
    const value = if (T == u8) bytes[position.*] else std.mem.readInt(u16, bytes[position.*..][0..2], .little);
    position.* += @sizeOf(T);
    return value;
}

pub fn decode(comptime T: type, plane: Plane, values: []T) !void {
    comptime std.debug.assert(T == u8 or T == u16);
    var position: usize = 0;
    if (!plane.runs) {
        const expected = std.math.mul(usize, values.len, @sizeOf(T)) catch return error.InvalidBlockPlan;
        if (plane.bytes.len != expected) return error.InvalidBlockPlan;
        for (values) |*value| value.* = try takeValue(T, plane.bytes, &position);
        return;
    }
    var produced: usize = 0;
    while (position < plane.bytes.len) {
        var count: usize = 0;
        var shift: usize = 0;
        while (true) {
            if (position == plane.bytes.len or shift >= @bitSizeOf(usize)) return error.InvalidBlockPlan;
            const byte = plane.bytes[position];
            position += 1;
            const part: usize = byte & 127;
            if (part > @as(usize, std.math.maxInt(usize)) >> @intCast(shift)) return error.InvalidBlockPlan;
            count |= part << @intCast(shift);
            if (byte & 128 == 0) break;
            shift += 7;
        }
        if (count == 0 or count > values.len - produced) return error.InvalidBlockPlan;
        const value = try takeValue(T, plane.bytes, &position);
        @memset(values[produced..][0..count], value);
        produced += count;
    }
    if (produced != values.len) return error.InvalidBlockPlan;
}

test "optimal plane runs round trip exact raw and run controls" {
    inline for (.{ u8, u16 }) |T| {
        var values: [1027]T = undefined;
        var decoded: [1027]T = undefined;
        for (0..4) |kind| {
            for (&values, 0..) |*v, i| v.* = switch (kind) {
                0 => 0,
                1 => @truncate(i),
                2 => @truncate(i / 129),
                else => @truncate(i *% 7919),
            };
            for ([_]usize{ 0, 1, 2, 127, 128, 129, 1027 }) |length| {
                const plane = try encode(T, std.testing.allocator, values[0..length]);
                defer plane.deinit(std.testing.allocator);
                try std.testing.expect(plane.bytes.len <= length * @sizeOf(T));
                try decode(T, plane, decoded[0..length]);
                try std.testing.expectEqualSlices(T, values[0..length], decoded[0..length]);
            }
        }
    }
}

test "optimal plane runs reject truncated zero oversized and trailing runs" {
    var output: [4]u8 = undefined;
    for ([_][]const u8{ &.{128}, &.{ 0, 17 }, &.{ 5, 17 }, &.{ 3, 17 }, &.{4}, &.{ 4, 17, 1, 19 } }) |input|
        try std.testing.expectError(error.InvalidBlockPlan, decode(u8, .{ .bytes = @constCast(input), .runs = true }, &output));
}

test "optimal plane word scanning preserves every scalar tail and offset" {
    inline for (.{ u8, u16 }) |T| {
        var values: [81]T = undefined;
        for ([_]T{ 0, 17, std.math.maxInt(T) }) |value| {
            for (0..9) |start| {
                for (start + 1..values.len + 1) |limit| {
                    for (start + 1..limit + 1) |mismatch| {
                        @memset(&values, value);
                        if (mismatch < limit) values[mismatch] +%= 1;
                        try std.testing.expectEqual(@min(mismatch, limit), runEnd(T, values[0..limit], start));
                    }
                }
            }
        }
    }
}

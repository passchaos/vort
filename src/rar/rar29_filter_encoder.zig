const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidRar29FilterOptions,
};

pub const Filter = union(enum) {
    delta: u8,
    e8,
    e8e9,
    itanium,
    rgb: struct { width: usize, red_position: u8 = 0 },
    audio: u8,
};

pub const max_filter_block_size: usize = 128 * 1024;
const max_delta_block_size: usize = 120_000;
const max_audio_block_size: usize = 120_000;

const e8_code = [_]u8{
    0x97, 0x1b, 0x01, 0x28, 0x07, 0x06, 0x98, 0x08, 0x00, 0x00, 0x00, 0xd1, 0x3a, 0x10, 0x15, 0x92,
    0xec, 0x50, 0xcb, 0x99, 0x20, 0xb9, 0x25, 0xf0, 0x29, 0x19, 0x15, 0x53, 0x03, 0x12, 0xae, 0x51,
    0x10, 0x35, 0x59, 0x2b, 0x60, 0x04, 0x15, 0x6d, 0x40, 0x66, 0xab, 0x02, 0x34, 0x49, 0x04, 0x36,
    0x02, 0x52, 0x3e, 0x97, 0x00,
};
const e8e9_code = [_]u8{
    0x84, 0x1b, 0x01, 0x28, 0x11, 0x10, 0x69, 0x80, 0x80, 0x00, 0x00, 0x0d, 0x13, 0xa1, 0x01, 0xc6,
    0x89, 0xd2, 0x80, 0xac, 0x97, 0x62, 0x85, 0x5c, 0xc9, 0x05, 0xc9, 0x2f, 0x81, 0x48, 0xc8, 0xaa,
    0x98, 0x18, 0x95, 0x72, 0x88, 0x81, 0xaa, 0xc9, 0x5b, 0x00, 0x20, 0xab, 0x6a, 0x03, 0x35, 0x58,
    0x11, 0xa2, 0x48, 0x21, 0xb0, 0x12, 0x91, 0xf4, 0xb8,
};
const delta_code = [_]u8{
    0x2f, 0x01, 0x9a, 0x41, 0x80, 0xec, 0x27, 0x48, 0x2f, 0x09, 0x76, 0x6d, 0xd3, 0xea, 0x41, 0x5b,
    0x59, 0x44, 0xe8, 0x17, 0x5c, 0xe1, 0x6c, 0x91, 0x4c, 0x4e, 0x3f, 0x77, 0x00,
};
const itanium_code = [_]u8{
    0x46, 0x9e, 0x08, 0x08, 0x0c, 0x0c, 0x00, 0x00, 0x0e, 0x0e, 0x08, 0x08, 0x00, 0x00, 0x08, 0x08,
    0x00, 0x00, 0x6c, 0x11, 0x5a, 0x04, 0xac, 0x0c, 0xc4, 0xcc, 0x5c, 0x08, 0x18, 0x46, 0x24, 0x08,
    0xf9, 0xa0, 0x44, 0x25, 0x12, 0x12, 0x45, 0x85, 0x99, 0x0c, 0x14, 0x00, 0x26, 0x25, 0x58, 0x99,
    0x90, 0x03, 0x38, 0x1a, 0x08, 0xdc, 0x02, 0x30, 0x0c, 0x4e, 0xd1, 0x1d, 0x89, 0xa1, 0xe2, 0xd0,
    0x55, 0x11, 0x33, 0x60, 0x8c, 0x5a, 0x23, 0x06, 0xde, 0x06, 0x18, 0x00, 0x7f, 0xff, 0xfc, 0x4d,
    0xcc, 0x19, 0x17, 0xb3, 0x06, 0xc4, 0x44, 0xb2, 0x32, 0x5a, 0x44, 0xc4, 0xa6, 0x01, 0xf4, 0x24,
    0x88, 0x83, 0x38, 0xcc, 0xc4, 0x11, 0x09, 0x87, 0xa6, 0xe0, 0x46, 0x02, 0xb2, 0x24, 0x03, 0xe2,
    0xa0, 0x32, 0x54, 0x83, 0x52, 0xc5, 0xb1, 0x70,
};
const rgb_code = [_]u8{
    0xc5, 0x01, 0x9a, 0x41, 0x95, 0xc9, 0xa6, 0x4d, 0xba, 0x4b, 0x14, 0x0a, 0xf4, 0x9b, 0x80, 0x4c,
    0x00, 0x15, 0xa6, 0xa8, 0x07, 0x26, 0x2a, 0xc9, 0xc4, 0x8b, 0x86, 0x62, 0x32, 0x0f, 0x86, 0x64,
    0x24, 0x06, 0x66, 0x71, 0x19, 0x98, 0xcc, 0x43, 0x33, 0x31, 0x99, 0x00, 0x66, 0x88, 0x33, 0x30,
    0xcc, 0xd1, 0x0e, 0x98, 0x0b, 0x33, 0x34, 0x40, 0x0c, 0xd1, 0x46, 0x66, 0x19, 0x9a, 0x28, 0xcc,
    0x49, 0x80, 0xb3, 0x33, 0x45, 0x00, 0xcd, 0x18, 0x66, 0x61, 0x99, 0xa3, 0x0c, 0xc8, 0x98, 0x0b,
    0x33, 0x34, 0x60, 0x4c, 0xd1, 0x06, 0x68, 0xa5, 0x20, 0x62, 0x66, 0x88, 0x33, 0x46, 0x28, 0x05,
    0x0f, 0x32, 0x0c, 0x4c, 0xd1, 0x46, 0x68, 0xc5, 0x00, 0x41, 0xe4, 0x8f, 0xc8, 0x85, 0x5e, 0x02,
    0x7c, 0xc9, 0x26, 0x81, 0x83, 0xb0, 0x9d, 0xc2, 0xde, 0x9c, 0x78, 0xac, 0xd6, 0x68, 0xb4, 0x0e,
    0x71, 0xdb, 0xb2, 0x49, 0x38, 0x6e, 0x02, 0x2a, 0x2c, 0x41, 0x2b, 0x10, 0x98, 0x82, 0x49, 0x03,
    0x14, 0xf4, 0xe1, 0x97, 0x00,
};
const audio_code = [_]u8{
    0x47, 0x01, 0x9a, 0x41, 0x95, 0xe5, 0x72, 0x0d, 0xc2, 0x64, 0x82, 0x74, 0x93, 0x24, 0xb1, 0x40,
    0x06, 0xd8, 0x38, 0x44, 0x00, 0xa8, 0x01, 0x34, 0x11, 0xdc, 0xa1, 0xba, 0x01, 0x99, 0x0c, 0xc4,
    0x03, 0x31, 0x19, 0xa4, 0x06, 0x66, 0x22, 0x60, 0x4d, 0x9a, 0x40, 0x0d, 0x66, 0x8e, 0x60, 0xd0,
    0x30, 0x40, 0x18, 0x26, 0xc1, 0xc8, 0xf6, 0xe6, 0x26, 0x13, 0x78, 0x92, 0x08, 0xe8, 0x50, 0xbc,
    0x5a, 0x07, 0xc6, 0xe9, 0xf5, 0x20, 0xa9, 0xa0, 0xed, 0x37, 0x33, 0x47, 0x39, 0x66, 0x90, 0x70,
    0x19, 0xa3, 0x9b, 0xcf, 0x25, 0x83, 0x80, 0xc1, 0xbd, 0x30, 0x16, 0x6e, 0x23, 0x34, 0x93, 0x81,
    0x16, 0x09, 0xb0, 0x50, 0x18, 0x3b, 0x4d, 0xc8, 0x4c, 0x05, 0x9b, 0x88, 0xc5, 0x28, 0xe0, 0x76,
    0x93, 0x90, 0x98, 0x0b, 0x37, 0x11, 0x8a, 0x59, 0xc4, 0x80, 0x42, 0x48, 0x43, 0xa9, 0x47, 0xee,
    0x43, 0x34, 0x60, 0x47, 0xd4, 0x4a, 0x0d, 0xbb, 0xd3, 0x59, 0xa4, 0x86, 0xee, 0x05, 0x09, 0x40,
    0x26, 0xc9, 0x34, 0x24, 0x76, 0xa0, 0x30, 0x6a, 0x20, 0xea, 0x02, 0x20, 0x04, 0xa0, 0x41, 0x50,
    0x9e, 0x50, 0x3f, 0xe6, 0xe1, 0x28, 0x94, 0x46, 0x01, 0xbd, 0x8b, 0x40, 0xf0, 0x68, 0x11, 0x36,
    0xc9, 0xa1, 0x92, 0x38, 0x11, 0x41, 0x9c, 0xa8, 0x95, 0x10, 0xee, 0x50, 0x66, 0x2b, 0x00, 0x20,
    0x95, 0x11, 0x04, 0x02, 0x62, 0xac, 0x66, 0x8c, 0x6a, 0xca, 0x26, 0x40, 0xb2, 0x67, 0x1b, 0x4b,
    0x26, 0xcc, 0x64, 0x8a, 0x62, 0x71, 0xa2, 0xb8,
};

const InitReg = struct { index: u3, value: u32 };

pub const Prepared = struct {
    allocator: std.mem.Allocator,
    data: []u8,
    record: []u8,

    pub fn deinit(self: *Prepared) void {
        self.allocator.free(self.data);
        self.allocator.free(self.record);
        self.* = undefined;
    }
};

pub fn validate(filter: Filter) Error!void {
    switch (filter) {
        .delta, .audio => |channels| if (channels == 0 or channels > 32)
            return error.InvalidRar29FilterOptions,
        .rgb => |rgb| if (rgb.width == 0 or rgb.width % 3 != 0 or
            rgb.width > max_filter_block_size or rgb.red_position > 2)
            return error.InvalidRar29FilterOptions,
        .e8, .e8e9, .itanium => {},
    }
}

pub fn blockSize(filter: Filter, requested: usize) Error!usize {
    try validate(filter);
    if (requested == 0) return error.InvalidRar29FilterOptions;
    const limit = switch (filter) {
        .delta => |channels| max_delta_block_size - max_delta_block_size % channels,
        .audio => |channels| max_audio_block_size - max_audio_block_size % channels,
        .rgb => |rgb| max_filter_block_size - max_filter_block_size % rgb.width,
        .e8, .e8e9, .itanium => max_filter_block_size,
    };
    return @min(requested, limit);
}

pub fn canApply(filter: Filter, input_len: usize) bool {
    if (input_len == 0) return false;
    return switch (filter) {
        .rgb => |rgb| input_len >= rgb.width,
        else => true,
    };
}

pub fn prepareBlockAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    filter: Filter,
    file_offset: usize,
    include_code: bool,
) Error!Prepared {
    try validate(filter);
    if (!canApply(filter, input.len)) return error.InvalidRar29FilterOptions;
    const data = try allocator.dupe(u8, input);
    errdefer allocator.free(data);
    var regs: [2]InitReg = undefined;
    const reg_count: usize = switch (filter) {
        .delta => |channels| blk: {
            try encodeDelta(allocator, data, channels);
            regs[0] = .{ .index = 0, .value = channels };
            break :blk 1;
        },
        .e8 => blk: {
            encodeE8E9(data, @truncate(file_offset), false);
            break :blk 0;
        },
        .e8e9 => blk: {
            encodeE8E9(data, @truncate(file_offset), true);
            break :blk 0;
        },
        .itanium => blk: {
            encodeItanium(data, @truncate(file_offset));
            break :blk 0;
        },
        .rgb => |rgb| blk: {
            try encodeRgb(allocator, data, rgb.width, rgb.red_position);
            regs[0] = .{ .index = 0, .value = @intCast(rgb.width + 3) };
            if (rgb.red_position != 0) {
                regs[1] = .{ .index = 1, .value = rgb.red_position };
                break :blk 2;
            }
            break :blk 1;
        },
        .audio => |channels| blk: {
            try encodeAudio(allocator, data, channels);
            regs[0] = .{ .index = 0, .value = channels };
            break :blk 1;
        },
    };
    const record = try encodeRecordAlloc(
        allocator,
        input.len,
        regs[0..reg_count],
        codeFor(filter),
        include_code,
    );
    return .{ .allocator = allocator, .data = data, .record = record };
}

fn codeFor(filter: Filter) []const u8 {
    return switch (filter) {
        .delta => &delta_code,
        .e8 => &e8_code,
        .e8e9 => &e8e9_code,
        .itanium => &itanium_code,
        .rgb => &rgb_code,
        .audio => &audio_code,
    };
}

fn encodeRecordAlloc(
    allocator: std.mem.Allocator,
    block_size: usize,
    regs: []const InitReg,
    code: []const u8,
    include_code: bool,
) Error![]u8 {
    if (block_size == 0 or block_size > std.math.maxInt(u32))
        return error.InvalidRar29FilterOptions;
    var body = RecordWriter{ .allocator = allocator };
    defer body.bytes.deinit(allocator);
    try body.writeEncodedU32(if (include_code) 0 else 1);
    try body.writeEncodedU32(0);
    try body.writeEncodedU32(@intCast(block_size));
    if (regs.len != 0) {
        var mask: u32 = 0;
        for (regs) |reg| mask |= @as(u32, 1) << reg.index;
        try body.writeBits(mask, 7);
        for (0..7) |index| {
            for (regs) |reg| {
                if (reg.index == index) try body.writeEncodedU32(reg.value);
            }
        }
    }
    if (include_code) {
        try body.writeEncodedU32(@intCast(code.len));
        for (code) |byte| try body.writeBits(byte, 8);
    }
    const body_bytes = body.bytes.items;
    if (body_bytes.len == 0 or body_bytes.len > std.math.maxInt(u16))
        return error.InvalidRar29FilterOptions;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var first: u8 = 0x80 | 0x20;
    if (regs.len != 0) first |= 0x10;
    switch (body_bytes.len) {
        1...6 => first |= @intCast(body_bytes.len - 1),
        7...262 => {
            first |= 6;
            try output.append(allocator, first);
            try output.append(allocator, @intCast(body_bytes.len - 7));
        },
        else => {
            first |= 7;
            try output.append(allocator, first);
            var length: [2]u8 = undefined;
            std.mem.writeInt(u16, &length, @intCast(body_bytes.len), .big);
            try output.appendSlice(allocator, &length);
        },
    }
    if (body_bytes.len <= 6) try output.append(allocator, first);
    try output.appendSlice(allocator, body_bytes);
    return output.toOwnedSlice(allocator);
}

const RecordWriter = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,
    bit_offset: usize = 0,

    fn writeEncodedU32(self: *RecordWriter, value: u32) Error!void {
        if (value < 16) {
            try self.writeBits(0, 2);
            try self.writeBits(value, 4);
        } else if (value < 256) {
            try self.writeBits(1, 2);
            try self.writeBits(value, 8);
        } else if (value <= std.math.maxInt(u16)) {
            try self.writeBits(2, 2);
            try self.writeBits(value, 16);
        } else {
            try self.writeBits(3, 2);
            try self.writeBits(value >> 16, 16);
            try self.writeBits(value & 0xffff, 16);
        }
    }

    fn writeBits(self: *RecordWriter, value: u32, count: u8) Error!void {
        var index: usize = count;
        while (index != 0) {
            index -= 1;
            if (self.bit_offset % 8 == 0) try self.bytes.append(self.allocator, 0);
            if (value & (@as(u32, 1) << @intCast(index)) != 0)
                self.bytes.items[self.bytes.items.len - 1] |=
                    @as(u8, 1) << @intCast(7 - self.bit_offset % 8);
            self.bit_offset += 1;
        }
    }
};

fn encodeDelta(allocator: std.mem.Allocator, data: []u8, channels: usize) Error!void {
    const encoded = try allocator.alloc(u8, data.len);
    defer allocator.free(encoded);
    var destination: usize = 0;
    for (0..channels) |channel| {
        var previous: u8 = 0;
        var source = channel;
        while (source < data.len) : (source += channels) {
            encoded[destination] = previous -% data[source];
            previous = data[source];
            destination += 1;
        }
    }
    @memcpy(data, encoded);
}

fn encodeE8E9(data: []u8, file_offset: u32, include_e9: bool) void {
    if (data.len <= 4) return;
    const compare_mask: u8 = if (include_e9) 0xfe else 0xff;
    var position: usize = 0;
    while (position < data.len - 4) {
        position += 1;
        if (data[position - 1] & compare_mask != 0xe8) continue;
        const offset = file_offset +% @as(u32, @truncate(position));
        const address = std.mem.readInt(u32, data[position..][0..4], .little);
        const candidate = address +% offset;
        const encoded: ?u32 = if (candidate < 0x0100_0000)
            candidate
        else blk: {
            const wrapped = address -% 0x0100_0000;
            break :blk if (wrapped & 0x8000_0000 != 0 and
                wrapped +% offset & 0x8000_0000 == 0)
                wrapped
            else
                null;
        };
        if (encoded) |value|
            std.mem.writeInt(u32, data[position..][0..4], value, .little);
        position += 4;
    }
}

fn encodeItanium(data: []u8, file_offset: u32) void {
    if (data.len <= 21) return;
    const base_offset = file_offset >> 4;
    const block_count = std.math.divCeil(usize, data.len - 21, 16) catch unreachable;
    for (0..block_count) |block| {
        const position = block * 16;
        const current_offset = base_offset +% @as(u32, @truncate(block));
        var mask: u32 = (@as(u32, 0x334b_0000) >> @intCast(data[position] & 0x1e)) & 3;
        if (mask == 0) continue;
        mask += 1;
        while (mask <= 4) : (mask += 1) {
            const instruction = position + @as(usize, mask) * 5 - 8;
            if ((data[instruction + 3] >> @intCast(mask)) & 15 != 5) continue;
            const raw = std.mem.readInt(u32, data[instruction..][0..4], .little);
            const shift: u5 = @intCast(mask);
            const value = (raw >> shift) +% current_offset & 0x000f_ffff;
            const encoded = (raw & ~(@as(u32, 0x000f_ffff) << shift)) | (value << shift);
            std.mem.writeInt(u32, data[instruction..][0..4], encoded, .little);
        }
    }
}

fn encodeRgb(
    allocator: std.mem.Allocator,
    data: []u8,
    width: usize,
    red_position: usize,
) Error!void {
    if (data.len < 3 or width == 0 or width % 3 != 0 or width > data.len or red_position > 2)
        return error.InvalidRar29FilterOptions;
    for (red_position..data.len - 2) |position| {
        if ((position - red_position) % 3 != 0) continue;
        const green = data[position + 1];
        data[position] -%= green;
        data[position + 2] -%= green;
    }
    const encoded = try allocator.alloc(u8, data.len);
    defer allocator.free(encoded);
    var destination: usize = 0;
    for (0..3) |channel| {
        var previous: u8 = 0;
        var source = channel;
        while (source < data.len) : (source += 3) {
            const predicted = if (source >= width + 3)
                rgbPredict(previous, data[source - width], data[source - width - 3])
            else
                previous;
            const byte = data[source];
            encoded[destination] = predicted -% byte;
            destination += 1;
            previous = byte;
        }
    }
    @memcpy(data, encoded);
}

fn rgbPredict(previous: u8, upper: u8, upper_left: u8) u8 {
    const predicted = @as(i32, previous) + @as(i32, upper) - @as(i32, upper_left);
    const distance_previous = @abs(predicted - @as(i32, previous));
    const distance_upper = @abs(predicted - @as(i32, upper));
    const distance_upper_left = @abs(predicted - @as(i32, upper_left));
    if (distance_previous <= distance_upper and distance_previous <= distance_upper_left)
        return previous;
    return if (distance_upper <= distance_upper_left) upper else upper_left;
}

fn encodeAudio(allocator: std.mem.Allocator, data: []u8, channels: usize) Error!void {
    const encoded = try allocator.alloc(u8, data.len);
    defer allocator.free(encoded);
    var destination: usize = 0;
    for (0..channels) |channel| {
        var previous_byte: u32 = 0;
        var previous_delta: i32 = 0;
        var delta_1: i32 = 0;
        var delta_2: i32 = 0;
        var coefficient_1: i32 = 0;
        var coefficient_2: i32 = 0;
        var coefficient_3: i32 = 0;
        var differences: [7]u32 = @splat(0);
        var byte_count: usize = 0;
        var source = channel;
        while (source < data.len) : (source += channels) {
            const delta_3 = delta_2;
            delta_2 = previous_delta - delta_1;
            delta_1 = previous_delta;
            const predicted = (8 * @as(i32, @intCast(previous_byte)) +
                coefficient_1 * delta_1 + coefficient_2 * delta_2 +
                coefficient_3 * delta_3) >> 3 & 0xff;
            const decoded = data[source];
            const encoded_byte = @as(u8, @intCast(predicted)) -% decoded;
            encoded[destination] = encoded_byte;
            destination += 1;
            previous_delta = @as(i8, @bitCast(decoded -% @as(u8, @truncate(previous_byte))));
            previous_byte = decoded;
            const difference = @as(i32, @as(i8, @bitCast(encoded_byte))) << 3;
            differences[0] +%= @abs(difference);
            differences[1] +%= @abs(difference - delta_1);
            differences[2] +%= @abs(difference + delta_1);
            differences[3] +%= @abs(difference - delta_2);
            differences[4] +%= @abs(difference + delta_2);
            differences[5] +%= @abs(difference - delta_3);
            differences[6] +%= @abs(difference + delta_3);
            if (byte_count & 0x1f == 0) {
                var minimum = differences[0];
                var minimum_index: usize = 0;
                differences[0] = 0;
                for (differences[1..], 1..) |*value, index| {
                    if (value.* < minimum) {
                        minimum = value.*;
                        minimum_index = index;
                    }
                    value.* = 0;
                }
                switch (minimum_index) {
                    1 => if (coefficient_1 >= -16) {
                        coefficient_1 -= 1;
                    },
                    2 => if (coefficient_1 < 16) {
                        coefficient_1 += 1;
                    },
                    3 => if (coefficient_2 >= -16) {
                        coefficient_2 -= 1;
                    },
                    4 => if (coefficient_2 < 16) {
                        coefficient_2 += 1;
                    },
                    5 => if (coefficient_3 >= -16) {
                        coefficient_3 -= 1;
                    },
                    6 => if (coefficient_3 < 16) {
                        coefficient_3 += 1;
                    },
                    else => {},
                }
            }
            byte_count += 1;
        }
    }
    @memcpy(data, encoded);
}

test "RAR29 standard filter bytecodes have canonical fingerprints" {
    const cases = .{
        .{ &e8_code, @as(u32, 0xad57_6887) },
        .{ &e8e9_code, @as(u32, 0x3cd7_e57e) },
        .{ &delta_code, @as(u32, 0x0e06_077d) },
        .{ &itanium_code, @as(u32, 0x3769_893f) },
        .{ &rgb_code, @as(u32, 0x1c2c_5dc8) },
        .{ &audio_code, @as(u32, 0xbc85_e701) },
    };
    inline for (cases) |case| {
        var xor: u8 = 0;
        for (case[0]) |byte| xor ^= byte;
        try std.testing.expectEqual(@as(u8, 0), xor);
        try std.testing.expectEqual(case[1], checksum.crc32(case[0]));
    }
}

const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidRar29Stream,
    UnsupportedRar29Ppmd,
    UnsupportedRar29Filter,
};

pub const InitialMode = enum { lz, ppmd };

pub fn initialMode(input: []const u8) Error!InitialMode {
    if (input.len == 0) return error.TruncatedFrame;
    return if (input[0] & 0x80 == 0) .lz else .ppmd;
}

const main_count: usize = 299;
const offset_count: usize = 60;
const low_offset_count: usize = 17;
const length_count: usize = 28;
const level_count: usize = 20;
const table_count: usize = main_count + offset_count + low_offset_count + length_count;

const length_bases = [_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224 };
const length_bits = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5 };
const offset_bases = [_]usize{ 0, 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512, 768, 1024, 1536, 2048, 3072, 4096, 6144, 8192, 12288, 16384, 24576, 32768, 49152, 65536, 98304, 131072, 196608, 262144, 327680, 393216, 458752, 524288, 589824, 655360, 720896, 786432, 851968, 917504, 983040, 1048576, 1310720, 1572864, 1835008, 2097152, 2359296, 2621440, 2883584, 3145728, 3407872, 3670016, 3932160 };
const offset_bits = [_]u8{ 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18 };
const short_bases = [_]usize{ 0, 4, 8, 16, 32, 64, 128, 192 };
const short_bits = [_]u8{ 2, 2, 3, 4, 5, 6, 6, 6 };

const BitReader = struct {
    input: []const u8,
    bit_offset: usize = 0,

    fn alignByte(self: *BitReader) Error!void {
        self.bit_offset = std.math.add(usize, self.bit_offset, 7) catch
            return error.IntegerOverflow;
        self.bit_offset &= ~@as(usize, 7);
        if (self.bit_offset > self.input.len * 8) return error.TruncatedFrame;
    }

    fn read(self: *BitReader, count: u8) Error!u32 {
        const value = try self.peek(count);
        self.bit_offset = std.math.add(usize, self.bit_offset, count) catch
            return error.IntegerOverflow;
        return value;
    }

    fn peek(self: BitReader, count: u8) Error!u32 {
        if (count > 24) return error.InvalidRar29Stream;
        const total_bits = std.math.mul(usize, self.input.len, 8) catch
            return error.IntegerOverflow;
        if (self.bit_offset > total_bits or count > total_bits - self.bit_offset)
            return error.TruncatedFrame;
        var value: u32 = 0;
        for (0..count) |index| {
            const bit = self.bit_offset + index;
            value = (value << 1) | ((self.input[bit / 8] >> @intCast(7 - bit % 8)) & 1);
        }
        return value;
    }

    fn remainingZero(self: BitReader) bool {
        const total_bits = self.input.len * 8;
        var bit = self.bit_offset;
        while (bit < total_bits) : (bit += 1)
            if ((self.input[bit / 8] >> @intCast(7 - bit % 8)) & 1 != 0) return false;
        return true;
    }
};

const Huffman = struct {
    symbols: [table_count]u16 = @splat(0),
    symbol_count: usize = 0,
    first_code: [16]u16 = @splat(0),
    first_index: [16]u16 = @splat(0),
    counts: [16]u16 = @splat(0),

    fn init(lengths: []const u8) Error!Huffman {
        if (lengths.len > table_count) return error.InvalidRar29Stream;
        var result = Huffman{};
        for (lengths) |length| {
            if (length > 15) return error.InvalidRar29Stream;
            if (length != 0) result.counts[length] += 1;
        }
        var available: i32 = 1;
        for (result.counts[1..]) |count| {
            available = (available << 1) - count;
            if (available < 0) return error.InvalidRar29Stream;
        }
        var code: u16 = 0;
        var symbol_index: u16 = 0;
        for (1..16) |length| {
            code = (code + result.counts[length - 1]) << 1;
            result.first_code[length] = code;
            result.first_index[length] = symbol_index;
            symbol_index += result.counts[length];
        }
        result.symbol_count = symbol_index;
        var positions = result.first_index;
        for (lengths, 0..) |length, symbol| {
            if (length == 0) continue;
            const destination = positions[length];
            result.symbols[destination] = @intCast(symbol);
            positions[length] += 1;
        }
        return result;
    }

    fn decode(self: *const Huffman, bits: *BitReader) Error!usize {
        if (self.symbol_count == 0) return error.InvalidRar29Stream;
        var code: u16 = 0;
        for (1..16) |length| {
            code = (code << 1) | @as(u16, @intCast(try bits.read(1)));
            const count = self.counts[length];
            if (count == 0) continue;
            const offset = code -% self.first_code[length];
            if (offset < count) return self.symbols[self.first_index[length] + offset];
        }
        return error.InvalidRar29Stream;
    }
};

const BlockEnd = enum { same_file_new_table, new_file_keep_tables, new_file_new_tables };

const Decoder = struct {
    bits: BitReader,
    output: []u8,
    output_offset: usize = 0,
    levels: [table_count]u8 = @splat(0),
    main: Huffman = .{},
    offsets: Huffman = .{},
    low_offsets: Huffman = .{},
    lengths: Huffman = .{},
    old_offsets: [4]usize = @splat(0),
    last_offset: usize = 0,
    last_length: usize = 0,
    last_low_offset: usize = 0,
    low_offset_repeats: usize = 0,
    in_block: bool = false,

    fn decode(self: *Decoder) Error!void {
        while (self.output_offset < self.output.len) {
            if (!self.in_block) {
                try self.readTables();
                self.in_block = true;
            }
            try self.decodeBlock();
        }
        try self.finishMember();
    }

    fn readTables(self: *Decoder) Error!void {
        try self.bits.alignByte();
        if (try self.bits.peek(1) != 0) return error.UnsupportedRar29Ppmd;
        _ = try self.bits.read(1);
        const keep_tables = try self.bits.read(1) != 0;
        self.last_low_offset = 0;
        self.low_offset_repeats = 0;
        if (!keep_tables) self.levels = @splat(0);

        var level_lengths: [level_count]u8 = @splat(0);
        var level_position: usize = 0;
        while (level_position < level_count) {
            const value: u8 = @intCast(try self.bits.read(4));
            if (value == 15) {
                const zeros: usize = try self.bits.read(4);
                if (zeros == 0) {
                    level_lengths[level_position] = 15;
                    level_position += 1;
                } else {
                    level_position = @min(level_count, level_position + zeros + 2);
                }
            } else {
                level_lengths[level_position] = value;
                level_position += 1;
            }
        }
        const level_decoder = try Huffman.init(&level_lengths);
        var new_levels: [table_count]u8 = @splat(0);
        var position: usize = 0;
        while (position < table_count) {
            const symbol = try level_decoder.decode(&self.bits);
            switch (symbol) {
                0...15 => {
                    new_levels[position] = (self.levels[position] +% @as(u8, @intCast(symbol))) & 0x0f;
                    position += 1;
                },
                16 => {
                    if (position == 0) return error.InvalidRar29Stream;
                    fillLevels(
                        &new_levels,
                        &position,
                        @as(usize, try self.bits.read(3)) + 3,
                        new_levels[position - 1],
                    );
                },
                17 => {
                    if (position == 0) return error.InvalidRar29Stream;
                    fillLevels(
                        &new_levels,
                        &position,
                        @as(usize, try self.bits.read(7)) + 11,
                        new_levels[position - 1],
                    );
                },
                18 => fillLevels(
                    &new_levels,
                    &position,
                    @as(usize, try self.bits.read(3)) + 3,
                    0,
                ),
                19 => fillLevels(
                    &new_levels,
                    &position,
                    @as(usize, try self.bits.read(7)) + 11,
                    0,
                ),
                else => return error.InvalidRar29Stream,
            }
        }
        self.levels = new_levels;
        self.main = try Huffman.init(self.levels[0..main_count]);
        self.offsets = try Huffman.init(self.levels[main_count .. main_count + offset_count]);
        self.low_offsets = try Huffman.init(
            self.levels[main_count + offset_count .. main_count + offset_count + low_offset_count],
        );
        self.lengths = try Huffman.init(self.levels[main_count + offset_count + low_offset_count ..]);
    }

    fn decodeBlock(self: *Decoder) Error!void {
        while (self.output_offset < self.output.len and self.in_block) {
            const symbol = try self.main.decode(&self.bits);
            switch (symbol) {
                0...255 => try self.putByte(@intCast(symbol)),
                256 => _ = try self.readBlockEnd(),
                257 => return error.UnsupportedRar29Filter,
                258 => if (self.last_length != 0) try self.copy(self.last_length, self.last_offset),
                259...262 => {
                    const index = symbol - 259;
                    const offset = self.old_offsets[index];
                    const slot = try self.lengths.decode(&self.bits);
                    if (slot >= length_count) return error.InvalidRar29Stream;
                    var length = length_bases[slot] + 2;
                    if (length_bits[slot] != 0) length += try self.bits.read(length_bits[slot]);
                    self.rotateOffset(index);
                    self.last_offset = offset;
                    self.last_length = length;
                    try self.copy(length, offset);
                },
                263...270 => {
                    const index = symbol - 263;
                    var offset = short_bases[index] + 1;
                    if (short_bits[index] != 0) offset += try self.bits.read(short_bits[index]);
                    self.pushOffset(offset);
                    self.last_offset = offset;
                    self.last_length = 2;
                    try self.copy(2, offset);
                },
                271...298 => {
                    const slot = symbol - 271;
                    var length = length_bases[slot] + 3;
                    if (length_bits[slot] != 0) length += try self.bits.read(length_bits[slot]);
                    const offset = try self.readOffset();
                    if (offset >= 0x2000) length += 1;
                    if (offset >= 0x40000) length += 1;
                    self.pushOffset(offset);
                    self.last_offset = offset;
                    self.last_length = length;
                    try self.copy(length, offset);
                },
                else => return error.InvalidRar29Stream,
            }
        }
    }

    fn readOffset(self: *Decoder) Error!usize {
        const slot = try self.offsets.decode(&self.bits);
        if (slot >= offset_count) return error.InvalidRar29Stream;
        var offset = offset_bases[slot] + 1;
        const extra = offset_bits[slot];
        if (extra == 0) return offset;
        if (slot <= 9) return offset + try self.bits.read(extra);
        if (extra > 4) offset += @as(usize, try self.bits.read(extra - 4)) << 4;
        if (self.low_offset_repeats > 0) {
            self.low_offset_repeats -= 1;
            return offset + self.last_low_offset;
        }
        const low = try self.low_offsets.decode(&self.bits);
        if (low == 16) {
            self.low_offset_repeats = 15;
            return offset + self.last_low_offset;
        }
        if (low >= 16) return error.InvalidRar29Stream;
        self.last_low_offset = low;
        return offset + low;
    }

    fn readBlockEnd(self: *Decoder) Error!BlockEnd {
        if (try self.bits.read(1) != 0) {
            self.in_block = false;
            return .same_file_new_table;
        }
        if (try self.bits.read(1) != 0) {
            self.in_block = false;
            return .new_file_new_tables;
        }
        self.in_block = true;
        return .new_file_keep_tables;
    }

    fn finishMember(self: *Decoder) Error!void {
        while (self.in_block) {
            if (try self.main.decode(&self.bits) != 256) return error.TrailingData;
            switch (try self.readBlockEnd()) {
                .same_file_new_table => {
                    if (self.bits.remainingZero()) return;
                    self.readTables() catch |err| switch (err) {
                        error.TruncatedFrame => return,
                        else => return err,
                    };
                    self.in_block = true;
                },
                .new_file_keep_tables, .new_file_new_tables => return,
            }
        }
    }

    fn copy(self: *Decoder, length: usize, raw_offset: usize) Error!void {
        if (length > self.output.len - self.output_offset) return error.SizeMismatch;
        const offset = if (raw_offset == 0) 1 else raw_offset;
        const before_history = offset > self.output_offset;
        for (0..length) |_| {
            const byte: u8 = if (before_history) 0 else self.output[self.output_offset - offset];
            try self.putByte(byte);
        }
    }

    fn putByte(self: *Decoder, byte: u8) Error!void {
        if (self.output_offset == self.output.len) return error.SizeMismatch;
        self.output[self.output_offset] = byte;
        self.output_offset += 1;
    }

    fn pushOffset(self: *Decoder, offset: usize) void {
        self.old_offsets[3] = self.old_offsets[2];
        self.old_offsets[2] = self.old_offsets[1];
        self.old_offsets[1] = self.old_offsets[0];
        self.old_offsets[0] = offset;
    }

    fn rotateOffset(self: *Decoder, index: usize) void {
        const value = self.old_offsets[index];
        var current = index;
        while (current > 0) : (current -= 1) self.old_offsets[current] = self.old_offsets[current - 1];
        self.old_offsets[0] = value;
    }
};

pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    var decoder = Decoder{ .bits = .{ .input = input }, .output = output };
    try decoder.decode();
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
) ![]u8 {
    return decodeAllocLimited(allocator, input, output_len, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
    max_output_len: usize,
) ![]u8 {
    if (output_len > max_output_len) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    try decodeInto(input, output);
    return output;
}

fn fillLevels(levels: *[table_count]u8, position: *usize, count: usize, value: u8) void {
    const end = @min(position.* +| count, levels.len);
    @memset(levels[position.*..end], value);
    position.* = end;
}

test "RAR29 decoder distinguishes truncated LZ PPMd and VM input" {
    var output: [32]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto("", &output));
    // A set first bit selects a PPMd block before any model data is consumed.
    try std.testing.expectError(error.UnsupportedRar29Ppmd, decodeInto(&.{0x80}, &output));
}

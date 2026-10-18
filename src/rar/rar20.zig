const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidRar20Stream,
    MissingRar20SolidState,
    Rar20DecoderPoisoned,
};

const main_count: usize = 298;
const offset_count: usize = 48;
const length_count: usize = 28;
const level_count: usize = 19;
const table_count: usize = main_count + offset_count + length_count;
const audio_count: usize = 257;
const max_channels: usize = 4;
const old_level_count: usize = audio_count * max_channels;
const max_history_size: usize = 1024 * 1024;

const length_bases = [_]usize{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224 };
const length_bits = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5 };
const offset_bases = [_]usize{ 0, 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512, 768, 1024, 1536, 2048, 3072, 4096, 6144, 8192, 12288, 16384, 24576, 32768, 49152, 65536, 98304, 131072, 196608, 262144, 327680, 393216, 458752, 524288, 589824, 655360, 720896, 786432, 851968, 917504, 983040 };
const offset_bits = [_]u8{ 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16 };
const short_bases = [_]usize{ 0, 4, 8, 16, 32, 64, 128, 192 };
const short_bits = [_]u8{ 2, 2, 3, 4, 5, 6, 6, 6 };

const BitReader = struct {
    input: []const u8,
    bit_offset: usize = 0,

    fn read(self: *BitReader, count: u8) Error!u32 {
        const value = try self.peek(count);
        self.bit_offset = std.math.add(usize, self.bit_offset, count) catch
            return error.IntegerOverflow;
        return value;
    }

    fn peek(self: BitReader, count: u8) Error!u32 {
        if (count > 24) return error.InvalidRar20Stream;
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

    fn remainingBits(self: BitReader) Error!usize {
        const total = std.math.mul(usize, self.input.len, 8) catch
            return error.IntegerOverflow;
        if (self.bit_offset > total) return error.TruncatedFrame;
        return total - self.bit_offset;
    }
};

const Huffman = struct {
    symbols: [old_level_count]u16 = @splat(0),
    symbol_count: usize = 0,
    first_code: [16]u16 = @splat(0),
    first_index: [16]u16 = @splat(0),
    counts: [16]u16 = @splat(0),

    fn init(lengths: []const u8) Error!Huffman {
        if (lengths.len > old_level_count) return error.InvalidRar20Stream;
        var result = Huffman{};
        for (lengths) |length| {
            if (length > 15) return error.InvalidRar20Stream;
            if (length != 0) result.counts[length] += 1;
        }
        if (result.counts[1..].len == 0) return error.InvalidRar20Stream;
        var available: i32 = 1;
        for (result.counts[1..]) |count| {
            available = (available << 1) - count;
            if (available < 0) return error.InvalidRar20Stream;
        }

        var code: u16 = 0;
        var index: u16 = 0;
        for (1..16) |length| {
            code = (code + result.counts[length - 1]) << 1;
            result.first_code[length] = code;
            result.first_index[length] = index;
            index += result.counts[length];
        }
        result.symbol_count = index;
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
        if (self.symbol_count == 0) return error.InvalidRar20Stream;
        var code: u16 = 0;
        for (1..16) |length| {
            code = (code << 1) | @as(u16, @intCast(try bits.read(1)));
            const count = self.counts[length];
            if (count == 0) continue;
            const offset = code -% self.first_code[length];
            if (offset < count) return self.symbols[self.first_index[length] + offset];
        }
        return error.InvalidRar20Stream;
    }
};

const AudioState = struct {
    coefficients: [5]i32 = @splat(0),
    d1: i32 = 0,
    d2: i32 = 0,
    d3: i32 = 0,
    d4: i32 = 0,
    last_delta: i32 = 0,
    last_char: i32 = 0,
    byte_count: u32 = 0,
    differences: [11]u32 = @splat(0),
};

const Decoder = struct {
    bits: BitReader,
    output: []u8,
    output_offset: usize = 0,
    levels: [old_level_count]u8 = @splat(0),
    main: Huffman = .{},
    offsets: Huffman = .{},
    lengths: Huffman = .{},
    audio_tables: [max_channels]Huffman = @splat(.{}),
    audio_block: bool = false,
    channels: usize = 1,
    channel: usize = 0,
    audio: [max_channels]AudioState = @splat(.{}),
    channel_delta: i32 = 0,
    old_offsets: [4]usize = @splat(0),
    last_offset: usize = 0,
    last_length: usize = 0,
    in_block: bool = false,

    fn decode(self: *Decoder) Error!void {
        while (self.output_offset < self.output.len) {
            if (!self.in_block) {
                try self.readTables();
                self.in_block = true;
            }
            try self.decodeBlock();
        }
    }

    fn finishMember(self: *Decoder) Error!void {
        if (try self.bits.remainingBits() < 40) return;
        const end_symbol = if (self.audio_block)
            try self.audio_tables[self.channel].decode(&self.bits)
        else
            try self.main.decode(&self.bits);
        const expected = if (self.audio_block) @as(usize, 256) else 269;
        if (end_symbol != expected) return;
        self.in_block = false;
        try self.readTables();
        self.in_block = true;
    }

    fn readTables(self: *Decoder) Error!void {
        const marker = try self.bits.peek(16);
        self.audio_block = marker & 0x8000 != 0;
        const keep_tables = marker & 0x4000 != 0;
        _ = try self.bits.read(2);
        if (!keep_tables) self.levels = @splat(0);

        const table_size = if (self.audio_block) blk: {
            self.channels = @as(usize, @intCast((marker >> 12) & 3)) + 1;
            if (self.channel >= self.channels) self.channel = 0;
            _ = try self.bits.read(2);
            break :blk audio_count * self.channels;
        } else table_count;

        var level_lengths: [level_count]u8 = undefined;
        for (&level_lengths) |*length| length.* = @intCast(try self.bits.read(4));
        const level_decoder = try Huffman.init(&level_lengths);
        var new_levels: [old_level_count]u8 = @splat(0);
        var position: usize = 0;
        while (position < table_size) {
            const symbol = try level_decoder.decode(&self.bits);
            switch (symbol) {
                0...15 => {
                    new_levels[position] = (self.levels[position] +% @as(u8, @intCast(symbol))) & 0x0f;
                    position += 1;
                },
                16 => {
                    if (position == 0) return error.InvalidRar20Stream;
                    const count = @as(usize, try self.bits.read(2)) + 3;
                    fillLevels(&new_levels, &position, count, new_levels[position - 1], table_size);
                },
                17 => fillLevels(
                    &new_levels,
                    &position,
                    @as(usize, try self.bits.read(3)) + 3,
                    0,
                    table_size,
                ),
                18 => fillLevels(
                    &new_levels,
                    &position,
                    @as(usize, try self.bits.read(7)) + 11,
                    0,
                    table_size,
                ),
                else => return error.InvalidRar20Stream,
            }
        }
        self.levels = new_levels;
        if (self.audio_block) {
            for (0..self.channels) |channel| {
                const start = channel * audio_count;
                self.audio_tables[channel] = try Huffman.init(self.levels[start .. start + audio_count]);
            }
        } else {
            self.main = try Huffman.init(self.levels[0..main_count]);
            self.offsets = try Huffman.init(self.levels[main_count .. main_count + offset_count]);
            self.lengths = try Huffman.init(self.levels[main_count + offset_count .. table_count]);
        }
    }

    fn decodeBlock(self: *Decoder) Error!void {
        while (self.output_offset < self.output.len and self.in_block) {
            if (self.audio_block) {
                try self.decodeAudioByte();
                continue;
            }
            const symbol = try self.main.decode(&self.bits);
            switch (symbol) {
                0...255 => try self.putByte(@intCast(symbol)),
                256 => if (self.last_length != 0) {
                    self.pushOffset(self.last_offset);
                    try self.copy(self.last_length, self.last_offset);
                },
                257...260 => {
                    const offset = self.old_offsets[symbol - 257];
                    const slot = try self.lengths.decode(&self.bits);
                    if (slot >= length_count) return error.InvalidRar20Stream;
                    var length = length_bases[slot] + 2;
                    if (length_bits[slot] != 0) length += try self.bits.read(length_bits[slot]);
                    if (offset >= 0x101) length += 1;
                    if (offset >= 0x2000) length += 1;
                    if (offset >= 0x40000) length += 1;
                    self.pushOffset(offset);
                    self.last_offset = offset;
                    self.last_length = length;
                    try self.copy(length, offset);
                },
                261...268 => {
                    const index = symbol - 261;
                    var offset = short_bases[index] + 1;
                    if (short_bits[index] != 0) offset += try self.bits.read(short_bits[index]);
                    self.pushOffset(offset);
                    self.last_offset = offset;
                    self.last_length = 2;
                    try self.copy(2, offset);
                },
                269 => self.in_block = false,
                270...297 => {
                    const slot = symbol - 270;
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
                else => return error.InvalidRar20Stream,
            }
        }
    }

    fn readOffset(self: *Decoder) Error!usize {
        const slot = try self.offsets.decode(&self.bits);
        if (slot >= offset_count) return error.InvalidRar20Stream;
        var offset = offset_bases[slot] + 1;
        if (offset_bits[slot] != 0) offset += try self.bits.read(offset_bits[slot]);
        return offset;
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

    fn decodeAudioByte(self: *Decoder) Error!void {
        const symbol = try self.audio_tables[self.channel].decode(&self.bits);
        if (symbol == 256) {
            self.in_block = false;
            return;
        }
        if (symbol > 255) return error.InvalidRar20Stream;
        const byte = self.decodeAudio(@intCast(symbol));
        try self.putByte(byte);
        self.channel += 1;
        if (self.channel == self.channels) self.channel = 0;
    }

    fn decodeAudio(self: *Decoder, delta: u8) u8 {
        const state = &self.audio[self.channel];
        state.byte_count +%= 1;
        state.d4 = state.d3;
        state.d3 = state.d2;
        state.d2 = state.last_delta -% state.d1;
        state.d1 = state.last_delta;
        var predicted = 8 *% state.last_char;
        const history = [5]i32{ state.d1, state.d2, state.d3, state.d4, self.channel_delta };
        for (state.coefficients, history) |coefficient, difference|
            predicted +%= coefficient *% difference;
        predicted = (predicted >> 3) & 0xff;
        const byte: u8 = @truncate(@as(u32, @bitCast(predicted -% @as(i32, delta))));
        const signed_delta: i32 = @as(i32, @as(i8, @bitCast(delta))) * 8;
        const differences = [_]i32{
            signed_delta,
            signed_delta -% state.d1,
            signed_delta +% state.d1,
            signed_delta -% state.d2,
            signed_delta +% state.d2,
            signed_delta -% state.d3,
            signed_delta +% state.d3,
            signed_delta -% state.d4,
            signed_delta +% state.d4,
            signed_delta -% self.channel_delta,
            signed_delta +% self.channel_delta,
        };
        for (differences, 0..) |difference, index|
            state.differences[index] +%= absoluteUnsigned(difference);
        const last_char: u8 = @intCast(state.last_char);
        self.channel_delta = @as(i32, @as(i8, @bitCast(byte -% last_char)));
        state.last_delta = self.channel_delta;
        state.last_char = byte;
        if (state.byte_count & 0x1f == 0) adjustAudio(state);
        return byte;
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
};

pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    var decoder = Decoder{ .bits = .{ .input = input }, .output = output };
    try decoder.decode();
}

pub const Session = struct {
    allocator: std.mem.Allocator,
    decoder: Decoder,
    history: std.ArrayList(u8) = .empty,
    initialized: bool = false,
    poisoned: bool = false,

    pub fn init(allocator: std.mem.Allocator) Session {
        return .{
            .allocator = allocator,
            .decoder = newDecoder(),
        };
    }

    pub fn deinit(self: *Session) void {
        self.history.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Session) void {
        self.decoder = newDecoder();
        self.history.clearRetainingCapacity();
        self.initialized = false;
        self.poisoned = false;
    }

    pub fn canContinue(self: *const Session) bool {
        return self.initialized and !self.poisoned;
    }

    pub fn decodeMemberInto(
        self: *Session,
        input: []const u8,
        output: []u8,
        dictionary_size: usize,
        solid: bool,
    ) (Error || std.mem.Allocator.Error)!void {
        if (!validDictionarySize(dictionary_size)) return error.InvalidRar20Stream;
        if (!solid)
            self.reset()
        else {
            if (self.poisoned) return error.Rar20DecoderPoisoned;
            if (!self.initialized) return error.MissingRar20SolidState;
        }
        errdefer self.poisoned = true;
        const history_limit = @min(dictionary_size, max_history_size);
        self.trimHistory(history_limit);
        const combined_len = std.math.add(usize, self.history.items.len, output.len) catch
            return error.IntegerOverflow;
        const combined = try self.allocator.alloc(u8, combined_len);
        defer self.allocator.free(combined);
        @memcpy(combined[0..self.history.items.len], self.history.items);
        const member_start = self.history.items.len;

        self.decoder.bits = .{ .input = input };
        self.decoder.output = combined;
        self.decoder.output_offset = member_start;
        defer {
            self.decoder.bits = .{ .input = "" };
            self.decoder.output = undefined;
            self.decoder.output_offset = 0;
        }
        if (output.len == 0 and input.len != 0 and !self.decoder.in_block) {
            try self.decoder.readTables();
            self.decoder.in_block = true;
        }
        try self.decoder.decode();
        if (self.decoder.output_offset != combined.len) return error.SizeMismatch;
        try self.decoder.finishMember();
        @memcpy(output, combined[member_start..]);
        try self.history.appendSlice(self.allocator, output);
        self.trimHistory(history_limit);
        if (input.len != 0) self.initialized = true;
        self.poisoned = false;
    }

    fn trimHistory(self: *Session, limit: usize) void {
        if (self.history.items.len <= limit) return;
        const discard = self.history.items.len - limit;
        @memmove(self.history.items[0..limit], self.history.items[discard..]);
        self.history.items.len = limit;
    }
};

fn newDecoder() Decoder {
    return .{ .bits = .{ .input = "" }, .output = undefined };
}

fn validDictionarySize(size: usize) bool {
    return size >= 64 * 1024 and size <= 4 * 1024 * 1024 and
        std.math.isPowerOfTwo(size);
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

fn fillLevels(
    levels: *[old_level_count]u8,
    position: *usize,
    count: usize,
    value: u8,
    limit: usize,
) void {
    const end = @min(position.* +| count, limit);
    @memset(levels[position.*..end], value);
    position.* = end;
}

fn adjustAudio(state: *AudioState) void {
    var minimum = state.differences[0];
    var selected: usize = 0;
    state.differences[0] = 0;
    for (state.differences[1..], 1..) |*difference, index| {
        if (difference.* < minimum) {
            minimum = difference.*;
            selected = index;
        }
        difference.* = 0;
    }
    switch (selected) {
        1 => if (state.coefficients[0] >= -16) {
            state.coefficients[0] -= 1;
        },
        2 => if (state.coefficients[0] < 16) {
            state.coefficients[0] += 1;
        },
        3 => if (state.coefficients[1] >= -16) {
            state.coefficients[1] -= 1;
        },
        4 => if (state.coefficients[1] < 16) {
            state.coefficients[1] += 1;
        },
        5 => if (state.coefficients[2] >= -16) {
            state.coefficients[2] -= 1;
        },
        6 => if (state.coefficients[2] < 16) {
            state.coefficients[2] += 1;
        },
        7 => if (state.coefficients[3] >= -16) {
            state.coefficients[3] -= 1;
        },
        8 => if (state.coefficients[3] < 16) {
            state.coefficients[3] += 1;
        },
        9 => if (state.coefficients[4] >= -16) {
            state.coefficients[4] -= 1;
        },
        10 => if (state.coefficients[4] < 16) {
            state.coefficients[4] += 1;
        },
        else => {},
    }
}

fn absoluteUnsigned(value: i32) u32 {
    return if (value < 0) @intCast(-@as(i64, value)) else @intCast(value);
}

test "RAR20 decoder rejects truncated tables" {
    var output: [32]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto("", &output));
    try std.testing.expectError(error.TruncatedFrame, decodeInto(&.{ 0, 0 }, &output));
}

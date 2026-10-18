const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidRar15Stream,
    MissingRar15SolidState,
    Rar15DecoderPoisoned,
};

const max_history_size: usize = 64 * 1024;

const dec_l1 = [_]u16{ 0x8000, 0xa000, 0xc000, 0xd000, 0xe000, 0xea00, 0xee00, 0xf000, 0xf200, 0xf200, 0xffff };
const pos_l1 = [_]u16{ 0, 0, 0, 2, 3, 5, 7, 11, 16, 20, 24, 32, 32 };
const dec_l2 = [_]u16{ 0xa000, 0xc000, 0xd000, 0xe000, 0xea00, 0xee00, 0xf000, 0xf200, 0xf240, 0xffff };
const pos_l2 = [_]u16{ 0, 0, 0, 0, 5, 7, 9, 13, 18, 22, 26, 34, 36 };
const dec_hf0 = [_]u16{ 0x8000, 0xc000, 0xe000, 0xf200, 0xf200, 0xf200, 0xf200, 0xf200, 0xffff };
const pos_hf0 = [_]u16{ 0, 0, 0, 0, 0, 8, 16, 24, 33, 33, 33, 33, 33 };
const dec_hf1 = [_]u16{ 0x2000, 0xc000, 0xe000, 0xf000, 0xf200, 0xf200, 0xf7e0, 0xffff };
const pos_hf1 = [_]u16{ 0, 0, 0, 0, 0, 0, 4, 44, 60, 76, 80, 80, 127 };
const dec_hf2 = [_]u16{ 0x1000, 0x2400, 0x8000, 0xc000, 0xfa00, 0xffff, 0xffff, 0xffff };
const pos_hf2 = [_]u16{ 0, 0, 0, 0, 0, 0, 2, 7, 53, 117, 233, 0, 0 };
const dec_hf3 = [_]u16{ 0x0800, 0x2400, 0xee00, 0xfe80, 0xffff, 0xffff, 0xffff };
const pos_hf3 = [_]u16{ 0, 0, 0, 0, 0, 0, 0, 2, 16, 218, 251, 0, 0 };
const dec_hf4 = [_]u16{ 0xff00, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff };
const pos_hf4 = [_]u16{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 0, 0, 0 };

const short_len1 = [_]u8{ 1, 3, 4, 4, 5, 6, 7, 8, 8, 4, 4, 5, 6, 6, 4, 0 };
const short_xor1 = [_]u8{ 0x00, 0xa0, 0xd0, 0xe0, 0xf0, 0xf8, 0xfc, 0xfe, 0xff, 0xc0, 0x80, 0x90, 0x98, 0x9c, 0xb0 };
const short_len2 = [_]u8{ 2, 3, 3, 3, 4, 4, 5, 6, 6, 4, 4, 5, 6, 6, 4, 0 };
const short_xor2 = [_]u8{ 0x00, 0x40, 0x60, 0xa0, 0xd0, 0xe0, 0xf0, 0xf8, 0xfc, 0xc0, 0x80, 0x90, 0x98, 0x9c, 0xb0 };

const BitReader = struct {
    input: []const u8,
    bit_offset: usize = 0,

    fn peek16(self: BitReader) Error!u32 {
        const total_bits = std.math.mul(usize, self.input.len, 8) catch
            return error.IntegerOverflow;
        if (self.bit_offset > total_bits +| 15) return error.TruncatedFrame;
        var value: u32 = 0;
        for (0..16) |index| {
            value <<= 1;
            const bit = self.bit_offset + index;
            if (bit < total_bits)
                value |= (self.input[bit / 8] >> @intCast(7 - bit % 8)) & 1;
        }
        return value;
    }

    fn advance(self: *BitReader, count: usize) Error!void {
        self.bit_offset = std.math.add(usize, self.bit_offset, count) catch
            return error.IntegerOverflow;
    }
};

const Decoder = struct {
    bits: BitReader,
    output: []u8,
    output_offset: usize = 0,
    ch_set: [256]u16 = undefined,
    ch_set_a: [256]u16 = undefined,
    ch_set_b: [256]u16 = undefined,
    ch_set_c: [256]u16 = undefined,
    n_to_pl: [256]u8 = @splat(0),
    n_to_pl_b: [256]u8 = @splat(0),
    n_to_pl_c: [256]u8 = @splat(0),
    avr_plc: u32 = 0x3500,
    avr_plc_b: u32 = 0,
    avr_ln1: u32 = 0,
    avr_ln2: u32 = 0,
    avr_ln3: u32 = 0,
    max_dist3: u32 = 0x2001,
    nhfb: u32 = 0x80,
    nlzb: u32 = 0x80,
    num_huf: u32 = 0,
    buf60: u32 = 0,
    st_mode: bool = false,
    l_count: u32 = 0,
    flag_buf: u32 = 0,
    flags_count: i32 = -2,
    old_dist: [4]u32 = @splat(std.math.maxInt(u32)),
    old_dist_index: usize = 0,
    last_dist: u32 = std.math.maxInt(u32),
    last_length: u32 = 0,

    fn init(input: []const u8, output: []u8) Decoder {
        var self = Decoder{ .bits = .{ .input = input }, .output = output };
        self.initHuffman();
        return self;
    }

    fn decode(self: *Decoder) Error!void {
        while (self.output_offset < self.output.len) try self.step();
    }

    fn step(self: *Decoder) Error!void {
        if (self.flags_count == -2) {
            try self.readFlags();
            self.flags_count = 8;
        }
        if (self.st_mode) return self.decodeHuffman();

        self.flags_count -= 1;
        if (self.flags_count < 0) {
            try self.readFlags();
            self.flags_count = 7;
        }
        if (self.flag_buf & 0x80 != 0) {
            self.flag_buf = (self.flag_buf << 1) & 0xff;
            return if (self.nlzb > self.nhfb) self.decodeLong() else self.decodeHuffman();
        }

        self.flag_buf = (self.flag_buf << 1) & 0xff;
        self.flags_count -= 1;
        if (self.flags_count < 0) {
            try self.readFlags();
            self.flags_count = 7;
        }
        if (self.flag_buf & 0x80 != 0) {
            self.flag_buf = (self.flag_buf << 1) & 0xff;
            return if (self.nlzb > self.nhfb) self.decodeHuffman() else self.decodeLong();
        }
        self.flag_buf = (self.flag_buf << 1) & 0xff;
        return self.decodeShort();
    }

    fn decodeShort(self: *Decoder) Error!void {
        self.num_huf = 0;
        var bit_field = try self.bits.peek16();
        if (self.l_count == 2) {
            try self.bits.advance(1);
            if (bit_field >= 0x8000) return self.copy(self.last_dist, self.last_length);
            bit_field = (bit_field << 1) & 0xffff;
            self.l_count = 0;
        }

        const bit_byte: u8 = @truncate(bit_field >> 8);
        var length_index: usize = 0;
        if (self.avr_ln1 < 37) {
            while (length_index < short_xor1.len) : (length_index += 1) {
                const length = self.shortLength1(length_index);
                const mask: u8 = @truncate(~(@as(u16, 0xff) >> @intCast(length)));
                if ((bit_byte ^ short_xor1[length_index]) & mask == 0) break;
            }
            if (length_index == short_xor1.len) return error.InvalidRar15Stream;
            try self.bits.advance(self.shortLength1(length_index));
        } else {
            while (length_index < short_xor2.len) : (length_index += 1) {
                const length = self.shortLength2(length_index);
                const mask: u8 = @truncate(~(@as(u16, 0xff) >> @intCast(length)));
                if ((bit_byte ^ short_xor2[length_index]) & mask == 0) break;
            }
            if (length_index == short_xor2.len) return error.InvalidRar15Stream;
            try self.bits.advance(self.shortLength2(length_index));
        }

        var length: u32 = @intCast(length_index);
        if (length >= 9) {
            if (length == 9) {
                self.l_count += 1;
                return self.copy(self.last_dist, self.last_length);
            }
            if (length == 14) {
                self.l_count = 0;
                length = try self.decodeNumber(try self.bits.peek16(), 3, &dec_l2, &pos_l2) + 5;
                const distance = (try self.bits.peek16() >> 1) | 0x8000;
                try self.bits.advance(15);
                self.last_length = length;
                self.last_dist = distance;
                return self.copy(distance, length);
            }

            self.l_count = 0;
            const saved = length;
            const distance = self.old_dist[(self.old_dist_index -% @as(usize, length - 9)) & 3];
            length = try self.decodeNumber(try self.bits.peek16(), 2, &dec_l1, &pos_l1) + 2;
            if (length == 0x101 and saved == 10) {
                self.buf60 ^= 1;
                return;
            }
            if (distance > 256) length += 1;
            if (distance >= self.max_dist3) length += 1;
            self.remember(distance, length);
            return self.copy(distance, length);
        }

        self.l_count = 0;
        self.avr_ln1 += length;
        self.avr_ln1 -= self.avr_ln1 >> 4;
        const place = @as(usize, @intCast(try self.decodeNumber(
            try self.bits.peek16(),
            5,
            &dec_hf2,
            &pos_hf2,
        ) & 0xff));
        var distance = @as(u32, self.ch_set_a[place]);
        if (place > 0) {
            self.ch_set_a[place] = self.ch_set_a[place - 1];
            self.ch_set_a[place - 1] = @intCast(distance);
        }
        length += 2;
        distance += 1;
        self.remember(distance, length);
        return self.copy(distance, length);
    }

    fn decodeLong(self: *Decoder) Error!void {
        self.num_huf = 0;
        self.nlzb += 16;
        if (self.nlzb > 0xff) {
            self.nlzb = 0x90;
            self.nhfb >>= 1;
        }
        const old_avr2 = self.avr_ln2;
        const first_bits = try self.bits.peek16();
        var length = if (self.avr_ln2 >= 122)
            try self.decodeNumber(first_bits, 3, &dec_l2, &pos_l2)
        else if (self.avr_ln2 >= 64)
            try self.decodeNumber(first_bits, 2, &dec_l1, &pos_l1)
        else if (first_bits < 0x100) blk: {
            try self.bits.advance(16);
            break :blk first_bits;
        } else blk: {
            var count: u32 = 0;
            while (((first_bits << @intCast(count)) & 0x8000) == 0) : (count += 1) {
                if (count >= 15) return error.InvalidRar15Stream;
            }
            try self.bits.advance(count + 1);
            break :blk count;
        };
        self.avr_ln2 += length;
        self.avr_ln2 -= self.avr_ln2 >> 5;

        const second_bits = try self.bits.peek16();
        const distance_place = if (self.avr_plc_b > 0x28ff)
            try self.decodeNumber(second_bits, 5, &dec_hf2, &pos_hf2)
        else if (self.avr_plc_b > 0x06ff)
            try self.decodeNumber(second_bits, 5, &dec_hf1, &pos_hf1)
        else
            try self.decodeNumber(second_bits, 4, &dec_hf0, &pos_hf0);
        self.avr_plc_b += distance_place;
        self.avr_plc_b -= self.avr_plc_b >> 8;

        const index: usize = @intCast(distance_place & 0xff);
        var distance: u32 = undefined;
        var new_place: usize = undefined;
        while (true) {
            distance = self.ch_set_b[index];
            const rank_index: usize = @intCast(distance & 0xff);
            new_place = self.n_to_pl_b[rank_index];
            self.n_to_pl_b[rank_index] +%= 1;
            distance += 1;
            if (distance & 0xff != 0) break;
            corrHuffman(&self.ch_set_b, &self.n_to_pl_b);
        }
        self.ch_set_b[index] = self.ch_set_b[new_place];
        self.ch_set_b[new_place] = @intCast(distance);

        distance = ((distance & 0xff00) | (try self.bits.peek16() >> 8)) >> 1;
        try self.bits.advance(7);
        const old_avr3 = self.avr_ln3;
        if (length != 1 and length != 4) {
            if (length == 0 and distance <= self.max_dist3) {
                self.avr_ln3 += 1;
                self.avr_ln3 -= self.avr_ln3 >> 8;
            } else if (self.avr_ln3 > 0) self.avr_ln3 -= 1;
        }
        length += 3;
        if (distance >= self.max_dist3) length += 1;
        if (distance <= 256) length += 8;
        self.max_dist3 = if (old_avr3 > 0xb0 or (self.avr_plc >= 0x2a00 and old_avr2 < 0x40))
            0x7f00
        else
            0x2001;
        self.remember(distance, length);
        return self.copy(distance, length);
    }

    fn decodeHuffman(self: *Decoder) Error!void {
        const bit_field = try self.bits.peek16();
        var byte_place = (if (self.avr_plc > 0x75ff)
            try self.decodeNumber(bit_field, 8, &dec_hf4, &pos_hf4)
        else if (self.avr_plc > 0x5dff)
            try self.decodeNumber(bit_field, 6, &dec_hf3, &pos_hf3)
        else if (self.avr_plc > 0x35ff)
            try self.decodeNumber(bit_field, 5, &dec_hf2, &pos_hf2)
        else if (self.avr_plc > 0x0dff)
            try self.decodeNumber(bit_field, 5, &dec_hf1, &pos_hf1)
        else
            try self.decodeNumber(bit_field, 4, &dec_hf0, &pos_hf0)) & 0xff;

        if (self.st_mode) {
            if (byte_place == 0 and bit_field > 0x0fff) byte_place = 0x100;
            if (byte_place == 0) {
                const control = try self.bits.peek16();
                try self.bits.advance(1);
                if (control & 0x8000 != 0) {
                    self.num_huf = 0;
                    self.st_mode = false;
                    return;
                }
                const length: u32 = if (control & 0x4000 != 0) 4 else 3;
                try self.bits.advance(1);
                var distance = try self.decodeNumber(
                    try self.bits.peek16(),
                    5,
                    &dec_hf2,
                    &pos_hf2,
                );
                distance = (distance << 5) | (try self.bits.peek16() >> 11);
                try self.bits.advance(5);
                return self.copy(distance, length);
            }
            byte_place -= 1;
        } else {
            if (self.num_huf >= 16 and self.flags_count == 0) self.st_mode = true;
            self.num_huf += 1;
        }

        self.avr_plc += byte_place;
        self.avr_plc -= self.avr_plc >> 8;
        self.nhfb += 16;
        if (self.nhfb > 0xff) {
            self.nhfb = 0x90;
            self.nlzb >>= 1;
        }
        if (byte_place >= 256) return error.InvalidRar15Stream;
        const index: usize = @intCast(byte_place);
        try self.putByte(@truncate(self.ch_set[index] >> 8));

        var current: u32 = undefined;
        var new_place: usize = undefined;
        while (true) {
            current = self.ch_set[index];
            const rank_index: usize = @intCast(current & 0xff);
            new_place = self.n_to_pl[rank_index];
            self.n_to_pl[rank_index] +%= 1;
            current += 1;
            if (current & 0xff <= 0xa1) break;
            corrHuffman(&self.ch_set, &self.n_to_pl);
        }
        self.ch_set[index] = self.ch_set[new_place];
        self.ch_set[new_place] = @intCast(current);
    }

    fn readFlags(self: *Decoder) Error!void {
        const place = try self.decodeNumber(try self.bits.peek16(), 5, &dec_hf2, &pos_hf2);
        if (place >= 256) return error.InvalidRar15Stream;
        const index: usize = @intCast(place);
        var flags: u32 = undefined;
        var new_place: usize = undefined;
        while (true) {
            flags = self.ch_set_c[index];
            const rank_index: usize = @intCast(flags & 0xff);
            new_place = self.n_to_pl_c[rank_index];
            self.n_to_pl_c[rank_index] +%= 1;
            self.flag_buf = flags >> 8;
            flags += 1;
            if (flags & 0xff != 0) break;
            corrHuffman(&self.ch_set_c, &self.n_to_pl_c);
        }
        self.ch_set_c[index] = self.ch_set_c[new_place];
        self.ch_set_c[new_place] = @intCast(flags);
    }

    fn decodeNumber(
        self: *Decoder,
        raw: u32,
        start_position: u32,
        decode_table: []const u16,
        position_table: []const u16,
    ) Error!u32 {
        const number = raw & 0xfff0;
        var position = start_position;
        var index: usize = 0;
        while (index < decode_table.len and decode_table[index] <= number) : (index += 1)
            position += 1;
        if (index >= decode_table.len or position >= position_table.len or position > 16)
            return error.InvalidRar15Stream;
        try self.bits.advance(position);
        const previous: u32 = if (index == 0) 0 else decode_table[index - 1];
        return ((number - previous) >> @intCast(16 - position)) + position_table[position];
    }

    fn copy(self: *Decoder, distance: u32, length: u32) Error!void {
        const count: usize = length;
        if (count > self.output.len - self.output_offset) return error.SizeMismatch;
        const distance_usize: usize = distance;
        for (0..count) |_| {
            const byte: u8 = if (distance == 0 or distance_usize > 0x10000 or
                distance_usize > self.output_offset)
                0
            else
                self.output[self.output_offset - distance_usize];
            try self.putByte(byte);
        }
    }

    fn putByte(self: *Decoder, byte: u8) Error!void {
        if (self.output_offset == self.output.len) return error.SizeMismatch;
        self.output[self.output_offset] = byte;
        self.output_offset += 1;
    }

    fn remember(self: *Decoder, distance: u32, length: u32) void {
        self.old_dist[self.old_dist_index] = distance;
        self.old_dist_index = (self.old_dist_index + 1) & 3;
        self.last_dist = distance;
        self.last_length = length;
    }

    fn shortLength1(self: *Decoder, index: usize) usize {
        return if (index == 1) self.buf60 + 3 else short_len1[index];
    }

    fn shortLength2(self: *Decoder, index: usize) usize {
        return if (index == 3) self.buf60 + 3 else short_len2[index];
    }

    fn initHuffman(self: *Decoder) void {
        for (0..256) |index| {
            self.ch_set[index] = @as(u16, @intCast(index)) << 8;
            self.ch_set_b[index] = @as(u16, @intCast(index)) << 8;
            self.ch_set_a[index] = @intCast(index);
            self.ch_set_c[index] = @as(u16, 0 -% @as(u8, @intCast(index))) << 8;
        }
        corrHuffman(&self.ch_set_b, &self.n_to_pl_b);
    }
};

pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    var decoder = Decoder.init(input, output);
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
            .decoder = Decoder.init("", undefined),
        };
    }

    pub fn deinit(self: *Session) void {
        self.history.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Session) void {
        self.decoder = Decoder.init("", undefined);
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
        solid: bool,
    ) (Error || std.mem.Allocator.Error)!void {
        if (!solid)
            self.reset()
        else {
            if (self.poisoned) return error.Rar15DecoderPoisoned;
            if (!self.initialized) return error.MissingRar15SolidState;
        }
        errdefer self.poisoned = true;
        self.trimHistory();
        const combined_len = std.math.add(usize, self.history.items.len, output.len) catch
            return error.IntegerOverflow;
        const combined = try self.allocator.alloc(u8, combined_len);
        defer self.allocator.free(combined);
        @memcpy(combined[0..self.history.items.len], self.history.items);
        const member_start = self.history.items.len;

        self.decoder.bits = .{ .input = input };
        self.decoder.output = combined;
        self.decoder.output_offset = member_start;
        self.decoder.flag_buf = 0;
        self.decoder.flags_count = -2;
        self.decoder.st_mode = false;
        self.decoder.l_count = 0;
        defer {
            self.decoder.bits = .{ .input = "" };
            self.decoder.output = undefined;
            self.decoder.output_offset = 0;
        }
        try self.decoder.decode();
        if (self.decoder.output_offset != combined.len) return error.SizeMismatch;
        @memcpy(output, combined[member_start..]);
        try self.history.appendSlice(self.allocator, output);
        self.trimHistory();
        if (input.len != 0) self.initialized = true;
        self.poisoned = false;
    }

    fn trimHistory(self: *Session) void {
        if (self.history.items.len <= max_history_size) return;
        const discard = self.history.items.len - max_history_size;
        @memmove(
            self.history.items[0..max_history_size],
            self.history.items[discard..],
        );
        self.history.items.len = max_history_size;
    }
};

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

fn corrHuffman(char_set: *[256]u16, number_to_place: *[256]u8) void {
    var position: usize = 0;
    var rank: i32 = 7;
    while (rank >= 0) : (rank -= 1) {
        for (0..32) |_| {
            char_set[position] = (char_set[position] & 0xff00) | @as(u16, @intCast(rank));
            position += 1;
        }
    }
    number_to_place.* = @splat(0);
    rank = 6;
    while (rank >= 0) : (rank -= 1)
        number_to_place[@intCast(rank)] = @intCast((7 - rank) * 32);
}

test "RAR15 decoder rejects truncation and output overrun" {
    var large: [1024]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto("", &large));
    var one: [1]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decodeInto("", &one));
}

const std = @import("std");
const core = @import("../core.zig");
const ppmd_h = @import("ppmd_h.zig");
const rar29_vm = @import("rar29_vm.zig");

pub const Error = core.Error || ppmd_h.Error || rar29_vm.Error || error{
    InvalidRar29Stream,
    UnsupportedRar29Ppmd,
    UnsupportedRar29Filter,
    MissingRar29SolidState,
    Rar29DecoderPoisoned,
};

pub const default_max_ppmd_memory: usize = 256 * 1024 * 1024;
pub const default_max_vm_instructions: usize = rar29_vm.default_max_instructions;

pub const DecodeOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_ppmd_memory: usize = default_max_ppmd_memory,
    max_vm_instructions: usize = default_max_vm_instructions,
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
const BlockMode = enum { lz, ppmd };

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
    block_mode: BlockMode = .lz,
    allocator: ?std.mem.Allocator = null,
    ppmd: ?ppmd_h.Session = null,
    vm: ?rar29_vm.State = null,
    max_ppmd_memory: usize = 0,
    max_vm_instructions: usize = 0,

    fn deinit(self: *Decoder) void {
        if (self.ppmd) |*session| session.deinit();
        if (self.vm) |*state| state.deinit();
    }

    fn decode(self: *Decoder) Error!void {
        try self.decodeRaw();
        try self.applyFilters(0);
    }

    fn decodeRaw(self: *Decoder) Error!void {
        while (self.output_offset < self.output.len) {
            if (!self.in_block) {
                try self.readTables();
                self.in_block = true;
            }
            switch (self.block_mode) {
                .lz => try self.decodeBlock(),
                .ppmd => try self.decodePpmd(),
            }
        }
        try self.finishMember();
    }

    fn applyFilters(self: *Decoder, member_start: usize) Error!void {
        if (self.vm) |*state|
            try state.applyMember(self.output[0..self.output_offset], member_start);
    }

    fn readTables(self: *Decoder) Error!void {
        try self.bits.alignByte();
        if (try self.bits.peek(1) != 0) {
            const allocator = self.allocator orelse return error.UnsupportedRar29Ppmd;
            const first_byte: u8 = @intCast(try self.bits.read(8));
            if (self.ppmd == null) self.ppmd = ppmd_h.Session.init(allocator);
            const position = self.bits.bit_offset / 8;
            try self.ppmd.?.startBlock(
                first_byte,
                self.bits.input,
                position,
                self.max_ppmd_memory,
            );
            self.block_mode = .ppmd;
            return;
        }
        _ = try self.bits.read(1);
        self.block_mode = .lz;
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

    fn decodePpmd(self: *Decoder) Error!void {
        while (self.output_offset < self.output.len and self.in_block) {
            const session = if (self.ppmd) |*value| value else return error.InvalidRar29Stream;
            const symbol = (try session.decodeSymbol(self.bits.input)) orelse
                return error.TruncatedFrame;
            if (symbol != session.escape) {
                try self.putByte(symbol);
                continue;
            }
            const control = (try session.decodeSymbol(self.bits.input)) orelse
                return error.TruncatedFrame;
            switch (control) {
                0 => {
                    self.syncPpmd();
                    self.in_block = false;
                },
                1, 6...std.math.maxInt(u8) => try self.putByte(session.escape),
                2 => {
                    self.syncPpmd();
                    self.in_block = false;
                    if (self.output_offset != self.output.len) return error.SizeMismatch;
                },
                3 => try self.readVmCodePpmd(),
                4 => {
                    var offset: usize = 0;
                    for (0..3) |_| offset = (offset << 8) | try self.readPpmdByte();
                    offset += 2;
                    const length = @as(usize, try self.readPpmdByte()) + 32;
                    try self.copy(length, offset);
                },
                5 => {
                    const length = @as(usize, try self.readPpmdByte()) + 4;
                    try self.copy(length, 1);
                },
            }
        }
    }

    fn readPpmdByte(self: *Decoder) Error!u8 {
        const session = if (self.ppmd) |*value| value else return error.InvalidRar29Stream;
        return (try session.decodeSymbol(self.bits.input)) orelse error.TruncatedFrame;
    }

    fn syncPpmd(self: *Decoder) void {
        if (self.ppmd) |session| self.bits.bit_offset = session.position * 8;
    }

    fn decodeBlock(self: *Decoder) Error!void {
        while (self.output_offset < self.output.len and self.in_block) {
            const symbol = try self.main.decode(&self.bits);
            switch (symbol) {
                0...255 => try self.putByte(@intCast(symbol)),
                256 => _ = try self.readBlockEnd(),
                257 => try self.readVmCode(),
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
        if (self.block_mode == .ppmd) return self.finishPpmd();
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

    fn finishPpmd(self: *Decoder) Error!void {
        if (!self.in_block) return;
        const session = if (self.ppmd) |*value| value else return error.InvalidRar29Stream;
        const symbol = (try session.decodeSymbol(self.bits.input)) orelse return;
        if (symbol != session.escape) return error.TrailingData;
        const control = (try session.decodeSymbol(self.bits.input)) orelse return;
        if (control != 0 and control != 2) return error.TrailingData;
        self.syncPpmd();
        self.in_block = false;
    }

    fn readVmCode(self: *Decoder) Error!void {
        const first_byte: u8 = @intCast(try self.bits.read(8));
        var length = @as(usize, first_byte & 7) + 1;
        if (length == 7) {
            length = @as(usize, try self.bits.read(8)) + 7;
        } else if (length == 8) {
            length = try self.bits.read(16);
        }
        const allocator = self.allocator orelse return error.UnsupportedRar29Filter;
        const data = try allocator.alloc(u8, length);
        defer allocator.free(data);
        for (data) |*byte| byte.* = @intCast(try self.bits.read(8));
        try self.parseVmCode(first_byte, data, allocator);
    }

    fn readVmCodePpmd(self: *Decoder) Error!void {
        const first_byte = try self.readPpmdByte();
        var length = @as(usize, first_byte & 7) + 1;
        if (length == 7) {
            length = @as(usize, try self.readPpmdByte()) + 7;
        } else if (length == 8) {
            length = (@as(usize, try self.readPpmdByte()) << 8) |
                try self.readPpmdByte();
        }
        const allocator = self.allocator orelse return error.UnsupportedRar29Filter;
        const data = try allocator.alloc(u8, length);
        defer allocator.free(data);
        for (data) |*byte| byte.* = try self.readPpmdByte();
        try self.parseVmCode(first_byte, data, allocator);
    }

    fn parseVmCode(
        self: *Decoder,
        first_byte: u8,
        data: []const u8,
        allocator: std.mem.Allocator,
    ) Error!void {
        if (self.vm == null)
            self.vm = rar29_vm.State.init(allocator, self.max_vm_instructions);
        const state = if (self.vm) |*value| value else unreachable;
        try state.parseRecord(first_byte, data, self.output_offset);
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

/// Reusable RAR29 state for sequential solid and non-solid members.
///
/// RAR29 filters transform bytes after LZ/PPMd decoding, while the solid
/// dictionary retains the bytes before that transform. The session therefore
/// captures raw member bytes before applying pending VM filters.
pub const Session = struct {
    allocator: std.mem.Allocator,
    options: DecodeOptions,
    decoder: Decoder,
    history: std.ArrayList(u8) = .empty,
    initialized: bool = false,
    poisoned: bool = false,

    pub fn init(allocator: std.mem.Allocator, options: DecodeOptions) Session {
        return .{
            .allocator = allocator,
            .options = options,
            .decoder = newDecoder(allocator, options),
        };
    }

    pub fn deinit(self: *Session) void {
        self.decoder.deinit();
        self.history.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Session) void {
        self.decoder.deinit();
        self.decoder = newDecoder(self.allocator, self.options);
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
    ) Error!void {
        if (output.len > self.options.max_output_len) return error.OutputLimitExceeded;
        if (!validDictionarySize(dictionary_size)) return error.InvalidRar29Stream;
        if (!solid)
            self.reset()
        else {
            if (self.poisoned) return error.Rar29DecoderPoisoned;
            if (!self.initialized) return error.MissingRar29SolidState;
        }
        errdefer self.poisoned = true;
        self.trimHistory(dictionary_size);

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
        try self.decoder.decodeRaw();
        if (self.decoder.output_offset != combined.len) return error.SizeMismatch;

        try self.history.appendSlice(self.allocator, combined[member_start..]);
        self.trimHistory(dictionary_size);
        try self.decoder.applyFilters(member_start);
        @memcpy(output, combined[member_start..]);
        if (input.len != 0) self.initialized = true;
        self.poisoned = false;
    }

    fn trimHistory(self: *Session, dictionary_size: usize) void {
        if (self.history.items.len <= dictionary_size) return;
        const discard = self.history.items.len - dictionary_size;
        @memmove(
            self.history.items[0..dictionary_size],
            self.history.items[discard..],
        );
        self.history.items.len = dictionary_size;
    }
};

fn newDecoder(allocator: std.mem.Allocator, options: DecodeOptions) Decoder {
    return .{
        .bits = .{ .input = "" },
        .output = undefined,
        .allocator = allocator,
        .max_ppmd_memory = options.max_ppmd_memory,
        .max_vm_instructions = options.max_vm_instructions,
    };
}

fn validDictionarySize(dictionary_size: usize) bool {
    return switch (dictionary_size) {
        64 * 1024,
        128 * 1024,
        256 * 1024,
        512 * 1024,
        1024 * 1024,
        2 * 1024 * 1024,
        4 * 1024 * 1024,
        => true,
        else => false,
    };
}

pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    var decoder = Decoder{ .bits = .{ .input = input }, .output = output };
    defer decoder.deinit();
    try decoder.decode();
}

pub fn decodeIntoWithOptions(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: DecodeOptions,
) Error!void {
    if (output.len > options.max_output_len) return error.OutputLimitExceeded;
    var decoder = Decoder{
        .bits = .{ .input = input },
        .output = output,
        .allocator = allocator,
        .max_ppmd_memory = options.max_ppmd_memory,
        .max_vm_instructions = options.max_vm_instructions,
    };
    defer decoder.deinit();
    try decoder.decode();
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
) ![]u8 {
    return decodeAllocWithOptions(allocator, input, output_len, .{});
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
    max_output_len: usize,
) ![]u8 {
    return decodeAllocWithOptions(
        allocator,
        input,
        output_len,
        .{ .max_output_len = max_output_len },
    );
}

pub fn decodeAllocWithOptions(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
    options: DecodeOptions,
) ![]u8 {
    if (output_len > options.max_output_len) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    try decodeIntoWithOptions(allocator, input, output, options);
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

    var one_byte: [1]u8 = undefined;
    try std.testing.expectError(
        error.RarPpmdMemoryLimitExceeded,
        decodeIntoWithOptions(
            std.testing.allocator,
            &.{ 0xa1, 63, 0, 0, 0, 0 },
            &one_byte,
            .{ .max_ppmd_memory = 32 * 1024 * 1024 },
        ),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeIntoWithOptions(
            std.testing.allocator,
            "",
            &output,
            .{ .max_output_len = output.len - 1 },
        ),
    );
}

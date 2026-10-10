const std = @import("std");
const core = @import("../core.zig");
const filters_mod = @import("rar50_filters.zig");

pub const Error = core.Error || filters_mod.Error || error{
    InvalidRar50Stream,
    Rar50DictionaryLimitExceeded,
};

pub const DecodeOptions = struct {
    max_dictionary_size: usize = std.math.maxInt(usize),
};

const level_count: usize = 20;
const main_count: usize = 306;
const distance_count_v0: usize = 64;
const distance_count_v1: usize = 80;
const align_count: usize = 16;
const length_count: usize = 44;
const max_table_count = main_count + distance_count_v1 + align_count + length_count;
const max_filters: usize = 8192;

const MainHuffman = Huffman(main_count);
const DistanceHuffman = Huffman(distance_count_v1);
const AlignHuffman = Huffman(align_count);
const LengthHuffman = Huffman(length_count);
const LevelHuffman = Huffman(level_count);

const Tables = struct {
    main: MainHuffman,
    distance: DistanceHuffman,
    alignment: AlignHuffman,
    length: LengthHuffman,
    align_mode: bool,
};

const Block = struct {
    payload: []const u8,
    payload_bits: usize,
    next_offset: usize,
    is_last: bool,
    has_tables: bool,
};

pub fn decodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    algorithm_version: u8,
    dictionary_size: usize,
    options: DecodeOptions,
) Error!void {
    if (dictionary_size == 0) return error.InvalidRar50Stream;
    if (dictionary_size > options.max_dictionary_size)
        return error.Rar50DictionaryLimitExceeded;
    if (algorithm_version > 1) return error.InvalidRar50Stream;

    var tables: ?Tables = null;
    var repeated_distances: [4]usize = @splat(0);
    var last_length: usize = 0;
    var output_offset: usize = 0;
    var input_offset: usize = 0;
    var first_block = true;
    var pending_filters: std.ArrayList(filters_mod.Filter) = .empty;
    defer pending_filters.deinit(allocator);

    while (first_block or output_offset < output.len) {
        first_block = false;
        const block = try parseBlock(input, input_offset);
        input_offset = block.next_offset;
        var bits = BitReader{
            .input = block.payload,
            .bit_limit = block.payload_bits,
        };
        if (block.has_tables)
            tables = try readTables(&bits, algorithm_version);
        const active = if (tables) |*value| value else return error.InvalidRar50Stream;

        while (bits.bit_offset < bits.bit_limit and output_offset < output.len) {
            const symbol = try active.main.decode(&bits);
            switch (symbol) {
                0...255 => {
                    output[output_offset] = @intCast(symbol);
                    output_offset += 1;
                },
                256 => {
                    if (pending_filters.items.len == max_filters)
                        return error.InvalidRar50Stream;
                    try pending_filters.append(
                        allocator,
                        try readFilter(&bits, output_offset),
                    );
                },
                257 => if (last_length != 0) {
                    try copyMatch(
                        output,
                        &output_offset,
                        repeated_distances[0],
                        last_length,
                        dictionary_size,
                    );
                },
                258...261 => {
                    const repeat_index = symbol - 258;
                    const distance = repeated_distances[repeat_index];
                    if (distance == 0) return error.InvalidRar50Stream;
                    const length_slot = try active.length.decode(&bits);
                    const length_extra = try bits.read(try lengthSlotBits(length_slot));
                    const length = try slotToLength(length_slot, length_extra);
                    var index = repeat_index;
                    while (index != 0) : (index -= 1)
                        repeated_distances[index] = repeated_distances[index - 1];
                    repeated_distances[0] = distance;
                    last_length = length;
                    try copyMatch(
                        output,
                        &output_offset,
                        distance,
                        length,
                        dictionary_size,
                    );
                },
                262...305 => {
                    const length_slot = symbol - 262;
                    const length_extra = try bits.read(try lengthSlotBits(length_slot));
                    var length = try slotToLength(length_slot, length_extra);
                    const distance_slot = try active.distance.decode(&bits);
                    const distance_bits = try distanceSlotBits(distance_slot);
                    const distance_extra: u32 = if (distance_bits >= 4 and active.align_mode) blk: {
                        const high = try bits.read(@intCast(distance_bits - 4));
                        const low = try active.alignment.decode(&bits);
                        break :blk (high << 4) | @as(u32, @intCast(low));
                    } else try bits.read(@intCast(distance_bits));
                    const distance = try slotToDistance(distance_slot, distance_extra);
                    length += lengthBonus(distance);
                    repeated_distances[3] = repeated_distances[2];
                    repeated_distances[2] = repeated_distances[1];
                    repeated_distances[1] = repeated_distances[0];
                    repeated_distances[0] = distance;
                    last_length = length;
                    try copyMatch(
                        output,
                        &output_offset,
                        distance,
                        length,
                        dictionary_size,
                    );
                },
                else => return error.InvalidRar50Stream,
            }
        }
        if (block.is_last or output_offset == output.len) break;
    }
    if (output_offset != output.len) return error.SizeMismatch;
    try filters_mod.applyAll(allocator, output, pending_filters.items);
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
    algorithm_version: u8,
    dictionary_size: usize,
    options: DecodeOptions,
) ![]u8 {
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    try decodeInto(
        allocator,
        input,
        output,
        algorithm_version,
        dictionary_size,
        options,
    );
    return output;
}

fn parseBlock(input: []const u8, offset: usize) Error!Block {
    if (offset > input.len or input.len - offset < 3) return error.TruncatedFrame;
    const flags = input[offset];
    const checksum = input[offset + 1];
    const size_len: usize = switch ((flags >> 3) & 3) {
        0 => 1,
        1 => 2,
        2 => 3,
        else => return error.InvalidRar50Stream,
    };
    if (input.len - offset < 2 + size_len) return error.TruncatedFrame;
    const size_bytes = input[offset + 2 .. offset + 2 + size_len];
    var actual = checksum ^ flags;
    var payload_size: usize = 0;
    for (size_bytes, 0..) |byte, index| {
        actual ^= byte;
        payload_size |= @as(usize, byte) << @intCast(index * 8);
    }
    if (actual != 0x5a) return error.InvalidRar50Stream;
    const payload_start = offset + 2 + size_len;
    const payload_end = std.math.add(usize, payload_start, payload_size) catch
        return error.IntegerOverflow;
    if (payload_end > input.len) return error.TruncatedFrame;
    const payload_bits = if (payload_size == 0)
        0
    else blk: {
        const whole_bytes = std.math.mul(usize, payload_size - 1, 8) catch
            return error.IntegerOverflow;
        break :blk std.math.add(
            usize,
            whole_bytes,
            @as(usize, (flags & 7) + 1),
        ) catch return error.IntegerOverflow;
    };
    return .{
        .payload = input[payload_start..payload_end],
        .payload_bits = payload_bits,
        .next_offset = payload_end,
        .is_last = flags & 0x40 != 0,
        .has_tables = flags & 0x80 != 0,
    };
}

fn readTables(bits: *BitReader, algorithm_version: u8) Error!Tables {
    var level_lengths: [level_count]u8 = @splat(0);
    var level_position: usize = 0;
    while (level_position < level_count) {
        const length: u8 = @intCast(try bits.read(4));
        if (length == 15) {
            const zero_count = try bits.read(4);
            if (zero_count == 0) {
                level_lengths[level_position] = 15;
                level_position += 1;
            } else {
                level_position = @min(level_count, level_position + zero_count + 2);
            }
        } else {
            level_lengths[level_position] = length;
            level_position += 1;
        }
    }
    const level_decoder = try LevelHuffman.init(&level_lengths);
    const distance_count = if (algorithm_version == 0)
        distance_count_v0
    else
        distance_count_v1;
    const table_count = main_count + distance_count + align_count + length_count;
    var lengths: [max_table_count]u8 = @splat(0);
    var position: usize = 0;
    while (position < table_count) {
        const number = try level_decoder.decode(bits);
        switch (number) {
            0...15 => {
                lengths[position] = @intCast(number);
                position += 1;
            },
            16, 17 => {
                if (position == 0) return error.InvalidRar50Stream;
                const count = if (number == 16)
                    @as(usize, try bits.read(3)) + 3
                else
                    @as(usize, try bits.read(7)) + 11;
                const end = @min(table_count, position +| count);
                @memset(lengths[position..end], lengths[position - 1]);
                position = end;
            },
            18, 19 => {
                const count = if (number == 18)
                    @as(usize, try bits.read(3)) + 3
                else
                    @as(usize, try bits.read(7)) + 11;
                position = @min(table_count, position +| count);
            },
            else => return error.InvalidRar50Stream,
        }
    }
    const distance_start = main_count;
    const align_start = distance_start + distance_count;
    const length_start = align_start + align_count;
    var align_mode = false;
    for (lengths[align_start..length_start]) |length|
        if (length != 0 and length != 4) {
            align_mode = true;
            break;
        };
    return .{
        .main = try MainHuffman.init(lengths[0..distance_start]),
        .distance = try DistanceHuffman.init(lengths[distance_start..align_start]),
        .alignment = try AlignHuffman.init(lengths[align_start..length_start]),
        .length = try LengthHuffman.init(lengths[length_start..table_count]),
        .align_mode = align_mode,
    };
}

fn readFilter(bits: *BitReader, current_position: usize) Error!filters_mod.Filter {
    const offset = @as(usize, try readFilterData(bits));
    const length = @as(usize, try readFilterData(bits));
    const kind: filters_mod.Kind = switch (try bits.read(3)) {
        0 => .delta,
        1 => .e8,
        2 => .e8e9,
        3 => .arm,
        else => return error.InvalidRar50Stream,
    };
    return .{
        .start = std.math.add(usize, current_position, offset) catch
            return error.IntegerOverflow,
        .length = length,
        .kind = kind,
        .channels = if (kind == .delta) @as(usize, try bits.read(5)) + 1 else 0,
    };
}

fn readFilterData(bits: *BitReader) Error!u32 {
    const byte_count = try bits.read(2) + 1;
    var value: u32 = 0;
    for (0..byte_count) |index|
        value |= try bits.read(8) << @intCast(index * 8);
    return value;
}

fn copyMatch(
    output: []u8,
    output_offset: *usize,
    distance: usize,
    length: usize,
    dictionary_size: usize,
) Error!void {
    if (length > output.len - output_offset.*) return error.SizeMismatch;
    const before_history = distance == 0 or distance > dictionary_size or
        distance > output_offset.*;
    for (0..length) |_| {
        output[output_offset.*] = if (before_history)
            0
        else
            output[output_offset.* - distance];
        output_offset.* += 1;
    }
}

fn lengthSlotBits(slot: usize) Error!u8 {
    if (slot < 8) return 0;
    const count = (slot >> 2) - 1;
    if (count > 24) return error.InvalidRar50Stream;
    return @intCast(count);
}

fn slotToLength(slot: usize, extra: u32) Error!usize {
    if (slot < 8) return slot + 2;
    const bit_count = (slot >> 2) - 1;
    if (bit_count > 24 or extra >= (@as(u32, 1) << @intCast(bit_count)))
        return error.InvalidRar50Stream;
    return (((4 | (slot & 3)) << @intCast(bit_count)) | extra) + 2;
}

fn distanceSlotBits(slot: usize) Error!usize {
    if (slot < 4) return 0;
    const count = (slot - 2) >> 1;
    if (count > 31) return error.InvalidRar50Stream;
    return count;
}

fn slotToDistance(slot: usize, extra: u32) Error!usize {
    if (slot < 4) return slot + 1;
    const bit_count = try distanceSlotBits(slot);
    const max_extra: u32 = if (bit_count == 32)
        std.math.maxInt(u32)
    else
        (@as(u32, 1) << @intCast(bit_count)) - 1;
    if (extra > max_extra) return error.InvalidRar50Stream;
    return (((2 | (slot & 1)) << @intCast(bit_count)) | extra) + 1;
}

fn lengthBonus(distance: usize) usize {
    return @as(usize, @intFromBool(distance > 0x100)) +
        @as(usize, @intFromBool(distance > 0x2000)) +
        @as(usize, @intFromBool(distance > 0x40000));
}

fn Huffman(comptime capacity: usize) type {
    return struct {
        symbols: [capacity]u16 = @splat(0),
        symbol_count: usize = 0,
        first_code: [16]u16 = @splat(0),
        first_index: [16]u16 = @splat(0),
        counts: [16]u16 = @splat(0),

        const Self = @This();

        fn init(lengths: []const u8) Error!Self {
            if (lengths.len > capacity) return error.InvalidRar50Stream;
            var result = Self{};
            for (lengths) |length| {
                if (length > 15) return error.InvalidRar50Stream;
                if (length != 0) result.counts[length] += 1;
            }
            var available: i32 = 1;
            for (result.counts[1..]) |count| {
                available = (available << 1) - count;
                if (available < 0) return error.InvalidRar50Stream;
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
                result.symbols[positions[length]] = @intCast(symbol);
                positions[length] += 1;
            }
            return result;
        }

        fn decode(self: *const Self, bits: *BitReader) Error!usize {
            if (self.symbol_count == 0) return error.InvalidRar50Stream;
            var code: u16 = 0;
            for (1..16) |length| {
                code = (code << 1) | @as(u16, @intCast(try bits.read(1)));
                const count = self.counts[length];
                if (count == 0) continue;
                const delta = code -% self.first_code[length];
                if (delta < count)
                    return self.symbols[self.first_index[length] + delta];
            }
            return error.InvalidRar50Stream;
        }
    };
}

const BitReader = struct {
    input: []const u8,
    bit_offset: usize = 0,
    bit_limit: usize,

    fn read(self: *BitReader, count: u8) Error!u32 {
        const end = std.math.add(usize, self.bit_offset, count) catch
            return error.IntegerOverflow;
        if (end > self.bit_limit or self.bit_limit > self.input.len * 8)
            return error.TruncatedFrame;
        var value: u32 = 0;
        for (0..count) |index| {
            const bit = self.bit_offset + index;
            value = value *% 2 |
                ((self.input[bit / 8] >> @intCast(7 - bit % 8)) & 1);
        }
        self.bit_offset = end;
        return value;
    }
};

test "RAR50 block parser validates header checksum and truncation" {
    try std.testing.expectError(error.TruncatedFrame, parseBlock(&.{}, 0));
    try std.testing.expectError(
        error.InvalidRar50Stream,
        parseBlock(&.{ 0x40, 0, 0 }, 0),
    );
    const flags: u8 = 0x40;
    const size: u8 = 0;
    const checksum = 0x5a ^ flags ^ size;
    const block = try parseBlock(&.{ flags, checksum, size }, 0);
    try std.testing.expect(block.is_last);
    try std.testing.expectEqual(@as(usize, 0), block.payload_bits);
}

test "RAR50 length and distance slots decode boundaries" {
    try std.testing.expectEqual(@as(usize, 2), try slotToLength(0, 0));
    try std.testing.expectEqual(@as(usize, 10), try slotToLength(8, 0));
    try std.testing.expectEqual(@as(usize, 1), try slotToDistance(0, 0));
    try std.testing.expectEqual(@as(usize, 5), try slotToDistance(4, 0));
}

test "RAR50 decoder enforces dictionary limit before reading blocks" {
    try std.testing.expectError(
        error.Rar50DictionaryLimitExceeded,
        decodeInto(
            std.testing.allocator,
            &.{},
            &.{},
            0,
            1024 * 1024,
            .{ .max_dictionary_size = 512 * 1024 },
        ),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        decodeInto(std.testing.allocator, &.{}, &.{}, 0, 128 * 1024, .{}),
    );
}

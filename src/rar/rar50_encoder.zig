const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidRar50EncodeOptions,
};

pub const Options = struct {
    dictionary_size: usize = 128 * 1024,
    block_size: usize = 64 * 1024,
};

const main_count: usize = 306;
const distance_count: usize = 64;
const align_count: usize = 16;
const length_count: usize = 44;
const level_count: usize = 20;
const min_match: usize = 4;
const max_match: usize = 4096;
const hash_size: usize = 1 << 16;
pub const max_block_size: usize = 4 * 1024 * 1024;

const Token = union(enum) {
    literal: u8,
    match: struct { length: usize, distance: usize },
};

const MatchState = struct {
    distances: [4]usize = @splat(0),
    last_length: usize = 0,

    fn remember(self: *MatchState, length: usize, distance: usize) void {
        if (distance == self.distances[0] and length == self.last_length) return;
        var found: ?usize = null;
        for (self.distances, 0..) |old, index|
            if (old == distance) {
                found = index;
                break;
            };
        if (found) |index| {
            var current = index;
            while (current != 0) : (current -= 1)
                self.distances[current] = self.distances[current - 1];
        } else {
            self.distances[3] = self.distances[2];
            self.distances[2] = self.distances[1];
            self.distances[1] = self.distances[0];
        }
        self.distances[0] = distance;
        self.last_length = length;
    }
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
) Error![]u8 {
    if (options.dictionary_size < 128 * 1024 or options.block_size == 0 or
        options.block_size > max_block_size)
        return error.InvalidRar50EncodeOptions;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var state = MatchState{};
    if (input.len == 0) {
        try encodeBlock(allocator, &output, input, options, &state, true);
    } else {
        var start: usize = 0;
        while (start < input.len) {
            const end = @min(input.len, start +| options.block_size);
            try encodeBlock(
                allocator,
                &output,
                input[start..end],
                options,
                &state,
                end == input.len,
            );
            start = end;
        }
    }
    return output.toOwnedSlice(allocator);
}

fn encodeBlock(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: Options,
    state: *MatchState,
    is_last: bool,
) Error!void {
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(allocator);
    try tokenize(allocator, &tokens, input, options.dictionary_size);

    var writer = BitWriter{ .allocator = allocator };
    defer writer.bytes.deinit(allocator);
    const level_lengths = fixedLevelLengths();
    const main_lengths = fixedMainLengths();
    const distance_lengths: [distance_count]u8 = @splat(6);
    const alignment_lengths: [align_count]u8 = @splat(4);
    const length_lengths = fixedLengthLengths();
    const level_codes = try Codes(level_count).init(&level_lengths);
    const main_codes = try Codes(main_count).init(&main_lengths);
    const distance_codes = try Codes(distance_count).init(&distance_lengths);
    const alignment_codes = try Codes(align_count).init(&alignment_lengths);
    const length_codes = try Codes(length_count).init(&length_lengths);

    for (level_lengths) |length| try writer.writeBits(length, 4);
    try writeTableRuns(&writer, &level_codes, &main_lengths);
    try writeTableRuns(&writer, &level_codes, &distance_lengths);
    try writeTableRuns(&writer, &level_codes, &alignment_lengths);
    try writeTableRuns(&writer, &level_codes, &length_lengths);

    for (tokens.items) |token| switch (token) {
        .literal => |byte| try writer.writeCode(&main_codes, byte),
        .match => |match| {
            const distance = match.distance;
            const length = match.length;
            if (distance == state.distances[0] and length == state.last_length and
                state.last_length != 0)
            {
                try writer.writeCode(&main_codes, 257);
            } else if (repeatIndex(state.distances, distance)) |index| {
                try writer.writeCode(&main_codes, 258 + index);
                const length_data = try lengthSlot(length);
                try writer.writeCode(&length_codes, length_data.slot);
                try writer.writeBits(length_data.extra, length_data.extra_bits);
            } else {
                const encoded_length = length - lengthBonus(distance);
                const length_data = try lengthSlot(encoded_length);
                const distance_data = try distanceSlot(distance);
                try writer.writeCode(&main_codes, 262 + length_data.slot);
                try writer.writeBits(length_data.extra, length_data.extra_bits);
                try writer.writeCode(&distance_codes, distance_data.slot);
                if (distance_data.extra_bits >= 4) {
                    try writer.writeBits(
                        distance_data.extra >> 4,
                        distance_data.extra_bits - 4,
                    );
                    try writer.writeCode(&alignment_codes, distance_data.extra & 0x0f);
                } else {
                    try writer.writeBits(distance_data.extra, distance_data.extra_bits);
                }
            }
            state.remember(length, distance);
        },
    };
    try appendCompressedBlock(
        allocator,
        output,
        writer.bytes.items,
        writer.bit_offset,
        is_last,
    );
}

fn tokenize(
    allocator: std.mem.Allocator,
    tokens: *std.ArrayList(Token),
    input: []const u8,
    dictionary_size: usize,
) Error!void {
    const heads = try allocator.alloc(usize, hash_size);
    defer allocator.free(heads);
    @memset(heads, std.math.maxInt(usize));
    var position: usize = 0;
    while (position < input.len) {
        var best_length: usize = 0;
        var best_distance: usize = 0;
        if (position + min_match <= input.len) {
            const hash = hashAt(input, position);
            const previous = heads[hash];
            heads[hash] = position;
            if (previous != std.math.maxInt(usize)) {
                const distance = position - previous;
                if (distance <= dictionary_size) {
                    const length = matchLength(
                        input,
                        position,
                        distance,
                        @min(max_match, input.len - position),
                    );
                    const required = @max(min_match, 2 + lengthBonus(distance));
                    if (length >= required) {
                        best_length = length;
                        best_distance = distance;
                    }
                }
            }
        }
        if (best_length < min_match) {
            try tokens.append(allocator, .{ .literal = input[position] });
            position += 1;
            continue;
        }
        try tokens.append(allocator, .{ .match = .{
            .length = best_length,
            .distance = best_distance,
        } });
        const match_end = position + best_length;
        position += 1;
        while (position < match_end) : (position += 1) {
            if (position + min_match <= input.len)
                heads[hashAt(input, position)] = position;
        }
    }
}

fn hashAt(input: []const u8, position: usize) usize {
    const value = std.mem.readInt(u32, input[position..][0..4], .little);
    return @truncate((value *% 0x9e37_79b1) >> 16);
}

fn matchLength(input: []const u8, position: usize, distance: usize, limit: usize) usize {
    var length: usize = 0;
    while (length < limit and input[position + length] == input[position + length - distance])
        length += 1;
    return length;
}

fn repeatIndex(distances: [4]usize, distance: usize) ?usize {
    for (distances, 0..) |old, index|
        if (old == distance and old != 0) return index;
    return null;
}

const Slot = struct {
    slot: usize,
    extra: usize,
    extra_bits: u8,
};

fn lengthSlot(length: usize) Error!Slot {
    if (length < 2) return error.InvalidRar50EncodeOptions;
    const value = length - 2;
    if (value < 8) return .{ .slot = value, .extra = 0, .extra_bits = 0 };
    const bit_count = std.math.log2_int(usize, value) - 2;
    const slot = ((bit_count + 1) << 2) |
        ((value >> bit_count) & 3);
    if (slot >= length_count) return error.InvalidRar50EncodeOptions;
    return .{
        .slot = slot,
        .extra = value & ((@as(usize, 1) << bit_count) - 1),
        .extra_bits = @intCast(bit_count),
    };
}

fn distanceSlot(distance: usize) Error!Slot {
    if (distance == 0) return error.InvalidRar50EncodeOptions;
    const value = distance - 1;
    if (value < 4) return .{ .slot = value, .extra = 0, .extra_bits = 0 };
    const bit_count = std.math.log2_int(usize, value) - 1;
    const slot = (bit_count << 1) + 2 + ((value >> bit_count) & 1);
    if (slot >= distance_count) return error.InvalidRar50EncodeOptions;
    return .{
        .slot = slot,
        .extra = value & ((@as(usize, 1) << bit_count) - 1),
        .extra_bits = @intCast(bit_count),
    };
}

fn lengthBonus(distance: usize) usize {
    return @as(usize, @intFromBool(distance > 0x100)) +
        @as(usize, @intFromBool(distance > 0x2000)) +
        @as(usize, @intFromBool(distance > 0x40000));
}

fn fixedLevelLengths() [level_count]u8 {
    var lengths: [level_count]u8 = undefined;
    @memset(lengths[0..12], 4);
    @memset(lengths[12..], 5);
    return lengths;
}

fn fixedMainLengths() [main_count]u8 {
    var lengths: [main_count]u8 = undefined;
    @memset(lengths[0..206], 8);
    @memset(lengths[206..], 9);
    return lengths;
}

fn fixedLengthLengths() [length_count]u8 {
    var lengths: [length_count]u8 = undefined;
    @memset(lengths[0..20], 5);
    @memset(lengths[20..], 6);
    return lengths;
}

fn writeTableRuns(
    writer: *BitWriter,
    level_codes: *const Codes(level_count),
    lengths: []const u8,
) Error!void {
    var position: usize = 0;
    while (position < lengths.len) {
        const value = lengths[position];
        var run: usize = 1;
        while (position + run < lengths.len and lengths[position + run] == value)
            run += 1;
        if (value == 0) {
            var remaining = run;
            while (remaining >= 11) {
                const count = @min(remaining, 138);
                try writer.writeCode(level_codes, 19);
                try writer.writeBits(count - 11, 7);
                remaining -= count;
            }
            while (remaining >= 3) {
                const count = @min(remaining, 10);
                try writer.writeCode(level_codes, 18);
                try writer.writeBits(count - 3, 3);
                remaining -= count;
            }
            while (remaining != 0) : (remaining -= 1)
                try writer.writeCode(level_codes, 0);
        } else {
            try writer.writeCode(level_codes, value);
            var remaining = run - 1;
            while (remaining >= 11) {
                const count = @min(remaining, 138);
                try writer.writeCode(level_codes, 17);
                try writer.writeBits(count - 11, 7);
                remaining -= count;
            }
            while (remaining >= 3) {
                const count = @min(remaining, 10);
                try writer.writeCode(level_codes, 16);
                try writer.writeBits(count - 3, 3);
                remaining -= count;
            }
            while (remaining != 0) : (remaining -= 1)
                try writer.writeCode(level_codes, value);
        }
        position += run;
    }
}

fn appendCompressedBlock(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    payload: []const u8,
    payload_bits: usize,
    is_last: bool,
) Error!void {
    if (payload.len == 0 or payload.len > 0x00ff_ffff or
        payload_bits <= (payload.len - 1) * 8 or payload_bits > payload.len * 8)
        return error.InvalidRar50EncodeOptions;
    const size_len: usize = if (payload.len <= 0xff)
        1
    else if (payload.len <= 0xffff)
        2
    else
        3;
    const final_bits: u8 = @intCast((payload_bits - 1) % 8 + 1);
    var flags: u8 = final_bits - 1;
    flags |= @as(u8, @intCast(size_len - 1)) << 3;
    flags |= 0x80;
    if (is_last) flags |= 0x40;
    var size_bytes: [3]u8 = @splat(0);
    var remaining = payload.len;
    for (size_bytes[0..size_len]) |*byte| {
        byte.* = @truncate(remaining);
        remaining >>= 8;
    }
    var checksum: u8 = 0x5a ^ flags;
    for (size_bytes[0..size_len]) |byte| checksum ^= byte;
    try output.append(allocator, flags);
    try output.append(allocator, checksum);
    try output.appendSlice(allocator, size_bytes[0..size_len]);
    try output.appendSlice(allocator, payload);
}

fn Codes(comptime count: usize) type {
    return struct {
        codes: [count]u16,
        lengths: [count]u8,

        const Self = @This();

        fn init(lengths: *const [count]u8) Error!Self {
            var counts: [16]u16 = @splat(0);
            for (lengths) |length| {
                if (length > 15) return error.InvalidRar50EncodeOptions;
                if (length != 0) counts[length] += 1;
            }
            var available: i32 = 1;
            for (counts[1..]) |length_count_value| {
                available = (available << 1) - length_count_value;
                if (available < 0) return error.InvalidRar50EncodeOptions;
            }
            var next: [16]u16 = @splat(0);
            var code: u16 = 0;
            for (1..16) |length| {
                code = (code + counts[length - 1]) << 1;
                next[length] = code;
            }
            var result = Self{ .codes = @splat(0), .lengths = lengths.* };
            for (lengths, 0..) |length, symbol| {
                if (length == 0) continue;
                result.codes[symbol] = next[length];
                next[length] += 1;
            }
            return result;
        }
    };
}

const BitWriter = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,
    bit_offset: usize = 0,

    fn writeCode(self: *BitWriter, codes: anytype, symbol: usize) Error!void {
        if (symbol >= codes.lengths.len or codes.lengths[symbol] == 0)
            return error.InvalidRar50EncodeOptions;
        try self.writeBits(codes.codes[symbol], codes.lengths[symbol]);
    }

    fn writeBits(self: *BitWriter, value: anytype, raw_count: anytype) Error!void {
        const count: usize = @intCast(raw_count);
        if (count == 0) return;
        const bits: u64 = @intCast(value);
        var index: usize = count;
        while (index != 0) {
            index -= 1;
            if (self.bit_offset % 8 == 0) try self.bytes.append(self.allocator, 0);
            if (bits & (@as(u64, 1) << @intCast(index)) != 0)
                self.bytes.items[self.bytes.items.len - 1] |=
                    @as(u8, 1) << @intCast(7 - self.bit_offset % 8);
            self.bit_offset += 1;
        }
    }
};

test "RAR50 encoder round trips repetitive and empty data" {
    const decoder = @import("rar50.zig");
    const inputs = [_][]const u8{ "", "abcd" ** 1024 };
    for (inputs) |input| {
        const encoded = try encodeAlloc(std.testing.allocator, input, .{});
        defer std.testing.allocator.free(encoded);
        const output = try std.testing.allocator.alloc(u8, input.len);
        defer std.testing.allocator.free(output);
        try decoder.decodeInto(
            std.testing.allocator,
            encoded,
            output,
            0,
            128 * 1024,
            .{},
        );
        try std.testing.expectEqualSlices(u8, input, output);
    }
}

const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidRar50EncodeOptions,
};

pub const Options = struct {
    dictionary_size: usize = 128 * 1024,
    block_size: usize = 64 * 1024,
    filter: ?Filter = null,
};

pub const Filter = union(enum) {
    delta: u8,
    e8,
    e8e9,
    arm,
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
    filter: FilterRecord,
    literal: u8,
    match: struct { length: usize, distance: usize },
};

const FilterRecord = struct {
    length: usize,
    kind: Filter,
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
    try validateOptions(options);
    if (input.len == 0 and options.filter != null)
        return error.InvalidRar50EncodeOptions;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var state = MatchState{};
    if (input.len == 0) {
        try encodeBlock(allocator, &output, input, 0, options, &state, true);
    } else {
        var start: usize = 0;
        const block_size = if (options.filter == null)
            options.block_size
        else
            @min(options.block_size, 0x3ffff);
        while (start < input.len) {
            const end = @min(input.len, start +| block_size);
            try encodeBlock(
                allocator,
                &output,
                input[start..end],
                start,
                options,
                &state,
                end == input.len,
            );
            start = end;
        }
    }
    return output.toOwnedSlice(allocator);
}

pub fn validateOptions(options: Options) Error!void {
    if (options.dictionary_size < 128 * 1024 or options.block_size == 0 or
        options.block_size > max_block_size)
        return error.InvalidRar50EncodeOptions;
    if (options.filter) |filter| try validateFilter(filter);
}

fn encodeBlock(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    file_offset: usize,
    options: Options,
    state: *MatchState,
    is_last: bool,
) Error!void {
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(allocator);
    var transformed: ?[]u8 = null;
    defer if (transformed) |bytes| allocator.free(bytes);
    if (options.filter) |filter| {
        transformed = try allocator.dupe(u8, input);
        try encodeFilter(allocator, transformed.?, filter, file_offset);
        try tokens.append(allocator, .{ .filter = .{
            .length = input.len,
            .kind = filter,
        } });
    }
    try tokenize(
        allocator,
        &tokens,
        transformed orelse input,
        options.dictionary_size,
    );

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
        .filter => |filter| {
            try writer.writeCode(&main_codes, 256);
            try writeFilter(&writer, filter);
        },
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

fn validateFilter(filter: Filter) Error!void {
    switch (filter) {
        .delta => |channels| if (channels == 0 or channels > 32)
            return error.InvalidRar50EncodeOptions,
        .e8, .e8e9, .arm => {},
    }
}

fn encodeFilter(
    allocator: std.mem.Allocator,
    data: []u8,
    filter: Filter,
    file_offset: usize,
) Error!void {
    switch (filter) {
        .delta => |channels| {
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
        },
        .e8 => encodeE8E9(data, @truncate(file_offset), false),
        .e8e9 => encodeE8E9(data, @truncate(file_offset), true),
        .arm => encodeArm(data, @truncate(file_offset)),
    }
}

const x86_file_size: u32 = 0x0100_0000;

fn encodeE8E9(data: []u8, file_offset: u32, include_e9: bool) void {
    if (data.len <= 4) return;
    const compare_mask: u8 = if (include_e9) 0xfe else 0xff;
    var position: usize = 0;
    while (position < data.len - 4) {
        position += 1;
        if (data[position - 1] & compare_mask != 0xe8) continue;
        const offset = (file_offset +% @as(u32, @truncate(position))) % x86_file_size;
        const address = std.mem.readInt(u32, data[position..][0..4], .little);
        const candidate = address +% offset;
        const encoded: ?u32 = if (candidate < x86_file_size)
            candidate
        else blk: {
            const wrapped = address -% x86_file_size;
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

fn encodeArm(data: []u8, file_offset: u32) void {
    var position: usize = 0;
    while (position + 3 < data.len) : (position += 4) {
        if (data[position + 3] != 0xeb) continue;
        var offset = @as(u32, data[position]) |
            (@as(u32, data[position + 1]) << 8) |
            (@as(u32, data[position + 2]) << 16);
        offset +%= (file_offset +% @as(u32, @truncate(position))) / 4;
        data[position] = @truncate(offset);
        data[position + 1] = @truncate(offset >> 8);
        data[position + 2] = @truncate(offset >> 16);
    }
}

fn writeFilter(writer: *BitWriter, filter: FilterRecord) Error!void {
    try writeFilterData(writer, 0);
    try writeFilterData(writer, filter.length);
    switch (filter.kind) {
        .delta => |channels| {
            try writer.writeBits(0, 3);
            try writer.writeBits(channels - 1, 5);
        },
        .e8 => try writer.writeBits(1, 3),
        .e8e9 => try writer.writeBits(2, 3),
        .arm => try writer.writeBits(3, 3),
    }
}

fn writeFilterData(writer: *BitWriter, raw_value: usize) Error!void {
    if (raw_value > std.math.maxInt(u32)) return error.InvalidRar50EncodeOptions;
    const value: u32 = @intCast(raw_value);
    const byte_count: u8 = if (value <= 0xff)
        1
    else if (value <= 0xffff)
        2
    else if (value <= 0x00ff_ffff)
        3
    else
        4;
    try writer.writeBits(byte_count - 1, 2);
    for (0..byte_count) |index|
        try writer.writeBits(value >> @intCast(index * 8) & 0xff, 8);
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

test "RAR50 encoder round trips all native filters across blocks" {
    const decoder = @import("rar50.zig");
    var input: [8192]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @truncate(index *% 37);
    input[16] = 0xe8;
    std.mem.writeInt(u32, input[17..21], 0x1000, .little);
    input[32] = 0xe9;
    std.mem.writeInt(u32, input[33..37], 0x2000, .little);
    input[64..68].* = .{ 4, 0, 0, 0xeb };
    const filter_cases = [_]Filter{
        .{ .delta = 4 },
        .e8,
        .e8e9,
        .arm,
    };
    for (filter_cases) |filter| {
        const encoded = try encodeAlloc(std.testing.allocator, &input, .{
            .block_size = 1024,
            .filter = filter,
        });
        defer std.testing.allocator.free(encoded);
        var output: [input.len]u8 = undefined;
        try decoder.decodeInto(
            std.testing.allocator,
            encoded,
            &output,
            0,
            128 * 1024,
            .{},
        );
        try std.testing.expectEqualSlices(u8, &input, &output);
    }
    try std.testing.expectError(
        error.InvalidRar50EncodeOptions,
        encodeAlloc(std.testing.allocator, &input, .{ .filter = .{ .delta = 0 } }),
    );
}

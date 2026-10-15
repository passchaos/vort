const std = @import("std");
const incremental = @import("reduce/incremental_decoder.zig");

pub const Error = incremental.Error || std.mem.Allocator.Error || error{
    InvalidReduceOptions,
};

pub const Factor = incremental.Factor;
pub const IncrementalDecoder = incremental.Decoder;
pub const IncrementalWorkspace = incremental.Workspace;

pub const Options = struct {
    max_chain: u16 = 64,
};

pub const dle: u8 = 144;

const BitReader = struct {
    input: []const u8,
    byte_offset: usize = 0,
    reservoir: u64 = 0,
    bit_count: u8 = 0,

    fn read(self: *BitReader, count: u4) Error!u8 {
        if (count == 0) return 0;
        while (self.bit_count < count) {
            if (self.byte_offset == self.input.len) return error.TruncatedReduceInput;
            self.reservoir |= @as(u64, self.input[self.byte_offset]) << @intCast(self.bit_count);
            self.byte_offset += 1;
            self.bit_count += 8;
        }
        const result: u8 = @truncate(self.reservoir & ((@as(u64, 1) << count) - 1));
        self.reservoir >>= count;
        self.bit_count -= count;
        return result;
    }

    fn finish(self: *const BitReader) Error!void {
        if (self.byte_offset != self.input.len) return error.ReduceTrailingData;
    }
};

const BitWriter = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    reservoir: u64 = 0,
    bit_count: u8 = 0,

    fn write(self: *BitWriter, value: u8, count: u4) Error!void {
        if (count == 0) return;
        std.debug.assert(value < @as(u16, 1) << count);
        self.reservoir |= @as(u64, value) << @intCast(self.bit_count);
        self.bit_count += count;
        while (self.bit_count >= 8) {
            try self.output.append(self.allocator, @truncate(self.reservoir));
            self.reservoir >>= 8;
            self.bit_count -= 8;
        }
    }

    fn finish(self: *BitWriter) Error!void {
        if (self.bit_count != 0)
            try self.output.append(self.allocator, @truncate(self.reservoir));
        self.reservoir = 0;
        self.bit_count = 0;
    }
};

pub const FollowerTable = struct {
    counts: [256]u8 = @splat(0),
    symbols: [256][32]u8 = @splat(@splat(0)),

    fn parse(reader: *BitReader) Error!FollowerTable {
        var result = FollowerTable{};
        var previous: usize = 256;
        while (previous != 0) {
            previous -= 1;
            const count = try reader.read(6);
            if (count > 32) return error.InvalidReduceStream;
            result.counts[previous] = count;
            for (result.symbols[previous][0..count]) |*symbol|
                symbol.* = try reader.read(8);
        }
        return result;
    }
};

pub fn followerBits(count: u8) u4 {
    if (count <= 1) return 0;
    return @intCast(std.math.log2_int_ceil(u8, count));
}

fn nextReducedByte(
    reader: *BitReader,
    followers: *const FollowerTable,
    last_character: *u8,
) Error!u8 {
    const count = followers.counts[last_character.*];
    const byte = if (count == 0)
        try reader.read(8)
    else if (try reader.read(1) != 0)
        try reader.read(8)
    else selected: {
        const index = try reader.read(followerBits(count));
        if (index >= count) return error.InvalidReduceStream;
        break :selected followers.symbols[last_character.*][index];
    };
    last_character.* = byte;
    return byte;
}

pub fn decodeInto(input: []const u8, output: []u8, factor: Factor) Error!void {
    var reader = BitReader{ .input = input };
    const followers = try FollowerTable.parse(&reader);
    const factor_bits: u4 = @intFromEnum(factor);
    const length_bits: u4 = 8 - factor_bits;
    const length_mask: u8 = (@as(u8, 1) << @intCast(length_bits)) - 1;
    var last_character: u8 = 0;
    var state: u2 = 0;
    var match_control: u8 = 0;
    var match_length: usize = 0;
    var output_offset: usize = 0;

    while (output_offset < output.len) {
        const byte = try nextReducedByte(&reader, &followers, &last_character);
        switch (state) {
            0 => {
                if (byte == dle) {
                    state = 1;
                } else {
                    output[output_offset] = byte;
                    output_offset += 1;
                }
            },
            1 => {
                if (byte == 0) {
                    output[output_offset] = dle;
                    output_offset += 1;
                    state = 0;
                } else {
                    match_control = byte;
                    match_length = byte & length_mask;
                    state = if (match_length == length_mask) 2 else 3;
                }
            },
            2 => {
                match_length += byte;
                state = 3;
            },
            3 => {
                const distance = (@as(usize, match_control >> @intCast(length_bits)) << 8) + byte + 1;
                const length = match_length + 3;
                if (length > output.len - output_offset) return error.ReduceSizeMismatch;
                for (0..length) |_| {
                    output[output_offset] = if (distance <= output_offset)
                        output[output_offset - distance]
                    else
                        0;
                    output_offset += 1;
                }
                state = 0;
            },
        }
    }
    if (state != 0) return error.ReduceSizeMismatch;
    try reader.finish();
}

fn appendLiteral(intermediate: *std.ArrayList(u8), allocator: std.mem.Allocator, byte: u8) Error!void {
    try intermediate.append(allocator, byte);
    if (byte == dle) try intermediate.append(allocator, 0);
}

fn hashAt(input: []const u8, position: usize) usize {
    return ((@as(usize, input[position]) * 251 + input[position + 1]) * 251 +
        input[position + 2]) & 0xffff;
}

fn insertPosition(input: []const u8, position: usize, heads: []i32, previous: []i32) void {
    if (input.len - position < 3) return;
    const hash = hashAt(input, position);
    previous[position % previous.len] = heads[hash];
    heads[hash] = @intCast(position);
}

const Match = struct { length: usize = 0, distance: usize = 0 };

fn findMatch(
    input: []const u8,
    position: usize,
    maximum_length: usize,
    window_size: usize,
    max_chain: usize,
    heads: []const i32,
    previous: []const i32,
) Match {
    if (input.len - position < 4 or max_chain == 0) return .{};
    var candidate = heads[hashAt(input, position)];
    var remaining = max_chain;
    var best = Match{};
    while (candidate >= 0 and remaining != 0) : (remaining -= 1) {
        const source: usize = @intCast(candidate);
        const distance = position - source;
        if (distance == 0 or distance > window_size) break;
        var length: usize = 0;
        const limit = @min(maximum_length, input.len - position);
        while (length < limit and input[source + length] == input[position + length])
            length += 1;
        if (length > best.length and length >= 4) {
            best = .{ .length = length, .distance = distance };
            if (length == limit) break;
        }
        candidate = previous[source % previous.len];
    }
    return best;
}

fn buildIntermediate(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    factor: Factor,
    options: Options,
) Error!void {
    const factor_bits: u4 = @intFromEnum(factor);
    const length_bits: u4 = 8 - factor_bits;
    const length_mask: usize = (@as(usize, 1) << length_bits) - 1;
    const window_size: usize = @as(usize, 1) << @intCast(8 + factor_bits);
    const maximum_length = length_mask + 255 + 3;
    const heads = try allocator.alloc(i32, 1 << 16);
    defer allocator.free(heads);
    @memset(heads, -1);
    const previous = try allocator.alloc(i32, window_size);
    defer allocator.free(previous);
    @memset(previous, -1);

    var position: usize = 0;
    while (position < input.len) {
        const match = findMatch(
            input,
            position,
            maximum_length,
            window_size,
            options.max_chain,
            heads,
            previous,
        );
        if (match.length < 4) {
            try appendLiteral(output, allocator, input[position]);
            insertPosition(input, position, heads, previous);
            position += 1;
            continue;
        }

        const stored_length = match.length - 3;
        const stored_distance = match.distance - 1;
        const low_length = @min(stored_length, length_mask);
        const control: u8 = @intCast(
            ((stored_distance >> 8) << length_bits) | low_length,
        );
        try output.appendSlice(allocator, &.{ dle, control });
        if (low_length == length_mask)
            try output.append(allocator, @intCast(stored_length - length_mask));
        try output.append(allocator, @truncate(stored_distance));
        for (0..match.length) |offset|
            insertPosition(input, position + offset, heads, previous);
        position += match.length;
    }
}

fn trainFollowersFromIntermediate(
    allocator: std.mem.Allocator,
    intermediate: []const u8,
) Error!FollowerTable {
    const transition_counts = try allocator.alloc(u32, 256 * 256);
    defer allocator.free(transition_counts);
    @memset(transition_counts, 0);
    var previous: u8 = 0;
    for (intermediate) |byte| {
        transition_counts[@as(usize, previous) * 256 + byte] += 1;
        previous = byte;
    }

    var followers = FollowerTable{};
    for (0..256) |context| {
        var selected: [256]bool = @splat(false);
        var count: usize = 0;
        while (count < 32) : (count += 1) {
            var best_symbol: ?u8 = null;
            var best_count: u32 = 0;
            for (0..256) |symbol| {
                if (selected[symbol]) continue;
                const frequency = transition_counts[context * 256 + symbol];
                if (frequency > best_count) {
                    best_count = frequency;
                    best_symbol = @intCast(symbol);
                }
            }
            if (best_symbol == null or best_count == 0) break;
            followers.symbols[context][count] = best_symbol.?;
            selected[best_symbol.?] = true;
        }
        followers.counts[context] = @intCast(count);
    }
    return followers;
}

/// Trains the exact follower table used by `encodeAppend` after applying the
/// same factor-specific DLE match plan. Callers can reuse the returned table
/// with the incremental encoder when a replayable prepass is available.
pub fn trainFollowerTable(
    allocator: std.mem.Allocator,
    input: []const u8,
    factor: Factor,
    options: Options,
) Error!FollowerTable {
    if (options.max_chain == 0) return error.InvalidReduceOptions;
    var intermediate: std.ArrayList(u8) = .empty;
    defer intermediate.deinit(allocator);
    try buildIntermediate(allocator, &intermediate, input, factor, options);
    return trainFollowersFromIntermediate(allocator, intermediate.items);
}

fn followerIndex(followers: *const FollowerTable, previous: u8, byte: u8) ?u8 {
    for (followers.symbols[previous][0..followers.counts[previous]], 0..) |candidate, index|
        if (candidate == byte) return @intCast(index);
    return null;
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    factor: Factor,
    options: Options,
) Error!usize {
    if (options.max_chain == 0) return error.InvalidReduceOptions;
    const start = output.items.len;
    errdefer output.items.len = start;
    var intermediate: std.ArrayList(u8) = .empty;
    defer intermediate.deinit(allocator);
    try buildIntermediate(allocator, &intermediate, input, factor, options);
    const followers = try trainFollowersFromIntermediate(allocator, intermediate.items);
    var writer = BitWriter{ .allocator = allocator, .output = output };

    var context: usize = 256;
    while (context != 0) {
        context -= 1;
        const count = followers.counts[context];
        try writer.write(count, 6);
        for (followers.symbols[context][0..count]) |symbol|
            try writer.write(symbol, 8);
    }

    var previous: u8 = 0;
    for (intermediate.items) |byte| {
        const count = followers.counts[previous];
        if (count == 0) {
            try writer.write(byte, 8);
        } else if (followerIndex(&followers, previous, byte)) |index| {
            try writer.write(0, 1);
            try writer.write(index, followerBits(count));
        } else {
            try writer.write(1, 1);
            try writer.write(byte, 8);
        }
        previous = byte;
    }
    try writer.finish();
    return output.items.len - start;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    factor: Factor,
    options: Options,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, factor, options);
    return output.toOwnedSlice(allocator);
}

test "ZIP Reduce round trips all factors DLE literals and matches" {
    const input = ("Reduce follower payload\x90\n" ** 256) ++ ([_]u8{ 0, 1, 2, 3, 4, 5 } ** 256);
    inline for (std.meta.tags(Factor)) |factor| {
        const encoded = try encodeAlloc(std.testing.allocator, input, factor, .{});
        defer std.testing.allocator.free(encoded);
        const decoded = try std.testing.allocator.alloc(u8, input.len);
        defer std.testing.allocator.free(decoded);
        try decodeInto(encoded, decoded, factor);
        try std.testing.expectEqualSlices(u8, input, decoded);
        try std.testing.expect(encoded.len < input.len);
    }
}

test "ZIP Reduce decoder handles zero history and rejects invalid follower indexes" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .allocator = std.testing.allocator, .output = &encoded };
    for (0..256) |_| try writer.write(0, 6);
    inline for (.{ dle, @as(u8, 1), @as(u8, 3) }) |byte| try writer.write(byte, 8);
    try writer.finish();
    var output: [4]u8 = undefined;
    try decodeInto(encoded.items, &output, .factor_1);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, &output);

    encoded.clearRetainingCapacity();
    writer = .{ .allocator = std.testing.allocator, .output = &encoded };
    var context: usize = 256;
    while (context != 0) {
        context -= 1;
        if (context == 0) {
            try writer.write(3, 6);
            inline for (.{ @as(u8, 'A'), @as(u8, 'B'), @as(u8, 'C') }) |byte|
                try writer.write(byte, 8);
        } else {
            try writer.write(0, 6);
        }
    }
    try writer.write(0, 1);
    try writer.write(3, 2);
    try writer.finish();
    try std.testing.expectError(error.InvalidReduceStream, decodeInto(encoded.items, output[0..1], .factor_1));
}

test "ZIP Reduce rejects truncation size mismatch and trailing data" {
    const encoded = try encodeAlloc(std.testing.allocator, "reduce payload", .factor_4, .{});
    defer std.testing.allocator.free(encoded);
    var output: ["reduce payload".len]u8 = undefined;
    try std.testing.expectError(
        error.TruncatedReduceInput,
        decodeInto(encoded[0 .. encoded.len - 1], &output, .factor_4),
    );
    try std.testing.expectError(
        error.ReduceTrailingData,
        decodeInto(encoded, output[0 .. output.len - 1], .factor_4),
    );
    var trailing = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(trailing);
    trailing = try std.testing.allocator.realloc(trailing, trailing.len + 1);
    trailing[trailing.len - 1] = 0;
    try std.testing.expectError(error.ReduceTrailingData, decodeInto(trailing, &output, .factor_4));
}

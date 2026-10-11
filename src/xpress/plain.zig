const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{InvalidXpress};

pub const EncodeOptions = struct {};

pub const Summary = struct {
    encoded_size: usize,
    decoded_size: usize,
    literals: usize,
    matches: usize,
    matched_bytes: usize,
};

const window_size: usize = 8192;
const hash_table_len: usize = 4096;
const no_position = std.math.maxInt(usize);
const max_chain: usize = 256;

pub fn encodedBound(input_len: usize) Error!usize {
    if (input_len == 0) return 0;
    const token_slots = std.math.add(usize, input_len, 1) catch
        return error.IntegerOverflow;
    const flag_words = (std.math.add(usize, token_slots, 31) catch
        return error.IntegerOverflow) / 32;
    const flag_bytes = std.math.mul(usize, flag_words, 4) catch
        return error.IntegerOverflow;
    return std.math.add(usize, input_len, flag_bytes) catch return error.IntegerOverflow;
}

pub fn summarize(input: []const u8) Error!Summary {
    return summarizeLimited(input, std.math.maxInt(usize));
}

pub fn summarizeLimited(input: []const u8, max_output_len: usize) Error!Summary {
    return walk(input, null, max_output_len);
}

pub fn decodedSize(input: []const u8) Error!usize {
    return (try summarize(input)).decoded_size;
}

pub fn decodedSizeLimited(input: []const u8, max_output_len: usize) Error!usize {
    return (try summarizeLimited(input, max_output_len)).decoded_size;
}

pub fn decodeInto(input: []const u8, output: []u8) Error!usize {
    const size = try decodedSize(input);
    if (size > output.len) return error.OutputTooSmall;
    const result = try walk(input, output[0..size], size);
    if (result.decoded_size != size) return error.SizeMismatch;
    return size;
}

pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return decodeAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) Error![]u8 {
    const size = try decodedSizeLimited(input, max_output_len);
    const output = try allocator.alloc(u8, size);
    errdefer allocator.free(output);
    const written = try decodeInto(input, output);
    if (written != size) return error.SizeMismatch;
    return output;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) Error!usize {
    _ = options;
    if (input.len == 0) return 0;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encodeStream(allocator, &encoded, input);
    try output.ensureUnusedCapacity(allocator, encoded.items.len);
    output.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: EncodeOptions,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn walk(input: []const u8, output: ?[]u8, max_output_len: usize) Error!Summary {
    var summary = Summary{
        .encoded_size = input.len,
        .decoded_size = 0,
        .literals = 0,
        .matches = 0,
        .matched_bytes = 0,
    };
    if (input.len == 0) return summary;
    var input_offset: usize = 0;
    var flags: u32 = 0;
    var flags_remaining: u6 = 0;
    var last_length_half_byte: ?usize = null;
    while (true) {
        if (flags_remaining == 0) {
            if (input_offset == input.len) return summary;
            if (input.len - input_offset < 4) return error.TruncatedFrame;
            flags = std.mem.readInt(u32, input[input_offset..][0..4], .little);
            input_offset += 4;
            flags_remaining = 32;
        }
        const is_match = flags & 0x8000_0000 != 0;
        flags <<= 1;
        flags_remaining -= 1;
        if (!is_match) {
            if (input_offset == input.len) return error.TruncatedFrame;
            try addOutput(&summary.decoded_size, 1, max_output_len);
            if (output) |bytes| bytes[summary.decoded_size - 1] = input[input_offset];
            input_offset += 1;
            summary.literals += 1;
            continue;
        }

        if (input_offset == input.len) return summary;
        if (input.len - input_offset < 2) return error.TruncatedFrame;
        const token = std.mem.readInt(u16, input[input_offset..][0..2], .little);
        input_offset += 2;
        const distance: usize = @as(usize, token >> 3) + 1;
        if (distance > summary.decoded_size) return error.InvalidMatch;
        var length: usize = token & 7;
        if (length == 7) {
            const nibble: u8 = if (last_length_half_byte) |offset| blk: {
                last_length_half_byte = null;
                break :blk input[offset] >> 4;
            } else blk: {
                if (input_offset == input.len) return error.TruncatedFrame;
                last_length_half_byte = input_offset;
                const value = input[input_offset] & 0x0f;
                input_offset += 1;
                break :blk value;
            };
            if (nibble < 15) {
                length = @as(usize, nibble) + 10;
            } else {
                if (input_offset == input.len) return error.TruncatedFrame;
                const byte_length = input[input_offset];
                input_offset += 1;
                if (byte_length < 255) {
                    length = @as(usize, byte_length) + 25;
                } else {
                    if (input.len - input_offset < 2) return error.TruncatedFrame;
                    var wide_length: u64 = std.mem.readInt(
                        u16,
                        input[input_offset..][0..2],
                        .little,
                    );
                    input_offset += 2;
                    if (wide_length == 0) {
                        if (input.len - input_offset < 4) return error.TruncatedFrame;
                        wide_length = std.mem.readInt(
                            u32,
                            input[input_offset..][0..4],
                            .little,
                        );
                        input_offset += 4;
                    }
                    if (wide_length < 22) return error.InvalidXpress;
                    length = std.math.cast(usize, wide_length + 3) orelse
                        return error.IntegerOverflow;
                }
            }
        } else {
            length += 3;
        }
        try addOutput(&summary.decoded_size, length, max_output_len);
        if (output) |bytes| {
            var position = summary.decoded_size - length;
            while (position < summary.decoded_size) : (position += 1)
                bytes[position] = bytes[position - distance];
        }
        summary.matches += 1;
        summary.matched_bytes = std.math.add(usize, summary.matched_bytes, length) catch
            return error.IntegerOverflow;
    }
}

fn addOutput(offset: *usize, amount: usize, limit: usize) Error!void {
    const end = std.math.add(usize, offset.*, amount) catch return error.IntegerOverflow;
    if (end > limit) return error.OutputLimitExceeded;
    offset.* = end;
}

const Match = struct {
    distance: usize = 0,
    length: usize = 0,
};

const MatchIndex = struct {
    allocator: std.mem.Allocator,
    heads: []usize,
    previous: []usize,

    fn init(allocator: std.mem.Allocator, input_len: usize) Error!MatchIndex {
        const heads = try allocator.alloc(usize, hash_table_len);
        errdefer allocator.free(heads);
        const previous = try allocator.alloc(usize, @min(input_len, window_size));
        @memset(heads, no_position);
        @memset(previous, no_position);
        return .{ .allocator = allocator, .heads = heads, .previous = previous };
    }

    fn deinit(self: *MatchIndex) void {
        self.allocator.free(self.previous);
        self.allocator.free(self.heads);
        self.* = undefined;
    }

    fn insert(self: *MatchIndex, input: []const u8, position: usize) void {
        if (input.len - position < 3 or self.previous.len == 0) return;
        const hash_value = hash(input[position..][0..3]);
        self.previous[position % self.previous.len] = self.heads[hash_value];
        self.heads[hash_value] = position;
    }

    fn find(self: MatchIndex, input: []const u8, position: usize) Match {
        if (input.len - position < 3 or position == 0 or self.previous.len == 0)
            return .{};
        const max_distance = @min(position, window_size);
        const max_length = @min(input.len - position, std.math.maxInt(u32));
        var best = Match{};
        var candidate = self.heads[hash(input[position..][0..3])];
        var searched: usize = 0;
        while (candidate != no_position and searched < max_chain) : (searched += 1) {
            const distance = position - candidate;
            if (distance > max_distance) break;
            if (std.mem.eql(u8, input[candidate..][0..3], input[position..][0..3])) {
                var length: usize = 3;
                while (length < max_length and
                    input[candidate + length] == input[position + length])
                    length += 1;
                if (length > best.length) {
                    best = .{ .distance = distance, .length = length };
                    if (length == max_length) break;
                }
            }
            candidate = self.previous[candidate % self.previous.len];
        }
        return best;
    }
};

const LengthWriter = struct {
    half_byte_offset: ?usize = null,

    fn append(
        self: *LengthWriter,
        allocator: std.mem.Allocator,
        output: *std.ArrayList(u8),
        length: usize,
    ) Error!void {
        if (length < 10) return;
        const nibble: u8 = if (length <= 24) @intCast(length - 10) else 15;
        if (self.half_byte_offset) |offset| {
            output.items[offset] |= nibble << 4;
            self.half_byte_offset = null;
        } else {
            self.half_byte_offset = output.items.len;
            try output.append(allocator, nibble);
        }
        if (nibble != 15) return;
        if (length <= 279) {
            try output.append(allocator, @intCast(length - 25));
        } else if (length - 3 <= std.math.maxInt(u16)) {
            try output.append(allocator, 255);
            try appendU16(allocator, output, @intCast(length - 3));
        } else {
            if (length - 3 > std.math.maxInt(u32)) return error.InvalidBlockPlan;
            try output.append(allocator, 255);
            try appendU16(allocator, output, 0);
            try appendU32(allocator, output, @intCast(length - 3));
        }
    }
};

fn encodeStream(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!void {
    var index = try MatchIndex.init(allocator, input.len);
    defer index.deinit();
    var length_writer = LengthWriter{};
    var position: usize = 0;
    while (true) {
        if (position == input.len) {
            try appendU32(allocator, output, std.math.maxInt(u32));
            return;
        }
        const flags_offset = output.items.len;
        try appendU32(allocator, output, 0);
        var flags: u32 = 0;
        var entities: usize = 0;
        while (entities < 32 and position < input.len) : (entities += 1) {
            const match = index.find(input, position);
            const consumed = if (match.length >= 3) blk: {
                flags |= @as(u32, 1) << @intCast(31 - entities);
                const token = (@as(u16, @intCast(match.distance - 1)) << 3) |
                    @as(u16, @intCast(@min(match.length - 3, 7)));
                try appendU16(allocator, output, token);
                try length_writer.append(allocator, output, match.length);
                break :blk match.length;
            } else blk: {
                try output.append(allocator, input[position]);
                break :blk 1;
            };
            const end = position + consumed;
            while (position < end) : (position += 1) index.insert(input, position);
        }
        if (position == input.len and entities < 32)
            flags |= (@as(u32, 1) << @intCast(32 - entities)) - 1;
        std.mem.writeInt(u32, output.items[flags_offset..][0..4], flags, .little);
        if (position == input.len and entities < 32) return;
    }
}

fn hash(bytes: *const [3]u8) usize {
    return (@as(usize, bytes[0]) *% 0x1e35_a7bd +%
        @as(usize, bytes[1]) *% 0x9e37_79b1 +% bytes[2]) & (hash_table_len - 1);
}

fn appendU16(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn appendU32(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn fillPseudoRandom(output: []u8) void {
    var state: u32 = 0x1234_5678;
    for (output) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
}

test "XPRESS plain reproduces the MS-XCA example" {
    const expected = &.{
        0xff, 0xff, 0xff, 0x1f, 'a', 'b', 'c', 0x17, 0x00, 0x0f, 0xff, 0x26, 0x01,
    };
    const input = "abc" ** 100;
    const decoded = try decodeAlloc(std.testing.allocator, expected);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    const encoded = try encodeAlloc(std.testing.allocator, input, .{});
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, expected, encoded);
}

test "XPRESS plain round trips literals matches and extended lengths" {
    const allocator = std.testing.allocator;
    var random: [9000]u8 = undefined;
    fillPseudoRandom(&random);
    const repeated = "XPRESS plain repeated payload 0123456789\n" ** 400;
    const cases = [_][]const u8{
        "",
        "tiny",
        &random,
        repeated,
        "a" ** 11,
        "b" ** 25,
        "c" ** 26,
        "d" ** 280,
        "e" ** 281,
        "f" ** 70_000,
    };
    for (cases) |input| {
        const encoded = try encodeAlloc(allocator, input, .{});
        defer allocator.free(encoded);
        try std.testing.expect(encoded.len <= try encodedBound(input.len));
        const summary = try summarize(encoded);
        try std.testing.expectEqual(input.len, summary.decoded_size);
        const decoded = try decodeAllocLimited(allocator, encoded, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        const into = try allocator.alloc(u8, input.len);
        defer allocator.free(into);
        try std.testing.expectEqual(input.len, try decodeInto(encoded, into));
        try std.testing.expectEqualSlices(u8, input, into);
    }

    const bound = try encodedBound(repeated.len);
    const encoded_into = try allocator.alloc(u8, bound);
    defer allocator.free(encoded_into);
    const encoded_len = try encodeInto(allocator, repeated, encoded_into, .{});
    const decoded = try decodeAlloc(allocator, encoded_into[0..encoded_len]);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, repeated, decoded);
}

test "XPRESS plain rejects malformed streams and enforces output limits" {
    try std.testing.expectError(error.TruncatedFrame, decodedSize(&.{ 0, 0, 0 }));
    try std.testing.expectError(error.TruncatedFrame, decodedSize(&.{ 0, 0, 0, 0 }));
    try std.testing.expectError(
        error.InvalidMatch,
        decodedSize(&.{ 0, 0, 0, 0x80, 0, 0 }),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        decodedSize(&.{ 0, 0, 0, 0x40, 'a', 7, 0, 0x0f }),
    );
    try std.testing.expectError(
        error.InvalidXpress,
        decodedSize(&.{ 0, 0, 0, 0x40, 'a', 7, 0, 0x0f, 0xff, 1, 0 }),
    );
    const encoded = try encodeAlloc(std.testing.allocator, "output limit", .{});
    defer std.testing.allocator.free(encoded);
    try std.testing.expectError(error.OutputLimitExceeded, decodedSizeLimited(encoded, 11));
    var too_small: [11]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeInto(encoded, &too_small));
}

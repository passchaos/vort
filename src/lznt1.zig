const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{InvalidLznt1};

pub const chunk_size: usize = 4096;
const signature: u16 = 0x3000;
const compressed_flag: u16 = 0x8000;
const length_mask: u16 = 0x0fff;
const hash_table_len: usize = 4096;
const no_position = std.math.maxInt(u16);

pub const EncodeOptions = struct {
    end_marker: bool = false,
};

pub const Summary = struct {
    encoded_size: usize,
    decoded_size: usize,
    chunk_count: usize,
    compressed_chunks: usize,
    stored_chunks: usize,
    terminated: bool,
};

pub fn encodedBound(input_len: usize, options: EncodeOptions) Error!usize {
    const chunks = if (input_len == 0)
        0
    else
        (std.math.add(usize, input_len, chunk_size - 1) catch
            return error.IntegerOverflow) / chunk_size;
    const headers = std.math.mul(usize, chunks, 2) catch return error.IntegerOverflow;
    const without_marker = std.math.add(usize, input_len, headers) catch
        return error.IntegerOverflow;
    return std.math.add(usize, without_marker, if (options.end_marker) 2 else 0) catch
        return error.IntegerOverflow;
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
    const summary = try walk(input, output[0..size], size);
    if (summary.decoded_size != size) return error.SizeMismatch;
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
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        const length = @min(chunk_size, input.len - offset);
        try appendChunk(allocator, &encoded, input[offset..][0..length]);
        offset += length;
    }
    if (options.end_marker) try appendU16(allocator, &encoded, 0);
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
        .chunk_count = 0,
        .compressed_chunks = 0,
        .stored_chunks = 0,
        .terminated = false,
    };
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        if (input.len - input_offset < 2) return error.TruncatedFrame;
        const header = std.mem.readInt(u16, input[input_offset..][0..2], .little);
        input_offset += 2;
        if (header == 0) {
            summary.terminated = true;
            for (input[input_offset..]) |byte| if (byte != 0) return error.TrailingData;
            return summary;
        }
        if (header & 0x7000 != signature) return error.InvalidLznt1;
        const payload_len: usize = @as(usize, header & length_mask) + 1;
        const payload_end = std.math.add(usize, input_offset, payload_len) catch
            return error.IntegerOverflow;
        if (payload_end > input.len) return error.TruncatedFrame;

        if (summary.chunk_count != 0 and summary.decoded_size % chunk_size != 0) {
            const padding = chunk_size - summary.decoded_size % chunk_size;
            try addOutput(&summary.decoded_size, padding, max_output_len);
            if (output) |bytes| @memset(bytes[summary.decoded_size - padding .. summary.decoded_size], 0);
        }

        const chunk_output_start = summary.decoded_size;
        const payload = input[input_offset..payload_end];
        if (header & compressed_flag == 0) {
            try addOutput(&summary.decoded_size, payload.len, max_output_len);
            if (summary.decoded_size - chunk_output_start > chunk_size)
                return error.InvalidLznt1;
            if (output) |bytes|
                @memcpy(bytes[chunk_output_start..summary.decoded_size], payload);
            summary.stored_chunks += 1;
        } else {
            try decodeCompressedChunk(
                payload,
                output,
                &summary.decoded_size,
                chunk_output_start,
                max_output_len,
            );
            if (summary.decoded_size == chunk_output_start) return error.InvalidLznt1;
            summary.compressed_chunks += 1;
        }
        summary.chunk_count += 1;
        input_offset = payload_end;
    }
    return summary;
}

fn decodeCompressedChunk(
    input: []const u8,
    output: ?[]u8,
    output_offset: *usize,
    chunk_start: usize,
    max_output_len: usize,
) Error!void {
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const flags = input[input_offset];
        input_offset += 1;
        for (0..8) |bit| {
            if (input_offset == input.len) break;
            const chunk_offset = output_offset.* - chunk_start;
            if (flags & (@as(u8, 1) << @intCast(bit)) == 0) {
                if (chunk_offset >= chunk_size) return error.InvalidLznt1;
                try addOutput(output_offset, 1, max_output_len);
                if (output) |bytes| bytes[output_offset.* - 1] = input[input_offset];
                input_offset += 1;
                continue;
            }

            if (input.len - input_offset < 2) return error.CorruptFrame;
            if (chunk_offset == 0) return error.InvalidMatch;
            const token = std.mem.readInt(u16, input[input_offset..][0..2], .little);
            input_offset += 2;
            const distance_bits = tokenDistanceBits(chunk_offset);
            const token_length_bits: u4 = @intCast(16 - distance_bits);
            const token_length_mask: u16 = (@as(u16, 1) << token_length_bits) - 1;
            const length: usize = @as(usize, token & token_length_mask) + 3;
            const distance: usize = @as(usize, token >> token_length_bits) + 1;
            if (distance > chunk_offset) return error.InvalidMatch;
            if (length > chunk_size - chunk_offset) return error.InvalidLznt1;
            try addOutput(output_offset, length, max_output_len);
            if (output) |bytes| {
                var position = output_offset.* - length;
                while (position < output_offset.*) : (position += 1)
                    bytes[position] = bytes[position - distance];
            }
        }
    }
}

fn addOutput(offset: *usize, amount: usize, limit: usize) Error!void {
    const end = std.math.add(usize, offset.*, amount) catch return error.IntegerOverflow;
    if (end > limit) return error.OutputLimitExceeded;
    offset.* = end;
}

fn appendChunk(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!void {
    if (input.len == 0 or input.len > chunk_size) return error.InvalidBlockPlan;
    var compressed: std.ArrayList(u8) = .empty;
    defer compressed.deinit(allocator);
    try encodeCompressedChunk(allocator, &compressed, input);
    if (compressed.items.len < input.len) {
        try appendU16(
            allocator,
            output,
            compressed_flag | signature | @as(u16, @intCast(compressed.items.len - 1)),
        );
        try output.appendSlice(allocator, compressed.items);
    } else {
        try appendU16(allocator, output, signature | @as(u16, @intCast(input.len - 1)));
        try output.appendSlice(allocator, input);
    }
}

const Match = struct {
    distance: usize = 0,
    length: usize = 0,
};

fn encodeCompressedChunk(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!void {
    var heads: [hash_table_len]u16 = @splat(no_position);
    var previous: [chunk_size]u16 = @splat(no_position);
    var position: usize = 0;
    while (position < input.len) {
        const flags_offset = output.items.len;
        try output.append(allocator, 0);
        var flags: u8 = 0;
        for (0..8) |bit| {
            if (position == input.len) break;
            const match = findMatch(input, position, &heads, &previous);
            const consumed = if (match.length >= 3) blk: {
                const distance_bits = tokenDistanceBits(position);
                const token_length_bits: u4 = @intCast(16 - distance_bits);
                const token = (@as(u16, @intCast(match.distance - 1)) << token_length_bits) |
                    @as(u16, @intCast(match.length - 3));
                flags |= @as(u8, 1) << @intCast(bit);
                try appendU16(allocator, output, token);
                break :blk match.length;
            } else blk: {
                try output.append(allocator, input[position]);
                break :blk 1;
            };
            const consumed_end = position + consumed;
            while (position < consumed_end) : (position += 1)
                insertPosition(input, position, &heads, &previous);
        }
        output.items[flags_offset] = flags;
    }
}

fn findMatch(
    input: []const u8,
    position: usize,
    heads: *const [hash_table_len]u16,
    previous: *const [chunk_size]u16,
) Match {
    if (input.len - position < 3 or position == 0) return .{};
    const distance_bits = tokenDistanceBits(position);
    const max_distance = @min(position, @as(usize, 1) << @intCast(distance_bits));
    const length_bits: u4 = @intCast(16 - distance_bits);
    const max_length = @min(input.len - position, ((@as(usize, 1) << length_bits) - 1) + 3);
    var best = Match{};
    var candidate = heads[hash(input[position..][0..3])];
    var searched: usize = 0;
    while (candidate != no_position and searched < 256) : (searched += 1) {
        const candidate_position: usize = candidate;
        const distance = position - candidate_position;
        if (distance > max_distance) break;
        if (!std.mem.eql(
            u8,
            input[candidate_position..][0..3],
            input[position..][0..3],
        )) {
            candidate = previous[candidate_position];
            continue;
        }
        var length: usize = 3;
        while (length < max_length and
            input[candidate_position + length] == input[position + length])
            length += 1;
        if (length > best.length) {
            best = .{ .distance = distance, .length = length };
            if (length == max_length) break;
        }
        candidate = previous[candidate_position];
    }
    return best;
}

fn insertPosition(
    input: []const u8,
    position: usize,
    heads: *[hash_table_len]u16,
    previous: *[chunk_size]u16,
) void {
    if (input.len - position < 3) return;
    const hash_value = hash(input[position..][0..3]);
    previous[position] = heads[hash_value];
    heads[hash_value] = @intCast(position);
}

fn hash(bytes: *const [3]u8) usize {
    return (@as(usize, bytes[0]) *% 0x1e35_a7bd +%
        @as(usize, bytes[1]) *% 0x9e37_79b1 +% bytes[2]) & (hash_table_len - 1);
}

fn tokenDistanceBits(output_offset: usize) u5 {
    var bits: u5 = 4;
    const position = output_offset -| 1;
    while (position >> bits != 0) bits += 1;
    return bits;
}

fn appendU16(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
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

test "LZNT1 decodes the MS-XCA overlapping-copy example" {
    const encoded = &.{
        0x38, 0xb0, 0x88, 0x46, 0x23, 0x20, 0x00, 0x20,
        0x47, 0x20, 0x41, 0x00, 0x10, 0xa2, 0x47, 0x01,
        0xa0, 0x45, 0x20, 0x44, 0x00, 0x08, 0x45, 0x01,
        0x50, 0x79, 0x00, 0xc0, 0x45, 0x20, 0x05, 0x24,
        0x13, 0x88, 0x05, 0xb4, 0x02, 0x4a, 0x44, 0xef,
        0x03, 0x58, 0x02, 0x8c, 0x09, 0x16, 0x01, 0x48,
        0x45, 0x00, 0xbe, 0x00, 0x9e, 0x00, 0x04, 0x01,
        0x18, 0x90, 0x00,
    };
    const expected = "F# F# G A A G F# E D D E F# F# E E F# F# G A A G F# E D D E F# E D D E E F# D E F# G F# D E F# G F# E D E A F# F# G A A G F# E D D E F# E D D\x00";
    const decoded = try decodeAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 142), decoded.len);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "LZNT1 round trips stored compressed and multi-chunk streams" {
    const allocator = std.testing.allocator;
    var random: [9000]u8 = undefined;
    fillPseudoRandom(&random);
    const repeated = "LZNT1 repeated payload 0123456789\n" ** 400;
    const cases = [_][]const u8{ "", "tiny", &random, repeated, repeated ++ "tail" };
    for (cases) |input| {
        inline for (.{ false, true }) |end_marker| {
            const encoded = try encodeAlloc(allocator, input, .{ .end_marker = end_marker });
            defer allocator.free(encoded);
            try std.testing.expect(encoded.len <= try encodedBound(input.len, .{ .end_marker = end_marker }));
            const summary = try summarize(encoded);
            try std.testing.expectEqual(input.len, summary.decoded_size);
            try std.testing.expectEqual(end_marker, summary.terminated);
            const decoded = try decodeAllocLimited(allocator, encoded, input.len);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, input, decoded);
            const into = try allocator.alloc(u8, input.len);
            defer allocator.free(into);
            try std.testing.expectEqual(input.len, try decodeInto(encoded, into));
            try std.testing.expectEqualSlices(u8, input, into);
        }
    }

    const repeated_encoded = try encodeAlloc(allocator, repeated, .{});
    defer allocator.free(repeated_encoded);
    const repeated_summary = try summarize(repeated_encoded);
    try std.testing.expect(repeated_summary.compressed_chunks != 0);
    try std.testing.expect(repeated_encoded.len < repeated.len);
    const random_encoded = try encodeAlloc(allocator, &random, .{});
    defer allocator.free(random_encoded);
    try std.testing.expect((try summarize(random_encoded)).stored_chunks != 0);

    const bound = try encodedBound(repeated.len, .{ .end_marker = true });
    const encoded_into = try allocator.alloc(u8, bound);
    defer allocator.free(encoded_into);
    const encoded_len = try encodeInto(
        allocator,
        repeated,
        encoded_into,
        .{ .end_marker = true },
    );
    const decoded_into = try decodeAlloc(allocator, encoded_into[0..encoded_len]);
    defer allocator.free(decoded_into);
    try std.testing.expectEqualSlices(u8, repeated, decoded_into);
}

test "LZNT1 pads partial chunks before following chunks" {
    const encoded = &.{ 0x00, 0x30, 'A', 0x00, 0x30, 'B' };
    const decoded = try decodeAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, chunk_size + 1), decoded.len);
    try std.testing.expectEqual(@as(u8, 'A'), decoded[0]);
    for (decoded[1..chunk_size]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    try std.testing.expectEqual(@as(u8, 'B'), decoded[chunk_size]);
}

test "LZNT1 rejects malformed chunks and enforces bounds" {
    try std.testing.expectError(error.TruncatedFrame, decodedSize(&.{0}));
    try std.testing.expectError(error.InvalidLznt1, decodedSize(&.{ 0, 0x20, 'x' }));
    try std.testing.expectError(error.TruncatedFrame, decodedSize(&.{ 1, 0x30, 'x' }));
    try std.testing.expectError(error.InvalidMatch, decodedSize(&.{ 2, 0xb0, 1, 0, 0 }));
    try std.testing.expectError(error.InvalidLznt1, decodedSize(&.{ 3, 0xb0, 2, 'a', 0xff, 0x0f }));
    try std.testing.expectError(error.TrailingData, decodedSize(&.{ 0, 0, 1 }));
    const encoded = try encodeAlloc(std.testing.allocator, "limit", .{});
    defer std.testing.allocator.free(encoded);
    try std.testing.expectError(error.OutputLimitExceeded, decodedSizeLimited(encoded, 4));
    var too_small: [4]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeInto(encoded, &too_small));
}

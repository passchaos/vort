const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidLzfBlock,
};

pub const max_literal_length: usize = 32;
pub const max_match_length: usize = 264;
pub const max_distance: usize = 8192;

const hash_bits: usize = 14;
const hash_size: usize = 1 << hash_bits;

/// Return a safe upper bound for one raw LZF block.
pub fn encodedBound(input_len: usize) Error!usize {
    if (input_len == 0) return 0;
    const literal_runs = input_len / max_literal_length + @intFromBool(input_len % max_literal_length != 0);
    return std.math.add(usize, input_len, literal_runs) catch error.IntegerOverflow;
}

/// Validate one complete raw LZF block and return its decoded size.
pub fn decodedSize(input: []const u8) Error!usize {
    return decodedSizeLimited(input, std.math.maxInt(usize));
}

/// Validate one complete raw LZF block with an explicit expansion limit.
pub fn decodedSizeLimited(input: []const u8, max_output_len: usize) Error!usize {
    var input_offset: usize = 0;
    var output_size: usize = 0;
    while (input_offset < input.len) {
        const control = input[input_offset];
        input_offset += 1;
        if (control < 32) {
            const literal_len = @as(usize, control) + 1;
            if (literal_len > input.len - input_offset) return error.TruncatedFrame;
            input_offset += literal_len;
            output_size = std.math.add(usize, output_size, literal_len) catch
                return error.IntegerOverflow;
            if (output_size > max_output_len) return error.OutputLimitExceeded;
            continue;
        }

        var stored_len = @as(usize, control >> 5);
        if (stored_len == 7) {
            if (input_offset == input.len) return error.TruncatedFrame;
            stored_len += input[input_offset];
            input_offset += 1;
        }
        if (input_offset == input.len) return error.TruncatedFrame;
        const distance = ((@as(usize, control & 0x1f) << 8) |
            input[input_offset]) + 1;
        input_offset += 1;
        if (distance > output_size) return error.InvalidLzfBlock;
        output_size = std.math.add(usize, output_size, stored_len + 2) catch
            return error.IntegerOverflow;
        if (output_size > max_output_len) return error.OutputLimitExceeded;
    }
    return output_size;
}

/// Decode one complete raw LZF block into caller-owned storage.
///
/// The output slice may be larger than the decoded block. The returned value
/// is the exact number of bytes written.
pub fn decodeInto(input: []const u8, output: []u8) Error!usize {
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < input.len) {
        const control = input[input_offset];
        input_offset += 1;
        if (control < 32) {
            const literal_len = @as(usize, control) + 1;
            if (literal_len > input.len - input_offset) return error.TruncatedFrame;
            if (literal_len > output.len - output_offset) return error.OutputTooSmall;
            @memcpy(
                output[output_offset .. output_offset + literal_len],
                input[input_offset .. input_offset + literal_len],
            );
            input_offset += literal_len;
            output_offset += literal_len;
            continue;
        }

        var stored_len = @as(usize, control >> 5);
        if (stored_len == 7) {
            if (input_offset == input.len) return error.TruncatedFrame;
            stored_len += input[input_offset];
            input_offset += 1;
        }
        if (input_offset == input.len) return error.TruncatedFrame;
        const distance = ((@as(usize, control & 0x1f) << 8) |
            input[input_offset]) + 1;
        input_offset += 1;
        if (distance > output_offset) return error.InvalidLzfBlock;
        const match_len = stored_len + 2;
        if (match_len > output.len - output_offset) return error.OutputTooSmall;
        for (0..match_len) |_| {
            output[output_offset] = output[output_offset - distance];
            output_offset += 1;
        }
    }
    return output_offset;
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) Error![]u8 {
    return decodeAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) Error![]u8 {
    const output_len = try decodedSizeLimited(input, max_output_len);
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    const written = try decodeInto(input, output);
    if (written != output.len) return error.SizeMismatch;
    return output;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input);
    return output.toOwnedSlice(allocator);
}

/// Append one raw LZF block transactionally.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    if (input.len == 0) return 0;
    if (input.len < 3) {
        try appendLiterals(allocator, output, input);
        return output.items.len - start;
    }

    const heads = try allocator.alloc(i64, hash_size);
    defer allocator.free(heads);
    @memset(heads, -1);

    var literal_start: usize = 0;
    var position: usize = 0;
    while (input.len - position >= 3) {
        const hash = hashAt(input, position);
        const candidate = heads[hash];
        heads[hash] = std.math.cast(i64, position) orelse return error.IntegerOverflow;

        var match_len: usize = 0;
        var distance: usize = 0;
        if (candidate >= 0) {
            const source: usize = @intCast(candidate);
            distance = position - source;
            if (distance <= max_distance and
                input[source] == input[position] and
                input[source + 1] == input[position + 1] and
                input[source + 2] == input[position + 2])
            {
                match_len = 3;
                const limit = @min(max_match_length, input.len - position);
                while (match_len < limit and
                    input[source + match_len] == input[position + match_len])
                {
                    match_len += 1;
                }
            }
        }

        if (match_len < 3) {
            position += 1;
            continue;
        }

        try appendLiterals(allocator, output, input[literal_start..position]);
        try appendMatch(allocator, output, distance, match_len);
        for (1..match_len) |offset| {
            const inserted = position + offset;
            if (input.len - inserted < 3) break;
            heads[hashAt(input, inserted)] = std.math.cast(i64, inserted) orelse
                return error.IntegerOverflow;
        }
        position += match_len;
        literal_start = position;
    }
    try appendLiterals(allocator, output, input[literal_start..]);
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn hashAt(input: []const u8, position: usize) usize {
    const value = (@as(u32, input[position]) << 16) |
        (@as(u32, input[position + 1]) << 8) |
        input[position + 2];
    return @intCast((value *% 0x1e35_a7bd) >> (32 - hash_bits));
}

fn appendLiterals(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    literals: []const u8,
) Error!void {
    var offset: usize = 0;
    while (offset < literals.len) {
        const count = @min(max_literal_length, literals.len - offset);
        try output.append(allocator, @intCast(count - 1));
        try output.appendSlice(allocator, literals[offset .. offset + count]);
        offset += count;
    }
}

fn appendMatch(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    distance: usize,
    match_len: usize,
) Error!void {
    std.debug.assert(distance >= 1 and distance <= max_distance);
    std.debug.assert(match_len >= 3 and match_len <= max_match_length);
    const stored_distance = distance - 1;
    const stored_len = match_len - 2;
    if (stored_len < 7) {
        try output.append(
            allocator,
            @intCast((stored_len << 5) | (stored_distance >> 8)),
        );
    } else {
        try output.append(
            allocator,
            @intCast((7 << 5) | (stored_distance >> 8)),
        );
        try output.append(allocator, @intCast(stored_len - 7));
    }
    try output.append(allocator, @truncate(stored_distance));
}

test "raw LZF round trips empty tiny random repetitive and long-distance inputs" {
    const allocator = std.testing.allocator;
    var random: [16 * 1024]u8 = undefined;
    var state: u32 = 0x1f2e_3d4c;
    for (&random) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    var long_distance: [12 * 1024]u8 = undefined;
    @memcpy(long_distance[0..6000], random[0..6000]);
    @memset(long_distance[6000..6003], 0xa5);
    @memcpy(long_distance[6003..12000], random[0..5997]);
    @memset(long_distance[12000..], 0x42);

    const cases = [_][]const u8{
        "",
        "x",
        "LZF raw block payload " ** 256,
        &random,
        &long_distance,
    };
    for (cases) |input| {
        const encoded = try encodeAlloc(allocator, input);
        defer allocator.free(encoded);
        try std.testing.expect(encoded.len <= try encodedBound(input.len));
        const caller_encoded = try allocator.alloc(u8, encoded.len);
        defer allocator.free(caller_encoded);
        try std.testing.expectEqual(encoded.len, try encodeInto(allocator, input, caller_encoded));
        try std.testing.expectEqualSlices(u8, encoded, caller_encoded);
        try std.testing.expectEqual(input.len, try decodedSize(encoded));
        const decoded = try decodeAlloc(allocator, encoded);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        if (input.len != 0) {
            try std.testing.expectError(
                error.OutputLimitExceeded,
                decodeAllocLimited(allocator, encoded, input.len - 1),
            );
            try std.testing.expectError(
                error.OutputLimitExceeded,
                decodedSizeLimited(encoded, input.len - 1),
            );
        }
    }
}

test "raw LZF accepts canonical literals and overlapping matches" {
    const encoded = [_]u8{
        2,        'A', 'B', 'C',
        (3 << 5), 2,
    };
    var output: [8]u8 = undefined;
    try std.testing.expectEqual(output.len, try decodeInto(&encoded, &output));
    try std.testing.expectEqualSlices(u8, "ABCABCAB", &output);
}

test "raw LZF writer reaches the 8 KiB distance boundary" {
    var input: [max_distance + 3]u8 = @splat(0);
    input[0..3].* = .{ 1, 2, 3 };
    input[max_distance..][0..3].* = .{ 1, 2, 3 };
    const encoded = try encodeAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len >= 2);
    try std.testing.expectEqualSlices(u8, &.{ 0x3f, 0xff }, encoded[encoded.len - 2 ..]);
    const decoded = try decodeAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "raw LZF rejects truncation bad distance and short output" {
    try std.testing.expectError(error.TruncatedFrame, decodedSize(&.{0}));
    try std.testing.expectError(error.TruncatedFrame, decodedSize(&.{0xe0}));
    try std.testing.expectError(error.TruncatedFrame, decodedSize(&.{0x20}));
    try std.testing.expectError(error.InvalidLzfBlock, decodedSize(&.{ 0x20, 0 }));

    const encoded = try encodeAlloc(std.testing.allocator, "bounded LZF output");
    defer std.testing.allocator.free(encoded);
    var output: [4]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeInto(encoded, &output));
}

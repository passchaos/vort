const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidLzjbStream,
};

const match_min: usize = 3;
const match_max: usize = 66;
const offset_max: usize = 1023;
const hash_size: usize = 1024;
const invalid_position = std.math.maxInt(usize);

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!usize {
    const start = output.items.len;
    errdefer output.shrinkRetainingCapacity(start);
    var table: [hash_size]usize = @splat(invalid_position);
    var position: usize = 0;
    var token_index: usize = 0;
    var map_index: usize = 0;
    while (position < input.len) {
        if (token_index & 7 == 0) {
            map_index = output.items.len;
            try output.append(allocator, 0);
        }
        var match_length: usize = 0;
        var distance: usize = 0;
        if (input.len - position >= match_max) {
            const hash = hashAt(input, position);
            const candidate = table[hash];
            table[hash] = position;
            if (candidate != invalid_position and candidate < position) {
                distance = position - candidate;
                if (distance <= offset_max and
                    std.mem.eql(
                        u8,
                        input[candidate..][0..match_min],
                        input[position..][0..match_min],
                    ))
                {
                    match_length = match_min;
                    while (match_length < match_max and
                        input[candidate + match_length] == input[position + match_length])
                        match_length += 1;
                }
            }
        }
        if (match_length >= match_min) {
            output.items[map_index] |= @as(u8, 1) << @intCast(token_index & 7);
            try output.append(
                allocator,
                @as(u8, @intCast((match_length - match_min) << 2)) |
                    @as(u8, @intCast(distance >> 8)),
            );
            try output.append(allocator, @truncate(distance));
            position += match_length;
        } else {
            try output.append(allocator, input[position]);
            position += 1;
        }
        token_index += 1;
    }
    return output.items.len - start;
}

pub fn decodeAllocExactSize(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
) Error![]u8 {
    const output = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(output);
    _ = try decodeIntoExactSize(input, output);
    return output;
}

pub fn decodeIntoExactSize(input: []const u8, output: []u8) Error!usize {
    var input_position: usize = 0;
    var output_position: usize = 0;
    var map: u8 = 0;
    var token_index: usize = 0;
    while (output_position < output.len) {
        if (token_index & 7 == 0) {
            if (input_position == input.len) return error.TruncatedFrame;
            map = input[input_position];
            input_position += 1;
        }
        if (map & (@as(u8, 1) << @intCast(token_index & 7)) != 0) {
            if (input.len - input_position < 2) return error.TruncatedFrame;
            const first = input[input_position];
            const distance = (@as(usize, first & 0x03) << 8) |
                input[input_position + 1];
            const length = @as(usize, first >> 2) + match_min;
            input_position += 2;
            if (distance == 0 or distance > output_position)
                return error.InvalidMatch;
            const output_end = std.math.add(usize, output_position, length) catch
                return error.IntegerOverflow;
            if (output_end > output.len) return error.SizeMismatch;
            while (output_position < output_end) : (output_position += 1)
                output[output_position] = output[output_position - distance];
        } else {
            if (input_position == input.len) return error.TruncatedFrame;
            output[output_position] = input[input_position];
            input_position += 1;
            output_position += 1;
        }
        token_index += 1;
    }
    return input_position;
}

fn hashAt(input: []const u8, position: usize) usize {
    var hash = (@as(usize, input[position]) << 16) |
        (@as(usize, input[position + 1]) << 8) |
        input[position + 2];
    hash += hash >> 9;
    hash += hash >> 5;
    return hash & (hash_size - 1);
}

test "ZFS LZJB decodes literal and overlapping match tokens" {
    const encoded = [_]u8{ 0x08, 'a', 'b', 'c', 0x0c, 0x03 };
    var output: [9]u8 = undefined;
    try std.testing.expectEqual(@as(usize, encoded.len), try decodeIntoExactSize(&encoded, &output));
    try std.testing.expectEqualStrings("abcabcabc", &output);
}

test "ZFS LZJB writer round trips repetitive data" {
    const input = "ZFS LZJB repeated payload\n" ** 400;
    const encoded = try encodeAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len < input.len);
    const decoded = try decodeAllocExactSize(std.testing.allocator, encoded, input.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings(input, decoded);
}

test "ZFS LZJB rejects truncated and invalid matches" {
    var output: [3]u8 = undefined;
    try std.testing.expectError(
        error.TruncatedFrame,
        decodeIntoExactSize(&.{0x01}, &output),
    );
    try std.testing.expectError(
        error.InvalidMatch,
        decodeIntoExactSize(&.{ 0x01, 0, 0 }, &output),
    );
}

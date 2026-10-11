const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidZleStream,
};

pub const parameter: usize = 64;
const max_zero_run: usize = 256 - parameter;

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
    var position: usize = 0;
    while (position < input.len) {
        if (input[position] == 0) {
            var end = position + 1;
            while (end < input.len and end - position < max_zero_run and
                input[end] == 0)
                end += 1;
            const length = end - position;
            try output.append(allocator, @intCast(parameter + length - 1));
            position = end;
        } else {
            var end = position + 1;
            while (end < input.len and end - position < parameter and
                input[end] != 0)
                end += 1;
            const length = end - position;
            try output.append(allocator, @intCast(length - 1));
            try output.appendSlice(allocator, input[position..end]);
            position = end;
        }
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
    while (input_position < input.len and output_position < output.len) {
        const control = input[input_position];
        input_position += 1;
        const encoded_length = @as(usize, control) + 1;
        if (encoded_length <= parameter) {
            const input_end = std.math.add(
                usize,
                input_position,
                encoded_length,
            ) catch return error.IntegerOverflow;
            const output_end = std.math.add(
                usize,
                output_position,
                encoded_length,
            ) catch return error.IntegerOverflow;
            if (input_end > input.len) return error.TruncatedFrame;
            if (output_end > output.len) return error.SizeMismatch;
            @memcpy(output[output_position..output_end], input[input_position..input_end]);
            input_position = input_end;
            output_position = output_end;
        } else {
            const length = encoded_length - parameter;
            const output_end = std.math.add(usize, output_position, length) catch
                return error.IntegerOverflow;
            if (output_end > output.len) return error.SizeMismatch;
            @memset(output[output_position..output_end], 0);
            output_position = output_end;
        }
    }
    if (output_position != output.len) return error.SizeMismatch;
    return input_position;
}

test "ZFS ZLE decodes literal and zero runs" {
    const encoded = [_]u8{ 2, 'a', 'b', 'c', 66, 1, 'd', 'e' };
    var output: [8]u8 = undefined;
    try std.testing.expectEqual(@as(usize, encoded.len), try decodeIntoExactSize(&encoded, &output));
    try std.testing.expectEqualSlices(u8, &.{ 'a', 'b', 'c', 0, 0, 0, 'd', 'e' }, &output);
}

test "ZFS ZLE writer round trips sparse data" {
    var input: [2048]u8 = @splat(0);
    @memcpy(input[100..108], "non-zero");
    @memcpy(input[1500..1504], "tail");
    const encoded = try encodeAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len < input.len);
    const decoded = try decodeAllocExactSize(std.testing.allocator, encoded, input.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "ZFS ZLE rejects truncated and oversized runs" {
    var output: [2]u8 = undefined;
    try std.testing.expectError(
        error.TruncatedFrame,
        decodeIntoExactSize(&.{ 1, 'a' }, &output),
    );
    try std.testing.expectError(
        error.SizeMismatch,
        decodeIntoExactSize(&.{255}, &output),
    );
}

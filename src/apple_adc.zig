const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidAppleAdcStream,
};

pub fn decodedSize(input: []const u8) Error!usize {
    return decodedSizeLimited(input, std.math.maxInt(usize));
}

pub fn decodedSizeLimited(input: []const u8, max_output_len: usize) Error!usize {
    return decodeInternal(input, null, max_output_len);
}

pub fn decodeInto(input: []const u8, output: []u8) Error!usize {
    return decodeInternal(input, output, output.len);
}

pub fn decodeIntoExactSize(input: []const u8, output: []u8) Error!void {
    const written = decodeInternal(input, output, output.len) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != output.len) return error.SizeMismatch;
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_output_len: usize,
) Error![]u8 {
    const size = try decodedSizeLimited(input, max_output_len);
    const output = try allocator.alloc(u8, size);
    errdefer allocator.free(output);
    try decodeIntoExactSize(input, output);
    return output;
}

pub fn decodeAllocExactSize(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_output_len: usize,
) Error![]u8 {
    const output = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(output);
    try decodeIntoExactSize(input, output);
    return output;
}

pub fn encodedBound(input_len: usize) Error!usize {
    const commands = if (input_len == 0)
        0
    else
        (std.math.add(usize, input_len, 127) catch
            return error.IntegerOverflow) / 128;
    return std.math.add(usize, input_len, commands) catch error.IntegerOverflow;
}

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
        const length = @min(@as(usize, 128), input.len - position);
        try output.append(allocator, 0x80 | @as(u8, @intCast(length - 1)));
        try output.appendSlice(allocator, input[position..][0..length]);
        position += length;
    }
    return output.items.len - start;
}

pub fn encodeInto(input: []const u8, output: []u8) Error!usize {
    const required = try encodedBound(input.len);
    if (output.len < required) return error.OutputTooSmall;
    var input_position: usize = 0;
    var output_position: usize = 0;
    while (input_position < input.len) {
        const length = @min(@as(usize, 128), input.len - input_position);
        output[output_position] = 0x80 | @as(u8, @intCast(length - 1));
        output_position += 1;
        @memcpy(
            output[output_position..][0..length],
            input[input_position..][0..length],
        );
        input_position += length;
        output_position += length;
    }
    return output_position;
}

fn decodeInternal(
    input: []const u8,
    output: ?[]u8,
    max_output_len: usize,
) Error!usize {
    var input_position: usize = 0;
    var output_position: usize = 0;
    while (input_position < input.len) {
        const command = input[input_position];
        input_position += 1;
        if (command & 0x80 != 0) {
            const length: usize = @as(usize, command & 0x7f) + 1;
            const input_end = std.math.add(usize, input_position, length) catch
                return error.IntegerOverflow;
            if (input_end > input.len) return error.TruncatedFrame;
            const output_end = try checkedOutputEnd(
                output_position,
                length,
                max_output_len,
                output != null,
            );
            if (output) |bytes| {
                if (output_end > bytes.len) return error.OutputTooSmall;
                @memcpy(bytes[output_position..output_end], input[input_position..input_end]);
            }
            input_position = input_end;
            output_position = output_end;
            continue;
        }

        var length: usize = undefined;
        var encoded_distance: usize = undefined;
        if (command & 0x40 != 0) {
            if (input.len - input_position < 2) return error.TruncatedFrame;
            length = @as(usize, command & 0x3f) + 4;
            encoded_distance = std.mem.readInt(
                u16,
                input[input_position..][0..2],
                .big,
            );
            input_position += 2;
        } else {
            if (input_position == input.len) return error.TruncatedFrame;
            length = @as(usize, command >> 2) + 3;
            encoded_distance = (@as(usize, command & 0x03) << 8) |
                input[input_position];
            input_position += 1;
        }
        const distance = encoded_distance + 1;
        if (distance > output_position) return error.InvalidMatch;
        const output_end = try checkedOutputEnd(
            output_position,
            length,
            max_output_len,
            output != null,
        );
        if (output) |bytes| {
            if (output_end > bytes.len) return error.OutputTooSmall;
            var destination = output_position;
            while (destination < output_end) : (destination += 1)
                bytes[destination] = bytes[destination - distance];
        }
        output_position = output_end;
    }
    return output_position;
}

fn checkedOutputEnd(
    position: usize,
    length: usize,
    limit: usize,
    caller_buffer: bool,
) Error!usize {
    const end = std.math.add(usize, position, length) catch
        return error.IntegerOverflow;
    if (end > limit)
        return if (caller_buffer) error.OutputTooSmall else error.OutputLimitExceeded;
    return end;
}

test "Apple ADC decodes literal short-match and long-match commands" {
    const short = [_]u8{ 0x82, 'a', 'b', 'c', 0x00, 0x02 };
    var short_output: [6]u8 = undefined;
    try decodeIntoExactSize(&short, &short_output);
    try std.testing.expectEqualStrings("abcabc", &short_output);

    const long = [_]u8{ 0x80, 'x', 0x40, 0x00, 0x00 };
    var long_output: [5]u8 = undefined;
    try decodeIntoExactSize(&long, &long_output);
    try std.testing.expectEqualStrings("xxxxx", &long_output);
}

test "Apple ADC literal writer round trips boundary sizes" {
    const allocator = std.testing.allocator;
    const cases = [_][]const u8{
        "",
        "a",
        "Apple ADC literal stream",
        "0123456789abcdef" ** 8,
        ("ADC-boundary-pattern-" ** 13) ++ "tail",
    };
    for (cases) |input| {
        const encoded = try encodeAlloc(allocator, input);
        defer allocator.free(encoded);
        try std.testing.expectEqual(try encodedBound(input.len), encoded.len);
        const decoded = try decodeAllocLimited(allocator, encoded, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "Apple ADC rejects truncated invalid-distance and bounded output" {
    try std.testing.expectError(
        error.TruncatedFrame,
        decodedSize(&.{ 0x82, 'a' }),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        decodedSize(&.{0x40}),
    );
    try std.testing.expectError(
        error.InvalidMatch,
        decodedSize(&.{ 0x00, 0x00 }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodedSizeLimited(&.{ 0x80, 'x' }, 0),
    );
    var short_output: [1]u8 = undefined;
    try std.testing.expectError(
        error.OutputTooSmall,
        decodeInto(&.{ 0x81, 'a', 'b' }, &short_output),
    );
}

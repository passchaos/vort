const std = @import("std");
const bitstream = @import("../bitstream.zig");
const bit_count = @import("../io/bit_count.zig");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidZooLzdStream,
};

const clear_code: u16 = 256;
const end_code: u16 = 257;
const first_code: u16 = 258;
const initial_code_bits: u5 = 9;
const maximum_code_bits: u5 = 13;
const table_size: usize = 1 << maximum_code_bits;

/// Decode one ZOO method-1 LZD payload into caller-owned storage.
///
/// ZOO uses a continuous LSB-first LZW bitstream. Code width grows from 9
/// through 13 bits and the stream carries explicit CLEAR and end codes.
pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    var reader = bitstream.BitReader.init(input);
    var prefixes: [table_size]u16 = @splat(0);
    var suffixes: [table_size]u8 = @splat(0);
    for (suffixes[0..256], 0..) |*suffix, value| suffix.* = @intCast(value);
    var stack: [table_size]u8 = undefined;

    var code_bits = initial_code_bits;
    var next_code: u16 = first_code;
    var previous_code: ?u16 = null;
    var first_byte: u8 = 0;
    var output_offset: usize = 0;
    var saw_initial_clear = false;

    while (true) {
        const encoded_code = reader.readBits(u16, code_bits) catch |err| switch (err) {
            error.TruncatedFrame => return error.TruncatedFrame,
            else => return err,
        };

        if (encoded_code == clear_code) {
            code_bits = initial_code_bits;
            next_code = first_code;
            previous_code = null;
            saw_initial_clear = true;
            continue;
        }
        if (!saw_initial_clear) return error.InvalidZooLzdStream;
        if (encoded_code == end_code) {
            if (output_offset != output.len) return error.SizeMismatch;
            return finishReader(reader);
        }

        if (previous_code == null) {
            if (encoded_code >= 256) return error.InvalidZooLzdStream;
            if (output_offset == output.len) return error.OutputTooSmall;
            first_byte = @intCast(encoded_code);
            output[output_offset] = first_byte;
            output_offset += 1;
            previous_code = encoded_code;
            continue;
        }

        if (next_code == table_size) return error.InvalidZooLzdStream;
        if (encoded_code > next_code or encoded_code >= table_size)
            return error.InvalidZooLzdStream;

        const original_code = encoded_code;
        var code = encoded_code;
        var stack_len: usize = 0;
        if (code == next_code) {
            stack[stack_len] = first_byte;
            stack_len += 1;
            code = previous_code.?;
        }

        var followed: usize = 0;
        while (code >= first_code) {
            if (code >= next_code or stack_len == stack.len or followed == table_size)
                return error.InvalidZooLzdStream;
            stack[stack_len] = suffixes[code];
            stack_len += 1;
            code = prefixes[code];
            followed += 1;
        }
        if (code >= 256 or stack_len == stack.len) return error.InvalidZooLzdStream;
        first_byte = @intCast(code);
        stack[stack_len] = first_byte;
        stack_len += 1;

        if (stack_len > output.len - output_offset) return error.OutputTooSmall;
        while (stack_len != 0) {
            stack_len -= 1;
            output[output_offset] = stack[stack_len];
            output_offset += 1;
        }

        prefixes[next_code] = previous_code.?;
        suffixes[next_code] = first_byte;
        next_code += 1;
        if (next_code == (@as(u16, 1) << @intCast(code_bits)) and
            code_bits < maximum_code_bits)
        {
            code_bits += 1;
        }
        previous_code = original_code;
    }
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
) Error![]u8 {
    return decodeAllocLimited(allocator, input, output_len, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
    max_output_len: usize,
) Error![]u8 {
    if (output_len > max_output_len) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    try decodeInto(input, output);
    return output;
}

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input);
    return output.toOwnedSlice(allocator);
}

/// Append a deterministic literal-only ZOO LZD stream.
///
/// This baseline deliberately favors interoperability and simple auditing;
/// match finding can be added later without changing the public API or wire
/// format. It still exercises every code width and emits CLEAR when the 8K
/// dictionary fills.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;

    var writer = bitstream.BitWriter{};
    defer writer.deinit(allocator);
    try writer.writeBits(allocator, clear_code, initial_code_bits);

    var code_bits = initial_code_bits;
    var next_code: u16 = first_code;
    var have_previous = false;
    for (input) |literal| {
        if (next_code == table_size) {
            try writer.writeBits(allocator, clear_code, code_bits);
            code_bits = initial_code_bits;
            next_code = first_code;
            have_previous = false;
        }

        try writer.writeBits(allocator, literal, code_bits);
        if (have_previous) {
            next_code += 1;
            if (next_code == (@as(u16, 1) << @intCast(code_bits)) and
                code_bits < maximum_code_bits)
            {
                code_bits += 1;
            }
        } else {
            have_previous = true;
        }
    }
    try writer.writeBits(allocator, end_code, code_bits);
    const encoded = try writer.toOwnedSlice(allocator);
    defer allocator.free(encoded);
    try output.appendSlice(allocator, encoded);
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

fn finishReader(reader: bitstream.BitReader) Error!void {
    const position = reader.bitPosition();
    const total_bits = try bit_count.fromBytes(reader.input.len);
    if (position > total_bits) return error.IntegerOverflow;
    const remaining = total_bits - position;
    if (remaining >= 8) return error.TrailingData;
    var bit = position;
    while (bit < total_bits) : (bit += 1) {
        const byte_index = try bit_count.floorBytes(bit);
        if ((reader.input[byte_index] >> @intCast(bit % 8)) & 1 != 0)
            return error.TrailingData;
    }
}

test "ZOO LZD round trips literals across widths and dictionary clears" {
    const allocator = std.testing.allocator;
    const cases = [_][]const u8{
        "",
        "a",
        "abracadabra abracadabra",
        "ZOO method one payload\n" ** 128,
    };
    for (cases) |input| {
        const encoded = try encodeAlloc(allocator, input);
        defer allocator.free(encoded);
        const decoded = try decodeAlloc(allocator, encoded, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }

    var large: [20_000]u8 = undefined;
    var state: u32 = 0x20_10_1986;
    for (&large) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const encoded = try encodeAlloc(allocator, &large);
    defer allocator.free(encoded);
    const decoded = try decodeAlloc(allocator, encoded, large.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &large, decoded);
}

test "ZOO LZD rejects missing controls truncation and size mismatches" {
    var one: [1]u8 = undefined;
    try std.testing.expectError(error.InvalidZooLzdStream, decodeInto(&.{ 0, 0 }, &one));

    const encoded = try encodeAlloc(std.testing.allocator, "abc");
    defer std.testing.allocator.free(encoded);
    var exact: [3]u8 = undefined;
    try std.testing.expectError(
        error.TruncatedFrame,
        decodeInto(encoded[0 .. encoded.len - 1], &exact),
    );
    try std.testing.expectError(error.OutputTooSmall, decodeInto(encoded, &one));
    var long: [4]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decodeInto(encoded, &long));

    const trailing = try std.testing.allocator.alloc(u8, encoded.len + 1);
    defer std.testing.allocator.free(trailing);
    @memcpy(trailing[0..encoded.len], encoded);
    trailing[encoded.len] = 1;
    try std.testing.expectError(error.TrailingData, decodeInto(trailing, &exact));
}

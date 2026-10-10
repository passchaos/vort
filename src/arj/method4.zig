const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidArjMethod4Stream,
};

const BitReader = struct {
    input: []const u8,
    byte_offset: usize = 0,
    reservoir: u64 = 0,
    bit_count: u7 = 0,

    fn read(self: *BitReader, count: u6) Error!u32 {
        if (count == 0) return 0;
        while (self.bit_count < count) {
            if (self.byte_offset == self.input.len) return error.TruncatedFrame;
            self.reservoir = (self.reservoir << 8) | self.input[self.byte_offset];
            self.byte_offset += 1;
            self.bit_count += 8;
        }
        const shift: u7 = self.bit_count - count;
        const result: u32 = @truncate(self.reservoir >> @intCast(shift));
        self.bit_count -= count;
        self.reservoir &= mask(self.bit_count);
        return result & @as(u32, @intCast(mask(count)));
    }

    fn finish(self: *const BitReader) Error!void {
        if (self.byte_offset != self.input.len) return error.TrailingData;
    }
};

const BitWriter = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    reservoir: u64 = 0,
    bit_count: u7 = 0,

    fn write(self: *BitWriter, value: u32, count: u6) Error!void {
        if (count == 0) return;
        std.debug.assert(@as(u64, value) <= mask(count));
        self.reservoir = (self.reservoir << @intCast(count)) | value;
        self.bit_count += count;
        while (self.bit_count >= 8) {
            const shift: u7 = self.bit_count - 8;
            try self.output.append(
                self.allocator,
                @truncate(self.reservoir >> @intCast(shift)),
            );
            self.bit_count -= 8;
            self.reservoir &= mask(self.bit_count);
        }
    }

    fn finish(self: *BitWriter) Error!void {
        if (self.bit_count != 0) {
            try self.output.append(
                self.allocator,
                @truncate(self.reservoir << @intCast(8 - self.bit_count)),
            );
        }
        self.reservoir = 0;
        self.bit_count = 0;
    }
};

fn mask(count: anytype) u64 {
    const bits: u7 = @intCast(count);
    return if (bits == 0) 0 else (@as(u64, 1) << @intCast(bits)) - 1;
}

pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    if (output.len == 0) {
        if (input.len != 0) return error.TrailingData;
        return;
    }
    var reader = BitReader{ .input = input };
    var output_offset: usize = 0;
    while (output_offset < output.len) {
        const length_code = try decodeValue(&reader, 0, 7);
        if (length_code == 0) {
            output[output_offset] = @truncate(try reader.read(8));
            output_offset += 1;
            continue;
        }
        const match_len = @as(usize, length_code) + 2;
        if (match_len > output.len - output_offset) return error.SizeMismatch;
        const stored_distance = try decodeValue(&reader, 9, 13);
        const distance = @as(usize, stored_distance) + 1;
        if (distance > output_offset) return error.InvalidArjMethod4Stream;
        for (0..match_len) |_| {
            output[output_offset] = output[output_offset - distance];
            output_offset += 1;
        }
    }
    try reader.finish();
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

/// Emit a deterministic literal-only method-4 stream.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    var writer = BitWriter{ .allocator = allocator, .output = output };
    for (input) |literal| {
        try writer.write(0, 1);
        try writer.write(literal, 8);
    }
    try writer.finish();
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

fn decodeValue(reader: *BitReader, from: u6, to: u6) Error!u32 {
    var add: u32 = 0;
    var exponent = @as(u32, 1) << @intCast(from);
    var bits = from;
    while (bits < to) : (bits += 1) {
        if (try reader.read(1) == 0) break;
        add += exponent;
        exponent <<= 1;
    }
    return add + if (bits == 0) 0 else try reader.read(bits);
}

test "ARJ method 4 literal writer round trips arbitrary bytes" {
    const allocator = std.testing.allocator;
    var input: [4097]u8 = undefined;
    var state: u32 = 0xa4f4_0001;
    for (&input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const encoded = try encodeAlloc(allocator, &input);
    defer allocator.free(encoded);
    const caller_encoded = try allocator.alloc(u8, encoded.len);
    defer allocator.free(caller_encoded);
    try std.testing.expectEqual(encoded.len, try encodeInto(allocator, &input, caller_encoded));
    try std.testing.expectEqualSlices(u8, encoded, caller_encoded);
    const decoded = try decodeAlloc(allocator, encoded, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocLimited(allocator, encoded, input.len, input.len - 1),
    );
}

test "ARJ method 4 decoder handles overlap and rejects malformed streams" {
    // Literal 'A', then length code 1 (10 + one low bit 0) and distance 0.
    const encoded = [_]u8{ 0x20, 0xc0, 0x00 };
    var output: [4]u8 = undefined;
    try decodeInto(&encoded, &output);
    try std.testing.expectEqualSlices(u8, "AAAA", &output);

    var one: [1]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto(&.{}, &one));
    var match_only: [3]u8 = undefined;
    try std.testing.expectError(
        error.InvalidArjMethod4Stream,
        decodeInto(&.{ 0x80, 0 }, &match_only),
    );
    var short: [2]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decodeInto(&encoded, &short));
}

const std = @import("std");
const core = @import("../core.zig");
const rle = @import("rle.zig");

pub const Error = core.Error || rle.Error || std.mem.Allocator.Error || error{
    InvalidArcLzwStream,
};

pub const Mode = enum { crunched, squashed };

const clear_code: u16 = 256;
const first_code: u16 = 257;
const table_size: usize = 8192;

const BitReader = struct {
    input: []const u8,
    bit_offset: usize = 0,

    fn read(self: *BitReader, count: u5) Error!u16 {
        if (count == 0) return 0;
        const total_bits = std.math.mul(usize, self.input.len, 8) catch
            return error.IntegerOverflow;
        if (self.bit_offset > total_bits or count > total_bits - self.bit_offset)
            return error.TruncatedFrame;
        var result: u16 = 0;
        for (0..count) |index| {
            const position = self.bit_offset + index;
            const bit = (self.input[position / 8] >> @intCast(position % 8)) & 1;
            result |= @as(u16, bit) << @intCast(index);
        }
        self.bit_offset += count;
        return result;
    }

    fn skip(self: *BitReader, count: usize) Error!void {
        const total_bits = self.input.len * 8;
        if (self.bit_offset > total_bits or count > total_bits - self.bit_offset)
            return error.TruncatedFrame;
        self.bit_offset += count;
    }

    fn remaining(self: *const BitReader) usize {
        return self.input.len * 8 - self.bit_offset;
    }

    fn remainingZero(self: *const BitReader) bool {
        var position = self.bit_offset;
        while (position < self.input.len * 8) : (position += 1)
            if ((self.input[position / 8] >> @intCast(position % 8)) & 1 != 0) return false;
        return true;
    }
};

const BitWriter = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    reservoir: u64 = 0,
    bit_count: u7 = 0,

    fn write(self: *BitWriter, value: u16, count: u5) Error!void {
        if (count == 0) return;
        std.debug.assert(value < @as(u32, 1) << @intCast(count));
        self.reservoir |= @as(u64, value) << @intCast(self.bit_count);
        self.bit_count += count;
        while (self.bit_count >= 8) {
            try self.output.append(self.allocator, @truncate(self.reservoir));
            self.reservoir >>= 8;
            self.bit_count -= 8;
        }
    }

    fn writeZeroes(self: *BitWriter, count: usize) Error!void {
        var remaining = count;
        while (remaining != 0) {
            const chunk: u5 = @intCast(@min(remaining, @as(usize, 16)));
            try self.write(0, chunk);
            remaining -= chunk;
        }
    }

    fn finish(self: *BitWriter) Error!void {
        if (self.bit_count != 0)
            try self.output.append(self.allocator, @truncate(self.reservoir));
        self.reservoir = 0;
        self.bit_count = 0;
    }
};

const CodeReader = struct {
    reader: BitReader,
    bit_width: u5 = 9,
    max_code: u16 = 511,
    free_entry: u16 = first_code,
    clear_pending: bool = false,
    group_codes: u4 = 0,
    max_bits: u5,
    max_code_limit: u16,

    fn next(self: *CodeReader) Error!?u16 {
        if (self.clear_pending or self.free_entry > self.max_code) {
            if (self.group_codes != 0) {
                try self.reader.skip(
                    (@as(usize, 8) - self.group_codes) * self.bit_width,
                );
                self.group_codes = 0;
            }
            if (self.free_entry > self.max_code) {
                self.bit_width += 1;
                self.max_code = if (self.bit_width == self.max_bits)
                    self.max_code_limit
                else
                    (@as(u16, 1) << @intCast(self.bit_width)) - 1;
            }
            if (self.clear_pending) {
                self.clear_pending = false;
                self.bit_width = 9;
                self.max_code = 511;
            }
        }
        if (self.reader.remaining() < self.bit_width) return null;
        const code = try self.reader.read(self.bit_width);
        self.group_codes = (self.group_codes + 1) % 8;
        return code;
    }
};

const Emitter = struct {
    output: []u8,
    use_rle: bool,
    output_offset: usize = 0,
    rle_decoder: rle.Decoder = .{},

    fn emit(self: *Emitter, byte: u8) Error!void {
        if (self.use_rle) {
            try self.rle_decoder.feed(byte, self.output);
        } else {
            if (self.output_offset == self.output.len) return error.OutputTooSmall;
            self.output[self.output_offset] = byte;
            self.output_offset += 1;
        }
    }

    fn finish(self: *Emitter) Error!void {
        if (self.use_rle)
            try self.rle_decoder.finish(self.output.len)
        else if (self.output_offset != self.output.len)
            return error.SizeMismatch;
    }
};

pub fn decodeInto(input: []const u8, output: []u8, mode: Mode) Error!void {
    var payload = input;
    const max_bits: u5 = switch (mode) {
        .crunched => blk: {
            if (payload.len == 0) return error.TruncatedFrame;
            if (payload[0] != 12) return error.InvalidArcLzwStream;
            payload = payload[1..];
            break :blk 12;
        },
        .squashed => 13,
    };
    if (payload.len == 0) {
        if (output.len != 0) return error.SizeMismatch;
        return;
    }

    var codes = CodeReader{
        .reader = .{ .input = payload },
        .max_bits = max_bits,
        .max_code_limit = @as(u16, 1) << @intCast(max_bits),
    };
    var prefix: [table_size]u16 = @splat(0);
    var suffix: [table_size]u8 = @splat(0);
    for (suffix[0..256], 0..) |*byte, value| byte.* = @intCast(value);
    var stack: [table_size]u8 = undefined;
    var emitter = Emitter{ .output = output, .use_rle = mode == .crunched };

    const first = (try codes.next()) orelse {
        if (output.len != 0) return error.SizeMismatch;
        return;
    };
    if (first >= 256) return error.InvalidArcLzwStream;
    var old_code = first;
    var final_byte: u8 = @intCast(first);
    try emitter.emit(final_byte);

    while (try codes.next()) |raw_code| {
        var code = raw_code;
        if (code == clear_code) {
            @memset(&prefix, 0);
            codes.clear_pending = true;
            codes.free_entry = first_code - 1;
            code = (try codes.next()) orelse break;
            if (code >= 256) return error.InvalidArcLzwStream;
        }
        const input_code = code;
        var stack_len: usize = 0;
        if (code >= codes.free_entry) {
            if (code != codes.free_entry) return error.InvalidArcLzwStream;
            stack[stack_len] = final_byte;
            stack_len += 1;
            code = old_code;
        }
        var iterations: usize = 0;
        while (code >= 256) {
            if (code >= codes.free_entry or code >= table_size) return error.InvalidArcLzwStream;
            if (stack_len == stack.len or iterations > table_size)
                return error.InvalidArcLzwStream;
            stack[stack_len] = suffix[code];
            stack_len += 1;
            code = prefix[code];
            iterations += 1;
        }
        final_byte = suffix[code];
        stack[stack_len] = final_byte;
        stack_len += 1;
        while (stack_len != 0) {
            stack_len -= 1;
            try emitter.emit(stack[stack_len]);
        }
        if (codes.free_entry < codes.max_code_limit) {
            prefix[codes.free_entry] = old_code;
            suffix[codes.free_entry] = final_byte;
            codes.free_entry += 1;
        }
        old_code = input_code;
    }
    try emitter.finish();
    if (!codes.reader.remainingZero()) return error.TrailingData;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    mode: Mode,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, mode);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    mode: Mode,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    const source = if (mode == .crunched)
        try rle.encodeAlloc(allocator, input)
    else
        try allocator.dupe(u8, input);
    defer allocator.free(source);
    if (mode == .crunched) try output.append(allocator, 12);

    var writer = BitWriter{ .allocator = allocator, .output = output };
    var bit_width: u5 = 9;
    var max_code: u16 = 511;
    var free_entry: u16 = first_code;
    const max_bits: u5 = if (mode == .crunched) 12 else 13;
    const max_code_limit: u16 = @as(u16, 1) << @intCast(max_bits);
    var group_codes: u4 = 0;
    for (source, 0..) |literal, index| {
        if (free_entry > max_code) {
            if (group_codes != 0) {
                try writer.writeZeroes(
                    (@as(usize, 8) - group_codes) * bit_width,
                );
                group_codes = 0;
            }
            bit_width += 1;
            max_code = if (bit_width == max_bits)
                max_code_limit
            else
                (@as(u16, 1) << @intCast(bit_width)) - 1;
        }
        try writer.write(literal, bit_width);
        group_codes = (group_codes + 1) % 8;
        if (index != 0 and free_entry < max_code_limit) free_entry += 1;
    }
    try writer.finish();
    return output.items.len - start;
}

test "ARC crunched and squashed literal writers cross code widths" {
    const allocator = std.testing.allocator;
    var input: [12 * 1024]u8 = undefined;
    var state: u32 = 0xa5c9_0001;
    for (&input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    inline for (std.meta.tags(Mode)) |mode| {
        const encoded = try encodeAlloc(allocator, &input, mode);
        defer allocator.free(encoded);
        var decoded: [input.len]u8 = undefined;
        try decodeInto(encoded, &decoded, mode);
        try std.testing.expectEqualSlices(u8, &input, &decoded);
    }
}

test "ARC LZW rejects properties truncation and short output" {
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.InvalidArcLzwStream, decodeInto(&.{ 11, 0 }, &output, .crunched));
    try std.testing.expectError(error.SizeMismatch, decodeInto(&.{12}, &output, .crunched));
    const encoded = try encodeAlloc(std.testing.allocator, "ab", .squashed);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectError(error.OutputTooSmall, decodeInto(encoded, &output, .squashed));
}

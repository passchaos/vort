const std = @import("std");

pub const Error = std.mem.Allocator.Error || error{
    InvalidShrinkStream,
    TruncatedShrinkInput,
    ShrinkSizeMismatch,
    ShrinkTrailingData,
};

const control_code: u16 = 256;
const first_free_code: u16 = 257;
const empty_code: u16 = 256;
const min_bits: u4 = 9;
const max_bits: u4 = 13;
const dictionary_size: usize = 1 << max_bits;

const BitReader = struct {
    input: []const u8,
    byte_offset: usize = 0,
    reservoir: u64 = 0,
    bit_count: u8 = 0,

    fn read(self: *BitReader, count: u4) Error!u16 {
        while (self.bit_count < count) {
            if (self.byte_offset == self.input.len) return error.TruncatedShrinkInput;
            self.reservoir |= @as(u64, self.input[self.byte_offset]) << @intCast(self.bit_count);
            self.byte_offset += 1;
            self.bit_count += 8;
        }
        const result: u16 = @truncate(self.reservoir & ((@as(u64, 1) << count) - 1));
        self.reservoir >>= count;
        self.bit_count -= count;
        return result;
    }

    fn finish(self: *const BitReader) Error!void {
        if (self.byte_offset != self.input.len) return error.ShrinkTrailingData;
        if (self.reservoir != 0) return error.ShrinkTrailingData;
    }
};

const BitWriter = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    reservoir: u64 = 0,
    bit_count: u8 = 0,

    fn write(self: *BitWriter, value: u16, count: u4) Error!void {
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

pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    if (output.len == 0) {
        if (input.len != 0) return error.ShrinkTrailingData;
        return;
    }

    var parents: [dictionary_size]u16 = @splat(empty_code);
    var suffixes: [dictionary_size]u8 = undefined;
    var stack: [dictionary_size]u8 = undefined;
    var parent_marks: [dictionary_size]bool = @splat(false);
    var reader = BitReader{ .input = input };
    var bits: u4 = min_bits;
    var head: u16 = first_free_code;
    var last_symbol: ?u16 = null;
    var last_character: u8 = 0;
    var output_offset: usize = 0;

    while (output_offset < output.len) {
        var symbol = try reader.read(bits);
        if (symbol == control_code) {
            const command = try reader.read(bits);
            switch (command) {
                1 => {
                    if (bits == max_bits) return error.InvalidShrinkStream;
                    bits += 1;
                },
                2 => {
                    @memset(&parent_marks, false);
                    for (first_free_code..dictionary_size) |index| {
                        const parent = parents[index];
                        if (parent != empty_code) parent_marks[parent] = true;
                    }
                    for (first_free_code..dictionary_size) |index| {
                        if (!parent_marks[index]) parents[index] = empty_code;
                    }
                    head = first_free_code;
                },
                else => return error.InvalidShrinkStream,
            }
            continue;
        }

        var inserted: ?u16 = null;
        if (last_symbol != null and head < dictionary_size) {
            while (head < dictionary_size and parents[head] != empty_code) head += 1;
            if (head < dictionary_size) {
                parents[head] = last_symbol.?;
                suffixes[head] = last_character;
                inserted = head;
                head += 1;
            }
        }

        last_symbol = symbol;
        var stack_size: usize = 0;
        while (symbol >= 256) {
            if (symbol >= dictionary_size or stack_size == stack.len)
                return error.InvalidShrinkStream;
            stack[stack_size] = suffixes[symbol];
            stack_size += 1;
            symbol = parents[symbol];
            if (symbol == empty_code) return error.InvalidShrinkStream;
        }
        stack[stack_size] = @intCast(symbol);
        stack_size += 1;
        last_character = @intCast(symbol);
        if (inserted) |code| suffixes[code] = last_character;
        if (stack_size > output.len - output_offset) return error.ShrinkSizeMismatch;
        while (stack_size != 0) {
            stack_size -= 1;
            output[output_offset] = stack[stack_size];
            output_offset += 1;
        }
    }
    try reader.finish();
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    if (input.len == 0) return 0;

    var dictionary = std.AutoHashMap(u32, u16).init(allocator);
    defer dictionary.deinit();
    try dictionary.ensureTotalCapacity(dictionary_size - first_free_code);
    var writer = BitWriter{ .allocator = allocator, .output = output };
    var bits: u4 = min_bits;
    var next_code: u16 = first_free_code;
    var prefix: u16 = input[0];

    for (input[1..]) |byte| {
        const key = (@as(u32, prefix) << 8) | byte;
        if (dictionary.get(key)) |code| {
            prefix = code;
            continue;
        }
        try writer.write(prefix, bits);
        if (next_code < dictionary_size) {
            if (next_code == @as(u16, 1) << bits) {
                try writer.write(control_code, bits);
                try writer.write(1, bits);
                bits += 1;
            }
            try dictionary.put(key, next_code);
            next_code += 1;
        }
        prefix = byte;
    }
    try writer.write(prefix, bits);
    try writer.finish();
    return output.items.len - start;
}

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input);
    return output.toOwnedSlice(allocator);
}

test "ZIP Shrink round trips empty text binary and width growth" {
    const binary = [_]u8{0x00} ++ [_]u8{0xff} ++ ([_]u8{ 1, 2, 3, 4 } ** 1024);
    inline for (.{ "", "a", "abracadabra", "Shrink LZW payload\n" ** 512, &binary }) |input| {
        const encoded = try encodeAlloc(std.testing.allocator, input);
        defer std.testing.allocator.free(encoded);
        const decoded = try std.testing.allocator.alloc(u8, input.len);
        defer std.testing.allocator.free(decoded);
        try decodeInto(encoded, decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "ZIP Shrink decoder handles partial clear and rejects malformed controls" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .allocator = std.testing.allocator, .output = &encoded };
    inline for (.{ @as(u16, 'A'), @as(u16, 'B'), control_code, 2, @as(u16, 'A') }) |code|
        try writer.write(code, min_bits);
    try writer.finish();
    var decoded: [3]u8 = undefined;
    try decodeInto(encoded.items, &decoded);
    try std.testing.expectEqualSlices(u8, "ABA", &decoded);

    encoded.clearRetainingCapacity();
    writer = .{ .allocator = std.testing.allocator, .output = &encoded };
    try writer.write(control_code, min_bits);
    try writer.write(3, min_bits);
    try writer.finish();
    try std.testing.expectError(error.InvalidShrinkStream, decodeInto(encoded.items, decoded[0..1]));

    encoded.clearRetainingCapacity();
    writer = .{ .allocator = std.testing.allocator, .output = &encoded };
    inline for (.{ @as(u16, 'A'), @as(u16, 'B'), first_free_code }) |code|
        try writer.write(code, min_bits);
    try writer.finish();
    try std.testing.expectError(error.ShrinkSizeMismatch, decodeInto(encoded.items, &decoded));
}

test "ZIP Shrink decoder rejects truncation output mismatch and trailing data" {
    const encoded = try encodeAlloc(std.testing.allocator, "shrink payload");
    defer std.testing.allocator.free(encoded);
    var output: ["shrink payload".len]u8 = undefined;
    try std.testing.expectError(
        error.TruncatedShrinkInput,
        decodeInto(encoded[0 .. encoded.len - 1], &output),
    );
    try std.testing.expectError(error.ShrinkTrailingData, decodeInto(encoded, output[0 .. output.len - 1]));
    var trailing = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(trailing);
    trailing = try std.testing.allocator.realloc(trailing, trailing.len + 1);
    trailing[trailing.len - 1] = 0;
    try std.testing.expectError(error.ShrinkTrailingData, decodeInto(trailing, &output));
}

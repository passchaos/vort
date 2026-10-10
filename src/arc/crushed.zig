const std = @import("std");
const core = @import("../core.zig");
const rle = @import("rle.zig");

pub const Error = core.Error || rle.Error || std.mem.Allocator.Error || error{
    InvalidArcCrushedStream,
};

const table_size_limit: usize = 8192;
const reserved_entries: usize = 257;
const eof_symbol: usize = 256;

const BitReader = struct {
    input: []const u8,
    bit_offset: usize = 0,

    fn read(self: *BitReader, count: u5) Error!u16 {
        const total = self.input.len * 8;
        if (self.bit_offset > total or count > total - self.bit_offset)
            return error.TruncatedFrame;
        var result: u16 = 0;
        for (0..count) |index| {
            const position = self.bit_offset + index;
            result |= @as(u16, (self.input[position / 8] >> @intCast(position % 8)) & 1) <<
                @intCast(index);
        }
        self.bit_offset += count;
        return result;
    }

    fn finish(self: *const BitReader) Error!void {
        var position = self.bit_offset;
        while (position < self.input.len * 8) : (position += 1)
            if ((self.input[position / 8] >> @intCast(position % 8)) & 1 != 0)
                return error.TrailingData;
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

    fn finish(self: *BitWriter) Error!void {
        if (self.bit_count != 0)
            try self.output.append(self.allocator, @truncate(self.reservoir));
        self.reservoir = 0;
        self.bit_count = 0;
    }
};

const Entry = struct { parent: i32 = -1, byte: u8 = 0 };

const State = struct {
    table: [table_size_limit]Entry = @splat(.{}),
    usage: [table_size_limit]u8 = @splat(0),
    table_size: usize = reserved_entries,
    code_bits: u5 = 1,
    next_bump: usize = 2,
    literal_mode: bool = true,
    ring: [500]bool = @splat(false),
    ring_offset: usize = 0,
    string_count: usize = 0,
    usage_offset: usize = reserved_entries,
    previous_symbol: ?usize = null,

    fn init() State {
        var self = State{};
        for (0..256) |symbol| self.table[symbol] = .{ .byte = @intCast(symbol) };
        for (self.usage[0..reserved_entries]) |*value| value.* = 4;
        return self;
    }

    fn readSymbol(self: *const State, reader: *BitReader) Error!usize {
        if (self.literal_mode) {
            if (try reader.read(1) == 0) return try reader.read(8);
            return @as(usize, try reader.read(self.code_bits)) + 256;
        }
        const code = try reader.read(self.code_bits);
        return if (code < 256) code ^ 0xff else code;
    }

    fn updateMode(self: *State, is_string: bool) void {
        if (self.ring[self.ring_offset]) self.string_count -= 1;
        self.ring[self.ring_offset] = is_string;
        if (is_string) self.string_count += 1;
        self.ring_offset = (self.ring_offset + 1) % self.ring.len;
        const literal_mode = self.string_count < 375;
        if (literal_mode != self.literal_mode) {
            self.literal_mode = literal_mode;
            self.next_bump = (@as(usize, 1) << @intCast(self.code_bits)) -
                @as(usize, @intFromBool(!literal_mode)) * 0x100;
        }
    }

    fn checkCodeSize(self: *State) void {
        const added = self.table_size - reserved_entries;
        if (added >= self.next_bump and self.code_bits < 13) {
            self.code_bits += 1;
            self.next_bump = (@as(usize, 1) << @intCast(self.code_bits)) -
                @as(usize, @intFromBool(!self.literal_mode)) * 0x100;
        }
    }

    fn firstByte(self: *const State, start: usize) Error!u8 {
        var symbol = start;
        for (0..table_size_limit + 1) |_| {
            if (symbol >= self.table_size) return error.InvalidArcCrushedStream;
            const parent = self.table[symbol].parent;
            if (parent < 0) return self.table[symbol].byte;
            symbol = @intCast(parent);
        }
        return error.InvalidArcCrushedStream;
    }

    fn markUsed(self: *State, start: usize) Error!void {
        var symbol = start;
        for (0..table_size_limit + 1) |_| {
            if (symbol >= self.table_size) return error.InvalidArcCrushedStream;
            self.usage[symbol] = 4;
            const parent = self.table[symbol].parent;
            if (parent < 0) return;
            symbol = @intCast(parent);
        }
        return error.InvalidArcCrushedStream;
    }

    fn addEntry(self: *State, symbol: usize) Error!void {
        const previous = self.previous_symbol orelse {
            self.previous_symbol = symbol;
            return;
        };
        const first = if (symbol == self.table_size)
            try self.firstByte(previous)
        else
            try self.firstByte(symbol);
        if (self.table_size < table_size_limit) {
            self.table[self.table_size] = .{ .parent = @intCast(previous), .byte = first };
            self.usage[self.table_size] = 2;
            self.table_size += 1;
        } else {
            var minimum_index = reserved_entries;
            var minimum_usage: u8 = std.math.maxInt(u8);
            var index = self.usage_offset;
            while (true) {
                index += 1;
                if (index == table_size_limit) index = reserved_entries;
                if (self.usage[index] < minimum_usage) {
                    minimum_index = index;
                    minimum_usage = self.usage[index];
                }
                if (self.usage[index] > 0) self.usage[index] -= 1;
                if (self.usage[index] == 0 or index == self.usage_offset) break;
            }
            self.usage_offset = index;
            self.table[minimum_index] = .{ .parent = @intCast(previous), .byte = first };
            self.usage[minimum_index] = 2;
        }
        self.previous_symbol = symbol;
    }

    fn decodeString(
        self: *const State,
        symbol: usize,
        stack: *[table_size_limit + 1]u8,
    ) Error!usize {
        var stack_len: usize = 0;
        var current = if (symbol == self.table_size)
            self.previous_symbol orelse return error.InvalidArcCrushedStream
        else
            symbol;
        while (true) {
            if (current >= self.table_size or stack_len == stack.len)
                return error.InvalidArcCrushedStream;
            stack[stack_len] = self.table[current].byte;
            stack_len += 1;
            const parent = self.table[current].parent;
            if (parent < 0) break;
            current = @intCast(parent);
        }
        if (symbol == self.table_size) {
            const first = stack[stack_len - 1];
            std.mem.copyBackwards(u8, stack[1 .. stack_len + 1], stack[0..stack_len]);
            stack[0] = first;
            stack_len += 1;
        }
        return stack_len;
    }
};

pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    if (input.len == 0) {
        if (output.len != 0) return error.SizeMismatch;
        return;
    }
    var state = State.init();
    var reader = BitReader{ .input = input };
    var decoder = rle.Decoder{};
    var stack: [table_size_limit + 1]u8 = undefined;
    while (true) {
        const symbol = try state.readSymbol(&reader);
        if (symbol == eof_symbol) break;
        if (symbol > state.table_size or symbol >= table_size_limit)
            return error.InvalidArcCrushedStream;
        if (symbol < state.table_size)
            try state.markUsed(symbol)
        else if (state.previous_symbol) |previous|
            try state.markUsed(previous);
        state.updateMode(symbol >= 256);
        var stack_len = try state.decodeString(symbol, &stack);
        while (stack_len != 0) {
            stack_len -= 1;
            try decoder.feed(stack[stack_len], output);
        }
        try state.addEntry(symbol);
        state.checkCodeSize();
    }
    try decoder.finish(output.len);
    try reader.finish();
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
    errdefer output.items.len = start;
    const source = try rle.encodeAlloc(allocator, input);
    defer allocator.free(source);
    var state = State.init();
    var writer = BitWriter{ .allocator = allocator, .output = output };
    for (source) |literal| {
        std.debug.assert(state.literal_mode);
        try writer.write(0, 1);
        try writer.write(literal, 8);
        state.updateMode(false);
        try state.addEntry(literal);
        state.checkCodeSize();
    }
    try writer.write(1, 1);
    try writer.write(0, state.code_bits);
    try writer.finish();
    return output.items.len - start;
}

test "PAK Crushed literal writer round trips across code growth" {
    const input = ("Crushed PAK payload\n" ** 512) ++ ([_]u8{ 0x90, 0, 1 } ** 64);
    const encoded = try encodeAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(encoded);
    var decoded: [input.len]u8 = undefined;
    try decodeInto(encoded, &decoded);
    try std.testing.expectEqualSlices(u8, input, &decoded);
}

test "PAK Crushed rejects truncation bad symbols and output limits" {
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, decodeInto(&.{}, &output));
    try std.testing.expectError(error.TruncatedFrame, decodeInto(&.{ 0, 0 }, &output));
}

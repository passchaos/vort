const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidLhStream,
    InvalidLhMethod,
};

pub const Method = enum {
    lh5,
    lh6,
    lh7,

    pub fn dictionaryBits(self: Method) u5 {
        return switch (self) {
            .lh5 => 13,
            .lh6 => 15,
            .lh7 => 16,
        };
    }

    fn offsetBits(self: Method) u6 {
        return switch (self) {
            .lh5 => 4,
            .lh6, .lh7 => 5,
        };
    }
};

const max_code_length: usize = 16;
const temp_symbol_count: usize = 31;
const command_symbol_count: usize = 510;
const max_offset_symbol_count: usize = 31;
const copy_threshold: usize = 3;

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
        self.reservoir &= lowMask(self.bit_count);
        return result & @as(u32, @intCast(lowMask(count)));
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
        std.debug.assert(@as(u64, value) <= lowMask(count));
        self.reservoir = (self.reservoir << @intCast(count)) | value;
        self.bit_count += count;
        while (self.bit_count >= 8) {
            const shift: u7 = self.bit_count - 8;
            try self.output.append(
                self.allocator,
                @truncate(self.reservoir >> @intCast(shift)),
            );
            self.bit_count -= 8;
            self.reservoir &= lowMask(self.bit_count);
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

fn lowMask(count: anytype) u64 {
    const bits: u7 = @intCast(count);
    if (bits == 0) return 0;
    return (@as(u64, 1) << @intCast(bits)) - 1;
}

fn DecodeTable(comptime symbol_count: usize) type {
    return struct {
        single: ?u16 = null,
        counts: [max_code_length + 1]u16 = @splat(0),
        symbols: [symbol_count]u16 = @splat(0),

        const Self = @This();

        fn initSingle(symbol: usize) Error!Self {
            if (symbol >= symbol_count) return error.InvalidLhStream;
            return .{ .single = @intCast(symbol) };
        }

        fn init(lengths: *const [symbol_count]u8) Error!Self {
            var table = Self{};
            var used: usize = 0;
            for (lengths) |length| {
                if (length > max_code_length) return error.InvalidLhStream;
                if (length != 0) {
                    table.counts[length] += 1;
                    used += 1;
                }
            }
            if (used == 0) return error.InvalidLhStream;

            var left: i32 = 1;
            for (1..max_code_length + 1) |length| {
                left = (left << 1) - table.counts[length];
                if (left < 0) return error.InvalidLhStream;
            }

            var offsets: [max_code_length + 1]u16 = @splat(0);
            for (1..max_code_length) |length|
                offsets[length + 1] = offsets[length] + table.counts[length];
            var write_offsets = offsets;
            for (lengths, 0..) |length, symbol| {
                if (length != 0) {
                    table.symbols[write_offsets[length]] = @intCast(symbol);
                    write_offsets[length] += 1;
                }
            }
            return table;
        }

        fn decode(self: *const Self, reader: *BitReader) Error!u16 {
            if (self.single) |symbol| return symbol;
            var code: u32 = 0;
            var first: u32 = 0;
            var index: usize = 0;
            for (1..max_code_length + 1) |length| {
                code = (code << 1) | try reader.read(1);
                const count = self.counts[length];
                if (code >= first and code - first < count)
                    return self.symbols[index + code - first];
                index += count;
                first = (first + count) << 1;
            }
            return error.InvalidLhStream;
        }
    };
}

pub fn decodeInto(
    input: []const u8,
    output: []u8,
    method: Method,
) Error!void {
    if (output.len == 0) {
        if (input.len != 0) return error.TrailingData;
        return;
    }

    var reader = BitReader{ .input = input };
    var output_offset: usize = 0;
    var block_remaining: usize = 0;
    var command_table: DecodeTable(command_symbol_count) = undefined;
    var offset_table: DecodeTable(max_offset_symbol_count) = undefined;

    while (output_offset < output.len) {
        if (block_remaining == 0) {
            block_remaining = try reader.read(16);
            if (block_remaining == 0) return error.InvalidLhStream;
            const temp_table = try readTempTable(&reader);
            command_table = try readCommandTable(&reader, &temp_table);
            offset_table = try readOffsetTable(&reader, method);
        }

        block_remaining -= 1;
        const command = try command_table.decode(&reader);
        if (command < 256) {
            output[output_offset] = @intCast(command);
            output_offset += 1;
            continue;
        }

        const match_len = @as(usize, command) - 256 + copy_threshold;
        if (match_len > output.len - output_offset) return error.SizeMismatch;
        const offset_symbol = try offset_table.decode(&reader);
        if (offset_symbol > method.dictionaryBits()) return error.InvalidLhStream;
        const stored_offset: usize = if (offset_symbol == 0)
            0
        else if (offset_symbol == 1)
            1
        else blk: {
            const extra_bits: u6 = @intCast(offset_symbol - 1);
            const low = try reader.read(extra_bits);
            break :blk (@as(usize, 1) << @intCast(extra_bits)) + low;
        };
        const distance = stored_offset + 1;
        if (distance > @as(usize, 1) << method.dictionaryBits())
            return error.InvalidLhStream;
        copyMatch(output, &output_offset, distance, match_len);
    }

    if (block_remaining != 0) return error.SizeMismatch;
    try reader.finish();
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
    method: Method,
) Error![]u8 {
    return decodeAllocLimited(allocator, input, output_len, method, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    output_len: usize,
    method: Method,
    max_output_len: usize,
) Error![]u8 {
    if (output_len > max_output_len) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    try decodeInto(input, output, method);
    return output;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    method: Method,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, method);
    return output.toOwnedSlice(allocator);
}

/// Emit deterministic literal-only new-style LH blocks.
///
/// This is a functionality-first writer. Match planning is intentionally left
/// for later ratio work; every method still emits a standard decodable stream.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    method: Method,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    if (input.len == 0) return 0;

    var writer = BitWriter{ .allocator = allocator, .output = output };
    var offset: usize = 0;
    while (offset < input.len) {
        const count = @min(@as(usize, std.math.maxInt(u16)), input.len - offset);
        try writer.write(@intCast(count), 16);
        try writeFixedTables(&writer, method);
        for (input[offset .. offset + count]) |literal|
            try writeCommand(&writer, literal);
        offset += count;
    }
    try writer.finish();
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    method: Method,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, method);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn readTempTable(reader: *BitReader) Error!DecodeTable(temp_symbol_count) {
    const count = try reader.read(5);
    if (count == 0) return DecodeTable(temp_symbol_count).initSingle(try reader.read(5));
    if (count > temp_symbol_count) return error.InvalidLhStream;

    var lengths: [temp_symbol_count]u8 = @splat(0);
    var index: usize = 0;
    while (index < count) : (index += 1) {
        lengths[index] = try readLengthValue(reader);
        if (index == 2) {
            const skip = try reader.read(2);
            if (skip > count - index - 1) return error.InvalidLhStream;
            index += skip;
        }
    }
    return DecodeTable(temp_symbol_count).init(&lengths);
}

fn readCommandTable(
    reader: *BitReader,
    temp_table: *const DecodeTable(temp_symbol_count),
) Error!DecodeTable(command_symbol_count) {
    const count = try reader.read(9);
    if (count == 0) return DecodeTable(command_symbol_count).initSingle(try reader.read(9));
    if (count > command_symbol_count) return error.InvalidLhStream;

    var lengths: [command_symbol_count]u8 = @splat(0);
    var index: usize = 0;
    while (index < count) {
        const code = try temp_table.decode(reader);
        if (code <= 2) {
            const skip: usize = switch (code) {
                0 => 1,
                1 => @as(usize, try reader.read(4)) + 3,
                2 => @as(usize, try reader.read(9)) + 20,
                else => unreachable,
            };
            if (skip > count - index) return error.InvalidLhStream;
            index += skip;
        } else {
            const length = code - 2;
            if (length > max_code_length) return error.InvalidLhStream;
            lengths[index] = @intCast(length);
            index += 1;
        }
    }
    return DecodeTable(command_symbol_count).init(&lengths);
}

fn readOffsetTable(
    reader: *BitReader,
    method: Method,
) Error!DecodeTable(max_offset_symbol_count) {
    const field_bits = method.offsetBits();
    const count = try reader.read(field_bits);
    const symbol_count = @as(usize, method.dictionaryBits()) + 1;
    if (count == 0) {
        const symbol = try reader.read(field_bits);
        if (symbol >= symbol_count) return error.InvalidLhStream;
        return DecodeTable(max_offset_symbol_count).initSingle(symbol);
    }
    if (count > symbol_count) return error.InvalidLhStream;

    var lengths: [max_offset_symbol_count]u8 = @splat(0);
    for (0..count) |index| lengths[index] = try readLengthValue(reader);
    return DecodeTable(max_offset_symbol_count).init(&lengths);
}

fn readLengthValue(reader: *BitReader) Error!u8 {
    var length: u8 = @intCast(try reader.read(3));
    if (length == 7) {
        while (try reader.read(1) != 0) {
            if (length == max_code_length) return error.InvalidLhStream;
            length += 1;
        }
    }
    return length;
}

fn writeFixedTables(writer: *BitWriter, method: Method) Error!void {
    // A complete 510-leaf command tree: symbols 0 and 1 use eight bits;
    // symbols 2...509 use nine. The temporary tree has one-bit symbols 10
    // and 11, which encode those command lengths as (symbol - 2).
    try writer.write(12, 5);
    try writer.write(0, 3);
    try writer.write(0, 3);
    try writer.write(0, 3);
    try writer.write(3, 2);
    inline for (0..4) |_| try writer.write(0, 3);
    try writer.write(1, 3);
    try writer.write(1, 3);

    try writer.write(command_symbol_count, 9);
    try writer.write(0, 1);
    try writer.write(0, 1);
    for (2..command_symbol_count) |_| try writer.write(1, 1);

    // Matches are not emitted yet, but a valid offset table is mandatory.
    try writer.write(0, method.offsetBits());
    try writer.write(0, method.offsetBits());
}

fn writeCommand(writer: *BitWriter, command: u16) Error!void {
    if (command >= command_symbol_count) return error.InvalidLhStream;
    if (command < 2)
        try writer.write(command, 8)
    else
        try writer.write(@as(u32, command) + 2, 9);
}

fn copyMatch(
    output: []u8,
    output_offset: *usize,
    distance: usize,
    count: usize,
) void {
    for (0..count) |_| {
        output[output_offset.*] = if (distance > output_offset.*)
            ' '
        else
            output[output_offset.* - distance];
        output_offset.* += 1;
    }
}

test "LH5 LH6 and LH7 literal writer round trip edge payloads" {
    const allocator = std.testing.allocator;
    var random: [70 * 1024]u8 = undefined;
    var state: u32 = 0x1a5a_7001;
    for (&random) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const cases = [_][]const u8{ "", "x", "new-style LHA payload" ** 256, &random };
    inline for (std.meta.tags(Method)) |method| {
        for (cases) |input| {
            const encoded = try encodeAlloc(allocator, input, method);
            defer allocator.free(encoded);
            const caller_encoded = try allocator.alloc(u8, encoded.len);
            defer allocator.free(caller_encoded);
            try std.testing.expectEqual(
                encoded.len,
                try encodeInto(allocator, input, caller_encoded, method),
            );
            try std.testing.expectEqualSlices(u8, encoded, caller_encoded);
            const decoded = try decodeAlloc(allocator, encoded, input.len, method);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, input, decoded);
            if (input.len != 0) {
                try std.testing.expectError(
                    error.OutputLimitExceeded,
                    decodeAllocLimited(allocator, encoded, input.len, method, input.len - 1),
                );
            }
        }
    }
}

test "new-style LH decoder accepts implicit space history" {
    // One match token (code 256 => length 3) and offset zero => distance one.
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .allocator = std.testing.allocator, .output = &encoded };
    try writer.write(1, 16);
    try writeFixedTables(&writer, .lh5);
    try writeCommand(&writer, 256);
    try writer.finish();
    var output: [3]u8 = undefined;
    try decodeInto(encoded.items, &output, .lh5);
    try std.testing.expectEqualSlices(u8, "   ", &output);
}

test "new-style LH decoder rejects truncation invalid tables and size mismatch" {
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto(&.{}, &output, .lh5));
    try std.testing.expectError(error.InvalidLhStream, decodeInto(&.{ 0, 0 }, &output, .lh5));

    const encoded = try encodeAlloc(std.testing.allocator, "ab", .lh5);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectError(error.SizeMismatch, decodeInto(encoded, &output, .lh5));
    var too_large: [3]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto(encoded, &too_large, .lh5));
}

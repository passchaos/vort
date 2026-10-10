const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidArcDistilledStream,
};

const eof_symbol: usize = 0x100;
const max_nodes: usize = 0x274;
const writer_nodes: usize = 512;
const writer_symbols: usize = 257;

const offset_lengths = [64]u4{
    3, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
};
const offset_codes = [64]u8{
    0x00, 0x02, 0x04, 0x0c, 0x01, 0x06, 0x0a, 0x0e,
    0x11, 0x16, 0x1a, 0x1e, 0x05, 0x09, 0x0d, 0x15,
    0x19, 0x1d, 0x25, 0x29, 0x2d, 0x35, 0x39, 0x3d,
    0x03, 0x07, 0x0b, 0x13, 0x17, 0x1b, 0x23, 0x27,
    0x2b, 0x33, 0x37, 0x3b, 0x43, 0x47, 0x4b, 0x53,
    0x57, 0x5b, 0x63, 0x67, 0x6b, 0x73, 0x77, 0x7b,
    0x0f, 0x1f, 0x2f, 0x3f, 0x4f, 0x5f, 0x6f, 0x7f,
    0x8f, 0x9f, 0xaf, 0xbf, 0xcf, 0xdf, 0xef, 0xff,
};

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

pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    if (input.len < 3) return error.TruncatedFrame;
    const node_count = std.mem.readInt(u16, input[0..2], .little);
    const value_bits = input[2];
    if (node_count < 2 or node_count > max_nodes or value_bits == 0 or value_bits > 16)
        return error.InvalidArcDistilledStream;
    var reader = BitReader{ .input = input[3..] };
    var nodes: [max_nodes]u16 = @splat(0);
    for (nodes[0..node_count]) |*node| node.* = try reader.read(@intCast(value_bits));

    var output_offset: usize = 0;
    while (true) {
        const symbol = try decodeSymbol(&reader, &nodes, node_count);
        if (symbol < eof_symbol) {
            if (output_offset == output.len) return error.OutputTooSmall;
            output[output_offset] = @intCast(symbol);
            output_offset += 1;
        } else if (symbol == eof_symbol) {
            if (output_offset != output.len) return error.SizeMismatch;
            try reader.finish();
            return;
        } else {
            const match_len = symbol - 0x101 + 3;
            if (match_len > output.len - output_offset) return error.SizeMismatch;
            const offset_symbol = try decodeOffset(&reader);
            const extra_bits = extraBits(output_offset);
            const extra = try reader.read(extra_bits);
            const distance = (@as(usize, offset_symbol) << @intCast(extra_bits)) + extra + 1;
            for (0..match_len) |_| {
                output[output_offset] = if (distance > output_offset)
                    ' '
                else
                    output[output_offset - distance];
                output_offset += 1;
            }
        }
    }
}

fn decodeSymbol(
    reader: *BitReader,
    nodes: []const u16,
    node_count: usize,
) Error!usize {
    var node = node_count - 2;
    for (0..65) |_| {
        if (node + 1 >= node_count) return error.InvalidArcDistilledStream;
        const child = nodes[node + try reader.read(1)];
        if (child >= node_count) return child - node_count;
        node = child;
    }
    return error.InvalidArcDistilledStream;
}

fn decodeOffset(reader: *BitReader) Error!u8 {
    var code: u8 = 0;
    for (1..9) |length| {
        code |= @as(u8, @intCast(try reader.read(1))) << @intCast(length - 1);
        for (offset_lengths, offset_codes, 0..) |wanted_length, wanted_code, symbol| {
            if (wanted_length == length and wanted_code == code) return @intCast(symbol);
        }
    }
    return error.InvalidArcDistilledStream;
}

fn extraBits(position: usize) u5 {
    if (position >= 0x0fc4) return 7;
    if (position >= 0x07c4) return 6;
    if (position >= 0x03c4) return 5;
    if (position >= 0x01c4) return 4;
    if (position >= 0x00c4) return 3;
    if (position >= 0x0044) return 2;
    if (position >= 0x0004) return 1;
    return 0;
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
    var tree = FixedTree{};
    const root = tree.build(0, writer_symbols, 0, 0);
    std.debug.assert(root == writer_nodes - 2);
    try appendLe16(allocator, output, writer_nodes);
    try output.append(allocator, 10);
    var writer = BitWriter{ .allocator = allocator, .output = output };
    for (tree.nodes) |node| try writer.write(node, 10);
    for (input) |literal| try tree.writeSymbol(&writer, literal);
    try tree.writeSymbol(&writer, eof_symbol);
    try writer.finish();
    return output.items.len - start;
}

const FixedTree = struct {
    nodes: [writer_nodes]u16 = @splat(0),
    codes: [writer_symbols]u16 = @splat(0),
    lengths: [writer_symbols]u5 = @splat(0),
    next_node: usize = 0,

    fn build(
        self: *FixedTree,
        start: usize,
        end: usize,
        depth: u5,
        code: u16,
    ) u16 {
        if (end - start == 1) {
            self.codes[start] = code;
            self.lengths[start] = depth;
            return @intCast(writer_nodes + start);
        }
        const middle = start + (end - start) / 2;
        const left = self.build(start, middle, depth + 1, code);
        const right = self.build(
            middle,
            end,
            depth + 1,
            code | (@as(u16, 1) << @intCast(depth)),
        );
        const node = self.next_node;
        self.next_node += 2;
        self.nodes[node] = left;
        self.nodes[node + 1] = right;
        return @intCast(node);
    }

    fn writeSymbol(
        self: *const FixedTree,
        writer: *BitWriter,
        symbol: usize,
    ) Error!void {
        try writer.write(self.codes[symbol], self.lengths[symbol]);
    }
};

fn appendLe16(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u16,
) Error!void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

test "PAK Distilled fixed tree round trips arbitrary literals" {
    const input = "Distilled PAK payload\n" ** 256;
    const encoded = try encodeAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(encoded);
    var decoded: [input.len]u8 = undefined;
    try decodeInto(encoded, &decoded);
    try std.testing.expectEqualSlices(u8, input, &decoded);
}

test "PAK Distilled rejects bad headers trees and output sizes" {
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto(&.{}, &output));
    try std.testing.expectError(
        error.InvalidArcDistilledStream,
        decodeInto(&.{ 1, 0, 1, 0 }, &output),
    );
}

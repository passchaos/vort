const std = @import("std");
const core = @import("../core.zig");
const rle = @import("rle.zig");

pub const Error = core.Error || rle.Error || std.mem.Allocator.Error || error{
    InvalidArcSqueezeStream,
};

const symbol_count: usize = 257;
const node_count: usize = symbol_count - 1;
const eof_symbol: usize = 256;

const BitReader = struct {
    input: []const u8,
    byte_offset: usize = 0,
    reservoir: u64 = 0,
    bit_count: u7 = 0,

    fn read(self: *BitReader, count: u6) Error!u32 {
        if (count == 0) return 0;
        while (self.bit_count < count) {
            if (self.byte_offset == self.input.len) return error.TruncatedFrame;
            self.reservoir |= @as(u64, self.input[self.byte_offset]) << @intCast(self.bit_count);
            self.byte_offset += 1;
            self.bit_count += 8;
        }
        const result: u32 = @truncate(self.reservoir & mask(count));
        self.reservoir >>= @intCast(count);
        self.bit_count -= count;
        return result;
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

fn mask(count: anytype) u64 {
    const bits: u7 = @intCast(count);
    return if (bits == 0) 0 else (@as(u64, 1) << @intCast(bits)) - 1;
}

pub fn decodeInto(input: []const u8, output: []u8) Error!void {
    if (input.len < 2) return error.TruncatedFrame;
    const count = std.mem.readInt(u16, input[0..2], .little);
    if (count == 0) {
        if (output.len != 0) return error.SizeMismatch;
        if (input.len != 2) return error.TrailingData;
        return;
    }
    if (count > node_count) return error.InvalidArcSqueezeStream;
    const nodes_end = std.math.add(usize, 2, @as(usize, count) * 4) catch
        return error.IntegerOverflow;
    if (nodes_end > input.len) return error.TruncatedFrame;
    var nodes: [node_count][2]i16 = @splat(.{ 0, 0 });
    for (0..count) |index| {
        const start = 2 + index * 4;
        nodes[index][0] = @bitCast(std.mem.readInt(u16, input[start..][0..2], .little));
        nodes[index][1] = @bitCast(std.mem.readInt(u16, input[start + 2 ..][0..2], .little));
    }

    var reader = BitReader{ .input = input[nodes_end..] };
    var rle_decoder = rle.Decoder{};
    while (true) {
        var node_index: usize = 0;
        var steps: usize = 0;
        while (true) {
            if (node_index >= count or steps > count) return error.InvalidArcSqueezeStream;
            const child = nodes[node_index][try reader.read(1)];
            if (child < 0) {
                const symbol: usize = @intCast(-(child + 1));
                if (symbol > eof_symbol) return error.InvalidArcSqueezeStream;
                if (symbol == eof_symbol) {
                    try rle_decoder.finish(output.len);
                    try reader.finish();
                    return;
                }
                try rle_decoder.feed(@intCast(symbol), output);
                break;
            }
            node_index = @intCast(child);
            steps += 1;
        }
    }
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
    const encoded_rle = try rle.encodeAlloc(allocator, input);
    defer allocator.free(encoded_rle);

    var tree = FixedTree{};
    _ = tree.build(0, symbol_count, 0, 0);
    try appendLe16(allocator, output, node_count);
    for (tree.nodes) |node| {
        try appendLe16(allocator, output, @bitCast(node[0]));
        try appendLe16(allocator, output, @bitCast(node[1]));
    }
    var writer = BitWriter{ .allocator = allocator, .output = output };
    for (encoded_rle) |byte| try tree.writeSymbol(&writer, byte);
    try tree.writeSymbol(&writer, eof_symbol);
    try writer.finish();
    return output.items.len - start;
}

const FixedTree = struct {
    nodes: [node_count][2]i16 = @splat(.{ 0, 0 }),
    codes: [symbol_count]u16 = @splat(0),
    lengths: [symbol_count]u5 = @splat(0),
    next_node: usize = 0,

    fn build(
        self: *FixedTree,
        start: usize,
        end: usize,
        depth: u5,
        code: u16,
    ) i16 {
        if (end - start == 1) {
            self.codes[start] = code;
            self.lengths[start] = depth;
            return -@as(i16, @intCast(start)) - 1;
        }
        const node = self.next_node;
        self.next_node += 1;
        const middle = start + (end - start) / 2;
        self.nodes[node][0] = self.build(start, middle, depth + 1, code);
        self.nodes[node][1] = self.build(
            middle,
            end,
            depth + 1,
            code | (@as(u16, 1) << @intCast(depth)),
        );
        return @intCast(node);
    }

    fn writeSymbol(
        self: *const FixedTree,
        writer: *BitWriter,
        symbol: usize,
    ) Error!void {
        if (symbol >= symbol_count) return error.InvalidArcSqueezeStream;
        try writer.write(self.codes[symbol], @intCast(self.lengths[symbol]));
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

test "ARC Squeeze fixed tree round trips RLE-sensitive payloads" {
    const allocator = std.testing.allocator;
    const input = ("Squeezed ARC payload\n" ** 128) ++ ([_]u8{ 0x90, 0, 1 } ** 32);
    const encoded = try encodeAlloc(allocator, input);
    defer allocator.free(encoded);
    var decoded: [input.len]u8 = undefined;
    try decodeInto(encoded, &decoded);
    try std.testing.expectEqualSlices(u8, input, &decoded);
}

test "ARC Squeeze rejects invalid trees truncation and output mismatch" {
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeInto(&.{}, &output));
    try std.testing.expectError(error.InvalidArcSqueezeStream, decodeInto(&.{ 1, 1 }, &output));
    try std.testing.expectError(error.SizeMismatch, decodeInto(&.{ 0, 0 }, &output));
}

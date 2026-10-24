const std = @import("std");
const incremental = @import("implode/incremental_decoder.zig");

pub const Error = incremental.Error || std.mem.Allocator.Error || error{
    InvalidImplodeOptions,
};

pub const Dictionary = incremental.Dictionary;
pub const IncrementalDecoder = incremental.Decoder;
pub const IncrementalWorkspace = incremental.Workspace;

pub const Options = struct {
    dictionary: Dictionary = .large_8k,
    literal_tree: bool = true,
    max_chain: u16 = 64,

    pub fn flags(self: Options) u16 {
        return (@as(u16, @intFromBool(self.dictionary == .large_8k)) << 1) |
            (@as(u16, @intFromBool(self.literal_tree)) << 2);
    }
};

const max_tree_bits: usize = 16;
const literal_symbols: usize = 256;
const length_symbols: usize = 64;
const distance_symbols: usize = 64;
const length_direct_bits: u5 = 8;

const BitReader = struct {
    input: []const u8,
    byte_offset: usize = 0,
    reservoir: u64 = 0,
    bit_count: u8 = 0,

    fn alignedByte(self: *BitReader) Error!u8 {
        if (self.bit_count != 0) return error.InvalidImplodeStream;
        if (self.byte_offset == self.input.len) return error.TruncatedImplodeInput;
        const byte = self.input[self.byte_offset];
        self.byte_offset += 1;
        return byte;
    }

    fn read(self: *BitReader, count: u5) Error!u16 {
        while (self.bit_count < count) {
            if (self.byte_offset == self.input.len) return error.TruncatedImplodeInput;
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
        if (self.byte_offset != self.input.len) return error.ImplodeTrailingData;
    }
};

const BitWriter = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    reservoir: u64 = 0,
    bit_count: u8 = 0,

    fn write(self: *BitWriter, value: u16, count: u5) Error!void {
        std.debug.assert(value < @as(u16, 1) << @intCast(count));
        self.reservoir |= @as(u64, value) << @intCast(self.bit_count);
        self.bit_count += @intCast(count);
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

const Tree = struct {
    starts: [max_tree_bits + 1]u16 = @splat(0),
    counts: [max_tree_bits + 1]u16 = @splat(0),
    poses: [max_tree_bits + 1]u16 = @splat(0),
    symbols: [literal_symbols]u8 = @splat(0),

    fn parse(reader: *BitReader, symbol_count: usize) Error!Tree {
        var lengths: [literal_symbols]u8 = @splat(0);
        const record_count = @as(usize, try reader.alignedByte()) + 1;
        var index: usize = 0;
        for (0..record_count) |_| {
            const descriptor = try reader.alignedByte();
            const length = (descriptor & 0x0f) + 1;
            const repetitions = @as(usize, descriptor >> 4) + 1;
            if (index + repetitions > symbol_count) return error.InvalidImplodeStream;
            @memset(lengths[index .. index + repetitions], length);
            index += repetitions;
        }
        if (index != symbol_count) return error.InvalidImplodeStream;

        var tree = Tree{};
        for (lengths[0..symbol_count]) |length| tree.counts[length] += 1;
        var start_position: u32 = 1 << max_tree_bits;
        var symbol_position: u16 = 0;
        for (1..max_tree_bits + 1) |length| {
            const range = @as(u32, tree.counts[length]) << @intCast(max_tree_bits - length);
            if (start_position < range) return error.InvalidImplodeStream;
            start_position -= range;
            tree.starts[length] = @intCast(start_position >> @intCast(max_tree_bits - length));
            tree.poses[length] = symbol_position;
            symbol_position += tree.counts[length];
        }
        if (start_position != 0) return error.InvalidImplodeStream;
        for (1..max_tree_bits + 1) |length| {
            var position = tree.poses[length];
            var symbol = symbol_count;
            while (symbol != 0) {
                symbol -= 1;
                if (lengths[symbol] == length) {
                    tree.symbols[position] = @intCast(symbol);
                    position += 1;
                }
            }
        }
        return tree;
    }

    fn decode(self: *const Tree, reader: *BitReader) Error!u8 {
        var code: u16 = 0;
        for (1..max_tree_bits + 1) |length| {
            code = (code << 1) | try reader.read(1);
            const start = self.starts[length];
            const count = self.counts[length];
            if (code >= start and code - start < count)
                return self.symbols[self.poses[length] + code - start];
        }
        return error.InvalidImplodeStream;
    }
};

pub fn decodeInto(input: []const u8, output: []u8, flags: u16) Error!void {
    const options = optionsFromFlags(flags);
    var reader = BitReader{ .input = input };
    const literal_tree = if (options.literal_tree)
        try Tree.parse(&reader, literal_symbols)
    else
        null;
    const length_tree = try Tree.parse(&reader, length_symbols);
    const distance_tree = try Tree.parse(&reader, distance_symbols);
    const distance_bits: u5 = if (options.dictionary == .large_8k) 7 else 6;
    const minimum_length: usize = if (options.literal_tree) 3 else 2;
    var output_offset: usize = 0;

    while (output_offset < output.len) {
        if (try reader.read(1) != 0) {
            output[output_offset] = if (literal_tree) |tree|
                try tree.decode(&reader)
            else
                @truncate(try reader.read(8));
            output_offset += 1;
            continue;
        }

        const low_distance = try reader.read(distance_bits);
        const distance_symbol = try distance_tree.decode(&reader);
        const stored_distance = (@as(usize, distance_symbol) << @intCast(distance_bits)) |
            low_distance;
        const length_symbol = try length_tree.decode(&reader);
        var length = @as(usize, length_symbol);
        if (length_symbol == length_symbols - 1)
            length += try reader.read(length_direct_bits);
        length += minimum_length;
        if (length > output.len - output_offset) return error.ImplodeSizeMismatch;
        for (0..length) |_| {
            output[output_offset] = if (stored_distance < output_offset)
                output[output_offset - stored_distance - 1]
            else
                0;
            output_offset += 1;
        }
    }
    try reader.finish();
}

fn optionsFromFlags(flags: u16) Options {
    return .{
        .dictionary = if (flags & 0x0002 != 0) .large_8k else .small_4k,
        .literal_tree = flags & 0x0004 != 0,
    };
}

fn appendFixedTree(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    symbol_count: usize,
    bit_length: u8,
) Error!void {
    std.debug.assert(symbol_count % 16 == 0);
    const records = symbol_count / 16;
    try output.append(allocator, @intCast(records - 1));
    const descriptor: u8 = 0xf0 | (bit_length - 1);
    try output.appendNTimes(allocator, descriptor, records);
}

fn reverseBits(value: u16, count: u5) u16 {
    var source = value;
    var result: u16 = 0;
    for (0..count) |_| {
        result = (result << 1) | (source & 1);
        source >>= 1;
    }
    return result;
}

fn writeFixedSymbol(writer: *BitWriter, symbol: u16, symbol_count: u16, bits: u5) Error!void {
    const code = symbol_count - 1 - symbol;
    try writer.write(reverseBits(code, bits), bits);
}

fn hashAt(input: []const u8, position: usize, minimum_length: usize) usize {
    if (minimum_length == 2)
        return (@as(usize, input[position]) << 8) | input[position + 1];
    return ((@as(usize, input[position]) * 251 + input[position + 1]) * 251 +
        input[position + 2]) & 0xffff;
}

fn insertPosition(
    input: []const u8,
    position: usize,
    minimum_length: usize,
    heads: []i32,
    previous: []i32,
) void {
    if (input.len - position < minimum_length) return;
    const hash = hashAt(input, position, minimum_length);
    previous[position % previous.len] = heads[hash];
    heads[hash] = @intCast(position);
}

const Match = struct { length: usize = 0, distance: usize = 0 };

fn findMatch(
    input: []const u8,
    position: usize,
    minimum_length: usize,
    maximum_length: usize,
    window_size: usize,
    max_chain: usize,
    heads: []const i32,
    previous: []const i32,
) Match {
    if (input.len - position < minimum_length or max_chain == 0) return .{};
    var candidate = heads[hashAt(input, position, minimum_length)];
    var remaining = max_chain;
    var best = Match{};
    while (candidate >= 0 and remaining != 0) : (remaining -= 1) {
        const source: usize = @intCast(candidate);
        const distance = position - source;
        if (distance == 0 or distance > window_size) break;
        var length: usize = 0;
        const limit = @min(maximum_length, input.len - position);
        while (length < limit and input[source + length] == input[position + length])
            length += 1;
        if (length > best.length and length >= minimum_length) {
            best = .{ .length = length, .distance = distance };
            if (length == limit) break;
        }
        candidate = previous[source % previous.len];
    }
    return best;
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: Options,
) Error!usize {
    if (options.max_chain == 0) return error.InvalidImplodeOptions;
    const start = output.items.len;
    errdefer output.items.len = start;
    if (options.literal_tree) try appendFixedTree(allocator, output, literal_symbols, 8);
    try appendFixedTree(allocator, output, length_symbols, 6);
    try appendFixedTree(allocator, output, distance_symbols, 6);

    const window_size: usize = if (options.dictionary == .large_8k) 8192 else 4096;
    const distance_bits: u5 = if (options.dictionary == .large_8k) 7 else 6;
    const minimum_length: usize = if (options.literal_tree) 3 else 2;
    const maximum_length = minimum_length + 63 + 255;
    const heads = try allocator.alloc(i32, 1 << 16);
    defer allocator.free(heads);
    @memset(heads, -1);
    const previous = try allocator.alloc(i32, window_size);
    defer allocator.free(previous);
    @memset(previous, -1);
    var writer = BitWriter{ .allocator = allocator, .output = output };
    var position: usize = 0;
    while (position < input.len) {
        const match = findMatch(
            input,
            position,
            minimum_length,
            maximum_length,
            window_size,
            options.max_chain,
            heads,
            previous,
        );
        if (match.length < minimum_length) {
            try writer.write(1, 1);
            if (options.literal_tree)
                try writeFixedSymbol(&writer, input[position], literal_symbols, 8)
            else
                try writer.write(input[position], 8);
            insertPosition(input, position, minimum_length, heads, previous);
            position += 1;
            continue;
        }

        try writer.write(0, 1);
        const stored_distance = match.distance - 1;
        try writer.write(@intCast(stored_distance & ((@as(usize, 1) << distance_bits) - 1)), distance_bits);
        try writeFixedSymbol(
            &writer,
            @intCast(stored_distance >> distance_bits),
            distance_symbols,
            6,
        );
        const stored_length = match.length - minimum_length;
        const length_symbol: u16 = @intCast(@min(stored_length, length_symbols - 1));
        try writeFixedSymbol(&writer, length_symbol, length_symbols, 6);
        if (length_symbol == length_symbols - 1)
            try writer.write(@intCast(stored_length - (length_symbols - 1)), length_direct_bits);
        for (0..match.length) |offset|
            insertPosition(input, position + offset, minimum_length, heads, previous);
        position += match.length;
    }
    try writer.finish();
    return output.items.len - start;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

test "ZIP Implode round trips all dictionary and literal-tree modes" {
    const input = ("Implode Shannon-Fano payload\n" ** 256) ++ ([_]u8{ 0, 1, 2, 3, 4, 5 } ** 128);
    inline for (.{ Dictionary.small_4k, .large_8k }) |dictionary| {
        inline for (.{ false, true }) |literal_tree| {
            const options = Options{ .dictionary = dictionary, .literal_tree = literal_tree };
            const encoded = try encodeAlloc(std.testing.allocator, input, options);
            defer std.testing.allocator.free(encoded);
            const decoded = try std.testing.allocator.alloc(u8, input.len);
            defer std.testing.allocator.free(decoded);
            try decodeInto(encoded, decoded, options.flags());
            try std.testing.expectEqualSlices(u8, input, decoded);
            try std.testing.expect(encoded.len < input.len);
        }
    }
}

test "ZIP Implode decoder accepts implicit zero history" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try appendFixedTree(std.testing.allocator, &encoded, length_symbols, 6);
    try appendFixedTree(std.testing.allocator, &encoded, distance_symbols, 6);
    var writer = BitWriter{ .allocator = std.testing.allocator, .output = &encoded };
    try writer.write(0, 1);
    try writer.write(3, 6);
    try writeFixedSymbol(&writer, 0, distance_symbols, 6);
    try writeFixedSymbol(&writer, 2, length_symbols, 6);
    try writer.finish();
    var output: [4]u8 = undefined;
    try decodeInto(encoded.items, &output, (Options{ .dictionary = .small_4k, .literal_tree = false }).flags());
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, &output);
}

test "ZIP Implode rejects malformed trees truncation and trailing data" {
    var one: [1]u8 = undefined;
    try std.testing.expectError(error.TruncatedImplodeInput, decodeInto(&.{}, &one, 0));
    try std.testing.expectError(
        error.InvalidImplodeStream,
        decodeInto(&.{ 0, 0 }, &one, 0),
    );
    const encoded = try encodeAlloc(std.testing.allocator, "implode payload", .{});
    defer std.testing.allocator.free(encoded);
    var output: ["implode payload".len]u8 = undefined;
    try std.testing.expectError(
        error.TruncatedImplodeInput,
        decodeInto(encoded[0 .. encoded.len - 1], &output, (Options{}).flags()),
    );
    var trailing = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(trailing);
    trailing = try std.testing.allocator.realloc(trailing, trailing.len + 1);
    trailing[trailing.len - 1] = 0;
    try std.testing.expectError(
        error.ImplodeTrailingData,
        decodeInto(trailing, &output, (Options{}).flags()),
    );
}

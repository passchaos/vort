const std = @import("std");
const core = @import("core.zig");
const bitstream = @import("bitstream.zig");
const huffman = @import("huffman.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

pub const max_uncompressed_meta_block_len: usize = 1 << 24;

pub const default_window_bits: u5 = 16;

pub const StoredStreamOptions = struct {
    window_bits: u5 = default_window_bits,
    metadata: []const u8 = "",
};

const BitWriter = struct {
    out: *std.ArrayList(u8),
    bit_index: u3 = 0,

    fn writeBits(self: *BitWriter, allocator: std.mem.Allocator, value: u64, count: u6) Error!void {
        if (count > 64) return error.CorruptFrame;
        var remaining = count;
        var cursor = value;
        while (remaining > 0) : (remaining -= 1) {
            if (self.bit_index == 0) try self.out.append(allocator, 0);
            if ((cursor & 1) != 0) self.out.items[self.out.items.len - 1] |= @as(u8, 1) << self.bit_index;
            cursor >>= 1;
            self.bit_index +%= 1;
        }
    }

    fn alignToByte(self: *BitWriter) void {
        self.bit_index = 0;
    }

    fn writeAlignedBytes(self: *BitWriter, allocator: std.mem.Allocator, bytes: []const u8) Error!void {
        if (self.bit_index != 0) return error.CorruptFrame;
        try self.out.appendSlice(allocator, bytes);
    }
};

pub fn PrefixCode(comptime alphabet_size: usize) type {
    return struct {
        single_symbol: ?u16 = null,
        table: huffman.HuffmanTable(alphabet_size) = .{},

        const Self = @This();

        pub fn decode(self: *const Self, reader: *bitstream.BitReader) Error!u16 {
            if (self.single_symbol) |symbol| return symbol;
            return try self.table.decodeValue(reader);
        }
    };
}

const MinimalCompressedHeader = struct {
    npostfix: u2,
    ndirect: u16,
    literal_context_modes: [max_literal_block_types]u2,
    literal_block: BlockSwitchState(max_literal_block_types),
    literal_context_map: [max_literal_block_types * 64]u8,
    literal_trees: [max_literal_context_trees]PrefixCode(256),
    command_block: BlockSwitchState(max_command_block_types),
    insert_copy_trees: [max_command_block_types]PrefixCode(704),
    distance_block: BlockSwitchState(max_distance_block_types),
    distance_context_map: [max_distance_block_types * 4]u8,
    distance_trees: [max_distance_context_trees]PrefixCode(max_distance_alphabet_size),
};

const max_distance_alphabet_size = 16 + 120 + (48 << 3);
const max_context_map_alphabet_size = 256 + 16;
const max_literal_block_types = 16;
const max_literal_context_trees = 16;
const max_command_block_types = 16;
const max_distance_block_types = 16;
const max_distance_context_trees = 16;
const initial_last_distances = [_]usize{ 16, 15, 11, 4 };

fn BlockSwitchState(comptime max_block_types: usize) type {
    return struct {
        block_type_count: u16 = 1,
        current_type: u16 = 0,
        previous_type: u16 = 1,
        remaining: usize = max_uncompressed_meta_block_len,
        type_tree: PrefixCode(max_block_types + 2) = .{},
        length_tree: PrefixCode(26) = .{},
    };
}

const InsertCopyLengths = struct {
    insert_len: usize,
    copy_len: usize,
    distance_symbol_zero: bool,
};

const LiteralHistory = struct {
    previous: [2]u8 = .{ 0, 0 },
    tail: [256]u8 = @splat(0),
    tail_len: usize = 0,
    tail_start: usize = 0,
    known: bool = true,

    fn context(self: *const LiteralHistory, header: *const MinimalCompressedHeader) Error!usize {
        if (!self.known) return error.UnsupportedBrotliFeature;
        return try literalContextFromMode(
            header.literal_context_modes[header.literal_block.current_type],
            self.previous[1],
            self.previous[0],
        );
    }

    fn push(self: *LiteralHistory, value: u8) void {
        self.previous[0] = self.previous[1];
        self.previous[1] = value;
        if (self.tail_len < self.tail.len) {
            self.tail[(self.tail_start + self.tail_len) % self.tail.len] = value;
            self.tail_len += 1;
        } else {
            self.tail[self.tail_start] = value;
            self.tail_start = (self.tail_start + 1) % self.tail.len;
        }
        self.known = true;
    }

    fn pushSlice(self: *LiteralHistory, bytes: []const u8) void {
        const keep = @min(bytes.len, self.tail.len);
        for (bytes[bytes.len - keep ..]) |value| self.push(value);
    }

    fn copy(self: *LiteralHistory, distance: usize, len: usize) void {
        if (!self.known or len == 0) return;
        if (distance == 0 or distance > self.tail_len) {
            self.known = false;
            return;
        }
        var i: usize = 0;
        while (i < len) : (i += 1) {
            const source_index = (self.tail_start + self.tail_len - distance) % self.tail.len;
            self.push(self.tail[source_index]);
        }
    }

    fn markUnknown(self: *LiteralHistory) void {
        self.known = false;
        self.tail_len = 0;
        self.tail_start = 0;
    }
};

pub fn encodeStoredStreamAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeStoredStreamWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeStoredStreamWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: StoredStreamOptions) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try encodeStoredStreamWithOptionsAppend(allocator, &out, input, options);
    return out.toOwnedSlice(allocator);
}

pub fn encodeStoredStreamAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8) Error!void {
    try encodeStoredStreamWithOptionsAppend(allocator, out, input, .{});
}

pub fn encodeStoredStreamWithOptionsAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, options: StoredStreamOptions) Error!void {
    var writer = BitWriter{ .out = out };
    try writeWindowBits(allocator, &writer, options.window_bits);
    if (options.metadata.len != 0) try writeMetadataMetaBlock(allocator, &writer, options.metadata);

    var offset: usize = 0;
    while (offset < input.len) {
        const block_len = @min(input.len - offset, max_uncompressed_meta_block_len);
        try writeUncompressedMetaBlock(allocator, &writer, input[offset..][0..block_len]);
        offset += block_len;
    }

    // End with an empty final meta-block. Brotli forbids marking an
    // uncompressed meta-block as the last one, so even non-empty stored streams
    // need this explicit terminator.
    try writer.writeBits(allocator, 1, 1); // ISLAST
    try writer.writeBits(allocator, 1, 1); // ISLASTEMPTY
}

pub fn encodeStoredStreamInto(input: []const u8, output: []u8) Error!usize {
    return try encodeStoredStreamWithOptionsInto(input, output, .{});
}

pub fn encodeStoredStreamWithOptionsInto(input: []const u8, output: []u8, options: StoredStreamOptions) Error!usize {
    var fba = std.heap.FixedBufferAllocator.init(output);
    const encoded = try encodeStoredStreamWithOptionsAlloc(fba.allocator(), input, options);
    return encoded.len;
}

fn writeUncompressedMetaBlock(allocator: std.mem.Allocator, writer: *BitWriter, block: []const u8) Error!void {
    if (block.len == 0 or block.len > max_uncompressed_meta_block_len) return error.InvalidBlockPlan;
    const len_minus_one = block.len - 1;
    const mnibbles: usize = if (len_minus_one <= 0xffff)
        4
    else if (len_minus_one <= 0xfffff)
        5
    else
        6;
    const mnibbles_code: u2 = switch (mnibbles) {
        4 => 0b00,
        5 => 0b01,
        6 => 0b10,
        else => unreachable,
    };

    try writer.writeBits(allocator, 0, 1); // ISLAST = false.
    try writer.writeBits(allocator, mnibbles_code, 2);
    try writer.writeBits(allocator, @intCast(len_minus_one), @intCast(mnibbles * 4));
    try writer.writeBits(allocator, 1, 1); // ISUNCOMPRESSED.
    writer.alignToByte();
    try writer.writeAlignedBytes(allocator, block);
}

fn writeMetadataMetaBlock(allocator: std.mem.Allocator, writer: *BitWriter, metadata: []const u8) Error!void {
    if (metadata.len > 0x1_0000) return error.InvalidBlockPlan;
    try writer.writeBits(allocator, 0, 1); // ISLAST = false.
    try writer.writeBits(allocator, 0b11, 2); // MNIBBLES = 0.
    try writer.writeBits(allocator, 0, 1); // reserved.
    if (metadata.len == 0) {
        try writer.writeBits(allocator, 0, 2); // MSKIPBYTES = 0.
    } else {
        const len_minus_one = metadata.len - 1;
        const mskipbytes: usize = if (len_minus_one <= 0xff) 1 else 2;
        try writer.writeBits(allocator, @intCast(mskipbytes), 2);
        try writer.writeBits(allocator, @intCast(len_minus_one), @intCast(mskipbytes * 8));
    }
    writer.alignToByte();
    try writer.writeAlignedBytes(allocator, metadata);
}

pub fn decodeStreamAlloc(allocator: std.mem.Allocator, stream: []const u8) Error![]u8 {
    return try decodeStreamAllocLimited(allocator, stream, std.math.maxInt(usize));
}

pub fn decodeStreamAllocLimited(allocator: std.mem.Allocator, stream: []const u8, max_output_len: usize) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    _ = try decodeStreamAppendLimited(allocator, &out, stream, max_output_len);
    return out.toOwnedSlice(allocator);
}

pub fn decodeStreamAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), stream: []const u8) Error!usize {
    return try decodeStreamAppendLimited(allocator, out, stream, std.math.maxInt(usize));
}

pub fn decodeStreamAppendLimited(allocator: std.mem.Allocator, out: *std.ArrayList(u8), stream: []const u8, max_output_len: usize) Error!usize {
    const decoded_len = try decodedStreamSizeLimited(stream, max_output_len);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeStreamInto(stream, slot) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeStreamInto(stream: []const u8, output: []u8) Error!usize {
    var reader = bitstream.BitReader.init(stream);
    try readWindowBits(&reader);
    var written: usize = 0;
    var last_distances = initial_last_distances;
    while (true) {
        const is_last = try reader.readBits(u1, 1) == 1;
        if (is_last) {
            const is_last_empty = try reader.readBits(u1, 1) == 1;
            if (is_last_empty) {
                try ensureZeroPaddingAndEnd(reader);
                return written;
            }
        }

        const mnibbles_code = try reader.readBits(u2, 2);
        const mnibbles: usize = switch (mnibbles_code) {
            0b00 => 4,
            0b01 => 5,
            0b10 => 6,
            0b11 => 0,
        };
        if (mnibbles == 0) {
            try skipMetadataMetaBlock(&reader);
            continue;
        }
        const len_minus_one = try reader.readBits(u32, @intCast(mnibbles * 4));
        if (mnibbles > 4 and ((len_minus_one >> @intCast((mnibbles - 1) * 4)) & 0xf) == 0) return error.CorruptFrame;
        const meta_block_len = std.math.add(usize, len_minus_one, 1) catch return error.IntegerOverflow;
        if (is_last) {
            try processMinimalCompressedMetaBlock(&reader, output, &written, meta_block_len, &last_distances);
            try ensureZeroPaddingAndEnd(reader);
            return written;
        }
        const is_uncompressed = try reader.readBits(u1, 1) == 1;
        if (!is_uncompressed) {
            try processMinimalCompressedMetaBlock(&reader, output, &written, meta_block_len, &last_distances);
            continue;
        }
        try consumeZeroPaddingToByte(&reader);
        if (output.len - written < meta_block_len) return error.OutputTooSmall;
        try reader.readAlignedBytes(output[written..][0..meta_block_len]);
        written += meta_block_len;
    }
}

pub fn decodedStreamSize(stream: []const u8) Error!usize {
    return try decodedStreamSizeLimited(stream, std.math.maxInt(usize));
}

pub fn decodedStreamSizeLimited(stream: []const u8, max_output_len: usize) Error!usize {
    var reader = bitstream.BitReader.init(stream);
    try readWindowBits(&reader);
    var total: usize = 0;
    var last_distances = initial_last_distances;
    var literal_history = LiteralHistory{};
    while (true) {
        const is_last = try reader.readBits(u1, 1) == 1;
        if (is_last) {
            const is_last_empty = try reader.readBits(u1, 1) == 1;
            if (is_last_empty) {
                try ensureZeroPaddingAndEnd(reader);
                return total;
            }
        }

        const mnibbles_code = try reader.readBits(u2, 2);
        const mnibbles: usize = switch (mnibbles_code) {
            0b00 => 4,
            0b01 => 5,
            0b10 => 6,
            0b11 => 0,
        };
        if (mnibbles == 0) {
            try skipMetadataMetaBlock(&reader);
            continue;
        }
        const len_minus_one = try reader.readBits(u32, @intCast(mnibbles * 4));
        if (mnibbles > 4 and ((len_minus_one >> @intCast((mnibbles - 1) * 4)) & 0xf) == 0) return error.CorruptFrame;
        const meta_block_len = std.math.add(usize, len_minus_one, 1) catch return error.IntegerOverflow;
        const meta_block_start = total;
        total = std.math.add(usize, total, meta_block_len) catch return error.IntegerOverflow;
        if (total > max_output_len) return error.OutputLimitExceeded;
        if (is_last) {
            try skipMinimalCompressedMetaBlock(&reader, meta_block_start, meta_block_len, &last_distances, &literal_history);
            try ensureZeroPaddingAndEnd(reader);
            return total;
        }
        const is_uncompressed = try reader.readBits(u1, 1) == 1;
        if (!is_uncompressed) {
            try skipMinimalCompressedMetaBlock(&reader, meta_block_start, meta_block_len, &last_distances, &literal_history);
            continue;
        }
        try consumeZeroPaddingToByte(&reader);
        if (reader.byte_index > stream.len or stream.len - reader.byte_index < meta_block_len) return error.TruncatedFrame;
        literal_history.pushSlice(stream[reader.byte_index..][0..meta_block_len]);
        reader.byte_index += meta_block_len;
    }
}

fn readWindowBits(reader: *bitstream.BitReader) Error!void {
    _ = try readWindowBitsValue(reader);
}

fn readBlockTypeCount(reader: *bitstream.BitReader) Error!u16 {
    const first = try reader.readBits(u1, 1);
    if (first == 0) return 1;

    const selector = try reader.readBits(u3, 3);
    if (selector == 0) return 2;

    const extra = try reader.readBits(u16, selector);
    return (@as(u16, 1) << selector) + 1 + extra;
}

fn readMinimalCompressedHeader(reader: *bitstream.BitReader) Error!MinimalCompressedHeader {
    const nbltypes_l = try readBlockTypeCount(reader);
    if (nbltypes_l > max_literal_block_types) return error.UnsupportedBrotliFeature;
    var literal_block = BlockSwitchState(max_literal_block_types){ .block_type_count = nbltypes_l };
    if (nbltypes_l >= 2) {
        literal_block.type_tree = try readPrefixCodeRuntime(max_literal_block_types + 2, @as(usize, nbltypes_l) + 2, reader);
        literal_block.length_tree = try readPrefixCode(26, reader);
        literal_block.remaining = try readBlockLength(&literal_block.length_tree, reader);
    }
    const nbltypes_i = try readBlockTypeCount(reader);
    if (nbltypes_i > max_command_block_types) return error.UnsupportedBrotliFeature;
    var command_block = BlockSwitchState(max_command_block_types){ .block_type_count = nbltypes_i };
    if (nbltypes_i >= 2) {
        command_block.type_tree = try readPrefixCodeRuntime(max_command_block_types + 2, @as(usize, nbltypes_i) + 2, reader);
        command_block.length_tree = try readPrefixCode(26, reader);
        command_block.remaining = try readBlockLength(&command_block.length_tree, reader);
    }
    const nbltypes_d = try readBlockTypeCount(reader);
    if (nbltypes_d > max_distance_block_types) return error.UnsupportedBrotliFeature;
    var distance_block = BlockSwitchState(max_distance_block_types){ .block_type_count = nbltypes_d };
    if (nbltypes_d >= 2) {
        distance_block.type_tree = try readPrefixCodeRuntime(max_distance_block_types + 2, @as(usize, nbltypes_d) + 2, reader);
        distance_block.length_tree = try readPrefixCode(26, reader);
        distance_block.remaining = try readBlockLength(&distance_block.length_tree, reader);
    }

    const npostfix = try reader.readBits(u2, 2);
    const ndirect_high = try reader.readBits(u4, 4);
    const ndirect: u16 = @as(u16, ndirect_high) << npostfix;
    if (ndirect > 120) return error.CorruptFrame;
    const distance_alphabet_size: usize = 16 + @as(usize, ndirect) + (@as(usize, 48) << npostfix);

    var literal_context_modes: [max_literal_block_types]u2 = @splat(0);
    for (0..nbltypes_l) |i| {
        literal_context_modes[i] = try reader.readBits(u2, 2);
    }

    const ntrees_l = try readBlockTypeCount(reader);
    if (ntrees_l > max_literal_context_trees) return error.UnsupportedBrotliFeature;
    var literal_context_map: [max_literal_block_types * 64]u8 = @splat(0);
    try readContextMap(reader, literal_context_map[0..(@as(usize, nbltypes_l) * 64)], ntrees_l);
    const ntrees_d = try readBlockTypeCount(reader);
    if (ntrees_d > max_distance_context_trees) return error.UnsupportedBrotliFeature;
    var distance_context_map: [max_distance_block_types * 4]u8 = @splat(0);
    try readContextMap(reader, distance_context_map[0..(@as(usize, nbltypes_d) * 4)], ntrees_d);

    var literal_trees: [max_literal_context_trees]PrefixCode(256) = @splat(.{});
    literal_trees[0] = try readPrefixCode(256, reader);
    var literal_tree_index: u16 = 1;
    while (literal_tree_index < ntrees_l) : (literal_tree_index += 1) {
        literal_trees[literal_tree_index] = try readPrefixCode(256, reader);
    }

    var insert_copy_trees: [max_command_block_types]PrefixCode(704) = @splat(.{});
    insert_copy_trees[0] = try readPrefixCode(704, reader);
    var command_tree_index: u16 = 1;
    while (command_tree_index < nbltypes_i) : (command_tree_index += 1) {
        insert_copy_trees[command_tree_index] = try readPrefixCode(704, reader);
    }

    var distance_trees: [max_distance_context_trees]PrefixCode(max_distance_alphabet_size) = @splat(.{});
    distance_trees[0] = try readPrefixCodeRuntime(max_distance_alphabet_size, distance_alphabet_size, reader);
    var distance_tree_index: u16 = 1;
    while (distance_tree_index < ntrees_d) : (distance_tree_index += 1) {
        distance_trees[distance_tree_index] = try readPrefixCodeRuntime(max_distance_alphabet_size, distance_alphabet_size, reader);
    }

    return .{
        .npostfix = npostfix,
        .ndirect = ndirect,
        .literal_context_modes = literal_context_modes,
        .literal_block = literal_block,
        .literal_context_map = literal_context_map,
        .literal_trees = literal_trees,
        .command_block = command_block,
        .insert_copy_trees = insert_copy_trees,
        .distance_block = distance_block,
        .distance_context_map = distance_context_map,
        .distance_trees = distance_trees,
    };
}

fn readBlockLength(prefix: *const PrefixCode(26), reader: *bitstream.BitReader) Error!usize {
    const symbol = try prefix.decode(reader);
    if (symbol >= block_length_specs.len) return error.InvalidHuffmanCode;
    const spec = block_length_specs[symbol];
    const extra = try reader.readBits(usize, spec.extra_bits);
    return spec.base + extra;
}

const block_length_specs = [_]LengthSpec{
    .{ .base = 1, .extra_bits = 2 },
    .{ .base = 5, .extra_bits = 2 },
    .{ .base = 9, .extra_bits = 2 },
    .{ .base = 13, .extra_bits = 2 },
    .{ .base = 17, .extra_bits = 3 },
    .{ .base = 25, .extra_bits = 3 },
    .{ .base = 33, .extra_bits = 3 },
    .{ .base = 41, .extra_bits = 3 },
    .{ .base = 49, .extra_bits = 4 },
    .{ .base = 65, .extra_bits = 4 },
    .{ .base = 81, .extra_bits = 4 },
    .{ .base = 97, .extra_bits = 4 },
    .{ .base = 113, .extra_bits = 5 },
    .{ .base = 145, .extra_bits = 5 },
    .{ .base = 177, .extra_bits = 5 },
    .{ .base = 209, .extra_bits = 5 },
    .{ .base = 241, .extra_bits = 6 },
    .{ .base = 305, .extra_bits = 6 },
    .{ .base = 369, .extra_bits = 7 },
    .{ .base = 497, .extra_bits = 8 },
    .{ .base = 753, .extra_bits = 9 },
    .{ .base = 1265, .extra_bits = 10 },
    .{ .base = 2289, .extra_bits = 11 },
    .{ .base = 4337, .extra_bits = 12 },
    .{ .base = 8433, .extra_bits = 13 },
    .{ .base = 16625, .extra_bits = 24 },
};

fn readZeroContextMap(reader: *bitstream.BitReader, context_map_size: usize, ntrees: u16) Error!void {
    var context_map: [64]u8 = undefined;
    if (context_map_size > context_map.len) return error.UnsupportedBrotliFeature;
    try readContextMap(reader, context_map[0..context_map_size], ntrees);
    for (context_map[0..context_map_size]) |tree_index| {
        if (tree_index != 0) return error.UnsupportedBrotliFeature;
    }
}

fn readContextMap(reader: *bitstream.BitReader, context_map: []u8, ntrees: u16) Error!void {
    if (ntrees == 0) return error.CorruptFrame;
    @memset(context_map, 0);
    if (ntrees == 1) return;

    const use_rle_for_zeros = try reader.readBits(u1, 1);
    const max_run_length_prefix: u5 = if (use_rle_for_zeros == 0) 0 else @as(u5, try reader.readBits(u4, 4)) + 1;
    const alphabet_size = @as(usize, ntrees) + max_run_length_prefix;
    const prefix = try readPrefixCodeRuntime(max_context_map_alphabet_size, alphabet_size, reader);

    var written: usize = 0;
    while (written < context_map.len) {
        const code = try prefix.decode(reader);
        if (code == 0) {
            context_map[written] = 0;
            written += 1;
            continue;
        }
        if (code <= max_run_length_prefix) {
            const run_extra = try reader.readBits(usize, @intCast(code));
            const run_len = (@as(usize, 1) << @intCast(code)) + run_extra;
            if (run_len > context_map.len - written) return error.CorruptFrame;
            @memset(context_map[written..][0..run_len], 0);
            written += run_len;
            continue;
        }
        const tree_index = code - max_run_length_prefix;
        if (tree_index >= ntrees) return error.CorruptFrame;
        context_map[written] = @intCast(tree_index);
        written += 1;
    }

    const imtf = try reader.readBits(u1, 1);
    if (imtf != 0) applyInverseMoveToFront(context_map);
}

fn applyInverseMoveToFront(context_map: []u8) void {
    var mtf: [256]u8 = undefined;
    for (&mtf, 0..) |*value, i| value.* = @intCast(i);

    for (context_map) |*entry| {
        const index = entry.*;
        const value = mtf[index];
        if (index != 0) {
            var i: usize = index;
            while (i > 0) : (i -= 1) {
                mtf[i] = mtf[i - 1];
            }
            mtf[0] = value;
        }
        entry.* = value;
    }
}

fn readInsertCopyLengths(symbol: u16, reader: *bitstream.BitReader) Error!InsertCopyLengths {
    if (symbol >= 704) return error.InvalidHuffmanCode;
    const ranges = insertCopyCodeRanges(symbol);
    const insert_code = ranges.insert_base + ((symbol >> 3) & 0x7);
    const copy_code = ranges.copy_base + (symbol & 0x7);
    const insert = try readInsertLength(insert_code, reader);
    const copy = try readCopyLength(copy_code, reader);
    return .{
        .insert_len = insert,
        .copy_len = copy,
        .distance_symbol_zero = symbol < 128,
    };
}

fn processMinimalCompressedMetaBlock(
    reader: *bitstream.BitReader,
    output: []u8,
    written: *usize,
    meta_block_len: usize,
    last_distances: *[4]usize,
) Error!void {
    const meta_block_end = std.math.add(usize, written.*, meta_block_len) catch return error.IntegerOverflow;
    if (meta_block_end > output.len) return error.OutputTooSmall;
    var header = try readMinimalCompressedHeader(reader);
    while (written.* < meta_block_end) {
        const command_symbol = try readCommandSymbol(&header, reader);
        const lengths = try readInsertCopyLengths(command_symbol, reader);
        if (lengths.insert_len > meta_block_end - written.*) return error.CorruptFrame;
        var i: usize = 0;
        while (i < lengths.insert_len) : (i += 1) {
            try ensureLiteralBlock(&header, reader);
            const context = try literalContext(&header, output, written.*);
            const tree_index = header.literal_context_map[@as(usize, header.literal_block.current_type) * 64 + context];
            if (tree_index >= max_literal_context_trees) return error.UnsupportedBrotliFeature;
            const literal = try header.literal_trees[tree_index].decode(reader);
            if (literal > 0xff) return error.InvalidHuffmanCode;
            output[written.*] = @intCast(literal);
            written.* += 1;
            if (header.literal_block.remaining != 0) header.literal_block.remaining -= 1;
        }
        if (written.* == meta_block_end) {
            return;
        }
        const distance = try readMinimalDistance(&header, reader, lengths, last_distances);
        if (distance == 0) return error.InvalidMatch;
        if (distance > written.*) {
            const word = try minimalStaticDictionaryWord(distance, lengths.copy_len, written.*);
            if (word.len > meta_block_end - written.*) return error.CorruptFrame;
            @memcpy(output[written.*..][0..word.len], word);
            written.* += word.len;
            continue;
        }
        pushLastDistance(last_distances, distance);
        if (lengths.copy_len > meta_block_end - written.*) return error.CorruptFrame;
        var copy_index: usize = 0;
        while (copy_index < lengths.copy_len) : (copy_index += 1) {
            output[written.*] = output[written.* - distance];
            written.* += 1;
        }
    }
}

fn skipMinimalCompressedMetaBlock(
    reader: *bitstream.BitReader,
    start_written: usize,
    meta_block_len: usize,
    last_distances: *[4]usize,
    literal_history: *LiteralHistory,
) Error!void {
    const meta_block_end = std.math.add(usize, start_written, meta_block_len) catch return error.IntegerOverflow;
    var header = try readMinimalCompressedHeader(reader);
    var written = start_written;
    while (written < meta_block_end) {
        const command_symbol = try readCommandSymbol(&header, reader);
        const lengths = try readInsertCopyLengths(command_symbol, reader);
        if (lengths.insert_len > meta_block_end - written) return error.CorruptFrame;
        var i: usize = 0;
        while (i < lengths.insert_len) : (i += 1) {
            try ensureLiteralBlock(&header, reader);
            const context = try literal_history.context(&header);
            const tree_index = header.literal_context_map[@as(usize, header.literal_block.current_type) * 64 + context];
            if (tree_index >= max_literal_context_trees) return error.UnsupportedBrotliFeature;
            const literal = try header.literal_trees[tree_index].decode(reader);
            if (literal > 0xff) return error.InvalidHuffmanCode;
            literal_history.push(@intCast(literal));
            written += 1;
            if (header.literal_block.remaining != 0) header.literal_block.remaining -= 1;
        }
        if (written == meta_block_end) {
            return;
        }
        const distance = try readMinimalDistance(&header, reader, lengths, last_distances);
        if (distance == 0) return error.InvalidMatch;
        if (distance > written) {
            const word = try minimalStaticDictionaryWord(distance, lengths.copy_len, written);
            if (word.len > meta_block_end - written) return error.CorruptFrame;
            literal_history.pushSlice(word);
            written += word.len;
            continue;
        }
        pushLastDistance(last_distances, distance);
        if (lengths.copy_len > meta_block_end - written) return error.CorruptFrame;
        literal_history.copy(distance, lengths.copy_len);
        written += lengths.copy_len;
    }
}

pub const StaticDictionaryEntry = struct {
    transform: u16,
    copy_len: usize,
    word_index: usize,
    word: []const u8,
};

const minimal_static_dictionary_entries = [_]StaticDictionaryEntry{
    .{ .transform = 0, .copy_len = 5, .word_index = 35, .word = "about" },
    .{ .transform = 0, .copy_len = 5, .word_index = 42, .word = "large" },
    .{ .transform = 0, .copy_len = 5, .word_index = 43, .word = "words" },
    .{ .transform = 0, .copy_len = 5, .word_index = 44, .word = "games" },
    .{ .transform = 0, .copy_len = 5, .word_index = 81, .word = "press" },
    .{ .transform = 0, .copy_len = 5, .word_index = 101, .word = "other" },
    .{ .transform = 0, .copy_len = 5, .word_index = 107, .word = "quick" },
    .{ .transform = 0, .copy_len = 5, .word_index = 719, .word = "hello" },
    .{ .transform = 0, .copy_len = 5, .word_index = 989, .word = "dolor" },
    .{ .transform = 0, .copy_len = 6, .word_index = 6, .word = "system" },
    .{ .transform = 0, .copy_len = 6, .word_index = 15, .word = "number" },
    .{ .transform = 0, .copy_len = 6, .word_index = 18, .word = "public" },
    .{ .transform = 0, .copy_len = 7, .word_index = 37, .word = "history" },
    .{ .transform = 0, .copy_len = 7, .word_index = 92, .word = "English" },
    .{ .transform = 0, .copy_len = 7, .word_index = 94, .word = "through" },
    .{ .transform = 0, .copy_len = 7, .word_index = 154, .word = "another" },
    .{ .transform = 0, .copy_len = 7, .word_index = 170, .word = "release" },
    .{ .transform = 0, .copy_len = 7, .word_index = 196, .word = "because" },
    .{ .transform = 0, .copy_len = 7, .word_index = 202, .word = "between" },
    .{ .transform = 0, .copy_len = 7, .word_index = 464, .word = "example" },
    .{ .transform = 0, .copy_len = 7, .word_index = 572, .word = "however" },
    .{ .transform = 0, .copy_len = 8, .word_index = 10, .word = "children" },
    .{ .transform = 0, .copy_len = 8, .word_index = 355, .word = "American" },
    .{ .transform = 0, .copy_len = 8, .word_index = 425, .word = "history." },
    .{ .transform = 0, .copy_len = 8, .word_index = 558, .word = "examples" },
    .{ .transform = 0, .copy_len = 8, .word_index = 4, .word = "language" },
    .{ .transform = 0, .copy_len = 8, .word_index = 79, .word = "internet" },
    .{ .transform = 0, .copy_len = 9, .word_index = 5, .word = "available" },
    .{ .transform = 0, .copy_len = 9, .word_index = 55, .word = "important" },
    .{ .transform = 0, .copy_len = 9, .word_index = 95, .word = "different" },
    .{ .transform = 0, .copy_len = 9, .word_index = 592, .word = "however, " },
    .{ .transform = 0, .copy_len = 10, .word_index = 18, .word = "government" },
    .{ .transform = 0, .copy_len = 10, .word_index = 84, .word = "expression" },
    .{ .transform = 0, .copy_len = 10, .word_index = 135, .word = "depression" },
    .{ .transform = 0, .copy_len = 10, .word_index = 205, .word = "dictionary" },
    .{ .transform = 0, .copy_len = 10, .word_index = 240, .word = "number of " },
    .{ .transform = 0, .copy_len = 10, .word_index = 608, .word = "to another" },
    .{ .transform = 0, .copy_len = 10, .word_index = 327, .word = "Dictionary" },
    .{ .transform = 0, .copy_len = 11, .word_index = 5, .word = "information" },
    .{ .transform = 0, .copy_len = 11, .word_index = 162, .word = "one another" },
    .{ .transform = 0, .copy_len = 11, .word_index = 452, .word = "one of the " },
    .{ .transform = 0, .copy_len = 11, .word_index = 186, .word = "Information" },
    .{ .transform = 0, .copy_len = 16, .word_index = 52, .word = "large number of " },
    .{ .transform = 1, .copy_len = 5, .word_index = 43, .word = "words " },
    .{ .transform = 1, .copy_len = 5, .word_index = 44, .word = "games " },
    .{ .transform = 1, .copy_len = 7, .word_index = 170, .word = "release " },
    .{ .transform = 1, .copy_len = 10, .word_index = 205, .word = "dictionary " },
    .{ .transform = 1, .copy_len = 11, .word_index = 5, .word = "information " },
    .{ .transform = 20, .copy_len = 7, .word_index = 37, .word = "history." },
    .{ .transform = 6, .copy_len = 5, .word_index = 43, .word = " words" },
    .{ .transform = 6, .copy_len = 5, .word_index = 44, .word = " games" },
    .{ .transform = 6, .copy_len = 7, .word_index = 170, .word = " release" },
    .{ .transform = 9, .copy_len = 7, .word_index = 5, .word = "Content" },
    .{ .transform = 9, .copy_len = 7, .word_index = 37, .word = "History" },
    .{ .transform = 9, .copy_len = 7, .word_index = 369, .word = "English" },
    .{ .transform = 9, .copy_len = 10, .word_index = 205, .word = "Dictionary" },
    .{ .transform = 9, .copy_len = 11, .word_index = 5, .word = "Information" },
    .{ .transform = 12, .copy_len = 5, .word_index = 43, .word = "word" },
    .{ .transform = 12, .copy_len = 5, .word_index = 44, .word = "game" },
    .{ .transform = 12, .copy_len = 7, .word_index = 1767, .word = "one an" },
};

pub fn minimalStaticDictionaryCoverage() []const StaticDictionaryEntry {
    return &minimal_static_dictionary_entries;
}

fn minimalStaticDictionaryWord(distance: usize, copy_len: usize, current_output_len: usize) Error![]const u8 {
    // Brotli static-dictionary addresses are relative to the current maximum
    // LZ77 distance, not the raw distance code. In this minimal decoder slice
    // we only enter here while `distance > current_output_len`, so the current
    // output length is the same limit used by RFC 7932 for small streams. The
    // table below intentionally keeps just the proven word/transform tuples;
    // full dictionary bytes, full transform metadata, and late-window dictionary
    // references remain follow-up work.
    if (distance <= current_output_len) return error.InvalidMatch;
    const address = distance - current_output_len - 1;
    const size_bits = minimalStaticDictionarySizeBits(copy_len) orelse return error.UnsupportedBrotliFeature;
    const mask = (@as(usize, 1) << @intCast(size_bits)) - 1;
    const word_index = address & mask;
    const transform_index = address >> @intCast(size_bits);

    for (minimal_static_dictionary_entries) |entry| {
        if (entry.transform == transform_index and entry.copy_len == copy_len and entry.word_index == word_index) return entry.word;
    }
    return error.UnsupportedBrotliFeature;
}

pub fn minimalStaticDictionarySizeBits(copy_len: usize) ?u5 {
    return switch (copy_len) {
        4, 5, 8, 9, 10, 11, 12 => 10,
        6, 7 => 11,
        13, 14 => 9,
        15, 18 => 8,
        16, 17, 19, 20 => 7,
        21, 22 => 6,
        23, 24 => 5,
        else => null,
    };
}

fn readCommandSymbol(header: *MinimalCompressedHeader, reader: *bitstream.BitReader) Error!u16 {
    if (header.command_block.block_type_count > 1 and header.command_block.remaining == 0) {
        try switchCommandBlock(&header.command_block, reader);
    }
    if (header.command_block.current_type >= max_command_block_types) return error.UnsupportedBrotliFeature;
    const symbol = try header.insert_copy_trees[header.command_block.current_type].decode(reader);
    if (header.command_block.remaining != 0) header.command_block.remaining -= 1;
    return symbol;
}

fn ensureLiteralBlock(header: *MinimalCompressedHeader, reader: *bitstream.BitReader) Error!void {
    if (header.literal_block.block_type_count > 1 and header.literal_block.remaining == 0) {
        try switchBlock(max_literal_block_types, &header.literal_block, reader);
    }
}

fn switchCommandBlock(block: *BlockSwitchState(max_command_block_types), reader: *bitstream.BitReader) Error!void {
    try switchBlock(max_command_block_types, block, reader);
}

fn switchBlock(comptime max_block_types: usize, block: *BlockSwitchState(max_block_types), reader: *bitstream.BitReader) Error!void {
    if (block.block_type_count <= 1) return error.CorruptFrame;
    const symbol = try block.type_tree.decode(reader);
    var block_type: u16 = switch (symbol) {
        0 => block.previous_type,
        1 => block.current_type + 1,
        else => symbol - 2,
    };
    if (block_type >= block.block_type_count) block_type -= block.block_type_count;
    block.previous_type = block.current_type;
    block.current_type = block_type;
    block.remaining = try readBlockLength(&block.length_tree, reader);
}

fn literalContext(header: *const MinimalCompressedHeader, output: []const u8, written: usize) Error!usize {
    const previous = if (written == 0) 0 else output[written - 1];
    const second_previous = if (written < 2) 0 else output[written - 2];
    return try literalContextFromMode(header.literal_context_modes[header.literal_block.current_type], previous, second_previous);
}

fn literalContextFromMode(mode: u2, previous: u8, second_previous: u8) Error!usize {
    return switch (mode) {
        0 => previous & 0x3f,
        1 => previous >> 2,
        2 => utf8Context(previous, second_previous),
        3 => (signedContextBucket(previous) << 3) | signedContextBucket(second_previous),
    };
}

fn utf8Context(previous: u8, second_previous: u8) usize {
    return utf8LastByteContext(previous) | utf8SecondLastByteContext(second_previous);
}

fn utf8LastByteContext(value: u8) usize {
    if (value >= 192) return 2 + (value & 1);
    if (value >= 128) return value & 1;
    if ((value < 32 and value != 9 and value != 10 and value != 13) or value == 127) return 0;
    return switch (value) {
        9, 10, 13 => 4,
        32 => 8,
        '"', '\'' => 16,
        '%' => 20,
        '(', '<', '[', '{' => 24,
        ')', '>', ']', '}' => 28,
        ',', ';', ':' => 32,
        '.' => 36,
        '=' => 40,
        '0'...'9' => 44,
        'A', 'E', 'I', 'O', 'U' => 48,
        'B'...'D', 'F'...'H', 'J'...'N', 'P'...'T', 'V'...'Z' => 52,
        'a', 'e', 'i', 'o', 'u' => 56,
        'b'...'d', 'f'...'h', 'j'...'n', 'p'...'t', 'v'...'z' => 60,
        else => 12,
    };
}

fn utf8SecondLastByteContext(value: u8) usize {
    if (value >= 208) return 2;
    if (value >= 128) return 0;
    return switch (value) {
        0...32, 127 => 0,
        '0'...'9', 'A'...'Z' => 2,
        'a'...'z' => 3,
        else => 1,
    };
}

fn signedContextBucket(value: u8) usize {
    return switch (value) {
        0 => 0,
        1...15 => 1,
        16...63 => 2,
        64...127 => 3,
        128...191 => 4,
        192...239 => 5,
        240...254 => 6,
        255 => 7,
    };
}

fn readMinimalDistance(
    header: *MinimalCompressedHeader,
    reader: *bitstream.BitReader,
    lengths: InsertCopyLengths,
    last_distances: *[4]usize,
) Error!usize {
    const symbol = if (lengths.distance_symbol_zero) 0 else blk: {
        try ensureDistanceBlock(header, reader);
        const context = distanceContext(lengths.copy_len);
        if (header.distance_block.current_type >= max_distance_block_types) return error.UnsupportedBrotliFeature;
        const tree_index = header.distance_context_map[@as(usize, header.distance_block.current_type) * 4 + context];
        if (tree_index >= max_distance_context_trees) return error.UnsupportedBrotliFeature;
        const decoded = try header.distance_trees[tree_index].decode(reader);
        if (header.distance_block.remaining != 0) header.distance_block.remaining -= 1;
        break :blk decoded;
    };
    if (symbol < 16) {
        return try resolveShortDistance(symbol, last_distances);
    }
    const direct_index = symbol - 16;
    return if (direct_index < header.ndirect)
        @as(usize, direct_index) + 1
    else
        try readRegularDistance(header, reader, symbol);
}

fn ensureDistanceBlock(header: *MinimalCompressedHeader, reader: *bitstream.BitReader) Error!void {
    if (header.distance_block.block_type_count > 1 and header.distance_block.remaining == 0) {
        try switchBlock(max_distance_block_types, &header.distance_block, reader);
    }
}

fn distanceContext(copy_len: usize) usize {
    if (copy_len <= 4) return copy_len - 2;
    return 3;
}

fn readRegularDistance(header: *const MinimalCompressedHeader, reader: *bitstream.BitReader, symbol: u16) Error!usize {
    const xcode = @as(usize, symbol) - @as(usize, header.ndirect) - 16;
    const npostfix: usize = header.npostfix;
    const ndistbits_value = 1 + (xcode >> @intCast(npostfix + 1));
    if (ndistbits_value > 24) return error.CorruptFrame;
    const ndistbits: u5 = @intCast(ndistbits_value);
    const dextra = if (ndistbits == 0) 0 else try reader.readBits(u32, ndistbits);
    return try resolveRegularDistance(header.npostfix, header.ndirect, symbol, dextra);
}

fn resolveRegularDistance(npostfix: u2, ndirect: u16, symbol: u16, dextra: usize) Error!usize {
    if (symbol < 16 + @as(usize, ndirect)) return error.InvalidHuffmanCode;
    const xcode = @as(usize, symbol) - @as(usize, ndirect) - 16;
    const npostfix_usize: usize = npostfix;
    const ndistbits = 1 + (xcode >> @intCast(npostfix_usize + 1));
    if (ndistbits > 24) return error.CorruptFrame;

    const hcode = xcode >> @intCast(npostfix_usize);
    const postfix_mask = (@as(usize, 1) << @intCast(npostfix_usize)) - 1;
    const lcode = xcode & postfix_mask;
    const offset = ((@as(usize, 2) + (hcode & 1)) << @intCast(ndistbits)) - 4;
    const base_with_extra = std.math.add(usize, offset, dextra) catch return error.IntegerOverflow;
    const shifted = base_with_extra << @intCast(npostfix_usize);
    const with_postfix = std.math.add(usize, shifted, lcode) catch return error.IntegerOverflow;
    const with_direct = std.math.add(usize, with_postfix, ndirect) catch return error.IntegerOverflow;
    return std.math.add(usize, with_direct, 1) catch return error.IntegerOverflow;
}

fn resolveShortDistance(symbol: u16, last_distances: *const [4]usize) Error!usize {
    return switch (symbol) {
        0 => last_distances[3],
        1 => last_distances[2],
        2 => last_distances[1],
        3 => last_distances[0],
        4 => try distanceWithDelta(last_distances[3], -1),
        5 => try distanceWithDelta(last_distances[3], 1),
        6 => try distanceWithDelta(last_distances[3], -2),
        7 => try distanceWithDelta(last_distances[3], 2),
        8 => try distanceWithDelta(last_distances[3], -3),
        9 => try distanceWithDelta(last_distances[3], 3),
        10 => try distanceWithDelta(last_distances[2], -1),
        11 => try distanceWithDelta(last_distances[2], 1),
        12 => try distanceWithDelta(last_distances[2], -2),
        13 => try distanceWithDelta(last_distances[2], 2),
        14 => try distanceWithDelta(last_distances[2], -3),
        15 => try distanceWithDelta(last_distances[2], 3),
        else => error.InvalidHuffmanCode,
    };
}

fn distanceWithDelta(base: usize, delta: i8) Error!usize {
    if (delta < 0) {
        const magnitude: usize = @intCast(-delta);
        if (base <= magnitude) return error.InvalidMatch;
        return base - magnitude;
    }
    return std.math.add(usize, base, @intCast(delta)) catch return error.IntegerOverflow;
}

fn pushLastDistance(last_distances: *[4]usize, distance: usize) void {
    last_distances[0] = last_distances[1];
    last_distances[1] = last_distances[2];
    last_distances[2] = last_distances[3];
    last_distances[3] = distance;
}

const InsertCopyCodeRanges = struct {
    insert_base: u16,
    copy_base: u16,
};

fn insertCopyCodeRanges(symbol: u16) InsertCopyCodeRanges {
    if (symbol < 64) return .{ .insert_base = 0, .copy_base = 0 };
    if (symbol < 128) return .{ .insert_base = 0, .copy_base = 8 };
    if (symbol < 192) return .{ .insert_base = 0, .copy_base = 0 };
    if (symbol < 256) return .{ .insert_base = 0, .copy_base = 8 };
    if (symbol < 320) return .{ .insert_base = 8, .copy_base = 0 };
    if (symbol < 384) return .{ .insert_base = 8, .copy_base = 8 };
    if (symbol < 448) return .{ .insert_base = 0, .copy_base = 16 };
    if (symbol < 512) return .{ .insert_base = 16, .copy_base = 0 };
    if (symbol < 576) return .{ .insert_base = 8, .copy_base = 16 };
    if (symbol < 640) return .{ .insert_base = 16, .copy_base = 8 };
    return .{ .insert_base = 16, .copy_base = 16 };
}

const LengthSpec = struct {
    base: usize,
    extra_bits: u5,
};

fn readInsertLength(code: u16, reader: *bitstream.BitReader) Error!usize {
    const spec = insertLengthSpec(code);
    const extra = if (spec.extra_bits == 0) 0 else try reader.readBits(u32, spec.extra_bits);
    return spec.base + extra;
}

fn readCopyLength(code: u16, reader: *bitstream.BitReader) Error!usize {
    const spec = copyLengthSpec(code);
    const extra = if (spec.extra_bits == 0) 0 else try reader.readBits(u32, spec.extra_bits);
    return spec.base + extra;
}

fn insertLengthSpec(code: u16) LengthSpec {
    return switch (code) {
        0...5 => .{ .base = code, .extra_bits = 0 },
        6...7 => .{ .base = 6 + (@as(usize, code - 6) << 1), .extra_bits = 1 },
        8...9 => .{ .base = 10 + (@as(usize, code - 8) << 2), .extra_bits = 2 },
        10...11 => .{ .base = 18 + (@as(usize, code - 10) << 3), .extra_bits = 3 },
        12...13 => .{ .base = 34 + (@as(usize, code - 12) << 4), .extra_bits = 4 },
        14...15 => .{ .base = 66 + (@as(usize, code - 14) << 5), .extra_bits = 5 },
        16 => .{ .base = 130, .extra_bits = 6 },
        17 => .{ .base = 194, .extra_bits = 7 },
        18 => .{ .base = 322, .extra_bits = 8 },
        19 => .{ .base = 578, .extra_bits = 9 },
        20 => .{ .base = 1090, .extra_bits = 10 },
        21 => .{ .base = 2114, .extra_bits = 12 },
        22 => .{ .base = 6210, .extra_bits = 14 },
        23 => .{ .base = 22594, .extra_bits = 24 },
        else => unreachable,
    };
}

fn copyLengthSpec(code: u16) LengthSpec {
    return switch (code) {
        0...7 => .{ .base = 2 + code, .extra_bits = 0 },
        8...9 => .{ .base = 10 + (@as(usize, code - 8) << 1), .extra_bits = 1 },
        10...11 => .{ .base = 14 + (@as(usize, code - 10) << 2), .extra_bits = 2 },
        12...13 => .{ .base = 22 + (@as(usize, code - 12) << 3), .extra_bits = 3 },
        14...15 => .{ .base = 38 + (@as(usize, code - 14) << 4), .extra_bits = 4 },
        16 => .{ .base = 70, .extra_bits = 5 },
        17 => .{ .base = 102, .extra_bits = 5 },
        18 => .{ .base = 134, .extra_bits = 6 },
        19 => .{ .base = 198, .extra_bits = 7 },
        20 => .{ .base = 326, .extra_bits = 8 },
        21 => .{ .base = 582, .extra_bits = 9 },
        22 => .{ .base = 1094, .extra_bits = 10 },
        23 => .{ .base = 2118, .extra_bits = 24 },
        else => unreachable,
    };
}

fn readPrefixCode(comptime alphabet_size: usize, reader: *bitstream.BitReader) Error!PrefixCode(alphabet_size) {
    return try readPrefixCodeRuntime(alphabet_size, alphabet_size, reader);
}

fn readPrefixCodeRuntime(comptime max_alphabet_size: usize, alphabet_size: usize, reader: *bitstream.BitReader) Error!PrefixCode(max_alphabet_size) {
    if (alphabet_size == 0 or alphabet_size > max_alphabet_size) return error.CorruptFrame;
    const kind = try reader.readBits(u2, 2);
    if (kind != 1) return try readComplexPrefixCodeRuntime(max_alphabet_size, alphabet_size, reader, kind);

    const nsym = @as(usize, try reader.readBits(u2, 2)) + 1;
    const alphabet_bits = alphabetBitsRuntime(alphabet_size);
    var symbols: [4]u16 = undefined;
    for (0..nsym) |i| {
        const symbol = try reader.readBits(u16, alphabet_bits);
        if (symbol >= alphabet_size) return error.InvalidHuffmanCode;
        for (symbols[0..i]) |previous| {
            if (previous == symbol) return error.InvalidHuffmanCode;
        }
        symbols[i] = symbol;
    }

    var lengths: [max_alphabet_size]u4 = @splat(0);
    switch (nsym) {
        1 => return .{ .single_symbol = symbols[0] },
        2 => {
            lengths[symbols[0]] = 1;
            lengths[symbols[1]] = 1;
        },
        3 => {
            lengths[symbols[0]] = 1;
            lengths[symbols[1]] = 2;
            lengths[symbols[2]] = 2;
        },
        4 => {
            const tree_select = try reader.readBits(u1, 1);
            if (tree_select == 0) {
                for (symbols) |symbol| lengths[symbol] = 2;
            } else {
                lengths[symbols[0]] = 1;
                lengths[symbols[1]] = 2;
                lengths[symbols[2]] = 3;
                lengths[symbols[3]] = 3;
            }
        },
        else => unreachable,
    }

    return .{ .table = try huffman.HuffmanTable(max_alphabet_size).init(&lengths) };
}

const code_length_alphabet_size = 18;
const code_length_order = [_]u5{ 1, 2, 3, 4, 0, 5, 17, 6, 16, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

fn readComplexPrefixCodeRuntime(comptime max_alphabet_size: usize, alphabet_size: usize, reader: *bitstream.BitReader, hskip: u2) Error!PrefixCode(max_alphabet_size) {
    if (hskip == 1) return error.CorruptFrame;

    var code_length_lengths: [code_length_alphabet_size]u4 = @splat(0);
    var code_length_space: i32 = 32;
    var code_length_nonzero: usize = 0;
    var code_length_index: usize = if (hskip == 0) 0 else hskip;
    while (code_length_index < code_length_order.len) : (code_length_index += 1) {
        const length = try readCodeLengthCodeLength(reader);
        const symbol = code_length_order[code_length_index];
        code_length_lengths[symbol] = length;
        if (length != 0) {
            code_length_nonzero += 1;
            code_length_space -= @intCast(@as(u32, 32) >> length);
            if (code_length_space < 0) return error.InvalidHuffmanCode;
            if (code_length_space == 0) {
                if (code_length_nonzero < 2) return error.InvalidHuffmanCode;
                break;
            }
        }
    }
    if (code_length_nonzero == 0) return error.InvalidHuffmanCode;
    if (code_length_space != 0 and code_length_index == code_length_order.len) {
        if (code_length_nonzero != 1) return error.InvalidHuffmanCode;
    } else if (code_length_space != 0) {
        return error.InvalidHuffmanCode;
    }

    const code_length_prefix = if (code_length_nonzero == 1)
        singleSymbolPrefixCode(code_length_alphabet_size, &code_length_lengths)
    else
        PrefixCode(code_length_alphabet_size){ .table = try huffman.HuffmanTable(code_length_alphabet_size).init(&code_length_lengths) };

    var lengths: [max_alphabet_size]u4 = @splat(0);
    var index: usize = 0;
    var space: i32 = 32768;
    var last_nonzero_length: u4 = 8;
    var previous_repeat_symbol: ?u16 = null;
    var pending_repeat_count: usize = 0;
    var pending_repeat_length: u4 = 0;
    var last_symbol: ?u16 = null;
    while (index < alphabet_size and space > 0) {
        const symbol = try code_length_prefix.decode(reader);
        switch (symbol) {
            0 => {
                try flushPendingRepeat(alphabet_size, max_alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                lengths[index] = 0;
                index += 1;
            },
            1...15 => {
                try flushPendingRepeat(alphabet_size, max_alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                const length: u4 = @intCast(symbol);
                lengths[index] = length;
                index += 1;
                last_nonzero_length = length;
                space -= @intCast(@as(u32, 32768) >> length);
                if (space < 0) return error.InvalidHuffmanCode;
            },
            16 => {
                const repeat = @as(usize, try reader.readBits(u2, 2)) + 3;
                if (previous_repeat_symbol == 16) {
                    pending_repeat_count = 4 * (pending_repeat_count - 2) + repeat;
                } else {
                    try flushPendingRepeat(alphabet_size, max_alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                    pending_repeat_count = repeat;
                    pending_repeat_length = last_nonzero_length;
                }
                previous_repeat_symbol = 16;
                try validatePendingRepeat(alphabet_size, index, pending_repeat_length, pending_repeat_count, space);
                if (pendingRepeatCompletesSpace(pending_repeat_length, pending_repeat_count, space)) {
                    try flushPendingRepeat(alphabet_size, max_alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                }
            },
            17 => {
                const repeat = @as(usize, try reader.readBits(u3, 3)) + 3;
                if (previous_repeat_symbol == 17) {
                    pending_repeat_count = 8 * (pending_repeat_count - 2) + repeat;
                } else {
                    try flushPendingRepeat(alphabet_size, max_alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
                    pending_repeat_count = repeat;
                    pending_repeat_length = 0;
                }
                previous_repeat_symbol = 17;
                try validatePendingRepeat(alphabet_size, index, pending_repeat_length, pending_repeat_count, space);
            },
            else => return error.InvalidHuffmanCode,
        }
        last_symbol = symbol;
    }
    try flushPendingRepeat(alphabet_size, max_alphabet_size, &lengths, &index, &previous_repeat_symbol, &pending_repeat_count, &pending_repeat_length, &space);
    if (space != 0) return error.InvalidHuffmanCode;
    if (last_symbol == null or last_symbol.? == 0 or last_symbol.? == 17) return error.InvalidHuffmanCode;

    var active: usize = 0;
    for (lengths[0..alphabet_size]) |length| {
        if (length != 0) active += 1;
    }
    if (active < 2) return error.InvalidHuffmanCode;
    return .{ .table = try huffman.HuffmanTable(max_alphabet_size).init(&lengths) };
}

fn readCodeLengthCodeLength(reader: *bitstream.BitReader) Error!u4 {
    const first = try reader.readBits(u1, 1);
    const second = try reader.readBits(u1, 1);
    if (first == 0) return if (second == 0) 0 else 3;
    if (second == 0) return 4;
    const third = try reader.readBits(u1, 1);
    if (third == 0) return 2;
    const fourth = try reader.readBits(u1, 1);
    return if (fourth == 0) 1 else 5;
}

fn singleSymbolPrefixCode(comptime alphabet_size: usize, lengths: *const [alphabet_size]u4) PrefixCode(alphabet_size) {
    for (lengths, 0..) |length, symbol| {
        if (length != 0) return .{ .single_symbol = @intCast(symbol) };
    }
    unreachable;
}

fn repeatCodeLength(
    alphabet_size: usize,
    comptime max_alphabet_size: usize,
    lengths: *[max_alphabet_size]u4,
    index: *usize,
    length: u4,
    repeat: usize,
    space: *i32,
) Error!void {
    if (index.* > alphabet_size or alphabet_size - index.* < repeat) return error.InvalidHuffmanCode;
    var i: usize = 0;
    while (i < repeat) : (i += 1) {
        lengths[index.*] = length;
        index.* += 1;
        if (length != 0) {
            space.* -= @intCast(@as(u32, 32768) >> length);
            if (space.* < 0) return error.InvalidHuffmanCode;
        }
    }
}

fn flushPendingRepeat(
    alphabet_size: usize,
    comptime max_alphabet_size: usize,
    lengths: *[max_alphabet_size]u4,
    index: *usize,
    previous_repeat_symbol: *?u16,
    pending_repeat_count: *usize,
    pending_repeat_length: *u4,
    space: *i32,
) Error!void {
    if (previous_repeat_symbol.* == null) return;
    try repeatCodeLength(alphabet_size, max_alphabet_size, lengths, index, pending_repeat_length.*, pending_repeat_count.*, space);
    previous_repeat_symbol.* = null;
    pending_repeat_count.* = 0;
    pending_repeat_length.* = 0;
}

fn validatePendingRepeat(alphabet_size: usize, index: usize, length: u4, count: usize, space: i32) Error!void {
    if (index > alphabet_size or alphabet_size - index < count) return error.InvalidHuffmanCode;
    if (length != 0) {
        const contribution: i32 = @intCast(count * (@as(usize, 32768) >> length));
        if (contribution > space) return error.InvalidHuffmanCode;
    }
}

fn pendingRepeatCompletesSpace(length: u4, count: usize, space: i32) bool {
    if (length == 0) return false;
    const contribution: i32 = @intCast(count * (@as(usize, 32768) >> length));
    return contribution == space;
}

fn alphabetBits(comptime alphabet_size: usize) u6 {
    return alphabetBitsRuntime(alphabet_size);
}

fn alphabetBitsRuntime(alphabet_size: usize) u6 {
    if (alphabet_size <= 1) return 0;
    var bits: u6 = 0;
    var value: usize = alphabet_size - 1;
    while (value != 0) : (value >>= 1) bits += 1;
    return bits;
}

fn readWindowBitsValue(reader: *bitstream.BitReader) Error!u5 {
    const first = try reader.readBits(u1, 1);
    if (first == 0) return 16;
    const low3 = try reader.readBits(u3, 3);
    if (low3 != 0) return @as(u5, low3) + 17;

    const tail = try reader.readBits(u3, 3);
    return switch (tail) {
        0 => 17,
        1 => error.CorruptFrame,
        else => @as(u5, tail) + 8,
    };
}

fn writeWindowBits(allocator: std.mem.Allocator, writer: *BitWriter, window_bits: u5) Error!void {
    switch (window_bits) {
        16 => try writer.writeBits(allocator, 0, 1),
        18...24 => {
            try writer.writeBits(allocator, 1, 1);
            try writer.writeBits(allocator, @as(u64, window_bits - 17), 3);
        },
        17 => {
            try writer.writeBits(allocator, 1, 1);
            try writer.writeBits(allocator, 0, 3);
            try writer.writeBits(allocator, 0, 3);
        },
        10...15 => {
            try writer.writeBits(allocator, 1, 1);
            try writer.writeBits(allocator, 0, 3);
            try writer.writeBits(allocator, @as(u64, window_bits - 8), 3);
        },
        else => return error.InvalidBlockPlan,
    }
}

fn consumeZeroPaddingToByte(reader: *bitstream.BitReader) Error!void {
    if (reader.bit_index == 0) return;
    const pad_bits: u6 = 8 - @as(u6, reader.bit_index);
    const padding = try reader.readBits(u8, pad_bits);
    if (padding != 0) return error.CorruptFrame;
}

fn skipMetadataMetaBlock(reader: *bitstream.BitReader) Error!void {
    const reserved = try reader.readBits(u1, 1);
    if (reserved != 0) return error.CorruptFrame;
    const mskipbytes = try reader.readBits(u2, 2);
    var metadata_len: usize = 0;
    if (mskipbytes != 0) {
        const len_minus_one = try reader.readBits(u32, @intCast(@as(usize, mskipbytes) * 8));
        if (mskipbytes > 1 and ((len_minus_one >> @intCast((@as(usize, mskipbytes) - 1) * 8)) & 0xff) == 0) return error.CorruptFrame;
        metadata_len = std.math.add(usize, len_minus_one, 1) catch return error.IntegerOverflow;
    }
    try consumeZeroPaddingToByte(reader);
    if (reader.byte_index > reader.input.len or reader.input.len - reader.byte_index < metadata_len) return error.TruncatedFrame;
    reader.byte_index += metadata_len;
}

fn ensureZeroPaddingAndEnd(reader: bitstream.BitReader) Error!void {
    var copy = reader;
    try consumeZeroPaddingToByte(&copy);
    if (copy.byte_index != copy.input.len) return error.TrailingData;
}

test "br stored stream encodes RFC-valid empty stream" {
    const encoded = try encodeStoredStreamAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x06}, encoded);
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "", decoded);
}

test "br stored stream round trips hello with known bytes" {
    const encoded = try encodeStoredStreamAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x40, 0x00, 0x10, 'h', 'e', 'l', 'l', 'o', 0x03 }, encoded);
    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, encoded, 5);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello", decoded);
    try std.testing.expectError(error.OutputLimitExceeded, decodedStreamSizeLimited(encoded, 4));
    var out: [5]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 5), try decodeStreamInto(encoded, &out));
    try std.testing.expectEqualSlices(u8, "hello", &out);
}

test "br stored stream supports all RFC window bits" {
    inline for (.{ 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24 }) |bits| {
        const encoded = try encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "window", .{ .window_bits = bits });
        defer std.testing.allocator.free(encoded);
        try std.testing.expectEqual(@as(usize, 6), try decodedStreamSize(encoded));
        const decoded = try decodeStreamAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, "window", decoded);
    }
}

test "br stored stream skips metadata meta-blocks" {
    const encoded = try encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "payload", .{ .metadata = "vort-metadata" });
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqual(@as(usize, 7), try decodedStreamSize(encoded));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "payload", decoded);
}

test "br stored stream decodes multiple uncompressed meta-blocks" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writeUncompressedMetaBlock(std.testing.allocator, &writer, "first ");
    try writeUncompressedMetaBlock(std.testing.allocator, &writer, "second");
    try writer.writeBits(std.testing.allocator, 1, 1);
    try writer.writeBits(std.testing.allocator, 1, 1);

    const payload = "first second";
    try std.testing.expectEqual(payload.len, try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "br minimal compressed stream decodes literal-only final metablock" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForHello(std.testing.allocator, &writer);
    // Insert-copy prefix is a single symbol (40), so no command bits are
    // emitted. The literal tree is canonical by sorted symbol order:
    // e=00, h=01, l=10, o=11, stored LSB-first.
    try writer.writeBits(std.testing.allocator, 2, 2); // h
    try writer.writeBits(std.testing.allocator, 0, 2); // e
    try writer.writeBits(std.testing.allocator, 1, 2); // l
    try writer.writeBits(std.testing.allocator, 1, 2); // l
    try writer.writeBits(std.testing.allocator, 3, 2); // o

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello", decoded);
}

test "br minimal compressed stream decodes trivial context maps" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForHelloWithContextMaps(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 2, 2); // h
    try writer.writeBits(std.testing.allocator, 0, 2); // e
    try writer.writeBits(std.testing.allocator, 1, 2); // l
    try writer.writeBits(std.testing.allocator, 1, 2); // l
    try writer.writeBits(std.testing.allocator, 3, 2); // o

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello", decoded);
}

test "br minimal compressed stream can precede stored metablocks" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLAST = false.
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writer.writeBits(std.testing.allocator, 0, 1); // ISUNCOMPRESSED = false
    try writeMinimalCompressedHeaderForHello(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 2, 2); // h
    try writer.writeBits(std.testing.allocator, 0, 2); // e
    try writer.writeBits(std.testing.allocator, 1, 2); // l
    try writer.writeBits(std.testing.allocator, 1, 2); // l
    try writer.writeBits(std.testing.allocator, 3, 2); // o

    try writeUncompressedMetaBlock(std.testing.allocator, &writer, "!");
    try writer.writeBits(std.testing.allocator, 1, 1);
    try writer.writeBits(std.testing.allocator, 1, 1);

    try std.testing.expectEqual(@as(usize, 6), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello!", decoded);
}

test "br stored metablock history feeds following compressed literal context" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writeUncompressedMetaBlock(std.testing.allocator, &writer, "a");

    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 0, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralContextAfterStoredA(std.testing.allocator, &writer);

    try std.testing.expectEqual(@as(usize, 2), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ab", decoded);
}

test "br minimal compressed stream decodes direct-distance copy" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForCopy(std.testing.allocator, &writer);
    // Insert-copy and literal prefixes are single-symbol. Command 138 inserts
    // one literal and copies four bytes; distance symbol 16 is direct distance 1.

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaaaa", decoded);
}

test "br minimal compressed stream reuses last distance" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLastDistance(std.testing.allocator, &writer);
    // First command inserts 'a' and copies two bytes from direct distance 1.
    // Second command has symbol 0: insert 0, copy 2, implicit distance zero,
    // which reuses the last pushed distance 1.
    try writer.writeBits(std.testing.allocator, 1, 1); // command 136
    try writer.writeBits(std.testing.allocator, 0, 1); // command 0

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaaaa", decoded);
}

test "br minimal compressed stream decodes short-distance copy" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForShortDistance(std.testing.allocator, &writer);
    // Command 136 pushes direct distance 1 after producing "aaa". Command 128
    // then copies two bytes from short code 5: last distance + 1 => distance 2.
    try writer.writeBits(std.testing.allocator, 1, 1); // command 136
    try writer.writeBits(std.testing.allocator, 1, 1); // distance 16
    try writer.writeBits(std.testing.allocator, 0, 1); // command 128
    try writer.writeBits(std.testing.allocator, 0, 1); // distance 5

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaaaa", decoded);
}

test "br minimal compressed stream keeps short distances across metablocks" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);

    try writer.writeBits(std.testing.allocator, 0, 1); // ISLAST = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writer.writeBits(std.testing.allocator, 0, 1); // ISUNCOMPRESSED = false
    try writeMinimalCompressedHeaderForShortDistance(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 1, 1); // command 136
    try writer.writeBits(std.testing.allocator, 1, 1); // distance 16

    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 1, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForShortDistance(std.testing.allocator, &writer);
    // The final block uses short code 5: last distance + 1 => distance 2. If
    // the recent-distance ring were reset at the meta-block boundary, this would
    // resolve to the initial last distance + 1 and fail the history check.
    try writer.writeBits(std.testing.allocator, 0, 1); // command 128
    try writer.writeBits(std.testing.allocator, 0, 1); // distance 5

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaaaa", decoded);
}

test "br minimal compressed stream decodes regular-distance copy" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForRegularDistance(std.testing.allocator, &writer);
    // The single command inserts "ab" and copies three bytes. Distance symbol
    // 17 with NPOSTFIX=1, NDIRECT=0, and dextra=0 resolves to distance 2.
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 1); // b
    try writer.writeBits(std.testing.allocator, 0, 1); // dextra

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ababa", decoded);
}

test "br minimal compressed stream selects distance context tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForDistanceContext(std.testing.allocator, &writer);
    // Command 145 inserts "ab" and copies three bytes. Copy length 3 maps to
    // distance context 1, which selects tree 1 and distance 2.
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 1); // b

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ababa", decoded);
}

test "br minimal compressed stream selects distance context tree through complex context map" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForDistanceContextComplexMap(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 1); // b

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ababa", decoded);
}

test "br minimal compressed stream decodes complex distance prefix tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForComplexDistancePrefix(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 1); // b
    try writer.writeBits(std.testing.allocator, 1, 1); // distance 2

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ababa", decoded);
}

test "br minimal compressed stream selects fifth distance context tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForFifthDistanceContext(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 1); // b

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ababa", decoded);
}

test "br minimal compressed stream selects ninth distance context tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForNinthDistanceContext(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 1); // b

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ababa", decoded);
}

test "br minimal compressed stream selects literal context tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralContext(std.testing.allocator, &writer);
    // Command 24 inserts three literals. LSB6 context after literal 'a' is 33,
    // which maps to tree 1 for literal 'b'. Tree 0 cannot decode 'b', so this
    // proves the map selection path.

    try std.testing.expectEqual(@as(usize, 3), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aba", decoded);
}

test "br minimal compressed stream decodes complex literal prefix tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForComplexLiteralPrefix(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 1); // b
    try writer.writeBits(std.testing.allocator, 0, 1); // a

    try std.testing.expectEqual(@as(usize, 3), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aba", decoded);
}

test "br minimal compressed stream decodes complex command prefix tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 1, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForComplexCommandPrefix(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 1, 1); // command 18
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 1); // b

    try std.testing.expectEqual(@as(usize, 2), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ab", decoded);
}

test "br minimal compressed stream selects literal context tree through IMTF map" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralContextImtf(std.testing.allocator, &writer);

    try std.testing.expectEqual(@as(usize, 3), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aba", decoded);
}

test "br minimal compressed stream selects literal context tree through UTF8 mode" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralContextUtf8(std.testing.allocator, &writer);

    try std.testing.expectEqual(@as(usize, 3), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aba", decoded);
}

test "br minimal compressed stream selects literal context tree through RLE context map" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralContextUtf8Rle(std.testing.allocator, &writer);

    try std.testing.expectEqual(@as(usize, 3), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aba", decoded);
}

test "br minimal compressed stream selects literal context tree through complex context map" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralContextUtf8ComplexMap(std.testing.allocator, &writer);

    try std.testing.expectEqual(@as(usize, 3), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aba", decoded);
}

test "br minimal compressed stream selects fifth literal context tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralContextFiveTrees(std.testing.allocator, &writer);

    try std.testing.expectEqual(@as(usize, 3), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aba", decoded);
}

test "br minimal compressed stream selects ninth literal context tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralContextNineTrees(std.testing.allocator, &writer);

    try std.testing.expectEqual(@as(usize, 3), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aba", decoded);
}

test "br minimal compressed stream keeps UTF8 literal context after distance-three copy" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 5, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForUtf8ContextAfterDistanceThreeCopy(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 1, 1); // command 152
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 1); // b
    try writer.writeBits(std.testing.allocator, 0, 1); // command 8

    try std.testing.expectEqual(@as(usize, 6), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abcabc", decoded);
}

test "br minimal compressed stream keeps literal context after distance-thirty-three copy" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 35, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForContextAfterDistanceThirtyThreeCopy(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 1, 1); // command 280
    try writer.writeBits(std.testing.allocator, 7, 3); // insert length 33
    try writer.writeBits(std.testing.allocator, 0, 1); // a, tree 0
    try writer.writeBits(std.testing.allocator, 1, 1); // b, tree 0
    var i: usize = 0;
    while (i < 31) : (i += 1) try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 0, 1); // command 8
    try writer.writeBits(std.testing.allocator, 1, 1); // c, tree 1

    try std.testing.expectEqual(@as(usize, 36), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabc", decoded);
}

test "br minimal compressed stream keeps literal context after distance-sixty-five copy" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 67, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForContextAfterDistanceSixtyFiveCopy(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 1, 1); // command 296
    try writer.writeBits(std.testing.allocator, 15, 4); // insert length 65
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 1); // b
    var i: usize = 0;
    while (i < 63) : (i += 1) try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 0, 1); // command 8
    try writer.writeBits(std.testing.allocator, 1, 1); // c

    try std.testing.expectEqual(@as(usize, 68), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ab" ++ ("a" ** 63) ++ "abc", decoded);
}

test "br minimal compressed stream keeps literal context after distance-one-twenty-nine copy" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 131, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForContextAfterDistanceOneTwentyNineCopy(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 1, 1); // command 312
    try writer.writeBits(std.testing.allocator, 31, 5); // insert length 129
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 1); // b
    var i: usize = 0;
    while (i < 127) : (i += 1) try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 4, 6); // distance 129 extra bits
    try writer.writeBits(std.testing.allocator, 0, 1); // command 8
    try writer.writeBits(std.testing.allocator, 1, 1); // c

    try std.testing.expectEqual(@as(usize, 132), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ab" ++ ("a" ** 127) ++ "abc", decoded);
}

test "br minimal static dictionary word decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0xc0, 0x00, 0x00, 0x20, 0xe0, 0x38, 0xbc,
        0xde, 0xdd, 0x77, 0x5f, 0x44, 0xa4, 0x1a, 0x24,
        0x9f, 0x6a, 0x3c, 0xa7, 0x83, 0xd6, 0xc7, 0x00,
    };
    const expected = "hello brotli hello brotli";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary quick word decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0xf0, 0x01, 0x00, 0x20, 0x10, 0x6d, 0xc3,
        0x54, 0x2f, 0x57, 0xc5, 0x57, 0x91, 0xf1, 0x32,
        0x66, 0x8e, 0xb2, 0x8f, 0x44, 0x65, 0x65, 0x66,
        0x14, 0xce, 0x89, 0xed, 0x7a, 0x2a, 0x5e, 0x2f,
        0x69, 0x95, 0x36, 0xd0, 0x2d, 0x1d, 0xd2, 0xb2,
        0xf9, 0x0f, 0xa7, 0x01, 0x0f,
    };
    const expected = "the quick brown fox jumps over the lazy dog the quick brown fox";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary dolor word decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0xf8, 0x07, 0x00, 0x20, 0xea, 0xa6, 0xd7,
        0x1b, 0x7e, 0xf1, 0xba, 0xf6, 0x3c, 0xd2, 0x85,
        0x11, 0x58, 0x55, 0x6c, 0xac, 0x81, 0x46, 0xac,
        0xeb, 0xe3, 0xb3, 0x0e, 0x13, 0xda, 0x75, 0x13,
        0xdb, 0x5b, 0x00, 0x25, 0x63, 0x24, 0xdd, 0x10,
        0x6b, 0x16, 0xc3, 0xf4, 0x3d, 0x18, 0xaf, 0xb6,
        0x2a, 0x34, 0x3f, 0xf0, 0x97, 0x3b, 0x30,
    };
    const expected = ("Lorem ipsum dolor sit amet, consectetur adipiscing elit. " ** 5)[0..256];
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary about word decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0x80, 0x00, 0x00, 0x20, 0x01, 0x52,
        0x83, 0x20, 0x53, 0x93, 0xe5, 0x6d,
    };
    const expected = "about information";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary information word decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0x80, 0x00, 0x00, 0x20, 0x01, 0x52,
        0x8b, 0x00, 0x53, 0xd2, 0xb5, 0x1c,
    };
    const expected = "information about";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary dictionary word decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0x78, 0x00, 0x00, 0x20, 0x01, 0x52,
        0x8b, 0x00, 0x53, 0xd7, 0xd6, 0x08, 0x01,
    };
    const expected = "dictionary about";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary press stem decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0x80, 0x00, 0x00, 0x20, 0xb0, 0x01, 0x47,
        0x1a, 0xfb, 0x34, 0x7c, 0xb5, 0xc9, 0x28, 0x75,
        0x61, 0xe2, 0xe2, 0xf5, 0x18,
    };
    const expected = "compression about";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary release word decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0x60, 0x00, 0x00, 0x20, 0x01, 0x52,
        0x83, 0x34, 0x52, 0x98, 0x46, 0x9d, 0x06,
    };
    const expected = "press release";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary expression word decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0x48, 0x00, 0x00, 0x20, 0x01,
        0x10, 0xc0, 0x04, 0x06, 0x03,
    };
    const expected = "expression";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary depression word decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0x48, 0x00, 0x00, 0x20, 0x01,
        0x10, 0xc0, 0x84, 0x66, 0x01,
    };
    const expected = "depression";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary omit-last-one transform decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0x40, 0x00, 0x00, 0x20, 0x01,
        0x10, 0x83, 0x14, 0x76, 0x7e, 0x01,
        0x19,
    };
    const expected = "wordpress";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary identity words entry decodes Node-accepted frame" {
    const encoded = [_]u8{
        0x82, 0x00, 0x00, 0x00, 0x04, 0x40,
        0x0c, 0x12, 0xd6, 0x03,
    };
    const expected = "words";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary identity games entry decodes Node-accepted frame" {
    const encoded = [_]u8{
        0x82, 0x00, 0x00, 0x00, 0x04, 0x40,
        0x0c, 0x12, 0x17, 0x00,
    };
    const expected = "games";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary omit-last-one games transform decodes Node-accepted frame" {
    const encoded = [_]u8{
        0x62, 0x00, 0x00, 0x00, 0x04, 0x40,
        0x0c, 0x12, 0x27, 0x0c, 0x00,
    };
    const expected = "game";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary leading-space words transform decodes Node-accepted frame" {
    const encoded = [_]u8{
        0xa2, 0x00, 0x00, 0x00, 0x04, 0x40,
        0x0c, 0x12, 0xe5, 0x0b, 0x00,
    };
    const expected = " words";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary leading-space games transform decodes Node-accepted frame" {
    const encoded = [_]u8{
        0xa2, 0x00, 0x00, 0x00, 0x04, 0x40,
        0x0c, 0x12, 0x25, 0x0c, 0x00,
    };
    const expected = " games";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary leading-space release transform decodes Node-accepted frame" {
    const encoded = [_]u8{
        0xe2, 0x00, 0x00, 0x00, 0x04, 0x40,
        0x14, 0x12, 0xa7, 0x2b, 0x00,
    };
    const expected = " release";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary trailing-space words transform decodes Node-accepted frame" {
    const encoded = [_]u8{
        0xa2, 0x00, 0x00, 0x00, 0x04, 0x40,
        0x0c, 0x12, 0xe0, 0x0b,
    };
    const expected = "words ";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary trailing-space games transform decodes Node-accepted frame" {
    const encoded = [_]u8{
        0xa2, 0x00, 0x00, 0x00, 0x04, 0x40,
        0x0c, 0x12, 0x20, 0x0c,
    };
    const expected = "games ";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary trailing-space release transform decodes Node-accepted frame" {
    const encoded = [_]u8{
        0xe2, 0x00, 0x00, 0x00, 0x04, 0x40,
        0x14, 0x12, 0xa2, 0x2b,
    };
    const expected = "release ";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary trailing-space dictionary transform decodes Node-accepted frame" {
    const encoded = [_]u8{
        0x42, 0x01, 0x00, 0x00, 0x04, 0x40,
        0x00, 0x13, 0xa0, 0x68,
    };
    const expected = "dictionary ";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary trailing-space information transform decodes Node-accepted frame" {
    const encoded = [_]u8{
        0x62, 0x01, 0x00, 0x00, 0x04, 0x40,
        0x00, 0x13, 0xe0, 0x04,
    };
    const expected = "information ";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary uppercase dictionary identity decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0x48, 0x00, 0x00, 0x20, 0x01,
        0x10, 0xc0, 0x04, 0x67, 0x09,
    };
    const expected = "Dictionary";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary uppercase information identity decodes Node quality-five frame" {
    const encoded = [_]u8{
        0xa1, 0x50, 0x00, 0x00, 0x20, 0x01,
        0x10, 0xc0, 0x84, 0xd6, 0x07,
    };
    const expected = "Information";
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(&encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, &encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal compressed stream selects literal context tree through signed mode" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralContextSigned(std.testing.allocator, &writer);

    try std.testing.expectEqual(@as(usize, 3), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &.{ 1, 'b', 1 }, decoded);
}

test "br minimal compressed stream selects third literal context tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralContextThreeTrees(std.testing.allocator, &writer);

    try std.testing.expectEqual(@as(usize, 3), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abc", decoded);
}

test "br minimal compressed stream switches command block tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 3, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForCommandSwitch(std.testing.allocator, &writer);

    try std.testing.expectEqual(@as(usize, 4), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaab", decoded);
}

test "br minimal compressed stream switches third command block tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 6, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForCommandSwitchThreeTypes(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 0, 2); // next command block count = 1
    try writer.writeBits(std.testing.allocator, 1, 2); // b
    try writer.writeBits(std.testing.allocator, 0, 2); // next command block count = 1
    try writer.writeBits(std.testing.allocator, 3, 2); // c

    try std.testing.expectEqual(@as(usize, 7), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaabbbc", decoded);
}

test "br minimal compressed stream switches fifth command block tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 12, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForCommandSwitchFiveTypes(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 0, 2); // next command block count = 1
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 0, 2); // next command block count = 1
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 0, 2); // next command block count = 1
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 0, 2); // next command block count = 1
    try writer.writeBits(std.testing.allocator, 1, 1); // b

    try std.testing.expectEqual(@as(usize, 13), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaaaaaaaaaaab", decoded);
}

test "br minimal compressed stream switches ninth command block tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 24, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForCommandSwitchNineTypes(std.testing.allocator, &writer);
    for (0..8) |_| {
        try writer.writeBits(std.testing.allocator, 0, 1); // a
        try writer.writeBits(std.testing.allocator, 0, 2); // next command block count = 1
    }
    try writer.writeBits(std.testing.allocator, 1, 1); // b

    try std.testing.expectEqual(@as(usize, 25), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaaaaaaaaaaaaaaaaaaaaaaab", decoded);
}

test "br minimal compressed stream switches literal block tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 1, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralBlockSwitch(std.testing.allocator, &writer);

    try std.testing.expectEqual(@as(usize, 2), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ab", decoded);
}

test "br minimal compressed stream switches literal block with complex length tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 1, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralBlockSwitchComplexLength(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 0, 1); // block length symbol 0
    try writer.writeBits(std.testing.allocator, 0, 2); // next literal block count = 1

    try std.testing.expectEqual(@as(usize, 2), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "ab", decoded);
}

test "br minimal compressed stream switches third literal block tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 2, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralBlockSwitchThreeTypes(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 0, 2); // next literal block count = 1
    try writer.writeBits(std.testing.allocator, 0, 2); // next literal block count = 1

    try std.testing.expectEqual(@as(usize, 3), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abc", decoded);
}

test "br minimal compressed stream switches fifth literal block tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 4, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralBlockSwitchFiveTypes(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 0, 2); // next literal block count = 1
    try writer.writeBits(std.testing.allocator, 0, 2); // next literal block count = 1
    try writer.writeBits(std.testing.allocator, 0, 2); // next literal block count = 1
    try writer.writeBits(std.testing.allocator, 0, 2); // next literal block count = 1

    try std.testing.expectEqual(@as(usize, 5), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaaae", decoded);
}

test "br minimal compressed stream switches ninth literal block tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 8, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForLiteralBlockSwitchNineTypes(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 1, 1); // insert length extra bit -> 9
    for (0..8) |_| {
        try writer.writeBits(std.testing.allocator, 0, 2); // next literal block count = 1
    }

    try std.testing.expectEqual(@as(usize, 9), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "aaaaaaaai", decoded);
}

test "br minimal compressed stream switches distance block tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 6, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForDistanceBlockSwitch(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 1, 1); // command 152
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 2); // b
    try writer.writeBits(std.testing.allocator, 3, 2); // c
    try writer.writeBits(std.testing.allocator, 0, 1); // command 128
    try writer.writeBits(std.testing.allocator, 0, 2); // next distance block count = 1

    try std.testing.expectEqual(@as(usize, 7), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abcabab", decoded);
}

test "br minimal compressed stream switches third distance block tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 8, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForDistanceBlockSwitchThreeTypes(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 1, 1); // command 152
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 2); // b
    try writer.writeBits(std.testing.allocator, 3, 2); // c
    try writer.writeBits(std.testing.allocator, 0, 1); // command 128
    try writer.writeBits(std.testing.allocator, 0, 2); // next distance block count = 1
    try writer.writeBits(std.testing.allocator, 0, 1); // command 128
    try writer.writeBits(std.testing.allocator, 0, 2); // next distance block count = 1

    try std.testing.expectEqual(@as(usize, 9), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abcababbb", decoded);
}

test "br minimal compressed stream switches fifth distance block tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 12, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForDistanceBlockSwitchFiveTypes(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 1, 1); // command 152
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 2); // b
    try writer.writeBits(std.testing.allocator, 3, 2); // c
    try writer.writeBits(std.testing.allocator, 0, 1); // command 128
    try writer.writeBits(std.testing.allocator, 0, 2); // next distance block count = 1
    try writer.writeBits(std.testing.allocator, 0, 1); // command 128
    try writer.writeBits(std.testing.allocator, 0, 2); // next distance block count = 1
    try writer.writeBits(std.testing.allocator, 0, 1); // command 128
    try writer.writeBits(std.testing.allocator, 0, 2); // next distance block count = 1
    try writer.writeBits(std.testing.allocator, 0, 1); // command 128
    try writer.writeBits(std.testing.allocator, 0, 2); // next distance block count = 1

    try std.testing.expectEqual(@as(usize, 13), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abcabcabcabbb", decoded);
}

test "br minimal compressed stream switches ninth distance block tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 1, 1); // ISLAST
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(std.testing.allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(std.testing.allocator, 20, 16); // MLEN - 1
    try writeMinimalCompressedHeaderForDistanceBlockSwitchNineTypes(std.testing.allocator, &writer);
    try writer.writeBits(std.testing.allocator, 1, 1); // command 152
    try writer.writeBits(std.testing.allocator, 0, 1); // a
    try writer.writeBits(std.testing.allocator, 1, 2); // b
    try writer.writeBits(std.testing.allocator, 3, 2); // c
    for (0..8) |_| {
        try writer.writeBits(std.testing.allocator, 0, 1); // command 128
        try writer.writeBits(std.testing.allocator, 0, 2); // next distance block count = 1
    }

    try std.testing.expectEqual(@as(usize, 21), try decodedStreamSize(encoded.items));
    const decoded = try decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abcabcabcabcabcabcaaa", decoded);
}

test "br stored stream rejects unsupported compressed blocks and trailing data" {
    try std.testing.expectError(error.TruncatedFrame, decodeStreamAlloc(std.testing.allocator, &[_]u8{ 0x00, 0x00 }));
    try std.testing.expectError(error.TrailingData, decodedStreamSize(&[_]u8{ 0x06, 0x00 }));
    try std.testing.expectError(error.TruncatedFrame, decodedStreamSize(&[_]u8{ 0x40, 0x00, 0x10, 'h' }));
}

test "br stored stream rejects malformed metadata meta-blocks" {
    var reserved_bad: std.ArrayList(u8) = .empty;
    defer reserved_bad.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &reserved_bad };
    try writeWindowBits(std.testing.allocator, &writer, default_window_bits);
    try writer.writeBits(std.testing.allocator, 0, 1); // ISLAST = false.
    try writer.writeBits(std.testing.allocator, 0b11, 2); // MNIBBLES = 0.
    try writer.writeBits(std.testing.allocator, 1, 1); // reserved, invalid.
    try writer.writeBits(std.testing.allocator, 0, 2);
    try std.testing.expectError(error.CorruptFrame, decodedStreamSize(reserved_bad.items));

    var truncated = try encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "", .{ .metadata = "metadata" });
    defer std.testing.allocator.free(truncated);
    try std.testing.expectError(error.TruncatedFrame, decodedStreamSize(truncated[0 .. truncated.len - 1]));
}

test "br simple prefix code decodes single symbol without consuming data bits" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 1, 2); // simple prefix code.
    try writer.writeBits(std.testing.allocator, 0, 2); // NSYM = 1.
    try writer.writeBits(std.testing.allocator, 5, alphabetBits(8));

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(8, &reader);
    const before = reader.bitPosition();
    try std.testing.expectEqual(@as(u16, 5), try prefix.decode(&reader));
    try std.testing.expectEqual(before, reader.bitPosition());
}

test "br block type count reader covers RFC boundaries" {
    const cases = [_]u16{ 1, 2, 3, 4, 5, 8, 9, 16, 17, 32, 33, 64, 65, 128, 129, 256 };
    inline for (cases) |value| {
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(std.testing.allocator);
        var writer = BitWriter{ .out = &encoded };
        try writeBlockTypeCount(std.testing.allocator, &writer, value);

        var reader = bitstream.BitReader.init(encoded.items);
        try std.testing.expectEqual(@as(u16, value), try readBlockTypeCount(&reader));
    }

    var truncated = bitstream.BitReader.init(&.{});
    try std.testing.expectError(error.TruncatedFrame, readBlockTypeCount(&truncated));
}

test "br minimal compressed header parser reads single-tree shape" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NBLTYPESL
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NBLTYPESI
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NBLTYPESD
    try writer.writeBits(std.testing.allocator, 1, 2); // NPOSTFIX
    try writer.writeBits(std.testing.allocator, 3, 4); // NDIRECT high bits -> 6
    try writer.writeBits(std.testing.allocator, 2, 2); // literal context mode
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NTREESL
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NTREESD
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &writer, 256, 'A');
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &writer, 704, 0);
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &writer, 118, 0);

    var reader = bitstream.BitReader.init(encoded.items);
    const header = try readMinimalCompressedHeader(&reader);
    try std.testing.expectEqual(@as(u2, 1), header.npostfix);
    try std.testing.expectEqual(@as(u16, 6), header.ndirect);
    try std.testing.expectEqual(@as(u2, 2), header.literal_context_modes[0]);
    try std.testing.expectEqual(@as(u16, 'A'), try header.literal_trees[0].decode(&reader));
    try std.testing.expectEqual(@as(u16, 0), try header.insert_copy_trees[0].decode(&reader));
    try std.testing.expectEqual(@as(u16, 0), try header.distance_trees[0].decode(&reader));
}

test "br minimal compressed header parser accepts ninth literal context tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NBLTYPESL
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NBLTYPESI
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NBLTYPESD
    try writer.writeBits(std.testing.allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(std.testing.allocator, 0, 4); // NDIRECT
    try writer.writeBits(std.testing.allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(std.testing.allocator, &writer, 9); // NTREESL
    try writeZeroContextMapRle(std.testing.allocator, &writer, 64, 9, 6);
    try writeBlockTypeCount(std.testing.allocator, &writer, 1); // NTREESD
    for (0..9) |symbol| {
        try writeSimpleSingleSymbolPrefix(std.testing.allocator, &writer, 256, @intCast(symbol));
    }
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &writer, 704, 0);
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &writer, 64, 0);

    var reader = bitstream.BitReader.init(encoded.items);
    const header = try readMinimalCompressedHeader(&reader);
    try std.testing.expectEqual(@as(u16, 0), try header.literal_trees[0].decode(&reader));
    try std.testing.expectEqual(@as(u16, 8), try header.literal_trees[8].decode(&reader));
}

test "br minimal compressed header parser accepts ndirect boundary" {
    var bad_ndirect: std.ArrayList(u8) = .empty;
    defer bad_ndirect.deinit(std.testing.allocator);
    var bad_writer = BitWriter{ .out = &bad_ndirect };
    try writeBlockTypeCount(std.testing.allocator, &bad_writer, 1);
    try writeBlockTypeCount(std.testing.allocator, &bad_writer, 1);
    try writeBlockTypeCount(std.testing.allocator, &bad_writer, 1);
    try bad_writer.writeBits(std.testing.allocator, 3, 2); // NPOSTFIX
    try bad_writer.writeBits(std.testing.allocator, 15, 4); // NDIRECT = 120 is valid.
    try bad_writer.writeBits(std.testing.allocator, 0, 2);
    try writeBlockTypeCount(std.testing.allocator, &bad_writer, 1);
    try writeBlockTypeCount(std.testing.allocator, &bad_writer, 1);
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &bad_writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &bad_writer, 704, 0);
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &bad_writer, 520, 0);
    var valid_reader = bitstream.BitReader.init(bad_ndirect.items);
    try std.testing.expectEqual(@as(u16, 120), (try readMinimalCompressedHeader(&valid_reader)).ndirect);
}

test "br context map reader applies inverse move-to-front maps" {
    var imtf_context_map: std.ArrayList(u8) = .empty;
    defer imtf_context_map.deinit(std.testing.allocator);
    var multi_writer = BitWriter{ .out = &imtf_context_map };
    try multi_writer.writeBits(std.testing.allocator, 0, 1); // RLEMAX = 0
    try multi_writer.writeBits(std.testing.allocator, 1, 2); // simple context-map prefix
    try multi_writer.writeBits(std.testing.allocator, 2, 2); // NSYM = 3
    try multi_writer.writeBits(std.testing.allocator, 0, alphabetBits(3));
    try multi_writer.writeBits(std.testing.allocator, 1, alphabetBits(3));
    try multi_writer.writeBits(std.testing.allocator, 2, alphabetBits(3));
    try multi_writer.writeBits(std.testing.allocator, 1, 2); // raw MTF index 1
    try multi_writer.writeBits(std.testing.allocator, 1, 2); // raw MTF index 1
    try multi_writer.writeBits(std.testing.allocator, 0, 1); // raw MTF index 0
    try multi_writer.writeBits(std.testing.allocator, 3, 2); // raw MTF index 2
    try multi_writer.writeBits(std.testing.allocator, 1, 1); // IMTF = true
    var multi_reader = bitstream.BitReader.init(imtf_context_map.items);
    var context_map: [4]u8 = @splat(0);
    try readContextMap(&multi_reader, &context_map, 3);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 2 }, &context_map);
}

test "br zero context map reader accepts plain and RLE all-zero maps" {
    var plain: std.ArrayList(u8) = .empty;
    defer plain.deinit(std.testing.allocator);
    var plain_writer = BitWriter{ .out = &plain };
    try plain_writer.writeBits(std.testing.allocator, 0, 1); // RLEMAX = 0
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &plain_writer, 2, 0);
    try plain_writer.writeBits(std.testing.allocator, 0, 1); // IMTF = false
    var plain_reader = bitstream.BitReader.init(plain.items);
    try readZeroContextMap(&plain_reader, 64, 2);

    var rle: std.ArrayList(u8) = .empty;
    defer rle.deinit(std.testing.allocator);
    var rle_writer = BitWriter{ .out = &rle };
    try writeZeroContextMapRle(std.testing.allocator, &rle_writer, 64, 2, 6);
    var rle_reader = bitstream.BitReader.init(rle.items);
    try readZeroContextMap(&rle_reader, 64, 2);

    var nonzero: std.ArrayList(u8) = .empty;
    defer nonzero.deinit(std.testing.allocator);
    var nonzero_writer = BitWriter{ .out = &nonzero };
    try nonzero_writer.writeBits(std.testing.allocator, 0, 1);
    try writeSimpleSingleSymbolPrefix(std.testing.allocator, &nonzero_writer, 2, 1);
    var nonzero_reader = bitstream.BitReader.init(nonzero.items);
    try std.testing.expectError(error.UnsupportedBrotliFeature, readZeroContextMap(&nonzero_reader, 64, 2));
}

test "br distance context map reader preserves nonzero tree indexes" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writeDistanceContextMapForCopyLenThree(std.testing.allocator, &writer);

    var context_map: [4]u8 = @splat(0);
    var reader = bitstream.BitReader.init(encoded.items);
    try readContextMap(&reader, &context_map, 2);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0, 0 }, &context_map);
}

test "br literal context helpers cover LSB6 and MSB6 modes" {
    var header = MinimalCompressedHeader{
        .npostfix = 0,
        .ndirect = 0,
        .literal_context_modes = @splat(0),
        .literal_block = .{},
        .literal_context_map = @splat(0),
        .literal_trees = @splat(.{}),
        .command_block = .{},
        .insert_copy_trees = @splat(.{}),
        .distance_block = .{},
        .distance_context_map = @splat(0),
        .distance_trees = @splat(.{}),
    };
    try std.testing.expectEqual(@as(usize, 0), try literalContext(&header, "", 0));
    try std.testing.expectEqual(@as(usize, 0x23), try literalContext(&header, "abc", 3));
    header.literal_context_modes[0] = 1;
    try std.testing.expectEqual(@as(usize, 0x18), try literalContext(&header, "abc", 3));
    header.literal_context_modes[0] = 2;
    try std.testing.expectEqual(@as(usize, 60 | 2), try literalContext(&header, "1b", 2));
    try std.testing.expectEqual(@as(usize, 56), try literalContextFromMode(2, 'a', 0));
    try std.testing.expectEqual(@as(usize, 3), try literalContextFromMode(2, 193, 0));
    header.literal_context_modes[0] = 3;
    try std.testing.expectEqual(@as(usize, 25), try literalContext(&header, &.{ 1, 64 }, 2));
    try std.testing.expectEqual(@as(usize, 63), try literalContextFromMode(3, 255, 255));
}

test "br insert-copy length decoder covers basic and extra-bit ranges" {
    var empty_reader = bitstream.BitReader.init(&.{});
    const zero = try readInsertCopyLengths(0, &empty_reader);
    try std.testing.expectEqual(@as(usize, 0), zero.insert_len);
    try std.testing.expectEqual(@as(usize, 2), zero.copy_len);
    try std.testing.expect(zero.distance_symbol_zero);

    var insert_extra_reader = bitstream.BitReader.init(&.{0b0000_0001});
    const insert_extra = try readInsertCopyLengths(6 << 3, &insert_extra_reader);
    try std.testing.expectEqual(@as(usize, 7), insert_extra.insert_len);
    try std.testing.expectEqual(@as(usize, 2), insert_extra.copy_len);
    try std.testing.expect(insert_extra.distance_symbol_zero);

    var copy_extra_reader = bitstream.BitReader.init(&.{0b0000_0001});
    const copy_extra = try readInsertCopyLengths(64 + 0, &copy_extra_reader);
    try std.testing.expectEqual(@as(usize, 0), copy_extra.insert_len);
    try std.testing.expectEqual(@as(usize, 11), copy_extra.copy_len);
    try std.testing.expect(copy_extra.distance_symbol_zero);

    var explicit_distance_reader = bitstream.BitReader.init(&.{0});
    const explicit_distance = try readInsertCopyLengths(128, &explicit_distance_reader);
    try std.testing.expectEqual(@as(usize, 0), explicit_distance.insert_len);
    try std.testing.expectEqual(@as(usize, 2), explicit_distance.copy_len);
    try std.testing.expect(!explicit_distance.distance_symbol_zero);
}

test "br insert-copy length decoder handles high range extra bits" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 3, 10); // insert code 20 extra => 1093.
    try writer.writeBits(std.testing.allocator, 17, 10); // copy code 22 extra => 1111.

    var reader = bitstream.BitReader.init(encoded.items);
    const lengths = try readInsertCopyLengths(640 + (4 << 3) + 6, &reader);
    try std.testing.expectEqual(@as(usize, 1093), lengths.insert_len);
    try std.testing.expectEqual(@as(usize, 1111), lengths.copy_len);
    try std.testing.expect(!lengths.distance_symbol_zero);

    var invalid_reader = bitstream.BitReader.init(&.{});
    try std.testing.expectError(error.InvalidHuffmanCode, readInsertCopyLengths(704, &invalid_reader));
}

test "br short distance resolver covers RFC table" {
    const last_distances = [_]usize{ 16, 15, 11, 4 };
    const expected = [_]usize{ 4, 11, 15, 16, 3, 5, 2, 6, 1, 7, 10, 12, 9, 13, 8, 14 };
    for (expected, 0..) |distance, symbol| {
        try std.testing.expectEqual(distance, try resolveShortDistance(@intCast(symbol), &last_distances));
    }

    const small_last = [_]usize{ 16, 15, 2, 1 };
    try std.testing.expectError(error.InvalidMatch, resolveShortDistance(4, &small_last));
    try std.testing.expectError(error.InvalidMatch, resolveShortDistance(12, &small_last));
}

test "br regular distance resolver covers postfix and extra bits" {
    try std.testing.expectEqual(@as(usize, 2), try resolveRegularDistance(1, 0, 17, 0));
    try std.testing.expectEqual(@as(usize, 3), try resolveRegularDistance(0, 1, 17, 1));
    try std.testing.expectEqual(@as(usize, 18), try resolveRegularDistance(2, 4, 25, 1));
    try std.testing.expectError(error.InvalidHuffmanCode, resolveRegularDistance(0, 4, 19, 0));
}

test "br simple prefix code decodes three-symbol canonical tree" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 1, 2); // simple prefix code.
    try writer.writeBits(std.testing.allocator, 2, 2); // NSYM = 3.
    try writer.writeBits(std.testing.allocator, 5, alphabetBits(8));
    try writer.writeBits(std.testing.allocator, 2, alphabetBits(8));
    try writer.writeBits(std.testing.allocator, 7, alphabetBits(8));
    try writer.writeBits(std.testing.allocator, 0, 1); // symbol 5, length 1, canonical code 0.
    try writer.writeBits(std.testing.allocator, 1, 2); // symbol 2, length 2, canonical code 10 -> stored 01.
    try writer.writeBits(std.testing.allocator, 3, 2); // symbol 7, length 2, canonical code 11.

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(8, &reader);
    try std.testing.expectEqual(@as(u16, 5), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 2), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 7), try prefix.decode(&reader));
}

test "br simple prefix code decodes four-symbol tree variants" {
    inline for (.{ 0, 1 }) |tree_select| {
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(std.testing.allocator);
        var writer = BitWriter{ .out = &encoded };
        try writer.writeBits(std.testing.allocator, 1, 2); // simple prefix code.
        try writer.writeBits(std.testing.allocator, 3, 2); // NSYM = 4.
        try writer.writeBits(std.testing.allocator, 1, alphabetBits(8));
        try writer.writeBits(std.testing.allocator, 2, alphabetBits(8));
        try writer.writeBits(std.testing.allocator, 3, alphabetBits(8));
        try writer.writeBits(std.testing.allocator, 4, alphabetBits(8));
        try writer.writeBits(std.testing.allocator, tree_select, 1);

        if (tree_select == 0) {
            // Four 2-bit codes assigned by sorted symbol order: 00, 01, 10, 11.
            try writer.writeBits(std.testing.allocator, 0, 2);
            try writer.writeBits(std.testing.allocator, 2, 2);
            try writer.writeBits(std.testing.allocator, 1, 2);
            try writer.writeBits(std.testing.allocator, 3, 2);
        } else {
            // Lengths in representation order are 1,2,3,3.
            try writer.writeBits(std.testing.allocator, 0, 1);
            try writer.writeBits(std.testing.allocator, 1, 2);
            try writer.writeBits(std.testing.allocator, 3, 3);
            try writer.writeBits(std.testing.allocator, 7, 3);
        }

        var reader = bitstream.BitReader.init(encoded.items);
        const prefix = try readPrefixCode(8, &reader);
        try std.testing.expectEqual(@as(u16, 1), try prefix.decode(&reader));
        try std.testing.expectEqual(@as(u16, 2), try prefix.decode(&reader));
        try std.testing.expectEqual(@as(u16, 3), try prefix.decode(&reader));
        try std.testing.expectEqual(@as(u16, 4), try prefix.decode(&reader));
    }
}

test "br simple prefix code rejects invalid symbol lists" {
    var duplicate: std.ArrayList(u8) = .empty;
    defer duplicate.deinit(std.testing.allocator);
    var duplicate_writer = BitWriter{ .out = &duplicate };
    try duplicate_writer.writeBits(std.testing.allocator, 1, 2);
    try duplicate_writer.writeBits(std.testing.allocator, 1, 2); // NSYM = 2.
    try duplicate_writer.writeBits(std.testing.allocator, 3, alphabetBits(8));
    try duplicate_writer.writeBits(std.testing.allocator, 3, alphabetBits(8));
    var duplicate_reader = bitstream.BitReader.init(duplicate.items);
    try std.testing.expectError(error.InvalidHuffmanCode, readPrefixCode(8, &duplicate_reader));

    var out_of_range: std.ArrayList(u8) = .empty;
    defer out_of_range.deinit(std.testing.allocator);
    var out_of_range_writer = BitWriter{ .out = &out_of_range };
    try out_of_range_writer.writeBits(std.testing.allocator, 1, 2);
    try out_of_range_writer.writeBits(std.testing.allocator, 0, 2); // NSYM = 1.
    try out_of_range_writer.writeBits(std.testing.allocator, 7, alphabetBits(7));
    var out_of_range_reader = bitstream.BitReader.init(out_of_range.items);
    try std.testing.expectError(error.InvalidHuffmanCode, readPrefixCode(7, &out_of_range_reader));

    var truncated_complex = bitstream.BitReader.init(&[_]u8{0});
    try std.testing.expectError(error.TruncatedFrame, readPrefixCode(8, &truncated_complex));
}

test "br complex prefix code decodes direct length sequence" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[0] = 2;
    cl_lengths[1] = 2;
    cl_lengths[2] = 2;
    cl_lengths[3] = 2;
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 2); // symbol 1
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 2); // symbol 2
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 2); // symbol 3
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 4
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 2); // symbol 0

    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 1);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 2);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 3);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 3);
    try writer.writeBits(std.testing.allocator, 0, 1); // symbol 0, code 0
    try writer.writeBits(std.testing.allocator, 1, 2); // symbol 1, code 10 -> stored 01
    try writer.writeBits(std.testing.allocator, 3, 3); // symbol 2, code 110 -> stored 011
    try writer.writeBits(std.testing.allocator, 7, 3); // symbol 3, code 111

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(4, &reader);
    try std.testing.expectEqual(@as(u16, 0), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 1), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 2), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 3), try prefix.decode(&reader));
}

test "br complex prefix code supports zero repeats" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[1] = 1;
    cl_lengths[17] = 1;
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 1
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 2
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 3
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 4
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 0
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 5
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 17

    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 17);
    try writer.writeBits(std.testing.allocator, 1, 3); // repeat 4 zeros.
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 1);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 1);
    try writer.writeBits(std.testing.allocator, 0, 1);
    try writer.writeBits(std.testing.allocator, 1, 1);

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(6, &reader);
    try std.testing.expectEqual(@as(u16, 4), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 5), try prefix.decode(&reader));
}

test "br complex prefix code supports repeat previous length" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[2] = 1;
    cl_lengths[16] = 1;
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 1
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 2
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 3
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 4
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 0
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 5
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 17
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 6
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 16

    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 2);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 16);
    try writer.writeBits(std.testing.allocator, 0, 2); // repeat previous length 3 times.
    try writer.writeBits(std.testing.allocator, 0, 2);
    try writer.writeBits(std.testing.allocator, 2, 2);
    try writer.writeBits(std.testing.allocator, 1, 2);
    try writer.writeBits(std.testing.allocator, 3, 2);

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(4, &reader);
    try std.testing.expectEqual(@as(u16, 0), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 1), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 2), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 3), try prefix.decode(&reader));
}

test "br complex prefix code supports chained zero repeats" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[1] = 1;
    cl_lengths[17] = 1;
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 1
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 2
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 3
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 4
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 0
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 5
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 17

    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 17);
    try writer.writeBits(std.testing.allocator, 0, 3); // repeat 3 zeros.
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 17);
    try writer.writeBits(std.testing.allocator, 1, 3); // chained repeat: 8*(3-2)+4 = 12 zeros.
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 1);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 1);
    try writer.writeBits(std.testing.allocator, 0, 1);
    try writer.writeBits(std.testing.allocator, 1, 1);

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(17, &reader);
    try std.testing.expectEqual(@as(u16, 12), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 13), try prefix.decode(&reader));
}

test "br complex prefix code supports chained previous-length repeats" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &encoded };
    try writer.writeBits(std.testing.allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[4] = 1;
    cl_lengths[16] = 1;
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 1
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 2
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 3
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 4
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 0
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 5
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 17
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 0); // symbol 6
    try writeCodeLengthCodeLength(std.testing.allocator, &writer, 1); // symbol 16

    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 4);
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 16);
    try writer.writeBits(std.testing.allocator, 2, 2); // repeat previous length 5 times.
    try writeCodeLengthSymbol(std.testing.allocator, &writer, &cl_lengths, 16);
    try writer.writeBits(std.testing.allocator, 0, 2); // chained repeat: 4*(5-2)+3 = 15 repeats.
    try writer.writeBits(std.testing.allocator, 0, 4);
    try writer.writeBits(std.testing.allocator, 8, 4);
    try writer.writeBits(std.testing.allocator, 4, 4);
    try writer.writeBits(std.testing.allocator, 12, 4);

    var reader = bitstream.BitReader.init(encoded.items);
    const prefix = try readPrefixCode(16, &reader);
    try std.testing.expectEqual(@as(u16, 0), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 1), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 2), try prefix.decode(&reader));
    try std.testing.expectEqual(@as(u16, 3), try prefix.decode(&reader));
}

fn writeCodeLengthCodeLength(allocator: std.mem.Allocator, writer: *BitWriter, length: u4) Error!void {
    switch (length) {
        0 => try writer.writeBits(allocator, 0b00, 2),
        1 => try writer.writeBits(allocator, 0b0111, 4),
        2 => try writer.writeBits(allocator, 0b011, 3),
        3 => try writer.writeBits(allocator, 0b10, 2),
        4 => try writer.writeBits(allocator, 0b01, 2),
        5 => try writer.writeBits(allocator, 0b1111, 4),
        else => return error.InvalidHuffmanCode,
    }
}

fn writeMinimalCompressedHeaderForHello(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 3, 2); // NSYM = 4
    try writer.writeBits(allocator, 'h', alphabetBits(256));
    try writer.writeBits(allocator, 'e', alphabetBits(256));
    try writer.writeBits(allocator, 'l', alphabetBits(256));
    try writer.writeBits(allocator, 'o', alphabetBits(256));
    try writer.writeBits(allocator, 0, 1); // tree-select

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 40);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForHelloWithContextMaps(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeZeroContextMapRle(allocator, writer, 64, 2, 6);
    try writeBlockTypeCount(allocator, writer, 2); // NTREESD
    try writeZeroContextMapRle(allocator, writer, 4, 2, 2);

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 3, 2); // NSYM = 4
    try writer.writeBits(allocator, 'h', alphabetBits(256));
    try writer.writeBits(allocator, 'e', alphabetBits(256));
    try writer.writeBits(allocator, 'l', alphabetBits(256));
    try writer.writeBits(allocator, 'o', alphabetBits(256));
    try writer.writeBits(allocator, 0, 1); // tree-select
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0); // unused literal tree

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 40);

    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0); // unused distance tree
}

fn writeMinimalCompressedHeaderForCopy(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 1, 4); // NDIRECT = 1
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 138);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 65, 16);
}

fn writeMinimalCompressedHeaderForLastDistance(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 1, 4); // NDIRECT = 1
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 136, alphabetBits(704));
    try writer.writeBits(allocator, 0, alphabetBits(704));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 65, 16);
}

fn writeMinimalCompressedHeaderForShortDistance(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 1, 4); // NDIRECT = 1
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 136, alphabetBits(704));
    try writer.writeBits(allocator, 128, alphabetBits(704));

    try writer.writeBits(allocator, 1, 2); // simple distance prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 16, alphabetBits(65));
    try writer.writeBits(allocator, 5, alphabetBits(65));
}

fn writeMinimalCompressedHeaderForRegularDistance(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 1, 2); // NPOSTFIX
    try writer.writeBits(allocator, 1, 4); // NDIRECT = 1
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 0, 2); // NSYM = 1
    try writer.writeBits(allocator, 145, alphabetBits(704));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 112, 17);
}

fn writeMinimalCompressedHeaderForDistanceContext(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 2, 4); // NDIRECT = 2
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 2); // NTREESD
    try writeDistanceContextMapForCopyLenThree(allocator, writer);

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 145);

    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 17);
}

fn writeMinimalCompressedHeaderForDistanceContextComplexMap(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 2, 4); // NDIRECT = 2
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 2); // NTREESD
    try writeDistanceContextMapForCopyLenThreeComplexPrefix(allocator, writer);

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 145);

    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 17);
}

fn writeMinimalCompressedHeaderForComplexDistancePrefix(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 2, 4); // NDIRECT = 2
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 145);
    try writeComplexDistancePrefixForDistanceTwo(allocator, writer);
}

fn writeMinimalCompressedHeaderForFifthDistanceContext(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 2, 4); // NDIRECT = 2
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 5); // NTREESD
    try writeDistanceContextMapForCopyLenThreeFifthTree(allocator, writer);

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 145);

    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 17);
}

fn writeMinimalCompressedHeaderForNinthDistanceContext(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 2, 4); // NDIRECT = 2
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 9); // NTREESD
    try writeDistanceContextMapForCopyLenThreeNinthTree(allocator, writer);

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 145);

    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 66, 17);
}

fn writeMinimalCompressedHeaderForLiteralContext(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode = LSB6
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeLiteralContextMapForA(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 24);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForLiteralContextAfterStoredA(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode = LSB6
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeLiteralContextMapForA(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 8);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForComplexLiteralPrefix(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode = LSB6
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeComplexTwoLiteralPrefix(allocator, writer, 'a', 'b');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 24);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForComplexCommandPrefix(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode = LSB6
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));
    try writeComplexCommandPrefixForInsertTwo(allocator, writer);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForLiteralContextImtf(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode = LSB6
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeLiteralContextMapForAImtf(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 24);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForLiteralContextUtf8(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 2, 2); // literal context mode = UTF8
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeUtf8LiteralContextMapForA(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 24);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForLiteralContextUtf8Rle(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 2, 2); // literal context mode = UTF8
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeUtf8LiteralContextMapForARle(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 24);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForLiteralContextUtf8ComplexMap(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 2, 2); // literal context mode = UTF8
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeUtf8LiteralContextMapForAComplexPrefix(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 24);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForUtf8ContextAfterDistanceThreeCopy(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 3, 4); // NDIRECT = 3
    try writer.writeBits(allocator, 2, 2); // literal context mode = UTF8
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeUtf8LiteralContextMapForContext63(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'c');

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 152, alphabetBits(704));
    try writer.writeBits(allocator, 8, alphabetBits(704));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 18);
}

fn writeMinimalCompressedHeaderForContextAfterDistanceThirtyThreeCopy(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 3, 2); // NPOSTFIX
    try writer.writeBits(allocator, 5, 4); // NDIRECT = 40
    try writer.writeBits(allocator, 0, 2); // literal context mode = LSB6
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeLiteralContextMapForB(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));
    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'c', alphabetBits(256));

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 280, alphabetBits(704));
    try writer.writeBits(allocator, 8, alphabetBits(704));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 440, 48);
}

fn writeMinimalCompressedHeaderForContextAfterDistanceSixtyFiveCopy(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 3, 2); // NPOSTFIX
    try writer.writeBits(allocator, 9, 4); // NDIRECT = 72
    try writer.writeBits(allocator, 0, 2); // literal context mode = LSB6
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeLiteralContextMapForB(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));
    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'c', alphabetBits(256));

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 296, alphabetBits(704));
    try writer.writeBits(allocator, 8, alphabetBits(704));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 472, 80);
}

fn writeMinimalCompressedHeaderForContextAfterDistanceOneTwentyNineCopy(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode = LSB6
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeLiteralContextMapForB(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));
    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'c', alphabetBits(256));

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 312, alphabetBits(704));
    try writer.writeBits(allocator, 8, alphabetBits(704));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 26);
}

fn writeMinimalCompressedHeaderForLiteralContextFiveTrees(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 2, 2); // literal context mode = UTF8
    try writeBlockTypeCount(allocator, writer, 5); // NTREESL
    try writeUtf8LiteralContextMapForFifthTree(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 24);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForLiteralContextNineTrees(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 2, 2); // literal context mode = UTF8
    try writeBlockTypeCount(allocator, writer, 9); // NTREESL
    try writeUtf8LiteralContextMapForNinthTree(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 24);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForLiteralContextSigned(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 3, 2); // literal context mode = Signed
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeSignedLiteralContextMapForOneAfterZero(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 1);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 24);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForLiteralContextThreeTrees(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode = LSB6
    try writeBlockTypeCount(allocator, writer, 3); // NTREESL
    try writeLiteralContextMapForAb(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'c');

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 24);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForCommandSwitch(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 2); // NBLTYPESI
    try writeSimpleSingleSymbolPrefix(allocator, writer, 4, 1); // next command block type
    try writeSimpleSingleSymbolPrefix(allocator, writer, 26, 0); // block count code
    try writer.writeBits(allocator, 0, 2); // first block count = 1
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 1, 4); // NDIRECT = 1
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 136);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 8);

    try writeSimpleSingleSymbolPrefix(allocator, writer, 65, 16);
    try writer.writeBits(allocator, 0, 1); // a
    try writer.writeBits(allocator, 0, 2); // next block count = 1
    try writer.writeBits(allocator, 1, 1); // b
}

fn writeMinimalCompressedHeaderForCommandSwitchThreeTypes(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 3); // NBLTYPESI
    try writeSimpleSingleSymbolPrefix(allocator, writer, 5, 1); // next command block type
    try writeSimpleSingleSymbolPrefix(allocator, writer, 26, 0); // block count code
    try writer.writeBits(allocator, 0, 2); // first command block count = 1
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 1, 4); // NDIRECT = 1
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 2, 2); // NSYM = 3
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));
    try writer.writeBits(allocator, 'c', alphabetBits(256));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 136);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 136);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 8);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 65, 16);
}

fn writeMinimalCompressedHeaderForCommandSwitchFiveTypes(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 5); // NBLTYPESI
    try writeSimpleSingleSymbolPrefix(allocator, writer, 7, 1); // next command block type
    try writeSimpleSingleSymbolPrefix(allocator, writer, 26, 0); // block count code
    try writer.writeBits(allocator, 0, 2); // first command block count = 1
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 1, 4); // NDIRECT = 1
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 136);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 136);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 136);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 136);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 8);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 65, 16);
}

fn writeMinimalCompressedHeaderForCommandSwitchNineTypes(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 9); // NBLTYPESI
    try writeSimpleSingleSymbolPrefix(allocator, writer, 11, 1); // next command block type
    try writeSimpleSingleSymbolPrefix(allocator, writer, 26, 0); // block count code
    try writer.writeBits(allocator, 0, 2); // first command block count = 1
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 1, 4); // NDIRECT = 1
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));

    for (0..8) |_| {
        try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 136);
    }
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 8);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 65, 16);
}

fn writeMinimalCompressedHeaderForLiteralBlockSwitch(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 2); // NBLTYPESL
    try writeSimpleSingleSymbolPrefix(allocator, writer, 4, 1); // next literal block type
    try writeSimpleSingleSymbolPrefix(allocator, writer, 26, 0); // block count code
    try writer.writeBits(allocator, 0, 2); // first literal block count = 1
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode for block type 0
    try writer.writeBits(allocator, 0, 2); // literal context mode for block type 1
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeLiteralBlockSwitchContextMap(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForLiteralBlockSwitchComplexLength(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 2); // NBLTYPESL
    try writeSimpleSingleSymbolPrefix(allocator, writer, 4, 1); // next literal block type
    try writeComplexBlockLengthPrefixOne(allocator, writer);
    try writer.writeBits(allocator, 0, 1); // block length symbol 0
    try writer.writeBits(allocator, 0, 2); // first literal block count = 1
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode for block type 0
    try writer.writeBits(allocator, 0, 2); // literal context mode for block type 1
    try writeBlockTypeCount(allocator, writer, 2); // NTREESL
    try writeLiteralBlockSwitchContextMap(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForLiteralBlockSwitchThreeTypes(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 3); // NBLTYPESL
    try writeSimpleSingleSymbolPrefix(allocator, writer, 5, 1); // next literal block type
    try writeSimpleSingleSymbolPrefix(allocator, writer, 26, 0); // block count code
    try writer.writeBits(allocator, 0, 2); // first literal block count = 1
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode for block type 0
    try writer.writeBits(allocator, 0, 2); // literal context mode for block type 1
    try writer.writeBits(allocator, 0, 2); // literal context mode for block type 2
    try writeBlockTypeCount(allocator, writer, 3); // NTREESL
    try writeLiteralBlockSwitchThreeTypesContextMap(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'c');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 24);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForLiteralBlockSwitchFiveTypes(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 5); // NBLTYPESL
    try writeSimpleSingleSymbolPrefix(allocator, writer, 7, 1); // next literal block type
    try writeSimpleSingleSymbolPrefix(allocator, writer, 26, 0); // block count code
    try writer.writeBits(allocator, 0, 2); // first literal block count = 1
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode for block type 0
    try writer.writeBits(allocator, 0, 2); // literal context mode for block type 1
    try writer.writeBits(allocator, 0, 2); // literal context mode for block type 2
    try writer.writeBits(allocator, 0, 2); // literal context mode for block type 3
    try writer.writeBits(allocator, 0, 2); // literal context mode for block type 4
    try writeBlockTypeCount(allocator, writer, 5); // NTREESL
    try writeLiteralBlockSwitchFiveTypesContextMap(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'b');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'c');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'd');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'e');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 40);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForLiteralBlockSwitchNineTypes(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 9); // NBLTYPESL
    try writeSimpleSingleSymbolPrefix(allocator, writer, 11, 1); // next literal block type
    try writeSimpleSingleSymbolPrefix(allocator, writer, 26, 0); // block count code
    try writer.writeBits(allocator, 0, 2); // first literal block count = 1
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESD
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 0, 4); // NDIRECT
    for (0..9) |_| {
        try writer.writeBits(allocator, 0, 2); // literal context mode
    }
    try writeBlockTypeCount(allocator, writer, 9); // NTREESL
    try writeLiteralBlockSwitchNineTypesContextMap(allocator, writer);
    try writeBlockTypeCount(allocator, writer, 1); // NTREESD

    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'a');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 0);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 256, 'i');
    try writeSimpleSingleSymbolPrefix(allocator, writer, 704, 56);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 64, 0);
}

fn writeMinimalCompressedHeaderForDistanceBlockSwitch(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 2); // NBLTYPESD
    try writeSimpleSingleSymbolPrefix(allocator, writer, 4, 1); // next distance block type
    try writeSimpleSingleSymbolPrefix(allocator, writer, 26, 0); // block count code
    try writer.writeBits(allocator, 0, 2); // first distance block count = 1
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 3, 4); // NDIRECT = 3
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 2); // NTREESD
    try writeDistanceBlockSwitchContextMap(allocator, writer);

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 2, 2); // NSYM = 3
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));
    try writer.writeBits(allocator, 'c', alphabetBits(256));

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 152, alphabetBits(704));
    try writer.writeBits(allocator, 128, alphabetBits(704));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 18);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 17);
}

fn writeMinimalCompressedHeaderForDistanceBlockSwitchThreeTypes(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 3); // NBLTYPESD
    try writeSimpleSingleSymbolPrefix(allocator, writer, 5, 1); // next distance block type
    try writeSimpleSingleSymbolPrefix(allocator, writer, 26, 0); // block count code
    try writer.writeBits(allocator, 0, 2); // first distance block count = 1
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 3, 4); // NDIRECT = 3
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 3); // NTREESD
    try writeDistanceBlockSwitchThreeTypesContextMap(allocator, writer);

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 2, 2); // NSYM = 3
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));
    try writer.writeBits(allocator, 'c', alphabetBits(256));

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 152, alphabetBits(704));
    try writer.writeBits(allocator, 128, alphabetBits(704));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 18);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 17);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 16);
}

fn writeMinimalCompressedHeaderForDistanceBlockSwitchFiveTypes(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 5); // NBLTYPESD
    try writeSimpleSingleSymbolPrefix(allocator, writer, 7, 1); // next distance block type
    try writeSimpleSingleSymbolPrefix(allocator, writer, 26, 0); // block count code
    try writer.writeBits(allocator, 0, 2); // first distance block count = 1
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 3, 4); // NDIRECT = 3
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 5); // NTREESD
    try writeDistanceBlockSwitchFiveTypesContextMap(allocator, writer);

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 2, 2); // NSYM = 3
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));
    try writer.writeBits(allocator, 'c', alphabetBits(256));

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 152, alphabetBits(704));
    try writer.writeBits(allocator, 128, alphabetBits(704));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 18);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 17);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 18);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 16);
}

fn writeMinimalCompressedHeaderForDistanceBlockSwitchNineTypes(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESL
    try writeBlockTypeCount(allocator, writer, 1); // NBLTYPESI
    try writeBlockTypeCount(allocator, writer, 9); // NBLTYPESD
    try writeSimpleSingleSymbolPrefix(allocator, writer, 11, 1); // next distance block type
    try writeSimpleSingleSymbolPrefix(allocator, writer, 26, 0); // block count code
    try writer.writeBits(allocator, 0, 2); // first distance block count = 1
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX
    try writer.writeBits(allocator, 3, 4); // NDIRECT = 3
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writeBlockTypeCount(allocator, writer, 1); // NTREESL
    try writeBlockTypeCount(allocator, writer, 9); // NTREESD
    try writeDistanceBlockSwitchNineTypesContextMap(allocator, writer);

    try writer.writeBits(allocator, 1, 2); // simple literal prefix
    try writer.writeBits(allocator, 2, 2); // NSYM = 3
    try writer.writeBits(allocator, 'a', alphabetBits(256));
    try writer.writeBits(allocator, 'b', alphabetBits(256));
    try writer.writeBits(allocator, 'c', alphabetBits(256));

    try writer.writeBits(allocator, 1, 2); // simple insert-copy prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 152, alphabetBits(704));
    try writer.writeBits(allocator, 128, alphabetBits(704));

    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 18);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 17);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 18);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 18);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 16);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 18);
    try writeSimpleSingleSymbolPrefix(allocator, writer, 67, 16);
}

fn writeBlockTypeCount(allocator: std.mem.Allocator, writer: *BitWriter, value: u16) Error!void {
    if (value == 0 or value > 256) return error.InvalidBlockPlan;
    if (value == 1) return try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 1, 1);
    if (value == 2) return try writer.writeBits(allocator, 0, 3);
    var selector: u4 = 1;
    while (selector < 8) : (selector += 1) {
        const min = (@as(u16, 1) << selector) + 1;
        const max = min + ((@as(u16, 1) << selector) - 1);
        if (value >= min and value <= max) {
            try writer.writeBits(allocator, selector, 3);
            try writer.writeBits(allocator, value - min, selector);
            return;
        }
    }
    return error.InvalidBlockPlan;
}

fn writeDistanceContextMapForCopyLenThree(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(2));
    try writer.writeBits(allocator, 1, alphabetBits(2));
    try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 1, 1);
    try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeDistanceContextMapForCopyLenThreeComplexPrefix(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 0, 2); // HSKIP = 0, complex context-map prefix
    for (code_length_order) |symbol| {
        try writeCodeLengthCodeLength(allocator, writer, if (symbol == 1) 1 else 0);
    }
    try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 1, 1);
    try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeComplexTwoLiteralPrefix(allocator: std.mem.Allocator, writer: *BitWriter, first: u8, second: u8) Error!void {
    if (first != 'a' or second != 'b') return error.InvalidBlockPlan;
    try writer.writeBits(allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[1] = 1;
    cl_lengths[17] = 1;
    try writeCodeLengthCodeLength(allocator, writer, 1); // symbol 1
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 2
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 3
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 4
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 0
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 5
    try writeCodeLengthCodeLength(allocator, writer, 1); // symbol 17

    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 17);
    try writer.writeBits(allocator, 0, 3); // start chained repeat with 3 zeros.
    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 17);
    try writer.writeBits(allocator, 2, 3); // chained repeat count becomes 13 zeros.
    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 17);
    try writer.writeBits(allocator, 6, 3); // chained repeat count becomes 97 zeros.
    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 1);
    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 1);
}

fn writeComplexCommandPrefixForInsertTwo(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[1] = 1;
    cl_lengths[17] = 1;
    try writeCodeLengthCodeLength(allocator, writer, 1); // symbol 1
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 2
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 3
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 4
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 0
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 5
    try writeCodeLengthCodeLength(allocator, writer, 1); // symbol 17

    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 17);
    try writer.writeBits(allocator, 5, 3); // repeat 8 zeros before command 8.
    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 1);
    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 17);
    try writer.writeBits(allocator, 6, 3); // repeat 9 zeros before command 18.
    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 1);
}

fn writeComplexDistancePrefixForDistanceTwo(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[1] = 1;
    cl_lengths[17] = 1;
    try writeCodeLengthCodeLength(allocator, writer, 1); // symbol 1
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 2
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 3
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 4
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 0
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 5
    try writeCodeLengthCodeLength(allocator, writer, 1); // symbol 17

    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 17);
    try writer.writeBits(allocator, 0, 3); // start chained repeat with 3 zeros.
    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 17);
    try writer.writeBits(allocator, 5, 3); // chained repeat count becomes 16 zeros.
    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 1);
    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 1);
}

fn writeComplexBlockLengthPrefixOne(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 2); // HSKIP = 0, complex code.

    var cl_lengths: [code_length_alphabet_size]u4 = @splat(0);
    cl_lengths[1] = 1;
    cl_lengths[17] = 1;
    try writeCodeLengthCodeLength(allocator, writer, 1); // symbol 1
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 2
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 3
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 4
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 0
    try writeCodeLengthCodeLength(allocator, writer, 0); // symbol 5
    try writeCodeLengthCodeLength(allocator, writer, 1); // symbol 17

    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 1);
    try writeCodeLengthSymbol(allocator, writer, &cl_lengths, 1);
}

fn writeDistanceContextMapForCopyLenThreeFifthTree(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(5));
    try writer.writeBits(allocator, 4, alphabetBits(5));
    try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 1, 1);
    try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeDistanceContextMapForCopyLenThreeNinthTree(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(9));
    try writer.writeBits(allocator, 8, alphabetBits(9));
    try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 1, 1);
    try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 0, 1);
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeLiteralContextMapForA(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(2));
    try writer.writeBits(allocator, 1, alphabetBits(2));
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        try writer.writeBits(allocator, if (i == ('a' & 0x3f)) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeLiteralContextMapForAImtf(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(2));
    try writer.writeBits(allocator, 1, alphabetBits(2));
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        const raw_index: u1 = if (i == ('a' & 0x3f) or i == ('a' & 0x3f) + 1) 1 else 0;
        try writer.writeBits(allocator, raw_index, 1);
    }
    try writer.writeBits(allocator, 1, 1); // IMTF = true
}

fn writeUtf8LiteralContextMapForA(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(2));
    try writer.writeBits(allocator, 1, alphabetBits(2));
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        try writer.writeBits(allocator, if (i == 56) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeUtf8LiteralContextMapForARle(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 1, 1); // use RLE for zeros
    try writer.writeBits(allocator, 5, 4); // RLEMAX = 6
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 2, 2); // NSYM = 3
    try writer.writeBits(allocator, 0, alphabetBits(8));
    try writer.writeBits(allocator, 5, alphabetBits(8));
    try writer.writeBits(allocator, 7, alphabetBits(8));
    try writer.writeBits(allocator, 1, 2); // code 5, length 2: 56-zero run
    try writer.writeBits(allocator, 24, 5);
    try writer.writeBits(allocator, 3, 2); // code 7, length 2: tree index 1 for UTF8 context 56
    for (0..7) |_| {
        try writer.writeBits(allocator, 0, 1); // trailing zero contexts
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeUtf8LiteralContextMapForAComplexPrefix(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 0, 2); // HSKIP = 0, complex context-map prefix
    for (code_length_order) |symbol| {
        try writeCodeLengthCodeLength(allocator, writer, if (symbol == 1) 1 else 0);
    }
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        try writer.writeBits(allocator, if (i == 56) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeUtf8LiteralContextMapForContext63(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(2));
    try writer.writeBits(allocator, 1, alphabetBits(2));
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        try writer.writeBits(allocator, if (i == 63) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeLiteralContextMapForB(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(2));
    try writer.writeBits(allocator, 1, alphabetBits(2));
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        try writer.writeBits(allocator, if (i == ('b' & 0x3f)) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeUtf8LiteralContextMapForFifthTree(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(5));
    try writer.writeBits(allocator, 4, alphabetBits(5));
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        try writer.writeBits(allocator, if (i == 56) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeUtf8LiteralContextMapForNinthTree(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(9));
    try writer.writeBits(allocator, 8, alphabetBits(9));
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        try writer.writeBits(allocator, if (i == 56) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeSignedLiteralContextMapForOneAfterZero(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(2));
    try writer.writeBits(allocator, 1, alphabetBits(2));
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        try writer.writeBits(allocator, if (i == 8) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeLiteralContextMapForAb(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 2, 2); // NSYM = 3
    try writer.writeBits(allocator, 0, alphabetBits(3));
    try writer.writeBits(allocator, 1, alphabetBits(3));
    try writer.writeBits(allocator, 2, alphabetBits(3));
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        const tree_index: u2 = if (i == ('a' & 0x3f)) 1 else if (i == ('b' & 0x3f)) 2 else 0;
        try writeThreeSymbolContextMapCode(allocator, writer, tree_index);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeThreeSymbolContextMapCode(allocator: std.mem.Allocator, writer: *BitWriter, symbol: u2) Error!void {
    switch (symbol) {
        0 => try writer.writeBits(allocator, 0, 1),
        1 => try writer.writeBits(allocator, 1, 2),
        2 => try writer.writeBits(allocator, 3, 2),
        else => return error.InvalidHuffmanCode,
    }
}

fn writeLiteralBlockSwitchContextMap(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(2));
    try writer.writeBits(allocator, 1, alphabetBits(2));
    var i: usize = 0;
    while (i < 128) : (i += 1) {
        try writer.writeBits(allocator, if (i >= 64) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeLiteralBlockSwitchThreeTypesContextMap(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 2, 2); // NSYM = 3
    try writer.writeBits(allocator, 0, alphabetBits(3));
    try writer.writeBits(allocator, 1, alphabetBits(3));
    try writer.writeBits(allocator, 2, alphabetBits(3));
    var i: usize = 0;
    while (i < 192) : (i += 1) {
        const tree_index: u2 = @intCast(i / 64);
        try writeThreeSymbolContextMapCode(allocator, writer, tree_index);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeLiteralBlockSwitchFiveTypesContextMap(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(5));
    try writer.writeBits(allocator, 4, alphabetBits(5));
    var i: usize = 0;
    while (i < 320) : (i += 1) {
        try writer.writeBits(allocator, if (i >= 256) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeLiteralBlockSwitchNineTypesContextMap(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(9));
    try writer.writeBits(allocator, 8, alphabetBits(9));
    var i: usize = 0;
    while (i < 576) : (i += 1) {
        try writer.writeBits(allocator, if (i >= 512) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeDistanceBlockSwitchContextMap(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(2));
    try writer.writeBits(allocator, 1, alphabetBits(2));
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        try writer.writeBits(allocator, if (i == 4) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeDistanceBlockSwitchThreeTypesContextMap(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 2, 2); // NSYM = 3
    try writer.writeBits(allocator, 0, alphabetBits(3));
    try writer.writeBits(allocator, 1, alphabetBits(3));
    try writer.writeBits(allocator, 2, alphabetBits(3));
    var i: usize = 0;
    while (i < 12) : (i += 1) {
        const tree_index: u2 = if (i == 0) 0 else if (i == 4) 1 else if (i == 8) 2 else 0;
        try writeThreeSymbolContextMapCode(allocator, writer, tree_index);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeDistanceBlockSwitchFiveTypesContextMap(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(5));
    try writer.writeBits(allocator, 4, alphabetBits(5));
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        try writer.writeBits(allocator, if (i == 16) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeDistanceBlockSwitchNineTypesContextMap(allocator: std.mem.Allocator, writer: *BitWriter) Error!void {
    try writer.writeBits(allocator, 0, 1); // RLEMAX = 0
    try writer.writeBits(allocator, 1, 2); // simple context-map prefix
    try writer.writeBits(allocator, 1, 2); // NSYM = 2
    try writer.writeBits(allocator, 0, alphabetBits(9));
    try writer.writeBits(allocator, 8, alphabetBits(9));
    var i: usize = 0;
    while (i < 36) : (i += 1) {
        try writer.writeBits(allocator, if (i == 32) 1 else 0, 1);
    }
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeZeroContextMapRle(
    allocator: std.mem.Allocator,
    writer: *BitWriter,
    context_map_size: usize,
    comptime ntrees: u16,
    comptime rlemax: u4,
) Error!void {
    if (ntrees < 2 or rlemax == 0 or rlemax > 16) return error.InvalidBlockPlan;
    if (context_map_size < (@as(usize, 1) << rlemax)) return error.InvalidBlockPlan;
    if (context_map_size >= (@as(usize, 1) << @intCast(@as(usize, rlemax) + 1))) return error.InvalidBlockPlan;
    try writer.writeBits(allocator, 1, 1); // use RLE for zeros
    try writer.writeBits(allocator, rlemax - 1, 4);
    try writeSimpleSingleSymbolPrefix(allocator, writer, @as(usize, ntrees) + rlemax, rlemax);
    try writer.writeBits(allocator, context_map_size - (@as(usize, 1) << rlemax), @intCast(rlemax));
    try writer.writeBits(allocator, 0, 1); // IMTF = false
}

fn writeSimpleSingleSymbolPrefix(
    allocator: std.mem.Allocator,
    writer: *BitWriter,
    comptime alphabet_size: usize,
    symbol: usize,
) Error!void {
    if (symbol >= alphabet_size) return error.InvalidHuffmanCode;
    try writer.writeBits(allocator, 1, 2); // simple prefix code
    try writer.writeBits(allocator, 0, 2); // NSYM = 1
    try writer.writeBits(allocator, symbol, alphabetBits(alphabet_size));
}

fn writeCodeLengthSymbol(
    allocator: std.mem.Allocator,
    writer: *BitWriter,
    lengths: *const [code_length_alphabet_size]u4,
    symbol: usize,
) Error!void {
    const encoder = try huffman.HuffmanTable(code_length_alphabet_size).Encoder.init(lengths);
    try writer.writeBits(allocator, encoder.codes[symbol], encoder.bits[symbol]);
}

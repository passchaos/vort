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
    .{ .transform = 0, .copy_len = 5, .word_index = 0, .word = "first" },
    .{ .transform = 0, .copy_len = 5, .word_index = 1, .word = "video" },
    .{ .transform = 0, .copy_len = 5, .word_index = 2, .word = "light" },
    .{ .transform = 0, .copy_len = 5, .word_index = 3, .word = "world" },
    .{ .transform = 0, .copy_len = 5, .word_index = 4, .word = "media" },
    .{ .transform = 0, .copy_len = 5, .word_index = 5, .word = "white" },
    .{ .transform = 0, .copy_len = 5, .word_index = 6, .word = "close" },
    .{ .transform = 0, .copy_len = 5, .word_index = 7, .word = "black" },
    .{ .transform = 0, .copy_len = 5, .word_index = 8, .word = "right" },
    .{ .transform = 0, .copy_len = 5, .word_index = 9, .word = "small" },
    .{ .transform = 0, .copy_len = 5, .word_index = 10, .word = "books" },
    .{ .transform = 0, .copy_len = 5, .word_index = 11, .word = "place" },
    .{ .transform = 0, .copy_len = 5, .word_index = 12, .word = "music" },
    .{ .transform = 0, .copy_len = 5, .word_index = 13, .word = "field" },
    .{ .transform = 0, .copy_len = 5, .word_index = 14, .word = "order" },
    .{ .transform = 0, .copy_len = 5, .word_index = 16, .word = "value" },
    .{ .transform = 0, .copy_len = 5, .word_index = 17, .word = "level" },
    .{ .transform = 0, .copy_len = 5, .word_index = 18, .word = "table" },
    .{ .transform = 0, .copy_len = 5, .word_index = 19, .word = "board" },
    .{ .transform = 0, .copy_len = 5, .word_index = 20, .word = "house" },
    .{ .transform = 0, .copy_len = 5, .word_index = 21, .word = "group" },
    .{ .transform = 0, .copy_len = 5, .word_index = 23, .word = "years" },
    .{ .transform = 0, .copy_len = 5, .word_index = 26, .word = "water" },
    .{ .transform = 0, .copy_len = 5, .word_index = 27, .word = "start" },
    .{ .transform = 0, .copy_len = 5, .word_index = 28, .word = "style" },
    .{ .transform = 0, .copy_len = 5, .word_index = 29, .word = "death" },
    .{ .transform = 0, .copy_len = 5, .word_index = 30, .word = "power" },
    .{ .transform = 0, .copy_len = 5, .word_index = 31, .word = "phone" },
    .{ .transform = 0, .copy_len = 5, .word_index = 32, .word = "night" },
    .{ .transform = 0, .copy_len = 5, .word_index = 33, .word = "error" },
    .{ .transform = 0, .copy_len = 5, .word_index = 34, .word = "input" },
    .{ .transform = 0, .copy_len = 5, .word_index = 35, .word = "about" },
    .{ .transform = 0, .copy_len = 5, .word_index = 36, .word = "terms" },
    .{ .transform = 0, .copy_len = 5, .word_index = 39, .word = "event" },
    .{ .transform = 0, .copy_len = 5, .word_index = 40, .word = "local" },
    .{ .transform = 0, .copy_len = 5, .word_index = 42, .word = "large" },
    .{ .transform = 0, .copy_len = 5, .word_index = 43, .word = "words" },
    .{ .transform = 0, .copy_len = 5, .word_index = 44, .word = "games" },
    .{ .transform = 0, .copy_len = 5, .word_index = 45, .word = "short" },
    .{ .transform = 0, .copy_len = 5, .word_index = 46, .word = "space" },
    .{ .transform = 0, .copy_len = 5, .word_index = 47, .word = "focus" },
    .{ .transform = 0, .copy_len = 5, .word_index = 48, .word = "clear" },
    .{ .transform = 0, .copy_len = 5, .word_index = 50, .word = "block" },
    .{ .transform = 0, .copy_len = 5, .word_index = 51, .word = "guide" },
    .{ .transform = 0, .copy_len = 5, .word_index = 52, .word = "radio" },
    .{ .transform = 0, .copy_len = 5, .word_index = 53, .word = "share" },
    .{ .transform = 0, .copy_len = 5, .word_index = 54, .word = "women" },
    .{ .transform = 0, .copy_len = 5, .word_index = 55, .word = "again" },
    .{ .transform = 0, .copy_len = 5, .word_index = 56, .word = "money" },
    .{ .transform = 0, .copy_len = 5, .word_index = 81, .word = "press" },
    .{ .transform = 0, .copy_len = 5, .word_index = 101, .word = "other" },
    .{ .transform = 0, .copy_len = 5, .word_index = 107, .word = "quick" },
    .{ .transform = 0, .copy_len = 5, .word_index = 719, .word = "hello" },
    .{ .transform = 0, .copy_len = 5, .word_index = 989, .word = "dolor" },
    .{ .transform = 0, .copy_len = 6, .word_index = 0, .word = "&quot;" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1, .word = "domain" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2, .word = "common" },
    .{ .transform = 0, .copy_len = 6, .word_index = 5, .word = "master" },
    .{ .transform = 0, .copy_len = 6, .word_index = 6, .word = "system" },
    .{ .transform = 0, .copy_len = 6, .word_index = 8, .word = "banner" },
    .{ .transform = 0, .copy_len = 6, .word_index = 9, .word = "remove" },
    .{ .transform = 0, .copy_len = 6, .word_index = 10, .word = "scroll" },
    .{ .transform = 0, .copy_len = 6, .word_index = 11, .word = "update" },
    .{ .transform = 0, .copy_len = 6, .word_index = 12, .word = "global" },
    .{ .transform = 0, .copy_len = 6, .word_index = 14, .word = "filter" },
    .{ .transform = 0, .copy_len = 6, .word_index = 15, .word = "number" },
    .{ .transform = 0, .copy_len = 6, .word_index = 16, .word = "change" },
    .{ .transform = 0, .copy_len = 6, .word_index = 17, .word = "result" },
    .{ .transform = 0, .copy_len = 6, .word_index = 18, .word = "public" },
    .{ .transform = 0, .copy_len = 6, .word_index = 19, .word = "screen" },
    .{ .transform = 0, .copy_len = 6, .word_index = 20, .word = "choose" },
    .{ .transform = 0, .copy_len = 6, .word_index = 21, .word = "normal" },
    .{ .transform = 0, .copy_len = 6, .word_index = 22, .word = "travel" },
    .{ .transform = 0, .copy_len = 6, .word_index = 23, .word = "issues" },
    .{ .transform = 0, .copy_len = 6, .word_index = 25, .word = "target" },
    .{ .transform = 0, .copy_len = 6, .word_index = 26, .word = "spring" },
    .{ .transform = 0, .copy_len = 6, .word_index = 27, .word = "module" },
    .{ .transform = 0, .copy_len = 6, .word_index = 28, .word = "mobile" },
    .{ .transform = 0, .copy_len = 6, .word_index = 29, .word = "switch" },
    .{ .transform = 0, .copy_len = 6, .word_index = 30, .word = "photos" },
    .{ .transform = 0, .copy_len = 6, .word_index = 32, .word = "region" },
    .{ .transform = 0, .copy_len = 6, .word_index = 33, .word = "itself" },
    .{ .transform = 0, .copy_len = 6, .word_index = 34, .word = "social" },
    .{ .transform = 0, .copy_len = 6, .word_index = 35, .word = "active" },
    .{ .transform = 0, .copy_len = 6, .word_index = 36, .word = "column" },
    .{ .transform = 0, .copy_len = 6, .word_index = 37, .word = "record" },
    .{ .transform = 0, .copy_len = 6, .word_index = 38, .word = "follow" },
    .{ .transform = 0, .copy_len = 6, .word_index = 39, .word = "title>" },
    .{ .transform = 0, .copy_len = 6, .word_index = 40, .word = "either" },
    .{ .transform = 0, .copy_len = 6, .word_index = 41, .word = "length" },
    .{ .transform = 0, .copy_len = 6, .word_index = 42, .word = "family" },
    .{ .transform = 0, .copy_len = 6, .word_index = 43, .word = "friend" },
    .{ .transform = 0, .copy_len = 6, .word_index = 44, .word = "layout" },
    .{ .transform = 0, .copy_len = 6, .word_index = 45, .word = "author" },
    .{ .transform = 0, .copy_len = 6, .word_index = 47, .word = "review" },
    .{ .transform = 0, .copy_len = 6, .word_index = 49, .word = "server" },
    .{ .transform = 0, .copy_len = 6, .word_index = 51, .word = "player" },
    .{ .transform = 0, .copy_len = 6, .word_index = 52, .word = "expand" },
    .{ .transform = 0, .copy_len = 6, .word_index = 53, .word = "policy" },
    .{ .transform = 0, .copy_len = 6, .word_index = 55, .word = "double" },
    .{ .transform = 0, .copy_len = 6, .word_index = 57, .word = "series" },
    .{ .transform = 0, .copy_len = 6, .word_index = 58, .word = "person" },
    .{ .transform = 0, .copy_len = 6, .word_index = 59, .word = "living" },
    .{ .transform = 0, .copy_len = 6, .word_index = 60, .word = "design" },
    .{ .transform = 0, .copy_len = 6, .word_index = 63, .word = "unique" },
    .{ .transform = 0, .copy_len = 6, .word_index = 64, .word = "weight" },
    .{ .transform = 0, .copy_len = 6, .word_index = 65, .word = "people" },
    .{ .transform = 0, .copy_len = 6, .word_index = 66, .word = "energy" },
    .{ .transform = 0, .copy_len = 6, .word_index = 67, .word = "nature" },
    .{ .transform = 0, .copy_len = 6, .word_index = 68, .word = "search" },
    .{ .transform = 0, .copy_len = 6, .word_index = 69, .word = "figure" },
    .{ .transform = 0, .copy_len = 6, .word_index = 70, .word = "having" },
    .{ .transform = 0, .copy_len = 6, .word_index = 71, .word = "custom" },
    .{ .transform = 0, .copy_len = 6, .word_index = 72, .word = "offset" },
    .{ .transform = 0, .copy_len = 6, .word_index = 74, .word = "window" },
    .{ .transform = 0, .copy_len = 6, .word_index = 75, .word = "submit" },
    .{ .transform = 0, .copy_len = 6, .word_index = 76, .word = "render" },
    .{ .transform = 0, .copy_len = 6, .word_index = 77, .word = "groups" },
    .{ .transform = 0, .copy_len = 6, .word_index = 78, .word = "upload" },
    .{ .transform = 0, .copy_len = 6, .word_index = 79, .word = "health" },
    .{ .transform = 0, .copy_len = 6, .word_index = 80, .word = "method" },
    .{ .transform = 0, .copy_len = 6, .word_index = 83, .word = "future" },
    .{ .transform = 0, .copy_len = 6, .word_index = 84, .word = "shadow" },
    .{ .transform = 0, .copy_len = 6, .word_index = 85, .word = "debate" },
    .{ .transform = 0, .copy_len = 6, .word_index = 87, .word = "Object" },
    .{ .transform = 0, .copy_len = 6, .word_index = 90, .word = "league" },
    .{ .transform = 0, .copy_len = 6, .word_index = 91, .word = "chrome" },
    .{ .transform = 0, .copy_len = 6, .word_index = 92, .word = "simple" },
    .{ .transform = 0, .copy_len = 6, .word_index = 93, .word = "notice" },
    .{ .transform = 0, .copy_len = 6, .word_index = 95, .word = "ending" },
    .{ .transform = 0, .copy_len = 6, .word_index = 96, .word = "season" },
    .{ .transform = 0, .copy_len = 6, .word_index = 97, .word = "report" },
    .{ .transform = 0, .copy_len = 6, .word_index = 98, .word = "online" },
    .{ .transform = 0, .copy_len = 6, .word_index = 99, .word = "square" },
    .{ .transform = 0, .copy_len = 6, .word_index = 100, .word = "button" },
    .{ .transform = 0, .copy_len = 6, .word_index = 102, .word = "enable" },
    .{ .transform = 0, .copy_len = 6, .word_index = 104, .word = "latest" },
    .{ .transform = 0, .copy_len = 6, .word_index = 107, .word = "period" },
    .{ .transform = 0, .copy_len = 6, .word_index = 109, .word = "repeat" },
    .{ .transform = 0, .copy_len = 6, .word_index = 110, .word = "London" },
    .{ .transform = 0, .copy_len = 6, .word_index = 113, .word = "demand" },
    .{ .transform = 0, .copy_len = 6, .word_index = 114, .word = "secure" },
    .{ .transform = 0, .copy_len = 6, .word_index = 116, .word = "toggle" },
    .{ .transform = 0, .copy_len = 6, .word_index = 118, .word = "device" },
    .{ .transform = 0, .copy_len = 6, .word_index = 119, .word = "static" },
    .{ .transform = 0, .copy_len = 6, .word_index = 120, .word = "cities" },
    .{ .transform = 0, .copy_len = 6, .word_index = 121, .word = "stream" },
    .{ .transform = 0, .copy_len = 6, .word_index = 122, .word = "yellow" },
    .{ .transform = 0, .copy_len = 6, .word_index = 123, .word = "attack" },
    .{ .transform = 0, .copy_len = 6, .word_index = 125, .word = "flight" },
    .{ .transform = 0, .copy_len = 6, .word_index = 126, .word = "hidden" },
    .{ .transform = 0, .copy_len = 6, .word_index = 127, .word = "info\">" },
    .{ .transform = 0, .copy_len = 6, .word_index = 129, .word = "useful" },
    .{ .transform = 0, .copy_len = 6, .word_index = 131, .word = "causes" },
    .{ .transform = 0, .copy_len = 6, .word_index = 132, .word = "leader" },
    .{ .transform = 0, .copy_len = 6, .word_index = 133, .word = "secret" },
    .{ .transform = 0, .copy_len = 6, .word_index = 134, .word = "second" },
    .{ .transform = 0, .copy_len = 6, .word_index = 137, .word = "except" },
    .{ .transform = 0, .copy_len = 6, .word_index = 138, .word = "rating" },
    .{ .transform = 0, .copy_len = 6, .word_index = 141, .word = "effect" },
    .{ .transform = 0, .copy_len = 6, .word_index = 144, .word = "office" },
    .{ .transform = 0, .copy_len = 6, .word_index = 145, .word = "visual" },
    .{ .transform = 0, .copy_len = 6, .word_index = 146, .word = "editor" },
    .{ .transform = 0, .copy_len = 6, .word_index = 147, .word = "volume" },
    .{ .transform = 0, .copy_len = 6, .word_index = 148, .word = "Report" },
    .{ .transform = 0, .copy_len = 6, .word_index = 149, .word = "museum" },
    .{ .transform = 0, .copy_len = 6, .word_index = 151, .word = "parent" },
    .{ .transform = 0, .copy_len = 6, .word_index = 152, .word = "access" },
    .{ .transform = 0, .copy_len = 6, .word_index = 153, .word = "mostly" },
    .{ .transform = 0, .copy_len = 6, .word_index = 155, .word = "\" id=\"" },
    .{ .transform = 0, .copy_len = 6, .word_index = 156, .word = "market" },
    .{ .transform = 0, .copy_len = 6, .word_index = 159, .word = "survey" },
    .{ .transform = 0, .copy_len = 6, .word_index = 160, .word = "before" },
    .{ .transform = 0, .copy_len = 6, .word_index = 161, .word = "symbol" },
    .{ .transform = 0, .copy_len = 6, .word_index = 162, .word = "moment" },
    .{ .transform = 0, .copy_len = 6, .word_index = 164, .word = "motion" },
    .{ .transform = 0, .copy_len = 6, .word_index = 165, .word = "inside" },
    .{ .transform = 0, .copy_len = 6, .word_index = 167, .word = "Center" },
    .{ .transform = 0, .copy_len = 6, .word_index = 168, .word = "object" },
    .{ .transform = 0, .copy_len = 6, .word_index = 169, .word = "exists" },
    .{ .transform = 0, .copy_len = 6, .word_index = 170, .word = "middle" },
    .{ .transform = 0, .copy_len = 6, .word_index = 171, .word = "Europe" },
    .{ .transform = 0, .copy_len = 6, .word_index = 173, .word = "legacy" },
    .{ .transform = 0, .copy_len = 6, .word_index = 174, .word = "manner" },
    .{ .transform = 0, .copy_len = 6, .word_index = 175, .word = "enough" },
    .{ .transform = 0, .copy_len = 6, .word_index = 177, .word = "answer" },
    .{ .transform = 0, .copy_len = 6, .word_index = 178, .word = "origin" },
    .{ .transform = 0, .copy_len = 6, .word_index = 179, .word = "portal" },
    .{ .transform = 0, .copy_len = 6, .word_index = 180, .word = "client" },
    .{ .transform = 0, .copy_len = 6, .word_index = 182, .word = "random" },
    .{ .transform = 0, .copy_len = 6, .word_index = 185, .word = "coming" },
    .{ .transform = 0, .copy_len = 6, .word_index = 186, .word = "father" },
    .{ .transform = 0, .copy_len = 6, .word_index = 189, .word = "raised" },
    .{ .transform = 0, .copy_len = 6, .word_index = 191, .word = "chosen" },
    .{ .transform = 0, .copy_len = 6, .word_index = 192, .word = "church" },
    .{ .transform = 0, .copy_len = 6, .word_index = 193, .word = "define" },
    .{ .transform = 0, .copy_len = 6, .word_index = 195, .word = "corner" },
    .{ .transform = 0, .copy_len = 6, .word_index = 196, .word = "output" },
    .{ .transform = 0, .copy_len = 6, .word_index = 197, .word = "memory" },
    .{ .transform = 0, .copy_len = 6, .word_index = 198, .word = "iframe" },
    .{ .transform = 0, .copy_len = 6, .word_index = 201, .word = "Number" },
    .{ .transform = 0, .copy_len = 6, .word_index = 202, .word = "during" },
    .{ .transform = 0, .copy_len = 6, .word_index = 205, .word = "killed" },
    .{ .transform = 0, .copy_len = 6, .word_index = 208, .word = "silver" },
    .{ .transform = 0, .copy_len = 6, .word_index = 209, .word = "margin" },
    .{ .transform = 0, .copy_len = 6, .word_index = 210, .word = "delete" },
    .{ .transform = 0, .copy_len = 6, .word_index = 214, .word = "Global" },
    .{ .transform = 0, .copy_len = 6, .word_index = 216, .word = "widget" },
    .{ .transform = 0, .copy_len = 6, .word_index = 218, .word = "budget" },
    .{ .transform = 0, .copy_len = 6, .word_index = 219, .word = "nowrap" },
    .{ .transform = 0, .copy_len = 6, .word_index = 220, .word = "credit" },
    .{ .transform = 0, .copy_len = 6, .word_index = 222, .word = "engine" },
    .{ .transform = 0, .copy_len = 6, .word_index = 223, .word = "safety" },
    .{ .transform = 0, .copy_len = 6, .word_index = 225, .word = "spirit" },
    .{ .transform = 0, .copy_len = 6, .word_index = 226, .word = "-style" },
    .{ .transform = 0, .copy_len = 6, .word_index = 227, .word = "spread" },
    .{ .transform = 0, .copy_len = 6, .word_index = 228, .word = "making" },
    .{ .transform = 0, .copy_len = 6, .word_index = 230, .word = "russia" },
    .{ .transform = 0, .copy_len = 6, .word_index = 231, .word = "please" },
    .{ .transform = 0, .copy_len = 6, .word_index = 233, .word = "Script" },
    .{ .transform = 0, .copy_len = 6, .word_index = 234, .word = "broken" },
    .{ .transform = 0, .copy_len = 6, .word_index = 237, .word = "divide" },
    .{ .transform = 0, .copy_len = 6, .word_index = 239, .word = "member" },
    .{ .transform = 0, .copy_len = 6, .word_index = 240, .word = "-based" },
    .{ .transform = 0, .copy_len = 6, .word_index = 241, .word = "theory" },
    .{ .transform = 0, .copy_len = 6, .word_index = 242, .word = "config" },
    .{ .transform = 0, .copy_len = 6, .word_index = 247, .word = "impact" },
    .{ .transform = 0, .copy_len = 6, .word_index = 248, .word = "should" },
    .{ .transform = 0, .copy_len = 6, .word_index = 249, .word = "always" },
    .{ .transform = 0, .copy_len = 6, .word_index = 252, .word = "list\">" },
    .{ .transform = 0, .copy_len = 6, .word_index = 253, .word = "){var " },
    .{ .transform = 0, .copy_len = 6, .word_index = 254, .word = "prefix" },
    .{ .transform = 0, .copy_len = 6, .word_index = 255, .word = "orange" },
    .{ .transform = 0, .copy_len = 6, .word_index = 256, .word = "Header" },
    .{ .transform = 0, .copy_len = 6, .word_index = 257, .word = ".push(" },
    .{ .transform = 0, .copy_len = 6, .word_index = 258, .word = "couple" },
    .{ .transform = 0, .copy_len = 6, .word_index = 259, .word = "garden" },
    .{ .transform = 0, .copy_len = 6, .word_index = 260, .word = "bridge" },
    .{ .transform = 0, .copy_len = 6, .word_index = 261, .word = "launch" },
    .{ .transform = 0, .copy_len = 6, .word_index = 262, .word = "Review" },
    .{ .transform = 0, .copy_len = 6, .word_index = 263, .word = "taking" },
    .{ .transform = 0, .copy_len = 6, .word_index = 265, .word = "little" },
    .{ .transform = 0, .copy_len = 6, .word_index = 266, .word = "dating" },
    .{ .transform = 0, .copy_len = 6, .word_index = 267, .word = "Button" },
    .{ .transform = 0, .copy_len = 6, .word_index = 268, .word = "beauty" },
    .{ .transform = 0, .copy_len = 6, .word_index = 270, .word = "forgot" },
    .{ .transform = 0, .copy_len = 6, .word_index = 272, .word = "anchor" },
    .{ .transform = 0, .copy_len = 6, .word_index = 273, .word = "almost" },
    .{ .transform = 0, .copy_len = 6, .word_index = 275, .word = "Change" },
    .{ .transform = 0, .copy_len = 6, .word_index = 277, .word = "string" },
    .{ .transform = 0, .copy_len = 6, .word_index = 278, .word = "reload" },
    .{ .transform = 0, .copy_len = 6, .word_index = 280, .word = "income" },
    .{ .transform = 0, .copy_len = 6, .word_index = 282, .word = "Source" },
    .{ .transform = 0, .copy_len = 6, .word_index = 286, .word = "course" },
    .{ .transform = 0, .copy_len = 6, .word_index = 288, .word = "island" },
    .{ .transform = 0, .copy_len = 6, .word_index = 289, .word = "<html " },
    .{ .transform = 0, .copy_len = 6, .word_index = 290, .word = "cookie" },
    .{ .transform = 0, .copy_len = 6, .word_index = 292, .word = "amazon" },
    .{ .transform = 0, .copy_len = 6, .word_index = 293, .word = "modern" },
    .{ .transform = 0, .copy_len = 6, .word_index = 294, .word = "advice" },
    .{ .transform = 0, .copy_len = 6, .word_index = 295, .word = "in</a>" },
    .{ .transform = 0, .copy_len = 6, .word_index = 296, .word = ": The " },
    .{ .transform = 0, .copy_len = 6, .word_index = 297, .word = "dialog" },
    .{ .transform = 0, .copy_len = 6, .word_index = 299, .word = "BEGIN " },
    .{ .transform = 0, .copy_len = 6, .word_index = 300, .word = "Mexico" },
    .{ .transform = 0, .copy_len = 6, .word_index = 304, .word = "adding" },
    .{ .transform = 0, .copy_len = 6, .word_index = 306, .word = "assets" },
    .{ .transform = 0, .copy_len = 6, .word_index = 307, .word = "Empire" },
    .{ .transform = 0, .copy_len = 6, .word_index = 308, .word = "School" },
    .{ .transform = 0, .copy_len = 6, .word_index = 309, .word = "effort" },
    .{ .transform = 0, .copy_len = 6, .word_index = 310, .word = "direct" },
    .{ .transform = 0, .copy_len = 6, .word_index = 311, .word = "nearly" },
    .{ .transform = 0, .copy_len = 6, .word_index = 312, .word = "manual" },
    .{ .transform = 0, .copy_len = 6, .word_index = 313, .word = "Select" },
    .{ .transform = 0, .copy_len = 6, .word_index = 314, .word = ".\n\nOne" },
    .{ .transform = 0, .copy_len = 6, .word_index = 318, .word = "awards" },
    .{ .transform = 0, .copy_len = 6, .word_index = 319, .word = "handle" },
    .{ .transform = 0, .copy_len = 6, .word_index = 320, .word = "import" },
    .{ .transform = 0, .copy_len = 6, .word_index = 322, .word = "regard" },
    .{ .transform = 0, .copy_len = 6, .word_index = 323, .word = "skills" },
    .{ .transform = 0, .copy_len = 6, .word_index = 324, .word = "nation" },
    .{ .transform = 0, .copy_len = 6, .word_index = 325, .word = "Sports" },
    .{ .transform = 0, .copy_len = 6, .word_index = 326, .word = "degree" },
    .{ .transform = 0, .copy_len = 6, .word_index = 327, .word = "weekly" },
    .{ .transform = 0, .copy_len = 6, .word_index = 328, .word = " (e.g." },
    .{ .transform = 0, .copy_len = 6, .word_index = 329, .word = "behind" },
    .{ .transform = 0, .copy_len = 6, .word_index = 330, .word = "doctor" },
    .{ .transform = 0, .copy_len = 6, .word_index = 331, .word = "logged" },
    .{ .transform = 0, .copy_len = 6, .word_index = 332, .word = "united" },
    .{ .transform = 0, .copy_len = 6, .word_index = 333, .word = "</b></" },
    .{ .transform = 0, .copy_len = 6, .word_index = 340, .word = "canada" },
    .{ .transform = 0, .copy_len = 6, .word_index = 343, .word = "remain" },
    .{ .transform = 0, .copy_len = 6, .word_index = 344, .word = "Brazil" },
    .{ .transform = 0, .copy_len = 6, .word_index = 345, .word = "sample" },
    .{ .transform = 0, .copy_len = 6, .word_index = 346, .word = "logo\">" },
    .{ .transform = 0, .copy_len = 6, .word_index = 347, .word = "beyond" },
    .{ .transform = 0, .copy_len = 6, .word_index = 348, .word = "-scale" },
    .{ .transform = 0, .copy_len = 6, .word_index = 352, .word = "Footer" },
    .{ .transform = 0, .copy_len = 6, .word_index = 353, .word = "camera" },
    .{ .transform = 0, .copy_len = 6, .word_index = 355, .word = "_form\"" },
    .{ .transform = 0, .copy_len = 6, .word_index = 358, .word = "\" />\r\n" },
    .{ .transform = 0, .copy_len = 6, .word_index = 359, .word = ".gif\" " },
    .{ .transform = 0, .copy_len = 6, .word_index = 360, .word = "onload" },
    .{ .transform = 0, .copy_len = 6, .word_index = 366, .word = "female" },
    .{ .transform = 0, .copy_len = 6, .word_index = 367, .word = "Design" },
    .{ .transform = 0, .copy_len = 6, .word_index = 370, .word = "text\">" },
    .{ .transform = 0, .copy_len = 6, .word_index = 372, .word = "thanks" },
    .{ .transform = 0, .copy_len = 6, .word_index = 377, .word = "Africa" },
    .{ .transform = 0, .copy_len = 6, .word_index = 379, .word = "recent" },
    .{ .transform = 0, .copy_len = 6, .word_index = 380, .word = "People" },
    .{ .transform = 0, .copy_len = 6, .word_index = 381, .word = "<br />" },
    .{ .transform = 0, .copy_len = 6, .word_index = 382, .word = "wonder" },
    .{ .transform = 0, .copy_len = 6, .word_index = 385, .word = "|| {};" },
    .{ .transform = 0, .copy_len = 6, .word_index = 386, .word = "main\">" },
    .{ .transform = 0, .copy_len = 6, .word_index = 387, .word = "inline" },
    .{ .transform = 0, .copy_len = 6, .word_index = 388, .word = "sunday" },
    .{ .transform = 0, .copy_len = 6, .word_index = 389, .word = "wrap\">" },
    .{ .transform = 0, .copy_len = 6, .word_index = 391, .word = "census" },
    .{ .transform = 0, .copy_len = 6, .word_index = 393, .word = "beacon" },
    .{ .transform = 0, .copy_len = 6, .word_index = 395, .word = "150px|" },
    .{ .transform = 0, .copy_len = 6, .word_index = 396, .word = "estate" },
    .{ .transform = 0, .copy_len = 6, .word_index = 398, .word = "email\"" },
    .{ .transform = 0, .copy_len = 6, .word_index = 403, .word = "1.html" },
    .{ .transform = 0, .copy_len = 6, .word_index = 404, .word = "signup" },
    .{ .transform = 0, .copy_len = 6, .word_index = 406, .word = "float:" },
    .{ .transform = 0, .copy_len = 6, .word_index = 408, .word = "forum." },
    .{ .transform = 0, .copy_len = 6, .word_index = 409, .word = "Access" },
    .{ .transform = 0, .copy_len = 6, .word_index = 412, .word = "extend" },
    .{ .transform = 0, .copy_len = 6, .word_index = 413, .word = "Height" },
    .{ .transform = 0, .copy_len = 6, .word_index = 415, .word = "UTF-8\"" },
    .{ .transform = 0, .copy_len = 6, .word_index = 417, .word = "Before" },
    .{ .transform = 0, .copy_len = 6, .word_index = 418, .word = ". With" },
    .{ .transform = 0, .copy_len = 6, .word_index = 419, .word = "studio" },
    .{ .transform = 0, .copy_len = 6, .word_index = 424, .word = "annual" },
    .{ .transform = 0, .copy_len = 6, .word_index = 426, .word = "bought" },
    .{ .transform = 0, .copy_len = 6, .word_index = 428, .word = "google" },
    .{ .transform = 0, .copy_len = 6, .word_index = 430, .word = "i++) {" },
    .{ .transform = 0, .copy_len = 6, .word_index = 431, .word = "israel" },
    .{ .transform = 0, .copy_len = 6, .word_index = 432, .word = "saying" },
    .{ .transform = 0, .copy_len = 6, .word_index = 436, .word = "ensure" },
    .{ .transform = 0, .copy_len = 6, .word_index = 441, .word = "top\"><" },
    .{ .transform = 0, .copy_len = 6, .word_index = 442, .word = "racing" },
    .{ .transform = 0, .copy_len = 6, .word_index = 443, .word = "resize" },
    .{ .transform = 0, .copy_len = 6, .word_index = 444, .word = "--&gt;" },
    .{ .transform = 0, .copy_len = 6, .word_index = 445, .word = "pacity" },
    .{ .transform = 0, .copy_len = 6, .word_index = 447, .word = "bureau" },
    .{ .transform = 0, .copy_len = 6, .word_index = 448, .word = ".jpg\" " },
    .{ .transform = 0, .copy_len = 6, .word_index = 449, .word = "10,000" },
    .{ .transform = 0, .copy_len = 6, .word_index = 450, .word = "obtain" },
    .{ .transform = 0, .copy_len = 6, .word_index = 452, .word = "amount" },
    .{ .transform = 0, .copy_len = 6, .word_index = 453, .word = ", Inc." },
    .{ .transform = 0, .copy_len = 6, .word_index = 454, .word = "comedy" },
    .{ .transform = 0, .copy_len = 6, .word_index = 456, .word = "lyrics" },
    .{ .transform = 0, .copy_len = 6, .word_index = 460, .word = "_logo." },
    .{ .transform = 0, .copy_len = 6, .word_index = 461, .word = "Family" },
    .{ .transform = 0, .copy_len = 6, .word_index = 463, .word = "Market" },
    .{ .transform = 0, .copy_len = 6, .word_index = 464, .word = "lse if" },
    .{ .transform = 0, .copy_len = 6, .word_index = 465, .word = "Player" },
    .{ .transform = 0, .copy_len = 6, .word_index = 466, .word = "turkey" },
    .{ .transform = 0, .copy_len = 6, .word_index = 467, .word = ");var " },
    .{ .transform = 0, .copy_len = 6, .word_index = 471, .word = "Domain" },
    .{ .transform = 0, .copy_len = 6, .word_index = 472, .word = "}else{" },
    .{ .transform = 0, .copy_len = 6, .word_index = 473, .word = "insert" },
    .{ .transform = 0, .copy_len = 6, .word_index = 474, .word = "Blog</" },
    .{ .transform = 0, .copy_len = 6, .word_index = 475, .word = "footer" },
    .{ .transform = 0, .copy_len = 6, .word_index = 477, .word = "faster" },
    .{ .transform = 0, .copy_len = 6, .word_index = 479, .word = "<body " },
    .{ .transform = 0, .copy_len = 6, .word_index = 480, .word = "10px 0" },
    .{ .transform = 0, .copy_len = 6, .word_index = 481, .word = "pragma" },
    .{ .transform = 0, .copy_len = 6, .word_index = 482, .word = "friday" },
    .{ .transform = 0, .copy_len = 6, .word_index = 483, .word = "junior" },
    .{ .transform = 0, .copy_len = 6, .word_index = 484, .word = "dollar" },
    .{ .transform = 0, .copy_len = 6, .word_index = 488, .word = "5,000 " },
    .{ .transform = 0, .copy_len = 6, .word_index = 490, .word = "boston" },
    .{ .transform = 0, .copy_len = 6, .word_index = 491, .word = ".test(" },
    .{ .transform = 0, .copy_len = 6, .word_index = 492, .word = "avatar" },
    .{ .transform = 0, .copy_len = 6, .word_index = 494, .word = "_count" },
    .{ .transform = 0, .copy_len = 6, .word_index = 496, .word = "schema" },
    .{ .transform = 0, .copy_len = 6, .word_index = 498, .word = "filled" },
    .{ .transform = 0, .copy_len = 6, .word_index = 501, .word = "alert(" },
    .{ .transform = 0, .copy_len = 6, .word_index = 502, .word = "appear" },
    .{ .transform = 0, .copy_len = 6, .word_index = 503, .word = "Submit" },
    .{ .transform = 0, .copy_len = 6, .word_index = 504, .word = "line\">" },
    .{ .transform = 0, .copy_len = 6, .word_index = 505, .word = "body\">" },
    .{ .transform = 0, .copy_len = 6, .word_index = 506, .word = "\n* The" },
    .{ .transform = 0, .copy_len = 6, .word_index = 507, .word = "Though" },
    .{ .transform = 0, .copy_len = 6, .word_index = 508, .word = "seeing" },
    .{ .transform = 0, .copy_len = 6, .word_index = 509, .word = "jersey" },
    .{ .transform = 0, .copy_len = 6, .word_index = 511, .word = "verify" },
    .{ .transform = 0, .copy_len = 6, .word_index = 513, .word = "injury" },
    .{ .transform = 0, .copy_len = 6, .word_index = 515, .word = "Cookie" },
    .{ .transform = 0, .copy_len = 6, .word_index = 516, .word = "START " },
    .{ .transform = 0, .copy_len = 6, .word_index = 518, .word = "_image" },
    .{ .transform = 0, .copy_len = 6, .word_index = 519, .word = "thread" },
    .{ .transform = 0, .copy_len = 6, .word_index = 521, .word = "pocket" },
    .{ .transform = 0, .copy_len = 6, .word_index = 524, .word = " David" },
    .{ .transform = 0, .copy_len = 6, .word_index = 525, .word = "cancer" },
    .{ .transform = 0, .copy_len = 6, .word_index = 528, .word = "April " },
    .{ .transform = 0, .copy_len = 6, .word_index = 531, .word = "item\">" },
    .{ .transform = 0, .copy_len = 6, .word_index = 532, .word = "more\">" },
    .{ .transform = 0, .copy_len = 6, .word_index = 539, .word = "guitar" },
    .{ .transform = 0, .copy_len = 6, .word_index = 540, .word = "finish" },
    .{ .transform = 0, .copy_len = 6, .word_index = 545, .word = "assume" },
    .{ .transform = 0, .copy_len = 6, .word_index = 547, .word = "wilson" },
    .{ .transform = 0, .copy_len = 6, .word_index = 549, .word = "relief" },
    .{ .transform = 0, .copy_len = 6, .word_index = 550, .word = "sweden" },
    .{ .transform = 0, .copy_len = 6, .word_index = 551, .word = "Custom" },
    .{ .transform = 0, .copy_len = 6, .word_index = 552, .word = "easily" },
    .{ .transform = 0, .copy_len = 6, .word_index = 553, .word = " your " },
    .{ .transform = 0, .copy_len = 6, .word_index = 555, .word = "\n\nWhil" },
    .{ .transform = 0, .copy_len = 6, .word_index = 556, .word = "taylor" },
    .{ .transform = 0, .copy_len = 6, .word_index = 558, .word = "resort" },
    .{ .transform = 0, .copy_len = 6, .word_index = 559, .word = "french" },
    .{ .transform = 0, .copy_len = 6, .word_index = 560, .word = "though" },
    .{ .transform = 0, .copy_len = 6, .word_index = 561, .word = "\") + \"" },
    .{ .transform = 0, .copy_len = 6, .word_index = 563, .word = "buying" },
    .{ .transform = 0, .copy_len = 6, .word_index = 565, .word = "Member" },
    .{ .transform = 0, .copy_len = 6, .word_index = 567, .word = "opping" },
    .{ .transform = 0, .copy_len = 6, .word_index = 570, .word = "vspace" },
    .{ .transform = 0, .copy_len = 6, .word_index = 573, .word = "coffee" },
    .{ .transform = 0, .copy_len = 6, .word_index = 574, .word = "martin" },
    .{ .transform = 0, .copy_len = 6, .word_index = 575, .word = "mature" },
    .{ .transform = 0, .copy_len = 6, .word_index = 577, .word = "</nav>" },
    .{ .transform = 0, .copy_len = 6, .word_index = 578, .word = "kansas" },
    .{ .transform = 0, .copy_len = 6, .word_index = 579, .word = "link\">" },
    .{ .transform = 0, .copy_len = 6, .word_index = 582, .word = "while " },
    .{ .transform = 0, .copy_len = 6, .word_index = 583, .word = "hspace" },
    .{ .transform = 0, .copy_len = 6, .word_index = 584, .word = "0&amp;" },
    .{ .transform = 0, .copy_len = 6, .word_index = 585, .word = " \n\nIn " },
    .{ .transform = 0, .copy_len = 6, .word_index = 587, .word = "Polski" },
    .{ .transform = 0, .copy_len = 6, .word_index = 588, .word = "-color" },
    .{ .transform = 0, .copy_len = 6, .word_index = 589, .word = "jordan" },
    .{ .transform = 0, .copy_len = 6, .word_index = 590, .word = "Bottom" },
    .{ .transform = 0, .copy_len = 6, .word_index = 591, .word = "Start " },
    .{ .transform = 0, .copy_len = 6, .word_index = 592, .word = "-count" },
    .{ .transform = 0, .copy_len = 6, .word_index = 593, .word = "2.html" },
    .{ .transform = 0, .copy_len = 6, .word_index = 595, .word = "01.jpg" },
    .{ .transform = 0, .copy_len = 6, .word_index = 599, .word = "senior" },
    .{ .transform = 0, .copy_len = 6, .word_index = 604, .word = "ection" },
    .{ .transform = 0, .copy_len = 6, .word_index = 605, .word = "repair" },
    .{ .transform = 0, .copy_len = 6, .word_index = 606, .word = ".xml\" " },
    .{ .transform = 0, .copy_len = 6, .word_index = 607, .word = " right" },
    .{ .transform = 0, .copy_len = 6, .word_index = 608, .word = "s.html" },
    .{ .transform = 0, .copy_len = 6, .word_index = 609, .word = "-block" },
    .{ .transform = 0, .copy_len = 6, .word_index = 610, .word = "regExp" },
    .{ .transform = 0, .copy_len = 6, .word_index = 613, .word = "virgin" },
    .{ .transform = 0, .copy_len = 6, .word_index = 616, .word = "using " },
    .{ .transform = 0, .copy_len = 6, .word_index = 617, .word = "\n\tvar " },
    .{ .transform = 0, .copy_len = 6, .word_index = 618, .word = ">');\n\t" },
    .{ .transform = 0, .copy_len = 6, .word_index = 621, .word = "bahasa" },
    .{ .transform = 0, .copy_len = 6, .word_index = 622, .word = "brasil" },
    .{ .transform = 0, .copy_len = 6, .word_index = 623, .word = "galego" },
    .{ .transform = 0, .copy_len = 6, .word_index = 624, .word = "magyar" },
    .{ .transform = 0, .copy_len = 6, .word_index = 625, .word = "polski" },
    .{ .transform = 0, .copy_len = 6, .word_index = 626, .word = "srpski" },
    .{ .transform = 0, .copy_len = 6, .word_index = 627, .word = "ردو" },
    .{ .transform = 0, .copy_len = 6, .word_index = 628, .word = "中文" },
    .{ .transform = 0, .copy_len = 6, .word_index = 629, .word = "简体" },
    .{ .transform = 0, .copy_len = 6, .word_index = 630, .word = "繁體" },
    .{ .transform = 0, .copy_len = 6, .word_index = 631, .word = "信息" },
    .{ .transform = 0, .copy_len = 6, .word_index = 633, .word = "我们" },
    .{ .transform = 0, .copy_len = 6, .word_index = 634, .word = "一个" },
    .{ .transform = 0, .copy_len = 6, .word_index = 635, .word = "公司" },
    .{ .transform = 0, .copy_len = 6, .word_index = 636, .word = "管理" },
    .{ .transform = 0, .copy_len = 6, .word_index = 637, .word = "论坛" },
    .{ .transform = 0, .copy_len = 6, .word_index = 640, .word = "时间" },
    .{ .transform = 0, .copy_len = 6, .word_index = 641, .word = "个人" },
    .{ .transform = 0, .copy_len = 6, .word_index = 642, .word = "产品" },
    .{ .transform = 0, .copy_len = 6, .word_index = 643, .word = "自己" },
    .{ .transform = 0, .copy_len = 6, .word_index = 644, .word = "企业" },
    .{ .transform = 0, .copy_len = 6, .word_index = 645, .word = "查看" },
    .{ .transform = 0, .copy_len = 6, .word_index = 646, .word = "工作" },
    .{ .transform = 0, .copy_len = 6, .word_index = 647, .word = "联系" },
    .{ .transform = 0, .copy_len = 6, .word_index = 648, .word = "没有" },
    .{ .transform = 0, .copy_len = 6, .word_index = 649, .word = "网站" },
    .{ .transform = 0, .copy_len = 6, .word_index = 650, .word = "所有" },
    .{ .transform = 0, .copy_len = 6, .word_index = 652, .word = "中心" },
    .{ .transform = 0, .copy_len = 6, .word_index = 653, .word = "文章" },
    .{ .transform = 0, .copy_len = 6, .word_index = 654, .word = "用户" },
    .{ .transform = 0, .copy_len = 6, .word_index = 656, .word = "作者" },
    .{ .transform = 0, .copy_len = 6, .word_index = 658, .word = "问题" },
    .{ .transform = 0, .copy_len = 6, .word_index = 659, .word = "相关" },
    .{ .transform = 0, .copy_len = 6, .word_index = 660, .word = "下载" },
    .{ .transform = 0, .copy_len = 6, .word_index = 662, .word = "使用" },
    .{ .transform = 0, .copy_len = 6, .word_index = 664, .word = "在线" },
    .{ .transform = 0, .copy_len = 6, .word_index = 666, .word = "资料" },
    .{ .transform = 0, .copy_len = 6, .word_index = 667, .word = "视频" },
    .{ .transform = 0, .copy_len = 6, .word_index = 671, .word = "收藏" },
    .{ .transform = 0, .copy_len = 6, .word_index = 672, .word = "内容" },
    .{ .transform = 0, .copy_len = 6, .word_index = 674, .word = "市场" },
    .{ .transform = 0, .copy_len = 6, .word_index = 676, .word = "空间" },
    .{ .transform = 0, .copy_len = 6, .word_index = 677, .word = "发布" },
    .{ .transform = 0, .copy_len = 6, .word_index = 678, .word = "什么" },
    .{ .transform = 0, .copy_len = 6, .word_index = 679, .word = "好友" },
    .{ .transform = 0, .copy_len = 6, .word_index = 680, .word = "生活" },
    .{ .transform = 0, .copy_len = 6, .word_index = 681, .word = "图片" },
    .{ .transform = 0, .copy_len = 6, .word_index = 684, .word = "手机" },
    .{ .transform = 0, .copy_len = 6, .word_index = 685, .word = "新闻" },
    .{ .transform = 0, .copy_len = 6, .word_index = 686, .word = "最新" },
    .{ .transform = 0, .copy_len = 6, .word_index = 687, .word = "方式" },
    .{ .transform = 0, .copy_len = 6, .word_index = 688, .word = "北京" },
    .{ .transform = 0, .copy_len = 6, .word_index = 689, .word = "提供" },
    .{ .transform = 0, .copy_len = 6, .word_index = 690, .word = "关于" },
    .{ .transform = 0, .copy_len = 6, .word_index = 691, .word = "更多" },
    .{ .transform = 0, .copy_len = 6, .word_index = 692, .word = "这个" },
    .{ .transform = 0, .copy_len = 6, .word_index = 695, .word = "游戏" },
    .{ .transform = 0, .copy_len = 6, .word_index = 696, .word = "广告" },
    .{ .transform = 0, .copy_len = 6, .word_index = 697, .word = "其他" },
    .{ .transform = 0, .copy_len = 6, .word_index = 698, .word = "发表" },
    .{ .transform = 0, .copy_len = 6, .word_index = 699, .word = "安全" },
    .{ .transform = 0, .copy_len = 6, .word_index = 700, .word = "第一" },
    .{ .transform = 0, .copy_len = 6, .word_index = 702, .word = "进行" },
    .{ .transform = 0, .copy_len = 6, .word_index = 703, .word = "点击" },
    .{ .transform = 0, .copy_len = 6, .word_index = 704, .word = "版权" },
    .{ .transform = 0, .copy_len = 6, .word_index = 708, .word = "免费" },
    .{ .transform = 0, .copy_len = 6, .word_index = 709, .word = "教育" },
    .{ .transform = 0, .copy_len = 6, .word_index = 710, .word = "加入" },
    .{ .transform = 0, .copy_len = 6, .word_index = 711, .word = "活动" },
    .{ .transform = 0, .copy_len = 6, .word_index = 712, .word = "他们" },
    .{ .transform = 0, .copy_len = 6, .word_index = 713, .word = "商品" },
    .{ .transform = 0, .copy_len = 6, .word_index = 714, .word = "博客" },
    .{ .transform = 0, .copy_len = 6, .word_index = 715, .word = "现在" },
    .{ .transform = 0, .copy_len = 6, .word_index = 716, .word = "上海" },
    .{ .transform = 0, .copy_len = 6, .word_index = 718, .word = "已经" },
    .{ .transform = 0, .copy_len = 6, .word_index = 720, .word = "详细" },
    .{ .transform = 0, .copy_len = 6, .word_index = 721, .word = "社区" },
    .{ .transform = 0, .copy_len = 6, .word_index = 723, .word = "本站" },
    .{ .transform = 0, .copy_len = 6, .word_index = 724, .word = "需要" },
    .{ .transform = 0, .copy_len = 6, .word_index = 727, .word = "国际" },
    .{ .transform = 0, .copy_len = 6, .word_index = 728, .word = "链接" },
    .{ .transform = 0, .copy_len = 6, .word_index = 729, .word = "国家" },
    .{ .transform = 0, .copy_len = 6, .word_index = 730, .word = "建设" },
    .{ .transform = 0, .copy_len = 6, .word_index = 731, .word = "朋友" },
    .{ .transform = 0, .copy_len = 6, .word_index = 733, .word = "法律" },
    .{ .transform = 0, .copy_len = 6, .word_index = 734, .word = "位置" },
    .{ .transform = 0, .copy_len = 6, .word_index = 735, .word = "经济" },
    .{ .transform = 0, .copy_len = 6, .word_index = 736, .word = "选择" },
    .{ .transform = 0, .copy_len = 6, .word_index = 737, .word = "这样" },
    .{ .transform = 0, .copy_len = 6, .word_index = 738, .word = "当前" },
    .{ .transform = 0, .copy_len = 6, .word_index = 740, .word = "排行" },
    .{ .transform = 0, .copy_len = 6, .word_index = 741, .word = "因为" },
    .{ .transform = 0, .copy_len = 6, .word_index = 744, .word = "音乐" },
    .{ .transform = 0, .copy_len = 6, .word_index = 747, .word = "行业" },
    .{ .transform = 0, .copy_len = 6, .word_index = 748, .word = "科技" },
    .{ .transform = 0, .copy_len = 6, .word_index = 749, .word = "可能" },
    .{ .transform = 0, .copy_len = 6, .word_index = 751, .word = "合作" },
    .{ .transform = 0, .copy_len = 6, .word_index = 753, .word = "社会" },
    .{ .transform = 0, .copy_len = 6, .word_index = 754, .word = "研究" },
    .{ .transform = 0, .copy_len = 6, .word_index = 755, .word = "专业" },
    .{ .transform = 0, .copy_len = 6, .word_index = 756, .word = "全部" },
    .{ .transform = 0, .copy_len = 6, .word_index = 757, .word = "项目" },
    .{ .transform = 0, .copy_len = 6, .word_index = 758, .word = "这里" },
    .{ .transform = 0, .copy_len = 6, .word_index = 759, .word = "还是" },
    .{ .transform = 0, .copy_len = 6, .word_index = 761, .word = "情况" },
    .{ .transform = 0, .copy_len = 6, .word_index = 762, .word = "电脑" },
    .{ .transform = 0, .copy_len = 6, .word_index = 763, .word = "文件" },
    .{ .transform = 0, .copy_len = 6, .word_index = 764, .word = "品牌" },
    .{ .transform = 0, .copy_len = 6, .word_index = 765, .word = "帮助" },
    .{ .transform = 0, .copy_len = 6, .word_index = 769, .word = "学习" },
    .{ .transform = 0, .copy_len = 6, .word_index = 770, .word = "地址" },
    .{ .transform = 0, .copy_len = 6, .word_index = 771, .word = "浏览" },
    .{ .transform = 0, .copy_len = 6, .word_index = 772, .word = "投资" },
    .{ .transform = 0, .copy_len = 6, .word_index = 773, .word = "工程" },
    .{ .transform = 0, .copy_len = 6, .word_index = 774, .word = "要求" },
    .{ .transform = 0, .copy_len = 6, .word_index = 775, .word = "怎么" },
    .{ .transform = 0, .copy_len = 6, .word_index = 777, .word = "功能" },
    .{ .transform = 0, .copy_len = 6, .word_index = 778, .word = "主要" },
    .{ .transform = 0, .copy_len = 6, .word_index = 779, .word = "目前" },
    .{ .transform = 0, .copy_len = 6, .word_index = 781, .word = "城市" },
    .{ .transform = 0, .copy_len = 6, .word_index = 784, .word = "招聘" },
    .{ .transform = 0, .copy_len = 6, .word_index = 785, .word = "声明" },
    .{ .transform = 0, .copy_len = 6, .word_index = 786, .word = "任何" },
    .{ .transform = 0, .copy_len = 6, .word_index = 787, .word = "健康" },
    .{ .transform = 0, .copy_len = 6, .word_index = 788, .word = "数据" },
    .{ .transform = 0, .copy_len = 6, .word_index = 790, .word = "汽车" },
    .{ .transform = 0, .copy_len = 6, .word_index = 791, .word = "介绍" },
    .{ .transform = 0, .copy_len = 6, .word_index = 792, .word = "但是" },
    .{ .transform = 0, .copy_len = 6, .word_index = 794, .word = "生产" },
    .{ .transform = 0, .copy_len = 6, .word_index = 795, .word = "所以" },
    .{ .transform = 0, .copy_len = 6, .word_index = 797, .word = "显示" },
    .{ .transform = 0, .copy_len = 6, .word_index = 799, .word = "单位" },
    .{ .transform = 0, .copy_len = 6, .word_index = 801, .word = "分析" },
    .{ .transform = 0, .copy_len = 6, .word_index = 803, .word = "旅游" },
    .{ .transform = 0, .copy_len = 6, .word_index = 804, .word = "工具" },
    .{ .transform = 0, .copy_len = 6, .word_index = 805, .word = "学生" },
    .{ .transform = 0, .copy_len = 6, .word_index = 806, .word = "系列" },
    .{ .transform = 0, .copy_len = 6, .word_index = 807, .word = "网友" },
    .{ .transform = 0, .copy_len = 6, .word_index = 810, .word = "频道" },
    .{ .transform = 0, .copy_len = 6, .word_index = 815, .word = "网上" },
    .{ .transform = 0, .copy_len = 6, .word_index = 818, .word = "喜欢" },
    .{ .transform = 0, .copy_len = 6, .word_index = 819, .word = "进入" },
    .{ .transform = 0, .copy_len = 6, .word_index = 820, .word = "友情" },
    .{ .transform = 0, .copy_len = 6, .word_index = 823, .word = "发现" },
    .{ .transform = 0, .copy_len = 6, .word_index = 824, .word = "培训" },
    .{ .transform = 0, .copy_len = 6, .word_index = 825, .word = "以上" },
    .{ .transform = 0, .copy_len = 6, .word_index = 826, .word = "政府" },
    .{ .transform = 0, .copy_len = 6, .word_index = 827, .word = "成为" },
    .{ .transform = 0, .copy_len = 6, .word_index = 828, .word = "环境" },
    .{ .transform = 0, .copy_len = 6, .word_index = 830, .word = "同时" },
    .{ .transform = 0, .copy_len = 6, .word_index = 831, .word = "娱乐" },
    .{ .transform = 0, .copy_len = 6, .word_index = 832, .word = "发送" },
    .{ .transform = 0, .copy_len = 6, .word_index = 833, .word = "一定" },
    .{ .transform = 0, .copy_len = 6, .word_index = 834, .word = "开发" },
    .{ .transform = 0, .copy_len = 6, .word_index = 835, .word = "作品" },
    .{ .transform = 0, .copy_len = 6, .word_index = 836, .word = "标准" },
    .{ .transform = 0, .copy_len = 6, .word_index = 837, .word = "欢迎" },
    .{ .transform = 0, .copy_len = 6, .word_index = 839, .word = "地方" },
    .{ .transform = 0, .copy_len = 6, .word_index = 841, .word = "以及" },
    .{ .transform = 0, .copy_len = 6, .word_index = 843, .word = "或者" },
    .{ .transform = 0, .copy_len = 6, .word_index = 846, .word = "积分" },
    .{ .transform = 0, .copy_len = 6, .word_index = 847, .word = "女人" },
    .{ .transform = 0, .copy_len = 6, .word_index = 848, .word = "数码" },
    .{ .transform = 0, .copy_len = 6, .word_index = 849, .word = "销售" },
    .{ .transform = 0, .copy_len = 6, .word_index = 851, .word = "离线" },
    .{ .transform = 0, .copy_len = 6, .word_index = 853, .word = "列表" },
    .{ .transform = 0, .copy_len = 6, .word_index = 855, .word = "编辑" },
    .{ .transform = 0, .copy_len = 6, .word_index = 856, .word = "统计" },
    .{ .transform = 0, .copy_len = 6, .word_index = 857, .word = "查询" },
    .{ .transform = 0, .copy_len = 6, .word_index = 858, .word = "不要" },
    .{ .transform = 0, .copy_len = 6, .word_index = 859, .word = "有关" },
    .{ .transform = 0, .copy_len = 6, .word_index = 860, .word = "机构" },
    .{ .transform = 0, .copy_len = 6, .word_index = 861, .word = "很多" },
    .{ .transform = 0, .copy_len = 6, .word_index = 862, .word = "播放" },
    .{ .transform = 0, .copy_len = 6, .word_index = 863, .word = "组织" },
    .{ .transform = 0, .copy_len = 6, .word_index = 864, .word = "政策" },
    .{ .transform = 0, .copy_len = 6, .word_index = 865, .word = "直接" },
    .{ .transform = 0, .copy_len = 6, .word_index = 866, .word = "能力" },
    .{ .transform = 0, .copy_len = 6, .word_index = 867, .word = "来源" },
    .{ .transform = 0, .copy_len = 6, .word_index = 868, .word = "時間" },
    .{ .transform = 0, .copy_len = 6, .word_index = 869, .word = "看到" },
    .{ .transform = 0, .copy_len = 6, .word_index = 870, .word = "热门" },
    .{ .transform = 0, .copy_len = 6, .word_index = 871, .word = "关键" },
    .{ .transform = 0, .copy_len = 6, .word_index = 872, .word = "专区" },
    .{ .transform = 0, .copy_len = 6, .word_index = 873, .word = "非常" },
    .{ .transform = 0, .copy_len = 6, .word_index = 874, .word = "英语" },
    .{ .transform = 0, .copy_len = 6, .word_index = 878, .word = "比较" },
    .{ .transform = 0, .copy_len = 6, .word_index = 879, .word = "知识" },
    .{ .transform = 0, .copy_len = 6, .word_index = 880, .word = "规定" },
    .{ .transform = 0, .copy_len = 6, .word_index = 882, .word = "部门" },
    .{ .transform = 0, .copy_len = 6, .word_index = 883, .word = "意见" },
    .{ .transform = 0, .copy_len = 6, .word_index = 885, .word = "日本" },
    .{ .transform = 0, .copy_len = 6, .word_index = 886, .word = "提高" },
    .{ .transform = 0, .copy_len = 6, .word_index = 888, .word = "方面" },
    .{ .transform = 0, .copy_len = 6, .word_index = 890, .word = "处理" },
    .{ .transform = 0, .copy_len = 6, .word_index = 892, .word = "影片" },
    .{ .transform = 0, .copy_len = 6, .word_index = 893, .word = "银行" },
    .{ .transform = 0, .copy_len = 6, .word_index = 895, .word = "分享" },
    .{ .transform = 0, .copy_len = 6, .word_index = 896, .word = "物品" },
    .{ .transform = 0, .copy_len = 6, .word_index = 897, .word = "经营" },
    .{ .transform = 0, .copy_len = 6, .word_index = 898, .word = "添加" },
    .{ .transform = 0, .copy_len = 6, .word_index = 900, .word = "这种" },
    .{ .transform = 0, .copy_len = 6, .word_index = 901, .word = "话题" },
    .{ .transform = 0, .copy_len = 6, .word_index = 902, .word = "起来" },
    .{ .transform = 0, .copy_len = 6, .word_index = 903, .word = "业务" },
    .{ .transform = 0, .copy_len = 6, .word_index = 905, .word = "记录" },
    .{ .transform = 0, .copy_len = 6, .word_index = 907, .word = "质量" },
    .{ .transform = 0, .copy_len = 6, .word_index = 908, .word = "男人" },
    .{ .transform = 0, .copy_len = 6, .word_index = 910, .word = "引用" },
    .{ .transform = 0, .copy_len = 6, .word_index = 911, .word = "报告" },
    .{ .transform = 0, .copy_len = 6, .word_index = 913, .word = "快速" },
    .{ .transform = 0, .copy_len = 6, .word_index = 914, .word = "咨询" },
    .{ .transform = 0, .copy_len = 6, .word_index = 916, .word = "注意" },
    .{ .transform = 0, .copy_len = 6, .word_index = 917, .word = "申请" },
    .{ .transform = 0, .copy_len = 6, .word_index = 918, .word = "学校" },
    .{ .transform = 0, .copy_len = 6, .word_index = 919, .word = "应该" },
    .{ .transform = 0, .copy_len = 6, .word_index = 920, .word = "历史" },
    .{ .transform = 0, .copy_len = 6, .word_index = 921, .word = "只是" },
    .{ .transform = 0, .copy_len = 6, .word_index = 922, .word = "返回" },
    .{ .transform = 0, .copy_len = 6, .word_index = 923, .word = "购买" },
    .{ .transform = 0, .copy_len = 6, .word_index = 924, .word = "名称" },
    .{ .transform = 0, .copy_len = 6, .word_index = 925, .word = "为了" },
    .{ .transform = 0, .copy_len = 6, .word_index = 926, .word = "成功" },
    .{ .transform = 0, .copy_len = 6, .word_index = 928, .word = "供应" },
    .{ .transform = 0, .copy_len = 6, .word_index = 929, .word = "孩子" },
    .{ .transform = 0, .copy_len = 6, .word_index = 930, .word = "专题" },
    .{ .transform = 0, .copy_len = 6, .word_index = 933, .word = "會員" },
    .{ .transform = 0, .copy_len = 6, .word_index = 935, .word = "其它" },
    .{ .transform = 0, .copy_len = 6, .word_index = 936, .word = "保护" },
    .{ .transform = 0, .copy_len = 6, .word_index = 937, .word = "而且" },
    .{ .transform = 0, .copy_len = 6, .word_index = 938, .word = "今天" },
    .{ .transform = 0, .copy_len = 6, .word_index = 939, .word = "窗口" },
    .{ .transform = 0, .copy_len = 6, .word_index = 940, .word = "动态" },
    .{ .transform = 0, .copy_len = 6, .word_index = 941, .word = "状态" },
    .{ .transform = 0, .copy_len = 6, .word_index = 942, .word = "特别" },
    .{ .transform = 0, .copy_len = 6, .word_index = 943, .word = "认为" },
    .{ .transform = 0, .copy_len = 6, .word_index = 944, .word = "必须" },
    .{ .transform = 0, .copy_len = 6, .word_index = 945, .word = "更新" },
    .{ .transform = 0, .copy_len = 6, .word_index = 946, .word = "小说" },
    .{ .transform = 0, .copy_len = 6, .word_index = 947, .word = "我們" },
    .{ .transform = 0, .copy_len = 6, .word_index = 948, .word = "作为" },
    .{ .transform = 0, .copy_len = 6, .word_index = 949, .word = "媒体" },
    .{ .transform = 0, .copy_len = 6, .word_index = 950, .word = "包括" },
    .{ .transform = 0, .copy_len = 6, .word_index = 952, .word = "一样" },
    .{ .transform = 0, .copy_len = 6, .word_index = 954, .word = "是否" },
    .{ .transform = 0, .copy_len = 6, .word_index = 957, .word = "学院" },
    .{ .transform = 0, .copy_len = 6, .word_index = 958, .word = "具有" },
    .{ .transform = 0, .copy_len = 6, .word_index = 959, .word = "过程" },
    .{ .transform = 0, .copy_len = 6, .word_index = 960, .word = "由于" },
    .{ .transform = 0, .copy_len = 6, .word_index = 962, .word = "出来" },
    .{ .transform = 0, .copy_len = 6, .word_index = 965, .word = "明星" },
    .{ .transform = 0, .copy_len = 6, .word_index = 966, .word = "故事" },
    .{ .transform = 0, .copy_len = 6, .word_index = 967, .word = "关系" },
    .{ .transform = 0, .copy_len = 6, .word_index = 968, .word = "标题" },
    .{ .transform = 0, .copy_len = 6, .word_index = 973, .word = "教学" },
    .{ .transform = 0, .copy_len = 6, .word_index = 974, .word = "了解" },
    .{ .transform = 0, .copy_len = 6, .word_index = 975, .word = "建筑" },
    .{ .transform = 0, .copy_len = 6, .word_index = 977, .word = "全球" },
    .{ .transform = 0, .copy_len = 6, .word_index = 978, .word = "通知" },
    .{ .transform = 0, .copy_len = 6, .word_index = 979, .word = "计划" },
    .{ .transform = 0, .copy_len = 6, .word_index = 980, .word = "对于" },
    .{ .transform = 0, .copy_len = 6, .word_index = 981, .word = "艺术" },
    .{ .transform = 0, .copy_len = 6, .word_index = 984, .word = "真的" },
    .{ .transform = 0, .copy_len = 6, .word_index = 988, .word = "经验" },
    .{ .transform = 0, .copy_len = 6, .word_index = 990, .word = "制作" },
    .{ .transform = 0, .copy_len = 6, .word_index = 991, .word = "来自" },
    .{ .transform = 0, .copy_len = 6, .word_index = 992, .word = "标签" },
    .{ .transform = 0, .copy_len = 6, .word_index = 995, .word = "无法" },
    .{ .transform = 0, .copy_len = 6, .word_index = 997, .word = "個人" },
    .{ .transform = 0, .copy_len = 6, .word_index = 999, .word = "指南" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1001, .word = "集团" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1003, .word = "关注" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1004, .word = "因此" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1005, .word = "照片" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1007, .word = "商业" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1011, .word = "最近" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1012, .word = "综合" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1013, .word = "表示" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1014, .word = "专辑" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1016, .word = "交通" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1017, .word = "评价" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1018, .word = "觉得" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1022, .word = "感觉" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1024, .word = "得到" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1025, .word = "邮件" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1027, .word = "食品" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1028, .word = "虽然" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1029, .word = "转载" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1030, .word = "报价" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1031, .word = "记者" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1033, .word = "行政" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1034, .word = "人民" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1035, .word = "用品" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1036, .word = "东西" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1037, .word = "提出" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1038, .word = "酒店" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1040, .word = "付款" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1043, .word = "完全" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1045, .word = "设置" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1048, .word = "医院" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1049, .word = "看看" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1050, .word = "经典" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1052, .word = "平台" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1054, .word = "增加" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1055, .word = "材料" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1056, .word = "新增" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1057, .word = "之后" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1058, .word = "职业" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1059, .word = "效果" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1061, .word = "论文" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1064, .word = "版主" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1065, .word = "修改" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1066, .word = "参与" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1068, .word = "快乐" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1070, .word = "观点" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1071, .word = "存在" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1072, .word = "精神" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1073, .word = "获得" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1074, .word = "利用" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1075, .word = "继续" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1078, .word = "模式" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1079, .word = "语言" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1081, .word = "雅虎" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1082, .word = "操作" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1083, .word = "风格" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1085, .word = "科学" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1086, .word = "体育" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1087, .word = "短信" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1088, .word = "条件" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1089, .word = "治疗" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1090, .word = "运动" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1091, .word = "产业" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1093, .word = "导航" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1094, .word = "先生" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1096, .word = "可是" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1097, .word = "問題" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1098, .word = "结构" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1099, .word = "作用" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1100, .word = "调查" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1101, .word = "資料" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1103, .word = "负责" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1105, .word = "访问" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1107, .word = "接受" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1108, .word = "讨论" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1110, .word = "反馈" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1113, .word = "范围" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1114, .word = "服務" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1115, .word = "休闲" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1116, .word = "今日" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1117, .word = "客服" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1118, .word = "觀看" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1119, .word = "参加" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1123, .word = "图书" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1125, .word = "测试" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1127, .word = "才能" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1128, .word = "决定" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1129, .word = "股票" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1130, .word = "不断" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1131, .word = "需求" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1133, .word = "办法" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1135, .word = "采用" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1136, .word = "营销" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1138, .word = "目标" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1139, .word = "爱情" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1140, .word = "摄影" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1142, .word = "複製" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1144, .word = "机会" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1145, .word = "数字" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1146, .word = "装修" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1148, .word = "农村" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1150, .word = "精品" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1152, .word = "事情" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1154, .word = "提示" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1155, .word = "上市" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1157, .word = "普通" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1159, .word = "上传" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1160, .word = "类别" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1162, .word = "拥有" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1163, .word = "创新" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1164, .word = "配件" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1166, .word = "时代" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1167, .word = "資訊" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1168, .word = "达到" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1169, .word = "人生" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1170, .word = "订阅" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1171, .word = "老师" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1172, .word = "展示" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1173, .word = "心理" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1174, .word = "贴子" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1175, .word = "網站" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1179, .word = "简单" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1185, .word = "删除" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1186, .word = "证券" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1187, .word = "节目" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1188, .word = "重点" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1189, .word = "次數" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1190, .word = "多少" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1193, .word = "找到" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1197, .word = "最佳" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1198, .word = "回答" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1199, .word = "天下" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1201, .word = "现代" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1202, .word = "检查" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1203, .word = "投票" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1204, .word = "小时" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1205, .word = "沒有" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1206, .word = "正常" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1207, .word = "甚至" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1208, .word = "代理" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1211, .word = "复制" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1212, .word = "金融" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1213, .word = "幸福" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1216, .word = "准备" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1218, .word = "回到" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1219, .word = "思想" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1220, .word = "怎样" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1221, .word = "协议" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1222, .word = "认证" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1223, .word = "最好" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1224, .word = "产生" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1225, .word = "按照" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1226, .word = "服装" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1227, .word = "广东" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1229, .word = "采购" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1231, .word = "组图" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1232, .word = "面板" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1233, .word = "参考" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1234, .word = "政治" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1235, .word = "容易" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1236, .word = "天地" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1237, .word = "努力" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1239, .word = "升级" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1243, .word = "流行" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1244, .word = "造成" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1245, .word = "文字" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1246, .word = "韩国" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1247, .word = "贸易" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1249, .word = "相關" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1251, .word = "影视" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1254, .word = "大小" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1255, .word = "报道" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1256, .word = "条款" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1258, .word = "许多" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1261, .word = "书店" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1262, .word = "连接" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1263, .word = "立即" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1264, .word = "举报" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1265, .word = "技巧" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1267, .word = "登入" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1268, .word = "以来" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1269, .word = "理论" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1270, .word = "事件" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1271, .word = "自由" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1273, .word = "办公" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1275, .word = "真正" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1276, .word = "不错" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1277, .word = "全文" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1278, .word = "合同" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1279, .word = "价值" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1280, .word = "别人" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1281, .word = "监督" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1282, .word = "具体" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1284, .word = "团队" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1285, .word = "创业" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1286, .word = "承担" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1287, .word = "增长" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1294, .word = "股份" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1296, .word = "实际" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1298, .word = "经理" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1299, .word = "生命" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1300, .word = "宣传" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1301, .word = "任务" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1303, .word = "特色" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1306, .word = "只能" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1308, .word = "重新" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1309, .word = "內容" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1311, .word = "运行" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1312, .word = "日志" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1313, .word = "賣家" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1314, .word = "超过" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1315, .word = "土地" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1317, .word = "支付" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1320, .word = "杭州" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1321, .word = "执行" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1322, .word = "制造" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1323, .word = "之一" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1324, .word = "推广" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1326, .word = "描述" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1327, .word = "变化" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1330, .word = "保险" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1332, .word = "医疗" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1334, .word = "过去" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1336, .word = "收入" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1338, .word = "杂志" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1339, .word = "美丽" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1340, .word = "最高" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1341, .word = "登陆" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1342, .word = "未来" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1345, .word = "教程" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1346, .word = "版块" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1348, .word = "重庆" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1349, .word = "出售" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1350, .word = "成本" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1351, .word = "形式" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1352, .word = "土豆" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1354, .word = "东方" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1356, .word = "南京" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1357, .word = "求职" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1358, .word = "取得" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1360, .word = "相信" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1361, .word = "页面" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1363, .word = "网页" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1364, .word = "确定" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1367, .word = "积极" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1368, .word = "错误" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1370, .word = "宝贝" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1372, .word = "风险" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1373, .word = "授权" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1374, .word = "病毒" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1375, .word = "宠物" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1376, .word = "除了" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1377, .word = "評論" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1378, .word = "疾病" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1382, .word = "儿童" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1383, .word = "每天" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1386, .word = "每个" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1387, .word = "天津" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1388, .word = "字体" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1389, .word = "台灣" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1390, .word = "维护" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1392, .word = "个性" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1393, .word = "官方" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1394, .word = "常见" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1396, .word = "战略" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1397, .word = "应当" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1401, .word = "股市" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1402, .word = "房屋" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1403, .word = "栏目" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1404, .word = "员工" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1407, .word = "道具" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1409, .word = "结合" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1410, .word = "档案" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1411, .word = "劳动" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1412, .word = "另外" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1414, .word = "引起" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1418, .word = "說明" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1419, .word = "隐私" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1422, .word = "消费" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1423, .word = "共同" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1424, .word = "忘记" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1425, .word = "体系" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1426, .word = "带来" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1427, .word = "名字" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1428, .word = "發表" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1429, .word = "开放" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1430, .word = "加盟" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1431, .word = "受到" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1432, .word = "二手" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1433, .word = "大量" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1435, .word = "数量" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1436, .word = "共享" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1437, .word = "区域" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1438, .word = "女孩" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1442, .word = "通信" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1443, .word = "超级" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1444, .word = "配置" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1445, .word = "当时" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1446, .word = "优秀" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1447, .word = "性感" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1448, .word = "房产" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1449, .word = "遊戲" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1452, .word = "就业" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1453, .word = "保健" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1454, .word = "程度" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1455, .word = "参数" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1460, .word = "特殊" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1461, .word = "分類" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1463, .word = "属于" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1464, .word = "门户" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1466, .word = "声音" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1467, .word = "及其" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1468, .word = "财经" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1469, .word = "坚持" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1470, .word = "干部" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1471, .word = "成立" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1473, .word = "考虑" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1474, .word = "成都" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1475, .word = "包装" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1478, .word = "文明" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1479, .word = "招商" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1480, .word = "完整" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1482, .word = "眼睛" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1483, .word = "伙伴" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1484, .word = "威望" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1486, .word = "卫生" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1488, .word = "論壇" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1490, .word = "良好" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1491, .word = "充分" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1492, .word = "符合" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1493, .word = "附件" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1494, .word = "特点" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1495, .word = "不可" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1496, .word = "英文" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1497, .word = "资产" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1498, .word = "根本" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1500, .word = "密碼" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1501, .word = "公众" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1502, .word = "民族" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1504, .word = "享受" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1506, .word = "启动" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1507, .word = "适合" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1509, .word = "问答" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1510, .word = "本文" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1511, .word = "美食" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1512, .word = "绿色" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1514, .word = "终于" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1515, .word = "生物" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1516, .word = "供求" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1518, .word = "力量" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1519, .word = "严重" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1520, .word = "永远" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1521, .word = "写真" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1522, .word = "有限" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1523, .word = "竞争" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1524, .word = "对象" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1525, .word = "费用" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1528, .word = "十分" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1529, .word = "促进" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1531, .word = "影音" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1534, .word = "欣赏" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1535, .word = "并且" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1536, .word = "有点" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1539, .word = "信用" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1540, .word = "设施" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1541, .word = "形象" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1543, .word = "突破" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1546, .word = "于是" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1547, .word = "毕业" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1548, .word = "智能" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1550, .word = "完美" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1552, .word = "统一" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1553, .word = "出版" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1556, .word = "概况" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1557, .word = "用于" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1558, .word = "保留" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1559, .word = "因素" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1564, .word = "长期" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1565, .word = "口价" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1568, .word = "安排" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1569, .word = "武汉" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1570, .word = "里面" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1571, .word = "创建" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1572, .word = "天空" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1573, .word = "首先" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1575, .word = "驱动" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1580, .word = "阳光" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1581, .word = "英国" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1582, .word = "漂亮" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1583, .word = "军事" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1584, .word = "玩家" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1585, .word = "群众" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1587, .word = "即可" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1590, .word = "动画" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1591, .word = "想到" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1593, .word = "小学" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1594, .word = "性能" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1595, .word = "考研" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1598, .word = "清楚" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1599, .word = "搞笑" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1600, .word = "首頁" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1601, .word = "黄金" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1602, .word = "适用" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1603, .word = "江苏" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1606, .word = "阶段" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1607, .word = "註冊" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1608, .word = "翻译" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1609, .word = "权利" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1610, .word = "做好" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1612, .word = "通讯" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1613, .word = "施工" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1614, .word = "狀態" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1615, .word = "也许" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1616, .word = "环保" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1617, .word = "培养" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1620, .word = "机票" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1622, .word = "匿名" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1623, .word = "cuando" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1624, .word = "enviar" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1625, .word = "madrid" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1627, .word = "inicio" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1628, .word = "tiempo" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1629, .word = "porque" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1630, .word = "cuenta" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1636, .word = "nombre" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1639, .word = "manera" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1641, .word = "ciudad" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1643, .word = "aunque" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1645, .word = "dentro" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1647, .word = "precio" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1648, .word = "según" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1650, .word = "volver" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1652, .word = "semana" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1653, .word = "había" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1654, .word = "agosto" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1657, .word = "carlos" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1658, .word = "equipo" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1659, .word = "niños" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1660, .word = "muchos" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1661, .word = "alguna" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1666, .word = "maría" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1667, .word = "hombre" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1668, .word = "empleo" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1669, .word = "verdad" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1674, .word = "línea" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1683, .word = "miguel" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1685, .word = "cuatro" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1689, .word = "europa" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1693, .word = "demás" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1703, .word = "cuerpo" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1704, .word = "siendo" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1705, .word = "prensa" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1706, .word = "llegar" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1709, .word = "murcia" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1710, .word = "podrá" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1712, .word = "diario" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1716, .word = "propio" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1717, .word = "crisis" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1718, .word = "cierto" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1719, .word = "seguro" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1720, .word = "muerte" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1721, .word = "fuente" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1722, .word = "cerrar" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1723, .word = "grande" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1724, .word = "efecto" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1728, .word = "ofrece" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1729, .word = "tierra" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1730, .word = "e-mail" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1736, .word = "riesgo" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1739, .word = "único" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1740, .word = "camino" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1742, .word = "razón" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1743, .word = "debido" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1744, .word = "prueba" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1745, .word = "toledo" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1746, .word = "tenía" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1747, .word = "jesús" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1749, .word = "cocina" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1751, .word = "tienda" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1752, .word = "ciento" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1753, .word = "cádiz" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1758, .word = "estilo" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1759, .word = "guerra" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1761, .word = "éxito" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1764, .word = "vídeo" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1765, .word = "evitar" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1766, .word = "pagina" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1767, .word = "metros" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1768, .word = "javier" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1769, .word = "padres" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1770, .word = "fácil" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1771, .word = "cabeza" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1773, .word = "salida" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1774, .word = "envío" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1775, .word = "japón" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1782, .word = "común" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1785, .word = "tenido" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1786, .word = "bilbao" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1791, .word = "для" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1792, .word = "что" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1793, .word = "как" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1794, .word = "или" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1795, .word = "это" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1796, .word = "все" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1797, .word = "его" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1799, .word = "так" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1800, .word = "еще" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1802, .word = "Как" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1803, .word = "без" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1804, .word = "был" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1805, .word = "они" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1806, .word = "Все" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1807, .word = "под" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1808, .word = "Это" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1809, .word = "том" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1810, .word = "чем" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1811, .word = "нет" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1812, .word = "лет" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1813, .word = "раз" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1815, .word = "где" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1816, .word = "мне" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1817, .word = "Для" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1818, .word = "При" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1819, .word = "нас" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1820, .word = "них" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1821, .word = "тем" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1822, .word = "кто" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1823, .word = "год" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1824, .word = "вот" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1826, .word = "США" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1827, .word = "мая" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1828, .word = "Что" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1829, .word = "вас" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1831, .word = "ему" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1832, .word = "Так" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1833, .word = "два" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1839, .word = "про" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1840, .word = "тут" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1842, .word = "дня" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1843, .word = "Вот" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1844, .word = "три" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1846, .word = "Вас" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1848, .word = "сам" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1854, .word = "ООО" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1860, .word = "мой" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1863, .word = "суд" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1865, .word = "है" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1868, .word = "का" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1871, .word = "पर" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1872, .word = "ने" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1878, .word = "तो" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1880, .word = "आप" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1883, .word = "या" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1885, .word = "था" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1886, .word = "jagran" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1888, .word = "जो" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1889, .word = "अब" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1891, .word = "गई" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1895, .word = "इन" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1900, .word = "घर" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1905, .word = "वे" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1909, .word = "उस" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1910, .word = "मे" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1913, .word = "ले" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1916, .word = "दे" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1917, .word = "ओर" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1921, .word = "बन" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1922, .word = "चल" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1928, .word = "إلى" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1929, .word = "هذا" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1930, .word = "آخر" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1931, .word = "عدد" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1935, .word = "غير" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1936, .word = "كان" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1937, .word = "ولا" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1939, .word = "عرض" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1940, .word = "ذلك" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1941, .word = "هنا" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1943, .word = "قال" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1944, .word = "علي" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1947, .word = "حتى" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1948, .word = "قبل" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1949, .word = "وحة" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1950, .word = "اخر" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1951, .word = "فقط" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1952, .word = "عبد" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1953, .word = "ركن" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1954, .word = "إذا" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1955, .word = "كما" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1960, .word = "كيف" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1961, .word = "بحث" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1963, .word = "وهو" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1964, .word = "أنا" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1968, .word = "عند" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1969, .word = "ليس" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1972, .word = "منذ" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1975, .word = "مثل" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1977, .word = "الا" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1978, .word = "حيث" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1979, .word = "مصر" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1980, .word = "شرح" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1981, .word = "حول" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1982, .word = "وفي" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1983, .word = "اذا" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1984, .word = "لكل" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1985, .word = "مرة" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1988, .word = "أبو" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1991, .word = "انه" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1993, .word = "عضو" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1994, .word = "وقد" },
    .{ .transform = 0, .copy_len = 6, .word_index = 1997, .word = "بنت" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2001, .word = "ابو" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2002, .word = "قصص" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2005, .word = "أحد" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2006, .word = "نحن" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2008, .word = "رأي" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2009, .word = "احة" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2010, .word = "كتب" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2011, .word = "دون" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2012, .word = "يجب" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2015, .word = "جهة" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2016, .word = "سنة" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2017, .word = "يتم" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2018, .word = "كرة" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2020, .word = "نفس" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2023, .word = "لنا" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2024, .word = "تلك" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2026, .word = "لما" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2028, .word = "أول" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2031, .word = "أما" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2034, .word = "ذات" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2036, .word = "بأن" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2041, .word = "حسن" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2043, .word = "شعر" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2044, .word = "أهل" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2045, .word = "شهر" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2046, .word = "قطر" },
    .{ .transform = 0, .copy_len = 6, .word_index = 2047, .word = "طلب" },
    .{ .transform = 0, .copy_len = 7, .word_index = 0, .word = "profile" },
    .{ .transform = 0, .copy_len = 7, .word_index = 2, .word = "default" },
    .{ .transform = 0, .copy_len = 7, .word_index = 4, .word = "details" },
    .{ .transform = 0, .copy_len = 7, .word_index = 6, .word = "support" },
    .{ .transform = 0, .copy_len = 7, .word_index = 8, .word = "message" },
    .{ .transform = 0, .copy_len = 7, .word_index = 9, .word = "success" },
    .{ .transform = 0, .copy_len = 7, .word_index = 10, .word = "fashion" },
    .{ .transform = 0, .copy_len = 7, .word_index = 11, .word = "<title>" },
    .{ .transform = 0, .copy_len = 7, .word_index = 13, .word = "account" },
    .{ .transform = 0, .copy_len = 7, .word_index = 14, .word = "created" },
    .{ .transform = 0, .copy_len = 7, .word_index = 15, .word = "stories" },
    .{ .transform = 0, .copy_len = 7, .word_index = 17, .word = "running" },
    .{ .transform = 0, .copy_len = 7, .word_index = 18, .word = "process" },
    .{ .transform = 0, .copy_len = 7, .word_index = 20, .word = "objects" },
    .{ .transform = 0, .copy_len = 7, .word_index = 21, .word = "visible" },
    .{ .transform = 0, .copy_len = 7, .word_index = 22, .word = "welcome" },
    .{ .transform = 0, .copy_len = 7, .word_index = 23, .word = "article" },
    .{ .transform = 0, .copy_len = 7, .word_index = 24, .word = "unknown" },
    .{ .transform = 0, .copy_len = 7, .word_index = 25, .word = "network" },
    .{ .transform = 0, .copy_len = 7, .word_index = 26, .word = "company" },
    .{ .transform = 0, .copy_len = 7, .word_index = 27, .word = "dynamic" },
    .{ .transform = 0, .copy_len = 7, .word_index = 28, .word = "browser" },
    .{ .transform = 0, .copy_len = 7, .word_index = 29, .word = "privacy" },
    .{ .transform = 0, .copy_len = 7, .word_index = 30, .word = "problem" },
    .{ .transform = 0, .copy_len = 7, .word_index = 31, .word = "Service" },
    .{ .transform = 0, .copy_len = 7, .word_index = 33, .word = "display" },
    .{ .transform = 0, .copy_len = 7, .word_index = 34, .word = "request" },
    .{ .transform = 0, .copy_len = 7, .word_index = 36, .word = "website" },
    .{ .transform = 0, .copy_len = 7, .word_index = 37, .word = "history" },
    .{ .transform = 0, .copy_len = 7, .word_index = 39, .word = "options" },
    .{ .transform = 0, .copy_len = 7, .word_index = 41, .word = "version" },
    .{ .transform = 0, .copy_len = 7, .word_index = 42, .word = "million" },
    .{ .transform = 0, .copy_len = 7, .word_index = 44, .word = "window." },
    .{ .transform = 0, .copy_len = 7, .word_index = 45, .word = "address" },
    .{ .transform = 0, .copy_len = 7, .word_index = 47, .word = "weather" },
    .{ .transform = 0, .copy_len = 7, .word_index = 48, .word = "correct" },
    .{ .transform = 0, .copy_len = 7, .word_index = 49, .word = "product" },
    .{ .transform = 0, .copy_len = 7, .word_index = 50, .word = "edirect" },
    .{ .transform = 0, .copy_len = 7, .word_index = 51, .word = "forward" },
    .{ .transform = 0, .copy_len = 7, .word_index = 52, .word = "you can" },
    .{ .transform = 0, .copy_len = 7, .word_index = 54, .word = "subject" },
    .{ .transform = 0, .copy_len = 7, .word_index = 56, .word = "archive" },
    .{ .transform = 0, .copy_len = 7, .word_index = 57, .word = "current" },
    .{ .transform = 0, .copy_len = 7, .word_index = 59, .word = "library" },
    .{ .transform = 0, .copy_len = 7, .word_index = 61, .word = "manager" },
    .{ .transform = 0, .copy_len = 7, .word_index = 62, .word = "further" },
    .{ .transform = 0, .copy_len = 7, .word_index = 63, .word = "summary" },
    .{ .transform = 0, .copy_len = 7, .word_index = 64, .word = "machine" },
    .{ .transform = 0, .copy_len = 7, .word_index = 65, .word = "minutes" },
    .{ .transform = 0, .copy_len = 7, .word_index = 68, .word = "program" },
    .{ .transform = 0, .copy_len = 7, .word_index = 73, .word = "trigger" },
    .{ .transform = 0, .copy_len = 7, .word_index = 75, .word = "loading" },
    .{ .transform = 0, .copy_len = 7, .word_index = 76, .word = "element" },
    .{ .transform = 0, .copy_len = 7, .word_index = 77, .word = "partner" },
    .{ .transform = 0, .copy_len = 7, .word_index = 80, .word = "meaning" },
    .{ .transform = 0, .copy_len = 7, .word_index = 83, .word = "culture" },
    .{ .transform = 0, .copy_len = 7, .word_index = 85, .word = "journal" },
    .{ .transform = 0, .copy_len = 7, .word_index = 86, .word = "project" },
    .{ .transform = 0, .copy_len = 7, .word_index = 87, .word = "surface" },
    .{ .transform = 0, .copy_len = 7, .word_index = 88, .word = "s&quot;" },
    .{ .transform = 0, .copy_len = 7, .word_index = 89, .word = "expires" },
    .{ .transform = 0, .copy_len = 7, .word_index = 91, .word = "balance" },
    .{ .transform = 0, .copy_len = 7, .word_index = 92, .word = "English" },
    .{ .transform = 0, .copy_len = 7, .word_index = 93, .word = "Content" },
    .{ .transform = 0, .copy_len = 7, .word_index = 94, .word = "through" },
    .{ .transform = 0, .copy_len = 7, .word_index = 95, .word = "Please " },
    .{ .transform = 0, .copy_len = 7, .word_index = 96, .word = "opinion" },
    .{ .transform = 0, .copy_len = 7, .word_index = 97, .word = "contact" },
    .{ .transform = 0, .copy_len = 7, .word_index = 98, .word = "average" },
    .{ .transform = 0, .copy_len = 7, .word_index = 99, .word = "primary" },
    .{ .transform = 0, .copy_len = 7, .word_index = 101, .word = "Spanish" },
    .{ .transform = 0, .copy_len = 7, .word_index = 102, .word = "gallery" },
    .{ .transform = 0, .copy_len = 7, .word_index = 103, .word = "decline" },
    .{ .transform = 0, .copy_len = 7, .word_index = 105, .word = "mission" },
    .{ .transform = 0, .copy_len = 7, .word_index = 107, .word = "quality" },
    .{ .transform = 0, .copy_len = 7, .word_index = 108, .word = "measure" },
    .{ .transform = 0, .copy_len = 7, .word_index = 112, .word = "section" },
    .{ .transform = 0, .copy_len = 7, .word_index = 114, .word = "counter" },
    .{ .transform = 0, .copy_len = 7, .word_index = 115, .word = "initial" },
    .{ .transform = 0, .copy_len = 7, .word_index = 121, .word = "earlier" },
    .{ .transform = 0, .copy_len = 7, .word_index = 122, .word = "express" },
    .{ .transform = 0, .copy_len = 7, .word_index = 123, .word = "digital" },
    .{ .transform = 0, .copy_len = 7, .word_index = 124, .word = "picture" },
    .{ .transform = 0, .copy_len = 7, .word_index = 125, .word = "Another" },
    .{ .transform = 0, .copy_len = 7, .word_index = 126, .word = "married" },
    .{ .transform = 0, .copy_len = 7, .word_index = 127, .word = "traffic" },
    .{ .transform = 0, .copy_len = 7, .word_index = 131, .word = "victory" },
    .{ .transform = 0, .copy_len = 7, .word_index = 132, .word = "images/" },
    .{ .transform = 0, .copy_len = 7, .word_index = 133, .word = "reasons" },
    .{ .transform = 0, .copy_len = 7, .word_index = 135, .word = "feature" },
    .{ .transform = 0, .copy_len = 7, .word_index = 137, .word = "must be" },
    .{ .transform = 0, .copy_len = 7, .word_index = 139, .word = "Version" },
    .{ .transform = 0, .copy_len = 7, .word_index = 141, .word = "episode" },
    .{ .transform = 0, .copy_len = 7, .word_index = 144, .word = "obvious" },
    .{ .transform = 0, .copy_len = 7, .word_index = 145, .word = "overlay" },
    .{ .transform = 0, .copy_len = 7, .word_index = 148, .word = "</ul>\r\n" },
    .{ .transform = 0, .copy_len = 7, .word_index = 150, .word = "already" },
    .{ .transform = 0, .copy_len = 7, .word_index = 151, .word = "certain" },
    .{ .transform = 0, .copy_len = 7, .word_index = 154, .word = "another" },
    .{ .transform = 0, .copy_len = 7, .word_index = 155, .word = "desktop" },
    .{ .transform = 0, .copy_len = 7, .word_index = 157, .word = "pattern" },
    .{ .transform = 0, .copy_len = 7, .word_index = 158, .word = "unusual" },
    .{ .transform = 0, .copy_len = 7, .word_index = 159, .word = "Digital" },
    .{ .transform = 0, .copy_len = 7, .word_index = 160, .word = "capital" },
    .{ .transform = 0, .copy_len = 7, .word_index = 161, .word = "Website" },
    .{ .transform = 0, .copy_len = 7, .word_index = 162, .word = "failure" },
    .{ .transform = 0, .copy_len = 7, .word_index = 163, .word = "connect" },
    .{ .transform = 0, .copy_len = 7, .word_index = 164, .word = "reduced" },
    .{ .transform = 0, .copy_len = 7, .word_index = 165, .word = "Android" },
    .{ .transform = 0, .copy_len = 7, .word_index = 166, .word = "decades" },
    .{ .transform = 0, .copy_len = 7, .word_index = 167, .word = "regular" },
    .{ .transform = 0, .copy_len = 7, .word_index = 168, .word = " &amp; " },
    .{ .transform = 0, .copy_len = 7, .word_index = 170, .word = "release" },
    .{ .transform = 0, .copy_len = 7, .word_index = 171, .word = "Automat" },
    .{ .transform = 0, .copy_len = 7, .word_index = 172, .word = "getting" },
    .{ .transform = 0, .copy_len = 7, .word_index = 174, .word = "nothing" },
    .{ .transform = 0, .copy_len = 7, .word_index = 175, .word = "Popular" },
    .{ .transform = 0, .copy_len = 7, .word_index = 176, .word = "caption" },
    .{ .transform = 0, .copy_len = 7, .word_index = 180, .word = "license" },
    .{ .transform = 0, .copy_len = 7, .word_index = 183, .word = "=1&amp;" },
    .{ .transform = 0, .copy_len = 7, .word_index = 184, .word = "History" },
    .{ .transform = 0, .copy_len = 7, .word_index = 185, .word = " = new " },
    .{ .transform = 0, .copy_len = 7, .word_index = 188, .word = "Special" },
    .{ .transform = 0, .copy_len = 7, .word_index = 189, .word = "Network" },
    .{ .transform = 0, .copy_len = 7, .word_index = 192, .word = "warning" },
    .{ .transform = 0, .copy_len = 7, .word_index = 193, .word = "College" },
    .{ .transform = 0, .copy_len = 7, .word_index = 194, .word = "toolbar" },
    .{ .transform = 0, .copy_len = 7, .word_index = 196, .word = "because" },
    .{ .transform = 0, .copy_len = 7, .word_index = 197, .word = "elected" },
    .{ .transform = 0, .copy_len = 7, .word_index = 198, .word = "Deutsch" },
    .{ .transform = 0, .copy_len = 7, .word_index = 199, .word = "finance" },
    .{ .transform = 0, .copy_len = 7, .word_index = 202, .word = "between" },
    .{ .transform = 0, .copy_len = 7, .word_index = 219, .word = "Mobile " },
    .{ .transform = 0, .copy_len = 7, .word_index = 228, .word = "Current" },
    .{ .transform = 0, .copy_len = 7, .word_index = 241, .word = "Science" },
    .{ .transform = 0, .copy_len = 7, .word_index = 243, .word = "Article" },
    .{ .transform = 0, .copy_len = 7, .word_index = 251, .word = "General" },
    .{ .transform = 0, .copy_len = 7, .word_index = 282, .word = "return " },
    .{ .transform = 0, .copy_len = 7, .word_index = 287, .word = "America" },
    .{ .transform = 0, .copy_len = 7, .word_index = 290, .word = "Message" },
    .{ .transform = 0, .copy_len = 7, .word_index = 321, .word = "Results" },
    .{ .transform = 0, .copy_len = 7, .word_index = 327, .word = "Account" },
    .{ .transform = 0, .copy_len = 7, .word_index = 349, .word = "Studies" },
    .{ .transform = 0, .copy_len = 7, .word_index = 369, .word = "english" },
    .{ .transform = 0, .copy_len = 7, .word_index = 373, .word = "Company" },
    .{ .transform = 0, .copy_len = 7, .word_index = 391, .word = "Gallery" },
    .{ .transform = 0, .copy_len = 7, .word_index = 456, .word = "Culture" },
    .{ .transform = 0, .copy_len = 7, .word_index = 460, .word = "Browser" },
    .{ .transform = 0, .copy_len = 7, .word_index = 463, .word = "Project" },
    .{ .transform = 0, .copy_len = 7, .word_index = 464, .word = "example" },
    .{ .transform = 0, .copy_len = 7, .word_index = 475, .word = "Further" },
    .{ .transform = 0, .copy_len = 7, .word_index = 483, .word = "Request" },
    .{ .transform = 0, .copy_len = 7, .word_index = 512, .word = " Other " },
    .{ .transform = 0, .copy_len = 7, .word_index = 537, .word = "select " },
    .{ .transform = 0, .copy_len = 7, .word_index = 570, .word = "Display" },
    .{ .transform = 0, .copy_len = 7, .word_index = 572, .word = "however" },
    .{ .transform = 0, .copy_len = 7, .word_index = 585, .word = "Online " },
    .{ .transform = 0, .copy_len = 7, .word_index = 648, .word = "Privacy" },
    .{ .transform = 0, .copy_len = 7, .word_index = 669, .word = "Section" },
    .{ .transform = 0, .copy_len = 7, .word_index = 693, .word = "Default" },
    .{ .transform = 0, .copy_len = 7, .word_index = 717, .word = "Product" },
    .{ .transform = 0, .copy_len = 7, .word_index = 730, .word = "Element" },
    .{ .transform = 0, .copy_len = 7, .word_index = 738, .word = "Systems" },
    .{ .transform = 0, .copy_len = 7, .word_index = 739, .word = "Program" },
    .{ .transform = 0, .copy_len = 7, .word_index = 741, .word = " width=" },
    .{ .transform = 0, .copy_len = 7, .word_index = 803, .word = "Options" },
    .{ .transform = 0, .copy_len = 7, .word_index = 831, .word = "Address" },
    .{ .transform = 0, .copy_len = 7, .word_index = 880, .word = "Comment" },
    .{ .transform = 0, .copy_len = 7, .word_index = 899, .word = " return" },
    .{ .transform = 0, .copy_len = 7, .word_index = 952, .word = "Summary" },
    .{ .transform = 0, .copy_len = 7, .word_index = 973, .word = "Capital" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1018, .word = "famous " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1020, .word = "License" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1053, .word = "Usually" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1086, .word = " target" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1135, .word = " center" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1167, .word = "of the " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1180, .word = " window" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1182, .word = " simple" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1271, .word = "Letters" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1275, .word = " groups" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1292, .word = "having " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1294, .word = " active" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1302, .word = "Picture" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1305, .word = " object" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1371, .word = "Famous " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1374, .word = " Online" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1408, .word = "policy." },
    .{ .transform = 0, .copy_len = 7, .word_index = 1418, .word = " &nbsp;" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1431, .word = " Search" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1445, .word = "Mission" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1487, .word = " About " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1525, .word = "Through" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1537, .word = " market" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1646, .word = "Certain" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1668, .word = "height " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1690, .word = "better " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1694, .word = " System" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1709, .word = "giving " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1726, .word = "called " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1767, .word = "one and" },
    .{ .transform = 0, .copy_len = 7, .word_index = 1781, .word = "either " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1845, .word = "really " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1857, .word = "Office " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1865, .word = "around " },
    .{ .transform = 0, .copy_len = 7, .word_index = 1925, .word = " size=\"" },
    .{ .transform = 0, .copy_len = 8, .word_index = 4, .word = "language" },
    .{ .transform = 0, .copy_len = 8, .word_index = 10, .word = "children" },
    .{ .transform = 0, .copy_len = 8, .word_index = 65, .word = "Language" },
    .{ .transform = 0, .copy_len = 8, .word_index = 79, .word = "internet" },
    .{ .transform = 0, .copy_len = 8, .word_index = 319, .word = "connect." },
    .{ .transform = 0, .copy_len = 8, .word_index = 321, .word = " website" },
    .{ .transform = 0, .copy_len = 8, .word_index = 355, .word = "American" },
    .{ .transform = 0, .copy_len = 8, .word_index = 362, .word = "section " },
    .{ .transform = 0, .copy_len = 8, .word_index = 425, .word = "history." },
    .{ .transform = 0, .copy_len = 8, .word_index = 438, .word = "Examples" },
    .{ .transform = 0, .copy_len = 8, .word_index = 460, .word = "Content " },
    .{ .transform = 0, .copy_len = 8, .word_index = 467, .word = " quality" },
    .{ .transform = 0, .copy_len = 8, .word_index = 515, .word = "primary " },
    .{ .transform = 0, .copy_len = 8, .word_index = 518, .word = "quickly " },
    .{ .transform = 0, .copy_len = 8, .word_index = 540, .word = " Online " },
    .{ .transform = 0, .copy_len = 8, .word_index = 550, .word = "quality " },
    .{ .transform = 0, .copy_len = 8, .word_index = 558, .word = "examples" },
    .{ .transform = 0, .copy_len = 8, .word_index = 572, .word = " project" },
    .{ .transform = 0, .copy_len = 8, .word_index = 608, .word = " changes" },
    .{ .transform = 0, .copy_len = 8, .word_index = 614, .word = " numbers" },
    .{ .transform = 0, .copy_len = 9, .word_index = 5, .word = "available" },
    .{ .transform = 0, .copy_len = 9, .word_index = 55, .word = "important" },
    .{ .transform = 0, .copy_len = 9, .word_index = 95, .word = "different" },
    .{ .transform = 0, .copy_len = 9, .word_index = 205, .word = "from the " },
    .{ .transform = 0, .copy_len = 9, .word_index = 271, .word = "those who" },
    .{ .transform = 0, .copy_len = 9, .word_index = 592, .word = "however, " },
    .{ .transform = 0, .copy_len = 9, .word_index = 676, .word = " language" },
    .{ .transform = 0, .copy_len = 10, .word_index = 18, .word = "government" },
    .{ .transform = 0, .copy_len = 10, .word_index = 84, .word = "expression" },
    .{ .transform = 0, .copy_len = 10, .word_index = 135, .word = "depression" },
    .{ .transform = 0, .copy_len = 10, .word_index = 150, .word = "Government" },
    .{ .transform = 0, .copy_len = 10, .word_index = 205, .word = "dictionary" },
    .{ .transform = 0, .copy_len = 10, .word_index = 240, .word = "number of " },
    .{ .transform = 0, .copy_len = 10, .word_index = 327, .word = "Dictionary" },
    .{ .transform = 0, .copy_len = 10, .word_index = 608, .word = "to another" },
    .{ .transform = 0, .copy_len = 11, .word_index = 5, .word = "information" },
    .{ .transform = 0, .copy_len = 11, .word_index = 162, .word = "one another" },
    .{ .transform = 0, .copy_len = 11, .word_index = 178, .word = "One of the " },
    .{ .transform = 0, .copy_len = 11, .word_index = 186, .word = "Information" },
    .{ .transform = 0, .copy_len = 11, .word_index = 189, .word = "in order to" },
    .{ .transform = 0, .copy_len = 11, .word_index = 429, .word = "In order to" },
    .{ .transform = 0, .copy_len = 11, .word_index = 452, .word = "one of the " },
    .{ .transform = 0, .copy_len = 12, .word_index = 285, .word = " Information" },
    .{ .transform = 0, .copy_len = 16, .word_index = 52, .word = "large number of " },
    .{ .transform = 1, .copy_len = 5, .word_index = 43, .word = "words " },
    .{ .transform = 1, .copy_len = 5, .word_index = 44, .word = "games " },
    .{ .transform = 1, .copy_len = 7, .word_index = 170, .word = "release " },
    .{ .transform = 1, .copy_len = 7, .word_index = 369, .word = "english " },
    .{ .transform = 1, .copy_len = 10, .word_index = 205, .word = "dictionary " },
    .{ .transform = 1, .copy_len = 11, .word_index = 5, .word = "information " },
    .{ .transform = 1, .copy_len = 12, .word_index = 285, .word = " Information " },
    .{ .transform = 1, .copy_len = 16, .word_index = 52, .word = "large number of  " },
    .{ .transform = 6, .copy_len = 5, .word_index = 43, .word = " words" },
    .{ .transform = 6, .copy_len = 5, .word_index = 44, .word = " games" },
    .{ .transform = 6, .copy_len = 6, .word_index = 201, .word = " Number" },
    .{ .transform = 6, .copy_len = 6, .word_index = 202, .word = " during" },
    .{ .transform = 6, .copy_len = 6, .word_index = 205, .word = " killed" },
    .{ .transform = 6, .copy_len = 6, .word_index = 377, .word = " Africa" },
    .{ .transform = 6, .copy_len = 6, .word_index = 379, .word = " recent" },
    .{ .transform = 6, .copy_len = 6, .word_index = 380, .word = " People" },
    .{ .transform = 6, .copy_len = 6, .word_index = 381, .word = " <br />" },
    .{ .transform = 6, .copy_len = 6, .word_index = 382, .word = " wonder" },
    .{ .transform = 6, .copy_len = 6, .word_index = 386, .word = " main\">" },
    .{ .transform = 6, .copy_len = 6, .word_index = 387, .word = " inline" },
    .{ .transform = 6, .copy_len = 6, .word_index = 388, .word = " sunday" },
    .{ .transform = 6, .copy_len = 6, .word_index = 389, .word = " wrap\">" },
    .{ .transform = 6, .copy_len = 6, .word_index = 391, .word = " census" },
    .{ .transform = 6, .copy_len = 6, .word_index = 393, .word = " beacon" },
    .{ .transform = 6, .copy_len = 6, .word_index = 395, .word = " 150px|" },
    .{ .transform = 6, .copy_len = 6, .word_index = 567, .word = " opping" },
    .{ .transform = 6, .copy_len = 6, .word_index = 570, .word = " vspace" },
    .{ .transform = 6, .copy_len = 6, .word_index = 573, .word = " coffee" },
    .{ .transform = 6, .copy_len = 6, .word_index = 574, .word = " martin" },
    .{ .transform = 6, .copy_len = 6, .word_index = 575, .word = " mature" },
    .{ .transform = 6, .copy_len = 6, .word_index = 577, .word = " </nav>" },
    .{ .transform = 6, .copy_len = 6, .word_index = 578, .word = " kansas" },
    .{ .transform = 6, .copy_len = 6, .word_index = 579, .word = " link\">" },
    .{ .transform = 6, .copy_len = 6, .word_index = 582, .word = " while " },
    .{ .transform = 6, .copy_len = 6, .word_index = 583, .word = " hspace" },
    .{ .transform = 6, .copy_len = 6, .word_index = 584, .word = " 0&amp;" },
    .{ .transform = 6, .copy_len = 6, .word_index = 585, .word = "  \n\nIn " },
    .{ .transform = 6, .copy_len = 6, .word_index = 758, .word = " 这里" },
    .{ .transform = 6, .copy_len = 6, .word_index = 759, .word = " 还是" },
    .{ .transform = 6, .copy_len = 6, .word_index = 761, .word = " 情况" },
    .{ .transform = 6, .copy_len = 6, .word_index = 762, .word = " 电脑" },
    .{ .transform = 6, .copy_len = 6, .word_index = 763, .word = " 文件" },
    .{ .transform = 6, .copy_len = 6, .word_index = 764, .word = " 品牌" },
    .{ .transform = 6, .copy_len = 6, .word_index = 765, .word = " 帮助" },
    .{ .transform = 6, .copy_len = 6, .word_index = 769, .word = " 学习" },
    .{ .transform = 6, .copy_len = 6, .word_index = 770, .word = " 地址" },
    .{ .transform = 6, .copy_len = 6, .word_index = 771, .word = " 浏览" },
    .{ .transform = 6, .copy_len = 6, .word_index = 772, .word = " 投资" },
    .{ .transform = 6, .copy_len = 6, .word_index = 773, .word = " 工程" },
    .{ .transform = 6, .copy_len = 6, .word_index = 774, .word = " 要求" },
    .{ .transform = 6, .copy_len = 6, .word_index = 775, .word = " 怎么" },
    .{ .transform = 6, .copy_len = 6, .word_index = 777, .word = " 功能" },
    .{ .transform = 6, .copy_len = 6, .word_index = 778, .word = " 主要" },
    .{ .transform = 6, .copy_len = 6, .word_index = 779, .word = " 目前" },
    .{ .transform = 6, .copy_len = 6, .word_index = 781, .word = " 城市" },
    .{ .transform = 6, .copy_len = 6, .word_index = 957, .word = " 学院" },
    .{ .transform = 6, .copy_len = 6, .word_index = 958, .word = " 具有" },
    .{ .transform = 6, .copy_len = 6, .word_index = 959, .word = " 过程" },
    .{ .transform = 6, .copy_len = 6, .word_index = 960, .word = " 由于" },
    .{ .transform = 6, .copy_len = 6, .word_index = 962, .word = " 出来" },
    .{ .transform = 6, .copy_len = 6, .word_index = 965, .word = " 明星" },
    .{ .transform = 6, .copy_len = 6, .word_index = 966, .word = " 故事" },
    .{ .transform = 6, .copy_len = 6, .word_index = 967, .word = " 关系" },
    .{ .transform = 6, .copy_len = 6, .word_index = 968, .word = " 标题" },
    .{ .transform = 6, .copy_len = 6, .word_index = 973, .word = " 教学" },
    .{ .transform = 6, .copy_len = 6, .word_index = 974, .word = " 了解" },
    .{ .transform = 6, .copy_len = 6, .word_index = 975, .word = " 建筑" },
    .{ .transform = 6, .copy_len = 6, .word_index = 977, .word = " 全球" },
    .{ .transform = 6, .copy_len = 6, .word_index = 978, .word = " 通知" },
    .{ .transform = 6, .copy_len = 6, .word_index = 979, .word = " 计划" },
    .{ .transform = 6, .copy_len = 6, .word_index = 980, .word = " 对于" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1152, .word = " 事情" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1154, .word = " 提示" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1155, .word = " 上市" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1157, .word = " 普通" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1159, .word = " 上传" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1160, .word = " 类别" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1162, .word = " 拥有" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1163, .word = " 创新" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1164, .word = " 配件" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1166, .word = " 时代" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1167, .word = " 資訊" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1168, .word = " 达到" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1169, .word = " 人生" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1170, .word = " 订阅" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1171, .word = " 老师" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1172, .word = " 展示" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1173, .word = " 心理" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1174, .word = " 贴子" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1175, .word = " 網站" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1348, .word = " 重庆" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1349, .word = " 出售" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1350, .word = " 成本" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1351, .word = " 形式" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1352, .word = " 土豆" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1354, .word = " 东方" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1356, .word = " 南京" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1357, .word = " 求职" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1358, .word = " 取得" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1360, .word = " 相信" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1361, .word = " 页面" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1363, .word = " 网页" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1364, .word = " 确定" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1367, .word = " 积极" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1368, .word = " 错误" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1541, .word = " 形象" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1543, .word = " 突破" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1546, .word = " 于是" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1547, .word = " 毕业" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1548, .word = " 智能" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1550, .word = " 完美" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1552, .word = " 统一" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1553, .word = " 出版" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1556, .word = " 概况" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1557, .word = " 用于" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1558, .word = " 保留" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1559, .word = " 因素" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1564, .word = " 长期" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1736, .word = " riesgo" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1739, .word = " único" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1740, .word = " camino" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1742, .word = " razón" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1743, .word = " debido" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1744, .word = " prueba" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1745, .word = " toledo" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1746, .word = " tenía" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1747, .word = " jesús" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1749, .word = " cocina" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1751, .word = " tienda" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1752, .word = " ciento" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1753, .word = " cádiz" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1928, .word = " إلى" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1929, .word = " هذا" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1930, .word = " آخر" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1931, .word = " عدد" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1935, .word = " غير" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1936, .word = " كان" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1937, .word = " ولا" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1939, .word = " عرض" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1940, .word = " ذلك" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1941, .word = " هنا" },
    .{ .transform = 6, .copy_len = 6, .word_index = 1943, .word = " قال" },
    .{ .transform = 6, .copy_len = 7, .word_index = 170, .word = " release" },
    .{ .transform = 6, .copy_len = 7, .word_index = 369, .word = " english" },
    .{ .transform = 6, .copy_len = 10, .word_index = 18, .word = " government" },
    .{ .transform = 6, .copy_len = 11, .word_index = 5, .word = " information" },
    .{ .transform = 6, .copy_len = 11, .word_index = 178, .word = " One of the " },
    .{ .transform = 6, .copy_len = 11, .word_index = 186, .word = " Information" },
    .{ .transform = 6, .copy_len = 11, .word_index = 189, .word = " in order to" },
    .{ .transform = 6, .copy_len = 11, .word_index = 429, .word = " In order to" },
    .{ .transform = 6, .copy_len = 11, .word_index = 452, .word = " one of the " },
    .{ .transform = 6, .copy_len = 12, .word_index = 285, .word = "  Information" },
    .{ .transform = 6, .copy_len = 16, .word_index = 52, .word = " large number of " },
    .{ .transform = 9, .copy_len = 7, .word_index = 5, .word = "Content" },
    .{ .transform = 9, .copy_len = 7, .word_index = 37, .word = "History" },
    .{ .transform = 9, .copy_len = 7, .word_index = 369, .word = "English" },
    .{ .transform = 9, .copy_len = 10, .word_index = 205, .word = "Dictionary" },
    .{ .transform = 9, .copy_len = 11, .word_index = 5, .word = "Information" },
    .{ .transform = 9, .copy_len = 12, .word_index = 285, .word = " Information" },
    .{ .transform = 12, .copy_len = 5, .word_index = 43, .word = "word" },
    .{ .transform = 12, .copy_len = 5, .word_index = 44, .word = "game" },
    .{ .transform = 12, .copy_len = 7, .word_index = 1767, .word = "one an" },
    .{ .transform = 12, .copy_len = 8, .word_index = 614, .word = " number" },
    .{ .transform = 20, .copy_len = 7, .word_index = 37, .word = "history." },
    .{ .transform = 20, .copy_len = 7, .word_index = 369, .word = "english." },
    .{ .transform = 20, .copy_len = 12, .word_index = 285, .word = " Information." },
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

fn expectBrStaticDictionaryFrame(encoded: []const u8, expected: []const u8) !void {
    try std.testing.expectEqual(expected.len, try decodedStreamSizeLimited(encoded, expected.len));
    const decoded = try decodeStreamAllocLimited(std.testing.allocator, encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "br minimal static dictionary common phrase batch decodes Node quality-five frames" {
    // These are real Node quality-5 streams that address common phrase entries
    // from Brotli's static dictionary before any output byte has been emitted.
    // Keeping them together makes this batch's dictionary-table expansion easy to
    // audit while the complete RFC dictionary import remains future work.
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x38, 0x09 }, "of the ");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x40, 0x00, 0x00, 0x20, 0x01, 0x10, 0x87, 0xc4, 0x16, 0x01 }, "from the ");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x40, 0x00, 0x00, 0x20, 0x01, 0x10, 0x87, 0x04, 0x37, 0x01 }, "those who");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x50, 0x00, 0x00, 0x20, 0x01, 0x10, 0xc0, 0xc4, 0x36, 0x00 }, "in order to");
}

test "br minimal static dictionary candidate batch decodes Node quality-five frames" {
    // These frames come from entries first surfaced by the generated candidate
    // report. They prove the report can drive real decoder coverage instead of
    // remaining only a planning artifact.
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x57, 0x07 }, "english");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9c, 0x7a }, "english ");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x67, 0x07 }, " english");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9c, 0x7a }, "english.");
}

test "br minimal static dictionary candidate identity batch decodes Node quality-five frames" {
    // Node sometimes chooses a different identity dictionary word than the
    // transform candidate that motivated the payload. Capturing those frames
    // keeps the candidate-driven workflow honest: unsupported candidates become
    // concrete identity-source coverage when that is what the encoder emits.
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x98, 0x1f }, "Through");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x16, 0x00 }, "Another");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0xb8, 0x0e }, "one and");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0xc8, 0x0e }, " one and");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x40, 0x00, 0x00, 0x20, 0x01, 0x10, 0x87, 0x84, 0x87, 0x0a }, " language");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x04, 0x56, 0x00 }, "Language");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x37, 0x02 }, "America");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x3e }, "History.");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x44, 0xa7, 0x03 }, "Examples");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x48, 0x00, 0x00, 0x20, 0x01, 0x10, 0xc0, 0x84, 0x46, 0x03 }, "Government");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x40, 0x00, 0x00, 0x20, 0x95, 0xf6, 0x56, 0x85, 0x48, 0x12, 0x19, 0x5f }, "expressio");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x58, 0x00, 0x00, 0x20, 0x01, 0x10, 0xc1, 0x04, 0x27, 0x04 }, " Information");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x50, 0x00, 0x00, 0x20, 0x01, 0x10, 0xc0, 0x44, 0x37, 0x06 }, "In order to");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x50, 0x00, 0x00, 0x20, 0x01, 0x10, 0xc0, 0x84, 0xd6, 0x06 }, "One of the ");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x70, 0x00, 0x00, 0x20, 0x09, 0x62, 0xf6, 0x96, 0x83, 0x18, 0xa2, 0x49, 0x59, 0x27, 0xde, 0x37, 0xd9, 0x01 }, "large number of");
}

test "br minimal static dictionary numbers identity decodes Node quality-five frames" {
    // Full candidate probing showed that Node reuses the identity ` numbers`
    // tuple for several transformed candidate payloads (` numbers`, ` numbers `,
    // `  numbers`, and ` numbers.`). Pin the source tuple directly so future
    // full-probe runs do not regress on the shared frame prefix.
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x84, 0xa7, 0x06 }, " numbers");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x40, 0x00, 0x00, 0x20, 0x01, 0x52, 0x86, 0x28, 0x12, 0x1e, 0xb5 }, " numbers ");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x40, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8e, 0x84, 0xb7, 0x06 }, "  numbers");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x40, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x86, 0x28, 0x12, 0x1e, 0xb5 }, " numbers.");
}

test "br minimal static dictionary size winners decode Node quality-five frames" {
    // These entries are the first candidate-probe rows whose Node Brotli frames
    // are smaller than the original payload. Keep them pinned so size-winning
    // dictionary coverage remains tied to concrete encoder output.
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x80, 0x00, 0x00, 0x20, 0x01, 0x52, 0x8b, 0x20, 0x53, 0xd6, 0xc6, 0x77, 0x07 }, " large number of ");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x58, 0x00, 0x00, 0x20, 0x01, 0x12, 0xc8, 0x84, 0x54 }, " information");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x60, 0x00, 0x00, 0x20, 0x01, 0x12, 0xc9, 0x04, 0x47, 0x04 }, "  Information");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x80, 0x00, 0x00, 0x20, 0x01, 0x92, 0x83, 0x28, 0x82, 0x4c, 0x59, 0x1b, 0xbe, 0x7a }, "large number of  ");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x50, 0x00, 0x00, 0x20, 0x01, 0x12, 0xc8, 0x04, 0xe5 }, " government");
}

test "br minimal static dictionary upstream1024 identity words decode leading-space Node frames" {
    // The upstream1024 [5120, 6144) probe first exposed these through
    // leading-space candidate payloads, but Node encodes the concrete frames as
    // one literal space followed by an identity static-dictionary word. Pinning
    // the actual source tuple keeps the decoder aligned with observed encoder
    // output instead of assuming a transform-equivalent address.
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x04, 0x14 }, " first");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x44, 0x04 }, " video");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x44, 0x14 }, " light");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x04 }, " world");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x14 }, " media");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x24 }, " white");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x34 }, " close");
}

test "br minimal static dictionary upstream2048 identity money decodes leading-space Node frame" {
    // The first upstream2048 incremental probe failure is another concrete
    // example where Node uses one literal space plus an identity dictionary
    // word rather than the transform-equivalent leading-space address.
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0xd5 }, " money");
}

test "br minimal static dictionary upstream2048 identity five-byte tail decodes leading-space Node frames" {
    // Node encoded these leading-space upstream2048 candidates as one literal
    // space followed by the corresponding 5-byte identity dictionary word.
    // Keeping the observed frames here prevents the generated-probe failures
    // from regressing while full dictionary import remains future work.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0x04 }, .expected = " black" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0x24 }, .expected = " small" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0x34 }, .expected = " books" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x04, 0x05 }, .expected = " place" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x04, 0x15 }, .expected = " music" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x04, 0x25 }, .expected = " field" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x04, 0x35 }, .expected = " order" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x04, 0x55 }, .expected = " value" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x04, 0x65 }, .expected = " level" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x04, 0x75 }, .expected = " table" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x44, 0x05 }, .expected = " board" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x44, 0x15 }, .expected = " house" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x44, 0x25 }, .expected = " group" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x44, 0x45 }, .expected = " years" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x44, 0x75 }, .expected = " water" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x05 }, .expected = " start" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x15 }, .expected = " style" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x25 }, .expected = " death" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x35 }, .expected = " power" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x45 }, .expected = " phone" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x55 }, .expected = " night" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x65 }, .expected = " error" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x75 }, .expected = " input" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0x95 }, .expected = " terms" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0xc5 }, .expected = " event" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0x84, 0xd5 }, .expected = " local" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0x25 }, .expected = " short" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0x35 }, .expected = " space" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0x45 }, .expected = " focus" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0x55 }, .expected = " clear" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0x75 }, .expected = " block" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0x85 }, .expected = " guide" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0x95 }, .expected = " radio" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0xa5 }, .expected = " share" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0xb5 }, .expected = " women" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8b, 0xc4, 0xc5 }, .expected = " again" },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
}

test "br minimal static dictionary upstream2048 identity six-byte tail decodes Node frames" {
    // The upstream2048 tail probe surfaced early 6-byte identity words. The
    // leading-space payloads again encode as one literal space plus these
    // identity source words, so each source tuple is pinned by both direct and
    // leading-space Node frames when Node emitted both forms.
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x04, 0x04 }, "&quot;");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x14 }, " &quot;");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x04, 0x14 }, "domain");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x04 }, " domain");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x44, 0x04 }, "common");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x14 }, " common");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0x14 }, "master");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x24 }, " master");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0x04 }, "banner");
    try expectBrStaticDictionaryFrame(&[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x14 }, " banner");
}

test "br minimal static dictionary upstream4096 identity six-byte first window decodes Node frames" {
    // The first source-limit 4096 probe window expands the 6-byte dictionary
    // slice substantially. Node often emits transform-equivalent payloads using
    // the identity source word, so this table pins every observed failing frame
    // from that window while the decoder still carries a reviewed subset rather
    // than the complete RFC dictionary.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0x14 }, .expected = "remove" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x24 }, .expected = " remove" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0x24 }, .expected = "scroll" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x34 }, .expected = " scroll" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0x34 }, .expected = "update" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x05 }, .expected = " update" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x04, 0x05 }, .expected = "global" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x15 }, .expected = " global" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x04, 0x25 }, .expected = "filter" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x35 }, .expected = " filter" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x04, 0x45 }, .expected = "change" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x55 }, .expected = " change" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x04, 0x55 }, .expected = "result" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x65 }, .expected = " result" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x04, 0x75 }, .expected = "screen" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x05 }, .expected = " screen" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x44, 0x05 }, .expected = "choose" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x15 }, .expected = " choose" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x44, 0x15 }, .expected = "normal" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x25 }, .expected = " normal" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x44, 0x25 }, .expected = "travel" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x35 }, .expected = " travel" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x44, 0x35 }, .expected = "issues" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x45 }, .expected = " issues" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x28, 0x04 }, .expected = " target" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x44, 0x65 }, .expected = "spring" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x75 }, .expected = " spring" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x44, 0x75 }, .expected = "module" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x05 }, .expected = " module" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0x05 }, .expected = "mobile" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x15 }, .expected = " mobile" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0x15 }, .expected = "switch" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x25 }, .expected = " switch" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0x25 }, .expected = "photos" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x35 }, .expected = " photos" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0x45 }, .expected = "region" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x55 }, .expected = " region" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0x55 }, .expected = "itself" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x65 }, .expected = " itself" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0x65 }, .expected = "social" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x75 }, .expected = " social" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x28, 0x11 }, .expected = " active" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0x85 }, .expected = "column" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x95 }, .expected = " column" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0x95 }, .expected = "record" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa5 }, .expected = " record" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0xa5 }, .expected = "follow" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xb5 }, .expected = " follow" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0xb5 }, .expected = "title>" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xc5 }, .expected = " title>" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x98, 0x0f }, .expected = "either " },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0xd5 }, .expected = "length" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe5 }, .expected = " length" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0xe5 }, .expected = "family" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xf5 }, .expected = " family" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0x84, 0xf5 }, .expected = "friend" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x05 }, .expected = " friend" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0x05 }, .expected = "layout" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x15 }, .expected = " layout" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0x15 }, .expected = "author" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x25 }, .expected = " author" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0x35 }, .expected = "review" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x45 }, .expected = " review" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0x55 }, .expected = "server" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x65 }, .expected = " server" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0x75 }, .expected = "player" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x85 }, .expected = " player" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0x85 }, .expected = "expand" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x95 }, .expected = " expand" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x48, 0x18 }, .expected = "policy." },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0xb5 }, .expected = "double" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc5 }, .expected = " double" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0xd5 }, .expected = "series" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xe5 }, .expected = " series" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0xe5 }, .expected = "person" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf5 }, .expected = " person" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0x01, 0x10, 0x84, 0xc4, 0xf5 }, .expected = "living" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x06, 0x00 }, .expected = " living" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x16, 0x00 }, .expected = " design" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x46, 0x00 }, .expected = " unique" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x56, 0x00 }, .expected = " weight" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x66, 0x00 }, .expected = " people" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x76, 0x00 }, .expected = " energy" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x86, 0x00 }, .expected = " nature" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x96, 0x00 }, .expected = " search" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa6, 0x00 }, .expected = " figure" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x08, 0x11 }, .expected = "having " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc6, 0x00 }, .expected = " custom" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd6, 0x00 }, .expected = " offset" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x08, 0x0a }, .expected = " window" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x05 }, .expected = "window." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x06, 0x01 }, .expected = " submit" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x16, 0x01 }, .expected = " render" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xf8, 0x0f }, .expected = " groups" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x36, 0x01 }, .expected = " upload" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x46, 0x01 }, .expected = " health" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x56, 0x01 }, .expected = " method" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x86, 0x01 }, .expected = " future" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x96, 0x01 }, .expected = " shadow" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa6, 0x01 }, .expected = " debate" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc6, 0x01 }, .expected = " Object" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf6, 0x01 }, .expected = " league" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x06, 0x00 }, .expected = " chrome" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x28, 0x0a }, .expected = " simple" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x26, 0x00 }, .expected = " notice" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x46, 0x00 }, .expected = " ending" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x56, 0x00 }, .expected = " season" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x66, 0x00 }, .expected = " report" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x76, 0x00 }, .expected = " online" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x86, 0x00 }, .expected = " square" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x96, 0x00 }, .expected = " button" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb6, 0x00 }, .expected = " enable" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd6, 0x00 }, .expected = " latest" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x06, 0x01 }, .expected = " period" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x26, 0x01 }, .expected = " repeat" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x36, 0x01 }, .expected = " London" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x66, 0x01 }, .expected = " demand" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x76, 0x01 }, .expected = " secure" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x96, 0x01 }, .expected = " toggle" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb6, 0x01 }, .expected = " device" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc6, 0x01 }, .expected = " static" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd6, 0x01 }, .expected = " cities" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe6, 0x01 }, .expected = " stream" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf6, 0x01 }, .expected = " yellow" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x06, 0x00 }, .expected = " attack" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x26, 0x00 }, .expected = " flight" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x36, 0x00 }, .expected = " hidden" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x46, 0x00 }, .expected = " info\">" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x66, 0x00 }, .expected = " useful" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x86, 0x00 }, .expected = " causes" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x96, 0x00 }, .expected = " leader" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa6, 0x00 }, .expected = " secret" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xb6, 0x00 }, .expected = " second" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe6, 0x00 }, .expected = " except" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xf6, 0x00 }, .expected = " rating" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x26, 0x01 }, .expected = " effect" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x56, 0x01 }, .expected = " office" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x66, 0x01 }, .expected = " visual" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x76, 0x01 }, .expected = " editor" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x86, 0x01 }, .expected = " volume" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x96, 0x01 }, .expected = " Report" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa6, 0x01 }, .expected = " museum" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xc6, 0x01 }, .expected = " parent" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xd6, 0x01 }, .expected = " access" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe6, 0x01 }, .expected = " mostly" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x06, 0x02 }, .expected = " \" id=\"" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x58, 0x00 }, .expected = " market" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x46, 0x02 }, .expected = " survey" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x56, 0x02 }, .expected = " before" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x66, 0x02 }, .expected = " symbol" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x76, 0x02 }, .expected = " moment" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x96, 0x02 }, .expected = " motion" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa6, 0x02 }, .expected = " inside" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xc6, 0x02 }, .expected = " Center" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xd8, 0x11 }, .expected = " object" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe6, 0x02 }, .expected = " exists" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xf6, 0x02 }, .expected = " middle" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x06, 0x03 }, .expected = " Europe" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x26, 0x03 }, .expected = " legacy" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x36, 0x03 }, .expected = " manner" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x46, 0x03 }, .expected = " enough" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x66, 0x03 }, .expected = " answer" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x76, 0x03 }, .expected = " origin" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x86, 0x03 }, .expected = " portal" },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
}

test "br minimal static dictionary upstream4096 identity second window decodes Node frames" {
    // Continuation of the source-limit 4096 probe: these frames from the next
    // candidate window again resolve to identity source tuples, including some
    // 7-byte words selected by Node for transform-equivalent 6-byte payloads.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x28, 0x0c }, .expected = "called " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x56, 0x01 }, .expected = " silver" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x66, 0x01 }, .expected = " margin" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x76, 0x01 }, .expected = " delete" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0xe8, 0x09 }, .expected = "better " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xb6, 0x01 }, .expected = " Global" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xd6, 0x01 }, .expected = " widget" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x38, 0x07 }, .expected = " center" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf6, 0x01 }, .expected = " budget" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x06, 0x02 }, .expected = " nowrap" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x16, 0x02 }, .expected = " credit" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x36, 0x02 }, .expected = " engine" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x46, 0x02 }, .expected = " safety" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x66, 0x02 }, .expected = " spirit" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x76, 0x02 }, .expected = " -style" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x86, 0x02 }, .expected = " spread" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x96, 0x02 }, .expected = " making" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xb6, 0x02 }, .expected = " russia" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc6, 0x02 }, .expected = " please" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xe6, 0x02 }, .expected = " Script" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf6, 0x02 }, .expected = " broken" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x26, 0x03 }, .expected = " divide" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x46, 0x03 }, .expected = " member" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x56, 0x03 }, .expected = " -based" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x66, 0x03 }, .expected = " theory" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x76, 0x03 }, .expected = " config" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0xd8, 0x14 }, .expected = "around " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc6, 0x03 }, .expected = " impact" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xd6, 0x03 }, .expected = " should" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xe6, 0x03 }, .expected = " always" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x17, 0x00 }, .expected = " list\">" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x27, 0x00 }, .expected = " ){var " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x37, 0x00 }, .expected = " prefix" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x47, 0x00 }, .expected = " orange" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x57, 0x00 }, .expected = " Header" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x67, 0x00 }, .expected = " .push(" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x77, 0x00 }, .expected = " couple" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x87, 0x00 }, .expected = " garden" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x97, 0x00 }, .expected = " bridge" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa7, 0x00 }, .expected = " launch" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb7, 0x00 }, .expected = " Review" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc7, 0x00 }, .expected = " taking" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe7, 0x00 }, .expected = " little" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf7, 0x00 }, .expected = " dating" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x07, 0x01 }, .expected = " Button" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x17, 0x01 }, .expected = " beauty" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x37, 0x01 }, .expected = " forgot" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xb8, 0x19 }, .expected = " Search" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x57, 0x01 }, .expected = " anchor" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x67, 0x01 }, .expected = " almost" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x87, 0x01 }, .expected = " Change" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xe7, 0x01 }, .expected = "return " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x77, 0x08 }, .expected = " return" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa7, 0x01 }, .expected = " string" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb7, 0x01 }, .expected = " reload" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0xf6, 0x01 }, .expected = "Mobile " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd7, 0x01 }, .expected = " income" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf7, 0x01 }, .expected = " Source" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xe8, 0x18 }, .expected = " &nbsp;" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x37, 0x02 }, .expected = " course" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x38, 0x1d }, .expected = " About " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x57, 0x02 }, .expected = " island" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x67, 0x02 }, .expected = " <html " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x77, 0x02 }, .expected = " cookie" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x97, 0x02 }, .expected = " amazon" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa7, 0x02 }, .expected = " modern" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb7, 0x02 }, .expected = " advice" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc7, 0x02 }, .expected = " in</a>" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd7, 0x02 }, .expected = " : The " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe7, 0x02 }, .expected = " dialog" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x07, 0x03 }, .expected = " BEGIN " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x17, 0x03 }, .expected = " Mexico" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x88, 0x08 }, .expected = "height " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x57, 0x03 }, .expected = " adding" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x77, 0x03 }, .expected = " assets" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x87, 0x03 }, .expected = " Empire" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x97, 0x03 }, .expected = " School" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa7, 0x03 }, .expected = " effort" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb7, 0x03 }, .expected = " direct" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc7, 0x03 }, .expected = " nearly" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd7, 0x03 }, .expected = " manual" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe7, 0x03 }, .expected = " Select" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf7, 0x03 }, .expected = " .\n\nOne" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x37, 0x04 }, .expected = " awards" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x47, 0x04 }, .expected = " handle" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x57, 0x04 }, .expected = " import" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x58, 0x14 }, .expected = "Office " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x77, 0x04 }, .expected = " regard" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x87, 0x04 }, .expected = " skills" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x97, 0x04 }, .expected = " nation" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa7, 0x04 }, .expected = " Sports" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb7, 0x04 }, .expected = " degree" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc7, 0x04 }, .expected = " weekly" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd7, 0x04 }, .expected = "  (e.g." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe7, 0x04 }, .expected = " behind" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf7, 0x04 }, .expected = " doctor" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x07, 0x05 }, .expected = " logged" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x17, 0x05 }, .expected = " united" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x27, 0x05 }, .expected = " </b></" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x97, 0x05 }, .expected = " canada" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc7, 0x05 }, .expected = " remain" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd7, 0x05 }, .expected = " Brazil" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe7, 0x05 }, .expected = " sample" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf7, 0x05 }, .expected = " logo\">" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x07, 0x06 }, .expected = " beyond" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x17, 0x06 }, .expected = " -scale" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x57, 0x06 }, .expected = " Footer" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x67, 0x06 }, .expected = " camera" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x87, 0x06 }, .expected = " _form\"" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb7, 0x06 }, .expected = " \" />\r\n" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc7, 0x06 }, .expected = " .gif\" " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd7, 0x06 }, .expected = " onload" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x37, 0x07 }, .expected = " female" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x47, 0x07 }, .expected = " Design" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x98, 0x18 }, .expected = " size=\"" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x77, 0x07 }, .expected = " text\">" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x97, 0x07 }, .expected = " thanks" },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
}

test "br minimal static dictionary upstream4096 identity third window decodes Node frames" {
    // Third source-limit 4096 probe window. These observed Node frames continue
    // to resolve to identity source tuples, with a few 7-byte alternatives for
    // transform-equivalent 6-byte payloads. Pinning the frames keeps the manual
    // subset honest until the full static dictionary is imported.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x17, 0x01 }, .expected = " estate" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x37, 0x01 }, .expected = " email\"" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x87, 0x01 }, .expected = " 1.html" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x97, 0x01 }, .expected = " signup" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb7, 0x01 }, .expected = " float:" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd7, 0x01 }, .expected = " forum." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe7, 0x01 }, .expected = " Access" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x17, 0x02 }, .expected = " extend" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x27, 0x02 }, .expected = " Height" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x47, 0x02 }, .expected = " UTF-8\"" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xc6, 0x02 }, .expected = " &amp; " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x67, 0x02 }, .expected = " Before" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x77, 0x02 }, .expected = " . With" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x87, 0x02 }, .expected = " studio" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd7, 0x02 }, .expected = " annual" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf7, 0x02 }, .expected = " bought" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0xe7, 0x0f }, .expected = "famous " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x17, 0x03 }, .expected = " google" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x37, 0x03 }, .expected = " i++) {" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x47, 0x03 }, .expected = " israel" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x57, 0x03 }, .expected = " saying" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x97, 0x03 }, .expected = " ensure" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe7, 0x03 }, .expected = " top\"><" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf7, 0x03 }, .expected = " racing" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x07, 0x04 }, .expected = " resize" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x17, 0x04 }, .expected = " --&gt;" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x27, 0x04 }, .expected = " pacity" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x47, 0x04 }, .expected = " bureau" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x57, 0x04 }, .expected = " .jpg\" " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x67, 0x04 }, .expected = " 10,000" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x77, 0x04 }, .expected = " obtain" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x97, 0x04 }, .expected = " amount" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa7, 0x04 }, .expected = " , Inc." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb7, 0x04 }, .expected = " comedy" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd7, 0x04 }, .expected = " lyrics" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x17, 0x05 }, .expected = " _logo." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x27, 0x05 }, .expected = " Family" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x47, 0x05 }, .expected = " Market" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x57, 0x05 }, .expected = " lse if" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x67, 0x05 }, .expected = " Player" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x77, 0x05 }, .expected = " turkey" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x87, 0x05 }, .expected = " );var " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x18, 0x0b }, .expected = "giving " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc7, 0x05 }, .expected = " Domain" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd7, 0x05 }, .expected = " }else{" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe7, 0x05 }, .expected = " insert" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf7, 0x05 }, .expected = " Blog</" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x07, 0x06 }, .expected = " footer" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x27, 0x06 }, .expected = " faster" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x47, 0x06 }, .expected = " <body " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x57, 0x06 }, .expected = " 10px 0" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x67, 0x06 }, .expected = " pragma" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x77, 0x06 }, .expected = " friday" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x87, 0x06 }, .expected = " junior" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x97, 0x06 }, .expected = " dollar" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd7, 0x06 }, .expected = " 5,000 " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf7, 0x06 }, .expected = " boston" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x07, 0x07 }, .expected = " .test(" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x17, 0x07 }, .expected = " avatar" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x37, 0x07 }, .expected = " _count" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x57, 0x07 }, .expected = " schema" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x77, 0x07 }, .expected = " filled" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa7, 0x07 }, .expected = " alert(" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb7, 0x07 }, .expected = " appear" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc7, 0x07 }, .expected = " Submit" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd7, 0x07 }, .expected = " line\">" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe7, 0x07 }, .expected = " body\">" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf7, 0x07 }, .expected = " \n* The" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x07, 0x00 }, .expected = " Though" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x17, 0x00 }, .expected = " seeing" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x27, 0x00 }, .expected = " jersey" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x47, 0x00 }, .expected = " verify" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x67, 0x00 }, .expected = " injury" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x97, 0x0e }, .expected = " width=" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x87, 0x00 }, .expected = " Cookie" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x97, 0x00 }, .expected = " START " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xb7, 0x00 }, .expected = " _image" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xc7, 0x00 }, .expected = " thread" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe7, 0x00 }, .expected = " pocket" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x28, 0x0a }, .expected = " System" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x17, 0x01 }, .expected = "  David" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x27, 0x01 }, .expected = " cancer" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x57, 0x01 }, .expected = " April " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x98, 0x13 }, .expected = "really " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x87, 0x01 }, .expected = " item\">" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x97, 0x01 }, .expected = " more\">" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x07, 0x02 }, .expected = " guitar" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x17, 0x02 }, .expected = " finish" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x47, 0x00 }, .expected = " Other " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x67, 0x02 }, .expected = " assume" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x87, 0x02 }, .expected = " wilson" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa7, 0x02 }, .expected = " relief" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xb7, 0x02 }, .expected = " sweden" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xc7, 0x02 }, .expected = " Custom" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xd7, 0x02 }, .expected = " easily" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe7, 0x02 }, .expected = "  your " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x07, 0x03 }, .expected = " \n\nWhil" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x17, 0x03 }, .expected = " taylor" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x37, 0x03 }, .expected = " resort" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x47, 0x03 }, .expected = " french" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x57, 0x03 }, .expected = " though" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x67, 0x03 }, .expected = " \") + \"" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x87, 0x03 }, .expected = " buying" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa7, 0x03 }, .expected = " Member" },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
}

test "br minimal static dictionary upstream4096 identity fourth window decodes Node frames" {
    // Fourth source-limit 4096 probe window. This slice reaches later 6-byte
    // dictionary words, including non-ASCII entries, and continues to validate
    // the actual identity addresses selected by Node for transformed payloads.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x07, 0x05 }, .expected = " Polski" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x17, 0x05 }, .expected = " -color" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x27, 0x05 }, .expected = " jordan" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x37, 0x05 }, .expected = " Bottom" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x47, 0x05 }, .expected = " Start " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x57, 0x05 }, .expected = " -count" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x67, 0x05 }, .expected = " 2.html" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x87, 0x05 }, .expected = " 01.jpg" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xd7, 0x04 }, .expected = "Online " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x28, 0x16 }, .expected = " Online" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0xd1, 0x12, 0x8b, 0xc4, 0x14 }, .expected = "-right" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x05, 0xd2, 0x12, 0x93, 0xc4, 0xa4 }, .expected = " -right" },
        .{ .encoded = &[_]u8{ 0xa1, 0x28, 0x00, 0x00, 0x20, 0xd1, 0x12, 0x8b, 0xc4, 0x14 }, .expected = "-right" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xc7, 0x05 }, .expected = " senior" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x17, 0x06 }, .expected = " ection" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x27, 0x06 }, .expected = " repair" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x37, 0x06 }, .expected = " .xml\" " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x47, 0x06 }, .expected = "  right" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x57, 0x06 }, .expected = " s.html" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x67, 0x06 }, .expected = " -block" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x77, 0x06 }, .expected = " regExp" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa7, 0x06 }, .expected = " virgin" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xd7, 0x06 }, .expected = " using " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe7, 0x06 }, .expected = " \n\tvar " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xf7, 0x06 }, .expected = " >');\n\t" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x27, 0x07 }, .expected = " bahasa" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x37, 0x07 }, .expected = " brasil" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x47, 0x07 }, .expected = " galego" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x57, 0x07 }, .expected = " magyar" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x67, 0x07 }, .expected = " polski" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x77, 0x07 }, .expected = " srpski" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x87, 0x07 }, .expected = " \xd8\xb1\xd8\xaf\xd9\x88" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x97, 0x07 }, .expected = " \xe4\xb8\xad\xe6\x96\x87" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa7, 0x07 }, .expected = " \xe7\xae\x80\xe4\xbd\x93" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xb7, 0x07 }, .expected = " \xe7\xb9\x81\xe9\xab\x94" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xc7, 0x07 }, .expected = " \xe4\xbf\xa1\xe6\x81\xaf" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe7, 0x07 }, .expected = " \xe6\x88\x91\xe4\xbb\xac" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xf7, 0x07 }, .expected = " \xe4\xb8\x80\xe4\xb8\xaa" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x07, 0x08 }, .expected = " \xe5\x85\xac\xe5\x8f\xb8" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x17, 0x08 }, .expected = " \xe7\xae\xa1\xe7\x90\x86" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x27, 0x08 }, .expected = " \xe8\xae\xba\xe5\x9d\x9b" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x57, 0x08 }, .expected = " \xe6\x97\xb6\xe9\x97\xb4" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x67, 0x08 }, .expected = " \xe4\xb8\xaa\xe4\xba\xba" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x77, 0x08 }, .expected = " \xe4\xba\xa7\xe5\x93\x81" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x87, 0x08 }, .expected = " \xe8\x87\xaa\xe5\xb7\xb1" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x97, 0x08 }, .expected = " \xe4\xbc\x81\xe4\xb8\x9a" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa7, 0x08 }, .expected = " \xe6\x9f\xa5\xe7\x9c\x8b" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xb7, 0x08 }, .expected = " \xe5\xb7\xa5\xe4\xbd\x9c" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xc7, 0x08 }, .expected = " \xe8\x81\x94\xe7\xb3\xbb" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xd7, 0x08 }, .expected = " \xe6\xb2\xa1\xe6\x9c\x89" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe7, 0x08 }, .expected = " \xe7\xbd\x91\xe7\xab\x99" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xf7, 0x08 }, .expected = " \xe6\x89\x80\xe6\x9c\x89" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x17, 0x09 }, .expected = " \xe4\xb8\xad\xe5\xbf\x83" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x27, 0x09 }, .expected = " \xe6\x96\x87\xe7\xab\xa0" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x37, 0x09 }, .expected = " \xe7\x94\xa8\xe6\x88\xb7" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x57, 0x09 }, .expected = " \xe4\xbd\x9c\xe8\x80\x85" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x77, 0x09 }, .expected = " \xe9\x97\xae\xe9\xa2\x98" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x87, 0x09 }, .expected = " \xe7\x9b\xb8\xe5\x85\xb3" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x97, 0x09 }, .expected = " \xe4\xb8\x8b\xe8\xbd\xbd" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xb7, 0x09 }, .expected = " \xe4\xbd\xbf\xe7\x94\xa8" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xd7, 0x09 }, .expected = " \xe5\x9c\xa8\xe7\xba\xbf" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xf7, 0x09 }, .expected = " \xe8\xb5\x84\xe6\x96\x99" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x07, 0x0a }, .expected = " \xe8\xa7\x86\xe9\xa2\x91" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x47, 0x0a }, .expected = " \xe6\x94\xb6\xe8\x97\x8f" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x57, 0x0a }, .expected = " \xe5\x86\x85\xe5\xae\xb9" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x77, 0x0a }, .expected = " \xe5\xb8\x82\xe5\x9c\xba" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x97, 0x0a }, .expected = " \xe7\xa9\xba\xe9\x97\xb4" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa7, 0x0a }, .expected = " \xe5\x8f\x91\xe5\xb8\x83" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xb7, 0x0a }, .expected = " \xe4\xbb\x80\xe4\xb9\x88" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xc7, 0x0a }, .expected = " \xe5\xa5\xbd\xe5\x8f\x8b" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xd7, 0x0a }, .expected = " \xe7\x94\x9f\xe6\xb4\xbb" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe7, 0x0a }, .expected = " \xe5\x9b\xbe\xe7\x89\x87" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x17, 0x0b }, .expected = " \xe6\x89\x8b\xe6\x9c\xba" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x27, 0x0b }, .expected = " \xe6\x96\xb0\xe9\x97\xbb" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x37, 0x0b }, .expected = " \xe6\x9c\x80\xe6\x96\xb0" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x47, 0x0b }, .expected = " \xe6\x96\xb9\xe5\xbc\x8f" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x57, 0x0b }, .expected = " \xe5\x8c\x97\xe4\xba\xac" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x67, 0x0b }, .expected = " \xe6\x8f\x90\xe4\xbe\x9b" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x77, 0x0b }, .expected = " \xe5\x85\xb3\xe4\xba\x8e" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x87, 0x0b }, .expected = " \xe6\x9b\xb4\xe5\xa4\x9a" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x97, 0x0b }, .expected = " \xe8\xbf\x99\xe4\xb8\xaa" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xc7, 0x0b }, .expected = " \xe6\xb8\xb8\xe6\x88\x8f" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xd7, 0x0b }, .expected = " \xe5\xb9\xbf\xe5\x91\x8a" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe7, 0x0b }, .expected = " \xe5\x85\xb6\xe4\xbb\x96" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xf7, 0x0b }, .expected = " \xe5\x8f\x91\xe8\xa1\xa8" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x07, 0x0c }, .expected = " \xe5\xae\x89\xe5\x85\xa8" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x17, 0x0c }, .expected = " \xe7\xac\xac\xe4\xb8\x80" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x37, 0x0c }, .expected = " \xe8\xbf\x9b\xe8\xa1\x8c" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x47, 0x0c }, .expected = " \xe7\x82\xb9\xe5\x87\xbb" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x57, 0x0c }, .expected = " \xe7\x89\x88\xe6\x9d\x83" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x97, 0x0c }, .expected = " \xe5\x85\x8d\xe8\xb4\xb9" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa7, 0x0c }, .expected = " \xe6\x95\x99\xe8\x82\xb2" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xb7, 0x0c }, .expected = " \xe5\x8a\xa0\xe5\x85\xa5" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xc7, 0x0c }, .expected = " \xe6\xb4\xbb\xe5\x8a\xa8" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xd7, 0x0c }, .expected = " \xe4\xbb\x96\xe4\xbb\xac" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe7, 0x0c }, .expected = " \xe5\x95\x86\xe5\x93\x81" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xf7, 0x0c }, .expected = " \xe5\x8d\x9a\xe5\xae\xa2" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x07, 0x0d }, .expected = " \xe7\x8e\xb0\xe5\x9c\xa8" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x17, 0x0d }, .expected = " \xe4\xb8\x8a\xe6\xb5\xb7" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x37, 0x0d }, .expected = " \xe5\xb7\xb2\xe7\xbb\x8f" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x57, 0x0d }, .expected = " \xe8\xaf\xa6\xe7\xbb\x86" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x67, 0x0d }, .expected = " \xe7\xa4\xbe\xe5\x8c\xba" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x87, 0x0d }, .expected = " \xe6\x9c\xac\xe7\xab\x99" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x97, 0x0d }, .expected = " \xe9\x9c\x80\xe8\xa6\x81" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xc7, 0x0d }, .expected = " \xe5\x9b\xbd\xe9\x99\x85" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xd7, 0x0d }, .expected = " \xe9\x93\xbe\xe6\x8e\xa5" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xe7, 0x0d }, .expected = " \xe5\x9b\xbd\xe5\xae\xb6" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xf7, 0x0d }, .expected = " \xe5\xbb\xba\xe8\xae\xbe" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x07, 0x0e }, .expected = " \xe6\x9c\x8b\xe5\x8f\x8b" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x27, 0x0e }, .expected = " \xe6\xb3\x95\xe5\xbe\x8b" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x37, 0x0e }, .expected = " \xe4\xbd\x8d\xe7\xbd\xae" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x47, 0x0e }, .expected = " \xe7\xbb\x8f\xe6\xb5\x8e" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x57, 0x0e }, .expected = " \xe9\x80\x89\xe6\x8b\xa9" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x67, 0x0e }, .expected = " \xe8\xbf\x99\xe6\xa0\xb7" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x77, 0x0e }, .expected = " \xe5\xbd\x93\xe5\x89\x8d" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x97, 0x0e }, .expected = " \xe6\x8e\x92\xe8\xa1\x8c" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa7, 0x0e }, .expected = " \xe5\x9b\xa0\xe4\xb8\xba" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xd7, 0x0e }, .expected = " \xe9\x9f\xb3\xe4\xb9\x90" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x07, 0x0f }, .expected = " \xe8\xa1\x8c\xe4\xb8\x9a" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x17, 0x0f }, .expected = " \xe7\xa7\x91\xe6\x8a\x80" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x27, 0x0f }, .expected = " \xe5\x8f\xaf\xe8\x83\xbd" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x47, 0x0f }, .expected = " \xe5\x90\x88\xe4\xbd\x9c" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x67, 0x0f }, .expected = " \xe7\xa4\xbe\xe4\xbc\x9a" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x77, 0x0f }, .expected = " \xe7\xa0\x94\xe7\xa9\xb6" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x87, 0x0f }, .expected = " \xe4\xb8\x93\xe4\xb8\x9a" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x97, 0x0f }, .expected = " \xe5\x85\xa8\xe9\x83\xa8" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0xa7, 0x0f }, .expected = " \xe9\xa1\xb9\xe7\x9b\xae" },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
}

test "br minimal static dictionary upstream4096 identity fifth window decodes Node frames" {
    // Fifth source-limit 4096 probe window. This slice is mostly CJK 6-byte
    // words, with Node again selecting identity addresses for leading-space
    // transformed payloads.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x57, 0x01 }, .expected = " 招聘" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x67, 0x01 }, .expected = " 声明" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x77, 0x01 }, .expected = " 任何" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x87, 0x01 }, .expected = " 健康" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x97, 0x01 }, .expected = " 数据" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xb7, 0x01 }, .expected = " 汽车" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc7, 0x01 }, .expected = " 介绍" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xd7, 0x01 }, .expected = " 但是" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf7, 0x01 }, .expected = " 生产" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x07, 0x02 }, .expected = " 所以" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x27, 0x02 }, .expected = " 显示" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x47, 0x02 }, .expected = " 单位" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x67, 0x02 }, .expected = " 分析" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x87, 0x02 }, .expected = " 旅游" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x97, 0x02 }, .expected = " 工具" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xa7, 0x02 }, .expected = " 学生" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xb7, 0x02 }, .expected = " 系列" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc7, 0x02 }, .expected = " 网友" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf7, 0x02 }, .expected = " 频道" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x47, 0x03 }, .expected = " 网上" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x77, 0x03 }, .expected = " 喜欢" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x87, 0x03 }, .expected = " 进入" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x97, 0x03 }, .expected = " 友情" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc7, 0x03 }, .expected = " 发现" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xd7, 0x03 }, .expected = " 培训" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xe7, 0x03 }, .expected = " 以上" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf7, 0x03 }, .expected = " 政府" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x07, 0x04 }, .expected = " 成为" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x17, 0x04 }, .expected = " 环境" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x37, 0x04 }, .expected = " 同时" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x47, 0x04 }, .expected = " 娱乐" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x57, 0x04 }, .expected = " 发送" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x67, 0x04 }, .expected = " 一定" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x77, 0x04 }, .expected = " 开发" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x87, 0x04 }, .expected = " 作品" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x97, 0x04 }, .expected = " 标准" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xa7, 0x04 }, .expected = " 欢迎" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc7, 0x04 }, .expected = " 地方" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xe7, 0x04 }, .expected = " 以及" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x07, 0x05 }, .expected = " 或者" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x37, 0x05 }, .expected = " 积分" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x47, 0x05 }, .expected = " 女人" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x57, 0x05 }, .expected = " 数码" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x67, 0x05 }, .expected = " 销售" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x87, 0x05 }, .expected = " 离线" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xa7, 0x05 }, .expected = " 列表" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc7, 0x05 }, .expected = " 编辑" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xd7, 0x05 }, .expected = " 统计" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xe7, 0x05 }, .expected = " 查询" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf7, 0x05 }, .expected = " 不要" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x07, 0x06 }, .expected = " 有关" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x17, 0x06 }, .expected = " 机构" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x27, 0x06 }, .expected = " 很多" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x37, 0x06 }, .expected = " 播放" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x47, 0x06 }, .expected = " 组织" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x57, 0x06 }, .expected = " 政策" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x67, 0x06 }, .expected = " 直接" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x77, 0x06 }, .expected = " 能力" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x87, 0x06 }, .expected = " 来源" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x97, 0x06 }, .expected = " 時間" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xa7, 0x06 }, .expected = " 看到" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xb7, 0x06 }, .expected = " 热门" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc7, 0x06 }, .expected = " 关键" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xd7, 0x06 }, .expected = " 专区" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xe7, 0x06 }, .expected = " 非常" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf7, 0x06 }, .expected = " 英语" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x37, 0x07 }, .expected = " 比较" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x47, 0x07 }, .expected = " 知识" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x57, 0x07 }, .expected = " 规定" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x77, 0x07 }, .expected = " 部门" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x87, 0x07 }, .expected = " 意见" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xa7, 0x07 }, .expected = " 日本" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xb7, 0x07 }, .expected = " 提高" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xd7, 0x07 }, .expected = " 方面" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf7, 0x07 }, .expected = " 处理" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x17, 0x08 }, .expected = " 影片" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x27, 0x08 }, .expected = " 银行" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x47, 0x08 }, .expected = " 分享" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x57, 0x08 }, .expected = " 物品" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x67, 0x08 }, .expected = " 经营" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x77, 0x08 }, .expected = " 添加" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x97, 0x08 }, .expected = " 这种" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xa7, 0x08 }, .expected = " 话题" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xb7, 0x08 }, .expected = " 起来" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc7, 0x08 }, .expected = " 业务" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xe7, 0x08 }, .expected = " 记录" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x07, 0x09 }, .expected = " 质量" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x17, 0x09 }, .expected = " 男人" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x37, 0x09 }, .expected = " 引用" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x47, 0x09 }, .expected = " 报告" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x67, 0x09 }, .expected = " 快速" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x77, 0x09 }, .expected = " 咨询" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x97, 0x09 }, .expected = " 注意" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xa7, 0x09 }, .expected = " 申请" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xb7, 0x09 }, .expected = " 学校" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc7, 0x09 }, .expected = " 应该" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xd7, 0x09 }, .expected = " 历史" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xe7, 0x09 }, .expected = " 只是" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf7, 0x09 }, .expected = " 返回" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x07, 0x0a }, .expected = " 购买" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x17, 0x0a }, .expected = " 名称" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x27, 0x0a }, .expected = " 为了" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x37, 0x0a }, .expected = " 成功" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x57, 0x0a }, .expected = " 供应" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x67, 0x0a }, .expected = " 孩子" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x77, 0x0a }, .expected = " 专题" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xa7, 0x0a }, .expected = " 會員" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc7, 0x0a }, .expected = " 其它" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xd7, 0x0a }, .expected = " 保护" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xe7, 0x0a }, .expected = " 而且" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf7, 0x0a }, .expected = " 今天" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x07, 0x0b }, .expected = " 窗口" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x17, 0x0b }, .expected = " 动态" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x27, 0x0b }, .expected = " 状态" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x37, 0x0b }, .expected = " 特别" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x47, 0x0b }, .expected = " 认为" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x57, 0x0b }, .expected = " 必须" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x67, 0x0b }, .expected = " 更新" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x77, 0x0b }, .expected = " 小说" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x87, 0x0b }, .expected = " 我們" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x97, 0x0b }, .expected = " 作为" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xa7, 0x0b }, .expected = " 媒体" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xb7, 0x0b }, .expected = " 包括" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xd7, 0x0b }, .expected = " 一样" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf7, 0x0b }, .expected = " 是否" },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
}

test "br minimal static dictionary upstream4096 identity sixth window decodes Node frames" {
    // Sixth source-limit 4096 probe window. The observed Node frames continue
    // the CJK-heavy 6-byte identity slice selected for leading-space payloads.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xa7, 0x0d }, .expected = " 艺术" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xd7, 0x0d }, .expected = " 真的" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x17, 0x0e }, .expected = " 经验" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x37, 0x0e }, .expected = " 制作" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x47, 0x0e }, .expected = " 来自" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x57, 0x0e }, .expected = " 标签" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x87, 0x0e }, .expected = " 无法" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xa7, 0x0e }, .expected = " 個人" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xc7, 0x0e }, .expected = " 指南" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xe7, 0x0e }, .expected = " 集团" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x07, 0x0f }, .expected = " 关注" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x17, 0x0f }, .expected = " 因此" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x27, 0x0f }, .expected = " 照片" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x47, 0x0f }, .expected = " 商业" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x87, 0x0f }, .expected = " 最近" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0x97, 0x0f }, .expected = " 综合" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xa7, 0x0f }, .expected = " 表示" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xb7, 0x0f }, .expected = " 专辑" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xd7, 0x0f }, .expected = " 交通" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xe7, 0x0f }, .expected = " 评价" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0xc4, 0xf7, 0x0f }, .expected = " 觉得" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x00 }, .expected = " 感觉" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x00 }, .expected = " 得到" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x00 }, .expected = " 邮件" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x00 }, .expected = " 食品" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x00 }, .expected = " 虽然" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x00 }, .expected = " 转载" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x00 }, .expected = " 报价" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x00 }, .expected = " 记者" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x00 }, .expected = " 行政" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x00 }, .expected = " 人民" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x01 }, .expected = " 用品" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x01 }, .expected = " 东西" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x01 }, .expected = " 提出" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x01 }, .expected = " 酒店" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x01 }, .expected = " 付款" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x01 }, .expected = " 完全" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x01 }, .expected = " 设置" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x01 }, .expected = " 医院" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x01 }, .expected = " 看看" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x01 }, .expected = " 经典" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x02 }, .expected = " 平台" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x02 }, .expected = " 增加" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x02 }, .expected = " 材料" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x02 }, .expected = " 新增" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x02 }, .expected = " 之后" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x02 }, .expected = " 职业" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x02 }, .expected = " 效果" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x02 }, .expected = " 论文" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x02 }, .expected = " 版主" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x02 }, .expected = " 修改" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x02 }, .expected = " 参与" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x03 }, .expected = " 快乐" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x03 }, .expected = " 观点" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x03 }, .expected = " 存在" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x03 }, .expected = " 精神" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x03 }, .expected = " 获得" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x03 }, .expected = " 利用" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x03 }, .expected = " 继续" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x03 }, .expected = " 模式" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x03 }, .expected = " 语言" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x03 }, .expected = " 雅虎" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x03 }, .expected = " 操作" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x04 }, .expected = " 风格" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x04 }, .expected = " 科学" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x04 }, .expected = " 体育" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x04 }, .expected = " 短信" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x04 }, .expected = " 条件" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x04 }, .expected = " 治疗" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x04 }, .expected = " 运动" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x04 }, .expected = " 产业" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x04 }, .expected = " 导航" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x04 }, .expected = " 先生" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x04 }, .expected = " 可是" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x04 }, .expected = " 問題" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x04 }, .expected = " 结构" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x05 }, .expected = " 作用" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x05 }, .expected = " 调查" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x05 }, .expected = " 資料" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x05 }, .expected = " 负责" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x05 }, .expected = " 访问" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x05 }, .expected = " 接受" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x05 }, .expected = " 讨论" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x05 }, .expected = " 反馈" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x05 }, .expected = " 范围" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x05 }, .expected = " 服務" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x06 }, .expected = " 休闲" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x06 }, .expected = " 今日" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x06 }, .expected = " 客服" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x06 }, .expected = " 觀看" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x06 }, .expected = " 参加" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x06 }, .expected = " 图书" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x06 }, .expected = " 测试" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x06 }, .expected = " 才能" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x06 }, .expected = " 决定" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x06 }, .expected = " 股票" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x06 }, .expected = " 不断" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x07 }, .expected = " 需求" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x07 }, .expected = " 办法" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x07 }, .expected = " 采用" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x07 }, .expected = " 营销" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x07 }, .expected = " 目标" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x07 }, .expected = " 爱情" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x07 }, .expected = " 摄影" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x07 }, .expected = " 複製" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x07 }, .expected = " 机会" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x07 }, .expected = " 数字" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x07 }, .expected = " 装修" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x08 }, .expected = " 农村" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x08 }, .expected = " 精品" },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
}

test "br minimal static dictionary upstream4096 identity seventh window decodes Node frames" {
    // Seventh source-limit 4096 probe window. This continues the CJK-heavy
    // 6-byte identity slice for leading-space payloads.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x0a }, .expected = " 简单" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x0a }, .expected = " 删除" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x0a }, .expected = " 证券" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x0a }, .expected = " 节目" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x0a }, .expected = " 重点" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x0a }, .expected = " 次數" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x0a }, .expected = " 多少" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x0a }, .expected = " 找到" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x0b }, .expected = " 最佳" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x0b }, .expected = " 回答" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x0b }, .expected = " 天下" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x0b }, .expected = " 现代" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x0b }, .expected = " 检查" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x0b }, .expected = " 投票" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x0b }, .expected = " 小时" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x0b }, .expected = " 沒有" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x0b }, .expected = " 正常" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x0b }, .expected = " 甚至" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x0b }, .expected = " 代理" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x0c }, .expected = " 复制" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x0c }, .expected = " 金融" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x0c }, .expected = " 幸福" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x0c }, .expected = " 准备" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x0c }, .expected = " 回到" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x0c }, .expected = " 思想" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x0c }, .expected = " 怎样" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x0c }, .expected = " 协议" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x0c }, .expected = " 认证" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x0c }, .expected = " 最好" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x0c }, .expected = " 产生" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x0c }, .expected = " 按照" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x0c }, .expected = " 服装" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x0d }, .expected = " 广东" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x0d }, .expected = " 采购" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x0d }, .expected = " 组图" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x0d }, .expected = " 面板" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x0d }, .expected = " 参考" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x0d }, .expected = " 政治" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x0d }, .expected = " 容易" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x0d }, .expected = " 天地" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x0d }, .expected = " 努力" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x0d }, .expected = " 升级" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x0e }, .expected = " 流行" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x0e }, .expected = " 造成" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x0e }, .expected = " 文字" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x0e }, .expected = " 韩国" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x0e }, .expected = " 贸易" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x0e }, .expected = " 相關" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x0e }, .expected = " 影视" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x0e }, .expected = " 大小" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x0e }, .expected = " 报道" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x0e }, .expected = " 条款" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x0e }, .expected = " 许多" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x0f }, .expected = " 书店" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x0f }, .expected = " 连接" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x0f }, .expected = " 立即" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x0f }, .expected = " 举报" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x0f }, .expected = " 技巧" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x0f }, .expected = " 登入" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x0f }, .expected = " 以来" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x0f }, .expected = " 理论" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x0f }, .expected = " 事件" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x0f }, .expected = " 自由" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x0f }, .expected = " 办公" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x10 }, .expected = " 真正" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x10 }, .expected = " 不错" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x10 }, .expected = " 全文" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x10 }, .expected = " 合同" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x10 }, .expected = " 价值" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x10 }, .expected = " 别人" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x10 }, .expected = " 监督" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x10 }, .expected = " 具体" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x10 }, .expected = " 团队" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x10 }, .expected = " 创业" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x10 }, .expected = " 承担" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x10 }, .expected = " 增长" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x11 }, .expected = " 股份" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x11 }, .expected = " 实际" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x11 }, .expected = " 经理" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x11 }, .expected = " 生命" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x11 }, .expected = " 宣传" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x11 }, .expected = " 任务" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x11 }, .expected = " 特色" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x11 }, .expected = " 只能" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x12 }, .expected = " 重新" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x12 }, .expected = " 內容" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x12 }, .expected = " 运行" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x12 }, .expected = " 日志" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x12 }, .expected = " 賣家" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x12 }, .expected = " 超过" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x12 }, .expected = " 土地" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x12 }, .expected = " 支付" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x12 }, .expected = " 杭州" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x12 }, .expected = " 执行" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x12 }, .expected = " 制造" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x13 }, .expected = " 之一" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x13 }, .expected = " 推广" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x13 }, .expected = " 描述" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x13 }, .expected = " 变化" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x13 }, .expected = " 保险" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x13 }, .expected = " 医疗" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x13 }, .expected = " 过去" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x13 }, .expected = " 收入" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x13 }, .expected = " 杂志" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x14 }, .expected = " 美丽" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x14 }, .expected = " 最高" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x14 }, .expected = " 登陆" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x14 }, .expected = " 未来" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x14 }, .expected = " 教程" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x14 }, .expected = " 版块" },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
}

test "br minimal static dictionary upstream4096 identity eighth window decodes Node frames" {
    // Eighth source-limit 4096 probe window. This continues the 6-byte CJK
    // identity slice selected by Node for leading-space transformed payloads.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x15 }, .expected = " 宝贝" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x16 }, .expected = " 风险" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x16 }, .expected = " 授权" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x16 }, .expected = " 病毒" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x16 }, .expected = " 宠物" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x16 }, .expected = " 除了" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x16 }, .expected = " 評論" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x16 }, .expected = " 疾病" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x16 }, .expected = " 儿童" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x16 }, .expected = " 每天" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x16 }, .expected = " 每个" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x17 }, .expected = " 天津" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x17 }, .expected = " 字体" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x17 }, .expected = " 台灣" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x17 }, .expected = " 维护" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x17 }, .expected = " 个性" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x17 }, .expected = " 官方" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x17 }, .expected = " 常见" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x17 }, .expected = " 战略" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x17 }, .expected = " 应当" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x17 }, .expected = " 股市" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x17 }, .expected = " 房屋" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x18 }, .expected = " 栏目" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x18 }, .expected = " 员工" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x18 }, .expected = " 道具" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x18 }, .expected = " 结合" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x18 }, .expected = " 档案" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x18 }, .expected = " 劳动" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x18 }, .expected = " 另外" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x18 }, .expected = " 引起" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x18 }, .expected = " 說明" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x19 }, .expected = " 隐私" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x19 }, .expected = " 消费" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x19 }, .expected = " 共同" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x19 }, .expected = " 忘记" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x19 }, .expected = " 体系" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x19 }, .expected = " 带来" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x19 }, .expected = " 名字" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x19 }, .expected = " 發表" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x19 }, .expected = " 开放" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x19 }, .expected = " 加盟" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x19 }, .expected = " 受到" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x19 }, .expected = " 二手" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x19 }, .expected = " 大量" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x1a }, .expected = " 数量" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x1a }, .expected = " 共享" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x1a }, .expected = " 区域" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x1a }, .expected = " 女孩" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x1a }, .expected = " 通信" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x1a }, .expected = " 超级" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x1a }, .expected = " 配置" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x1a }, .expected = " 当时" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x1a }, .expected = " 优秀" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x1a }, .expected = " 性感" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x1a }, .expected = " 房产" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x1a }, .expected = " 遊戲" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x1b }, .expected = " 就业" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x1b }, .expected = " 保健" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x1b }, .expected = " 程度" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x1b }, .expected = " 参数" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x1b }, .expected = " 特殊" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x1b }, .expected = " 分類" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x1b }, .expected = " 属于" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x1b }, .expected = " 门户" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x1b }, .expected = " 声音" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x1c }, .expected = " 及其" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x1c }, .expected = " 财经" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x1c }, .expected = " 坚持" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x1c }, .expected = " 干部" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x1c }, .expected = " 成立" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x1c }, .expected = " 考虑" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x1c }, .expected = " 成都" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x1c }, .expected = " 包装" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x1c }, .expected = " 文明" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x1c }, .expected = " 招商" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x1c }, .expected = " 完整" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x1c }, .expected = " 眼睛" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x1d }, .expected = " 伙伴" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x1d }, .expected = " 威望" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x1d }, .expected = " 卫生" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x1d }, .expected = " 論壇" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x1d }, .expected = " 良好" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x1d }, .expected = " 充分" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x1d }, .expected = " 符合" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x1d }, .expected = " 附件" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x1d }, .expected = " 特点" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x1d }, .expected = " 不可" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x1d }, .expected = " 英文" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x1d }, .expected = " 资产" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x1d }, .expected = " 根本" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x1e }, .expected = " 密碼" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x28, 0x1e }, .expected = " 公众" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x1e }, .expected = " 民族" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x1e }, .expected = " 享受" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x1e }, .expected = " 启动" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x1e }, .expected = " 适合" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x1e }, .expected = " 问答" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xb8, 0x1e }, .expected = " 本文" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xc8, 0x1e }, .expected = " 美食" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x1e }, .expected = " 绿色" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xf8, 0x1e }, .expected = " 终于" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x08, 0x1f }, .expected = " 生物" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x18, 0x1f }, .expected = " 供求" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x38, 0x1f }, .expected = " 力量" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x48, 0x1f }, .expected = " 严重" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x58, 0x1f }, .expected = " 永远" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x68, 0x1f }, .expected = " 写真" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x78, 0x1f }, .expected = " 有限" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x88, 0x1f }, .expected = " 竞争" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0x98, 0x1f }, .expected = " 对象" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xa8, 0x1f }, .expected = " 费用" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xd8, 0x1f }, .expected = " 十分" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x04, 0xe8, 0x1f }, .expected = " 促进" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x00 }, .expected = " 影音" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x00 }, .expected = " 欣赏" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x00 }, .expected = " 并且" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x00 }, .expected = " 有点" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x88, 0x00 }, .expected = " 信用" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x00 }, .expected = " 设施" },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
}

test "br minimal static dictionary upstream4096 identity ninth window decodes Node frames" {
    // Ninth source-limit 4096 probe window. This slice transitions from CJK
    // dictionary words into Latin/Spanish 6-byte identity entries.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x02 }, .expected = " 口价" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x02 }, .expected = " 安排" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x02 }, .expected = " 武汉" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x02 }, .expected = " 里面" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x88, 0x02 }, .expected = " 创建" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x02 }, .expected = " 天空" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa8, 0x02 }, .expected = " 首先" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x02 }, .expected = " 驱动" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x03 }, .expected = " 阳光" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x03 }, .expected = " 英国" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x03 }, .expected = " 漂亮" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x03 }, .expected = " 军事" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x03 }, .expected = " 玩家" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x03 }, .expected = " 群众" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x88, 0x03 }, .expected = " 即可" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb8, 0x03 }, .expected = " 动画" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x03 }, .expected = " 想到" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x03 }, .expected = " 小学" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x03 }, .expected = " 性能" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x04 }, .expected = " 考研" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x04 }, .expected = " 清楚" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x04 }, .expected = " 搞笑" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x04 }, .expected = " 首頁" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x04 }, .expected = " 黄金" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x04 }, .expected = " 适用" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x88, 0x04 }, .expected = " 江苏" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb8, 0x04 }, .expected = " 阶段" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x04 }, .expected = " 註冊" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x04 }, .expected = " 翻译" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x04 }, .expected = " 权利" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x04 }, .expected = " 做好" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x05 }, .expected = " 通讯" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x05 }, .expected = " 施工" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x05 }, .expected = " 狀態" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x05 }, .expected = " 也许" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x05 }, .expected = " 环保" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x05 }, .expected = " 培养" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x05 }, .expected = " 机票" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb8, 0x05 }, .expected = " 匿名" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x05 }, .expected = " cuando" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x05 }, .expected = " enviar" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x05 }, .expected = " madrid" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x06 }, .expected = " inicio" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x06 }, .expected = " tiempo" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x06 }, .expected = " porque" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x06 }, .expected = " cuenta" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x06 }, .expected = " nombre" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x06 }, .expected = " manera" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x06 }, .expected = " ciudad" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x07 }, .expected = " aunque" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x07 }, .expected = " dentro" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x07 }, .expected = " precio" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x07 }, .expected = " según" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x07 }, .expected = " volver" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x07 }, .expected = " semana" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa8, 0x07 }, .expected = " había" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb8, 0x07 }, .expected = " agosto" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x07 }, .expected = " carlos" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x07 }, .expected = " equipo" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x08 }, .expected = " niños" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x08 }, .expected = " muchos" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x08 }, .expected = " alguna" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x08 }, .expected = " maría" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x88, 0x08 }, .expected = " hombre" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x08 }, .expected = " empleo" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa8, 0x08 }, .expected = " verdad" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x08 }, .expected = " línea" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x88, 0x09 }, .expected = " miguel" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa8, 0x09 }, .expected = " cuatro" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x09 }, .expected = " europa" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x0a }, .expected = " demás" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x0a }, .expected = " cuerpo" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x0a }, .expected = " siendo" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x0a }, .expected = " prensa" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x0a }, .expected = " llegar" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x0b }, .expected = " murcia" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x0b }, .expected = " podrá" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x0b }, .expected = " diario" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x0b }, .expected = " propio" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa8, 0x0b }, .expected = " crisis" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb8, 0x0b }, .expected = " cierto" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x0b }, .expected = " seguro" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x0b }, .expected = " muerte" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x0b }, .expected = " fuente" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x0b }, .expected = " cerrar" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x0c }, .expected = " grande" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x0c }, .expected = " efecto" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x0c }, .expected = " ofrece" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x0c }, .expected = " tierra" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x0c }, .expected = " e-mail" },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
}

test "br minimal static dictionary upstream4096 identity tenth window decodes Node frames" {
    // Tenth source-limit 4096 probe window. This slice covers Latin/Spanish,
    // Russian, and Hindi 6-byte identity entries selected for leading-space
    // transformed payloads.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x0e }, .expected = " estilo" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x0e }, .expected = " guerra" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x0e }, .expected = " éxito" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x0e }, .expected = " vídeo" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa8, 0x0e }, .expected = " evitar" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb8, 0x0e }, .expected = " pagina" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x0e }, .expected = " metros" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x0e }, .expected = " javier" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x0e }, .expected = " padres" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x0e }, .expected = " fácil" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x0f }, .expected = " cabeza" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x0f }, .expected = " salida" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x0f }, .expected = " envío" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x0f }, .expected = " japón" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb8, 0x0f }, .expected = " común" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x0f }, .expected = " tenido" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x0f }, .expected = " bilbao" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x10 }, .expected = " для" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x10 }, .expected = " что" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x10 }, .expected = " как" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x10 }, .expected = " или" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x88, 0x10 }, .expected = " это" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x10 }, .expected = " все" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa8, 0x10 }, .expected = " его" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x10 }, .expected = " так" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x10 }, .expected = " еще" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x10 }, .expected = " Как" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x11 }, .expected = " без" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x11 }, .expected = " был" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x11 }, .expected = " они" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x11 }, .expected = " Все" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x11 }, .expected = " под" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x11 }, .expected = " Это" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x11 }, .expected = " том" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x11 }, .expected = " чем" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x88, 0x11 }, .expected = " нет" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x11 }, .expected = " лет" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa8, 0x11 }, .expected = " раз" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x11 }, .expected = " где" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x11 }, .expected = " мне" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x11 }, .expected = " Для" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x11 }, .expected = " При" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x12 }, .expected = " нас" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x12 }, .expected = " них" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x12 }, .expected = " тем" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x12 }, .expected = " кто" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x12 }, .expected = " год" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x12 }, .expected = " вот" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x12 }, .expected = " США" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x88, 0x12 }, .expected = " мая" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x12 }, .expected = " Что" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa8, 0x12 }, .expected = " вас" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x12 }, .expected = " ему" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x12 }, .expected = " Так" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x12 }, .expected = " два" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x13 }, .expected = " про" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x13 }, .expected = " тут" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x13 }, .expected = " дня" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x88, 0x13 }, .expected = " Вот" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x13 }, .expected = " три" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb8, 0x13 }, .expected = " Вас" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x13 }, .expected = " сам" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x14 }, .expected = " ООО" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x14 }, .expected = " мой" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x14 }, .expected = " суд" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x14 }, .expected = " है" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x15 }, .expected = " का" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x15 }, .expected = " पर" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x15 }, .expected = " ने" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb8, 0x15 }, .expected = " तो" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x15 }, .expected = " आप" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x16 }, .expected = " या" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x16 }, .expected = " था" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x16 }, .expected = " jagran" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x16 }, .expected = " जो" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x16 }, .expected = " अब" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x88, 0x16 }, .expected = " गई" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x16 }, .expected = " इन" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x17 }, .expected = " घर" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x17 }, .expected = " वे" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa8, 0x17 }, .expected = " उस" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb8, 0x17 }, .expected = " मे" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x17 }, .expected = " ले" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x18 }, .expected = " दे" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x18 }, .expected = " ओर" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x18 }, .expected = " बन" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x18 }, .expected = " चल" },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
}

test "br minimal static dictionary upstream4096 identity eleventh window decodes Node frames" {
    // Eleventh source-limit 4096 probe window. This slice finishes the late
    // Arabic 6-byte words and enters early 7-byte identity entries whose
    // transform-equivalent frames often still use identity source addresses.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x19 }, .expected = " علي" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x1a }, .expected = " حتى" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x1a }, .expected = " قبل" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x1a }, .expected = " وحة" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x1a }, .expected = " اخر" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x1a }, .expected = " فقط" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x1a }, .expected = " عبد" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x1a }, .expected = " ركن" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x1a }, .expected = " إذا" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x88, 0x1a }, .expected = " كما" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x1a }, .expected = " كيف" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x1a }, .expected = " بحث" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x1b }, .expected = " وهو" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x1b }, .expected = " أنا" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x1b }, .expected = " عند" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x1b }, .expected = " ليس" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x1b }, .expected = " منذ" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x1b }, .expected = " مثل" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x1b }, .expected = " الا" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x1b }, .expected = " حيث" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x1c }, .expected = " مصر" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x1c }, .expected = " شرح" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x1c }, .expected = " حول" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x38, 0x1c }, .expected = " وفي" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x1c }, .expected = " اذا" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x1c }, .expected = " لكل" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x1c }, .expected = " مرة" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x1c }, .expected = " أبو" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x1c }, .expected = " انه" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x1c }, .expected = " عضو" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x1c }, .expected = " وقد" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x28, 0x1d }, .expected = " بنت" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x1d }, .expected = " ابو" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x1d }, .expected = " قصص" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xa8, 0x1d }, .expected = " أحد" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xb8, 0x1d }, .expected = " نحن" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x1d }, .expected = " رأي" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x1d }, .expected = " احة" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x1d }, .expected = " كتب" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x08, 0x1e }, .expected = " دون" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x1e }, .expected = " يجب" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x1e }, .expected = " جهة" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x58, 0x1e }, .expected = " سنة" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x68, 0x1e }, .expected = " يتم" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x1e }, .expected = " كرة" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x1e }, .expected = " نفس" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xc8, 0x1e }, .expected = " لنا" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xd8, 0x1e }, .expected = " تلك" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xf8, 0x1e }, .expected = " لما" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x18, 0x1f }, .expected = " أول" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x48, 0x1f }, .expected = " أما" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x78, 0x1f }, .expected = " ذات" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0x98, 0x1f }, .expected = " بأن" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x44, 0xe8, 0x1f }, .expected = " حسن" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x08, 0x00 }, .expected = " شعر" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x18, 0x00 }, .expected = " أهل" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x28, 0x00 }, .expected = " شهر" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x38, 0x00 }, .expected = " قطر" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8c, 0x84, 0x48, 0x00 }, .expected = " طلب" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x04 }, .expected = "profile" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x10, 0x01 }, .expected = "profile " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x14 }, .expected = " profile" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x10, 0x01 }, .expected = "profile." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x35 }, .expected = "Service" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x04 }, .expected = "default" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x11, 0x01 }, .expected = "default " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x14 }, .expected = " default" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x97, 0x0b }, .expected = "Default" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x11, 0x01 }, .expected = "default." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x04 }, .expected = "details" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x12, 0x02 }, .expected = "details " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x14 }, .expected = " details" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x12, 0x02 }, .expected = "details." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x24 }, .expected = "support" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x12, 0x03 }, .expected = "support " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x34 }, .expected = " support" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x12, 0x03 }, .expected = "support." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x04 }, .expected = "message" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x13, 0x02 }, .expected = "message " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x14 }, .expected = " message" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x67, 0x02 }, .expected = "Message" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x13, 0x02 }, .expected = "message." },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x84, 0x07, 0x02 }, .expected = " Online " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xf8, 0x15 }, .expected = "Famous " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x84, 0x07, 0x02 }, .expected = " Online " },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
}

test "br minimal static dictionary upstream8192 identity first window decodes Node frames" {
    // First source-limit 8192 probe window. The candidate rows include several
    // transform-equivalent payloads, but the debug trace showed that Node
    // addressed 145 concrete identity source tuples. Pin every observed failing
    // frame here so the hand-reviewed subset remains tied to real encoder output.
    const cases = [_]struct {
        encoded: []const u8,
        expected: []const u8,
    }{
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x14 }, .expected = "success" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x93, 0x02 }, .expected = "success " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x24 }, .expected = " success" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x93, 0x02 }, .expected = "success." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x24 }, .expected = "fashion" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x13, 0x03 }, .expected = "fashion " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x34 }, .expected = " fashion" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x13, 0x03 }, .expected = "fashion." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x34 }, .expected = "<title>" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x93, 0x03 }, .expected = "<title> " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x05 }, .expected = " <title>" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x34 }, .expected = "<title>" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x93, 0x03 }, .expected = "<title>." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x15 }, .expected = "account" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x94, 0x04 }, .expected = "account " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x25 }, .expected = " account" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xb7, 0x04 }, .expected = "Account" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x94, 0x04 }, .expected = "account." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x25 }, .expected = "created" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x14, 0x05 }, .expected = "created " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x35 }, .expected = " created" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x14, 0x05 }, .expected = "created." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x35 }, .expected = "stories" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x94, 0x05 }, .expected = "stories " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x45 }, .expected = " stories" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x94, 0x05 }, .expected = "stories." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x57, 0x04 }, .expected = "Results" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x55 }, .expected = "running" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x94, 0x06 }, .expected = "running " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x65 }, .expected = " running" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x94, 0x06 }, .expected = "running." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x65 }, .expected = "process" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x14, 0x07 }, .expected = "process " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x75 }, .expected = " process" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x14, 0x07 }, .expected = "process." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x05 }, .expected = "objects" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x15, 0x04 }, .expected = "objects " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x15 }, .expected = " objects" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x15, 0x04 }, .expected = "objects." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x15 }, .expected = "visible" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x95, 0x04 }, .expected = "visible " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x25 }, .expected = " visible" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x95, 0x04 }, .expected = "visible." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x25 }, .expected = "welcome" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x15, 0x05 }, .expected = "welcome " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x35 }, .expected = " welcome" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x15, 0x05 }, .expected = "welcome." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x35 }, .expected = "article" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x95, 0x05 }, .expected = "article " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x45 }, .expected = " article" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x76, 0x03 }, .expected = "Article" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x95, 0x05 }, .expected = "article." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x45 }, .expected = "unknown" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x15, 0x06 }, .expected = "unknown " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x55 }, .expected = " unknown" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x15, 0x06 }, .expected = "unknown." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x55 }, .expected = "network" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x95, 0x06 }, .expected = "network " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x65 }, .expected = " network" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x16, 0x00 }, .expected = "Network" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x95, 0x06 }, .expected = "network." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x65 }, .expected = "company" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x15, 0x07 }, .expected = "company " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x75 }, .expected = " company" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x97, 0x07 }, .expected = "Company" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x15, 0x07 }, .expected = "company." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x75 }, .expected = "dynamic" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x95, 0x07 }, .expected = "dynamic " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x05 }, .expected = " dynamic" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x95, 0x07 }, .expected = "dynamic." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x05 }, .expected = "browser" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x16, 0x08 }, .expected = "browser " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x15 }, .expected = " browser" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x07, 0x05 }, .expected = "Browser" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x16, 0x08 }, .expected = "browser." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x15 }, .expected = "privacy" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x96, 0x08 }, .expected = "privacy " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x25 }, .expected = " privacy" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xc7, 0x08 }, .expected = "Privacy" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x96, 0x08 }, .expected = "privacy." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x25 }, .expected = "problem" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x16, 0x09 }, .expected = "problem " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x35 }, .expected = " problem" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x16, 0x09 }, .expected = "problem." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x55 }, .expected = "display" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x96, 0x0a }, .expected = "display " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x65 }, .expected = " display" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xe7, 0x03 }, .expected = "Display" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x96, 0x0a }, .expected = "display." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x65 }, .expected = "request" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x16, 0x0b }, .expected = "request " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x75 }, .expected = " request" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x77, 0x06 }, .expected = "Request" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x16, 0x0b }, .expected = "request." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x85 }, .expected = "website" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x16, 0x0c }, .expected = "website " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x04, 0x57, 0x04 }, .expected = " website" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x56, 0x02 }, .expected = "Website" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x16, 0x0c }, .expected = "website." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xb5 }, .expected = "options" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x96, 0x0d }, .expected = "options " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xc5 }, .expected = " options" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x77, 0x02 }, .expected = "Options" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x96, 0x0d }, .expected = "options." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xd5 }, .expected = "version" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x96, 0x0e }, .expected = "version " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xe5 }, .expected = " version" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xf6, 0x00 }, .expected = "Version" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x96, 0x0e }, .expected = "version." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xe5 }, .expected = "million" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x16, 0x0f }, .expected = "million " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xf5 }, .expected = " million" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x16, 0x0f }, .expected = "million." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x15 }, .expected = "address" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x97, 0x08 }, .expected = "address " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x25 }, .expected = " address" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x37, 0x04 }, .expected = "Address" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x97, 0x08 }, .expected = "address." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x35 }, .expected = "weather" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x97, 0x09 }, .expected = "weather " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x45 }, .expected = " weather" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x97, 0x09 }, .expected = "weather." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x45 }, .expected = "correct" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x17, 0x0a }, .expected = "correct " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x55 }, .expected = " correct" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x17, 0x0a }, .expected = "correct." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x55 }, .expected = "product" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x97, 0x0a }, .expected = "product " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x65 }, .expected = " product" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x17, 0x0d }, .expected = "Product" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x97, 0x0a }, .expected = "product." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x65 }, .expected = "edirect" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x17, 0x0b }, .expected = "edirect " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x75 }, .expected = " edirect" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x17, 0x0b }, .expected = "edirect." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x75 }, .expected = "forward" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x97, 0x0b }, .expected = "forward " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x85 }, .expected = " forward" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x97, 0x0b }, .expected = "forward." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x85 }, .expected = "you can" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x17, 0x0c }, .expected = "you can " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x95 }, .expected = " you can" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x17, 0x0c }, .expected = "you can." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0xa5 }, .expected = "subject" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x17, 0x0d }, .expected = "subject " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0xb5 }, .expected = " subject" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x17, 0x0d }, .expected = "subject." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0xc5 }, .expected = "archive" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x17, 0x0e }, .expected = "archive " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0xd5 }, .expected = " archive" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x17, 0x0e }, .expected = "archive." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0xd5 }, .expected = "current" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x97, 0x0e }, .expected = "current " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0xe5 }, .expected = " current" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x86, 0x02 }, .expected = "Current" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x97, 0x0e }, .expected = "current." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0xf5 }, .expected = "library" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x97, 0x0f }, .expected = "library " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x06, 0x00 }, .expected = " library" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x97, 0x0f }, .expected = "library." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x16, 0x00 }, .expected = "manager" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x98, 0x10 }, .expected = "manager " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x26, 0x00 }, .expected = " manager" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x98, 0x10 }, .expected = "manager." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x26, 0x00 }, .expected = "further" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x18, 0x11 }, .expected = "further " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x36, 0x00 }, .expected = " further" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0xf7, 0x05 }, .expected = "Further" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x18, 0x11 }, .expected = "further." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x36, 0x00 }, .expected = "summary" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x98, 0x11 }, .expected = "summary " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x46, 0x00 }, .expected = " summary" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0xc7, 0x0b }, .expected = "Summary" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x98, 0x11 }, .expected = "summary." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x46, 0x00 }, .expected = "machine" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x18, 0x12 }, .expected = "machine " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x56, 0x00 }, .expected = " machine" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x18, 0x12 }, .expected = "machine." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x56, 0x00 }, .expected = "minutes" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x98, 0x12 }, .expected = "minutes " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x66, 0x00 }, .expected = " minutes" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x98, 0x12 }, .expected = "minutes." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x86, 0x00 }, .expected = "program" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x18, 0x14 }, .expected = "program " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x96, 0x00 }, .expected = " program" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x77, 0x0e }, .expected = "Program" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x18, 0x14 }, .expected = "program." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xd6, 0x00 }, .expected = "trigger" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x98, 0x16 }, .expected = "trigger " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0xe6, 0x00 }, .expected = " trigger" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x98, 0x16 }, .expected = "trigger." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xf6, 0x00 }, .expected = "loading" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x98, 0x17 }, .expected = "loading " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x06, 0x01 }, .expected = " loading" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x98, 0x17 }, .expected = "loading." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x06, 0x01 }, .expected = "element" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x18, 0x18 }, .expected = "element " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x16, 0x01 }, .expected = " element" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xe7, 0x0d }, .expected = "Element" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x18, 0x18 }, .expected = "element." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x16, 0x01 }, .expected = "partner" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x98, 0x18 }, .expected = "partner " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x26, 0x01 }, .expected = " partner" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x98, 0x18 }, .expected = "partner." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x46, 0x01 }, .expected = "meaning" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x18, 0x1a }, .expected = "meaning " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x56, 0x01 }, .expected = " meaning" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x18, 0x1a }, .expected = "meaning." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x67, 0x0e }, .expected = "Systems" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x76, 0x01 }, .expected = "culture" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x98, 0x1b }, .expected = "culture " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0x86, 0x01 }, .expected = " culture" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0xc7, 0x04 }, .expected = "Culture" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x98, 0x1b }, .expected = "culture." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x96, 0x01 }, .expected = "journal" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x98, 0x1c }, .expected = "journal " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0xa6, 0x01 }, .expected = " journal" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x98, 0x1c }, .expected = "journal." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xa6, 0x01 }, .expected = "project" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x18, 0x1d }, .expected = "project " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x84, 0x07, 0x04 }, .expected = " project" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x37, 0x05 }, .expected = "Project" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x18, 0x1d }, .expected = "project." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xb6, 0x01 }, .expected = "surface" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x98, 0x1d }, .expected = "surface " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0xc6, 0x01 }, .expected = " surface" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x98, 0x1d }, .expected = "surface." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xc6, 0x01 }, .expected = "s&quot;" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x18, 0x1e }, .expected = "s&quot; " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0xd6, 0x01 }, .expected = " s&quot;" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x18, 0x1e }, .expected = "s&quot;." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xd6, 0x01 }, .expected = "expires" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x98, 0x1e }, .expected = "expires " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x04, 0xe6, 0x01 }, .expected = " expires" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x98, 0x1e }, .expected = "expires." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xf6, 0x01 }, .expected = "balance" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x98, 0x1f }, .expected = "balance " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x06, 0x00 }, .expected = " balance" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x98, 0x1f }, .expected = "balance." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x16, 0x00 }, .expected = "Content" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x44, 0x07, 0x05 }, .expected = "Content " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x26, 0x00 }, .expected = " Content" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x16, 0x00 }, .expected = "Content" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x99, 0x10 }, .expected = "Content." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x36, 0x00 }, .expected = "Please " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x99, 0x11 }, .expected = "Please  " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x46, 0x00 }, .expected = " Please " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x36, 0x00 }, .expected = "Please " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x99, 0x11 }, .expected = "Please ." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x46, 0x00 }, .expected = "opinion" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x19, 0x12 }, .expected = "opinion " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x56, 0x00 }, .expected = " opinion" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x19, 0x12 }, .expected = "opinion." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x56, 0x00 }, .expected = "contact" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x99, 0x12 }, .expected = "contact " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x66, 0x00 }, .expected = " contact" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x99, 0x12 }, .expected = "contact." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x66, 0x00 }, .expected = "average" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x19, 0x13 }, .expected = "average " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x76, 0x00 }, .expected = " average" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x19, 0x13 }, .expected = "average." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x76, 0x00 }, .expected = "primary" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x84, 0x77, 0x00 }, .expected = "primary " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x86, 0x00 }, .expected = " primary" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x99, 0x13 }, .expected = "primary." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x96, 0x00 }, .expected = "Spanish" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x99, 0x14 }, .expected = "Spanish " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0xa6, 0x00 }, .expected = " Spanish" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x96, 0x00 }, .expected = "Spanish" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x99, 0x14 }, .expected = "Spanish." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0xa6, 0x00 }, .expected = "gallery" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x19, 0x15 }, .expected = "gallery " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0xb6, 0x00 }, .expected = " gallery" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0xb7, 0x00 }, .expected = "Gallery" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x19, 0x15 }, .expected = "gallery." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0xb6, 0x00 }, .expected = "decline" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x99, 0x15 }, .expected = "decline " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0xc6, 0x00 }, .expected = " decline" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x99, 0x15 }, .expected = "decline." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0xd6, 0x00 }, .expected = "mission" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x99, 0x16 }, .expected = "mission " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0xe6, 0x00 }, .expected = " mission" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x98, 0x1a }, .expected = "Mission" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x99, 0x16 }, .expected = "mission." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x36, 0x03 }, .expected = "Popular" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0xf6, 0x00 }, .expected = "quality" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x84, 0xa7, 0x02 }, .expected = "quality " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x44, 0x77, 0x05 }, .expected = " quality" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x99, 0x17 }, .expected = "quality." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x06, 0x01 }, .expected = "measure" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x19, 0x18 }, .expected = "measure " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x16, 0x01 }, .expected = " measure" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x19, 0x18 }, .expected = "measure." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0xf6, 0x03 }, .expected = "General" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x46, 0x01 }, .expected = "section" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x04, 0xe7, 0x06 }, .expected = "section " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x56, 0x01 }, .expected = " section" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x17, 0x0a }, .expected = "Section" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x19, 0x1a }, .expected = "section." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x66, 0x01 }, .expected = "counter" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x19, 0x1b }, .expected = "counter " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x76, 0x01 }, .expected = " counter" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x19, 0x1b }, .expected = "counter." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x76, 0x01 }, .expected = "initial" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x99, 0x1b }, .expected = "initial " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0x86, 0x01 }, .expected = " initial" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x99, 0x1b }, .expected = "initial." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0xd6, 0x01 }, .expected = "earlier" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x99, 0x1e }, .expected = "earlier " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x44, 0xe6, 0x01 }, .expected = " earlier" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x99, 0x1e }, .expected = "earlier." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0xf6, 0x01 }, .expected = "digital" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x99, 0x1f }, .expected = "digital " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x06, 0x00 }, .expected = " digital" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x36, 0x02 }, .expected = "Digital" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x99, 0x1f }, .expected = "digital." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x06, 0x00 }, .expected = "picture" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x20 }, .expected = "picture " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x16, 0x00 }, .expected = " picture" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xa8, 0x11 }, .expected = "Picture" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x20 }, .expected = "picture." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x26, 0x00 }, .expected = "married" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x21 }, .expected = "married " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x36, 0x00 }, .expected = " married" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x21 }, .expected = "married." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x36, 0x00 }, .expected = "traffic" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x21 }, .expected = "traffic " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x46, 0x00 }, .expected = " traffic" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x21 }, .expected = "traffic." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x76, 0x00 }, .expected = "victory" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x23 }, .expected = "victory " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x86, 0x00 }, .expected = " victory" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x23 }, .expected = "victory." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x86, 0x00 }, .expected = "images/" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x24 }, .expected = "images/ " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x96, 0x00 }, .expected = " images/" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x24 }, .expected = "images/." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x96, 0x00 }, .expected = "reasons" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x24 }, .expected = "reasons " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xa6, 0x00 }, .expected = " reasons" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x24 }, .expected = "reasons." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x17, 0x06 }, .expected = "Studies" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xb6, 0x00 }, .expected = "feature" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x25 }, .expected = "feature " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xc6, 0x00 }, .expected = " feature" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x25 }, .expected = "feature." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xd6, 0x00 }, .expected = "must be" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x26 }, .expected = "must be " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xe6, 0x00 }, .expected = " must be" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x26 }, .expected = "must be." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xf6, 0x00 }, .expected = "Version" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x27 }, .expected = "Version " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x06, 0x01 }, .expected = " Version" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xf6, 0x00 }, .expected = "Version" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x27 }, .expected = "Version." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x18, 0x02 }, .expected = "Usually" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x16, 0x01 }, .expected = "episode" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x28 }, .expected = "episode " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x26, 0x01 }, .expected = " episode" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x28 }, .expected = "episode." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x46, 0x01 }, .expected = "obvious" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x2a }, .expected = "obvious " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x56, 0x01 }, .expected = " obvious" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x2a }, .expected = "obvious." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x56, 0x01 }, .expected = "overlay" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x2a }, .expected = "overlay " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x66, 0x01 }, .expected = " overlay" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x2a }, .expected = "overlay." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x86, 0x01 }, .expected = "</ul>\r\n" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x2c }, .expected = "</ul>\r\n " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x96, 0x01 }, .expected = " </ul>\r\n" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x86, 0x01 }, .expected = "</ul>\r\n" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x2c }, .expected = "</ul>\r\n." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xa6, 0x01 }, .expected = "already" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x2d }, .expected = "already " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xb6, 0x01 }, .expected = " already" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x2d }, .expected = "already." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xb6, 0x01 }, .expected = "certain" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x2d }, .expected = "certain " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xc6, 0x01 }, .expected = " certain" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x44, 0x28, 0x07 }, .expected = "Certain" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x2d }, .expected = "certain." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xf6, 0x01 }, .expected = "desktop" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x2f }, .expected = "desktop " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x06, 0x02 }, .expected = " desktop" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x2f }, .expected = "desktop." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x16, 0x02 }, .expected = "pattern" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x30 }, .expected = "pattern " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x26, 0x02 }, .expected = " pattern" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x30 }, .expected = "pattern." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x26, 0x02 }, .expected = "unusual" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x31 }, .expected = "unusual " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x36, 0x02 }, .expected = " unusual" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x31 }, .expected = "unusual." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x36, 0x02 }, .expected = "Digital" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x31 }, .expected = "Digital " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x46, 0x02 }, .expected = " Digital" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x36, 0x02 }, .expected = "Digital" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x31 }, .expected = "Digital." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x46, 0x02 }, .expected = "capital" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x32 }, .expected = "capital " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x56, 0x02 }, .expected = " capital" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x17, 0x0d }, .expected = "Capital" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x32 }, .expected = "capital." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x56, 0x02 }, .expected = "Website" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x32 }, .expected = "Website " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x66, 0x02 }, .expected = " Website" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x56, 0x02 }, .expected = "Website" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x32 }, .expected = "Website." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x66, 0x02 }, .expected = "failure" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x33 }, .expected = "failure " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x76, 0x02 }, .expected = " failure" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x33 }, .expected = "failure." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x76, 0x02 }, .expected = "connect" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x33 }, .expected = "connect " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x86, 0x02 }, .expected = " connect" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x04, 0x37, 0x04 }, .expected = "connect." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x86, 0x02 }, .expected = "reduced" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x34 }, .expected = "reduced " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x96, 0x02 }, .expected = " reduced" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x34 }, .expected = "reduced." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x96, 0x02 }, .expected = "Android" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x34 }, .expected = "Android " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xa6, 0x02 }, .expected = " Android" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x96, 0x02 }, .expected = "Android" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x34 }, .expected = "Android." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xa6, 0x02 }, .expected = "decades" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x35 }, .expected = "decades " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xb6, 0x02 }, .expected = " decades" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x35 }, .expected = "decades." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xb6, 0x02 }, .expected = "regular" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x35 }, .expected = "regular " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xc6, 0x02 }, .expected = " regular" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x35 }, .expected = "regular." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xf6, 0x02 }, .expected = "Automat" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x37 }, .expected = "Automat " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x06, 0x03 }, .expected = " Automat" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xf6, 0x02 }, .expected = "Automat" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x37 }, .expected = "Automat." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x06, 0x03 }, .expected = "getting" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x38 }, .expected = "getting " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x16, 0x03 }, .expected = " getting" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x38 }, .expected = "getting." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x26, 0x03 }, .expected = "nothing" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x39 }, .expected = "nothing " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x36, 0x03 }, .expected = " nothing" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x39 }, .expected = "nothing." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x36, 0x03 }, .expected = "Popular" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x39 }, .expected = "Popular " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x46, 0x03 }, .expected = " Popular" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x36, 0x03 }, .expected = "Popular" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x39 }, .expected = "Popular." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x46, 0x03 }, .expected = "caption" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x3a }, .expected = "caption " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x56, 0x03 }, .expected = " caption" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x3a }, .expected = "caption." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0xb8, 0x0f }, .expected = "Letters" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x56, 0x03 }, .expected = "Science" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0x86, 0x03 }, .expected = "license" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x3c }, .expected = "license " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0x96, 0x03 }, .expected = " license" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x04, 0x08, 0x00 }, .expected = "License" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1a, 0x3c }, .expected = "license." },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x84, 0x47, 0x06 }, .expected = " changes" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xb6, 0x03 }, .expected = "=1&amp;" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x3d }, .expected = "=1&amp; " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xc6, 0x03 }, .expected = " =1&amp;" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xb6, 0x03 }, .expected = "=1&amp;" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x3d }, .expected = "=1&amp;." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xd6, 0x03 }, .expected = " = new " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x3e }, .expected = " = new  " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0x84, 0xe6, 0x03 }, .expected = "  = new " },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0x84, 0xd6, 0x03 }, .expected = " = new " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9a, 0x3e }, .expected = " = new ." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x06, 0x00 }, .expected = "Special" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1b, 0x20 }, .expected = "Special " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x16, 0x00 }, .expected = " Special" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x06, 0x00 }, .expected = "Special" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1b, 0x20 }, .expected = "Special." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x47, 0x07 }, .expected = "Comment" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x46, 0x00 }, .expected = "warning" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1b, 0x22 }, .expected = "warning " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x56, 0x00 }, .expected = " warning" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1b, 0x22 }, .expected = "warning." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x56, 0x00 }, .expected = "College" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9b, 0x22 }, .expected = "College " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x66, 0x00 }, .expected = " College" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x56, 0x00 }, .expected = "College" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9b, 0x22 }, .expected = "College." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x66, 0x00 }, .expected = "toolbar" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1b, 0x23 }, .expected = "toolbar " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0x76, 0x00 }, .expected = " toolbar" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1b, 0x23 }, .expected = "toolbar." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0x96, 0x00 }, .expected = "elected" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9b, 0x24 }, .expected = "elected " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0xa6, 0x00 }, .expected = " elected" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x9b, 0x24 }, .expected = "elected." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0xa6, 0x00 }, .expected = "Deutsch" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x1b, 0x25 }, .expected = "Deutsch " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0xb6, 0x00 }, .expected = " Deutsch" },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0xa6, 0x00 }, .expected = "Deutsch" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0xe1, 0x52, 0x85, 0x28, 0x12, 0x1b, 0x25 }, .expected = "Deutsch." },
        .{ .encoded = &[_]u8{ 0xa1, 0x30, 0x00, 0x00, 0x20, 0x01, 0x10, 0x85, 0xc4, 0xb6, 0x00 }, .expected = "finance" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x52, 0x85, 0x28, 0x12, 0x9b, 0x25 }, .expected = "finance " },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x12, 0x8d, 0xc4, 0xc6, 0x00 }, .expected = " finance" },
        .{ .encoded = &[_]u8{ 0xa1, 0x38, 0x00, 0x00, 0x20, 0x01, 0x10, 0x86, 0x84, 0xa7, 0x00 }, .expected = "quickly " },
    };
    for (cases) |case| {
        try expectBrStaticDictionaryFrame(case.encoded, case.expected);
    }
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

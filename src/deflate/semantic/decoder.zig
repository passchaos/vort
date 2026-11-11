//! Semantic Deflate Huffman tables shared by the one-shot and (future)
//! incremental windowed decoders.

const std = @import("std");
const core = @import("../../core.zig");
const huffman = @import("../../huffman.zig");
const bitstream = @import("../../bitstream.zig");
const bit_geometry = @import("../../io/bit_count.zig");
const secondary_index = @import("../decoder/secondary_index.zig");
const shortcopy = @import("../decoder/shortcopy.zig");
const png_non_overlap = @import("../png/non_overlap.zig");
const tables = @import("tables.zig");

const Error = core.Error;
const BitCount = bit_geometry.BitCount;
const length_table = tables.length_table;
const distance_table = tables.distance_table;

pub const DynamicDistanceDecoder = union(enum) {
    single: huffman.HuffmanTable(30).Entry,
    fast8: huffman.FastDecoder(30, 8),

    pub fn init(table: huffman.HuffmanTable(30)) DynamicDistanceDecoder {
        if (table.len == 1) return .{ .single = table.entries[0] };
        return .{ .fast8 = huffman.FastDecoder(30, 8).init(table) };
    }

    pub inline fn decodeValue(self: *const DynamicDistanceDecoder, reader: anytype) Error!u16 {
        return switch (self.*) {
            .single => |entry| blk: {
                const bits: u6 = entry.bits;
                const code = reader.peekBitsPadded(u16, bits);
                if (!reader.hasStagedBits(entry.bits)) return error.TruncatedFrame;
                if (code != entry.code) return error.InvalidHuffmanCode;
                reader.advanceBitsStagedAssumeAvailable(bits);
                break :blk entry.symbol;
            },
            .fast8 => |*decoder| try decoder.decodeValue(reader),
        };
    }

    pub fn fastWouldHit(self: *const DynamicDistanceDecoder, reader: *bitstream.BufferedBitReader) bool {
        return switch (self.*) {
            .single => |entry| entry.bits <= 8 and reader.hasBits(entry.bits),
            .fast8 => |*decoder| huffmanFastWouldHit(30, 8, decoder, reader),
        };
    }

    pub fn lookupCoverage(self: *const DynamicDistanceDecoder) usize {
        return switch (self.*) {
            .single => 0,
            .fast8 => |*decoder| decoder.lookupCoverage(),
        };
    }

    pub fn lookupSize(self: *const DynamicDistanceDecoder) usize {
        return switch (self.*) {
            .single => 0,
            .fast8 => |*decoder| decoder.lookup.len,
        };
    }
};

pub const SemanticDynamicDecoder = struct {
    pub const literal_lookup_bits: u4 = 11;
    pub const literal_lookup_len = @as(usize, 1) << literal_lookup_bits;
    pub const literal_lookup_mask: u64 = literal_lookup_len - 1;
    pub const distance_lookup_bits: u4 = 8;
    pub const distance_lookup_len = @as(usize, 1) << distance_lookup_bits;
    pub const distance_lookup_mask: u64 = distance_lookup_len - 1;
    const literal_secondary_capacity = 4096;
    const distance_secondary_capacity = 1024;

    pub const literal_flag: u32 = 0x8000;
    pub const exceptional_flag: u32 = 0x4000;
    pub const secondary_flag: u32 = 0x2000;

    literal: [literal_lookup_len]u32 = undefined,
    literal_secondary: [literal_secondary_capacity]u16 = undefined,
    literal_secondary_len: usize = 0,
    distance: [distance_lookup_len]u32 = undefined,
    distance_secondary: [distance_secondary_capacity]u16 = undefined,
    distance_secondary_len: usize = 0,
    single_distance: u32 = 0,
    compact_literal: *const huffman.HuffmanTable(286) = undefined,
    compact_distance: *const huffman.HuffmanTable(30) = undefined,

    const Self = @This();

    pub fn init(self: *Self, literal_table: *const huffman.HuffmanTable(286), distance_table_: *const huffman.HuffmanTable(30)) bool {
        if (!treeIsComplete(286, literal_table)) return false;

        self.* = Self{
            .distance = @splat(0),
            .compact_literal = literal_table,
            .compact_distance = distance_table_,
        };
        if (!self.buildLiteralTable(literal_table)) return false;
        if (!self.buildDistanceTable(distance_table_)) return false;
        return true;
    }

    pub fn initWithDynamicDistanceDecoder(
        self: *Self,
        literal_table: *const huffman.HuffmanTable(286),
        dist_decoder: *const DynamicDistanceDecoder,
    ) bool {
        if (!treeIsComplete(286, literal_table)) return false;
        const distance_table_ = switch (dist_decoder.*) {
            .single => return false,
            .fast8 => |*decoder| &decoder.table,
        };

        self.* = Self{
            .distance = @splat(0),
            .compact_literal = literal_table,
            .compact_distance = distance_table_,
        };
        if (!self.buildLiteralTable(literal_table)) return false;
        if (!self.buildDistanceTable(distance_table_)) return false;
        return true;
    }

    pub fn initSingleDistance(self: *Self, literal_table: *const huffman.HuffmanTable(286), distance_table_: *const huffman.HuffmanTable(30)) bool {
        if (!treeIsComplete(286, literal_table) or distance_table_.len != 1) return false;
        const entry = distance_table_.entries[0];
        if (entry.code != 0 or entry.symbol >= distance_table.len) return false;

        self.* = Self{
            .single_distance = semanticDistanceEntry(entry.symbol, entry.bits),
            .compact_literal = literal_table,
            .compact_distance = distance_table_,
        };
        return self.buildLiteralTable(literal_table);
    }

    pub fn treeIsComplete(comptime symbol_count: usize, table: *const huffman.HuffmanTable(symbol_count)) bool {
        if (table.max_bits == 0) return false;
        var used: usize = 0;
        var bits: usize = 1;
        while (bits <= table.max_bits) : (bits += 1) {
            used += @as(usize, table.count_by_bits[bits]) << @intCast(@as(usize, table.max_bits) - bits);
        }
        return used == (@as(usize, 1) << @intCast(table.max_bits));
    }

    fn buildLiteralTable(self: *Self, table: *const huffman.HuffmanTable(286)) bool {
        return buildSemanticLiteralTable(literal_lookup_bits, &self.literal, &self.literal_secondary, &self.literal_secondary_len, table);
    }

    fn buildDistanceTable(self: *Self, table: *const huffman.HuffmanTable(30)) bool {
        // Same primary-only shortcut for distance codes. This keeps the fast
        // path identical while removing secondary-prefix setup for blocks whose
        // distance alphabet already fits in the 8-bit table.
        if (table.max_bits <= distance_lookup_bits) {
            for (table.entries[0..table.len]) |entry| {
                fillPrimary(
                    &self.distance,
                    distance_lookup_bits,
                    entry,
                    semanticDistanceEntry(entry.symbol, entry.bits),
                );
            }
            return true;
        }

        var prefix_max_bits: [distance_lookup_len]u4 = @splat(0);
        for (table.entries[0..table.len]) |entry| {
            if (entry.bits <= distance_lookup_bits) {
                fillPrimary(
                    &self.distance,
                    distance_lookup_bits,
                    entry,
                    semanticDistanceEntry(entry.symbol, entry.bits),
                );
            } else {
                const prefix = @as(usize, entry.code) & (distance_lookup_len - 1);
                prefix_max_bits[prefix] = @max(prefix_max_bits[prefix], entry.bits);
            }
        }

        for (prefix_max_bits, 0..) |max_bits, prefix| {
            if (max_bits == 0) continue;
            const size = @as(usize, 1) << @intCast(max_bits - distance_lookup_bits);
            if (self.distance_secondary_len + size > self.distance_secondary.len or size > 256) return false;
            const start = self.distance_secondary_len;
            self.distance_secondary_len += size;
            self.distance[prefix] = (@as(u32, @intCast(start)) << 16) |
                exceptional_flag |
                secondary_flag |
                @as(u32, @intCast(size - 1));
        }

        for (table.entries[0..table.len]) |entry| {
            if (entry.bits <= distance_lookup_bits) continue;
            const prefix = @as(usize, entry.code) & (distance_lookup_len - 1);
            const primary = self.distance[prefix];
            const start: usize = @intCast(primary >> 16);
            const mask: usize = @intCast(primary & 0xff);
            const suffix_bits: u4 = entry.bits - distance_lookup_bits;
            const suffix = @as(usize, entry.code) >> distance_lookup_bits;
            const fill = (mask + 1) >> suffix_bits;
            var i: usize = 0;
            while (i < fill) : (i += 1) {
                const index = start + suffix + (i << suffix_bits);
                self.distance_secondary[index] = (@as(u16, entry.symbol) << 4) | entry.bits;
            }
        }
        return true;
    }

    fn fillPrimary(
        primary: anytype,
        comptime lookup_bits: u4,
        entry: anytype,
        semantic: u32,
    ) void {
        const fill = @as(usize, 1) << @intCast(lookup_bits - entry.bits);
        var i: usize = 0;
        while (i < fill) : (i += 1) {
            primary[entry.code | (i << entry.bits)] = semantic;
        }
    }

    fn semanticLiteralEntry(symbol: u16, bits: u4) u32 {
        if (symbol < 256) {
            return (@as(u32, symbol) << 16) | literal_flag | (1 << 8) | bits;
        }
        if (symbol == 256) return exceptional_flag | bits;
        if (symbol <= 285) {
            const metadata = length_table[symbol - 257];
            return (@as(u32, metadata.base) << 16) |
                (@as(u32, metadata.extra_bits) << 8) |
                bits;
        }
        return exceptional_flag;
    }

    fn semanticDistanceEntry(symbol: u16, bits: u4) u32 {
        if (symbol >= distance_table.len) return 0;
        const metadata = distance_table[symbol];
        return (@as(u32, metadata.base) << 16) |
            (@as(u32, metadata.extra_bits) << 8) |
            literal_flag |
            bits;
    }
};

pub fn buildSemanticLiteralTable(
    comptime literal_lookup_bits: u4,
    literal: anytype,
    literal_secondary: anytype,
    literal_secondary_len: *usize,
    table: *const huffman.HuffmanTable(286),
) bool {
    const literal_lookup_len = @as(usize, 1) << literal_lookup_bits;
    // Build the primary table one code width at a time. After entries for a
    // width are installed, duplicating the completed prefix table grows it
    // to the next width. This writes each primary slot only O(1) times and
    // lets double-literal pairs be inserted once at their combined width.
    literal[0] = 0;
    literal[1] = 0;
    var total_bits: usize = 1;
    while (total_bits <= literal_lookup_bits) : (total_bits += 1) {
        const first = table.first_by_bits[total_bits];
        const end = first + table.count_by_bits[total_bits];
        for (table.entries[first..end]) |entry| {
            literal[entry.code] = SemanticDynamicDecoder.semanticLiteralEntry(entry.symbol, entry.bits);
        }

        var first_bits: usize = 1;
        while (first_bits + 1 < total_bits) : (first_bits += 1) {
            const second_bits = total_bits - first_bits;
            const first_start = table.first_by_bits[first_bits];
            const first_end = first_start + table.count_by_bits[first_bits];
            const second_start = table.first_by_bits[second_bits];
            const second_end = second_start + table.count_by_bits[second_bits];
            for (table.entries[first_start..first_end]) |first_entry| {
                if (first_entry.symbol >= 256) continue;
                for (table.entries[second_start..second_end]) |second_entry| {
                    if (second_entry.symbol >= 256) continue;
                    const code = @as(usize, first_entry.code) |
                        (@as(usize, second_entry.code) << @intCast(first_bits));
                    literal[code] = (@as(u32, @intCast(total_bits)) & 0xf) |
                        SemanticDynamicDecoder.literal_flag |
                        (2 << 8) |
                        (@as(u32, first_entry.symbol) << 16) |
                        (@as(u32, second_entry.symbol) << 24);
                }
            }
        }

        if (total_bits < literal_lookup_bits) {
            const current_len = @as(usize, 1) << @intCast(total_bits);
            @memcpy(
                literal[current_len .. current_len * 2],
                literal[0..current_len],
            );
        }
    }

    // When every literal/length code fits in the primary semantic lookup,
    // the secondary table is provably unused. Many PNG dynamic blocks have
    // this shape (for example small icons and several Kodak images), so
    // avoid scanning and zero-checking the 2 KiB prefix map on every block.
    if (table.max_bits <= literal_lookup_bits) return true;

    var prefix_max_bits: [literal_lookup_len]u4 = @splat(0);
    for (table.entries[0..table.len]) |entry| {
        if (entry.bits > literal_lookup_bits) {
            const prefix = @as(usize, entry.code) & (literal_lookup_len - 1);
            prefix_max_bits[prefix] = @max(prefix_max_bits[prefix], entry.bits);
        }
    }

    for (prefix_max_bits, 0..) |max_bits, prefix| {
        if (max_bits == 0) continue;
        const size = @as(usize, 1) << @intCast(max_bits - literal_lookup_bits);
        if (literal_secondary_len.* + size > literal_secondary.len or size > 256) return false;
        const start = literal_secondary_len.*;
        literal_secondary_len.* += size;
        literal[prefix] = (@as(u32, @intCast(start)) << 16) |
            SemanticDynamicDecoder.exceptional_flag |
            SemanticDynamicDecoder.secondary_flag |
            @as(u32, @intCast(size - 1));
    }

    for (table.entries[0..table.len]) |entry| {
        if (entry.bits <= literal_lookup_bits) continue;
        const prefix = @as(usize, entry.code) & (literal_lookup_len - 1);
        const primary = literal[prefix];
        const start: usize = @intCast(primary >> 16);
        const mask: usize = @intCast(primary & 0xff);
        const suffix_bits: u4 = entry.bits - literal_lookup_bits;
        const suffix = @as(usize, entry.code) >> literal_lookup_bits;
        const fill = (mask + 1) >> suffix_bits;
        var i: usize = 0;
        while (i < fill) : (i += 1) {
            const index = start + suffix + (i << suffix_bits);
            literal_secondary[index] = (@as(u16, entry.symbol) << 4) | entry.bits;
        }
    }
    return true;
}

pub fn huffmanFastWouldHit(
    comptime max_symbols: usize,
    comptime lookup_bits: u4,
    decoder: *const huffman.FastDecoder(max_symbols, lookup_bits),
    reader: *bitstream.BufferedBitReader,
) bool {
    const peek = reader.peekBitsPadded(u16, lookup_bits);
    const entry = decoder.lookup[peek];
    return entry.bits != 0 and reader.hasBits(entry.bits);
}

pub const LinearStatus = enum { need_output, end_of_block };

pub const LinearStep = struct {
    output_written: usize,
    status: LinearStatus,
};

fn LinearResult(comptime resumable: bool) type {
    return if (resumable) LinearStep else usize;
}

inline fn linearResult(
    comptime resumable: bool,
    output_written: usize,
    status: LinearStatus,
) LinearResult(resumable) {
    if (comptime resumable) {
        return .{
            .output_written = output_written,
            .status = status,
        };
    }
    std.debug.assert(status == .end_of_block);
    return output_written;
}

/// Decode one dynamic block into a linear history/output window. Tokens are
/// committed atomically: when the next token does not fit, the reader remains
/// positioned before that token and `need_output` is returned.
///
/// The reader may start with an already populated reservoir whose bytes belong
/// to a different input slice. Reader accounting is updated from the state
/// delta observed by this call rather than reconstructed as an absolute offset
/// into `reader.input`.
pub noinline fn decodeDynamicBlockIntoWindow(
    noalias reader: *bitstream.BufferedBitReader,
    noalias output: []u8,
    initial_out_offset: usize,
    noalias decoder: *const SemanticDynamicDecoder,
) Error!LinearStep {
    return decodeDynamicBlockIntoLinearMode(
        false,
        false,
        false,
        false,
        true,
        reader,
        output,
        initial_out_offset,
        decoder,
    );
}

/// Shared implementation used by the one-shot specializations in
/// `deflate.zig` and the resumable window API above.
pub inline fn decodeDynamicBlockIntoLinearMode(
    comptime single_distance: bool,
    comptime rle1_distance: bool,
    comptime inline_non_overlap: bool,
    comptime rle258_pair: bool,
    comptime pause_at_output_boundary: bool,
    noalias reader: *bitstream.BufferedBitReader,
    noalias output: []u8,
    initial_out_offset: usize,
    noalias decoder: anytype,
) Error!LinearResult(pause_at_output_boundary) {
    comptime std.debug.assert(!rle1_distance or single_distance);
    const Decoder = @TypeOf(decoder.*);
    const input = reader.input;
    const initial_byte_index = reader.byte_index;
    const initial_bit_count = reader.bit_count;
    const initial_consumed_bits = reader.consumed_bits;
    var bit_buffer = reader.bit_buffer;
    var bit_count = reader.bit_count;
    var byte_index = reader.byte_index;
    var out_pos = initial_out_offset;

    // The fast semantic loop only needs enough destination room for its
    // speculative two-byte literal stores and bounded match writes. A smaller
    // headroom keeps short PNG rows and dynamic-block tails out of the compact
    // fallback decoder without changing the public OutputTooSmall boundary.
    // A non-overlap iteration can retire two paired-literal entries before a
    // maximum-length match, so its unchecked copy needs 4 + 258 bytes.
    const output_headroom: usize = if (pause_at_output_boundary)
        258
    else if (inline_non_overlap)
        262
    else
        16;
    if (out_pos + output_headroom <= output.len and byte_index + 8 <= input.len) {
        refillBits(input, &byte_index, &bit_buffer, &bit_count);
    }
    var entry = decoder.literal[@intCast(bit_buffer & Decoder.literal_lookup_mask)];

    while (out_pos + output_headroom <= output.len and byte_index + 8 <= input.len) {
        if (comptime rle258_pair) {
            if ((bit_buffer & 0b11) == 0 and
                out_pos != 0 and
                output.len - out_pos >= 258)
            {
                bit_buffer >>= 2;
                bit_count -= 2;
                if (bit_count >= Decoder.literal_lookup_bits) {
                    entry = decoder.literal[@intCast(bit_buffer & Decoder.literal_lookup_mask)];
                    refillBits(input, &byte_index, &bit_buffer, &bit_count);
                } else {
                    refillBits(input, &byte_index, &bit_buffer, &bit_count);
                    entry = decoder.literal[@intCast(bit_buffer & Decoder.literal_lookup_mask)];
                }

                const byte = output[out_pos - 1];
                fillLinearRle(output, out_pos, 258, byte);
                out_pos += 258;
                continue;
            }
        }

        if ((entry & SemanticDynamicDecoder.literal_flag) != 0) {
            const entry_bits: u6 = @truncate(entry);
            const entry2 = decoder.literal[
                @as(usize, @intCast((bit_buffer >> @intCast(entry_bits)) & Decoder.literal_lookup_mask))
            ];
            const entry2_bits: u6 = @truncate(entry2);
            const entry12_bits: u6 = entry_bits + entry2_bits;
            const entry3 = decoder.literal[
                @as(usize, @intCast((bit_buffer >> @intCast(entry12_bits)) & Decoder.literal_lookup_mask))
            ];
            const entry3_bits: u6 = @truncate(entry3);
            const entry123_bits: u6 = entry12_bits + entry3_bits;
            const entry4 = decoder.literal[
                @as(usize, @intCast((bit_buffer >> @intCast(entry123_bits)) & Decoder.literal_lookup_mask))
            ];

            const advance1: usize = @intCast((entry >> 8) & 0xf);
            if (comptime rle1_distance or
                (inline_non_overlap and pause_at_output_boundary))
            {
                writeLiteralPair(output, out_pos, entry);
            } else {
                output[out_pos] = @truncate(entry >> 16);
                output[out_pos + 1] = @truncate(entry >> 24);
            }
            out_pos += advance1;

            if ((entry2 & SemanticDynamicDecoder.literal_flag) != 0) {
                const advance2: usize = @intCast((entry2 >> 8) & 0xf);
                if (comptime rle1_distance or
                    (inline_non_overlap and pause_at_output_boundary))
                {
                    writeLiteralPair(output, out_pos, entry2);
                } else {
                    output[out_pos] = @truncate(entry2 >> 16);
                    output[out_pos + 1] = @truncate(entry2 >> 24);
                }
                out_pos += advance2;

                if ((entry3 & SemanticDynamicDecoder.literal_flag) != 0) {
                    const advance3: usize = @intCast((entry3 >> 8) & 0xf);
                    if (comptime rle1_distance or
                        (inline_non_overlap and pause_at_output_boundary))
                    {
                        writeLiteralPair(output, out_pos, entry3);
                    } else {
                        output[out_pos] = @truncate(entry3 >> 16);
                        output[out_pos + 1] = @truncate(entry3 >> 24);
                    }
                    out_pos += advance3;

                    bit_buffer >>= @intCast(entry123_bits);
                    bit_count -= entry123_bits;
                    entry = entry4;
                    refillBits(input, &byte_index, &bit_buffer, &bit_count);
                    continue;
                }

                bit_buffer >>= @intCast(entry12_bits);
                bit_count -= entry12_bits;
                entry = entry3;
            } else {
                bit_buffer >>= @intCast(entry_bits);
                bit_count -= entry_bits;
                entry = entry2;
            }
        }

        // Packed literals leave at least 34 staged bits. That covers the
        // longest LL/extra prefix (20) and the distance primary lookup (8).
        // Restage only when a secondary code or its extras need more bits.
        var match_bits: u6 = @truncate(entry);
        var length_entry: u32 = entry;
        if ((entry & SemanticDynamicDecoder.exceptional_flag) != 0) {
            @branchHint(.unlikely);
            if ((entry & SemanticDynamicDecoder.secondary_flag) != 0) {
                const start: usize = @intCast(entry >> 16);
                const mask: usize = @intCast(entry & 0xff);
                const secondary_index_ = start +
                    secondary_index.suffix(bit_buffer, Decoder.literal_lookup_bits, mask);
                if (secondary_index_ >= decoder.literal_secondary_len) return error.InvalidHuffmanCode;
                const secondary = decoder.literal_secondary[secondary_index_];
                const symbol: u16 = secondary >> 4;
                const secondary_bits: u6 = @truncate(secondary & 0x0f);
                if (symbol < 256) {
                    bit_buffer >>= @intCast(secondary_bits);
                    bit_count -= secondary_bits;
                    output[out_pos] = @truncate(symbol);
                    out_pos += 1;
                    if (bit_count >= Decoder.literal_lookup_bits) {
                        entry = decoder.literal[@intCast(bit_buffer & Decoder.literal_lookup_mask)];
                        refillBits(input, &byte_index, &bit_buffer, &bit_count);
                    } else {
                        refillBits(input, &byte_index, &bit_buffer, &bit_count);
                        entry = decoder.literal[@intCast(bit_buffer & Decoder.literal_lookup_mask)];
                    }
                    continue;
                }
                if (symbol == 256) {
                    bit_buffer >>= @intCast(secondary_bits);
                    bit_count -= secondary_bits;
                    storeReaderStateDelta(
                        reader,
                        bit_buffer,
                        bit_count,
                        byte_index,
                        initial_bit_count,
                        initial_byte_index,
                        initial_consumed_bits,
                    );
                    return linearResult(
                        pause_at_output_boundary,
                        out_pos,
                        .end_of_block,
                    );
                }
                if (symbol > 285) return error.InvalidHuffmanCode;
                const metadata = length_table[symbol - 257];
                length_entry = (@as(u32, @intCast(metadata.base)) << 16) |
                    (@as(u32, metadata.extra_bits) << 8);
                match_bits = secondary_bits;
            } else {
                if (match_bits == 0) return error.InvalidHuffmanCode;
                bit_buffer >>= @intCast(match_bits);
                bit_count -= match_bits;
                storeReaderStateDelta(
                    reader,
                    bit_buffer,
                    bit_count,
                    byte_index,
                    initial_bit_count,
                    initial_byte_index,
                    initial_consumed_bits,
                );
                return linearResult(
                    pause_at_output_boundary,
                    out_pos,
                    .end_of_block,
                );
            }
        }

        var bits = bit_buffer >> @intCast(match_bits);
        const length_extra_bits: u6 = @truncate(length_entry >> 8);
        const length = if (comptime inline_non_overlap and pause_at_output_boundary) blk: {
            if (length_extra_bits == 0) {
                @branchHint(.likely);
                break :blk @as(usize, @intCast(length_entry >> 16));
            }
            const length_mask = (@as(u64, 1) << @intCast(length_extra_bits)) - 1;
            const decoded = @as(usize, @intCast(length_entry >> 16)) + @as(usize, @intCast(bits & length_mask));
            bits >>= @intCast(length_extra_bits);
            break :blk decoded;
        } else blk: {
            const length_mask = (@as(u64, 1) << @intCast(length_extra_bits)) - 1;
            const decoded = @as(usize, @intCast(length_entry >> 16)) + @as(usize, @intCast(bits & length_mask));
            bits >>= @intCast(length_extra_bits);
            break :blk decoded;
        };

        if (comptime rle1_distance) {
            if ((bits & 1) != 0) return error.InvalidHuffmanCode;
            const total_bits: u6 = match_bits + length_extra_bits + 1;
            if (comptime pause_at_output_boundary) {
                if (length > output.len - out_pos) {
                    if (out_pos == 0) return error.InvalidMatch;
                    storeReaderStateDelta(reader, bit_buffer, bit_count, byte_index, initial_bit_count, initial_byte_index, initial_consumed_bits);
                    return .{ .output_written = out_pos, .status = .need_output };
                }
            }
            bit_buffer >>= @intCast(total_bits);
            bit_count -= total_bits;
            if (bit_count >= Decoder.literal_lookup_bits) {
                entry = decoder.literal[@intCast(bit_buffer & Decoder.literal_lookup_mask)];
                refillBits(input, &byte_index, &bit_buffer, &bit_count);
            } else {
                refillBits(input, &byte_index, &bit_buffer, &bit_count);
                entry = decoder.literal[@intCast(bit_buffer & Decoder.literal_lookup_mask)];
            }

            if (out_pos == 0) return error.InvalidMatch;
            if (length > output.len - out_pos) return error.OutputTooSmall;
            fillLinearRle(output, out_pos, length, output[out_pos - 1]);
            out_pos += length;
            continue;
        }

        const distance_start_bits: u6 = match_bits + length_extra_bits;
        var distance_entry: u32 = if (single_distance)
            decoder.single_distance
        else
            decoder.distance[@as(usize, @intCast(bits & SemanticDynamicDecoder.distance_lookup_mask))];
        if ((distance_entry & SemanticDynamicDecoder.literal_flag) == 0) {
            @branchHint(.unlikely);
            if ((distance_entry & SemanticDynamicDecoder.secondary_flag) == 0)
                return error.InvalidHuffmanCode;
            if (bit_count < distance_start_bits + @as(u6, 15)) {
                refillBits(input, &byte_index, &bit_buffer, &bit_count);
                bits = bit_buffer >> distance_start_bits;
            }
            const start: usize = @intCast(distance_entry >> 16);
            const mask: usize = @intCast(distance_entry & 0xff);
            const secondary_index_ = start +
                secondary_index.suffix(bits, SemanticDynamicDecoder.distance_lookup_bits, mask);
            if (secondary_index_ >= decoder.distance_secondary_len) return error.InvalidHuffmanCode;
            const secondary = decoder.distance_secondary[secondary_index_];
            const symbol: u16 = secondary >> 4;
            if (symbol >= distance_table.len) return error.InvalidHuffmanCode;
            const metadata = distance_table[symbol];
            distance_entry = (@as(u32, @intCast(metadata.base)) << 16) |
                (@as(u32, metadata.extra_bits) << 8) |
                @as(u32, @truncate(secondary & 0x0f));
        }
        const distance_code_bits: u6 = @truncate(distance_entry);
        if (single_distance and
            (bits & ((@as(u64, 1) << @intCast(distance_code_bits)) - 1)) != 0)
        {
            return error.InvalidHuffmanCode;
        }
        const distance_extra_bits: u6 = @truncate(distance_entry >> 8);
        const total_bits: u6 = distance_start_bits + distance_code_bits + distance_extra_bits;
        if (bit_count < total_bits) refillBits(input, &byte_index, &bit_buffer, &bit_count);
        bits = bit_buffer >> (distance_start_bits + distance_code_bits);
        const distance_mask = (@as(u64, 1) << @intCast(distance_extra_bits)) - 1;
        const distance = @as(usize, @intCast(distance_entry >> 16)) + @as(usize, @intCast(bits & distance_mask));
        if (comptime pause_at_output_boundary) {
            if (length > output.len - out_pos) {
                // Packed literals may have consumed the loop's original 258
                // bytes of headroom. Keep their progress, but leave this match
                // at its token start. Invalid distance retains fast-loop priority.
                if (distance == 0 or distance > out_pos) return error.InvalidMatch;
                storeReaderStateDelta(reader, bit_buffer, bit_count, byte_index, initial_bit_count, initial_byte_index, initial_consumed_bits);
                return .{ .output_written = out_pos, .status = .need_output };
            }
        }

        bit_buffer >>= @intCast(total_bits);
        bit_count -= total_bits;
        if (bit_count >= Decoder.literal_lookup_bits) {
            entry = decoder.literal[@intCast(bit_buffer & Decoder.literal_lookup_mask)];
            refillBits(input, &byte_index, &bit_buffer, &bit_count);
        } else {
            refillBits(input, &byte_index, &bit_buffer, &bit_count);
            entry = decoder.literal[@intCast(bit_buffer & Decoder.literal_lookup_mask)];
        }
        if (comptime inline_non_overlap) {
            if (distance >= length) {
                @branchHint(.likely);
                if (distance > out_pos) return error.InvalidMatch;
                if (comptime pause_at_output_boundary) {
                    if (length > output.len - out_pos) return error.OutputTooSmall;
                    if (!png_non_overlap.copyShortWindowMatch(
                        output,
                        out_pos,
                        length,
                        distance,
                    )) {
                        @memcpy(output[out_pos..][0..length], output[out_pos - distance ..][0..length]);
                    }
                } else {
                    std.debug.assert(length <= output.len - out_pos);
                    if (length <= 16 and distance >= 16) {
                        @branchHint(.likely);
                        const source: *align(1) const [16]u8 = @ptrCast(output[out_pos - distance ..].ptr);
                        const destination: *align(1) [16]u8 = @ptrCast(output[out_pos..].ptr);
                        destination.* = source.*;
                    } else {
                        @memcpy(output[out_pos..][0..length], output[out_pos - distance ..][0..length]);
                    }
                }
            } else {
                try copyMatchAt(output, out_pos, length, distance);
            }
        } else if (distance == 1) {
            if (out_pos == 0) return error.InvalidMatch;
            if (length > output.len - out_pos) return error.OutputTooSmall;
            fillLinearRle(output, out_pos, length, output[out_pos - 1]);
        } else if (distance >= length) {
            if (distance > out_pos) return error.InvalidMatch;
            if (length > output.len - out_pos) return error.OutputTooSmall;
            if (length <= 16 and distance >= 16 and out_pos + 16 <= output.len) {
                @branchHint(.likely);
                const source: *align(1) const [16]u8 = @ptrCast(output[out_pos - distance ..].ptr);
                const destination: *align(1) [16]u8 = @ptrCast(output[out_pos..].ptr);
                destination.* = source.*;
            } else if (distance >= 16 and out_pos + 258 <= output.len) {
                // Fixed-width inline vector moves with one overlapping tail
                // store; the 258-byte loop headroom bounds every speculative
                // byte, so no runtime-length compiler-rt memcpy is needed.
                shortcopy.copyWideAtLeast16(output[out_pos..][0..length], output[out_pos - distance ..][0..length], length);
            } else {
                shortcopy.copy(output[out_pos..][0..length], output[out_pos - distance ..][0..length], length);
            }
        } else {
            try copyMatchAt(output, out_pos, length, distance);
        }
        out_pos += length;
    }

    storeReaderStateDelta(
        reader,
        bit_buffer,
        bit_count,
        byte_index,
        initial_bit_count,
        initial_byte_index,
        initial_consumed_bits,
    );
    if (comptime pause_at_output_boundary) {
        return decodeTailWindow(reader, decoder, output, out_pos);
    }
    while (true) {
        switch (try decodeTailSymbol(reader, decoder)) {
            .literal => |literal| {
                if (out_pos == output.len) return error.OutputTooSmall;
                output[out_pos] = literal;
                out_pos += 1;
            },
            .double_literal => |literal_pair| {
                if (output.len - out_pos < 2) return error.OutputTooSmall;
                output[out_pos] = literal_pair[0];
                output[out_pos + 1] = literal_pair[1];
                out_pos += 2;
            },
            .length => |length_info| {
                const length = length_info.base + try readExtraBits(reader, length_info.extra_bits);
                const distance_symbol = try decoder.compact_distance.decodeValue(reader);
                const distance = try decodeDistance(distance_symbol, reader);
                try copyMatchAt(output, out_pos, length, distance);
                out_pos += length;
            },
            .eob => return linearResult(
                pause_at_output_boundary,
                out_pos,
                .end_of_block,
            ),
        }
    }
}

fn decodeTailWindow(
    reader: *bitstream.BufferedBitReader,
    decoder: *const SemanticDynamicDecoder,
    output: []u8,
    initial_out_pos: usize,
) Error!LinearStep {
    var out_pos = initial_out_pos;
    while (true) {
        const saved_reader = reader.*;
        switch (try decodeTailSymbol(reader, decoder)) {
            .literal => |literal| {
                if (out_pos == output.len) {
                    reader.* = saved_reader;
                    return .{ .output_written = out_pos, .status = .need_output };
                }
                output[out_pos] = literal;
                out_pos += 1;
            },
            .double_literal => |pair| {
                if (output.len - out_pos < 2) {
                    if (out_pos != output.len) {
                        // The packed entry represents two independent literal
                        // codes. When exactly one caller byte remains, commit
                        // the first through the compact table so limit/error
                        // progress matches the scalar decoder instead of
                        // rolling the otherwise valid literal back with its
                        // successor.
                        reader.* = saved_reader;
                        const first = try decoder.compact_literal.decodeValue(reader);
                        if (first >= 256) return error.InvalidHuffmanCode;
                        output[out_pos] = @truncate(first);
                        out_pos += 1;
                        continue;
                    }
                    reader.* = saved_reader;
                    return .{ .output_written = out_pos, .status = .need_output };
                }
                output[out_pos] = pair[0];
                output[out_pos + 1] = pair[1];
                out_pos += 2;
            },
            .length => |length_info| {
                const length = length_info.base + try readExtraBits(reader, length_info.extra_bits);
                const distance_symbol = try decoder.compact_distance.decodeValue(reader);
                const distance = try decodeDistance(distance_symbol, reader);
                if (length > output.len - out_pos) {
                    reader.* = saved_reader;
                    return .{ .output_written = out_pos, .status = .need_output };
                }
                try copyMatchAt(output, out_pos, length, distance);
                out_pos += length;
            },
            .eob => return .{ .output_written = out_pos, .status = .end_of_block },
        }
    }
}

const RollingError = Error;
const RollingStep = LinearStep;
pub const RollingStrategy = struct {
    pub const Error = RollingError;
    pub const LinearStep = RollingStep;
    pub const decodeTail = decodeTailSymbol;
    pub const extraOf = readExtraBits;
    pub const distanceOf = decodeDistance;
    pub const publishReader = storeReaderStateDelta;
    pub const refill = refillBits;
    pub const oldWindow = decodeDynamicBlockIntoWindow;
};

pub const TailSymbol = union(enum) {
    literal: u8,
    double_literal: [2]u8,
    length: struct { base: usize, extra_bits: u6 },
    eob,
};

fn decodeTailSymbol(reader: *bitstream.BufferedBitReader, decoder: anytype) Error!TailSymbol {
    const Decoder = @TypeOf(decoder.*);
    const peek = reader.peekBitsPadded(u16, Decoder.literal_lookup_bits);
    const entry = decoder.literal[peek];
    var entry_bits: u6 = @truncate(entry);
    if ((entry & SemanticDynamicDecoder.literal_flag) != 0) {
        const literal_count: usize = @intCast((entry >> 8) & 0xf);
        if (!reader.hasStagedBits(entry_bits)) return error.TruncatedFrame;
        reader.advanceBitsStagedAssumeAvailable(entry_bits);
        if (literal_count == 2) return .{ .double_literal = .{ @truncate(entry >> 16), @truncate(entry >> 24) } };
        return .{ .literal = @truncate(entry >> 16) };
    }

    if ((entry & SemanticDynamicDecoder.exceptional_flag) != 0 and
        (entry & SemanticDynamicDecoder.secondary_flag) != 0)
    {
        const start: usize = @intCast(entry >> 16);
        const mask: usize = @intCast(entry & 0xff);
        const suffix: usize = @intCast(reader.peekBitsPadded(u16, 15) >> Decoder.literal_lookup_bits);
        const secondary_index_ = start + (suffix & mask);
        if (secondary_index_ >= decoder.literal_secondary_len) return error.InvalidHuffmanCode;
        const secondary = decoder.literal_secondary[secondary_index_];
        const symbol: u16 = secondary >> 4;
        entry_bits = @truncate(secondary & 0x0f);
        if (!reader.hasStagedBits(entry_bits)) return error.TruncatedFrame;
        reader.advanceBitsStagedAssumeAvailable(entry_bits);
        if (symbol < 256) return .{ .literal = @truncate(symbol) };
        if (symbol == 256) return .eob;
        if (symbol > 285) return error.InvalidHuffmanCode;
        const metadata = length_table[symbol - 257];
        return .{ .length = .{ .base = metadata.base, .extra_bits = metadata.extra_bits } };
    }

    if ((entry & SemanticDynamicDecoder.exceptional_flag) == 0) {
        if (!reader.hasStagedBits(entry_bits)) return error.TruncatedFrame;
        reader.advanceBitsStagedAssumeAvailable(entry_bits);
        return .{ .length = .{ .base = @intCast(entry >> 16), .extra_bits = @truncate(entry >> 8) } };
    }

    if (entry_bits == 0) return error.InvalidHuffmanCode;
    if (!reader.hasStagedBits(entry_bits)) return error.TruncatedFrame;
    reader.advanceBitsStagedAssumeAvailable(entry_bits);
    return .eob;
}

inline fn refillBits(input: []const u8, byte_index: *usize, bit_buffer: *u64, bit_count: *usize) void {
    if (bit_count.* >= 56) return;
    // Restaging a long token can use the loop's last eight-byte read before
    // its normal next-entry refill. Leave shorter input to the bounded tail.
    if (input.len - byte_index.* < 8) return;
    const bytes_to_stage = (63 - bit_count.*) / 8;
    bit_buffer.* |= std.mem.readInt(u64, input[byte_index.*..][0..8], .little) << @intCast(bit_count.*);
    bit_count.* += bytes_to_stage * 8;
    byte_index.* += bytes_to_stage;
}

inline fn storeReaderStateDelta(
    reader: *bitstream.BufferedBitReader,
    bit_buffer: u64,
    final_bit_count: usize,
    final_byte_index: usize,
    initial_bit_count: usize,
    initial_byte_index: usize,
    initial_consumed_bits: BitCount,
) void {
    std.debug.assert(final_byte_index >= initial_byte_index);
    const newly_staged = bit_geometry.fromBytesAssumeBounded(final_byte_index - initial_byte_index);
    const staged_during_call = @as(BitCount, initial_bit_count) + newly_staged;
    std.debug.assert(@as(BitCount, final_bit_count) <= staged_during_call);
    reader.bit_buffer = bit_buffer;
    reader.bit_count = final_bit_count;
    reader.byte_index = final_byte_index;
    reader.consumed_bits = initial_consumed_bits + staged_during_call - @as(BitCount, final_bit_count);
}

inline fn writeLiteralPair(output: []u8, out_pos: usize, entry: u32) void {
    std.debug.assert(output.len - out_pos >= 2);
    std.mem.writeInt(u16, output[out_pos..][0..2], @truncate(entry >> 16), .little);
}

inline fn fillLinearRle(output: []u8, out_pos: usize, length: usize, byte: u8) void {
    std.debug.assert(length != 0);
    std.debug.assert(out_pos <= output.len and length <= output.len - out_pos);
    const repeated: @Vector(64, u8) = @splat(byte);
    var copied: usize = 0;
    while (copied + 64 <= length) : (copied += 64) {
        output[out_pos + copied ..][0..64].* = @bitCast(repeated);
    }
    if (copied == length) return;

    const tail_pos = out_pos + copied;
    if (output.len - tail_pos >= 64) {
        output[tail_pos..][0..64].* = @bitCast(repeated);
    } else {
        @memset(output[tail_pos..][0 .. length - copied], byte);
    }
}

inline fn decodeDistance(symbol: u16, reader: anytype) Error!usize {
    if (symbol >= distance_table.len) return error.InvalidHuffmanCode;
    if (symbol < 4) return symbol + 1;
    const entry = distance_table[symbol];
    return entry.base + try readExtraBits(reader, entry.extra_bits);
}

inline fn readExtraBits(reader: anytype, count: u6) Error!usize {
    std.debug.assert(count <= 13);
    if (count == 0) return 0;
    const extra = reader.peekBitsPadded(u16, count);
    if (!reader.hasStagedBits(count)) return error.TruncatedFrame;
    reader.advanceBitsStagedAssumeAvailable(count);
    return extra;
}

fn copyMatchAt(output: []u8, out_offset: usize, length: usize, distance: usize) Error!void {
    if (distance == 0 or distance > out_offset) return error.InvalidMatch;
    if (out_offset > output.len or output.len - out_offset < length) return error.OutputTooSmall;
    const dest = output[out_offset..][0..length];
    if (distance == 1) {
        @memset(dest, output[out_offset - 1]);
        return;
    }
    if (distance <= 4) {
        copySmallDistanceMatch(dest, output[out_offset - distance ..], distance);
        return;
    }
    if (distance >= length) {
        @memcpy(dest, output[out_offset - distance ..][0..length]);
        return;
    }
    copyOverlappingMatchAt(output, out_offset, length, distance);
}

fn copySmallDistanceMatch(dest: []u8, pattern: []const u8, distance: usize) void {
    if (dest.len >= 16) return repeatSmallPatternByDoubling(dest, pattern[0..distance]);
    switch (distance) {
        1 => @memset(dest, pattern[0]),
        2 => {
            const a = pattern[0];
            const b = pattern[1];
            var i: usize = 0;
            while (i + 2 <= dest.len) : (i += 2) {
                dest[i] = a;
                dest[i + 1] = b;
            }
            if (i < dest.len) dest[i] = a;
        },
        3 => {
            const a = pattern[0];
            const b = pattern[1];
            const c = pattern[2];
            var i: usize = 0;
            while (i + 3 <= dest.len) : (i += 3) {
                dest[i] = a;
                dest[i + 1] = b;
                dest[i + 2] = c;
            }
            if (i < dest.len) {
                dest[i] = a;
                i += 1;
            }
            if (i < dest.len) dest[i] = b;
        },
        4 => {
            const a = pattern[0];
            const b = pattern[1];
            const c = pattern[2];
            const d = pattern[3];
            var i: usize = 0;
            while (i + 4 <= dest.len) : (i += 4) {
                dest[i] = a;
                dest[i + 1] = b;
                dest[i + 2] = c;
                dest[i + 3] = d;
            }
            if (i < dest.len) {
                dest[i] = a;
                i += 1;
            }
            if (i < dest.len) {
                dest[i] = b;
                i += 1;
            }
            if (i < dest.len) dest[i] = c;
        },
        else => unreachable,
    }
}

fn repeatSmallPatternByDoubling(dest: []u8, pattern: []const u8) void {
    const seed = @min(pattern.len, dest.len);
    @memcpy(dest[0..seed], pattern[0..seed]);
    var copied = seed;
    while (copied < dest.len) {
        const n = @min(copied, dest.len - copied);
        @memcpy(dest[copied..][0..n], dest[0..n]);
        copied += n;
    }
}

fn copyOverlappingMatchAt(output: []u8, out_offset: usize, length: usize, distance: usize) void {
    const first = @min(distance, length);
    @memcpy(output[out_offset..][0..first], output[out_offset - distance ..][0..first]);
    var copied = first;
    while (copied < length) {
        const n = @min(copied, length - copied);
        @memcpy(output[out_offset + copied ..][0..n], output[out_offset..][0..n]);
        copied += n;
    }
}

test "linear reader accounting supports a preloaded reservoir" {
    var reader = bitstream.BufferedBitReader.init(&.{});
    reader.bit_buffer = 0x1f;
    reader.bit_count = 11;
    reader.consumed_bits = 13;

    storeReaderStateDelta(&reader, 0x7, 20, 3, 11, 0, 13);

    // 11 initial bits plus 24 newly staged bits minus 20 retained bits.
    try std.testing.expectEqual(@as(BitCount, 28), reader.consumed_bits);
    try std.testing.expectEqual(@as(usize, 3), reader.byte_index);
    try std.testing.expectEqual(@as(usize, 20), reader.bit_count);
}

test "semantic window packed literals pause before a non-fitting match" {
    try @import("window_capacity_tests.zig").packedCapacity();
}

test "semantic window restages before a maximum length distance token" {
    try @import("window_capacity_tests.zig").longToken();
}

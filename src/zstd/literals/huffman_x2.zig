const std = @import("std");
const builtin = @import("builtin");
const bit_reader = @import("../sequence/bit_reader.zig");
const reservoir = @import("huffman_reservoir.zig");
const abi = @import("huffman_x2_abi.zig");

const default_text_section = switch (builtin.object_format) {
    .elf => ".text",
    .macho => "__TEXT,__text",
    .coff => ".text",
    else => ".text",
};

pub const wide_text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_huffman_wide_x2",
    .macho => "__TEXT,__vort_zstd_hwx2",
    .coff => ".text$vort_zstd_huffman_wide_x2",
    else => ".text",
};

pub const Entry = packed struct(u32) {
    sequence: u16,
    bit_count: u8,
    symbol_count: u8,
};

pub fn Table(comptime target_bits: u4) type {
    return struct {
        pub const bit_width = target_bits;
        pub const len = @as(usize, 1) << target_bits;
        const text_section = if (target_bits == 14) wide_text_section else default_text_section;
        entries: [len]Entry,

        pub noinline fn buildComplete(self: *@This(), tree: anytype) linksection(text_section) bool {
            const table_log: u4 = tree.max_bit_count;
            if (table_log == 0 or table_log > target_bits) return false;
            const baseline: u5 = @as(u5, table_log) + 1;
            const nodes = tree.nodes[0 .. @as(usize, tree.symbol_count_minus_one) + 1];
            var counts: [16]usize = @splat(0);
            var max_weight: u4 = 0;
            for (nodes) |node| {
                if (node.weight > baseline) return false;
                counts[node.weight] += 1;
                max_weight = @max(max_weight, node.weight);
            }
            if (max_weight == 0) return false;

            var rank_start: [18]usize = @splat(0);
            var symbol_count: usize = 0;
            for (1..@as(usize, max_weight) + 1) |weight| {
                rank_start[weight] = symbol_count;
                symbol_count += counts[weight];
            }
            rank_start[@as(usize, max_weight) + 1] = symbol_count;
            if (symbol_count != nodes.len) return false;

            var rank_values: [@as(usize, target_bits) + 1][16]usize = @splat(@splat(0));
            const rescale: i8 = @as(i8, target_bits) - @as(i8, table_log) - 1;
            var next_value: usize = 0;
            for (1..@as(usize, max_weight) + 1) |weight| {
                rank_values[0][weight] = next_value;
                const shift: u4 = @intCast(@as(i8, @intCast(weight)) + rescale);
                next_value += counts[weight] << shift;
            }
            if (next_value != len) return false;
            const min_bits: u4 = @intCast(baseline - max_weight);
            for (min_bits..@as(usize, target_bits - min_bits) + 1) |consumed| {
                for (1..@as(usize, max_weight) + 1) |weight|
                    rank_values[consumed][weight] = rank_values[0][weight] >> @intCast(consumed);
            }

            const scale_log: i8 = @as(i8, baseline) - @as(i8, target_bits);
            for (1..@as(usize, max_weight) + 1) |weight| {
                const begin = rank_start[weight];
                const end = rank_start[weight + 1];
                const first_bits: u4 = @intCast(baseline - @as(u5, @intCast(weight)));
                if (target_bits - first_bits >= min_bits) {
                    const subtable_len = @as(usize, 1) << (target_bits - first_bits);
                    var start = rank_values[0][weight];
                    var min_second_weight: i8 = @as(i8, first_bits) + scale_log;
                    if (min_second_weight < 1) min_second_weight = 1;
                    for (nodes[begin..end]) |first| {
                        if (start > len or subtable_len > len - start) return false;
                        fillLevel2(self.entries[start..][0..subtable_len], first_bits, @intCast(min_second_weight), max_weight, &rank_values[first_bits], &rank_start, nodes, baseline, first.symbol);
                        start += subtable_len;
                    }
                } else {
                    fillSymbols(self.entries[rank_values[0][weight]..], nodes[begin..end], first_bits, target_bits, 0, 1);
                }
            }
            return true;
        }

        inline fn lookup(self: *const @This(), bits: usize) Entry {
            return self.entries[bits];
        }

        fn fillLevel2(table: []Entry, first_bits: u4, min_weight: u4, max_weight: u4, rank_values: *const [16]usize, rank_start: *const [18]usize, nodes: anytype, baseline: u5, first_symbol: u8) linksection(text_section) void {
            if (min_weight > 1) {
                const one_symbol_len = rank_values[min_weight];
                fillEntries(table[0..one_symbol_len], .{ .sequence = first_symbol, .bit_count = first_bits, .symbol_count = 1 });
            }
            for (min_weight..@as(usize, max_weight) + 1) |weight| {
                const second_bits: u4 = @intCast(baseline - @as(u5, @intCast(weight)));
                fillSymbols(table[rank_values[weight]..], nodes[rank_start[weight]..rank_start[weight + 1]], first_bits + second_bits, target_bits, first_symbol, 2);
            }
        }

        fn fillSymbols(table: []Entry, nodes: anytype, bit_count: u4, table_bits: u4, first_symbol: u8, symbol_count: u8) linksection(text_section) void {
            const repeat = @as(usize, 1) << (table_bits - bit_count);
            var offset: usize = 0;
            for (nodes) |node| {
                fillEntries(table[offset..][0..repeat], .{
                    .sequence = if (symbol_count == 1) node.symbol else @as(u16, first_symbol) | (@as(u16, node.symbol) << 8),
                    .bit_count = bit_count,
                    .symbol_count = symbol_count,
                });
                offset += repeat;
            }
        }

        inline fn fillEntries(dest: []Entry, entry: Entry) void {
            var index: usize = 0;
            while (dest.len - index >= 8) : (index += 8) {
                const wide: *align(1) [8]Entry = @ptrCast(dest[index..].ptr);
                wide.* = @splat(entry);
            }
            while (index < dest.len) : (index += 1) dest[index] = entry;
        }
    };
}

fn decode(tree: anytype, streams: [4][]const u8, lookup: *const Table(11), dest: []u8) !void {
    const segment_len = (dest.len + 3) / 4;
    var readers = [4]bit_reader.Reader{
        try bit_reader.Reader.init(streams[0]),
        try bit_reader.Reader.init(streams[1]),
        try bit_reader.Reader.init(streams[2]),
        try bit_reader.Reader.init(streams[3]),
    };
    var positions = [4]usize{ 0, segment_len, segment_len * 2, segment_len * 3 };
    const ends = [4]usize{ segment_len, segment_len * 2, segment_len * 3, dest.len };
    if (readers[0].available() > 56 and readers[1].available() > 56 and readers[2].available() > 56 and readers[3].available() > 56)
        decodeReservoir(&readers, &positions, ends, lookup, dest);

    for (0..4) |stream_index| {
        var cursor = readers[stream_index];
        var position = positions[stream_index];
        const end = ends[stream_index];
        while (end - position >= 2 and cursor.available() >= Table(11).bit_width) {
            const entry = lookup.lookup(cursor.peekBulkHuffman(Table(11).bit_width));
            std.mem.writeInt(u16, dest[position..][0..2], entry.sequence, .little);
            cursor.skipBulkHuffman(entry.bit_count);
            position += entry.symbol_count;
        }
        while (position < end) : (position += 1) dest[position] = try readCold(&cursor, tree);
        try cursor.expectEnd();
    }
}

fn decodeWide(tree: anytype, streams: [4][]const u8, lookup: *const Table(14), dest: []u8) linksection(wide_text_section) !void {
    const segment_len = (dest.len + 3) / 4;
    var readers = [4]bit_reader.Reader{
        try bit_reader.Reader.init(streams[0]),
        try bit_reader.Reader.init(streams[1]),
        try bit_reader.Reader.init(streams[2]),
        try bit_reader.Reader.init(streams[3]),
    };
    var positions = [4]usize{ 0, segment_len, segment_len * 2, segment_len * 3 };
    const ends = [4]usize{ segment_len, segment_len * 2, segment_len * 3, dest.len };
    if (readers[0].available() > 56 and readers[1].available() > 56 and readers[2].available() > 56 and readers[3].available() > 56)
        WideReservoirDecoder.run(&readers, &positions, ends, lookup, dest);

    for (0..4) |stream_index| {
        var cursor = readers[stream_index];
        var position = positions[stream_index];
        const end = ends[stream_index];
        while (end - position >= 2 and cursor.available() >= Table(14).bit_width) {
            const entry = lookup.lookup(cursor.peekBulkHuffman(Table(14).bit_width));
            std.debug.assert(entry.symbol_count == 2);
            std.mem.writeInt(u16, dest[position..][0..2], entry.sequence, .little);
            cursor.skipBulkHuffman(entry.bit_count);
            position += entry.symbol_count;
        }
        while (position < end) : (position += 1) dest[position] = try readCold(&cursor, tree);
        try cursor.expectEnd();
    }
}

const WideReservoirDecoder = if (builtin.cpu.arch.isWasm()) struct {
    noinline fn run(readers: *[4]bit_reader.Reader, positions: *[4]usize, ends: [4]usize, lookup: *const Table(14), dest: []u8) linksection(wide_text_section) void {
        decodeWideReservoirImpl(readers, positions, ends, lookup, dest);
    }
} else struct {
    noinline fn run(readers: *[4]bit_reader.Reader, positions: *[4]usize, ends: [4]usize, lookup: *const Table(14), dest: []u8) align(64) linksection(wide_text_section) void {
        decodeWideReservoirImpl(readers, positions, ends, lookup, dest);
    }
};

inline fn decodeWideReservoirImpl(readers: *[4]bit_reader.Reader, positions: *[4]usize, ends: [4]usize, lookup: *const Table(14), dest: []u8) void {
    var output_positions = positions.*;
    var reservoirs = [4]reservoir.Reservoir{
        reservoir.Reservoir.init(readers[0]) orelse unreachable,
        reservoir.Reservoir.init(readers[1]) orelse unreachable,
        reservoir.Reservoir.init(readers[2]) orelse unreachable,
        reservoir.Reservoir.init(readers[3]) orelse unreachable,
    };
    while (ends[3] - output_positions[3] >= 8 and
        reservoirs[0].canDecodeFourWide(Table(14).bit_width) and reservoirs[1].canDecodeFourWide(Table(14).bit_width) and
        reservoirs[2].canDecodeFourWide(Table(14).bit_width) and reservoirs[3].canDecodeFourWide(Table(14).bit_width))
    {
        inline for (0..4) |_| inline for (0..4) |stream_index| {
            const entry = lookup.lookup(reservoirs[stream_index].peek(Table(14).bit_width));
            std.debug.assert(entry.symbol_count == 2);
            std.mem.writeInt(u16, dest[output_positions[stream_index]..][0..2], entry.sequence, .little);
            output_positions[stream_index] += 2;
            reservoirs[stream_index].consume(entry.bit_count);
        };
        inline for (0..4) |stream_index| reservoirs[stream_index].reload();
    }
    inline for (0..4) |stream_index| {
        readers[stream_index].remaining_bits = reservoirs[stream_index].remainingBits();
        positions[stream_index] = output_positions[stream_index];
    }
}

noinline fn decodeReservoir(readers: *[4]bit_reader.Reader, positions: *[4]usize, ends: [4]usize, lookup: *const Table(11), dest: []u8) void {
    var output_positions = positions.*;
    var reservoirs = [4]reservoir.Reservoir{
        reservoir.Reservoir.init(readers[0]) orelse unreachable,
        reservoir.Reservoir.init(readers[1]) orelse unreachable,
        reservoir.Reservoir.init(readers[2]) orelse unreachable,
        reservoir.Reservoir.init(readers[3]) orelse unreachable,
    };
    while (ends[0] - output_positions[0] >= 10 and ends[1] - output_positions[1] >= 10 and
        ends[2] - output_positions[2] >= 10 and ends[3] - output_positions[3] >= 10 and
        reservoirs[0].canDecodeFive(Table(11).bit_width) and reservoirs[1].canDecodeFive(Table(11).bit_width) and
        reservoirs[2].canDecodeFive(Table(11).bit_width) and reservoirs[3].canDecodeFive(Table(11).bit_width))
    {
        inline for (0..5) |_| inline for (0..4) |stream_index| {
            const entry = lookup.lookup(reservoirs[stream_index].peek(Table(11).bit_width));
            std.mem.writeInt(u16, dest[output_positions[stream_index]..][0..2], entry.sequence, .little);
            output_positions[stream_index] += entry.symbol_count;
            reservoirs[stream_index].consume(entry.bit_count);
        };
        inline for (0..4) |stream_index| reservoirs[stream_index].reload();
    }
    inline for (0..4) |stream_index| {
        readers[stream_index].remaining_bits = reservoirs[stream_index].remainingBits();
        positions[stream_index] = output_positions[stream_index];
    }
}

fn readCold(reader: *bit_reader.Reader, tree: anytype) !u8 {
    const max_bit_count: u4 = tree.max_bit_count;
    var tree_index: usize = tree.symbol_count_minus_one;
    var bits_read: u4 = 0;
    var bit_count_to_read: u4 = max_bit_count + 1 - tree.nodes[tree_index].weight;
    var prefix: u16 = 0;
    while (true) {
        const bits = try reader.read(bit_count_to_read);
        prefix = (prefix << bit_count_to_read) | @as(u16, @intCast(bits));
        bits_read += bit_count_to_read;
        const weight = tree.nodes[tree_index].weight;
        var index = tree_index;
        while (tree.nodes[index].weight == weight) {
            if (tree.nodes[index].prefix == prefix) return tree.nodes[index].symbol;
            if (index == 0) return error.CorruptFrame;
            index -= 1;
        }
        tree_index = index;
        const next_bit_count: u4 = max_bit_count + 1 - tree.nodes[index].weight;
        if (next_bit_count <= bits_read) return error.CorruptFrame;
        bit_count_to_read = next_bit_count - bits_read;
    }
}

pub fn decodeRequest(request: *const abi.Request) abi.Status {
    const Tree = std.compress.zstd.Decompress.LiteralsSection.HuffmanTree;
    const tree: *const Tree = @ptrCast(@alignCast(request.tree));
    var table: Table(11) = undefined;
    if (!table.buildComplete(tree)) return .unsupported;
    const streams = [4][]const u8{
        request.stream_ptrs[0][0..request.stream_lens[0]],
        request.stream_ptrs[1][0..request.stream_lens[1]],
        request.stream_ptrs[2][0..request.stream_lens[2]],
        request.stream_ptrs[3][0..request.stream_lens[3]],
    };
    decode(tree, streams, &table, request.dest_ptr[0..request.dest_len]) catch |err| return switch (err) {
        error.TruncatedFrame => .truncated,
        else => .corrupt,
    };
    return .success;
}

pub fn decodeWideRequest(request: *const abi.Request) linksection(wide_text_section) abi.Status {
    const Tree = std.compress.zstd.Decompress.LiteralsSection.HuffmanTree;
    const tree: *const Tree = @ptrCast(@alignCast(request.tree));
    if (tree.max_bit_count != 7 or request.dest_len < 64 * 1024) return .unsupported;
    const streams = [4][]const u8{
        request.stream_ptrs[0][0..request.stream_lens[0]],
        request.stream_ptrs[1][0..request.stream_lens[1]],
        request.stream_ptrs[2][0..request.stream_lens[2]],
        request.stream_ptrs[3][0..request.stream_lens[3]],
    };
    var table: Table(14) = undefined;
    if (!table.buildComplete(tree)) return .unsupported;
    decodeWide(tree, streams, &table, request.dest_ptr[0..request.dest_len]) catch |err| return switch (err) {
        error.TruncatedFrame => .truncated,
        else => .corrupt,
    };
    return .success;
}

test "wide X2 table pairs every pair of seven-bit symbols" {
    const Node = struct {
        symbol: u8,
        prefix: u16,
        weight: u4,
    };
    const Tree = struct {
        max_bit_count: u4,
        symbol_count_minus_one: u8,
        nodes: [256]Node,
    };
    var tree: Tree = undefined;
    tree.max_bit_count = 7;
    tree.symbol_count_minus_one = 127;
    for (tree.nodes[0..128], 0..) |*node, symbol| {
        node.* = .{
            .symbol = @intCast(symbol),
            .prefix = @intCast(symbol),
            .weight = 1,
        };
    }
    var table: Table(14) = undefined;
    try std.testing.expect(table.buildComplete(&tree));
    for (table.entries, 0..) |entry, index| {
        try std.testing.expectEqual(@as(u8, 2), entry.symbol_count);
        try std.testing.expectEqual(@as(u8, 14), entry.bit_count);
        try std.testing.expectEqual(@as(u16, @intCast((index >> 7) | ((index & 0x7f) << 8))), entry.sequence);
    }
}

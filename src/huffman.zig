const std = @import("std");
const builtin = @import("builtin");

const zstd_dense_text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_dense_huffman",
    .macho => "__TEXT,__vort_zstd_huf",
    .coff => ".text$vort_zstd_dense_huffman",
    else => ".text",
};
const deflate_dense_text_section = switch (builtin.object_format) {
    .elf => ".vort_deflate_dense_huffman",
    .macho => "__TEXT,__vort_dfl_dhuf",
    .coff => ".text$vort_deflate_dense_huffman",
    else => ".text",
};
const bitstream = @import("bitstream.zig");
const core = @import("core.zig");

pub const Error = core.Error;

pub const max_code_bits = 15;
pub const fixed_literal_count = 288;
pub const fixed_distance_count = 32;

pub const Symbol = struct {
    value: u16,
    bits: u4,
};

inline fn hasDecodedBits(reader: anytype, count: u4) bool {
    const Reader = switch (@typeInfo(@TypeOf(reader))) {
        .pointer => |ptr| ptr.child,
        else => @TypeOf(reader),
    };
    // Fast Huffman decode always calls `peekBitsPadded` before this check. The
    // buffered/chunked readers use that peek to stage exactly the bytes they
    // could actually read, so testing the staged reservoir avoids a second
    // total-remaining-bits calculation in the hot path while still rejecting
    // padded lookup hits that do not have enough real input bits.
    if (comptime @hasDecl(Reader, "hasStagedBits")) {
        return reader.hasStagedBits(count);
    }
    return reader.hasBits(count);
}

pub fn HuffmanTable(comptime max_symbols: usize) type {
    return struct {
        entries: [max_symbols]Entry = undefined,
        len: usize = 0,
        max_bits: u4 = 0,
        /// Entries are grouped by code width so long-code fallback can scan
        /// only the symbols that could match the current bit count. Dynamic
        /// DEFLATE text/source blocks often miss the fast lookup on cold
        /// literals; avoiding a full active-symbol scan on each miss keeps the
        /// compact table representation without paying O(symbols * bit_width).
        first_by_bits: [max_code_bits + 1]u16 = @splat(0),
        count_by_bits: [max_code_bits + 1]u16 = @splat(0),

        const Self = @This();
        pub const Entry = struct {
            symbol: u16,
            code: u16,
            bits: u4,
        };

        pub const Encoder = struct {
            codes: [max_symbols]u16 = @splat(0),
            bits: [max_symbols]u4 = @splat(0),
            const max_sparse_symbols = 64;

            pub fn init(lengths: []const u4) Error!Encoder {
                @setEvalBranchQuota(20_000);
                if (lengths.len > max_symbols) return error.CorruptFrame;
                var counts: [max_code_bits + 1]u16 = @splat(0);
                var max_bits_seen: u4 = 0;
                for (lengths) |code_bits| {
                    if (code_bits > max_code_bits) return error.CorruptFrame;
                    if (code_bits != 0) {
                        counts[code_bits] += 1;
                        max_bits_seen = @max(max_bits_seen, code_bits);
                    }
                }
                if (max_bits_seen == 0) return .{};

                // Canonical encoder construction only needs the length
                // histogram and next-code recurrence. The previous path built
                // a fully bucketed decoder table first, then scanned it again
                // to reconstruct these two arrays. Dynamic DEFLATE builds three
                // encoders per block, so skipping that intermediate table also
                // removes its active-symbol list and bucket write passes.
                var available: i32 = 1;
                var code: u16 = 0;
                var next_code: [max_code_bits + 1]u16 = @splat(0);
                for (1..max_code_bits + 1) |code_bits| {
                    available = (available << 1) - @as(i32, counts[code_bits]);
                    if (available < 0) return error.InvalidHuffmanCode;
                    code = (code + counts[code_bits - 1]) << 1;
                    next_code[code_bits] = code;
                }

                var encoder = Encoder{};
                for (lengths, 0..) |code_bits, symbol| {
                    if (code_bits == 0) continue;
                    encoder.codes[symbol] = reverseBits(next_code[code_bits], code_bits);
                    encoder.bits[symbol] = code_bits;
                    next_code[code_bits] += 1;
                }
                return encoder;
            }

            /// Build canonical codes for a trusted sparse symbol set. Entries
            /// outside `active_symbols` remain undefined and must never be
            /// queried; this avoids clearing and scanning a 256+ entry dense
            /// encoder when a format planner already owns the exact alphabet.
            pub fn initSparseTrusted(lengths: []const u4, active_symbols: []const u16) Error!Encoder {
                if (lengths.len > max_symbols or active_symbols.len > max_sparse_symbols) return error.CorruptFrame;
                if (active_symbols.len == 0) return .{};

                var symbols: [max_sparse_symbols]u16 = undefined;
                @memcpy(symbols[0..active_symbols.len], active_symbols);
                // Canonical codes are assigned by increasing symbol value,
                // while Brotli's planner alphabet is frequency-ordered.
                for (symbols[1..active_symbols.len], 1..) |symbol, i| {
                    var j = i;
                    while (j != 0 and symbol < symbols[j - 1]) : (j -= 1) symbols[j] = symbols[j - 1];
                    symbols[j] = symbol;
                }

                var counts: [max_code_bits + 1]u16 = @splat(0);
                for (symbols[0..active_symbols.len], 0..) |symbol, i| {
                    if (symbol >= lengths.len or (i != 0 and symbol == symbols[i - 1])) return error.CorruptFrame;
                    const code_bits = lengths[symbol];
                    if (code_bits == 0 or code_bits > max_code_bits) return error.CorruptFrame;
                    counts[code_bits] += 1;
                }

                var available: i32 = 1;
                var code: u16 = 0;
                var next_code: [max_code_bits + 1]u16 = @splat(0);
                for (1..max_code_bits + 1) |code_bits| {
                    available = (available << 1) - @as(i32, counts[code_bits]);
                    if (available < 0) return error.InvalidHuffmanCode;
                    code = (code + counts[code_bits - 1]) << 1;
                    next_code[code_bits] = code;
                }

                var encoder: Encoder = undefined;
                for (symbols[0..active_symbols.len]) |symbol| {
                    const code_bits = lengths[symbol];
                    encoder.codes[symbol] = reverseBits(next_code[code_bits], code_bits);
                    encoder.bits[symbol] = code_bits;
                    next_code[code_bits] += 1;
                }
                return encoder;
            }

            pub fn writeSymbol(self: *const Encoder, writer: *bitstream.BitWriter, allocator: std.mem.Allocator, symbol: usize) !void {
                if (symbol >= max_symbols or self.bits[symbol] == 0) return error.InvalidHuffmanCode;
                try writer.writeBits(allocator, self.codes[symbol], self.bits[symbol]);
            }
        };

        pub fn init(lengths: []const u4) Error!Self {
            @setEvalBranchQuota(200000);
            if (lengths.len > max_symbols) return error.CorruptFrame;
            var counts: [max_code_bits + 1]u16 = @splat(0);
            var active_symbols: [max_symbols]u16 = undefined;
            var active_len: usize = 0;
            var max_bits_seen: u4 = 0;
            for (lengths, 0..) |bits, symbol| {
                if (bits > max_code_bits) return error.CorruptFrame;
                if (bits != 0) {
                    counts[bits] += 1;
                    max_bits_seen = @max(max_bits_seen, bits);
                    active_symbols[active_len] = @intCast(symbol);
                    active_len += 1;
                }
            }
            if (active_len == 0) return Self{};

            var available: i32 = 1;
            for (1..max_code_bits + 1) |bits| {
                available = (available << 1) - @as(i32, counts[bits]);
                if (available < 0) return error.InvalidHuffmanCode;
            }

            var code: u16 = 0;
            var next_code: [max_code_bits + 1]u16 = @splat(0);
            for (1..max_code_bits + 1) |bits| {
                code = (code + counts[bits - 1]) << 1;
                next_code[bits] = code;
            }

            // Build a stable bit-length index before materializing entries.
            // Canonical code assignment still follows increasing symbol order
            // through `active_symbols`; only the physical entry storage is
            // bucketed by bit width for faster decode fallback scans.
            var table = Self{ .len = active_len, .max_bits = max_bits_seen };
            var offset: u16 = 0;
            for (1..max_code_bits + 1) |bits| {
                table.first_by_bits[bits] = offset;
                table.count_by_bits[bits] = counts[bits];
                offset += counts[bits];
            }
            std.debug.assert(offset == active_len);

            var write_offsets = table.first_by_bits;
            for (active_symbols[0..active_len]) |symbol| {
                const bits = lengths[symbol];
                const canonical = next_code[bits];
                next_code[bits] += 1;
                const entry_index = write_offsets[bits];
                write_offsets[bits] += 1;
                const entry = Entry{
                    .symbol = @intCast(symbol),
                    .code = reverseBits(canonical, bits),
                    .bits = bits,
                };
                table.entries[entry_index] = entry;
            }
            return table;
        }

        /// Build a decoder from a validated ascending list of active symbols.
        /// Format parsers that already discovered this set can avoid rescanning
        /// a large sparse alphabet solely to reconstruct the same list.
        pub fn initSparseTrusted(lengths: []const u4, active_symbols: []const u16) Error!Self {
            if (lengths.len > max_symbols or active_symbols.len > max_symbols) return error.CorruptFrame;
            if (active_symbols.len == 0) return Self{};
            return initSparseTrustedNonEmpty(lengths, active_symbols);
        }

        // Keep the non-empty path separate so callers with a proven active set
        // do not retain the large zero-value return as a cold copy path.
        fn initSparseTrustedNonEmpty(lengths: []const u4, active_symbols: []const u16) Error!Self {
            if (lengths.len > max_symbols or active_symbols.len == 0 or active_symbols.len > max_symbols) return error.CorruptFrame;

            var counts: [max_code_bits + 1]u16 = @splat(0);
            var max_bits_seen: u4 = 0;
            for (active_symbols, 0..) |symbol, index| {
                if (symbol >= lengths.len or (index != 0 and symbol <= active_symbols[index - 1])) return error.CorruptFrame;
                const bits = lengths[symbol];
                if (bits == 0 or bits > max_code_bits) return error.CorruptFrame;
                counts[bits] += 1;
                max_bits_seen = @max(max_bits_seen, bits);
            }

            var available: i32 = 1;
            var code: u16 = 0;
            var next_code: [max_code_bits + 1]u16 = @splat(0);
            for (1..max_code_bits + 1) |bits| {
                available = (available << 1) - @as(i32, counts[bits]);
                if (available < 0) return error.InvalidHuffmanCode;
                code = (code + counts[bits - 1]) << 1;
                next_code[bits] = code;
            }

            var table = Self{ .len = active_symbols.len, .max_bits = max_bits_seen };
            var write_offsets: [max_code_bits + 1]u16 = @splat(0);
            var offset: u16 = 0;
            for (1..max_code_bits + 1) |bits| {
                table.first_by_bits[bits] = offset;
                write_offsets[bits] = offset;
                table.count_by_bits[bits] = counts[bits];
                offset += counts[bits];
            }
            for (active_symbols) |symbol| {
                const bits = lengths[symbol];
                const canonical = next_code[bits];
                next_code[bits] += 1;
                const entry_index = write_offsets[bits];
                write_offsets[bits] += 1;
                table.entries[entry_index] = .{
                    .symbol = symbol,
                    .code = reverseBits(canonical, bits),
                    .bits = bits,
                };
            }
            return table;
        }

        /// Build a small decoder when code lengths and wire symbols are already
        /// available as parallel lists. Brotli simple trees contain at most four
        /// symbols, so expanding them into a max-alphabet-sized sparse array is
        /// unnecessary. Canonical assignment still follows symbol order.
        pub fn initExplicitSymbols(code_lengths: []const u4, symbols: []const u16) Error!Self {
            if (code_lengths.len != symbols.len or symbols.len == 0 or symbols.len > max_symbols) return error.CorruptFrame;
            var sorted_symbols: [4]u16 = undefined;
            var sorted_lengths: [4]u4 = undefined;
            if (symbols.len > sorted_symbols.len) return error.CorruptFrame;
            for (symbols, code_lengths, 0..) |symbol, bits, i| {
                if (symbol >= max_symbols or bits == 0 or bits > max_code_bits) return error.CorruptFrame;
                var insert = i;
                while (insert != 0 and symbol < sorted_symbols[insert - 1]) : (insert -= 1) {
                    sorted_symbols[insert] = sorted_symbols[insert - 1];
                    sorted_lengths[insert] = sorted_lengths[insert - 1];
                }
                if (insert != 0 and symbol == sorted_symbols[insert - 1]) return error.CorruptFrame;
                sorted_symbols[insert] = symbol;
                sorted_lengths[insert] = bits;
            }

            var counts: [max_code_bits + 1]u16 = @splat(0);
            var max_bits_seen: u4 = 0;
            for (sorted_lengths[0..symbols.len]) |bits| {
                counts[bits] += 1;
                max_bits_seen = @max(max_bits_seen, bits);
            }
            var available: i32 = 1;
            var code: u16 = 0;
            var next_code: [max_code_bits + 1]u16 = @splat(0);
            for (1..max_code_bits + 1) |bits| {
                available = (available << 1) - @as(i32, counts[bits]);
                if (available < 0) return error.InvalidHuffmanCode;
                code = (code + counts[bits - 1]) << 1;
                next_code[bits] = code;
            }

            var table = Self{ .len = symbols.len, .max_bits = max_bits_seen };
            var offset: u16 = 0;
            for (1..max_code_bits + 1) |bits| {
                table.first_by_bits[bits] = offset;
                table.count_by_bits[bits] = counts[bits];
                offset += counts[bits];
            }
            var write_offsets = table.first_by_bits;
            for (sorted_symbols[0..symbols.len], sorted_lengths[0..symbols.len]) |symbol, bits| {
                const canonical = next_code[bits];
                next_code[bits] += 1;
                const entry_index = write_offsets[bits];
                write_offsets[bits] += 1;
                table.entries[entry_index] = .{
                    .symbol = symbol,
                    .code = reverseBits(canonical, bits),
                    .bits = bits,
                };
            }
            return table;
        }

        pub fn decode(self: *const Self, reader: anytype) Error!Symbol {
            const decoded = try self.decodeValueWithBits(reader);
            return .{ .value = decoded.value, .bits = decoded.bits };
        }

        pub fn decodeValue(self: *const Self, reader: anytype) Error!u16 {
            var code: u16 = 0;
            var bits: u4 = 1;
            while (bits <= max_code_bits) {
                const bit = try reader.readBits(u16, 1);
                code |= bit << @intCast(bits - 1);
                const first = self.first_by_bits[bits];
                const end = first + self.count_by_bits[bits];
                for (self.entries[first..end]) |entry| {
                    if (entry.code == code) return entry.symbol;
                }
                if (bits == max_code_bits) break;
                bits += 1;
            }
            return error.InvalidHuffmanCode;
        }

        /// Place an 8-bit lookup in the unused tail of the entry array. Callers
        /// opt in only when they own enough slack, so this adds no table bytes
        /// and leaves the ordinary compact decoder completely unchanged.
        pub fn buildTailLookup8(self: *Self) bool {
            return self.buildTailLookup(8);
        }

        pub fn buildTailLookup9(self: *Self) bool {
            return self.buildTailLookup(9);
        }

        fn buildTailLookup(self: *Self, comptime lookup_bits: u4) bool {
            const lookup_len = 1 << lookup_bits;
            const lookup_bytes = lookup_len * @sizeOf(u16);
            const entry_count = (lookup_bytes + @sizeOf(Entry) - 1) / @sizeOf(Entry);
            if (!self.canBuildTailLookup(lookup_bits)) return false;
            const lookup: *[lookup_len]u16 = @ptrCast(&self.entries[max_symbols - entry_count]);
            @memset(lookup, 0);
            for (self.entries[0..self.len]) |entry| {
                if (entry.bits > lookup_bits) continue;
                const fill = @as(usize, 1) << @intCast(lookup_bits - entry.bits);
                const packed_entry: u16 = (entry.symbol + 1) << 4 | entry.bits;
                var i: usize = 0;
                while (i < fill) : (i += 1) lookup[entry.code | (i << entry.bits)] = packed_entry;
            }
            return true;
        }

        pub fn canBuildTailLookup8(self: *const Self) bool {
            return self.canBuildTailLookup(8);
        }

        pub fn canBuildTailLookup9(self: *const Self) bool {
            return self.canBuildTailLookup(9);
        }

        fn canBuildTailLookup(self: *const Self, comptime lookup_bits: u4) bool {
            const lookup_bytes = (1 << lookup_bits) * @sizeOf(u16);
            const entry_count = (lookup_bytes + @sizeOf(Entry) - 1) / @sizeOf(Entry);
            if (comptime max_symbols < entry_count) return false;
            return self.len + entry_count <= max_symbols;
        }

        /// Decode through a lookup previously installed by `buildTailLookup8`.
        pub inline fn decodeValueTailLookup8(self: *const Self, reader: anytype) Error!u16 {
            return self.decodeValueTailLookup(reader, 8);
        }

        pub inline fn decodeValueTailLookup9(self: *const Self, reader: anytype) Error!u16 {
            return self.decodeValueTailLookup(reader, 9);
        }

        inline fn decodeValueTailLookup(self: *const Self, reader: anytype, comptime lookup_bits: u4) Error!u16 {
            const lookup_len = 1 << lookup_bits;
            const lookup_bytes = lookup_len * @sizeOf(u16);
            const entry_count = (lookup_bytes + @sizeOf(Entry) - 1) / @sizeOf(Entry);
            if (comptime max_symbols < entry_count) return self.decodeValue(reader);
            const lookup: *const [lookup_len]u16 = @ptrCast(&self.entries[max_symbols - entry_count]);
            const packed_entry = lookup[reader.peekBitsPadded(u16, lookup_bits)];
            if (packed_entry == 0) {
                @branchHint(.unlikely);
                return self.decodeValueLongAfterLookup(reader, lookup_bits);
            }
            const bits: u4 = @truncate(packed_entry);
            if (!hasDecodedBits(reader, bits)) return error.TruncatedFrame;
            reader.advanceBitsStagedAssumeAvailable(bits);
            return (packed_entry >> 4) - 1;
        }

        noinline fn decodeValueLongAfterLookup(self: *const Self, reader: anytype, comptime lookup_bits: u4) Error!u16 {
            if (self.max_bits <= lookup_bits or !hasDecodedBits(reader, lookup_bits))
                return self.decodeValue(reader);

            var code = reader.peekBitsPadded(u16, lookup_bits);
            reader.advanceBitsStagedAssumeAvailable(lookup_bits);
            var bits: u4 = lookup_bits + 1;
            while (bits <= self.max_bits) {
                code |= try reader.readBits(u16, 1) << @intCast(bits - 1);
                const first = self.first_by_bits[bits];
                const end = first + self.count_by_bits[bits];
                var index = first;
                while (index + 1 < end) : (index += 2) {
                    const first_entry = self.entries[index];
                    if (first_entry.code == code) return first_entry.symbol;
                    const second_entry = self.entries[index + 1];
                    if (second_entry.code == code) return second_entry.symbol;
                }
                if (index < end and self.entries[index].code == code) return self.entries[index].symbol;
                if (bits == self.max_bits) break;
                bits += 1;
            }
            return error.InvalidHuffmanCode;
        }

        fn decodeValueWithBits(self: *const Self, reader: anytype) Error!Symbol {
            var code: u16 = 0;
            var bits: u4 = 1;
            while (bits <= max_code_bits) {
                const bit = try reader.readBits(u16, 1);
                code |= bit << @intCast(bits - 1);
                const first = self.first_by_bits[bits];
                const end = first + self.count_by_bits[bits];
                for (self.entries[first..end]) |entry| {
                    if (entry.code == code) {
                        return .{ .value = entry.symbol, .bits = bits };
                    }
                }
                if (bits == max_code_bits) break;
                bits += 1;
            }
            return error.InvalidHuffmanCode;
        }
    };
}

test "sparse trusted encoder matches dense canonical codes" {
    var lengths: [704]u4 = @splat(0);
    const active = [_]u16{ 500, 3, 241, 17, 700, 99 };
    for (active) |symbol| lengths[symbol] = if (symbol == 3 or symbol == 17) 2 else 3;

    const dense = try HuffmanTable(704).Encoder.init(&lengths);
    const sparse = try HuffmanTable(704).Encoder.initSparseTrusted(&lengths, &active);
    for (active) |symbol| {
        try std.testing.expectEqual(dense.bits[symbol], sparse.bits[symbol]);
        try std.testing.expectEqual(dense.codes[symbol], sparse.codes[symbol]);
    }
}

test "sparse trusted decoder matches dense canonical table" {
    var lengths: [704]u4 = @splat(0);
    const active = [_]u16{ 3, 17, 99, 241, 500, 700 };
    for (active) |symbol| lengths[symbol] = if (symbol == 3 or symbol == 17) 2 else 3;

    const dense = try HuffmanTable(704).init(&lengths);
    const sparse = try HuffmanTable(704).initSparseTrusted(&lengths, &active);
    try std.testing.expectEqual(dense.len, sparse.len);
    try std.testing.expectEqual(dense.max_bits, sparse.max_bits);
    try std.testing.expectEqualSlices(HuffmanTable(704).Entry, dense.entries[0..dense.len], sparse.entries[0..sparse.len]);
    try std.testing.expectEqual(dense.first_by_bits, sparse.first_by_bits);
    try std.testing.expectEqual(dense.count_by_bits, sparse.count_by_bits);
}

test "explicit-symbol decoder matches dense simple trees" {
    const cases = [_]struct {
        symbols: []const u16,
        lengths: []const u4,
    }{
        .{ .symbols = &.{ 241, 3 }, .lengths = &.{ 1, 1 } },
        .{ .symbols = &.{ 241, 3, 700 }, .lengths = &.{ 1, 2, 2 } },
        .{ .symbols = &.{ 241, 3, 700, 17 }, .lengths = &.{ 1, 2, 3, 3 } },
    };
    for (cases) |case| {
        var dense_lengths: [704]u4 = @splat(0);
        for (case.symbols, case.lengths) |symbol, bits| dense_lengths[symbol] = bits;
        const dense = try HuffmanTable(704).init(&dense_lengths);
        const explicit = try HuffmanTable(704).initExplicitSymbols(case.lengths, case.symbols);
        try std.testing.expectEqual(dense.len, explicit.len);
        try std.testing.expectEqual(dense.max_bits, explicit.max_bits);
        try std.testing.expectEqualSlices(HuffmanTable(704).Entry, dense.entries[0..dense.len], explicit.entries[0..explicit.len]);
        try std.testing.expectEqual(dense.first_by_bits, explicit.first_by_bits);
        try std.testing.expectEqual(dense.count_by_bits, explicit.count_by_bits);
    }
}

test "explicit-symbol decoder rejects malformed lists" {
    try std.testing.expectError(error.CorruptFrame, HuffmanTable(8).initExplicitSymbols(&.{ 1, 1 }, &.{1}));
    try std.testing.expectError(error.CorruptFrame, HuffmanTable(8).initExplicitSymbols(&.{ 1, 1 }, &.{ 2, 2 }));
    try std.testing.expectError(error.CorruptFrame, HuffmanTable(8).initExplicitSymbols(&.{ 1, 1 }, &.{ 1, 8 }));
    try std.testing.expectError(error.CorruptFrame, HuffmanTable(8).initExplicitSymbols(&.{ 1, 0 }, &.{ 1, 2 }));
}

test "sparse trusted decoder rejects invalid active sets" {
    var lengths: [8]u4 = @splat(0);
    lengths[1] = 1;
    try std.testing.expectError(error.CorruptFrame, HuffmanTable(8).initSparseTrusted(&lengths, &.{ 1, 1 }));
    try std.testing.expectError(error.CorruptFrame, HuffmanTable(8).initSparseTrusted(&lengths, &.{2}));
    try std.testing.expectError(error.CorruptFrame, HuffmanTable(8).initSparseTrusted(&lengths, &.{8}));
}

test "sparse trusted decoder matches dense randomized tables" {
    var state: u32 = 0x243f_6a88;
    for (0..128) |_| {
        var frequencies: [64]u32 = @splat(0);
        const active_len: usize = 2 + state % 63;
        for (0..active_len) |index| {
            state = state *% 1_664_525 +% 1_013_904_223;
            frequencies[index] = 1 + (state >> 20);
        }
        const lengths = treeCodeLengths(64, &frequencies, max_code_bits);
        var active: [64]u16 = undefined;
        var count: usize = 0;
        for (lengths, 0..) |bits, symbol| {
            if (bits == 0) continue;
            active[count] = @intCast(symbol);
            count += 1;
        }
        const dense = try HuffmanTable(64).init(&lengths);
        const sparse = try HuffmanTable(64).initSparseTrusted(&lengths, active[0..count]);
        try std.testing.expectEqual(dense.len, sparse.len);
        try std.testing.expectEqual(dense.max_bits, sparse.max_bits);
        try std.testing.expectEqualSlices(HuffmanTable(64).Entry, dense.entries[0..dense.len], sparse.entries[0..sparse.len]);
        try std.testing.expectEqual(dense.first_by_bits, sparse.first_by_bits);
        try std.testing.expectEqual(dense.count_by_bits, sparse.count_by_bits);
    }
}

test "sparse trusted encoder matches dense randomized alphabets" {
    var state: u32 = 0x6a09_e667;
    for (0..64) |round| {
        var frequencies: [704]u32 = @splat(0);
        var active: [64]u16 = undefined;
        const active_len: usize = 5 + state % 60;
        for (active[0..active_len], 0..) |*symbol, i| {
            // 37 is coprime to 704, so every symbol in one round is unique.
            symbol.* = @intCast((round * 53 + i * 37) % frequencies.len);
            state = state *% 1_664_525 +% 1_013_904_223;
            frequencies[symbol.*] = 1 + (state >> 20);
        }
        const lengths = treeCodeLengths(704, &frequencies, max_code_bits);
        const dense = try HuffmanTable(704).Encoder.init(&lengths);
        const sparse = try HuffmanTable(704).Encoder.initSparseTrusted(&lengths, active[0..active_len]);
        for (active[0..active_len]) |symbol| {
            try std.testing.expectEqual(dense.bits[symbol], sparse.bits[symbol]);
            try std.testing.expectEqual(dense.codes[symbol], sparse.codes[symbol]);
        }
    }
}

test "sparse trusted encoder rejects invalid active sets" {
    var lengths: [8]u4 = @splat(0);
    lengths[1] = 1;
    try std.testing.expectError(error.CorruptFrame, HuffmanTable(8).Encoder.initSparseTrusted(&lengths, &.{ 1, 1 }));
    try std.testing.expectError(error.CorruptFrame, HuffmanTable(8).Encoder.initSparseTrusted(&lengths, &.{2}));
    try std.testing.expectError(error.CorruptFrame, HuffmanTable(8).Encoder.initSparseTrusted(&lengths, &.{8}));
}

pub fn FastDecoder(comptime max_symbols: usize, comptime lookup_bits: u4) type {
    comptime {
        if (lookup_bits == 0 or lookup_bits > max_code_bits) @compileError("invalid Huffman lookup width");
    }
    return struct {
        table: HuffmanTable(max_symbols),
        lookup: [@as(usize, 1) << lookup_bits]FixedLookupEntry = undefined,

        const Self = @This();

        pub fn init(table: HuffmanTable(max_symbols)) Self {
            var decoder = Self{ .table = table };
            const coverage = decoder.lookupCoverage();
            // Use the already-maintained length histogram to decide whether the
            // fast lookup is fully covered. That preserves the no-memset path
            // for fixed-style full tables while avoiding the old partial-table
            // cost of filling lookup entries once, clearing, then filling the
            // same entries again. Some dynamic PNG tables are almost full: every
            // lookup slot is either covered by a short code or is the prefix of a
            // long fallback code. For that shape, fill short entries and clear
            // only those long prefixes instead of memseting thousands of entries.
            if (coverage == decoder.lookup.len) {
                _ = decoder.fillLookup();
            } else if (coverage + decoder.longPrefixCoverage() == decoder.lookup.len) {
                _ = decoder.fillLookup();
                decoder.clearLongPrefixes();
            } else {
                @memset(&decoder.lookup, .{ .symbol = 0, .bits = 0 });
                _ = decoder.fillLookup();
            }
            return decoder;
        }

        fn fillLookup(self: *Self) usize {
            var covered: usize = 0;
            for (self.table.entries[0..self.table.len]) |entry| {
                if (entry.bits > lookup_bits) continue;
                if (entry.bits == lookup_bits) {
                    self.lookup[entry.code] = .{ .symbol = entry.symbol, .bits = entry.bits };
                    covered += 1;
                    continue;
                }
                const fill = @as(usize, 1) << @intCast(lookup_bits - entry.bits);
                covered += fill;
                var i: usize = 0;
                while (i < fill) : (i += 1) {
                    self.lookup[entry.code | (i << entry.bits)] = .{ .symbol = entry.symbol, .bits = entry.bits };
                }
            }
            return covered;
        }

        fn longPrefixCoverage(self: *const Self) usize {
            var seen: [@as(usize, 1) << lookup_bits]bool = @splat(false);
            var covered: usize = 0;
            var bits: usize = lookup_bits + 1;
            while (bits <= self.table.max_bits) : (bits += 1) {
                const first = self.table.first_by_bits[bits];
                const end = first + self.table.count_by_bits[bits];
                for (self.table.entries[first..end]) |entry| {
                    const prefix: usize = @as(usize, entry.code) & ((@as(usize, 1) << lookup_bits) - 1);
                    if (!seen[prefix]) {
                        seen[prefix] = true;
                        covered += 1;
                    }
                }
            }
            return covered;
        }

        fn clearLongPrefixes(self: *Self) void {
            var bits: usize = lookup_bits + 1;
            while (bits <= self.table.max_bits) : (bits += 1) {
                const first = self.table.first_by_bits[bits];
                const end = first + self.table.count_by_bits[bits];
                for (self.table.entries[first..end]) |entry| {
                    const prefix: usize = @as(usize, entry.code) & ((@as(usize, 1) << lookup_bits) - 1);
                    self.lookup[prefix] = .{ .symbol = 0, .bits = 0 };
                }
            }
        }

        pub fn lookupCoverage(self: *const Self) usize {
            var covered: usize = 0;
            var bits: u4 = 1;
            while (bits <= @min(self.table.max_bits, lookup_bits)) : (bits += 1) {
                covered += @as(usize, self.table.count_by_bits[bits]) << @intCast(lookup_bits - bits);
            }
            return covered;
        }

        pub fn decode(self: *const Self, reader: anytype) Error!Symbol {
            return self.decodeSlowAware(reader);
        }

        pub inline fn decodeValue(self: *const Self, reader: anytype) Error!u16 {
            const peek = reader.peekBitsPadded(u16, lookup_bits);
            const entry = self.lookup[peek];
            if (entry.bits != 0) {
                @branchHint(.likely);
                if (!hasDecodedBits(reader, entry.bits)) {
                    @branchHint(.unlikely);
                    return error.TruncatedFrame;
                }
                reader.advanceBitsStagedAssumeAvailable(entry.bits);
                return entry.symbol;
            } else {
                @branchHint(.unlikely);
            }
            if (self.table.max_bits == 0) return error.InvalidHuffmanCode;
            if (self.table.max_bits <= lookup_bits) {
                if (!hasDecodedBits(reader, self.table.max_bits)) {
                    @branchHint(.unlikely);
                    return error.TruncatedFrame;
                }
                return error.InvalidHuffmanCode;
            }

            var bits: u4 = lookup_bits + 1;
            while (bits <= self.table.max_bits) {
                const code = reader.peekBitsPadded(u16, bits);
                if (!hasDecodedBits(reader, bits)) {
                    @branchHint(.unlikely);
                    return error.TruncatedFrame;
                }
                const first = self.table.first_by_bits[bits];
                const end = first + self.table.count_by_bits[bits];
                for (self.table.entries[first..end]) |long_entry| {
                    if (long_entry.code == code) {
                        reader.advanceBitsStagedAssumeAvailable(bits);
                        return long_entry.symbol;
                    }
                }
                if (bits == self.table.max_bits) break;
                bits += 1;
            }
            return error.InvalidHuffmanCode;
        }

        fn decodeSlowAware(self: *const Self, reader: anytype) Error!Symbol {
            const peek = reader.peekBitsPadded(u16, lookup_bits);
            const entry = self.lookup[peek];
            if (entry.bits != 0) {
                @branchHint(.likely);
                if (!hasDecodedBits(reader, entry.bits)) {
                    @branchHint(.unlikely);
                    return error.TruncatedFrame;
                }
                reader.advanceBitsStagedAssumeAvailable(entry.bits);
                return .{ .value = entry.symbol, .bits = entry.bits };
            } else {
                // A fast-table miss already proves that no code of `lookup_bits`
                // or fewer matches this prefix. Continue from the first possible
                // long width instead of restarting the generic table decoder at
                // one bit and rescanning short entries. Dynamic DEFLATE streams
                // commonly put cold literals/distances behind long Huffman codes,
                // so avoiding the redundant 1..lookup_bits work is a measurable
                // win on text-heavy blocks while keeping the compact reference
                // table representation.
                @branchHint(.unlikely);
            }

            if (self.table.max_bits == 0) return error.InvalidHuffmanCode;
            if (self.table.max_bits <= lookup_bits) {
                if (!hasDecodedBits(reader, self.table.max_bits)) {
                    @branchHint(.unlikely);
                    return error.TruncatedFrame;
                }
                return error.InvalidHuffmanCode;
            }

            var bits: u4 = lookup_bits + 1;
            while (bits <= self.table.max_bits) {
                const code = reader.peekBitsPadded(u16, bits);
                if (!hasDecodedBits(reader, bits)) {
                    @branchHint(.unlikely);
                    return error.TruncatedFrame;
                }
                const first = self.table.first_by_bits[bits];
                const end = first + self.table.count_by_bits[bits];
                for (self.table.entries[first..end]) |long_entry| {
                    if (long_entry.code == code) {
                        reader.advanceBitsStagedAssumeAvailable(bits);
                        return .{ .value = long_entry.symbol, .bits = bits };
                    }
                }
                if (bits == self.table.max_bits) break;
                bits += 1;
            }
            return error.InvalidHuffmanCode;
        }
    };
}

/// Compact external lookup for callers that cannot reserve space inside a
/// Huffman table. A zero slot denotes a long-code fallback; populated slots
/// pack `(symbol + 1, bit_count)` into one `u16`.
pub fn PackedLookup(comptime lookup_bits: u4) type {
    comptime {
        if (lookup_bits == 0 or lookup_bits > max_code_bits) @compileError("invalid Huffman lookup width");
    }
    return struct {
        slots: [@as(usize, 1) << lookup_bits]u16 = @splat(0),

        const Self = @This();

        pub fn init(table: anytype) Error!Self {
            var lookup: Self = .{};
            for (table.entries[0..table.len]) |entry| {
                if (entry.bits > lookup_bits) continue;
                if (entry.symbol >= 4095) return error.InvalidHuffmanCode;
                const packed_entry: u16 = (entry.symbol + 1) << 4 | entry.bits;
                const fill = @as(usize, 1) << @intCast(lookup_bits - entry.bits);
                var i: usize = 0;
                while (i < fill) : (i += 1)
                    lookup.slots[entry.code | (i << entry.bits)] = packed_entry;
            }
            return lookup;
        }

        pub fn initSingle(symbol: u16) Error!Self {
            if (symbol >= 4095) return error.InvalidHuffmanCode;
            return .{ .slots = @splat((symbol + 1) << 4) };
        }

        pub inline fn decodeValueFast(self: *const Self, reader: anytype) Error!?u16 {
            const packed_entry = self.slots[reader.peekBitsPadded(u16, lookup_bits)];
            if (packed_entry == 0) {
                @branchHint(.unlikely);
                return null;
            }
            const bits: u4 = @truncate(packed_entry);
            if (!hasDecodedBits(reader, bits)) {
                @branchHint(.unlikely);
                return error.TruncatedFrame;
            }
            reader.advanceBitsStagedAssumeAvailable(bits);
            return (packed_entry >> 4) - 1;
        }

        pub inline fn decodeValueFast10(self: *const Self, reader: anytype) Error!?u16 {
            comptime std.debug.assert(lookup_bits == 10);
            const packed_entry = self.slots[reader.peekBits10Padded()];
            if (packed_entry == 0) {
                @branchHint(.unlikely);
                return null;
            }
            const bits: u4 = @truncate(packed_entry);
            if (!hasDecodedBits(reader, bits)) {
                @branchHint(.unlikely);
                return error.TruncatedFrame;
            }
            reader.advanceBitsStagedAssumeAvailable(bits);
            return (packed_entry >> 4) - 1;
        }

        pub inline fn decodeValue(self: *const Self, table: anytype, reader: anytype) Error!u16 {
            if (try self.decodeValueFast(reader)) |value| return value;
            return self.decodeValueLong(table, reader);
        }

        pub inline fn decodeValueLong(_: *const Self, table: anytype, reader: anytype) Error!u16 {
            if (table.max_bits == 0) return error.InvalidHuffmanCode;
            if (table.max_bits <= lookup_bits) {
                if (!hasDecodedBits(reader, table.max_bits)) return error.TruncatedFrame;
                return error.InvalidHuffmanCode;
            }
            var bits: u4 = lookup_bits + 1;
            while (bits <= table.max_bits) {
                const code = reader.peekBitsPadded(u16, bits);
                if (!hasDecodedBits(reader, bits)) return error.TruncatedFrame;
                const first = table.first_by_bits[bits];
                const end = first + table.count_by_bits[bits];
                for (table.entries[first..end]) |entry| {
                    if (entry.code == code) {
                        reader.advanceBitsStagedAssumeAvailable(bits);
                        return entry.symbol;
                    }
                }
                if (bits == table.max_bits) break;
                bits += 1;
            }
            return error.InvalidHuffmanCode;
        }
    };
}

pub const code_length_order = [_]u8{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
pub const CodeLengthTable = HuffmanTable(19);

pub const DynamicHeader = struct {
    final: bool,
    hlit: u16,
    hdist: u16,
    hclen: u8,
    code_length_lengths: [19]u4,
};

pub const DynamicLengths = struct {
    header: DynamicHeader,
    literal_lengths: [286]u4 = @splat(0),
    distance_lengths: [30]u4 = @splat(0),
    literal_max_bits: u4 = 0,
    distance_max_bits: u4 = 0,
    code_length_symbol_histogram: [19]u16 = @splat(0),
};

pub fn parseDynamicHeader(reader: anytype) Error!DynamicHeader {
    const final = (try reader.readBits(u1, 1)) != 0;
    const block_type = try reader.readBits(u2, 2);
    if (block_type != 0b10) return error.InvalidDeflateBlockType;

    const hlit: u16 = @as(u16, try reader.readBits(u5, 5)) + 257;
    const hdist: u16 = @as(u16, try reader.readBits(u5, 5)) + 1;
    const hclen: u8 = @as(u8, try reader.readBits(u4, 4)) + 4;
    if (hlit > 286 or hdist > 30 or hclen > code_length_order.len) return error.InvalidDynamicBlockHeader;

    var lengths: [19]u4 = @splat(0);
    for (code_length_order[0..hclen]) |symbol| {
        lengths[symbol] = try reader.readBits(u4, 3);
    }

    return .{
        .final = final,
        .hlit = hlit,
        .hdist = hdist,
        .hclen = hclen,
        .code_length_lengths = lengths,
    };
}

pub fn parseDynamicLengths(reader: anytype) Error!DynamicLengths {
    return parseDynamicLengthsBody(try parseDynamicHeader(reader), reader);
}

pub fn parseDynamicLengthsAfterHeader(final: bool, reader: anytype) Error!DynamicLengths {
    const hlit: u16 = @as(u16, try reader.readBits(u5, 5)) + 257;
    const hdist: u16 = @as(u16, try reader.readBits(u5, 5)) + 1;
    const hclen: u8 = @as(u8, try reader.readBits(u4, 4)) + 4;
    if (hlit > 286 or hdist > 30 or hclen > code_length_order.len) return error.InvalidDynamicBlockHeader;

    var lengths: [19]u4 = @splat(0);
    for (code_length_order[0..hclen]) |symbol| {
        lengths[symbol] = try reader.readBits(u4, 3);
    }

    return parseDynamicLengthsBody(.{
        .final = final,
        .hlit = hlit,
        .hdist = hdist,
        .hclen = hclen,
        .code_length_lengths = lengths,
    }, reader);
}

pub fn parseDynamicLengthsBody(header: DynamicHeader, reader: anytype) Error!DynamicLengths {
    const code_lengths = try CodeLengthTable.init(&header.code_length_lengths);
    const code_decoder = FastDecoder(19, 7).init(code_lengths);
    const total = header.hlit + header.hdist;
    var parsed = DynamicLengths{ .header = header };
    var pos: usize = 0;
    while (pos < total) {
        const symbol = try code_decoder.decodeValue(reader);
        parsed.code_length_symbol_histogram[symbol] += 1;
        switch (symbol) {
            0...15 => {
                setDynamicLength(&parsed, header, pos, @intCast(symbol));
                pos += 1;
            },
            16 => {
                if (pos == 0) return error.InvalidDynamicBlockHeader;
                const count: usize = @as(usize, try reader.readBits(u2, 2)) + 3;
                if (pos + count > total) return error.InvalidDynamicBlockHeader;
                const value = getDynamicLength(parsed, header, pos - 1);
                setDynamicLengthRun(&parsed, header, pos, count, value);
                pos += count;
            },
            17 => {
                const count: usize = @as(usize, try reader.readBits(u3, 3)) + 3;
                if (pos + count > total) return error.InvalidDynamicBlockHeader;
                setDynamicLengthRun(&parsed, header, pos, count, 0);
                pos += count;
            },
            18 => {
                const count: usize = @as(usize, try reader.readBits(u7, 7)) + 11;
                if (pos + count > total) return error.InvalidDynamicBlockHeader;
                setDynamicLengthRun(&parsed, header, pos, count, 0);
                pos += count;
            },
            else => return error.InvalidDynamicBlockHeader,
        }
    }

    // A dynamic literal/length alphabet without the end-of-block symbol cannot
    // terminate a compressed block. Reject it at header parse time so wrappers
    // consistently report a malformed dynamic header instead of decoding until
    // the bitstream happens to run out.
    if (parsed.literal_lengths[256] == 0) return error.InvalidDynamicBlockHeader;
    return parsed;
}

fn setDynamicLength(parsed: *DynamicLengths, header: DynamicHeader, pos: usize, value: u4) void {
    if (pos < header.hlit) {
        parsed.literal_lengths[pos] = value;
        parsed.literal_max_bits = @max(parsed.literal_max_bits, value);
    } else {
        parsed.distance_lengths[pos - header.hlit] = value;
        parsed.distance_max_bits = @max(parsed.distance_max_bits, value);
    }
}

fn getDynamicLength(parsed: DynamicLengths, header: DynamicHeader, pos: usize) u4 {
    return if (pos < header.hlit) parsed.literal_lengths[pos] else parsed.distance_lengths[pos - header.hlit];
}

fn setDynamicLengthRun(parsed: *DynamicLengths, header: DynamicHeader, pos: usize, count: usize, value: u4) void {
    const literal_end = @min(pos + count, header.hlit);
    if (pos < literal_end) {
        @memset(parsed.literal_lengths[pos..literal_end], value);
        parsed.literal_max_bits = @max(parsed.literal_max_bits, value);
    }
    if (pos + count > header.hlit) {
        const dist_start = if (pos > header.hlit) pos - header.hlit else 0;
        const dist_end = pos + count - header.hlit;
        @memset(parsed.distance_lengths[dist_start..dist_end], value);
        parsed.distance_max_bits = @max(parsed.distance_max_bits, value);
    }
}

pub fn simpleCodeLengths(comptime n: usize, freqs: *const [n]u32, max_bits: u4) [n]u4 {
    var lengths: [n]u4 = @splat(0);
    var active: usize = 0;
    for (freqs) |freq| {
        if (freq != 0) active += 1;
    }
    if (active == 0) return lengths;
    var bits: u4 = 1;
    var capacity: usize = 2;
    while (capacity < active and bits < max_bits) : (bits += 1) capacity <<= 1;
    for (freqs, 0..) |freq, i| {
        if (freq != 0) lengths[i] = bits;
    }
    return lengths;
}

pub fn weightedCodeLengths(comptime n: usize, freqs: *const [n]u32, max_bits: u4) [n]u4 {
    var lengths: [n]u4 = @splat(0);
    var active: usize = 0;
    for (freqs) |freq| {
        if (freq != 0) active += 1;
    }
    if (active == 0) return lengths;
    if (active == 1) {
        for (freqs, 0..) |freq, i| {
            if (freq != 0) lengths[i] = 1;
        }
        return lengths;
    }

    var remaining = active;
    var current_bits: u4 = 1;
    while (remaining > 0) : (current_bits += 1) {
        var best_i: ?usize = null;
        var best_freq: u32 = 0;
        for (freqs, 0..) |freq, i| {
            if (freq == 0 or lengths[i] != 0) continue;
            if (best_i == null or freq > best_freq) {
                best_i = i;
                best_freq = freq;
            }
        }
        const i = best_i orelse break;
        lengths[i] = @min(current_bits, max_bits);
        remaining -= 1;
        if (current_bits == max_bits) {
            for (freqs, 0..) |freq, j| {
                if (freq != 0 and lengths[j] == 0) lengths[j] = max_bits;
            }
            break;
        }
    }
    return lengths;
}

pub fn treeCodeLengths(comptime n: usize, freqs: *const [n]u32, max_bits: u4) [n]u4 {
    var lengths: [n]u4 = @splat(0);
    var active: usize = 0;
    for (freqs.*) |freq| {
        if (freq == 0) continue;
        active += 1;
    }
    if (active == 0) return lengths;
    if (active == 1) {
        for (freqs.*, 0..) |freq, symbol| {
            if (freq != 0) {
                lengths[symbol] = 1;
                break;
            }
        }
        return lengths;
    }
    // Dynamic DEFLATE alphabets are frequently sparse (especially distance and
    // code-length trees). Specializing the package record width to the active
    // symbol count avoids moving the full 286-symbol multiplicity vector at
    // every package-merge depth, then maps the compact result back to symbols.
    if (active <= 32 and n > 32)
        return compactPackageMergeCodeLengths(n, freqs, max_bits, active, 32);
    if (active <= 64 and n > 64)
        return compactPackageMergeCodeLengths(n, freqs, max_bits, active, 64);
    if (n > 64)
        return backrefPackageMergeCodeLengths(n, freqs, max_bits, active);
    return packageMergeCodeLengths(n, freqs, max_bits, active);
}

/// Fast canonical Huffman construction for a dense DEFLATE literal/length
/// alphabet. The ordinary bounded builder remains the fallback for any
/// distribution whose natural tree exceeds RFC 1951's 15-bit limit.
pub noinline fn treeCodeLengthsDenseDeflate(
    freqs: *const [286]u32,
    active: usize,
) linksection(deflate_dense_text_section) [286]u4 {
    std.debug.assert(active >= 240 and active <= freqs.len);
    return unboundedDenseCodeLengthsWithSpreadPolicy(286, freqs, 15, active, false, true) orelse
        backrefPackageMergeCodeLengths(286, freqs, 15, active);
}

/// Build lengths when the caller already tracks every non-zero symbol. The
/// trusted list is already sorted by symbol so compact package merge can
/// preserve canonical tie ordering without rescanning the full alphabet.
pub fn treeCodeLengthsKnownActive(
    comptime n: usize,
    freqs: *const [n]u32,
    max_bits: u4,
    active_symbols: anytype,
) [n]u4 {
    if (comptime builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        std.debug.assert(active_symbols.len <= n);
        for (active_symbols, 0..) |symbol_value, index| {
            const symbol: usize = @intCast(symbol_value);
            std.debug.assert(symbol < n and freqs[symbol] != 0);
            if (index != 0) std.debug.assert(active_symbols[index - 1] < symbol_value);
        }
    }
    if (active_symbols.len == 0) return @splat(0);
    if (active_symbols.len == 1) {
        var lengths: [n]u4 = @splat(0);
        lengths[active_symbols[0]] = 1;
        return lengths;
    }
    if (active_symbols.len <= 32 and n > 32)
        return compactPackageMergeCodeLengthsKnownActive(n, freqs, max_bits, active_symbols, 32);
    if (active_symbols.len <= 64 and n > 64)
        return compactPackageMergeCodeLengthsKnownActive(n, freqs, max_bits, active_symbols, 64);
    if (n > 64) {
        if (comptime n == 256) if (max_bits == 11 and active_symbols.len >= 128)
            return treeCodeLengthsDenseKnownActive(n, freqs, max_bits, active_symbols);
        return backrefPackageMergeCodeLengths(n, freqs, max_bits, active_symbols.len);
    }
    return packageMergeCodeLengths(n, freqs, max_bits, active_symbols.len);
}

// Keep the larger bucket workspace and package-merge instance out of the shared
// known-active caller. This preserves the compact path's code layout while
// specializing the dense Zstd alphabet.
noinline fn treeCodeLengthsDenseKnownActive(
    comptime n: usize,
    freqs: *const [n]u32,
    max_bits: u4,
    active_symbols: anytype,
) linksection(zstd_dense_text_section) [n]u4 {
    std.debug.assert(n > 64 and active_symbols.len >= 128);
    if (comptime builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        std.debug.assert(active_symbols.len <= n);
        for (active_symbols, 0..) |symbol_value, index| {
            const symbol: usize = @intCast(symbol_value);
            std.debug.assert(symbol < n and freqs[symbol] != 0);
            if (index != 0) std.debug.assert(active_symbols[index - 1] < symbol_value);
        }
    }
    return unboundedDenseCodeLengths(n, freqs, max_bits, active_symbols.len) orelse
        backrefPackageMergeCodeLengthsDense(n, freqs, max_bits, active_symbols.len);
}

noinline fn unboundedDenseCodeLengths(
    comptime n: usize,
    freqs: *const [n]u32,
    max_bits: u4,
    active: usize,
) linksection(zstd_dense_text_section) ?[n]u4 {
    return unboundedDenseCodeLengthsWithSpreadPolicy(n, freqs, max_bits, active, true, false);
}

fn unboundedDenseCodeLengthsWithSpreadPolicy(
    comptime n: usize,
    freqs: *const [n]u32,
    max_bits: u4,
    active: usize,
    comptime reject_wide_spread: bool,
    comptime deflate_leaf_order: bool,
) ?[n]u4 {
    const invalid = std.math.maxInt(u16);
    const Node = struct {
        weight: u64,
        symbol: u16 = invalid,
    };
    const Less = struct {
        nodes: []const Node,

        fn less(context: @This(), lhs: u16, rhs: u16) bool {
            const left = context.nodes[lhs];
            const right = context.nodes[rhs];
            return left.weight < right.weight or
                (left.weight == right.weight and lhs < rhs);
        }
    };

    var nodes: [2 * n - 1]Node = undefined;
    var parents: [2 * n - 1]u16 = undefined;
    var leaves: [n]u16 = undefined;
    var node_len: usize = 0;
    var min_frequency: u32 = std.math.maxInt(u32);
    var max_frequency: u32 = 0;
    var deflate_leaf_counts: [dense_deflate_leaf_bucket_count]u16 = if (deflate_leaf_order) @splat(0) else undefined;
    for (freqs.*, 0..) |frequency, symbol| {
        if (frequency == 0) continue;
        min_frequency = @min(min_frequency, frequency);
        max_frequency = @max(max_frequency, frequency);
        const index: u16 = @intCast(node_len);
        nodes[node_len] = .{ .weight = frequency, .symbol = @intCast(symbol) };
        if (deflate_leaf_order)
            deflate_leaf_counts[denseDeflateLeafFrequencyBucket(frequency)] += 1
        else
            leaves[node_len] = index;
        node_len += 1;
    }
    std.debug.assert(node_len == active);
    // Very uneven histograms are the only measured source of >11-bit natural
    // trees. Reject them before sorting/building so the bounded package-merge
    // fallback does not pay for a failed full-tree probe. The tree depth check
    // below remains authoritative for every admitted distribution.
    if (reject_wide_spread and @as(u64, max_frequency) > @as(u64, min_frequency) * 16) return null;
    const less = Less{ .nodes = nodes[0..active] };
    if (deflate_leaf_order)
        orderDenseDeflateNodeIndexes(leaves[0..active], nodes[0..active], &deflate_leaf_counts, less, Less.less)
    else
        bucketSortNodeIndexes(n, leaves[0..active], nodes[0..active], less, Less.less);

    var leaf_i: usize = 0;
    var parent_i: usize = active;
    while (node_len < 2 * active - 1) {
        const first = popHuffmanNode(Node, nodes[0..node_len], leaves[0..active], &leaf_i, &parent_i);
        const second = popHuffmanNode(Node, nodes[0..node_len], leaves[0..active], &leaf_i, &parent_i);
        const parent: u16 = @intCast(node_len);
        nodes[node_len] = .{
            .weight = nodes[first].weight + nodes[second].weight,
        };
        parents[first] = parent;
        parents[second] = parent;
        node_len += 1;
    }

    var depths: [2 * n - 1]u16 = undefined;
    depths[node_len - 1] = 0;
    var index = node_len - 1;
    while (index != 0) {
        index -= 1;
        depths[index] = depths[parents[index]] + 1;
    }
    var lengths: [n]u4 = @splat(0);
    for (nodes[0..active], depths[0..active]) |node, depth| {
        if (depth == 0 or depth > max_bits) return null;
        lengths[node.symbol] = @intCast(depth);
    }
    return lengths;
}

inline fn popHuffmanNode(
    comptime Node: type,
    nodes: []const Node,
    leaves: []const u16,
    leaf_i: *usize,
    parent_i: *usize,
) u16 {
    if (leaf_i.* >= leaves.len) {
        const result: u16 = @intCast(parent_i.*);
        parent_i.* += 1;
        return result;
    }
    const leaf = leaves[leaf_i.*];
    if (parent_i.* >= nodes.len) {
        leaf_i.* += 1;
        return leaf;
    }
    const parent: u16 = @intCast(parent_i.*);
    const leaf_node = nodes[leaf];
    const parent_node = nodes[parent];
    if (leaf_node.weight < parent_node.weight or
        (leaf_node.weight == parent_node.weight and leaf < parent))
    {
        leaf_i.* += 1;
        return leaf;
    }
    parent_i.* += 1;
    return parent;
}

fn compactPackageMergeCodeLengthsKnownActive(
    comptime n: usize,
    freqs: *const [n]u32,
    max_bits: u4,
    active_symbols: anytype,
    comptime compact_n: usize,
) [n]u4 {
    std.debug.assert(active_symbols.len <= compact_n);
    var symbols: [compact_n]u16 = undefined;
    for (active_symbols, 0..) |symbol, index| symbols[index] = @intCast(symbol);
    var compact_freqs: [compact_n]u32 = @splat(0);
    for (symbols[0..active_symbols.len], 0..) |symbol, index| {
        std.debug.assert(symbol < n and freqs[symbol] != 0);
        compact_freqs[index] = freqs[symbol];
    }
    const compact_lengths = packageMergeCodeLengths(compact_n, &compact_freqs, max_bits, active_symbols.len);
    var lengths: [n]u4 = @splat(0);
    for (symbols[0..active_symbols.len], compact_lengths[0..active_symbols.len]) |symbol, code_bits|
        lengths[symbol] = code_bits;
    return lengths;
}

/// Full-alphabet package-merge reference retained for focused equivalence and
/// performance measurements of the compact sparse production path.
pub fn treeCodeLengthsFullWidth(comptime n: usize, freqs: *const [n]u32, max_bits: u4) [n]u4 {
    var active: usize = 0;
    for (freqs.*) |freq| active += @intFromBool(freq != 0);
    if (active < 2) return treeCodeLengths(n, freqs, max_bits);
    return packageMergeCodeLengths(n, freqs, max_bits, active);
}

/// Back-reference package merge with the original per-root DAG traversal.
/// Retained as a focused equivalence and performance reference.
pub fn treeCodeLengthsBackrefTraversal(comptime n: usize, freqs: *const [n]u32, max_bits: u4) [n]u4 {
    var active: usize = 0;
    for (freqs.*) |freq| active += @intFromBool(freq != 0);
    std.debug.assert(n > 64 and active > 64);
    return backrefPackageMergeCodeLengthsReference(n, freqs, max_bits, active);
}

fn compactPackageMergeCodeLengths(
    comptime n: usize,
    freqs: *const [n]u32,
    max_bits: u4,
    active: usize,
    comptime compact_n: usize,
) [n]u4 {
    var compact_freqs: [compact_n]u32 = @splat(0);
    var symbols: [compact_n]u16 = undefined;
    var compact_i: usize = 0;
    for (freqs.*, 0..) |freq, symbol| {
        if (freq == 0) continue;
        compact_freqs[compact_i] = freq;
        symbols[compact_i] = @intCast(symbol);
        compact_i += 1;
    }
    std.debug.assert(compact_i == active);
    const compact_lengths = packageMergeCodeLengths(compact_n, &compact_freqs, max_bits, active);
    var lengths: [n]u4 = @splat(0);
    for (symbols[0..active], compact_lengths[0..active]) |symbol, code_bits|
        lengths[symbol] = code_bits;
    return lengths;
}

fn backrefPackageMergeCodeLengths(comptime n: usize, freqs: *const [n]u32, max_bits: u4, active: usize) [n]u4 {
    return backrefPackageMergeCodeLengthsWithRecovery(n, freqs, max_bits, active, true, false);
}

fn backrefPackageMergeCodeLengthsReference(comptime n: usize, freqs: *const [n]u32, max_bits: u4, active: usize) [n]u4 {
    return backrefPackageMergeCodeLengthsWithRecovery(n, freqs, max_bits, active, false, false);
}

fn backrefPackageMergeCodeLengthsDense(comptime n: usize, freqs: *const [n]u32, max_bits: u4, active: usize) [n]u4 {
    return backrefPackageMergeCodeLengthsWithRecovery(n, freqs, max_bits, active, true, true);
}

fn backrefPackageMergeCodeLengthsWithRecovery(
    comptime n: usize,
    freqs: *const [n]u32,
    max_bits: u4,
    active: usize,
    comptime linear_recovery: bool,
    comptime bucket_leaves: bool,
) [n]u4 {
    comptime std.debug.assert(n * max_code_bits <= std.math.maxInt(u16));
    const invalid = std.math.maxInt(u16);
    const Node = struct {
        weight: u64,
        left: u16 = invalid,
        right: u16 = invalid,
        symbol: u16 = invalid,
        serial: u16,
    };
    const Less = struct {
        nodes: []const Node,

        fn less(context: @This(), lhs: u16, rhs: u16) bool {
            const left = context.nodes[lhs];
            const right = context.nodes[rhs];
            if (left.weight != right.weight) return left.weight < right.weight;
            // Equal-weight symbols/packages are interchangeable for weighted
            // cost. A stable creation-order tie-break keeps output deterministic
            // without reconstructing or storing a 286-symbol count vector.
            return left.serial < right.serial;
        }
    };

    // Each level creates fewer than `active` packages. Keeping one compact
    // arena of back-references avoids copying an n-symbol multiplicity vector
    // through every package and defers code-length recovery until selection.
    var nodes: [n * max_code_bits]Node = undefined;
    var node_len: usize = 0;
    var leaves: [n]u16 = undefined;
    for (freqs.*, 0..) |freq, symbol| {
        if (freq == 0) continue;
        const index: u16 = @intCast(node_len);
        nodes[node_len] = .{ .weight = freq, .symbol = @intCast(symbol), .serial = index };
        leaves[node_len] = index;
        node_len += 1;
    }
    std.debug.assert(node_len == active);
    if (bucket_leaves)
        bucketSortNodeIndexes(n, leaves[0..active], nodes[0..node_len], Less{ .nodes = nodes[0..node_len] }, Less.less)
    else
        std.mem.sort(u16, leaves[0..active], Less{ .nodes = nodes[0..node_len] }, Less.less);

    var current: [2 * n]u16 = undefined;
    var next: [n]u16 = undefined;
    var current_len = active;
    @memcpy(current[0..current_len], leaves[0..active]);

    var depth: u4 = 1;
    while (depth < max_bits) : (depth += 1) {
        var pair_len: usize = 0;
        var i: usize = 0;
        while (i + 1 < current_len) : (i += 2) {
            const left = current[i];
            const right = current[i + 1];
            const index: u16 = @intCast(node_len);
            nodes[node_len] = .{
                .weight = nodes[left].weight + nodes[right].weight,
                .left = left,
                .right = right,
                .serial = index,
            };
            node_len += 1;
            next[pair_len] = index;
            pair_len += 1;
        }
        const less = Less{ .nodes = nodes[0..node_len] };
        if (comptime builtin.mode == .Debug or builtin.mode == .ReleaseSafe)
            std.debug.assert(nodeIndexesAreSorted(Node, next[0..pair_len], less));
        current_len = mergeNodeIndexLists(Node, &current, leaves[0..active], next[0..pair_len], less);
    }

    const selected_count = 2 * active - 2;
    std.debug.assert(selected_count <= current_len);
    var lengths: [n]u4 = @splat(0);
    if (comptime linear_recovery) {
        var multiplicities: [n * max_code_bits]u16 = undefined;
        @memset(multiplicities[0..node_len], 0);
        for (current[0..selected_count]) |index| multiplicities[index] += 1;
        var index = node_len;
        while (index > active) {
            index -= 1;
            const multiplicity = multiplicities[index];
            if (multiplicity == 0) continue;
            // Every occurrence of an internal node reaches every leaf below
            // it, so its multiplicity cannot exceed the final code length.
            std.debug.assert(multiplicity <= max_bits);
            const node = nodes[index];
            multiplicities[node.left] += multiplicity;
            multiplicities[node.right] += multiplicity;
            std.debug.assert(multiplicities[node.left] <= max_bits);
            std.debug.assert(multiplicities[node.right] <= max_bits);
        }
        for (nodes[0..active], multiplicities[0..active]) |node, multiplicity| {
            std.debug.assert(multiplicity != 0 and multiplicity <= max_bits);
            lengths[node.symbol] = @intCast(multiplicity);
        }
    } else {
        for (current[0..selected_count]) |index|
            accumulateBackrefLengths(Node, n, nodes[0..node_len], index, &lengths);
    }
    return lengths;
}

const leaf_exact_count_cutoff = 166;
const leaf_bucket_count = 192;
// Dense high-diversity DEFLATE blocks overwhelmingly use leaf frequencies
// 1--4. Keep those stable buckets exact and comparison-sort the small tail;
// scanning the generic 166-entry exact range costs more than sorting that tail.
const dense_deflate_leaf_bucket_count = 6;

fn denseDeflateLeafFrequencyBucket(weight: u64) u8 {
    std.debug.assert(weight != 0 and weight <= std.math.maxInt(u32));
    return @intCast(@min(weight, dense_deflate_leaf_bucket_count - 1));
}

/// Order the dense DEFLATE leaves directly from their creation-order node
/// array. Frequencies 1--4 retain exact stable buckets; the remaining
/// tail receives one full `(weight, serial)` sort. This is equivalent to the
/// generic logarithmic tail buckets while avoiding an input-index scan, an
/// intermediate ordered array, and the unused generic bucket range on this
/// isolated path.
fn orderDenseDeflateNodeIndexes(
    indexes: []u16,
    nodes: anytype,
    counts: *const [dense_deflate_leaf_bucket_count]u16,
    context: anytype,
    comptime lessThanFn: fn (@TypeOf(context), u16, u16) bool,
) void {
    std.debug.assert(indexes.len == nodes.len);
    var offsets: [dense_deflate_leaf_bucket_count]u16 = undefined;
    var next: u16 = 0;
    for (counts.*, 0..) |count, bucket| {
        offsets[bucket] = next;
        next += count;
    }
    std.debug.assert(next == indexes.len);
    const tail_start = offsets[dense_deflate_leaf_bucket_count - 1];

    for (nodes, 0..) |node, index| {
        const bucket = denseDeflateLeafFrequencyBucket(node.weight);
        indexes[offsets[bucket]] = @intCast(index);
        offsets[bucket] += 1;
    }
    if (indexes.len - tail_start > 1)
        std.mem.sort(u16, indexes[tail_start..], context, lessThanFn);
}

fn leafFrequencyBucket(weight: u64) u8 {
    std.debug.assert(weight != 0 and weight <= std.math.maxInt(u32));
    if (weight < leaf_exact_count_cutoff) return @intCast(weight);
    return @intCast(leaf_exact_count_cutoff - 1 + @as(usize, std.math.log2_int(u64, weight)) - 7);
}

fn bucketSortNodeIndexes(
    comptime n: usize,
    indexes: []u16,
    nodes: anytype,
    context: anytype,
    comptime lessThanFn: fn (@TypeOf(context), u16, u16) bool,
) void {
    var counts: [leaf_bucket_count]u16 = @splat(0);
    for (indexes) |index| counts[leafFrequencyBucket(nodes[index].weight)] += 1;

    var offsets: [leaf_bucket_count]u16 = undefined;
    var next: u16 = 0;
    for (counts, 0..) |count, bucket| {
        offsets[bucket] = next;
        next += count;
    }
    var ordered: [n]u16 = undefined;
    for (indexes) |index| {
        const bucket = leafFrequencyBucket(nodes[index].weight);
        ordered[offsets[bucket]] = index;
        offsets[bucket] += 1;
    }

    var start: usize = 0;
    for (counts, 0..) |count, bucket| {
        const end = start + count;
        if (bucket >= leaf_exact_count_cutoff - 1 and count > 1)
            std.mem.sort(u16, ordered[start..end], context, lessThanFn);
        start = end;
    }
    @memcpy(indexes, ordered[0..indexes.len]);
}

fn nodeIndexesAreSorted(comptime Node: type, indexes: []const u16, less: anytype) bool {
    _ = Node;
    for (indexes[1..], indexes[0..indexes.len -| 1]) |current, previous|
        if (less.less(current, previous)) return false;
    return true;
}

fn mergeNodeIndexLists(comptime Node: type, out: anytype, leaves: []const u16, packages: []const u16, less: anytype) usize {
    _ = Node;
    var out_len: usize = 0;
    var leaf_i: usize = 0;
    var package_i: usize = 0;
    while (leaf_i < leaves.len or package_i < packages.len) {
        const take_leaf = if (package_i >= packages.len)
            true
        else if (leaf_i >= leaves.len)
            false
        else
            less.less(leaves[leaf_i], packages[package_i]);
        out[out_len] = if (take_leaf) leaves[leaf_i] else packages[package_i];
        out_len += 1;
        if (take_leaf) leaf_i += 1 else package_i += 1;
    }
    return out_len;
}

fn accumulateBackrefLengths(comptime Node: type, comptime n: usize, nodes: []const Node, root: u16, lengths: *[n]u4) void {
    const invalid = std.math.maxInt(u16);
    var stack: [max_code_bits + 1]u16 = undefined;
    var stack_len: usize = 1;
    stack[0] = root;
    while (stack_len != 0) {
        stack_len -= 1;
        const node = nodes[stack[stack_len]];
        if (node.symbol != invalid) {
            lengths[node.symbol] += 1;
        } else {
            std.debug.assert(stack_len + 2 <= stack.len);
            stack[stack_len] = node.left;
            stack[stack_len + 1] = node.right;
            stack_len += 2;
        }
    }
}

fn packageMergeCodeLengths(comptime n: usize, freqs: *const [n]u32, max_bits: u4, active: usize) [n]u4 {
    std.debug.assert(max_bits <= max_code_bits);
    const Packed = PackedLengthPackage(n);
    var leaves: [n]Packed = undefined;
    var leaf_count: usize = 0;
    for (freqs.*, 0..) |freq, symbol| {
        if (freq == 0) continue;
        var package = Packed{ .weight = freq, .counts = @splat(0) };
        packedCountSet(n, &package.counts, symbol, 1);
        leaves[leaf_count] = package;
        leaf_count += 1;
    }
    std.debug.assert(leaf_count == active);
    std.mem.sort(Packed, leaves[0..active], {}, packedPackageLess(n));

    var current: [2 * n]Packed = undefined;
    var next: [2 * n]Packed = undefined;
    var current_len = active;
    @memcpy(current[0..current_len], leaves[0..active]);

    var depth: u4 = 1;
    while (depth < max_bits) : (depth += 1) {
        var pair_len: usize = 0;
        var i: usize = 0;
        while (i + 1 < current_len) : (i += 2) {
            next[pair_len] = combinePackedPackages(
                n,
                current[i],
                current[i + 1],
            );
            pair_len += 1;
        }
        if (comptime builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
            std.debug.assert(
                packedPackagesAreSorted(n, next[0..pair_len]),
            );
        }
        current_len = mergePackedPackageLists(
            n,
            &current,
            leaves[0..active],
            next[0..pair_len],
        );
        std.debug.assert(current_len <= current.len);
    }

    const selected_count = 2 * active - 2;
    std.debug.assert(selected_count <= current_len);
    var selected_counts: [(n + 15) / 16]u64 = @splat(0);
    for (current[0..selected_count]) |package| {
        if (comptime builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
            for (0..n) |symbol| {
                std.debug.assert(
                    @as(u5, packedCountGet(n, selected_counts, symbol)) +
                        packedCountGet(n, package.counts, symbol) <= max_bits,
                );
            }
        }
        // As in package combination, each nibble's final sum is a valid code
        // length no greater than max_bits. Accumulating whole words therefore
        // performs sixteen independent additions without cross-nibble carry.
        for (&selected_counts, package.counts) |*total, counts| {
            total.* += counts;
        }
    }
    var lengths: [n]u4 = undefined;
    for (&lengths, 0..) |*length, symbol| {
        length.* = packedCountGet(n, selected_counts, symbol);
    }
    return lengths;
}

fn packageMergeCodeLengthsReference(comptime n: usize, freqs: *const [n]u32, max_bits: u4, active: usize) [n]u4 {
    return packageMergeCodeLengthsWithSortPolicy(n, freqs, max_bits, active, true);
}

fn packageMergeCodeLengthsWithSortPolicy(
    comptime n: usize,
    freqs: *const [n]u32,
    max_bits: u4,
    active: usize,
    comptime sort_pairs: bool,
) [n]u4 {
    std.debug.assert(max_bits > 0);
    std.debug.assert(active <= (@as(usize, 1) << max_bits));
    const Pkg = LengthPackage(n);
    var leaves: [n]Pkg = undefined;
    var leaf_count: usize = 0;
    for (freqs.*, 0..) |freq, symbol| {
        if (freq == 0) continue;
        var counts: [n]u8 = @splat(0);
        counts[symbol] = 1;
        leaves[leaf_count] = .{ .weight = freq, .counts = counts };
        leaf_count += 1;
    }
    std.debug.assert(leaf_count == active);
    std.mem.sort(Pkg, leaves[0..active], {}, packageLess(n));

    // The package list length converges below 2*active because every level
    // merges adjacent packages pairwise and then merges those packages with the
    // original leaf list. Storing multiplicity counts (rather than a bitset)
    // is essential: package-merge can select the same symbol through multiple
    // packages, and those selections are exactly the code length.
    var current: [2 * n]Pkg = undefined;
    var next: [2 * n]Pkg = undefined;
    var current_len = active;
    @memcpy(current[0..current_len], leaves[0..active]);

    var depth: u4 = 1;
    while (depth < max_bits) : (depth += 1) {
        var pair_len: usize = 0;
        var i: usize = 0;
        while (i + 1 < current_len) : (i += 2) {
            next[pair_len] = combinePackages(n, current[i], current[i + 1]);
            pair_len += 1;
        }
        if (sort_pairs) {
            // Retained only as a test oracle for the original implementation.
            std.mem.sort(Pkg, next[0..pair_len], {}, packageLess(n));
        } else {
            // `current` is sorted. Pair weights are therefore nondecreasing:
            // a[i] <= a[i+1] <= a[i+2] <= a[i+3] implies
            // a[i]+a[i+1] <= a[i+2]+a[i+3]. Equal pair weights require all
            // four input weights to be equal, where the counts tie-breaker is
            // also preserved by component-wise addition. The pair list can be
            // merged with the sorted leaves directly; sorting it again moved
            // the full, large package records at every code-length depth.
            if (comptime builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
                std.debug.assert(packagesAreSorted(n, next[0..pair_len]));
            }
        }
        current_len = mergePackageLists(n, &current, leaves[0..active], next[0..pair_len]);
        std.debug.assert(current_len <= current.len);
    }

    const selected_count = 2 * active - 2;
    std.debug.assert(selected_count <= current_len);
    var length_counts: [n]u8 = @splat(0);
    for (current[0..selected_count]) |package| {
        for (package.counts, 0..) |count, symbol| length_counts[symbol] += count;
    }
    var lengths: [n]u4 = @splat(0);
    for (length_counts, 0..) |count, symbol| {
        std.debug.assert(count <= max_bits);
        lengths[symbol] = @intCast(count);
    }
    return lengths;
}

fn packagesAreSorted(comptime n: usize, packages: []const LengthPackage(n)) bool {
    const less = packageLess(n);
    for (packages[1..], packages[0..packages.len -| 1]) |current, previous| {
        if (less({}, current, previous)) return false;
    }
    return true;
}

fn PackedLengthPackage(comptime n: usize) type {
    return struct {
        weight: u64,
        // Four bits are sufficient for every symbol multiplicity because a
        // DEFLATE code length is capped at 15. Packing sixteen symbols per word
        // lets package combination use native integer addition and lets the
        // equal-weight tie-break compare sixteen symbols at a time. Symbol
        // indices increase with nibble significance, so walking words in
        // reverse preserves the byte-packed implementation's exact ordering.
        counts: [(n + 15) / 16]u64,
    };
}

fn packedCountGet(
    comptime n: usize,
    counts: [(n + 15) / 16]u64,
    symbol: usize,
) u4 {
    const word = counts[symbol / 16];
    return @truncate(word >> @intCast((symbol & 15) * 4));
}

fn packedCountSet(
    comptime n: usize,
    counts: *[(n + 15) / 16]u64,
    symbol: usize,
    value: u4,
) void {
    const shift: u6 = @intCast((symbol & 15) * 4);
    const mask: u64 = @as(u64, 0x0f) << shift;
    counts[symbol / 16] =
        (counts[symbol / 16] & ~mask) | (@as(u64, value) << shift);
}

fn packedPackageLess(
    comptime n: usize,
) fn (void, PackedLengthPackage(n), PackedLengthPackage(n)) bool {
    return struct {
        fn less(
            _: void,
            lhs: PackedLengthPackage(n),
            rhs: PackedLengthPackage(n),
        ) bool {
            if (lhs.weight != rhs.weight) return lhs.weight < rhs.weight;
            var i: usize = lhs.counts.len;
            while (i > 0) {
                i -= 1;
                if (lhs.counts[i] != rhs.counts[i]) {
                    return lhs.counts[i] < rhs.counts[i];
                }
            }
            return false;
        }
    }.less;
}

fn combinePackedPackages(
    comptime n: usize,
    lhs: PackedLengthPackage(n),
    rhs: PackedLengthPackage(n),
) PackedLengthPackage(n) {
    var out = PackedLengthPackage(n){
        .weight = lhs.weight + rhs.weight,
        .counts = @splat(0),
    };
    // Every nibble is a package multiplicity bounded by max_code_bits (15).
    // Package-merge only combines selections whose per-symbol sums stay <= 15.
    // With that invariant, a native word addition cannot carry across a nibble
    // boundary and therefore performs sixteen independent count additions.
    if (comptime builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        for (0..n) |symbol| {
            std.debug.assert(
                @as(u5, packedCountGet(n, lhs.counts, symbol)) +
                    packedCountGet(n, rhs.counts, symbol) <= 0x0f,
            );
        }
    }
    for (&out.counts, lhs.counts, rhs.counts) |*value, left, right| {
        value.* = left + right;
    }
    return out;
}

fn packedPackagesAreSorted(
    comptime n: usize,
    packages: []const PackedLengthPackage(n),
) bool {
    const less = packedPackageLess(n);
    for (
        packages[1..],
        packages[0..packages.len -| 1],
    ) |current, previous| {
        if (less({}, current, previous)) return false;
    }
    return true;
}

fn mergePackedPackageLists(
    comptime n: usize,
    out: *[2 * n]PackedLengthPackage(n),
    leaves: []const PackedLengthPackage(n),
    packages: []const PackedLengthPackage(n),
) usize {
    var out_len: usize = 0;
    var leaf_i: usize = 0;
    var package_i: usize = 0;
    const less = packedPackageLess(n);
    while (leaf_i < leaves.len or package_i < packages.len) {
        const take_leaf = if (package_i >= packages.len)
            true
        else if (leaf_i >= leaves.len)
            false
        else
            less({}, leaves[leaf_i], packages[package_i]);
        out[out_len] = if (take_leaf)
            leaves[leaf_i]
        else
            packages[package_i];
        out_len += 1;
        if (take_leaf) {
            leaf_i += 1;
        } else {
            package_i += 1;
        }
    }
    return out_len;
}

fn LengthPackage(comptime n: usize) type {
    return struct {
        weight: u64,
        counts: [n]u8,
    };
}

fn packageLess(comptime n: usize) fn (void, LengthPackage(n), LengthPackage(n)) bool {
    return struct {
        fn less(_: void, lhs: LengthPackage(n), rhs: LengthPackage(n)) bool {
            if (lhs.weight != rhs.weight) return lhs.weight < rhs.weight;
            var i: usize = n;
            while (i > 0) {
                i -= 1;
                if (lhs.counts[i] != rhs.counts[i]) return lhs.counts[i] < rhs.counts[i];
            }
            return false;
        }
    }.less;
}

fn combinePackages(comptime n: usize, lhs: LengthPackage(n), rhs: LengthPackage(n)) LengthPackage(n) {
    var out = LengthPackage(n){ .weight = lhs.weight + rhs.weight, .counts = @splat(0) };
    for (&out.counts, lhs.counts, rhs.counts) |*value, left, right| value.* = left + right;
    return out;
}

fn mergePackageLists(comptime n: usize, out: *[2 * n]LengthPackage(n), leaves: []const LengthPackage(n), packages: []const LengthPackage(n)) usize {
    var out_len: usize = 0;
    var leaf_i: usize = 0;
    var package_i: usize = 0;
    const less = packageLess(n);
    while (leaf_i < leaves.len or package_i < packages.len) {
        const take_leaf = if (package_i >= packages.len)
            true
        else if (leaf_i >= leaves.len)
            false
        else
            less({}, leaves[leaf_i], packages[package_i]);
        out[out_len] = if (take_leaf) leaves[leaf_i] else packages[package_i];
        out_len += 1;
        if (take_leaf) {
            leaf_i += 1;
        } else {
            package_i += 1;
        }
    }
    return out_len;
}

fn kraftCost(comptime n: usize, lengths: *const [n]u4, max_bits: u4) usize {
    var cost: usize = 0;
    for (lengths.*) |bits| {
        if (bits == 0) continue;
        cost += @as(usize, 1) << @intCast(max_bits - bits);
    }
    return cost;
}

pub const FixedLookupEntry = struct { symbol: u16, bits: u4 };

pub const fixed_literal_lookup = blk: {
    @setEvalBranchQuota(10000);
    const lengths = fixedLiteralLengths();
    const table = FixedLiteralTable.init(&lengths) catch unreachable;
    var lookup: [512]FixedLookupEntry = @splat(.{ .symbol = 0, .bits = 0 });
    for (table.entries[0..table.len]) |entry| {
        const fill = @as(usize, 1) << @intCast(9 - entry.bits);
        var i: usize = 0;
        while (i < fill) : (i += 1) {
            lookup[entry.code | (i << entry.bits)] = .{ .symbol = entry.symbol, .bits = entry.bits };
        }
    }
    break :blk lookup;
};

pub fn decodeFixedLiteralFast(reader: anytype) Error!Symbol {
    const peek = reader.peekBitsPadded(u16, 9);
    const entry = fixed_literal_lookup[peek];
    if (entry.bits == 0) {
        @branchHint(.unlikely);
        return error.InvalidHuffmanCode;
    }
    if (!hasDecodedBits(reader, entry.bits)) return error.TruncatedFrame;
    reader.advanceBitsStagedAssumeAvailable(entry.bits);
    return .{ .value = entry.symbol, .bits = entry.bits };
}

pub fn decodeFixedLiteralValueFast(reader: anytype) Error!u16 {
    const peek = reader.peekBitsPadded(u16, 9);
    const entry = fixed_literal_lookup[peek];
    if (entry.bits == 0) {
        @branchHint(.unlikely);
        return error.InvalidHuffmanCode;
    }
    if (!hasDecodedBits(reader, entry.bits)) return error.TruncatedFrame;
    reader.advanceBitsStagedAssumeAvailable(entry.bits);
    return entry.symbol;
}

pub const fixed_distance_lookup = blk: {
    @setEvalBranchQuota(2000);
    const lengths = fixedDistanceLengths();
    const table = FixedDistanceTable.init(&lengths) catch unreachable;
    var lookup: [32]FixedLookupEntry = @splat(.{ .symbol = 0, .bits = 0 });
    for (table.entries[0..table.len]) |entry| {
        lookup[entry.code] = .{ .symbol = entry.symbol, .bits = entry.bits };
    }
    break :blk lookup;
};

pub fn decodeFixedDistanceFast(reader: anytype) Error!Symbol {
    const peek = reader.peekBitsPadded(u16, 5);
    const entry = fixed_distance_lookup[peek];
    if (entry.bits == 0) {
        @branchHint(.unlikely);
        return error.InvalidHuffmanCode;
    }
    if (!hasDecodedBits(reader, entry.bits)) return error.TruncatedFrame;
    reader.advanceBitsStagedAssumeAvailable(entry.bits);
    return .{ .value = entry.symbol, .bits = entry.bits };
}

pub fn decodeFixedDistanceValueFast(reader: anytype) Error!u16 {
    const peek = reader.peekBitsPadded(u16, 5);
    const entry = fixed_distance_lookup[peek];
    if (entry.bits == 0) {
        @branchHint(.unlikely);
        return error.InvalidHuffmanCode;
    }
    if (!hasDecodedBits(reader, entry.bits)) return error.TruncatedFrame;
    reader.advanceBitsStagedAssumeAvailable(entry.bits);
    return entry.symbol;
}

pub const FixedLiteralTable = HuffmanTable(fixed_literal_count);
pub const FixedDistanceTable = HuffmanTable(fixed_distance_count);
pub const FixedLiteralEncoder = FixedLiteralTable.Encoder;
pub const FixedDistanceEncoder = FixedDistanceTable.Encoder;

pub fn fixedLiteralLengths() [fixed_literal_count]u4 {
    var lengths: [fixed_literal_count]u4 = undefined;
    for (&lengths, 0..) |*len, i| {
        len.* = switch (i) {
            0...143 => 8,
            144...255 => 9,
            256...279 => 7,
            280...287 => 8,
            else => unreachable,
        };
    }
    return lengths;
}

pub fn fixedDistanceLengths() [fixed_distance_count]u4 {
    return [_]u4{5} ** fixed_distance_count;
}

pub fn fixedLiteralTable() Error!FixedLiteralTable {
    const lengths = fixedLiteralLengths();
    return FixedLiteralTable.init(&lengths);
}

pub fn fixedDistanceTable() Error!FixedDistanceTable {
    const lengths = fixedDistanceLengths();
    return FixedDistanceTable.init(&lengths);
}

pub const fixed_literal_encoder = blk: {
    const lengths = fixedLiteralLengths();
    break :blk FixedLiteralEncoder.init(&lengths) catch unreachable;
};

pub const fixed_distance_encoder = blk: {
    const lengths = fixedDistanceLengths();
    break :blk FixedDistanceEncoder.init(&lengths) catch unreachable;
};

fn reverseBits(code: u16, bits: u4) u16 {
    if (bits == 0) return 0;
    return @bitReverse(code) >> @intCast(16 - @as(usize, bits));
}

test "fixed Huffman tables expose expected boundary code lengths" {
    const lit_lengths = fixedLiteralLengths();
    try std.testing.expectEqual(@as(u4, 8), lit_lengths[0]);
    try std.testing.expectEqual(@as(u4, 8), lit_lengths[143]);
    try std.testing.expectEqual(@as(u4, 9), lit_lengths[144]);
    try std.testing.expectEqual(@as(u4, 9), lit_lengths[255]);
    try std.testing.expectEqual(@as(u4, 7), lit_lengths[256]);
    try std.testing.expectEqual(@as(u4, 7), lit_lengths[279]);
    try std.testing.expectEqual(@as(u4, 8), lit_lengths[280]);
    try std.testing.expectEqual(@as(u4, 8), lit_lengths[287]);

    const dist_lengths = fixedDistanceLengths();
    for (dist_lengths) |bits| try std.testing.expectEqual(@as(u4, 5), bits);
}

test "canonical Huffman decoder handles a small RFC-style tree" {
    const Table = HuffmanTable(4);
    const table = try Table.init(&.{ 2, 1, 3, 3 });
    var reader = bitstream.BitReader.init(&.{0b0001_1010});
    try std.testing.expectEqual(@as(u16, 1), (try table.decode(&reader)).value);
    try std.testing.expectEqual(@as(u16, 0), (try table.decode(&reader)).value);
    try std.testing.expectEqual(@as(u16, 2), (try table.decode(&reader)).value);
}

test "tail lookup decoder matches compact decoder" {
    const table_size = @sizeOf(HuffmanTable(256));
    var frequencies: [256]u32 = @splat(0);
    for (0..64) |symbol| frequencies[symbol] = @intCast(65 - symbol);
    const lengths = treeCodeLengths(256, &frequencies, max_code_bits);
    var table = try HuffmanTable(256).init(&lengths);
    try std.testing.expect(table.buildTailLookup8());

    const encoder = try HuffmanTable(256).Encoder.init(&lengths);
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(std.testing.allocator);
    for (0..64) |symbol| try encoder.writeSymbol(&writer, std.testing.allocator, symbol);
    const encoded = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(encoded);

    var reference = bitstream.BitReader.init(encoded);
    var lookup = bitstream.BitReader.init(encoded);
    for (0..64) |_|
        try std.testing.expectEqual(try table.decodeValue(&reference), try table.decodeValueTailLookup8(&lookup));
    try std.testing.expectEqual(reference.bitPosition(), lookup.bitPosition());
    try std.testing.expectEqual(table_size, @sizeOf(HuffmanTable(256)));

    var too_dense = try HuffmanTable(256).init(&([_]u4{8} ** 256));
    try std.testing.expect(!too_dense.buildTailLookup8());

    const short = try HuffmanTable(256).init(&([_]u4{7} ++ [_]u4{0} ** 255));
    var short_with_lookup = short;
    try std.testing.expect(short_with_lookup.buildTailLookup8());
    var truncated = bitstream.BitReader.init(&.{});
    try std.testing.expectError(error.TruncatedFrame, short_with_lookup.decodeValueTailLookup8(&truncated));

    const lengths9 = [_]u4{8} ** 192 ++ [_]u4{9} ** 128 ++ [_]u4{0} ** 384;
    var table9 = try HuffmanTable(704).init(&lengths9);
    try std.testing.expect(table9.buildTailLookup9());
    const encoder9 = try HuffmanTable(704).Encoder.init(&lengths9);
    var writer9: bitstream.BitWriter = .{};
    defer writer9.deinit(std.testing.allocator);
    for (0..320) |symbol| try encoder9.writeSymbol(&writer9, std.testing.allocator, symbol);
    const encoded9 = try writer9.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(encoded9);
    const compact9 = try HuffmanTable(704).init(&lengths9);
    var reference9 = bitstream.BitReader.init(encoded9);
    var lookup9 = bitstream.BitReader.init(encoded9);
    for (0..320) |_|
        try std.testing.expectEqual(try compact9.decodeValue(&reference9), try table9.decodeValueTailLookup9(&lookup9));
    try std.testing.expectEqual(reference9.bitPosition(), lookup9.bitPosition());
    const short9 = try HuffmanTable(704).init(&([_]u4{9} ++ [_]u4{0} ** 703));
    var short_with_lookup9 = short9;
    try std.testing.expect(short_with_lookup9.buildTailLookup9());
    var truncated9 = bitstream.BitReader.initBitLength(&.{0}, 8);
    try std.testing.expectError(error.TruncatedFrame, short_with_lookup9.decodeValueTailLookup9(&truncated9));

    var too_dense9 = try HuffmanTable(520).init(&([_]u4{9} ** 512 ++ [_]u4{0} ** 8));
    try std.testing.expect(!too_dense9.buildTailLookup9());

    const long_lengths = [_]u4{8} ** 192 ++ [_]u4{9} ** 64 ++ [_]u4{10} ** 128 ++ [_]u4{0} ** 320;
    var long_lookup_table = try HuffmanTable(704).init(&long_lengths);
    try std.testing.expect(long_lookup_table.buildTailLookup9());
    const long_encoder = try HuffmanTable(704).Encoder.init(&long_lengths);
    var long_writer: bitstream.BitWriter = .{};
    defer long_writer.deinit(std.testing.allocator);
    try long_encoder.writeSymbol(&long_writer, std.testing.allocator, 256);
    const long_encoded = try long_writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(long_encoded);

    var full_long_reader = bitstream.BitReader.init(long_encoded);
    try std.testing.expectEqual(@as(u16, 256), try long_lookup_table.decodeValueTailLookup9(&full_long_reader));
    var truncated_long_reference = bitstream.BitReader.initBitLength(long_encoded, 9);
    var truncated_long_lookup = bitstream.BitReader.initBitLength(long_encoded, 9);
    try std.testing.expectError(error.TruncatedFrame, long_lookup_table.decodeValue(&truncated_long_reference));
    try std.testing.expectError(error.TruncatedFrame, long_lookup_table.decodeValueTailLookup9(&truncated_long_lookup));
    try std.testing.expectEqual(truncated_long_reference.bitPosition(), truncated_long_lookup.bitPosition());
}

test "external packed lookup covers dense tables and long-code fallback" {
    const single_lookup = try PackedLookup(10).initSingle(211);
    var empty_reader = bitstream.BitReader.init(&.{});
    try std.testing.expectEqual(@as(?u16, 211), try single_lookup.decodeValueFast(&empty_reader));
    try std.testing.expectEqual(@as(usize, 0), empty_reader.bitPosition());

    const dense_lengths = [_]u4{8} ** 256;
    const dense_table = try HuffmanTable(256).init(&dense_lengths);
    const dense_lookup = try PackedLookup(10).init(&dense_table);
    const dense_encoder = try HuffmanTable(256).Encoder.init(&dense_lengths);
    var dense_writer: bitstream.BitWriter = .{};
    defer dense_writer.deinit(std.testing.allocator);
    for (0..256) |symbol|
        try dense_encoder.writeSymbol(&dense_writer, std.testing.allocator, symbol);
    const dense_encoded = try dense_writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(dense_encoded);

    var dense_reference = bitstream.BitReader.init(dense_encoded);
    var dense_fast = bitstream.BitReader.init(dense_encoded);
    for (0..256) |_|
        try std.testing.expectEqual(
            try dense_table.decodeValue(&dense_reference),
            try dense_lookup.decodeValue(&dense_table, &dense_fast),
        );
    try std.testing.expectEqual(dense_reference.bitPosition(), dense_fast.bitPosition());

    const mixed_lengths = [_]u4{ 2, 1, 3, 3 };
    const mixed_table = try HuffmanTable(mixed_lengths.len).init(&mixed_lengths);
    const mixed_lookup = try PackedLookup(2).init(&mixed_table);
    const mixed_encoder = try HuffmanTable(mixed_lengths.len).Encoder.init(&mixed_lengths);
    var mixed_writer: bitstream.BitWriter = .{};
    defer mixed_writer.deinit(std.testing.allocator);
    for (0..mixed_lengths.len) |symbol|
        try mixed_encoder.writeSymbol(&mixed_writer, std.testing.allocator, symbol);
    const mixed_encoded = try mixed_writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(mixed_encoded);

    var mixed_reference = bitstream.BitReader.init(mixed_encoded);
    var mixed_fast = bitstream.BitReader.init(mixed_encoded);
    for (0..mixed_lengths.len) |_|
        try std.testing.expectEqual(
            try mixed_table.decodeValue(&mixed_reference),
            try mixed_lookup.decodeValue(&mixed_table, &mixed_fast),
        );
    try std.testing.expectEqual(mixed_reference.bitPosition(), mixed_fast.bitPosition());

    const short_table = try HuffmanTable(2).init(&.{ 7, 0 });
    const short_lookup = try PackedLookup(10).init(&short_table);
    var truncated = bitstream.BitReader.init(&.{});
    try std.testing.expectError(error.TruncatedFrame, short_lookup.decodeValue(&short_table, &truncated));
}

test "fast Huffman decoder falls back for long codes" {
    const Table = HuffmanTable(4);
    const table = try Table.init(&.{ 2, 1, 3, 3 });
    const fast = FastDecoder(4, 2).init(table);
    var reader = bitstream.BitReader.init(&.{0b0001_1010});
    try std.testing.expectEqual(@as(u16, 1), (try fast.decode(&reader)).value);
    try std.testing.expectEqual(@as(u16, 0), (try fast.decode(&reader)).value);
    try std.testing.expectEqual(@as(u16, 2), (try fast.decode(&reader)).value);
}

test "fast Huffman decoder checks staged bits after padded lookup" {
    const Table = HuffmanTable(2);
    const short_table = try Table.init(&.{ 7, 0 });
    const short = FastDecoder(2, 9).init(short_table);

    var buffered_short = bitstream.BufferedBitReader.init(&.{0});
    try std.testing.expectEqual(@as(u16, 0), try short.decodeValue(&buffered_short));
    const short_chunks = [_][]const u8{&.{0}};
    var chunked_short = try bitstream.ChunkedBitReader.init(&short_chunks);
    try std.testing.expectEqual(@as(u16, 0), try short.decodeValue(&chunked_short));

    const long_table = try Table.init(&.{ 9, 0 });
    const long = FastDecoder(2, 9).init(long_table);
    var buffered_long = bitstream.BufferedBitReader.init(&.{0});
    try std.testing.expectError(error.TruncatedFrame, long.decodeValue(&buffered_long));
    const long_chunks = [_][]const u8{ &.{}, &.{0} };
    var chunked_long = try bitstream.ChunkedBitReader.init(&long_chunks);
    try std.testing.expectError(error.TruncatedFrame, long.decodeValue(&chunked_long));
}

test "fast Huffman decoder reports lookup coverage" {
    const FullTable = HuffmanTable(2);
    const full_table = try FullTable.init(&.{ 1, 1 });
    const full = FastDecoder(2, 2).init(full_table);
    try std.testing.expectEqual(full.lookup.len, full.lookupCoverage());

    const SparseTable = HuffmanTable(4);
    const sparse_table = try SparseTable.init(&.{ 2, 1, 3, 0 });
    const sparse = FastDecoder(4, 2).init(sparse_table);
    try std.testing.expectEqual(@as(usize, 3), sparse.lookupCoverage());
    try std.testing.expect(sparse.lookupCoverage() < sparse.lookup.len);
}

test "Huffman table records maximum active code length" {
    const Table = HuffmanTable(4);
    const table = try Table.init(&.{ 2, 1, 3, 3 });
    try std.testing.expectEqual(@as(u4, 3), table.max_bits);

    const empty = try Table.init(&.{ 0, 0, 0, 0 });
    try std.testing.expectEqual(@as(u4, 0), empty.max_bits);
}

test "canonical Huffman decoder rejects oversubscribed trees" {
    const Table = HuffmanTable(3);
    try std.testing.expectError(error.InvalidHuffmanCode, Table.init(&.{ 1, 1, 1 }));
}

test "fixed literal table decodes end-of-block code" {
    const table = try fixedLiteralTable();
    // Symbol 256 has canonical code 0000000; deflate stores it LSB-first.
    var reader = bitstream.BitReader.init(&.{0});
    const sym = try table.decode(&reader);
    try std.testing.expectEqual(@as(u16, 256), sym.value);
    try std.testing.expectEqual(@as(u4, 7), sym.bits);
}

test "dynamic header parser reads RFC1951 fields" {
    // BFINAL=1, BTYPE=dynamic, HLIT raw=0, HDIST raw=0, HCLEN raw=0, then four 3-bit code-length lengths.
    var reader = bitstream.BitReader.init(&.{ 0x05, 0x00, 0x48, 0x02 });
    const header = try parseDynamicHeader(&reader);
    try std.testing.expect(header.final);
    try std.testing.expectEqual(@as(u16, 257), header.hlit);
    try std.testing.expectEqual(@as(u16, 1), header.hdist);
    try std.testing.expectEqual(@as(u8, 4), header.hclen);
    try std.testing.expectEqual(@as(u4, 4), header.code_length_lengths[16]);
    try std.testing.expectEqual(@as(u4, 4), header.code_length_lengths[17]);
    try std.testing.expectEqual(@as(u4, 4), header.code_length_lengths[18]);
    try std.testing.expectEqual(@as(u4, 0), header.code_length_lengths[0]);
}

test "dynamic length parser expands repeat symbols" {
    // Synthetic dynamic block header:
    // - final dynamic block, HLIT=257, HDIST=1, HCLEN=18
    // - code-length alphabet uses symbols 1, 3, 17, 18, all 3 bits wide
    // - length stream expands to: one literal length 3, 255 zeros, one length 1, one distance length 1.
    const bytes = [_]u8{ 0x05, 0xc0, 0x01, 0x01, 0x00, 0x00, 0x00, 0x02, 0x20, 0xfb, 0xa7, 0x06 };
    var reader = bitstream.BitReader.init(&bytes);
    const parsed = try parseDynamicLengths(&reader);
    try std.testing.expectEqual(@as(u16, 257), parsed.header.hlit);
    try std.testing.expectEqual(@as(u16, 1), parsed.header.hdist);
    try std.testing.expectEqual(@as(u4, 3), parsed.literal_lengths[0]);
    for (parsed.literal_lengths[1..256]) |bits| try std.testing.expectEqual(@as(u4, 0), bits);
    try std.testing.expectEqual(@as(u4, 1), parsed.literal_lengths[256]);
    try std.testing.expectEqual(@as(u4, 1), parsed.distance_lengths[0]);
    try std.testing.expectEqual(@as(u4, 3), parsed.literal_max_bits);
    try std.testing.expectEqual(@as(u4, 1), parsed.distance_max_bits);
}

test "dynamic length parser rejects invalid repeat symbols" {
    {
        var lengths: [19]u4 = @splat(0);
        lengths[0] = 1;
        lengths[16] = 1;
        const encoder = try CodeLengthTable.Encoder.init(&lengths);
        var writer = bitstream.BitWriter{};
        defer writer.deinit(std.testing.allocator);
        try writer.writeBits(std.testing.allocator, 1, 1);
        try writer.writeBits(std.testing.allocator, 0b10, 2);
        try writer.writeBits(std.testing.allocator, 0, 5);
        try writer.writeBits(std.testing.allocator, 0, 5);
        try writer.writeBits(std.testing.allocator, 0, 4);
        try writer.writeBits(std.testing.allocator, 1, 3);
        try writer.writeBits(std.testing.allocator, 0, 3);
        try writer.writeBits(std.testing.allocator, 0, 3);
        try writer.writeBits(std.testing.allocator, 1, 3);
        try encoder.writeSymbol(&writer, std.testing.allocator, 16);
        const bytes = try writer.toOwnedSlice(std.testing.allocator);
        defer std.testing.allocator.free(bytes);
        var reader = bitstream.BitReader.init(bytes);
        try std.testing.expectError(error.InvalidDynamicBlockHeader, parseDynamicLengths(&reader));
    }

    {
        var lengths: [19]u4 = @splat(0);
        lengths[0] = 1;
        lengths[18] = 1;
        const encoder = try CodeLengthTable.Encoder.init(&lengths);
        var writer = bitstream.BitWriter{};
        defer writer.deinit(std.testing.allocator);
        try writer.writeBits(std.testing.allocator, 1, 1);
        try writer.writeBits(std.testing.allocator, 0b10, 2);
        try writer.writeBits(std.testing.allocator, 0, 5);
        try writer.writeBits(std.testing.allocator, 0, 5);
        try writer.writeBits(std.testing.allocator, 0, 4);
        try writer.writeBits(std.testing.allocator, 0, 3);
        try writer.writeBits(std.testing.allocator, 0, 3);
        try writer.writeBits(std.testing.allocator, 1, 3);
        try writer.writeBits(std.testing.allocator, 1, 3);
        try encoder.writeSymbol(&writer, std.testing.allocator, 18);
        try writer.writeBits(std.testing.allocator, 127, 7);
        try encoder.writeSymbol(&writer, std.testing.allocator, 18);
        try writer.writeBits(std.testing.allocator, 127, 7);
        const bytes = try writer.toOwnedSlice(std.testing.allocator);
        defer std.testing.allocator.free(bytes);
        var reader = bitstream.BitReader.init(bytes);
        try std.testing.expectError(error.InvalidDynamicBlockHeader, parseDynamicLengths(&reader));
    }
}

test "fixed Huffman encoder writes symbols decoded by fixed table" {
    const lengths = fixedLiteralLengths();
    const encoder = try FixedLiteralTable.Encoder.init(&lengths);
    const decoder = try fixedLiteralTable();
    var writer = bitstream.BitWriter{};
    defer writer.deinit(std.testing.allocator);
    try encoder.writeSymbol(&writer, std.testing.allocator, 'h');
    try encoder.writeSymbol(&writer, std.testing.allocator, 'i');
    try encoder.writeSymbol(&writer, std.testing.allocator, 256);
    const bytes = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bytes);

    var reader = bitstream.BitReader.init(bytes);
    try std.testing.expectEqual(@as(u16, 'h'), (try decoder.decode(&reader)).value);
    try std.testing.expectEqual(@as(u16, 'i'), (try decoder.decode(&reader)).value);
    try std.testing.expectEqual(@as(u16, 256), (try decoder.decode(&reader)).value);
}

test "dynamic parser rejects non-dynamic block type and truncated header" {
    var stored_reader = bitstream.BitReader.init(&.{0x01});
    try std.testing.expectError(error.InvalidDeflateBlockType, parseDynamicHeader(&stored_reader));
    var truncated_reader = bitstream.BitReader.init(&.{0x05});
    try std.testing.expectError(error.TruncatedFrame, parseDynamicHeader(&truncated_reader));
}

test "simple Huffman length builder creates decodable table" {
    const freqs = [_]u32{ 5, 7, 1, 0, 3 };
    const lengths = simpleCodeLengths(freqs.len, &freqs, 7);
    try std.testing.expect(lengths[0] != 0);
    try std.testing.expect(lengths[3] == 0);
    const Table = HuffmanTable(freqs.len);
    const table = try Table.init(&lengths);
    try std.testing.expect(table.len == 4);
}

test "weighted Huffman length builder favors frequent symbols" {
    const freqs = [_]u32{ 100, 50, 25, 1 };
    const lengths = weightedCodeLengths(freqs.len, &freqs, 7);
    try std.testing.expect(lengths[0] <= lengths[1]);
    try std.testing.expect(lengths[1] <= lengths[2]);
    try std.testing.expect(lengths[2] <= lengths[3]);
    const Table = HuffmanTable(freqs.len);
    const table = try Table.init(&lengths);
    try std.testing.expectEqual(@as(usize, 4), table.len);
}

test "tree Huffman length builder favors frequent symbols and decodes" {
    const freqs = [_]u32{ 100, 50, 25, 1, 0 };
    const lengths = treeCodeLengths(freqs.len, &freqs, 7);
    try std.testing.expect(lengths[0] <= lengths[1]);
    try std.testing.expect(lengths[1] <= lengths[2]);
    try std.testing.expect(lengths[4] == 0);
    const Table = HuffmanTable(freqs.len);
    const table = try Table.init(&lengths);
    try std.testing.expectEqual(@as(usize, 4), table.len);
}

test "package-merge Huffman length builder preserves canonical code space" {
    var freqs: [32]u32 = undefined;
    for (&freqs, 0..) |*freq, i| freq.* = @intCast(i + 1);
    const lengths = treeCodeLengths(freqs.len, &freqs, 5);
    try std.testing.expect(kraftCost(freqs.len, &lengths, 5) <= (@as(usize, 1) << 5));
    const Table = HuffmanTable(freqs.len);
    const table = try Table.init(&lengths);
    try std.testing.expectEqual(@as(usize, 32), table.len);
}

test "package-merge naturally ordered pairs match sorted reference" {
    {
        var freqs: [286]u32 = @splat(1);
        try expectPackageMergeMatchesReference(freqs.len, &freqs, 15);
        for (&freqs, 0..) |*freq, i| {
            freq.* = @intCast(1 + ((i * 17 + (i / 7) * 31) % 251));
        }
        try expectPackageMergeMatchesReference(freqs.len, &freqs, 15);
        for (&freqs, 0..) |*freq, i| {
            freq.* = if (i == 256 or i % 17 == 0)
                @intCast(1 + ((i * 13 + 5) % 97))
            else
                0;
        }
        try expectPackageMergeMatchesReference(freqs.len, &freqs, 15);
        for (0..16) |seed| {
            for (&freqs, 0..) |*freq, i| {
                // Include sparse entries and many equal weights so packed
                // byte comparison exercises both nibbles of every tie-break
                // byte, including the odd final symbol pair.
                freq.* = if ((i + seed) % 11 == 0 and i != 256)
                    0
                else
                    @intCast(1 + ((i * 5 + seed * 7 + i * seed) % 13));
            }
            try expectPackageMergeMatchesReference(freqs.len, &freqs, 15);
        }
    }
    {
        var freqs: [30]u32 = @splat(1);
        try expectPackageMergeMatchesReference(freqs.len, &freqs, 15);
        for (&freqs, 0..) |*freq, i| {
            freq.* = @intCast(1 + ((i * 11 + 3) % 29));
        }
        try expectPackageMergeMatchesReference(freqs.len, &freqs, 15);
        for (0..16) |seed| {
            for (&freqs, 0..) |*freq, i| {
                freq.* = if ((i + seed) % 7 == 0)
                    0
                else
                    @intCast(1 + ((i * 3 + seed * 5 + i * seed) % 9));
            }
            try expectPackageMergeMatchesReference(freqs.len, &freqs, 15);
        }
    }
    {
        var freqs: [19]u32 = @splat(1);
        try expectPackageMergeMatchesReference(freqs.len, &freqs, 7);
        for (0..32) |seed| {
            for (&freqs, 0..) |*freq, i| {
                // The small modulus deliberately creates many equal package
                // weights, exercising the counts tie-break proof as well as
                // the simpler strictly increasing pair-weight case.
                freq.* = @intCast(1 + ((i * 7 + seed * 11 + i * seed) % 9));
            }
            try expectPackageMergeMatchesReference(freqs.len, &freqs, 7);
        }
    }
}

fn expectPackageMergeMatchesReference(
    comptime n: usize,
    freqs: *const [n]u32,
    max_bits: u4,
) !void {
    var active: usize = 0;
    for (freqs.*) |freq| active += @intFromBool(freq != 0);
    try std.testing.expect(active >= 2);
    try std.testing.expect(active <= (@as(usize, 1) << max_bits));
    try std.testing.expectEqual(
        packageMergeCodeLengthsReference(n, freqs, max_bits, active),
        packageMergeCodeLengths(n, freqs, max_bits, active),
    );
}

test "compact sparse package-merge matches full-width reference" {
    var freqs: [286]u32 = @splat(0);
    for (0..48) |active| {
        @memset(&freqs, 0);
        const count = active + 2;
        for (0..count) |i| {
            const symbol = (i * 17 + active * 11) % freqs.len;
            freqs[symbol] = @intCast(1 + ((i * 13 + active * 7) % 97));
        }
        var actual_active: usize = 0;
        for (freqs) |freq| actual_active += @intFromBool(freq != 0);
        if (actual_active < 2 or actual_active > 64) continue;
        try std.testing.expectEqual(
            packageMergeCodeLengths(freqs.len, &freqs, 15, actual_active),
            treeCodeLengths(freqs.len, &freqs, 15),
        );
    }
}

test "known-active package-merge matches scanned builder" {
    for (2..257) |active_count| {
        var freqs: [286]u32 = @splat(0);
        var active: [256]u16 = undefined;
        for (0..active_count) |index| {
            const symbol: u16 = @intCast((index * 97 + 41) % freqs.len);
            active[index] = symbol;
            freqs[symbol] = @intCast(1 + ((index * 13 + active_count) % 89));
        }
        std.mem.sort(u16, active[0..active_count], {}, std.sort.asc(u16));
        try std.testing.expectEqual(
            treeCodeLengths(freqs.len, &freqs, 15),
            treeCodeLengthsKnownActive(freqs.len, &freqs, 15, active[0..active_count]),
        );
    }
}

test "dense back-reference package-merge preserves optimal weighted cost" {
    var freqs: [286]u32 = undefined;
    for (0..24) |seed| {
        for (&freqs, 0..) |*freq, symbol|
            freq.* = @intCast(1 + ((symbol * 17 + seed * 31 + symbol * seed) % 251));
        const production = treeCodeLengths(freqs.len, &freqs, 15);
        const reference = treeCodeLengthsFullWidth(freqs.len, &freqs, 15);
        try std.testing.expectEqual(
            codeLengthCost(freqs.len, &freqs, &reference),
            codeLengthCost(freqs.len, &freqs, &production),
        );
        try std.testing.expect(kraftCost(freqs.len, &production, 15) <= (@as(usize, 1) << 15));
        try std.testing.expectEqual(production, treeCodeLengths(freqs.len, &freqs, 15));
    }
}

test "dense Deflate unbounded tree matches package-merge cost" {
    var state: u32 = 0x510e_527f;
    var freqs: [286]u32 = undefined;
    for (0..64) |seed| {
        @memset(&freqs, 0);
        const active = 240 + seed % 47;
        for (0..active) |index| {
            state = state *% 1_664_525 +% 1_013_904_223;
            freqs[(index * 149 + seed * 53) % freqs.len] = 1 + (state >> 20);
        }
        const reference = backrefPackageMergeCodeLengths(freqs.len, &freqs, 15, active);
        const production = treeCodeLengthsDenseDeflate(&freqs, active);
        try std.testing.expectEqual(reference, production);
        if (unboundedDenseCodeLengthsWithSpreadPolicy(freqs.len, &freqs, 15, active, false, true)) |fast| {
            try std.testing.expectEqual(
                codeLengthCost(freqs.len, &freqs, &reference),
                codeLengthCost(freqs.len, &freqs, &fast),
            );
            try std.testing.expectEqual(reference, fast);
            try std.testing.expect(kraftCost(freqs.len, &fast, 15) <= (@as(usize, 1) << 15));
        }
    }
}

test "dense Deflate leaf ordering matches generic total order" {
    const Node = struct {
        weight: u64,
        serial: u16,
    };
    const Less = struct {
        nodes: []const Node,

        fn less(context: @This(), lhs: u16, rhs: u16) bool {
            const left = context.nodes[lhs];
            const right = context.nodes[rhs];
            return left.weight < right.weight or
                (left.weight == right.weight and left.serial < right.serial);
        }
    };

    var state: u32 = 0x1f83_d9ab;
    var nodes: [286]Node = undefined;
    var production: [286]u16 = undefined;
    var reference: [286]u16 = undefined;
    for (0..128) |seed| {
        const active = 240 + seed % 47;
        var counts: [dense_deflate_leaf_bucket_count]u16 = @splat(0);
        for (nodes[0..active], 0..) |*node, index| {
            state = state *% 1_664_525 +% 1_013_904_223;
            const weight: u32 = switch (seed % 4) {
                0 => 1 + (state % 4),
                1 => 160 + (state % 16),
                2 => 1 + (state >> 20),
                else => if (index < 258) 1 + @as(u32, @intCast(index % 4)) else 166 + (state % 4096),
            };
            node.* = .{ .weight = weight, .serial = @intCast(index) };
            production[index] = @intCast(index);
            reference[index] = @intCast(index);
            counts[denseDeflateLeafFrequencyBucket(weight)] += 1;
        }
        const less = Less{ .nodes = nodes[0..active] };
        orderDenseDeflateNodeIndexes(
            production[0..active],
            nodes[0..active],
            &counts,
            less,
            Less.less,
        );
        std.mem.sort(u16, reference[0..active], less, Less.less);
        try std.testing.expectEqualSlices(u16, reference[0..active], production[0..active]);
    }
}

test "linear back-reference recovery matches root traversal" {
    var state: u32 = 0xbb67_ae85;
    {
        var freqs: [286]u32 = undefined;
        for (0..48) |seed| {
            for (&freqs, 0..) |*freq, symbol| {
                state = state *% 1_664_525 +% 1_013_904_223;
                freq.* = if ((symbol + seed) % 17 == 0) 0 else 1 + ((state >> 16) % 4096);
            }
            var active: usize = 0;
            for (freqs) |frequency| active += @intFromBool(frequency != 0);
            try std.testing.expect(active > 64);
            try std.testing.expectEqual(
                backrefPackageMergeCodeLengthsReference(freqs.len, &freqs, 15, active),
                backrefPackageMergeCodeLengths(freqs.len, &freqs, 15, active),
            );
        }
    }
    {
        var freqs: [256]u32 = undefined;
        for (0..48) |seed| {
            @memset(&freqs, 0);
            const active = 65 + (seed * 37) % 192;
            for (0..active) |index| {
                state = state *% 1_664_525 +% 1_013_904_223;
                freqs[(index * 149 + seed * 53) % freqs.len] = 1 + ((state >> 16) % 4096);
            }
            try std.testing.expectEqual(
                backrefPackageMergeCodeLengthsReference(freqs.len, &freqs, 11, active),
                backrefPackageMergeCodeLengths(freqs.len, &freqs, 11, active),
            );
        }
    }
}

test "dense known-active fast paths match comparison sort" {
    var state: u32 = 0x3c6e_f372;
    var freqs: [256]u32 = undefined;
    var active_symbols: [256]u16 = undefined;
    for (65..257) |active_target| {
        @memset(&freqs, 0);
        for (0..active_target) |index| {
            state = state *% 1_664_525 +% 1_013_904_223;
            freqs[(index * 149 + active_target * 37) % freqs.len] = 1 + ((state >> 16) % 4096);
        }
        var active_count: usize = 0;
        for (freqs, 0..) |frequency, symbol| {
            if (frequency == 0) continue;
            active_symbols[active_count] = @intCast(symbol);
            active_count += 1;
        }
        try std.testing.expectEqual(active_target, active_count);
        try std.testing.expectEqual(
            treeCodeLengths(freqs.len, &freqs, 11),
            treeCodeLengthsKnownActive(freqs.len, &freqs, 11, active_symbols[0..active_count]),
        );
    }

    for (0..128) |seed| {
        const active = 128 + (seed * 37) % 129;
        var balanced: [256]u32 = @splat(0);
        for (0..active) |index| {
            state = state *% 1_664_525 +% 1_013_904_223;
            balanced[(index * 149 + seed * 53) % balanced.len] = 64 + (state >> 24);
        }
        const balanced_fast = unboundedDenseCodeLengths(balanced.len, &balanced, 11, active) orelse
            return error.CorruptFrame;
        try std.testing.expectEqual(treeCodeLengths(balanced.len, &balanced, 11), balanced_fast);
    }

    var spread_boundary: [256]u32 = @splat(0);
    @memset(spread_boundary[0..128], 1);
    spread_boundary[127] = 16;
    try std.testing.expect(unboundedDenseCodeLengths(spread_boundary.len, &spread_boundary, 11, 128) != null);
    spread_boundary[127] = 17;
    try std.testing.expect(unboundedDenseCodeLengths(spread_boundary.len, &spread_boundary, 11, 128) == null);

    var skewed: [256]u32 = @splat(0);
    var active_skewed: [128]u16 = undefined;
    for (&active_skewed, 0..) |*symbol, index| {
        symbol.* = @intCast(index);
        skewed[index] = if (index < 96) 1 else @as(u32, 1) << @intCast(@min(index - 96, 30));
    }
    try std.testing.expect(unboundedDenseCodeLengthsWithSpreadPolicy(skewed.len, &skewed, 11, active_skewed.len, false, false) == null);
    try std.testing.expectEqual(
        backrefPackageMergeCodeLengths(skewed.len, &skewed, 11, active_skewed.len),
        treeCodeLengthsKnownActive(skewed.len, &skewed, 11, &active_skewed),
    );
}

test "package-merge Huffman lengths match small optimal costs" {
    {
        const freqs = [_]u32{ 5, 7, 10, 15 };
        const lengths = treeCodeLengths(freqs.len, &freqs, 3);
        try std.testing.expectEqual(@as(usize, 71), codeLengthCost(freqs.len, &freqs, &lengths));
        try std.testing.expect(kraftCost(freqs.len, &lengths, 3) <= (@as(usize, 1) << 3));
    }
    {
        const freqs = [_]u32{ 100, 50, 25, 1 };
        const lengths = treeCodeLengths(freqs.len, &freqs, 3);
        try std.testing.expectEqual(@as(usize, 278), codeLengthCost(freqs.len, &freqs, &lengths));
        try std.testing.expect(kraftCost(freqs.len, &lengths, 3) <= (@as(usize, 1) << 3));
    }
    {
        const freqs = [_]u32{ 1, 2, 3, 4, 5 };
        const lengths = treeCodeLengths(freqs.len, &freqs, 3);
        try std.testing.expectEqual(@as(usize, 33), codeLengthCost(freqs.len, &freqs, &lengths));
        try std.testing.expect(kraftCost(freqs.len, &lengths, 3) <= (@as(usize, 1) << 3));
    }
    {
        const freqs = [_]u32{ 10_000, 1_000, 1, 1, 1, 1, 1 };
        const lengths = treeCodeLengths(freqs.len, &freqs, 4);
        try std.testing.expectEqual(@as(usize, 13_019), codeLengthCost(freqs.len, &freqs, &lengths));
        try std.testing.expect(kraftCost(freqs.len, &lengths, 4) <= (@as(usize, 1) << 4));
    }
}

test "package-merge Huffman length builder covers deflate alphabet sizes" {
    {
        var freqs: [286]u32 = @splat(0);
        for (&freqs, 0..) |*freq, i| {
            // Deterministic non-uniform shape that exercises all literal/length
            // symbols without depending on corpus data. Symbol 256 is not
            // special here: dynamic block planning separately ensures EOB is
            // present before calling the length builder.
            freq.* = @intCast(1 + ((i * 17 + (i / 7) * 31) % 251));
        }
        const first = treeCodeLengths(freqs.len, &freqs, max_code_bits);
        const second = treeCodeLengths(freqs.len, &freqs, max_code_bits);
        try std.testing.expectEqual(first, second);
        try std.testing.expect(kraftCost(freqs.len, &first, max_code_bits) <= (@as(usize, 1) << max_code_bits));
        for (first) |bits| try std.testing.expect(bits > 0 and bits <= max_code_bits);
    }
    {
        var freqs: [30]u32 = @splat(0);
        for (&freqs, 0..) |*freq, i| freq.* = @intCast(1 + ((i * 11 + 3) % 29));
        const lengths = treeCodeLengths(freqs.len, &freqs, max_code_bits);
        try std.testing.expect(kraftCost(freqs.len, &lengths, max_code_bits) <= (@as(usize, 1) << max_code_bits));
        for (lengths) |bits| try std.testing.expect(bits > 0 and bits <= max_code_bits);
    }
    {
        var freqs: [19]u32 = @splat(0);
        for (&freqs, 0..) |*freq, i| freq.* = @intCast(1 + ((i * 5 + 7) % 23));
        const lengths = treeCodeLengths(freqs.len, &freqs, 7);
        try std.testing.expect(kraftCost(freqs.len, &lengths, 7) <= (@as(usize, 1) << 7));
        for (lengths) |bits| try std.testing.expect(bits > 0 and bits <= 7);
    }
}

test "direct Huffman encoder matches canonical decoder table entries" {
    const cases = [_][19]u4{
        .{ 3, 3, 3, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 1, 3, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 2, 2, 3, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    };
    for (cases) |lengths| {
        const table = try HuffmanTable(lengths.len).init(&lengths);
        const encoder = try HuffmanTable(lengths.len).Encoder.init(&lengths);
        for (table.entries[0..table.len]) |entry| {
            try std.testing.expectEqual(entry.bits, encoder.bits[entry.symbol]);
            try std.testing.expectEqual(entry.code, encoder.codes[entry.symbol]);
        }
    }

    const oversubscribed = [_]u4{ 1, 1, 1 };
    try std.testing.expectError(error.InvalidHuffmanCode, HuffmanTable(oversubscribed.len).Encoder.init(&oversubscribed));
    const too_many = [_]u4{ 1, 1, 1, 1 };
    try std.testing.expectError(error.InvalidHuffmanCode, HuffmanTable(too_many.len).Encoder.init(&too_many));
}

test "tree Huffman length limiter preserves skewed short codes" {
    var freqs: [20]u32 = @splat(1);
    freqs[0] = 10_000;
    freqs[1] = 1_000;
    const lengths = treeCodeLengths(freqs.len, &freqs, 5);
    try std.testing.expect(kraftCost(freqs.len, &lengths, 5) <= (@as(usize, 1) << 5));
    try std.testing.expect(lengths[0] < lengths[19]);
    try std.testing.expect(lengths[1] <= lengths[19]);
    for (lengths) |bits| {
        try std.testing.expect(bits > 0);
        try std.testing.expect(bits <= 5);
    }
    const Table = HuffmanTable(freqs.len);
    const table = try Table.init(&lengths);
    try std.testing.expectEqual(@as(usize, freqs.len), table.len);
}

test "fast decoder sparse-clears long prefixes" {
    const lengths = [_]u4{
        1, // covers 4 of the 8 lookup slots for a 3-bit fast table
        2, // covers 2 more slots
        3, // covers one more slot
        4, // the only long code covers the last prefix that must fast-miss
    };
    const table = try HuffmanTable(lengths.len).init(&lengths);
    const decoder = FastDecoder(lengths.len, 3).init(table);
    try std.testing.expectEqual(@as(usize, decoder.lookup.len), decoder.lookupCoverage() + decoder.longPrefixCoverage());

    var symbol: usize = 0;
    while (symbol < lengths.len) : (symbol += 1) {
        const bits = lengths[symbol];
        var writer = bitstream.BitWriter{};
        defer writer.deinit(std.testing.allocator);
        const encoder = try HuffmanTable(lengths.len).Encoder.init(&lengths);
        try encoder.writeSymbol(&writer, std.testing.allocator, symbol);
        const bytes = try writer.toOwnedSlice(std.testing.allocator);
        defer std.testing.allocator.free(bytes);

        var reader = bitstream.BitReader.init(bytes);
        try std.testing.expectEqual(@as(u16, @intCast(symbol)), try decoder.decodeValue(&reader));
        try std.testing.expectEqual(@as(usize, bits), reader.bitPosition());
    }
}

fn codeLengthCost(comptime n: usize, freqs: *const [n]u32, lengths: *const [n]u4) usize {
    var cost: usize = 0;
    for (freqs.*, lengths.*) |freq, bits| cost += @as(usize, freq) * bits;
    return cost;
}

test "fixed literal fast lookup matches table decoder" {
    const bytes = [_]u8{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 };
    var fast = bitstream.BitReader.init(&bytes);
    _ = try fast.readBits(u1, 1);
    _ = try fast.readBits(u2, 2);
    var slow = bitstream.BitReader.init(&bytes);
    _ = try slow.readBits(u1, 1);
    _ = try slow.readBits(u2, 2);
    const table = try fixedLiteralTable();
    for (0..6) |_| {
        try std.testing.expectEqual((try table.decode(&slow)).value, (try decodeFixedLiteralFast(&fast)).value);
    }

    var value_reader = bitstream.BitReader.init(&bytes);
    _ = try value_reader.readBits(u1, 1);
    _ = try value_reader.readBits(u2, 2);
    try std.testing.expectEqual(@as(u16, 'h'), try decodeFixedLiteralValueFast(&value_reader));
}

test "fixed distance fast lookup decodes all symbols" {
    for (0..30) |symbol| {
        const code = @bitReverse(@as(u5, @intCast(symbol)));
        var bytes = [_]u8{@intCast(code)};
        var reader = bitstream.BitReader.init(&bytes);
        try std.testing.expectEqual(@as(u16, @intCast(symbol)), (try decodeFixedDistanceFast(&reader)).value);
        var value_reader = bitstream.BitReader.init(&bytes);
        try std.testing.expectEqual(@as(u16, @intCast(symbol)), try decodeFixedDistanceValueFast(&value_reader));
    }
}

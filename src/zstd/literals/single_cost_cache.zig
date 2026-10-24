//! Exact costs for the legacy single-sequence prefix/tail literal view.
//! A cache borrows one immutable block and owns only fixed-size histogram state.
const std = @import("std");
const CutHistogram = @import("cut_histogram.zig").CutHistogram;

pub const Work = struct {
    cost_queries: u64 = 0,
    huffman_plans: u64 = 0,
    stream_symbol_products: u64 = 0,
    reference_checks: u64 = 0,
    reference_mismatches: u64 = 0,
};

/// Codec delegates the existing Huffman tree, header, and sequence-table rules.
/// `prefix_len` deliberately means block[0..prefix_len], even for a finder
/// query whose start_min is nonzero. This preserves the legacy cost view.
pub fn Cache(comptime Codec: type) type {
    return struct {
        histogram: CutHistogram,
        block: []const u8,
        work: Work = .{},

        const Self = @This();

        pub fn init(block: []const u8) Codec.Error!Self {
            return .{ .histogram = try CutHistogram.init(block), .block = block };
        }

        pub fn payloadLen(self: *Self, prefix_len: usize, offset: usize, match_len: usize, tail_start: usize) Codec.Error!usize {
            self.work.cost_queries +|= 1;
            const actual = self.calculatePayloadLen(prefix_len, offset, match_len, tail_start);
            // Test codecs compare every query, including rejected and losing
            // candidates. Production codecs retain no reference callback.
            if (@hasDecl(Codec, "referenceCost")) {
                self.work.reference_checks +|= 1;
                const reference = Codec.referenceCost(self.block, prefix_len, offset, match_len, tail_start);
                const equal = if (reference) |expected|
                    if (actual) |value| value == expected else |_| false
                else |expected_error| if (actual) |_| false else |actual_error| actual_error == expected_error;
                self.work.reference_mismatches +|= @intFromBool(!equal);
            }
            return actual;
        }

        fn calculatePayloadLen(self: *Self, prefix_len: usize, offset: usize, match_len: usize, tail_start: usize) Codec.Error!usize {
            const literals_len = try self.literalSectionLen(prefix_len, tail_start);
            var best: ?usize = null;
            if (Codec.rlePayloadLen(prefix_len, offset, match_len, literals_len)) |len| {
                best = len;
            } else |err| switch (err) {
                error.CorruptFrame => {},
                else => return err,
            }
            if (Codec.predefinedPayloadLen(prefix_len, offset, match_len, literals_len)) |len| {
                if (best == null or len < best.?) best = len;
            } else |err| switch (err) {
                error.CorruptFrame => {},
                else => return err,
            }
            return best orelse error.CorruptFrame;
        }

        pub fn literalSectionLen(self: *Self, prefix_len: usize, tail_start: usize) Codec.Error!usize {
            try self.histogram.update(prefix_len, tail_start);
            var frequencies: [256]u32 = undefined;
            self.histogram.totalFrequencies(&frequencies);
            var unique: usize = 0;
            for (frequencies) |frequency| unique += @intFromBool(frequency != 0);
            const regenerated = self.histogram.regenerated_len;
            const raw_len = if (unique == 1) 1 else regenerated;
            var best = std.math.add(usize, try Codec.literalHeaderLen(regenerated), raw_len) catch return error.IntegerOverflow;
            if (unique < 2 or regenerated < 64) return best;

            self.work.huffman_plans +|= 1;
            const plan = Codec.planFromFrequencies(&frequencies) orelse return best;
            const tree_len = try Codec.treeLen(&plan) orelse return best;
            const streams_len = try self.streamsLen(&plan.bit_counts) orelse return best;
            const compressed_size = std.math.add(usize, tree_len, streams_len) catch return error.IntegerOverflow;
            const header_len = Codec.huffmanHeaderLen(regenerated, compressed_size) catch |err| switch (err) {
                error.UnsupportedZstdFeature => return best,
                else => return err,
            };
            const compressed = std.math.add(usize, header_len, compressed_size) catch return error.IntegerOverflow;
            if (compressed < best) best = compressed;
            return best;
        }

        /// The histogram already divides the regenerated prefix/tail view into
        /// the canonical one or four streams. Count bits without scanning bytes.
        fn streamsLen(self: *Self, bit_counts: *const [256]u8) Codec.Error!?usize {
            var total: usize = if (self.histogram.stream_count == 1) 0 else 6;
            for (self.histogram.stream_frequencies[0..self.histogram.stream_count]) |*frequencies| {
                var stream_bits: usize = 0;
                for (frequencies, bit_counts) |frequency, bits| {
                    if (frequency == 0) continue;
                    if (bits == 0) return error.CorruptFrame;
                    self.work.stream_symbol_products +|= 1;
                    const product = std.math.mul(usize, frequency, bits) catch return error.IntegerOverflow;
                    stream_bits = std.math.add(usize, stream_bits, product) catch return error.IntegerOverflow;
                }
                const rounded = std.math.add(usize, stream_bits, 8) catch return error.IntegerOverflow;
                const stream_len = rounded / 8; // One end bit followed by padding.
                if (self.histogram.stream_count != 1 and stream_len > std.math.maxInt(u16)) return null;
                total = std.math.add(usize, total, stream_len) catch return error.IntegerOverflow;
            }
            return total;
        }
    };
}

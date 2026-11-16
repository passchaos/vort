//! N-way interleaved rANS.
//!
//! This is the decode-ILP mechanism in the native entropy design
//! (`docs/formats/native-entropy-design.md`). Symbols are assigned round-robin
//! to `N` lanes; every lane owns an independent scalar rANS state and its own
//! renormalization byte span. Because lane `i`'s recurrence touches only
//! `state[i]` and `bytes[i]`, the lanes have no shared cursor and can be
//! decoded concurrently or mapped to SIMD lanes later. This module still runs
//! them scalarly and proves the two decode strategies agree exactly.
//!
//! No frame I/O and no wire bytes are frozen here: the produced stream is an
//! in-memory representation a later framing milestone can serialize.
const std = @import("std");
const encoder_mod = @import("encoder.zig");
const decoder_mod = @import("decoder.zig");
const table_mod = @import("table.zig");

const Encoder = encoder_mod.Encoder;
const Decoder = decoder_mod.Decoder;
const Table = table_mod.Table;

/// Upper bound on interleaving. The design's first milestone fixes N = 4; the
/// cap lets property tests sweep every smaller lane count without heap arrays
/// of lanes.
pub const max_lanes: u8 = 8;

pub const Error = encoder_mod.Error || decoder_mod.Error || error{
    /// Requested lane count was zero or exceeded `max_lanes`.
    InvalidLaneCount,
    /// A caller-provided output buffer did not match the required symbol count.
    OutputTooSmall,
    OutOfMemory,
};

/// Number of symbols assigned to `lane` when `symbol_count` symbols are spread
/// round-robin over `lane_count` lanes: positions `lane, lane+N, lane+2N, ...`.
pub fn laneSymbolCount(symbol_count: usize, lane_count: usize, lane: usize) usize {
    if (lane >= lane_count or lane >= symbol_count) return 0;
    return (symbol_count - 1 - lane) / lane_count + 1;
}

/// An encoded interleaved stream: one contiguous renorm buffer plus prefix
/// offsets so each lane's span is independently indexable, and one final state
/// per lane.
pub const Stream = struct {
    allocator: std.mem.Allocator,
    log2_scale: u8,
    lane_count: u8,
    symbol_count: usize,
    states: [max_lanes]u32,
    offsets: [max_lanes + 1]usize,
    bytes: []u8,

    pub fn deinit(self: *Stream) void {
        self.allocator.free(self.bytes);
    }

    /// Borrowed view of one lane's forward-order renormalization bytes.
    pub fn laneBytes(self: Stream, lane: usize) []const u8 {
        return self.bytes[self.offsets[lane]..self.offsets[lane + 1]];
    }

    pub fn laneState(self: Stream, lane: usize) u32 {
        return self.states[lane];
    }
};

pub const InterleavedEncoder = struct {
    allocator: std.mem.Allocator,
    log2_scale: u8,
    lane_count: u8,
    symbol_count: usize = 0,
    lanes: [max_lanes]Encoder,

    pub fn init(allocator: std.mem.Allocator, log2_scale: u8, lane_count: u8) Error!InterleavedEncoder {
        if (lane_count == 0 or lane_count > max_lanes) return error.InvalidLaneCount;
        var lanes: [max_lanes]Encoder = undefined;
        var index: usize = 0;
        while (index < max_lanes) : (index += 1) {
            lanes[index] = Encoder.init(allocator, log2_scale);
        }
        return .{
            .allocator = allocator,
            .log2_scale = log2_scale,
            .lane_count = lane_count,
            .lanes = lanes,
        };
    }

    pub fn deinit(self: *InterleavedEncoder) void {
        for (&self.lanes) |*lane| lane.deinit();
    }

    /// Encode one symbol onto its round-robin lane.
    pub fn encodeSymbol(self: *InterleavedEncoder, model: Table, symbol: usize) Error!void {
        const lane = self.symbol_count % self.lane_count;
        try self.lanes[lane].encodeSymbol(model, symbol);
        self.symbol_count += 1;
    }

    /// Finish every lane and pack the renorm spans into one owned buffer with
    /// per-lane prefix offsets. The scalar lane encoders are consumed and left
    /// empty; their exact states and byte order are preserved.
    pub fn finishOwned(self: *InterleavedEncoder) Error!Stream {
        var states: [max_lanes]u32 = std.mem.zeroes([max_lanes]u32);
        var offsets: [max_lanes + 1]usize = std.mem.zeroes([max_lanes + 1]usize);
        var total_bytes: usize = 0;

        // First finish each lane (this reverses its bytes) and learn lengths.
        var lane_slices: [max_lanes][]u8 = undefined;
        var lane: usize = 0;
        while (lane < self.lane_count) : (lane += 1) {
            const finished = try self.lanes[lane].finishOwned();
            states[lane] = finished.state;
            lane_slices[lane] = finished.bytes;
            offsets[lane + 1] = offsets[lane] + finished.bytes.len;
            total_bytes += finished.bytes.len;
        }

        const bytes = self.allocator.alloc(u8, total_bytes) catch return error.OutOfMemory;
        errdefer self.allocator.free(bytes);
        lane = 0;
        while (lane < self.lane_count) : (lane += 1) {
            const span = lane_slices[lane];
            @memcpy(bytes[offsets[lane]..offsets[lane + 1]], span);
            self.allocator.free(span);
        }

        return .{
            .allocator = self.allocator,
            .log2_scale = self.log2_scale,
            .lane_count = self.lane_count,
            .symbol_count = self.symbol_count,
            .states = states,
            .offsets = offsets,
            .bytes = bytes,
        };
    }
};

pub const InterleavedDecoder = struct {
    log2_scale: u8,
    lane_count: u8,
    symbol_count: usize,
    lanes: [max_lanes]Decoder,

    pub fn init(stream: Stream) InterleavedDecoder {
        var lanes: [max_lanes]Decoder = undefined;
        var lane: usize = 0;
        while (lane < max_lanes) : (lane += 1) {
            if (lane < stream.lane_count) {
                lanes[lane] = Decoder.init(stream.laneState(lane), stream.laneBytes(lane), stream.log2_scale);
            } else {
                lanes[lane] = Decoder.init(0, &.{}, stream.log2_scale);
            }
        }
        return .{
            .log2_scale = stream.log2_scale,
            .lane_count = stream.lane_count,
            .symbol_count = stream.symbol_count,
            .lanes = lanes,
        };
    }

    /// Sequential interleaved walk: decode positions from the last encoded
    /// symbol down to the first, choosing the lane by `position mod N`. The
    /// returned slice is in reverse encoding order (natural rANS order).
    pub fn decodeReversed(self: *InterleavedDecoder, model: Table, allocator: std.mem.Allocator) Error![]u16 {
        const out = allocator.alloc(u16, self.symbol_count) catch return error.OutOfMemory;
        errdefer allocator.free(out);
        var position: usize = self.symbol_count;
        var out_index: usize = 0;
        while (position > 0) {
            position -= 1;
            const lane = position % self.lane_count;
            out[out_index] = try self.lanes[lane].next(model);
            out_index += 1;
        }
        return out;
    }

    /// Independent per-lane decode (the parallel form). Decodes only the
    /// symbols owned by `lane` into `out`, which must hold exactly
    /// `laneSymbolCount(...)` entries. Lanes never share state, so each call is
    /// independent and could run concurrently in a later executor.
    pub fn decodeLaneInto(self: *InterleavedDecoder, model: Table, lane: usize, out: []u16) Error!void {
        if (lane >= self.lane_count) return error.InvalidLaneCount;
        const expected = laneSymbolCount(self.symbol_count, self.lane_count, lane);
        if (out.len != expected) return error.OutputTooSmall;
        var index: usize = 0;
        while (index < expected) : (index += 1) {
            out[index] = try self.lanes[lane].next(model);
        }
    }

    /// True when every lane has consumed its full renorm span.
    pub fn allBytesConsumed(self: InterleavedDecoder) bool {
        var lane: usize = 0;
        while (lane < self.lane_count) : (lane += 1) {
            if (self.lanes[lane].remainingBytes() != 0) return false;
        }
        return true;
    }

    /// True when every lane state has returned to the lower bound.
    pub fn allStatesAtLowerBound(self: InterleavedDecoder) bool {
        var lane: usize = 0;
        while (lane < self.lane_count) : (lane += 1) {
            if (self.lanes[lane].state != encoder_mod.lower_bound) return false;
        }
        return true;
    }
};

test "lane symbol count partitions every position exactly once" {
    const n: usize = 4;
    const m: usize = 10;
    var total: usize = 0;
    for (0..n) |lane| {
        const count = laneSymbolCount(m, n, lane);
        try std.testing.expectEqual(@as(usize, if (lane < 2) 3 else 2), count);
        total += count;
    }
    try std.testing.expectEqual(m, total);
    // Lanes beyond the symbol span and beyond the lane count own nothing.
    try std.testing.expectEqual(@as(usize, 0), laneSymbolCount(m, n, 7));
    try std.testing.expectEqual(@as(usize, 0), laneSymbolCount(m, n, n));
    // When there are fewer symbols than lanes, trailing lanes are empty.
    try std.testing.expectEqual(@as(usize, 1), laneSymbolCount(2, 4, 0));
    try std.testing.expectEqual(@as(usize, 0), laneSymbolCount(2, 4, 2));
}

test "interleaved encoder rejects invalid lane counts" {
    try std.testing.expectError(error.InvalidLaneCount, InterleavedEncoder.init(std.testing.allocator, 8, 0));
    try std.testing.expectError(error.InvalidLaneCount, InterleavedEncoder.init(std.testing.allocator, 8, max_lanes + 1));
}

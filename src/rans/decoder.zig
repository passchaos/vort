//! Scalar byte-renormalized rANS decoder.
//!
//! Inverse of `encoder.zig`. Each step maps the current state's low
//! `log2_scale` bits to a symbol through the normalized table, reconstructs the
//! predecessor state, then refills from the forward renormalization byte
//! stream while the state is below the fixed lower bound `B = 1 << 23`. The
//! lower bound is independent of the model constant `L`; this mirrors the
//! encoder's single-byte flush invariant. All arithmetic is bounded and a
//! truncated or corrupt stream fails explicitly rather than reading out of
//! range.
const std = @import("std");
const table_mod = @import("table.zig");
const encoder_mod = @import("encoder.zig");
const Table = table_mod.Table;
const lower_bound = encoder_mod.lower_bound;

pub const Error = error{
    /// Renormalization bytes were exhausted before the state returned to `B`.
    TruncatedStream,
    /// A slot resolved to an inactive symbol (table/stream disagreement).
    CorruptStream,
};

pub const Decoder = struct {
    log2_scale: u8,
    state: u32,
    bytes: []const u8,
    pos: usize = 0,

    pub fn init(state: u32, bytes: []const u8, log2_scale: u8) Decoder {
        // A stored final state may already be below `B`; the first `next`
        // refill restores it. State magnitude is not a validity check at this
        // layer, so truncation and symbol-table agreement are the errors.
        return .{ .log2_scale = log2_scale, .state = state, .bytes = bytes };
    }

    pub fn remainingBytes(self: Decoder) usize {
        return self.bytes.len - self.pos;
    }

    /// Decode one symbol. Symbols come out in reverse encoding order.
    pub fn next(self: *Decoder, model: Table) Error!u16 {
        const l: u32 = @as(u32, 1) << @intCast(self.log2_scale);
        const mask = l - 1;

        const slot: usize = @intCast(self.state & mask);
        const symbol = model.symbolFromSlot(slot);
        const f = model.freq[symbol];
        if (f == 0) return error.CorruptStream;
        const b = model.cum[symbol];

        var x = f * (self.state >> @intCast(self.log2_scale)) + @as(u32, @intCast(slot)) - b;
        while (x < lower_bound) {
            if (self.pos >= self.bytes.len) return error.TruncatedStream;
            x = (x << 8) | self.bytes[self.pos];
            self.pos += 1;
        }
        self.state = x;
        return symbol;
    }
};

/// Independent reference decoder that ignores the dense `lookup` table and
/// finds the symbol by linear cumulative search. Tests use it to prove the
/// table-driven decoder and the encoder agree without trusting the lookup.
pub fn nextLinear(decoder: *Decoder, model: Table) Error!u16 {
    const l: u32 = @as(u32, 1) << @intCast(decoder.log2_scale);
    const mask = l - 1;

    const slot: usize = @intCast(decoder.state & mask);
    const symbol = model.symbolFromSlotLinear(slot) orelse return error.CorruptStream;
    const f = model.freq[symbol];
    if (f == 0) return error.CorruptStream;
    const b = model.cum[symbol];

    var x = f * (decoder.state >> @intCast(decoder.log2_scale)) + @as(u32, @intCast(slot)) - b;
    while (x < lower_bound) {
        if (decoder.pos >= decoder.bytes.len) return error.TruncatedStream;
        x = (x << 8) | decoder.bytes[decoder.pos];
        decoder.pos += 1;
    }
    decoder.state = x;
    return symbol;
}

test "decoder accepts a stored state below the lower bound and refills on first step" {
    const bytes = [_]u8{ 0x10, 0x00 };
    // A low initial state is legal: the first step refills before use.
    var dec = Decoder.init(1, &bytes, 8);
    try std.testing.expectEqual(@as(usize, 2), dec.remainingBytes());
    try std.testing.expectEqual(@as(u32, 1), dec.state);
}

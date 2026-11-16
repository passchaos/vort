//! Scalar byte-renormalized rANS encoder.
//!
//! Canonical forward rANS following the standard two-constant invariant:
//!
//! - `B = 1 << 23` is the fixed state lower bound, independent of the model's
//!   normalization constant `L = 2^log2_scale`;
//! - a live state always stays in `[B, 256*B)`;
//! - before encoding a symbol of frequency `f`, low bytes are flushed while
//!   `x >= x_max`, where `x_max = (B / L) * 256 * f`. A rare symbol (`f = 1`)
//!   at large `L` can require more than one byte, so this is a loop, the exact
//!   inverse of the decoder's refill-while-`x < B` loop.
//!
//! Keeping `B` separate from `L` is what keeps the state bounded for rare
//! symbols (`f = 1`): the `B / L` headroom means only a few byte shifts are ever
//! needed, and the flush loop (the exact inverse of the decoder refill) runs
//! until the invariant holds. Renormalization bytes are appended in emission
//! order and reversed at `finish`, so the returned slice is in the exact forward
//! order the decoder consumes. rANS recovers symbols in reverse encoding order;
//! the framing layer handles reordering.
const std = @import("std");
const table_mod = @import("table.zig");
const Table = table_mod.Table;

/// Fixed rANS state lower bound. Model precision must not exceed this so the
/// `B / L` headroom stays positive; `table.max_log2_scale` enforces that.
pub const lower_bound: u32 = 1 << 23;

/// Renormalization base: each flushed/refilled unit is one byte.
pub const renorm_base: u32 = 256;

pub const Error = error{
    /// Asked to encode a symbol whose normalized frequency is zero.
    InvalidSymbol,
    OutOfMemory,
};

/// Initial rANS state. A stream always begins at the fixed lower bound.
pub fn initialState() u32 {
    return lower_bound;
}

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    log2_scale: u8,
    state: u32,
    renorm: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, log2_scale: u8) Encoder {
        return .{
            .allocator = allocator,
            .log2_scale = log2_scale,
            .state = initialState(),
            .renorm = .empty,
        };
    }

    pub fn deinit(self: *Encoder) void {
        self.renorm.deinit(self.allocator);
    }

    /// Encode one symbol. Mirrors the decoder recurrence exactly:
    /// `x' = (x / f) * L + (x mod f) + b`, after flushing low bytes while
    /// needed to keep the next state inside `[B, 256*B)`.
    pub fn encodeSymbol(self: *Encoder, model: Table, symbol: usize) Error!void {
        if (symbol >= model.freq.len) return error.InvalidSymbol;
        const f = model.freq[symbol];
        if (f == 0) return error.InvalidSymbol;
        const l: u32 = @as(u32, 1) << @intCast(self.log2_scale);
        const x_max = (lower_bound / l) * renorm_base * f;

        var x = self.state;
        while (x >= x_max) {
            self.renorm.append(self.allocator, @as(u8, @truncate(x))) catch return error.OutOfMemory;
            x >>= 8;
        }
        self.state = (x / f) * l + (x % f) + model.cum[symbol];
    }

    pub const Finished = struct {
        /// Final state; the decoder starts here.
        state: u32,
        /// Renormalization bytes in decoder-consumption (forward) order.
        bytes: []u8,
    };

    /// Reverse the emitted bytes and hand ownership of the slice to the caller.
    /// The encoder is left empty and must not be reused without re-init.
    pub fn finishOwned(self: *Encoder) Error!Finished {
        std.mem.reverse(u8, self.renorm.items);
        const bytes = self.renorm.toOwnedSlice(self.allocator) catch return error.OutOfMemory;
        return .{ .state = self.state, .bytes = bytes };
    }
};

test "initial state is the fixed lower bound, independent of model scale" {
    try std.testing.expectEqual(@as(u32, 1 << 23), initialState());
}

test "encoding an inactive symbol is rejected without changing state" {
    const counts = [_]u32{ 5, 0, 3 };
    var model = try table_mod.normalize(std.testing.allocator, &counts, 8);
    defer model.deinit();
    var encoder = Encoder.init(std.testing.allocator, 8);
    defer encoder.deinit();
    const before = encoder.state;
    try std.testing.expectError(error.InvalidSymbol, encoder.encodeSymbol(model, 1));
    try std.testing.expectError(error.InvalidSymbol, encoder.encodeSymbol(model, 99));
    try std.testing.expectEqual(before, encoder.state);
}

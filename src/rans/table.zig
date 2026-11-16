//! Scalar rANS frequency table and deterministic normalization.
//!
//! This is the portable correctness oracle for the native entropy stage
//! proposed in `docs/formats/native-entropy-design.md`. It contains no frame
//! I/O and no wire commitments: the byte layout of any future native block is
//! decided separately. Everything here is deterministic for identical inputs so
//! it can underpin both the scalar and the later SIMD decoder.
const std = @import("std");

/// Largest supported model normalization precision. The rANS state lower
/// bound `B = 1 << 23` is fixed, so capping `log2_scale` at 16 keeps at least
/// a 128x `B / L` headroom: a single byte flush always restores the
/// `[B, 256*B)` state invariant, even for the rarest `f = 1` symbols. The
/// design's first milestone uses 12 (`L = 4096`).
pub const max_log2_scale: u8 = 16;

pub const Error = error{
    /// No symbol carried a non-zero count.
    EmptyAlphabet,
    /// More active symbols than available normalized slots (`> L`).
    PrecisionTooSmall,
    /// A requested scale was outside `[1, max_log2_scale]`.
    InvalidScale,
    OutOfMemory,
};

/// A normalized rANS model. `freq[s]` is positive for every active symbol and
/// the frequencies sum exactly to `L`. `cum[s]` is the cumulative frequency
/// of symbols before `s`, and `lookup[slot]` maps every slot in `[0, L)` to
/// the symbol whose `[cum, cum + freq)` interval contains it.
pub const Table = struct {
    allocator: std.mem.Allocator,
    log2_scale: u8,
    /// One entry per input alphabet symbol (inactive symbols have freq 0).
    freq: []u32,
    cum: []u32,
    /// One entry per normalized slot, length `L`.
    lookup: []u16,
    /// Number of distinct active symbols.
    active_count: usize,
    /// Highest active symbol index plus one.
    active_span: usize,

    pub fn scale(self: Table) usize {
        return @as(usize, 1) << @intCast(self.log2_scale);
    }

    pub fn deinit(self: *Table) void {
        self.allocator.free(self.freq);
        self.allocator.free(self.cum);
        self.allocator.free(self.lookup);
    }

    /// Resolve the symbol for a normalized slot. The caller guarantees
    /// `slot < L`; this is the hot decode entry point.
    pub inline fn symbolFromSlot(self: Table, slot: usize) u16 {
        return self.lookup[slot];
    }

    /// Independent reference lookup that scans cumulative intervals instead of
    /// using the precomputed `lookup` table. Test oracles use this to prove the
    /// dense table was built correctly; production decode uses `symbolFromSlot`.
    pub fn symbolFromSlotLinear(self: Table, slot: usize) ?u16 {
        if (slot >= self.scale()) return null;
        var symbol: usize = 0;
        while (symbol < self.active_span) : (symbol += 1) {
            const f = self.freq[symbol];
            if (f == 0) continue;
            const b = self.cum[symbol];
            if (slot >= b and slot < b + f) return @intCast(symbol);
        }
        return null;
    }
};

/// Build a normalized table from raw symbol counts.
///
/// Normalization is the deterministic largest-remainder (Hamilton) method:
/// every active symbol receives one slot, then the remaining `L - active`
/// slots are divided proportionally and the rounding leftovers are granted to
/// the largest fractional remainders, ties broken by ascending symbol index.
/// The result always sums to exactly `L`, keeps every active frequency
/// positive, and is stable across runs and platforms.
pub fn normalize(
    allocator: std.mem.Allocator,
    counts: []const u32,
    log2_scale: u8,
) Error!Table {
    if (log2_scale == 0 or log2_scale > max_log2_scale) return error.InvalidScale;
    const l: usize = @as(usize, 1) << @intCast(log2_scale);

    // First pass: count active symbols and the total raw count.
    var active_count: usize = 0;
    var active_span: usize = 0;
    var total: u64 = 0;
    for (counts, 0..) |count, index| {
        if (count == 0) continue;
        active_count += 1;
        active_span = index + 1;
        total += count;
    }
    if (active_count == 0) return error.EmptyAlphabet;
    if (active_count > l) return error.PrecisionTooSmall;

    const freq = try allocator.alloc(u32, counts.len);
    errdefer allocator.free(freq);
    @memset(freq, 0);

    // Every active symbol starts at one slot. Distribute the rest by largest
    // remainder so the sum lands exactly on L.
    const remaining = l - active_count;
    const quotients = try allocator.alloc(usize, active_count);
    defer allocator.free(quotients);
    const remainders = try allocator.alloc(u64, active_count);
    defer allocator.free(remainders);
    const active_indices = try allocator.alloc(usize, active_count);
    defer allocator.free(active_indices);

    var assigned: usize = 0;
    var active_pos: usize = 0;
    for (counts, 0..) |count, index| {
        if (count == 0) continue;
        active_indices[active_pos] = index;
        if (remaining == 0) {
            quotients[active_pos] = 0;
            remainders[active_pos] = 0;
        } else {
            const numerator = @as(u64, count) * @as(u64, remaining);
            quotients[active_pos] = @intCast(numerator / total);
            remainders[active_pos] = numerator % total;
            assigned += quotients[active_pos];
        }
        active_pos += 1;
    }

    // Grant unassigned slots to the largest remainders, ties by lowest index.
    var leftover = remaining -| assigned;
    while (leftover > 0) {
        var best: ?usize = null;
        for (remainders, 0..) |rem, pos| {
            // A symbol that already holds the maximum proportional share cannot
            // take more once its quotient reaches the per-symbol ceiling; the
            // remainder ordering naturally exhausts before that point.
            if (best == null or rem > remainders[best.?] or
                (rem == remainders[best.?] and active_indices[pos] < active_indices[best.?]))
            {
                best = pos;
            }
        }
        const pos = best orelse break;
        quotients[pos] += 1;
        remainders[pos] = 0; // consume so the next leftover picks a different symbol
        leftover -= 1;
    }

    var sum: usize = 0;
    for (quotients, 0..) |q, pos| {
        const index = active_indices[pos];
        freq[index] = @intCast(1 + q);
        sum += freq[index];
    }
    std.debug.assert(sum == l);

    const cum = try allocator.alloc(u32, counts.len);
    errdefer allocator.free(cum);
    @memset(cum, 0);
    var running: u32 = 0;
    for (freq, 0..) |f, index| {
        cum[index] = running;
        running += f;
    }
    std.debug.assert(running == l);

    const lookup = try allocator.alloc(u16, l);
    errdefer allocator.free(lookup);
    for (freq, 0..) |f, index| {
        if (f == 0) continue;
        const start = cum[index];
        const end = start + f;
        @memset(lookup[start..end], @intCast(index));
    }

    return .{
        .allocator = allocator,
        .log2_scale = log2_scale,
        .freq = freq,
        .cum = cum,
        .lookup = lookup,
        .active_count = active_count,
        .active_span = active_span,
    };
}

test "normalization sums exactly to the scale and keeps active frequencies positive" {
    const counts = [_]u32{ 10, 0, 7, 3, 0, 25 };
    var table = try normalize(std.testing.allocator, &counts, 12);
    defer table.deinit();

    try std.testing.expectEqual(@as(usize, 4096), table.scale());
    var sum: usize = 0;
    for (table.freq) |f| sum += f;
    try std.testing.expectEqual(table.scale(), sum);
    try std.testing.expectEqual(@as(usize, 4), table.active_count);
    for (counts, 0..) |count, index| {
        if (count == 0) try std.testing.expectEqual(@as(u32, 0), table.freq[index]);
    }
}

test "normalization is deterministic and independent of allocation" {
    const counts = [_]u32{ 3, 1, 4, 1, 5, 9, 2, 6 };
    var first = try normalize(std.testing.allocator, &counts, 10);
    defer first.deinit();
    var second = try normalize(std.testing.allocator, &counts, 10);
    defer second.deinit();
    try std.testing.expectEqualSlices(u32, first.freq, second.freq);
    try std.testing.expectEqualSlices(u32, first.cum, second.cum);
    try std.testing.expectEqualSlices(u16, first.lookup, second.lookup);
}

test "dense lookup agrees with the linear cumulative oracle on every slot" {
    var prng = std.Random.DefaultPrng.init(0x52a1_7f3c);
    const random = prng.random();
    var counts: [64]u32 = undefined;
    for (&counts) |*c| c.* = random.intRangeAtMost(u32, 0, 1000);
    counts[0] += 1; // guarantee a non-empty alphabet

    var table = try normalize(std.testing.allocator, &counts, 12);
    defer table.deinit();
    var slot: usize = 0;
    while (slot < table.scale()) : (slot += 1) {
        const dense = table.symbolFromSlot(slot);
        const linear = table.symbolFromSlotLinear(slot) orelse return error.InvalidStreamState;
        try std.testing.expectEqual(linear, dense);
    }
}

test "single-symbol alphabet owns the whole scale" {
    const counts = [_]u32{ 0, 0, 42, 0 };
    var table = try normalize(std.testing.allocator, &counts, 8);
    defer table.deinit();
    try std.testing.expectEqual(@as(u32, 256), table.freq[2]);
    try std.testing.expectEqual(@as(u32, 0), table.cum[2]);
    for (table.lookup) |symbol| try std.testing.expectEqual(@as(u16, 2), symbol);
}

test "normalization rejects empty alphabets, over-wide alphabets and bad scales" {
    const empty = [_]u32{ 0, 0, 0 };
    try std.testing.expectError(error.EmptyAlphabet, normalize(std.testing.allocator, &empty, 8));

    // Scale 1 gives L = 2 slots but there are three active symbols.
    const too_many = [_]u32{ 1, 1, 1 };
    try std.testing.expectError(error.PrecisionTooSmall, normalize(std.testing.allocator, &too_many, 1));

    try std.testing.expectError(error.InvalidScale, normalize(std.testing.allocator, &too_many, 0));
    try std.testing.expectError(error.InvalidScale, normalize(std.testing.allocator, &too_many, 17));
}

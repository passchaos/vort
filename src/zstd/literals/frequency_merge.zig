//! Fixed-alphabet merging for the four streams of a valid CutHistogram.
//! All rows are initialized and each symbol's combined frequency is at most
//! the regenerated block length, bounded by 128KiB. No input is retained.

const lane_count = 8;
const Frequencies = @Vector(lane_count, u32);

/// Write all 256 combined frequencies and return the nonzero-symbol count in
/// the same pass. Inputs and output need only their ordinary u32 alignment.
/// Keep ordinary u32 addition and the scalar path's per-symbol left-to-right
/// order; valid histogram sums cannot overflow. This does not validate an
/// arbitrary externally constructed histogram or change its arithmetic mode.
pub fn mergeActive(rows: *const [4][256]u32, out: *[256]u32) usize {
    var active: usize = 0;
    var offset: usize = 0;
    while (offset < 256) : (offset += lane_count) {
        const first: Frequencies = rows[0][offset..][0..lane_count].*;
        const second: Frequencies = rows[1][offset..][0..lane_count].*;
        const third: Frequencies = rows[2][offset..][0..lane_count].*;
        const fourth: Frequencies = rows[3][offset..][0..lane_count].*;
        const merged = ((first + second) + third) + fourth;
        out[offset..][0..lane_count].* = merged;
        const nonzero = merged != @as(Frequencies, @splat(0));
        active += @popCount(@as(u8, @bitCast(nonzero)));
    }
    return active;
}

/// Original two-pass scalar path for diagnostics and benchmark baselines.
/// Write every total with the original totalFrequencies addition expression,
/// then count nonzero symbols in a separate traversal of the complete output.
pub fn scalarReference(rows: *const [4][256]u32, out: *[256]u32) usize {
    for (out, 0..) |*frequency, symbol| {
        frequency.* = rows[0][symbol] + rows[1][symbol] +
            rows[2][symbol] + rows[3][symbol];
    }
    var active: usize = 0;
    for (out) |frequency| active += @intFromBool(frequency != 0);
    return active;
}

test "zstd frequency merge complete scalar oracle contracts" {
    try @import("frequency_merge_tests.zig").contracts(@This());
}

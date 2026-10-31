//! Detect the original start-major, period-major best repeated byte segment.
const std = @import("std");

pub const Segment = struct {
    start: usize,
    period: usize,
    match_len: usize,
    tail_len: usize,
};
pub const period_max: usize = 64;
pub const start_scan: usize = 48;

pub fn findIn(block: []const u8, start_min: usize, end: usize) ?Segment {
    if (end > block.len or start_min >= end or end - start_min < 8) return null;
    // Subtract before adding so a valid slice near usize.max cannot overflow.
    const last_start = start_min + @min(start_scan, end - start_min - 8);
    // For fixed period p, cache the first mismatch of block[i]==block[i-p].
    // A later start within this verified run reaches the same mismatch/end.
    var cached_end: [period_max + 1]usize = @splat(0);
    var best: ?Segment = null;
    for (start_min..last_start + 1) |start| {
        const remaining = end - start;
        if (best) |old| if (old.match_len >= remaining - 2) break;
        for (2..@min(remaining / 2, period_max) + 1) |period| {
            if (best) |old| if (old.match_len >= remaining - period) break;
            const begin = start + period;
            // Three consecutive shifted equalities are required for a usable
            // match; this preserves the original cheap non-period rejection.
            if (!std.mem.eql(u8, block[start..][0..3], block[begin..][0..3])) continue;
            const end_of_run = if (begin < cached_end[period]) cached_end[period] else extend(block, period, begin + 3, end);
            cached_end[period] = end_of_run;
            const candidate: Segment = .{ .start = start, .period = period, .match_len = end_of_run - begin, .tail_len = end - end_of_run };
            if (best == null or candidate.match_len > best.?.match_len) best = candidate;
        }
    }
    return best;
}

fn extend(block: []const u8, period: usize, begin: usize, end: usize) usize {
    var index = begin;
    // The initial shifted prefix is known equal. Thereafter each additional
    // equality equals the original modulo-anchor comparison by induction.
    while (end - index >= 32) : (index += 32) {
        const left: @Vector(32, u8) = block[index..][0..32].*;
        const right: @Vector(32, u8) = block[index - period ..][0..32].*;
        if (std.simd.firstTrue(left != right)) |mismatch| return index + mismatch;
    }
    while (end - index >= 8) : (index += 8) {
        const left = std.mem.readInt(u64, block[index..][0..8], .little);
        const right = std.mem.readInt(u64, block[index - period ..][0..8], .little);
        if (left != right) return index + @ctz(left ^ right) / 8;
    }
    while (index < end and block[index] == block[index - period]) : (index += 1) {}
    return index;
}

test {
    _ = @import("repeated_pattern_tests.zig");
}

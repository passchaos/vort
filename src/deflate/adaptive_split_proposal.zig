const std = @import("std");
const lz77 = @import("../lz77.zig");

pub const observation_type_count: usize = 10;
pub const observations_per_check: u32 = 512;
pub const max_proposals: usize = 4;

// Keep the detector bounded by the largest DEFLATE block horizon. Histograms
// use u32 counters, while all cross-products below widen to u64.
const Histogram = [observation_type_count]u32;

const DriftInterval = struct {
    begin_token: u16,
    end_token: u16,
    begin_plain: u16,
    end_plain: u16,

    fn byteLength(self: DriftInterval) usize {
        return @as(usize, self.end_plain) - self.begin_plain;
    }
};

pub const ProposalSet = struct {
    boundaries: [max_proposals]usize = @splat(0),
    len: usize = 0,

    pub fn slice(self: *const ProposalSet) []const usize {
        return self.boundaries[0..self.len];
    }

    fn appendValid(
        self: *ProposalSet,
        boundary: usize,
        horizon: usize,
        min_block_len: usize,
    ) void {
        if (boundary > horizon or boundary < min_block_len or
            horizon - boundary < min_block_len)
            return;
        if (self.len != 0 and self.boundaries[self.len - 1] == boundary) return;
        self.boundaries[self.len] = boundary;
        self.len += 1;
    }
};

pub fn proposeTokenBoundary(
    tokens: []const lz77.Token,
    horizon: usize,
    min_block_len: usize,
) !?usize {
    const proposals = try proposeTokenBoundaries(tokens, horizon, min_block_len, 1);
    return if (proposals.len == 0) null else proposals.boundaries[0];
}

pub fn proposeTokenBoundaries(
    tokens: []const lz77.Token,
    horizon: usize,
    min_block_len: usize,
    proposal_limit: usize,
) !ProposalSet {
    if (horizon == 0 or min_block_len == 0 or min_block_len > horizon)
        return error.InvalidBlockPlan;
    if (horizon > std.math.maxInt(u16)) return error.InvalidBlockPlan;
    if (proposal_limit == 0 or proposal_limit > max_proposals)
        return error.InvalidBlockPlan;

    var old_histogram: Histogram = @splat(0);
    var new_histogram: Histogram = @splat(0);
    var old_count: u32 = 0;
    var new_count: u32 = 0;
    var plain_position: usize = 0;
    var new_begin_plain: usize = 0;
    var new_begin_token: usize = 0;
    var proposals: ProposalSet = .{};
    var intervals: [max_proposals]DriftInterval = undefined;
    var interval_count: usize = 0;

    for (tokens, 0..) |token, token_index| {
        const token_len: usize = switch (token) {
            .literal => 1,
            .match => |match| match.length,
        };
        plain_position = std.math.add(usize, plain_position, token_len) catch
            return error.IntegerOverflow;
        if (plain_position > horizon) return error.InvalidBlockPlan;

        const class = observationClass(token);
        new_histogram[class] = std.math.add(u32, new_histogram[class], 1) catch
            return error.IntegerOverflow;
        new_count = std.math.add(u32, new_count, 1) catch
            return error.IntegerOverflow;

        if (new_count < observations_per_check or
            plain_position < min_block_len or
            horizon - plain_position < min_block_len)
        {
            continue;
        }

        // This is libdeflate's coarse 512-observation drift test, used only as
        // evidence. The caller still reparses and fully scores every proposal.
        if (old_count != 0 and distributionChanged(
            old_histogram,
            old_count,
            new_histogram,
            new_count,
            plain_position,
        )) {
            if (proposal_limit == 1) {
                // Match libdeflate's previous-stable-point behavior for the
                // minimal K=1 policy.
                proposals.appendValid(new_begin_plain, horizon, min_block_len);
                if (proposals.len == 0)
                    proposals.appendValid(plain_position, horizon, min_block_len);
                return proposals;
            }
            retainWidestInterval(
                &intervals,
                &interval_count,
                proposal_limit,
                .{
                    .begin_token = @intCast(new_begin_token),
                    .end_token = @intCast(token_index + 1),
                    .begin_plain = @intCast(new_begin_plain),
                    .end_plain = @intCast(plain_position),
                },
            );
            // Treat the changed batch as the old distribution of a virtual
            // next block, mirroring libdeflate's retained lookahead stats.
            replaceHistogram(&old_histogram, &old_count, &new_histogram, &new_count);
            new_begin_plain = plain_position;
            new_begin_token = token_index + 1;
            continue;
        }

        mergeHistogram(&old_histogram, &old_count, &new_histogram, &new_count) catch
            return error.IntegerOverflow;
        new_begin_plain = plain_position;
        new_begin_token = token_index + 1;
    }
    if (plain_position != horizon) return error.InvalidBlockPlan;
    return materializeIntervalMidpoints(
        tokens,
        intervals[0..interval_count],
        horizon,
        min_block_len,
    );
}

pub fn observationClass(token: lz77.Token) usize {
    return switch (token) {
        .literal => |literal| ((@as(usize, literal) >> 5) & 0x6) |
            (@as(usize, literal) & 1),
        .match => |match| @as(usize, 8) + @intFromBool(match.length >= 9),
    };
}

pub fn distributionChanged(
    old_histogram: Histogram,
    old_count: u32,
    new_histogram: Histogram,
    new_count: u32,
    block_length: usize,
) bool {
    std.debug.assert(old_count != 0 and new_count != 0);
    var total_delta: u64 = 0;
    for (old_histogram, new_histogram) |old, new| {
        const expected = @as(u64, old) * new_count;
        const actual = @as(u64, new) * old_count;
        total_delta = total_delta +| if (actual > expected)
            actual - expected
        else
            expected - actual;
    }

    const item_count = @as(u64, old_count) + new_count;
    var cutoff = (@as(u64, new_count) * 200 / observations_per_check) *
        old_count;
    if (block_length < 10_000 and item_count < 8192) {
        cutoff = cutoff +| (cutoff *| (8192 - item_count)) / 8192;
    }
    const length_bias = @as(u64, block_length / 4096) *| old_count;
    return total_delta +| length_bias >= cutoff;
}

fn mergeHistogram(
    old_histogram: *Histogram,
    old_count: *u32,
    new_histogram: *Histogram,
    new_count: *u32,
) !void {
    for (old_histogram, new_histogram) |*old, *new| {
        old.* = try std.math.add(u32, old.*, new.*);
        new.* = 0;
    }
    old_count.* = try std.math.add(u32, old_count.*, new_count.*);
    new_count.* = 0;
}

fn replaceHistogram(
    old_histogram: *Histogram,
    old_count: *u32,
    new_histogram: *Histogram,
    new_count: *u32,
) void {
    old_histogram.* = new_histogram.*;
    new_histogram.* = @splat(0);
    old_count.* = new_count.*;
    new_count.* = 0;
}

fn retainWidestInterval(
    intervals: *[max_proposals]DriftInterval,
    len: *usize,
    limit: usize,
    candidate: DriftInterval,
) void {
    // K>1 uses the widest changed plaintext regions. Their midpoints are only
    // approximate locations; the caller projects them onto its deterministic
    // cost-scoring lattice before doing exact horizon arbitration.
    var index: usize = 0;
    while (index < len.* and !intervalBefore(candidate, intervals[index])) : (index += 1) {}
    if (index >= limit) return;
    const new_len = @min(len.* + 1, limit);
    var move = new_len - 1;
    while (move > index) : (move -= 1) intervals[move] = intervals[move - 1];
    intervals[index] = candidate;
    len.* = new_len;
}

fn intervalBefore(a: DriftInterval, b: DriftInterval) bool {
    if (a.byteLength() != b.byteLength()) return a.byteLength() > b.byteLength();
    return a.begin_token < b.begin_token;
}

fn materializeIntervalMidpoints(
    tokens: []const lz77.Token,
    intervals: []const DriftInterval,
    horizon: usize,
    min_block_len: usize,
) !ProposalSet {
    var targets: [max_proposals]usize = @splat(0);
    for (intervals, 0..) |interval, index| {
        targets[index] = @as(usize, interval.begin_plain) +
            interval.byteLength() / 2;
    }
    std.mem.sort(usize, targets[0..intervals.len], {}, std.sort.asc(usize));

    var proposals: ProposalSet = .{};
    var target_index: usize = 0;
    var token_begin: usize = 0;
    for (tokens) |token| {
        const token_end = token_begin + switch (token) {
            .literal => 1,
            .match => |match| match.length,
        };
        while (target_index < intervals.len and targets[target_index] <= token_end) : (target_index += 1) {
            const target = targets[target_index];
            const boundary = if (target - token_begin < token_end - target)
                token_begin
            else
                token_end;
            proposals.appendValid(boundary, horizon, min_block_len);
        }
        token_begin = token_end;
    }
    return proposals;
}

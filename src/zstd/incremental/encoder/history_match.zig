const std = @import("std");
const core = @import("../../../core.zig");
const Count = core.StreamCount;
const history_mod = @import("history.zig");
const history_index = @import("history_index.zig");

pub const max_matches = 128;

pub const Match = struct {
    history_start: usize,
    block_start: usize,
    len: usize,

    pub fn offset(self: Match, history_len: usize) ?usize {
        if (self.history_start > history_len) return null;
        return std.math.add(usize, history_len - self.history_start, self.block_start) catch null;
    }
};

pub const Plan = struct {
    matches: [max_matches]Match = undefined,
    len: usize = 0,

    pub fn slice(self: *const Plan) []const Match {
        return self.matches[0..self.len];
    }
};

/// Build a greedy multi-sequence plan from the persistent rolling-history
/// index. At most four recent plus four sparse-long same-hash candidates and
/// 128 matches are examined per block, so work stays bounded at large windows.
pub fn findPlan(history: history_mod.View, block: []const u8) Plan {
    if (history.longEnabled()) return findPlanImpl(true, history, block);
    return findPlanImpl(false, history, block);
}

fn findPlanImpl(
    comptime include_long: bool,
    history: history_mod.View,
    block: []const u8,
) Plan {
    var plan: Plan = .{};
    // No indexed match can contain the required eight-byte anchor when the
    // retained history is shorter than one anchor. In particular, this avoids
    // walking every byte of the first frame block against an empty index.
    if (history.bytes.len < 8 or block.len < 8) return plan;
    var literal_start: usize = 0;
    while (plan.len < max_matches and literal_start + 8 <= block.len) {
        const found = findNext(include_long, history, block, literal_start) orelse break;
        plan.matches[plan.len] = found;
        plan.len += 1;
        literal_start = found.block_start + found.len;
    }
    return plan;
}

fn findNext(
    comptime include_long: bool,
    history: history_mod.View,
    block: []const u8,
    start: usize,
) ?Match {
    var block_start = start;
    while (block_start + 8 <= block.len) : (block_start += 1) {
        var best: ?Match = null;
        const prefix = block[block_start..][0..8];
        if (comptime include_long) {
            const candidates = history.candidateSets(prefix);
            considerCandidates(history, block, block_start, prefix, candidates.recent, &best);
            if (candidates.long.len != 0)
                considerCandidates(history, block, block_start, prefix, candidates.long, &best);
        } else {
            considerCandidates(
                history,
                block,
                block_start,
                prefix,
                history.recentCandidates(prefix),
                &best,
            );
        }
        if (best) |match| return match;
    }
    return null;
}

inline fn considerCandidates(
    history: history_mod.View,
    block: []const u8,
    block_start: usize,
    prefix: *const [8]u8,
    candidates: []const Count,
    best: *?Match,
) void {
    for (candidates) |absolute_candidate| {
        if (absolute_candidate == history_index.invalid_position or
            absolute_candidate < history.absolute_start) continue;
        const candidate_offset = absolute_candidate - history.absolute_start;
        // Reject logical positions outside the physical retained window before
        // narrowing them to an index, including future and very old entries.
        if (candidate_offset > core.stream_count.fromLocal(history.bytes.len - 8)) continue;
        const history_start: usize = @intCast(candidate_offset);
        if (!std.mem.eql(u8, history.bytes[history_start..][0..8], prefix)) continue;

        var len: usize = 8;
        while (history_start + len < history.bytes.len and
            block_start + len < block.len and
            history.bytes[history_start + len] == block[block_start + len]) : (len += 1)
        {}
        if (best.* == null or len > best.*.?.len) {
            best.* = .{
                .history_start = history_start,
                .block_start = block_start,
                .len = len,
            };
        }
    }
}

test "Zstd incremental history matcher finds multiple non-prefix matches" {
    var rolling: history_mod.Rolling = .{};
    defer rolling.deinit(std.testing.allocator);
    const history = "alpha-0123456789-omega-ABCDEFGHIJK-tail";
    try rolling.prepareCompletedBlock(std.testing.allocator, history, 1024);
    rolling.appendCompletedBlock(history, 1024);

    const plan = findPlan(rolling.view(), "pfx-0123456789-mid-ABCDEFGHIJK-end");
    try std.testing.expectEqual(@as(usize, 2), plan.len);
    // The leading '-' extends both history matches by one byte. Assert the
    // actual maximal regions rather than only the alphanumeric cores.
    try std.testing.expectEqual(@as(usize, 3), plan.matches[0].block_start);
    try std.testing.expectEqual(@as(usize, 12), plan.matches[0].len);
    try std.testing.expectEqual(@as(usize, 18), plan.matches[1].block_start);
}

test "Zstd incremental history matcher skips an empty history" {
    var rolling: history_mod.Rolling = .{};
    defer rolling.deinit(std.testing.allocator);
    const plan = findPlan(rolling.view(), "a block long enough to scan");
    try std.testing.expectEqual(@as(usize, 0), plan.len);
}

test "Zstd incremental encoder counters bound wide history candidates before indexing" {
    var rolling: history_mod.Rolling = .{};
    defer rolling.deinit(std.testing.allocator);
    const boundary: Count = @as(Count, 1) << 32;
    rolling.absolute_start = boundary - 3;
    rolling.absolute_end = boundary - 3;
    try rolling.prepareCompletedBlock(std.testing.allocator, "abcdefgh", 16);
    rolling.appendCompletedBlock("abcdefgh", 16);
    // Same-hash future entries can differ by more than a local 32-bit index.
    // The matcher must skip them before casting or reading the byte window.
    rolling.index.insertBlock("abcdefgh", boundary * 2);
    rolling.index.insertBlock("abcdefgh", std.math.maxInt(Count) - 8);
    rolling.index.insertBlock("abcdefgh", boundary - 4);
    const plan = findPlan(rolling.view(), "abcdefgh");
    try std.testing.expectEqual(@as(usize, 1), plan.len);
    try std.testing.expectEqual(@as(usize, 0), plan.matches[0].history_start);
    try std.testing.expectEqual(@as(usize, 8), plan.matches[0].len);
    try std.testing.expectEqual(@as(?usize, 8), plan.matches[0].offset(rolling.bytes.items.len));
}

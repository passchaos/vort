const std = @import("std");
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
/// index. At most four same-hash candidates and 128 matches are examined per
/// block, so planner work stays bounded even with the full advertised window.
pub fn findPlan(history: history_mod.View, block: []const u8) Plan {
    var plan: Plan = .{};
    var literal_start: usize = 0;
    while (plan.len < max_matches and literal_start + 8 <= block.len) {
        const found = findNext(history, block, literal_start) orelse break;
        plan.matches[plan.len] = found;
        plan.len += 1;
        literal_start = found.block_start + found.len;
    }
    return plan;
}

fn findNext(history: history_mod.View, block: []const u8, start: usize) ?Match {
    var block_start = start;
    while (block_start + 8 <= block.len) : (block_start += 1) {
        var best: ?Match = null;
        for (history.candidates(block[block_start..][0..8])) |absolute_candidate| {
            if (absolute_candidate == history_index.invalid_position or
                absolute_candidate < history.absolute_start) continue;
            const history_start = absolute_candidate - history.absolute_start;
            if (history_start + 8 > history.bytes.len or
                !std.mem.eql(u8, history.bytes[history_start..][0..8], block[block_start..][0..8])) continue;

            var len: usize = 8;
            while (history_start + len < history.bytes.len and
                block_start + len < block.len and
                history.bytes[history_start + len] == block[block_start + len]) : (len += 1)
            {}
            if (best == null or len > best.?.len) {
                best = .{ .history_start = history_start, .block_start = block_start, .len = len };
            }
        }
        if (best) |match| return match;
    }
    return null;
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

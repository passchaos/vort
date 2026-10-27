const std = @import("std");
const Index = @import("prefix_index.zig").Index;

pub fn find(comptime Candidate: type, index: *const Index, input: []const u8, pos: usize, options: anytype, minimum: usize, maximum: usize, comptime extend: anytype) Candidate {
    std.debug.assert(index.position == pos and pos <= input.len and minimum >= 3);
    if (input.len - pos < minimum or options.max_chain == 0) return .{};
    const max_len = @min(maximum, input.len - pos);
    const needle = input[pos];
    const prefix = std.mem.readInt(u16, input[pos + 1 ..][0..2], .little);
    var candidates = index.candidates(input, pos, options.window_len);
    var best = Candidate{};
    while (candidates.next()) |candidate| {
        // Hash collisions with other first bytes never spend the scan budget.
        if (input[candidate] != needle) continue;
        // Ordinals include all skipped first-byte anchors whose prefixes fail.
        // Since chains run newest first, crossing the budget terminates search.
        if (index.consumed(needle, candidate) > options.max_chain) break;
        if (std.mem.readInt(u16, input[candidate + 1 ..][0..2], .little) != prefix) continue;
        const length = extend(input, candidate, pos, max_len);
        if (length >= minimum and length > best.length) {
            best = .{ .length = length, .distance = pos - candidate };
            if (length >= options.nice_len) break;
        }
    }
    return best;
}

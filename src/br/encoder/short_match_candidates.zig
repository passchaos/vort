const std = @import("std");
const command_plan = @import("command_plan.zig");

pub const CandidateSet = struct {
    masks: [16]u16 = undefined,
    len: usize = 0,

    pub fn slice(set: *const CandidateSet) []const u16 {
        return set.masks[0..set.len];
    }

    fn append(set: *CandidateSet, mask: u16) void {
        if (std.mem.indexOfScalar(u16, set.slice(), mask) != null) return;
        set.masks[set.len] = mask;
        set.len += 1;
    }
};

/// Build the bounded exact alternatives used by balanced Brotli planning. A
/// bit in a candidate mask identifies the original command to literalize.
/// A dense leading prefix is the preferred single candidate because its shared
/// alphabet overhead dominates isolated-copy decisions. Other plans retain the
/// exhaustive three-byte subset coverage (at most 15 candidates). Keeping the
/// strategies mutually exclusive avoids paying for weaker subsets after the
/// wider prefix already gives the encoder a better structural alternative.
pub fn collect(commands: []const command_plan.Command) CandidateSet {
    var result = CandidateSet{};
    if (commands.len > 16) return result;

    var prefix_len: usize = 0;
    var prefix_has_wider_copy = false;
    while (prefix_len < @min(commands.len, 4)) : (prefix_len += 1) {
        const command = commands[prefix_len];
        if (!command.has_copy or command.dictionary_output_len != 0 or command.copy_len > 5) break;
        prefix_has_wider_copy = prefix_has_wider_copy or command.copy_len > 3;
    }
    if (prefix_len >= 3 and prefix_has_wider_copy) {
        result.append((@as(u16, 1) << @intCast(prefix_len)) - 1);
        return result;
    }

    var three_byte_matches: [4]usize = undefined;
    var three_byte_count: usize = 0;
    for (commands, 0..) |command, index| {
        if (!command.has_copy or command.dictionary_output_len != 0 or command.copy_len != 3) continue;
        if (three_byte_count == three_byte_matches.len) return .{};
        three_byte_matches[three_byte_count] = index;
        three_byte_count += 1;
    }
    if (three_byte_count >= 2) {
        const subset_count = (@as(usize, 1) << @intCast(three_byte_count)) - 1;
        for (1..subset_count + 1) |subset| {
            var mask: u16 = 0;
            for (three_byte_matches[0..three_byte_count], 0..) |command_index, bit| {
                if (subset & (@as(usize, 1) << @intCast(bit)) != 0) mask |= @as(u16, 1) << @intCast(command_index);
            }
            result.append(mask);
        }
    }
    return result;
}

test "collects short-match subsets and one wider tiny prefix" {
    const commands = [_]command_plan.Command{
        .{ .insert_start = 0, .insert_len = 8, .copy_len = 3, .distance = 4, .has_copy = true },
        .{ .insert_start = 11, .insert_len = 2, .copy_len = 4, .distance = 8, .has_copy = true },
        .{ .insert_start = 17, .insert_len = 1, .copy_len = 3, .distance = 12, .has_copy = true },
        .{ .insert_start = 21, .insert_len = 3, .copy_len = 5, .distance = 16, .has_copy = true },
        .{ .insert_start = 29, .insert_len = 0, .copy_len = 32, .distance = 29, .has_copy = true },
    };
    const candidates = collect(&commands);
    try std.testing.expectEqualSlices(u16, &.{0b1111}, candidates.slice());
}

test "does not add a duplicate all-three-byte prefix" {
    const commands = [_]command_plan.Command{
        .{ .insert_start = 0, .insert_len = 8, .copy_len = 3, .distance = 4, .has_copy = true },
        .{ .insert_start = 11, .insert_len = 2, .copy_len = 3, .distance = 8, .has_copy = true },
        .{ .insert_start = 16, .insert_len = 1, .copy_len = 3, .distance = 12, .has_copy = true },
    };
    try std.testing.expectEqual(@as(usize, 7), collect(&commands).len);
}

test "rejects unbounded short-match plans" {
    var commands: [5]command_plan.Command = undefined;
    for (&commands, 0..) |*command, index| command.* = .{
        .insert_start = index * 3,
        .insert_len = 0,
        .copy_len = 3,
        .distance = 1,
        .has_copy = true,
    };
    try std.testing.expectEqual(@as(usize, 0), collect(&commands).len);
}

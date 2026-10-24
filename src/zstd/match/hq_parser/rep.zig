const std = @import("std");

pub const Repeats = [3]usize;
pub const initial_repeats: Repeats = .{ 1, 4, 8 };
pub const Error = error{InvalidBlockPlan};
pub const Choice = struct { offset_value: u32, distance: usize, repeats: Repeats };
pub const Choices = struct {
    items: [4]Choice = undefined,
    len: usize = 0,
    pub fn slice(self: *const Choices) []const Choice {
        return self.items[0..self.len];
    }
};

/// Offset values 1..3 are repeat selectors. With no literals they select
/// rep1, rep2 and rep0-1 instead of rep0, rep1 and rep2 respectively.
pub fn resolve(literal_len: usize, offset_value: u32, repeats: Repeats) Error!Choice {
    if (offset_value == 0 or repeats[0] == 0 or repeats[1] == 0 or repeats[2] == 0)
        return error.InvalidBlockPlan;
    if (offset_value > 3) {
        const distance: usize = offset_value - 3;
        return .{ .offset_value = offset_value, .distance = distance, .repeats = .{ distance, repeats[0], repeats[1] } };
    }
    const selector: usize = offset_value - 1 + @intFromBool(literal_len == 0);
    if (selector == 0) return .{ .offset_value = offset_value, .distance = repeats[0], .repeats = repeats };
    if (selector == 1) return .{ .offset_value = offset_value, .distance = repeats[1], .repeats = .{ repeats[1], repeats[0], repeats[2] } };
    if (selector == 2) return .{ .offset_value = offset_value, .distance = repeats[2], .repeats = .{ repeats[2], repeats[0], repeats[1] } };
    if (repeats[0] <= 1) return error.InvalidBlockPlan;
    const distance = repeats[0] - 1;
    return .{ .offset_value = offset_value, .distance = distance, .repeats = .{ distance, repeats[0], repeats[1] } };
}

/// Preserve all legal selectors, including duplicate repeat distances and a
/// direct offset. Their symbol costs and resulting repeat histories can differ.
pub fn choices(literal_len: usize, distance: usize, repeats: Repeats) Error!Choices {
    if (distance == 0 or distance > std.math.maxInt(u32) - 3) return error.InvalidBlockPlan;
    var result: Choices = .{};
    for ([_]u32{ 1, 2, 3 }) |value| {
        const choice = resolve(literal_len, value, repeats) catch continue;
        if (choice.distance != distance) continue;
        result.items[result.len] = choice;
        result.len += 1;
    }
    result.items[result.len] = try resolve(literal_len, @intCast(distance + 3), repeats);
    result.len += 1;
    return result;
}

pub fn distances(literal_len: usize, repeats: Repeats) Repeats {
    return if (literal_len != 0) repeats else .{ repeats[1], repeats[2], repeats[0] -| 1 };
}

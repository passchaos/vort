const std = @import("std");
const state = @import("../state.zig");
const Old = @import("../row_tags_cost_reference.zig");

fn check(comptime Codec: type, row: anytype, candidate: @TypeOf(row[0])) !void {
    var expected = row.*;
    var tags = Codec.init(row);
    const before = tags;
    var expected_tags = Old.init(&expected);
    const want = Old.insert(&expected, &expected_tags, candidate);
    const got = Codec.insert(row, &tags, candidate);
    try std.testing.expectEqual(want, got);
    try std.testing.expectEqualDeep(expected, row.*);
    try std.testing.expectEqualDeep(expected_tags, tags);
    if (!got) try std.testing.expectEqualDeep(before, tags);
}

fn collision(comptime Node: type, base: Node, word: ?usize) Node {
    var candidate = base;
    var delta: usize = 1;
    while (true) : (delta += 1) {
        if (word) |index| {
            candidate.repeats[index] = base.repeats[index] +% delta;
        } else candidate.literal_len = base.literal_len +% @as(u32, @truncate(delta));
        if (Old.key(base) == Old.key(candidate)) return candidate;
    }
}

pub fn contracts(comptime Codec: type) !void {
    const costs = [_]u64{ 0, 1, @as(u64, 1) << 63, std.math.maxInt(u64) - 1, std.math.maxInt(u64) };
    inline for (.{ state.Node, state.WholeNode }) |Node| {
        inline for (.{ 1, 8, 16 }) |width| {
            for (costs) |cost| {
                const base: Node = .{ .cost = cost, .literal_len = 17, .repeats = .{ 1, 4, 8 }, .match_len = 9, .offset_value = 7, .distance = 9, .previous_position = 3, .previous_slot = 5 };
                // Both acceptance gates: exact duplicate at the first slot,
                // and distinct colliding key against the final replacement.
                for ([_]bool{ false, true }) |distinct| {
                    const key_node = if (distinct) collision(Node, base, null) else base;
                    for ([_]u64{ cost -| 1, cost, cost +| 1 }) |candidate_cost| {
                        var row: [width]Node = @splat(.{});
                        row[if (distinct) width - 1 else 0] = base;
                        var candidate = key_node;
                        candidate.cost = candidate_cost;
                        try check(Codec, &row, candidate);
                    }
                    inline for (.{ "match_len", "offset_value", "distance", "previous_position", "previous_slot" }) |field| {
                        const T = @TypeOf(@field(base, field));
                        for ([_]T{ 0, @field(base, field), std.math.maxInt(T) }) |value| {
                            var row: [width]Node = @splat(.{});
                            row[if (distinct) width - 1 else 0] = base;
                            var candidate = key_node;
                            @field(candidate, field) = value;
                            try check(Codec, &row, candidate);
                        }
                    }
                }
                // Each scalar repeat word can change while its tag collides.
                for (0..3) |word| {
                    var row: [width]Node = @splat(.{});
                    row[width - 1] = base;
                    try check(Codec, &row, collision(Node, base, word));
                }
            }
            for (0..width) |slot| {
                var row: [width]Node = undefined;
                for (&row, 0..) |*node, index| node.* = .{ .cost = 100 - index, .literal_len = 1, .repeats = .{ 4, 4, 8 }, .previous_slot = @intCast(index) };
                var expected = row;
                var tags = Codec.init(&row);
                var expected_tags = Old.init(&expected);
                const want = Old.insert(&expected, &expected_tags, expected[slot]);
                const got = Codec.insert(&row, &tags, row[slot]);
                try std.testing.expectEqual(want, got);
                try std.testing.expectEqualDeep(expected, row);
                try std.testing.expectEqualDeep(expected_tags, tags);
            }
        }
    }
}

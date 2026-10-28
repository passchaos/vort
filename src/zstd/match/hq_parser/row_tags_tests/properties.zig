const std = @import("std");
const state = @import("../state.zig");
const frozen = @import("../state_tests.zig").referenceInsert;

pub fn synchronize(comptime Codec: type, row: anytype, tags: Codec.Tags) !void {
    for (row, 0..) |node, slot|
        try std.testing.expectEqual(Codec.key(node), tags[slot]);
}
pub fn step(comptime Codec: type, actual: anytype, expected: @TypeOf(actual), tags: *Codec.Tags, candidate: @TypeOf(actual[0])) !bool {
    try synchronize(Codec, actual, tags.*);
    const before = tags.*;
    const want = frozen(state, expected, candidate);
    const got = Codec.insert(actual, tags, candidate);
    try std.testing.expectEqual(want, got);
    try std.testing.expectEqualDeep(expected.*, actual.*);
    try synchronize(Codec, actual, tags.*);
    if (!got) try std.testing.expectEqualDeep(before, tags.*);
    return got;
}

pub fn contracts(comptime Codec: type) !void {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Codec.Tags));
    inline for (.{ state.Node, state.WholeNode }) |Node| {
        inline for (.{ 1, 8, 16 }) |width| {
            var row: [width]Node = @splat(.{});
            var tags = Codec.init(&row);
            try synchronize(Codec, &row, tags);
            try std.testing.expectEqual(Codec.key(@as(Node, .{})), tags[0]);
            // Find two different exact keys for each of all 256 tags. This
            // includes zero and the default sentinel tag; no tag is reserved.
            for (0..256) |tag| {
                var collisions: [width + 1]Node = undefined;
                var found: usize = 0;
                var value: u32 = 0;
                while (found < collisions.len) : (value += 1) {
                    const node: Node = .{ .cost = 100, .literal_len = value, .repeats = .{ 1, 4, 8 } };
                    if (Codec.key(node) != tag) continue;
                    collisions[found] = node;
                    found += 1;
                }
                for (&row, 0..) |*node, slot| {
                    node.* = collisions[slot];
                    node.cost = if (slot % 3 == 0) std.math.maxInt(u64) else 200 - slot;
                    node.previous_slot = @intCast(slot);
                }
                tags = Codec.init(&row);
                var expected = row;
                // A hash collision must still reject or accept by the exact
                // repeat/literal key and original last-slot/less rules.
                _ = try step(Codec, &row, &expected, &tags, collisions[width]);
                for (0..width) |slot| {
                    const want = frozen(state, &expected, expected[slot]);
                    const got = Codec.insert(&row, &tags, row[slot]);
                    try std.testing.expectEqual(want, got);
                    try std.testing.expectEqualDeep(expected, row);
                    try synchronize(Codec, &row, tags);
                }
            }
            // Repeated exact keys in an arbitrary row retain first-match
            // order even if a later matching slot has a lower cost.
            for (&row, 0..) |*node, slot| node.* = .{ .cost = 100 - slot, .literal_len = 1, .repeats = .{ 4, 4, 8 }, .previous_slot = @intCast(slot) };
            tags = Codec.init(&row);
            var expected = row;
            var candidate = row[0];
            candidate.cost = 99;
            _ = try step(Codec, &row, &expected, &tags, candidate);
            candidate = row[0];
            candidate.cost += 1;
            try std.testing.expect(!try step(Codec, &row, &expected, &tags, candidate));
            // High key bits and every non-key tiebreak retain full exact-node
            // behavior, including a sentinel that wins a non-cost tie.
            inline for (.{ "cost", "literal_len", "match_len", "offset_value", "distance", "previous_position", "previous_slot" }) |field| {
                row = @splat(.{});
                row[0] = .{ .cost = 100, .literal_len = 17, .repeats = .{ 1, 4, 8 }, .match_len = 9, .offset_value = 7, .distance = 9, .previous_position = 3, .previous_slot = 5 };
                candidate = row[0];
                @field(candidate, field) = std.math.maxInt(@TypeOf(@field(candidate, field)));
                tags = Codec.init(&row);
                expected = row;
                _ = try step(Codec, &row, &expected, &tags, candidate);
            }
            for (0..3) |word| {
                row = @splat(.{});
                row[0] = .{ .cost = 100 };
                candidate = row[0];
                candidate.repeats[word] ^= @as(usize, 1) << (@bitSizeOf(usize) - 1);
                tags = Codec.init(&row);
                expected = row;
                _ = try step(Codec, &row, &expected, &tags, candidate);
            }
        }
    }
}

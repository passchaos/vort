const std = @import("std");
const referenceInsert = @import("state_tests.zig").referenceInsert;

fn node(comptime Node: type, index: usize) Node {
    return .{
        .cost = 10 + index % 5,
        .literal_len = @intCast(index % 3),
        .repeats = .{ index % 4, index % 5, index % 7 },
        .match_len = @intCast(100 - index),
        .offset_value = @intCast(index + 4),
        .distance = index + 1,
        .previous_position = @intCast(index * 17),
        .previous_slot = @intCast((index * 13) % 256),
    };
}

fn check(comptime Codec: type, input: anytype, candidate: @TypeOf(input[0])) !void {
    var actual = input;
    var expected = input;
    const want = referenceInsert(Codec, &expected, candidate);
    const got = Codec.insert(&actual, candidate);
    try std.testing.expectEqual(want, got);
    try std.testing.expectEqualDeep(expected, actual);
}

fn aliases(comptime Codec: type, input: anytype) !void {
    for (0..input.len) |slot| {
        var actual = input;
        var expected = input;
        // Exercise the actual row-element argument, including a later cheap
        // duplicate that replaces an earlier one and arbitrary sentinels.
        const want = referenceInsert(Codec, &expected, expected[slot]);
        const got = Codec.insert(&actual, actual[slot]);
        try std.testing.expectEqual(want, got);
        try std.testing.expectEqualDeep(expected, actual);
    }
}

fn rows(comptime Codec: type, comptime Node: type, comptime width: usize) !void {
    for (0..32) |phase| {
        var unsorted: [width]Node = undefined;
        for (&unsorted, 0..) |*entry, index| {
            entry.* = node(Node, (phase + index * 7) % 32);
            if ((index + phase) % 4 == 0) entry.cost = std.math.maxInt(u64);
        }
        // Whole fields and acceptance must agree even without a sorted-row
        // precondition. Sentinel fields deliberately differ from defaults.
        for (0..width) |index| {
            var candidate = unsorted[index];
            candidate.cost = 0;
            try check(Codec, unsorted, candidate);
            candidate.cost = std.math.maxInt(u64);
            candidate.literal_len = 0;
            candidate.repeats = .{ 0, 0, 0 };
            try check(Codec, unsorted, candidate);
        }
        try aliases(Codec, unsorted);
    }
    var duplicate: [width]Node = undefined;
    for (&duplicate, 0..) |*entry, index| {
        entry.* = node(Node, index);
        entry.cost = 100 - index;
        entry.literal_len = 0;
        entry.repeats = .{ 1, 4, 8 };
    }
    try aliases(Codec, duplicate);
    for (&duplicate, 0..) |*entry, index| {
        entry.cost = std.math.maxInt(u64);
        entry.literal_len = @intCast(width - index);
    }
    try aliases(Codec, duplicate);
}

fn fullMovement(comptime Codec: type, comptime Node: type, comptime width: usize) !void {
    var original: [width]Node = undefined;
    for (&original, 0..) |*entry, index| {
        entry.* = node(Node, index);
        entry.cost = 100 + index;
        entry.literal_len = @intCast(index + 1);
    }
    var candidate = node(Node, 31);
    candidate.cost = 0;
    candidate.literal_len = 0;
    var actual = original;
    try std.testing.expect(Codec.insert(&actual, candidate));
    try std.testing.expectEqualDeep(candidate, actual[0]);
    for (1..width) |slot| try std.testing.expectEqualDeep(original[slot - 1], actual[slot]);
    try check(Codec, original, candidate);
    for (0..width) |slot| {
        candidate = original[slot];
        candidate.cost = 1;
        try check(Codec, original, candidate);
    }
}

pub fn contracts(comptime Codec: type) !void {
    inline for (.{ Codec.Node, Codec.WholeNode }) |Node| {
        inline for (.{ 1, 8, 16 }) |width| {
            try rows(Codec, Node, width);
            try fullMovement(Codec, Node, width);
        }
    }
}

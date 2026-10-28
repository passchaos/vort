const std = @import("std");

// Frozen b04a9019 insert: keep the slice equality and the original replacement,
// rejection, and sorting rules independent of the production key comparison.
pub fn referenceInsert(comptime Codec: type, row: anytype, candidate: @TypeOf(row[0])) bool {
    var replace = row.len - 1;
    for (row, 0..) |old, slot| {
        if (old.cost != std.math.maxInt(u64) and old.literal_len == candidate.literal_len and std.mem.eql(usize, &old.repeats, &candidate.repeats)) {
            if (!Codec.less(candidate, old)) return false;
            replace = slot;
            break;
        }
    }
    if (!Codec.less(candidate, row[replace])) return false;
    row[replace] = candidate;
    while (replace > 0 and Codec.less(row[replace], row[replace - 1])) : (replace -= 1)
        std.mem.swap(@TypeOf(candidate), &row[replace], &row[replace - 1]);
    return true;
}

fn step(comptime Codec: type, actual: anytype, expected: @TypeOf(actual), candidate: @TypeOf(actual[0])) !bool {
    const want = referenceInsert(Codec, expected, candidate);
    const got = Codec.insert(actual, candidate);
    try std.testing.expectEqual(want, got);
    // Compare every field rather than padding bytes in the two node layouts.
    try std.testing.expectEqualDeep(expected.*, actual.*);
    for (1..actual.len) |slot|
        try std.testing.expect(!Codec.less(actual[slot], actual[slot - 1]));
    return got;
}

fn baseNode(comptime Node: type) Node {
    return .{
        .cost = 100,
        .literal_len = 17,
        .repeats = .{ 17, 29, 53 },
        .match_len = 100,
        .offset_value = 100,
        .distance = 100,
        .previous_position = 100,
        .previous_slot = 100,
    };
}

fn pair(comptime Codec: type, comptime Node: type, comptime width: usize, old: Node, candidate: Node, accepted: bool) !void {
    var actual: [width]Node = @splat(.{});
    var expected = actual;
    try std.testing.expect(try step(Codec, &actual, &expected, old));
    try std.testing.expectEqual(accepted, try step(Codec, &actual, &expected, candidate));
}

fn differentKeys(comptime Codec: type, comptime Node: type, comptime width: usize) !void {
    const base = baseNode(Node);
    const high: usize = @as(usize, 1) << (@bitSizeOf(usize) - 1);
    const points = [_]usize{ 0, 1, high - 1, high, high + 1, std.math.maxInt(u32), std.math.maxInt(usize) };
    for (0..3) |word| {
        for (points) |point| {
            var candidate = base;
            candidate.repeats[word] = point;
            candidate.cost += 1;
            // A distinct, more expensive key still fills a vacant slot. A
            // comparison that skips any of the three words would reject it.
            try pair(Codec, Node, width, base, candidate, width > 1);
            candidate.cost = base.cost - 1;
            try pair(Codec, Node, width, base, candidate, true);
        }
        var candidate = base;
        candidate.repeats[word] ^= high;
        candidate.cost += 1;
        try pair(Codec, Node, width, base, candidate, width > 1);
        if (@bitSizeOf(usize) > 32) {
            candidate = base;
            candidate.repeats[word] ^= @as(usize, 1) << 32;
            candidate.cost += 1;
            try pair(Codec, Node, width, base, candidate, width > 1);
        }
    }
    for ([_]u32{ 0, 1, std.math.maxInt(u32) - 1, std.math.maxInt(u32) }) |literal_len| {
        var candidate = base;
        candidate.literal_len = literal_len;
        candidate.cost += 1;
        try pair(Codec, Node, width, base, candidate, width > 1);
        candidate.cost = base.cost - 1;
        try pair(Codec, Node, width, base, candidate, true);
    }
}

fn duplicateTies(comptime Codec: type, comptime Node: type, comptime width: usize) !void {
    const base = baseNode(Node);
    try pair(Codec, Node, width, base, base, false);
    inline for (.{ "cost", "match_len", "offset_value", "distance", "previous_position", "previous_slot" }) |field| {
        const Field = @TypeOf(@field(base, field));
        var better = base;
        var worse = base;
        @field(better, field) = if (comptime std.mem.eql(u8, field, "match_len")) std.math.maxInt(Field) else 0;
        @field(worse, field) = if (comptime std.mem.eql(u8, field, "match_len")) 0 else std.math.maxInt(Field);
        try pair(Codec, Node, width, base, worse, false);
        try pair(Codec, Node, width, base, better, true);
        try pair(Codec, Node, width, better, base, false);
    }
}

fn costsAndSentinels(comptime Codec: type, comptime Node: type, comptime width: usize) !void {
    const maximum = std.math.maxInt(u64);
    for ([_]u64{ 0, 1, (@as(u64, 1) << 63) - 1, @as(u64, 1) << 63, maximum - 1 }) |cost| {
        var finite = baseNode(Node);
        finite.cost = cost;
        var actual: [width]Node = @splat(.{});
        var expected = actual;
        try std.testing.expect(try step(Codec, &actual, &expected, finite));
        var candidate = finite;
        candidate.cost = maximum;
        try std.testing.expect(!try step(Codec, &actual, &expected, candidate));
        candidate.cost = cost + 1;
        try std.testing.expect(!try step(Codec, &actual, &expected, candidate));
        if (cost > 0) {
            candidate.cost = cost - 1;
            try std.testing.expect(try step(Codec, &actual, &expected, candidate));
        }
    }

    var actual: [width]Node = @splat(.{});
    var expected = actual;
    try std.testing.expect(!try step(Codec, &actual, &expected, .{}));
    const sentinel: Node = .{ .repeats = .{ 0, 4, 8 } };
    // Sentinel costs are excluded from the duplicate scan, even if their keys
    // are identical. Their other fields still participate in row ordering.
    try std.testing.expect(try step(Codec, &actual, &expected, sentinel));
    try std.testing.expectEqual(width > 1, try step(Codec, &actual, &expected, sentinel));
    var finite = sentinel;
    finite.cost = maximum - 1;
    try std.testing.expect(try step(Codec, &actual, &expected, finite));
    finite.cost -= 1;
    try std.testing.expect(try step(Codec, &actual, &expected, finite));
    try std.testing.expect(!try step(Codec, &actual, &expected, sentinel));
}

fn fullRowOrdering(comptime Codec: type, comptime Node: type, comptime width: usize) !void {
    var actual: [width]Node = @splat(.{});
    var expected = actual;
    for (0..width) |index| {
        var candidate = baseNode(Node);
        candidate.cost = 100 + width - index;
        candidate.literal_len = @intCast(index);
        try std.testing.expect(try step(Codec, &actual, &expected, candidate));
        try std.testing.expectEqualDeep(candidate, actual[0]);
    }
    const worst = actual[width - 1];
    var improved = worst;
    improved.cost = 1;
    try std.testing.expect(try step(Codec, &actual, &expected, improved));
    try std.testing.expectEqualDeep(improved, actual[0]);
    try std.testing.expect(!try step(Codec, &actual, &expected, worst));
    var distinct = baseNode(Node);
    distinct.literal_len = std.math.maxInt(u32);
    distinct.cost = 0;
    try std.testing.expect(try step(Codec, &actual, &expected, distinct));
    try std.testing.expectEqualDeep(distinct, actual[0]);
    distinct.cost = 1000;
    distinct.literal_len -= 1;
    try std.testing.expect(!try step(Codec, &actual, &expected, distinct));
}

const Random = struct {
    state: u64,

    fn next(self: *Random) u64 {
        self.state ^= self.state >> 12;
        self.state ^= self.state << 25;
        self.state ^= self.state >> 27;
        return self.state *% 0x2545f4914f6cdd1d;
    }

    fn integer(self: *Random, comptime T: type) T {
        const maximum = std.math.maxInt(T);
        const high: T = @as(T, 1) << (@bitSizeOf(T) - 1);
        return switch (self.next() % 8) {
            0 => 0,
            1 => 1,
            2 => maximum,
            3 => maximum - 1,
            4 => high,
            5 => high - 1,
            6 => @truncate(self.next()),
            else => @intCast(self.next() % 64),
        };
    }

    fn node(self: *Random, comptime Node: type) Node {
        return .{
            .cost = self.integer(u64),
            .literal_len = self.integer(u32),
            .repeats = .{ self.integer(usize), self.integer(usize), self.integer(usize) },
            .match_len = self.integer(u32),
            .offset_value = self.integer(u32),
            .distance = self.integer(usize),
            .previous_position = self.integer(@TypeOf(@as(Node, .{}).previous_position)),
            .previous_slot = self.integer(u8),
        };
    }
};

fn randomized(comptime Codec: type, comptime Node: type, comptime width: usize) !void {
    var random: Random = .{ .state = @as(u64, 0x872aab1823c79e41) + width };
    // Reset regularly so the random stream exercises vacancy, replacement,
    // rejection, and sentinel handling instead of only a saturated cheap row.
    for (0..16) |_| {
        var actual: [width]Node = @splat(.{});
        var expected = actual;
        for (0..128) |iteration| {
            var candidate = random.node(Node);
            switch (iteration % 4) {
                0 => {},
                1 => {
                    candidate = actual[@intCast(random.next() % width)];
                    switch (random.next() % 8) {
                        0 => {},
                        1 => candidate.cost -|= 1,
                        2 => candidate.cost +|= 1,
                        3 => candidate.match_len = random.integer(u32),
                        4 => candidate.offset_value = random.integer(u32),
                        5 => candidate.distance = random.integer(usize),
                        6 => candidate.previous_position = random.integer(@TypeOf(candidate.previous_position)),
                        else => candidate.previous_slot = random.integer(u8),
                    }
                },
                2 => {
                    candidate.literal_len = @intCast(random.next() % 4);
                    candidate.repeats = .{ @intCast(random.next() % 4), @intCast(random.next() % 4), @intCast(random.next() % 4) };
                    if (random.next() % 4 != 0) candidate.cost = random.next() % 128;
                },
                else => {
                    const cost = candidate.cost;
                    candidate = actual[@intCast(random.next() % width)];
                    candidate.cost = cost;
                    if (random.next() % 4 == 0) {
                        candidate.literal_len ^= @as(u32, 1) << 31;
                    } else {
                        candidate.repeats[@intCast(random.next() % 3)] ^= @as(usize, 1) << (@bitSizeOf(usize) - 1);
                    }
                },
            }
            _ = try step(Codec, &actual, &expected, candidate);
        }
    }
}

pub fn contracts(comptime Codec: type) !void {
    inline for (.{ Codec.Node, Codec.WholeNode }) |Node| {
        inline for (.{ 1, 8, 16 }) |width| {
            try differentKeys(Codec, Node, width);
            try duplicateTies(Codec, Node, width);
            try costsAndSentinels(Codec, Node, width);
            try fullRowOrdering(Codec, Node, width);
            try randomized(Codec, Node, width);
        }
    }
}

const std = @import("std");

fn fill(input: []u8) void {
    var prng = std.Random.DefaultPrng.init(0xadab_1e11_6400_2026);
    const random = prng.random();
    const alphabets = [_]usize{ 2, 16, 64, 4 };
    const bases = [_]u8{ 0x10, 0x80, 0x30, 0xe0 };
    const records = input.len / 64;
    for (0..records) |record| {
        const block = input[record * 64 ..][0..64];
        const region = @min(@as(usize, 3), record * 4 / records);
        for (block[0..46]) |*byte| byte.* = bases[region] + random.uintLessThan(u8, @intCast(alphabets[region]));
        block[46] = @truncate(record);
        block[47] = @truncate(record >> 8);
        @memcpy(block[48..64], " repeated phrase");
    }
}

pub fn check(comptime Codec: type) !void {
    const allocator = std.testing.allocator;
    var borrowed_literals: usize = 0;
    var borrowed_distances: usize = 0;
    for ([_]usize{ 8192, 16384, 65536 }) |len| {
        const input = try allocator.alloc(u8, len);
        defer allocator.free(input);
        fill(input);
        const saved = try allocator.dupe(u8, input);
        defer allocator.free(saved);
        const old = try Codec.encode(allocator, input, true);
        defer allocator.free(old);
        const old_counts = Codec.counts();
        try std.testing.expectEqual(@as(usize, 0), old_counts.groups);
        const current = try Codec.encode(allocator, input, false);
        defer allocator.free(current);
        const counts = Codec.counts();
        try std.testing.expect(counts.groups > 0);
        try std.testing.expectEqualSlices(u8, old, current);
        try std.testing.expectEqualDeep(try Codec.summarize(allocator, old), try Codec.summarize(allocator, current));
        const decoded = try Codec.decode(allocator, current, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        try std.testing.expectEqualSlices(u8, saved, input);
        borrowed_literals += counts.literal_models;
        borrowed_distances += counts.distance_models;
        try std.testing.expectEqual(old_counts.captures, counts.captures + counts.literal_models);
        try std.testing.expectEqual(old_counts.distance_builds, counts.distance_builds + counts.distance_models);
        std.debug.print("command group public bytes={d} groups={d} captures={d}->{d} literal_borrows={d} distance_builds={d}->{d} distance_borrows={d}\n", .{
            len,                        counts.groups,          old_counts.captures,    counts.captures, counts.literal_models,
            old_counts.distance_builds, counts.distance_builds, counts.distance_models,
        });
    }
    try std.testing.expect(borrowed_literals > 0);
    // A legitimate public fixture may not discover a distance split. The
    // adaptive distance helper's independent oracle establishes its direct
    // borrowed route; this aggregate reports actual public coverage.
    std.debug.print("command group public literal_borrows={d} distance_borrows={d}\n", .{ borrowed_literals, borrowed_distances });
}

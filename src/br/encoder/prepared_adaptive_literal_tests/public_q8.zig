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

pub fn check(comptime Codec: type) !usize {
    const allocator = std.testing.allocator;
    var prepares: usize = 0;
    for ([_]usize{ 8192, 16384, 65536 }) |len| {
        const input = try allocator.alloc(u8, len);
        defer allocator.free(input);
        fill(input);
        const saved = try allocator.dupe(u8, input);
        defer allocator.free(saved);
        const old = try Codec.publicOriginalQ8(allocator, input);
        defer allocator.free(old);
        try std.testing.expectEqual(@as(usize, 0), Codec.preparedCountCalls());
        const current = try Codec.publicCurrentQ8(allocator, input);
        defer allocator.free(current);
        prepares += Codec.preparedCountCalls();
        std.debug.print("adaptive literal public input={d} actual_prepares={d}\n", .{ len, Codec.preparedCountCalls() });
        try std.testing.expectEqualSlices(u8, old, current);
        try std.testing.expectEqualDeep(try Codec.summarize(allocator, old), try Codec.summarize(allocator, current));
        const decoded = try Codec.decode(allocator, current, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        try std.testing.expectEqualSlices(u8, saved, input);
    }
    try std.testing.expect(prepares > 0);
    return prepares;
}

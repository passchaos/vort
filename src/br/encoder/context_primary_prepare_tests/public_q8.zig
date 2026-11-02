const std = @import("std");
const fixtures = @import("fixtures.zig");

fn compare(comptime Codec: type, input: []u8) !usize {
    const allocator = std.testing.allocator;
    const saved = try allocator.dupe(u8, input);
    defer allocator.free(saved);
    const original = try Codec.publicOriginalQ8(allocator, input);
    defer allocator.free(original);
    try std.testing.expectEqual(@as(usize, 0), Codec.primaryCountCalls());
    try std.testing.expectEqual(@as(usize, 0), Codec.primaryColdCountCalls());
    const current = try Codec.publicCurrentQ8(allocator, input);
    defer allocator.free(current);
    const attempted = Codec.primaryCountCalls();
    const successful = Codec.primaryColdCountCalls();
    std.debug.print("context primary public input={d} recent_max={d} count_attempted={d} count_successful={d}\n", .{ input.len, Codec.primaryRecentMax(), attempted, successful });
    try std.testing.expect(successful <= attempted);
    try std.testing.expectEqualSlices(u8, original, current);
    const old_summary = try Codec.summarize(allocator, original);
    const new_summary = try Codec.summarize(allocator, current);
    try std.testing.expectEqualDeep(old_summary, new_summary);
    const decoded = try Codec.decode(allocator, current, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expectEqualSlices(u8, saved, input);
    return successful;
}

fn fillMixed(input: []u8) void {
    var prng = std.Random.DefaultPrng.init(0x243f_6a88_7f00_2026);
    const random = prng.random();
    const phrase = " repeated common value: the quick brown fox jumps over the lazy dog";
    var position: usize = 0;
    var record: usize = 0;
    while (position < input.len) : (record += 1) {
        const prefix = @min(input.len - position, 4 + record % 19);
        random.bytes(input[position..][0..prefix]);
        position += prefix;
        const repeated = @min(input.len - position, 4 + (record * 7) % 60);
        @memcpy(input[position..][0..repeated], phrase[0..repeated]);
        position += repeated;
    }
}

fn fillConditional(input: []u8) void {
    var prng = std.Random.DefaultPrng.init(0xc01d_c0de_5600_2026);
    const random = prng.random();
    for (0..input.len / 32) |record| {
        const block = input[record * 32 ..][0..32];
        for (0..8) |pair| {
            const high = random.boolean();
            block[pair * 2] = if (high) 0xe0 else 0x10;
            block[pair * 2 + 1] = (if (high) @as(u8, 0x80) else @as(u8, 0x40)) + random.uintLessThan(u8, 16);
        }
        @memcpy(block[16..32], " repeated phrase");
    }
}

fn fillConditionalWithIds(input: []u8) void {
    var prng = std.Random.DefaultPrng.init(0xc01d_c0de_6400_2026);
    const random = prng.random();
    for (0..input.len / 32) |record| {
        const block = input[record * 32 ..][0..32];
        block[0] = @truncate(record);
        block[1] = @truncate(record >> 8);
        for (0..7) |pair| {
            const high = random.boolean();
            block[2 + pair * 2] = if (high) 0xe0 else 0x10;
            block[3 + pair * 2] = (if (high) @as(u8, 0x80) else @as(u8, 0x40)) + random.uintLessThan(u8, 16);
        }
        @memcpy(block[16..32], " repeated phrase");
    }
}

fn fillConditionalWithGuards(input: []u8) void {
    fillConditionalWithIds(input);
    for (0..input.len / 32) |record| {
        const block = input[record * 32 ..][0..32];
        // Keep the preceding byte stable while its predecessor is unique.
        // Copies can start at the stable high ID plus phrase, but cannot
        // extend backwards into a matching random control/value pair.
        block[14] = @truncate(record);
        block[15] = @truncate(record >> 8);
    }
}

pub fn check(comptime Codec: type) !usize {
    const allocator = std.testing.allocator;
    var successful: usize = 0;
    for ([_]usize{ 8192, 16384 }) |len| {
        const input = try allocator.alloc(u8, len);
        defer allocator.free(input);
        for (0..3) |kind| {
            fixtures.fillStructured(input, kind);
            successful += try compare(Codec, input);
        }
        fillMixed(input);
        successful += try compare(Codec, input);
    }
    const conditional = try allocator.alloc(u8, 16384);
    defer allocator.free(conditional);
    fillConditional(conditional);
    successful += try compare(Codec, conditional);
    fillConditionalWithIds(conditional);
    successful += try compare(Codec, conditional);
    fillConditionalWithGuards(conditional);
    successful += try compare(Codec, conditional);
    const larger = try allocator.alloc(u8, 32768);
    defer allocator.free(larger);
    fillConditionalWithGuards(larger);
    successful += try compare(Codec, larger);
    try std.testing.expect(successful != 0);
    return successful;
}

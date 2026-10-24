const std = @import("std");
const cache_mod = @import("single_cost_cache.zig");

fn VerifiedCodec(comptime Codec: type) type {
    return struct {
        pub const Error = Codec.CostCodec.Error;
        pub const literalHeaderLen = Codec.CostCodec.literalHeaderLen;
        pub const huffmanHeaderLen = Codec.CostCodec.huffmanHeaderLen;
        pub const planFromFrequencies = Codec.CostCodec.planFromFrequencies;
        pub const treeLen = Codec.CostCodec.treeLen;
        pub const rlePayloadLen = Codec.CostCodec.rlePayloadLen;
        pub const predefinedPayloadLen = Codec.CostCodec.predefinedPayloadLen;
        pub const referenceCost = Codec.referenceCost;
    };
}

fn fill(bytes: []u8, seed: u32, pattern: u2) void {
    var state = seed;
    for (bytes, 0..) |*byte, i| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = switch (pattern) {
            0 => @truncate(state >> 24),
            1 => @intCast((i * 17 + i / 257) % 97),
            2 => 0xff,
            3 => if (i % 16 < 12) 'a' else @intCast('b' + i % 7),
        };
    }
}

pub fn costs(comptime Codec: type) !void {
    const Cache = cache_mod.Cache(VerifiedCodec(Codec));
    try std.testing.expect(@sizeOf(Cache) <= 8 * 1024);
    var storage: [131072]u8 = undefined;
    for (0..4) |pattern| {
        fill(&storage, 0x243f6a88, @intCast(pattern));
        for ([_]usize{ 0, 1, 7, 8, 63, 64, 65, 1022, 1023, 1024, 1025, 4096, 65535, 65536, 65537, storage.len }) |length| {
            const block = storage[0..length];
            var cache = try Cache.init(block);
            const cuts = [_][2]usize{
                .{ 0, length },                  .{ 0, 0 },                   .{ length, length },
                .{ length / 4, length * 3 / 4 }, .{ length / 2, length / 2 }, .{ @min(length, 1023), length },
                .{ @min(length, 1024), length },
            };
            for (cuts) |cut| {
                const match_len = @max(@as(usize, 3), cut[1] - cut[0]);
                for ([_]usize{ 1, 8, 65537 }) |offset| {
                    const actual = cache.payloadLen(cut[0], offset, match_len, cut[1]);
                    const expected = Codec.referenceCost(block, cut[0], offset, match_len, cut[1]);
                    if (expected) |cost| {
                        try std.testing.expectEqual(cost, try actual);
                    } else |err| {
                        try std.testing.expectError(err, actual);
                    }
                }
            }
            try std.testing.expectEqual(@as(u64, 0), cache.work.reference_mismatches);
            try std.testing.expect(cache.work.reference_checks != 0);
        }
    }
}

pub fn errors(comptime Codec: type) !void {
    const Cache = cache_mod.Cache(Codec.CostCodec);
    var block: [131073]u8 = @splat('a');
    try std.testing.expectError(error.CorruptFrame, Cache.init(&block));
    var cache = try Cache.init(block[0..1024]);
    try std.testing.expectError(error.CorruptFrame, cache.payloadLen(1025, 1, 3, 1024));
    try std.testing.expectError(error.CorruptFrame, cache.payloadLen(5, 1, 3, 4));
    try std.testing.expectError(error.CorruptFrame, cache.payloadLen(0, 1, 3, 1025));
    try std.testing.expectError(error.CorruptFrame, cache.payloadLen(0, 1, 2, 1024));
    try std.testing.expectEqual(try Codec.referenceCost(block[0..1024], 16, 8, 64, 80), try cache.payloadLen(16, 8, 64, 80));
    var empty = try Cache.init("");
    try std.testing.expectEqual(try Codec.referenceCost("", 0, 1, 3, 0), try empty.payloadLen(0, 1, 3, 0));

    // A complete flat high-byte alphabet has no profitable serialized weight
    // tree. Cache this real codec's successful null, rather than only a mock.
    var flat: [1024]u8 = undefined;
    for (&flat, 0..) |*byte, i| byte.* = @truncate(i);
    const frequencies: [256]u32 = @splat(4);
    const plan = Codec.CostCodec.planFromFrequencies(&frequencies) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(?usize, null), try Codec.CostCodec.treeLen(&plan));
    var flat_cache = try Cache.init(&flat);
    try std.testing.expectEqual(try Codec.referenceCost(&flat, 0, 1, 3, 0), try flat_cache.payloadLen(0, 1, 3, 0));
    try std.testing.expectEqual(try Codec.referenceCost(&flat, 0, 8, 3, 0), try flat_cache.payloadLen(0, 8, 3, 0));
    try std.testing.expectEqual(@as(u64, 1), flat_cache.work.tree_serializations);
    try std.testing.expectEqual(@as(u64, 1), flat_cache.work.tree_cache_hits);
}

pub fn legacyPrefix(comptime Codec: type) !void {
    const Cache = cache_mod.Cache(VerifiedCodec(Codec));
    var block: [256]u8 = @splat('a');
    for (block[64..128], 0..) |*byte, i| byte.* = @intCast(33 + i);
    var cache = try Cache.init(&block);
    const prefix_len = 128 - 64; // second_start minus finder start_min.
    const old_cost = try Codec.referenceCost(&block, prefix_len, 64, 8, 136);
    try std.testing.expectEqual(old_cost, try cache.payloadLen(prefix_len, 64, 8, 136));
    var actual_suffix_view = block;
    @memcpy(actual_suffix_view[0..64], block[64..128]);
    try std.testing.expect(old_cost != try Codec.referenceCost(&actual_suffix_view, prefix_len, 64, 8, 136));
    try std.testing.expectEqual(@as(u32, 184), cache.histogram.stream_frequencies[0]['a']);
}

pub fn deltaWork(comptime Codec: type) !void {
    const Cache = cache_mod.Cache(VerifiedCodec(Codec));
    var block: [65536]u8 = undefined;
    fill(&block, 17, 1);
    var cache = try Cache.init(&block);
    _ = try cache.payloadLen(16384, 8, 16384, 32768);
    const scanned_before = cache.histogram.scanned_bytes;
    for (1..129) |step| _ = try cache.payloadLen(16384 + step, 8, 16384, 32768 + step);
    try std.testing.expectEqual(@as(u64, 49152), scanned_before);
    try std.testing.expectEqual(@as(u64, 256), cache.histogram.scanned_bytes - scanned_before);
    try std.testing.expectEqual(@as(u64, 129), cache.histogram.update_count);
    try std.testing.expectEqual(@as(u64, 129), cache.work.cost_queries);
    try std.testing.expectEqual(@as(u64, 129), cache.work.reference_checks);
    try std.testing.expectEqual(@as(u64, 0), cache.work.reference_mismatches);
    try std.testing.expect(cache.work.stream_symbol_products != 0);
    try std.testing.expect(cache.work.stream_symbol_products <= 129 * 4 * 256);

    // Frequency counts and cuts may change independently of the dense tree
    // key. A stable three-symbol tree must serialize once while stream prices
    // continue to use the current four frequency vectors on every query.
    for (&block, 0..) |*byte, i| byte.* = if (i % 4 < 2) 'a' else if (i % 4 == 2) 'b' else 'c';
    var stable = try Cache.init(&block);
    for (0..129) |step| _ = try stable.payloadLen(16384 + step, 8, 16384, 32768);
    try std.testing.expectEqual(@as(u64, 1), stable.work.tree_serializations);
    try std.testing.expectEqual(@as(u64, 128), stable.work.tree_cache_hits);
    try std.testing.expectEqual(@as(u64, 129), stable.work.huffman_plans);
    try std.testing.expectEqual(@as(u64, 129), stable.work.reference_checks);
    try std.testing.expectEqual(@as(u64, 0), stable.work.reference_mismatches);
    try std.testing.expectEqual(@as(u64, 129 * 4 * 3), stable.work.stream_symbol_products);
}

pub fn finders(comptime Codec: type) !void {
    const Cache = cache_mod.Cache(VerifiedCodec(Codec));
    var storage: [131072]u8 = undefined;
    for ([_]usize{ 4097, 65535, 65536, 65537, storage.len }) |length| {
        fill(storage[0..length], 0xa4093822, 0);
        const fragment = storage[512..768].*;
        @memcpy(storage[length / 2 ..][0..256], &fragment);
        @memcpy(storage[length - 512 ..][0..256], &fragment);
        const block = storage[0..length];
        var cache = try Cache.init(block);
        for ([_]usize{ 0, 17, length / 4, length / 2 + 100, length - 16 }) |start| {
            const expected = try Codec.referenceFinder(block, start);
            const actual = try Codec.cachedFinder(block, start, &cache);
            try std.testing.expectEqualDeep(expected, actual);
        }
        try std.testing.expect(cache.work.reference_checks != 0);
        try std.testing.expectEqual(@as(u64, 0), cache.work.reference_mismatches);
    }
}

pub fn wireAndAllocations(comptime Codec: type) !void {
    var storage: [65537]u8 = undefined;
    var successful: usize = 0;
    for ([_]usize{ 1023, 1024, 4096, 4097, 65535, 65536, storage.len }) |length| {
        fill(storage[0..length], 0x13198a2e, 0);
        // The first accepted match is longer, and the second pair is wholly
        // after its end. A suffix query therefore retains two real sequences.
        const first_fragment = storage[16..208].*;
        const second_fragment = storage[480..608].*;
        @memcpy(storage[256..448], &first_fragment);
        @memcpy(storage[736..864], &second_fragment);
        const block = storage[0..length];
        var reference_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
        var cached_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
        var reference: std.ArrayList(u8) = .empty;
        var cached: std.ArrayList(u8) = .empty;
        defer reference.deinit(reference_heap.allocator());
        defer cached.deinit(cached_heap.allocator());
        const expected = try Codec.multi(false, reference_heap.allocator(), &reference, block);
        const actual = try Codec.multi(true, cached_heap.allocator(), &cached, block);
        successful += @intFromBool(actual);
        try std.testing.expectEqual(expected, actual);
        try std.testing.expectEqualSlices(u8, reference.items, cached.items);
        try std.testing.expectEqual(reference_heap.alloc_index, cached_heap.alloc_index);
        try std.testing.expectEqual(reference_heap.allocated_bytes, cached_heap.allocated_bytes);
        try std.testing.expectEqual(reference_heap.freed_bytes, cached_heap.freed_bytes);
    }
    try std.testing.expect(successful != 0);
}

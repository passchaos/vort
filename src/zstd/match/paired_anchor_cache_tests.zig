//! Caller-level suffix traces independently reproduce alternating hash pairs.
//! This helper never imports its parent cache module or changes indexed rules.
const std = @import("std");
const hash_count = 32768;

fn canonicalHasher(bytes: *const [8]u8) usize {
    return @intCast((std.mem.readInt(u64, bytes, .little) *% 11_400_714_819_323_198_485) >> 49);
}
fn independentHash(block: []const u8, position: usize) usize {
    var word: u64 = 0;
    for (0..8) |byte| word |= @as(u64, block[position + byte]) << @as(u6, @intCast(byte * 8));
    return @intCast((word *% 11_400_714_819_323_198_485) >> 49);
}
fn collisionHasher(_: *const [8]u8) usize {
    return 17;
}
fn refusedHasher(_: *const [8]u8) usize {
    @panic("Hasher called before rejected initialization finished admission");
}
fn directExtension(block: []const u8, first: usize, second: usize) usize {
    var length: usize = 0;
    while (second + length < block.len and block[first + length] == block[second + length]) length += 1;
    return length;
}
fn fill(bytes: []u8, seed: u32) void {
    var random = seed;
    for (bytes) |*byte| {
        random = random *% 1664525 +% 1013904223;
        byte.* = @truncate(random >> 24);
    }
}

fn suffixTraces(comptime Module: type, block: []const u8, starts: []const usize, comptime collisions: bool) !void {
    const a = std.testing.allocator;
    const count = block.len -| 7;
    const hashes = try a.alloc(u16, count);
    defer a.free(hashes);
    const lengths = try a.alloc(u32, count);
    defer a.free(lengths);
    const seen = try a.alloc(bool, count);
    defer a.free(seen);
    @memset(seen, false);
    var cache = try Module.Cache.init(block, hashes, lengths, if (collisions) collisionHasher else canonicalHasher);
    try std.testing.expectEqual(@as(u64, count), cache.work.build_hashes);
    try std.testing.expectEqual(@as(u64, count * 6), cache.work.workspace_bytes);
    for (lengths) |length| try std.testing.expectEqual(std.math.maxInt(u32), length);
    var queries: u64 = 0;
    var extensions: u64 = 0;
    var hits: u64 = 0;
    for (starts) |start| {
        // Exactly the original unindexed scanner: reset pending per suffix,
        // toggle before rejecting collision length, and never remove an anchor.
        var first_by_hash: [hash_count]u32 = undefined;
        var pending: [hash_count]bool = @splat(false);
        for (start..count) |position| {
            const key = if (collisions) 17 else independentHash(block, position);
            try std.testing.expectEqual(key, cache.hash(position));
            queries += 1;
            if (!pending[key]) {
                first_by_hash[key] = @intCast(position);
                pending[key] = true;
                continue;
            }
            const first: usize = first_by_hash[key];
            pending[key] = false;
            const expected = directExtension(block, first, position);
            try std.testing.expectEqual(expected, cache.cachedLength(first, position, directExtension));
            if (seen[position]) hits += 1 else extensions += 1;
            seen[position] = true;
            try std.testing.expectEqual(@as(u32, @intCast(expected)), lengths[position]);
        }
    }
    try std.testing.expectEqual(queries, cache.work.query_hashes);
    try std.testing.expectEqual(extensions, cache.work.extension_calls);
    try std.testing.expectEqual(hits, cache.work.extension_hits);
    try std.testing.expectEqual(extensions + hits, cache.work.extension_calls + cache.work.extension_hits);
}

fn pairingParity(comptime Module: type) !void {
    const text = "abcdefghijklmnopqrstuvwxABCDEFGH";
    var starts: [text.len + 1]usize = undefined;
    const anchors = text.len - 7;
    for (starts[0 .. anchors + 1], 0..) |*start, position| start.* = position;
    try suffixTraces(Module, text, starts[0 .. anchors + 1], true);
    var repeated: [64]u8 = undefined;
    fill(&repeated, 19);
    @memcpy(repeated[32..48], repeated[0..16]);
    try suffixTraces(Module, &repeated, &.{ 0, 1, 7, 17, 32, repeated.len - 7 }, false);

    // Four occurrences in one bucket. Global (q0,q1)/(q2,q3) filtering from
    // q1 would yield (q2,q3), whereas suffix reset must pair (q1,q2).
    var bytes: [11]u8 = @splat('a');
    var hashes: [4]u16 = undefined;
    var lengths: [4]u32 = undefined;
    var cache = try Module.Cache.init(&bytes, &hashes, &lengths, collisionHasher);
    const global = [_][2]usize{ .{ 0, 1 }, .{ 2, 3 } };
    const suffix = [_][2]usize{.{ 1, 2 }};
    try std.testing.expect(!std.meta.eql(global[1], suffix[0]));
    try std.testing.expectEqual(@as(usize, 9), cache.cachedLength(suffix[0][0], suffix[0][1], directExtension));
    try std.testing.expectEqual(@as(usize, 8), cache.cachedLength(global[1][0], global[1][1], directExtension));
    try std.testing.expectEqual(@as(u32, 9), lengths[2]);
    try std.testing.expectEqual(@as(u32, 8), lengths[3]);
}

fn storageAdmission(comptime Module: type) !void {
    var bytes: [64]u8 align(4) = @splat(0xa5);
    var hashes: [66]u16 = @splat(0xbeef);
    var lengths: [66]u32 = @splat(0xdead_beef);
    const hashes_before = hashes;
    const lengths_before = lengths;
    try std.testing.expectError(error.InsufficientStorage, Module.Cache.init(&bytes, hashes[1..56], lengths[1..65], refusedHasher));
    try std.testing.expectError(error.InsufficientStorage, Module.Cache.init(&bytes, hashes[1..65], lengths[1..56], refusedHasher));
    try std.testing.expectEqualDeep(hashes_before, hashes);
    try std.testing.expectEqualDeep(lengths_before, lengths);
    const input_hashes: []u16 = @alignCast(std.mem.bytesAsSlice(u16, bytes[0..]));
    try std.testing.expectError(error.OverlappingStorage, Module.Cache.init(bytes[0..32], input_hashes, lengths[0..32], refusedHasher));
    const input_lengths: []u32 = @alignCast(std.mem.bytesAsSlice(u32, bytes[0..]));
    try std.testing.expectError(error.OverlappingStorage, Module.Cache.init(bytes[0..16], hashes[0..16], input_lengths, refusedHasher));
    try std.testing.expectEqualDeep(hashes_before, hashes);
    try std.testing.expectEqualDeep(lengths_before, lengths);
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    var shared: [80]u32 align(4) = @splat(0x1234_5678);
    const shared_before = shared;
    const overlapping_hashes: []u16 = @alignCast(std.mem.bytesAsSlice(u16, std.mem.sliceAsBytes(shared[0..32])));
    try std.testing.expectError(error.OverlappingStorage, Module.Cache.init(bytes[0..32], overlapping_hashes, shared[16..48], refusedHasher));
    try std.testing.expectEqualDeep(shared_before, shared);
    // Used prefixes are disjoint for one anchor, but the full borrowed slices
    // overlap in their spare capacity and must be refused before mutation.
    const spare_hashes: []u16 = @alignCast(std.mem.bytesAsSlice(u16, std.mem.sliceAsBytes(shared[0..4])));
    try std.testing.expectError(error.OverlappingStorage, Module.Cache.init(bytes[0..8], spare_hashes, shared[1..3], refusedHasher));
    try std.testing.expectEqualDeep(shared_before, shared);
    var cache = try Module.Cache.init(&bytes, hashes[1..65], lengths[1..65], canonicalHasher);
    try std.testing.expectEqual(@as(u16, 0xbeef), hashes[0]);
    try std.testing.expectEqual(@as(u16, 0xbeef), hashes[65]);
    try std.testing.expectEqual(@as(u32, 0xdead_beef), lengths[0]);
    try std.testing.expectEqual(@as(u32, 0xdead_beef), lengths[65]);
    // Provided trailing spare capacity lies outside the used 57 entries.
    for (hashes[58..65]) |hash| try std.testing.expectEqual(@as(u16, 0xbeef), hash);
    for (lengths[58..65]) |length| try std.testing.expectEqual(@as(u32, 0xdead_beef), length);
    try std.testing.expectEqual(independentHash(&bytes, 0), cache.hash(0));
    var hash_storage: [66]u16 align(32) = @splat(0xbeef);
    var length_storage: [66]u32 align(32) = @splat(0xdead_beef);
    var unaligned = try Module.Cache.init(&bytes, hash_storage[1..65], length_storage[1..65], canonicalHasher);
    try std.testing.expectEqual(@as(usize, 2), @intFromPtr(hash_storage[1..].ptr) % 32);
    try std.testing.expectEqual(@as(usize, 4), @intFromPtr(length_storage[1..].ptr) % 32);
    try std.testing.expectEqual(independentHash(&bytes, 1), unaligned.hash(1));
    try std.testing.expectEqual(@as(u16, 0xbeef), hash_storage[0]);
    try std.testing.expectEqual(@as(u32, 0xdead_beef), length_storage[0]);
}

fn boundsAndLengths(comptime Module: type) !void {
    const a = std.testing.allocator;
    const block = try a.alloc(u8, 131073);
    defer a.free(block);
    const hashes = try a.alloc(u16, 131067);
    defer a.free(hashes);
    const lengths = try a.alloc(u32, 131067);
    defer a.free(lengths);
    for ([_]usize{ 0, 7, 8, 32, 4097, 65535, 65536, 65537, 131072 }) |length| {
        fill(block[0..length], 0x243f6a88);
        @memset(hashes, 0xbeef);
        @memset(lengths, 0xdead_beef);
        var cache = try Module.Cache.init(block[0..length], hashes[1..], lengths[1..], canonicalHasher);
        const anchors = length -| 7;
        try std.testing.expectEqual(@as(u64, anchors), cache.work.build_hashes);
        try std.testing.expectEqual(@as(u64, anchors * 6), cache.work.workspace_bytes);
        for (0..anchors) |position| {
            try std.testing.expectEqual(independentHash(block[0..length], position), cache.hash(position));
            try std.testing.expectEqual(std.math.maxInt(u32), lengths[position + 1]);
        }
        try std.testing.expectEqual(@as(u16, 0xbeef), hashes[0]);
        try std.testing.expectEqual(@as(u32, 0xdead_beef), lengths[0]);
    }
    @memset(hashes, 0xbeef);
    @memset(lengths, 0xdead_beef);
    try std.testing.expectError(error.InvalidBlock, Module.Cache.init(block, hashes, lengths, refusedHasher));
    for (hashes) |hash| try std.testing.expectEqual(@as(u16, 0xbeef), hash);
    for (lengths) |length| try std.testing.expectEqual(@as(u32, 0xdead_beef), length);

    @memset(block, 'R');
    var long = try Module.Cache.init(block[0..131072], hashes, lengths, canonicalHasher);
    // Every anchor has one key; these pairs are immediate predecessors in
    // that global occurrence sequence and valid under suitable suffix parity.
    try std.testing.expectEqual(@as(usize, 131071), long.cachedLength(0, 1, directExtension));
    try std.testing.expectEqual(@as(usize, 65536), long.cachedLength(65535, 65536, directExtension));
    try std.testing.expectEqual(@as(usize, 65535), long.cachedLength(65536, 65537, directExtension));
    try std.testing.expectEqual(@as(usize, 65535), long.cachedLength(65536, 65537, directExtension));
    try std.testing.expectEqual(@as(u64, 3), long.work.extension_calls);
    try std.testing.expectEqual(@as(u64, 1), long.work.extension_hits);
}

fn collisionsAndReinitialization(comptime Module: type) !void {
    var bytes: [32]u8 = undefined;
    var hashes: [25]u16 = undefined;
    var lengths: [25]u32 = undefined;
    for (0..8) |equal_prefix| {
        @memset(&bytes, 'a');
        bytes[equal_prefix + 1] = 'b';
        var cache = try Module.Cache.init(&bytes, &hashes, &lengths, collisionHasher);
        try std.testing.expectEqual(equal_prefix, cache.cachedLength(0, 1, directExtension));
        try std.testing.expectEqual(equal_prefix, cache.cachedLength(0, 1, directExtension));
        try std.testing.expectEqual(@as(u64, 1), cache.work.extension_calls);
        try std.testing.expectEqual(@as(u64, 1), cache.work.extension_hits);
    }
    @memset(&bytes, 'a');
    var cache = try Module.Cache.init(&bytes, &hashes, &lengths, collisionHasher);
    try std.testing.expectEqual(@as(usize, 31), cache.cachedLength(0, 1, directExtension));
    // Finish the old immutable borrow before changing the reused caller bytes.
    bytes[1] = 'b';
    cache = try Module.Cache.init(&bytes, &hashes, &lengths, canonicalHasher);
    try std.testing.expectEqual(@as(u64, 25), cache.work.build_hashes);
    try std.testing.expectEqual(@as(u64, 0), cache.work.query_hashes);
    try std.testing.expectEqual(@as(u64, 0), cache.work.extension_calls);
    try std.testing.expectEqual(@as(u64, 0), cache.work.extension_hits);
    for (lengths) |length| try std.testing.expectEqual(std.math.maxInt(u32), length);
    for (0..25) |position| try std.testing.expectEqual(independentHash(&bytes, position), cache.hash(position));
}

pub fn contracts(comptime Module: type) !void {
    try std.testing.expect(@sizeOf(Module.Cache) <= 256);
    try pairingParity(Module);
    try storageAdmission(Module);
    try boundsAndLengths(Module);
    try collisionsAndReinitialization(Module);
}

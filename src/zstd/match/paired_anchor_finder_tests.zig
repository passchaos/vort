const std = @import("std");
const anchors = @import("paired_anchor_cache.zig");
const winner = @import("../literals/winner_cost_cache.zig");

fn VerifiedCostCodec(comptime Codec: type) type {
    return struct {
        pub const Error = Codec.CostCodec.Error;
        pub const literalHeaderLen = Codec.CostCodec.literalHeaderLen;
        pub const huffmanHeaderLen = Codec.CostCodec.huffmanHeaderLen;
        pub const planFromFrequencies = Codec.CostCodec.planFromFrequencies;
        pub const treeLen = Codec.CostCodec.treeLen;
        pub const rlePayloadLen = Codec.CostCodec.rlePayloadLen;
        pub const predefinedPayloadLen = Codec.CostCodec.predefinedPayloadLen;
        pub const singleSequenceBaseLen = Codec.CostCodec.singleSequenceBaseLen;
        pub const optimal_huffman_bits = Codec.CostCodec.optimal_huffman_bits;
        pub const minimum_tree_bytes = Codec.CostCodec.minimum_tree_bytes;
        pub const referenceCost = Codec.referenceCost;
    };
}

const Event = struct {
    prefix: usize,
    offset: usize,
    match_len: usize,
    tail: usize,
    incumbent: ?winner.Winner,
    cost: ?usize = null,
    failure: ?anyerror = null,
    injected_failure: bool = false,
    certificate_age: u64,
    certificate_refreshes: u64,
    inner_queries: u64,
    huffman_plans: u64,
    would_reject: u64,
    rejected: u64,
};

fn Trace(comptime Codec: type, comptime mode: winner.Mode) type {
    return struct {
        cache: winner.Cache(VerifiedCostCodec(Codec), mode),
        events: std.ArrayList(Event) = .empty,
        inject_cost_errors: bool = false,
        const Self = @This();

        fn init(block: []const u8, inject: bool) Codec.CostCodec.Error!Self {
            return .{ .cache = try winner.Cache(VerifiedCostCodec(Codec), mode).init(block), .inject_cost_errors = inject };
        }
        fn deinit(self: *Self) void {
            self.events.deinit(std.testing.allocator);
        }
        pub fn payloadForWinner(self: *Self, prefix: usize, offset: usize, match_len: usize, tail: usize, incumbent: ?winner.Winner) Codec.CostCodec.Error!?usize {
            const inject = self.inject_cost_errors and self.events.items.len % 7 == 3;
            const actual: Codec.CostCodec.Error!?usize = if (inject)
                error.CorruptFrame
            else
                self.cache.payloadForWinner(prefix, offset, match_len, tail, incumbent);
            var event: Event = .{
                .prefix = prefix,
                .offset = offset,
                .match_len = match_len,
                .tail = tail,
                .incumbent = incumbent,
                .injected_failure = inject,
                .certificate_age = self.cache.certificate_age,
                .certificate_refreshes = self.cache.bound_work.certificate_refreshes,
                .inner_queries = self.cache.inner.work.cost_queries,
                .huffman_plans = self.cache.inner.work.huffman_plans,
                .would_reject = self.cache.bound_work.would_reject,
                .rejected = self.cache.bound_work.rejected,
            };
            if (actual) |value| event.cost = value else |err| event.failure = err;
            try self.events.append(std.testing.allocator, event);
            return actual;
        }
    };
}

fn fill(bytes: []u8, seed: u32) void {
    var random = seed;
    for (bytes) |*byte| {
        random = random *% 1664525 +% 1013904223;
        byte.* = @truncate(random >> 24);
    }
}

fn compareFinders(comptime Codec: type, block: []const u8, starts: []const usize, comptime mode: winner.Mode, inject: bool) !void {
    const a = std.testing.allocator;
    const count = block.len -| 7;
    const hashes = try a.alloc(u16, count);
    defer a.free(hashes);
    const lengths = try a.alloc(u32, count);
    defer a.free(lengths);
    var prepared = try anchors.Cache.init(block, hashes, lengths, Codec.hash);
    var old = try Trace(Codec, mode).init(block, inject);
    defer old.deinit();
    var cached = try Trace(Codec, mode).init(block, inject);
    defer cached.deinit();
    for (starts) |start| {
        const expected = try Codec.finder(false, block, start, &old, null);
        const actual = try Codec.finder(true, block, start, &cached, &prepared);
        try std.testing.expectEqualDeep(expected, actual);
        try std.testing.expectEqualDeep(old.events.items, cached.events.items);
        try std.testing.expectEqualDeep(old.cache.inner.work, cached.cache.inner.work);
        try std.testing.expectEqualDeep(old.cache.bound_work, cached.cache.bound_work);
        try std.testing.expectEqualDeep(old.cache.certificate, cached.cache.certificate);
        try std.testing.expectEqual(old.cache.certificate_age, cached.cache.certificate_age);
    }
    try std.testing.expect(old.events.items.len != 0);
    try std.testing.expectEqual(@as(u64, 0), old.cache.inner.work.reference_mismatches);
    try std.testing.expectEqual(@as(u64, 0), cached.cache.inner.work.reference_mismatches);
    try std.testing.expectEqual(@as(u64, 0), cached.cache.bound_work.bound_violations);
    try std.testing.expectEqual(@as(u64, 0), cached.cache.bound_work.false_rejections);
    try std.testing.expectEqual(@as(u64, count), prepared.work.build_hashes);
    try std.testing.expect(prepared.work.query_hashes != 0);
    try std.testing.expect(prepared.work.extension_calls != 0);
    // Cached lengths include collisions, so verify every published entry using
    // an independently reconstructed adjacent predecessor for its hash bucket.
    var previous: [32768]u32 = @splat(std.math.maxInt(u32));
    for (0..count) |position| {
        const key = Codec.hash(block[position..][0..8]);
        if (lengths[position] != anchors.unknown_length) {
            if (previous[key] == std.math.maxInt(u32)) return error.TestUnexpectedResult;
            const first: usize = previous[key];
            try std.testing.expectEqual(@as(u32, @intCast(Codec.extension(block, first, position))), lengths[position]);
        }
        previous[key] = @intCast(position);
    }
    if (inject) {
        var errors: usize = 0;
        for (old.events.items) |event| errors += @intFromBool(event.injected_failure);
        try std.testing.expect(errors != 0);
    }
}

fn collisionBlock(comptime Codec: type, block: []u8) !void {
    fill(block, 0x243f6a88);
    const fragment = block[32..96].*;
    @memcpy(block[1024..1088], &fragment);
    @memcpy(block[2048..2112], &fragment);
    const wanted = Codec.hash(block[32..40]);
    var found = false;
    for (0..1048576) |probe| {
        var value: u32 = @intCast(probe);
        for (0..4) |index| block[512 + index] = @truncate(value >> @as(u5, @intCast(index * 8)));
        value *%= 0x9e37_79b1;
        for (0..4) |index| block[516 + index] = @truncate(value >> @as(u5, @intCast(index * 8)));
        if (Codec.hash(block[512..520]) == wanted and !std.mem.eql(u8, block[32..40], block[512..520])) {
            found = true;
            break;
        }
    }
    try std.testing.expect(found);
    try std.testing.expect(Codec.extension(block, 32, 512) < 8);
}

pub fn contracts(comptime Codec: type) !void {
    const a = std.testing.allocator;
    const block = try a.alloc(u8, 65537);
    defer a.free(block);
    inline for (.{ winner.Mode.shadow, winner.Mode.prune }) |mode| {
        for ([_]usize{ 4097, 65537 }) |length| {
            const input = block[0..length];
            try collisionBlock(Codec, input);
            try compareFinders(Codec, input, &.{ 0, 1, 32, 33, 512, 513, 1024, 1025, 2048, length - 8, length - 7, length }, mode, false);
            fill(input, 0xa4093822);
            // Multiple ordered pairs produce enough actual cost callbacks to
            // exercise deterministic injected CorruptFrame pricing failures.
            const first = input[16..80].*;
            const second = input[320..384].*;
            @memcpy(input[256..320], &first);
            @memcpy(input[768..832], &first);
            @memcpy(input[1024..1088], &first);
            @memcpy(input[1408..1472], &second);
            @memcpy(input[1792..1856], &second);
            try compareFinders(Codec, input, &.{ 0, 17, 256, 257, 320, 768, 769, 1024, 1408, length - 16, length }, mode, true);
            @memset(input, 'R');
            try compareFinders(Codec, input, &.{ 0, 1, 7, length / 2, length - 8, length - 7, length }, mode, false);
        }
    }
}

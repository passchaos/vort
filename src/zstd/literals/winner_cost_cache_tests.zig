const std = @import("std");
const winner = @import("winner_cost_cache.zig");

fn VerifiedCostCodec(comptime Codec: type) type {
    return struct {
        pub const Error = Codec.CostCodec.Error;
        pub const literalHeaderLen = Codec.CostCodec.literalHeaderLen;
        pub const huffmanHeaderLen = Codec.CostCodec.huffmanHeaderLen;
        pub const planFromFrequencies = Codec.CostCodec.planFromFrequencies;
        pub const treeLen = Codec.CostCodec.treeLen;
        pub const rlePayloadLen = Codec.CostCodec.rlePayloadLen;
        pub const predefinedPayloadLen = Codec.CostCodec.predefinedPayloadLen;
        pub const optimal_huffman_bits = Codec.CostCodec.optimal_huffman_bits;
        pub const minimum_tree_bytes = Codec.CostCodec.minimum_tree_bytes;
        pub const referenceCost = Codec.referenceCost;
    };
}

fn fill(bytes: []u8) void {
    for (bytes, 0..) |*byte, index| byte.* = if (index % 8 < 5) 'a' else if (index % 8 < 7) 'b' else 'c';
}

fn expectExact(comptime Codec: type, cache: anytype, block: []const u8, prefix: usize, offset: usize, match: usize, tail: usize, incumbent: ?winner.Winner) !?usize {
    const reference = Codec.referenceCost(block, prefix, offset, match, tail);
    const actual = cache.payloadForWinner(prefix, offset, match, tail, incumbent);
    if (reference) |cost| {
        const result = try actual;
        if (result) |value| {
            try std.testing.expectEqual(cost, value);
        } else {
            const prior = incumbent orelse return error.TestUnexpectedResult;
            try std.testing.expect(!winner.canUpdate(cost, match, prior));
        }
        return result;
    } else |err| {
        try std.testing.expectError(err, actual);
        return null;
    }
}

fn seed(comptime Codec: type, cache: anytype, block: []const u8) !void {
    try std.testing.expect(cache.certificate == null);
    _ = try expectExact(Codec, cache, block, 1024, 8, 1024, 2048, null);
    try std.testing.expect(cache.certificate != null);
    try std.testing.expectEqual(@as(u64, 1), cache.bound_work.certificate_refreshes);
    try std.testing.expectEqual(@as(u64, 0), cache.certificate_age);
}

/// Build the declared relaxation independently from physical prefix/tail
/// bytes. This supplies an exact equality incumbent for the predicate test;
/// old referenceCost still verifies the returned complete candidate cost.
fn independentLower(comptime Codec: type, certificate: anytype, block: []const u8, prefix: usize, offset: usize, match: usize, tail: usize) !usize {
    var frequencies: [256]u32 = @splat(0);
    for (block[0..prefix]) |byte| frequencies[byte] += 1;
    for (block[tail..]) |byte| frequencies[byte] += 1;
    var current: i128 = 0;
    var negative: i128 = 0;
    for (frequencies, certificate.frequencies) |frequency, previous| {
        current += frequency;
        negative += previous -| frequency;
        try std.testing.expectEqual(previous != 0, frequency != 0);
    }
    const changed = @as(i128, certificate.trusted_lower_bits) + current - certificate.total_frequency - 10 * negative;
    const lower_bits: usize = @intCast(@max(current, changed));
    const regenerated: usize = @intCast(current);
    const stream_count: usize = if (regenerated < 1024) 1 else 4;
    const bits_with_markers = lower_bits + stream_count;
    const streams = bits_with_markers / 8 + @intFromBool(bits_with_markers % 8 != 0) + (if (stream_count == 4) @as(usize, 6) else 0);
    const huffman = try Codec.CostCodec.huffmanHeaderLen(regenerated, 1) + Codec.CostCodec.minimum_tree_bytes + streams;
    const raw = try Codec.CostCodec.literalHeaderLen(regenerated) + regenerated;
    var sequence: ?usize = null;
    if (Codec.CostCodec.rlePayloadLen(prefix, offset, match, 0)) |cost| sequence = cost else |err| if (err != error.CorruptFrame) return err;
    if (Codec.CostCodec.predefinedPayloadLen(prefix, offset, match, 0)) |cost| {
        sequence = @min(sequence orelse cost, cost);
    } else |err| if (err != error.CorruptFrame) return err;
    return (sequence orelse return error.TestUnexpectedResult) + @min(raw, huffman);
}

fn rejectionAndEquality(comptime Codec: type) !void {
    const Verified = VerifiedCostCodec(Codec);
    const Shadow = winner.Cache(Verified, .shadow);
    const Prune = winner.Cache(Verified, .prune);
    try std.testing.expect(@sizeOf(Shadow) < 8 * 1024 and @sizeOf(Prune) < 8 * 1024);
    var block: [8192]u8 = undefined;
    fill(&block);
    var shadow = try Shadow.init(&block);
    var prune = try Prune.init(&block);
    try seed(Codec, &shadow, &block);
    try seed(Codec, &prune, &block);
    const witness = prune.certificate.?;
    const plans_before = prune.inner.work.huffman_plans;
    var equality = prune;
    var changed_price = shadow;
    const initial_cost = try Codec.referenceCost(&block, 1024, 8, 1024, 2048);
    const later_cost = try Codec.referenceCost(&block, 1088, 8, 1024, 2048);
    try std.testing.expect(initial_cost != later_cost);
    const loose: winner.Winner = .{ .payload_len = std.math.maxInt(usize), .match_len = 0 };
    try std.testing.expectEqual(@as(?usize, later_cost), try expectExact(Codec, &changed_price, &block, 1088, 8, 1024, 2048, loose));
    try std.testing.expectEqual(@as(u64, 1), changed_price.bound_work.bound_checks);
    try std.testing.expectEqual(@as(u64, 2), changed_price.bound_work.certificate_refreshes);
    const impossible: winner.Winner = .{ .payload_len = 1, .match_len = 65536 };
    for (1..5) |step| {
        const exact = try expectExact(Codec, &shadow, &block, 1024 + step, 8, 1024, 2048, impossible);
        try std.testing.expect(exact != null);
        try std.testing.expectEqual(@as(?usize, null), try expectExact(Codec, &prune, &block, 1024 + step, 8, 1024, 2048, impossible));
        try std.testing.expectEqualDeep(witness, prune.certificate.?);
        try std.testing.expectEqualDeep(witness, shadow.certificate.?);
        try std.testing.expectEqual(@as(u64, step), prune.certificate_age);
        try std.testing.expectEqual(@as(u64, step), shadow.certificate_age);
    }
    var changed: [256]u32 = undefined;
    prune.inner.histogram.totalFrequencies(&changed);
    try std.testing.expect(!std.mem.eql(u32, &witness.frequencies, &changed));
    try std.testing.expectEqual(@as(u64, 4), shadow.bound_work.would_reject);
    try std.testing.expectEqual(@as(u64, 0), shadow.bound_work.rejected);
    try std.testing.expectEqual(@as(u64, 4), prune.bound_work.would_reject);
    try std.testing.expectEqual(@as(u64, 4), prune.bound_work.rejected);
    try std.testing.expectEqual(@as(u64, 1), shadow.bound_work.certificate_refreshes);
    try std.testing.expectEqual(@as(u64, 1), prune.bound_work.certificate_refreshes);
    try std.testing.expectEqual(plans_before, prune.inner.work.huffman_plans);
    try std.testing.expectEqual(plans_before + 4, shadow.inner.work.huffman_plans);
    try std.testing.expectEqual(@as(u64, 0), prune.inner.work.reference_mismatches);
    try std.testing.expectEqual(@as(u64, 0), shadow.inner.work.reference_mismatches);
    try std.testing.expectEqual(@as(u64, 0), prune.bound_work.false_rejections);
    try std.testing.expectEqual(@as(u64, 0), shadow.bound_work.bound_violations);

    const lower = try independentLower(Codec, witness, &block, 1024, 8, 1024, 2048);
    const longer_tie: winner.Winner = .{ .payload_len = lower, .match_len = 1023 };
    try std.testing.expect(winner.canUpdate(lower, 1024, longer_tie));
    try std.testing.expect(!winner.canUpdate(lower, 1023, longer_tie));
    try std.testing.expect(!winner.canUpdate(lower + 1, 1024, longer_tie));
    try std.testing.expect((try expectExact(Codec, &equality, &block, 1024, 8, 1024, 2048, longer_tie)) != null);
    try std.testing.expectEqual(@as(u64, 1), equality.bound_work.equality_longer_retained);
    try std.testing.expectEqual(@as(u64, 0), equality.bound_work.rejected);
    try std.testing.expectEqual(plans_before + 1, equality.inner.work.huffman_plans);
    try std.testing.expectEqual(@as(u64, 2), equality.bound_work.certificate_refreshes);
}

fn publicationAndFallback(comptime Codec: type) !void {
    const Prune = winner.Cache(VerifiedCostCodec(Codec), .prune);
    var block: [8192]u8 = undefined;
    fill(&block);
    block[1500] = 0xff; // The seed cut excludes this support-changing symbol.
    var cache = try Prune.init(&block);
    try seed(Codec, &cache, &block);
    const old_witness = cache.certificate.?;
    const refreshes = cache.bound_work.certificate_refreshes;
    _ = try expectExact(Codec, &cache, &block, 5, 8, 3, 4, null);
    _ = try expectExact(Codec, &cache, &block, 1024, 8, 2, 2048, null);
    try std.testing.expectEqualDeep(old_witness, cache.certificate.?);
    try std.testing.expectEqual(refreshes, cache.bound_work.certificate_refreshes);
    const impossible: winner.Winner = .{ .payload_len = 1, .match_len = 65536 };
    const before_plans = cache.inner.work.huffman_plans;
    try std.testing.expect((try expectExact(Codec, &cache, &block, 1536, 8, 512, 2048, impossible)) != null);
    try std.testing.expectEqual(@as(u64, 1), cache.bound_work.support_mismatch);
    try std.testing.expectEqual(@as(u64, 0), cache.bound_work.rejected);
    try std.testing.expect(cache.inner.work.huffman_plans > before_plans);

    var flat: [1024]u8 = undefined;
    for (&flat, 0..) |*byte, index| byte.* = @truncate(index);
    var null_tree = try Prune.init(&flat);
    _ = try expectExact(Codec, &null_tree, &flat, 0, 1, 3, 0, null);
    try std.testing.expect(null_tree.certificate == null);
    _ = try expectExact(Codec, &null_tree, &flat, 0, 8, 3, 0, impossible);
    try std.testing.expect(null_tree.certificate == null);
    try std.testing.expectEqual(@as(u64, 0), null_tree.bound_work.certificate_refreshes);
    try std.testing.expectEqual(@as(u64, 0), null_tree.bound_work.rejected);

    var rle: [4096]u8 = @splat('a');
    var rle_cache = try Prune.init(&rle);
    _ = try expectExact(Codec, &rle_cache, &rle, 64, 8, 128, 192, impossible);
    try std.testing.expect(rle_cache.certificate == null);
    try std.testing.expectEqual(@as(u64, 0), rle_cache.bound_work.certificate_refreshes);
    var small: [63]u8 = undefined;
    fill(&small);
    var small_cache = try Prune.init(&small);
    _ = try expectExact(Codec, &small_cache, &small, 0, 8, 3, 0, impossible);
    try std.testing.expect(small_cache.certificate == null);
    try std.testing.expectEqual(@as(u64, 0), small_cache.bound_work.certificate_refreshes);
}

fn finderWinners(comptime Codec: type) !void {
    var block: [8193]u8 = undefined;
    var random: u32 = 0x243f6a88;
    for (&block) |*byte| {
        random = random *% 1664525 +% 1013904223;
        byte.* = @truncate(random >> 24);
    }
    const fragment = block[512..768].*;
    @memcpy(block[4096..4352], &fragment);
    @memcpy(block[7680..7936], &fragment);
    inline for (.{ winner.Mode.shadow, winner.Mode.prune }) |mode| {
        var cache = try winner.Cache(VerifiedCostCodec(Codec), mode).init(&block);
        for ([_]usize{ 0, 17, 2048, 4200, 8000 }) |start| {
            const reference = try Codec.referenceFinder(&block, start);
            const actual = try Codec.cachedFinder(&block, start, &cache);
            try std.testing.expectEqualDeep(reference, actual);
        }
        try std.testing.expect(cache.bound_work.queries != 0);
        try std.testing.expectEqual(@as(u64, 0), cache.inner.work.reference_mismatches);
        try std.testing.expectEqual(@as(u64, 0), cache.bound_work.bound_violations);
        try std.testing.expectEqual(@as(u64, 0), cache.bound_work.false_rejections);
    }
}

fn preparedBoundaries(comptime Codec: type) !void {
    var block: [131072]u8 = undefined;
    fill(&block);
    const impossible: winner.Winner = .{ .payload_len = 1, .match_len = 65536 };
    const loose: winner.Winner = .{ .payload_len = std.math.maxInt(usize), .match_len = 0 };
    inline for (.{ winner.Mode.shadow, winner.Mode.prune }) |mode| {
        var cache = try winner.Cache(VerifiedCostCodec(Codec), mode).init(&block);
        try seed(Codec, &cache, &block);
        for ([_]usize{ 1023, 1024, 1023, 16383, 16384, 16383, 65535, 65536, 65537, 131072, 65536, 1024 }) |regenerated| {
            const tail = block.len - regenerated;
            const witness = cache.certificate.?;
            const refreshes = cache.bound_work.certificate_refreshes;
            const plans = cache.inner.work.huffman_plans;
            // These are literal/cost geometry queries, including a full-block
            // view; they do not claim to encode a real match for every cut.
            const candidate = try expectExact(Codec, &cache, &block, 0, 8, 3, tail, impossible);
            if (mode == .prune) {
                try std.testing.expectEqual(@as(?usize, null), candidate);
                try std.testing.expectEqual(plans, cache.inner.work.huffman_plans);
            } else {
                try std.testing.expect(candidate != null);
                try std.testing.expectEqual(plans + 1, cache.inner.work.huffman_plans);
            }
            try std.testing.expectEqualDeep(witness, cache.certificate.?);
            try std.testing.expectEqual(refreshes, cache.bound_work.certificate_refreshes);
            try std.testing.expectEqual(regenerated, cache.inner.histogram.regenerated_len);
            try std.testing.expectEqual(@as(usize, if (regenerated < 1024) 1 else 4), cache.inner.histogram.stream_count);
            const minimum_header: usize = if (regenerated <= 1023) 3 else if (regenerated <= 16383) 4 else 5;
            try std.testing.expectEqual(minimum_header, try Codec.CostCodec.huffmanHeaderLen(regenerated, 1));
            var frequencies: [256]u32 = undefined;
            cache.inner.histogram.totalFrequencies(&frequencies);
            var expected: [256]u32 = @splat(0);
            for (block[tail..]) |symbol| expected[symbol] += 1;
            try std.testing.expectEqualSlices(u32, &expected, &frequencies);
            const support = try witness.analyze(&frequencies);
            try std.testing.expect(support.same_support);
            try std.testing.expectEqual(@as(usize, 3), support.current_active_symbols);

            // A loose incumbent admits a complete fresh price at the same cut.
            // This also moves the witness across both shrinking and growing R.
            try std.testing.expect((try expectExact(Codec, &cache, &block, 0, 8, 3, tail, loose)) != null);
            try std.testing.expectEqual(refreshes + 1, cache.bound_work.certificate_refreshes);
            try std.testing.expectEqual(@as(u64, 0), cache.certificate_age);
            try std.testing.expectEqual(@as(u32, @intCast(regenerated)), cache.certificate.?.total_frequency);
        }
        try std.testing.expect(cache.bound_work.negative_delta_total > 0);
        try std.testing.expect(cache.bound_work.max_negative_delta > 0);
        try std.testing.expectEqual(@as(u64, 12), cache.bound_work.would_reject);
        try std.testing.expectEqual(@as(u64, if (mode == .prune) 12 else 0), cache.bound_work.rejected);
        try std.testing.expectEqual(@as(u64, 0), cache.bound_work.support_mismatch);
        try std.testing.expectEqual(@as(u64, 0), cache.bound_work.bound_violations);
        try std.testing.expectEqual(@as(u64, 0), cache.bound_work.false_rejections);
        try std.testing.expectEqual(@as(u64, 0), cache.inner.work.reference_mismatches);
    }
}

fn HeaderFailureCodec(comptime Codec: type) type {
    return struct {
        pub const Error = Codec.CostCodec.Error;
        pub const huffmanHeaderLen = Codec.CostCodec.huffmanHeaderLen;
        pub const planFromFrequencies = Codec.CostCodec.planFromFrequencies;
        pub const treeLen = Codec.CostCodec.treeLen;
        pub const rlePayloadLen = Codec.CostCodec.rlePayloadLen;
        pub const predefinedPayloadLen = Codec.CostCodec.predefinedPayloadLen;
        pub const optimal_huffman_bits = Codec.CostCodec.optimal_huffman_bits;
        pub const minimum_tree_bytes = Codec.CostCodec.minimum_tree_bytes;

        pub fn literalHeaderLen(_: usize) Error!usize {
            return error.IntegerOverflow;
        }
        // The injected codec has its own matching error oracle. Aliasing the
        // real codec's successful price would conceal a reference mismatch.
        pub fn referenceCost(_: []const u8, _: usize, _: usize, _: usize, _: usize) Error!usize {
            return error.IntegerOverflow;
        }
    };
}

fn failedPreparationAccounting(comptime Codec: type) !void {
    var block: [8192]u8 = undefined;
    fill(&block);
    var real = try winner.Cache(VerifiedCostCodec(Codec), .shadow).init(&block);
    try seed(Codec, &real, &block);
    const trusted = real.certificate.?;
    inline for (.{ winner.Mode.shadow, winner.Mode.prune }) |mode| {
        for ([_]bool{ false, true }) |retained| {
            var cache = try winner.Cache(HeaderFailureCodec(Codec), mode).init(&block);
            if (retained) cache.certificate = trusted;
            try std.testing.expectError(error.IntegerOverflow, cache.payloadForWinner(1025, 8, 1024, 2048, null));
            // Histogram admission precedes the injected header error. Retrying
            // the base API would admit the same cut twice and double update_count.
            try std.testing.expectEqual(@as(u64, 1), cache.inner.histogram.update_count);
            try std.testing.expectEqual(@as(usize, 7169), cache.inner.histogram.regenerated_len);
            try std.testing.expectEqual(@as(u64, 1), cache.inner.work.cost_queries);
            try std.testing.expectEqual(@as(u64, 1), cache.inner.work.reference_checks);
            try std.testing.expectEqual(@as(u64, 0), cache.inner.work.reference_mismatches);
            try std.testing.expectEqual(@as(u64, 1), cache.bound_work.queries);
            try std.testing.expectEqual(@as(u64, 0), cache.bound_work.certificate_refreshes);
            try std.testing.expectEqual(@as(u64, 0), cache.inner.work.huffman_plans);
            if (retained) {
                try std.testing.expectEqualDeep(trusted, cache.certificate.?);
                try std.testing.expectEqual(@as(u64, 1), cache.certificate_age);
            } else {
                try std.testing.expect(cache.certificate == null);
                try std.testing.expectEqual(@as(u64, 0), cache.certificate_age);
            }
        }
    }
}

pub fn contracts(comptime Codec: type) !void {
    try rejectionAndEquality(Codec);
    try publicationAndFallback(Codec);
    try finderWinners(Codec);
    try preparedBoundaries(Codec);
    try failedPreparationAccounting(Codec);
}

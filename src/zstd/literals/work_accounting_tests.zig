//! Work accounting is observed externally. Disabled cache work fields are
//! never read; callback logs and semantic state remain independently visible.
const std = @import("std");
const exact = @import("single_cost_cache.zig");
const winner = @import("winner_cost_cache.zig");

const Kind = enum { literal_header, huffman_header, plan, tree, rle, predefined, sequence_base, reference };
const Event = struct {
    kind: Kind,
    args: [5]usize = @splat(0),
    result: ?usize = null,
    failure: ?anyerror = null,
    frequencies: [256]u32 = @splat(0),
    bits: [256]u8 = @splat(0),
};
const Log = std.ArrayList(Event);

fn ObservedCodec(comptime Codec: type, comptime fail_header: bool) type {
    const Plan = @typeInfo(@TypeOf(Codec.CostCodec.planFromFrequencies(@as(*const [256]u32, undefined)))).optional.child;
    return struct {
        pub const Error = Codec.CostCodec.Error;
        pub const optimal_huffman_bits = Codec.CostCodec.optimal_huffman_bits;
        pub const minimum_tree_bytes = Codec.CostCodec.minimum_tree_bytes;
        // Contextless codec callbacks borrow this test-owned observer while a
        // single operation runs. It is never stored in a production cache.
        var observer: ?*Log = null;
        pub fn observe(log: *Log) void {
            observer = log;
        }
        pub fn detach() void {
            observer = null;
        }
        fn record(event: Event) void {
            const log = observer orelse @panic("missing external callback observer");
            log.append(std.testing.allocator, event) catch @panic("observer allocation failed");
        }
        fn resultEvent(kind: Kind, args: [5]usize, result: Error!usize) Error!usize {
            var event: Event = .{ .kind = kind, .args = args };
            if (result) |value| event.result = value else |err| event.failure = err;
            record(event);
            return result;
        }
        pub fn literalHeaderLen(length: usize) Error!usize {
            return resultEvent(.literal_header, .{ length, 0, 0, 0, 0 }, if (fail_header) error.IntegerOverflow else Codec.CostCodec.literalHeaderLen(length));
        }
        pub fn huffmanHeaderLen(regenerated: usize, compressed: usize) Error!usize {
            return resultEvent(.huffman_header, .{ regenerated, compressed, 0, 0, 0 }, Codec.CostCodec.huffmanHeaderLen(regenerated, compressed));
        }
        pub fn planFromFrequencies(frequencies: *const [256]u32) ?Plan {
            const plan = Codec.CostCodec.planFromFrequencies(frequencies);
            var event: Event = .{ .kind = .plan, .frequencies = frequencies.* };
            if (plan) |value| {
                event.result = value.max_symbol;
                event.bits = value.bit_counts;
            }
            record(event);
            return plan;
        }
        pub fn treeLen(plan: *const Plan) Error!?usize {
            const result = Codec.CostCodec.treeLen(plan);
            var event: Event = .{ .kind = .tree, .args = .{ plan.max_symbol, plan.max_bit_count, 0, 0, 0 }, .bits = plan.bit_counts };
            if (result) |value| event.result = value else |err| event.failure = err;
            record(event);
            return result;
        }
        pub fn rlePayloadLen(prefix: usize, offset: usize, match: usize, section: usize) Error!usize {
            return resultEvent(.rle, .{ prefix, offset, match, section, 0 }, Codec.CostCodec.rlePayloadLen(prefix, offset, match, section));
        }
        pub fn predefinedPayloadLen(prefix: usize, offset: usize, match: usize, section: usize) Error!usize {
            return resultEvent(.predefined, .{ prefix, offset, match, section, 0 }, Codec.CostCodec.predefinedPayloadLen(prefix, offset, match, section));
        }
        pub fn singleSequenceBaseLen(prefix: usize, offset: usize, match: usize) Error!usize {
            return resultEvent(.sequence_base, .{ prefix, offset, match, 0, 0 }, Codec.CostCodec.singleSequenceBaseLen(prefix, offset, match));
        }
        pub fn referenceCost(block: []const u8, prefix: usize, offset: usize, match: usize, tail: usize) Error!usize {
            return resultEvent(.reference, .{ prefix, offset, match, tail, block.len }, if (fail_header) error.IntegerOverflow else Codec.referenceCost(block, prefix, offset, match, tail));
        }
    };
}

fn equalResult(expected: anytype, actual: anytype) !void {
    if (expected) |value| try std.testing.expectEqualDeep(value, try actual) else |err| try std.testing.expectError(err, actual);
}

fn equalExactState(on: anytype, off: anytype) !void {
    try std.testing.expectEqualDeep(on.histogram, off.histogram);
    try std.testing.expectEqualSlices(u8, on.block, off.block);
    try std.testing.expectEqualDeep(on.tree_entry, off.tree_entry);
}
fn equalWinnerState(on: anytype, off: anytype) !void {
    try equalExactState(on.inner, off.inner);
    try std.testing.expectEqualDeep(on.certificate, off.certificate);
}

fn fill(block: []u8) void {
    for (block, 0..) |*byte, index| byte.* = if (index % 8 < 5) 'a' else if (index % 8 < 7) 'b' else 'c';
}

fn exactContracts(comptime Codec: type) !void {
    const Observed = ObservedCodec(Codec, false);
    defer Observed.detach();
    var on_log: Log = .empty;
    defer on_log.deinit(std.testing.allocator);
    var off_log: Log = .empty;
    defer off_log.deinit(std.testing.allocator);
    var block: [8192]u8 = undefined;
    fill(&block);
    block[1500] = 255;
    var on = try exact.CacheWithAccounting(Observed, true).init(&block);
    var off = try exact.CacheWithAccounting(Observed, false).init(&block);
    try std.testing.expect(@TypeOf(off.work) == void);
    try std.testing.expect(@sizeOf(@TypeOf(on)) < 8 * 1024 and @sizeOf(@TypeOf(off)) < 8 * 1024);
    for ([_][4]usize{ .{ 1024, 8, 1024, 2048 }, .{ 1025, 8, 1024, 2048 }, .{ 1536, 8, 512, 2048 }, .{ 0, 8, 3, 7169 }, .{ 0, 8, 3, 7168 }, .{ 5, 8, 3, 8192 }, .{ 2, 8, 3, 1 }, .{ 1024, 8, 2, 2048 } }) |query| {
        Observed.observe(&on_log);
        const expected = on.payloadLen(query[0], query[1], query[2], query[3]);
        Observed.observe(&off_log);
        const actual = off.payloadLen(query[0], query[1], query[2], query[3]);
        try equalResult(expected, actual);
        try std.testing.expectEqualDeep(on_log.items, off_log.items);
        try equalExactState(on, off);
    }
    Observed.observe(&on_log);
    const prepared_on = try on.prepareLiterals(1024, 2048);
    Observed.observe(&off_log);
    const prepared_off = try off.prepareLiterals(1024, 2048);
    try std.testing.expectEqualDeep(prepared_on, prepared_off);
    Observed.observe(&on_log);
    const cost_on = on.payloadCostPrepared(1024, 8, 1024, 2048, &prepared_on);
    Observed.observe(&off_log);
    const cost_off = off.payloadCostPrepared(1024, 8, 1024, 2048, &prepared_off);
    try equalResult(cost_on, cost_off);
    try std.testing.expectEqualDeep(on_log.items, off_log.items);
    try equalExactState(on, off);
    var references: usize = 0;
    for (off_log.items) |event| references += @intFromBool(event.kind == .reference);
    try std.testing.expect(references != 0);

    // Histogram work counters remain part of both types' unchanged admission
    // contract. An overflow must preserve its full range/frequency state.
    on.histogram.scanned_bytes = std.math.maxInt(u64);
    off.histogram.scanned_bytes = std.math.maxInt(u64);
    const prior_on = on.histogram;
    const prior_off = off.histogram;
    Observed.observe(&on_log);
    const overflow_on = on.prepareLiterals(1025, 2049);
    Observed.observe(&off_log);
    const overflow_off = off.prepareLiterals(1025, 2049);
    try std.testing.expectError(error.IntegerOverflow, overflow_on);
    try std.testing.expectError(error.IntegerOverflow, overflow_off);
    try std.testing.expectEqualDeep(prior_on, on.histogram);
    try std.testing.expectEqualDeep(prior_off, off.histogram);
    try std.testing.expectEqualDeep(on_log.items, off_log.items);
}

fn winnerContracts(comptime Codec: type) !void {
    const Observed = ObservedCodec(Codec, false);
    defer Observed.detach();
    var block: [8192]u8 = undefined;
    fill(&block);
    block[1500] = 255;
    inline for (.{ winner.Mode.shadow, winner.Mode.prune }) |mode| {
        var on_log: Log = .empty;
        defer on_log.deinit(std.testing.allocator);
        var off_log: Log = .empty;
        defer off_log.deinit(std.testing.allocator);
        var on = try winner.CacheWithAccounting(Observed, mode, true).init(&block);
        var off = try winner.CacheWithAccounting(Observed, mode, false).init(&block);
        try std.testing.expect(@TypeOf(off.bound_work) == void and @TypeOf(off.certificate_age) == void);
        try std.testing.expect(@TypeOf(off.inner.work) == void);
        try std.testing.expect(@sizeOf(@TypeOf(on)) < 8 * 1024 and @sizeOf(@TypeOf(off)) < 8 * 1024);
        const impossible: winner.Winner = .{ .payload_len = 1, .match_len = 65536 };
        const loose: winner.Winner = .{ .payload_len = std.math.maxInt(usize), .match_len = 0 };
        for ([_][4]usize{ .{ 1024, 8, 1024, 2048 }, .{ 1025, 8, 1024, 2048 }, .{ 1026, 8, 1024, 2048 }, .{ 1536, 8, 512, 2048 }, .{ 1537, 8, 512, 2048 }, .{ 5, 8, 3, 4 }, .{ 1536, 8, 2, 2048 } }, 0..) |query, index| {
            const incumbent: ?winner.Winner = if (index == 0) null else if (index == 4) loose else impossible;
            Observed.observe(&on_log);
            const expected = on.payloadForWinner(query[0], query[1], query[2], query[3], incumbent);
            Observed.observe(&off_log);
            const actual = off.payloadForWinner(query[0], query[1], query[2], query[3], incumbent);
            try equalResult(expected, actual);
            try std.testing.expectEqualDeep(on_log.items, off_log.items);
            try equalWinnerState(on, off);
            if (index == 0) try std.testing.expect(on.certificate != null);
        }
        try std.testing.expect(on.bound_work.would_reject != 0);
        if (mode == .shadow) try std.testing.expectEqual(@as(u64, 0), on.bound_work.rejected) else try std.testing.expect(on.bound_work.rejected != 0);
        try std.testing.expectEqual(@as(u64, 0), on.inner.work.reference_mismatches);

        // Use an independently assembled same-support bit relaxation to set an
        // equal incumbent. A longer match must be priced in both configurations.
        const witness = on.certificate.?;
        var frequencies: [256]u32 = @splat(0);
        for (block[0..1537]) |byte| frequencies[byte] += 1;
        for (block[2048..]) |byte| frequencies[byte] += 1;
        const analysis = try witness.analyze(&frequencies);
        const streams: usize = 4;
        const stream_bits: usize = @intCast(analysis.bit_lower_bound.?);
        const rounded = (stream_bits + streams) / 8 + @intFromBool((stream_bits + streams) % 8 != 0) + 6;
        const huf = try Codec.CostCodec.huffmanHeaderLen(7681, 1) + Codec.CostCodec.minimum_tree_bytes + rounded;
        const raw = try Codec.CostCodec.literalHeaderLen(7681) + 7681;
        const lower = try Codec.CostCodec.singleSequenceBaseLen(1537, 8, 512) + @min(raw, huf);
        const equal_longer: winner.Winner = .{ .payload_len = lower, .match_len = 511 };
        Observed.observe(&on_log);
        const expected = on.payloadForWinner(1537, 8, 512, 2048, equal_longer);
        Observed.observe(&off_log);
        const actual = off.payloadForWinner(1537, 8, 512, 2048, equal_longer);
        try equalResult(expected, actual);
        try std.testing.expect((try expected) != null);
        try std.testing.expectEqualDeep(on_log.items, off_log.items);
        try equalWinnerState(on, off);
        try std.testing.expect(on.bound_work.equality_longer_retained != 0);
    }
}

fn nullRawAndErrors(comptime Codec: type) !void {
    const Observed = ObservedCodec(Codec, false);
    defer Observed.detach();
    var block: [1024]u8 = undefined;
    inline for (.{ winner.Mode.shadow, winner.Mode.prune }) |mode| {
        for (0..3) |pattern| {
            for (&block, 0..) |*byte, symbol| byte.* = if (pattern == 0) @truncate(symbol) else if (pattern == 1) 'a' else @intCast('a' + symbol % 3);
            const input = if (pattern == 2) block[0..63] else block[0..];
            var on = try winner.CacheWithAccounting(Observed, mode, true).init(input);
            var off = try winner.CacheWithAccounting(Observed, mode, false).init(input);
            var on_log: Log = .empty;
            defer on_log.deinit(std.testing.allocator);
            var off_log: Log = .empty;
            defer off_log.deinit(std.testing.allocator);
            Observed.observe(&on_log);
            const expected = on.payloadForWinner(0, 8, 3, 0, null);
            Observed.observe(&off_log);
            const actual = off.payloadForWinner(0, 8, 3, 0, null);
            try equalResult(expected, actual);
            try std.testing.expectEqualDeep(on_log.items, off_log.items);
            try equalWinnerState(on, off);
            try std.testing.expect(on.certificate == null);
        }
    }
    const Broken = ObservedCodec(Codec, true);
    defer Broken.detach();
    fill(&block);
    inline for (.{ winner.Mode.shadow, winner.Mode.prune }) |mode| {
        var on = try winner.CacheWithAccounting(Broken, mode, true).init(&block);
        var off = try winner.CacheWithAccounting(Broken, mode, false).init(&block);
        var on_log: Log = .empty;
        defer on_log.deinit(std.testing.allocator);
        var off_log: Log = .empty;
        defer off_log.deinit(std.testing.allocator);
        Broken.observe(&on_log);
        const expected = on.payloadForWinner(17, 8, 64, 81, null);
        Broken.observe(&off_log);
        const actual = off.payloadForWinner(17, 8, 64, 81, null);
        try std.testing.expectError(error.IntegerOverflow, expected);
        try std.testing.expectError(error.IntegerOverflow, actual);
        try std.testing.expectEqualDeep(on_log.items, off_log.items);
        try equalWinnerState(on, off);
        try std.testing.expectEqual(@as(u64, 1), on.inner.histogram.update_count);
        try std.testing.expectEqual(@as(u64, 1), on.inner.work.cost_queries);
        try std.testing.expectEqual(@as(u64, 1), on.inner.work.reference_checks);
        try std.testing.expect(on.certificate == null);
    }
}

fn saturate(value: anytype) void {
    inline for (@typeInfo(@TypeOf(value.*)).@"struct".fields) |field| {
        switch (@typeInfo(field.type)) {
            .int => @field(value.*, field.name) = std.math.maxInt(u64),
            .array => @memset(&@field(value.*, field.name), std.math.maxInt(u64)),
            else => @compileError("unexpected accounting field"),
        }
    }
}

fn wrapperCompatibility(comptime Codec: type) !void {
    const Observed = ObservedCodec(Codec, false);
    defer Observed.detach();
    var block: [4096]u8 = undefined;
    fill(&block);
    var explicit = try exact.CacheWithAccounting(Observed, true).init(&block);
    var wrapper = try exact.Cache(Observed).init(&block);
    try std.testing.expect(@TypeOf(explicit) == @TypeOf(wrapper));
    var log: Log = .empty;
    defer log.deinit(std.testing.allocator);
    Observed.observe(&log);
    _ = try explicit.payloadLen(512, 8, 512, 1024);
    _ = try wrapper.payloadLen(512, 8, 512, 1024);
    try std.testing.expectEqualDeep(explicit, wrapper);
    saturate(&explicit.work);
    saturate(&wrapper.work);
    _ = try explicit.payloadLen(513, 8, 512, 1024);
    _ = try wrapper.payloadLen(513, 8, 512, 1024);
    try std.testing.expectEqualDeep(explicit, wrapper);
    try std.testing.expectEqual(std.math.maxInt(u64), explicit.work.cost_queries);
    inline for (.{ winner.Mode.shadow, winner.Mode.prune }) |mode| {
        var on = try winner.CacheWithAccounting(Observed, mode, true).init(&block);
        var old_wrapper = try winner.Cache(Observed, mode).init(&block);
        try std.testing.expect(@TypeOf(on) == @TypeOf(old_wrapper));
        _ = try on.payloadForWinner(512, 8, 512, 1024, null);
        _ = try old_wrapper.payloadForWinner(512, 8, 512, 1024, null);
        saturate(&on.inner.work);
        saturate(&old_wrapper.inner.work);
        saturate(&on.bound_work);
        saturate(&old_wrapper.bound_work);
        on.certificate_age = std.math.maxInt(u64);
        old_wrapper.certificate_age = std.math.maxInt(u64);
        const incumbent: winner.Winner = .{ .payload_len = 1, .match_len = 4096 };
        try equalResult(on.payloadForWinner(513, 8, 512, 1024, incumbent), old_wrapper.payloadForWinner(513, 8, 512, 1024, incumbent));
        try std.testing.expectEqualDeep(on, old_wrapper);
        try std.testing.expectEqual(std.math.maxInt(u64), on.bound_work.queries);
        try std.testing.expectEqual(std.math.maxInt(u64), on.certificate_age);
    }
}

fn finderCallbacks(comptime Codec: type) !void {
    const Observed = ObservedCodec(Codec, false);
    defer Observed.detach();
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
        var on = try winner.CacheWithAccounting(Observed, mode, true).init(&block);
        var off = try winner.CacheWithAccounting(Observed, mode, false).init(&block);
        var on_log: Log = .empty;
        defer on_log.deinit(std.testing.allocator);
        var off_log: Log = .empty;
        defer off_log.deinit(std.testing.allocator);
        for ([_]usize{ 0, 17, 2048, 4200, 8000 }) |start| {
            Observed.observe(&on_log);
            const expected = try Codec.cachedFinder(&block, start, &on);
            Observed.observe(&off_log);
            const actual = try Codec.cachedFinder(&block, start, &off);
            try std.testing.expectEqualDeep(expected, actual);
            try std.testing.expectEqualDeep(try Codec.referenceFinder(&block, start), actual);
            try std.testing.expectEqualDeep(on_log.items, off_log.items);
            try equalWinnerState(on, off);
        }
        try std.testing.expect(on_log.items.len != 0);
        var references: usize = 0;
        for (off_log.items) |event| references += @intFromBool(event.kind == .reference);
        try std.testing.expect(references != 0);
    }
}

pub fn contracts(comptime Codec: type) !void {
    try exactContracts(Codec);
    try winnerContracts(Codec);
    try nullRawAndErrors(Codec);
    try wrapperCompatibility(Codec);
    try finderCallbacks(Codec);
}

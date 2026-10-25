//! Independent wide-reduction oracle. Totals use u128 scalar arithmetic;
//! comparison covers complete errors and Analysis fields, not only the bound.
const std = @import("std");
const reduction = @import("frequency_reduction.zig");

fn scalarInspection(comptime n: usize, current: *const [n]u32, previous: *const [n]u32, maximum: u32) reduction.Error!reduction.Inspection {
    var total: u128 = 0;
    var negative: u128 = 0;
    var active: usize = 0;
    var same = true;
    for (0..n) |index| {
        const value = current[index];
        const prior = previous[index];
        total += value;
        active += @intFromBool(value != 0);
        same = same and ((value != 0) == (prior != 0));
        if (prior > value) negative += @as(u128, prior) - value;
    }
    // Domain admission precedes negative-mass narrowing and support fallback.
    if (total > maximum) return error.InvalidFrequencyTotal;
    if (negative > std.math.maxInt(u32)) return error.IntegerOverflow;
    return .{ .total = @intCast(total), .active = active, .same_support = same, .negative_delta = @intCast(negative) };
}

fn oracleAnalysis(comptime Bound: type, comptime n: usize, comptime bits: u8, certificate: anytype, current: *const [n]u32) Bound.Error!Bound.Analysis {
    const info = try scalarInspection(n, current, &certificate.frequencies, Bound.max_total_frequency);
    var result: Bound.Analysis = .{ .same_support = info.same_support, .current_total = info.total, .current_active_symbols = info.active, .negative_delta = info.negative_delta, .bit_lower_bound = null };
    if (!info.same_support) return result;
    if (certificate.trusted_lower_bits > std.math.maxInt(i64)) return error.IntegerOverflow;
    const prior: i128 = certificate.trusted_lower_bits;
    const changed = prior + @as(i128, info.total) - certificate.total_frequency;
    if (changed > std.math.maxInt(i64) or changed < std.math.minInt(i64)) return error.IntegerOverflow;
    const adjusted = changed - (@as(i128, bits) - 1) * info.negative_delta;
    if (adjusted > std.math.maxInt(i64) or adjusted < std.math.minInt(i64)) return error.IntegerOverflow;
    result.bit_lower_bound = @intCast(@max(@as(i128, info.total), adjusted));
    return result;
}

fn compareAnalysis(comptime Bound: type, comptime n: usize, comptime bits: u8, certificate: anytype, current: *const [n]u32) !void {
    const expected = oracleAnalysis(Bound, n, bits, certificate, current);
    const scalar = certificate.analyzeReference(current);
    const actual = certificate.analyze(current);
    if (expected) |value| {
        try std.testing.expectEqualDeep(value, try scalar);
        try std.testing.expectEqualDeep(value, try actual);
    } else |err| {
        try std.testing.expectError(err, scalar);
        try std.testing.expectError(err, actual);
    }
}

fn compareKernel(current: *const [256]u32, previous: *const [256]u32, maximum: u32) !void {
    const expected = scalarInspection(256, current, previous, maximum);
    const actual = reduction.inspect256(current, previous, maximum);
    if (expected) |value| try std.testing.expectEqualDeep(value, try actual) else |err| try std.testing.expectError(err, actual);
}

fn wideVectors(comptime Bound: type) !void {
    const Cert = Bound.Certificate(256, 11);
    const old: [256]u32 = @splat(17);
    // Equal frequencies on 256 symbols have the exact balanced 8-bit optimum.
    const certificate = try Cert.init(&old, 256 * 17 * 8);
    try std.testing.expect(@sizeOf(Cert) < 2 * 1024);
    var random: u32 = 0x6a09e667;
    for (0..128) |round| {
        var current: [256]u32 = undefined;
        for (&current, 0..) |*frequency, symbol| {
            random = random *% 1664525 +% 1013904223;
            frequency.* = 1 + (random >> 24);
            if (round % 3 == 0 and symbol % 7 == 0) frequency.* = 0;
        }
        try compareAnalysis(Bound, 256, 11, certificate, &current);
        try compareKernel(&current, &old, Bound.max_total_frequency);
    }
    var largest: [256]u32 = @splat(512);
    try compareAnalysis(Bound, 256, 11, certificate, &largest);
    try compareKernel(&largest, &old, Bound.max_total_frequency);
    largest[255] += 1;
    try std.testing.expectError(error.InvalidFrequencyTotal, certificate.analyze(&largest));
    try compareAnalysis(Bound, 256, 11, certificate, &largest);
    try compareKernel(&largest, &old, Bound.max_total_frequency);

    var huge: [256]u32 = @splat(@as(u32, 1) << 24);
    // The real total is 2^32. A u32 lane reduction must not wrap it to zero.
    try compareAnalysis(Bound, 256, 11, certificate, &huge);
    try compareKernel(&huge, &old, std.math.maxInt(u32));
    @memset(&huge, std.math.maxInt(u32));
    try compareAnalysis(Bound, 256, 11, certificate, &huge);
    try compareKernel(&huge, &old, Bound.max_total_frequency);
    try compareKernel(&huge, &old, std.math.maxInt(u32));

    var sparse_old: [256]u32 = @splat(0);
    var replacement: [256]u32 = @splat(0);
    for (0..128) |index| {
        sparse_old[index * 2] = 2;
        replacement[index * 2 + 1] = 2;
    }
    const sparse = try Cert.init(&sparse_old, 128 * 2 * 7);
    try compareAnalysis(Bound, 256, 11, sparse, &replacement);
    const changed = try sparse.analyze(&replacement);
    try std.testing.expectEqual(@as(usize, 128), changed.current_active_symbols);
    try std.testing.expect(!changed.same_support);
    try std.testing.expectEqual(@as(?u64, null), changed.bit_lower_bound);
    @memset(&replacement, 0);
    try compareAnalysis(Bound, 256, 11, sparse, &replacement);
    replacement[0] = 17;
    try compareAnalysis(Bound, 256, 11, sparse, &replacement);
    replacement[1] = std.math.maxInt(u32);
    try std.testing.expectError(error.InvalidFrequencyTotal, sparse.analyze(&replacement));
    try compareAnalysis(Bound, 256, 11, sparse, &replacement);
}

fn corruptedPriorities(comptime Bound: type) !void {
    const Cert = Bound.Certificate(256, 11);
    const old: [256]u32 = @splat(1);
    var certificate = try Cert.init(&old, 2048);
    // Public state may be numerically malformed. Total admission still wins
    // over negative-mass overflow; support mismatch cannot swallow that error.
    @memset(&certificate.frequencies, std.math.maxInt(u32));
    var current: [256]u32 = @splat(0);
    try std.testing.expectError(error.IntegerOverflow, certificate.analyze(&current));
    try compareAnalysis(Bound, 256, 11, certificate, &current);
    try compareKernel(&current, &certificate.frequencies, Bound.max_total_frequency);
    @memset(&current, @as(u32, 1) << 24);
    try std.testing.expectError(error.InvalidFrequencyTotal, certificate.analyze(&current));
    try compareAnalysis(Bound, 256, 11, certificate, &current);
    try compareKernel(&current, &certificate.frequencies, std.math.maxInt(u32));
    @memset(&current, 1);
    try std.testing.expectError(error.IntegerOverflow, certificate.analyze(&current));
    try compareAnalysis(Bound, 256, 11, certificate, &current);

    @memset(&certificate.frequencies, 0);
    certificate.frequencies[0] = std.math.maxInt(u32);
    @memset(&current, 0);
    try compareAnalysis(Bound, 256, 11, certificate, &current);
    try compareKernel(&current, &certificate.frequencies, Bound.max_total_frequency);
    try std.testing.expectEqual(std.math.maxInt(u32), (try certificate.analyze(&current)).negative_delta);
    certificate.frequencies[1] = 1;
    try std.testing.expectError(error.IntegerOverflow, certificate.analyze(&current));
    try compareAnalysis(Bound, 256, 11, certificate, &current);

    certificate = try Cert.init(&old, 2048);
    certificate.trusted_lower_bits = std.math.maxInt(u64);
    try compareAnalysis(Bound, 256, 11, certificate, &old);
    @memset(&current, 0);
    // Support mismatch occurs after valid mass reduction but before the old
    // scalar conversion, so the invalid trusted scalar is not examined here.
    try compareAnalysis(Bound, 256, 11, certificate, &current);
    certificate.trusted_lower_bits = std.math.maxInt(i64);
    certificate.total_frequency = 0;
    try compareAnalysis(Bound, 256, 11, certificate, &old);
}

fn genericFallbacks(comptime Bound: type) !void {
    inline for (.{ 2, 3, 4, 257 }) |n| {
        inline for (.{ 1, 3, 11, 255 }) |bits| {
            const Cert = Bound.Certificate(n, bits);
            var old: [n]u32 = @splat(0);
            const active = if (bits == 1) 2 else if (bits == 3) @min(n, 4) else n;
            @memset(old[0..active], 1);
            // Exact cost of a balanced tree for an equal-weight alphabet.
            var width: usize = 0;
            var capacity: usize = 1;
            while (capacity < active) : (width += 1) capacity *= 2;
            const cost = active * (width + 1) - capacity;
            var certificate = try Cert.init(&old, cost);
            try std.testing.expect(@sizeOf(Cert) < 2 * 1024);
            try compareAnalysis(Bound, n, bits, certificate, &old);
            var current = old;
            for (current[0..active], 0..) |*frequency, index| frequency.* = @intCast(1 + index % 19);
            try compareAnalysis(Bound, n, bits, certificate, &current);
            current[0] = 0;
            try compareAnalysis(Bound, n, bits, certificate, &current);
            const before = certificate;
            @memset(&current, 0);
            try std.testing.expectError(error.InvalidSupport, certificate.publish(&current, 1));
            try std.testing.expectEqualDeep(before, certificate);
            current[0] = 131072;
            current[1] = 1;
            try std.testing.expectError(error.InvalidFrequencyTotal, certificate.publish(&current, 131072));
            try std.testing.expectEqualDeep(before, certificate);
            try std.testing.expectError(error.InvalidCertificateCost, certificate.publish(&old, 0));
            try std.testing.expectEqualDeep(before, certificate);
        }
    }
    // Vector selection also leaves extreme B values and their scalar formula
    // unchanged on the 256-symbol specialization itself.
    inline for (.{ 1, 3, 255 }) |bits| {
        var old: [256]u32 = @splat(0);
        old[0] = 7;
        old[255] = 11;
        const certificate = try Bound.Certificate(256, bits).init(&old, 18);
        old[0] = 3;
        old[255] = 14;
        try compareAnalysis(Bound, 256, bits, certificate, &old);
    }
}

fn misalignedVectors(comptime Bound: type) !void {
    var storage: [257]u32 align(32) = undefined;
    const current: *[256]u32 = storage[1..257];
    var previous_storage: [258]u32 align(32) = undefined;
    const previous: *[256]u32 = previous_storage[2..258];
    try std.testing.expectEqual(@as(usize, 4), @intFromPtr(current) % 32);
    try std.testing.expectEqual(@as(usize, 8), @intFromPtr(previous) % 32);
    @memset(previous, 17);
    const certificate = try Bound.Certificate(256, 11).init(previous, 256 * 17 * 8);
    for (current, 0..) |*frequency, symbol| frequency.* = @intCast(1 + symbol % 31);
    try compareKernel(current, previous, Bound.max_total_frequency);
    try compareAnalysis(Bound, 256, 11, certificate, current);
    @memset(current, @as(u32, 1) << 24);
    try compareKernel(current, previous, std.math.maxInt(u32));
    try compareAnalysis(Bound, 256, 11, certificate, current);
}

fn widePublication(comptime Bound: type) !void {
    const Cert = Bound.Certificate(256, 11);
    const old: [256]u32 = @splat(1);
    var certificate = try Cert.init(&old, 2048);
    const before = certificate;
    var invalid: [256]u32 = @splat(@as(u32, 1) << 24);
    try std.testing.expectError(error.InvalidFrequencyTotal, Cert.init(&invalid, 2048));
    try std.testing.expectError(error.InvalidFrequencyTotal, certificate.publish(&invalid, 2048));
    try std.testing.expectEqualDeep(before, certificate);
    @memset(&invalid, 0);
    try std.testing.expectError(error.InvalidSupport, Cert.init(&invalid, 1));
    try std.testing.expectError(error.InvalidSupport, certificate.publish(&invalid, 1));
    try std.testing.expectEqualDeep(before, certificate);
    try std.testing.expectError(error.InvalidCertificateCost, certificate.publish(&old, std.math.maxInt(u64)));
    try std.testing.expectEqualDeep(before, certificate);
    const largest: [256]u32 = @splat(512);
    try certificate.publish(&largest, 131072 * 8);
    try std.testing.expectEqual(@as(u32, 131072), certificate.total_frequency);
    try compareAnalysis(Bound, 256, 11, certificate, &largest);
}

pub fn contracts(comptime Bound: type) !void {
    try wideVectors(Bound);
    try corruptedPriorities(Bound);
    try genericFallbacks(Bound);
    try misalignedVectors(Bound);
    try widePublication(Bound);
}

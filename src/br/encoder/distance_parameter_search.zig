const std = @import("std");
const command_plan = @import("command_plan.zig");
const complex_prefix = @import("complex_prefix.zig");
const distance = @import("distance.zig");

pub const max_alphabet_size: usize = 16 + 120 + (48 << 3);

pub const DistanceFrequency = struct {
    semantic_distance: usize,
    frequency: u32,
};

/// Short-distance symbols are already resolved by the caller and contribute to
/// every candidate's Huffman tree unchanged. `distances` contains only semantic
/// explicit distances that must be recoded for each parameter shape.
pub const Input = struct {
    format: distance.Format = .standard,
    distances: []const usize = &.{},
    distance_frequencies: []const DistanceFrequency = &.{},
    short_symbol_frequencies: [16]u32 = @splat(0),
};

/// Caller-owned dense work area. Every active field is initialized by `score`,
/// so callers may construct this as `undefined` and reuse it across searches.
pub fn ScratchFor(comptime capacity: usize) type {
    return struct {
        frequencies: [capacity]u32,
        alphabet: command_plan.PrefixAlphabetFor(capacity),
        lengths: [capacity]u4,
    };
}
pub const Scratch = ScratchFor(max_alphabet_size);
pub const LargeScratch = ScratchFor(544);

pub const Candidate = struct {
    parameters: distance.Parameters,
    tree_bits: u64,
    payload_bits: u64,
    extra_bits: u64,

    pub fn totalBits(self: Candidate) u64 {
        return self.tree_bits + self.payload_bits + self.extra_bits;
    }
};

pub const Selection = struct {
    baseline: Candidate,
    alternative: Candidate,

    /// Equal-cost candidates deliberately retain the established (0, 0)
    /// baseline, keeping selection deterministic and avoiding neutral rewrites.
    pub fn preferred(self: Selection) Candidate {
        return if (self.alternative.totalBits() < self.baseline.totalBits())
            self.alternative
        else
            self.baseline;
    }
};

/// Score all 64 RFC 7932 parameter shapes. The result retains both the fixed
/// (NPOSTFIX=0, NDIRECT=0) baseline and the best non-baseline candidate. This is
/// a score-only stage: no Brotli wire bytes are written.
pub fn select(allocator: std.mem.Allocator, input: Input, scratch: anytype) !Selection {
    const baseline_parameters = distance.Parameters.init(0, 0);
    const baseline = try score(allocator, input, baseline_parameters, scratch);
    var alternative: ?Candidate = null;

    for (0..4) |npostfix_value| {
        const npostfix: u2 = @intCast(npostfix_value);
        for (0..16) |ndirect_high_value| {
            const ndirect_high: u4 = @intCast(ndirect_high_value);
            if (npostfix == 0 and ndirect_high == 0) continue;
            const candidate = score(
                allocator,
                input,
                distance.Parameters.init(npostfix, ndirect_high),
                scratch,
            ) catch |err| switch (err) {
                // Large Window exposes only whole signed-safe groups. A shape
                // unable to express this stream is not a search candidate.
                error.InvalidDistance => if (input.format == .large_window) continue else return err,
                else => return err,
            };
            if (alternative == null or candidate.totalBits() < alternative.?.totalBits())
                alternative = candidate;
        }
    }

    return .{ .baseline = baseline, .alternative = alternative orelse baseline };
}

pub fn selectAlloc(allocator: std.mem.Allocator, input: Input) !Selection {
    if (input.format == .large_window) {
        const scratch = try allocator.create(LargeScratch);
        defer allocator.destroy(scratch);
        return select(allocator, input, scratch);
    }
    const scratch = try allocator.create(Scratch);
    defer allocator.destroy(scratch);
    return select(allocator, input, scratch);
}

pub fn selectDistances(allocator: std.mem.Allocator, distances: []const usize, scratch: anytype) !Selection {
    return select(allocator, .{ .distances = distances }, scratch);
}

/// Compute the exact distance-tree, Huffman payload, and extra-bit cost for one
/// legal parameter shape. The common six NPOSTFIX/NDIRECT header bits are
/// intentionally omitted because they cannot affect candidate ordering.
pub fn score(allocator: std.mem.Allocator, input: Input, parameters: distance.Parameters, scratch: anytype) !Candidate {
    const capacity = scratch.frequencies.len;
    const active_size = parameters.activeAlphabetSize(input.format);
    const wire_size = parameters.wireAlphabetSize(input.format);
    if (active_size > capacity) return error.InvalidDistance;
    @memset(&scratch.frequencies, 0);
    var event_count: u64 = 0;
    for (input.short_symbol_frequencies, 0..) |frequency, symbol| {
        scratch.frequencies[symbol] = frequency;
        event_count += frequency;
    }

    var extra_bits: u64 = 0;
    for (input.distances) |semantic_distance| {
        const encoding = distance.encodeWithFormat(semantic_distance, parameters, input.format) orelse
            return error.InvalidDistance;
        if (encoding.symbol >= active_size or encoding.symbol >= capacity)
            return error.InvalidDistance;
        if (scratch.frequencies[encoding.symbol] == std.math.maxInt(u32))
            return error.FrequencyOverflow;
        scratch.frequencies[encoding.symbol] += 1;
        event_count += 1;
        extra_bits = std.math.add(u64, extra_bits, encoding.extra_bits) catch
            return error.IntegerOverflow;
    }
    for (input.distance_frequencies) |entry| {
        if (entry.frequency == 0) return error.InvalidDistance;
        const encoding = distance.encodeWithFormat(entry.semantic_distance, parameters, input.format) orelse
            return error.InvalidDistance;
        if (encoding.symbol >= active_size or encoding.symbol >= capacity)
            return error.InvalidDistance;
        scratch.frequencies[encoding.symbol] = std.math.add(
            u32,
            scratch.frequencies[encoding.symbol],
            entry.frequency,
        ) catch return error.FrequencyOverflow;
        event_count = std.math.add(u64, event_count, entry.frequency) catch
            return error.IntegerOverflow;
        extra_bits = std.math.add(
            u64,
            extra_bits,
            @as(u64, encoding.extra_bits) * entry.frequency,
        ) catch return error.IntegerOverflow;
    }
    if (event_count == 0) return error.EmptyDistanceStream;

    try command_plan.alphabetFromFrequenciesInto(
        capacity,
        &scratch.alphabet,
        &scratch.frequencies,
    );
    scratch.lengths = try scratch.alphabet.codeLengths(&scratch.frequencies);

    var payload_bits: u64 = 0;
    for (scratch.frequencies, scratch.lengths) |frequency, length|
        payload_bits += @as(u64, frequency) * length;

    const tree_bits: u64 = if (scratch.alphabet.len <= 4)
        4 + @as(u64, scratch.alphabet.len) * alphabetBits(wire_size) +
            @intFromBool(scratch.alphabet.len == 4)
    else blk: {
        var highest: usize = 0;
        for (scratch.alphabet.symbols[0..scratch.alphabet.len]) |symbol|
            highest = @max(highest, symbol);
        break :blk try complex_prefix.bitCost(
            allocator,
            active_size,
            &scratch.lengths,
            highest + 1,
        );
    };

    return .{
        .parameters = parameters,
        .tree_bits = tree_bits,
        .payload_bits = payload_bits,
        .extra_bits = extra_bits,
    };
}

fn alphabetBits(alphabet_size: usize) u6 {
    if (alphabet_size <= 1) return 0;
    return @intCast(std.math.log2_int_ceil(usize, alphabet_size));
}

test "distance parameter scores match an independent tree-writing oracle" {
    const distances = [_]usize{ 1, 2, 3, 4, 7, 8, 15, 16, 17, 31, 32, 33, 127, 128, 1023, 1024, 4095, 4096, (@as(usize, 1) << 24) - 1 };
    const input = Input{
        .distances = &distances,
        .short_symbol_frequencies = .{ 11, 7, 5, 3, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    };
    var scratch: Scratch = undefined;
    var oracle_scratch: Scratch = undefined;

    for (0..4) |npostfix_value| {
        const npostfix: u2 = @intCast(npostfix_value);
        for (0..16) |ndirect_high_value| {
            const parameters = distance.Parameters.init(npostfix, @intCast(ndirect_high_value));
            const actual = try score(std.testing.allocator, input, parameters, &scratch);
            const expected = try oracleScore(std.testing.allocator, input, parameters, &oracle_scratch);
            try std.testing.expectEqual(expected, actual);
            try std.testing.expect(actual.parameters.alphabetSize() <= max_alphabet_size);
        }
    }
}

test "distance parameter search selects a stable nonzero postfix winner" {
    const distances = [_]usize{1024} ** 256;
    var scratch: Scratch = undefined;
    const first = try selectDistances(std.testing.allocator, &distances, &scratch);
    const second = try selectDistances(std.testing.allocator, &distances, &scratch);

    try std.testing.expectEqual(first, second);
    try std.testing.expect(first.alternative.totalBits() < first.baseline.totalBits());
    try std.testing.expect(first.preferred().parameters.npostfix != 0);
    try std.testing.expectEqual(first.alternative, first.preferred());
}

test "distance parameter search retains baseline on an exact tie" {
    var scratch: Scratch = undefined;
    const selection = try select(std.testing.allocator, .{
        .distances = &.{},
        .short_symbol_frequencies = .{ 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    }, &scratch);

    try std.testing.expectEqual(selection.baseline.totalBits(), selection.alternative.totalBits());
    try std.testing.expectEqual(distance.Parameters.init(0, 0), selection.preferred().parameters);
}

test "distance parameter search rejects empty and invalid streams" {
    var scratch: Scratch = undefined;
    try std.testing.expectError(
        error.EmptyDistanceStream,
        selectDistances(std.testing.allocator, &.{}, &scratch),
    );
    try std.testing.expectError(
        error.InvalidDistance,
        selectDistances(std.testing.allocator, &.{0}, &scratch),
    );
    const beyond_all_alphabets = distance.Parameters.init(3, 15).maximumDistance() + 1;
    try std.testing.expectError(
        error.InvalidDistance,
        selectDistances(std.testing.allocator, &.{beyond_all_alphabets}, &scratch),
    );
}

test "distance parameter search propagates allocation failures" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const distances = [_]usize{ 7, 31, 127, 511, 2047, 8191 } ** 4;
            _ = try selectAlloc(allocator, .{ .distances = &distances });
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}

test "Br general large window distance scoring uses safe active shapes and wire tree costs" {
    const input: Input = .{
        .format = .large_window,
        .distances = &.{ 1, 2, 3, 7, 31, 511, 65520, 1 << 28 },
    };
    var scratch: LargeScratch = undefined;
    var oracle_scratch: LargeScratch = undefined;
    for (0..4) |postfix| for (0..16) |direct| {
        const parameters = distance.Parameters.init(@intCast(postfix), @intCast(direct));
        const actual = try score(std.testing.allocator, input, parameters, &scratch);
        const expected = try oracleScore(std.testing.allocator, input, parameters, &oracle_scratch);
        try std.testing.expectEqual(expected, actual);
    };
    const selected = try selectAlloc(std.testing.allocator, input);
    try std.testing.expect(selected.preferred().totalBits() <= selected.baseline.totalBits());
    const last = distance.Parameters.init(0, 0).maximumDistanceForFormat(.large_window);
    _ = try selectAlloc(std.testing.allocator, .{ .format = .large_window, .distances = &.{last} });
    try std.testing.expectError(error.InvalidDistance, selectAlloc(std.testing.allocator, .{
        .format = .large_window,
        .distances = &.{distance.safe_max_distance + 1},
    }));
}

fn oracleScore(allocator: std.mem.Allocator, input: Input, parameters: distance.Parameters, scratch: anytype) !Candidate {
    @memset(&scratch.frequencies, 0);
    var extra_bits: u64 = 0;
    for (input.short_symbol_frequencies, 0..) |frequency, symbol|
        scratch.frequencies[symbol] = frequency;
    for (input.distances) |semantic_distance| {
        const encoding = distance.encodeWithFormat(semantic_distance, parameters, input.format) orelse
            return error.InvalidDistance;
        scratch.frequencies[encoding.symbol] += 1;
        extra_bits += encoding.extra_bits;
    }
    for (input.distance_frequencies) |entry| {
        const encoding = distance.encodeWithFormat(entry.semantic_distance, parameters, input.format) orelse
            return error.InvalidDistance;
        scratch.frequencies[encoding.symbol] += entry.frequency;
        extra_bits += @as(u64, encoding.extra_bits) * entry.frequency;
    }
    try command_plan.alphabetFromFrequenciesInto(
        scratch.frequencies.len,
        &scratch.alphabet,
        &scratch.frequencies,
    );
    scratch.lengths = try scratch.alphabet.codeLengths(&scratch.frequencies);

    var payload_bits: u64 = 0;
    for (scratch.frequencies, scratch.lengths) |frequency, length|
        payload_bits += @as(u64, frequency) * length;

    const tree_bits: u64 = if (scratch.alphabet.len <= 4)
        4 + @as(u64, scratch.alphabet.len) * oracleAlphabetBits(parameters.wireAlphabetSize(input.format)) +
            @intFromBool(scratch.alphabet.len == 4)
    else blk: {
        var highest: usize = 0;
        for (scratch.alphabet.symbols[0..scratch.alphabet.len]) |symbol|
            highest = @max(highest, symbol);
        var counter = CountingWriter{};
        try complex_prefix.writeWithStopIndex(
            allocator,
            &counter,
            parameters.activeAlphabetSize(input.format),
            &scratch.lengths,
            highest + 1,
        );
        break :blk counter.bits;
    };
    return .{
        .parameters = parameters,
        .tree_bits = tree_bits,
        .payload_bits = payload_bits,
        .extra_bits = extra_bits,
    };
}

const CountingWriter = struct {
    bits: u64 = 0,

    pub fn writeBits(self: *CountingWriter, _: std.mem.Allocator, _: anytype, count: anytype) !void {
        self.bits += count;
    }

    pub fn writeHuffmanBits(self: *CountingWriter, _: std.mem.Allocator, _: u16, count: u4) !void {
        self.bits += count;
    }
};

fn oracleAlphabetBits(alphabet_size: usize) u6 {
    if (alphabet_size <= 1) return 0;
    var bits: u6 = 0;
    var value = alphabet_size - 1;
    while (value != 0) : (value >>= 1) bits += 1;
    return bits;
}

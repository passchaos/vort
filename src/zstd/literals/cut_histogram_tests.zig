const std = @import("std");
const histogram = @import("cut_histogram.zig");
const CutHistogram = histogram.CutHistogram;

const Pattern = enum { random, ascii, high, a, ff };

fn fill(bytes: []u8, pattern: Pattern) void {
    const text = "exact cut histogram | abcdefghabcdefgh | 0123456789\n";
    var state: u32 = 0x7a36_5e19;
    for (bytes, 0..) |*byte, index| {
        state = state *% 1664525 +% 1013904223;
        byte.* = switch (pattern) {
            .random => @truncate(state >> 24),
            .ascii => text[index % text.len],
            .high => 128 + @as(u8, @truncate(state >> 25)),
            .a => 'a',
            .ff => 0xff,
        };
    }
}

/// Materialize the literal concatenation, then partition that separate array.
/// No production range planner, difference scanner, or histogram is an oracle.
fn expectOracle(actual: *const CutHistogram, block: []const u8, prefix: usize, tail: usize) !void {
    const a = std.testing.allocator;
    const literal_len = prefix + block.len - tail;
    const literals = try a.alloc(u8, literal_len);
    defer a.free(literals);
    @memcpy(literals[0..prefix], block[0..prefix]);
    @memcpy(literals[prefix..], block[tail..]);
    var expected: [4][256]u32 = @splat(@splat(0));
    const streams: usize = if (literal_len < 1024) 1 else 4;
    const quota = literal_len / streams + @intFromBool(literal_len % streams != 0);
    var offset: usize = 0;
    for (expected[0..streams]) |*frequencies| {
        const end = @min(literals.len, offset + quota);
        for (literals[offset..end]) |byte| frequencies[byte] += 1;
        offset = end;
    }
    try std.testing.expectEqual(literals.len, offset);
    try std.testing.expectEqual(literal_len, actual.regenerated_len);
    try std.testing.expectEqual(streams, actual.stream_count);
    for (expected, actual.stream_frequencies) |reference, frequencies|
        try std.testing.expectEqualSlices(u32, &reference, &frequencies);
    var total: [256]u32 = @splat(0);
    for (literals) |byte| total[byte] += 1;
    var actual_total: [256]u32 = undefined;
    actual.totalFrequencies(&actual_total);
    try std.testing.expectEqualSlices(u32, &total, &actual_total);
}

fn updateAndCheck(state: *CutHistogram, block: []const u8, prefix: usize, tail: usize) !void {
    try state.update(prefix, tail);
    try expectOracle(state, block, prefix, tail);
}

test "Zstd cut histogram fixed state initializes without scanning and rejects oversized blocks" {
    try std.testing.expect(@sizeOf(CutHistogram) <= 8 * 1024);
    var empty = try CutHistogram.init("");
    try std.testing.expectEqual(@as(u64, 0), empty.scanned_bytes);
    try std.testing.expectEqual(@as(u64, 0), empty.update_count);
    try updateAndCheck(&empty, "", 0, 0);
    try std.testing.expectEqual(@as(u64, 0), empty.scanned_bytes);
    const oversized = try std.testing.allocator.alloc(u8, histogram.max_block_len + 1);
    defer std.testing.allocator.free(oversized);
    try std.testing.expectError(error.CorruptFrame, CutHistogram.init(oversized));
}

test "Zstd cut histogram exhaustive tiny cut pairs and reverse transitions match concatenation oracle" {
    var storage: [32]u8 = undefined;
    for (std.enums.values(Pattern)) |pattern| {
        fill(&storage, pattern);
        for (0..storage.len + 1) |length| {
            const block = storage[0..length];
            var state = try CutHistogram.init(block);
            for (0..length + 1) |prefix| {
                for (prefix..length + 1) |tail| try updateAndCheck(&state, block, prefix, tail);
            }
            var prefix = length + 1;
            while (prefix != 0) {
                prefix -= 1;
                var tail = length + 1;
                while (tail > prefix) {
                    tail -= 1;
                    try updateAndCheck(&state, block, prefix, tail);
                }
            }
        }
    }
}

test "Zstd cut histogram randomized forward backward and empty transitions match independent quarters" {
    const a = std.testing.allocator;
    const block = try a.alloc(u8, 8193);
    defer a.free(block);
    for (std.enums.values(Pattern)) |pattern| {
        fill(block, pattern);
        var state = try CutHistogram.init(block);
        var seed: u32 = 0x2468_ace1;
        for (0..256) |_| {
            seed = seed *% 1664525 +% 1013904223;
            const left = seed % (block.len + 1);
            seed = seed *% 1664525 +% 1013904223;
            const right = seed % (block.len + 1);
            try updateAndCheck(&state, block, @min(left, right), @max(left, right));
        }
        try updateAndCheck(&state, block, 0, block.len);
        try updateAndCheck(&state, block, block.len, block.len);
        try updateAndCheck(&state, block, 0, 0);
    }
}

test "Zstd cut histogram stream transitions around 1023 and 1024 retain exact seam symbols" {
    var block: [2053]u8 = undefined;
    fill(&block, .random);
    var state = try CutHistogram.init(&block);
    for ([_]usize{ 0, 1, 1022, 1023, 1024, 1025, 2047, 2053, 1024, 1023, 0 }) |length| {
        for ([_]usize{ 0, length / 2, length }) |prefix| {
            const tail = block.len - (length - prefix);
            try updateAndCheck(&state, &block, prefix, tail);
            if (length < 1024) {
                for (state.stream_frequencies[1..]) |stream| for (stream) |frequency| try std.testing.expectEqual(@as(u32, 0), frequency);
            }
        }
    }
}

test "Zstd cut histogram unequal quarter tails and moving seams assign each literal once" {
    const block = try std.testing.allocator.alloc(u8, 4111);
    defer std.testing.allocator.free(block);
    fill(block, .ascii);
    var state = try CutHistogram.init(block);
    for (1024..1041) |length| {
        // Cross every quarter boundary with the prefix/tail concatenation seam.
        for ([_]usize{ 0, 1, 255, 256, 257, 511, 512, 513, 767, 768, 769, length }) |prefix|
            try updateAndCheck(&state, block, prefix, block.len - (length - prefix));
    }
}

test "Zstd cut histogram 65535 65536 and 65537 byte inputs retain full u32 frequencies" {
    const block = try std.testing.allocator.alloc(u8, 65537);
    defer std.testing.allocator.free(block);
    for (std.enums.values(Pattern)) |pattern| {
        fill(block, pattern);
        for ([_]usize{ 65535, 65536, 65537 }) |length| {
            var state = try CutHistogram.init(block[0..length]);
            try updateAndCheck(&state, block[0..length], length, length);
            try std.testing.expectEqual(@as(u64, length), state.scanned_bytes);
            try updateAndCheck(&state, block[0..length], 17, length - 29);
            try updateAndCheck(&state, block[0..length], length / 2, length / 2);
        }
    }
}

test "Zstd cut histogram 128 KiB repeated symbols and new input binding preserve ownership" {
    const a = std.testing.allocator;
    const first = try a.alloc(u8, histogram.max_block_len);
    defer a.free(first);
    const second = try a.alloc(u8, histogram.max_block_len);
    defer a.free(second);
    fill(first, .a);
    fill(second, .ff);
    var state = try CutHistogram.init(first);
    try updateAndCheck(&state, first, first.len, first.len);
    var total: [256]u32 = undefined;
    state.totalFrequencies(&total);
    try std.testing.expectEqual(@as(u32, 131072), total['a']);
    // Rebinding requires a new value; it cannot silently reuse old frequencies.
    state = try CutHistogram.init(second);
    try std.testing.expectEqual(@as(u64, 0), state.scanned_bytes);
    try updateAndCheck(&state, second, 65537, 65539);
    state.totalFrequencies(&total);
    try std.testing.expectEqual(@as(u32, 131070), total[0xff]);
    try std.testing.expectEqual(@as(u32, 0), total['a']);
}

test "Zstd cut histogram identical cuts scan zero and adjacent moving cuts visit only differences" {
    const block = try std.testing.allocator.alloc(u8, 65536);
    defer std.testing.allocator.free(block);
    fill(block, .random);
    var state = try CutHistogram.init(block);
    try updateAndCheck(&state, block, 16384, 32768);
    const first_work = state.scanned_bytes;
    try std.testing.expectEqual(@as(u64, 49152), first_work);
    try updateAndCheck(&state, block, 16384, 32768);
    try std.testing.expectEqual(first_work, state.scanned_bytes);
    const before = state.scanned_bytes;
    for (1..129) |step| try updateAndCheck(&state, block, 16384 + step, 32768 + step);
    const work = state.scanned_bytes - before;
    // Length and quarters stay fixed. Each one-byte slide moves only seam and
    // tail endpoints; recounting 48 KiB per candidate would visit 6 MiB.
    try std.testing.expect(work <= 128 * 16);
    try std.testing.expect(work * 100 < 128 * 49152);
    std.debug.print("cut-histogram state-bytes={d} initial-scan={d} adjacent128-scan={d}\n", .{ @sizeOf(CutHistogram), first_work, work });
}

test "Zstd cut histogram invalid cuts and counter overflow leave the complete state unchanged" {
    var block: [4096]u8 = undefined;
    fill(&block, .high);
    var state = try CutHistogram.init(&block);
    try state.update(100, 200);
    const original = state;
    for ([_][2]usize{ .{ 1, 0 }, .{ 0, block.len + 1 }, .{ block.len + 1, block.len + 1 }, .{ std.math.maxInt(usize), std.math.maxInt(usize) } }) |cut| {
        try std.testing.expectError(error.CorruptFrame, state.update(cut[0], cut[1]));
        try std.testing.expectEqualDeep(original, state);
    }
    state.scanned_bytes = std.math.maxInt(u64);
    const scan_overflow = state;
    try std.testing.expectError(error.IntegerOverflow, state.update(101, 201));
    try std.testing.expectEqualDeep(scan_overflow, state);
    state = original;
    state.update_count = std.math.maxInt(u64);
    const count_overflow = state;
    try std.testing.expectError(error.IntegerOverflow, state.update(100, 200));
    try std.testing.expectEqualDeep(count_overflow, state);
}

test "Zstd cut histogram physical symmetric differences equal its work counter for tiny transitions" {
    var block: [17]u8 = undefined;
    fill(&block, .random);
    var state = try CutHistogram.init(&block);
    var previous: [17]bool = @splat(false);
    for (0..block.len + 1) |prefix| {
        for (prefix..block.len + 1) |tail| {
            var current: [17]bool = undefined;
            var differences: u64 = 0;
            for (&current, 0..) |*present, index| {
                present.* = index < prefix or index >= tail;
                differences += @intFromBool(present.* != previous[index]);
            }
            const before = state.scanned_bytes;
            try updateAndCheck(&state, &block, prefix, tail);
            try std.testing.expectEqual(differences, state.scanned_bytes - before);
            previous = current;
        }
    }
}

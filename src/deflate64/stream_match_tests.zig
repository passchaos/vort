//! Independent fixed-ring oracle and capacity/transaction contracts.
const std = @import("std");
const reference = @import("full_match_reference_tests.zig");

const Pattern = enum { random, repetitive, zero };
fn fill(bytes: []u8, pattern: Pattern) void {
    const text = "abcdeabcde | exact ring ties\n";
    var random: u32 = 0x243f6a88;
    for (bytes, 0..) |*byte, index| {
        random = random *% 1664525 +% 1013904223;
        byte.* = switch (pattern) {
            .random => @truncate(random >> 24),
            .repetitive => text[index % text.len],
            .zero => 0,
        };
    }
}

fn compareMatch(expected: reference.Match, actual: anytype) !void {
    try std.testing.expectEqual(expected.length, actual.length);
    try std.testing.expectEqual(expected.distance, actual.distance);
}

fn selected(position: usize, history_len: usize, total: usize) bool {
    const local = position - history_len;
    return total <= 64 or local < 4 or local % 173 == 0 or
        position == 4095 or position == 4096 or position == 4097 or
        position == 65535 or position == 65536 or position == 65537 or
        total - position <= 4;
}

fn compareCase(comptime Codec: type, old: *reference.Matcher, candidate: *Codec.Matcher, history: []const u8, block: []const u8) !void {
    const a = std.testing.allocator;
    const history_before = try a.dupe(u8, history);
    defer a.free(history_before);
    const block_before = try a.dupe(u8, block);
    defer a.free(block_before);
    const total = history.len + block.len;
    try candidate.ensureForSize(a, total);
    old.begin(history, block);
    candidate.begin(history, block);
    try compareMatch(old.find(total, 128, 128), candidate.find(total, 128, 128));
    // Heads are completely initialized by begin. Previous links are compared
    // only after an insert wrote them; unused reference tails remain untouched.
    try std.testing.expectEqualSlices(u32, old.heads, candidate.heads);
    for (history.len..total) |position| {
        if (selected(position, history.len, total)) {
            try compareMatch(old.find(position, 128, 128), candidate.find(position, 128, 128));
            if (position - history.len < 4 or total - position <= 4) {
                for ([_]usize{ 0, 1, 4, 128 }) |max_chain| {
                    for ([_]usize{ 0, 3, 128, 65538 }) |nice|
                        try compareMatch(old.find(position, max_chain, nice), candidate.find(position, max_chain, nice));
                }
            }
        }
        old.insert(position);
        candidate.insert(position);
        if (total - position >= 3) {
            const old_link = old.previous[position & 65535];
            const new_link = candidate.previous[position & (candidate.previous.len - 1)];
            try std.testing.expectEqual(old_link, new_link);
        }
    }
    // Match-driven consumption reproduces the real fixed-plan insertion order
    // and searches every token position in a separate fully rebuilt pass.
    old.begin(history, block);
    candidate.begin(history, block);
    var position = history.len;
    while (position < total) {
        const expected = old.find(position, 128, 128);
        const actual = candidate.find(position, 128, 128);
        try compareMatch(expected, actual);
        const consumed = if (expected.length >= 3) expected.length else 1;
        for (position..position + consumed) |inserted| {
            old.insert(inserted);
            candidate.insert(inserted);
        }
        position += consumed;
    }
    try std.testing.expectEqualSlices(u8, history_before, history);
    try std.testing.expectEqualSlices(u8, block_before, block);
}

fn exactReference(comptime Codec: type) !void {
    const a = std.testing.allocator;
    var old: reference.Matcher = .{};
    defer old.deinit(a);
    try old.ensure(a);
    const storage = try a.alloc(u8, 65536 + 131072);
    defer a.free(storage);
    // New values for each span prevent a prior large ring from masking the
    // correctness of a smaller newly allocated previous-link ring.
    for ([_]usize{ 0, 1, 2, 3, 15, 16, 17, 4095, 4096, 4097, 65535, 65536, 65537 }) |span| {
        for (std.enums.values(Pattern)) |pattern| {
            fill(storage[0..span], pattern);
            var candidate: Codec.Matcher = .{};
            defer candidate.deinit(a);
            try compareCase(Codec, &old, &candidate, "", storage[0..span]);
            try std.testing.expectEqual(Codec.requiredPreviousLen(span), candidate.previous.len);
        }
    }
    for ([_]usize{ 0, 16, 32768, 65536 }) |history_len| {
        for (std.enums.values(Pattern)) |pattern| {
            const total = history_len + 4097;
            fill(storage[0..total], pattern);
            if (history_len >= 4097) @memcpy(storage[history_len..total], storage[0..4097]);
            var candidate: Codec.Matcher = .{};
            defer candidate.deinit(a);
            try compareCase(Codec, &old, &candidate, storage[0..history_len], storage[history_len..total]);
        }
    }
    fill(storage, .random);
    @memcpy(storage[65536..131072], storage[0..65536]);
    @memcpy(storage[131072..], storage[65536..131072]);
    var large: Codec.Matcher = .{};
    defer large.deinit(a);
    try compareCase(Codec, &old, &large, storage[0..65536], storage[65536..]);

    // Exactly maximum-distance lookup happens before inserting its position.
    old.begin(storage[0..65536], storage[65536..131072]);
    large.begin(storage[0..65536], storage[65536..131072]);
    const expected = old.find(65536, 128, 65538);
    const actual = large.find(65536, 128, 65538);
    try compareMatch(expected, actual);
    try std.testing.expectEqual(@as(usize, 65536), actual.distance);
    try std.testing.expectEqual(@as(usize, 65536), actual.length);
    @memset(storage[0..65539], 0);
    old.begin("", storage[0..65539]);
    large.begin("", storage[0..65539]);
    old.insert(0);
    large.insert(0);
    try compareMatch(old.find(1, 128, 65538), large.find(1, 128, 65538));
    try std.testing.expectEqual(@as(usize, 65538), large.find(1, 128, 65538).length);
}

fn expectedCapacity(span: usize) usize {
    const bounded = @min(span, 65536);
    var capacity: usize = 1;
    while (capacity < bounded) capacity *= 2;
    return capacity;
}

fn capacities(comptime Codec: type) !void {
    for ([_]usize{ 0, 1, 2, 3, 15, 16, 17, 4095, 4096, 4097, 65535, 65536, 65537, 131072, 196608, std.math.maxInt(usize) }) |span|
        try std.testing.expectEqual(expectedCapacity(span), Codec.requiredPreviousLen(span));
    var backing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var candidate: Codec.Matcher = .{};
    for ([_]usize{ 0, 1, 2, 3, 15, 16, 17, 4096, 4097, 65535, 65536 }) |span| {
        try candidate.ensureForSize(backing.allocator(), span);
        try std.testing.expectEqual(@as(usize, 32768), candidate.heads.len);
        try std.testing.expectEqual(expectedCapacity(span), candidate.previous.len);
        try std.testing.expectEqual(@as(usize, 131072) + expectedCapacity(span) * 4, backing.allocated_bytes - backing.freed_bytes);
        const allocated = backing.alloc_index;
        const head_pointer = candidate.heads.ptr;
        const previous_pointer = candidate.previous.ptr;
        candidate.reset();
        try candidate.ensureForSize(backing.allocator(), 0);
        try std.testing.expectEqual(allocated, backing.alloc_index);
        try std.testing.expectEqual(head_pointer, candidate.heads.ptr);
        try std.testing.expectEqual(previous_pointer, candidate.previous.ptr);
    }
    try candidate.ensure(backing.allocator());
    try std.testing.expectEqual(@as(usize, 65536), candidate.previous.len);
    try std.testing.expectEqual(@as(usize, 393216), backing.allocated_bytes - backing.freed_bytes);
    candidate.deinit(backing.allocator());
    try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
}

fn atomicFailures(comptime Codec: type) !void {
    // Initial heads/previous allocations are one transaction. Every real
    // first-allocation failure leaves the empty value and ownership unchanged.
    for (0..2) |failure| {
        var backing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
        var candidate: Codec.Matcher = .{};
        const original = candidate;
        try std.testing.expectError(error.OutOfMemory, candidate.ensureForSize(backing.allocator(), 17));
        try std.testing.expectEqualDeep(original, candidate);
        try std.testing.expect(backing.has_induced_failure);
        try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
        backing.fail_index = std.math.maxInt(usize);
        try candidate.ensureForSize(backing.allocator(), 17);
        candidate.deinit(backing.allocator());
        try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
    }
    var backing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var candidate: Codec.Matcher = .{};
    errdefer candidate.deinit(backing.allocator());
    try candidate.ensureForSize(backing.allocator(), 16);
    var block: [16]u8 = "abcabcabcabcabcx".*;
    const input_before = block;
    candidate.begin("", &block);
    for (0..6) |position| candidate.insert(position);
    const match_before = candidate.find(6, 128, 128);
    const heads = try std.testing.allocator.dupe(u32, candidate.heads);
    defer std.testing.allocator.free(heads);
    // Only positions0..5 were inserted, so only their previous slots are read.
    var previous: [6]u32 = undefined;
    @memcpy(&previous, candidate.previous[0..6]);
    const head_pointer = candidate.heads.ptr;
    const previous_pointer = candidate.previous.ptr;
    const capacity = candidate.previous.len;
    const live = backing.allocated_bytes - backing.freed_bytes;
    const history_pointer = candidate.history.ptr;
    const block_pointer = candidate.block.ptr;
    backing.fail_index = backing.alloc_index;
    backing.resize_fail_index = backing.resize_index;
    try std.testing.expectError(error.OutOfMemory, candidate.ensureForSize(backing.allocator(), 4097));
    try std.testing.expectEqual(head_pointer, candidate.heads.ptr);
    try std.testing.expectEqual(previous_pointer, candidate.previous.ptr);
    try std.testing.expectEqual(capacity, candidate.previous.len);
    try std.testing.expectEqual(history_pointer, candidate.history.ptr);
    try std.testing.expectEqual(block_pointer, candidate.block.ptr);
    try std.testing.expectEqualSlices(u32, heads, candidate.heads);
    try std.testing.expectEqualSlices(u32, &previous, candidate.previous[0..6]);
    try std.testing.expectEqualDeep(input_before, block);
    try std.testing.expectEqualDeep(match_before, candidate.find(6, 128, 128));
    try std.testing.expectEqual(live, backing.allocated_bytes - backing.freed_bytes);
    backing.fail_index = std.math.maxInt(usize);
    backing.resize_fail_index = std.math.maxInt(usize);
    try candidate.ensureForSize(backing.allocator(), 4097);
    try std.testing.expectEqual(@as(usize, 8192), candidate.previous.len);
    // Successful growth intentionally need not copy an old pass's links.
    // A new begin rebuilds the index before any subsequent search.
    candidate.begin("", &block);
    for (0..6) |position| candidate.insert(position);
    try std.testing.expectEqualDeep(match_before, candidate.find(6, 128, 128));
    candidate.reset();
    try std.testing.expectEqual(@as(usize, 0), candidate.history.len);
    try std.testing.expectEqual(@as(usize, 0), candidate.block.len);
    try std.testing.expectEqual(@as(usize, 8192), candidate.previous.len);
    candidate.deinit(backing.allocator());
    try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
}

fn inPlaceGrowth(comptime Codec: type) !void {
    var storage: [256 * 1024]u8 align(4) = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var candidate: Codec.Matcher = .{};
    defer candidate.deinit(fixed.allocator());
    try candidate.ensureForSize(fixed.allocator(), 8);
    const previous_pointer = candidate.previous.ptr;
    const heads_pointer = candidate.heads.ptr;
    var block: [16]u8 = "abcabcabcabcabcx".*;
    try candidate.ensureForSize(fixed.allocator(), block.len);
    candidate.begin("", &block);
    for (0..6) |position| candidate.insert(position);
    const previous_match = candidate.find(6, 128, 128);
    candidate.reset();
    // Previous is the most recent allocation and the fixed buffer has room
    // for the expansion. This allocator supports deterministic in-place remap.
    try candidate.ensureForSize(fixed.allocator(), 4097);
    try std.testing.expectEqual(previous_pointer, candidate.previous.ptr);
    try std.testing.expectEqual(heads_pointer, candidate.heads.ptr);
    try std.testing.expectEqual(@as(usize, 8192), candidate.previous.len);
    candidate.begin("", &block);
    for (0..6) |position| candidate.insert(position);
    try std.testing.expectEqualDeep(previous_match, candidate.find(6, 128, 128));
    var old: reference.Matcher = .{};
    defer old.deinit(std.testing.allocator);
    try old.ensure(std.testing.allocator);
    old.begin("", &block);
    for (0..6) |position| old.insert(position);
    try compareMatch(old.find(6, 128, 128), candidate.find(6, 128, 128));
}

pub fn contracts(comptime Codec: type) !void {
    try exactReference(Codec);
    try capacities(Codec);
    try atomicFailures(Codec);
    try inPlaceGrowth(Codec);
}

const std = @import("std");
const lz77 = @import("../lz77.zig");
const Journal = @import("streaming_hash_journal.zig").Journal;
const a = std.testing.allocator;

test "Streaming hash journal rollback restores exact arrays and retry equals unlogged baseline" {
    var input: [733]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x7abc0281);
    for (&input) |*byte| byte.* = 'a' + random.random().uintLessThan(u8, 4);
    var baseline = try lz77.StreamingHashGreedy.init(a, 32);
    defer baseline.deinit(a);
    var state = try lz77.StreamingHashGreedy.init(a, 32);
    defer state.deinit(a);
    const snapshot = try Snapshot.init(&state);
    defer snapshot.deinit();
    const expected = try consume(a, &baseline, "", &input, 0, null);
    defer a.free(expected);
    var journal: Journal = .{};
    defer journal.deinit(a);
    try journal.ensureCapacity(a, input.len);
    try journal.begin();
    const rejected = try consume(a, &state, "", &input, 0, &journal);
    defer a.free(rejected);
    try std.testing.expectEqualSlices(lz77.Token, expected, rejected);
    journal.rollback(&state);
    try snapshot.expectState(&state);
    try journal.begin();
    const retry = try consume(a, &state, "", &input, 0, &journal);
    defer a.free(retry);
    journal.commit();
    journal.rollback(&state); // Deferred cleanup after successful commit is inert.
    try std.testing.expectEqualSlices(lz77.Token, expected, retry);
    try sameTables(&baseline, &state);
}

test "Streaming hash journal committed batch continues with the same history and tokens" {
    const prefix = "abcabcXabcabcYabcabcZabcabcXabcabcYabcabcZ";
    const suffix = "abcabcXabcabcYabcabcZ/end";
    var baseline = try lz77.StreamingHashGreedy.init(a, 32);
    defer baseline.deinit(a);
    var state = try lz77.StreamingHashGreedy.init(a, 32);
    defer state.deinit(a);
    var journal: Journal = .{};
    defer journal.deinit(a);
    try journal.reserve(a, prefix.len);
    const first = try consume(a, &baseline, "", prefix, 0, null);
    defer a.free(first);
    try journal.begin();
    const committed = try consume(a, &state, "", prefix, 0, &journal);
    defer a.free(committed);
    journal.commit();
    try std.testing.expectEqualSlices(lz77.Token, first, committed);
    const history = prefix[prefix.len - 32 ..];
    const second = try consume(a, &baseline, history, suffix, prefix.len, null);
    defer a.free(second);
    try journal.begin();
    const next = try consume(a, &state, history, suffix, prefix.len, &journal);
    defer a.free(next);
    journal.commit();
    try std.testing.expectEqualSlices(lz77.Token, second, next);
    try sameTables(&baseline, &state);
    try std.testing.expectEqual(@as(usize, 0), journal.entries.items.len);
    try std.testing.expect(!journal.isActive());
}

test "Streaming hash journal repeated bucket and ring slot writes undo in reverse order" {
    const input = [_]u8{'a'} ** 777;
    var state = try lz77.StreamingHashGreedy.init(a, 8);
    defer state.deinit(a);
    const snapshot = try Snapshot.init(&state);
    defer snapshot.deinit();
    var journal: Journal = .{};
    defer journal.deinit(a);
    try journal.ensureCapacity(a, input.len);
    try journal.begin();
    const tokens = try consume(a, &state, "", &input, 0, &journal);
    defer a.free(tokens);
    var repeated_slot = false;
    for (journal.entries.items, 0..) |entry, index| {
        for (journal.entries.items[0..index]) |earlier| {
            if (earlier.bucket == entry.bucket and earlier.slot == entry.slot) repeated_slot = true;
        }
    }
    try std.testing.expect(repeated_slot);
    journal.rollback(&state);
    try snapshot.expectState(&state);
}

test "Streaming hash journal capacity failure never writes an unlogged insertion" {
    const input = [_]u8{'a'} ** 512;
    for ([_]usize{ 1, 2 }) |capacity| {
        var state = try lz77.StreamingHashGreedy.init(a, 8);
        defer state.deinit(a);
        const snapshot = try Snapshot.init(&state);
        defer snapshot.deinit();
        var journal: Journal = .{};
        defer journal.deinit(a);
        try journal.ensureCapacity(a, capacity);
        try journal.begin();
        _ = try state.nextWithJournal("", &input, 0, 0, options(8), &journal);
        try std.testing.expectError(error.OutputTooSmall, state.nextWithJournal("", &input, 1, 0, options(8), &journal));
        try std.testing.expectEqual(capacity, journal.entries.items.len);
        // After the first position, the long match next inserts p=1 and p=255.
        // If reservation ends after p=1, the p=255 ring write remains untouched.
        try std.testing.expectEqual(@as(i64, -1), state.prev.items[7]);
        journal.rollback(&state);
        try snapshot.expectState(&state);
    }
}

test "Streaming hash journal owners move and reservation failure preserve reusable capacity" {
    var owner: ?lz77.StreamingHashGreedy = try lz77.StreamingHashGreedy.init(a, 8);
    defer if (owner) |*state| state.deinit(a);
    const snapshot = try Snapshot.init(&owner.?);
    defer snapshot.deinit();
    var journal: Journal = .{};
    defer journal.deinit(a);
    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, journal.ensureCapacity(failing.allocator(), 64));
    try std.testing.expectEqual(@as(usize, 0), journal.entries.capacity);
    try std.testing.expect(!journal.isActive());
    try snapshot.expectState(&owner.?);
    try journal.reserve(a, 64);
    const retained = journal.entries.capacity;
    const pointer = journal.entries.items.ptr;
    try std.testing.expectError(error.OutOfMemory, journal.ensureCapacity(failing.allocator(), 128));
    try std.testing.expectEqual(retained, journal.entries.capacity);
    try std.testing.expectEqual(pointer, journal.entries.items.ptr);
    try journal.begin();
    _ = try owner.?.nextWithJournal("", "abcabcabc", 0, 0, options(8), &journal);
    var moved_state = owner.?;
    owner = null;
    defer moved_state.deinit(a);
    var moved_journal = journal;
    journal = .{};
    defer moved_journal.deinit(a);
    moved_journal.rollback(&moved_state);
    try snapshot.expectState(&moved_state);
    try moved_journal.ensureCapacity(failing.allocator(), 64); // No allocation.
    try moved_journal.begin();
    moved_journal.commit();
}

test "Streaming hash journal inactive nested and zero allocation lifecycle contracts" {
    var state = try lz77.StreamingHashGreedy.init(a, 8);
    defer state.deinit(a);
    var journal: Journal = .{};
    defer journal.deinit(a);
    try std.testing.expectError(error.InvalidBlockPlan, state.nextWithJournal("", "ab", 0, 0, options(8), &journal));
    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    try journal.reserve(failing.allocator(), 0);
    try journal.begin();
    try std.testing.expectError(error.InvalidBlockPlan, journal.begin());
    try std.testing.expectError(error.InvalidBlockPlan, journal.ensureCapacity(failing.allocator(), 0));
    // Short tails do not insert hashes and need no log capacity.
    const result = try state.nextWithJournal("", "ab", 0, 0, options(8), &journal);
    try std.testing.expectEqual(@as(u8, 'a'), result.token.literal);
    journal.rollback(&state);
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
}

test "Streaming hash journal keeps full i64 positions and the largest ring slot" {
    var state = try lz77.StreamingHashGreedy.init(a, lz77.max_window_len);
    defer state.deinit(a);
    const snapshot = try Snapshot.init(&state);
    defer snapshot.deinit();
    var journal: Journal = .{};
    defer journal.deinit(a);
    try journal.ensureCapacity(a, 8);
    try journal.begin();
    _ = try state.nextWithJournal("", "abc", 0, 65535, options(lz77.max_window_len), &journal);
    try std.testing.expectEqual(@as(u16, 65535), journal.entries.items[0].slot);
    journal.rollback(&state);
    try snapshot.expectState(&state);
    if (comptime @bitSizeOf(usize) >= 64) {
        try journal.begin();
        const start: usize = @intCast(std.math.maxInt(i64));
        _ = try state.nextWithJournal("", "aaaaaaaa", 0, start, options(lz77.max_window_len), &journal);
        try std.testing.expectError(error.IntegerOverflow, state.nextWithJournal("", "aaaaaaaa", 1, start, options(lz77.max_window_len), &journal));
        try std.testing.expectEqual(@as(usize, 1), journal.entries.items.len);
        journal.rollback(&state);
        try snapshot.expectState(&state);
    }
}

test "Streaming hash journal releases all state log token and rollback allocation failures" {
    try std.testing.checkAllAllocationFailures(a, allocationCase, .{});
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    var state = try lz77.StreamingHashGreedy.init(allocator, 32);
    defer state.deinit(allocator);
    var journal: Journal = .{};
    defer journal.deinit(allocator);
    const input = "abcabc/abcdef/abcabc/abcdef/abcabc/abcdef";
    try journal.ensureCapacity(allocator, input.len);
    try journal.begin();
    defer journal.rollback(&state);
    const rejected = try consume(allocator, &state, "", input, 0, &journal);
    defer allocator.free(rejected);
    journal.rollback(&state);
    try journal.begin();
    const retry = try consume(allocator, &state, "", input, 0, &journal);
    defer allocator.free(retry);
    journal.commit();
    try std.testing.expectEqualSlices(lz77.Token, rejected, retry);
}

fn options(window_len: usize) lz77.GreedyOptions {
    return .{ .window_len = window_len, .max_chain = 64, .nice_len = 64, .max_candidates = 4, .min_match = 3, .max_match = 258 };
}

fn consume(allocator: std.mem.Allocator, state: *lz77.StreamingHashGreedy, history: []const u8, input: []const u8, start: usize, journal: ?*Journal) ![]lz77.Token {
    var tokens: std.ArrayList(lz77.Token) = .empty;
    errdefer tokens.deinit(allocator);
    var position: usize = 0;
    while (position < input.len) {
        const prior = if (journal) |log| log.entries.items.len else 0;
        const result = if (journal) |log|
            try state.nextWithJournal(history, input, position, start, options(state.window_len), log)
        else
            try state.next(history, input, position, start, options(state.window_len));
        if (journal) |log| {
            try std.testing.expect(log.entries.items.len - prior <= result.consumed);
            try std.testing.expect(log.entries.items.len <= input.len);
        }
        try tokens.append(allocator, result.token);
        position += result.consumed;
    }
    return tokens.toOwnedSlice(allocator);
}

fn sameTables(expected: *const lz77.StreamingHashGreedy, actual: *const lz77.StreamingHashGreedy) !void {
    try std.testing.expectEqual(expected.window_len, actual.window_len);
    try std.testing.expectEqualSlices(i64, expected.head.items, actual.head.items);
    try std.testing.expectEqualSlices(i64, expected.prev.items, actual.prev.items);
}

const Snapshot = struct {
    head: []i64,
    prev: []i64,
    head_pointer: [*]i64,
    prev_pointer: [*]i64,
    head_capacity: usize,
    prev_capacity: usize,
    window_len: usize,

    fn init(state: *const lz77.StreamingHashGreedy) !Snapshot {
        const head = try a.dupe(i64, state.head.items);
        errdefer a.free(head);
        return .{ .head = head, .prev = try a.dupe(i64, state.prev.items), .head_pointer = state.head.items.ptr, .prev_pointer = state.prev.items.ptr, .head_capacity = state.head.capacity, .prev_capacity = state.prev.capacity, .window_len = state.window_len };
    }

    fn deinit(self: Snapshot) void {
        a.free(self.prev);
        a.free(self.head);
    }

    fn expectState(self: Snapshot, state: *const lz77.StreamingHashGreedy) !void {
        try std.testing.expectEqual(self.window_len, state.window_len);
        try std.testing.expectEqual(self.head_pointer, state.head.items.ptr);
        try std.testing.expectEqual(self.prev_pointer, state.prev.items.ptr);
        try std.testing.expectEqual(self.head_capacity, state.head.capacity);
        try std.testing.expectEqual(self.prev_capacity, state.prev.capacity);
        try std.testing.expectEqualSlices(i64, self.head, state.head.items);
        try std.testing.expectEqualSlices(i64, self.prev, state.prev.items);
    }
};

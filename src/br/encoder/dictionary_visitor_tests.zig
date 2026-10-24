const std = @import("std");
const static = @import("../static_dictionary.zig");
const candidates = @import("static_dictionary_candidates.zig");
const serialized = @import("../serialized_dictionary.zig");
const serialized_matcher = @import("serialized_dictionary_matcher.zig");
const compound_matcher = @import("compound_dictionary_matcher.zig");
const WorkingAllocator = @import("../../io/working_allocator.zig").WorkingAllocator;
const allocator = std.testing.allocator;

fn Collector(comptime Match: type) type {
    return struct {
        items: std.ArrayList(Match) = .empty,
        pub fn visit(self: *@This(), match: Match) !bool {
            try self.items.append(allocator, match);
            return true;
        }
        fn deinit(self: *@This()) void {
            self.items.deinit(allocator);
        }
    };
}

const Stop = struct {
    calls: usize = 0,
    pub fn visit(self: *Stop, _: anytype) error{}!bool {
        self.calls += 1;
        return false;
    }
};

const Fail = struct {
    pub fn visit(_: *Fail, _: anytype) error{InjectedFailure}!bool {
        return error.InjectedFailure;
    }
};

fn Ordering(comptime Match: type) type {
    return struct {
        fn less(_: void, left: Match, right: Match) bool {
            if (left.output_len != right.output_len) return left.output_len < right.output_len;
            if (left.copy_len != right.copy_len) return left.copy_len < right.copy_len;
            return left.address < right.address;
        }
    };
}

fn staticOracle(input: []const u8, output: *Collector(static.Match)) !void {
    var scratch: [64]u8 = undefined;
    for (4..25) |copy_len| {
        const bits = static.sizeBits(copy_len).?;
        for (0..@as(usize, 1) << bits) |word_index| {
            const word = static.baseWord(copy_len, word_index).?;
            for (0..static.transform_count) |transform_index| {
                const bytes = static.transformWord(transform_index, word, &scratch).?;
                if (bytes.len == 0 or bytes.len > input.len or !std.mem.eql(u8, bytes, input[0..bytes.len])) continue;
                _ = try output.visit(.{
                    .address = (transform_index << bits) | word_index,
                    .copy_len = @intCast(copy_len),
                    .output_len = @intCast(bytes.len),
                });
            }
        }
    }
}

test "Brotli dictionary visitors static full tuples agree with exhaustive transformations and exact quota" {
    const required = candidates.Index.requiredWorkingMemory();
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, candidates.Index.init(failing.allocator(), required - 1));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    var budget = WorkingAllocator.init(allocator, required);
    var original = try candidates.Index.init(budget.allocator(), required);
    var index = original;
    original = undefined;
    defer index.deinit();
    try std.testing.expectEqual(required, budget.peak);
    try std.testing.expectEqual(index.byteSize(), budget.live);
    var short_outputs: u4 = 0;
    var saw_address_alias = false;
    var saw_copy_alias = false;
    for ([_][]const u8{ "first", "Information", "a" }) |input| {
        var actual: Collector(static.Match) = .{};
        defer actual.deinit();
        var repeated: Collector(static.Match) = .{};
        defer repeated.deinit();
        var expected: Collector(static.Match) = .{};
        defer expected.deinit();
        try index.visitMatches(input, &actual);
        try index.visitMatches(input, &repeated);
        try std.testing.expectEqualDeep(actual.items.items, repeated.items.items);
        try staticOracle(input, &expected);
        std.mem.sort(static.Match, actual.items.items, {}, Ordering(static.Match).less);
        std.mem.sort(static.Match, expected.items.items, {}, Ordering(static.Match).less);
        try std.testing.expectEqualDeep(expected.items.items, actual.items.items);
        try std.testing.expect(actual.items.items.len != 0);
        var first: ?static.Match = null;
        for (actual.items.items, 0..) |match, i| {
            if (match.output_len < 4) short_outputs |= @as(u4, 1) << @intCast(match.output_len);
            if (first == null or first.?.output_len != match.output_len) first = match;
            saw_address_alias = saw_address_alias or match.address != first.?.address;
            saw_copy_alias = saw_copy_alias or match.copy_len != first.?.copy_len;
            if (i != 0) try std.testing.expect(!std.meta.eql(actual.items.items[i - 1], match));
        }
    }
    try std.testing.expect(short_outputs == 0b1110 and saw_address_alias and saw_copy_alias);
    var stopped: Stop = .{};
    try index.visitMatches("first", &stopped);
    try std.testing.expectEqual(@as(usize, 1), stopped.calls);
    var rejected: Fail = .{};
    try std.testing.expectError(error.InjectedFailure, index.visitMatches("first", &rejected));
    var empty: Stop = .{};
    try index.visitMatchesAtLeast("a", 4, &empty);
    try std.testing.expectEqual(@as(usize, 0), empty.calls);
}

test "Brotli dictionary visitors static index allocation failures release each completed allocation" {
    for (0..3) |failure_index| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = failure_index });
        try std.testing.expectError(error.OutOfMemory, candidates.Index.init(failing.allocator(), candidates.Index.requiredWorkingMemory()));
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}

fn fixture() !std.ArrayList(u8) {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    try encoded.appendSlice(allocator, &.{ 0x91, 0, 0, 1 });
    var bits: [28]u8 = @splat(0);
    bits[0] = 1;
    bits[1] = 1;
    try encoded.appendSlice(allocator, &bits);
    try encoded.appendSlice(allocator, "testtesttestxtesty");
    try encoded.appendSlice(allocator, &.{ 1, 1, 0, 0, 4 });
    for ([_]u8{ 0, 1, 3, 9 }) |kind| try encoded.appendSlice(allocator, &.{ 0, kind, 0 });
    try encoded.appendSlice(allocator, &.{ 2, 0, 0, 0, 0, 1 });
    var contexts: [64]u8 = @splat(0);
    contexts[33] = 1;
    try encoded.appendSlice(allocator, &contexts);
    return encoded;
}

fn serializedOracle(dictionary: *const serialized.Dictionary, context: usize, input: []const u8, output: *Collector(serialized.Match)) !void {
    var scratch: [serialized.max_transformed_word_len]u8 = undefined;
    for (serialized.min_word_len..serialized.max_word_len + 1) |word_len| {
        var capacity: usize = 0;
        for (0..dictionary.dictionary_count) |id| capacity += try dictionary.candidateShape(id, word_len).?.capacity();
        for (0..capacity) |address| {
            const resolved = try dictionary.resolve(context, word_len, address, &scratch);
            if (resolved.bytes.len == 0 or resolved.bytes.len > input.len or !std.mem.eql(u8, resolved.bytes, input[0..resolved.bytes.len])) continue;
            _ = try output.visit(.{ .address = address, .copy_len = @intCast(word_len), .output_len = @intCast(resolved.bytes.len), .dictionary_id = resolved.dictionary_id });
        }
    }
}

test "Brotli dictionary visitors serialized preserve same spelling addresses raw lengths and short outputs" {
    var encoded = try fixture();
    defer encoded.deinit(allocator);
    const dictionary = try serialized.parse(encoded.items);
    var matcher = serialized_matcher.Matcher.init(allocator);
    defer matcher.deinit();
    try matcher.prepare(&dictionary);
    try std.testing.expect(matcher.usesIndex());
    var scratch: [serialized.max_transformed_word_len]u8 = undefined;
    for ([_]usize{ 0, 33 }) |context| {
        for ([_][]const u8{ "test", "testx", "tes", "te", "t" }) |input| {
            var actual: Collector(serialized.Match) = .{};
            defer actual.deinit();
            var expected: Collector(serialized.Match) = .{};
            defer expected.deinit();
            try matcher.visitMatches(context, input, &scratch, &actual);
            try serializedOracle(&dictionary, context, input, &expected);
            std.mem.sort(serialized.Match, actual.items.items, {}, Ordering(serialized.Match).less);
            std.mem.sort(serialized.Match, expected.items.items, {}, Ordering(serialized.Match).less);
            try std.testing.expectEqualDeep(expected.items.items, actual.items.items);
            try std.testing.expect(actual.items.items.len != 0);
        }
    }
    var stopped: Stop = .{};
    try matcher.visitMatches(0, "test", &scratch, &stopped);
    try std.testing.expectEqual(@as(usize, 1), stopped.calls);
    var fail: Fail = .{};
    try std.testing.expectError(error.InjectedFailure, matcher.visitMatches(0, "test", &scratch, &fail));
    // The built-in descriptor exceeds the index quota and takes the complete
    // descriptor traversal; short input must still reach a real candidate.
    const builtin_dictionary = try serialized.parse(&.{ 0x91, 0, 0, 0, 0 });
    var fallback = serialized_matcher.Matcher.init(allocator);
    defer fallback.deinit();
    try fallback.prepare(&builtin_dictionary);
    try std.testing.expect(!fallback.usesIndex());
    stopped = .{};
    try fallback.visitMatches(0, "a", &scratch, &stopped);
    try std.testing.expectEqual(@as(usize, 1), stopped.calls);
}

test "Brotli dictionary visitors compound enumerate every address beyond four ways and chunk boundaries" {
    const flattened = "abcd!abcd?abcd#abcd$abcd%abcd";
    const chunks = [_][]const u8{ "a", "", "bcd!abcd?ab", "cd#abcd$", "", "abcd%abc", "d" };
    var matcher = compound_matcher.Matcher.init(allocator);
    defer matcher.deinit();
    try matcher.prepare(.{ .raw_prefixes = &chunks });
    var actual: Collector(compound_matcher.Match) = .{};
    defer actual.deinit();
    try matcher.visitMatches("!abcd?", 1, 5, &actual);
    var expected: Collector(compound_matcher.Match) = .{};
    defer expected.deinit();
    const input = "abcd?";
    for (0..flattened.len) |address| {
        var length: usize = 0;
        while (length < input.len and address + length < flattened.len and input[length] == flattened[address + length]) : (length += 1) {}
        if (length >= 2) _ = try expected.visit(.{ .address = address, .length = length });
    }
    try std.testing.expectEqualDeep(expected.items.items, actual.items.items);
    try std.testing.expectEqual(@as(usize, 6), actual.items.items.len);
    var stopped: Stop = .{};
    try matcher.visitMatches("abcd", 0, 4, &stopped);
    try std.testing.expectEqual(@as(usize, 1), stopped.calls);
    var fail: Fail = .{};
    try std.testing.expectError(error.InjectedFailure, matcher.visitMatches("abcd", 0, 4, &fail));
    try matcher.prepare(.{ .raw_prefixes = &.{ "a", "", "b" } });
    actual.items.clearRetainingCapacity();
    try matcher.visitMatches("ab", 0, 2, &actual);
    try std.testing.expectEqualDeep(&[_]compound_matcher.Match{.{ .address = 0, .length = 2 }}, actual.items.items);
}

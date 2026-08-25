const std = @import("std");
const lz77 = @import("../../lz77.zig");
const static_dictionary = @import("../static_dictionary.zig");
const small_huffman = @import("small_huffman.zig");
const static_dictionary_matcher = @import("static_dictionary_matcher.zig");

/// A Brotli insert/copy command derived from a generic LZ77 token stream.
/// `insert_start` indexes the original input so the wire writer can emit the
/// literal bytes without duplicating them in the plan. The terminal command
/// may contain only inserts; its copy fields are then intentionally ignored by
/// the Brotli decoder after those inserts reach the meta-block boundary.
pub const Command = struct {
    insert_start: usize,
    insert_len: usize,
    copy_len: usize = 2,
    distance: usize = 0,
    has_copy: bool = false,
    /// RFC 7932 dictionary commands encode the untransformed word length in
    /// the command and advance by the transformed output length.
    dictionary_output_len: usize = 0,
    dictionary_address: usize = 0,
};

pub const Plan = struct {
    commands: []Command,
    match_count: usize,

    pub fn deinit(self: Plan, allocator: std.mem.Allocator) void {
        allocator.free(self.commands);
    }
};

/// Sparse, caller-owned cache for full-suffix dictionary probes. Ratio mode
/// runs a mixed planner and then a dictionary-only planner over the same short
/// input; caching only positions actually queried by either planner avoids the
/// cost of the previously rejected eager full-input scan. A zero output length
/// is safe as the cached "no match" sentinel because usable dictionary
/// commands must advance by at least four bytes.
pub const StaticDictionaryMatchCache = struct {
    matches: []static_dictionary.Match,
    known: []bool,

    pub fn init(matches: []static_dictionary.Match, known: []bool) StaticDictionaryMatchCache {
        std.debug.assert(matches.len == known.len);
        @memset(known, false);
        return .{ .matches = matches, .known = known };
    }

    fn findLongest(self: *StaticDictionaryMatchCache, matcher: *const static_dictionary_matcher.Index, input: []const u8, position: usize) ?static_dictionary.Match {
        std.debug.assert(position < input.len and input.len <= self.matches.len);
        if (!self.known[position]) {
            self.matches[position] = matcher.findLongest(input[position..]) orelse .{
                .output_len = 0,
                .copy_len = 0,
                .address = 0,
            };
            self.known[position] = true;
        }
        return if (self.matches[position].output_len == 0) null else self.matches[position];
    }
};

pub const max_prefix_symbols = 704;

/// A compact Brotli prefix alphabet, ordered by descending frequency so shorter
/// codes go to hotter symbols. Up to four entries use Brotli's simple prefix;
/// larger sets use the complex-tree writer. Equal-frequency ordering is
/// deterministic by symbol.
pub fn PrefixAlphabetFor(comptime capacity: usize) type {
    comptime std.debug.assert(capacity <= max_prefix_symbols);
    return struct {
        const Self = @This();

        symbols: [capacity]u16 = @splat(0),
        // A Brotli meta-block contains at most 2^24 bytes, so u32 exactly
        // covers every possible symbol count.
        frequencies: [capacity]u32 = @splat(0),
        len: usize = 0,

        pub fn add(self: *Self, symbol: u16) !void {
            for (self.symbols[0..self.len], 0..) |known, i| {
                if (known == symbol) {
                    self.frequencies[i] = std.math.add(u32, self.frequencies[i], 1) catch return error.IntegerOverflow;
                    return;
                }
            }
            if (self.len == self.symbols.len) return error.InvalidBlockPlan;
            self.symbols[self.len] = symbol;
            self.frequencies[self.len] = 1;
            self.len += 1;
        }

        pub fn finish(self: *Self) void {
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                var j = i;
                const symbol = self.symbols[j];
                const frequency = self.frequencies[j];
                while (j != 0 and lessValue(symbol, frequency, self.symbols[j - 1], self.frequencies[j - 1])) : (j -= 1) {
                    self.symbols[j] = self.symbols[j - 1];
                    self.frequencies[j] = self.frequencies[j - 1];
                }
                self.symbols[j] = symbol;
                self.frequencies[j] = frequency;
            }
        }

        pub fn codeLengths(self: *const Self, comptime alphabet_size: usize) ![alphabet_size]u4 {
            if (self.len == 0) return error.InvalidBlockPlan;
            var lengths: [alphabet_size]u4 = @splat(0);
            switch (self.len) {
                1 => {}, // Single-symbol trees consume no payload bits.
                2 => {
                    for (self.symbols[0..2]) |symbol| lengths[symbol] = 1;
                },
                3 => {
                    lengths[self.symbols[0]] = 1;
                    lengths[self.symbols[1]] = 2;
                    lengths[self.symbols[2]] = 2;
                },
                4 => {
                    for (self.symbols[0..4]) |symbol| lengths[symbol] = 2;
                },
                5...max_prefix_symbols => {
                    if (self.len <= 64) {
                        var compact_lengths: [64]u4 = undefined;
                        if (small_huffman.build(64, self.frequencies[0..self.len], &compact_lengths)) {
                            for (self.symbols[0..self.len], compact_lengths[0..self.len]) |symbol, bits| lengths[symbol] = bits;
                        } else {
                            self.fillTreeLengths(alphabet_size, 64, &lengths);
                        }
                    } else if (self.len <= 256)
                        self.fillTreeLengths(alphabet_size, 256, &lengths)
                    else
                        self.fillTreeLengths(alphabet_size, max_prefix_symbols, &lengths);
                },
                else => unreachable,
            }
            return lengths;
        }

        pub fn simpleCode(self: *const Self, symbol: u16) ?struct { code: u16, bits: u4 } {
            if (self.len == 0 or self.len > 4) return null;
            var index: usize = 0;
            while (index < self.len and self.symbols[index] != symbol) : (index += 1) {}
            if (index == self.len) return null;
            if (self.len == 1) return .{ .code = 0, .bits = 0 };
            const bits: u4 = switch (self.len) {
                2 => 1,
                3 => if (index == 0) 1 else 2,
                4 => 2,
                else => unreachable,
            };
            var counts: [3]u16 = @splat(0);
            for (0..self.len) |i| counts[
                switch (self.len) {
                    2 => 1,
                    3 => if (i == 0) 1 else 2,
                    4 => 2,
                    else => unreachable,
                }
            ] += 1;
            var next: [3]u16 = @splat(0);
            next[2] = counts[1] << 1;
            var rank: u16 = 0;
            for (0..self.len) |i| {
                const other_bits: u4 = switch (self.len) {
                    2 => 1,
                    3 => if (i == 0) 1 else 2,
                    4 => 2,
                    else => unreachable,
                };
                if (other_bits == bits and self.symbols[i] < symbol) rank += 1;
            }
            const canonical = next[bits] + rank;
            return .{ .code = @bitReverse(canonical) >> @intCast(16 - @as(usize, bits)), .bits = bits };
        }

        fn lessValue(left_symbol: u16, left_frequency: u32, right_symbol: u16, right_frequency: u32) bool {
            return left_frequency > right_frequency or
                (left_frequency == right_frequency and left_symbol < right_symbol);
        }

        fn fillTreeLengths(self: *const Self, comptime alphabet_size: usize, comptime compact_size: usize, lengths: *[alphabet_size]u4) void {
            std.debug.assert(self.len <= compact_size);
            var frequencies: [compact_size]u32 = @splat(0);
            for (self.frequencies[0..self.len], 0..) |frequency, i| frequencies[i] = frequency;
            const compact_lengths = @import("../../huffman.zig").treeCodeLengths(compact_size, &frequencies, 15);
            for (self.symbols[0..self.len], compact_lengths[0..self.len]) |symbol, bits| lengths[symbol] = bits;
        }
    };
}

pub const PrefixAlphabet = PrefixAlphabetFor(max_prefix_symbols);

test "prefix alphabet capacity controls scratch footprint" {
    try std.testing.expectEqual(@as(usize, 1544), @sizeOf(PrefixAlphabetFor(256)));
    try std.testing.expectEqual(@as(usize, 4232), @sizeOf(PrefixAlphabet));
}

/// O(1) frequency collection used by the planner hot path. Converting to the
/// compact ordered alphabet happens once after all commands are scanned, rather
/// than linearly searching up to 704 symbols for every literal/command/distance.
pub fn alphabetFromFrequencies(comptime alphabet_size: usize, frequencies: *const [alphabet_size]u32) !PrefixAlphabetFor(alphabet_size) {
    var alphabet = PrefixAlphabetFor(alphabet_size){};
    try alphabetFromFrequenciesInto(alphabet_size, &alphabet, frequencies);
    return alphabet;
}

pub fn alphabetFromFrequenciesInto(comptime alphabet_size: usize, alphabet: *PrefixAlphabetFor(alphabet_size), frequencies: *const [alphabet_size]u32) !void {
    alphabet.len = 0;
    for (frequencies, 0..) |frequency, symbol| {
        if (frequency == 0) continue;
        if (alphabet.len == alphabet.symbols.len) return error.InvalidBlockPlan;
        alphabet.symbols[alphabet.len] = @intCast(symbol);
        alphabet.frequencies[alphabet.len] = frequency;
        alphabet.len += 1;
    }
    if (alphabet.len == 0) return error.InvalidBlockPlan;
    alphabet.finish();
}

/// Coalesce consecutive literal tokens into the insert portion of the next
/// match command. This is format-neutral planning only: command-code and
/// distance-alphabet limits are checked by the Brotli wire writer.
pub fn buildAlloc(allocator: std.mem.Allocator, input: []const u8, tokens: []const lz77.Token) !Plan {
    var commands: std.ArrayList(Command) = .empty;
    errdefer commands.deinit(allocator);
    var position: usize = 0;
    var insert_start: usize = 0;
    var insert_len: usize = 0;
    var match_count: usize = 0;

    for (tokens) |token| switch (token) {
        .literal => |byte| {
            if (position >= input.len or input[position] != byte) return error.InvalidBlockPlan;
            position += 1;
            insert_len += 1;
        },
        .match => |match| {
            const copy_len: usize = match.length;
            const distance: usize = match.distance;
            if (copy_len == 0 or distance == 0 or distance > position) return error.InvalidBlockPlan;
            if (copy_len > input.len - position) return error.InvalidBlockPlan;
            // Validate the token stream rather than trusting a planner from a
            // different input. The bytewise recurrence also handles overlap.
            for (0..copy_len) |i|
                if (input[position + i] != input[position + i - distance]) return error.InvalidBlockPlan;
            // The shared LZ77 parser caps individual matches at 258 bytes,
            // while Brotli copy lengths can span the complete meta-block. Two
            // adjacent copies at the same distance are exactly one longer copy
            // (including overlapping copies), so coalesce them before building
            // the command alphabet. This removes repeated long-run command and
            // distance symbols without changing any decoded byte.
            try appendCopyCommand(&commands, allocator, insert_start, insert_len, copy_len, distance);
            position += copy_len;
            insert_start = position;
            insert_len = 0;
            match_count += 1;
        },
    };

    if (position != input.len) return error.InvalidBlockPlan;
    if (insert_len != 0) try commands.append(allocator, .{
        .insert_start = insert_start,
        .insert_len = insert_len,
    });
    return .{ .commands = try commands.toOwnedSlice(allocator), .match_count = match_count };
}

/// Dictionary planner that prefers the longest transformed word at each
/// position and emits remaining bytes as literal inserts. The immutable
/// process-wide index is reused across calls; candidate transforms still pass
/// through the independent RFC transform implementation before selection.
pub fn buildStaticDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8) !Plan {
    return buildStaticDictionaryWithCacheAlloc(allocator, input, null);
}

pub fn buildStaticDictionaryWithCacheAlloc(allocator: std.mem.Allocator, input: []const u8, cache: ?*StaticDictionaryMatchCache) !Plan {
    const matcher = try static_dictionary_matcher.Index.sharedIndex();
    var commands: std.ArrayList(Command) = .empty;
    errdefer commands.deinit(allocator);
    var position: usize = 0;
    var insert_start: usize = 0;
    var insert_len: usize = 0;
    var match_count: usize = 0;

    while (position < input.len) {
        const match = if (cache) |active| active.findLongest(matcher, input, position) else matcher.findLongest(input[position..]);
        const selected = match orelse {
            position += 1;
            insert_len += 1;
            continue;
        };
        try commands.append(allocator, .{
            .insert_start = insert_start,
            .insert_len = insert_len,
            .copy_len = selected.copy_len,
            .has_copy = true,
            .dictionary_output_len = selected.output_len,
            .dictionary_address = selected.address,
        });
        position += selected.output_len;
        insert_start = position;
        insert_len = 0;
        match_count += 1;
    }

    if (insert_len != 0) try commands.append(allocator, .{
        .insert_start = insert_start,
        .insert_len = insert_len,
    });
    return .{ .commands = try commands.toOwnedSlice(allocator), .match_count = match_count };
}

/// Replace portions of an existing plan's literal inserts with static-
/// dictionary commands while preserving every LZ77 copy. Dictionary matching
/// is deliberately confined to literal runs: it cannot overlap or invalidate a
/// previously selected backward reference, so the resulting mixed plan has the
/// same decoded positions and distances as the baseline.
pub fn mixStaticDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8, baseline: []const Command) !Plan {
    return mixStaticDictionaryWithCacheAlloc(allocator, input, baseline, null);
}

pub fn mixStaticDictionaryWithCacheAlloc(allocator: std.mem.Allocator, input: []const u8, baseline: []const Command, cache: ?*StaticDictionaryMatchCache) !Plan {
    const matcher = try static_dictionary_matcher.Index.sharedIndex();
    var commands: std.ArrayList(Command) = .empty;
    errdefer commands.deinit(allocator);
    var cursor: usize = 0;
    var pending_start: usize = 0;
    var pending_len: usize = 0;
    var match_count: usize = 0;

    for (baseline) |command| {
        if (command.insert_start != cursor or command.insert_len > input.len - cursor) return error.InvalidBlockPlan;
        const literal_end = cursor + command.insert_len;
        var position = cursor;
        while (position < literal_end) {
            const remaining = literal_end - position;
            const match = if (remaining < 4) null else if (cache) |active| blk: {
                const full_match = active.findLongest(matcher, input, position);
                if (full_match == null or full_match.?.output_len <= remaining) break :blk full_match;
                // The longest full-input word crosses the preserved LZ copy. A
                // shorter dictionary word may still fit this literal run.
                break :blk matcher.findLongest(input[position..literal_end]);
            } else matcher.findLongest(input[position..literal_end]);
            if (match == null) {
                position += 1;
                pending_len += 1;
                continue;
            }
            try commands.append(allocator, .{
                .insert_start = pending_start,
                .insert_len = pending_len,
                .copy_len = match.?.copy_len,
                .has_copy = true,
                .dictionary_output_len = match.?.output_len,
                .dictionary_address = match.?.address,
            });
            position += match.?.output_len;
            pending_start = position;
            pending_len = 0;
            match_count += 1;
        }
        cursor = literal_end;
        if (!command.has_copy) continue;
        const copy_output_len = if (command.dictionary_output_len == 0) command.copy_len else command.dictionary_output_len;
        if (copy_output_len == 0 or copy_output_len > input.len - cursor) return error.InvalidBlockPlan;
        var copied = command;
        copied.insert_start = pending_start;
        copied.insert_len = pending_len;
        try commands.append(allocator, copied);
        cursor += copy_output_len;
        pending_start = cursor;
        pending_len = 0;
    }
    if (cursor != input.len) return error.InvalidBlockPlan;
    if (pending_len != 0) try commands.append(allocator, .{ .insert_start = pending_start, .insert_len = pending_len });
    return .{ .commands = try commands.toOwnedSlice(allocator), .match_count = match_count };
}

pub fn staticDictionaryIndexBytes() usize {
    return static_dictionary_matcher.max_index_bytes;
}

/// Rebuild into caller-owned typed storage, preserving command capacity across
/// independent inputs. The returned match count is diagnostic only.
pub fn buildReuse(commands: *std.ArrayList(Command), allocator: std.mem.Allocator, input: []const u8, tokens: []const lz77.Token) !usize {
    return buildReuseInternal(commands, allocator, input, tokens, true);
}

/// Internal fast path for token streams produced by Vort's LZ77 parsers. Those
/// parsers have already verified every copy against `input`, so replaying every
/// matched byte here only duplicates work. Structural bounds and literal bytes
/// remain checked because they protect command-position accounting.
pub fn buildTrustedReuse(commands: *std.ArrayList(Command), allocator: std.mem.Allocator, input: []const u8, tokens: []const lz77.Token) !usize {
    return buildReuseInternal(commands, allocator, input, tokens, false);
}

fn buildReuseInternal(commands: *std.ArrayList(Command), allocator: std.mem.Allocator, input: []const u8, tokens: []const lz77.Token, comptime validate_copies: bool) !usize {
    commands.clearRetainingCapacity();
    var position: usize = 0;
    var insert_start: usize = 0;
    var insert_len: usize = 0;
    var match_count: usize = 0;
    for (tokens) |token| switch (token) {
        .literal => |byte| {
            if (position >= input.len or input[position] != byte) return error.InvalidBlockPlan;
            position += 1;
            insert_len += 1;
        },
        .match => |match| {
            const copy_len: usize = match.length;
            const distance: usize = match.distance;
            if (copy_len == 0 or distance == 0 or distance > position or copy_len > input.len - position) return error.InvalidBlockPlan;
            if (validate_copies) for (0..copy_len) |i| if (input[position + i] != input[position + i - distance]) return error.InvalidBlockPlan;
            try appendCopyCommand(commands, allocator, insert_start, insert_len, copy_len, distance);
            position += copy_len;
            insert_start = position;
            insert_len = 0;
            match_count += 1;
        },
    };
    if (position != input.len) return error.InvalidBlockPlan;
    if (insert_len != 0) try commands.append(allocator, .{ .insert_start = insert_start, .insert_len = insert_len });
    return match_count;
}

pub fn withoutCopyInto(output: []Command, input_len: usize, commands: []const Command, drop: usize) ![]Command {
    return withoutCopiesInto(output, input_len, commands, &.{drop});
}

pub fn withoutCopiesInto(output: []Command, input_len: usize, commands: []const Command, drops: []const usize) ![]Command {
    // Converting one short copy back to literals can reduce the total stream:
    // besides payload bits it may remove a command/distance alphabet symbol.
    // Rebuild positions explicitly so the resulting plan keeps the same
    // decoded bytes and every following match retains its original distance.
    if (drops.len == 0) return error.InvalidBlockPlan;
    var previous_drop: ?usize = null;
    for (drops) |drop| {
        if (drop >= commands.len or !commands[drop].has_copy or (previous_drop != null and drop <= previous_drop.?)) return error.InvalidBlockPlan;
        previous_drop = drop;
    }
    if (output.len < commands.len) return error.OutOfMemory;
    var command_count: usize = 0;
    var cursor: usize = 0;
    var insert_start: usize = 0;
    var insert_len: usize = 0;
    for (commands, 0..) |command, i| {
        if (command.insert_start != cursor) return error.InvalidBlockPlan;
        cursor += command.insert_len;
        insert_len += command.insert_len;
        if (!command.has_copy) continue;
        const copy_output_len = if (command.dictionary_output_len == 0) command.copy_len else command.dictionary_output_len;
        if (std.mem.indexOfScalar(usize, drops, i) != null) {
            cursor += copy_output_len;
            insert_len += copy_output_len;
            continue;
        }
        output[command_count] = .{
            .insert_start = insert_start,
            .insert_len = insert_len,
            .copy_len = command.copy_len,
            .distance = command.distance,
            .has_copy = true,
            .dictionary_output_len = command.dictionary_output_len,
            .dictionary_address = command.dictionary_address,
        };
        command_count += 1;
        cursor += copy_output_len;
        insert_start = cursor;
        insert_len = 0;
    }
    if (cursor != input_len) return error.InvalidBlockPlan;
    if (insert_len != 0) {
        output[command_count] = .{ .insert_start = insert_start, .insert_len = insert_len };
        command_count += 1;
    }
    return output[0..command_count];
}

fn appendCopyCommand(
    commands: *std.ArrayList(Command),
    allocator: std.mem.Allocator,
    insert_start: usize,
    insert_len: usize,
    copy_len: usize,
    distance: usize,
) !void {
    if (insert_len == 0 and commands.items.len != 0) {
        const previous = &commands.items[commands.items.len - 1];
        if (previous.has_copy and previous.dictionary_output_len == 0 and previous.distance == distance) {
            previous.copy_len = std.math.add(usize, previous.copy_len, copy_len) catch return error.IntegerOverflow;
            return;
        }
    }
    try commands.append(allocator, .{
        .insert_start = insert_start,
        .insert_len = insert_len,
        .copy_len = copy_len,
        .distance = distance,
        .has_copy = true,
    });
}

test "coalesces literals around LZ77 matches" {
    const input = "abcabc!";
    const tokens = [_]lz77.Token{
        .{ .literal = 'a' },
        .{ .literal = 'b' },
        .{ .literal = 'c' },
        .{ .match = .{ .length = 3, .distance = 3 } },
        .{ .literal = '!' },
    };
    const plan = try buildAlloc(std.testing.allocator, input, &tokens);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), plan.commands.len);
    try std.testing.expectEqual(Command{ .insert_start = 0, .insert_len = 3, .copy_len = 3, .distance = 3, .has_copy = true }, plan.commands[0]);
    try std.testing.expectEqual(Command{ .insert_start = 6, .insert_len = 1 }, plan.commands[1]);
}

test "coalesces adjacent copies at the same distance" {
    const input = "abcdabcdabcd!abcd";
    const tokens = [_]lz77.Token{
        .{ .literal = 'a' },
        .{ .literal = 'b' },
        .{ .literal = 'c' },
        .{ .literal = 'd' },
        .{ .match = .{ .length = 4, .distance = 4 } },
        .{ .match = .{ .length = 4, .distance = 4 } },
        .{ .literal = '!' },
        .{ .match = .{ .length = 4, .distance = 5 } },
    };
    const plan = try buildAlloc(std.testing.allocator, input, &tokens);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), plan.match_count);
    try std.testing.expectEqual(@as(usize, 2), plan.commands.len);
    try std.testing.expectEqual(Command{ .insert_start = 0, .insert_len = 4, .copy_len = 8, .distance = 4, .has_copy = true }, plan.commands[0]);
    try std.testing.expectEqual(Command{ .insert_start = 12, .insert_len = 1, .copy_len = 4, .distance = 5, .has_copy = true }, plan.commands[1]);

    var reused: std.ArrayList(Command) = .empty;
    defer reused.deinit(std.testing.allocator);
    try std.testing.expectEqual(plan.match_count, try buildReuse(&reused, std.testing.allocator, input, &tokens));
    try std.testing.expectEqualSlices(Command, plan.commands, reused.items);

    var trusted: std.ArrayList(Command) = .empty;
    defer trusted.deinit(std.testing.allocator);
    try std.testing.expectEqual(plan.match_count, try buildTrustedReuse(&trusted, std.testing.allocator, input, &tokens));
    try std.testing.expectEqualSlices(Command, plan.commands, trusted.items);
}

test "validated command builder rejects corrupt parser matches" {
    const input = "abcabc";
    const tokens = [_]lz77.Token{
        .{ .literal = 'a' },
        .{ .literal = 'b' },
        .{ .literal = 'c' },
        .{ .match = .{ .length = 3, .distance = 2 } },
    };
    var commands: std.ArrayList(Command) = .empty;
    defer commands.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidBlockPlan, buildReuse(&commands, std.testing.allocator, input, &tokens));
}

test "replaces one short copy with literals without shifting later commands" {
    const commands = [_]Command{
        .{ .insert_start = 0, .insert_len = 4, .copy_len = 3, .distance = 4, .has_copy = true },
        .{ .insert_start = 7, .insert_len = 1, .copy_len = 4, .distance = 5, .has_copy = true },
    };
    var storage: [commands.len]Command = undefined;
    const alternative = try withoutCopyInto(&storage, 12, &commands, 0);
    try std.testing.expectEqual(@as(usize, 1), alternative.len);
    try std.testing.expectEqual(Command{ .insert_start = 0, .insert_len = 8, .copy_len = 4, .distance = 5, .has_copy = true }, alternative[0]);
    try std.testing.expectError(error.InvalidBlockPlan, withoutCopyInto(&storage, 12, &commands, commands.len));
}

test "rejects invalid short-copy replacement requests" {
    const command = [_]Command{.{ .insert_start = 0, .insert_len = 4 }};
    var storage: [1]Command = undefined;
    try std.testing.expectError(error.InvalidBlockPlan, withoutCopyInto(&storage, 4, &command, 0));
    try std.testing.expectError(error.InvalidBlockPlan, withoutCopyInto(&storage, 4, &command, 1));
}

test "replaces multiple short copies using original indexes" {
    const commands = [_]Command{
        .{ .insert_start = 0, .insert_len = 4, .copy_len = 3, .distance = 4, .has_copy = true },
        .{ .insert_start = 7, .insert_len = 1, .copy_len = 3, .distance = 5, .has_copy = true },
        .{ .insert_start = 11, .insert_len = 1, .copy_len = 4, .distance = 6, .has_copy = true },
    };
    var storage: [commands.len]Command = undefined;
    const alternative = try withoutCopiesInto(&storage, 16, &commands, &.{ 0, 1 });
    try std.testing.expectEqual(@as(usize, 1), alternative.len);
    try std.testing.expectEqual(Command{ .insert_start = 0, .insert_len = 12, .copy_len = 4, .distance = 6, .has_copy = true }, alternative[0]);
    try std.testing.expectError(error.InvalidBlockPlan, withoutCopiesInto(&storage, 16, &commands, &.{ 1, 0 }));
}

test "static dictionary plan preserves transformed and copy lengths" {
    const input = " information follows";
    const plan = try buildStaticDictionaryAlloc(std.testing.allocator, input);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.match_count > 0);
    const command = plan.commands[0];
    try std.testing.expect(command.has_copy);
    try std.testing.expect(command.dictionary_output_len > 0);
    try std.testing.expect(command.copy_len != command.dictionary_output_len);
}

test "static dictionary mixes only inside literal runs" {
    const input = "information:informationinformation";
    const baseline = [_]Command{
        .{ .insert_start = 0, .insert_len = 12, .copy_len = 11, .distance = 12, .has_copy = true },
        .{ .insert_start = 23, .insert_len = 0, .copy_len = 11, .distance = 11, .has_copy = true },
    };
    const mixed = try mixStaticDictionaryAlloc(std.testing.allocator, input, &baseline);
    defer mixed.deinit(std.testing.allocator);
    try std.testing.expect(mixed.match_count > 0);
    try std.testing.expect(mixed.commands.len >= baseline.len);
    try std.testing.expect(mixed.commands[0].dictionary_output_len > 0);
    try std.testing.expectEqual(@as(usize, 11), mixed.commands[mixed.commands.len - 1].distance);
}

test "static dictionary cache preserves mixed and dictionary-only plans" {
    const input = "abcdefghabcdefgh information follows abcdefghabcdefgh";
    const baseline = [_]Command{
        .{ .insert_start = 0, .insert_len = 8, .copy_len = 8, .distance = 8, .has_copy = true },
        .{ .insert_start = 16, .insert_len = 21, .copy_len = 16, .distance = 37, .has_copy = true },
    };
    const expected_mixed = try mixStaticDictionaryAlloc(std.testing.allocator, input, &baseline);
    defer expected_mixed.deinit(std.testing.allocator);
    const expected_dictionary = try buildStaticDictionaryAlloc(std.testing.allocator, input);
    defer expected_dictionary.deinit(std.testing.allocator);

    var matches: [input.len]static_dictionary.Match = undefined;
    var known: [input.len]bool = undefined;
    var cache = StaticDictionaryMatchCache.init(&matches, &known);
    const actual_mixed = try mixStaticDictionaryWithCacheAlloc(std.testing.allocator, input, &baseline, &cache);
    defer actual_mixed.deinit(std.testing.allocator);
    const actual_dictionary = try buildStaticDictionaryWithCacheAlloc(std.testing.allocator, input, &cache);
    defer actual_dictionary.deinit(std.testing.allocator);

    try std.testing.expectEqual(expected_mixed.match_count, actual_mixed.match_count);
    try std.testing.expectEqualSlices(Command, expected_mixed.commands, actual_mixed.commands);
    try std.testing.expectEqual(expected_dictionary.match_count, actual_dictionary.match_count);
    try std.testing.expectEqualSlices(Command, expected_dictionary.commands, actual_dictionary.commands);

    const boundary_input = " information follows";
    const boundary_baseline = [_]Command{
        .{ .insert_start = 0, .insert_len = 12, .copy_len = boundary_input.len - 12, .distance = 1, .has_copy = true },
    };
    const expected_boundary = try mixStaticDictionaryAlloc(std.testing.allocator, boundary_input, &boundary_baseline);
    defer expected_boundary.deinit(std.testing.allocator);
    var boundary_matches: [boundary_input.len]static_dictionary.Match = undefined;
    var boundary_known: [boundary_input.len]bool = undefined;
    var boundary_cache = StaticDictionaryMatchCache.init(&boundary_matches, &boundary_known);
    const actual_boundary = try mixStaticDictionaryWithCacheAlloc(std.testing.allocator, boundary_input, &boundary_baseline, &boundary_cache);
    defer actual_boundary.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(Command, expected_boundary.commands, actual_boundary.commands);
}

test "simple alphabet orders hot symbols first" {
    var alphabet = PrefixAlphabet{};
    for ([_]u16{ 9, 4, 9, 7, 9, 4 }) |symbol| try alphabet.add(symbol);
    alphabet.finish();
    try std.testing.expectEqualSlices(u16, &.{ 9, 4, 7 }, alphabet.symbols[0..alphabet.len]);
    const lengths = try alphabet.codeLengths(16);
    try std.testing.expectEqual(@as(u4, 1), lengths[9]);
    try std.testing.expectEqual(@as(u4, 2), lengths[4]);
    try std.testing.expectEqual(@as(u4, 2), lengths[7]);
}

test "prefix alphabet frequency rejects u32 overflow" {
    var alphabet = PrefixAlphabet{};
    alphabet.symbols[0] = 7;
    alphabet.frequencies[0] = std.math.maxInt(u32);
    alphabet.len = 1;
    try std.testing.expectError(error.IntegerOverflow, alphabet.add(7));
}

test "simple alphabet direct codes match canonical encoder" {
    const huffman = @import("../../huffman.zig");
    inline for (2..5) |count| {
        var alphabet = PrefixAlphabet{};
        for (0..count) |i| {
            alphabet.symbols[i] = @intCast(9 - i * 2);
            alphabet.frequencies[i] = @intCast(count - i);
        }
        alphabet.len = count;
        const lengths = try alphabet.codeLengths(32);
        const generic = try huffman.HuffmanTable(32).Encoder.init(&lengths);
        for (alphabet.symbols[0..count]) |symbol| {
            const direct = alphabet.simpleCode(symbol).?;
            try std.testing.expectEqual(generic.bits[symbol], direct.bits);
            try std.testing.expectEqual(generic.codes[symbol], direct.code);
        }
    }
}

test "complex alphabet produces a complete balanced tree" {
    var alphabet = PrefixAlphabet{};
    for ([_]u16{ 9, 8, 7, 6, 5 }) |symbol| try alphabet.add(symbol);
    alphabet.finish();
    const lengths = try alphabet.codeLengths(16);
    for ([_]u16{ 5, 6, 7, 8, 9 }) |symbol| try std.testing.expect(lengths[symbol] != 0);
    _ = try @import("../../huffman.zig").HuffmanTable(16).init(&lengths);
}

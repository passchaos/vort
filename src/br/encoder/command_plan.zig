const std = @import("std");
const lz77 = @import("../../lz77.zig");
const static_dictionary = @import("../static_dictionary.zig");
const small_huffman = @import("small_huffman.zig");
pub const CodeLengthsBuildProfile = small_huffman.BuildProfile;
const static_dictionary_matcher = @import("static_dictionary_matcher.zig");
const compound_dictionary_matcher = @import("compound_dictionary_matcher.zig");
const literal_context = @import("literal_context.zig");
const serialized_dictionary = @import("../serialized_dictionary.zig");
const serialized_dictionary_matcher = @import("serialized_dictionary_matcher.zig");
const scoped_static_dictionary = @import("scoped_static_dictionary.zig");
const hq_types = @import("hq_types.zig");

/// A Brotli insert/copy command derived from a generic LZ77 token stream.
/// `insert_start` indexes the original input so the wire writer can emit the
/// literal bytes without duplicating them in the plan. The terminal command
/// may contain only inserts; its copy fields are then intentionally ignored by
/// the Brotli decoder after those inserts reach the meta-block boundary.
pub const Command = struct {
    pub const Source = enum {
        lz77,
        compound,
        static,
    };

    insert_start: usize,
    insert_len: usize,
    copy_len: usize = 2,
    distance: usize = 0,
    has_copy: bool = false,
    source: @This().Source = .lz77,
    /// RFC 7932 dictionary commands encode the untransformed word length in
    /// the command and advance by the transformed output length. Compound
    /// dictionary commands instead keep their output length in `copy_len`,
    /// their logical address in `dictionary_address`, and leave this zero.
    dictionary_output_len: usize = 0,
    dictionary_address: usize = 0,
    hq_encoding: ?hq_types.ExactEncoding = null,

    pub fn outputLen(self: Command) usize {
        if (!self.has_copy) return 0;
        return switch (self.source) {
            .lz77, .compound => self.copy_len,
            .static => self.dictionary_output_len,
        };
    }

    pub fn updatesRecentDistance(self: Command) bool {
        if (self.hq_encoding) |encoding|
            if (encoding.distance_code == 0) return false;
        return self.has_copy and !self.isStatic();
    }

    pub fn isLz77(self: Command) bool {
        return self.source == .lz77;
    }

    pub fn isStatic(self: Command) bool {
        return self.source == .static;
    }

    pub fn isCompound(self: Command) bool {
        return self.source == .compound;
    }
};

pub const Source = Command.Source;

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
        len: usize = 0,

        pub fn codeLengths(self: *const Self, frequencies: *const [capacity]u32) ![capacity]u4 {
            return self.codeLengthsInternal(false, true, frequencies, {}, {});
        }

        /// Preserve the legacy dense package-merge path as an exact full
        /// PrefixAlphabet reference; the <=128 routes retain their policy.
        pub fn codeLengthsReference(self: *const Self, frequencies: *const [capacity]u32) ![capacity]u4 {
            return self.codeLengthsInternal(false, false, frequencies, {}, {});
        }

        pub fn codeLengthsProfiled(
            self: *const Self,
            frequencies: *const [capacity]u32,
            io: std.Io,
            profile: *small_huffman.BuildProfile,
        ) ![capacity]u4 {
            return self.codeLengthsInternal(true, true, frequencies, io, profile);
        }

        fn codeLengthsInternal(
            self: *const Self,
            comptime profiled: bool,
            comptime dense_fast: bool,
            frequencies: *const [capacity]u32,
            io: if (profiled) std.Io else void,
            profile: if (profiled) *small_huffman.BuildProfile else void,
        ) ![capacity]u4 {
            if (self.len == 0) return error.InvalidBlockPlan;
            var lengths: [capacity]u4 = @splat(0);
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
                        var compact_frequencies: [64]u32 = undefined;
                        for (self.symbols[0..self.len], 0..) |symbol, i| compact_frequencies[i] = frequencies[symbol];
                        const built = if (profiled)
                            small_huffman.buildProfiled(64, compact_frequencies[0..self.len], &compact_lengths, io, profile)
                        else
                            small_huffman.build(64, compact_frequencies[0..self.len], &compact_lengths);
                        if (built) {
                            for (self.symbols[0..self.len], compact_lengths[0..self.len]) |symbol, bits| lengths[symbol] = bits;
                        } else {
                            if (profiled) profile.package_merge_calls += 1;
                            self.fillTreeLengths(frequencies, 64, &lengths);
                        }
                    } else if (self.len <= 128) {
                        var compact_lengths: [128]u4 = undefined;
                        var compact_frequencies: [128]u32 = undefined;
                        for (self.symbols[0..self.len], 0..) |symbol, i| compact_frequencies[i] = frequencies[symbol];
                        const built = if (profiled)
                            small_huffman.buildProfiled(128, compact_frequencies[0..self.len], &compact_lengths, io, profile)
                        else
                            small_huffman.build(128, compact_frequencies[0..self.len], &compact_lengths);
                        if (built) {
                            for (self.symbols[0..self.len], compact_lengths[0..self.len]) |symbol, bits| lengths[symbol] = bits;
                        } else {
                            if (profiled) profile.package_merge_calls += 1;
                            self.fillTreeLengths(frequencies, 256, &lengths);
                        }
                    } else if (self.len <= 256) {
                        if (comptime dense_fast) {
                            var compact_lengths: [256]u4 = undefined;
                            var compact_frequencies: [256]u32 = undefined;
                            for (self.symbols[0..self.len], 0..) |symbol, i| compact_frequencies[i] = frequencies[symbol];
                            const built = if (profiled)
                                small_huffman.buildProfiled(256, compact_frequencies[0..self.len], &compact_lengths, io, profile)
                            else
                                small_huffman.build(256, compact_frequencies[0..self.len], &compact_lengths);
                            if (built) {
                                for (self.symbols[0..self.len], compact_lengths[0..self.len]) |symbol, bits| lengths[symbol] = bits;
                            } else {
                                if (profiled) profile.package_merge_calls += 1;
                                self.fillTreeLengths(frequencies, 256, &lengths);
                            }
                        } else {
                            if (profiled) profile.package_merge_calls += 1;
                            self.fillTreeLengths(frequencies, 256, &lengths);
                        }
                    } else {
                        if (profiled) profile.package_merge_calls += 1;
                        self.fillTreeLengths(frequencies, max_prefix_symbols, &lengths);
                    }
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

        /// Increment one symbol without requiring the dense frequency array to
        /// be zero-initialized. This is intended for small event streams such
        /// as Brotli command plans, where the active set is much smaller than
        /// the 704-symbol wire alphabet.
        pub fn recordFrequency(self: *Self, frequencies: *[capacity]u32, symbol: usize) !void {
            if (symbol >= capacity) return error.InvalidBlockPlan;
            for (self.symbols[0..self.len]) |active_symbol| {
                if (active_symbol != symbol) continue;
                frequencies[symbol] += 1;
                return;
            }
            if (self.len == capacity) return error.InvalidBlockPlan;
            frequencies[symbol] = 1;
            self.symbols[self.len] = @intCast(symbol);
            self.len += 1;
        }

        /// O(1) sparse collection for byte-sized alphabets. `seen` is cleared
        /// once per plan; untouched dense counters and symbol slots remain
        /// undefined and are never observed below `len`.
        pub fn recordByteFrequency(self: *Self, frequencies: *[capacity]u32, seen: *[4]u64, symbol: u8) !void {
            comptime std.debug.assert(capacity >= 256);
            const word = symbol >> 6;
            const mask = @as(u64, 1) << @intCast(symbol & 63);
            if (seen[word] & mask != 0) {
                frequencies[symbol] += 1;
                return;
            }
            if (self.len == capacity) return error.InvalidBlockPlan;
            seen[word] |= mask;
            frequencies[symbol] = 1;
            self.symbols[self.len] = symbol;
            self.len += 1;
        }

        /// Put a sparsely collected active set in the same deterministic order
        /// produced by `alphabetFromFrequenciesInto`: descending frequency,
        /// then ascending symbol for ties.
        pub fn sortByFrequencies(self: *Self, frequencies: *const [capacity]u32) !void {
            if (self.len == 0) return error.InvalidBlockPlan;
            for (self.symbols[1..self.len], 1..) |symbol, i| {
                const frequency = frequencies[symbol];
                var index = i;
                while (index != 0) : (index -= 1) {
                    const previous = self.symbols[index - 1];
                    if (!lessValue(symbol, frequency, previous, frequencies[previous])) break;
                    self.symbols[index] = previous;
                }
                self.symbols[index] = symbol;
            }
        }

        fn fillTreeLengths(self: *const Self, frequencies: *const [capacity]u32, comptime compact_size: usize, lengths: *[capacity]u4) void {
            std.debug.assert(self.len <= compact_size);
            var compact_frequencies: [compact_size]u32 = @splat(0);
            for (self.symbols[0..self.len], 0..) |symbol, i| compact_frequencies[i] = frequencies[symbol];
            const compact_lengths = @import("../../huffman.zig").treeCodeLengths(compact_size, &compact_frequencies, 15);
            for (self.symbols[0..self.len], compact_lengths[0..self.len]) |symbol, bits| lengths[symbol] = bits;
        }
    };
}

pub const PrefixAlphabet = PrefixAlphabetFor(max_prefix_symbols);

test "dense Huffman PrefixAlphabet exact arrays and fallback contracts" {
    try @import("dense_huffman_tests.zig").commandIntegration(@This(), small_huffman);
}

test "prefix alphabet capacity controls scratch footprint" {
    // Both symbol arrays end on the native length field's alignment. The
    // length is a physical scratch index, so its size follows the target.
    try std.testing.expectEqual(@sizeOf([256]u16) + @sizeOf(usize), @sizeOf(PrefixAlphabetFor(256)));
    try std.testing.expectEqual(@sizeOf([max_prefix_symbols]u16) + @sizeOf(usize), @sizeOf(PrefixAlphabet));
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
    // `symbols` is scratch beyond `len`; callers may pass undefined storage so
    // constructing several dense-alphabet plans does not clear unused tails.
    alphabet.len = 0;
    for (frequencies, 0..) |frequency, symbol| {
        if (frequency == 0) continue;
        if (alphabet.len == alphabet.symbols.len) return error.InvalidBlockPlan;
        // Insert while scanning the dense table. This fuses collection with
        // sorting and avoids a second pass over the active symbol buffer. The
        // dense scan is ascending, so equal-frequency symbols naturally remain
        // in their deterministic ascending-symbol order.
        var index = alphabet.len;
        while (index != 0 and frequency > frequencies[alphabet.symbols[index - 1]]) : (index -= 1)
            alphabet.symbols[index] = alphabet.symbols[index - 1];
        alphabet.symbols[index] = @intCast(symbol);
        alphabet.len += 1;
    }
    if (alphabet.len == 0) return error.InvalidBlockPlan;
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
/// position and emits remaining bytes as literal inserts. Total-tracked calls
/// own their legacy indexes; untracked calls reuse process-wide indexes.
/// Candidate transforms still pass through the RFC implementation before use.
pub fn buildStaticDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8) !Plan {
    return buildStaticDictionaryWithCacheAlloc(allocator, input, null);
}

pub fn buildStaticDictionaryWithCacheAlloc(allocator: std.mem.Allocator, input: []const u8, cache: ?*StaticDictionaryMatchCache) !Plan {
    return buildStaticDictionaryInternal(allocator, input, cache, .compact);
}

/// Complete RFC 7932 planner. A lazy supplemental index covers omit-first and
/// short-core-plus-suffix transforms that the compact index cannot reach.
pub fn buildStaticDictionaryCompleteAlloc(allocator: std.mem.Allocator, input: []const u8) !Plan {
    return buildStaticDictionaryInternal(allocator, input, null, .complete);
}

/// Slow oracle retained for differential benchmarks and matcher validation.
/// Production encoder surfaces use either the compact or supplemental index.
pub fn buildStaticDictionaryReferenceAlloc(allocator: std.mem.Allocator, input: []const u8) !Plan {
    return buildStaticDictionaryInternal(allocator, input, null, .reference);
}

const StaticDictionarySearch = enum { compact, complete, reference };

fn buildStaticDictionaryInternal(
    allocator: std.mem.Allocator,
    input: []const u8,
    cache: ?*StaticDictionaryMatchCache,
    search: StaticDictionarySearch,
) !Plan {
    var commands: std.ArrayList(Command) = .empty;
    errdefer commands.deinit(allocator);
    const match_count = try buildStaticDictionaryReuseInternal(
        &commands,
        allocator,
        input,
        cache,
        search,
    );
    return .{
        .commands = try commands.toOwnedSlice(allocator),
        .match_count = match_count,
    };
}

/// Rebuild a complete RFC 7932 dictionary plan in caller-owned storage.
/// Capacity is retained across blocks and streams; errors leave the list empty.
pub fn buildStaticDictionaryCompleteReuse(
    commands: *std.ArrayList(Command),
    allocator: std.mem.Allocator,
    input: []const u8,
) !usize {
    return buildStaticDictionaryReuseInternal(
        commands,
        allocator,
        input,
        null,
        .complete,
    );
}

fn buildStaticDictionaryReuseInternal(
    commands: *std.ArrayList(Command),
    allocator: std.mem.Allocator,
    input: []const u8,
    cache: ?*StaticDictionaryMatchCache,
    search: StaticDictionarySearch,
) !usize {
    commands.clearRetainingCapacity();
    errdefer commands.clearRetainingCapacity();
    // The exhaustive reference needs no index. Each indexed plan acquires its
    // compact/supplemental owners once, before probing any input position.
    var indexes = if (search == .reference) scoped_static_dictionary.Indexes{} else try scoped_static_dictionary.Indexes.init(allocator, search == .complete);
    defer indexes.deinit();
    const matcher = if (search == .reference) null else indexes.compact();
    const complete_matcher = if (search == .complete) indexes.complete() else null;
    var position: usize = 0;
    var insert_start: usize = 0;
    var insert_len: usize = 0;
    var match_count: usize = 0;

    while (position < input.len) {
        const match = switch (search) {
            .complete => complete_matcher.?.findLongest(matcher.?, input[position..]),
            .reference => static_dictionary.findLongestMatch(input[position..]),
            .compact => if (cache) |active|
                active.findLongest(matcher.?, input, position)
            else
                matcher.?.findLongest(input[position..]),
        };
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
            .source = .static,
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
    return match_count;
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
    return mixStaticDictionaryWithCacheProbeLimitAlloc(allocator, input, baseline, cache, std.math.maxInt(usize));
}

/// Replace dictionary matches in at most `probe_limit` literal positions. This
/// lets high-ratio callers bound dictionary search independently of input size.
pub fn mixStaticDictionaryWithCacheProbeLimitAlloc(allocator: std.mem.Allocator, input: []const u8, baseline: []const Command, cache: ?*StaticDictionaryMatchCache, probe_limit: usize) !Plan {
    var indexes = try scoped_static_dictionary.Indexes.init(allocator, false);
    defer indexes.deinit();
    const matcher = indexes.compact();
    var commands: std.ArrayList(Command) = .empty;
    errdefer commands.deinit(allocator);
    var cursor: usize = 0;
    var pending_start: usize = 0;
    var pending_len: usize = 0;
    var match_count: usize = 0;
    var probes: usize = 0;

    for (baseline) |command| {
        if (command.insert_start != cursor or command.insert_len > input.len - cursor) return error.InvalidBlockPlan;
        const literal_end = cursor + command.insert_len;
        var position = cursor;
        while (position < literal_end) {
            const remaining = literal_end - position;
            if (remaining < 4 or probes == probe_limit) {
                pending_len += remaining;
                position = literal_end;
                break;
            }
            probes += 1;
            const match = if (cache) |active| blk: {
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
                .source = .static,
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
        const copy_output_len = command.outputLen();
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

/// Replace literal runs with RAW compound-dictionary copies without changing
/// any already-selected LZ77/static/compound copy. Logical dictionary
/// addresses remain independent of the current Brotli output position; the
/// wire writer resolves them against its active history window.
pub fn mixCompoundDictionaryAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    baseline: []const Command,
    matcher: *const compound_dictionary_matcher.Matcher,
    probe_limit: usize,
) !Plan {
    var commands: std.ArrayList(Command) = .empty;
    errdefer commands.deinit(allocator);
    var cursor: usize = 0;
    var pending_start: usize = 0;
    var pending_len: usize = 0;
    var match_count: usize = 0;

    for (baseline) |command| {
        if (command.insert_start != cursor or command.insert_len > input.len - cursor)
            return error.InvalidBlockPlan;
        const literal_end = cursor + command.insert_len;
        var position = cursor;
        while (position < literal_end) {
            const remaining = literal_end - position;
            const match = matcher.findLongest(input, position, remaining, probe_limit);
            if (match == null) {
                position += 1;
                pending_len += 1;
                continue;
            }
            try commands.append(allocator, .{
                .insert_start = pending_start,
                .insert_len = pending_len,
                .copy_len = match.?.length,
                .has_copy = true,
                .source = .compound,
                .dictionary_address = match.?.address,
            });
            position += match.?.length;
            pending_start = position;
            pending_len = 0;
            match_count += 1;
        }
        cursor = literal_end;
        if (!command.has_copy) continue;
        const output_len = command.outputLen();
        if (output_len == 0 or output_len > input.len - cursor) return error.InvalidBlockPlan;
        var copied = command;
        copied.insert_start = pending_start;
        copied.insert_len = pending_len;
        try commands.append(allocator, copied);
        cursor += output_len;
        pending_start = cursor;
        pending_len = 0;
    }
    if (cursor != input.len) return error.InvalidBlockPlan;
    if (pending_len != 0) try commands.append(allocator, .{
        .insert_start = pending_start,
        .insert_len = pending_len,
    });
    return .{ .commands = try commands.toOwnedSlice(allocator), .match_count = match_count };
}

/// Replace literal runs with contextual serialized static-dictionary copies.
///
/// `context_mode` must be exactly the mode emitted by the eventual Brotli
/// meta-block header. `initial_previous` is `{ second_previous, previous }` at
/// the start of `input`, allowing the same routine to operate on later stream
/// blocks without flattening prior history.
pub fn mixSerializedDictionaryAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    baseline: []const Command,
    dictionary: *const serialized_dictionary.Dictionary,
    context_mode: u2,
    initial_previous: [2]u8,
) !Plan {
    return mixSerializedDictionaryWithMatcherAlloc(
        allocator,
        input,
        baseline,
        dictionary,
        null,
        context_mode,
        initial_previous,
    );
}

pub fn mixSerializedDictionaryWithMatcherAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    baseline: []const Command,
    dictionary: *const serialized_dictionary.Dictionary,
    matcher: ?*const serialized_dictionary_matcher.Matcher,
    context_mode: u2,
    initial_previous: [2]u8,
) !Plan {
    var commands: std.ArrayList(Command) = .empty;
    errdefer commands.deinit(allocator);
    var transformed_scratch: [serialized_dictionary.max_transformed_word_len]u8 = undefined;
    var cursor: usize = 0;
    var pending_start: usize = 0;
    var pending_len: usize = 0;
    var match_count: usize = 0;

    for (baseline) |command| {
        if (command.insert_start != cursor or command.insert_len > input.len - cursor)
            return error.InvalidBlockPlan;
        const literal_end = cursor + command.insert_len;
        var position = cursor;
        while (position < literal_end) {
            const previous = if (position >= 1)
                input[position - 1]
            else
                initial_previous[1];
            const second_previous = if (position >= 2)
                input[position - 2]
            else if (position == 1)
                initial_previous[1]
            else
                initial_previous[0];
            const context = literal_context.value(
                context_mode,
                previous,
                second_previous,
            );
            const match = if (matcher) |indexed|
                try indexed.findLongest(
                    context,
                    input[position..literal_end],
                    &transformed_scratch,
                )
            else
                try dictionary.findLongest(
                    context,
                    input[position..literal_end],
                    &transformed_scratch,
                );
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
                .source = .static,
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
        const output_len = command.outputLen();
        if (output_len == 0 or output_len > input.len - cursor)
            return error.InvalidBlockPlan;
        var copied = command;
        copied.insert_start = pending_start;
        copied.insert_len = pending_len;
        try commands.append(allocator, copied);
        cursor += output_len;
        pending_start = cursor;
        pending_len = 0;
    }
    if (cursor != input.len) return error.InvalidBlockPlan;
    if (pending_len != 0) try commands.append(allocator, .{
        .insert_start = pending_start,
        .insert_len = pending_len,
    });
    return .{
        .commands = try commands.toOwnedSlice(allocator),
        .match_count = match_count,
    };
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

/// Build commands from a dictionary-seeded LZ77 plan. Token matches may reach
/// into the preceding history, so their distance is validated against the
/// combined dictionary plus current-output position rather than input alone.
pub fn buildWithDictionaryReuse(commands: *std.ArrayList(Command), allocator: std.mem.Allocator, input: []const u8, dictionary_len: usize, tokens: []const lz77.Token) !usize {
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
            if (copy_len == 0 or distance == 0 or distance > dictionary_len + position or copy_len > input.len - position) return error.InvalidBlockPlan;
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
        if (drop >= commands.len or !commands[drop].has_copy or !commands[drop].isLz77() or (previous_drop != null and drop <= previous_drop.?)) return error.InvalidBlockPlan;
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
        const copy_output_len = command.outputLen();
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
            .source = command.source,
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
        if (previous.has_copy and previous.isLz77() and previous.distance == distance) {
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

test "command sources centralize copy semantics" {
    const lz77_command = Command{
        .insert_start = 0,
        .insert_len = 2,
        .copy_len = 7,
        .distance = 4,
        .has_copy = true,
    };
    const compound_command = Command{
        .insert_start = 9,
        .insert_len = 0,
        .copy_len = 11,
        .has_copy = true,
        .source = .compound,
        .dictionary_address = 1234,
    };
    const static_command = Command{
        .insert_start = 20,
        .insert_len = 0,
        .copy_len = 6,
        .has_copy = true,
        .source = .static,
        .dictionary_output_len = 9,
        .dictionary_address = 5678,
    };

    try std.testing.expect(lz77_command.isLz77());
    try std.testing.expect(!lz77_command.isCompound());
    try std.testing.expect(!lz77_command.isStatic());
    try std.testing.expectEqual(@as(usize, 7), lz77_command.outputLen());
    try std.testing.expect(lz77_command.updatesRecentDistance());

    try std.testing.expect(compound_command.isCompound());
    try std.testing.expect(!compound_command.isLz77());
    try std.testing.expect(!compound_command.isStatic());
    try std.testing.expectEqual(@as(usize, 11), compound_command.outputLen());
    try std.testing.expect(compound_command.updatesRecentDistance());
    try std.testing.expectEqual(@as(usize, 0), compound_command.dictionary_output_len);

    try std.testing.expect(static_command.isStatic());
    try std.testing.expect(!static_command.isLz77());
    try std.testing.expect(!static_command.isCompound());
    try std.testing.expectEqual(@as(usize, 9), static_command.outputLen());
    try std.testing.expect(!static_command.updatesRecentDistance());

    const literal_only = Command{ .insert_start = 31, .insert_len = 3 };
    try std.testing.expect(literal_only.isLz77());
    try std.testing.expectEqual(@as(usize, 0), literal_only.outputLen());
    try std.testing.expect(!literal_only.updatesRecentDistance());
    try std.testing.expectEqual(Source.lz77, literal_only.source);
}

test "compound dictionary mixer replaces literal runs and preserves LZ77 copies" {
    var matcher = compound_dictionary_matcher.Matcher.init(std.testing.allocator);
    defer matcher.deinit();
    try matcher.prepare(.{ .raw_prefixes = &.{"hello-world"} });
    const input = "xxworldyyABCDABCD";
    const baseline = [_]Command{
        .{ .insert_start = 0, .insert_len = 9, .copy_len = 4, .distance = 4, .has_copy = true },
        .{ .insert_start = 13, .insert_len = 4 },
    };
    const mixed = try mixCompoundDictionaryAlloc(
        std.testing.allocator,
        input,
        &baseline,
        &matcher,
        compound_dictionary_matcher.bucket_ways,
    );
    defer mixed.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), mixed.match_count);
    try std.testing.expectEqual(@as(usize, 3), mixed.commands.len);
    try std.testing.expectEqual(Source.compound, mixed.commands[0].source);
    try std.testing.expectEqual(@as(usize, 2), mixed.commands[0].insert_len);
    try std.testing.expectEqual(@as(usize, 5), mixed.commands[0].copy_len);
    try std.testing.expectEqual(@as(usize, 6), mixed.commands[0].dictionary_address);
    try std.testing.expectEqual(Source.lz77, mixed.commands[1].source);
    try std.testing.expectEqual(@as(usize, 4), mixed.commands[1].distance);
    try std.testing.expectEqual(@as(usize, 4), mixed.commands[2].insert_len);
}

test "serialized dictionary mixer uses the emitted literal context mode" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try encoded.appendSlice(std.testing.allocator, &.{ 0x91, 0x00, 0, 2 });
    var bits: [28]u8 = @splat(0);
    bits[0] = 1;
    try encoded.appendSlice(std.testing.allocator, &bits);
    try encoded.appendSlice(std.testing.allocator, "red!xxxx");
    try encoded.appendSlice(std.testing.allocator, &bits);
    try encoded.appendSlice(std.testing.allocator, "bluezzzz");
    try encoded.appendSlice(std.testing.allocator, &.{
        1, 1, 0, 0, 1, 0, 0, 0, // identity transform list
        2, 0, 0, 1, 0, // two dictionary choices
        1, // contextual
    });
    var context_map: [64]u8 = @splat(0);
    context_map['a' & 0x3f] = 1;
    try encoded.appendSlice(std.testing.allocator, &context_map);
    const dictionary = try serialized_dictionary.parse(encoded.items);
    const input = "ablue red!";
    const baseline = [_]Command{.{ .insert_start = 0, .insert_len = input.len }};
    const mixed = try mixSerializedDictionaryAlloc(
        std.testing.allocator,
        input,
        &baseline,
        &dictionary,
        literal_context.mode_lsb6,
        .{ 0, 0 },
    );
    defer mixed.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), mixed.match_count);
    try std.testing.expectEqual(@as(usize, 2), mixed.commands.len);
    try std.testing.expectEqual(@as(usize, 1), mixed.commands[0].insert_len);
    try std.testing.expectEqual(@as(usize, 4), mixed.commands[0].dictionary_output_len);
    try std.testing.expectEqual(@as(usize, 1), mixed.commands[1].insert_len);
    try std.testing.expectEqual(@as(usize, 4), mixed.commands[1].dictionary_output_len);
}

test "legacy command initializers default to LZ77" {
    const legacy = Command{
        .insert_start = 0,
        .insert_len = 4,
        .copy_len = 8,
        .distance = 4,
        .has_copy = true,
    };
    const explicit = Command{
        .insert_start = 0,
        .insert_len = 4,
        .copy_len = 8,
        .distance = 4,
        .has_copy = true,
        .source = .lz77,
    };
    try std.testing.expectEqual(explicit, legacy);
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

test "dictionary-seeded command construction validates combined history" {
    const tokens = [_]lz77.Token{
        .{ .match = .{ .length = 4, .distance = 4 } },
        .{ .literal = '!' },
    };
    var commands: std.ArrayList(Command) = .empty;
    defer commands.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), try buildWithDictionaryReuse(&commands, std.testing.allocator, "abcd!", 4, &tokens));
    try std.testing.expectEqual(@as(usize, 2), commands.items.len);
    try std.testing.expectEqual(@as(usize, 4), commands.items[0].distance);
    try std.testing.expectEqual(@as(usize, 1), commands.items[1].insert_len);

    const bad_distance = [_]lz77.Token{.{ .match = .{ .length = 4, .distance = 5 } }};
    try std.testing.expectError(error.InvalidBlockPlan, buildWithDictionaryReuse(&commands, std.testing.allocator, "abcd", 4, &bad_distance));
    const bad_length = [_]lz77.Token{.{ .match = .{ .length = 5, .distance = 4 } }};
    try std.testing.expectError(error.InvalidBlockPlan, buildWithDictionaryReuse(&commands, std.testing.allocator, "abcd", 4, &bad_length));
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

    const compound = [_]Command{.{
        .insert_start = 0,
        .insert_len = 0,
        .copy_len = 4,
        .has_copy = true,
        .source = .compound,
        .dictionary_address = 7,
    }};
    try std.testing.expectError(error.InvalidBlockPlan, withoutCopyInto(&storage, 4, &compound, 0));

    const static = [_]Command{.{
        .insert_start = 0,
        .insert_len = 0,
        .copy_len = 4,
        .has_copy = true,
        .source = .static,
        .dictionary_output_len = 6,
        .dictionary_address = 9,
    }};
    try std.testing.expectError(error.InvalidBlockPlan, withoutCopyInto(&storage, 6, &static, 0));
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
    try std.testing.expect(command.isStatic());
    try std.testing.expect(command.dictionary_output_len > 0);
    try std.testing.expect(command.copy_len != command.dictionary_output_len);
    try std.testing.expectEqual(command.dictionary_output_len, command.outputLen());
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
    try std.testing.expect(mixed.commands[0].isStatic());
    try std.testing.expect(mixed.commands[0].dictionary_output_len > 0);
    try std.testing.expectEqual(@as(usize, 11), mixed.commands[mixed.commands.len - 1].distance);
}

test "static dictionary mixed planner honors literal probe limit" {
    const input = "qzinformation tail";
    const baseline = [_]Command{.{ .insert_start = 0, .insert_len = input.len }};

    const zero = try mixStaticDictionaryWithCacheProbeLimitAlloc(std.testing.allocator, input, &baseline, null, 0);
    defer zero.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), zero.match_count);
    try std.testing.expectEqualSlices(Command, &baseline, zero.commands);

    const before_match = try mixStaticDictionaryWithCacheProbeLimitAlloc(std.testing.allocator, input, &baseline, null, 2);
    defer before_match.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), before_match.match_count);
    try std.testing.expectEqualSlices(Command, &baseline, before_match.commands);

    const reaches_match = try mixStaticDictionaryWithCacheProbeLimitAlloc(std.testing.allocator, input, &baseline, null, 3);
    defer reaches_match.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), reaches_match.match_count);
    try std.testing.expectEqual(@as(usize, 2), reaches_match.commands[0].insert_len);
    try std.testing.expect(reaches_match.commands[0].isStatic());
    try std.testing.expect(reaches_match.commands[0].dictionary_output_len >= "information".len);
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

test "complete static dictionary planner reaches omit-first transforms" {
    const transform_index: usize = 3;
    var transformed_storage: [64]u8 = undefined;
    const compact = try static_dictionary_matcher.Index.sharedIndex();
    var chosen_storage: [64]u8 = undefined;
    var chosen_len: usize = 0;
    search: for (6..25) |copy_len| {
        const word_count = @as(usize, 1) << static_dictionary.sizeBits(copy_len).?;
        for (0..word_count) |word_index| {
            const word = static_dictionary.baseWord(copy_len, word_index).?;
            const transformed = static_dictionary.transformWord(
                transform_index,
                word,
                &transformed_storage,
            ).?;
            if (transformed.len < 5) continue;
            const compact_match = compact.findLongest(transformed);
            if (compact_match != null and compact_match.?.output_len >= transformed.len)
                continue;
            @memcpy(chosen_storage[0..transformed.len], transformed);
            chosen_len = transformed.len;
            break :search;
        }
    }
    try std.testing.expect(chosen_len != 0);
    const transformed = chosen_storage[0..chosen_len];
    const compact_match = compact.findLongest(transformed);
    const reference_match = static_dictionary.findLongestMatch(transformed).?;
    try std.testing.expect(compact_match == null or
        compact_match.?.output_len < reference_match.output_len);
    try std.testing.expectEqual(transformed.len, reference_match.output_len);

    const plan = try buildStaticDictionaryCompleteAlloc(
        std.testing.allocator,
        transformed,
    );
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), plan.match_count);
    try std.testing.expectEqual(@as(usize, 1), plan.commands.len);
    try std.testing.expect(plan.commands[0].isStatic());
    try std.testing.expectEqual(transformed.len, plan.commands[0].outputLen());
    var decoded_storage: [64]u8 = undefined;
    const decoded = static_dictionary.transform(
        plan.commands[0].dictionary_address,
        plan.commands[0].copy_len,
        &decoded_storage,
    ).?;
    try std.testing.expectEqualSlices(u8, transformed, decoded);
}

test "simple alphabet orders hot symbols first" {
    var frequencies: [max_prefix_symbols]u32 = @splat(0);
    var alphabet = PrefixAlphabet{};
    for ([_]u16{ 9, 4, 9, 7, 9, 4 }) |symbol| frequencies[symbol] += 1;
    try alphabetFromFrequenciesInto(max_prefix_symbols, &alphabet, &frequencies);
    try std.testing.expectEqualSlices(u16, &.{ 9, 4, 7 }, alphabet.symbols[0..alphabet.len]);
    const lengths = try alphabet.codeLengths(&frequencies);
    try std.testing.expectEqual(@as(u4, 1), lengths[9]);
    try std.testing.expectEqual(@as(u4, 2), lengths[4]);
    try std.testing.expectEqual(@as(u4, 2), lengths[7]);
}

test "fused alphabet collection preserves frequency and symbol ordering" {
    var state: u32 = 0xa54f_f53a;
    for (0..256) |_| {
        var frequencies: [256]u32 = @splat(0);
        for (&frequencies) |*frequency| {
            state = state *% 1_664_525 +% 1_013_904_223;
            frequency.* = if (state & 3 == 0) 0 else 1 + (state >> 27);
        }
        const alphabet = try alphabetFromFrequencies(256, &frequencies);
        for (alphabet.symbols[1..alphabet.len], alphabet.symbols[0 .. alphabet.len - 1]) |current, previous| {
            try std.testing.expect(frequencies[previous] > frequencies[current] or
                (frequencies[previous] == frequencies[current] and previous < current));
        }
    }
}

test "fused alphabet collection initializes undefined scratch" {
    var alphabet: PrefixAlphabetFor(16) = undefined;
    var frequencies: [16]u32 = @splat(0);
    frequencies[3] = 7;
    frequencies[9] = 11;
    try alphabetFromFrequenciesInto(16, &alphabet, &frequencies);
    try std.testing.expectEqual(@as(usize, 2), alphabet.len);
    try std.testing.expectEqualSlices(u16, &.{ 9, 3 }, alphabet.symbols[0..alphabet.len]);
}

test "sparse frequency collection matches dense alphabet ordering" {
    var frequencies: [32]u32 = undefined;
    var sparse: PrefixAlphabetFor(32) = undefined;
    sparse.len = 0;
    for ([_]u16{ 9, 4, 9, 7, 4, 9, 7 }) |symbol|
        try sparse.recordFrequency(&frequencies, symbol);
    try sparse.sortByFrequencies(&frequencies);

    var dense_frequencies: [32]u32 = @splat(0);
    for ([_]u16{ 9, 4, 9, 7, 4, 9, 7 }) |symbol| dense_frequencies[symbol] += 1;
    var dense: PrefixAlphabetFor(32) = undefined;
    try alphabetFromFrequenciesInto(32, &dense, &dense_frequencies);
    try std.testing.expectEqualSlices(u16, dense.symbols[0..dense.len], sparse.symbols[0..sparse.len]);
    for (sparse.symbols[0..sparse.len]) |symbol|
        try std.testing.expectEqual(dense_frequencies[symbol], frequencies[symbol]);
}

test "bitmap byte frequency collection matches dense alphabet ordering" {
    var frequencies: [256]u32 = undefined;
    var seen: [4]u64 = @splat(0);
    var sparse: PrefixAlphabetFor(256) = undefined;
    sparse.len = 0;
    for ("abracadabra") |symbol| try sparse.recordByteFrequency(&frequencies, &seen, symbol);
    try sparse.sortByFrequencies(&frequencies);

    var dense_frequencies: [256]u32 = @splat(0);
    for ("abracadabra") |symbol| dense_frequencies[symbol] += 1;
    var dense: PrefixAlphabetFor(256) = undefined;
    try alphabetFromFrequenciesInto(256, &dense, &dense_frequencies);
    try std.testing.expectEqualSlices(u16, dense.symbols[0..dense.len], sparse.symbols[0..sparse.len]);
    for (sparse.symbols[0..sparse.len]) |symbol|
        try std.testing.expectEqual(dense_frequencies[symbol], frequencies[symbol]);
}

test "simple alphabet direct codes match canonical encoder" {
    const huffman = @import("../../huffman.zig");
    inline for (2..5) |count| {
        var alphabet = PrefixAlphabetFor(32){};
        var frequencies: [32]u32 = @splat(0);
        for (0..count) |i| {
            alphabet.symbols[i] = @intCast(9 - i * 2);
            frequencies[alphabet.symbols[i]] = @intCast(count - i);
        }
        alphabet.len = count;
        const lengths = try alphabet.codeLengths(&frequencies);
        const generic = try huffman.HuffmanTable(32).Encoder.init(&lengths);
        for (alphabet.symbols[0..count]) |symbol| {
            const direct = alphabet.simpleCode(symbol).?;
            try std.testing.expectEqual(generic.bits[symbol], direct.bits);
            try std.testing.expectEqual(generic.codes[symbol], direct.code);
        }
    }
}

test "complex alphabet produces a complete balanced tree" {
    var frequencies: [16]u32 = @splat(0);
    var alphabet = PrefixAlphabetFor(16){};
    for ([_]u16{ 9, 8, 7, 6, 5 }) |symbol| frequencies[symbol] = 1;
    try alphabetFromFrequenciesInto(16, &alphabet, &frequencies);
    const lengths = try alphabet.codeLengths(&frequencies);
    for ([_]u16{ 5, 6, 7, 8, 9 }) |symbol| try std.testing.expect(lengths[symbol] != 0);
    _ = try @import("../../huffman.zig").HuffmanTable(16).init(&lengths);
}

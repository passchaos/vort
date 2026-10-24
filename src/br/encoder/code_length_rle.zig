const std = @import("std");

pub const Token = struct {
    symbol: u5,
    extra: u3 = 0,
};

pub const Summary = struct {
    frequencies: [18]u32 = @splat(0),
    token_count: usize = 0,
    repeat16_tokens: usize = 0,
    repeat17_tokens: usize = 0,
    input_lengths: usize = 0,
    zero_runs: usize = 0,
    nonzero_runs: usize = 0,
    zero_lengths: usize = 0,
    nonzero_lengths: usize = 0,
    literal_tokens: usize = 0,
    repeat_chain_buckets: [4]usize = @splat(0),
};

pub fn summarize(comptime collect_shape: bool, lengths: []const u4, stop_index: usize) !Summary {
    if (stop_index > lengths.len) return error.InvalidBlockPlan;
    var summary: Summary = .{};
    if (collect_shape) summary.input_lengths = stop_index;
    var index: usize = 0;
    while (index < stop_index) {
        const length = lengths[index];
        var end = index + 1;
        if (length == 0) {
            while (end < stop_index and lengths[end] == 0) end += 1;
            addZeroRun(collect_shape, &summary, end - index);
        } else {
            while (end < stop_index and lengths[end] == length) end += 1;
            addNonzeroRun(collect_shape, &summary, length, end - index);
        }
        index = end;
    }
    return summary;
}

/// Summarize a code-length alphabet from its non-zero symbol list. `symbols`
/// must be strictly increasing and must contain every non-zero position in
/// `lengths`; the latter is a caller-owned invariant so this path never scans
/// dense zero gaps merely to revalidate its sparse input.
pub fn summarizeSparse(comptime collect_shape: bool, lengths: []const u4, symbols: []const u8) !Summary {
    if (lengths.len > 256) return error.InvalidBlockPlan;

    var summary: Summary = .{};
    var symbol_cursor: usize = 0;
    var sparse_index: usize = 0;
    while (sparse_index < symbols.len) {
        const symbol_index: usize = symbols[sparse_index];
        if (symbol_index >= lengths.len or symbol_index < symbol_cursor or lengths[symbol_index] == 0) {
            return error.InvalidBlockPlan;
        }

        if (symbol_index > symbol_cursor) {
            addZeroRun(collect_shape, &summary, symbol_index - symbol_cursor);
        }

        const length = lengths[symbol_index];
        var run: usize = 1;
        var last_symbol = symbol_index;
        while (sparse_index + run < symbols.len) : (run += 1) {
            const next_symbol: usize = symbols[sparse_index + run];
            if (next_symbol >= lengths.len or next_symbol <= last_symbol or lengths[next_symbol] == 0) {
                return error.InvalidBlockPlan;
            }
            if (next_symbol != last_symbol + 1 or lengths[next_symbol] != length) break;
            last_symbol = next_symbol;
        }
        addNonzeroRun(collect_shape, &summary, length, run);
        sparse_index += run;
        // The addition is performed after widening the u8 symbol, so symbol
        // 255 produces the valid exclusive stop index 256 without overflow.
        symbol_cursor = last_symbol + 1;
    }
    if (collect_shape) summary.input_lengths = symbol_cursor;
    return summary;
}

fn addZeroRun(comptime collect_shape: bool, summary: *Summary, run: usize) void {
    std.debug.assert(run != 0);
    if (collect_shape) {
        summary.zero_runs += 1;
        summary.zero_lengths += run;
    }
    if (run < 3) {
        summary.frequencies[0] += @intCast(run);
        summary.token_count += run;
        if (collect_shape) summary.literal_tokens += run;
    } else {
        const tokens = repeatTokenCount(run, 8);
        summary.frequencies[17] += @intCast(tokens);
        summary.token_count += tokens;
        summary.repeat17_tokens += tokens;
        if (collect_shape) summary.repeat_chain_buckets[@min(tokens - 1, 3)] += 1;
    }
}

fn addNonzeroRun(comptime collect_shape: bool, summary: *Summary, length: u4, run: usize) void {
    std.debug.assert(length != 0 and run != 0);
    if (collect_shape) {
        summary.nonzero_runs += 1;
        summary.nonzero_lengths += run;
    }
    summary.frequencies[length] += 1;
    summary.token_count += 1;
    if (collect_shape) summary.literal_tokens += 1;
    if (run > 1) {
        const remaining = run - 1;
        if (remaining < 3) {
            summary.frequencies[length] += @intCast(remaining);
            summary.token_count += remaining;
            if (collect_shape) summary.literal_tokens += remaining;
        } else {
            const tokens = repeatTokenCount(remaining, 4);
            summary.frequencies[16] += @intCast(tokens);
            summary.token_count += tokens;
            summary.repeat16_tokens += tokens;
            if (collect_shape) summary.repeat_chain_buckets[@min(tokens - 1, 3)] += 1;
        }
    }
}

fn repeatTokenCount(run: usize, comptime radix: usize) usize {
    const max_extra = radix - 1;
    var count: usize = 1;
    var current = run;
    while (current > max_extra + 3) {
        const extra = (current - 3) & max_extra;
        current = ((current - (extra + 3)) / radix) + 2;
        count += 1;
    }
    return count;
}

/// Brotli code-length RLE for zero runs. Chained symbol-17 runs use the same
/// recurrence as the decoder: `total = 8 * (total - 2) + (extra + 3)`. This
/// compactly spans the large unused gaps in literal/command alphabets while
/// leaving non-zero lengths explicit for deterministic first production use.
pub fn encodeAlloc(allocator: std.mem.Allocator, lengths: []const u4, stop_index: usize) ![]Token {
    if (stop_index > lengths.len) return error.InvalidBlockPlan;
    var tokens: std.ArrayList(Token) = .empty;
    errdefer tokens.deinit(allocator);
    var i: usize = 0;
    while (i < stop_index) {
        if (lengths[i] != 0) {
            const length = lengths[i];
            var end = i + 1;
            while (end < stop_index and lengths[end] == length) end += 1;
            try appendNonzeroRun(allocator, &tokens, length, end - i);
            i = end;
            continue;
        }
        var end = i + 1;
        while (end < stop_index and lengths[end] == 0) end += 1;
        try appendZeroRun(allocator, &tokens, end - i);
        i = end;
    }
    return tokens.toOwnedSlice(allocator);
}

pub fn encodeInto(output: []Token, lengths: []const u4, stop_index: usize) !usize {
    if (stop_index > lengths.len or output.len < stop_index) return error.OutOfMemory;
    var tokens: std.ArrayList(Token) = .{ .items = output[0..0], .capacity = output.len };
    try encodeIntoList(&tokens, lengths, stop_index, null);
    return tokens.items.len;
}

/// Encode into caller storage while accumulating the code-length alphabet.
/// Complex-prefix construction always needs both results, so updating the tiny
/// 18-entry histogram at each emission avoids rereading the completed token
/// stream before building its Huffman code.
pub fn encodeIntoWithFrequencies(output: []Token, lengths: []const u4, stop_index: usize, frequencies: *[18]u32) !usize {
    if (stop_index > lengths.len or output.len < stop_index) return error.OutOfMemory;
    frequencies.* = @splat(0);
    var token_len: usize = 0;
    var i: usize = 0;
    while (i < stop_index) {
        if (lengths[i] != 0) {
            const length = lengths[i];
            var end = i + 1;
            while (end < stop_index and lengths[end] == length) end += 1;
            appendNonzeroRunWithFrequencies(output, &token_len, frequencies, length, end - i);
            i = end;
            continue;
        }
        const end = findNonzeroLength(lengths, i + 1, stop_index);
        appendZeroRunWithFrequencies(output, &token_len, frequencies, end - i);
        i = end;
    }
    return token_len;
}

fn findNonzeroLength(lengths: []const u4, start: usize, end: usize) usize {
    var index = start;
    while (index + 8 <= end) : (index += 8) {
        const bytes: *const [8]u8 = @ptrCast(lengths[index..][0..8]);
        if (std.mem.readInt(u64, bytes, .little) != 0) break;
    }
    while (index < end and lengths[index] == 0) index += 1;
    return index;
}

inline fn appendTokenWithFrequencies(output: []Token, token_len: *usize, frequencies: *[18]u32, token: Token) void {
    // Each emitted token consumes at least one input code length, so the
    // entry-point's `output.len >= stop_index` check proves this store fits.
    output[token_len.*] = token;
    token_len.* += 1;
    frequencies[token.symbol] += 1;
}

fn appendNonzeroRunWithFrequencies(output: []Token, token_len: *usize, frequencies: *[18]u32, length: u4, run: usize) void {
    appendTokenWithFrequencies(output, token_len, frequencies, .{ .symbol = length });
    if (run == 1) return;
    const remaining = run - 1;
    if (remaining < 3) {
        for (0..remaining) |_| appendTokenWithFrequencies(output, token_len, frequencies, .{ .symbol = length });
        return;
    }
    appendRepeatRunWithFrequencies(output, token_len, frequencies, 16, remaining, 4);
}

fn appendZeroRunWithFrequencies(output: []Token, token_len: *usize, frequencies: *[18]u32, run: usize) void {
    if (run < 3) {
        for (0..run) |_| appendTokenWithFrequencies(output, token_len, frequencies, .{ .symbol = 0 });
        return;
    }
    appendRepeatRunWithFrequencies(output, token_len, frequencies, 17, run, 8);
}

fn appendRepeatRunWithFrequencies(output: []Token, token_len: *usize, frequencies: *[18]u32, symbol: u5, run: usize, comptime radix: usize) void {
    const max_extra = radix - 1;
    var extras: [16]u3 = undefined;
    var extra_len: usize = 0;
    var current = run;
    while (current > max_extra + 3) {
        const extra = (current - 3) & max_extra;
        current = ((current - (extra + 3)) / radix) + 2;
        extras[extra_len] = @intCast(extra);
        extra_len += 1;
    }
    appendTokenWithFrequencies(output, token_len, frequencies, .{ .symbol = symbol, .extra = @intCast(current - 3) });
    while (extra_len != 0) {
        extra_len -= 1;
        appendTokenWithFrequencies(output, token_len, frequencies, .{ .symbol = symbol, .extra = extras[extra_len] });
    }
}

/// Validate and find the last non-zero code length in one forward pass. This
/// replaces complex-prefix's full validation pass plus backward trailing-zero
/// scan and returns the exclusive stop index expected by the RLE encoder.
pub fn validatedStopIndex(lengths: []const u4) !usize {
    var stop_index: usize = 0;
    for (lengths, 0..) |length, i| {
        if (length > 15) return error.InvalidBlockPlan;
        if (length != 0) stop_index = i + 1;
    }
    return stop_index;
}

fn encodeIntoList(tokens: *std.ArrayList(Token), lengths: []const u4, stop_index: usize, frequencies: ?*[18]u32) !void {
    var i: usize = 0;
    while (i < stop_index) {
        if (lengths[i] != 0) {
            const length = lengths[i];
            var end = i + 1;
            while (end < stop_index and lengths[end] == length) end += 1;
            try appendNonzeroRunBounded(tokens, frequencies, length, end - i);
            i = end;
            continue;
        }
        var end = i + 1;
        while (end < stop_index and lengths[end] == 0) end += 1;
        try appendZeroRunBounded(tokens, frequencies, end - i);
        i = end;
    }
}

inline fn appendTokenBounded(tokens: *std.ArrayList(Token), frequencies: ?*[18]u32, token: Token) !void {
    try tokens.appendBounded(token);
    if (frequencies) |counts| counts[token.symbol] += 1;
}

fn appendNonzeroRunBounded(tokens: *std.ArrayList(Token), frequencies: ?*[18]u32, length: u4, run: usize) !void {
    try appendTokenBounded(tokens, frequencies, .{ .symbol = length });
    if (run == 1) return;
    const remaining = run - 1;
    if (remaining < 3) {
        for (0..remaining) |_| try appendTokenBounded(tokens, frequencies, .{ .symbol = length });
        return;
    }
    try appendRepeatRunBounded(tokens, frequencies, 16, remaining, 4);
}

fn appendZeroRunBounded(tokens: *std.ArrayList(Token), frequencies: ?*[18]u32, run: usize) !void {
    if (run < 3) {
        for (0..run) |_| try appendTokenBounded(tokens, frequencies, .{ .symbol = 0 });
        return;
    }
    try appendRepeatRunBounded(tokens, frequencies, 17, run, 8);
}

fn appendRepeatRunBounded(tokens: *std.ArrayList(Token), frequencies: ?*[18]u32, symbol: u5, run: usize, comptime radix: usize) !void {
    const max_extra = radix - 1;
    var extras: [16]u3 = undefined;
    var extra_len: usize = 0;
    var current = run;
    while (current > max_extra + 3) {
        const extra = (current - 3) & max_extra;
        current = ((current - (extra + 3)) / radix) + 2;
        extras[extra_len] = @intCast(extra);
        extra_len += 1;
    }
    try appendTokenBounded(tokens, frequencies, .{ .symbol = symbol, .extra = @intCast(current - 3) });
    while (extra_len != 0) {
        extra_len -= 1;
        try appendTokenBounded(tokens, frequencies, .{ .symbol = symbol, .extra = extras[extra_len] });
    }
}

fn appendNonzeroRun(allocator: std.mem.Allocator, tokens: *std.ArrayList(Token), length: u4, run: usize) !void {
    try tokens.append(allocator, .{ .symbol = length });
    if (run == 1) return;
    const remaining = run - 1;
    // One or two repeats are smaller as explicit lengths; symbol 16 starts at
    // three and chains in base four for longer runs.
    if (remaining < 3) {
        for (0..remaining) |_| try tokens.append(allocator, .{ .symbol = length });
        return;
    }
    try appendRepeatRun(allocator, tokens, 16, remaining, 4);
}

fn appendZeroRun(allocator: std.mem.Allocator, tokens: *std.ArrayList(Token), run: usize) !void {
    if (run < 3) {
        for (0..run) |_| try tokens.append(allocator, .{ .symbol = 0 });
        return;
    }

    try appendRepeatRun(allocator, tokens, 17, run, 8);
}

fn appendRepeatRun(allocator: std.mem.Allocator, tokens: *std.ArrayList(Token), symbol: u5, run: usize, comptime radix: usize) !void {
    const max_extra = radix - 1;
    // Reverse the chaining recurrence until the predecessor can be represented
    // by one repeat token, then emit the chain forward.
    var extras: [16]u3 = undefined;
    var extra_len: usize = 0;
    var current = run;
    while (current > max_extra + 3) {
        // `current = radix * (previous - 2) + extra + 3`; both Brotli
        // repeat radices are powers of two, so the unique legal extra is the
        // low log2(radix) bits of current-3. This replaces an inner search and
        // modulo per chain level with one mask and shift.
        const extra = (current - 3) & max_extra;
        const previous = ((current - (extra + 3)) / radix) + 2;
        if (previous < 3 or previous >= current) return error.InvalidBlockPlan;
        extras[extra_len] = @intCast(extra);
        extra_len += 1;
        current = previous;
    }
    try tokens.append(allocator, .{ .symbol = symbol, .extra = @intCast(current - 3) });
    while (extra_len != 0) {
        extra_len -= 1;
        try tokens.append(allocator, .{ .symbol = symbol, .extra = extras[extra_len] });
    }
}

test "repeat inverse step reconstructs every bounded run" {
    inline for (.{ 4, 8 }) |radix| {
        const max_extra = radix - 1;
        var current: usize = max_extra + 4;
        while (current <= 703) : (current += 1) {
            const extra = (current - 3) & max_extra;
            const previous = ((current - (extra + 3)) / radix) + 2;
            try std.testing.expect(previous >= 3 and previous < current);
            try std.testing.expectEqual(current, radix * (previous - 2) + extra + 3);
        }
    }
}

pub fn decodedLength(tokens: []const Token) !usize {
    var total: usize = 0;
    var pending: usize = 0;
    var previous_repeat_symbol: ?u5 = null;
    for (tokens) |token| {
        if (token.symbol == 17 or token.symbol == 16) {
            const repeat = @as(usize, token.extra) + 3;
            const radix: usize = if (token.symbol == 17) 8 else 4;
            if (previous_repeat_symbol == token.symbol) {
                pending = radix * (pending - 2) + repeat;
            } else {
                total += pending;
                pending = repeat;
            }
            previous_repeat_symbol = token.symbol;
        } else {
            total += pending + 1;
            pending = 0;
            previous_repeat_symbol = null;
        }
    }
    return total + pending;
}

test "zero run chaining covers Brotli alphabet gaps" {
    inline for (.{ 1, 2, 3, 10, 11, 17, 31, 97, 255, 703 }) |run| {
        const lengths = try std.testing.allocator.alloc(u4, run);
        defer std.testing.allocator.free(lengths);
        @memset(lengths, 0);
        const tokens = try encodeAlloc(std.testing.allocator, lengths, lengths.len);
        defer std.testing.allocator.free(tokens);
        try std.testing.expectEqual(run, try decodedLength(tokens));
    }
}

test "nonzero run chaining uses symbol sixteen" {
    var lengths: [97]u4 = @splat(8);
    const tokens = try encodeAlloc(std.testing.allocator, &lengths, lengths.len);
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(lengths.len, try decodedLength(tokens));
    try std.testing.expect(tokens.len < 8);
    try std.testing.expect(tokens[1].symbol == 16);
}

test "bounded RLE matches allocating encoder" {
    var lengths: [704]u4 = @splat(0);
    for (&lengths, 0..) |*length, i| if (i % 17 == 0) {
        length.* = @intCast(1 + (i % 8));
    };
    const allocated = try encodeAlloc(std.testing.allocator, &lengths, lengths.len);
    defer std.testing.allocator.free(allocated);
    var bounded: [704]Token = undefined;
    const len = try encodeInto(&bounded, &lengths, lengths.len);
    try std.testing.expectEqualSlices(Token, allocated, bounded[0..len]);
}

test "bounded RLE frequency fusion matches token scan" {
    var state: u32 = 0x6d2b_79f5;
    for (0..512) |_| {
        var lengths: [704]u4 = undefined;
        for (&lengths) |*length| {
            state = state *% 1_664_525 +% 1_013_904_223;
            length.* = if (state & 3 == 0) 0 else @intCast(1 + (state >> 28) % 15);
        }
        const stop_index: usize = state % (lengths.len + 1);
        var expected_tokens: [704]Token = undefined;
        const expected_len = try encodeInto(&expected_tokens, &lengths, stop_index);
        var expected_frequencies: [18]u32 = @splat(0);
        for (expected_tokens[0..expected_len]) |token| expected_frequencies[token.symbol] += 1;

        var actual_tokens: [704]Token = undefined;
        var actual_frequencies: [18]u32 = undefined;
        const actual_len = try encodeIntoWithFrequencies(&actual_tokens, &lengths, stop_index, &actual_frequencies);
        try std.testing.expectEqual(expected_len, actual_len);
        try std.testing.expectEqualSlices(Token, expected_tokens[0..expected_len], actual_tokens[0..actual_len]);
        try std.testing.expectEqual(expected_frequencies, actual_frequencies);

        const summary = try summarize(true, &lengths, stop_index);
        try std.testing.expectEqual(expected_len, summary.token_count);
        try std.testing.expectEqual(expected_frequencies, summary.frequencies);
        var literal_tokens: usize = 0;
        var repeat16_tokens: usize = 0;
        var repeat17_tokens: usize = 0;
        for (expected_tokens[0..expected_len]) |token| switch (token.symbol) {
            16 => repeat16_tokens += 1,
            17 => repeat17_tokens += 1,
            else => literal_tokens += 1,
        };
        try std.testing.expectEqual(literal_tokens, summary.literal_tokens);
        try std.testing.expectEqual(repeat16_tokens, summary.repeat16_tokens);
        try std.testing.expectEqual(repeat17_tokens, summary.repeat17_tokens);
        try std.testing.expectEqual(stop_index, summary.zero_lengths + summary.nonzero_lengths);
    }
}

fn expectSparseSummaryMatchesDense(lengths: []const u4) !void {
    std.debug.assert(lengths.len <= 256);
    var symbols: [256]u8 = undefined;
    var active: usize = 0;
    var stop_index: usize = 0;
    for (lengths, 0..) |length, symbol| {
        if (length == 0) continue;
        symbols[active] = @intCast(symbol);
        active += 1;
        stop_index = symbol + 1;
    }

    inline for (.{ false, true }) |collect_shape| {
        const dense = try summarize(collect_shape, lengths, stop_index);
        const sparse = try summarizeSparse(collect_shape, lengths, symbols[0..active]);
        try std.testing.expectEqualDeep(dense, sparse);
    }
}

test "sparse summary matches dense boundary shapes" {
    var all_zero: [256]u4 = @splat(0);
    try expectSparseSummaryMatchesDense(&all_zero);
    try std.testing.expectEqualDeep(Summary{}, try summarizeSparse(true, &all_zero, &.{}));

    var gaps: [256]u4 = @splat(0);
    // Interior zero gaps of lengths 1, 2, 3, 10, and 11, plus both u8
    // symbol boundaries and one adjacent equal-length run.
    gaps[0] = 1;
    gaps[2] = 2;
    gaps[5] = 3;
    gaps[9] = 4;
    gaps[20] = 5;
    gaps[32] = 7;
    gaps[33] = 7;
    gaps[34] = 7;
    gaps[255] = 15;
    try expectSparseSummaryMatchesDense(&gaps);

    var leading: [64]u4 = @splat(0);
    @memset(leading[11..27], 6);
    leading[27] = 9;
    leading[29] = 9;
    try expectSparseSummaryMatchesDense(&leading);

    var all_nonzero: [256]u4 = @splat(8);
    try expectSparseSummaryMatchesDense(&all_nonzero);
}

test "sparse summary rejects invalid local metadata" {
    var lengths: [4]u4 = @splat(0);
    lengths[1] = 4;
    lengths[3] = 5;
    try std.testing.expectError(error.InvalidBlockPlan, summarizeSparse(false, &lengths, &.{ 1, 1 }));
    try std.testing.expectError(error.InvalidBlockPlan, summarizeSparse(false, &lengths, &.{ 3, 1 }));
    try std.testing.expectError(error.InvalidBlockPlan, summarizeSparse(false, &lengths, &.{2}));
    try std.testing.expectError(error.InvalidBlockPlan, summarizeSparse(false, lengths[0..2], &.{3}));

    var oversized: [257]u4 = @splat(0);
    try std.testing.expectError(error.InvalidBlockPlan, summarizeSparse(false, &oversized, &.{}));
}

test "sparse summary matches dense randomized alphabets" {
    var state: u64 = 0x5350_4152_5345_524c;
    for (0..8192) |_| {
        state = state *% 6_364_136_223_846_793_005 +% 1_442_695_040_888_963_407;
        const alphabet_len: usize = @intCast(state % 257);
        var lengths: [256]u4 = @splat(0);
        for (lengths[0..alphabet_len], 0..) |*length, symbol| {
            state = state *% 6_364_136_223_846_793_005 +% 1_442_695_040_888_963_407;
            const selector = state & 15;
            if (selector < 7) continue;
            if (selector < 12 and symbol != 0 and lengths[symbol - 1] != 0) {
                length.* = lengths[symbol - 1];
            } else {
                length.* = @intCast(1 + (state >> 32) % 15);
            }
        }
        try expectSparseSummaryMatchesDense(lengths[0..alphabet_len]);
    }
}

test "code-length zero scan matches scalar boundaries" {
    var lengths: [97]u4 = @splat(0);
    for ([_]usize{ 0, 1, 7, 8, 9, 31, 64, 96 }) |nonzero| lengths[nonzero] = @intCast(1 + nonzero % 15);
    for (0..lengths.len + 1) |start| {
        for (start..lengths.len + 1) |end| {
            var expected = start;
            while (expected < end and lengths[expected] == 0) expected += 1;
            try std.testing.expectEqual(expected, findNonzeroLength(&lengths, start, end));
        }
    }
}

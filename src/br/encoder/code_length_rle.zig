const std = @import("std");

pub const Token = struct {
    symbol: u5,
    extra: u3 = 0,
};

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
    try encodeIntoList(&tokens, lengths, stop_index);
    return tokens.items.len;
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

fn encodeIntoList(tokens: *std.ArrayList(Token), lengths: []const u4, stop_index: usize) !void {
    var i: usize = 0;
    while (i < stop_index) {
        if (lengths[i] != 0) {
            const length = lengths[i];
            var end = i + 1;
            while (end < stop_index and lengths[end] == length) end += 1;
            try appendNonzeroRunBounded(tokens, length, end - i);
            i = end;
            continue;
        }
        var end = i + 1;
        while (end < stop_index and lengths[end] == 0) end += 1;
        try appendZeroRunBounded(tokens, end - i);
        i = end;
    }
}

fn appendNonzeroRunBounded(tokens: *std.ArrayList(Token), length: u4, run: usize) !void {
    try tokens.appendBounded(.{ .symbol = length });
    if (run == 1) return;
    const remaining = run - 1;
    if (remaining < 3) {
        for (0..remaining) |_| try tokens.appendBounded(.{ .symbol = length });
        return;
    }
    try appendRepeatRunBounded(tokens, 16, remaining, 4);
}

fn appendZeroRunBounded(tokens: *std.ArrayList(Token), run: usize) !void {
    if (run < 3) {
        for (0..run) |_| try tokens.appendBounded(.{ .symbol = 0 });
        return;
    }
    try appendRepeatRunBounded(tokens, 17, run, 8);
}

fn appendRepeatRunBounded(tokens: *std.ArrayList(Token), symbol: u5, run: usize, comptime radix: usize) !void {
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
    try tokens.appendBounded(.{ .symbol = symbol, .extra = @intCast(current - 3) });
    while (extra_len != 0) {
        extra_len -= 1;
        try tokens.appendBounded(.{ .symbol = symbol, .extra = extras[extra_len] });
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

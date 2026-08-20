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
            try tokens.append(allocator, .{ .symbol = lengths[i] });
            i += 1;
            continue;
        }
        var end = i + 1;
        while (end < stop_index and lengths[end] == 0) end += 1;
        try appendZeroRun(allocator, &tokens, end - i);
        i = end;
    }
    return tokens.toOwnedSlice(allocator);
}

fn appendZeroRun(allocator: std.mem.Allocator, tokens: *std.ArrayList(Token), run: usize) !void {
    if (run < 3) {
        for (0..run) |_| try tokens.append(allocator, .{ .symbol = 0 });
        return;
    }

    // Reverse the chaining recurrence until the predecessor can be represented
    // by one symbol-17 token (3...10 zeros), then emit the chain forward.
    var extras: [16]u3 = undefined;
    var extra_len: usize = 0;
    var current = run;
    while (current > 10) {
        var extra: usize = 7;
        while (extra != 0 and (current - (extra + 3)) % 8 != 0) extra -= 1;
        const previous = (current - (extra + 3)) / 8 + 2;
        if (previous < 3 or previous >= current) return error.InvalidBlockPlan;
        extras[extra_len] = @intCast(extra);
        extra_len += 1;
        current = previous;
    }
    try tokens.append(allocator, .{ .symbol = 17, .extra = @intCast(current - 3) });
    while (extra_len != 0) {
        extra_len -= 1;
        try tokens.append(allocator, .{ .symbol = 17, .extra = extras[extra_len] });
    }
}

pub fn decodedLength(tokens: []const Token) !usize {
    var total: usize = 0;
    var pending: usize = 0;
    var previous_repeat = false;
    for (tokens) |token| {
        if (token.symbol == 17) {
            const repeat = @as(usize, token.extra) + 3;
            pending = if (previous_repeat) 8 * (pending - 2) + repeat else repeat;
            previous_repeat = true;
        } else {
            total += pending + 1;
            pending = 0;
            previous_repeat = false;
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

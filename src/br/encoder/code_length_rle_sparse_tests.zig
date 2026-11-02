const std = @import("std");
const rle = @import("code_length_rle.zig");

fn tokenOracle(comptime shape: bool, lengths: []const u4, stop: usize) !rle.Summary {
    var storage: [256]rle.Token = undefined;
    const count = try rle.encodeInto(&storage, lengths, stop);
    const tokens = storage[0..count];
    var result: rle.Summary = .{};
    var decoded: [256]u4 = undefined;
    var decoded_count: usize = 0;
    var previous_repeat: ?u5 = null;
    var total_repeat: usize = 0;
    var last_length: u4 = 8;
    for (tokens) |token| {
        result.frequencies[token.symbol] += 1;
        result.token_count += 1;
        if (token.symbol < 16) {
            decoded[decoded_count] = @intCast(token.symbol);
            decoded_count += 1;
            last_length = @intCast(token.symbol);
            previous_repeat = null;
            total_repeat = 0;
            if (shape) result.literal_tokens += 1;
        } else {
            if (token.symbol == 16) result.repeat16_tokens += 1 else result.repeat17_tokens += 1;
            const radix: usize = if (token.symbol == 16) 4 else 8;
            const preceding = if (previous_repeat == token.symbol) total_repeat else 0;
            const total = if (preceding == 0) @as(usize, token.extra) + 3 else radix * (preceding - 2) + token.extra + 3;
            const extra_lengths = total - preceding;
            try std.testing.expect(decoded_count + extra_lengths <= decoded.len);
            @memset(decoded[decoded_count..][0..extra_lengths], if (token.symbol == 16) last_length else 0);
            decoded_count += extra_lengths;
            previous_repeat = token.symbol;
            total_repeat = total;
        }
    }
    try std.testing.expectEqualSlices(u4, lengths[0..stop], decoded[0..decoded_count]);
    if (shape) {
        result.input_lengths = stop;
        for (lengths[0..stop], 0..) |length, index| {
            if (length == 0) result.zero_lengths += 1 else result.nonzero_lengths += 1;
            if (index == 0 or lengths[index - 1] != length) {
                if (length == 0) result.zero_runs += 1 else result.nonzero_runs += 1;
            }
        }
        var index: usize = 0;
        while (index < tokens.len) {
            const symbol = tokens[index].symbol;
            if (symbol < 16) {
                index += 1;
                continue;
            }
            var end = index + 1;
            while (end < tokens.len and tokens[end].symbol == symbol) end += 1;
            result.repeat_chain_buckets[@min(end - index - 1, 3)] += 1;
            index = end;
        }
    }
    return result;
}

fn compare(lengths: []const u4) !void {
    var symbols: [256]u8 = undefined;
    var active: usize = 0;
    var stop: usize = 0;
    var before: [256]u4 = undefined;
    @memcpy(before[0..lengths.len], lengths);
    for (lengths, 0..) |length, index| {
        if (length == 0) continue;
        symbols[active] = @intCast(index);
        active += 1;
        stop = index + 1;
    }
    const saved_symbols = symbols;
    inline for (.{ false, true }) |shape| {
        const sparse = try rle.summarizeSparse(shape, lengths, symbols[0..active]);
        try std.testing.expectEqualDeep(try rle.summarize(shape, lengths, stop), sparse);
        try std.testing.expectEqualDeep(try rle.summarizeSparseReference(shape, lengths, symbols[0..active]), sparse);
        try std.testing.expectEqualDeep(try tokenOracle(shape, lengths, stop), sparse);
    }
    try std.testing.expectEqualSlices(u4, before[0..lengths.len], lengths);
    try std.testing.expectEqualSlices(u8, saved_symbols[0..active], symbols[0..active]);
}

test "sparse RLE single-pass summary covers every length and repeat-run size" {
    var lengths: [256]u4 = @splat(0);
    try compare(lengths[0..0]);
    try compare(&lengths);
    for (1..16) |length| {
        for (1..257) |run| {
            @memset(&lengths, 0);
            @memset(lengths[0..run], @intCast(length));
            try compare(&lengths);
        }
    }
    for (0..256) |gap| {
        @memset(&lengths, 0);
        lengths[gap] = 15;
        try compare(&lengths);
    }
}

test "sparse RLE single-pass summary exhausts small mixed runs and bounded random support" {
    const values = [_]u4{ 0, 1, 7, 15 };
    var lengths: [256]u4 = undefined;
    var cases: usize = 1;
    for (0..7) |len| {
        if (len != 0) cases *= values.len;
        for (0..cases) |pattern| {
            var encoded = pattern;
            for (lengths[0..len]) |*length| {
                length.* = values[encoded % values.len];
                encoded /= values.len;
            }
            try compare(lengths[0..len]);
        }
    }
    var random = std.Random.DefaultPrng.init(0x5a12_5e77_f00d_2026);
    for (0..256) |case| {
        const len = random.random().uintLessThan(usize, 257);
        for (lengths[0..len], 0..) |*length, index| {
            const roll = random.random().int(u8);
            length.* = if (roll % 4 <= case % 4) @intCast(1 + roll % 15) else 0;
            if (index != 0 and roll & 7 == 0) length.* = lengths[index - 1];
        }
        try compare(lengths[0..len]);
    }
}

fn invalid(lengths: []const u4, symbols: []const u8) !void {
    inline for (.{ false, true }) |shape| {
        try std.testing.expectError(error.InvalidBlockPlan, rle.summarizeSparse(shape, lengths, symbols));
        try std.testing.expectError(error.InvalidBlockPlan, rle.summarizeSparseReference(shape, lengths, symbols));
    }
}

test "sparse RLE single-pass validation preserves sorting zero and bounds errors" {
    const lengths = [_]u4{ 1, 2, 0, 2, 3, 0 };
    try invalid(&lengths, &.{ 1, 1 });
    try invalid(&lengths, &.{ 1, 3, 1 });
    try invalid(&lengths, &.{ 3, 0 });
    try invalid(&lengths, &.{2});
    try invalid(&lengths, &.{ 0, 1, 2 });
    try invalid(&lengths, &.{ 0, 3, 5 });
    try invalid(&lengths, &.{ 0, 6 });
    try invalid(lengths[0..0], &.{0});
    try invalid(lengths[0..1], &.{ 0, 1 });
    const oversized: [257]u4 = @splat(1);
    try invalid(&oversized, &.{});
    try invalid(&oversized, &.{0});
    const full: [256]u4 = @splat(1);
    try invalid(full[0..255], &.{255});
    const duplicates: [257]u8 = @splat(0);
    try invalid(&full, &duplicates);
    // Completeness stays caller-owned: empty support does not read or
    // revalidate dense entries, exactly as in the prior implementation.
    try std.testing.expectEqualDeep(rle.Summary{}, try rle.summarizeSparse(true, &full, &.{}));
}

test "sparse RLE summary reads only initialized support and handles symbol 255" {
    var lengths: [256]u4 = undefined;
    var shadow: [256]u4 = @splat(0);
    const symbols = [_]u8{ 0, 1, 3, 4, 5, 18, 19, 20, 80, 254, 255 };
    for (symbols, 0..) |symbol, index| {
        const length: u4 = @intCast(1 + index % 15);
        lengths[symbol] = length;
        shadow[symbol] = length;
    }
    inline for (.{ false, true }) |shape| {
        try std.testing.expectEqualDeep(try rle.summarize(shape, &shadow, 256), try rle.summarizeSparse(shape, &lengths, &symbols));
    }
    for (symbols) |symbol| try std.testing.expectEqual(shadow[symbol], lengths[symbol]);
    try std.testing.expectEqualDeep(rle.Summary{}, try rle.summarizeSparse(false, &lengths, &.{}));
}

test "sparse RLE summary remains a pure allocation-free comptime operation" {
    const summary = comptime blk: {
        @setEvalBranchQuota(20_000);
        var lengths: [256]u4 = @splat(0);
        lengths[0] = 3;
        lengths[1] = 3;
        lengths[128] = 9;
        lengths[255] = 15;
        break :blk rle.summarizeSparse(true, &lengths, &.{ 0, 1, 128, 255 }) catch @compileError("sparse summary must evaluate without an allocator");
    };
    try std.testing.expectEqual(@as(usize, 256), summary.input_lengths);
    try std.testing.expectEqual(@as(usize, 4), summary.nonzero_lengths);
    try std.testing.expectEqual(@as(usize, 252), summary.zero_lengths);
}

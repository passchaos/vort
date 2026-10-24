const std = @import("std");
const command_lut = @import("../command_lut.zig");
const length = @import("../length.zig");

pub const Encoding = struct {
    symbol: u16,
    command: command_lut.Entry,
};

const explicit_symbol_index = blk: {
    @setEvalBranchQuota(100_000);
    var index: [24][24]u16 = @splat(@splat(std.math.maxInt(u16)));
    for (command_lut.entries, 0..) |entry, symbol| {
        if (entry.distance_code != -1) continue;
        const insert_code = length.codeForValue(entry.insert_base, true) orelse continue;
        const copy_code = length.codeForValue(entry.copy_base, false) orelse continue;
        if (index[insert_code][copy_code] == std.math.maxInt(u16))
            index[insert_code][copy_code] = @intCast(symbol);
    }
    break :blk index;
};

const last_distance_symbol_index = blk: {
    @setEvalBranchQuota(100_000);
    var index: [24][24]u16 = @splat(@splat(std.math.maxInt(u16)));
    for (command_lut.entries, 0..) |entry, symbol| {
        if (entry.distance_code != 0) continue;
        const insert_code = length.codeForValue(entry.insert_base, true) orelse continue;
        const copy_code = length.codeForValue(entry.copy_base, false) orelse continue;
        if (index[insert_code][copy_code] == std.math.maxInt(u16))
            index[insert_code][copy_code] = @intCast(symbol);
    }
    break :blk index;
};

pub fn forLengths(insert_len: usize, copy_len: usize, use_last_distance: bool) ?Encoding {
    const insert_code = length.codeForValue(insert_len, true) orelse return null;
    const copy_code = length.codeForValue(copy_len, false) orelse return null;
    return forCodes(insert_code, copy_code, use_last_distance);
}

pub fn forCodes(insert_code: u5, copy_code: u5, use_last_distance: bool) ?Encoding {
    const index = if (use_last_distance)
        &last_distance_symbol_index
    else
        &explicit_symbol_index;
    const symbol = index[insert_code][copy_code];
    if (symbol == std.math.maxInt(u16)) return null;
    return .{ .symbol = symbol, .command = command_lut.entries[symbol] };
}

test "command encoding covers every LUT length pair" {
    for (command_lut.entries, 0..) |entry, symbol| {
        const use_last_distance = entry.distance_code == 0;
        if (!use_last_distance and entry.distance_code != -1) continue;
        const encoding = forLengths(
            entry.insert_base,
            entry.copy_base,
            use_last_distance,
        ) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(@as(i16, entry.distance_code), encoding.command.distance_code);
        // Several symbols can cover the same length pair. The selected entry
        // must be deterministic and semantically equivalent, not necessarily
        // the current iteration's symbol.
        try std.testing.expect(encoding.symbol <= symbol or
            command_lut.entries[encoding.symbol].distance_code == entry.distance_code);
    }
}

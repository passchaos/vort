//! Admission budget for new literal-only candidates in planned encoders.
//! This predicts one-tree profitability; it is not a bound on every possible
//! context model. Accepted candidates still use complete-wire arbitration.
const std = @import("std");
const command_plan = @import("command_plan.zig");
const complex_prefix = @import("complex_prefix.zig");

pub fn shouldTry(allocator: std.mem.Allocator, input: []const u8) !bool {
    if (input.len < 5) return false;
    var frequencies: [256]u32 = @splat(0);
    for (input) |byte| frequencies[byte] += 1;
    var alphabet: command_plan.PrefixAlphabetFor(256) = undefined;
    try command_plan.alphabetFromFrequenciesInto(256, &alphabet, &frequencies);
    const lengths = try alphabet.codeLengths(&frequencies);
    var bits: u64 = 0;
    for (&frequencies, &lengths) |frequency, length| bits += @as(u64, frequency) * length;
    const tree_bits: u64 = if (alphabet.len <= 4)
        4 + @as(u64, alphabet.len) * 8 + @intFromBool(alphabet.len == 4)
    else blk: {
        var highest: usize = 0;
        for (alphabet.symbols[0..alphabet.len]) |symbol| highest = @max(highest, symbol);
        break :blk try complex_prefix.bitCost(allocator, 256, &lengths, highest + 1);
    };
    // Reserve eight bytes for command/framing overhead before admitting the
    // more expensive context and split proposals. Actual wire length wins.
    return bits + tree_bits + 64 < @as(u64, input.len) * 8;
}

const std = @import("std");
const command_encoding = @import("../command_encoding.zig");
const distance = @import("../distance.zig");
const history = @import("../../decoder/distance_history.zig");

fn lengthWidth(symbol: usize) usize {
    return if (symbol < 16) 2 + symbol / 4 else if (symbol < 18) 6 else if (symbol == 25) 24 else symbol - 11;
}

fn lengthBase(symbol: usize) usize {
    var base: usize = 1;
    for (0..symbol) |previous| base += @as(usize, 1) << @intCast(lengthWidth(previous));
    return base;
}

fn symbolBits(alphabet: anytype, lengths: anytype, symbol: u16, simple: bool) !u64 {
    if (alphabet.len == 1) return 0;
    if (simple and alphabet.len <= 4) return (alphabet.simpleCode(symbol) orelse return error.TestUnexpectedResult).bits;
    return lengths[symbol];
}

/// Replay commands and flatten literals by plan regions. The oracle neither
/// reads Prepared.payload_bits nor reuses its frequency collector/writer.
pub fn payload(input: []const u8, commands: anytype, options: anytype, prepared: anytype) !u64 {
    var bits: u64 = 0;
    var recent = options.starting_last_distances;
    var literals: std.ArrayList(u8) = .empty;
    defer literals.deinit(std.testing.allocator);
    for (commands) |item| {
        const short = if (item.has_copy) history.symbolForDistance(item.distance, &recent) else null;
        const encoded = command_encoding.forLengths(item.insert_len, item.copy_len, short == 0) orelse command_encoding.forLengths(item.insert_len, item.copy_len, false).?;
        bits += try symbolBits(&prepared.common.command_alphabet, &prepared.common.command_lengths, encoded.symbol, true);
        bits += @as(u64, encoded.command.insert_extra_bits) + encoded.command.copy_extra_bits;
        try literals.appendSlice(std.testing.allocator, input[item.insert_start..][0..item.insert_len]);
        if (item.has_copy and encoded.command.distance_code == -1) {
            const wire = if (short) |symbol| distance.Encoding{ .symbol = symbol } else distance.encodeWithFormat(item.distance, options.distance_parameters, .standard).?;
            bits += try symbolBits(&prepared.common.distance_alphabet, &prepared.common.distance_lengths, wire.symbol, true);
            bits += wire.extra_bits;
        }
        if (item.has_copy and short != 0) history.push(&recent, item.distance);
    }
    const plan = options.adaptive_literal_split.?;
    var offset: usize = 0;
    for (plan.lengths, plan.types) |len, tree| {
        for (literals.items[offset..][0..len]) |literal| bits += prepared.lengths[tree][literal];
        offset += len;
    }
    try std.testing.expectEqual(literals.items.len, offset);
    var previous_type: usize = 1;
    var current_type: usize = 0;
    for (1..plan.blockCount()) |block| {
        const type_symbol = prepared.split_code.type_model.symbols[block - 1];
        const next_type = if (type_symbol == 0) previous_type else if (type_symbol == 1) (current_type + 1) % plan.type_count else type_symbol - 2;
        try std.testing.expectEqual(@as(usize, plan.types[block]), next_type);
        previous_type = current_type;
        current_type = next_type;
        bits += try symbolBits(&prepared.split_code.type_alphabet, &prepared.split_code.type_lengths, type_symbol, true);
        const encoding = prepared.split_code.block_lengths[block];
        const base = lengthBase(encoding.symbol);
        const width = lengthWidth(encoding.symbol);
        try std.testing.expectEqual(@as(usize, plan.lengths[block]), base + encoding.extra);
        try std.testing.expectEqual(width, @as(usize, encoding.extra_bits));
        bits += try symbolBits(&prepared.split_code.length_alphabet, &prepared.split_code.length_lengths, encoding.symbol, true);
        bits += width;
    }
    return bits;
}

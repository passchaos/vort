const std = @import("std");
const mf = @import("../match_finder.zig");
const types = @import("types.zig");
pub const unit: u32 = 64;

const probabilities = table: {
    @setEvalBranchQuota(100000);
    var prices: [2049]u16 = undefined;
    prices[0] = 11 * unit;
    for (1..prices.len) |p| prices[p] = @intFromFloat(@round((11.0 - @log2(@as(f64, @floatFromInt(p)))) * unit));
    break :table prices;
};

pub fn bit(probability: u16, value: bool) u32 {
    const p = std.math.clamp(@as(usize, probability), 1, 2047);
    return probabilities[if (value) 2048 - p else p];
}
fn tree(probs: anytype, symbol: usize, bits: usize) u32 {
    var index: usize = 1;
    var result: u32 = 0;
    var left = bits;
    while (left != 0) {
        left -= 1;
        const value = (symbol >> @intCast(left)) & 1;
        result += bit(probs[index], value != 0);
        index = (index << 1) | value;
    }
    return result;
}
fn reverseTree(probs: anytype, offset: usize, symbol: usize, bits: usize) u32 {
    var index: usize = 1;
    var result: u32 = 0;
    for (0..bits) |i| {
        const value = symbol >> @intCast(i) & 1;
        result += bit(probs[offset + index], value != 0);
        index = (index << 1) | value;
    }
    return result;
}
fn lengthPrice(encoder: anytype, symbol: usize, position_state: usize) u32 {
    if (symbol < 8) return bit(encoder.choice, false) + tree(encoder.low[position_state], symbol, 3);
    if (symbol < 16) return bit(encoder.choice, true) + bit(encoder.choice2, false) + tree(encoder.mid[position_state], symbol - 8, 3);
    return bit(encoder.choice, true) + bit(encoder.choice2, true) + tree(encoder.high, symbol - 16, 8);
}

pub const Lengths = struct {
    normal: [16][272]u32,
    repeated: [16][272]u32,

    pub fn init(model: anytype) Lengths {
        var result: Lengths = undefined;
        for (0..16) |position| for (0..272) |symbol| {
            result.normal[position][symbol] = lengthPrice(model.length, symbol, position);
            result.repeated[position][symbol] = lengthPrice(model.rep_length, symbol, position);
        };
        return result;
    }
};

pub fn literal(model: anytype, source: mf.Source, position: usize, stream_start: usize, state: types.State) u32 {
    const stream_position = stream_start + position;
    const position_state = stream_position & ((@as(usize, 1) << model.properties.pb) - 1);
    var result = bit(model.is_match[(@as(usize, state.state) << 4) + position_state], false);
    const absolute = source.prefixLen() + position;
    const previous: usize = if (absolute == 0) 0 else source.byteAt(absolute - 1);
    const context = ((stream_position & ((@as(usize, 1) << model.properties.lp) - 1)) << model.properties.lc) + (previous >> (8 - model.properties.lc));
    const probs = &model.literal_probabilities[context];
    const byte: usize = source.input[position];
    var index: usize = 1;
    var bits: usize = 8;
    if (state.state >= 7) {
        const repeat_distance: usize = state.reps[0] + 1;
        if (repeat_distance > absolute) return std.math.maxInt(u32) / 4;
        var matched: usize = source.byteAt(absolute - repeat_distance);
        while (index < 0x100) {
            bits -= 1;
            const match_bit = matched >> 7 & 1;
            matched <<= 1;
            const value = byte >> @intCast(bits) & 1;
            result += bit(probs[((1 + match_bit) << 8) + index], value != 0);
            index = (index << 1) | value;
            if (match_bit != value) break;
        }
    }
    while (index < 0x100) {
        bits -= 1;
        const value = byte >> @intCast(bits) & 1;
        result += bit(probs[index], value != 0);
        index = (index << 1) | value;
    }
    return result;
}
pub fn repeatedBase(model: anytype, state: types.State, position_state: usize, index: usize, short: bool) u32 {
    const s: usize = state.state;
    var result = bit(model.is_match[(s << 4) + position_state], true) + bit(model.is_rep[s], true);
    result += bit(model.is_rep_g0[s], index != 0);
    if (index == 0) {
        result += bit(model.is_rep_0long[(s << 4) + position_state], !short);
    } else {
        result += bit(model.is_rep_g1[s], index != 1);
        if (index != 1) result += bit(model.is_rep_g2[s], index == 3);
    }
    return result;
}
pub fn normalBase(model: anytype, state: types.State, position_state: usize) u32 {
    const s: usize = state.state;
    return bit(model.is_match[(s << 4) + position_state], true) + bit(model.is_rep[s], false);
}
pub fn distance(model: anytype, length_state: usize, offset: usize) u32 {
    const slot = distanceSlot(offset);
    var result = tree(model.position_slots[length_state], slot, 6);
    if (slot < 4) return result;
    const direct_bits = (slot >> 1) - 1;
    const base = (2 | (slot & 1)) << @intCast(direct_bits);
    const remainder = offset - base;
    if (slot < 14) return result + reverseTree(model.positions, base - slot, remainder, direct_bits);
    result += @as(u32, @intCast(direct_bits - 4)) * unit;
    return result + reverseTree(model.alignment, 0, remainder & 15, 4);
}
pub fn decision(model: anytype, lengths: *const Lengths, source: mf.Source, position: usize, stream_start: usize, state: types.State, selected: types.Decision) u32 {
    if (selected.distance == 0) return literal(model, source, position, stream_start, state);
    const ps = (stream_start + position) & ((@as(usize, 1) << model.properties.pb) - 1);
    if (state.repIndex(selected.distance)) |index| {
        const base = repeatedBase(model, state, ps, index, selected.length == 1);
        return if (selected.length == 1) base else base + lengths.repeated[ps][selected.length - 2];
    }
    return normalBase(model, state, ps) + lengths.normal[ps][selected.length - 2] + distance(model, @min(selected.length - 2, 3), selected.distance - 1);
}
pub fn distanceSlot(offset: usize) usize {
    if (offset < 4) return offset;
    const highest = @bitSizeOf(usize) - 1 - @clz(offset);
    return (highest << 1) | (offset >> @intCast(highest - 1) & 1);
}

//! Fixed/stored Deflate64 emission into admitted caller storage. Planning and
//! emission replay the same bounded matcher, with no retained token array.
const std = @import("std");
const huffman = @import("../huffman.zig");
const matching = @import("stream_match.zig");

pub const State = struct { scratch: u32 = 0, bit_index: u3 = 0 };
pub const Stats = struct {
    match_count: usize = 0,
    max_match_length: usize = 0,
    max_match_distance: usize = 0,
};
pub const Plan = struct { bits: usize, stats: Stats };
const Extra = struct { symbol: u16, bits: u5, value: u16 };

pub const Writer = struct {
    state: State,
    output: []u8,
    len: usize = 0,

    pub fn bits(self: *Writer, value: u16, count: u5) void {
        std.debug.assert(count <= 16);
        self.state.scratch |= @as(u32, value) << @as(u5, self.state.bit_index);
        var live: u5 = @as(u5, self.state.bit_index) + count;
        while (live >= 8) {
            self.output[self.len] = @truncate(self.state.scratch);
            self.len += 1;
            self.state.scratch >>= 8;
            live -= 8;
        }
        self.state.bit_index = @intCast(live);
    }
    pub fn alignToByte(self: *Writer) void {
        if (self.state.bit_index == 0) return;
        self.output[self.len] = @truncate(self.state.scratch);
        self.len += 1;
        self.state = .{};
    }
    fn literal(self: *Writer, symbol: u16) void {
        self.bits(huffman.fixed_literal_encoder.codes[symbol], huffman.fixed_literal_encoder.bits[symbol]);
    }
    fn match(self: *Writer, value: matching.Match) void {
        const length = lengthCode(value.length);
        self.literal(length.symbol);
        self.bits(length.value, length.bits);
        const distance = distanceCode(value.distance);
        self.bits(huffman.fixed_distance_encoder.codes[distance.symbol], 5);
        self.bits(distance.value, distance.bits);
    }
};

pub fn fixedPlan(matcher: *matching.Matcher, history: []const u8, block: []const u8, max_chain: usize, nice_length: usize) Plan {
    if (block.len == 0) return .{ .bits = 10, .stats = .{} };
    matcher.begin(history, block);
    var plan: Plan = .{ .bits = 3 + 7, .stats = .{} };
    var position: usize = 0;
    while (position < block.len) {
        const current = history.len + position;
        const match = matcher.find(current, max_chain, nice_length);
        const take = if (match.length >= 3) match.length else 1;
        if (match.length >= 3) {
            const length = lengthCode(match.length);
            const distance = distanceCode(match.distance);
            plan.bits += @as(usize, huffman.fixed_literal_encoder.bits[length.symbol]) + length.bits + 5 + distance.bits;
            plan.stats.match_count += 1;
            plan.stats.max_match_length = @max(plan.stats.max_match_length, match.length);
            plan.stats.max_match_distance = @max(plan.stats.max_match_distance, match.distance);
        } else plan.bits += huffman.fixed_literal_encoder.bits[block[position]];
        for (current..current + take) |inserted| matcher.insert(inserted);
        position += take;
    }
    return plan;
}

pub fn writeFixed(writer: *Writer, matcher: *matching.Matcher, history: []const u8, block: []const u8, max_chain: usize, nice_length: usize, final: bool) void {
    writer.bits(0b010 | @as(u16, @intFromBool(final)), 3);
    if (block.len == 0) {
        writer.literal(256);
        return;
    }
    matcher.begin(history, block);
    var position: usize = 0;
    while (position < block.len) {
        const current = history.len + position;
        const match = matcher.find(current, max_chain, nice_length);
        const take = if (match.length >= 3) match.length else 1;
        if (match.length >= 3) writer.match(match) else writer.literal(block[position]);
        for (current..current + take) |inserted| matcher.insert(inserted);
        position += take;
    }
    writer.literal(256);
}

pub fn storedBlockCount(length: usize) usize {
    return if (length == 0) 1 else (length - 1) / 65_535 + 1;
}
/// Includes the padding needed after the first three-bit stored header from
/// the current continuous stream position. Following stored segments align.
pub fn storedBits(state: State, length: usize) usize {
    const after_header = @as(usize, state.bit_index) + 3;
    const padding = (8 - after_header % 8) % 8;
    return 3 + padding + 32 + length * 8 + (storedBlockCount(length) - 1) * 40;
}
pub fn writeStored(writer: *Writer, block: []const u8, final: bool) void {
    var position: usize = 0;
    const count = storedBlockCount(block.len);
    for (0..count) |part| {
        const take = @min(@as(usize, 65_535), block.len - position);
        writer.bits(@intFromBool(final and part + 1 == count), 3);
        writer.alignToByte();
        const len: u16 = @intCast(take);
        std.mem.writeInt(u16, writer.output[writer.len..][0..2], len, .little);
        std.mem.writeInt(u16, writer.output[writer.len + 2 ..][0..2], ~len, .little);
        writer.len += 4;
        @memcpy(writer.output[writer.len..][0..take], block[position..][0..take]);
        writer.len += take;
        position += take;
    }
}
pub fn writePartial(writer: *Writer) void {
    writer.bits(0b010, 3);
    writer.literal(256);
}
pub fn pendingBytes(state: State, bits: usize, final: bool) usize {
    const total = @as(usize, state.bit_index) + bits;
    return if (final) (total + 7) / 8 else total / 8;
}

fn lengthCode(length: usize) Extra {
    std.debug.assert(length >= 3 and length <= matching.max_match_len);
    if (length > 258) return .{ .symbol = 285, .bits = 16, .value = @intCast(length - 3) };
    if (length <= 10) return .{ .symbol = @intCast(length + 254), .bits = 0, .value = 0 };
    const bits: u5 = @intCast(std.math.log2_int(usize, length - 3) - 2);
    const span: usize = @as(usize, 1) << @intCast(bits);
    const base = (@as(usize, 1) << @intCast(@as(u8, bits) + 2)) + 3;
    const offset = length - base;
    return .{ .symbol = @intCast(261 + @as(usize, bits) * 4 + offset / span), .bits = bits, .value = @intCast(offset & (span - 1)) };
}
fn distanceCode(distance: usize) Extra {
    std.debug.assert(distance >= 1 and distance <= matching.window_len);
    if (distance <= 4) return .{ .symbol = @intCast(distance - 1), .bits = 0, .value = 0 };
    const bits: u5 = @intCast(std.math.log2_int(usize, distance - 1) - 1);
    const span: usize = @as(usize, 1) << @intCast(bits);
    const base = (@as(usize, 1) << @intCast(@as(u8, bits) + 1)) + 1;
    const offset = distance - base;
    return .{ .symbol = @intCast(2 + @as(usize, bits) * 2 + offset / span), .bits = bits, .value = @intCast(offset & (span - 1)) };
}

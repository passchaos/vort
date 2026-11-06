const std = @import("std");
const h = @import("helpers.zig");

/// Independent RFC 1951 bit-field writer. It deliberately calls no encoder,
/// Huffman builder, or decoder implementation to construct the contract wires.
const Bits = struct {
    bytes: std.ArrayList(u8) = .empty,
    byte: u8 = 0,
    used: u4 = 0,

    fn put(self: *Bits, value: u32, width: u6) !void {
        var remaining = width;
        var word = value;
        while (remaining != 0) : (remaining -= 1) {
            self.byte |= @as(u8, @intCast(word & 1)) << @intCast(self.used);
            self.used += 1;
            word >>= 1;
            if (self.used == 8) {
                try self.bytes.append(h.allocator, self.byte);
                self.byte = 0;
                self.used = 0;
            }
        }
    }

    fn symbol(self: *Bits, code: u32, width: u6) !void {
        var reverse: u32 = 0;
        for (0..width) |i| reverse = (reverse << 1) | ((code >> @intCast(i)) & 1);
        try self.put(reverse, width);
    }

    fn fixed(self: *Bits, value: usize) !void {
        if (value <= 143) return self.symbol(@intCast(0x30 + value), 8);
        if (value <= 255) return self.symbol(@intCast(0x190 + value - 144), 9);
        if (value <= 279) return self.symbol(@intCast(value - 256), 7);
        return self.symbol(@intCast(0xc0 + value - 280), 8);
    }

    fn finish(self: *Bits) ![]u8 {
        if (self.used != 0) try self.put(0, @intCast(8 - self.used));
        return self.bytes.toOwnedSlice(h.allocator);
    }
};

pub fn fixedEmpty() ![]u8 {
    var bits: Bits = .{};
    errdefer bits.bytes.deinit(h.allocator);
    try bits.put(3, 3);
    try bits.fixed(256);
    return bits.finish();
}

/// Final fixed block: length three / distance one, then EOB. The first token
/// needs the history retained from the repeated stored prefix.
pub fn fixedMatch() ![]u8 {
    var bits: Bits = .{};
    errdefer bits.bytes.deinit(h.allocator);
    try bits.put(3, 3);
    try bits.fixed(257);
    try bits.symbol(0, 5);
    try bits.fixed(256);
    return bits.finish();
}

pub const dynamic_output_len = 5000 + 258;

/// Complete trees: 226 literal symbols of width 8 and 60 of width 9;
/// two distances of width 4 and 28 of width 5. Four code-length symbols
/// {4,5,8,9} all have width 2. This exceeds the semantic input threshold.
pub fn dynamicMatch(comptime deflate64: bool) ![]u8 {
    return dynamicFixture(deflate64, false);
}

/// Nonfinal dynamic output ends in 'y'. A subsequent fixed match must read
/// that byte from the retained semantic/compact history across the boundary.
pub fn dynamicThenFixed() ![]u8 {
    return dynamicFixture(false, true);
}

fn dynamicFixture(comptime deflate64: bool, comptime continuation: bool) ![]u8 {
    var bits: Bits = .{};
    errdefer bits.bytes.deinit(h.allocator);
    try bits.put(if (continuation) 4 else 5, 3);
    try bits.put(29, 5); // 286 literal/length symbols.
    try bits.put(29, 5); // 30 distance symbols.
    try bits.put(8, 4); // 12 code-length symbols.
    for ([_]usize{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4 }) |value|
        try bits.put(if (value == 4 or value == 5 or value == 8 or value == 9) 2 else 0, 3);
    // Canonical code-length alphabet: 4->00, 5->01, 8->10, 9->11.
    for (0..286) |value| try bits.symbol(if (value < 226) 2 else 3, 2);
    for (0..30) |value| try bits.symbol(if (value < 2) 0 else 1, 2);
    for (0..5000) |_| try bits.symbol('x', 8);
    // First width-9 literal code is 452, at symbol 226.
    try bits.symbol(452 + 285 - 226, 9);
    if (deflate64) try bits.put(255, 16); // Deflate64 285: 3+255=258.
    try bits.symbol(0, 4); // distance one.
    if (continuation) try bits.symbol('y', 8);
    try bits.symbol(452 + 256 - 226, 9);
    if (continuation) {
        try bits.put(3, 3);
        try bits.fixed(257);
        try bits.symbol(0, 5);
        try bits.fixed(256);
    }
    return bits.finish();
}

/// Deflate64's 16-bit extended length and largest distance code both execute
/// against a full all-'x' 64 KiB ring after the lawful stored prefix.
pub fn extended64() ![]u8 {
    var bits: Bits = .{};
    errdefer bits.bytes.deinit(h.allocator);
    try bits.put(3, 3);
    try bits.fixed(285);
    try bits.put(1024, 16); // length 1027, distance one.
    try bits.symbol(0, 5);
    try bits.fixed(257); // length three, distance 65536.
    try bits.symbol(31, 5);
    try bits.put(16383, 14);
    try bits.fixed(256);
    return bits.finish();
}

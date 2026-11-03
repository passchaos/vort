//! Independent RFC 1951 fixtures. Canonical codes and a byte-at-a-time output
//! oracle are implemented here rather than borrowing decoder match copying.
const std = @import("std");
const Allocator = std.mem.Allocator;
const window: usize = 32768;
pub const suffix = [_]u8{ 0xd3, 0x5e, 0xf1, 0x07 };

pub const Fixture = struct {
    encoded: []u8,
    payload: []u8,
    body_len: usize,

    pub fn deinit(self: Fixture, allocator: Allocator) void {
        allocator.free(self.encoded);
        allocator.free(self.payload);
    }
};

const Builder = struct {
    allocator: Allocator,
    encoded: std.ArrayList(u8) = .empty,
    payload: std.ArrayList(u8) = .empty,
    dictionary: []const u8 = &.{},
    bucket: u8 = 0,
    used: u4 = 0,
    literal_lengths: [286]u4 = undefined,
    distance_lengths: [30]u4 = undefined,

    fn deinit(self: *Builder) void {
        self.encoded.deinit(self.allocator);
        self.payload.deinit(self.allocator);
    }

    fn bits(self: *Builder, value: u32, count: u6) !void {
        var remaining = count;
        var word = value;
        while (remaining != 0) : (remaining -= 1) {
            self.bucket |= @as(u8, @intCast(word & 1)) << @intCast(self.used);
            self.used += 1;
            word >>= 1;
            if (self.used == 8) {
                try self.encoded.append(self.allocator, self.bucket);
                self.bucket = 0;
                self.used = 0;
            }
        }
    }

    fn alignByte(self: *Builder) !void {
        if (self.used != 0) try self.bits(0, @intCast(8 - self.used));
    }

    fn canonical(self: *Builder, lengths: []const u4, symbol: usize) !void {
        var counts: [16]u32 = @splat(0);
        for (lengths) |length| counts[length] += 1;
        counts[0] = 0;
        var code: u32 = 0;
        for (1..@as(usize, lengths[symbol]) + 1) |width| code = (code + counts[width - 1]) << 1;
        for (lengths[0..symbol]) |length| {
            if (length == lengths[symbol]) code += 1;
        }
        var reversed: u32 = 0;
        for (0..lengths[symbol]) |_| {
            reversed = (reversed << 1) | (code & 1);
            code >>= 1;
        }
        try self.bits(reversed, lengths[symbol]);
    }

    fn dynamic(self: *Builder, final: bool) !void {
        try self.bits(if (final) 5 else 4, 3);
        try self.bits(29, 5); // HLIT = 286.
        try self.bits(29, 5); // HDIST = 30.
        try self.bits(8, 4); // HCLEN = 12.
        var code_lengths: [19]u4 = @splat(0);
        for ([_]usize{ 4, 5, 8, 9 }) |symbol| code_lengths[symbol] = 2;
        const order = [_]usize{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4 };
        for (order) |symbol| try self.bits(code_lengths[symbol], 3);
        for (&self.literal_lengths, 0..) |*length, symbol| length.* = if (symbol < 226) 8 else 9;
        for (&self.distance_lengths, 0..) |*length, symbol| length.* = if (symbol < 2) 4 else 5;
        for (self.literal_lengths) |length| try self.canonical(&code_lengths, length);
        for (self.distance_lengths) |length| try self.canonical(&code_lengths, length);
    }

    fn fixed(self: *Builder, final: bool) !void {
        try self.bits(if (final) 3 else 2, 3);
    }

    fn fixedSymbol(self: *Builder, symbol: usize) !void {
        const width: u6 = if (symbol <= 143) 8 else if (symbol <= 255) 9 else if (symbol <= 279) 7 else 8;
        var code: u32 = @intCast(if (symbol <= 143) 0x30 + symbol else if (symbol <= 255) 0x190 + symbol - 144 else if (symbol <= 279) symbol - 256 else 0xc0 + symbol - 280);
        var reversed: u32 = 0;
        for (0..width) |_| {
            reversed = (reversed << 1) | (code & 1);
            code >>= 1;
        }
        try self.bits(reversed, width);
    }

    fn literal(self: *Builder, value: u8) !void {
        try self.canonical(&self.literal_lengths, value);
        try self.payload.append(self.allocator, value);
    }

    fn dynamicEnd(self: *Builder) !void {
        try self.canonical(&self.literal_lengths, 256);
    }

    fn oracleMatch(self: *Builder, length: usize, distance: usize) !void {
        for (0..length) |_| {
            const source = self.dictionary.len + self.payload.items.len - distance;
            const value = if (source < self.dictionary.len)
                self.dictionary[source]
            else
                self.payload.items[source - self.dictionary.len];
            try self.payload.append(self.allocator, value);
        }
    }

    fn match258(self: *Builder, distance: usize, is_fixed: bool) !void {
        if (is_fixed) try self.fixedSymbol(285) else try self.canonical(&self.literal_lengths, 285);
        const bases = [_]usize{ 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 };
        var symbol: usize = 0;
        while (symbol + 1 < bases.len and bases[symbol + 1] <= distance) : (symbol += 1) {}
        const extra: u6 = if (symbol < 4) 0 else @intCast(symbol / 2 - 1);
        if (is_fixed) {
            var code: u32 = @intCast(symbol);
            var reversed: u32 = 0;
            for (0..5) |_| {
                reversed = (reversed << 1) | (code & 1);
                code >>= 1;
            }
            try self.bits(reversed, 5);
        } else try self.canonical(&self.distance_lengths, symbol);
        try self.bits(@intCast(distance - bases[symbol]), extra);
        try self.oracleMatch(258, distance);
    }

    fn stored(self: *Builder, len: usize) !void {
        std.debug.assert(len <= 65535);
        try self.bits(0, 3);
        try self.alignByte();
        try self.bits(@intCast(len), 16);
        try self.bits(@as(u16, @truncate(len)) ^ 0xffff, 16);
        const start = self.payload.items.len;
        for (0..len) |index| {
            const value = pattern(start + index);
            try self.bits(value, 8);
            try self.payload.append(self.allocator, value);
        }
    }

    fn finish(self: *Builder) !Fixture {
        try self.alignByte();
        const body_len = self.encoded.items.len;
        try self.encoded.appendSlice(self.allocator, &suffix);
        const encoded = try self.encoded.toOwnedSlice(self.allocator);
        errdefer self.allocator.free(encoded);
        return .{
            .encoded = encoded,
            .payload = try self.payload.toOwnedSlice(self.allocator),
            .body_len = body_len,
        };
    }
};

fn pattern(index: usize) u8 {
    return @truncate((index *% 73) ^ (index >> 8) ^ (index >> 12) ^ 0x9b);
}

pub fn multiWindow(allocator: Allocator, prelude_len: usize) !Fixture {
    var builder: Builder = .{ .allocator = allocator };
    defer builder.deinit();
    if (prelude_len != 0) try builder.stored(prelude_len);
    try builder.dynamic(true);
    for (0..window) |index| try builder.literal(pattern(index));
    const distances = [_]usize{ window, 1, 2, 3, 4, 16, 258 };
    for (0..263) |index| try builder.match258(distances[index % distances.len], false);
    for (0..17) |index| try builder.literal(pattern(index + 137));
    try builder.dynamicEnd();
    return builder.finish();
}

pub fn transitions(allocator: Allocator) !Fixture {
    var builder: Builder = .{ .allocator = allocator };
    defer builder.deinit();
    try builder.dynamic(false);
    for (0..window) |index| try builder.literal(pattern(index));
    try builder.match258(window, false);
    for (0..17) |index| try builder.literal(pattern(index + 311));
    try builder.dynamicEnd();
    try builder.fixed(false);
    try builder.match258(window, true);
    try builder.fixedSymbol(256);
    try builder.stored(17);
    try builder.fixed(true);
    try builder.match258(window, true);
    try builder.fixedSymbol(256);
    return builder.finish();
}

pub fn shortDynamic(allocator: Allocator) !Fixture {
    var builder: Builder = .{ .allocator = allocator };
    defer builder.deinit();
    try builder.dynamic(true);
    for (0..97) |index| try builder.literal(pattern(index));
    try builder.dynamicEnd();
    return builder.finish();
}

pub fn dictionaryDynamic(allocator: Allocator, dictionary: []const u8) !Fixture {
    var builder: Builder = .{ .allocator = allocator, .dictionary = dictionary };
    defer builder.deinit();
    try builder.dynamic(true);
    try builder.match258(@min(window, dictionary.len), false);
    for (0..8192) |index| try builder.literal(pattern(index));
    try builder.dynamicEnd();
    return builder.finish();
}

/// Complete sparse literal tree whose packed B/C pair leaves one A literal
/// before a 258-byte match that cannot fit in the current private window.
pub fn capacityRegression(allocator: Allocator) !Fixture {
    var builder: Builder = .{ .allocator = allocator };
    defer builder.deinit();
    try capacityPrefix(&builder);
    try builder.dynamicEnd();
    return builder.finish();
}

fn capacityPrefix(builder: *Builder) !void {
    try builder.bits(5, 3); // Final dynamic block.
    try builder.bits(29, 5); // HLIT = 286.
    try builder.bits(0, 5); // HDIST = 1.
    try builder.bits(15, 4); // HCLEN = 19.
    var code_lengths: [19]u4 = @splat(0);
    for (code_lengths[0..16]) |*length| length.* = 4;
    const order = [_]usize{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
    for (order) |symbol| try builder.bits(code_lengths[symbol], 3);
    builder.literal_lengths = @splat(0);
    builder.literal_lengths['A'] = 2;
    builder.literal_lengths['B'] = 2;
    builder.literal_lengths['C'] = 3;
    builder.literal_lengths[256] = 3;
    builder.literal_lengths[261] = 3;
    builder.literal_lengths[285] = 3;
    builder.distance_lengths = @splat(0);
    builder.distance_lengths[0] = 1;
    for (builder.literal_lengths) |length| try builder.canonical(&code_lengths, length);
    try builder.canonical(&code_lengths, 1);

    try builder.literal('A');
    try builder.canonical(&builder.literal_lengths, 261); // Length 7, no extra bits.
    try builder.canonical(&builder.distance_lengths, 0); // Distance 1.
    try builder.oracleMatch(7, 1);
    for (0..32502) |_| try builder.literal('A');
    for ("BCA") |value| try builder.literal(value);
    try builder.match258(1, false);
    for (0..64) |_| try builder.literal('A');
}

/// The invalid singleton distance bit follows several committed generations.
/// Encoded-only padding preserves fast-loop readable headroom beyond the fault.
pub fn invalidSingletonAfterWindows(allocator: Allocator) !Fixture {
    var builder: Builder = .{ .allocator = allocator };
    defer builder.deinit();
    try capacityPrefix(&builder);
    for (0..400) |index| {
        try builder.literal("ABC"[index % 3]);
        try builder.match258(1, false);
    }
    for (0..17) |_| try builder.literal('A');
    try builder.canonical(&builder.literal_lengths, 285);
    try builder.bits(1, 1); // The sole legal distance code is bit zero.
    for (0..8192) |_| try builder.canonical(&builder.literal_lengths, 'A');
    try builder.dynamicEnd();
    return builder.finish();
}

//! Exact linear/rolling token comparisons, including wrapped optimized stores
//! and a reservoir populated from a different input slice.
const std = @import("std");
const semantic = @import("decoder.zig");
const windows = @import("rolling_window.zig");
const bitstream = @import("../../bitstream.zig");
const huffman = @import("../../huffman.zig");
const tables = @import("tables.zig");
const S = semantic.RollingStrategy;

const Fixture = struct {
    literal: huffman.HuffmanTable(286),
    distance: huffman.HuffmanTable(30),
    literal_encoder: huffman.HuffmanTable(286).Encoder,
    distance_encoder: huffman.HuffmanTable(30).Encoder,
    decoder: semantic.SemanticDynamicDecoder,

    fn init(self: *Fixture, secondary: bool) !void {
        var literals: [286]u4 = @splat(0);
        var distances: [30]u4 = @splat(0);
        if (secondary) {
            for ("abcdefgh", 1..) |symbol, width| literals[symbol] = @intCast(width);
            literals['A'] = 13;
            literals['B'] = 10;
            literals['C'] = 9;
            literals[256] = 11;
            literals[261] = 12;
            literals[285] = 13;
            for (0..13) |symbol| distances[symbol] = @intCast(symbol + 1);
            distances[29] = 13;
        } else {
            literals['A'] = 3;
            literals['B'] = 3;
            literals['C'] = 3;
            literals[256] = 3;
            literals[261] = 2;
            literals[285] = 2;
            for ([_]usize{ 0, 1, 2, 29 }) |symbol| distances[symbol] = 2;
        }
        self.literal = try huffman.HuffmanTable(286).init(&literals);
        self.distance = try huffman.HuffmanTable(30).init(&distances);
        self.literal_encoder = try huffman.HuffmanTable(286).Encoder.init(&literals);
        self.distance_encoder = try huffman.HuffmanTable(30).Encoder.init(&distances);
        try std.testing.expect(self.decoder.init(&self.literal, &self.distance));
    }
    fn literalBits(self: *const Fixture, writer: *bitstream.BitWriter, symbol: usize) !void {
        try writer.writeBits(std.testing.allocator, self.literal_encoder.codes[symbol], self.literal_encoder.bits[symbol]);
    }
    fn match(self: *const Fixture, writer: *bitstream.BitWriter, length: usize, distance: usize) !void {
        try self.literalBits(writer, if (length == 7) 261 else 285);
        var symbol: usize = 0;
        while (symbol + 1 < tables.distance_table.len and tables.distance_table[symbol + 1].base <= distance) symbol += 1;
        const metadata = tables.distance_table[symbol];
        try std.testing.expect(self.distance_encoder.bits[symbol] != 0);
        try writer.writeBits(std.testing.allocator, self.distance_encoder.codes[symbol], self.distance_encoder.bits[symbol]);
        try writer.writeBits(std.testing.allocator, distance - metadata.base, metadata.extra_bits);
    }
};

fn finish(fixture: *const Fixture, writer: *bitstream.BitWriter) !void {
    try fixture.literalBits(writer, 256);
    try writer.alignToByte(std.testing.allocator);
    for (0..16) |index| try writer.writeBits(std.testing.allocator, 0x30 + index, 8);
}

fn reader(bytes: []const u8, preloaded: bool) bitstream.BufferedBitReader {
    var result = bitstream.BufferedBitReader.init(if (preloaded) bytes[7..] else bytes);
    if (preloaded) {
        result.bit_buffer = std.mem.readInt(u64, bytes[0..8], .little);
        result.bit_count = 56;
        result.consumed_bits = 37;
    }
    return result;
}

fn compare(comptime Module: type, fixture: *const Fixture, bytes: []const u8, base: usize, prefix: usize, generated: usize, preloaded: bool) !void {
    const allocator = std.testing.allocator;
    const limit = prefix + generated;
    const linear = try allocator.alloc(u8, limit);
    defer allocator.free(linear);
    const storage = try allocator.alloc(u8, windows.capacity + 32);
    defer allocator.free(storage);
    @memset(linear, 0xa5);
    @memset(storage, 0xa5);
    const window: windows.Window = .{ .storage = storage, .base = base, .prefix_len = prefix, .output_limit = limit };
    for (0..prefix) |position| {
        const value: u8 = @truncate(position * 29 + 7);
        linear[position] = value;
        storage[window.physical(position)] = value;
    }
    var expected_reader = reader(bytes, preloaded);
    var actual_reader = expected_reader;
    const expected = S.oldWindow(&expected_reader, linear, prefix, &fixture.decoder);
    const actual = Module.decode(S, &actual_reader, window, &fixture.decoder);
    if (expected) |step| {
        const observed = try actual;
        try std.testing.expectEqualDeep(step, observed);
        const output = try allocator.alloc(u8, step.output_written);
        defer allocator.free(output);
        window.drain(0, output);
        try std.testing.expectEqualSlices(u8, linear[0..step.output_written], output);
        try std.testing.expectEqual(expected_reader.consumed_bits, actual_reader.consumed_bits);
        // Legal refill read-ahead can differ. The subsequent logical bitstream
        // must agree without reconstructing offsets into the current input.
        var expected_next = expected_reader;
        var actual_next = actual_reader;
        try std.testing.expectEqual(try expected_next.readBits(u32, 32), try actual_next.readBits(u32, 32));
        try std.testing.expectEqual(expected_next.consumed_bits, actual_next.consumed_bits);
    } else |err| {
        try std.testing.expectError(err, actual);
        try std.testing.expectEqual(expected_reader.consumed_bits, actual_reader.consumed_bits);
    }
    for (0..prefix) |position| try std.testing.expectEqual(@as(u8, @truncate(position * 29 + 7)), window.read(position));
    for (limit..windows.capacity) |logical|
        try std.testing.expectEqual(@as(u8, 0xa5), storage[(base + logical) & windows.mask]);
    for (storage[windows.capacity..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn successful(comptime Module: type) !void {
    for ([_]bool{ false, true }) |secondary| {
        var fixture: Fixture = undefined;
        try fixture.init(secondary);
        var writer: bitstream.BitWriter = .{};
        defer writer.deinit(std.testing.allocator);
        for (0..120) |index| try fixture.literalBits(&writer, ([_]usize{ 'A', 'B', 'C' })[index % 3]);
        for (0..8) |index| {
            try fixture.match(&writer, 258, 1 + index % 3);
            try fixture.literalBits(&writer, 'B');
            try fixture.match(&writer, 7, 2);
        }
        try finish(&fixture, &writer);
        for ([_]usize{ 0, 1, 32768, 65535, 65535 - 249 }) |base| {
            for ([_]usize{ 0, 255, 258, 32768 }) |generated| {
                try compare(Module, &fixture, writer.bytes.items, base, 0, generated, false);
                try compare(Module, &fixture, writer.bytes.items, base, 0, generated, true);
            }
        }
        var history_writer: bitstream.BitWriter = .{};
        defer history_writer.deinit(std.testing.allocator);
        for (0..128) |_| try fixture.match(&history_writer, 258, 32768);
        try finish(&fixture, &history_writer);
        for ([_]usize{ 0, 1, 32768, 65535 }) |base|
            try compare(Module, &fixture, history_writer.bytes.items, base, 32768, 32768, true);
    }
}

fn boundaryRegression(comptime Module: type) !void {
    var fixture: Fixture = undefined;
    try fixture.init(false);
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(std.testing.allocator);
    try fixture.literalBits(&writer, 'A');
    try fixture.match(&writer, 7, 1);
    for (0..32502) |_| try fixture.literalBits(&writer, 'A');
    for ("BCA") |symbol| try fixture.literalBits(&writer, symbol);
    try fixture.match(&writer, 258, 1);
    try finish(&fixture, &writer);
    for ([_]usize{ 0, 32768, 65535, 65535 - 32510 }) |base| {
        try compare(Module, &fixture, writer.bytes.items, base, 0, 32768, false);
        const storage = try std.testing.allocator.alloc(u8, windows.capacity);
        defer std.testing.allocator.free(storage);
        @memset(storage, 0xa5);
        var input = reader(writer.bytes.items, false);
        var progress: usize = 0;
        const step = try Module.decodeObserved(S, &input, .{ .storage = storage, .base = base, .prefix_len = 0, .output_limit = 32768 }, &fixture.decoder, &progress);
        try std.testing.expectEqual(semantic.LinearStatus.need_output, step.status);
        try std.testing.expectEqual(@as(usize, 32513), step.output_written);
        try std.testing.expectEqual(step.output_written, progress);
        const token = try S.decodeTail(&input, &fixture.decoder);
        try std.testing.expect(token == .length);
        try std.testing.expectEqual(@as(usize, 258), token.length.base);
    }
}

fn shortInputRestage(comptime Module: type) !void {
    var fixture: Fixture = undefined;
    try fixture.init(true);
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(std.testing.allocator);
    for ("BC") |symbol| try fixture.literalBits(&writer, symbol);
    try fixture.match(&writer, 258, 32768);
    try fixture.literalBits(&writer, 256);
    try writer.alignToByte(std.testing.allocator);
    // Fifteen input bytes admit the fast iteration, but restaging after two
    // literals leaves fewer than eight bytes before the next refill attempt.
    while (writer.bytes.items.len < 15) try writer.writeBits(std.testing.allocator, 0x7b, 8);
    try std.testing.expectEqual(@as(usize, 15), writer.bytes.items.len);
    for ([_]usize{ 0, 32768, 65535, 32767 }) |base|
        try compare(Module, &fixture, writer.bytes.items, base, 32768, 32768, false);
}

fn errorsAndSingleByte(comptime Module: type) !void {
    var fixture: Fixture = undefined;
    try fixture.init(false);
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(std.testing.allocator);
    for ("ABC") |symbol| try fixture.literalBits(&writer, symbol);
    try fixture.match(&writer, 258, 32768); // Invalid available history.
    try finish(&fixture, &writer);
    for ([_]usize{ 1, 65535, 65535 - 250 }) |base| {
        try compare(Module, &fixture, writer.bytes.items, base, 0, 258, false);
        try compare(Module, &fixture, writer.bytes.items, base, 0, 257, false);
        const storage = try std.testing.allocator.alloc(u8, windows.capacity);
        defer std.testing.allocator.free(storage);
        @memset(storage, 0xa5);
        var input = reader(writer.bytes.items, false);
        var position: usize = 99;
        try std.testing.expectError(error.InvalidMatch, Module.decodeObserved(S, &input, .{ .storage = storage, .base = base, .prefix_len = 0, .output_limit = 258 }, &fixture.decoder, &position));
        try std.testing.expectEqual(@as(usize, 3), position);
    }
    var literals: bitstream.BitWriter = .{};
    defer literals.deinit(std.testing.allocator);
    for ("ABCA") |symbol| try fixture.literalBits(&literals, symbol);
    try finish(&fixture, &literals);
    for ([_]usize{ 0, 1, 65535 }) |base| try compare(Module, &fixture, literals.bytes.items, base, 0, 1, false);
    var bad = fixture.decoder;
    @memset(&bad.distance, 0);
    const storage = try std.testing.allocator.alloc(u8, windows.capacity);
    defer std.testing.allocator.free(storage);
    @memset(storage, 0xa5);
    var input = reader(writer.bytes.items, false);
    var position: usize = 0;
    try std.testing.expectError(error.InvalidHuffmanCode, Module.decodeObserved(S, &input, .{ .storage = storage, .base = 65535, .prefix_len = 0, .output_limit = 258 }, &bad, &position));
    try std.testing.expectEqual(@as(usize, 3), position);
}

fn truncatedReservoirs(comptime Module: type) !void {
    for ([_]bool{ false, true }) |secondary| {
        var fixture: Fixture = undefined;
        try fixture.init(secondary);
        for (0..5) |variant| {
            var bits: bitstream.BitWriter = .{};
            defer bits.deinit(std.testing.allocator);
            if (variant != 0) {
                if (secondary and variant == 1) {
                    // A full secondary prefix lacks its final code bit.
                    try bits.writeBits(std.testing.allocator, fixture.literal_encoder.codes['A'], fixture.literal_encoder.bits['A'] - 1);
                } else {
                    try fixture.literalBits(&bits, 'A');
                    if (variant == 3) {
                        try fixture.literalBits(&bits, 'B');
                        try bits.writeBits(std.testing.allocator, fixture.literal_encoder.codes[261], fixture.literal_encoder.bits[261] - 1);
                    } else if (variant == 1) {
                        try bits.writeBits(std.testing.allocator, fixture.literal_encoder.codes[261], fixture.literal_encoder.bits[261] - 1);
                    } else {
                        try fixture.literalBits(&bits, 261);
                        const symbol: usize = if (variant == 4) 29 else 0;
                        if (variant == 4) {
                            try bits.writeBits(std.testing.allocator, fixture.distance_encoder.codes[symbol], fixture.distance_encoder.bits[symbol]);
                            try bits.writeBits(std.testing.allocator, 0xfff, 12); // Need thirteen extras.
                        } else {
                            try bits.writeBits(std.testing.allocator, fixture.distance_encoder.codes[symbol], fixture.distance_encoder.bits[symbol] - 1);
                        }
                    }
                }
            }
            var bytes: [8]u8 = @splat(0);
            @memcpy(bytes[0..bits.bytes.items.len], bits.bytes.items);
            bytes[bits.bytes.items.len] = bits.scratch;
            var expected_reader = bitstream.BufferedBitReader.init(&.{});
            expected_reader.bit_buffer = std.mem.readInt(u64, &bytes, .little);
            expected_reader.bit_count = bits.bytes.items.len * 8 + bits.bit_index;
            expected_reader.consumed_bits = 31;
            var actual_reader = expected_reader;
            const storage = try std.testing.allocator.alloc(u8, windows.capacity);
            defer std.testing.allocator.free(storage);
            @memset(storage, 0xa5);
            var linear: [6]u8 = @splat(0xa5);
            const window: windows.Window = .{ .storage = storage, .base = windows.mask, .prefix_len = 4, .output_limit = 6 };
            for (0..4) |logical| {
                linear[logical] = @intCast(logical + 17);
                storage[window.physical(logical)] = linear[logical];
            }
            var position: usize = 0;
            try std.testing.expectError(error.TruncatedFrame, S.oldWindow(&expected_reader, &linear, 4, &fixture.decoder));
            try std.testing.expectError(error.TruncatedFrame, Module.decodeObserved(S, &actual_reader, window, &fixture.decoder, &position));
            try std.testing.expectEqualDeep(expected_reader, actual_reader);
            const committed: usize = if (variant == 0 or (secondary and variant == 1)) 4 else if (variant == 3) 6 else 5;
            try std.testing.expectEqual(committed, position);
            for (0..committed) |logical| try std.testing.expectEqual(linear[logical], window.read(logical));
        }
    }
}

pub fn check(comptime Module: type) !void {
    try successful(Module);
    try boundaryRegression(Module);
    try shortInputRestage(Module);
    try errorsAndSingleByte(Module);
    try truncatedReservoirs(Module);
    std.debug.print("rolling_semantic linear_pairs=105 observed_pause=4 observed_errors=4 truncated_reservoirs=10\n", .{});
}

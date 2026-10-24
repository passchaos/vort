const std = @import("std");
const vort = @import("vort");
const br = vort.br;

const ActualWire = struct {
    window_bits: u8,
    header_bits: usize,
    meta_output_len: usize,
    command_symbol: u16,
    distance_symbol: u16,
    simple_distance_symbol_bits: usize,
    distance_extra_bits: usize,
    distance_extra: u64,
    physical_distance: u64,
};

/// Independent LSB-first reader for this public one-command wire shape. No
/// production prefix-code, distance encoder, or internal test writer is used.
const Reader = struct {
    bytes: []const u8,
    position: usize = 0,

    fn take(self: *Reader, count: usize) !u64 {
        if (count > 64 or self.position > self.bytes.len * 8 or count > self.bytes.len * 8 - self.position)
            return error.TruncatedWire;
        var result: u64 = 0;
        for (0..count) |index| {
            const at = self.position + index;
            const bit: u64 = (self.bytes[at / 8] >> @as(u3, @intCast(at % 8))) & 1;
            result |= bit << @as(u6, @intCast(index));
        }
        self.position += count;
        return result;
    }

    fn expect(self: *Reader, count: usize, value: u64) !void {
        try std.testing.expectEqual(value, try self.take(count));
    }

    fn singleSymbol(self: *Reader, alphabet_size: usize) !u16 {
        try self.expect(2, 1); // simple prefix
        try self.expect(2, 0); // exactly one symbol
        var width: usize = 0;
        var remainder = alphabet_size - 1;
        while (remainder != 0) : (remainder >>= 1) width += 1;
        const symbol = try self.take(width);
        if (symbol >= alphabet_size) return error.InvalidWireSymbol;
        return @intCast(symbol);
    }
};

fn actualWire(bytes: []const u8) !ActualWire {
    var reader: Reader = .{ .bytes = bytes };
    try reader.expect(1, 1);
    try reader.expect(3, 0);
    try reader.expect(3, 1);
    try reader.expect(1, 0);
    const window_bits: u8 = @intCast(try reader.take(6));
    const header_bits = reader.position;
    const last = try reader.take(1);
    if (last != 0) try reader.expect(1, 0); // non-empty final meta-block
    const nibbles: usize = @intCast((try reader.take(2)) + 4);
    if (nibbles == 7) return error.UnexpectedMetadataBlock;
    const meta_output_len: usize = @intCast((try reader.take(nibbles * 4)) + 1);
    if (last == 0) try reader.expect(1, 0); // compressed
    for (0..3) |_| try reader.expect(1, 0); // one block type for each alphabet
    try reader.expect(2, 0); // NPOSTFIX
    try reader.expect(4, 0); // NDIRECT_HIGH
    try reader.expect(2, 0); // literal context mode
    try reader.expect(1, 0); // one literal context tree
    try reader.expect(1, 0); // one distance context tree
    _ = try reader.singleSymbol(256);
    const command_symbol = try reader.singleSymbol(704);
    const distance_symbol = try reader.singleSymbol(140);
    // RFC 7932 command 198 pairs insert 0 with copy length code 14:
    // copy base 38, four extra bits. It carries an explicit distance symbol.
    try std.testing.expectEqual(@as(u16, 198), command_symbol);
    const copy_extra = try reader.take(4);
    try std.testing.expectEqual(@as(u64, 48), 38 + copy_extra);
    try std.testing.expectEqual(@as(u16, 64), distance_symbol);
    const distance_extra_bits: usize = 1 + (@as(usize, distance_symbol) - 16) / 2;
    const extra = try reader.take(distance_extra_bits);
    const code: u64 = distance_symbol - 16;
    const base = ((@as(u64, 2) + (code & 1)) << @as(u6, @intCast(distance_extra_bits))) - 4;
    const physical = base + extra + 1;
    if (last == 0) {
        try reader.expect(1, 1);
        try reader.expect(1, 1); // final empty meta-block
    }
    try reader.expect(bytes.len * 8 - reader.position, 0);
    return .{
        .window_bits = window_bits,
        .header_bits = header_bits,
        .meta_output_len = meta_output_len,
        .command_symbol = command_symbol,
        .distance_symbol = distance_symbol,
        .simple_distance_symbol_bits = 8,
        .distance_extra_bits = distance_extra_bits,
        .distance_extra = extra,
        .physical_distance = physical,
    };
}

test "Brotli Large Window public RAW dictionary copy emits actual twenty five bit distance extra" {
    if (@sizeOf(usize) != 8) return error.SkipZigTest;
    const allocator = std.testing.allocator;
    const dictionary_len: usize = (@as(usize, 1) << 26) + 57;
    const dictionary = try allocator.alloc(u8, dictionary_len);
    defer allocator.free(dictionary);
    @memset(dictionary, 0);
    var random_state: u64 = 0x1a6fe7438b026d;
    for (dictionary[0..64], 0..) |*byte, index| {
        random_state = random_state *% 6364136223846793005 +% 1442695040888963407;
        byte.* = 128 + @as(u8, @intCast((random_state >> 32) & 127));
        if (index == 0) byte.* = 254;
        if (index == 1) byte.* = 253;
    }
    const input = dictionary[0..48];
    const prefixes = [_][]const u8{dictionary};
    const shared: br.SharedDictionary = .{ .raw_prefixes = &prefixes };
    var profile: br.HqProfile = .{};
    var memory: br.EncodeMemoryProfile = .{};
    const parameters = br.HqDistanceParameters.init(0, 0);
    // RAW bytes are a real borrowed attachment. The total cap covers actual
    // encoder-owned workspace and wires, not caller-owned dictionary storage.
    const wire = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, .{
        .quality = 10,
        .large_window = true,
        .window_bits = 30,
        .shared_dictionary = shared,
        .max_total_working_memory = 64 * 1024 * 1024,
        .memory_profile = &memory,
        .hq = .{
            .beam_width = 1,
            .search_depth = 1,
            .iterations = 1,
            .nice_len = 128,
            .distance_parameters = parameters,
            .max_working_memory = 64 * 1024 * 1024,
            .profile = &profile,
        },
    });
    defer allocator.free(wire);
    try std.testing.expectEqual(@as(u64, 1), profile.emitted_metablocks);
    try std.testing.expectEqual(@as(u64, 1), profile.emitted_commands);
    try std.testing.expectEqual(@as(u64, 1), profile.emitted_compound_commands);
    try std.testing.expectEqual(@as(u64, 0), profile.emitted_static_commands);
    try std.testing.expectEqual(@as(u64, input.len), profile.emitted_copy_bytes);
    try std.testing.expectEqual(dictionary_len, profile.emitted_max_distance);
    try std.testing.expect(profile.emitted_max_distance > parameters.maximumDistance());
    try std.testing.expect(memory.available and memory.peak_requested_bytes <= 64 * 1024 * 1024);
    try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
    const actual = try actualWire(wire);
    try std.testing.expectEqual(@as(u8, 30), actual.window_bits);
    try std.testing.expectEqual(@as(usize, 14), actual.header_bits);
    try std.testing.expectEqual(input.len, actual.meta_output_len);
    try std.testing.expectEqual(@as(u16, 64), actual.distance_symbol);
    try std.testing.expectEqual(@as(usize, 8), actual.simple_distance_symbol_bits);
    try std.testing.expectEqual(@as(usize, 25), actual.distance_extra_bits);
    try std.testing.expectEqual(@as(u64, 60), actual.distance_extra);
    try std.testing.expectEqual(@as(u64, dictionary_len), actual.physical_distance);
    const decoded = try br.decodeStreamAllocExactSizeWithOptions(allocator, wire, input.len, .{ .allow_large_window = true, .shared_dictionary = shared });
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    // Shared-dictionary attachment preserves the library's existing implicit
    // extension policy; a plain decoder tests default header rejection.
    try std.testing.expectError(error.CorruptFrame, br.decodeStreamAllocWithOptions(allocator, wire, .{}));
    const summary = try br.summarizeStreamAllocLimitedWithOptions(allocator, wire, input.len, .{ .allow_large_window = true, .shared_dictionary = shared });
    try std.testing.expect(summary.large_window and summary.window_bits == 30);
    try std.testing.expectEqual(input.len, summary.decoded_bytes);
    try std.testing.expectEqual(@as(usize, 1), summary.shared_dictionary_copy_count);
    try std.testing.expectEqual(input.len, summary.shared_dictionary_bytes);
    try std.testing.expectEqual(@as(usize, 1), summary.regular_distance_copy_count);
}

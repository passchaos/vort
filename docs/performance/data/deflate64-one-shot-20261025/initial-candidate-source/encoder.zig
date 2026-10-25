const std = @import("std");
const bitstream = @import("../bitstream.zig");
const core = @import("../core.zig");
const one_shot = @import("one_shot.zig");

pub const Error = core.Error;

pub const EncodeOptions = struct {
    /// Maximum hash-chain candidates examined at each input position.
    max_chain: usize = 128,
    /// Stop searching once a match reaches this length. Zero retains the
    /// established first-match stopping behavior; the maximum is 65538.
    nice_length: u32 = 128,
};

const max_stored_block_len: usize = std.math.maxInt(u16);

/// Return a conservative bound for the adaptive encoder.
///
/// The encoder retains a fixed-Huffman candidate only when it is smaller than
/// the stored representation, so the exact stored size is also its bound.
pub fn encodedBound(input_len: usize) Error!usize {
    const block_count = if (input_len == 0) 1 else (input_len - 1) / max_stored_block_len + 1;
    const overhead = std.math.mul(usize, block_count, 5) catch return error.IntegerOverflow;
    return std.math.add(usize, input_len, overhead) catch return error.IntegerOverflow;
}

/// Encode one raw Deflate64 stream, choosing between a fixed-Huffman stream
/// and stored blocks. The fixed encoder uses Deflate64's extended distance
/// alphabet through distance 65536 and code-285 lengths through 65538. Fixed
/// blocks use borrowed 128KiB chunks with continuous bit packing and preceding
/// 64KiB history. The whole fixed candidate must beat the original global
/// stored representation; ties preserve stored output and encodedBound.
pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) ![]u8 {
    if (options.nice_length > 65_538) return error.InvalidBlockPlan;
    const stored_size = try encodedBound(input.len);
    var matcher: one_shot.Matcher = .{};
    defer matcher.deinit(allocator);
    const plan = try one_shot.plan(allocator, &matcher, input, options.max_chain, options.nice_length);
    if (plan.encoded_len >= stored_size) return encodeStoredAlloc(allocator, input);

    const output = try allocator.alloc(u8, plan.encoded_len);
    const written = one_shot.emit(&matcher, input, output, options.max_chain, options.nice_length);
    std.debug.assert(written == plan.encoded_len);
    return output;
}

/// Append one raw Deflate64 stream transactionally.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    try out.ensureUnusedCapacity(allocator, encoded.len);
    out.appendSliceAssumeCapacity(encoded);
    return encoded.len;
}

/// Encode into caller-owned output. Match planning uses the supplied allocator;
/// output is left unchanged when the buffer is too small.
pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn encodeStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const size = try encodedBound(input.len);
    const output = try allocator.alloc(u8, size);
    errdefer allocator.free(output);
    std.debug.assert(try encodeStoredInto(input, output) == size);
    return output;
}

/// Append a stored-block Deflate64 stream transactionally.
pub fn encodeStoredAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
) !usize {
    const encoded = try encodeStoredAlloc(allocator, input);
    defer allocator.free(encoded);
    try out.ensureUnusedCapacity(allocator, encoded.len);
    out.appendSliceAssumeCapacity(encoded);
    return encoded.len;
}

/// Encode a raw Deflate64 stream using only stored blocks.
pub fn encodeStoredInto(input: []const u8, output: []u8) Error!usize {
    const required = try encodedBound(input.len);
    if (output.len < required) return error.OutputTooSmall;

    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < input.len or (input.len == 0 and output_offset == 0)) {
        const block_len: usize = @min(max_stored_block_len, input.len - input_offset);
        const final = input_offset + block_len == input.len;
        output[output_offset] = @intFromBool(final);
        const len: u16 = @intCast(block_len);
        std.mem.writeInt(u16, output[output_offset + 1 ..][0..2], len, .little);
        std.mem.writeInt(u16, output[output_offset + 3 ..][0..2], ~len, .little);
        @memcpy(output[output_offset + 5 ..][0..block_len], input[input_offset..][0..block_len]);
        input_offset += block_len;
        output_offset += block_len;
        output_offset += 5;
    }
    return output_offset;
}

test "Deflate64 fixed codes cover extended length and distance boundaries" {
    const huffman = @import("../huffman.zig");
    const literal_table = try huffman.fixedLiteralTable();
    const distance_table = try huffman.fixedDistanceTable();
    const encoded = try encodeAlloc(std.testing.allocator, "R" ** 259, .{});
    defer std.testing.allocator.free(encoded);
    var reader = bitstream.BitReader.init(encoded);
    try std.testing.expectEqual(@as(u3, 0b011), try reader.readBits(u3, 3));
    try std.testing.expectEqual(@as(u16, 'R'), try literal_table.decodeValue(&reader));
    try std.testing.expectEqual(@as(u16, 284), try literal_table.decodeValue(&reader));
    try std.testing.expectEqual(@as(u16, 31), try reader.readBits(u16, 5));
    try std.testing.expectEqual(@as(u16, 0), try distance_table.decodeValue(&reader));
    try std.testing.expectEqual(@as(u16, 256), try literal_table.decodeValue(&reader));

    // Shared helper emission is driven by a real match against borrowed
    // history, then its fields are decoded without reusing code classifiers.
    const blocks = @import("stream_blocks.zig");
    var matcher: one_shot.Matcher = .{};
    defer matcher.deinit(std.testing.allocator);
    try matcher.ensure(std.testing.allocator);
    const history = try std.testing.allocator.alloc(u8, 65_536);
    defer std.testing.allocator.free(history);
    @memset(history, 0);
    @memcpy(history[0..3], "abc");
    for ([_]struct { distance: usize, symbol: u16, extra: u16 }{
        .{ .distance = 32_769, .symbol = 30, .extra = 0 },
        .{ .distance = 65_535, .symbol = 31, .extra = 16_382 },
        .{ .distance = 65_536, .symbol = 31, .extra = 16_383 },
    }) |boundary| {
        const plan = blocks.fixedPlan(&matcher, history[0..boundary.distance], "abc", 128, 3);
        try std.testing.expectEqual(@as(usize, 1), plan.stats.match_count);
        try std.testing.expectEqual(boundary.distance, plan.stats.max_match_distance);
        var bytes: [8]u8 = undefined;
        var writer: blocks.Writer = .{ .state = .{}, .output = &bytes };
        blocks.writeFixed(&writer, &matcher, history[0..boundary.distance], "abc", 128, 3, true);
        writer.alignToByte();
        var fields = bitstream.BitReader.init(bytes[0..writer.len]);
        try std.testing.expectEqual(@as(u3, 0b011), try fields.readBits(u3, 3));
        try std.testing.expectEqual(@as(u16, 257), try literal_table.decodeValue(&fields));
        try std.testing.expectEqual(boundary.symbol, try distance_table.decodeValue(&fields));
        try std.testing.expectEqual(boundary.extra, try fields.readBits(u16, 14));
        try std.testing.expectEqual(@as(u16, 256), try literal_table.decodeValue(&fields));
    }
}

test "Deflate64 encoder round trips empty, stored, and fixed streams" {
    const decoder = @import("decoder.zig");
    const allocator = std.testing.allocator;
    const zeroes = [_]u8{0} ** 1024;
    const cases = [_][]const u8{
        "",
        "Deflate64 fixed Huffman payload " ** 64,
        &zeroes,
    };
    for (cases) |input| {
        const encoded = try encodeAlloc(allocator, input, .{});
        defer allocator.free(encoded);
        const decoded = try decoder.decodeAlloc(allocator, encoded);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }

    var incompressible: [256]u8 = undefined;
    for (&incompressible, 0..) |*byte, index| byte.* = @intCast(index);
    const stored = try encodeAlloc(allocator, &incompressible, .{});
    defer allocator.free(stored);
    try std.testing.expectEqual(@as(u3, 0b001), @as(u3, @truncate(stored[0])));
    try std.testing.expectEqual(try encodedBound(incompressible.len), stored.len);

    const payload = "caller-owned Deflate64 output " ** 32;
    const expected = try encodeAlloc(allocator, payload, .{});
    defer allocator.free(expected);
    const into = try allocator.alloc(u8, try encodedBound(payload.len));
    defer allocator.free(into);
    const written = try encodeInto(allocator, payload, into, .{});
    try std.testing.expectEqualSlices(u8, expected, into[0..written]);

    @memset(into[0 .. written - 1], 0xa5);
    try std.testing.expectError(error.OutputTooSmall, encodeInto(allocator, payload, into[0 .. written - 1], .{}));
    for (into[0 .. written - 1]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try encodeAppend(allocator, &appended, payload, .{}));
    try std.testing.expectEqualStrings("prefix:", appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, expected, appended.items["prefix:".len..]);

    try std.testing.expectError(error.IntegerOverflow, encodedBound(std.math.maxInt(usize)));
}

test "Deflate64 encoder emits matches beyond the Deflate window" {
    const decoder = @import("decoder.zig");
    const allocator = std.testing.allocator;
    const prefix_len = 52_000;
    const separator = "deflate64-separator";
    const input = try allocator.alloc(u8, prefix_len * 2 + separator.len);
    defer allocator.free(input);
    var state: u32 = 0xdef1_a7e6;
    for (input[0..prefix_len]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(input[prefix_len..][0..separator.len], separator);
    @memcpy(input[prefix_len + separator.len ..], input[0..prefix_len]);

    var matcher: one_shot.Matcher = .{};
    defer matcher.deinit(allocator);
    const plan = try one_shot.plan(allocator, &matcher, input, 128, 128);
    try std.testing.expect(plan.stats.max_match_distance > 49_152);

    const encoded = try encodeAlloc(allocator, input, .{});
    defer allocator.free(encoded);
    try std.testing.expect(encoded.len < input.len * 3 / 4);
    const decoded = try decoder.decodeAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Deflate64 stored encoder splits blocks and preserves caller buffers" {
    const decoder = @import("decoder.zig");
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, max_stored_block_len + 1);
    defer allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index);

    const required = try encodedBound(input.len);
    const output = try allocator.alloc(u8, required);
    defer allocator.free(output);
    try std.testing.expectEqual(required, try encodeStoredInto(input, output));
    const decoded = try decoder.decodeAlloc(allocator, output);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    const too_small = try allocator.alloc(u8, required - 1);
    defer allocator.free(too_small);
    @memset(too_small, 0xa5);
    try std.testing.expectError(error.OutputTooSmall, encodeStoredInto(input, too_small));
    for (too_small) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    try std.testing.expectEqual(required, try encodeStoredAppend(allocator, &appended, input));
    try std.testing.expectEqualStrings("prefix:", appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, output, appended.items["prefix:".len..]);
}

test "Deflate64 one-shot full range and transactional output contracts" {
    try @import("one_shot_tests.zig").contracts(@This());
}

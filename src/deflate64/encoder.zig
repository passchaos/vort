const std = @import("std");
const bitstream = @import("../bitstream.zig");
const core = @import("../core.zig");
const huffman = @import("../huffman.zig");
const lz77 = @import("../lz77.zig");

pub const Error = core.Error;

pub const EncodeOptions = struct {
    /// Maximum hash-chain candidates examined at each input position.
    max_chain: usize = 128,
    /// Stop searching once a match reaches this length.
    nice_length: u16 = 128,
};

const max_stored_block_len: usize = std.math.maxInt(u16);
const max_encoder_distance: usize = std.math.maxInt(u16);

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
/// alphabet and its distinct code-285 semantics.
pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) ![]u8 {
    const stored_size = try encodedBound(input.len);
    const plan = try planAlloc(allocator, input, options);
    defer plan.deinit(allocator);

    const fixed = try encodeFixedPlanAlloc(allocator, plan.tokens);
    if (fixed.len < stored_size) return fixed;
    allocator.free(fixed);
    return encodeStoredAlloc(allocator, input);
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

fn planAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) !lz77.GreedyPlan {
    return lz77.hashGreedyPlanAlloc(allocator, input, .{
        .window_len = max_encoder_distance,
        .max_chain = options.max_chain,
        .nice_len = options.nice_length,
        .max_match = lz77.max_match_len,
    });
}

fn encodeFixedPlanAlloc(allocator: std.mem.Allocator, tokens: []const lz77.Token) ![]u8 {
    var writer: bitstream.BitWriter = .{};
    errdefer writer.deinit(allocator);

    // BFINAL=1 followed by fixed-Huffman BTYPE=01 in LSB-first order.
    try writer.writeBits(allocator, 0b011, 3);
    for (tokens) |token| switch (token) {
        .literal => |byte| try huffman.fixed_literal_encoder.writeSymbol(&writer, allocator, byte),
        .match => |match| {
            const length = lengthCode(match.length);
            try huffman.fixed_literal_encoder.writeSymbol(&writer, allocator, length.symbol);
            try writer.writeBits(allocator, length.extra_value, length.extra_bits);

            const distance = distanceCode(match.distance);
            try huffman.fixed_distance_encoder.writeSymbol(&writer, allocator, distance.symbol);
            try writer.writeBits(allocator, distance.extra_value, distance.extra_bits);
        },
    };
    try huffman.fixed_literal_encoder.writeSymbol(&writer, allocator, 256);
    return writer.toOwnedSlice(allocator);
}

const CodeExtra = struct {
    symbol: u16,
    extra_bits: u6,
    extra_value: u16,
};

fn lengthCode(length: u16) CodeExtra {
    std.debug.assert(length >= lz77.min_match_len and length <= lz77.max_match_len);
    if (length <= 10) return .{ .symbol = length + 254, .extra_bits = 0, .extra_value = 0 };

    // Unlike ordinary Deflate, Deflate64 reserves symbol 285 for a 16-bit
    // length extension. Length 258 therefore uses symbol 284 plus value 31.
    const extra_bits: u6 = @intCast(std.math.log2_int(u16, length - 3) - 2);
    const span: u16 = @as(u16, 1) << @intCast(extra_bits);
    const group_base: u16 = (@as(u16, 1) << @intCast(extra_bits + 2)) + 3;
    const offset = length - group_base;
    const slot = offset / span;
    return .{
        .symbol = 261 + @as(u16, extra_bits) * 4 + slot,
        .extra_bits = extra_bits,
        .extra_value = offset & (span - 1),
    };
}

fn distanceCode(distance: u16) CodeExtra {
    std.debug.assert(distance >= 1);
    if (distance <= 4) return .{ .symbol = distance - 1, .extra_bits = 0, .extra_value = 0 };

    const extra_bits: u6 = @intCast(std.math.log2_int(u16, distance - 1) - 1);
    const span: u16 = @as(u16, 1) << @intCast(extra_bits);
    const group_base: u16 = (@as(u16, 1) << @intCast(extra_bits + 1)) + 1;
    const offset = distance - group_base;
    const slot = offset / span;
    return .{
        .symbol = 2 + @as(u16, extra_bits) * 2 + slot,
        .extra_bits = extra_bits,
        .extra_value = offset & (span - 1),
    };
}

test "Deflate64 fixed codes cover extended length and distance boundaries" {
    const length = lengthCode(258);
    try std.testing.expectEqual(@as(u16, 284), length.symbol);
    try std.testing.expectEqual(@as(u6, 5), length.extra_bits);
    try std.testing.expectEqual(@as(u16, 31), length.extra_value);

    const code_30 = distanceCode(32 * 1024 + 1);
    try std.testing.expectEqual(@as(u16, 30), code_30.symbol);
    try std.testing.expectEqual(@as(u6, 14), code_30.extra_bits);
    try std.testing.expectEqual(@as(u16, 0), code_30.extra_value);

    const code_31 = distanceCode(std.math.maxInt(u16));
    try std.testing.expectEqual(@as(u16, 31), code_31.symbol);
    try std.testing.expectEqual(@as(u6, 14), code_31.extra_bits);
    try std.testing.expectEqual(@as(u16, 16_382), code_31.extra_value);
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

    const plan = try planAlloc(allocator, input, .{});
    defer plan.deinit(allocator);
    var saw_extended_distance = false;
    for (plan.tokens) |token| switch (token) {
        .match => |match| if (match.distance > 49_152) {
            saw_extended_distance = true;
            break;
        },
        else => {},
    };
    try std.testing.expect(saw_extended_distance);

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

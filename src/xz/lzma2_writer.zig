const std = @import("std");
const core = @import("../core.zig");
const range_encoder = @import("../lzma/range_encoder.zig");

pub const max_uncompressed_chunk: usize = 65_536;
const literal_context_bits: u4 = 3;
const position_bits: u4 = 2;
const lzma_property: u8 = 0x5d;
pub const dictionary_property: u8 = 0;

pub fn storedPayloadSize(input_len: usize) core.Error!usize {
    const chunk_count = if (input_len == 0) 0 else 1 + (input_len - 1) / max_uncompressed_chunk;
    const header_size = std.math.mul(usize, chunk_count, 3) catch return error.IntegerOverflow;
    const with_headers = std.math.add(usize, input_len, header_size) catch return error.IntegerOverflow;
    return std.math.add(usize, with_headers, 1) catch return error.IntegerOverflow;
}

/// Append a raw LZMA2 payload made of uncompressed chunks. The output is
/// transactional: allocation failure leaves `out.items` unchanged.
pub fn appendStoredPayload(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
) !usize {
    const encoded_size = try storedPayloadSize(input.len);
    try out.ensureUnusedCapacity(allocator, encoded_size);

    const start = out.items.len;
    var offset: usize = 0;
    while (offset < input.len) {
        const chunk_len = @min(max_uncompressed_chunk, input.len - offset);
        out.appendAssumeCapacity(if (offset == 0) 1 else 2);
        var size_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &size_bytes, @intCast(chunk_len - 1), .big);
        out.appendSliceAssumeCapacity(&size_bytes);
        out.appendSliceAssumeCapacity(input[offset..][0..chunk_len]);
        offset += chunk_len;
    }
    out.appendAssumeCapacity(0);
    std.debug.assert(out.items.len - start == encoded_size);
    return encoded_size;
}

/// Append a raw LZMA2 payload with independently decodable chunks. Literal
/// range coding is used when it beats an uncompressed chunk; otherwise the
/// writer falls back to the stored representation.
pub fn appendCompressedPayload(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
) !usize {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var candidate: std.ArrayList(u8) = .empty;
    defer candidate.deinit(allocator);

    var offset: usize = 0;
    while (offset < input.len) {
        const chunk_len = @min(max_uncompressed_chunk, input.len - offset);
        const chunk = input[offset..][0..chunk_len];
        candidate.clearRetainingCapacity();
        try encodeLiteralChunk(allocator, &candidate, chunk);
        if (candidate.items.len <= max_uncompressed_chunk and candidate.items.len + 3 < chunk.len) {
            try encoded.append(allocator, 0xe0);
            try appendU16Big(allocator, &encoded, @intCast(chunk.len - 1));
            try appendU16Big(allocator, &encoded, @intCast(candidate.items.len - 1));
            try encoded.append(allocator, lzma_property);
            try encoded.appendSlice(allocator, candidate.items);
        } else {
            try appendStoredChunk(allocator, &encoded, chunk, true);
        }
        offset += chunk_len;
    }
    try encoded.append(allocator, 0);

    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

fn encodeLiteralChunk(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) !void {
    var is_match: [1 << position_bits]u16 = @splat(0x400);
    var literal_probabilities: [1 << literal_context_bits][0x300]u16 = @splat(@splat(0x400));
    var encoder = range_encoder.Encoder.init(allocator, output);
    var previous: u8 = 0;
    for (input, 0..) |byte, position| {
        try encoder.encodeBit(&is_match[position & (is_match.len - 1)], false);
        const context = previous >> (8 - literal_context_bits);
        var tree_index: usize = 1;
        var bit_index: u4 = 8;
        while (bit_index != 0) {
            bit_index -= 1;
            const bit = byte >> @intCast(bit_index) & 1 != 0;
            try encoder.encodeBit(&literal_probabilities[context][tree_index], bit);
            tree_index = (tree_index << 1) | @intFromBool(bit);
        }
        previous = byte;
    }
    try encoder.finish();
}

fn appendStoredChunk(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    reset_dictionary: bool,
) !void {
    std.debug.assert(input.len != 0 and input.len <= max_uncompressed_chunk);
    try output.append(allocator, if (reset_dictionary) 1 else 2);
    try appendU16Big(allocator, output, @intCast(input.len - 1));
    try output.appendSlice(allocator, input);
}

fn appendU16Big(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .big);
    try output.appendSlice(allocator, &bytes);
}

test "raw LZMA2 stored payload splits chunks and terminates" {
    const input = try std.testing.allocator.alloc(u8, max_uncompressed_chunk + 1);
    defer std.testing.allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index);

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    const written = try appendStoredPayload(std.testing.allocator, &encoded, input);

    try std.testing.expectEqual(try storedPayloadSize(input.len), written);
    try std.testing.expectEqual(@as(u8, 1), encoded.items[0]);
    try std.testing.expectEqualSlices(u8, &.{ 0xff, 0xff }, encoded.items[1..3]);
    const second = 3 + max_uncompressed_chunk;
    try std.testing.expectEqual(@as(u8, 2), encoded.items[second]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, encoded.items[second + 1 ..][0..2]);
    try std.testing.expectEqual(@as(u8, 0), encoded.items[encoded.items.len - 1]);
}

test "raw LZMA2 empty stored payload is only an end marker" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), try appendStoredPayload(std.testing.allocator, &encoded, ""));
    try std.testing.expectEqualSlices(u8, &.{0}, encoded.items);
}

test "raw LZMA2 literal compression round trips and falls back for noise" {
    const container = @import("container.zig");
    const repetitive = "literal LZMA2 compression\n" ** 4096;
    var compressed: std.ArrayList(u8) = .empty;
    defer compressed.deinit(std.testing.allocator);
    _ = try appendCompressedPayload(std.testing.allocator, &compressed, repetitive);
    try std.testing.expect(compressed.items[0] >= 0xe0);
    try std.testing.expect(compressed.items.len < repetitive.len);
    const decoded = try container.decode7zPayloadAllocLimited(
        std.testing.allocator,
        compressed.items,
        dictionary_property,
        repetitive.len,
        4096,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, repetitive, decoded);

    var noise: [4096]u8 = undefined;
    var state: u32 = 0x1234_5678;
    for (&noise) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    var stored: std.ArrayList(u8) = .empty;
    defer stored.deinit(std.testing.allocator);
    _ = try appendCompressedPayload(std.testing.allocator, &stored, &noise);
    try std.testing.expectEqual(@as(u8, 1), stored.items[0]);
    const decoded_noise = try container.decode7zPayloadAllocLimited(
        std.testing.allocator,
        stored.items,
        dictionary_property,
        noise.len,
        4096,
    );
    defer std.testing.allocator.free(decoded_noise);
    try std.testing.expectEqualSlices(u8, &noise, decoded_noise);
}

test "raw LZMA2 payload switches safely from compressed to stored chunks" {
    const input = try std.testing.allocator.alloc(u8, max_uncompressed_chunk * 2);
    defer std.testing.allocator.free(input);
    @memset(input[0..max_uncompressed_chunk], 'A');
    var state: u32 = 0x9e37_79b9;
    for (input[max_uncompressed_chunk..]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    _ = try appendCompressedPayload(std.testing.allocator, &encoded, input);
    try std.testing.expect(encoded.items[0] >= 0xe0);
    const first_packed_size = @as(usize, std.mem.readInt(u16, encoded.items[3..5], .big)) + 1;
    try std.testing.expectEqual(@as(u8, 1), encoded.items[6 + first_packed_size]);

    const decoded = try @import("container.zig").decode7zPayloadAllocLimited(
        std.testing.allocator,
        encoded.items,
        dictionary_property,
        input.len,
        4096,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

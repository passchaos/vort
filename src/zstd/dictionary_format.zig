const std = @import("std");

pub const magic: u32 = 0xec30_a437;

// Portable baseline entropy tables for dictionaries created from already-
// selected content. These bytes are a complete RFC 8878 dictionary entropy
// section emitted by zstd 1.5.x from a representative corpus. They provide a
// dependency-free interoperability baseline; unlike COVER/FastCover training,
// they are deliberately not tuned to the caller's content or sample set.
const baseline_entropy = [_]u8{
    0x2f, 0x10, 0x80, 0x4f, 0x63, 0xfc, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff, 0xff, 0x70, 0x6f, 0xa1, 0x85, 0x16, 0x5a, 0x68, 0xa1, 0x85, 0x16, 0x5a,
    0x04, 0xee, 0x2d, 0xe5, 0x96, 0x12, 0x1d, 0xea, 0x90, 0x1a, 0x6a, 0xa8, 0x43, 0x6a, 0x20, 0x0c,
    0x03, 0x41, 0x20, 0x10, 0x08, 0x50, 0x04, 0xdd, 0xd6, 0x41, 0x22, 0x22, 0xf2, 0x54, 0xa0, 0x40,
    0x41, 0x41, 0x81, 0x0d, 0x86, 0x02, 0x8c, 0x82, 0x82, 0x82, 0x82, 0x82, 0x82, 0x82, 0x82, 0x82,
    0x82, 0x82, 0x82, 0x82, 0x82, 0x82, 0x02, 0x8c, 0x82, 0x82, 0x02, 0x88, 0x97, 0x02, 0x63, 0x8e,
    0x29, 0x3e, 0x48, 0x51, 0x4a, 0x29, 0xa5, 0x94, 0x52, 0x55, 0xd5, 0x03, 0x24, 0x15, 0x55, 0x28,
    0x14, 0x0a, 0x45, 0x51, 0x14, 0x45, 0x51, 0x14, 0x45, 0x51, 0x14, 0x45, 0x51, 0x14, 0xa5, 0x94,
    0x52, 0x4a, 0x29, 0x55, 0x55, 0x3d,
};

const baseline_repcodes = [3]u32{ 1, 4, 8 };
// The first byte is the FSE-compressed Huffman-weight payload length. The
// following three serialized FSE tables are intentionally kept as the stable
// sequence-model suffix while the literal model is trained by the parent
// codec. Keeping the split derived from the wire header prevents a second
// hand-maintained copy of the 86-byte suffix from drifting.
const baseline_huffman_len: usize = @as(usize, baseline_entropy[0]) + 1;
pub const baseline_sequence_entropy = baseline_entropy[baseline_huffman_len..];
pub const generated_header_len: usize = 8 + baseline_entropy.len + baseline_repcodes.len * @sizeOf(u32);

pub fn validateGenerationInput(content_len: usize, dictionary_id: u32) !void {
    if (dictionary_id == 0 or content_len < baseline_repcodes[2]) return error.InvalidDictionaryMetadata;
}

/// Return the exact number of bytes needed to wrap `content` in a standard
/// Zstandard full-dictionary container. Semantic constraints are checked by
/// `encodeFromContentInto`, because callers may use this function for sizing.
pub fn encodedFromContentLen(content_len: usize) !usize {
    return std.math.add(usize, generated_header_len, content_len) catch return error.IntegerOverflow;
}

/// Wrap caller-selected history bytes in a standard full dictionary using
/// stable baseline entropy tables and repcodes. A non-zero ID and at least
/// eight content bytes are required by the generated metadata and libzstd.
/// All fallible validation happens before the first write, so a short output
/// buffer is left unchanged. `content` and `output` must not overlap.
pub fn encodeFromContentInto(content: []const u8, dictionary_id: u32, output: []u8) !usize {
    try validateGenerationInput(content.len, dictionary_id);
    const needed = try encodedFromContentLen(content.len);
    if (output.len < needed) return error.OutputTooSmall;

    std.mem.writeInt(u32, output[0..4], magic, .little);
    std.mem.writeInt(u32, output[4..8], dictionary_id, .little);
    @memcpy(output[8 .. 8 + baseline_entropy.len], &baseline_entropy);
    const repcode_offset = 8 + baseline_entropy.len;
    for (baseline_repcodes, 0..) |repcode, i|
        std.mem.writeInt(u32, output[repcode_offset + i * 4 ..][0..4], repcode, .little);
    @memcpy(output[generated_header_len..needed], content);
    return needed;
}

pub fn encodedFromEntropyLen(content_len: usize, literal_entropy_len: usize, sequence_entropy_len: usize) !usize {
    var total = std.math.add(usize, 8, literal_entropy_len) catch return error.IntegerOverflow;
    total = std.math.add(usize, total, sequence_entropy_len) catch return error.IntegerOverflow;
    total = std.math.add(usize, total, baseline_repcodes.len * @sizeOf(u32)) catch return error.IntegerOverflow;
    return std.math.add(usize, total, content_len) catch return error.IntegerOverflow;
}

/// Assemble a full dictionary from caller-provided Huffman and OF/ML/LL FSE
/// descriptions. The parent codec owns entropy construction and validation;
/// this compatibility entry point retains the portable baseline repcodes.
pub fn encodeFromEntropyInto(
    content: []const u8,
    dictionary_id: u32,
    literal_entropy: []const u8,
    sequence_entropy: []const u8,
    output: []u8,
) !usize {
    return try encodeFromEntropyAndRepcodesInto(
        content,
        dictionary_id,
        literal_entropy,
        sequence_entropy,
        baseline_repcodes,
        output,
    );
}

/// Assemble a full dictionary with caller-selected, validated starting
/// repcodes. The content, entropy sections, and output must not overlap.
pub fn encodeFromEntropyAndRepcodesInto(
    content: []const u8,
    dictionary_id: u32,
    literal_entropy: []const u8,
    sequence_entropy: []const u8,
    repcodes: [3]u32,
    output: []u8,
) !usize {
    try validateGenerationInput(content.len, dictionary_id);
    if (literal_entropy.len == 0 or sequence_entropy.len == 0) return error.InvalidDictionaryTraining;
    for (repcodes) |repcode| {
        if (repcode == 0 or repcode > content.len) return error.InvalidDictionaryMetadata;
    }
    const needed = try encodedFromEntropyLen(content.len, literal_entropy.len, sequence_entropy.len);
    if (output.len < needed) return error.OutputTooSmall;

    std.mem.writeInt(u32, output[0..4], magic, .little);
    std.mem.writeInt(u32, output[4..8], dictionary_id, .little);
    var offset: usize = 8;
    @memcpy(output[offset..][0..literal_entropy.len], literal_entropy);
    offset += literal_entropy.len;
    @memcpy(output[offset..][0..sequence_entropy.len], sequence_entropy);
    offset += sequence_entropy.len;
    for (repcodes) |repcode| {
        std.mem.writeInt(u32, output[offset..][0..4], repcode, .little);
        offset += 4;
    }
    @memcpy(output[offset..needed], content);
    return needed;
}

pub const View = struct {
    id: u32,
    repcodes: [3]u32,
    content_offset: usize,
    content: []const u8,
};

/// Parse the format-independent prefix of a standard Zstandard dictionary.
/// The entropy payload is deliberately left opaque here; the parent codec owns
/// Huffman/FSE parsing and advances `entropy_len` before constructing `View`.
pub fn viewAfterEntropy(bytes: []const u8, entropy_len: usize) !View {
    if (bytes.len < 8) return error.TruncatedFrame;
    if (std.mem.readInt(u32, bytes[0..4], .little) != magic) return error.InvalidMagic;
    const id = std.mem.readInt(u32, bytes[4..8], .little);
    if (id == 0) return error.InvalidDictionaryMetadata;
    const content_offset = std.math.add(usize, 8, entropy_len) catch return error.IntegerOverflow;
    const repcode_end = std.math.add(usize, content_offset, 12) catch return error.IntegerOverflow;
    if (repcode_end > bytes.len) return error.TruncatedFrame;
    const content = bytes[repcode_end..];
    var repcodes: [3]u32 = undefined;
    for (0..3) |i| {
        const repcode = std.mem.readInt(u32, bytes[content_offset + i * 4 ..][0..4], .little);
        if (repcode == 0 or repcode > content.len) return error.InvalidDictionaryMetadata;
        repcodes[i] = repcode;
    }
    return .{ .id = id, .repcodes = repcodes, .content_offset = repcode_end, .content = content };
}

test "standard dictionary prefix validates repcodes and content" {
    var bytes: [24]u8 = @splat(0);
    std.mem.writeInt(u32, bytes[0..4], magic, .little);
    std.mem.writeInt(u32, bytes[4..8], 0x1234, .little);
    std.mem.writeInt(u32, bytes[8..12], 1, .little);
    std.mem.writeInt(u32, bytes[12..16], 2, .little);
    std.mem.writeInt(u32, bytes[16..20], 3, .little);
    @memcpy(bytes[20..24], "dict");
    const view = try viewAfterEntropy(&bytes, 0);
    try std.testing.expectEqual(@as(u32, 0x1234), view.id);
    try std.testing.expectEqual([3]u32{ 1, 2, 3 }, view.repcodes);
    try std.testing.expectEqual(@as(usize, 20), view.content_offset);
    try std.testing.expectEqualSlices(u8, "dict", view.content);
    bytes[8] = 0;
    try std.testing.expectError(error.InvalidDictionaryMetadata, viewAfterEntropy(&bytes, 0));
}

test "standard dictionary baseline container encoding" {
    const content = "dictionary history";
    try std.testing.expectEqual(@as(usize, 154), generated_header_len);
    var output: [generated_header_len + content.len]u8 = undefined;
    try std.testing.expectEqual(output.len, try encodedFromContentLen(content.len));
    try std.testing.expectEqual(output.len, try encodeFromContentInto(content, 0x1234_5678, &output));
    try std.testing.expectEqual(magic, std.mem.readInt(u32, output[0..4], .little));
    try std.testing.expectEqual(@as(u32, 0x1234_5678), std.mem.readInt(u32, output[4..8], .little));
    try std.testing.expectEqualSlices(u8, content, output[generated_header_len..]);

    const before = output;
    try std.testing.expectError(error.OutputTooSmall, encodeFromContentInto(content, 1, output[0 .. output.len - 1]));
    try std.testing.expectEqualSlices(u8, &before, &output);
    try std.testing.expectError(error.InvalidDictionaryMetadata, encodeFromContentInto(content, 0, &output));
    try std.testing.expectError(error.InvalidDictionaryMetadata, encodeFromContentInto("short", 1, &output));
    try std.testing.expectEqualSlices(u8, &before, &output);
    try std.testing.expectError(error.IntegerOverflow, encodedFromContentLen(std.math.maxInt(usize)));
}

test "standard dictionary custom entropy assembly is sized before writes" {
    const content = "dictionary history";
    const literal_entropy = [_]u8{ 128, 0x11 };
    const needed = try encodedFromEntropyLen(content.len, literal_entropy.len, baseline_sequence_entropy.len);
    var output: [8 + literal_entropy.len + baseline_sequence_entropy.len + 12 + content.len]u8 = undefined;
    try std.testing.expectEqual(output.len, needed);
    try std.testing.expectEqual(needed, try encodeFromEntropyInto(content, 9, &literal_entropy, baseline_sequence_entropy, &output));
    try std.testing.expectEqualSlices(u8, &literal_entropy, output[8 .. 8 + literal_entropy.len]);
    try std.testing.expectEqualSlices(u8, baseline_sequence_entropy, output[8 + literal_entropy.len ..][0..baseline_sequence_entropy.len]);

    const before = output;
    try std.testing.expectError(error.OutputTooSmall, encodeFromEntropyInto(content, 9, &literal_entropy, baseline_sequence_entropy, output[0 .. output.len - 1]));
    try std.testing.expectEqualSlices(u8, &before, &output);
    try std.testing.expectError(error.InvalidDictionaryTraining, encodeFromEntropyInto(content, 9, &.{}, baseline_sequence_entropy, &output));
    try std.testing.expectError(error.InvalidDictionaryTraining, encodeFromEntropyInto(content, 9, &literal_entropy, &.{}, &output));
    try std.testing.expectError(error.IntegerOverflow, encodedFromEntropyLen(std.math.maxInt(usize), 1, 1));
}

test "standard dictionary custom entropy accepts validated repcodes" {
    const content = "dictionary history";
    const literal_entropy = [_]u8{ 128, 0x11 };
    const needed = try encodedFromEntropyLen(content.len, literal_entropy.len, baseline_sequence_entropy.len);
    var output: [8 + literal_entropy.len + baseline_sequence_entropy.len + 12 + content.len]u8 = undefined;
    const repcodes = [3]u32{ 3, 7, 11 };
    try std.testing.expectEqual(needed, try encodeFromEntropyAndRepcodesInto(
        content,
        10,
        &literal_entropy,
        baseline_sequence_entropy,
        repcodes,
        &output,
    ));
    const view = try viewAfterEntropy(&output, literal_entropy.len + baseline_sequence_entropy.len);
    try std.testing.expectEqual(repcodes, view.repcodes);

    const before = output;
    try std.testing.expectError(error.InvalidDictionaryMetadata, encodeFromEntropyAndRepcodesInto(
        content,
        10,
        &literal_entropy,
        baseline_sequence_entropy,
        .{ 0, 7, 11 },
        &output,
    ));
    try std.testing.expectError(error.InvalidDictionaryMetadata, encodeFromEntropyAndRepcodesInto(
        content,
        10,
        &literal_entropy,
        baseline_sequence_entropy,
        .{ 3, 7, content.len + 1 },
        &output,
    ));
    try std.testing.expectEqualSlices(u8, &before, &output);
}

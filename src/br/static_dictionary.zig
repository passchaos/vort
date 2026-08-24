// RFC 7932 static dictionary bytes. The binary is generated from the same
// canonical Brotli dictionary used by upstream decoders; keeping it as data
// avoids a 120K source literal and lets this module own transform semantics.
const std = @import("std");
const data = @embedFile("dictionary.bin");

const offsets = [_]usize{
    0,     0,     0,      0,      0,      4096,   9216,   21504,  35840,  44032,  53248,  63488,  74752,
    87040, 93696, 100864, 104704, 106752, 108928, 113536, 115968, 118528, 119872, 121280, 122016,
};

const size_bits = [_]u5{
    0, 0, 0, 0, 10, 10, 11, 11, 10, 10, 10, 10, 10, 9, 9, 8, 7, 7, 8, 7, 7, 6, 6, 5, 5,
};

const prefix_suffix = [_]u8{
    0x00, 0x20, 0x00, 0x2c, 0x20, 0x00, 0x20, 0x6f, 0x66, 0x20, 0x74, 0x68, 0x65, 0x20, 0x00, 0x20,
    0x6f, 0x66, 0x20, 0x00, 0x73, 0x20, 0x00, 0x2e, 0x00, 0x20, 0x61, 0x6e, 0x64, 0x20, 0x00, 0x20,
    0x69, 0x6e, 0x20, 0x00, 0x22, 0x00, 0x20, 0x74, 0x6f, 0x20, 0x00, 0x22, 0x3e, 0x00, 0x0a, 0x00,
    0x2e, 0x20, 0x00, 0x5d, 0x00, 0x20, 0x66, 0x6f, 0x72, 0x20, 0x00, 0x20, 0x61, 0x20, 0x00, 0x20,
    0x74, 0x68, 0x61, 0x74, 0x20, 0x00, 0x27, 0x00, 0x20, 0x77, 0x69, 0x74, 0x68, 0x20, 0x00, 0x20,
    0x66, 0x72, 0x6f, 0x6d, 0x20, 0x00, 0x20, 0x62, 0x79, 0x20, 0x00, 0x28, 0x00, 0x2e, 0x20, 0x54,
    0x68, 0x65, 0x20, 0x00, 0x20, 0x6f, 0x6e, 0x20, 0x00, 0x20, 0x61, 0x73, 0x20, 0x00, 0x20, 0x69,
    0x73, 0x20, 0x00, 0x69, 0x6e, 0x67, 0x20, 0x00, 0x0a, 0x09, 0x00, 0x3a, 0x00, 0x65, 0x64, 0x20,
    0x00, 0x3d, 0x22, 0x00, 0x20, 0x61, 0x74, 0x20, 0x00, 0x6c, 0x79, 0x20, 0x00, 0x2c, 0x00, 0x3d,
    0x27, 0x00, 0x2e, 0x63, 0x6f, 0x6d, 0x2f, 0x00, 0x2e, 0x20, 0x54, 0x68, 0x69, 0x73, 0x20, 0x00,
    0x20, 0x6e, 0x6f, 0x74, 0x20, 0x00, 0x65, 0x72, 0x20, 0x00, 0x61, 0x6c, 0x20, 0x00, 0x66, 0x75,
    0x6c, 0x20, 0x00, 0x69, 0x76, 0x65, 0x20, 0x00, 0x6c, 0x65, 0x73, 0x73, 0x20, 0x00, 0x65, 0x73,
    0x74, 0x20, 0x00, 0x69, 0x7a, 0x65, 0x20, 0x00, 0xc2, 0xa0, 0x00, 0x6f, 0x75, 0x73, 0x20, 0x00,
};

const Transform = struct { prefix: u8, kind: u8, suffix: u8 };
const transforms = [_]Transform{
    .{ .prefix = 0, .kind = 0, .suffix = 0 },
    .{ .prefix = 0, .kind = 0, .suffix = 1 },
    .{ .prefix = 1, .kind = 0, .suffix = 1 },
    .{ .prefix = 0, .kind = 12, .suffix = 0 },
    .{ .prefix = 0, .kind = 10, .suffix = 1 },
    .{ .prefix = 0, .kind = 0, .suffix = 9 },
    .{ .prefix = 1, .kind = 0, .suffix = 0 },
    .{ .prefix = 20, .kind = 0, .suffix = 1 },
    .{ .prefix = 0, .kind = 0, .suffix = 15 },
    .{ .prefix = 0, .kind = 10, .suffix = 0 },
    .{ .prefix = 0, .kind = 0, .suffix = 25 },
    .{ .prefix = 0, .kind = 13, .suffix = 0 },
    .{ .prefix = 0, .kind = 1, .suffix = 0 },
    .{ .prefix = 3, .kind = 0, .suffix = 1 },
    .{ .prefix = 0, .kind = 0, .suffix = 3 },
    .{ .prefix = 1, .kind = 10, .suffix = 1 },
    .{ .prefix = 0, .kind = 0, .suffix = 31 },
    .{ .prefix = 0, .kind = 0, .suffix = 38 },
    .{ .prefix = 12, .kind = 0, .suffix = 1 },
    .{ .prefix = 0, .kind = 0, .suffix = 36 },
    .{ .prefix = 0, .kind = 0, .suffix = 23 },
    .{ .prefix = 0, .kind = 0, .suffix = 43 },
    .{ .prefix = 0, .kind = 0, .suffix = 46 },
    .{ .prefix = 0, .kind = 3, .suffix = 0 },
    .{ .prefix = 0, .kind = 0, .suffix = 51 },
    .{ .prefix = 0, .kind = 0, .suffix = 53 },
    .{ .prefix = 0, .kind = 14, .suffix = 0 },
    .{ .prefix = 0, .kind = 2, .suffix = 0 },
    .{ .prefix = 0, .kind = 0, .suffix = 59 },
    .{ .prefix = 0, .kind = 0, .suffix = 63 },
    .{ .prefix = 1, .kind = 10, .suffix = 0 },
    .{ .prefix = 0, .kind = 0, .suffix = 48 },
    .{ .prefix = 23, .kind = 0, .suffix = 0 },
    .{ .prefix = 1, .kind = 0, .suffix = 3 },
    .{ .prefix = 0, .kind = 15, .suffix = 0 },
    .{ .prefix = 0, .kind = 0, .suffix = 72 },
    .{ .prefix = 0, .kind = 0, .suffix = 70 },
    .{ .prefix = 0, .kind = 0, .suffix = 79 },
    .{ .prefix = 0, .kind = 0, .suffix = 86 },
    .{ .prefix = 0, .kind = 16, .suffix = 0 },
    .{ .prefix = 0, .kind = 17, .suffix = 0 },
    .{ .prefix = 9, .kind = 0, .suffix = 0 },
    .{ .prefix = 0, .kind = 4, .suffix = 0 },
    .{ .prefix = 0, .kind = 0, .suffix = 93 },
    .{ .prefix = 0, .kind = 11, .suffix = 0 },
    .{ .prefix = 0, .kind = 0, .suffix = 100 },
    .{ .prefix = 0, .kind = 0, .suffix = 105 },
    .{ .prefix = 0, .kind = 0, .suffix = 110 },
    .{ .prefix = 0, .kind = 7, .suffix = 0 },
    .{ .prefix = 0, .kind = 1, .suffix = 115 },
    .{ .prefix = 0, .kind = 0, .suffix = 120 },
    .{ .prefix = 0, .kind = 0, .suffix = 123 },
    .{ .prefix = 1, .kind = 0, .suffix = 48 },
    .{ .prefix = 0, .kind = 0, .suffix = 125 },
    .{ .prefix = 0, .kind = 20, .suffix = 0 },
    .{ .prefix = 0, .kind = 18, .suffix = 0 },
    .{ .prefix = 0, .kind = 6, .suffix = 0 },
    .{ .prefix = 0, .kind = 0, .suffix = 91 },
    .{ .prefix = 0, .kind = 10, .suffix = 3 },
    .{ .prefix = 0, .kind = 8, .suffix = 0 },
    .{ .prefix = 0, .kind = 0, .suffix = 132 },
    .{ .prefix = 0, .kind = 0, .suffix = 137 },
    .{ .prefix = 9, .kind = 0, .suffix = 15 },
    .{ .prefix = 0, .kind = 5, .suffix = 0 },
    .{ .prefix = 0, .kind = 9, .suffix = 0 },
    .{ .prefix = 1, .kind = 10, .suffix = 3 },
    .{ .prefix = 0, .kind = 10, .suffix = 36 },
    .{ .prefix = 23, .kind = 0, .suffix = 91 },
    .{ .prefix = 0, .kind = 11, .suffix = 1 },
    .{ .prefix = 0, .kind = 10, .suffix = 43 },
    .{ .prefix = 0, .kind = 0, .suffix = 129 },
    .{ .prefix = 1, .kind = 0, .suffix = 23 },
    .{ .prefix = 146, .kind = 0, .suffix = 0 },
    .{ .prefix = 9, .kind = 0, .suffix = 6 },
    .{ .prefix = 0, .kind = 10, .suffix = 70 },
    .{ .prefix = 0, .kind = 0, .suffix = 152 },
    .{ .prefix = 0, .kind = 0, .suffix = 141 },
    .{ .prefix = 23, .kind = 0, .suffix = 1 },
    .{ .prefix = 0, .kind = 10, .suffix = 91 },
    .{ .prefix = 0, .kind = 10, .suffix = 23 },
    .{ .prefix = 0, .kind = 0, .suffix = 160 },
    .{ .prefix = 1, .kind = 0, .suffix = 129 },
    .{ .prefix = 0, .kind = 0, .suffix = 166 },
    .{ .prefix = 1, .kind = 11, .suffix = 1 },
    .{ .prefix = 0, .kind = 0, .suffix = 170 },
    .{ .prefix = 1, .kind = 11, .suffix = 0 },
    .{ .prefix = 0, .kind = 0, .suffix = 143 },
    .{ .prefix = 0, .kind = 11, .suffix = 36 },
    .{ .prefix = 0, .kind = 10, .suffix = 48 },
    .{ .prefix = 1, .kind = 0, .suffix = 91 },
    .{ .prefix = 0, .kind = 0, .suffix = 174 },
    .{ .prefix = 1, .kind = 10, .suffix = 48 },
    .{ .prefix = 0, .kind = 0, .suffix = 179 },
    .{ .prefix = 0, .kind = 0, .suffix = 184 },
    .{ .prefix = 0, .kind = 11, .suffix = 70 },
    .{ .prefix = 0, .kind = 0, .suffix = 190 },
    .{ .prefix = 1, .kind = 10, .suffix = 23 },
    .{ .prefix = 0, .kind = 11, .suffix = 43 },
    .{ .prefix = 1, .kind = 0, .suffix = 143 },
    .{ .prefix = 0, .kind = 10, .suffix = 141 },
    .{ .prefix = 0, .kind = 0, .suffix = 195 },
    .{ .prefix = 0, .kind = 11, .suffix = 23 },
    .{ .prefix = 200, .kind = 0, .suffix = 0 },
    .{ .prefix = 1, .kind = 0, .suffix = 141 },
    .{ .prefix = 0, .kind = 10, .suffix = 129 },
    .{ .prefix = 0, .kind = 11, .suffix = 129 },
    .{ .prefix = 0, .kind = 0, .suffix = 203 },
    .{ .prefix = 0, .kind = 11, .suffix = 3 },
    .{ .prefix = 0, .kind = 10, .suffix = 143 },
    .{ .prefix = 1, .kind = 10, .suffix = 141 },
    .{ .prefix = 1, .kind = 11, .suffix = 129 },
    .{ .prefix = 1, .kind = 11, .suffix = 3 },
    .{ .prefix = 0, .kind = 11, .suffix = 141 },
    .{ .prefix = 0, .kind = 11, .suffix = 91 },
    .{ .prefix = 0, .kind = 11, .suffix = 48 },
    .{ .prefix = 1, .kind = 11, .suffix = 23 },
    .{ .prefix = 0, .kind = 11, .suffix = 143 },
    .{ .prefix = 1, .kind = 11, .suffix = 48 },
    .{ .prefix = 1, .kind = 10, .suffix = 129 },
    .{ .prefix = 1, .kind = 11, .suffix = 143 },
    .{ .prefix = 1, .kind = 10, .suffix = 143 },
};

pub const TransformMetadata = struct {
    prefix_len: u3,
    suffix_len: u4,
    first_suffix_byte: u8,
    keeps_whole_word: bool,
};

const transform_metadata = blk: {
    var result: [transforms.len]TransformMetadata = undefined;
    for (transforms, 0..) |spec, index| {
        result[index] = .{
            .prefix_len = @intCast(cStringLength(spec.prefix)),
            .suffix_len = @intCast(cStringLength(spec.suffix)),
            .first_suffix_byte = prefix_suffix[spec.suffix],
            .keeps_whole_word = spec.kind == 0 or spec.kind == 10 or spec.kind == 11,
        };
    }
    break :blk result;
};

pub const max_transformed_word_len: usize = 37;
pub const transform_count: usize = transforms.len;
pub const base_word_count: usize = blk: {
    var count: usize = 0;
    for (4..25) |copy_len| count += @as(usize, 1) << size_bits[copy_len];
    break :blk count;
};

pub const Match = struct {
    output_len: u6,
    copy_len: u5,
    address: usize,
};

pub fn transformPrefixLength(transform_index: usize) ?usize {
    return (transformMetadata(transform_index) orelse return null).prefix_len;
}

pub fn transformFirstSuffixByte(transform_index: usize) ?u8 {
    return (transformMetadata(transform_index) orelse return null).first_suffix_byte;
}

pub fn transformKeepsWholeWord(transform_index: usize) bool {
    return (transformMetadata(transform_index) orelse return false).keeps_whole_word;
}

pub fn transformSuffixLength(transform_index: usize) ?usize {
    return (transformMetadata(transform_index) orelse return null).suffix_len;
}

pub fn transformMetadata(transform_index: usize) ?TransformMetadata {
    if (transform_index >= transform_metadata.len) return null;
    return transform_metadata[transform_index];
}

/// Find the longest built-in static-dictionary word beginning at `input[0]`.
/// This reference matcher deliberately enumerates dictionary addresses rather
/// than importing upstream's generated encoder LUT: it keeps the wire model
/// independent and provides a correctness baseline for a future indexed path.
pub fn findLongestMatch(input: []const u8) ?Match {
    if (input.len < 4) return null;
    var scratch: [64]u8 = undefined;
    var best: ?Match = null;
    for (4..25) |copy_len| {
        const bits = sizeBits(copy_len) orelse continue;
        const word_count = @as(usize, 1) << bits;
        for (0..transforms.len) |transform_index| {
            for (0..word_count) |word_index| {
                const address = (transform_index << bits) | word_index;
                const transformed = transform(address, copy_len, &scratch) orelse continue;
                if (transformed.len < 4 or transformed.len > input.len or transformed.len > max_transformed_word_len) continue;
                if (!std.mem.eql(u8, transformed, input[0..transformed.len])) continue;
                if (best == null or transformed.len > best.?.output_len or
                    (transformed.len == best.?.output_len and address < best.?.address))
                {
                    best = .{ .output_len = @intCast(transformed.len), .copy_len = @intCast(copy_len), .address = address };
                }
            }
        }
    }
    return best;
}

pub fn baseWord(copy_len: usize, word_index: usize) ?[]const u8 {
    const bits = sizeBits(copy_len) orelse return null;
    if (word_index >= (@as(usize, 1) << bits)) return null;
    const start = offsets[copy_len] + word_index * copy_len;
    if (start > data.len or data.len - start < copy_len) return null;
    return data[start..][0..copy_len];
}

pub fn transform(address: usize, word_len: usize, out: []u8) ?[]const u8 {
    if (word_len < 4 or word_len > 24 or out.len < 64) return null;
    const bits = size_bits[word_len];
    const mask = (@as(usize, 1) << bits) - 1;
    const word_index = address & mask;
    const transform_index = address >> bits;
    if (transform_index >= transforms.len) return null;
    const start = offsets[word_len] + word_index * word_len;
    if (start > data.len or data.len - start < word_len) return null;
    const spec = transforms[transform_index];
    var written: usize = 0;
    written += copyCString(out[written..], spec.prefix);
    var skip: usize = if (spec.kind >= 12) spec.kind - 11 else 0;
    skip = @min(skip, word_len);
    var kept = word_len - skip;
    if (spec.kind <= 9) kept -|= spec.kind;
    @memcpy(out[written..][0..kept], data[start + skip ..][0..kept]);
    if (spec.kind == 10 and kept != 0) uppercase(out[written..][0..kept], false);
    if (spec.kind == 11 and kept != 0) uppercase(out[written..][0..kept], true);
    written += kept;
    written += copyCString(out[written..], spec.suffix);
    return out[0..written];
}

pub fn sizeBits(word_len: usize) ?u5 {
    if (word_len >= size_bits.len or size_bits[word_len] == 0) return null;
    return size_bits[word_len];
}

fn copyCString(out: []u8, offset: usize) usize {
    var len: usize = 0;
    while (prefix_suffix[offset + len] != 0) : (len += 1) out[len] = prefix_suffix[offset + len];
    return len;
}

fn cStringLength(offset: usize) usize {
    var len: usize = 0;
    while (prefix_suffix[offset + len] != 0) : (len += 1) {}
    return len;
}

fn uppercase(bytes: []u8, all: bool) void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const first = bytes[offset];
        const step: usize = if (first < 0xc0) blk: {
            if (first >= 'a' and first <= 'z') bytes[offset] ^= 32;
            break :blk 1;
        } else if (first < 0xe0) blk: {
            if (offset + 1 < bytes.len) bytes[offset + 1] ^= 32;
            break :blk 2;
        } else blk: {
            if (offset + 2 < bytes.len) bytes[offset + 2] ^= 5;
            break :blk 3;
        };
        if (!all) return;
        offset += step;
    }
}

test "full Brotli dictionary resolves quality-four omit transforms" {
    var out: [64]u8 = undefined;
    try std.testing.expectEqualSlices(u8, "service", transform((27 << 10) | 161, 9, &out).?);
    try std.testing.expectEqualSlices(u8, "value", transform((42 << 10) | 721, 9, &out).?);
}

test "static dictionary reference matcher returns copy length and address" {
    const match = findLongestMatch(" information follows").?;
    var out: [64]u8 = undefined;
    const transformed = transform(match.address, match.copy_len, &out).?;
    try std.testing.expectEqualSlices(u8, " information", transformed);
    try std.testing.expectEqual(@as(usize, transformed.len), match.output_len);
}

test "static dictionary transform metadata agrees with materialization" {
    var transformed: [64]u8 = undefined;
    for (4..25) |word_len| {
        const bits = sizeBits(word_len).?;
        for (0..transform_count) |transform_index| {
            const output = transform(transform_index << bits, word_len, &transformed).?;
            const prefix_len = transformPrefixLength(transform_index).?;
            const suffix_len = transformSuffixLength(transform_index).?;
            try std.testing.expect(prefix_len + suffix_len <= output.len);
            if (suffix_len != 0) try std.testing.expectEqual(transformFirstSuffixByte(transform_index).?, output[output.len - suffix_len]);
            if (transformKeepsWholeWord(transform_index)) try std.testing.expectEqual(prefix_len + word_len + suffix_len, output.len);
        }
    }
}

const std = @import("std");
const format = @import("../../format.zig");

pub const nid = 39;
pub const index_start = 1288;

/// Immutable erofs-utils metadata plus independently encoded zero-producing
/// LZ4 blocks. HEAD1-only packs isolate item-width errors from entropy errors.
pub fn build(allocator: std.mem.Allocator, logical_bits: u8, cluster_count: usize, two_byte: bool) ![]u8 {
    std.debug.assert(logical_bits >= 12 and logical_bits <= 14 and cluster_count <= 32);
    const text = @embedFile("../../testdata/lz4-compact-big.erofs.b64");
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const original = try allocator.alloc(u8, decoder.calcSizeUpperBound(text.len));
    defer allocator.free(original);
    _ = try decoder.decode(original, text);
    const image = try allocator.alloc(u8, (cluster_count + 1) * 4096);
    errdefer allocator.free(image);
    @memset(image, 0);
    @memcpy(image[0..4096], original[0..4096]);
    std.mem.writeInt(u32, image[1060..1064], @intCast(cluster_count + 1), .little);
    const cluster_size: usize = @as(usize, 1) << @intCast(logical_bits);
    std.mem.writeInt(u32, image[nid * 32 + 8 ..][0..4], @intCast(cluster_count * cluster_size), .little);
    std.mem.writeInt(u32, image[nid * 32 + 16 ..][0..4], @intCast(cluster_count), .little);
    std.mem.writeInt(u16, image[1284..1286], @intFromBool(two_byte), .little);
    image[1287] = logical_bits - 12;
    @memset(image[index_start..][0..256], 0);
    const initial = ((32 - index_start % 32) / 4) & 7;
    const middle = if (two_byte and cluster_count > initial) (cluster_count - initial) / 16 * 16 else 0;
    var logical: usize = 0;
    var position: usize = index_start;
    while (logical < cluster_count) {
        const is_two_byte = logical >= initial and logical < initial + middle;
        const count: usize = if (is_two_byte) 16 else 2;
        const size: usize = if (is_two_byte) 32 else 8;
        const bits: usize = if (is_two_byte) 14 else 16;
        const actual = @min(count, cluster_count - logical);
        for (0..actual) |item| {
            const value = @as(u32, 1) << @intCast(logical_bits);
            for (0..bits) |bit_index| {
                const bit = item * bits + bit_index;
                image[position + bit / 8] |= (@as(u8, @truncate(value >> @intCast(bit_index))) & 1) << @intCast(bit % 8);
            }
        }
        std.mem.writeInt(u32, image[position + size - 4 ..][0..4], @intCast(logical), .little);
        logical += actual;
        position += size;
    }
    var encoded: [128]u8 = undefined;
    encoded[0..4].* = .{ 0x1f, 0, 1, 0 };
    // One literal, a distance-one match, and five terminal literals. Match
    // length is cluster_size - 6; 19 is already represented by token 0x1f.
    const extensions = (cluster_size - 25) / 255;
    @memset(encoded[4..][0..extensions], 255);
    encoded[4 + extensions] = @intCast((cluster_size - 25) % 255);
    encoded[5 + extensions] = 0x50;
    @memset(encoded[6 + extensions ..][0..5], 0);
    const encoded_len = 11 + extensions;
    for (1..cluster_count + 1) |block| @memcpy(image[(block + 1) * 4096 - encoded_len ..][0..encoded_len], encoded[0..encoded_len]);
    std.mem.writeInt(u32, image[1028..1032], format.computeSuperblockChecksum(image[1024..4096]), .little);
    return image;
}

const std = @import("std");
const h = @import("helpers.zig");

pub const crossing_dictionary = "abcd";
pub const crossing_plain = "ababcdababcd";
// LL=2, OF code=3 (value 9 => distance 6), ML=7 (length 10), all RLE
// sequence tables. The final byte carries OF extra=1 and the end marker.
pub const crossing_payload = [_]u8{ 0x10, 'a', 'b', 1, 0x54, 2, 3, 7, 9 };
pub const mixed_plain = "abcdabcdabcd";

/// A raw block emits abcd; a compressed block uses LL=0, ML=8, distance=4.
/// Feeding this complete frame in one call requires live history from the raw
/// block before any successful API return has published those four bytes.
pub fn mixed(known: bool, magicless: bool) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(h.a);
    if (!magicless) try bytes.appendSlice(h.a, &h.wire.magic);
    try bytes.append(h.a, if (known) 0x24 else 4);
    try bytes.append(h.a, if (known) mixed_plain.len else 0);
    try bytes.appendSlice(h.a, &.{ 0x20, 0, 0, 'a', 'b', 'c', 'd', 0x3d, 0, 0, 0, 1, 0x54, 0, 2, 5, 7 });
    try appendChecksum(&bytes, mixed_plain);
    return bytes.toOwnedSlice(h.a);
}

pub fn crossing(known: bool, magicless: bool, checksum: bool, dictionary_id: u8) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(h.a);
    if (!magicless) try bytes.appendSlice(h.a, &h.wire.magic);
    try bytes.append(h.a, (if (known) @as(u8, 0x20) else 0) | (if (checksum) @as(u8, 4) else 0) | @intFromBool(dictionary_id != 0));
    if (!known) try bytes.append(h.a, 0); // 1 KiB window, no FCS.
    if (dictionary_id != 0) try bytes.append(h.a, dictionary_id);
    if (known) try bytes.append(h.a, crossing_plain.len);
    var block: [3]u8 = undefined;
    std.mem.writeInt(u24, &block, (@as(u24, crossing_payload.len) << 3) | 5, .little);
    try bytes.appendSlice(h.a, &block);
    try bytes.appendSlice(h.a, &crossing_payload);
    if (checksum) try appendChecksum(&bytes, crossing_plain);
    return bytes.toOwnedSlice(h.a);
}

pub fn rleBlocks(payload: []const u8, known: bool, magicless: bool, block_len: usize) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(h.a);
    if (!magicless) try bytes.appendSlice(h.a, &h.wire.magic);
    try bytes.append(h.a, if (known) 0xa4 else 4);
    if (known) {
        var size: [4]u8 = undefined;
        std.mem.writeInt(u32, &size, @intCast(payload.len), .little);
        try bytes.appendSlice(h.a, &size);
    } else try bytes.append(h.a, 0x38); // Window 128 KiB.
    var offset: usize = 0;
    while (offset < payload.len) {
        const len = @min(block_len, payload.len - offset);
        var block: [3]u8 = undefined;
        std.mem.writeInt(u24, &block, (@as(u24, @intCast(len)) << 3) | 2 | @intFromBool(offset + len == payload.len), .little);
        try bytes.appendSlice(h.a, &block);
        try bytes.append(h.a, payload[offset]);
        offset += len;
    }
    try appendChecksum(&bytes, payload);
    return bytes.toOwnedSlice(h.a);
}

pub fn rawBlocks(payload: []const u8, known: bool, magicless: bool, block_len: usize) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(h.a);
    if (!magicless) try bytes.appendSlice(h.a, &h.wire.magic);
    try bytes.append(h.a, if (known) 0xa4 else 4);
    if (known) {
        var size: [4]u8 = undefined;
        std.mem.writeInt(u32, &size, @intCast(payload.len), .little);
        try bytes.appendSlice(h.a, &size);
    } else try bytes.append(h.a, 0x38);
    var offset: usize = 0;
    while (true) {
        const len = @min(block_len, payload.len - offset);
        var block: [3]u8 = undefined;
        std.mem.writeInt(u24, &block, (@as(u24, @intCast(len)) << 3) | @intFromBool(offset + len == payload.len), .little);
        try bytes.appendSlice(h.a, &block);
        try bytes.appendSlice(h.a, payload[offset..][0..len]);
        offset += len;
        if (offset == payload.len) break;
    }
    try appendChecksum(&bytes, payload);
    return bytes.toOwnedSlice(h.a);
}

pub fn unknownCompressed(frame: []const u8, magicless: bool) ![]u8 {
    const header = try h.wire.header(frame, magicless);
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(h.a);
    if (!magicless) try bytes.appendSlice(h.a, &h.wire.magic);
    try bytes.append(h.a, header.descriptor & ~@as(u8, 0xe0));
    try bytes.append(h.a, 0x08); // 2 KiB window for the numbered JSON corpus.
    try bytes.appendSlice(h.a, frame[header.payload_offset..]);
    return bytes.toOwnedSlice(h.a);
}

fn appendChecksum(bytes: *std.ArrayList(u8), payload: []const u8) !void {
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try bytes.appendSlice(h.a, &checksum);
}

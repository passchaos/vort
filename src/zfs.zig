const lzjb = @import("zfs/lzjb.zig");
const zle = @import("zfs/zle.zig");
const block = @import("zfs/block.zig");

pub const Error = lzjb.Error || zle.Error || block.Error;
pub const Algorithm = block.Algorithm;
pub const EncodeOptions = block.EncodeOptions;
pub const ZstdMetadata = block.ZstdMetadata;
pub const encodeLzjbAlloc = lzjb.encodeAlloc;
pub const encodeLzjbAppend = lzjb.encodeAppend;
pub const decodeLzjbAllocExactSize = lzjb.decodeAllocExactSize;
pub const decodeLzjbIntoExactSize = lzjb.decodeIntoExactSize;
pub const encodeZleAlloc = zle.encodeAlloc;
pub const encodeZleAppend = zle.encodeAppend;
pub const decodeZleAllocExactSize = zle.decodeAllocExactSize;
pub const decodeZleIntoExactSize = zle.decodeIntoExactSize;
pub const encodeBlockAlloc = block.encodeAlloc;
pub const decodeBlockAllocExactSize = block.decodeAllocExactSize;
pub const parseZstdMetadata = block.parseZstdMetadata;

test {
    _ = lzjb;
    _ = zle;
    _ = block;
}

test "ZFS decodes pinned OpenZFS LZJB output" {
    const std = @import("std");
    const encoded_text = @embedFile("zfs/testdata/openzfs-lzjb.bin.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const encoded = try std.testing.allocator.alloc(
        u8,
        base64.calcSizeUpperBound(encoded_text.len),
    );
    defer std.testing.allocator.free(encoded);
    const encoded_len = try base64.decode(encoded, encoded_text);
    const expected = "OpenZFS pinned LZJB payload 0123456789\n" ** 300;
    const decoded = try decodeLzjbAllocExactSize(
        std.testing.allocator,
        encoded[0..encoded_len],
        expected.len,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings(expected, decoded);
}

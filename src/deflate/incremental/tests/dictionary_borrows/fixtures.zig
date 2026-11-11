//! Independent RFC 1951 fixed-block fixtures, checked by Python zlib 1.2.11.
const std = @import("std");
const checksum = @import("../../../../checksum.zig");

// BFINAL=1, BTYPE=01; symbol 264 gives length 10; distance symbol 6
// gives base 9 plus two extra bits containing 1; symbol 256 ends the block.
// The entire output is the last ten bytes of the supplied dictionary.
// Python zlib.decompressobj(wbits=-15, zdict=b"ABCDEFGHIJ") returns that
// dictionary; decompressing without a dictionary reports an invalid distance.
pub const tail_match = [_]u8{ 0x43, 0xb0, 0x00 };
// The same length symbol with distance symbol zero repeats the final byte.
pub const repeat_match = [_]u8{ 0x43, 0x00, 0x00 };
pub const empty_raw = [_]u8{ 0x03, 0x00 };
pub const dictionary = "ABCDEFGHIJ";
pub const stored = [_]u8{ 1, 3, 0, 0xfc, 0xff, 'a', 'b', 'c' };
pub const literal = [_]u8{ 0x73, 0x04, 0x00 }; // Fixed literal 'A', EOB.
// Five nine-bit literals (0x90) in a nonfinal fixed block take 55 bits
// including header/EOB. Seven input bytes therefore leave one bit of the
// next block header buffered. The final fixed block contains literal 'A'.
pub const partial_header = [_]u8{ 0x9a, 0x30, 0x61, 0xc2, 0x84, 0x09, 0x80, 0x39, 0x02, 0x00 };
pub const partial_header_output = [_]u8{ 0x90, 0x90, 0x90, 0x90, 0x90, 'A' };

pub const Frame = struct {
    bytes: [32]u8 = @splat(0xa5),
    len: usize,

    pub fn slice(self: *const Frame) []const u8 {
        return self.bytes[0..self.len];
    }
};

/// Assemble RFC 1950 framing around the independent raw fixture. DICTID
/// covers the full dictionary, while the footer covers only decoded bytes.
pub fn frame(dictionary_bytes: []const u8, compressed: []const u8, output: []const u8) Frame {
    var result = Frame{ .len = 6 + compressed.len + 4 };
    @memcpy(result.bytes[0..2], &[_]u8{ 0x78, 0x20 });
    std.mem.writeInt(u32, result.bytes[2..6], checksum.Adler32.hash(dictionary_bytes), .big);
    @memcpy(result.bytes[6..][0..compressed.len], compressed);
    std.mem.writeInt(u32, result.bytes[6 + compressed.len ..][0..4], checksum.Adler32.hash(output), .big);
    return result;
}

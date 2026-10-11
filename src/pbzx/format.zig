const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidPbzx,
    UnsupportedPbzxCompression,
};

pub const magic = "pbzx";
pub const xz_magic = [_]u8{ 0xfd, '7', 'z', 'X', 'Z', 0x00 };
pub const header_size: usize = 12;
pub const chunk_header_size: usize = 16;

pub const Chunk = struct {
    index: usize,
    decoded_offset: usize,
    decoded_size: usize,
    packed_offset: usize,
    packed_size: usize,

    pub fn isStored(self: Chunk) bool {
        return self.decoded_size == self.packed_size;
    }
};

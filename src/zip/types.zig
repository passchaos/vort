const winzip_aes = @import("vail_archive_crypto").winzip_aes;

pub const WinZipAesStrength = winzip_aes.Strength;

pub const WinZipAesVendorVersion = enum(u16) {
    ae1 = 1,
    ae2 = 2,
};

pub const WinZipAesInfo = struct {
    version: WinZipAesVendorVersion,
    strength: WinZipAesStrength,
};

pub const CompressionMethod = enum(u16) {
    stored = 0,
    shrink = 1,
    reduce_1 = 2,
    reduce_2 = 3,
    reduce_3 = 4,
    reduce_4 = 5,
    implode = 6,
    deflate = 8,
    deflate64 = 9,
    dcl_implode = 10,
    bzip2 = 12,
    lzma = 14,
    /// Deprecated PKWARE assignment retained for archives created before
    /// APPNOTE 6.3.8 reassigned Zstandard from method 20 to method 93.
    zstandard_legacy = 20,
    zstandard = 93,
    xz = 95,
    ppmd = 98,
    aes = 99,
    _,
};

/// Canonical central-directory metadata for one ZIP member.
///
/// `name` borrows the parsed archive bytes. The remaining fields are copied
/// values and can be used to configure an incremental entry decoder.
pub const Entry = struct {
    name: []const u8,
    method: CompressionMethod,
    flags: u16,
    crc32: u32,
    compressed_size: usize,
    uncompressed_size: usize,
    local_header_offset: usize,
    central_header_offset: usize,
    zip64: bool,
    winzip_aes: ?WinZipAesInfo = null,

    pub fn isDirectory(self: Entry) bool {
        return self.name.len != 0 and self.name[self.name.len - 1] == '/';
    }

    pub fn isEncrypted(self: Entry) bool {
        return self.flags & 1 != 0;
    }

    pub fn isWinZipAes(self: Entry) bool {
        return self.winzip_aes != null;
    }
};

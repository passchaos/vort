const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidXar,
    InvalidXarToc,
    UnsupportedXarCompression,
    UnsupportedXarChecksum,
    UnsupportedXarEntry,
    EncryptedXarEntry,
};

pub const magic: u32 = 0x7861_7221;
pub const base_header_size: usize = 28;

pub const ChecksumAlgorithm = enum(u32) {
    none = 0,
    sha1 = 1,
    md5 = 2,
    sha256 = 3,
    sha512 = 4,

    pub fn digestSize(self: ChecksumAlgorithm) usize {
        return switch (self) {
            .none => 0,
            .sha1 => 20,
            .md5 => 16,
            .sha256 => 32,
            .sha512 => 64,
        };
    }

    pub fn style(self: ChecksumAlgorithm) []const u8 {
        return switch (self) {
            .none => "none",
            .sha1 => "sha1",
            .md5 => "md5",
            .sha256 => "sha256",
            .sha512 => "sha512",
        };
    }

    pub fn fromStyle(style_text: []const u8) ?ChecksumAlgorithm {
        inline for (std.enums.values(ChecksumAlgorithm)) |algorithm|
            if (std.ascii.eqlIgnoreCase(style_text, algorithm.style()))
                return algorithm;
        return null;
    }
};

pub const Digest = struct {
    algorithm: ChecksumAlgorithm = .none,
    bytes: [64]u8 = @splat(0),

    pub fn slice(self: *const Digest) []const u8 {
        return self.bytes[0..self.algorithm.digestSize()];
    }
};

pub const Header = struct {
    header_size: usize,
    version: u16,
    toc_packed_size: usize,
    toc_size: usize,
    checksum_algorithm: ChecksumAlgorithm,

    pub fn heapOffset(self: Header) Error!usize {
        return std.math.add(usize, self.header_size, self.toc_packed_size) catch
            error.IntegerOverflow;
    }
};

pub const Encoding = enum {
    copy,
    zlib,
    bzip2,
    lzma,
    xz,

    pub fn style(self: Encoding) []const u8 {
        return switch (self) {
            .copy => "application/octet-stream",
            .zlib => "application/x-gzip",
            .bzip2 => "application/x-bzip2",
            .lzma => "application/x-lzma",
            .xz => "application/x-xz",
        };
    }

    pub fn fromStyle(style_text: []const u8) ?Encoding {
        if (style_text.len == 0 or
            std.ascii.eqlIgnoreCase(style_text, "octet-stream") or
            std.ascii.eqlIgnoreCase(style_text, "application/octet-stream"))
            return .copy;
        if (std.ascii.eqlIgnoreCase(style_text, "zlib") or
            std.ascii.eqlIgnoreCase(style_text, "application/x-gzip"))
            return .zlib;
        if (std.ascii.eqlIgnoreCase(style_text, "bzip2") or
            std.ascii.eqlIgnoreCase(style_text, "application/x-bzip2"))
            return .bzip2;
        if (std.ascii.eqlIgnoreCase(style_text, "lzma") or
            std.ascii.eqlIgnoreCase(style_text, "application/x-lzma"))
            return .lzma;
        if (std.ascii.eqlIgnoreCase(style_text, "xz") or
            std.ascii.eqlIgnoreCase(style_text, "application/x-xz"))
            return .xz;
        return null;
    }
};

pub const EntryKind = enum {
    file,
    directory,
    symlink,
    other,
};

pub const Data = struct {
    size: usize,
    packed_size: usize,
    offset: usize,
    encoding: Encoding,
    archived_checksum: Digest = .{},
    extracted_checksum: Digest = .{},
};

pub const Entry = struct {
    id: ?u64,
    parent: ?usize,
    path: []u8,
    kind: EntryKind,
    mode: ?u32,
    uid: ?u64,
    gid: ?u64,
    link_target: ?[]u8,
    data: ?Data,

    pub fn deinit(self: Entry, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        if (self.link_target) |target| allocator.free(target);
    }

    pub fn basename(self: Entry) []const u8 {
        const offset = std.mem.lastIndexOfScalar(u8, self.path, '/') orelse
            return self.path;
        return self.path[offset + 1 ..];
    }
};

pub fn parseHeader(input: []const u8) Error!Header {
    if (input.len < base_header_size) return error.TruncatedFrame;
    if (readU32Be(input, 0) != magic) return error.InvalidMagic;
    const header_size: usize = readU16Be(input, 4);
    if (header_size < base_header_size or header_size > input.len)
        return error.InvalidXar;
    const version = readU16Be(input, 6);
    if (version > 1) return error.UnsupportedVersion;
    const toc_packed_size = std.math.cast(usize, readU64Be(input, 8)) orelse
        return error.IntegerOverflow;
    const toc_size = std.math.cast(usize, readU64Be(input, 16)) orelse
        return error.IntegerOverflow;
    const checksum_algorithm = std.enums.fromInt(
        ChecksumAlgorithm,
        readU32Be(input, 24),
    ) orelse return error.UnsupportedXarChecksum;
    const toc_end = std.math.add(usize, header_size, toc_packed_size) catch
        return error.IntegerOverflow;
    if (toc_end > input.len) return error.TruncatedFrame;
    return .{
        .header_size = header_size,
        .version = version,
        .toc_packed_size = toc_packed_size,
        .toc_size = toc_size,
        .checksum_algorithm = checksum_algorithm,
    };
}

pub fn hash(algorithm: ChecksumAlgorithm, input: []const u8) Digest {
    var digest = Digest{ .algorithm = algorithm };
    switch (algorithm) {
        .none => {},
        .sha1 => std.crypto.hash.Sha1.hash(input, digest.bytes[0..20], .{}),
        .md5 => std.crypto.hash.Md5.hash(input, digest.bytes[0..16], .{}),
        .sha256 => std.crypto.hash.sha2.Sha256.hash(input, digest.bytes[0..32], .{}),
        .sha512 => std.crypto.hash.sha2.Sha512.hash(input, digest.bytes[0..64], .{}),
    }
    return digest;
}

pub fn readU16Be(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .big);
}

pub fn readU32Be(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .big);
}

pub fn readU64Be(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .big);
}

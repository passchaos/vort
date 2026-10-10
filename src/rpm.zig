const std = @import("std");
const core = @import("core.zig");
const cpio = @import("cpio.zig");
const header_mod = @import("rpm/header.zig");

pub const Error = core.Error || cpio.Error || header_mod.Error || error{
    InvalidRpmPackage,
    UnsupportedRpmPayload,
};

pub const Header = header_mod.Header;
pub const Index = header_mod.Index;
pub const ValueType = header_mod.ValueType;
pub const StringIterator = header_mod.StringIterator;

pub const PayloadCompression = enum { none, gzip, bzip2, lzma, xz, zstandard };

pub const Lead = struct {
    major: u8,
    minor: u8,
    package_type: u16,
    architecture: u16,
    name: []const u8,
    operating_system: u16,
    signature_type: u16,
};

pub const Package = struct {
    bytes: []const u8,
    lead: Lead,
    signature: Header,
    header: Header,
    payload_offset: usize,
    payload_compression: PayloadCompression,

    pub fn name(self: Package) Error![]const u8 {
        return (try self.header.string(tag_name)) orelse return error.InvalidRpmPackage;
    }

    pub fn version(self: Package) Error![]const u8 {
        return (try self.header.string(tag_version)) orelse return error.InvalidRpmPackage;
    }

    pub fn release(self: Package) Error![]const u8 {
        return (try self.header.string(tag_release)) orelse return error.InvalidRpmPackage;
    }

    pub fn architecture(self: Package) Error![]const u8 {
        return (try self.header.string(tag_arch)) orelse return error.InvalidRpmPackage;
    }

    pub fn operatingSystem(self: Package) Error![]const u8 {
        return (try self.header.string(tag_os)) orelse return error.InvalidRpmPackage;
    }

    pub fn decodePayloadAlloc(
        self: Package,
        allocator: std.mem.Allocator,
        max_cpio_size: usize,
    ) !cpio.OwnedArchive {
        return cpio.decodeCompressedAlloc(
            allocator,
            self.bytes[self.payload_offset..],
            cpioCompression(self.payload_compression),
            max_cpio_size,
        );
    }

    pub fn extractByNameAllocLimited(
        self: Package,
        allocator: std.mem.Allocator,
        entry_name: []const u8,
        max_cpio_size: usize,
        max_output_len: usize,
    ) ![]u8 {
        const owned = try self.decodePayloadAlloc(allocator, max_cpio_size);
        defer owned.deinit(allocator);
        return owned.archive.extractByNameAllocLimited(allocator, entry_name, max_output_len);
    }
};

pub fn parse(bytes: []const u8) Error!Package {
    const lead = try parseLead(bytes);
    const signature = try header_mod.parse(bytes, lead_size);
    const main_offset = try alignEnd(signature.next_offset, 8, bytes.len);
    for (bytes[signature.next_offset..main_offset]) |byte|
        if (byte != 0) return error.InvalidRpmPackage;
    const main = try header_mod.parse(bytes, main_offset);
    if (main.next_offset == bytes.len) return error.TruncatedFrame;
    const payload_format = (try main.header.string(tag_payload_format)) orelse
        return error.InvalidRpmPackage;
    if (!std.mem.eql(u8, payload_format, "cpio")) return error.UnsupportedRpmPayload;
    const compressor = (try main.header.string(tag_payload_compressor)) orelse "none";
    return .{
        .bytes = bytes,
        .lead = lead,
        .signature = signature.header,
        .header = main.header,
        .payload_offset = main.next_offset,
        .payload_compression = try parseCompression(compressor),
    };
}

fn parseLead(bytes: []const u8) Error!Lead {
    if (bytes.len < lead_size) return error.TruncatedFrame;
    if (!std.mem.eql(u8, bytes[0..4], &.{ 0xed, 0xab, 0xee, 0xdb }))
        return error.InvalidMagic;
    if (bytes[4] != 3) return error.UnsupportedVersion;
    const name_field = bytes[10..76];
    const name_end = std.mem.indexOfScalar(u8, name_field, 0) orelse
        return error.InvalidRpmPackage;
    for (bytes[80..96]) |byte| if (byte != 0) return error.InvalidRpmPackage;
    const signature_type = std.mem.readInt(u16, bytes[78..80], .big);
    if (signature_type != 5) return error.UnsupportedRpmPayload;
    return .{
        .major = bytes[4],
        .minor = bytes[5],
        .package_type = std.mem.readInt(u16, bytes[6..8], .big),
        .architecture = std.mem.readInt(u16, bytes[8..10], .big),
        .name = name_field[0..name_end],
        .operating_system = std.mem.readInt(u16, bytes[76..78], .big),
        .signature_type = signature_type,
    };
}

fn parseCompression(name: []const u8) Error!PayloadCompression {
    if (std.mem.eql(u8, name, "none")) return .none;
    if (std.mem.eql(u8, name, "gzip")) return .gzip;
    if (std.mem.eql(u8, name, "bzip2")) return .bzip2;
    if (std.mem.eql(u8, name, "lzma")) return .lzma;
    if (std.mem.eql(u8, name, "xz")) return .xz;
    if (std.mem.eql(u8, name, "zstd")) return .zstandard;
    return error.UnsupportedRpmPayload;
}

fn cpioCompression(compression: PayloadCompression) cpio.Compression {
    return switch (compression) {
        .none => .none,
        .gzip => .gzip,
        .bzip2 => .bzip2,
        .lzma => .lzma,
        .xz => .xz,
        .zstandard => .zstandard,
    };
}

fn alignEnd(offset: usize, alignment: usize, limit: usize) Error!usize {
    const padded = std.math.add(usize, offset, alignment - 1) catch
        return error.IntegerOverflow;
    const end = padded & ~(alignment - 1);
    if (end > limit) return error.TruncatedFrame;
    return end;
}

const lead_size: usize = 96;
pub const tag_name: u32 = 1000;
pub const tag_version: u32 = 1001;
pub const tag_release: u32 = 1002;
pub const tag_os: u32 = 1021;
pub const tag_arch: u32 = 1022;
pub const tag_payload_format: u32 = 1124;
pub const tag_payload_compressor: u32 = 1125;
pub const tag_payload_flags: u32 = 1126;

test "RPM parser rejects missing and malformed leads" {
    try std.testing.expectError(error.TruncatedFrame, parse(""));
    var lead: [lead_size]u8 = @splat(0);
    lead[0..4].* = .{ 0xed, 0xab, 0xee, 0xdb };
    lead[4] = 3;
    lead[10] = 'x';
    std.mem.writeInt(u16, lead[78..80], 5, .big);
    try std.testing.expectError(error.TruncatedFrame, parse(&lead));
}

test {
    _ = header_mod;
}

const std = @import("std");
const ar = @import("ar.zig");
const tar = @import("tar.zig");

pub const Error = ar.Error || tar.Error || error{
    InvalidDebPackage,
    MissingDebControlArchive,
    MissingDebDataArchive,
    UnsupportedDebCompression,
};

pub const Compression = enum { none, gzip, bzip2, lzma, xz, zstandard };

pub const Package = struct {
    archive: ar.Archive,
    control_entry: ar.Entry,
    data_entry: ar.Entry,
    control_compression: Compression,
    data_compression: Compression,

    pub fn decodeControlAlloc(
        self: Package,
        allocator: std.mem.Allocator,
        max_tar_size: usize,
    ) !tar.OwnedArchive {
        return tar.decodeCompressedAlloc(
            allocator,
            self.archive.bytes[self.control_entry.data_offset..][0..self.control_entry.size],
            tarCompression(self.control_compression),
            max_tar_size,
        );
    }

    pub fn decodeDataAlloc(
        self: Package,
        allocator: std.mem.Allocator,
        max_tar_size: usize,
    ) !tar.OwnedArchive {
        return tar.decodeCompressedAlloc(
            allocator,
            self.archive.bytes[self.data_entry.data_offset..][0..self.data_entry.size],
            tarCompression(self.data_compression),
            max_tar_size,
        );
    }

    pub fn extractDataByNameAllocLimited(
        self: Package,
        allocator: std.mem.Allocator,
        name: []const u8,
        max_tar_size: usize,
        max_output_len: usize,
    ) ![]u8 {
        const owned = try self.decodeDataAlloc(allocator, max_tar_size);
        defer owned.deinit(allocator);
        return owned.archive.extractByNameAllocLimited(allocator, name, max_output_len);
    }
};

pub const EncodeOptions = struct {
    control_compression: Compression = .gzip,
    data_compression: Compression = .xz,
};

pub fn parse(bytes: []const u8) Error!Package {
    const archive_value = try ar.parse(bytes);
    if (archive_value.entry_count < 3) return error.InvalidDebPackage;
    var iterator_value = archive_value.iterator();
    const version = (try iterator_value.next()) orelse return error.InvalidDebPackage;
    if (!std.mem.eql(u8, version.name, "debian-binary") or version.size != 4 or
        !std.mem.eql(u8, bytes[version.data_offset..][0..version.size], "2.0\n"))
        return error.InvalidDebPackage;

    var control_entry: ?ar.Entry = null;
    var data_entry: ?ar.Entry = null;
    var control_compression: Compression = undefined;
    var data_compression: Compression = undefined;
    while (try iterator_value.next()) |entry| {
        if (try compressionForName(entry.name, "control.tar")) |compression| {
            if (control_entry != null or data_entry != null) return error.InvalidDebPackage;
            control_entry = entry;
            control_compression = compression;
        } else if (try compressionForName(entry.name, "data.tar")) |compression| {
            if (control_entry == null or data_entry != null) return error.InvalidDebPackage;
            data_entry = entry;
            data_compression = compression;
        } else if (!std.mem.eql(u8, entry.name, "_gpgorigin")) {
            return error.InvalidDebPackage;
        }
    }
    return .{
        .archive = archive_value,
        .control_entry = control_entry orelse return error.MissingDebControlArchive,
        .data_entry = data_entry orelse return error.MissingDebDataArchive,
        .control_compression = control_compression,
        .data_compression = data_compression,
    };
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    control_entries: []const tar.EncodeEntry,
    data_entries: []const tar.EncodeEntry,
    options: EncodeOptions,
) ![]u8 {
    if (!hasControlFile(control_entries)) return error.InvalidDebPackage;
    const control = try tar.encodeCompressedAlloc(
        allocator,
        control_entries,
        .{ .compression = tarCompression(options.control_compression) },
    );
    defer allocator.free(control);
    const data = try tar.encodeCompressedAlloc(
        allocator,
        data_entries,
        .{ .compression = tarCompression(options.data_compression) },
    );
    defer allocator.free(data);
    const entries = [_]ar.EncodeEntry{
        .{ .name = "debian-binary", .data = "2.0\n" },
        .{ .name = archiveName("control.tar", options.control_compression), .data = control },
        .{ .name = archiveName("data.tar", options.data_compression), .data = data },
    };
    return ar.encodeAlloc(allocator, &entries);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    control_entries: []const tar.EncodeEntry,
    data_entries: []const tar.EncodeEntry,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeAlloc(allocator, control_entries, data_entries, options);
    defer allocator.free(encoded);
    const start = output.items.len;
    errdefer output.items.len = start;
    try output.appendSlice(allocator, encoded);
    return encoded.len;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    control_entries: []const tar.EncodeEntry,
    data_entries: []const tar.EncodeEntry,
    options: EncodeOptions,
    output: []u8,
) !usize {
    const encoded = try encodeAlloc(allocator, control_entries, data_entries, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn hasControlFile(entries: []const tar.EncodeEntry) bool {
    for (entries) |entry| {
        if (entry.kind == .file and (std.mem.eql(u8, entry.name, "control") or
            std.mem.eql(u8, entry.name, "./control"))) return true;
    }
    return false;
}

fn compressionForName(name: []const u8, prefix: []const u8) Error!?Compression {
    if (!std.mem.startsWith(u8, name, prefix)) return null;
    const suffix = name[prefix.len..];
    if (suffix.len == 0) return .none;
    if (std.mem.eql(u8, suffix, ".gz")) return .gzip;
    if (std.mem.eql(u8, suffix, ".bz2")) return .bzip2;
    if (std.mem.eql(u8, suffix, ".lzma")) return .lzma;
    if (std.mem.eql(u8, suffix, ".xz")) return .xz;
    if (std.mem.eql(u8, suffix, ".zst")) return .zstandard;
    return error.UnsupportedDebCompression;
}

fn archiveName(prefix: []const u8, compression: Compression) []const u8 {
    return switch (compression) {
        .none => prefix,
        .gzip => if (prefix[0] == 'c') "control.tar.gz" else "data.tar.gz",
        .bzip2 => if (prefix[0] == 'c') "control.tar.bz2" else "data.tar.bz2",
        .lzma => if (prefix[0] == 'c') "control.tar.lzma" else "data.tar.lzma",
        .xz => if (prefix[0] == 'c') "control.tar.xz" else "data.tar.xz",
        .zstandard => if (prefix[0] == 'c') "control.tar.zst" else "data.tar.zst",
    };
}

fn tarCompression(compression: Compression) tar.Compression {
    return switch (compression) {
        .none => .none,
        .gzip => .gzip,
        .bzip2 => .bzip2,
        .lzma => .lzma,
        .xz => .xz,
        .zstandard => .zstandard,
    };
}

test "Debian package writer round trips compressed control and data archives" {
    const allocator = std.testing.allocator;
    const control_entries = [_]tar.EncodeEntry{.{
        .name = "control",
        .data = "Package: vort-test\nVersion: 1.0\nArchitecture: all\nMaintainer: Vort\nDescription: test\n",
    }};
    const data_entries = [_]tar.EncodeEntry{.{
        .name = "usr/share/vort/payload.txt",
        .data = "deb payload",
    }};
    inline for (.{
        Compression.none,
        .gzip,
        .bzip2,
        .lzma,
        .xz,
        .zstandard,
    }) |compression| {
        const encoded = try encodeAlloc(allocator, &control_entries, &data_entries, .{
            .control_compression = compression,
            .data_compression = compression,
        });
        defer allocator.free(encoded);
        const package = try parse(encoded);
        try std.testing.expectEqual(compression, package.control_compression);
        try std.testing.expectEqual(compression, package.data_compression);
        const payload = try package.extractDataByNameAllocLimited(
            allocator,
            data_entries[0].name,
            1024 * 1024,
            1024,
        );
        defer allocator.free(payload);
        try std.testing.expectEqualStrings(data_entries[0].data, payload);
    }
}

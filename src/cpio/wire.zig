//! Shared deterministic CPIO wire serialization.

const std = @import("std");
const archive = @import("archive.zig");

pub const Error = archive.Error || std.mem.Allocator.Error || error{
    InvalidCpioEntryName,
    InvalidCpioOptions,
    CpioFieldOverflow,
};

pub const Metadata = struct {
    inode: u32,
    mode: u32,
    uid: u32,
    gid: u32,
    link_count: u32,
    mtime: u32,
    device_major: u32,
    device_minor: u32,
    rdevice_major: u32,
    rdevice_minor: u32,
};

pub fn validateName(name: []const u8) Error!void {
    if (!archive.isSafePath(name) or
        std.mem.eql(u8, name, archive.trailer_name) or
        std.mem.indexOfScalar(u8, name, 0) != null)
    {
        return error.InvalidCpioEntryName;
    }
}

pub fn validateDataKind(kind: archive.Kind, data_size: usize) Error!void {
    switch (kind) {
        .regular, .symlink => {},
        .directory, .block_device, .character_device, .fifo, .socket => if (data_size != 0) return error.InvalidCpioOptions,
        .unknown => return error.UnsupportedCpioEntry,
    }
}

pub fn modeFor(kind: archive.Kind, permissions: ?u16) Error!u32 {
    const type_mode: u32 = switch (kind) {
        .regular => archive.mode_regular,
        .directory => archive.mode_directory,
        .symlink => archive.mode_symlink,
        .block_device => archive.mode_block,
        .character_device => archive.mode_character,
        .fifo => archive.mode_fifo,
        .socket => archive.mode_socket,
        .unknown => return error.UnsupportedCpioEntry,
    };
    const defaults: u16 = switch (kind) {
        .directory => 0o755,
        .symlink => 0o777,
        else => 0o644,
    };
    return type_mode | (@as(u32, permissions orelse defaults) & 0o7777);
}

/// Appends one complete entry. `base_offset` is the absolute archive offset
/// corresponding to `output.items[0]`, so alignment remains correct when a
/// caller prepares a record in a temporary buffer.
pub fn appendEntry(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    base_offset: u64,
    name: []const u8,
    data: []const u8,
    metadata: Metadata,
    format: archive.Format,
) Error!void {
    try appendEntryPrefix(
        allocator,
        output,
        base_offset,
        name,
        data.len,
        if (format == .crc) archive.byteSum(data) else 0,
        metadata,
        format,
    );
    try output.appendSlice(allocator, data);
    try appendPadding(
        allocator,
        output,
        paddingForAppended(base_offset, output.items.len, dataAlignment(format)),
    );
}

/// Appends the header, pathname, terminator and pre-data alignment for one
/// entry. CRC callers must supply the byte sum before publishing this prefix.
pub fn appendEntryPrefix(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    base_offset: u64,
    name: []const u8,
    data_size: usize,
    checksum: u32,
    metadata: Metadata,
    format: archive.Format,
) Error!void {
    const name_size = std.math.add(usize, name.len, 1) catch return error.IntegerOverflow;
    switch (format) {
        .newc, .crc => try appendNewAsciiPrefix(
            allocator,
            output,
            base_offset,
            name,
            name_size,
            data_size,
            checksum,
            metadata,
            format,
        ),
        .odc => try appendOldAsciiPrefix(
            allocator,
            output,
            name,
            name_size,
            data_size,
            metadata,
        ),
        .binary_little, .binary_big => try appendBinaryPrefix(
            allocator,
            output,
            base_offset,
            name,
            name_size,
            data_size,
            metadata,
            format,
        ),
    }
}

pub fn entryPrefixLen(base_offset: u64, name_len: usize, format: archive.Format) Error!usize {
    const name_size = std.math.add(usize, name_len, 1) catch return error.IntegerOverflow;
    const header_size: usize = switch (format) {
        .newc, .crc => archive.newc_header_size,
        .odc => archive.odc_header_size,
        .binary_little, .binary_big => archive.binary_header_size,
    };
    const unaligned = std.math.add(usize, header_size, name_size) catch
        return error.IntegerOverflow;
    const padding = paddingForAppended(base_offset, unaligned, dataAlignment(format));
    return std.math.add(usize, unaligned, padding) catch error.IntegerOverflow;
}

fn appendNewAsciiPrefix(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    base_offset: u64,
    name: []const u8,
    name_size: usize,
    data_size_raw: usize,
    checksum: u32,
    metadata: Metadata,
    format: archive.Format,
) Error!void {
    const name_size_u32 = std.math.cast(u32, name_size) orelse
        return error.CpioFieldOverflow;
    const data_size = std.math.cast(u32, data_size_raw) orelse
        return error.CpioFieldOverflow;
    try output.appendSlice(allocator, if (format == .crc) archive.magic_crc else archive.magic_newc);
    inline for (.{
        metadata.inode,
        metadata.mode,
        metadata.uid,
        metadata.gid,
        metadata.link_count,
        metadata.mtime,
        data_size,
        metadata.device_major,
        metadata.device_minor,
        metadata.rdevice_major,
        metadata.rdevice_minor,
        name_size_u32,
        if (format == .crc) checksum else @as(u32, 0),
    }) |value| try appendNumber(allocator, output, value, 8, 16);
    try appendName(allocator, output, name);
    try appendPadding(allocator, output, paddingForAppended(base_offset, output.items.len, 4));
}

fn appendOldAsciiPrefix(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    name_size: usize,
    data_size: usize,
    metadata: Metadata,
) Error!void {
    if (metadata.device_major != 0 or metadata.rdevice_major != 0)
        return error.CpioFieldOverflow;
    try output.appendSlice(allocator, archive.magic_odc);
    try appendNumber(allocator, output, metadata.device_minor, 6, 8);
    try appendNumber(allocator, output, metadata.inode, 6, 8);
    try appendNumber(allocator, output, metadata.mode, 6, 8);
    try appendNumber(allocator, output, metadata.uid, 6, 8);
    try appendNumber(allocator, output, metadata.gid, 6, 8);
    try appendNumber(allocator, output, metadata.link_count, 6, 8);
    try appendNumber(allocator, output, metadata.rdevice_minor, 6, 8);
    try appendNumber(allocator, output, metadata.mtime, 11, 8);
    try appendNumber(allocator, output, name_size, 6, 8);
    try appendNumber(allocator, output, data_size, 11, 8);
    try appendName(allocator, output, name);
}

fn appendBinaryPrefix(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    base_offset: u64,
    name: []const u8,
    name_size: usize,
    data_size: usize,
    metadata: Metadata,
    format: archive.Format,
) Error!void {
    if (metadata.device_major != 0 or metadata.rdevice_major != 0)
        return error.CpioFieldOverflow;
    const endian: std.builtin.Endian = if (format == .binary_little) .little else .big;
    const inode = std.math.cast(u16, metadata.inode) orelse return error.CpioFieldOverflow;
    const mode = std.math.cast(u16, metadata.mode) orelse return error.CpioFieldOverflow;
    const uid = std.math.cast(u16, metadata.uid) orelse return error.CpioFieldOverflow;
    const gid = std.math.cast(u16, metadata.gid) orelse return error.CpioFieldOverflow;
    const links = std.math.cast(u16, metadata.link_count) orelse return error.CpioFieldOverflow;
    const device = std.math.cast(u16, metadata.device_minor) orelse return error.CpioFieldOverflow;
    const rdevice = std.math.cast(u16, metadata.rdevice_minor) orelse return error.CpioFieldOverflow;
    const names = std.math.cast(u16, name_size) orelse return error.CpioFieldOverflow;
    const size = std.math.cast(u32, data_size) orelse return error.CpioFieldOverflow;
    try appendInt16(allocator, output, archive.binary_magic, endian);
    try appendInt16(allocator, output, device, endian);
    try appendInt16(allocator, output, inode, endian);
    try appendInt16(allocator, output, mode, endian);
    try appendInt16(allocator, output, uid, endian);
    try appendInt16(allocator, output, gid, endian);
    try appendInt16(allocator, output, links, endian);
    try appendInt16(allocator, output, rdevice, endian);
    try appendSplit32(allocator, output, metadata.mtime, endian);
    try appendInt16(allocator, output, names, endian);
    try appendSplit32(allocator, output, size, endian);
    try appendName(allocator, output, name);
    try appendPadding(allocator, output, paddingForAppended(base_offset, output.items.len, 2));
}

fn appendName(allocator: std.mem.Allocator, output: *std.ArrayList(u8), name: []const u8) Error!void {
    try output.appendSlice(allocator, name);
    try output.append(allocator, 0);
}

fn appendNumber(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    raw_value: anytype,
    width: usize,
    radix: u8,
) Error!void {
    var field: [16]u8 = @splat('0');
    std.debug.assert(width <= field.len);
    var value: u64 = @intCast(raw_value);
    var index = width;
    while (index != 0 and value != 0) {
        index -= 1;
        const digit: u8 = @intCast(value % radix);
        field[index] = if (digit < 10) '0' + digit else 'A' + digit - 10;
        value /= radix;
    }
    if (value != 0) return error.CpioFieldOverflow;
    try output.appendSlice(allocator, field[0..width]);
}

fn appendInt16(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u16,
    endian: std.builtin.Endian,
) Error!void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, endian);
    try output.appendSlice(allocator, &bytes);
}

fn appendSplit32(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u32,
    endian: std.builtin.Endian,
) Error!void {
    try appendInt16(allocator, output, @truncate(value >> 16), endian);
    try appendInt16(allocator, output, @truncate(value), endian);
}

pub fn appendPadding(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    count: usize,
) Error!void {
    try output.appendNTimes(allocator, 0, count);
}

pub fn dataAlignment(format: archive.Format) usize {
    return switch (format) {
        .newc, .crc => 4,
        .binary_little, .binary_big => 2,
        .odc => 1,
    };
}

pub fn paddingFor(offset: usize, alignment: usize) usize {
    if (alignment == 0) return 0;
    return (alignment - offset % alignment) % alignment;
}

pub fn paddingForU64(offset: u64, alignment: usize) usize {
    if (alignment == 0) return 0;
    const alignment_u64: u64 = @intCast(alignment);
    return @intCast((alignment_u64 - offset % alignment_u64) % alignment_u64);
}

fn paddingForAppended(base_offset: u64, appended: usize, alignment: usize) usize {
    if (alignment == 0) return 0;
    const alignment_u64: u64 = @intCast(alignment);
    const remainder = (base_offset % alignment_u64 +
        @as(u64, @intCast(appended % alignment))) % alignment_u64;
    return @intCast((alignment_u64 - remainder) % alignment_u64);
}

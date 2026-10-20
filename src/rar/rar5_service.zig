const std = @import("std");

pub const Error = error{
    InvalidRarArchive,
    TruncatedFrame,
    IntegerOverflow,
};

pub const comment_name = "CMT";
pub const max_writer_comment_size: usize = 256 * 1024;

pub const header_data: u64 = 0x0002;
pub const header_split_before: u64 = 0x0008;
pub const header_split_after: u64 = 0x0010;
pub const file_directory: u64 = 0x0001;
pub const file_mtime: u64 = 0x0002;
pub const file_crc32: u64 = 0x0004;
pub const file_unknown_size: u64 = 0x0008;

/// Fields shared by RAR5 file and service headers. The surrounding archive
/// parser owns the common header, extra-area, and data-area accounting.
pub const Header = struct {
    file_flags: u64,
    unpacked_size: usize,
    attributes: u64,
    mtime: ?u32,
    data_crc32: ?u32,
    compression_info: u64,
    host_os: u64,
    name: []const u8,

    pub fn methodId(self: Header) u8 {
        return @intCast((self.compression_info >> 7) & 7);
    }

    pub fn compressionVersion(self: Header) u8 {
        return @intCast(self.compression_info & 0x3f);
    }
};

pub fn parse(bytes: []const u8, start: usize, end: usize) Error!Header {
    var cursor = start;
    const file_flags = try readVint(bytes, &cursor, end);
    const unpacked_u64 = try readVint(bytes, &cursor, end);
    const attributes = try readVint(bytes, &cursor, end);
    const mtime = if (file_flags & file_mtime != 0) blk: {
        const field_end = try checkedEnd(cursor, 4, end, bytes.len);
        const value = std.mem.readInt(u32, bytes[cursor..field_end][0..4], .little);
        cursor = field_end;
        break :blk value;
    } else null;
    const data_crc32 = if (file_flags & file_crc32 != 0) blk: {
        const field_end = try checkedEnd(cursor, 4, end, bytes.len);
        const value = std.mem.readInt(u32, bytes[cursor..field_end][0..4], .little);
        cursor = field_end;
        break :blk value;
    } else null;
    const compression_info = try readVint(bytes, &cursor, end);
    const host_os = try readVint(bytes, &cursor, end);
    const name_size_u64 = try readVint(bytes, &cursor, end);
    const name_size = std.math.cast(usize, name_size_u64) orelse
        return error.IntegerOverflow;
    const name_end = try checkedEnd(cursor, name_size, end, bytes.len);
    if (name_end != end) return error.InvalidRarArchive;
    return .{
        .file_flags = file_flags,
        .unpacked_size = std.math.cast(usize, unpacked_u64) orelse
            return error.IntegerOverflow,
        .attributes = attributes,
        .mtime = mtime,
        .data_crc32 = data_crc32,
        .compression_info = compression_info,
        .host_os = host_os,
        .name = bytes[cursor..name_end],
    };
}

pub fn isComment(header: Header) bool {
    return std.mem.eql(u8, header.name, comment_name);
}

pub fn validateCommentHeader(
    header: Header,
    general_flags: u64,
    packed_size: usize,
    encrypted: bool,
) Error!void {
    if (!isComment(header) or general_flags & header_data == 0 or
        general_flags & (header_split_before | header_split_after) != 0 or
        header.file_flags & (file_directory | file_unknown_size) != 0 or
        header.methodId() != 0 or header.compression_info & 0x40 != 0)
    {
        return error.InvalidRarArchive;
    }
    if (encrypted) {
        if (packed_size == 0 or packed_size % 16 != 0 or
            packed_size < header.unpacked_size or
            packed_size - header.unpacked_size >= 16)
        {
            return error.InvalidRarArchive;
        }
    } else if (packed_size != header.unpacked_size) {
        return error.InvalidRarArchive;
    }
}

pub fn validCommentText(comment: []const u8) bool {
    return std.unicode.utf8ValidateSlice(comment) and
        std.mem.indexOfScalar(u8, comment, 0) == null;
}

/// Plain CMT payloads occasionally include one trailing wire terminator.
pub fn commentText(stored: []const u8) Error![]const u8 {
    const text = if (stored.len != 0 and stored[stored.len - 1] == 0)
        stored[0 .. stored.len - 1]
    else
        stored;
    if (!validCommentText(text)) return error.InvalidRarArchive;
    return text;
}

/// RARLab encrypted CMT payloads can declare the full AES block as unpacked
/// data: UTF-8 text, a NUL terminator, and remaining block bytes all belong to
/// the CRC/MAC. UnRAR displays only the prefix before that first terminator.
pub fn encryptedCommentText(stored: []const u8) Error![]const u8 {
    const text = if (std.mem.indexOfScalar(u8, stored, 0)) |end|
        stored[0..end]
    else
        stored;
    if (!validCommentText(text)) return error.InvalidRarArchive;
    return text;
}

fn readVint(bytes: []const u8, cursor: *usize, limit: usize) Error!u64 {
    var value: u64 = 0;
    var shift: u6 = 0;
    var count: usize = 0;
    while (count < 10) : (count += 1) {
        if (cursor.* >= limit or cursor.* >= bytes.len) return error.TruncatedFrame;
        const byte = bytes[cursor.*];
        cursor.* += 1;
        if (shift == 63 and byte & 0x7e != 0) return error.IntegerOverflow;
        value |= @as(u64, byte & 0x7f) << shift;
        if (byte & 0x80 == 0) return value;
        if (shift > 56) return error.IntegerOverflow;
        shift += 7;
    }
    return error.InvalidRarArchive;
}

fn checkedEnd(start: usize, len: usize, limit: usize, bytes_len: usize) Error!usize {
    const end = std.math.add(usize, start, len) catch return error.IntegerOverflow;
    if (end > limit or end > bytes_len) return error.TruncatedFrame;
    return end;
}

test "RAR5 shared service header parses the official CMT field shape" {
    const bytes = [_]u8{
        0x04, // CRC flag.
        0x05, // Unpacked size.
        0x00, // Attributes.
        0x86, 0xa6, 0x10, 0x36, // Data CRC32.
        0x00, // Stored compression information.
        0x01, // Unix host.
        0x03,
        'C',
        'M',
        'T',
    };
    const header = try parse(&bytes, 0, bytes.len);
    try std.testing.expect(isComment(header));
    try std.testing.expectEqual(@as(usize, 5), header.unpacked_size);
    try std.testing.expectEqual(@as(?u32, 0x3610a686), header.data_crc32);
    try validateCommentHeader(header, header_data, 5, false);
}

test "RAR5 comment text accepts only an optional trailing wire terminator" {
    try std.testing.expectEqualSlices(u8, "text", try commentText("text\x00"));
    try std.testing.expectError(error.InvalidRarArchive, commentText("te\x00xt"));
    try std.testing.expectError(error.InvalidRarArchive, commentText("\xff"));
    try std.testing.expectEqualSlices(
        u8,
        "text",
        try encryptedCommentText("text\x00\xa5\x13\x6c"),
    );
}

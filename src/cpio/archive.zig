const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidCpioArchive,
    UnsupportedCpioEntry,
    CpioEntryNotFound,
};

pub const Format = enum {
    newc,
    crc,
    odc,
    binary_little,
    binary_big,
};

pub const Kind = enum {
    regular,
    directory,
    symlink,
    block_device,
    character_device,
    fifo,
    socket,
    unknown,
};

pub const Entry = struct {
    name: []const u8,
    format: Format,
    kind: Kind,
    mode: u32,
    inode: u32,
    uid: u32,
    gid: u32,
    link_count: u32,
    mtime: u32,
    device_major: u32,
    device_minor: u32,
    rdevice_major: u32,
    rdevice_minor: u32,
    checksum: ?u32,
    stored_size: usize,
    header_offset: usize,
    header_size: usize,
    data_offset: usize,
    next_offset: usize,
    safe_path: bool,

    pub fn isExtractable(self: Entry) bool {
        return self.kind == .regular or self.kind == .symlink;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    format: Format,
    entry_count: usize,
    archive_end: usize,
    trailer_padding: usize,

    pub fn iterator(self: Archive) Iterator {
        return .{
            .archive = self,
            .remaining = self.entry_count,
        };
    }

    pub fn entryAt(self: Archive, wanted: usize) Error!Entry {
        if (wanted >= self.entry_count) return error.RangeOutOfBounds;
        var it = self.iterator();
        var index: usize = 0;
        while (try it.next()) |entry| : (index += 1)
            if (index == wanted) return entry;
        return error.InvalidCpioArchive;
    }

    pub fn find(self: Archive, name: []const u8) Error!?Entry {
        var it = self.iterator();
        while (try it.next()) |entry|
            if (std.mem.eql(u8, entry.name, name)) return entry;
        return null;
    }

    pub fn extractInto(self: Archive, entry: Entry, output: []u8) Error!usize {
        const canonical = try self.canonicalEntry(entry);
        if (!canonical.isExtractable()) return error.UnsupportedCpioEntry;
        const content = try self.resolveContentEntry(canonical);
        if (output.len < content.stored_size) return error.OutputTooSmall;
        const data_end = try checkedEnd(
            content.data_offset,
            content.stored_size,
            self.bytes.len,
        );
        const data = self.bytes[content.data_offset..data_end];
        if (content.checksum) |expected| {
            // GNU cpio writes zero for CRC-format symlink targets even though
            // the target bytes occupy the entry data field. Accept that
            // historical convention; nonzero symlink checksums are verified.
            if (!(content.kind == .symlink and expected == 0) and
                byteSum(data) != expected)
            {
                return error.ChecksumMismatch;
            }
        }
        @memcpy(output[0..data.len], data);
        return data.len;
    }

    pub fn extractAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
    ) ![]u8 {
        return self.extractAllocLimited(allocator, entry, std.math.maxInt(usize));
    }

    pub fn extractAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        max_output_len: usize,
    ) ![]u8 {
        const content_size = try self.contentSize(entry);
        if (content_size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, content_size);
        errdefer allocator.free(output);
        const written = try self.extractInto(entry, output);
        if (written != output.len) return error.SizeMismatch;
        return output;
    }

    pub fn contentSize(self: Archive, entry: Entry) Error!usize {
        const canonical = try self.canonicalEntry(entry);
        if (!canonical.isExtractable()) return error.UnsupportedCpioEntry;
        return (try self.resolveContentEntry(canonical)).stored_size;
    }

    pub fn extractByNameAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        max_output_len: usize,
    ) ![]u8 {
        const entry = (try self.find(name)) orelse return error.CpioEntryNotFound;
        return self.extractAllocLimited(allocator, entry, max_output_len);
    }

    pub fn extractByNameAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) ![]u8 {
        return self.extractByNameAllocLimited(allocator, name, std.math.maxInt(usize));
    }

    fn canonicalEntry(self: Archive, entry: Entry) Error!Entry {
        const parsed = try parseEntry(self.bytes, entry.header_offset, self.format);
        if (parsed.is_trailer or !sameEntry(parsed.entry, entry))
            return error.InvalidCpioArchive;
        return parsed.entry;
    }

    fn resolveContentEntry(self: Archive, entry: Entry) Error!Entry {
        if (entry.kind != .regular or entry.stored_size != 0 or entry.link_count <= 1)
            return entry;
        var it = self.iterator();
        while (try it.next()) |candidate| {
            if (candidate.kind == .regular and candidate.stored_size != 0 and
                candidate.inode == entry.inode and
                candidate.link_count == entry.link_count and
                candidate.device_major == entry.device_major and
                candidate.device_minor == entry.device_minor)
            {
                return candidate;
            }
        }
        // A hard-linked empty file legitimately has no payload-bearing member.
        return entry;
    }
};

pub const Iterator = struct {
    archive: Archive,
    offset: usize = 0,
    remaining: usize,

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.remaining == 0) return null;
        const parsed = try parseEntry(self.archive.bytes, self.offset, self.archive.format);
        if (parsed.is_trailer) return error.InvalidCpioArchive;
        self.offset = parsed.entry.next_offset;
        self.remaining -= 1;
        return parsed.entry;
    }
};

pub fn parse(bytes: []const u8) Error!Archive {
    const format = try detectFormat(bytes, 0);
    var offset: usize = 0;
    var entry_count: usize = 0;
    const maximum_entries = bytes.len / minimum_header_size + 1;

    while (true) {
        if (entry_count > maximum_entries) return error.InvalidCpioArchive;
        if (try detectFormat(bytes, offset) != format) return error.InvalidCpioArchive;
        const parsed = try parseEntry(bytes, offset, format);
        offset = parsed.entry.next_offset;
        if (parsed.is_trailer) break;
        entry_count += 1;
    }

    for (bytes[offset..]) |byte|
        if (byte != 0) return error.TrailingData;
    return .{
        .bytes = bytes,
        .format = format,
        .entry_count = entry_count,
        .archive_end = offset,
        .trailer_padding = bytes.len - offset,
    };
}

const ParsedEntry = struct {
    entry: Entry,
    is_trailer: bool,
};

pub const FixedHeader = struct {
    format: Format,
    kind: Kind,
    mode: u32,
    inode: u32,
    uid: u32,
    gid: u32,
    link_count: u32,
    mtime: u32,
    device_major: u32,
    device_minor: u32,
    rdevice_major: u32,
    rdevice_minor: u32,
    checksum: ?u32,
    stored_size: usize,
    name_size: usize,
    header_size: usize,
    alignment: usize,
};

fn parseEntry(bytes: []const u8, offset: usize, format: Format) Error!ParsedEntry {
    const header_size = fixedHeaderSize(format);
    const header_end = try checkedEnd(offset, header_size, bytes.len);
    const fixed = try parseFixedHeader(bytes[offset..header_end], format);
    const name_end = try checkedEnd(header_end, fixed.name_size, bytes.len);
    const name = try parseName(bytes[header_end..name_end]);
    const data_offset = try alignedEnd(header_end, fixed.name_size, fixed.alignment, bytes.len);
    try requireZero(bytes[name_end..data_offset]);
    const data_end = try checkedEnd(data_offset, fixed.stored_size, bytes.len);
    const next_offset = try alignedEnd(
        data_offset,
        fixed.stored_size,
        fixed.alignment,
        bytes.len,
    );
    try requireZero(bytes[data_end..next_offset]);
    const is_trailer = try validateEntryHeader(fixed, name);
    return .{
        .entry = .{
            .name = name,
            .format = format,
            .kind = fixed.kind,
            .mode = fixed.mode,
            .inode = fixed.inode,
            .uid = fixed.uid,
            .gid = fixed.gid,
            .link_count = fixed.link_count,
            .mtime = fixed.mtime,
            .device_major = fixed.device_major,
            .device_minor = fixed.device_minor,
            .rdevice_major = fixed.rdevice_major,
            .rdevice_minor = fixed.rdevice_minor,
            .checksum = fixed.checksum,
            .stored_size = fixed.stored_size,
            .header_offset = offset,
            .header_size = fixed.header_size,
            .data_offset = data_offset,
            .next_offset = next_offset,
            .safe_path = isSafePath(name),
        },
        .is_trailer = is_trailer,
    };
}

pub fn fixedHeaderSize(format: Format) usize {
    return switch (format) {
        .newc, .crc => newc_header_size,
        .odc => odc_header_size,
        .binary_little, .binary_big => binary_header_size,
    };
}

pub fn parseFixedHeader(bytes: []const u8, format: Format) Error!FixedHeader {
    const header_size = fixedHeaderSize(format);
    if (bytes.len < header_size) return error.TruncatedFrame;
    const header = bytes[0..header_size];
    return switch (format) {
        .newc, .crc => parseNewAsciiFixed(header, format),
        .odc => parseOldAsciiFixed(header),
        .binary_little, .binary_big => parseBinaryFixed(header, format),
    };
}

fn parseNewAsciiFixed(header: []const u8, format: Format) Error!FixedHeader {
    const expected_magic = if (format == .crc) magic_crc else magic_newc;
    if (!std.mem.eql(u8, header[0..6], expected_magic)) return error.InvalidMagic;
    const stored_size_u32 = try parseAscii(u32, header[54..62], 16);
    const name_size_u32 = try parseAscii(u32, header[94..102], 16);
    const stored_checksum = try parseAscii(u32, header[102..110], 16);
    if (format == .newc and stored_checksum != 0) return error.InvalidCpioArchive;
    const mode = try parseAscii(u32, header[14..22], 16);
    return .{
        .format = format,
        .kind = kindFromMode(mode),
        .mode = mode,
        .inode = try parseAscii(u32, header[6..14], 16),
        .uid = try parseAscii(u32, header[22..30], 16),
        .gid = try parseAscii(u32, header[30..38], 16),
        .link_count = try parseAscii(u32, header[38..46], 16),
        .mtime = try parseAscii(u32, header[46..54], 16),
        .device_major = try parseAscii(u32, header[62..70], 16),
        .device_minor = try parseAscii(u32, header[70..78], 16),
        .rdevice_major = try parseAscii(u32, header[78..86], 16),
        .rdevice_minor = try parseAscii(u32, header[86..94], 16),
        .checksum = if (format == .crc) stored_checksum else null,
        .stored_size = std.math.cast(usize, stored_size_u32) orelse
            return error.IntegerOverflow,
        .name_size = std.math.cast(usize, name_size_u32) orelse
            return error.IntegerOverflow,
        .header_size = newc_header_size,
        .alignment = 4,
    };
}

fn parseOldAsciiFixed(header: []const u8) Error!FixedHeader {
    if (!std.mem.eql(u8, header[0..6], magic_odc)) return error.InvalidMagic;
    const mode = try parseAscii(u32, header[18..24], 8);
    const name_size_u32 = try parseAscii(u32, header[59..65], 8);
    const stored_size_u64 = try parseAscii(u64, header[65..76], 8);
    return .{
        .format = .odc,
        .kind = kindFromMode(mode),
        .mode = mode,
        .inode = try parseAscii(u32, header[12..18], 8),
        .uid = try parseAscii(u32, header[24..30], 8),
        .gid = try parseAscii(u32, header[30..36], 8),
        .link_count = try parseAscii(u32, header[36..42], 8),
        .mtime = try parseAscii(u32, header[48..59], 8),
        .device_major = 0,
        .device_minor = try parseAscii(u32, header[6..12], 8),
        .rdevice_major = 0,
        .rdevice_minor = try parseAscii(u32, header[42..48], 8),
        .checksum = null,
        .stored_size = std.math.cast(usize, stored_size_u64) orelse
            return error.IntegerOverflow,
        .name_size = std.math.cast(usize, name_size_u32) orelse
            return error.IntegerOverflow,
        .header_size = odc_header_size,
        .alignment = 1,
    };
}

fn parseBinaryFixed(header: []const u8, format: Format) Error!FixedHeader {
    const endian: std.builtin.Endian = if (format == .binary_little) .little else .big;
    if (std.mem.readInt(u16, header[0..2], endian) != binary_magic)
        return error.InvalidMagic;
    const mode: u32 = readBinary16(header, 6, endian);
    return .{
        .format = format,
        .kind = kindFromMode(mode),
        .mode = mode,
        .inode = readBinary16(header, 4, endian),
        .uid = readBinary16(header, 8, endian),
        .gid = readBinary16(header, 10, endian),
        .link_count = readBinary16(header, 12, endian),
        .mtime = readBinary32(header, 16, endian),
        .device_major = 0,
        .device_minor = readBinary16(header, 2, endian),
        .rdevice_major = 0,
        .rdevice_minor = readBinary16(header, 14, endian),
        .checksum = null,
        .stored_size = readBinary32(header, 22, endian),
        .name_size = readBinary16(header, 20, endian),
        .header_size = binary_header_size,
        .alignment = 2,
    };
}

pub fn validateEntryHeader(header: FixedHeader, name: []const u8) Error!bool {
    const is_trailer = std.mem.eql(u8, name, trailer_name);
    if (is_trailer) {
        if (header.stored_size != 0) return error.InvalidCpioArchive;
    } else {
        if (header.link_count == 0) return error.InvalidCpioArchive;
        switch (header.kind) {
            .directory, .block_device, .character_device, .fifo, .socket => if (header.stored_size != 0) return error.InvalidCpioArchive,
            else => {},
        }
    }
    return is_trailer;
}

pub fn detectFormat(bytes: []const u8, offset: usize) Error!Format {
    _ = try checkedEnd(offset, 2, bytes.len);
    if (std.mem.readInt(u16, bytes[offset..][0..2], .little) == binary_magic)
        return .binary_little;
    if (std.mem.readInt(u16, bytes[offset..][0..2], .big) == binary_magic)
        return .binary_big;
    const remaining = bytes.len - offset;
    if (remaining < 6) {
        const prefix = bytes[offset..];
        if (std.mem.eql(u8, prefix, magic_newc[0..remaining]) or
            std.mem.eql(u8, prefix, magic_crc[0..remaining]) or
            std.mem.eql(u8, prefix, magic_odc[0..remaining]))
        {
            return error.TruncatedFrame;
        }
        return error.InvalidMagic;
    }
    const magic = bytes[offset .. offset + 6];
    if (std.mem.eql(u8, magic, magic_newc)) return .newc;
    if (std.mem.eql(u8, magic, magic_crc)) return .crc;
    if (std.mem.eql(u8, magic, magic_odc)) return .odc;
    return error.InvalidMagic;
}

pub fn parseName(field: []const u8) Error![]const u8 {
    if (field.len < 2 or field[field.len - 1] != 0) return error.InvalidCpioArchive;
    const name = field[0 .. field.len - 1];
    if (std.mem.indexOfScalar(u8, name, 0) != null) return error.InvalidCpioArchive;
    return name;
}

fn parseAscii(comptime T: type, field: []const u8, radix: u8) Error!T {
    var value: u64 = 0;
    for (field) |byte| {
        const digit: u8 = if (byte >= '0' and byte <= '9')
            byte - '0'
        else if (radix == 16 and byte >= 'a' and byte <= 'f')
            byte - 'a' + 10
        else if (radix == 16 and byte >= 'A' and byte <= 'F')
            byte - 'A' + 10
        else
            return error.InvalidCpioArchive;
        if (digit >= radix) return error.InvalidCpioArchive;
        value = std.math.mul(u64, value, radix) catch return error.IntegerOverflow;
        value = std.math.add(u64, value, digit) catch return error.IntegerOverflow;
    }
    return std.math.cast(T, value) orelse error.IntegerOverflow;
}

pub fn kindFromMode(mode: u32) Kind {
    return switch (mode & mode_type_mask) {
        mode_regular => .regular,
        mode_directory => .directory,
        mode_symlink => .symlink,
        mode_block => .block_device,
        mode_character => .character_device,
        mode_fifo => .fifo,
        mode_socket => .socket,
        else => .unknown,
    };
}

pub fn isSafePath(path: []const u8) bool {
    if (path.len == 0 or path[0] == '/' or path[0] == '\\') return false;
    var component_start: usize = 0;
    for (path, 0..) |byte, index| {
        if (byte != '/' and byte != '\\') continue;
        if (!safeComponent(path[component_start..index])) return false;
        component_start = index + 1;
    }
    return safeComponent(path[component_start..]);
}

fn safeComponent(component: []const u8) bool {
    return component.len != 0 and !std.mem.eql(u8, component, ".") and
        !std.mem.eql(u8, component, "..");
}

fn readBinary16(bytes: []const u8, offset: usize, endian: std.builtin.Endian) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], endian);
}

fn readBinary32(bytes: []const u8, offset: usize, endian: std.builtin.Endian) u32 {
    const high = readBinary16(bytes, offset, endian);
    const low = readBinary16(bytes, offset + 2, endian);
    return (@as(u32, high) << 16) | low;
}

fn sameEntry(a: Entry, b: Entry) bool {
    return a.format == b.format and a.kind == b.kind and a.mode == b.mode and
        a.inode == b.inode and a.uid == b.uid and a.gid == b.gid and
        a.link_count == b.link_count and a.mtime == b.mtime and
        a.device_major == b.device_major and a.device_minor == b.device_minor and
        a.rdevice_major == b.rdevice_major and a.rdevice_minor == b.rdevice_minor and
        a.checksum == b.checksum and a.stored_size == b.stored_size and
        a.header_offset == b.header_offset and a.header_size == b.header_size and
        a.data_offset == b.data_offset and a.next_offset == b.next_offset and
        a.safe_path == b.safe_path and std.mem.eql(u8, a.name, b.name);
}

pub fn byteSum(bytes: []const u8) u32 {
    var sum: u32 = 0;
    for (bytes) |byte| sum +%= byte;
    return sum;
}

fn requireZero(bytes: []const u8) Error!void {
    for (bytes) |byte|
        if (byte != 0) return error.InvalidCpioArchive;
}

fn alignedEnd(start: usize, len: usize, alignment: usize, limit: usize) Error!usize {
    const end = try checkedEnd(start, len, limit);
    const padding = (alignment - end % alignment) % alignment;
    return checkedEnd(end, padding, limit);
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, len) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

pub const magic_newc = "070701";
pub const magic_crc = "070702";
pub const magic_odc = "070707";
pub const binary_magic: u16 = 0o70707;
pub const trailer_name = "TRAILER!!!";
pub const newc_header_size: usize = 110;
pub const odc_header_size: usize = 76;
pub const binary_header_size: usize = 26;
const minimum_header_size: usize = binary_header_size;

pub const mode_type_mask: u32 = 0o170000;
pub const mode_fifo: u32 = 0o010000;
pub const mode_character: u32 = 0o020000;
pub const mode_directory: u32 = 0o040000;
pub const mode_block: u32 = 0o060000;
pub const mode_regular: u32 = 0o100000;
pub const mode_symlink: u32 = 0o120000;
pub const mode_socket: u32 = 0o140000;

test "CPIO byte sum wraps at 32 bits" {
    try std.testing.expectEqual(@as(u32, 294), byteSum(&.{ 0xff, 39 }));
}

test "CPIO path safety rejects traversal and absolute paths" {
    try std.testing.expect(isSafePath("safe/path"));
    try std.testing.expect(!isSafePath("../escape"));
    try std.testing.expect(!isSafePath("safe/../escape"));
    try std.testing.expect(!isSafePath("/absolute"));
    try std.testing.expect(!isSafePath("safe//empty"));
}

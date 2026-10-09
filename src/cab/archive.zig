const std = @import("std");
const checksum = @import("checksum.zig");
const core = @import("../core.zig");
const types = @import("types.zig");

pub const Error = core.Error || error{
    InvalidCabinet,
    UnsupportedCabinetFeature,
    UnsupportedCabinetCompression,
    CabinetEntryNotFound,
    IncompleteCabinetSet,
    CabinetSetMismatch,
};

pub const Compression = types.Compression;
pub const Entry = types.Entry;
pub const Folder = types.Folder;
pub const DataBlock = types.DataBlock;
pub const Continuation = types.Continuation;

const fixed_header_len: usize = 36;
const folder_record_len: usize = 8;
const file_record_len: usize = 16;
const data_record_len: usize = 8;
const flag_prev_cabinet: u16 = 0x0001;
const flag_next_cabinet: u16 = 0x0002;
const flag_reserve_present: u16 = 0x0004;
const continued_from_previous: u16 = 0xfffd;
const continued_to_next: u16 = 0xfffe;
const continued_previous_and_next: u16 = 0xffff;
const max_folder_decoded_size: usize = 0x7fff_8000;

pub const Archive = struct {
    bytes: []const u8,
    folder_count: usize,
    file_count: usize,
    flags: u16,
    set_id: u16,
    cabinet_index: u16,
    folder_table_offset: usize,
    file_table_offset: usize,
    folder_reserve_size: usize,
    data_reserve_size: usize,
    previous_cabinet_name: ?[]const u8,
    previous_disk_name: ?[]const u8,
    next_cabinet_name: ?[]const u8,
    next_disk_name: ?[]const u8,

    pub fn hasPrevious(self: Archive) bool {
        return self.flags & flag_prev_cabinet != 0;
    }

    pub fn hasNext(self: Archive) bool {
        return self.flags & flag_next_cabinet != 0;
    }

    pub fn iterator(self: Archive) Iterator {
        return .{
            .archive = self,
            .offset = self.file_table_offset,
            .remaining = self.file_count,
        };
    }

    pub fn entryAt(self: Archive, index: usize) Error!Entry {
        if (index >= self.file_count) return error.RangeOutOfBounds;
        var iterator_value = self.iterator();
        var current: usize = 0;
        while (try iterator_value.next()) |entry| : (current += 1)
            if (current == index) return entry;
        return error.InvalidCabinet;
    }

    pub fn find(self: Archive, name: []const u8) Error!?Entry {
        var iterator_value = self.iterator();
        while (try iterator_value.next()) |entry|
            if (std.mem.eql(u8, entry.name, name)) return entry;
        return null;
    }

    pub fn entriesAlloc(self: Archive, allocator: std.mem.Allocator) ![]Entry {
        const entries = try allocator.alloc(Entry, self.file_count);
        errdefer allocator.free(entries);
        var iterator_value = self.iterator();
        var index: usize = 0;
        while (try iterator_value.next()) |entry| : (index += 1) entries[index] = entry;
        if (index != entries.len) return error.InvalidCabinet;
        return entries;
    }

    pub fn folderAt(self: Archive, index: usize) Error!Folder {
        if (index >= self.folder_count) return error.RangeOutOfBounds;
        const stride = folder_record_len + self.folder_reserve_size;
        const offset = try checkedAdd(self.folder_table_offset, try checkedMul(index, stride));
        _ = try checkedEnd(offset, stride, self.file_table_offset);
        const data_offset = try u32ToUsize(try readU32(self.bytes, offset));
        const block_count: usize = try readU16(self.bytes, offset + 4);
        const type_compress = try readU16(self.bytes, offset + 6);
        const compression: Compression = @enumFromInt(@as(u4, @truncate(type_compress)));

        var blocks = DataBlockIterator{
            .archive = self,
            .offset = data_offset,
            .remaining = block_count,
        };
        var decoded_size: usize = 0;
        var block_index: usize = 0;
        while (try blocks.next()) |block| : (block_index += 1) {
            decoded_size = try checkedAdd(decoded_size, block.uncompressed_size);
            if (decoded_size > max_folder_decoded_size) return error.InvalidCabinet;
            if (block.uncompressed_size == 0 and
                (blocks.remaining != 0 or !self.hasNext() or index + 1 != self.folder_count))
                return error.InvalidCabinet;
            if (compression == .none and
                block.uncompressed_size != 0 and
                block.compressed.len != block.uncompressed_size and
                !(self.hasPrevious() and index == 0 and block_index == 0 and
                    block.compressed.len < block.uncompressed_size))
                return error.InvalidCabinet;
        }
        return .{
            .data_offset = data_offset,
            .data_block_count = block_count,
            .compression = compression,
            .type_compress = type_compress,
            .decoded_size = decoded_size,
            .data_end = blocks.offset,
            .index = index,
        };
    }

    pub fn dataBlockIterator(self: Archive, folder: Folder) DataBlockIterator {
        return .{
            .archive = self,
            .offset = folder.data_offset,
            .remaining = folder.data_block_count,
        };
    }

    pub fn canonicalEntry(self: Archive, supplied: Entry) Error!Entry {
        if (supplied.record_offset < self.file_table_offset) return error.InvalidCabinet;
        var iterator_value = self.iterator();
        while (try iterator_value.next()) |entry| {
            if (entry.record_offset != supplied.record_offset) continue;
            if (!entryEqual(entry, supplied)) return error.InvalidCabinet;
            return entry;
        }
        return error.InvalidCabinet;
    }
};

pub const Iterator = struct {
    archive: Archive,
    offset: usize,
    remaining: usize,

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.remaining == 0) return null;
        const parsed = try parseEntryAt(self.archive, self.offset);
        self.offset = parsed.next_offset;
        self.remaining -= 1;
        return parsed.entry;
    }
};

pub const DataBlockIterator = struct {
    archive: Archive,
    offset: usize,
    remaining: usize,

    pub fn next(self: *DataBlockIterator) Error!?DataBlock {
        if (self.remaining == 0) return null;
        const header_end = try checkedEnd(self.offset, data_record_len, self.archive.bytes.len);
        const expected_checksum = try readU32(self.archive.bytes, self.offset);
        const compressed_size: usize = try readU16(self.archive.bytes, self.offset + 4);
        const uncompressed_size: usize = try readU16(self.archive.bytes, self.offset + 6);
        if (uncompressed_size > 32 * 1024) return error.UnsupportedCabinetFeature;
        const reserve_end = try checkedEnd(header_end, self.archive.data_reserve_size, self.archive.bytes.len);
        const data_end = try checkedEnd(reserve_end, compressed_size, self.archive.bytes.len);
        if (expected_checksum != 0) {
            const actual_checksum =
                checksum.compute(self.archive.bytes[self.offset + 4 .. header_end]) ^
                checksum.compute(self.archive.bytes[reserve_end..data_end]);
            if (actual_checksum != expected_checksum) return error.ChecksumMismatch;
        }
        const result = DataBlock{
            .checksum = expected_checksum,
            .compressed = self.archive.bytes[reserve_end..data_end],
            .reserve = self.archive.bytes[header_end..reserve_end],
            .uncompressed_size = uncompressed_size,
            .record_offset = self.offset,
            .next_offset = data_end,
        };
        self.offset = data_end;
        self.remaining -= 1;
        return result;
    }
};

const ParsedEntry = struct { entry: Entry, next_offset: usize };

pub fn parse(bytes: []const u8) Error!Archive {
    if (bytes.len < fixed_header_len or !std.mem.eql(u8, bytes[0..4], "MSCF"))
        return error.InvalidMagic;
    if (try readU32(bytes, 4) != 0 or try readU32(bytes, 12) != 0 or try readU32(bytes, 20) != 0)
        return error.InvalidCabinet;
    const cabinet_size = try u32ToUsize(try readU32(bytes, 8));
    if (cabinet_size != bytes.len) return error.SizeMismatch;
    const file_table_offset = try u32ToUsize(try readU32(bytes, 16));
    if (bytes[24] != 3 or bytes[25] != 1) return error.UnsupportedVersion;
    const folder_count: usize = try readU16(bytes, 26);
    const file_count: usize = try readU16(bytes, 28);
    const flags = try readU16(bytes, 30);
    if (flags & ~(flag_prev_cabinet | flag_next_cabinet | flag_reserve_present) != 0)
        return error.InvalidCabinet;
    const cabinet_index = try readU16(bytes, 34);

    var folder_table_offset = fixed_header_len;
    var folder_reserve_size: usize = 0;
    var data_reserve_size: usize = 0;
    if (flags & flag_reserve_present != 0) {
        _ = try checkedEnd(folder_table_offset, 4, bytes.len);
        const header_reserve_size: usize = try readU16(bytes, folder_table_offset);
        folder_reserve_size = bytes[folder_table_offset + 2];
        data_reserve_size = bytes[folder_table_offset + 3];
        folder_table_offset = try checkedEnd(folder_table_offset + 4, header_reserve_size, bytes.len);
    }
    var previous_cabinet_name: ?[]const u8 = null;
    var previous_disk_name: ?[]const u8 = null;
    var next_cabinet_name: ?[]const u8 = null;
    var next_disk_name: ?[]const u8 = null;
    if (flags & flag_prev_cabinet != 0) {
        previous_cabinet_name = try readHeaderString(bytes, &folder_table_offset);
        previous_disk_name = try readHeaderString(bytes, &folder_table_offset);
    }
    if (flags & flag_next_cabinet != 0) {
        next_cabinet_name = try readHeaderString(bytes, &folder_table_offset);
        next_disk_name = try readHeaderString(bytes, &folder_table_offset);
    }
    const folders_len = try checkedMul(folder_count, folder_record_len + folder_reserve_size);
    const folder_table_end = try checkedEnd(folder_table_offset, folders_len, bytes.len);
    if (file_table_offset < folder_table_end or file_table_offset > bytes.len)
        return error.InvalidCabinet;

    var result = Archive{
        .bytes = bytes,
        .folder_count = folder_count,
        .file_count = file_count,
        .flags = flags,
        .set_id = try readU16(bytes, 32),
        .cabinet_index = cabinet_index,
        .folder_table_offset = folder_table_offset,
        .file_table_offset = file_table_offset,
        .folder_reserve_size = folder_reserve_size,
        .data_reserve_size = data_reserve_size,
        .previous_cabinet_name = previous_cabinet_name,
        .previous_disk_name = previous_disk_name,
        .next_cabinet_name = next_cabinet_name,
        .next_disk_name = next_disk_name,
    };

    var iterator_value = result.iterator();
    var files_end = file_table_offset;
    var previous_folder: usize = 0;
    var previous_offset: usize = 0;
    var file_index: usize = 0;
    while (try iterator_value.next()) |entry| : (file_index += 1) {
        if (file_index != 0 and
            (entry.folder_index < previous_folder or
                (entry.folder_index == previous_folder and entry.folder_offset < previous_offset)))
            return error.InvalidCabinet;
        previous_folder = entry.folder_index;
        previous_offset = entry.folder_offset;
        files_end = iterator_value.offset;
    }
    if (file_index != file_count) return error.InvalidCabinet;

    var previous_data_end = files_end;
    for (0..folder_count) |folder_index| {
        const folder_stride = folder_record_len + result.folder_reserve_size;
        const folder_record = try checkedAdd(
            result.folder_table_offset,
            try checkedMul(folder_index, folder_stride),
        );
        const declared_data_offset = try u32ToUsize(try readU32(bytes, folder_record));
        if (declared_data_offset < previous_data_end) return error.InvalidCabinet;
        const folder = try result.folderAt(folder_index);
        previous_data_end = folder.data_end;
    }
    var verify_entries = result.iterator();
    while (try verify_entries.next()) |entry| {
        if (entry.continuation == .none) {
            const folder = try result.folderAt(entry.folder_index);
            if (entry.size > folder.decoded_size -| entry.folder_offset or
                entry.folder_offset > folder.decoded_size)
                return error.InvalidCabinet;
        }
    }
    return result;
}

fn parseEntryAt(archive: Archive, offset: usize) Error!ParsedEntry {
    const fixed_end = try checkedEnd(offset, file_record_len, archive.bytes.len);
    const size = try u32ToUsize(try readU32(archive.bytes, offset));
    const folder_offset = try u32ToUsize(try readU32(archive.bytes, offset + 4));
    const raw_folder = try readU16(archive.bytes, offset + 8);
    const continuation: Continuation = switch (raw_folder) {
        continued_from_previous => .from_previous,
        continued_to_next => .to_next,
        continued_previous_and_next => .from_previous_and_next,
        else => .none,
    };
    if (archive.folder_count == 0 and continuation != .none) return error.InvalidCabinet;
    const folder_index: usize = switch (continuation) {
        .none => raw_folder,
        .from_previous => 0,
        .to_next => archive.folder_count - 1,
        .from_previous_and_next => blk: {
            if (archive.folder_count != 1) return error.InvalidCabinet;
            break :blk 0;
        },
    };
    if (folder_index >= archive.folder_count) return error.InvalidCabinet;
    if (continuation.startsBefore() and !archive.hasPrevious()) return error.InvalidCabinet;
    if (continuation.continuesAfter() and !archive.hasNext()) return error.InvalidCabinet;
    const name_limit = @min(archive.bytes.len, try checkedAdd(fixed_end, 257));
    const relative_end = std.mem.indexOfScalar(u8, archive.bytes[fixed_end..name_limit], 0) orelse
        return error.InvalidCabinet;
    if (relative_end == 0 or relative_end > 256) return error.InvalidCabinet;
    const name = archive.bytes[fixed_end .. fixed_end + relative_end];
    const attributes = try readU16(archive.bytes, offset + 14);
    if (attributes & 0x0080 != 0 and !std.unicode.utf8ValidateSlice(name))
        return error.InvalidCabinet;
    return .{
        .entry = .{
            .name = name,
            .size = size,
            .folder_offset = folder_offset,
            .folder_index = folder_index,
            .date = try readU16(archive.bytes, offset + 10),
            .time = try readU16(archive.bytes, offset + 12),
            .attributes = attributes,
            .record_offset = offset,
            .continuation = continuation,
        },
        .next_offset = fixed_end + relative_end + 1,
    };
}

fn entryEqual(a: Entry, b: Entry) bool {
    return a.size == b.size and
        a.folder_offset == b.folder_offset and
        a.folder_index == b.folder_index and
        a.date == b.date and
        a.time == b.time and
        a.attributes == b.attributes and
        a.record_offset == b.record_offset and
        a.continuation == b.continuation and
        std.mem.eql(u8, a.name, b.name);
}

fn readHeaderString(bytes: []const u8, offset: *usize) Error![]const u8 {
    const limit = @min(bytes.len, try checkedAdd(offset.*, 257));
    const relative_end = std.mem.indexOfScalar(u8, bytes[offset.*..limit], 0) orelse
        return error.InvalidCabinet;
    if (relative_end == 0 or relative_end > 256) return error.InvalidCabinet;
    const value = bytes[offset.* .. offset.* + relative_end];
    offset.* += relative_end + 1;
    return value;
}

fn readU16(bytes: []const u8, offset: usize) Error!u16 {
    _ = try checkedEnd(offset, 2, bytes.len);
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) Error!u32 {
    _ = try checkedEnd(offset, 4, bytes.len);
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn u32ToUsize(value: u32) Error!usize {
    return std.math.cast(usize, value) orelse error.IntegerOverflow;
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch return error.IntegerOverflow;
}

fn checkedMul(a: usize, b: usize) Error!usize {
    return std.math.mul(usize, a, b) catch return error.IntegerOverflow;
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = try checkedAdd(start, len);
    if (end > limit) return error.TruncatedFrame;
    return end;
}

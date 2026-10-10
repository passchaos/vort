const std = @import("std");
const core = @import("../core.zig");
const codec = @import("codec.zig");
const format = @import("format.zig");
const metadata = @import("metadata.zig");

pub const Error = core.Error || codec.Error || format.Error || metadata.Error ||
    std.mem.Allocator.Error || error{
    InvalidSquashfs,
    SquashfsEntryNotFound,
    SquashfsNotDirectory,
    SquashfsNotRegularFile,
};

pub const Inode = struct {
    allocator: std.mem.Allocator,
    reference: u64,
    kind: format.InodeKind,
    mode: u16,
    uid_index: u16,
    gid_index: u16,
    modification_time: u32,
    inode_number: u32,
    file_size: usize = 0,
    data_start: usize = 0,
    fragment: u32 = format.invalid_fragment,
    fragment_offset: u32 = 0,
    block_sizes: ?[]u32 = null,
    directory_start: u32 = 0,
    directory_offset: u16 = 0,
    directory_size: usize = 0,
    symlink: ?[]u8 = null,

    pub fn deinit(self: *Inode) void {
        if (self.block_sizes) |sizes| self.allocator.free(sizes);
        if (self.symlink) |target| self.allocator.free(target);
        self.* = undefined;
    }
};

pub const DirectoryEntry = struct {
    name: []const u8,
    inode_reference: u64,
    inode_number: u32,
    kind: format.InodeKind,
};

pub const Directory = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    entries: []DirectoryEntry,

    pub fn deinit(self: *Directory) void {
        self.allocator.free(self.entries);
        self.allocator.free(self.bytes);
        self.* = undefined;
    }

    pub fn find(self: Directory, name: []const u8) ?DirectoryEntry {
        for (self.entries) |entry|
            if (std.mem.eql(u8, entry.name, name)) return entry;
        return null;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    superblock: format.Superblock,

    pub fn init(bytes: []const u8) Error!Archive {
        return .{ .bytes = bytes, .superblock = try format.parseSuperblock(bytes) };
    }

    pub fn rootInodeAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        max_file_size: usize,
    ) Error!Inode {
        return self.readInodeAlloc(
            allocator,
            self.superblock.root_inode,
            max_file_size,
        );
    }

    pub fn readInodeAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        reference: u64,
        max_file_size: usize,
    ) Error!Inode {
        const block: usize = @intCast(reference >> 16);
        const offset: usize = @as(u16, @truncate(reference));
        const base = try metadata.readReferenceAlloc(
            allocator,
            self.bytes,
            self.superblock,
            self.superblock.inode_table_start,
            block,
            offset,
            16,
        );
        defer allocator.free(base);
        const kind = std.enums.fromInt(format.InodeKind, format.readU16(base, 0)) orelse
            return error.InvalidSquashfs;
        const uid = format.readU16(base, 4);
        const gid = format.readU16(base, 6);
        const inode_number = format.readU32(base, 12);
        if (uid >= self.superblock.id_count or gid >= self.superblock.id_count or
            inode_number == 0 or inode_number > self.superblock.inode_count)
            return error.InvalidSquashfs;
        var inode = Inode{
            .allocator = allocator,
            .reference = reference,
            .kind = kind,
            .mode = format.readU16(base, 2),
            .uid_index = uid,
            .gid_index = gid,
            .modification_time = format.readU32(base, 8),
            .inode_number = inode_number,
        };
        errdefer inode.deinit();
        switch (kind) {
            .regular => {
                const header = try self.readInodeBytesAlloc(allocator, block, offset, 32);
                defer allocator.free(header);
                inode.data_start = format.readU32(header, 16);
                inode.fragment = format.readU32(header, 20);
                inode.fragment_offset = format.readU32(header, 24);
                inode.file_size = format.readU32(header, 28);
                try self.readBlockList(allocator, block, offset, 32, &inode, max_file_size);
            },
            .long_regular => {
                const header = try self.readInodeBytesAlloc(allocator, block, offset, 56);
                defer allocator.free(header);
                inode.data_start = std.math.cast(usize, format.readU64(header, 16)) orelse
                    return error.IntegerOverflow;
                inode.file_size = std.math.cast(usize, format.readU64(header, 24)) orelse
                    return error.IntegerOverflow;
                inode.fragment = format.readU32(header, 44);
                inode.fragment_offset = format.readU32(header, 48);
                try self.readBlockList(allocator, block, offset, 56, &inode, max_file_size);
            },
            .directory => {
                const header = try self.readInodeBytesAlloc(allocator, block, offset, 32);
                defer allocator.free(header);
                inode.directory_start = format.readU32(header, 16);
                inode.directory_size = format.readU16(header, 24);
                inode.directory_offset = format.readU16(header, 26);
            },
            .long_directory => {
                const header = try self.readInodeBytesAlloc(allocator, block, offset, 40);
                defer allocator.free(header);
                inode.directory_size = format.readU32(header, 20);
                inode.directory_start = format.readU32(header, 24);
                inode.directory_offset = format.readU16(header, 34);
            },
            .symlink, .long_symlink => {
                const header = try self.readInodeBytesAlloc(allocator, block, offset, 24);
                defer allocator.free(header);
                const size: usize = format.readU32(header, 20);
                if (size > 65_535 or size > max_file_size) return error.OutputLimitExceeded;
                const total = std.math.add(usize, 24, size) catch return error.IntegerOverflow;
                const bytes = try self.readInodeBytesAlloc(allocator, block, offset, total);
                defer allocator.free(bytes);
                inode.symlink = try allocator.dupe(u8, bytes[24..]);
                inode.file_size = size;
            },
            else => {},
        }
        return inode;
    }

    fn readInodeBytesAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        block: usize,
        offset: usize,
        length: usize,
    ) Error![]u8 {
        return metadata.readReferenceAlloc(
            allocator,
            self.bytes,
            self.superblock,
            self.superblock.inode_table_start,
            block,
            offset,
            length,
        );
    }

    fn readBlockList(
        self: Archive,
        allocator: std.mem.Allocator,
        block: usize,
        offset: usize,
        header_size: usize,
        inode: *Inode,
        max_file_size: usize,
    ) Error!void {
        if (inode.file_size > max_file_size) return error.OutputLimitExceeded;
        const full_blocks = inode.file_size >> @intCast(self.superblock.block_log);
        const has_tail_block = inode.fragment == format.invalid_fragment and
            inode.file_size & (self.superblock.block_size - 1) != 0;
        const block_count = full_blocks + @intFromBool(has_tail_block);
        if (block_count > self.superblock.bytes_used / 4) return error.InvalidSquashfs;
        const list_bytes = std.math.mul(usize, block_count, 4) catch
            return error.IntegerOverflow;
        const total = std.math.add(usize, header_size, list_bytes) catch
            return error.IntegerOverflow;
        const bytes = try self.readInodeBytesAlloc(allocator, block, offset, total);
        defer allocator.free(bytes);
        const sizes = try allocator.alloc(u32, block_count);
        errdefer allocator.free(sizes);
        for (sizes, 0..) |*size, index|
            size.* = format.readU32(bytes, header_size + index * 4);
        inode.block_sizes = sizes;
    }

    pub fn readDirectoryAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        inode: Inode,
        max_directory_bytes: usize,
    ) Error!Directory {
        if (inode.kind != .directory and inode.kind != .long_directory)
            return error.SquashfsNotDirectory;
        if (inode.directory_size < 3) return error.InvalidSquashfs;
        const size = inode.directory_size - 3;
        if (size > max_directory_bytes) return error.OutputLimitExceeded;
        const bytes = try metadata.readReferenceAlloc(
            allocator,
            self.bytes,
            self.superblock,
            self.superblock.directory_table_start,
            inode.directory_start,
            inode.directory_offset,
            size,
        );
        errdefer allocator.free(bytes);
        var entries: std.ArrayList(DirectoryEntry) = .empty;
        errdefer entries.deinit(allocator);
        var position: usize = 0;
        var previous_name: ?[]const u8 = null;
        while (position < bytes.len) {
            if (bytes.len - position < 12) return error.TruncatedFrame;
            const count: usize = @as(usize, format.readU32(bytes, position)) + 1;
            if (count > 256) return error.InvalidSquashfs;
            const inode_block = format.readU32(bytes, position + 4);
            const base_inode = format.readU32(bytes, position + 8);
            position += 12;
            for (0..count) |_| {
                if (bytes.len - position < 8) return error.TruncatedFrame;
                const inode_offset = format.readU16(bytes, position);
                const inode_delta = format.readI16(bytes, position + 2);
                const kind = std.enums.fromInt(
                    format.InodeKind,
                    format.readU16(bytes, position + 4),
                ) orelse return error.InvalidSquashfs;
                const name_len: usize = @as(usize, format.readU16(bytes, position + 6)) + 1;
                position += 8;
                if (name_len == 0 or name_len > 256 or bytes.len - position < name_len)
                    return error.InvalidSquashfs;
                const name = bytes[position..][0..name_len];
                if (!validName(name)) return error.InvalidSquashfs;
                if (previous_name) |previous|
                    if (std.mem.order(u8, previous, name) != .lt) return error.InvalidSquashfs;
                previous_name = name;
                const number_i64 = @as(i64, base_inode) + inode_delta;
                if (number_i64 <= 0 or number_i64 > self.superblock.inode_count)
                    return error.InvalidSquashfs;
                try entries.append(allocator, .{
                    .name = name,
                    .inode_reference = format.inodeReference(inode_block, inode_offset),
                    .inode_number = @intCast(number_i64),
                    .kind = kind,
                });
                position += name_len;
            }
        }
        return .{
            .allocator = allocator,
            .bytes = bytes,
            .entries = try entries.toOwnedSlice(allocator),
        };
    }

    pub fn lookupAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        path: []const u8,
        max_file_size: usize,
        max_directory_bytes: usize,
    ) Error!Inode {
        var current = try self.rootInodeAlloc(allocator, max_file_size);
        errdefer current.deinit();
        var components = std.mem.tokenizeScalar(u8, path, '/');
        while (components.next()) |component| {
            if (!validName(component)) return error.InvalidSquashfs;
            var directory = try self.readDirectoryAlloc(
                allocator,
                current,
                max_directory_bytes,
            );
            defer directory.deinit();
            const entry = directory.find(component) orelse return error.SquashfsEntryNotFound;
            const next = try self.readInodeAlloc(allocator, entry.inode_reference, max_file_size);
            current.deinit();
            current = next;
        }
        return current;
    }

    pub fn extractByPathAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        path: []const u8,
        max_output_len: usize,
        max_directory_bytes: usize,
    ) Error![]u8 {
        var inode = try self.lookupAlloc(
            allocator,
            path,
            max_output_len,
            max_directory_bytes,
        );
        defer inode.deinit();
        if (inode.kind == .symlink or inode.kind == .long_symlink)
            return allocator.dupe(u8, inode.symlink.?);
        if (inode.kind != .regular and inode.kind != .long_regular)
            return error.SquashfsNotRegularFile;
        return self.extractRegularAlloc(allocator, inode, max_output_len);
    }

    fn extractRegularAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        inode: Inode,
        max_output_len: usize,
    ) Error![]u8 {
        if (inode.file_size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, inode.file_size);
        errdefer allocator.free(output);
        var output_offset: usize = 0;
        var data_position = inode.data_start;
        const sizes = inode.block_sizes orelse return error.InvalidSquashfs;
        for (sizes) |size_field| {
            const expected = @min(self.superblock.block_size, inode.file_size - output_offset);
            if (size_field == 0) {
                @memset(output[output_offset..][0..expected], 0);
            } else {
                if (size_field & 0xfe00_0000 != 0) return error.InvalidSquashfs;
                const stored_size: usize = size_field & 0x00ff_ffff;
                const compressed = size_field & 0x0100_0000 == 0;
                if (stored_size == 0 or stored_size > self.superblock.block_size)
                    return error.InvalidSquashfs;
                const end = try checkedEnd(data_position, stored_size, self.superblock.bytes_used);
                if (compressed) {
                    const decoded = try codec.decodeAllocExact(
                        allocator,
                        self.superblock.compression,
                        self.bytes[data_position..end],
                        expected,
                    );
                    defer allocator.free(decoded);
                    @memcpy(output[output_offset..][0..expected], decoded);
                } else {
                    if (stored_size != expected) return error.SizeMismatch;
                    @memcpy(output[output_offset..][0..expected], self.bytes[data_position..end]);
                }
                data_position = end;
            }
            output_offset += expected;
        }
        if (inode.fragment != format.invalid_fragment) {
            const fragment_bytes = inode.file_size & (self.superblock.block_size - 1);
            if (fragment_bytes == 0) return error.InvalidSquashfs;
            const fragment = try self.fragmentEntry(allocator, inode.fragment);
            const decoded = try self.decodeDataBlockLimited(
                allocator,
                fragment.start,
                fragment.size_field,
                self.superblock.block_size,
            );
            defer allocator.free(decoded);
            const fragment_start: usize = inode.fragment_offset;
            const fragment_end = try checkedEnd(fragment_start, fragment_bytes, decoded.len);
            @memcpy(output[output_offset..], decoded[fragment_start..fragment_end]);
            output_offset += fragment_bytes;
        }
        if (output_offset != output.len) return error.SizeMismatch;
        return output;
    }

    const FragmentEntry = struct {
        start: usize,
        size_field: u32,
    };

    fn fragmentEntry(
        self: Archive,
        allocator: std.mem.Allocator,
        index: u32,
    ) Error!FragmentEntry {
        if (index >= self.superblock.fragment_count or
            self.superblock.fragment_table_start == format.invalid_table)
            return error.InvalidSquashfs;
        const byte_offset = std.math.mul(usize, index, 16) catch
            return error.IntegerOverflow;
        const pointer_index = byte_offset / format.metadata_size;
        const entry_offset = byte_offset % format.metadata_size;
        const pointer_table = std.math.cast(
            usize,
            self.superblock.fragment_table_start,
        ) orelse return error.IntegerOverflow;
        const pointer_offset = std.math.add(
            usize,
            pointer_table,
            pointer_index * 8,
        ) catch return error.IntegerOverflow;
        if (self.superblock.bytes_used -| pointer_offset < 8) return error.TruncatedFrame;
        const metadata_position = std.math.cast(
            usize,
            format.readU64(self.bytes, pointer_offset),
        ) orelse return error.IntegerOverflow;
        const block = try metadata.decodeBlockAt(
            allocator,
            self.bytes,
            self.superblock,
            metadata_position,
        );
        defer allocator.free(block.bytes);
        if (block.bytes.len -| entry_offset < 16) return error.TruncatedFrame;
        return .{
            .start = std.math.cast(
                usize,
                format.readU64(block.bytes, entry_offset),
            ) orelse return error.IntegerOverflow,
            .size_field = format.readU32(block.bytes, entry_offset + 8),
        };
    }

    fn decodeDataBlockLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        position: usize,
        size_field: u32,
        max_output_len: usize,
    ) Error![]u8 {
        const stored_size: usize = size_field & 0x00ff_ffff;
        const compressed = size_field & 0x0100_0000 == 0;
        if (size_field & 0xfe00_0000 != 0) return error.InvalidSquashfs;
        if (stored_size == 0 or stored_size > self.superblock.block_size)
            return error.InvalidSquashfs;
        const end = try checkedEnd(position, stored_size, self.superblock.bytes_used);
        if (!compressed) return allocator.dupe(u8, self.bytes[position..end]);
        return codec.decodeAllocLimited(
            allocator,
            self.superblock.compression,
            self.bytes[position..end],
            max_output_len,
        );
    }
};

fn validName(name: []const u8) bool {
    if (name.len == 0 or std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, ".."))
        return false;
    return std.mem.indexOfScalar(u8, name, '/') == null and
        std.mem.indexOfScalar(u8, name, 0) == null;
}

fn checkedEnd(start: usize, length: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, length) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

fn fixtureAlloc(allocator: std.mem.Allocator, encoded_base64: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(
        u8,
        decoder.calcSizeUpperBound(encoded_base64.len),
    );
    errdefer allocator.free(bytes);
    const written = try decoder.decode(bytes, encoded_base64);
    return allocator.realloc(bytes, written);
}

test "SquashFS gzip fixture lists blocks fragments nesting and symlink" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/gzip-tree.sqfs.b64"),
    );
    defer allocator.free(bytes);
    const archive = try Archive.init(bytes);
    try std.testing.expectEqual(format.Compression.gzip, archive.superblock.compression);
    try std.testing.expectEqual(@as(u32, 6), archive.superblock.inode_count);
    var root = try archive.rootInodeAlloc(allocator, 400_000);
    defer root.deinit();
    var directory = try archive.readDirectoryAlloc(allocator, root, 1024 * 1024);
    defer directory.deinit();
    try std.testing.expectEqual(@as(usize, 4), directory.entries.len);

    const small = try archive.extractByPathAllocLimited(
        allocator,
        "small.txt",
        1024,
        1024 * 1024,
    );
    defer allocator.free(small);
    try std.testing.expectEqualSlices(u8, "small fragment payload\n", small);
    const nested = try archive.extractByPathAllocLimited(
        allocator,
        "nested/data.txt",
        1024,
        1024 * 1024,
    );
    defer allocator.free(nested);
    try std.testing.expectEqualSlices(u8, "nested squashfs payload\n", nested);
    const link = try archive.extractByPathAllocLimited(
        allocator,
        "link",
        1024,
        1024 * 1024,
    );
    defer allocator.free(link);
    try std.testing.expectEqualSlices(u8, "nested/data.txt", link);
    const large = try archive.extractByPathAllocLimited(
        allocator,
        "large.bin",
        400_000,
        1024 * 1024,
    );
    defer allocator.free(large);
    try std.testing.expectEqual(@as(usize, 350_000), large.len);
    const pattern = "large squashfs block payload 0123456789\n";
    for (large, 0..) |byte, index|
        try std.testing.expectEqual(pattern[index % pattern.len], byte);
}

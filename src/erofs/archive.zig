const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const codec = @import("codec.zig");
const xattr = @import("xattr.zig");

pub const Error = core.Error || format.Error || codec.Error || xattr.Error || std.mem.Allocator.Error || error{
    InvalidErofs,
    ErofsEntryNotFound,
    ErofsNotDirectory,
    ErofsNotRegularFile,
};

pub const Xattr = xattr.Attribute;
pub const Xattrs = xattr.Attributes;
pub const default_packed_extent_limit: usize = 8 * 1024 * 1024;

pub const ReadLimits = struct {
    max_output_len: usize,
    max_packed_extent_len: usize = default_packed_extent_limit,
};

pub const Inode = struct {
    nid: u64,
    location: usize,
    inode_size: usize,
    xattr_size: usize,
    layout: format.Layout,
    mode: u16,
    uid: u32,
    gid: u32,
    link_count: u32,
    file_size: usize,
    modification_time: u64,
    modification_nsec: u32,
    data_block: u64,
    compressed_algorithms: [2]?format.Compression = .{ null, null },
    compressed_cluster_bits: u8 = 0,
    compressed_advise: u16 = 0,
    compressed_header_start: usize = 0,
    compressed_index_start: usize = 0,
    compressed_inline_start: usize = 0,
    compressed_inline_size: usize = 0,
    compressed_inline_logical_start: usize = 0,
    compressed_inline_kind: u2 = 0,
    fragment_offset: ?u64 = null,
    fragment_logical_start: usize = 0,

    pub fn fileType(self: Inode) Error!format.FileType {
        return switch (self.mode & 0xf000) {
            0x8000 => .regular,
            0x4000 => .directory,
            0xa000 => .symlink,
            0x2000 => .character_device,
            0x6000 => .block_device,
            0x1000 => .fifo,
            0xc000 => .socket,
            else => error.InvalidErofs,
        };
    }
};

pub const DirectoryEntry = struct {
    nid: u64,
    name: []const u8,
    file_type: format.FileType,
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
        const superblock = try format.parseSuperblock(bytes);
        try xattr.validatePrefixTable(
            bytes,
            superblock.xattr_prefix_start,
            superblock.xattr_prefix_count,
        );
        return .{ .bytes = bytes, .superblock = superblock };
    }

    pub fn rootInode(self: Archive) Error!Inode {
        return self.inode(self.superblock.root_nid);
    }

    pub fn inode(self: Archive, nid: u64) Error!Inode {
        if (nid >> 63 != 0)
            return error.InvalidErofs;
        const metadata_start = std.math.mul(
            usize,
            self.superblock.meta_block,
            self.superblock.block_size,
        ) catch return error.IntegerOverflow;
        const slot_offset = std.math.mul(usize, @intCast(nid), format.inode_slot_size) catch
            return error.IntegerOverflow;
        const location = std.math.add(usize, metadata_start, slot_offset) catch
            return error.IntegerOverflow;
        if (self.bytes.len -| location < 32) return error.TruncatedFrame;
        const compact = self.bytes[location..];
        const inode_format = format.readU16(compact, 0);
        if (inode_format & ~@as(u16, 0x1f) != 0) return error.UnsupportedErofsFeature;
        const version = inode_format & 1;
        const layout_raw: u3 = @truncate((inode_format >> 1) & 7);
        const layout = std.enums.fromInt(format.Layout, layout_raw) orelse
            return error.UnsupportedErofsLayout;
        const inode_size: usize = if (version == 0) 32 else 64;
        if (self.bytes.len - location < inode_size) return error.TruncatedFrame;
        const inode_bytes = self.bytes[location..][0..inode_size];
        const xattr_count = format.readU16(inode_bytes, 2);
        const xattr_size: usize = if (xattr_count == 0)
            0
        else
            std.math.add(
                usize,
                12,
                std.math.mul(usize, xattr_count - 1, 4) catch
                    return error.IntegerOverflow,
            ) catch return error.IntegerOverflow;
        const mode = format.readU16(inode_bytes, 4);
        const file_size = if (version == 0)
            @as(usize, format.readU32(inode_bytes, 8))
        else
            std.math.cast(usize, format.readU64(inode_bytes, 8)) orelse
                return error.IntegerOverflow;
        const data_block: u64 = format.readU32(inode_bytes, 16);
        const uid = if (version == 0)
            @as(u32, format.readU16(inode_bytes, 24))
        else
            format.readU32(inode_bytes, 24);
        const gid = if (version == 0)
            @as(u32, format.readU16(inode_bytes, 26))
        else
            format.readU32(inode_bytes, 28);
        const modification_time = if (version == 0)
            std.math.add(u64, self.superblock.epoch, format.readU32(inode_bytes, 12)) catch
                return error.IntegerOverflow
        else
            format.readU64(inode_bytes, 32);
        const modification_nsec = if (version == 0)
            self.superblock.fixed_nsec
        else
            format.readU32(inode_bytes, 40);
        const link_count = if (version == 0)
            if (mode & 0xf000 != 0x4000 and inode_format & (1 << 4) != 0)
                1
            else
                @as(u32, format.readU16(inode_bytes, 6))
        else
            format.readU32(inode_bytes, 44);
        const result = Inode{
            .nid = nid,
            .location = location,
            .inode_size = inode_size,
            .xattr_size = xattr_size,
            .layout = layout,
            .mode = mode,
            .uid = uid,
            .gid = gid,
            .link_count = link_count,
            .file_size = file_size,
            .modification_time = modification_time,
            .modification_nsec = modification_nsec,
            .data_block = data_block,
        };
        _ = try result.fileType();
        var with_compression = result;
        if (layout == .compressed_full or layout == .compressed_compact) {
            const header_start = std.mem.alignForward(
                usize,
                location + inode_size + xattr_size,
                8,
            );
            if (self.bytes.len -| header_start < 16) return error.TruncatedFrame;
            const cluster_byte = self.bytes[header_start + 7];
            if (cluster_byte & 0x80 != 0) {
                if (layout != .compressed_full or
                    self.superblock.feature_incompat & format.feature_incompat_fragments == 0 or
                    self.superblock.packed_nid == 0)
                    return error.InvalidErofs;
                const encoded_offset = format.readU64(self.bytes, header_start);
                if (encoded_offset >> 63 == 0) return error.InvalidErofs;
                with_compression.compressed_advise = 0x20;
                with_compression.compressed_header_start = header_start;
                with_compression.compressed_index_start = header_start + 16;
                with_compression.fragment_offset = encoded_offset ^ (@as(u64, 1) << 63);
                with_compression.fragment_logical_start = 0;
                return with_compression;
            }
            const advise = format.readU16(self.bytes, header_start + 4);
            if (cluster_byte & 0xf0 != 0 or advise & ~@as(u16, 0x003f) != 0)
                return error.UnsupportedErofsFeature;
            if (advise & 0x28 == 0x28) return error.InvalidErofs;
            const algorithm1 = std.enums.fromInt(
                format.Compression,
                self.bytes[header_start + 6] & 0x0f,
            ) orelse return error.UnsupportedErofsCompression;
            const algorithm2_raw = self.bytes[header_start + 6] >> 4;
            const algorithm2 = if (algorithm2_raw == 0)
                algorithm1
            else
                std.enums.fromInt(format.Compression, algorithm2_raw) orelse
                    return error.UnsupportedErofsCompression;
            with_compression.compressed_algorithms = .{ algorithm1, algorithm2 };
            with_compression.compressed_cluster_bits = self.superblock.block_bits +
                (cluster_byte & 0x0f);
            with_compression.compressed_advise = advise;
            with_compression.compressed_header_start = header_start;
            with_compression.compressed_index_start = header_start +
                (if (layout == .compressed_full) @as(usize, 16) else 8);
            if (advise & 0x28 != 0) {
                const tail = try self.findTailHead(with_compression);
                if (advise & 0x20 != 0) {
                    if (self.superblock.feature_incompat & format.feature_incompat_fragments == 0 or
                        self.superblock.packed_nid == 0 or tail.logical_start == 0)
                        return error.InvalidErofs;
                    with_compression.fragment_offset = @as(
                        u64,
                        format.readU32(self.bytes, header_start),
                    ) | (if (layout == .compressed_full)
                        @as(u64, tail.index.physical_block) << 32
                    else
                        0);
                    with_compression.fragment_logical_start = tail.logical_start;
                } else {
                    if (self.superblock.feature_incompat &
                        format.feature_incompat_ztailpacking == 0)
                        return error.InvalidErofs;
                    const inline_size: usize = format.readU16(self.bytes, header_start + 2);
                    if (inline_size == 0) return error.InvalidErofs;
                    const cluster_size: usize = @as(usize, 1) << @intCast(
                        with_compression.compressed_cluster_bits,
                    );
                    const cluster_count = (std.math.add(
                        usize,
                        file_size,
                        cluster_size - 1,
                    ) catch return error.IntegerOverflow) / cluster_size;
                    const inline_start = try self.compressedIndexEnd(
                        with_compression,
                        cluster_count,
                    );
                    const inline_end = try checkedEnd(
                        inline_start,
                        inline_size,
                        self.bytes.len,
                    );
                    if (inline_start / self.superblock.block_size !=
                        (inline_end - 1) / self.superblock.block_size)
                        return error.InvalidErofs;
                    with_compression.compressed_inline_start = inline_start;
                    with_compression.compressed_inline_size = inline_size;
                    with_compression.compressed_inline_logical_start = tail.logical_start;
                    with_compression.compressed_inline_kind = tail.index.kind;
                }
            }
        }
        return with_compression;
    }

    pub fn readXattrsAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        inode_value: Inode,
        max_count: usize,
        max_total_bytes: usize,
    ) Error!Xattrs {
        const ibody_start = std.math.add(
            usize,
            inode_value.location,
            inode_value.inode_size,
        ) catch return error.IntegerOverflow;
        return xattr.readAllocLimited(
            allocator,
            self.bytes,
            self.superblock.block_size,
            self.superblock.xattr_block,
            self.superblock.xattr_prefix_start,
            self.superblock.xattr_prefix_count,
            ibody_start,
            inode_value.xattr_size,
            max_count,
            max_total_bytes,
        );
    }

    const TailHead = struct {
        logical_start: usize,
        index: CompressionIndex,
    };

    fn findTailHead(self: Archive, inode_value: Inode) Error!TailHead {
        const cluster_size: usize = @as(usize, 1) << @intCast(
            inode_value.compressed_cluster_bits,
        );
        if (cluster_size < self.superblock.block_size or cluster_size > 16 * 1024)
            return error.UnsupportedErofsFeature;
        const cluster_count = if (inode_value.file_size == 0) 0 else (std.math.add(usize, inode_value.file_size, cluster_size - 1) catch
            return error.IntegerOverflow) / cluster_size;
        var tail: ?TailHead = null;
        for (0..cluster_count) |cluster_index| {
            const index = if (inode_value.layout == .compressed_full)
                try self.readFullIndex(inode_value, cluster_index)
            else
                try self.readCompactIndex(inode_value, cluster_index, cluster_count);
            if (index.kind == 2) continue;
            const logical_base = std.math.mul(usize, cluster_index, cluster_size) catch
                return error.IntegerOverflow;
            const logical_start = std.math.add(
                usize,
                logical_base,
                index.logical_offset,
            ) catch return error.IntegerOverflow;
            if (logical_start >= inode_value.file_size) continue;
            tail = .{
                .logical_start = logical_start,
                .index = index,
            };
        }
        return tail orelse return error.InvalidErofs;
    }

    fn compressedIndexEnd(
        _: Archive,
        inode_value: Inode,
        cluster_count: usize,
    ) Error!usize {
        if (cluster_count == 0) return inode_value.compressed_index_start;
        if (inode_value.layout == .compressed_full) return std.math.add(
            usize,
            inode_value.compressed_index_start,
            std.math.mul(usize, cluster_count, 8) catch return error.IntegerOverflow,
        ) catch return error.IntegerOverflow;
        if (inode_value.layout != .compressed_compact)
            return error.UnsupportedErofsLayout;
        const cluster_index = cluster_count - 1;
        const entry_base = inode_value.compressed_index_start;
        const initial_4byte = ((32 - entry_base % 32) / 4) & 7;
        const compact_2byte = if (inode_value.compressed_advise & 1 != 0 and
            initial_4byte < cluster_count)
            (cluster_count - initial_4byte) / 16 * 16
        else
            0;
        var relative_index = cluster_index;
        var position = entry_base;
        var shift: u3 = 2;
        if (relative_index >= initial_4byte) {
            position += initial_4byte * 4;
            relative_index -= initial_4byte;
            if (relative_index < compact_2byte) {
                shift = 1;
            } else {
                position += compact_2byte * 2;
                relative_index -= compact_2byte;
            }
        }
        position += relative_index << shift;
        const entry_size: usize = @as(usize, 1) << shift;
        const value_count: usize = if (entry_size == 4) 2 else 16;
        const pack_size = value_count * entry_size;
        return std.math.add(
            usize,
            position & ~(pack_size - 1),
            pack_size,
        ) catch return error.IntegerOverflow;
    }

    pub fn readFlatAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        inode_value: Inode,
        max_output_len: usize,
    ) Error![]u8 {
        return self.readFlatAllocWithLimits(allocator, inode_value, .{
            .max_output_len = max_output_len,
        });
    }

    pub fn readFlatAllocWithLimits(
        self: Archive,
        allocator: std.mem.Allocator,
        inode_value: Inode,
        limits: ReadLimits,
    ) Error![]u8 {
        if (inode_value.file_size > limits.max_output_len) return error.OutputLimitExceeded;
        if (inode_value.layout != .flat_plain and inode_value.layout != .flat_inline)
            return self.readCompressedAllocLimited(
                allocator,
                inode_value,
                limits,
            );
        const output = try allocator.alloc(u8, inode_value.file_size);
        errdefer allocator.free(output);
        const full_blocks = if (inode_value.layout == .flat_inline)
            inode_value.file_size / self.superblock.block_size
        else
            (inode_value.file_size + self.superblock.block_size - 1) /
                self.superblock.block_size;
        const full_bytes = @min(
            inode_value.file_size,
            std.math.mul(usize, full_blocks, self.superblock.block_size) catch
                return error.IntegerOverflow,
        );
        if (full_bytes != 0) {
            if (inode_value.data_block == std.math.maxInt(u32)) {
                @memset(output[0..full_bytes], 0);
            } else {
                const data_start = std.math.mul(
                    usize,
                    @intCast(inode_value.data_block),
                    self.superblock.block_size,
                ) catch return error.IntegerOverflow;
                const data_end = try checkedEnd(data_start, full_bytes, self.bytes.len);
                @memcpy(output[0..full_bytes], self.bytes[data_start..data_end]);
            }
        }
        if (inode_value.layout == .flat_inline and full_bytes < output.len) {
            const inline_start = std.math.add(
                usize,
                inode_value.location,
                inode_value.inode_size + inode_value.xattr_size,
            ) catch return error.IntegerOverflow;
            const inline_len = output.len - full_bytes;
            if (inline_start / self.superblock.block_size !=
                (inline_start + inline_len - 1) / self.superblock.block_size)
                return error.InvalidErofs;
            const inline_end = try checkedEnd(inline_start, inline_len, self.bytes.len);
            @memcpy(output[full_bytes..], self.bytes[inline_start..inline_end]);
        }
        return output;
    }

    fn readCompressedAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        inode_value: Inode,
        limits: ReadLimits,
    ) Error![]u8 {
        if (inode_value.layout != .compressed_full and
            inode_value.layout != .compressed_compact)
            return error.UnsupportedErofsLayout;
        if (inode_value.file_size > limits.max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, inode_value.file_size);
        errdefer allocator.free(output);
        @memset(output, 0);
        if (inode_value.compressed_inline_size != 0) {
            if (inode_value.fragment_offset != null) return error.InvalidErofs;
            const inline_start = inode_value.compressed_inline_logical_start;
            if (inline_start > output.len) return error.InvalidErofs;
            if (inline_start != 0)
                try self.readCompressedRangeInto(
                    allocator,
                    inode_value,
                    0,
                    output[0..inline_start],
                    null,
                );
            try self.readCompressedInlineTailInto(
                allocator,
                inode_value,
                output[inline_start..],
            );
        } else if (inode_value.fragment_offset) |fragment_offset| {
            if (self.superblock.feature_incompat & format.feature_incompat_fragments == 0 or
                self.superblock.packed_nid == 0 or inode_value.nid == self.superblock.packed_nid)
                return error.InvalidErofs;
            const fragment_start = inode_value.fragment_logical_start;
            if (fragment_start > output.len) return error.InvalidErofs;
            if (fragment_start != 0)
                try self.readCompressedRangeInto(
                    allocator,
                    inode_value,
                    0,
                    output[0..fragment_start],
                    null,
                );
            try self.readPackedRangeInto(
                allocator,
                fragment_offset,
                output[fragment_start..],
                limits.max_packed_extent_len,
            );
        } else {
            try self.readCompressedRangeInto(
                allocator,
                inode_value,
                0,
                output,
                null,
            );
        }
        return output;
    }

    fn readCompressedInlineTailInto(
        self: Archive,
        allocator: std.mem.Allocator,
        inode_value: Inode,
        output: []u8,
    ) Error!void {
        const inline_end = try checkedEnd(
            inode_value.compressed_inline_start,
            inode_value.compressed_inline_size,
            self.bytes.len,
        );
        const encoded = self.bytes[inode_value.compressed_inline_start..inline_end];
        const kind = inode_value.compressed_inline_kind;
        if (kind == 0) {
            if (encoded.len != output.len) return error.InvalidErofs;
            @memcpy(output, encoded);
            return;
        }
        if (kind != 1 and kind != 3) return error.InvalidErofs;
        const algorithm = inode_value.compressed_algorithms[if (kind == 3) 1 else 0] orelse
            return error.InvalidErofs;
        const decoded = try codec.decodeExtentAlloc(
            allocator,
            algorithm,
            encoded,
            output.len,
            self.superblock.feature_incompat & 1 != 0,
        );
        defer allocator.free(decoded);
        @memcpy(output, decoded);
    }

    const CompressionHead = struct {
        logical_start: usize,
        physical_block: u32,
        kind: u2,
    };

    fn readCompressedRangeInto(
        self: Archive,
        allocator: std.mem.Allocator,
        inode_value: Inode,
        range_start: usize,
        output: []u8,
        max_extent_len: ?usize,
    ) Error!void {
        if (output.len == 0) return;
        _ = inode_value.compressed_algorithms[0] orelse return error.InvalidErofs;
        const range_end = std.math.add(usize, range_start, output.len) catch
            return error.IntegerOverflow;
        if (range_end > inode_value.file_size) return error.InvalidErofs;
        const cluster_size: usize = @as(usize, 1) << @intCast(
            inode_value.compressed_cluster_bits,
        );
        if (cluster_size < self.superblock.block_size or cluster_size > 16 * 1024)
            return error.UnsupportedErofsFeature;
        const cluster_count = (std.math.add(
            usize,
            inode_value.file_size,
            cluster_size - 1,
        ) catch return error.IntegerOverflow) / cluster_size;
        var previous: ?CompressionHead = null;
        for (0..cluster_count) |cluster_index| {
            const index = if (inode_value.layout == .compressed_full)
                try self.readFullIndex(inode_value, cluster_index)
            else
                try self.readCompactIndex(inode_value, cluster_index, cluster_count);
            const kind = index.kind;
            if (kind == 2) continue;
            const cluster_offset = index.logical_offset;
            if (cluster_offset >= cluster_size) return error.InvalidErofs;
            const logical_base = std.math.mul(usize, cluster_index, cluster_size) catch
                return error.IntegerOverflow;
            const logical = std.math.add(
                usize,
                logical_base,
                cluster_offset,
            ) catch return error.IntegerOverflow;
            const head = CompressionHead{
                .logical_start = logical,
                .physical_block = index.physical_block,
                .kind = kind,
            };
            if (previous) |prior| {
                if (head.logical_start <= prior.logical_start) return error.InvalidErofs;
                try self.readCompressedExtentRangeInto(
                    allocator,
                    inode_value,
                    prior,
                    head,
                    range_start,
                    output,
                    max_extent_len,
                );
            }
            previous = head;
        }
        const final = previous orelse return error.InvalidErofs;
        try self.readCompressedExtentRangeInto(
            allocator,
            inode_value,
            final,
            null,
            range_start,
            output,
            max_extent_len,
        );
    }

    fn readCompressedExtentRangeInto(
        self: Archive,
        allocator: std.mem.Allocator,
        inode_value: Inode,
        head: CompressionHead,
        next: ?CompressionHead,
        range_start: usize,
        output: []u8,
        max_extent_len: ?usize,
    ) Error!void {
        if (head.logical_start >= inode_value.file_size) return;
        const logical_end = @min(
            inode_value.file_size,
            if (next) |value| value.logical_start else inode_value.file_size,
        );
        if (logical_end <= head.logical_start) return error.InvalidErofs;
        const range_end = range_start + output.len;
        const overlap_start = @max(head.logical_start, range_start);
        const overlap_end = @min(logical_end, range_end);
        if (overlap_start >= overlap_end) return;

        const physical_start = std.math.mul(
            usize,
            head.physical_block,
            self.superblock.block_size,
        ) catch return error.IntegerOverflow;
        const physical_blocks: usize = if (next) |value|
            if (inode_value.fragment_offset != null and
                value.logical_start == inode_value.fragment_logical_start)
                1
            else if (value.physical_block > head.physical_block)
                value.physical_block - head.physical_block
            else
                1
        else
            1;
        const physical_size = std.math.mul(
            usize,
            physical_blocks,
            self.superblock.block_size,
        ) catch return error.IntegerOverflow;
        const physical_end = try checkedEnd(physical_start, physical_size, self.bytes.len);
        const physical = self.bytes[physical_start..physical_end];
        const destination = output[overlap_start - range_start .. overlap_end - range_start];
        const extent_offset = overlap_start - head.logical_start;
        const extent_len = logical_end - head.logical_start;
        if (head.kind == 0) {
            if (inode_value.compressed_advise & 0x10 != 0) {
                if (extent_len > self.superblock.block_size or
                    physical.len < self.superblock.block_size)
                    return error.InvalidErofs;
                const rotation = head.logical_start % self.superblock.block_size;
                for (destination, 0..) |*byte, index|
                    byte.* = physical[
                        (rotation + extent_offset + index) %
                            self.superblock.block_size
                    ];
            } else {
                const source_end = std.math.add(
                    usize,
                    extent_offset,
                    destination.len,
                ) catch return error.IntegerOverflow;
                if (source_end > physical.len) return error.InvalidErofs;
                @memcpy(destination, physical[extent_offset..source_end]);
            }
        } else if (head.kind == 1 or head.kind == 3) {
            if (max_extent_len) |limit|
                if (extent_len > limit) return error.OutputLimitExceeded;
            const algorithm = inode_value.compressed_algorithms[if (head.kind == 3) 1 else 0] orelse
                return error.InvalidErofs;
            const extent = try codec.decodeExtentAlloc(
                allocator,
                algorithm,
                physical,
                extent_len,
                self.superblock.feature_incompat & 1 != 0,
            );
            defer allocator.free(extent);
            @memcpy(destination, extent[extent_offset..][0..destination.len]);
        } else {
            return error.UnsupportedErofsFeature;
        }
    }

    fn readPackedRangeInto(
        self: Archive,
        allocator: std.mem.Allocator,
        fragment_offset: u64,
        output: []u8,
        max_extent_len: usize,
    ) Error!void {
        const offset = std.math.cast(usize, fragment_offset) orelse
            return error.IntegerOverflow;
        const end = std.math.add(usize, offset, output.len) catch
            return error.IntegerOverflow;
        const packed_inode = try self.inode(self.superblock.packed_nid);
        if (try packed_inode.fileType() != .regular or
            packed_inode.fragment_offset != null or end > packed_inode.file_size)
            return error.InvalidErofs;
        if (packed_inode.layout == .flat_plain or packed_inode.layout == .flat_inline) {
            return self.readFlatRangeInto(packed_inode, offset, output);
        }
        if (packed_inode.layout != .compressed_full and packed_inode.layout != .compressed_compact)
            return error.UnsupportedErofsLayout;
        return self.readCompressedRangeInto(
            allocator,
            packed_inode,
            offset,
            output,
            max_extent_len,
        );
    }

    fn readFlatRangeInto(
        self: Archive,
        inode_value: Inode,
        range_start: usize,
        output: []u8,
    ) Error!void {
        const range_end = std.math.add(usize, range_start, output.len) catch
            return error.IntegerOverflow;
        if (range_end > inode_value.file_size) return error.InvalidErofs;
        @memset(output, 0);
        const full_bytes = if (inode_value.layout == .flat_inline)
            inode_value.file_size / self.superblock.block_size * self.superblock.block_size
        else
            inode_value.file_size;
        const data_end = @min(range_end, full_bytes);
        if (range_start < data_end and inode_value.data_block != std.math.maxInt(u32)) {
            const data_start = std.math.mul(
                usize,
                @as(usize, inode_value.data_block),
                self.superblock.block_size,
            ) catch return error.IntegerOverflow;
            const source_start = std.math.add(usize, data_start, range_start) catch
                return error.IntegerOverflow;
            const source_end = try checkedEnd(
                source_start,
                data_end - range_start,
                self.bytes.len,
            );
            @memcpy(output[0 .. data_end - range_start], self.bytes[source_start..source_end]);
        }
        if (range_end > full_bytes) {
            if (inode_value.layout != .flat_inline) return error.InvalidErofs;
            const tail_len = inode_value.file_size - full_bytes;
            const inline_start = std.math.add(
                usize,
                inode_value.location,
                inode_value.inode_size + inode_value.xattr_size,
            ) catch return error.IntegerOverflow;
            if (tail_len != 0 and inline_start / self.superblock.block_size !=
                (inline_start + tail_len - 1) / self.superblock.block_size)
                return error.InvalidErofs;
            const tail_read_start = @max(range_start, full_bytes);
            const source_start = std.math.add(
                usize,
                inline_start,
                tail_read_start - full_bytes,
            ) catch return error.IntegerOverflow;
            const source_end = try checkedEnd(
                source_start,
                range_end - tail_read_start,
                self.bytes.len,
            );
            @memcpy(
                output[tail_read_start - range_start ..],
                self.bytes[source_start..source_end],
            );
        }
    }

    const CompressionIndex = struct {
        kind: u2,
        logical_offset: usize,
        physical_block: u32,
    };

    fn readFullIndex(
        self: Archive,
        inode_value: Inode,
        cluster_index: usize,
    ) Error!CompressionIndex {
        const index_offset = std.math.add(
            usize,
            inode_value.compressed_index_start,
            cluster_index * 8,
        ) catch return error.IntegerOverflow;
        if (self.bytes.len -| index_offset < 8) return error.TruncatedFrame;
        return .{
            .kind = @truncate(format.readU16(self.bytes, index_offset) & 3),
            .logical_offset = format.readU16(self.bytes, index_offset + 2),
            .physical_block = format.readU32(self.bytes, index_offset + 4),
        };
    }

    fn readCompactIndex(
        self: Archive,
        inode_value: Inode,
        cluster_index: usize,
        cluster_count: usize,
    ) Error!CompressionIndex {
        const entry_base = inode_value.compressed_index_start;
        const initial_4byte = ((32 - entry_base % 32) / 4) & 7;
        const compact_2byte = if (inode_value.compressed_advise & 1 != 0 and
            initial_4byte < cluster_count)
            (cluster_count - initial_4byte) / 16 * 16
        else
            0;
        var relative_index = cluster_index;
        var position = entry_base;
        var shift: u3 = 2;
        if (relative_index >= initial_4byte) {
            position += initial_4byte * 4;
            relative_index -= initial_4byte;
            if (relative_index < compact_2byte) {
                shift = 1;
            } else {
                position += compact_2byte * 2;
                relative_index -= compact_2byte;
            }
        }
        position += relative_index << shift;
        const entry_size: usize = @as(usize, 1) << shift;
        const value_count: usize = if (entry_size == 4) 2 else 16;
        const pack_size = value_count * entry_size;
        const pack_start = position & ~(pack_size - 1);
        if (self.bytes.len -| pack_start < pack_size) return error.TruncatedFrame;
        const item_index = (position & (pack_size - 1)) >> shift;
        const logical_bits = @max(inode_value.compressed_cluster_bits, 12);
        if (logical_bits > 14) return error.UnsupportedErofsFeature;
        const encoded_bits: usize = (pack_size - 4) * 8 / value_count;
        const value = readPackedBits(
            self.bytes[pack_start..][0 .. pack_size - 4],
            encoded_bits * item_index,
            encoded_bits,
        );
        const logical_mask = (@as(u32, 1) << @intCast(logical_bits)) - 1;
        const kind: u2 = @truncate((value >> @intCast(logical_bits)) & 3);
        var physical = format.readU32(self.bytes, pack_start + pack_size - 4);
        if (kind != 2) {
            var scan_index: isize = @intCast(item_index);
            var physical_delta: u32 = if (inode_value.compressed_advise & 2 != 0) 0 else 1;
            while (scan_index > 0) {
                scan_index -= 1;
                const previous = readPackedBits(
                    self.bytes[pack_start..][0 .. pack_size - 4],
                    encoded_bits * @as(usize, @intCast(scan_index)),
                    encoded_bits,
                );
                const previous_kind = (previous >> @intCast(logical_bits)) & 3;
                const previous_value = previous & logical_mask;
                if (inode_value.compressed_advise & 2 != 0) {
                    if (previous_kind == 2) {
                        if (previous_value & 0x800 != 0) {
                            scan_index -= 1;
                            physical_delta += previous_value & ~@as(u32, 0x800);
                            continue;
                        }
                        if (previous_value <= 1) return error.InvalidErofs;
                        scan_index -= @intCast(previous_value - 2);
                        continue;
                    }
                    physical_delta += 1;
                } else {
                    if (previous_kind == 2)
                        scan_index -= @intCast(previous_value);
                    if (scan_index >= 0) physical_delta += 1;
                }
            }
            physical = std.math.add(u32, physical, physical_delta) catch
                return error.IntegerOverflow;
        }
        return .{
            .kind = kind,
            .logical_offset = value & logical_mask,
            .physical_block = physical,
        };
    }

    pub fn readDirectoryAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        inode_value: Inode,
        max_directory_bytes: usize,
    ) Error!Directory {
        if (try inode_value.fileType() != .directory) return error.ErofsNotDirectory;
        const bytes = try self.readFlatAllocLimited(
            allocator,
            inode_value,
            max_directory_bytes,
        );
        errdefer allocator.free(bytes);
        var entries: std.ArrayList(DirectoryEntry) = .empty;
        errdefer entries.deinit(allocator);
        var block_start: usize = 0;
        var previous_name: ?[]const u8 = null;
        while (block_start < bytes.len) {
            const block_len = @min(self.superblock.block_size, bytes.len - block_start);
            const block = bytes[block_start..][0..block_len];
            if (block.len < 12) return error.InvalidErofs;
            const first_name_offset: usize = format.readU16(block, 8);
            if (first_name_offset < 12 or first_name_offset > block.len or
                first_name_offset % 12 != 0)
                return error.InvalidErofs;
            const count = first_name_offset / 12;
            for (0..count) |index| {
                const entry_offset = index * 12;
                const name_start: usize = format.readU16(block, entry_offset + 8);
                const name_end = if (index + 1 < count)
                    @as(usize, format.readU16(block, entry_offset + 20))
                else blk: {
                    const tail = block[name_start..];
                    break :blk name_start + (std.mem.indexOfScalar(u8, tail, 0) orelse tail.len);
                };
                if (name_start < first_name_offset or name_end <= name_start or
                    name_end > block.len or name_end - name_start > format.name_max)
                    return error.InvalidErofs;
                const name = block[name_start..name_end];
                if (std.mem.indexOfScalar(u8, name, '/') != null) return error.InvalidErofs;
                const file_type = std.enums.fromInt(
                    format.FileType,
                    block[entry_offset + 10],
                ) orelse return error.InvalidErofs;
                if (!std.mem.eql(u8, name, ".") and !std.mem.eql(u8, name, "..")) {
                    if (previous_name) |previous|
                        if (std.mem.order(u8, previous, name) != .lt)
                            return error.InvalidErofs;
                    previous_name = name;
                    try entries.append(allocator, .{
                        .nid = format.readU64(block, entry_offset),
                        .name = name,
                        .file_type = file_type,
                    });
                }
            }
            block_start += block_len;
        }
        return .{
            .allocator = allocator,
            .bytes = bytes,
            .entries = try entries.toOwnedSlice(allocator),
        };
    }

    pub fn lookup(
        self: Archive,
        allocator: std.mem.Allocator,
        path: []const u8,
        max_file_size: usize,
        max_directory_bytes: usize,
    ) Error!Inode {
        var current = try self.rootInode();
        var components = std.mem.tokenizeScalar(u8, path, '/');
        while (components.next()) |component| {
            if (!validName(component)) return error.InvalidErofs;
            var directory = try self.readDirectoryAlloc(
                allocator,
                current,
                max_directory_bytes,
            );
            defer directory.deinit();
            const entry = directory.find(component) orelse return error.ErofsEntryNotFound;
            current = try self.inode(entry.nid);
            if (current.file_size > max_file_size and
                (try current.fileType() == .regular or try current.fileType() == .symlink))
                return error.OutputLimitExceeded;
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
        return self.extractByPathAllocWithLimits(
            allocator,
            path,
            .{ .max_output_len = max_output_len },
            max_directory_bytes,
        );
    }

    pub fn extractByPathAllocWithLimits(
        self: Archive,
        allocator: std.mem.Allocator,
        path: []const u8,
        limits: ReadLimits,
        max_directory_bytes: usize,
    ) Error![]u8 {
        const target = try self.lookup(
            allocator,
            path,
            limits.max_output_len,
            max_directory_bytes,
        );
        const file_type = try target.fileType();
        if (file_type != .regular and file_type != .symlink)
            return error.ErofsNotRegularFile;
        return self.readFlatAllocWithLimits(allocator, target, limits);
    }
};

fn validName(name: []const u8) bool {
    if (name.len == 0 or std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, ".."))
        return false;
    return std.mem.indexOfScalar(u8, name, '/') == null and
        std.mem.indexOfScalar(u8, name, 0) == null;
}

fn readPackedBits(input: []const u8, bit_offset: usize, bit_count: usize) u32 {
    var value: u32 = 0;
    for (0..bit_count) |index| {
        const bit = bit_offset + index;
        value |= @as(u32, (input[bit / 8] >> @intCast(bit & 7)) & 1) <<
            @intCast(index);
    }
    return value;
}

fn checkedEnd(start: usize, length: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, length) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

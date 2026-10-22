const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const codec = @import("codec.zig");
const chunk = @import("chunk.zig");
const extent_reader = @import("extent.zig");
const xattr = @import("xattr.zig");
const compression_index = @import("compression_index.zig");
const reader_types = @import("reader/types.zig");
const metadata_reader = @import("reader/inode.zig");
const directory_reader = @import("reader/directory.zig");

pub const Error = metadata_reader.Error || core.Error || format.Error || codec.Error || chunk.Error || extent_reader.Error || xattr.Error ||
    std.mem.Allocator.Error || error{
    InvalidErofs,
    ErofsEntryNotFound,
    ErofsNotDirectory,
    ErofsNotRegularFile,
    ErofsMissingMetabox,
};

pub const Xattr = xattr.Attribute;
pub const Xattrs = xattr.Attributes;
pub const default_packed_extent_limit: usize = 8 * 1024 * 1024;

pub const ReadLimits = struct {
    max_output_len: usize,
    max_packed_extent_len: usize = default_packed_extent_limit,
};

pub const DeviceInfo = chunk.DeviceInfo;

pub const Inode = reader_types.Inode;
pub const DirectoryEntry = reader_types.DirectoryEntry;
pub const Directory = reader_types.Directory;

pub const LoadedMetaboxArchive = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    archive: Archive,

    pub fn deinit(self: *LoadedMetaboxArchive) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    devices: []const []const u8 = &.{},
    metabox_bytes: ?[]const u8 = null,
    superblock: format.Superblock,

    pub fn init(bytes: []const u8) Error!Archive {
        return initWithDevices(bytes, &.{});
    }

    pub fn initWithDevices(
        bytes: []const u8,
        devices: []const []const u8,
    ) Error!Archive {
        const superblock = try format.parseSuperblock(bytes);
        if (superblock.feature_compat & format.feature_compat_plain_xattr_prefixes != 0 or
            superblock.xattr_prefix_count == 0)
            try xattr.validatePrefixTable(
                bytes,
                superblock.xattr_prefix_start,
                superblock.xattr_prefix_count,
            );
        const result = Archive{
            .bytes = bytes,
            .devices = devices,
            .superblock = superblock,
        };
        try chunk.validateDevices(bytes, devices, superblock);
        return result;
    }

    pub fn loadMetaboxAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_metabox_len: usize,
        max_packed_extent_len: usize,
    ) Error!LoadedMetaboxArchive {
        if (self.superblock.feature_incompat & format.feature_incompat_metabox == 0 or
            self.superblock.metabox_nid == 0 or self.metabox_bytes != null)
            return error.InvalidErofs;
        const inode_value = try self.inode(self.superblock.metabox_nid);
        if (try inode_value.fileType() != .regular) return error.InvalidErofs;
        const bytes = try self.readFlatAllocWithLimits(allocator, inode_value, .{
            .max_output_len = max_metabox_len,
            .max_packed_extent_len = max_packed_extent_len,
        });
        var loaded = self;
        loaded.metabox_bytes = bytes;
        if (self.superblock.xattr_prefix_count != 0 and
            self.superblock.feature_compat & format.feature_compat_plain_xattr_prefixes == 0)
            try xattr.validatePrefixTable(
                bytes,
                self.superblock.xattr_prefix_start,
                self.superblock.xattr_prefix_count,
            );
        return .{ .allocator = allocator, .bytes = bytes, .archive = loaded };
    }

    pub fn deviceInfo(self: Archive, index: usize) Error!DeviceInfo {
        return chunk.deviceInfo(self.bytes, self.superblock, index);
    }

    fn metadataBytes(self: Archive, inode_value: Inode) Error![]const u8 {
        return if (inode_value.in_metabox)
            self.metabox_bytes orelse error.ErofsMissingMetabox
        else
            self.bytes;
    }

    pub fn rootInode(self: Archive) Error!Inode {
        return self.inode(self.superblock.root_nid);
    }

    fn inodeReader(self: Archive) metadata_reader.Reader {
        return .{
            .superblock = self.superblock,
            .primary = .{ .slice = self.bytes },
            .metabox = if (self.metabox_bytes) |bytes| .{ .slice = bytes } else null,
        };
    }

    pub fn inode(self: Archive, nid: u64) Error!Inode {
        return self.inodeReader().inode(nid);
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
        const metadata = try self.metadataBytes(inode_value);
        const prefix_metadata = if (self.superblock.xattr_prefix_count == 0 or
            self.superblock.feature_compat & format.feature_compat_plain_xattr_prefixes != 0)
            self.bytes
        else
            self.metabox_bytes orelse return error.ErofsMissingMetabox;
        const shared_metadata = if (self.superblock.feature_compat &
            format.feature_compat_shared_xattrs_in_metabox != 0)
            self.metabox_bytes orelse return error.ErofsMissingMetabox
        else
            self.bytes;
        return xattr.readAllocLimited(
            allocator,
            prefix_metadata,
            shared_metadata,
            metadata,
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
        if (inode_value.layout == .chunk_based)
            return self.readChunkedAllocLimited(allocator, inode_value, limits.max_output_len);
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
            const null_block: u64 = if (self.superblock.feature_incompat &
                format.feature_incompat_48bit != 0)
                (@as(u64, 1) << 48) - 1
            else
                std.math.maxInt(u32);
            if (inode_value.data_block == null_block) {
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
            const metadata = try self.metadataBytes(inode_value);
            const inline_start = std.math.add(
                usize,
                inode_value.location,
                inode_value.inode_size + inode_value.xattr_size,
            ) catch return error.IntegerOverflow;
            const inline_len = output.len - full_bytes;
            if (inline_start / self.superblock.block_size !=
                (inline_start + inline_len - 1) / self.superblock.block_size)
                return error.InvalidErofs;
            const inline_end = try checkedEnd(inline_start, inline_len, metadata.len);
            @memcpy(output[full_bytes..], metadata[inline_start..inline_end]);
        }
        return output;
    }

    fn readChunkedAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        inode_value: Inode,
        max_output_len: usize,
    ) Error![]u8 {
        if (inode_value.layout != .chunk_based) return error.UnsupportedErofsLayout;
        const metadata = try self.metadataBytes(inode_value);
        return chunk.readAllocLimited(
            allocator,
            self.bytes,
            metadata,
            self.devices,
            self.superblock,
            .{
                .file_size = inode_value.file_size,
                .chunk_format = inode_value.chunk_format,
                .chunk_bits = inode_value.chunk_bits,
                .index_start = inode_value.chunk_index_start,
                .index_size = inode_value.chunk_index_size,
            },
            max_output_len,
        );
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
        if (inode_value.compressed_extent_record_size != 0) {
            const metadata = try self.metadataBytes(inode_value);
            return extent_reader.readAllocLimited(
                allocator,
                self.bytes,
                metadata,
                self.superblock,
                .{
                    .file_size = inode_value.file_size,
                    .advise = inode_value.compressed_advise,
                    .cluster_bits = inode_value.compressed_cluster_bits,
                    .record_start = inode_value.compressed_extent_start,
                    .record_size = inode_value.compressed_extent_record_size,
                    .record_count = inode_value.compressed_extent_count,
                },
                limits.max_output_len,
            );
        }
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
        const metadata = try self.metadataBytes(inode_value);
        const inline_end = try checkedEnd(
            inode_value.compressed_inline_start,
            inode_value.compressed_inline_size,
            metadata.len,
        );
        const encoded = metadata[inode_value.compressed_inline_start..inline_end];
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
        compressed_blocks: ?u32,
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
                .compressed_blocks = try self.compressedBlockCount(inode_value, cluster_index, cluster_count, logical, kind),
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
        const physical_blocks: usize = if (head.compressed_blocks) |blocks|
            blocks
        else if (next) |value|
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
            const metadata = try self.metadataBytes(inode_value);
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
                metadata.len,
            );
            @memcpy(
                output[tail_read_start - range_start ..],
                metadata[source_start..source_end],
            );
        }
    }

    const CompressionIndex = compression_index.Index;

    fn compressedBlockCount(self: Archive, inode_value: Inode, cluster_index: usize, cluster_count: usize, logical_start: usize, kind: u2) Error!?u32 {
        return self.inodeReader().compressedBlockCount(inode_value, cluster_index, cluster_count, logical_start, kind);
    }

    fn readFullIndex(self: Archive, inode_value: Inode, cluster_index: usize) Error!CompressionIndex {
        return self.inodeReader().readFullIndex(inode_value, cluster_index);
    }

    fn readCompactIndex(self: Archive, inode_value: Inode, cluster_index: usize, cluster_count: usize) Error!CompressionIndex {
        return self.inodeReader().readCompactIndex(inode_value, cluster_index, cluster_count);
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
        return directory_reader.parseOwned(allocator, bytes, self.superblock.block_size);
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
    return directory_reader.validName(name);
}

fn checkedEnd(start: usize, length: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, length) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

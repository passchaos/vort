const input_module = @import("input.zig");
const std = @import("std");
const format = @import("../format.zig");
const compression_index = @import("../compression_index.zig");
const types = @import("types.zig");
pub const Error = types.Error || input_module.Error || error{ ErofsMissingMetabox, UnsupportedErofsCompression };
pub const Inode = types.Inode;
const CompressionIndex = compression_index.Index;

pub const Reader = struct {
    superblock: format.Superblock,
    primary: input_module.Input,
    metabox: ?input_module.Input = null,

    pub fn metadataInput(self: Reader, inode_value: Inode) Error!input_module.Input {
        return if (inode_value.in_metabox) self.metabox orelse error.ErofsMissingMetabox else self.primary;
    }

    pub fn inode(self: Reader, nid: u64) Error!Inode {
        const in_metabox = nid >> 63 != 0;
        if (in_metabox and
            self.superblock.feature_incompat & format.feature_incompat_metabox == 0)
            return error.InvalidErofs;
        const metadata = if (in_metabox)
            self.metabox orelse return error.ErofsMissingMetabox
        else
            self.primary;
        const metadata_start = if (in_metabox)
            0
        else
            std.math.mul(
                usize,
                self.superblock.meta_block,
                self.superblock.block_size,
            ) catch return error.IntegerOverflow;
        const slot_nid = nid & ((@as(u64, 1) << 63) - 1);
        const slot_offset = std.math.mul(usize, std.math.cast(usize, slot_nid) orelse return error.IntegerOverflow, format.inode_slot_size) catch
            return error.IntegerOverflow;
        const location = std.math.add(usize, metadata_start, slot_offset) catch
            return error.IntegerOverflow;
        var inode_buffer: [64]u8 = undefined;
        try metadata.read(location, inode_buffer[0..32]);
        const compact = &inode_buffer;
        const inode_format = format.readU16(compact, 0);
        if (inode_format & ~@as(u16, 0x1f) != 0) return error.UnsupportedErofsFeature;
        const version = inode_format & 1;
        const layout_raw: u3 = @truncate((inode_format >> 1) & 7);
        const layout = std.enums.fromInt(format.Layout, layout_raw) orelse
            return error.UnsupportedErofsLayout;
        const inode_size: usize = if (version == 0) 32 else 64;
        if (inode_size == 64) try metadata.read(location + 32, inode_buffer[32..]);
        const inode_bytes = inode_buffer[0..inode_size];
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
            .in_metabox = in_metabox,
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
        const file_type = try result.fileType();
        var with_compression = result;
        if (self.superblock.feature_incompat & format.feature_incompat_48bit != 0 and
            (layout == .flat_plain or layout == .flat_inline) and
            (version == 1 or (file_type != .directory and inode_format & (1 << 4) != 0)))
            with_compression.data_block |= @as(u64, format.readU16(inode_bytes, 6)) << 32;
        if (layout == .chunk_based) {
            if (file_type != .regular or
                self.superblock.feature_incompat & format.feature_incompat_chunked_file == 0)
                return error.InvalidErofs;
            const chunk_format = format.readU16(inode_bytes, 16);
            if (format.readU16(inode_bytes, 18) != 0) return error.InvalidErofs;
            if (chunk_format & ~@as(u16, 0x007f) != 0)
                return error.UnsupportedErofsFeature;
            if (chunk_format & 0x0040 != 0 and
                self.superblock.feature_incompat & format.feature_incompat_48bit == 0)
                return error.InvalidErofs;
            const chunk_bits = std.math.add(
                u8,
                self.superblock.block_bits,
                @as(u8, @intCast(chunk_format & 0x001f)),
            ) catch return error.IntegerOverflow;
            if (chunk_bits >= @bitSizeOf(usize)) return error.UnsupportedErofsFeature;
            const chunk_size: usize = @as(usize, 1) << @intCast(chunk_bits);
            const chunk_count = if (file_size == 0) 0 else (std.math.add(usize, file_size, chunk_size - 1) catch
                return error.IntegerOverflow) / chunk_size;
            const index_size: u8 = if (chunk_format & 0x0020 != 0) 8 else 4;
            const index_start = try alignForward(
                try add(try add(location, inode_size), xattr_size),
                index_size,
            );
            _ = try metadata.end(
                index_start,
                std.math.mul(usize, chunk_count, index_size) catch
                    return error.IntegerOverflow,
            );
            with_compression.chunk_format = chunk_format;
            with_compression.chunk_bits = chunk_bits;
            with_compression.chunk_index_start = index_start;
            with_compression.chunk_index_size = index_size;
            return with_compression;
        }
        if (layout == .compressed_full or layout == .compressed_compact) {
            const header_start = try alignForward(
                try add(try add(location, inode_size), xattr_size),
                8,
            );
            var header: [16]u8 = undefined;
            try metadata.read(header_start, &header);
            const cluster_byte = header[7];
            if (cluster_byte & 0x80 != 0) {
                if (layout != .compressed_full or
                    self.superblock.feature_incompat & format.feature_incompat_fragments == 0 or
                    self.superblock.packed_nid == 0)
                    return error.InvalidErofs;
                const encoded_offset = format.readU64(&header, 0);
                if (encoded_offset >> 63 == 0) return error.InvalidErofs;
                with_compression.compressed_advise = 0x20;
                with_compression.compressed_header_start = header_start;
                with_compression.compressed_index_start = header_start + 16;
                with_compression.fragment_offset = encoded_offset ^ (@as(u64, 1) << 63);
                with_compression.fragment_logical_start = 0;
                return with_compression;
            }
            const advise = format.readU16(&header, 4);
            if (cluster_byte & 0xf0 != 0 or advise & ~@as(u16, 0x003f) != 0)
                return error.UnsupportedErofsFeature;
            if (advise & 0x28 == 0x28) return error.InvalidErofs;
            if (layout == .compressed_full and
                self.superblock.feature_incompat & format.feature_incompat_48bit != 0 and
                advise & 1 != 0)
            {
                if (advise & 0x08 != 0) return error.UnsupportedErofsFeature;
                if (advise & 0x20 != 0 and (self.superblock.feature_incompat & format.feature_incompat_fragments == 0 or self.superblock.packed_nid == 0 or nid == self.superblock.packed_nid)) return error.InvalidErofs;
                const record_size: u8 = @as(u8, 4) << @intCast((advise >> 1) & 3);
                const record_start = try alignForward(
                    try add(header_start, 8),
                    record_size,
                );
                const extent_count = if (record_size <= 8) blk: {
                    const extent_cluster_bits = self.superblock.block_bits +
                        (cluster_byte & 0x0f);
                    const extent_cluster_size: usize = @as(usize, 1) <<
                        @intCast(extent_cluster_bits);
                    with_compression.compressed_cluster_bits = extent_cluster_bits;
                    break :blk if (file_size == 0) 0 else (std.math.add(usize, file_size, extent_cluster_size - 1) catch
                        return error.IntegerOverflow) / extent_cluster_size;
                } else std.math.cast(
                    usize,
                    @as(u64, format.readU32(&header, 0)) |
                        (@as(u64, format.readU16(&header, 6)) << 32),
                ) orelse return error.IntegerOverflow;
                const records_size = std.math.mul(
                    usize,
                    extent_count,
                    record_size,
                ) catch return error.IntegerOverflow;
                _ = try metadata.end(
                    record_start,
                    std.math.add(
                        usize,
                        records_size,
                        if (record_size == 4) @as(usize, 8) else 0,
                    ) catch return error.IntegerOverflow,
                );
                with_compression.compressed_advise = advise;
                with_compression.compressed_header_start = header_start;
                with_compression.compressed_extent_start = record_start;
                with_compression.compressed_extent_count = extent_count;
                with_compression.compressed_extent_record_size = record_size;
                return with_compression;
            }
            const algorithm1 = std.enums.fromInt(
                format.Compression,
                header[6] & 0x0f,
            ) orelse return error.UnsupportedErofsCompression;
            const algorithm2_raw = header[6] >> 4;
            const algorithm2 = std.enums.fromInt(format.Compression, algorithm2_raw) orelse
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
                        format.readU32(&header, 0),
                    ) | (if (layout == .compressed_full)
                        @as(u64, tail.index.physical_block) << 32
                    else
                        0);
                    with_compression.fragment_logical_start = tail.logical_start;
                } else {
                    if (self.superblock.feature_incompat &
                        format.feature_incompat_ztailpacking == 0)
                        return error.InvalidErofs;
                    const inline_size: usize = format.readU16(&header, 2);
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
                    const inline_end = try metadata.end(
                        inline_start,
                        inline_size,
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

    const TailHead = struct {
        logical_start: usize,
        index: CompressionIndex,
    };

    fn findTailHead(self: Reader, inode_value: Inode) Error!TailHead {
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
        _: Reader,
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
        return compression_index.compactIndexEnd(.{
            .index_start = inode_value.compressed_index_start,
            .cluster_bits = inode_value.compressed_cluster_bits,
            .advise = inode_value.compressed_advise,
            .block_size = 0,
        }, cluster_count);
    }

    pub fn compressedBlockCount(self: Reader, inode_value: Inode, cluster_index: usize, cluster_count: usize, logical_start: usize, kind: u2) Error!?u32 {
        if ((inode_value.fragment_offset != null and logical_start >= inode_value.fragment_logical_start) or
            (inode_value.compressed_inline_size != 0 and logical_start >= inode_value.compressed_inline_logical_start))
            return null;
        const flag: u16 = if (kind == 1) 2 else 4;
        if (inode_value.compressed_advise & flag == 0) return null;
        const next_index = cluster_index + 1;
        if (next_index >= cluster_count) return 1;
        const next = if (inode_value.layout == .compressed_full)
            try self.readFullIndex(inode_value, next_index)
        else
            try self.readCompactIndex(inode_value, next_index, cluster_count);
        if (next.kind != 2) return 1;
        const blocks = next.compressed_blocks orelse return error.InvalidErofs;
        if (blocks == 0) return error.InvalidErofs;
        return blocks;
    }

    fn indexView(self: Reader, inode_value: Inode) compression_index.View {
        return .{
            .index_start = inode_value.compressed_index_start,
            .cluster_bits = inode_value.compressed_cluster_bits,
            .advise = inode_value.compressed_advise,
            .block_size = self.superblock.block_size,
        };
    }

    pub fn readFullIndex(self: Reader, inode_value: Inode, cluster_index: usize) Error!CompressionIndex {
        return compression_index.readFullInput(try self.metadataInput(inode_value), self.indexView(inode_value), cluster_index);
    }

    pub fn readCompactIndex(self: Reader, inode_value: Inode, cluster_index: usize, cluster_count: usize) Error!CompressionIndex {
        return compression_index.readCompactInput(try self.metadataInput(inode_value), self.indexView(inode_value), cluster_index, cluster_count);
    }
};

fn add(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn alignForward(value: usize, alignment: usize) Error!usize {
    return (try add(value, alignment - 1)) & ~(alignment - 1);
}

const std = @import("std");
const apple_adc = @import("../apple_adc.zig");
const bzip2 = @import("../bzip2.zig");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const lzfse = @import("../lzfse.zig");
const xz = @import("../xz.zig");
const blkx = @import("blkx.zig");
const format = @import("format.zig");
const plist = @import("plist.zig");

pub const Error = core.Error || format.Error || blkx.Error || plist.Error ||
    apple_adc.Error || bzip2.Error || deflate.Error || lzfse.Error || xz.Error ||
    std.mem.Allocator.Error;

pub const ParseOptions = struct {
    max_xml_bytes: usize = 64 * 1024 * 1024,
    max_partitions: usize = 4096,
    max_blocks_per_partition: usize = 1 << 20,
    max_block_decoded_bytes: usize = 256 * 1024 * 1024,
    max_xz_dictionary_bytes: usize = 256 * 1024 * 1024,
    verify_data_fork_checksum: bool = true,
    verify_master_checksum: bool = true,
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    trailer: format.Trailer,
    partitions: []blkx.Partition,
    max_xz_dictionary_bytes: usize,

    pub fn parseAlloc(
        allocator: std.mem.Allocator,
        bytes: []const u8,
        options: ParseOptions,
    ) Error!Archive {
        const trailer = try format.parseTrailer(bytes);
        if (trailer.xml.length == 0) return error.UnsupportedDmgMetadata;
        const xml_len = std.math.cast(usize, trailer.xml.length) orelse
            return error.IntegerOverflow;
        if (xml_len > options.max_xml_bytes) return error.OutputLimitExceeded;
        const data_fork = try trailer.data_fork.slice(bytes);
        if (options.verify_data_fork_checksum) {
            if (trailer.data_fork_checksum.crc32()) |expected| {
                if (checksum.crc32Best(data_fork) != expected)
                    return error.ChecksumMismatch;
            }
        }
        const xml = try trailer.xml.slice(bytes);
        const descriptors = try plist.parseBlkxAlloc(
            allocator,
            xml,
            options.max_partitions,
        );
        defer plist.deinitDescriptors(allocator, descriptors);

        var partitions: std.ArrayList(blkx.Partition) = .empty;
        errdefer {
            for (partitions.items) |partition| partition.deinit(allocator);
            partitions.deinit(allocator);
        }
        for (descriptors) |descriptor| {
            const partition = try blkx.parseAlloc(
                allocator,
                descriptor.data,
                descriptor.name,
                .{
                    .max_blocks = options.max_blocks_per_partition,
                    .max_block_decoded_bytes = options.max_block_decoded_bytes,
                },
            );
            errdefer partition.deinit(allocator);
            try validatePartition(trailer, partition);
            try partitions.append(allocator, partition);
        }
        if (options.verify_master_checksum) {
            if (trailer.master_checksum.crc32()) |expected| {
                var crc = checksum.Crc32Best.init();
                for (partitions.items) |partition| {
                    const byte_len = partition.checksum.bits / 8;
                    if (partition.checksum.bits % 8 != 0 or
                        byte_len > partition.checksum.data.len)
                        return error.UnsupportedDmgChecksum;
                    crc.update(partition.checksum.data[0..byte_len]);
                }
                if (crc.digest() != expected) return error.ChecksumMismatch;
            }
        }
        return .{
            .allocator = allocator,
            .bytes = bytes,
            .trailer = trailer,
            .partitions = try partitions.toOwnedSlice(allocator),
            .max_xz_dictionary_bytes = options.max_xz_dictionary_bytes,
        };
    }

    pub fn deinit(self: *Archive) void {
        for (self.partitions) |partition| partition.deinit(self.allocator);
        self.allocator.free(self.partitions);
        self.* = undefined;
    }

    pub fn decodePartitionAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        partition_index: usize,
        max_output_len: usize,
    ) Error![]u8 {
        const partition = try self.getPartition(partition_index);
        const decoded_size = std.math.cast(usize, partition.decoded_size) orelse
            return error.IntegerOverflow;
        if (decoded_size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, decoded_size);
        errdefer allocator.free(output);
        try self.decodePartitionRangeInto(allocator, partition_index, 0, output);
        try verifyPartitionChecksum(partition, output);
        return output;
    }

    pub fn decodePartitionRangeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        partition_index: usize,
        offset: usize,
        length: usize,
        max_output_len: usize,
    ) Error![]u8 {
        if (length > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, length);
        errdefer allocator.free(output);
        try self.decodePartitionRangeInto(
            allocator,
            partition_index,
            offset,
            output,
        );
        return output;
    }

    pub fn decodePartitionRangeInto(
        self: Archive,
        allocator: std.mem.Allocator,
        partition_index: usize,
        offset: usize,
        output: []u8,
    ) Error!void {
        const partition = try self.getPartition(partition_index);
        const range_end = std.math.add(usize, offset, output.len) catch
            return error.IntegerOverflow;
        const partition_size = std.math.cast(usize, partition.decoded_size) orelse
            return error.IntegerOverflow;
        if (range_end > partition_size) return error.RangeOutOfBounds;
        if (output.len == 0) return;
        var copied: usize = 0;
        for (partition.blocks) |block| {
            const block_start = std.math.cast(usize, block.decoded_offset) orelse
                return error.IntegerOverflow;
            const block_size = std.math.cast(usize, block.decoded_size) orelse
                return error.IntegerOverflow;
            const block_end = std.math.add(usize, block_start, block_size) catch
                return error.IntegerOverflow;
            if (block_end <= offset or block_start >= range_end) continue;
            const copy_start = @max(offset, block_start);
            const copy_end = @min(range_end, block_end);
            const copy_len = copy_end - copy_start;
            if (block.kind.isZero()) {
                @memset(output[copy_start - offset ..][0..copy_len], 0);
            } else if (block.kind == .copy) {
                const packed_bytes = try packedSlice(self, partition, block);
                @memcpy(
                    output[copy_start - offset ..][0..copy_len],
                    packed_bytes[copy_start - block_start ..][0..copy_len],
                );
            } else {
                const decoded = try decodeCompressedBlockAlloc(
                    allocator,
                    block.kind,
                    try packedSlice(self, partition, block),
                    block_size,
                    self.max_xz_dictionary_bytes,
                );
                defer allocator.free(decoded);
                @memcpy(
                    output[copy_start - offset ..][0..copy_len],
                    decoded[copy_start - block_start ..][0..copy_len],
                );
            }
            copied += copy_len;
        }
        if (copied != output.len) return error.InvalidDmg;
    }

    fn getPartition(self: Archive, index: usize) Error!blkx.Partition {
        if (index >= self.partitions.len) return error.RangeOutOfBounds;
        return self.partitions[index];
    }
};

fn validatePartition(trailer: format.Trailer, partition: blkx.Partition) Error!void {
    const partition_sector_end = std.math.add(
        u64,
        partition.first_sector,
        partition.sector_count,
    ) catch return error.IntegerOverflow;
    if (partition_sector_end > trailer.sector_count) return error.InvalidDmg;
    for (partition.blocks) |block| {
        if (block.kind.isZero()) continue;
        const packed_end = try block.packedEnd();
        const relative_end = std.math.add(u64, partition.data_start, packed_end) catch
            return error.IntegerOverflow;
        if (relative_end > trailer.data_fork.length) return error.InvalidDmg;
    }
}

fn packedSlice(
    archive: Archive,
    partition: blkx.Partition,
    block: blkx.Block,
) Error![]const u8 {
    const relative = std.math.add(
        u64,
        partition.data_start,
        block.packed_offset,
    ) catch return error.IntegerOverflow;
    const absolute = std.math.add(
        u64,
        archive.trailer.data_fork.offset,
        relative,
    ) catch return error.IntegerOverflow;
    return (format.Fork{ .offset = absolute, .length = block.packed_size }).slice(
        archive.bytes,
    );
}

fn decodeCompressedBlockAlloc(
    allocator: std.mem.Allocator,
    kind: format.ChunkKind,
    input: []const u8,
    expected_size: usize,
    max_xz_dictionary_size: usize,
) Error![]u8 {
    const decoded = switch (kind) {
        .adc => try apple_adc.decodeAllocExactSize(allocator, input, expected_size),
        .zlib => try deflate.decodeZlibAllocExactSize(allocator, input, expected_size),
        .bzip2 => try bzip2.decodeAllocLimited(allocator, input, expected_size),
        .lzfse => try lzfse.decodeAllocLimited(allocator, input, expected_size),
        .xz => try xz.decodeAllocWithLimits(
            allocator,
            input,
            expected_size,
            max_xz_dictionary_size,
        ),
        else => return error.UnsupportedDmgChunk,
    };
    errdefer allocator.free(decoded);
    if (decoded.len != expected_size) return error.SizeMismatch;
    return decoded;
}

fn verifyPartitionChecksum(partition: blkx.Partition, output: []const u8) Error!void {
    const expected = partition.checksum.crc32() orelse return;
    var crc = checksum.Crc32Best.init();
    for (partition.blocks) |block| {
        if (block.kind == .zero_no_checksum) continue;
        const start = std.math.cast(usize, block.decoded_offset) orelse
            return error.IntegerOverflow;
        const length = std.math.cast(usize, block.decoded_size) orelse
            return error.IntegerOverflow;
        crc.update(output[start..][0..length]);
    }
    if (crc.digest() != expected) return error.ChecksumMismatch;
}

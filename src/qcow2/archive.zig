const std = @import("std");
const deflate = @import("../deflate.zig");
const zstd = @import("../zstd.zig");
const format = @import("format.zig");

pub const Error = format.Error || deflate.Error || zstd.Error ||
    std.mem.Allocator.Error;

pub const OpenOptions = struct {
    backing_file: ?[]const u8 = null,
    external_data_file: ?[]const u8 = null,
    max_l1_entries: usize = 1 << 22,
    max_cluster_size: usize = 2 * 1024 * 1024,
    max_compressed_bytes: usize = 4 * 1024 * 1024,
};

const Mapping = struct {
    entry: u64 = 0,
    bitmap: u64 = 0,
};

pub const Archive = struct {
    bytes: []const u8,
    header: format.Header,
    backing_file: ?[]const u8,
    external_data_file: ?[]const u8,
    max_compressed_bytes: usize,

    pub fn init(input: []const u8, options: OpenOptions) Error!Archive {
        const header = try format.parseHeader(input);
        if (header.cluster_size > options.max_cluster_size)
            return error.OutputLimitExceeded;
        if (header.l1_size > options.max_l1_entries)
            return error.OutputLimitExceeded;
        if (header.virtual_size != 0 and header.l1_size == 0)
            return error.InvalidQcow2;
        const guest_clusters = std.math.divCeil(
            u64,
            header.virtual_size,
            @intCast(header.cluster_size),
        ) catch return error.IntegerOverflow;
        const required_l1_entries = std.math.divCeil(
            u64,
            guest_clusters,
            @intCast(header.l2Entries()),
        ) catch return error.IntegerOverflow;
        if (required_l1_entries > @as(u64, @intCast(header.l1_size)))
            return error.InvalidQcow2;
        if (header.l1_table_offset & (header.cluster_size - 1) != 0)
            return error.InvalidQcow2;
        const l1_bytes = std.math.mul(usize, header.l1_size, 8) catch
            return error.IntegerOverflow;
        const l1_offset = std.math.cast(usize, header.l1_table_offset) orelse
            return error.IntegerOverflow;
        const l1_end = std.math.add(usize, l1_offset, l1_bytes) catch
            return error.IntegerOverflow;
        if (header.l1_size == 0) {
            if (l1_offset != 0) return error.InvalidQcow2;
        } else if (l1_offset < header.header_length or l1_end > input.len) {
            return error.TruncatedFrame;
        }
        if (header.hasRawExternalDataFile() and header.hasBackingFile())
            return error.InvalidQcow2;
        return .{
            .bytes = input,
            .header = header,
            .backing_file = options.backing_file,
            .external_data_file = options.external_data_file,
            .max_compressed_bytes = options.max_compressed_bytes,
        };
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        const size = std.math.cast(usize, self.header.virtual_size) orelse
            return error.IntegerOverflow;
        if (size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, size);
        errdefer allocator.free(output);
        try self.readRangeInto(allocator, 0, output);
        return output;
    }

    pub fn readRangeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        offset: usize,
        length: usize,
        max_output_len: usize,
    ) Error![]u8 {
        if (length > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, length);
        errdefer allocator.free(output);
        try self.readRangeInto(allocator, offset, output);
        return output;
    }

    pub fn readRangeInto(
        self: Archive,
        allocator: std.mem.Allocator,
        offset: usize,
        output: []u8,
    ) Error!void {
        const range_end = std.math.add(usize, offset, output.len) catch
            return error.IntegerOverflow;
        if (range_end > self.header.virtual_size) return error.RangeOutOfBounds;
        var position = offset;
        var written: usize = 0;
        while (written < output.len) {
            const cluster_index = position >> @intCast(self.header.cluster_bits);
            const cluster_offset = position & (self.header.cluster_size - 1);
            const length = @min(
                output.len - written,
                self.header.cluster_size - cluster_offset,
            );
            const mapping = try self.getMapping(cluster_index);
            try self.readMappedRange(
                allocator,
                cluster_index,
                cluster_offset,
                output[written..][0..length],
                mapping,
            );
            position += length;
            written += length;
        }
    }

    fn getMapping(self: Archive, cluster_index: usize) Error!Mapping {
        const l2_entries = self.header.l2Entries();
        const l1_index = cluster_index / l2_entries;
        if (l1_index >= self.header.l1_size) return .{};
        const l1_offset = std.math.cast(usize, self.header.l1_table_offset) orelse
            return error.IntegerOverflow;
        const l1_entry = format.readU64Be(self.bytes, l1_offset + l1_index * 8);
        if (l1_entry & format.l1_reserved_mask != 0) return error.InvalidQcow2;
        const l2_table_offset_u64 = l1_entry & format.offset_mask;
        if (l2_table_offset_u64 == 0) {
            if (l1_entry & format.copied_flag != 0) return error.InvalidQcow2;
            return .{};
        }
        if (l2_table_offset_u64 & (self.header.cluster_size - 1) != 0)
            return error.InvalidQcow2;
        const l2_table_offset = std.math.cast(usize, l2_table_offset_u64) orelse
            return error.IntegerOverflow;
        const l2_end = std.math.add(
            usize,
            l2_table_offset,
            self.header.cluster_size,
        ) catch return error.IntegerOverflow;
        if (l2_end > self.bytes.len) return error.TruncatedFrame;
        const l2_index = cluster_index % l2_entries;
        const entry_offset = l2_table_offset + l2_index * self.header.l2EntrySize();
        return .{
            .entry = format.readU64Be(self.bytes, entry_offset),
            .bitmap = if (self.header.hasExtendedL2())
                format.readU64Be(self.bytes, entry_offset + 8)
            else
                0,
        };
    }

    fn readMappedRange(
        self: Archive,
        allocator: std.mem.Allocator,
        cluster_index: usize,
        cluster_offset: usize,
        output: []u8,
        mapping: Mapping,
    ) Error!void {
        if (mapping.entry & format.compressed_flag != 0) {
            if (mapping.entry & format.copied_flag != 0 or
                self.header.hasExternalDataFile() or mapping.bitmap != 0)
                return error.InvalidQcow2;
            const decoded = try self.decodeCompressedCluster(allocator, mapping.entry);
            defer allocator.free(decoded);
            @memcpy(output, decoded[cluster_offset..][0..output.len]);
            return;
        }
        if (mapping.entry & format.l2_standard_reserved_mask != 0)
            return error.InvalidQcow2;
        const host_offset = mapping.entry & format.offset_mask;
        if (host_offset & (self.header.cluster_size - 1) != 0)
            return error.InvalidQcow2;
        const guest_cluster_offset = cluster_index * self.header.cluster_size;
        if (host_offset == 0 and
            mapping.entry & format.copied_flag != 0 and
            !self.header.hasExternalDataFile())
            return error.InvalidQcow2;
        if (self.header.hasExternalDataFile() and
            (host_offset != 0 or mapping.entry & format.copied_flag != 0) and
            (host_offset != guest_cluster_offset or
                mapping.entry & format.copied_flag == 0))
            return error.InvalidQcow2;
        if (!self.header.hasExtendedL2()) {
            if (self.header.version < 3 and mapping.entry & format.zero_flag != 0)
                return error.InvalidQcow2;
            if (mapping.entry & format.zero_flag != 0) {
                @memset(output, 0);
                return;
            }
            if (host_offset == 0) {
                if (mapping.entry & format.copied_flag != 0) {
                    if (!self.header.hasExternalDataFile())
                        return error.InvalidQcow2;
                    try self.readNormal(
                        host_offset,
                        cluster_index,
                        cluster_offset,
                        output,
                        mapping.entry,
                    );
                    return;
                }
                try self.readUnallocated(
                    cluster_index * self.header.cluster_size + cluster_offset,
                    output,
                );
                return;
            }
            try self.readNormal(host_offset, cluster_index, cluster_offset, output, mapping.entry);
            return;
        }

        if (mapping.entry & format.zero_flag != 0) return error.InvalidQcow2;
        const allocated = @as(u32, @truncate(mapping.bitmap));
        const zeroes = @as(u32, @truncate(mapping.bitmap >> 32));
        if (allocated & zeroes != 0) return error.InvalidQcow2;
        const subcluster_size = self.header.cluster_size / 32;
        var local_offset = cluster_offset;
        var output_position: usize = 0;
        while (output_position < output.len) {
            const subcluster_index = local_offset / subcluster_size;
            const in_subcluster = local_offset % subcluster_size;
            const length = @min(
                output.len - output_position,
                subcluster_size - in_subcluster,
            );
            const mask = @as(u32, 1) << @intCast(subcluster_index);
            const destination = output[output_position..][0..length];
            if (zeroes & mask != 0) {
                @memset(destination, 0);
            } else if (allocated & mask != 0) {
                if (host_offset == 0 and !self.header.hasExternalDataFile())
                    return error.InvalidQcow2;
                try self.readNormal(
                    host_offset,
                    cluster_index,
                    local_offset,
                    destination,
                    mapping.entry,
                );
            } else {
                try self.readUnallocated(
                    cluster_index * self.header.cluster_size + local_offset,
                    destination,
                );
            }
            local_offset += length;
            output_position += length;
        }
    }

    fn readNormal(
        self: Archive,
        host_offset_u64: u64,
        cluster_index: usize,
        cluster_offset: usize,
        output: []u8,
        entry: u64,
    ) Error!void {
        const guest_cluster_offset = cluster_index * self.header.cluster_size;
        const source = if (self.header.hasExternalDataFile()) blk: {
            if (entry & format.copied_flag == 0 or
                host_offset_u64 != guest_cluster_offset)
                return error.InvalidQcow2;
            break :blk self.external_data_file orelse
                return error.MissingQcow2DataFile;
        } else blk: {
            if (host_offset_u64 & (self.header.cluster_size - 1) != 0)
                return error.InvalidQcow2;
            break :blk self.bytes;
        };
        const start_u64 = std.math.add(u64, host_offset_u64, cluster_offset) catch
            return error.IntegerOverflow;
        const start = std.math.cast(usize, start_u64) orelse
            return error.IntegerOverflow;
        const end = std.math.add(usize, start, output.len) catch
            return error.IntegerOverflow;
        if (end > source.len) return error.TruncatedFrame;
        @memcpy(output, source[start..end]);
    }

    fn readUnallocated(
        self: Archive,
        virtual_offset: usize,
        output: []u8,
    ) Error!void {
        if (!self.header.hasBackingFile()) {
            @memset(output, 0);
            return;
        }
        const backing = self.backing_file orelse return error.MissingQcow2BackingFile;
        if (virtual_offset >= backing.len) {
            @memset(output, 0);
            return;
        }
        const available = @min(output.len, backing.len - virtual_offset);
        @memcpy(output[0..available], backing[virtual_offset..][0..available]);
        @memset(output[available..], 0);
    }

    fn decodeCompressedCluster(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: u64,
    ) Error![]u8 {
        const size_shift = 62 - (self.header.cluster_bits - 8);
        const size_mask = (@as(u64, 1) << @intCast(self.header.cluster_bits - 8)) - 1;
        const offset_mask = (@as(u64, 1) << @intCast(size_shift)) - 1;
        const host_offset_u64 = entry & offset_mask;
        if (host_offset_u64 >> 56 != 0) return error.InvalidQcow2;
        const sectors = ((entry >> @intCast(size_shift)) & size_mask) + 1;
        const span_u64 = sectors * 512 - (host_offset_u64 & 511);
        const host_offset = std.math.cast(usize, host_offset_u64) orelse
            return error.IntegerOverflow;
        const span = std.math.cast(usize, span_u64) orelse
            return error.IntegerOverflow;
        if (span > self.max_compressed_bytes) return error.OutputLimitExceeded;
        const end = std.math.add(usize, host_offset, span) catch
            return error.IntegerOverflow;
        if (end > self.bytes.len) return error.TruncatedFrame;
        const compressed = self.bytes[host_offset..end];
        return switch (self.header.compression_type) {
            .zlib => decodeRawDeflateAlloc(
                allocator,
                compressed,
                self.header.cluster_size,
            ),
            .zstd => decodeZstdAlloc(
                allocator,
                compressed,
                self.header.cluster_size,
            ),
        };
    }
};

fn decodeRawDeflateAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
) Error![]u8 {
    const output = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(output);
    const result = try deflate.decodeRawAuto(input, output);
    if (result.output_written != expected_size) return error.SizeMismatch;
    return output;
}

fn decodeZstdAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
) Error![]u8 {
    const output = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(output);
    var output_position: usize = 0;
    var iterator = zstd.iterateNativeStream(input);
    while (output_position < output.len) {
        const element = (try iterator.next()) orelse return error.TruncatedFrame;
        const frame = switch (element) {
            .frame => |value| value.bytes,
            .skippable => return error.InvalidQcow2,
        };
        const decoded = try zstd.decodeFrameAllocLimited(
            allocator,
            frame,
            output.len - output_position,
        );
        defer allocator.free(decoded);
        if (decoded.len == 0 or decoded.len > output.len - output_position)
            return error.SizeMismatch;
        @memcpy(output[output_position..][0..decoded.len], decoded);
        output_position += decoded.len;
    }
    return output;
}

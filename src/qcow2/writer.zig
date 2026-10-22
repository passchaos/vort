const std = @import("std");
const deflate = @import("../deflate.zig");
const zstd = @import("../zstd.zig");
const format = @import("format.zig");

pub const Error = format.Error || deflate.Error || zstd.Error ||
    std.mem.Allocator.Error;

pub const Compression = enum {
    none,
    zlib,
    zstd,
};

pub const EncodeOptions = struct {
    version: u32 = 3,
    cluster_bits: u5 = 16,
    compression: Compression = .zlib,
    /// Logical raw bytes inherited by unallocated guest clusters.
    backing_file: ?[]const u8 = null,
    /// QCOW2 backing path recorded in the image. Required with backing_file.
    backing_file_name: ?[]const u8 = null,
};

pub const ExternalDataEncodeOptions = struct {
    cluster_bits: u5 = 16,
    data_file_name: []const u8,
};

pub const EncodedExternalData = struct {
    image: []u8,
    data_file: []u8,

    pub fn deinit(self: *EncodedExternalData, allocator: std.mem.Allocator) void {
        allocator.free(self.image);
        allocator.free(self.data_file);
        self.* = undefined;
    }
};

const RecordKind = enum { unallocated, zero, normal, compressed };

const Record = struct {
    kind: RecordKind,
    payload: []u8,
    host_cluster: ?usize = null,

    fn deinit(self: Record, allocator: std.mem.Allocator) void {
        allocator.free(self.payload);
    }
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    if ((options.version != 2 and options.version != 3) or
        options.cluster_bits < format.min_cluster_bits or
        options.cluster_bits > format.max_cluster_bits or
        (options.compression == .zstd and options.version != 3))
        return error.InvalidQcow2;
    const cluster_size = @as(usize, 1) << options.cluster_bits;
    const backing_layout = try validateBackingOptions(options, cluster_size);
    const sector_remainder = input.len & 511;
    const virtual_size = if (sector_remainder == 0)
        input.len
    else
        std.math.add(usize, input.len, 512 - sector_remainder) catch
            return error.IntegerOverflow;
    const guest_clusters = std.math.divCeil(usize, virtual_size, cluster_size) catch
        return error.IntegerOverflow;
    const l2_entries = cluster_size / 8;
    const l1_size = std.math.divCeil(usize, guest_clusters, l2_entries) catch
        return error.IntegerOverflow;
    const l1_bytes = std.math.mul(usize, l1_size, 8) catch
        return error.IntegerOverflow;
    const l1_table_clusters = if (l1_size == 0)
        0
    else
        std.math.divCeil(usize, l1_bytes, cluster_size) catch
            return error.IntegerOverflow;

    var records: std.ArrayList(Record) = .empty;
    defer {
        for (records.items) |record| record.deinit(allocator);
        records.deinit(allocator);
    }
    for (0..guest_clusters) |cluster_index| {
        const input_start = cluster_index * cluster_size;
        const input_end = @min(input.len, input_start + cluster_size);
        const logical_end = @min(virtual_size, input_start + cluster_size);
        const logical_len = logical_end - input_start;
        const record = try makeRecordAlloc(
            allocator,
            input[input_start..input_end],
            input_start,
            logical_len,
            cluster_size,
            options,
        );
        records.append(allocator, record) catch |err| {
            record.deinit(allocator);
            return err;
        };
    }

    const l2_base_cluster = std.math.add(usize, 3, l1_table_clusters) catch
        return error.IntegerOverflow;
    const metadata_clusters = std.math.add(usize, l2_base_cluster, l1_size) catch
        return error.IntegerOverflow;
    var next_host_cluster = metadata_clusters;
    for (records.items) |*record| {
        if (record.kind == .unallocated or record.kind == .zero) continue;
        record.host_cluster = next_host_cluster;
        next_host_cluster = std.math.add(usize, next_host_cluster, 1) catch
            return error.IntegerOverflow;
    }
    const refcount_entries = cluster_size / 2;
    if (next_host_cluster > refcount_entries) return error.OutputLimitExceeded;
    const output_size = std.math.mul(usize, next_host_cluster, cluster_size) catch
        return error.IntegerOverflow;
    const output = try allocator.alloc(u8, output_size);
    errdefer allocator.free(output);
    @memset(output, 0);

    writeHeader(output, virtual_size, l1_size, options, backing_layout);
    const refcount_table_offset = cluster_size;
    const refcount_block_offset = 2 * cluster_size;
    const l1_offset = 3 * cluster_size;
    format.writeU64Be(output, refcount_table_offset, refcount_block_offset);
    for (0..next_host_cluster) |cluster_index|
        std.mem.writeInt(
            u16,
            output[refcount_block_offset + cluster_index * 2 ..][0..2],
            1,
            .big,
        );

    for (0..l1_size) |l1_index| {
        const l2_host_cluster = l2_base_cluster + l1_index;
        format.writeU64Be(
            output,
            l1_offset + l1_index * 8,
            format.copied_flag | @as(u64, l2_host_cluster * cluster_size),
        );
    }
    const size_shift = 62 - (@as(u32, options.cluster_bits) - 8);
    for (records.items, 0..) |record, guest_cluster| {
        const l1_index = guest_cluster / l2_entries;
        const l2_index = guest_cluster % l2_entries;
        const l2_offset = (l2_base_cluster + l1_index) * cluster_size + l2_index * 8;
        const entry: u64 = switch (record.kind) {
            .unallocated => 0,
            .zero => if (options.version == 3) format.zero_flag else 0,
            .normal => format.copied_flag |
                @as(u64, record.host_cluster.? * cluster_size),
            .compressed => blk: {
                const sectors = std.math.divCeil(
                    usize,
                    record.payload.len,
                    512,
                ) catch return error.IntegerOverflow;
                break :blk format.compressed_flag |
                    (@as(u64, sectors - 1) << @intCast(size_shift)) |
                    @as(u64, record.host_cluster.? * cluster_size);
            },
        };
        format.writeU64Be(output, l2_offset, entry);
        if (record.host_cluster) |host_cluster| {
            const host_offset = host_cluster * cluster_size;
            @memcpy(output[host_offset..][0..record.payload.len], record.payload);
        }
    }
    return output;
}

pub fn encodeExternalDataAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: ExternalDataEncodeOptions,
) Error!EncodedExternalData {
    if (options.cluster_bits < format.min_cluster_bits or
        options.cluster_bits > format.max_cluster_bits)
    {
        return error.InvalidQcow2;
    }
    const cluster_size = @as(usize, 1) << options.cluster_bits;
    const extension_end = try validateExternalDataName(
        options.data_file_name,
        cluster_size,
    );
    const sector_remainder = input.len & 511;
    const virtual_size = if (sector_remainder == 0)
        input.len
    else
        std.math.add(usize, input.len, 512 - sector_remainder) catch
            return error.IntegerOverflow;
    const guest_clusters = std.math.divCeil(usize, virtual_size, cluster_size) catch
        return error.IntegerOverflow;
    const l2_entries = cluster_size / 8;
    const l1_size = std.math.divCeil(usize, guest_clusters, l2_entries) catch
        return error.IntegerOverflow;
    const l1_bytes = std.math.mul(usize, l1_size, 8) catch
        return error.IntegerOverflow;
    const l1_table_clusters = if (l1_size == 0)
        0
    else
        std.math.divCeil(usize, l1_bytes, cluster_size) catch
            return error.IntegerOverflow;
    const l2_base_cluster = std.math.add(usize, 3, l1_table_clusters) catch
        return error.IntegerOverflow;
    const metadata_clusters = std.math.add(usize, l2_base_cluster, l1_size) catch
        return error.IntegerOverflow;
    if (metadata_clusters > cluster_size / 2) return error.OutputLimitExceeded;
    const metadata_size = std.math.mul(usize, metadata_clusters, cluster_size) catch
        return error.IntegerOverflow;
    const image = try allocator.alloc(u8, metadata_size);
    errdefer allocator.free(image);
    @memset(image, 0);
    const data_file = try allocator.alloc(u8, virtual_size);
    errdefer allocator.free(data_file);
    @memset(data_file, 0);
    @memcpy(data_file[0..input.len], input);

    const base_options = EncodeOptions{
        .version = 3,
        .cluster_bits = options.cluster_bits,
        .compression = .none,
    };
    writeHeader(image, virtual_size, l1_size, base_options, null);
    format.writeU64Be(image, 72, format.incompat_data_file);
    format.writeU64Be(image, 88, format.autoclear_data_file_raw);
    format.writeU32Be(image, 112, 0x4441_5441);
    format.writeU32Be(image, 116, @intCast(options.data_file_name.len));
    @memcpy(image[120..][0..options.data_file_name.len], options.data_file_name);
    _ = extension_end;

    const refcount_table_offset = cluster_size;
    const refcount_block_offset = 2 * cluster_size;
    const l1_offset = 3 * cluster_size;
    format.writeU64Be(image, refcount_table_offset, refcount_block_offset);
    for (0..metadata_clusters) |cluster_index|
        std.mem.writeInt(
            u16,
            image[refcount_block_offset + cluster_index * 2 ..][0..2],
            1,
            .big,
        );
    for (0..l1_size) |l1_index| {
        const l2_host_cluster = l2_base_cluster + l1_index;
        format.writeU64Be(
            image,
            l1_offset + l1_index * 8,
            format.copied_flag | @as(u64, l2_host_cluster * cluster_size),
        );
    }
    for (0..guest_clusters) |guest_cluster| {
        const guest_offset = std.math.mul(usize, guest_cluster, cluster_size) catch
            return error.IntegerOverflow;
        const guest_offset_u64: u64 = @intCast(guest_offset);
        if (guest_offset_u64 & ~format.offset_mask != 0)
            return error.OutputLimitExceeded;
        const l1_index = guest_cluster / l2_entries;
        const l2_index = guest_cluster % l2_entries;
        const l2_offset = (l2_base_cluster + l1_index) * cluster_size + l2_index * 8;
        format.writeU64Be(
            image,
            l2_offset,
            format.copied_flag | guest_offset_u64,
        );
    }
    return .{ .image = image, .data_file = data_file };
}

fn makeRecordAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    input_offset: usize,
    logical_len: usize,
    cluster_size: usize,
    options: EncodeOptions,
) Error!Record {
    const cluster = try allocator.alloc(u8, cluster_size);
    errdefer allocator.free(cluster);
    @memset(cluster, 0);
    @memcpy(cluster[0..input.len], input);
    if (options.backing_file) |backing|
        if (matchesBacking(cluster[0..logical_len], backing, input_offset))
            return .{ .kind = .unallocated, .payload = cluster };
    if (allZero(cluster)) return .{
        .kind = if (options.backing_file != null and options.version == 2)
            .normal
        else
            .zero,
        .payload = cluster,
    };
    if (options.compression == .none)
        return .{ .kind = .normal, .payload = cluster };
    const compressed = switch (options.compression) {
        .zlib => try encodeRawDeflateAlloc(allocator, cluster),
        .zstd => try zstd.encodeFrameWithLevelAndOptionsAlloc(
            allocator,
            cluster,
            3,
            .{ .include_content_size = false, .content_checksum = false },
        ),
        .none => unreachable,
    };
    if (compressed.len >= cluster_size) {
        allocator.free(compressed);
        return .{ .kind = .normal, .payload = cluster };
    }
    allocator.free(cluster);
    return .{ .kind = .compressed, .payload = compressed };
}

fn writeHeader(
    output: []u8,
    virtual_size: usize,
    l1_size: usize,
    options: EncodeOptions,
    backing_layout: ?BackingLayout,
) void {
    const cluster_size = @as(usize, 1) << options.cluster_bits;
    format.writeU32Be(output, 0, format.magic);
    format.writeU32Be(output, 4, options.version);
    if (backing_layout) |layout| {
        format.writeU64Be(output, 8, layout.name_offset);
        format.writeU32Be(output, 16, @intCast(options.backing_file_name.?.len));
    }
    format.writeU32Be(output, 20, options.cluster_bits);
    format.writeU64Be(output, 24, virtual_size);
    format.writeU32Be(output, 32, 0);
    format.writeU32Be(output, 36, @intCast(l1_size));
    format.writeU64Be(output, 40, if (l1_size == 0) 0 else 3 * cluster_size);
    format.writeU64Be(output, 48, cluster_size);
    format.writeU32Be(output, 56, 1);
    if (options.version == 3) {
        format.writeU64Be(
            output,
            72,
            if (options.compression == .zstd)
                format.incompat_compression
            else
                0,
        );
        format.writeU32Be(output, 96, 4);
        format.writeU32Be(output, 100, 112);
        output[104] = switch (options.compression) {
            .zstd => 1,
            else => 0,
        };
    }
    if (backing_layout) |layout| {
        format.writeU32Be(output, layout.extension_offset, 0xe279_2aca);
        format.writeU32Be(output, layout.extension_offset + 4, 3);
        @memcpy(output[layout.extension_offset + 8 ..][0..3], "raw");
        @memcpy(
            output[layout.name_offset..][0..options.backing_file_name.?.len],
            options.backing_file_name.?,
        );
    }
}

const BackingLayout = struct {
    extension_offset: usize,
    name_offset: usize,
};

fn validateBackingOptions(
    options: EncodeOptions,
    cluster_size: usize,
) Error!?BackingLayout {
    if ((options.backing_file == null) != (options.backing_file_name == null))
        return error.InvalidQcow2;
    const name = options.backing_file_name orelse return null;
    if (name.len == 0 or name.len > 1023 or std.mem.indexOfScalar(u8, name, 0) != null)
        return error.InvalidQcow2;
    const header_length: usize = if (options.version == 3) 112 else 72;
    const extension_end = std.mem.alignForward(usize, header_length + 8 + 3, 8);
    const name_offset = extension_end + 8;
    if (name_offset > cluster_size or name.len > cluster_size - name_offset)
        return error.InvalidQcow2;
    return .{
        .extension_offset = header_length,
        .name_offset = name_offset,
    };
}

fn validateExternalDataName(name: []const u8, cluster_size: usize) Error!usize {
    if (name.len == 0 or name.len > std.math.maxInt(u32) or
        std.mem.indexOfScalar(u8, name, 0) != null)
    {
        return error.InvalidQcow2;
    }
    const extension_end = std.mem.alignForward(usize, 120 + name.len, 8);
    if (extension_end > cluster_size or cluster_size - extension_end < 8)
        return error.InvalidQcow2;
    return extension_end;
}

fn matchesBacking(
    cluster: []const u8,
    backing: []const u8,
    backing_offset: usize,
) bool {
    for (cluster, 0..) |byte, index| {
        const offset = backing_offset + index;
        const inherited = if (offset < backing.len) backing[offset] else 0;
        if (byte != inherited) return false;
    }
    return true;
}

fn encodeRawDeflateAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) Error![]u8 {
    var options = deflate.optionsForLevel(.default);
    options.lz77_options.window_len = 4096;
    return deflate.encodeRawBestAlloc(allocator, input, options);
}

fn allZero(input: []const u8) bool {
    for (input) |byte| if (byte != 0) return false;
    return true;
}

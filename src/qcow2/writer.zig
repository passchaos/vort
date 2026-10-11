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
};

const RecordKind = enum { zero, normal, compressed };

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
        const cluster = try allocator.alloc(u8, cluster_size);
        @memset(cluster, 0);
        @memcpy(cluster[0 .. input_end - input_start], input[input_start..input_end]);
        if (allZero(cluster)) {
            try records.append(allocator, .{ .kind = .zero, .payload = cluster });
            continue;
        }
        if (options.compression == .none) {
            try records.append(allocator, .{ .kind = .normal, .payload = cluster });
            continue;
        }
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
            try records.append(allocator, .{ .kind = .normal, .payload = cluster });
        } else {
            allocator.free(cluster);
            try records.append(allocator, .{ .kind = .compressed, .payload = compressed });
        }
    }

    const l2_base_cluster = std.math.add(usize, 3, l1_table_clusters) catch
        return error.IntegerOverflow;
    const metadata_clusters = std.math.add(usize, l2_base_cluster, l1_size) catch
        return error.IntegerOverflow;
    var next_host_cluster = metadata_clusters;
    for (records.items) |*record| {
        if (record.kind == .zero) continue;
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

    writeHeader(output, virtual_size, l1_size, options);
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

fn writeHeader(
    output: []u8,
    virtual_size: usize,
    l1_size: usize,
    options: EncodeOptions,
) void {
    const cluster_size = @as(usize, 1) << options.cluster_bits;
    format.writeU32Be(output, 0, format.magic);
    format.writeU32Be(output, 4, options.version);
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

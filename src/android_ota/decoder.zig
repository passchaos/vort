const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const xz = @import("../xz.zig");
const format = @import("format.zig");

pub const Error = format.Error || bzip2.Error || xz.Error ||
    std.mem.Allocator.Error;

pub const Options = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_operation_output_len: usize = 1024 * 1024 * 1024,
    verify_partition_hash: bool = true,
    verify_source_hashes: bool = true,
    discard_as_zero: bool = false,
};

pub const View = struct {
    bytes: []const u8,
    data_offset: usize,
    block_size: usize,
    partitions: []const format.Partition,
    operations: []const format.Operation,
    extents: []const format.Extent,

    fn partitionOperations(
        self: View,
        partition: format.Partition,
    ) []const format.Operation {
        return self.operations[partition.operation_start..][0..partition.operation_count];
    }

    fn sourceExtents(
        self: View,
        operation: format.Operation,
    ) []const format.Extent {
        return self.extents[operation.src_extent_start..][0..operation.src_extent_count];
    }

    fn destinationExtents(
        self: View,
        operation: format.Operation,
    ) []const format.Extent {
        return self.extents[operation.dst_extent_start..][0..operation.dst_extent_count];
    }

    fn operationBlob(self: View, operation: format.Operation) []const u8 {
        const start = self.data_offset + @as(usize, @intCast(operation.data_offset));
        return self.bytes[start..][0..@intCast(operation.data_length)];
    }
};

pub fn readPartitionRangeInto(
    view: View,
    allocator: std.mem.Allocator,
    partition_index: usize,
    source: ?[]const u8,
    offset: u64,
    output: []u8,
    options: Options,
) Error!void {
    if (partition_index >= view.partitions.len)
        return error.RangeOutOfBounds;
    if (output.len > options.max_output_len)
        return error.OutputLimitExceeded;
    const partition = view.partitions[partition_index];
    const range_end = std.math.add(u64, offset, output.len) catch
        return error.IntegerOverflow;
    if (range_end > partition.new_info.size)
        return error.RangeOutOfBounds;
    const source_bytes = try validateSource(
        view,
        partition,
        source,
        options.verify_source_hashes,
    );
    const covered = try allocator.alloc(u8, output.len);
    defer allocator.free(covered);
    @memset(covered, 0);

    for (view.partitionOperations(partition)) |operation| {
        const destinations = view.destinationExtents(operation);
        if (!extentsIntersect(
            destinations,
            view.block_size,
            offset,
            range_end,
        )) continue;
        if (operation.kind == .zero or operation.kind == .discard) {
            if (operation.kind == .discard and !options.discard_as_zero)
                return error.UnsupportedAndroidOtaOperation;
            try copyOperationRange(
                null,
                destinations,
                view.block_size,
                offset,
                output,
                covered,
            );
            continue;
        }
        var owned: ?[]u8 = null;
        defer if (owned) |bytes| allocator.free(bytes);
        const operation_bytes: []const u8 = switch (operation.kind) {
            .replace => view.operationBlob(operation),
            .replace_bz => blk: {
                const expected = try operationOutputLength(
                    destinations,
                    view.block_size,
                    options.max_operation_output_len,
                );
                const decoded = try bzip2.decodeAllocLimited(
                    allocator,
                    view.operationBlob(operation),
                    expected,
                );
                owned = decoded;
                if (decoded.len != expected) return error.SizeMismatch;
                break :blk decoded;
            },
            .replace_xz => blk: {
                const expected = try operationOutputLength(
                    destinations,
                    view.block_size,
                    options.max_operation_output_len,
                );
                const decoded = try xz.decodeAllocLimited(
                    allocator,
                    view.operationBlob(operation),
                    expected,
                );
                owned = decoded;
                if (decoded.len != expected) return error.SizeMismatch;
                break :blk decoded;
            },
            .source_copy => blk: {
                const decoded = try readSourceExtentsAlloc(
                    allocator,
                    source_bytes orelse return error.MissingAndroidOtaSource,
                    view.sourceExtents(operation),
                    view.block_size,
                    options.max_operation_output_len,
                );
                owned = decoded;
                if (operation.src_sha256_hash.len != 0)
                    try verifySha256(decoded, operation.src_sha256_hash);
                break :blk decoded;
            },
            else => return error.UnsupportedAndroidOtaOperation,
        };
        try copyOperationRange(
            operation_bytes,
            destinations,
            view.block_size,
            offset,
            output,
            covered,
        );
    }
    for (covered) |value|
        if (value == 0) return error.IncompleteAndroidOtaPartition;
    if (options.verify_partition_hash and offset == 0 and
        output.len == partition.new_info.size and
        partition.new_info.hash.len != 0)
        try verifySha256(output, partition.new_info.hash);
}

fn validateSource(
    view: View,
    partition: format.Partition,
    source: ?[]const u8,
    verify_hash: bool,
) Error!?[]const u8 {
    var needs_source = false;
    for (view.partitionOperations(partition)) |operation|
        switch (operation.kind) {
            .source_copy,
            .source_bsdiff,
            .bsdiff,
            .brotli_bsdiff,
            .puffdiff,
            .zucchini,
            .lz4diff_bsdiff,
            .lz4diff_puffdiff,
            => needs_source = true,
            else => {},
        };
    if (!needs_source) return source;
    const bytes = source orelse return error.MissingAndroidOtaSource;
    const old_info = partition.old_info orelse return error.InvalidAndroidOta;
    if (bytes.len != old_info.size) return error.SizeMismatch;
    if (verify_hash and old_info.hash.len != 0)
        try verifySha256(bytes, old_info.hash);
    return bytes;
}

fn readSourceExtentsAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    extents: []const format.Extent,
    block_size: usize,
    max_output_len: usize,
) Error![]u8 {
    const length = try operationOutputLength(extents, block_size, max_output_len);
    const output = try allocator.alloc(u8, length);
    errdefer allocator.free(output);
    var written: usize = 0;
    for (extents) |extent| {
        const extent_length = std.math.mul(
            usize,
            std.math.cast(usize, extent.num_blocks) orelse
                return error.OutputLimitExceeded,
            block_size,
        ) catch return error.IntegerOverflow;
        if (extent.start_block == format.sparse_hole) {
            @memset(output[written..][0..extent_length], 0);
        } else {
            const start_u64 = std.math.mul(
                u64,
                extent.start_block,
                block_size,
            ) catch return error.IntegerOverflow;
            const start = std.math.cast(usize, start_u64) orelse
                return error.OutputLimitExceeded;
            if (start > source.len or extent_length > source.len - start)
                return error.InvalidAndroidOta;
            @memcpy(output[written..][0..extent_length], source[start..][0..extent_length]);
        }
        written += extent_length;
    }
    return output;
}

fn operationOutputLength(
    extents: []const format.Extent,
    block_size: usize,
    max_output_len: usize,
) Error!usize {
    var blocks: u64 = 0;
    for (extents) |extent|
        blocks = std.math.add(u64, blocks, extent.num_blocks) catch
            return error.IntegerOverflow;
    const length_u64 = std.math.mul(u64, blocks, block_size) catch
        return error.IntegerOverflow;
    const length = std.math.cast(usize, length_u64) orelse
        return error.OutputLimitExceeded;
    if (length > max_output_len) return error.OutputLimitExceeded;
    return length;
}

fn extentsIntersect(
    extents: []const format.Extent,
    block_size: usize,
    range_start: u64,
    range_end: u64,
) bool {
    for (extents) |extent| {
        const start = extent.start_block * block_size;
        const end = start + extent.num_blocks * block_size;
        if (start < range_end and end > range_start) return true;
    }
    return false;
}

fn copyOperationRange(
    operation_bytes: ?[]const u8,
    extents: []const format.Extent,
    block_size: usize,
    range_start: u64,
    output: []u8,
    covered: []u8,
) Error!void {
    const range_end = range_start + output.len;
    var operation_offset: usize = 0;
    for (extents) |extent| {
        const extent_start = extent.start_block * block_size;
        const extent_length_u64 = extent.num_blocks * block_size;
        const extent_end = extent_start + extent_length_u64;
        const extent_length: usize = @intCast(extent_length_u64);
        const copy_start = @max(extent_start, range_start);
        const copy_end = @min(extent_end, range_end);
        if (copy_start < copy_end) {
            const destination_start: usize = @intCast(copy_start - range_start);
            const length: usize = @intCast(copy_end - copy_start);
            for (covered[destination_start..][0..length]) |value|
                if (value != 0) return error.InvalidAndroidOta;
            @memset(covered[destination_start..][0..length], 1);
            if (operation_bytes) |bytes| {
                const source_start = operation_offset + @as(usize, @intCast(copy_start - extent_start));
                if (source_start > bytes.len or length > bytes.len - source_start)
                    return error.SizeMismatch;
                @memcpy(
                    output[destination_start..][0..length],
                    bytes[source_start..][0..length],
                );
            } else {
                @memset(output[destination_start..][0..length], 0);
            }
        }
        operation_offset = std.math.add(usize, operation_offset, extent_length) catch
            return error.IntegerOverflow;
    }
    if (operation_bytes) |bytes|
        if (operation_offset != bytes.len) return error.SizeMismatch;
}

fn verifySha256(bytes: []const u8, expected: []const u8) Error!void {
    if (expected.len != 32) return error.InvalidAndroidOta;
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
    if (!std.mem.eql(u8, &actual, expected)) return error.ChecksumMismatch;
}

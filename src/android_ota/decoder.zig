const std = @import("std");
const br = @import("../br.zig");
const bzip2 = @import("../bzip2.zig");
const xz = @import("../xz.zig");
const bsdiff = @import("bsdiff.zig");
const puffin = @import("puffin.zig");
const lz4diff = @import("lz4diff.zig");
const zucchini = @import("zucchini.zig");
const format = @import("format.zig");
const source_mod = @import("source.zig");

pub const Error = format.Error || bzip2.Error || xz.Error || bsdiff.Error || puffin.Error || lz4diff.Error || zucchini.Error ||
    source_mod.Error || std.mem.Allocator.Error;

pub const Options = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_operation_output_len: usize = 1024 * 1024 * 1024,
    max_operation_blob_len: usize = std.math.maxInt(usize),
    max_bsdiff_control_bytes: usize = 64 * 1024 * 1024,
    max_puffin_header_len: usize = 16 * 1024 * 1024,
    max_puffin_extents: usize = 1 << 20,
    max_puff_stream_len: usize = 1024 * 1024 * 1024,
    max_lz4diff_header_len: usize = 16 * 1024 * 1024,
    max_lz4diff_blocks: usize = 1 << 20,
    max_lz4diff_decompressed_len: usize = 1024 * 1024 * 1024,
    max_zucchini_patch_len: usize = 1024 * 1024 * 1024,
    max_zucchini_elements: usize = 1 << 20,
    max_zucchini_equivalences: usize = 1 << 24,
    max_zucchini_target_pools: usize = 1 << 20,
    max_zucchini_elf_sections: usize = 1 << 20,
    max_zucchini_pe_sections: usize = 1 << 20,
    max_zucchini_pe_reloc_blocks: usize = 1 << 20,
    max_zucchini_dex_map_items: usize = 21,
    max_zucchini_dex_items: usize = 1 << 24,
    max_zucchini_references: usize = 1 << 24,
    max_zucchini_targets: usize = 1 << 24,
    verify_partition_hash: bool = true,
    verify_source_hashes: bool = true,
    discard_as_zero: bool = false,
};

pub const Input = union(enum) {
    bytes: []const u8,
    source: source_mod.Source,

    fn len(self: Input) u64 {
        return switch (self) {
            .bytes => |bytes| bytes.len,
            .source => |source| source.len,
        };
    }

    fn readExact(self: Input, offset: u64, output: []u8) Error!void {
        switch (self) {
            .bytes => |bytes| {
                const start = std.math.cast(usize, offset) orelse
                    return error.OutputLimitExceeded;
                if (start > bytes.len or output.len > bytes.len - start)
                    return error.TruncatedFrame;
                @memcpy(output, bytes[start..][0..output.len]);
            },
            .source => |source| try source.readExact(offset, output),
        }
    }

    fn verifySha256All(self: Input, expected: []const u8) Error!void {
        if (expected.len != 32) return error.InvalidAndroidOta;
        switch (self) {
            .bytes => |bytes| try verifySha256(bytes, expected),
            .source => |source| try source.verifySha256(0, source.len, expected),
        }
    }
};

const Blob = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    owned: ?[]u8 = null,

    fn deinit(self: *Blob) void {
        if (self.owned) |bytes| self.allocator.free(bytes);
        self.* = undefined;
    }
};

pub const View = struct {
    payload: Input,
    data_offset: u64,
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

    fn operationBlob(
        self: View,
        allocator: std.mem.Allocator,
        operation: format.Operation,
        max_length: usize,
    ) Error!Blob {
        const length = std.math.cast(usize, operation.data_length) orelse
            return error.OutputLimitExceeded;
        if (length > max_length) return error.OutputLimitExceeded;
        if (length == 0) return .{ .allocator = allocator, .bytes = "" };
        const start = std.math.add(
            u64,
            self.data_offset,
            operation.data_offset,
        ) catch return error.IntegerOverflow;
        return switch (self.payload) {
            .bytes => |bytes| blk: {
                const local = std.math.cast(usize, start) orelse
                    return error.OutputLimitExceeded;
                if (local > bytes.len or length > bytes.len - local)
                    return error.TruncatedFrame;
                break :blk .{
                    .allocator = allocator,
                    .bytes = bytes[local..][0..length],
                };
            },
            .source => |source| blk: {
                const owned = try source.readAllocLimited(
                    allocator,
                    start,
                    operation.data_length,
                    max_length,
                );
                break :blk .{
                    .allocator = allocator,
                    .bytes = owned,
                    .owned = owned,
                };
            },
        };
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
    return readPartitionRangeIntoInputs(
        view,
        allocator,
        partition_index,
        if (source) |bytes| .{ .bytes = bytes } else null,
        offset,
        output,
        options,
    );
}

pub fn readPartitionRangeIntoInputs(
    view: View,
    allocator: std.mem.Allocator,
    partition_index: usize,
    source: ?Input,
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
    const source_input = try validateSource(
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
        if (operation.kind == .replace) {
            try copyReplaceRange(
                view,
                operation,
                destinations,
                offset,
                output,
                covered,
            );
            continue;
        }
        var blob = try view.operationBlob(
            allocator,
            operation,
            options.max_operation_blob_len,
        );
        defer blob.deinit();
        var owned: ?[]u8 = null;
        defer if (owned) |bytes| allocator.free(bytes);
        const operation_bytes: []const u8 = switch (operation.kind) {
            .replace_bz => blk: {
                const expected = try operationOutputLength(
                    destinations,
                    view.block_size,
                    options.max_operation_output_len,
                );
                const decoded = try bzip2.decodeAllocLimited(
                    allocator,
                    blob.bytes,
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
                    blob.bytes,
                    expected,
                );
                owned = decoded;
                if (decoded.len != expected) return error.SizeMismatch;
                break :blk decoded;
            },
            .source_copy => blk: {
                const decoded = try readSourceExtentsAlloc(
                    allocator,
                    source_input orelse return error.MissingAndroidOtaSource,
                    view.sourceExtents(operation),
                    view.block_size,
                    options.max_operation_output_len,
                );
                owned = decoded;
                if (operation.src_sha256_hash.len != 0)
                    try verifySha256(decoded, operation.src_sha256_hash);
                break :blk decoded;
            },
            .bsdiff, .source_bsdiff, .brotli_bsdiff => blk: {
                const old_bytes = try readSourceExtentsAlloc(
                    allocator,
                    source_input orelse return error.MissingAndroidOtaSource,
                    view.sourceExtents(operation),
                    view.block_size,
                    options.max_operation_output_len,
                );
                defer allocator.free(old_bytes);
                if (operation.src_sha256_hash.len != 0)
                    try verifySha256(old_bytes, operation.src_sha256_hash);
                const expected = try operationOutputLength(
                    destinations,
                    view.block_size,
                    options.max_operation_output_len,
                );
                const decoded = try bsdiff.applyAlloc(
                    allocator,
                    old_bytes,
                    blob.bytes,
                    expected,
                    .{
                        .max_output_len = options.max_operation_output_len,
                        .max_control_bytes = options.max_bsdiff_control_bytes,
                    },
                );
                owned = decoded;
                break :blk decoded;
            },
            .puffdiff => blk: {
                const old_bytes = try readSourceExtentsAlloc(
                    allocator,
                    source_input orelse return error.MissingAndroidOtaSource,
                    view.sourceExtents(operation),
                    view.block_size,
                    options.max_operation_output_len,
                );
                defer allocator.free(old_bytes);
                if (operation.src_sha256_hash.len != 0)
                    try verifySha256(old_bytes, operation.src_sha256_hash);
                const extent_output_len = try operationOutputLength(
                    destinations,
                    view.block_size,
                    options.max_operation_output_len,
                );
                const puff_options = puffin.ApplyOptions{
                    .max_output_len = options.max_operation_output_len,
                    .max_header_len = options.max_puffin_header_len,
                    .max_extents = options.max_puffin_extents,
                    .max_puff_stream_len = options.max_puff_stream_len,
                    .max_bsdiff_control_bytes = options.max_bsdiff_control_bytes,
                };
                const actual_len = if (operation.dst_length) |length|
                    std.math.cast(usize, length) orelse
                        return error.OutputLimitExceeded
                else
                    try puffin.decodedSizeAlloc(
                        allocator,
                        blob.bytes,
                        puff_options,
                    );
                if (actual_len > extent_output_len)
                    return error.InvalidPuffinPatch;
                const patched = try puffin.applyAlloc(
                    allocator,
                    old_bytes,
                    blob.bytes,
                    actual_len,
                    puff_options,
                );
                defer allocator.free(patched);
                const decoded = try allocator.alloc(u8, extent_output_len);
                @memset(decoded, 0);
                @memcpy(decoded[0..patched.len], patched);
                owned = decoded;
                break :blk decoded;
            },
            .lz4diff_bsdiff, .lz4diff_puffdiff => blk: {
                const old_bytes = try readSourceExtentsAlloc(
                    allocator,
                    source_input orelse return error.MissingAndroidOtaSource,
                    view.sourceExtents(operation),
                    view.block_size,
                    options.max_operation_output_len,
                );
                defer allocator.free(old_bytes);
                if (operation.src_sha256_hash.len != 0)
                    try verifySha256(old_bytes, operation.src_sha256_hash);
                const expected = try operationOutputLength(
                    destinations,
                    view.block_size,
                    options.max_operation_output_len,
                );
                const decoded = try lz4diff.applyAlloc(
                    allocator,
                    old_bytes,
                    blob.bytes,
                    expected,
                    .{
                        .max_output_len = options.max_operation_output_len,
                        .max_header_len = options.max_lz4diff_header_len,
                        .max_blocks = options.max_lz4diff_blocks,
                        .max_decompressed_len = options.max_lz4diff_decompressed_len,
                        .max_bsdiff_control_bytes = options.max_bsdiff_control_bytes,
                        .max_puffin_header_len = options.max_puffin_header_len,
                        .max_puffin_extents = options.max_puffin_extents,
                        .max_puff_stream_len = options.max_puff_stream_len,
                    },
                );
                owned = decoded;
                break :blk decoded;
            },
            .zucchini => blk: {
                const old_bytes = try readSourceExtentsAlloc(
                    allocator,
                    source_input orelse return error.MissingAndroidOtaSource,
                    view.sourceExtents(operation),
                    view.block_size,
                    options.max_operation_output_len,
                );
                defer allocator.free(old_bytes);
                if (operation.src_sha256_hash.len != 0)
                    try verifySha256(old_bytes, operation.src_sha256_hash);
                const expected = try operationOutputLength(
                    destinations,
                    view.block_size,
                    options.max_operation_output_len,
                );
                const decoded_patch = try br.decodeStreamAllocLimited(
                    allocator,
                    blob.bytes,
                    options.max_zucchini_patch_len,
                );
                defer allocator.free(decoded_patch);
                const decoded = try zucchini.applyAlloc(
                    allocator,
                    old_bytes,
                    decoded_patch,
                    expected,
                    .{
                        .max_output_len = options.max_operation_output_len,
                        .max_elements = options.max_zucchini_elements,
                        .max_equivalences = options.max_zucchini_equivalences,
                        .max_target_pools = options.max_zucchini_target_pools,
                        .max_elf_sections = options.max_zucchini_elf_sections,
                        .max_pe_sections = options.max_zucchini_pe_sections,
                        .max_pe_reloc_blocks = options.max_zucchini_pe_reloc_blocks,
                        .max_dex_map_items = options.max_zucchini_dex_map_items,
                        .max_dex_items = options.max_zucchini_dex_items,
                        .max_references = options.max_zucchini_references,
                        .max_targets = options.max_zucchini_targets,
                    },
                );
                owned = decoded;
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

fn copyReplaceRange(
    view: View,
    operation: format.Operation,
    extents: []const format.Extent,
    range_start: u64,
    output: []u8,
    covered: []u8,
) Error!void {
    const range_end = std.math.add(u64, range_start, output.len) catch
        return error.IntegerOverflow;
    const blob_start = std.math.add(
        u64,
        view.data_offset,
        operation.data_offset,
    ) catch return error.IntegerOverflow;
    var operation_offset: u64 = 0;
    for (extents) |extent| {
        const extent_start = std.math.mul(
            u64,
            extent.start_block,
            view.block_size,
        ) catch return error.IntegerOverflow;
        const extent_length = std.math.mul(
            u64,
            extent.num_blocks,
            view.block_size,
        ) catch return error.IntegerOverflow;
        const extent_end = std.math.add(u64, extent_start, extent_length) catch
            return error.IntegerOverflow;
        const copy_start = @max(extent_start, range_start);
        const copy_end = @min(extent_end, range_end);
        if (copy_start < copy_end) {
            const destination_start = std.math.cast(
                usize,
                copy_start - range_start,
            ) orelse return error.OutputLimitExceeded;
            const length = std.math.cast(usize, copy_end - copy_start) orelse
                return error.OutputLimitExceeded;
            for (covered[destination_start..][0..length]) |value|
                if (value != 0) return error.InvalidAndroidOta;
            const source_relative = std.math.add(
                u64,
                operation_offset,
                copy_start - extent_start,
            ) catch return error.IntegerOverflow;
            try view.payload.readExact(
                std.math.add(u64, blob_start, source_relative) catch
                    return error.IntegerOverflow,
                output[destination_start..][0..length],
            );
            @memset(covered[destination_start..][0..length], 1);
        }
        operation_offset = std.math.add(u64, operation_offset, extent_length) catch
            return error.IntegerOverflow;
    }
    if (operation_offset != operation.data_length) return error.SizeMismatch;
}

fn validateSource(
    view: View,
    partition: format.Partition,
    source: ?Input,
    verify_hash: bool,
) Error!?Input {
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
    const input = source orelse return error.MissingAndroidOtaSource;
    const old_info = partition.old_info orelse return error.InvalidAndroidOta;
    if (input.len() != old_info.size) return error.SizeMismatch;
    if (verify_hash and old_info.hash.len != 0)
        try input.verifySha256All(old_info.hash);
    return input;
}

fn readSourceExtentsAlloc(
    allocator: std.mem.Allocator,
    source: Input,
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
            const extent_length_u64 = std.math.cast(u64, extent_length) orelse
                return error.OutputLimitExceeded;
            const end = std.math.add(u64, start_u64, extent_length_u64) catch
                return error.IntegerOverflow;
            if (end > source.len())
                return error.InvalidAndroidOta;
            try source.readExact(
                start_u64,
                output[written..][0..extent_length],
            );
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

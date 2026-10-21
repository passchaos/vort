const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const xz = @import("../xz.zig");
const format = @import("format.zig");
const protobuf = @import("protobuf.zig");

pub const Error = format.Error || protobuf.Error || bzip2.Error || xz.Error ||
    std.mem.Allocator.Error || error{InvalidLzmaOptions};

pub const Compression = enum {
    auto,
    raw,
    bzip2,
    xz,
};

pub const EncodePartition = struct {
    name: []const u8,
    data: []const u8,
};

pub const EncodeOptions = struct {
    block_size: u32 = 4096,
    operation_size: usize = 1024 * 1024,
    compression: Compression = .auto,
    sparse_zero_blocks: bool = true,
    bzip2_block_size_100k: u4 = 9,
    xz_block_size: usize = 1024 * 1024,
    max_partitions: usize = 4096,
    max_operations: usize = 1 << 24,
    max_partition_name_bytes: usize = 4096,
    max_block_size: usize = 64 * 1024 * 1024,
    max_output_len: u64 = std.math.maxInt(u64),
};

pub const PlannedPartition = struct {
    name: []const u8,
    size: u64,
    operation_start: usize,
    operation_count: usize,
    sha256: [32]u8,
};

pub const PlannedOperation = struct {
    kind: format.OperationType,
    first_block: u64,
    block_count: u64,
    data_offset: u64,
    data_len: usize,
    data: []const u8,
    owned_data: ?[]u8,
    sha256: [32]u8,
};

pub const SelectedBlob = struct {
    kind: format.OperationType,
    data: []const u8,
    owned_data: ?[]u8,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    partitions: []const EncodePartition,
    options: EncodeOptions,
) Error![]u8 {
    const block_size = try validateOptions(partitions.len, options);

    var planned_partitions: std.ArrayList(PlannedPartition) = .empty;
    defer planned_partitions.deinit(allocator);
    var operations: std.ArrayList(PlannedOperation) = .empty;
    defer {
        for (operations.items) |operation|
            if (operation.owned_data) |bytes| allocator.free(bytes);
        operations.deinit(allocator);
    }
    var data_offset: u64 = 0;
    for (partitions, 0..) |partition, partition_index| {
        if (partition.name.len == 0 or
            partition.name.len > options.max_partition_name_bytes or
            partition.data.len % block_size != 0)
            return error.InvalidAndroidOta;
        for (partitions[0..partition_index]) |previous|
            if (std.mem.eql(u8, previous.name, partition.name))
                return error.DuplicateAndroidOtaPartition;
        const operation_start = operations.items.len;
        var input_offset: usize = 0;
        while (input_offset < partition.data.len) {
            if (operations.items.len >= options.max_operations)
                return error.OutputLimitExceeded;
            const length = @min(
                options.operation_size,
                partition.data.len - input_offset,
            );
            const chunk = partition.data[input_offset..][0..length];
            var selected = try selectBlob(allocator, chunk, options);
            errdefer if (selected.owned_data) |bytes| allocator.free(bytes);
            var digest: [32]u8 = undefined;
            if (selected.data.len != 0)
                std.crypto.hash.sha2.Sha256.hash(selected.data, &digest, .{})
            else
                @memset(&digest, 0);
            const block_count = length / block_size;
            try operations.append(allocator, .{
                .kind = selected.kind,
                .first_block = input_offset / block_size,
                .block_count = block_count,
                .data_offset = data_offset,
                .data_len = selected.data.len,
                .data = selected.data,
                .owned_data = selected.owned_data,
                .sha256 = digest,
            });
            selected.owned_data = null;
            data_offset = std.math.add(
                u64,
                data_offset,
                operations.items[operations.items.len - 1].data_len,
            ) catch return error.IntegerOverflow;
            input_offset += length;
        }
        var partition_digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(
            partition.data,
            &partition_digest,
            .{},
        );
        try planned_partitions.append(allocator, .{
            .name = partition.name,
            .size = partition.data.len,
            .operation_start = operation_start,
            .operation_count = operations.items.len - operation_start,
            .sha256 = partition_digest,
        });
    }

    const manifest = try encodeManifestAlloc(
        allocator,
        planned_partitions.items,
        operations.items,
        options.block_size,
    );
    defer allocator.free(manifest);
    const metadata_size = std.math.add(
        usize,
        format.header_size,
        manifest.len,
    ) catch return error.IntegerOverflow;
    const total_size_u64 = std.math.add(u64, metadata_size, data_offset) catch
        return error.IntegerOverflow;
    if (total_size_u64 > options.max_output_len)
        return error.OutputLimitExceeded;
    const total_size = std.math.cast(usize, total_size_u64) orelse
        return error.OutputLimitExceeded;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.ensureTotalCapacity(allocator, total_size);
    try output.appendSlice(allocator, format.magic);
    try format.appendU64Be(allocator, &output, format.major_version);
    try format.appendU64Be(allocator, &output, manifest.len);
    try format.appendU32Be(allocator, &output, 0);
    try output.appendSlice(allocator, manifest);
    for (operations.items) |operation|
        try output.appendSlice(allocator, operation.data);
    std.debug.assert(output.items.len == total_size);
    return output.toOwnedSlice(allocator);
}

pub fn validateOptions(
    partition_count: usize,
    options: EncodeOptions,
) Error!usize {
    const block_size: usize = options.block_size;
    if (block_size == 0 or block_size % 4 != 0 or
        block_size > options.max_block_size)
        return error.InvalidAndroidOta;
    if (options.operation_size == 0 or
        options.operation_size % block_size != 0)
        return error.InvalidAndroidOta;
    if (partition_count > options.max_partitions)
        return error.OutputLimitExceeded;
    return block_size;
}

pub fn selectBlob(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error!SelectedBlob {
    if (options.sparse_zero_blocks and allZero(input))
        return .{ .kind = .zero, .data = "", .owned_data = null };
    return switch (options.compression) {
        .raw => .{ .kind = .replace, .data = input, .owned_data = null },
        .bzip2 => blk: {
            const encoded = try bzip2.encodeAlloc(allocator, input, .{
                .block_size_100k = options.bzip2_block_size_100k,
            });
            break :blk .{
                .kind = .replace_bz,
                .data = encoded,
                .owned_data = encoded,
            };
        },
        .xz => blk: {
            const encoded = try xz.encodeAlloc(allocator, input, .{
                .check = .crc32,
                .block_size = options.xz_block_size,
            });
            break :blk .{
                .kind = .replace_xz,
                .data = encoded,
                .owned_data = encoded,
            };
        },
        .auto => try selectSmallestBlob(allocator, input, options),
    };
}

fn selectSmallestBlob(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error!SelectedBlob {
    const xz_bytes = try xz.encodeAlloc(allocator, input, .{
        .check = .crc32,
        .block_size = options.xz_block_size,
    });
    errdefer allocator.free(xz_bytes);
    const bzip2_bytes = try bzip2.encodeAlloc(allocator, input, .{
        .block_size_100k = options.bzip2_block_size_100k,
    });
    errdefer allocator.free(bzip2_bytes);
    if (xz_bytes.len < input.len and xz_bytes.len <= bzip2_bytes.len) {
        allocator.free(bzip2_bytes);
        return .{ .kind = .replace_xz, .data = xz_bytes, .owned_data = xz_bytes };
    }
    if (bzip2_bytes.len < input.len) {
        allocator.free(xz_bytes);
        return .{ .kind = .replace_bz, .data = bzip2_bytes, .owned_data = bzip2_bytes };
    }
    allocator.free(xz_bytes);
    allocator.free(bzip2_bytes);
    return .{ .kind = .replace, .data = input, .owned_data = null };
}

pub fn encodeManifestAlloc(
    allocator: std.mem.Allocator,
    partitions: []const PlannedPartition,
    operations: []const PlannedOperation,
    block_size: u32,
) Error![]u8 {
    var manifest: std.ArrayList(u8) = .empty;
    errdefer manifest.deinit(allocator);
    try protobuf.appendVarintField(allocator, &manifest, 3, block_size);
    try protobuf.appendVarintField(allocator, &manifest, 12, 0);
    for (partitions) |partition| {
        var partition_message: std.ArrayList(u8) = .empty;
        defer partition_message.deinit(allocator);
        try protobuf.appendBytesField(
            allocator,
            &partition_message,
            1,
            partition.name,
        );
        var info_message: std.ArrayList(u8) = .empty;
        defer info_message.deinit(allocator);
        try protobuf.appendVarintField(
            allocator,
            &info_message,
            1,
            partition.size,
        );
        try protobuf.appendBytesField(
            allocator,
            &info_message,
            2,
            &partition.sha256,
        );
        try protobuf.appendMessageField(
            allocator,
            &partition_message,
            7,
            info_message.items,
        );
        for (operations[partition.operation_start..][0..partition.operation_count]) |operation| {
            var operation_message: std.ArrayList(u8) = .empty;
            defer operation_message.deinit(allocator);
            try protobuf.appendVarintField(
                allocator,
                &operation_message,
                1,
                @intFromEnum(operation.kind),
            );
            if (operation.data_len != 0) {
                try protobuf.appendVarintField(
                    allocator,
                    &operation_message,
                    2,
                    operation.data_offset,
                );
                try protobuf.appendVarintField(
                    allocator,
                    &operation_message,
                    3,
                    operation.data_len,
                );
            }
            var extent_message: std.ArrayList(u8) = .empty;
            defer extent_message.deinit(allocator);
            try protobuf.appendVarintField(
                allocator,
                &extent_message,
                1,
                operation.first_block,
            );
            try protobuf.appendVarintField(
                allocator,
                &extent_message,
                2,
                operation.block_count,
            );
            try protobuf.appendMessageField(
                allocator,
                &operation_message,
                6,
                extent_message.items,
            );
            if (operation.data_len != 0)
                try protobuf.appendBytesField(
                    allocator,
                    &operation_message,
                    8,
                    &operation.sha256,
                );
            try protobuf.appendMessageField(
                allocator,
                &partition_message,
                8,
                operation_message.items,
            );
        }
        try protobuf.appendMessageField(
            allocator,
            &manifest,
            13,
            partition_message.items,
        );
    }
    return manifest.toOwnedSlice(allocator);
}

fn allZero(bytes: []const u8) bool {
    for (bytes) |byte| if (byte != 0) return false;
    return true;
}

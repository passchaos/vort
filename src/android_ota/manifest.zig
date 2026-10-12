const std = @import("std");
const format = @import("format.zig");
const protobuf = @import("protobuf.zig");

pub const Error = format.Error || protobuf.Error || std.mem.Allocator.Error;

pub const ParseOptions = struct {
    max_partitions: usize,
    max_operations: usize,
    max_extents: usize,
    max_partition_name_bytes: usize,
    max_block_size: usize,
    max_partition_size: u64,
};

pub const Parsed = struct {
    manifest: format.Manifest,
    partitions: []format.Partition,
    operations: []format.Operation,
    extents: []format.Extent,

    pub fn deinit(self: *Parsed, allocator: std.mem.Allocator) void {
        allocator.free(self.partitions);
        allocator.free(self.operations);
        allocator.free(self.extents);
        self.* = undefined;
    }
};

const Context = struct {
    allocator: std.mem.Allocator,
    options: ParseOptions,
    partitions: std.ArrayList(format.Partition) = .empty,
    operations: std.ArrayList(format.Operation) = .empty,
    extents: std.ArrayList(format.Extent) = .empty,

    fn deinit(self: *Context) void {
        self.partitions.deinit(self.allocator);
        self.operations.deinit(self.allocator);
        self.extents.deinit(self.allocator);
    }
};

pub fn parseAlloc(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    options: ParseOptions,
) Error!Parsed {
    var context = Context{ .allocator = allocator, .options = options };
    errdefer context.deinit();
    var block_size: u64 = 4096;
    var block_size_seen = false;
    var minor_version: u64 = 0;
    var minor_seen = false;
    var signatures_offset: ?u64 = null;
    var signatures_size: ?u64 = null;

    var reader = protobuf.Reader.init(bytes);
    while (try reader.next()) |field| switch (field.number) {
        3 => {
            if (block_size_seen) return error.InvalidAndroidOta;
            block_size_seen = true;
            block_size = try protobuf.expectVarint(field);
        },
        4 => {
            if (signatures_offset != null) return error.InvalidAndroidOta;
            signatures_offset = try protobuf.expectVarint(field);
        },
        5 => {
            if (signatures_size != null) return error.InvalidAndroidOta;
            signatures_size = try protobuf.expectVarint(field);
        },
        12 => {
            if (minor_seen) return error.InvalidAndroidOta;
            minor_seen = true;
            minor_version = try protobuf.expectVarint(field);
        },
        13 => {
            if (context.partitions.items.len >= options.max_partitions)
                return error.OutputLimitExceeded;
            try parsePartition(&context, try protobuf.expectBytes(field));
        },
        else => {},
    };
    if (block_size == 0 or block_size % 4 != 0 or
        block_size > options.max_block_size)
        return error.InvalidAndroidOta;
    if (minor_version > std.math.maxInt(u32)) return error.InvalidAndroidOta;
    if ((signatures_offset == null) != (signatures_size == null))
        return error.InvalidAndroidOta;
    const partitions = try context.partitions.toOwnedSlice(allocator);
    errdefer allocator.free(partitions);
    const operations = try context.operations.toOwnedSlice(allocator);
    errdefer allocator.free(operations);
    const extents = try context.extents.toOwnedSlice(allocator);
    return .{
        .manifest = .{
            .block_size = @intCast(block_size),
            .minor_version = @intCast(minor_version),
            .signatures_offset = signatures_offset,
            .signatures_size = signatures_size,
        },
        .partitions = partitions,
        .operations = operations,
        .extents = extents,
    };
}

fn parsePartition(context: *Context, bytes: []const u8) Error!void {
    var name: ?[]const u8 = null;
    var old_info: ?format.PartitionInfo = null;
    var new_info: ?format.PartitionInfo = null;
    const operation_start = context.operations.items.len;
    var reader = protobuf.Reader.init(bytes);
    while (try reader.next()) |field| switch (field.number) {
        1 => {
            if (name != null) return error.InvalidAndroidOta;
            const value = try protobuf.expectBytes(field);
            if (value.len == 0 or
                value.len > context.options.max_partition_name_bytes)
                return error.InvalidAndroidOta;
            name = value;
        },
        6 => {
            if (old_info != null) return error.InvalidAndroidOta;
            old_info = try parsePartitionInfo(
                try protobuf.expectBytes(field),
                context.options.max_partition_size,
            );
        },
        7 => {
            if (new_info != null) return error.InvalidAndroidOta;
            new_info = try parsePartitionInfo(
                try protobuf.expectBytes(field),
                context.options.max_partition_size,
            );
        },
        8 => {
            if (context.operations.items.len >= context.options.max_operations)
                return error.OutputLimitExceeded;
            try parseOperation(context, try protobuf.expectBytes(field));
        },
        else => {},
    };
    const partition_name = name orelse return error.InvalidAndroidOta;
    for (context.partitions.items) |partition|
        if (std.mem.eql(u8, partition.name, partition_name))
            return error.DuplicateAndroidOtaPartition;
    try context.partitions.append(context.allocator, .{
        .name = partition_name,
        .old_info = old_info,
        .new_info = new_info orelse return error.InvalidAndroidOta,
        .operation_start = operation_start,
        .operation_count = context.operations.items.len - operation_start,
    });
}

fn parsePartitionInfo(
    bytes: []const u8,
    max_partition_size: u64,
) Error!format.PartitionInfo {
    var size: u64 = 0;
    var size_seen = false;
    var hash: ?[]const u8 = null;
    var reader = protobuf.Reader.init(bytes);
    while (try reader.next()) |field| switch (field.number) {
        1 => {
            if (size_seen) return error.InvalidAndroidOta;
            size_seen = true;
            size = try protobuf.expectVarint(field);
        },
        2 => {
            if (hash != null) return error.InvalidAndroidOta;
            const value = try protobuf.expectBytes(field);
            if (value.len != 0 and value.len != 32)
                return error.InvalidAndroidOta;
            hash = value;
        },
        else => {},
    };
    if (size > max_partition_size) return error.OutputLimitExceeded;
    return .{ .size = size, .hash = hash orelse "" };
}

fn parseOperation(context: *Context, bytes: []const u8) Error!void {
    var kind: ?format.OperationType = null;
    var data_offset: u64 = 0;
    var data_offset_seen = false;
    var data_length: u64 = 0;
    var data_length_seen = false;
    var src_length: ?u64 = null;
    var dst_length: ?u64 = null;
    var data_hash: ?[]const u8 = null;
    var src_hash: ?[]const u8 = null;
    var src_extents: std.ArrayList(format.Extent) = .empty;
    defer src_extents.deinit(context.allocator);
    var dst_extents: std.ArrayList(format.Extent) = .empty;
    defer dst_extents.deinit(context.allocator);

    var reader = protobuf.Reader.init(bytes);
    while (try reader.next()) |field| switch (field.number) {
        1 => {
            if (kind != null) return error.InvalidAndroidOta;
            const raw = try protobuf.expectVarint(field);
            if (raw > std.math.maxInt(u32)) return error.InvalidAndroidOta;
            kind = @enumFromInt(@as(u32, @intCast(raw)));
        },
        2 => {
            if (data_offset_seen) return error.InvalidAndroidOta;
            data_offset_seen = true;
            data_offset = try protobuf.expectVarint(field);
        },
        3 => {
            if (data_length_seen) return error.InvalidAndroidOta;
            data_length_seen = true;
            data_length = try protobuf.expectVarint(field);
        },
        4 => try appendExtent(context, &src_extents, try protobuf.expectBytes(field)),
        5 => {
            if (src_length != null) return error.InvalidAndroidOta;
            src_length = try protobuf.expectVarint(field);
        },
        6 => try appendExtent(context, &dst_extents, try protobuf.expectBytes(field)),
        7 => {
            if (dst_length != null) return error.InvalidAndroidOta;
            dst_length = try protobuf.expectVarint(field);
        },
        8 => {
            if (data_hash != null) return error.InvalidAndroidOta;
            data_hash = try parseHash(field);
        },
        9 => {
            if (src_hash != null) return error.InvalidAndroidOta;
            src_hash = try parseHash(field);
        },
        else => {},
    };
    if (dst_extents.items.len == 0) return error.InvalidAndroidOta;
    const after_source = std.math.add(
        usize,
        context.extents.items.len,
        src_extents.items.len,
    ) catch return error.IntegerOverflow;
    const after_destination = std.math.add(
        usize,
        after_source,
        dst_extents.items.len,
    ) catch return error.IntegerOverflow;
    if (after_destination > context.options.max_extents)
        return error.OutputLimitExceeded;
    const src_extent_start = context.extents.items.len;
    try context.extents.appendSlice(context.allocator, src_extents.items);
    const dst_extent_start = context.extents.items.len;
    try context.extents.appendSlice(context.allocator, dst_extents.items);
    try context.operations.append(context.allocator, .{
        .kind = kind orelse return error.InvalidAndroidOta,
        .data_offset = data_offset,
        .data_length = data_length,
        .src_extent_start = src_extent_start,
        .src_extent_count = src_extents.items.len,
        .dst_extent_start = dst_extent_start,
        .dst_extent_count = dst_extents.items.len,
        .src_length = src_length,
        .dst_length = dst_length,
        .data_sha256_hash = data_hash orelse "",
        .src_sha256_hash = src_hash orelse "",
    });
}

fn appendExtent(
    context: *Context,
    list: *std.ArrayList(format.Extent),
    bytes: []const u8,
) Error!void {
    const pending = std.math.add(
        usize,
        context.extents.items.len,
        list.items.len,
    ) catch return error.IntegerOverflow;
    if (pending >= context.options.max_extents)
        return error.OutputLimitExceeded;
    var start_block: u64 = 0;
    var start_seen = false;
    var num_blocks: u64 = 0;
    var count_seen = false;
    var reader = protobuf.Reader.init(bytes);
    while (try reader.next()) |field| switch (field.number) {
        1 => {
            if (start_seen) return error.InvalidAndroidOta;
            start_seen = true;
            start_block = try protobuf.expectVarint(field);
        },
        2 => {
            if (count_seen) return error.InvalidAndroidOta;
            count_seen = true;
            num_blocks = try protobuf.expectVarint(field);
        },
        else => {},
    };
    if (num_blocks == 0) return error.InvalidAndroidOta;
    try list.append(context.allocator, .{
        .start_block = start_block,
        .num_blocks = num_blocks,
    });
}

fn parseHash(field: protobuf.Field) Error![]const u8 {
    const hash = try protobuf.expectBytes(field);
    if (hash.len != 0 and hash.len != 32) return error.InvalidAndroidOta;
    return hash;
}

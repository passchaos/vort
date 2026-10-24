//! Two-pass Android OTA writer over seekable partition sources.
//!
//! Pass one retains only operation metadata and hashes. Pass two re-reads and
//! deterministically recompresses each operation before writing it to a caller
//! sink, so neither complete partition images nor the complete payload wire are
//! retained. Sources must remain byte-stable across both passes.

const std = @import("std");
const format = @import("format.zig");
const source_mod = @import("source.zig");
const writer = @import("writer.zig");

pub const Error = writer.Error || source_mod.Error || std.mem.Allocator.Error || error{
    SinkWriteFailed,
    UnstableAndroidOtaSource,
};

pub const EncodePartition = struct {
    name: []const u8,
    source: source_mod.Source,
};

pub const Sink = struct {
    context: *anyopaque,
    write: *const fn (
        context: *anyopaque,
        bytes: []const u8,
    ) error{SinkWriteFailed}!usize,

    pub fn writeAll(self: Sink, bytes: []const u8) Error!void {
        var written: usize = 0;
        while (written < bytes.len) {
            const amount = try self.write(self.context, bytes[written..]);
            if (amount == 0 or amount > bytes.len - written)
                return error.SinkWriteFailed;
            written += amount;
        }
    }
};

pub const Result = struct {
    bytes_written: u64,
    operation_count: usize,
};

pub fn encodeTo(
    allocator: std.mem.Allocator,
    partitions: []const EncodePartition,
    options: writer.EncodeOptions,
    sink: Sink,
) Error!Result {
    const block_size = try writer.validateOptions(partitions.len, options);
    var max_chunk: usize = 0;
    for (partitions, 0..) |partition, partition_index| {
        if (partition.name.len == 0 or
            partition.name.len > options.max_partition_name_bytes or
            partition.source.len % block_size != 0)
        {
            return error.InvalidAndroidOta;
        }
        for (partitions[0..partition_index]) |previous|
            if (std.mem.eql(u8, previous.name, partition.name))
                return error.DuplicateAndroidOtaPartition;
        if (partition.source.len != 0)
            max_chunk = @max(max_chunk, @min(
                options.operation_size,
                std.math.cast(usize, partition.source.len) orelse
                    options.operation_size,
            ));
    }
    const buffer = try allocator.alloc(u8, max_chunk);
    defer allocator.free(buffer);

    var planned_partitions: std.ArrayList(writer.PlannedPartition) = .empty;
    defer planned_partitions.deinit(allocator);
    var operations: std.ArrayList(writer.PlannedOperation) = .empty;
    defer operations.deinit(allocator);
    var data_offset: u64 = 0;
    for (partitions) |partition| {
        const operation_start = operations.items.len;
        var partition_hash = std.crypto.hash.sha2.Sha256.init(.{});
        var input_offset: u64 = 0;
        while (input_offset < partition.source.len) {
            if (operations.items.len >= options.max_operations)
                return error.OutputLimitExceeded;
            const remaining = partition.source.len - input_offset;
            const length = @min(
                buffer.len,
                std.math.cast(usize, remaining) orelse buffer.len,
            );
            const chunk = buffer[0..length];
            try partition.source.readExact(input_offset, chunk);
            partition_hash.update(chunk);
            const selected = try writer.selectBlob(allocator, chunk, options);
            defer if (selected.owned_data) |bytes| allocator.free(bytes);
            var digest: [32]u8 = undefined;
            if (selected.data.len == 0)
                @memset(&digest, 0)
            else
                std.crypto.hash.sha2.Sha256.hash(selected.data, &digest, .{});
            try operations.append(allocator, .{
                .kind = selected.kind,
                .first_block = input_offset / block_size,
                .block_count = length / block_size,
                .data_offset = data_offset,
                .data_len = selected.data.len,
                .data = "",
                .owned_data = null,
                .sha256 = digest,
            });
            data_offset = std.math.add(u64, data_offset, selected.data.len) catch
                return error.IntegerOverflow;
            input_offset += length;
        }
        var digest: [32]u8 = undefined;
        partition_hash.final(&digest);
        try planned_partitions.append(allocator, .{
            .name = partition.name,
            .size = partition.source.len,
            .operation_start = operation_start,
            .operation_count = operations.items.len - operation_start,
            .sha256 = digest,
        });
    }

    const manifest = try writer.encodeManifestAlloc(
        allocator,
        planned_partitions.items,
        operations.items,
        options.block_size,
    );
    defer allocator.free(manifest);
    const metadata_size = std.math.add(usize, format.header_size, manifest.len) catch
        return error.IntegerOverflow;
    const total_size = std.math.add(u64, metadata_size, data_offset) catch
        return error.IntegerOverflow;
    if (total_size > options.max_output_len) return error.OutputLimitExceeded;
    var header: [format.header_size]u8 = undefined;
    @memcpy(header[0..4], format.magic);
    std.mem.writeInt(u64, header[4..12], format.major_version, .big);
    std.mem.writeInt(u64, header[12..20], manifest.len, .big);
    std.mem.writeInt(u32, header[20..24], 0, .big);
    try sink.writeAll(&header);
    try sink.writeAll(manifest);

    for (planned_partitions.items, partitions) |planned, partition| {
        for (operations.items[planned.operation_start..][0..planned.operation_count]) |operation| {
            const input_offset = std.math.mul(
                u64,
                operation.first_block,
                block_size,
            ) catch return error.IntegerOverflow;
            const length_u64 = std.math.mul(
                u64,
                operation.block_count,
                block_size,
            ) catch return error.IntegerOverflow;
            const length = std.math.cast(usize, length_u64) orelse
                return error.OutputLimitExceeded;
            const chunk = buffer[0..length];
            try partition.source.readExact(input_offset, chunk);
            const selected = try writer.selectBlob(allocator, chunk, options);
            defer if (selected.owned_data) |bytes| allocator.free(bytes);
            if (selected.kind != operation.kind or
                selected.data.len != operation.data_len)
            {
                return error.UnstableAndroidOtaSource;
            }
            if (selected.data.len != 0) {
                var digest: [32]u8 = undefined;
                std.crypto.hash.sha2.Sha256.hash(selected.data, &digest, .{});
                if (!std.mem.eql(u8, &digest, &operation.sha256))
                    return error.UnstableAndroidOtaSource;
                try sink.writeAll(selected.data);
            }
        }
    }
    return .{
        .bytes_written = total_size,
        .operation_count = operations.items.len,
    };
}

test "Android OTA sink completes short writes and rejects stalled output" {
    const Context = struct {
        bytes: std.ArrayList(u8) = .empty,
        allocator: std.mem.Allocator,
        max_chunk: usize,
        stall: bool = false,

        fn write(
            raw_context: *anyopaque,
            input: []const u8,
        ) error{SinkWriteFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw_context));
            if (self.stall) return 0;
            const amount = @min(input.len, self.max_chunk);
            self.bytes.appendSlice(self.allocator, input[0..amount]) catch
                return error.SinkWriteFailed;
            return amount;
        }
    };
    var context = Context{ .allocator = std.testing.allocator, .max_chunk = 2 };
    defer context.bytes.deinit(std.testing.allocator);
    try (Sink{ .context = &context, .write = Context.write }).writeAll("short writes");
    try std.testing.expectEqualSlices(u8, "short writes", context.bytes.items);
    context.stall = true;
    try std.testing.expectError(
        error.SinkWriteFailed,
        (Sink{ .context = &context, .write = Context.write }).writeAll("x"),
    );
}

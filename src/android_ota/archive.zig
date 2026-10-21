const std = @import("std");
const decoder = @import("decoder.zig");
const format = @import("format.zig");
const manifest_mod = @import("manifest.zig");
const signatures = @import("signatures.zig");

pub const Error = format.Error || manifest_mod.Error || decoder.Error ||
    signatures.Error || std.mem.Allocator.Error;

pub const OpenOptions = struct {
    max_manifest_size: usize = 64 * 1024 * 1024,
    max_metadata_signature_size: usize = 16 * 1024 * 1024,
    max_partitions: usize = 4096,
    max_operations: usize = 1 << 24,
    max_extents: usize = 1 << 24,
    max_partition_name_bytes: usize = 4096,
    max_block_size: usize = 64 * 1024 * 1024,
    max_partition_size: u64 = 1 << 50,
    max_blob_size: u64 = 4 * 1024 * 1024 * 1024,
    verify_data_hashes: bool = true,
    max_data_hash_bytes: u64 = 64 * 1024 * 1024 * 1024,
};

pub const DecodeOptions = decoder.Options;
pub const SignatureLimits = signatures.Limits;
pub const SignaturePublicKey = signatures.PublicKey;
pub const SignatureMatch = signatures.Match;

pub const SignatureVerificationOptions = struct {
    limits: SignatureLimits = .{},
    require_metadata: bool = true,
    require_payload: bool = true,
};

pub const SignatureVerificationResult = struct {
    metadata: ?SignatureMatch,
    payload: ?SignatureMatch,
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    header: format.Header,
    manifest: format.Manifest,
    partitions: []format.Partition,
    operations: []format.Operation,
    extents: []format.Extent,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        input: []const u8,
        options: OpenOptions,
    ) Error!Archive {
        if (input.len < format.header_size) return error.TruncatedFrame;
        if (!std.mem.eql(u8, input[0..4], format.magic))
            return error.InvalidMagic;
        const major = format.readU64Be(input, 4);
        if (major != format.major_version) return error.UnsupportedVersion;
        const manifest_size_u64 = format.readU64Be(input, 12);
        const manifest_size = std.math.cast(usize, manifest_size_u64) orelse
            return error.OutputLimitExceeded;
        if (manifest_size > options.max_manifest_size)
            return error.OutputLimitExceeded;
        const metadata_signature_size: usize = format.readU32Be(input, 20);
        if (metadata_signature_size > options.max_metadata_signature_size)
            return error.OutputLimitExceeded;
        const metadata_size = std.math.add(
            usize,
            format.header_size,
            manifest_size,
        ) catch return error.IntegerOverflow;
        const data_offset = std.math.add(
            usize,
            metadata_size,
            metadata_signature_size,
        ) catch return error.IntegerOverflow;
        if (data_offset > input.len) return error.TruncatedFrame;
        var parsed = try manifest_mod.parseAlloc(
            allocator,
            input[format.header_size..metadata_size],
            .{
                .max_partitions = options.max_partitions,
                .max_operations = options.max_operations,
                .max_extents = options.max_extents,
                .max_partition_name_bytes = options.max_partition_name_bytes,
                .max_block_size = options.max_block_size,
                .max_partition_size = options.max_partition_size,
            },
        );
        errdefer parsed.deinit(allocator);
        try validateManifestGeometry(input.len - data_offset, parsed, options);
        if (options.verify_data_hashes)
            try verifyDataHashesSlice(input, data_offset, parsed);
        return .{
            .allocator = allocator,
            .bytes = input,
            .header = .{
                .major = major,
                .manifest_size = manifest_size,
                .metadata_signature_size = metadata_signature_size,
                .metadata_size = metadata_size,
                .data_offset = data_offset,
                .physical_size = input.len,
            },
            .manifest = parsed.manifest,
            .partitions = parsed.partitions,
            .operations = parsed.operations,
            .extents = parsed.extents,
        };
    }

    pub fn deinit(self: *Archive) void {
        self.allocator.free(self.partitions);
        self.allocator.free(self.operations);
        self.allocator.free(self.extents);
        self.* = undefined;
    }

    pub fn metadataSignature(self: Archive) []const u8 {
        return self.bytes[self.header.metadata_size..self.header.data_offset];
    }

    pub fn payloadSignature(self: Archive) ?[]const u8 {
        const offset = self.manifest.signatures_offset orelse return null;
        const size = self.manifest.signatures_size.?;
        const start = self.header.data_offset + @as(usize, @intCast(offset));
        return self.bytes[start..][0..@intCast(size)];
    }

    pub fn operationBlob(self: Archive, operation: format.Operation) []const u8 {
        const start = self.header.data_offset + @as(usize, @intCast(operation.data_offset));
        return self.bytes[start..][0..@intCast(operation.data_length)];
    }

    pub fn verifySignatures(
        self: Archive,
        keys: []const SignaturePublicKey,
        options: SignatureVerificationOptions,
    ) Error!SignatureVerificationResult {
        const metadata = if (self.metadataSignature().len == 0) blk: {
            if (options.require_metadata) return error.AndroidOtaSignatureMissing;
            break :blk null;
        } else blk: {
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(
                self.bytes[0..self.header.metadata_size],
                &digest,
                .{},
            );
            break :blk try signatures.verifyAny(
                try signatures.parse(self.metadataSignature(), options.limits),
                keys,
                &digest,
            );
        };
        const payload_bytes = self.payloadSignature();
        const payload = if (payload_bytes == null) blk: {
            if (options.require_payload) return error.AndroidOtaSignatureMissing;
            break :blk null;
        } else blk: {
            const signature_offset = self.manifest.signatures_offset.?;
            const signed_end_u64 = std.math.add(
                u64,
                self.header.data_offset,
                signature_offset,
            ) catch return error.IntegerOverflow;
            const signed_end = std.math.cast(usize, signed_end_u64) orelse
                return error.OutputLimitExceeded;
            if (signed_end > self.bytes.len) return error.TruncatedFrame;
            var hasher = std.crypto.hash.sha2.Sha256.init(.{});
            hasher.update(self.bytes[0..self.header.metadata_size]);
            hasher.update(self.bytes[self.header.data_offset..signed_end]);
            var digest: [32]u8 = undefined;
            hasher.final(&digest);
            break :blk try signatures.verifyAny(
                try signatures.parse(payload_bytes.?, options.limits),
                keys,
                &digest,
            );
        };
        return .{ .metadata = metadata, .payload = payload };
    }

    pub fn findPartition(self: Archive, name: []const u8) ?usize {
        for (self.partitions, 0..) |partition, index|
            if (std.mem.eql(u8, partition.name, name)) return index;
        return null;
    }

    pub fn partitionOperations(
        self: Archive,
        partition: format.Partition,
    ) []const format.Operation {
        return self.operations[partition.operation_start..][0..partition.operation_count];
    }

    pub fn operationSourceExtents(
        self: Archive,
        operation: format.Operation,
    ) []const format.Extent {
        return self.extents[operation.src_extent_start..][0..operation.src_extent_count];
    }

    pub fn operationDestinationExtents(
        self: Archive,
        operation: format.Operation,
    ) []const format.Extent {
        return self.extents[operation.dst_extent_start..][0..operation.dst_extent_count];
    }

    pub fn decodePartitionAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        partition_index: usize,
        source: ?[]const u8,
        max_output_len: usize,
    ) Error![]u8 {
        return self.decodePartitionAllocWithOptions(
            allocator,
            partition_index,
            source,
            .{ .max_output_len = max_output_len },
        );
    }

    pub fn decodePartitionAllocWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        partition_index: usize,
        source: ?[]const u8,
        options: DecodeOptions,
    ) Error![]u8 {
        if (partition_index >= self.partitions.len)
            return error.RangeOutOfBounds;
        const partition = self.partitions[partition_index];
        const size = std.math.cast(usize, partition.new_info.size) orelse
            return error.OutputLimitExceeded;
        if (size > options.max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, size);
        errdefer allocator.free(output);
        try self.readPartitionRangeInto(
            allocator,
            partition_index,
            source,
            0,
            output,
            options,
        );
        return output;
    }

    pub fn decodePartitionByNameAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        source: ?[]const u8,
        max_output_len: usize,
    ) Error![]u8 {
        const index = self.findPartition(name) orelse
            return error.RangeOutOfBounds;
        return self.decodePartitionAllocLimited(
            allocator,
            index,
            source,
            max_output_len,
        );
    }

    pub fn readPartitionRangeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        partition_index: usize,
        source: ?[]const u8,
        offset: u64,
        length: usize,
        max_output_len: usize,
    ) Error![]u8 {
        if (length > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, length);
        errdefer allocator.free(output);
        try self.readPartitionRangeInto(
            allocator,
            partition_index,
            source,
            offset,
            output,
            .{
                .max_output_len = max_output_len,
                .verify_partition_hash = false,
            },
        );
        return output;
    }

    pub fn readPartitionRangeInto(
        self: Archive,
        allocator: std.mem.Allocator,
        partition_index: usize,
        source: ?[]const u8,
        offset: u64,
        output: []u8,
        options: DecodeOptions,
    ) Error!void {
        return decoder.readPartitionRangeInto(.{
            .payload = .{ .bytes = self.bytes },
            .data_offset = self.header.data_offset,
            .block_size = self.manifest.block_size,
            .partitions = self.partitions,
            .operations = self.operations,
            .extents = self.extents,
        }, allocator, partition_index, source, offset, output, options);
    }
};

pub fn validateManifestGeometry(
    data_size: u64,
    parsed: manifest_mod.Parsed,
    options: OpenOptions,
) Error!void {
    var previous_blob_end: u64 = 0;
    var hash_bytes: u64 = 0;
    for (parsed.partitions) |partition| {
        const partition_blocks = divCeil(
            partition.new_info.size,
            parsed.manifest.block_size,
        );
        for (parsed.operations[partition.operation_start..][0..partition.operation_count]) |operation| {
            const source_extents = parsed.extents[operation.src_extent_start..][0..operation.src_extent_count];
            const destination_extents = parsed.extents[operation.dst_extent_start..][0..operation.dst_extent_count];
            const destination_bytes = try validateExtents(
                destination_extents,
                parsed.manifest.block_size,
                partition_blocks,
                false,
            );
            const source_blocks = if (partition.old_info) |old_info|
                divCeil(old_info.size, parsed.manifest.block_size)
            else
                0;
            const source_bytes = try validateExtents(
                source_extents,
                parsed.manifest.block_size,
                source_blocks,
                true,
            );
            if (operation.dst_length) |length|
                if (length > destination_bytes) return error.InvalidAndroidOta;
            if (operation.src_length) |length|
                if (length > source_bytes) return error.InvalidAndroidOta;
            if (operation.data_length > options.max_blob_size)
                return error.OutputLimitExceeded;
            const blob_end = std.math.add(
                u64,
                operation.data_offset,
                operation.data_length,
            ) catch return error.IntegerOverflow;
            if (blob_end > data_size) return error.TruncatedFrame;
            if (operation.data_length != 0) {
                if (operation.data_offset < previous_blob_end)
                    return error.InvalidAndroidOta;
                previous_blob_end = blob_end;
            }
            switch (operation.kind) {
                .replace => {
                    if (operation.data_length != destination_bytes or
                        source_extents.len != 0)
                        return error.InvalidAndroidOta;
                },
                .replace_bz, .replace_xz => {
                    if (operation.data_length == 0 or source_extents.len != 0)
                        return error.InvalidAndroidOta;
                },
                .zero, .discard => {
                    if (operation.data_length != 0 or source_extents.len != 0)
                        return error.InvalidAndroidOta;
                },
                .source_copy => {
                    if (operation.data_length != 0 or
                        source_extents.len == 0 or source_bytes != destination_bytes or
                        partition.old_info == null)
                        return error.InvalidAndroidOta;
                },
                .move => return error.UnsupportedAndroidOtaOperation,
                .bsdiff,
                .source_bsdiff,
                .brotli_bsdiff,
                .puffdiff,
                .zucchini,
                .lz4diff_bsdiff,
                .lz4diff_puffdiff,
                => if (operation.data_length == 0 or source_extents.len == 0)
                    return error.InvalidAndroidOta,
                else => {},
            }
            if (operation.data_sha256_hash.len != 0) {
                hash_bytes = std.math.add(
                    u64,
                    hash_bytes,
                    operation.data_length,
                ) catch return error.IntegerOverflow;
                if (hash_bytes > options.max_data_hash_bytes)
                    return error.OutputLimitExceeded;
            }
        }
    }
    if (parsed.manifest.signatures_offset) |offset| {
        const size = parsed.manifest.signatures_size.?;
        const end = std.math.add(u64, offset, size) catch
            return error.IntegerOverflow;
        if (offset < previous_blob_end or end > data_size)
            return error.TruncatedFrame;
    }
}

fn verifyDataHashesSlice(
    input: []const u8,
    data_offset: usize,
    parsed: manifest_mod.Parsed,
) Error!void {
    for (parsed.operations) |operation| {
        if (operation.data_sha256_hash.len == 0) continue;
        const relative = std.math.cast(usize, operation.data_offset) orelse
            return error.OutputLimitExceeded;
        const length = std.math.cast(usize, operation.data_length) orelse
            return error.OutputLimitExceeded;
        const start = std.math.add(usize, data_offset, relative) catch
            return error.IntegerOverflow;
        if (start > input.len or length > input.len - start)
            return error.TruncatedFrame;
        try verifySha256(input[start..][0..length], operation.data_sha256_hash);
    }
}

fn validateExtents(
    extents: []const format.Extent,
    block_size: usize,
    partition_blocks: u64,
    allow_sparse_hole: bool,
) Error!u64 {
    var blocks: u64 = 0;
    for (extents) |extent| {
        if (extent.start_block == format.sparse_hole) {
            if (!allow_sparse_hole) return error.InvalidAndroidOta;
        } else {
            const end = std.math.add(
                u64,
                extent.start_block,
                extent.num_blocks,
            ) catch return error.IntegerOverflow;
            if (end > partition_blocks) return error.InvalidAndroidOta;
        }
        blocks = std.math.add(u64, blocks, extent.num_blocks) catch
            return error.IntegerOverflow;
    }
    return std.math.mul(u64, blocks, block_size) catch
        return error.IntegerOverflow;
}

fn divCeil(value: u64, divisor: usize) u64 {
    return value / divisor + @intFromBool(value % divisor != 0);
}

fn verifySha256(bytes: []const u8, expected: []const u8) Error!void {
    if (expected.len != 32) return error.InvalidAndroidOta;
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
    if (!std.mem.eql(u8, &actual, expected)) return error.ChecksumMismatch;
}

//! Source-backed Android OTA parsing and range extraction.
//!
//! Only the bounded header, manifest, and metadata signature are retained.
//! Operation blobs and old-partition extents remain in caller-owned random-
//! access sources and are read only when an intersecting operation is decoded.

const std = @import("std");
const archive_mod = @import("archive.zig");
const decoder = @import("decoder.zig");
const format = @import("format.zig");
const manifest_mod = @import("manifest.zig");
const signatures = @import("signatures.zig");
const source_mod = @import("source.zig");

pub const Error = archive_mod.Error || decoder.Error || source_mod.Error ||
    std.mem.Allocator.Error;

pub const Archive = struct {
    allocator: std.mem.Allocator,
    source: source_mod.Source,
    metadata: []u8,
    header: format.Header,
    manifest: format.Manifest,
    partitions: []format.Partition,
    operations: []format.Operation,
    extents: []format.Extent,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        source: source_mod.Source,
        options: archive_mod.OpenOptions,
    ) Error!Archive {
        var fixed: [format.header_size]u8 = undefined;
        try source.readExact(0, &fixed);
        if (!std.mem.eql(u8, fixed[0..4], format.magic))
            return error.InvalidMagic;
        const major = format.readU64Be(&fixed, 4);
        if (major != format.major_version) return error.UnsupportedVersion;
        const manifest_size_u64 = format.readU64Be(&fixed, 12);
        const manifest_size = std.math.cast(usize, manifest_size_u64) orelse
            return error.OutputLimitExceeded;
        if (manifest_size > options.max_manifest_size)
            return error.OutputLimitExceeded;
        const signature_size: usize = format.readU32Be(&fixed, 20);
        if (signature_size > options.max_metadata_signature_size)
            return error.OutputLimitExceeded;
        const metadata_size = std.math.add(
            usize,
            format.header_size,
            manifest_size,
        ) catch return error.IntegerOverflow;
        const data_offset = std.math.add(
            usize,
            metadata_size,
            signature_size,
        ) catch return error.IntegerOverflow;
        if (data_offset > source.len) return error.TruncatedFrame;
        const metadata = try allocator.alloc(u8, data_offset);
        errdefer allocator.free(metadata);
        try source.readExact(0, metadata);
        var parsed = try manifest_mod.parseAlloc(
            allocator,
            metadata[format.header_size..metadata_size],
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
        try archive_mod.validateManifestGeometry(
            source.len - data_offset,
            parsed,
            options,
        );
        if (options.verify_data_hashes)
            try verifyDataHashes(source, data_offset, parsed);
        return .{
            .allocator = allocator,
            .source = source,
            .metadata = metadata,
            .header = .{
                .major = major,
                .manifest_size = manifest_size,
                .metadata_signature_size = signature_size,
                .metadata_size = metadata_size,
                .data_offset = data_offset,
                .physical_size = source.len,
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
        self.allocator.free(self.metadata);
        self.* = undefined;
    }

    pub fn metadataSignature(self: Archive) []const u8 {
        return self.metadata[self.header.metadata_size..self.header.data_offset];
    }

    pub fn payloadSignatureAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_size: usize,
    ) Error!?[]u8 {
        const offset = self.manifest.signatures_offset orelse return null;
        const size = self.manifest.signatures_size.?;
        return try self.source.readAllocLimited(
            allocator,
            try absoluteOffset(self.header.data_offset, offset),
            size,
            max_size,
        );
    }

    pub fn operationBlobAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        operation: format.Operation,
        max_size: usize,
    ) Error![]u8 {
        return self.source.readAllocLimited(
            allocator,
            try absoluteOffset(self.header.data_offset, operation.data_offset),
            operation.data_length,
            max_size,
        );
    }

    pub fn verifySignatures(
        self: Archive,
        allocator: std.mem.Allocator,
        keys: []const archive_mod.SignaturePublicKey,
        options: archive_mod.SignatureVerificationOptions,
    ) Error!archive_mod.SignatureVerificationResult {
        const metadata = if (self.metadataSignature().len == 0) blk: {
            if (options.require_metadata) return error.AndroidOtaSignatureMissing;
            break :blk null;
        } else blk: {
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(
                self.metadata[0..self.header.metadata_size],
                &digest,
                .{},
            );
            break :blk try signatures.verifyAny(
                try signatures.parse(self.metadataSignature(), options.limits),
                keys,
                &digest,
            );
        };
        const payload = if (self.manifest.signatures_offset == null) blk: {
            if (options.require_payload) return error.AndroidOtaSignatureMissing;
            break :blk null;
        } else blk: {
            const signature_bytes = (try self.payloadSignatureAllocLimited(
                allocator,
                options.limits.max_blob_size,
            )).?;
            defer allocator.free(signature_bytes);
            var hasher = std.crypto.hash.sha2.Sha256.init(.{});
            try self.source.updateSha256(0, self.header.metadata_size, &hasher);
            try self.source.updateSha256(
                self.header.data_offset,
                self.manifest.signatures_offset.?,
                &hasher,
            );
            var digest: [32]u8 = undefined;
            hasher.final(&digest);
            break :blk try signatures.verifyAny(
                try signatures.parse(signature_bytes, options.limits),
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

    pub fn decodePartitionAllocWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        partition_index: usize,
        old_source: ?source_mod.Source,
        options: archive_mod.DecodeOptions,
    ) Error![]u8 {
        if (partition_index >= self.partitions.len) return error.RangeOutOfBounds;
        const size = std.math.cast(
            usize,
            self.partitions[partition_index].new_info.size,
        ) orelse return error.OutputLimitExceeded;
        if (size > options.max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, size);
        errdefer allocator.free(output);
        try self.readPartitionRangeInto(
            allocator,
            partition_index,
            old_source,
            0,
            output,
            options,
        );
        return output;
    }

    pub fn decodePartitionAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        partition_index: usize,
        old_source: ?source_mod.Source,
        max_output_len: usize,
    ) Error![]u8 {
        return self.decodePartitionAllocWithOptions(
            allocator,
            partition_index,
            old_source,
            .{ .max_output_len = max_output_len },
        );
    }

    pub fn decodePartitionByNameAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        old_source: ?source_mod.Source,
        max_output_len: usize,
    ) Error![]u8 {
        const index = self.findPartition(name) orelse return error.RangeOutOfBounds;
        return self.decodePartitionAllocLimited(
            allocator,
            index,
            old_source,
            max_output_len,
        );
    }

    pub fn readPartitionRangeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        partition_index: usize,
        old_source: ?source_mod.Source,
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
            old_source,
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
        old_source: ?source_mod.Source,
        offset: u64,
        output: []u8,
        options: archive_mod.DecodeOptions,
    ) Error!void {
        return decoder.readPartitionRangeIntoInputs(
            .{
                .payload = .{ .source = self.source },
                .data_offset = self.header.data_offset,
                .block_size = self.manifest.block_size,
                .partitions = self.partitions,
                .operations = self.operations,
                .extents = self.extents,
            },
            allocator,
            partition_index,
            if (old_source) |source| .{ .source = source } else null,
            offset,
            output,
            options,
        );
    }
};

fn verifyDataHashes(
    source: source_mod.Source,
    data_offset: usize,
    parsed: manifest_mod.Parsed,
) Error!void {
    for (parsed.operations) |operation| {
        if (operation.data_sha256_hash.len == 0) continue;
        try source.verifySha256(
            try absoluteOffset(data_offset, operation.data_offset),
            operation.data_length,
            operation.data_sha256_hash,
        );
    }
}

fn absoluteOffset(base: usize, relative: u64) Error!u64 {
    return std.math.add(u64, base, relative) catch error.IntegerOverflow;
}

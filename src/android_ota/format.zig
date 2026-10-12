const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidAndroidOta,
    InvalidProtobuf,
    UnsupportedProtobufWireType,
    UnsupportedAndroidOtaOperation,
    MissingAndroidOtaSource,
    DuplicateAndroidOtaPartition,
    IncompleteAndroidOtaPartition,
    InvalidBsdiffPatch,
    UnsupportedBsdiffCompression,
};

pub const magic = "CrAU";
pub const major_version: u64 = 2;
pub const header_size: usize = 24;
pub const sparse_hole = std.math.maxInt(u64);

const std = @import("std");

pub const OperationType = enum(u32) {
    replace = 0,
    replace_bz = 1,
    move = 2,
    bsdiff = 3,
    source_copy = 4,
    source_bsdiff = 5,
    zero = 6,
    discard = 7,
    replace_xz = 8,
    puffdiff = 9,
    brotli_bsdiff = 10,
    zucchini = 11,
    lz4diff_bsdiff = 12,
    lz4diff_puffdiff = 13,
    _,
};

pub const Header = struct {
    major: u64,
    manifest_size: usize,
    metadata_signature_size: usize,
    metadata_size: usize,
    data_offset: usize,
    physical_size: usize,
};

pub const Manifest = struct {
    block_size: usize,
    minor_version: u32,
    signatures_offset: ?u64,
    signatures_size: ?u64,
};

pub const PartitionInfo = struct {
    size: u64,
    hash: []const u8,
};

pub const Extent = struct {
    start_block: u64,
    num_blocks: u64,
};

pub const Operation = struct {
    kind: OperationType,
    data_offset: u64,
    data_length: u64,
    src_extent_start: usize,
    src_extent_count: usize,
    dst_extent_start: usize,
    dst_extent_count: usize,
    src_length: ?u64,
    dst_length: ?u64,
    data_sha256_hash: []const u8,
    src_sha256_hash: []const u8,
};

pub const Partition = struct {
    name: []const u8,
    old_info: ?PartitionInfo,
    new_info: PartitionInfo,
    operation_start: usize,
    operation_count: usize,
};

pub fn readU32Be(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .big);
}

pub fn readU64Be(input: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, input[offset..][0..8], .big);
}

pub fn appendU32Be(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u32,
) std.mem.Allocator.Error!void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .big);
    try output.appendSlice(allocator, &bytes);
}

pub fn appendU64Be(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u64,
) std.mem.Allocator.Error!void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .big);
    try output.appendSlice(allocator, &bytes);
}

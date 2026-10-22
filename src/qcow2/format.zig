const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidQcow2,
    UnsupportedQcow2Feature,
    UnsupportedQcow2Compression,
    MissingQcow2BackingFile,
    MissingQcow2DataFile,
    EncryptedQcow2,
};

pub const magic: u32 = 0x5146_49fb;
pub const min_cluster_bits: u32 = 9;
pub const max_cluster_bits: u32 = 21;
pub const compressed_flag: u64 = @as(u64, 1) << 62;
pub const copied_flag: u64 = @as(u64, 1) << 63;
pub const zero_flag: u64 = 1;
pub const offset_mask: u64 = 0x00ff_ffff_ffff_fe00;
pub const l1_reserved_mask: u64 = 0x7f00_0000_0000_01ff;
pub const l2_standard_reserved_mask: u64 = 0x3f00_0000_0000_01fe;

pub const incompat_dirty: u64 = 1 << 0;
pub const incompat_corrupt: u64 = 1 << 1;
pub const incompat_data_file: u64 = 1 << 2;
pub const incompat_compression: u64 = 1 << 3;
pub const incompat_extended_l2: u64 = 1 << 4;
pub const known_incompat = incompat_dirty | incompat_corrupt |
    incompat_data_file | incompat_compression | incompat_extended_l2;
pub const autoclear_data_file_raw: u64 = 1 << 1;

pub const CompressionType = enum(u8) {
    zlib = 0,
    zstd = 1,
};

pub const Header = struct {
    version: u32,
    header_length: usize,
    cluster_bits: u32,
    cluster_size: usize,
    virtual_size: u64,
    crypt_method: u32,
    l1_size: usize,
    l1_table_offset: u64,
    refcount_table_offset: u64,
    refcount_table_clusters: u32,
    snapshot_count: u32,
    snapshots_offset: u64,
    incompatible_features: u64,
    compatible_features: u64,
    autoclear_features: u64,
    refcount_order: u32,
    compression_type: CompressionType,
    backing_file_offset: u64,
    backing_file_size: usize,
    backing_file_name: []const u8,
    data_file_name: []const u8,

    pub fn hasBackingFile(self: Header) bool {
        return self.backing_file_offset != 0;
    }

    pub fn hasExternalDataFile(self: Header) bool {
        return self.incompatible_features & incompat_data_file != 0;
    }

    pub fn hasExtendedL2(self: Header) bool {
        return self.incompatible_features & incompat_extended_l2 != 0;
    }

    pub fn hasRawExternalDataFile(self: Header) bool {
        return self.autoclear_features & autoclear_data_file_raw != 0;
    }

    pub fn l2EntrySize(self: Header) usize {
        return if (self.hasExtendedL2()) 16 else 8;
    }

    pub fn l2Entries(self: Header) usize {
        return self.cluster_size / self.l2EntrySize();
    }
};

pub fn parseHeader(input: []const u8) Error!Header {
    if (input.len < 72) return error.TruncatedFrame;
    if (readU32Be(input, 0) != magic) return error.InvalidMagic;
    const version = readU32Be(input, 4);
    if (version != 2 and version != 3) return error.UnsupportedVersion;
    const backing_file_offset = readU64Be(input, 8);
    const backing_file_size: usize = readU32Be(input, 16);
    if ((backing_file_offset == 0) != (backing_file_size == 0) or
        backing_file_size > 1023)
        return error.InvalidQcow2;
    const cluster_bits = readU32Be(input, 20);
    if (cluster_bits < min_cluster_bits or cluster_bits > max_cluster_bits)
        return error.InvalidQcow2;
    const cluster_size = @as(usize, 1) << @intCast(cluster_bits);
    if (input.len < cluster_size) return error.TruncatedFrame;
    const virtual_size = readU64Be(input, 24);
    const crypt_method = readU32Be(input, 32);
    if (crypt_method != 0) return error.EncryptedQcow2;
    const l1_size: usize = readU32Be(input, 36);
    const l1_table_offset = readU64Be(input, 40);
    const refcount_table_offset = readU64Be(input, 48);
    const refcount_table_clusters = readU32Be(input, 56);
    const snapshot_count = readU32Be(input, 60);
    const snapshots_offset = readU64Be(input, 64);

    var header_length: usize = 72;
    var incompatible_features: u64 = 0;
    var compatible_features: u64 = 0;
    var autoclear_features: u64 = 0;
    var refcount_order: u32 = 4;
    var compression_type: CompressionType = .zlib;
    if (version == 3) {
        if (input.len < 104) return error.TruncatedFrame;
        incompatible_features = readU64Be(input, 72);
        compatible_features = readU64Be(input, 80);
        autoclear_features = readU64Be(input, 88);
        refcount_order = readU32Be(input, 96);
        header_length = readU32Be(input, 100);
        if (header_length < 104 or header_length > cluster_size or
            header_length & 7 != 0)
            return error.InvalidQcow2;
        if (header_length > input.len) return error.TruncatedFrame;
        if (header_length > 104) {
            compression_type = std.enums.fromInt(
                CompressionType,
                input[104],
            ) orelse return error.UnsupportedQcow2Compression;
            for (input[105..header_length]) |byte|
                if (byte != 0) return error.InvalidQcow2;
        }
        if (refcount_order > 6) return error.InvalidQcow2;
        if (incompatible_features & ~known_incompat != 0)
            return error.UnsupportedQcow2Feature;
        if (incompatible_features & incompat_corrupt != 0)
            return error.InvalidQcow2;
        if (incompatible_features & incompat_extended_l2 != 0 and
            cluster_bits < 14)
            return error.InvalidQcow2;
        const has_compression_feature = incompatible_features &
            incompat_compression != 0;
        if ((compression_type == .zlib and has_compression_feature) or
            (compression_type != .zlib and !has_compression_feature))
            return error.InvalidQcow2;
        if (autoclear_features & autoclear_data_file_raw != 0 and
            incompatible_features & incompat_data_file == 0)
            return error.InvalidQcow2;
    }
    const backing_end = std.math.add(
        u64,
        backing_file_offset,
        backing_file_size,
    ) catch return error.IntegerOverflow;
    if (backing_file_offset != 0 and
        (backing_file_offset < header_length or backing_end > cluster_size))
        return error.InvalidQcow2;
    const backing_start = std.math.cast(usize, backing_file_offset) orelse
        return error.IntegerOverflow;
    const backing_file_name = if (backing_file_size == 0)
        ""
    else
        input[backing_start..][0..backing_file_size];
    if (backing_file_size != 0 and
        autoclear_features & autoclear_data_file_raw != 0)
        return error.InvalidQcow2;
    const extension_limit = if (backing_file_size == 0)
        cluster_size
    else
        backing_start;
    const data_file_name = try parseDataFileExtension(
        input,
        header_length,
        extension_limit,
    );
    return .{
        .version = version,
        .header_length = header_length,
        .cluster_bits = cluster_bits,
        .cluster_size = cluster_size,
        .virtual_size = virtual_size,
        .crypt_method = crypt_method,
        .l1_size = l1_size,
        .l1_table_offset = l1_table_offset,
        .refcount_table_offset = refcount_table_offset,
        .refcount_table_clusters = refcount_table_clusters,
        .snapshot_count = snapshot_count,
        .snapshots_offset = snapshots_offset,
        .incompatible_features = incompatible_features,
        .compatible_features = compatible_features,
        .autoclear_features = autoclear_features,
        .refcount_order = refcount_order,
        .compression_type = compression_type,
        .backing_file_offset = backing_file_offset,
        .backing_file_size = backing_file_size,
        .backing_file_name = backing_file_name,
        .data_file_name = data_file_name,
    };
}

fn parseDataFileExtension(
    input: []const u8,
    start: usize,
    limit: usize,
) Error![]const u8 {
    var data_file_name: []const u8 = "";
    var cursor = start;
    while (cursor + 8 <= limit) {
        const magic_value = readU32Be(input, cursor);
        const length: usize = readU32Be(input, cursor + 4);
        if (magic_value == 0) {
            if (length != 0) return error.InvalidQcow2;
            break;
        }
        const payload = cursor + 8;
        if (length > limit - payload) return error.InvalidQcow2;
        const end = payload + length;
        const next = std.mem.alignForward(usize, end, 8);
        if (next > limit) return error.InvalidQcow2;
        if (magic_value == 0x4441_5441) {
            if (length == 0 or data_file_name.len != 0)
                return error.InvalidQcow2;
            data_file_name = input[payload..end];
        }
        cursor = next;
    }
    return data_file_name;
}

pub fn readU32Be(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .big);
}

pub fn readU64Be(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .big);
}

pub fn writeU32Be(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .big);
}

pub fn writeU64Be(bytes: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, bytes[offset..][0..8], value, .big);
}

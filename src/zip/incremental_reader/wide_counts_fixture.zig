//! Small ZIP64 records and mathematically proven repeat checkpoints.
const std = @import("std");
const core = @import("../../core.zig");
const checksum = @import("../../checksum.zig");
const wire = @import("../wire.zig");
pub const Count = core.StreamCount;
pub const boundary: Count = @as(Count, 1) << 32;
pub const name = "wide.bin";
pub const comment = "checked";
pub const archive_comment = "done";

// Nonfinal fixed block: literal x, length 258/distance 1, EOB; then an empty
// stored block and alignment. One complete repetition emits 259 x bytes and
// returns to the same byte-aligned block boundary. zlib independently decoded
// prefix + final_copy as exactly 517 x bytes.
pub const raw_prefix = [_]u8{ 0xaa, 0x18, 0x05, 0, 0, 0, 0, 0xff, 0xff };
pub const raw_final_copy = [_]u8{ 0x1b, 0x05, 0 };
pub const raw_prefix_output: usize = 259;

pub const Metadata = struct {
    compressed: Count,
    uncompressed: Count,
    crc32: u32,
    initial_offset: Count = 0,
    method: u16 = 0,
    descriptor: bool = true,
    signed: bool = true,
    encrypted: bool = false,
};

pub const Archive = struct {
    bytes: []u8,
    local_len: usize,
    descriptor_offset: usize,
    central_wire_offset: usize,
    central_absolute_offset: Count,
    zip64_end_wire_offset: usize,
    omitted_payload: Count,
};

pub fn create(allocator: std.mem.Allocator, metadata: Metadata, supplied_payload: []const u8) !Archive {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try local(allocator, &bytes, metadata);
    const local_len = bytes.items.len;
    try bytes.appendSlice(allocator, supplied_payload);
    const descriptor_offset = bytes.items.len;
    if (metadata.descriptor) try descriptorRecord(allocator, &bytes, metadata);
    const central_wire_offset = bytes.items.len;
    const descriptor_len: usize = if (!metadata.descriptor) 0 else if (metadata.signed) 24 else 20;
    const central_absolute = metadata.initial_offset + local_len + metadata.compressed + descriptor_len;
    try central(allocator, &bytes, metadata);
    const central_len = bytes.items.len - central_wire_offset;
    const zip64_end_wire_offset = bytes.items.len;
    try ending(allocator, &bytes, central_absolute, central_len);
    return .{
        .bytes = try bytes.toOwnedSlice(allocator),
        .local_len = local_len,
        .descriptor_offset = descriptor_offset,
        .central_wire_offset = central_wire_offset,
        .central_absolute_offset = central_absolute,
        .zip64_end_wire_offset = zip64_end_wire_offset,
        .omitted_payload = metadata.compressed - supplied_payload.len,
    };
}

pub fn local(allocator: std.mem.Allocator, bytes: *std.ArrayList(u8), metadata: Metadata) !void {
    try int(u32, allocator, bytes, wire.local_file_signature);
    try int(u16, allocator, bytes, 45);
    try int(u16, allocator, bytes, flags(metadata));
    try int(u16, allocator, bytes, metadata.method);
    try int(u16, allocator, bytes, 0);
    try int(u16, allocator, bytes, 33);
    try int(u32, allocator, bytes, if (metadata.descriptor) 0 else metadata.crc32);
    try int(u32, allocator, bytes, std.math.maxInt(u32));
    try int(u32, allocator, bytes, std.math.maxInt(u32));
    try int(u16, allocator, bytes, name.len);
    try int(u16, allocator, bytes, 20);
    try bytes.appendSlice(allocator, name);
    try int(u16, allocator, bytes, 1); // ZIP64 extra.
    try int(u16, allocator, bytes, 16);
    try int(u64, allocator, bytes, metadata.uncompressed);
    try int(u64, allocator, bytes, metadata.compressed);
}

fn descriptorRecord(allocator: std.mem.Allocator, bytes: *std.ArrayList(u8), metadata: Metadata) !void {
    if (metadata.signed) try int(u32, allocator, bytes, wire.data_descriptor_signature);
    try int(u32, allocator, bytes, metadata.crc32);
    try int(u64, allocator, bytes, metadata.compressed);
    try int(u64, allocator, bytes, metadata.uncompressed);
}

fn central(allocator: std.mem.Allocator, bytes: *std.ArrayList(u8), metadata: Metadata) !void {
    try int(u32, allocator, bytes, wire.central_file_signature);
    try int(u16, allocator, bytes, 45);
    try int(u16, allocator, bytes, 45);
    try int(u16, allocator, bytes, flags(metadata));
    try int(u16, allocator, bytes, metadata.method);
    try int(u16, allocator, bytes, 0);
    try int(u16, allocator, bytes, 33);
    try int(u32, allocator, bytes, metadata.crc32);
    try int(u32, allocator, bytes, std.math.maxInt(u32));
    try int(u32, allocator, bytes, std.math.maxInt(u32));
    try int(u16, allocator, bytes, name.len);
    try int(u16, allocator, bytes, 28);
    try int(u16, allocator, bytes, comment.len);
    try int(u16, allocator, bytes, 0); // Disk number.
    try int(u16, allocator, bytes, 0);
    try int(u32, allocator, bytes, 0);
    try int(u32, allocator, bytes, std.math.maxInt(u32));
    try bytes.appendSlice(allocator, name);
    try int(u16, allocator, bytes, 1);
    try int(u16, allocator, bytes, 24);
    try int(u64, allocator, bytes, metadata.uncompressed);
    try int(u64, allocator, bytes, metadata.compressed);
    try int(u64, allocator, bytes, metadata.initial_offset);
    try bytes.appendSlice(allocator, comment);
}

fn ending(allocator: std.mem.Allocator, bytes: *std.ArrayList(u8), central_offset: Count, central_len: usize) !void {
    const zip64_offset = central_offset + central_len;
    try int(u32, allocator, bytes, wire.zip64_end_of_central_signature);
    try int(u64, allocator, bytes, 44);
    try int(u16, allocator, bytes, 45);
    try int(u16, allocator, bytes, 45);
    try int(u32, allocator, bytes, 0);
    try int(u32, allocator, bytes, 0);
    try int(u64, allocator, bytes, 1);
    try int(u64, allocator, bytes, 1);
    try int(u64, allocator, bytes, central_len);
    try int(u64, allocator, bytes, central_offset);
    try int(u32, allocator, bytes, wire.zip64_end_of_central_locator_signature);
    try int(u32, allocator, bytes, 0);
    try int(u64, allocator, bytes, zip64_offset);
    try int(u32, allocator, bytes, 1);
    try int(u32, allocator, bytes, wire.end_of_central_signature);
    try int(u16, allocator, bytes, 0);
    try int(u16, allocator, bytes, 0);
    try int(u16, allocator, bytes, std.math.maxInt(u16));
    try int(u16, allocator, bytes, std.math.maxInt(u16));
    try int(u32, allocator, bytes, std.math.maxInt(u32));
    try int(u32, allocator, bytes, std.math.maxInt(u32));
    try int(u16, allocator, bytes, archive_comment.len);
    try bytes.appendSlice(allocator, archive_comment);
}

fn flags(metadata: Metadata) u16 {
    return (if (metadata.descriptor) @as(u16, 8) else 0) | (if (metadata.encrypted) @as(u16, 1) else 0);
}

fn int(comptime T: type, allocator: std.mem.Allocator, bytes: *std.ArrayList(u8), value: T) !void {
    var encoded: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &encoded, value, .little);
    try bytes.appendSlice(allocator, &encoded);
}

/// Public CRC concatenation exponentiation: no wide plaintext is allocated.
pub fn repeatedCrc(count: Count) u32 {
    var remaining = count;
    var digest: u32 = 0;
    var power = checksum.Crc32Best.hash("x");
    var power_len: u64 = 1;
    while (remaining != 0) {
        if (remaining & 1 != 0) digest = checksum.crc32Combine(digest, power, power_len);
        remaining >>= 1;
        if (remaining != 0) {
            power = checksum.crc32Combine(power, power, power_len);
            power_len *= 2;
        }
    }
    return digest;
}

pub fn crcWithSuffix(prefix_len: Count, suffix: []const u8) u32 {
    return checksum.crc32Combine(repeatedCrc(prefix_len), checksum.Crc32Best.hash(suffix), suffix.len);
}

pub fn applyRawRepeat(raw: anytype, blocks: Count) void {
    const decoded = blocks * raw_prefix_output;
    raw.total_input = blocks * raw_prefix.len;
    raw.total_output = decoded;
    raw.history_len = core.stream_count.bounded(decoded, raw.history.len);
    raw.history_pos = core.stream_count.ringIndex(decoded, raw.history.len);
    @memset(raw.history[0..raw.history_len], 'x');
}

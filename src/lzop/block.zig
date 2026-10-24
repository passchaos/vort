const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const lzo1x = @import("../lzo1x.zig");

pub const Error = core.Error || lzo1x.Error;

pub const Checksums = struct {
    data_adler: ?u32 = null,
    data_crc: ?u32 = null,
    compressed_adler: ?u32 = null,
    compressed_crc: ?u32 = null,
};

/// Decode and validate one complete LZOP block into caller-owned storage.
/// Compressed-payload checks are verified before decompression; decoded-data
/// checks are verified after the optional legacy delta filter is reversed.
pub fn decodeInto(
    payload: []const u8,
    output: []u8,
    filter: ?u32,
    expected: Checksums,
) Error!void {
    try validateCompressed(payload, expected);

    if (payload.len < output.len) {
        const written = lzo1x.decodeInto(payload, output) catch |err| switch (err) {
            error.OutputTooSmall => return error.SizeMismatch,
            else => |decode_error| return decode_error,
        };
        if (written != output.len) return error.SizeMismatch;
    } else {
        if (payload.len != output.len) return error.SizeMismatch;
        @memcpy(output, payload);
    }

    if (filter) |distance| applyDeltaFilter(output, @intCast(distance));
    if (expected.data_adler) |value|
        if (checksum.adler32(output) != value) return error.ChecksumMismatch;
    if (expected.data_crc) |value|
        if (checksum.crc32Best(output) != value) return error.ChecksumMismatch;
}

pub fn validateCompressed(payload: []const u8, expected: Checksums) Error!void {
    if (expected.compressed_adler) |value|
        if (checksum.adler32(payload) != value) return error.ChecksumMismatch;
    if (expected.compressed_crc) |value|
        if (checksum.crc32Best(payload) != value) return error.ChecksumMismatch;
}

fn applyDeltaFilter(bytes: []u8, distance_u8: u8) void {
    if (distance_u8 == 0 or bytes.len <= distance_u8) return;
    const distance: usize = distance_u8;
    for (distance..bytes.len) |index| bytes[index] +%= bytes[index - distance];
}

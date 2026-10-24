//! Seekable access to wimlib's pipable WIM resource layout.

const std = @import("std");
const core = @import("../core.zig");
const codec = @import("codec.zig");
const format = @import("format.zig");

pub const Error = core.Error || codec.Error || format.Error ||
    std.mem.Allocator.Error || error{InvalidWim};

pub const blob_magic: u64 = 0x2b9b_9ba2_443d_b9d8;
pub const blob_header_size: usize = 40;
pub const chunk_header_size: usize = 4;

pub fn validateBlobHeader(
    archive_bytes: []const u8,
    resource: format.ResourceHeader,
    expected_sha1: ?*const [20]u8,
) Error!void {
    if (resource.isZero()) {
        if (expected_sha1) |sha1| {
            if (!std.mem.allEqual(u8, sha1, 0)) return error.InvalidWim;
        }
        return;
    }
    if (archive_bytes.len < 2 * format.header_size) return error.TruncatedFrame;
    const resource_start = std.math.cast(usize, resource.offset_in_wim) orelse
        return error.IntegerOverflow;
    const stored_len = std.math.cast(usize, resource.size_in_wim) orelse
        return error.IntegerOverflow;
    _ = try checkedEnd(
        resource_start,
        stored_len,
        archive_bytes.len - format.header_size,
    );
    if (resource_start < format.header_size + blob_header_size)
        return error.InvalidWim;
    const header_start = resource_start - blob_header_size;
    const header_end = try checkedEnd(
        header_start,
        blob_header_size,
        archive_bytes.len,
    );
    const header = archive_bytes[header_start..header_end];
    if (format.readU64(header, 0) != blob_magic) return error.InvalidWim;
    if (format.readU64(header, 8) != resource.uncompressed_size)
        return error.InvalidWim;
    if (expected_sha1) |sha1| {
        if (!std.mem.eql(u8, header[16..36], sha1)) return error.InvalidWim;
    }
    const flags = format.readU32(header, 36);
    if (flags != resource.flags) return error.InvalidWim;
}

pub fn readCompressedAllocLimited(
    allocator: std.mem.Allocator,
    archive_bytes: []const u8,
    resource: format.ResourceHeader,
    compression: format.Compression,
    chunk_size: usize,
    max_output_len: usize,
) Error![]u8 {
    if (!resource.isCompressed() or resource.isSolid() or resource.isSpanned())
        return error.InvalidWim;
    if (compression == .none or chunk_size == 0) return error.InvalidWim;
    const output_len = std.math.cast(usize, resource.uncompressed_size) orelse
        return error.IntegerOverflow;
    if (output_len > max_output_len) return error.OutputLimitExceeded;
    if (output_len == 0) return error.InvalidWim;
    const stored_len = std.math.cast(usize, resource.size_in_wim) orelse
        return error.IntegerOverflow;
    const resource_start = std.math.cast(usize, resource.offset_in_wim) orelse
        return error.IntegerOverflow;
    const resource_end = try checkedEnd(resource_start, stored_len, archive_bytes.len);
    const chunk_count = (std.math.add(
        usize,
        output_len,
        chunk_size - 1,
    ) catch return error.IntegerOverflow) / chunk_size;
    const entry_size: usize = if (resource.uncompressed_size <= std.math.maxInt(u32)) 4 else 8;
    const table_size = std.math.mul(usize, chunk_count - 1, entry_size) catch
        return error.IntegerOverflow;
    const headers_size = std.math.mul(usize, chunk_count, chunk_header_size) catch
        return error.IntegerOverflow;
    const overhead = std.math.add(usize, table_size, headers_size) catch
        return error.IntegerOverflow;
    if (overhead > stored_len) return error.InvalidWim;
    const chunk_data_end = resource_end - table_size;
    const table = archive_bytes[chunk_data_end..resource_end];

    const output = try allocator.alloc(u8, output_len);
    errdefer allocator.free(output);
    var cursor = resource_start;
    var output_offset: usize = 0;
    var encoded_offset: u64 = 0;
    for (0..chunk_count) |chunk_index| {
        const header_end = try checkedEnd(
            cursor,
            chunk_header_size,
            chunk_data_end,
        );
        const encoded_len: usize = format.readU32(archive_bytes, cursor);
        cursor = header_end;
        const decoded_len = @min(chunk_size, output_len - output_offset);
        if (encoded_len == 0 or encoded_len > decoded_len) return error.InvalidWim;
        if (chunk_index > 0) {
            const table_offset = (chunk_index - 1) * entry_size;
            const recorded_offset = if (entry_size == 4)
                @as(u64, format.readU32(table, table_offset))
            else
                format.readU64(table, table_offset);
            if (recorded_offset != encoded_offset) return error.InvalidWim;
        }
        const encoded_end = try checkedEnd(cursor, encoded_len, chunk_data_end);
        const encoded = archive_bytes[cursor..encoded_end];
        const decoded = output[output_offset..][0..decoded_len];
        if (encoded_len == decoded_len) {
            @memcpy(decoded, encoded);
        } else {
            try codec.decodeChunkInto(
                allocator,
                compression,
                encoded,
                decoded,
                chunk_size,
            );
        }
        cursor = encoded_end;
        output_offset += decoded_len;
        encoded_offset = std.math.add(u64, encoded_offset, encoded_len) catch
            return error.IntegerOverflow;
    }
    if (cursor != chunk_data_end or output_offset != output.len)
        return error.InvalidWim;
    return output;
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, len) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

test "pipable resource validates blob header" {
    var bytes: [2 * format.header_size + blob_header_size + 3]u8 = @splat(0);
    const resource_start = format.header_size + blob_header_size;
    const header = bytes[format.header_size..resource_start];
    std.mem.writeInt(u64, header[0..8], blob_magic, .little);
    std.mem.writeInt(u64, header[8..16], 3, .little);
    @memset(header[16..36], 0x5a);
    std.mem.writeInt(u32, header[36..40], 0, .little);
    const resource = format.ResourceHeader{
        .size_in_wim = 3,
        .flags = 0,
        .offset_in_wim = resource_start,
        .uncompressed_size = 3,
    };
    const sha1: [20]u8 = @splat(0x5a);
    try validateBlobHeader(&bytes, resource, &sha1);
    var overlapping = resource;
    overlapping.size_in_wim += 1;
    try std.testing.expectError(
        error.TruncatedFrame,
        validateBlobHeader(&bytes, overlapping, &sha1),
    );
    bytes[format.header_size] ^= 1;
    try std.testing.expectError(
        error.InvalidWim,
        validateBlobHeader(&bytes, resource, &sha1),
    );
}

test "pipable resource decodes chunk headers and validates trailing table" {
    const allocator = std.testing.allocator;
    const chunk_size = 4096;
    const output_len = chunk_size + 904;
    const stored_len = chunk_header_size + chunk_size + chunk_header_size + 904 + 4;
    const bytes = try allocator.alloc(u8, stored_len);
    defer allocator.free(bytes);
    var cursor: usize = 0;
    std.mem.writeInt(u32, bytes[cursor..][0..4], chunk_size, .little);
    cursor += 4;
    @memset(bytes[cursor..][0..chunk_size], 'a');
    cursor += chunk_size;
    std.mem.writeInt(u32, bytes[cursor..][0..4], 904, .little);
    cursor += 4;
    @memset(bytes[cursor..][0..904], 'b');
    cursor += 904;
    std.mem.writeInt(u32, bytes[cursor..][0..4], chunk_size, .little);
    const resource = format.ResourceHeader{
        .size_in_wim = stored_len,
        .flags = 0x04,
        .offset_in_wim = 0,
        .uncompressed_size = output_len,
    };
    const output = try readCompressedAllocLimited(
        allocator,
        bytes,
        resource,
        .xpress,
        chunk_size,
        output_len,
    );
    defer allocator.free(output);
    try std.testing.expect(std.mem.allEqual(u8, output[0..chunk_size], 'a'));
    try std.testing.expect(std.mem.allEqual(u8, output[chunk_size..], 'b'));

    std.mem.writeInt(u32, bytes[cursor..][0..4], chunk_size - 1, .little);
    try std.testing.expectError(
        error.InvalidWim,
        readCompressedAllocLimited(
            allocator,
            bytes,
            resource,
            .xpress,
            chunk_size,
            output_len,
        ),
    );
}

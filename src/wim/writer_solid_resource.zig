const std = @import("std");
const core = @import("../core.zig");
const lzms_encoder = @import("../lzms/encoder.zig");
const format = @import("format.zig");
const plan_mod = @import("writer_plan.zig");
const solid = @import("solid.zig");

pub const Error = core.Error || lzms_encoder.Error || std.mem.Allocator.Error || error{
    InvalidWimWriterOptions,
    WimResourceTooLarge,
};

pub fn append(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    blobs: []plan_mod.Blob,
    chunk_size: usize,
) Error!?format.ResourceHeader {
    format.validateChunkSize(.lzms, chunk_size) catch
        return error.InvalidWimWriterOptions;
    var total_size: usize = 0;
    for (blobs) |blob|
        total_size = std.math.add(usize, total_size, blob.data.len) catch
            return error.IntegerOverflow;
    if (total_size == 0) return null;

    var logical_offset: usize = 0;
    for (blobs) |*blob| {
        blob.resource = .{
            .size_in_wim = blob.data.len,
            .flags = 0x10,
            .offset_in_wim = logical_offset,
            .uncompressed_size = 0,
        };
        logical_offset += blob.data.len;
    }
    std.debug.assert(logical_offset == total_size);

    const chunk_count = 1 + (total_size - 1) / chunk_size;
    const table_size = std.math.mul(usize, chunk_count, 4) catch
        return error.IntegerOverflow;
    const prefix_size = std.math.add(usize, 16, table_size) catch
        return error.IntegerOverflow;
    const resource_start = output.items.len;
    try output.appendNTimes(allocator, 0, prefix_size);
    writeU64(output.items, resource_start, total_size);
    writeU32(output.items, resource_start + 8, @intCast(chunk_size));
    writeU32(output.items, resource_start + 12, 3);

    const scratch = try allocator.alloc(u8, @min(total_size, chunk_size));
    defer allocator.free(scratch);
    var blob_index: usize = 0;
    var blob_offset: usize = 0;
    var input_offset: usize = 0;
    for (0..chunk_count) |chunk_index| {
        const decoded_len = @min(chunk_size, total_size - input_offset);
        var filled: usize = 0;
        while (filled < decoded_len) {
            const blob = blobs[blob_index];
            const count = @min(decoded_len - filled, blob.data.len - blob_offset);
            @memcpy(scratch[filled..][0..count], blob.data[blob_offset..][0..count]);
            filled += count;
            blob_offset += count;
            if (blob_offset == blob.data.len) {
                blob_index += 1;
                blob_offset = 0;
            }
        }
        const chunk = scratch[0..decoded_len];
        const encoded = try lzms_encoder.encodeAlloc(allocator, chunk);
        defer allocator.free(encoded);
        const stored = if (encoded.len < chunk.len) encoded else chunk;
        if (stored.len == 0 or stored.len > std.math.maxInt(u32))
            return error.WimResourceTooLarge;
        writeU32(
            output.items,
            resource_start + 16 + chunk_index * 4,
            @intCast(stored.len),
        );
        try output.appendSlice(allocator, stored);
        input_offset += decoded_len;
    }
    if (input_offset != total_size or blob_index != blobs.len or blob_offset != 0)
        return error.InvalidWimWriterOptions;
    const stored_size = output.items.len - resource_start;
    if (stored_size >= @as(u64, 1) << 56)
        return error.WimResourceTooLarge;
    return .{
        .size_in_wim = stored_size,
        .flags = 0x10,
        .offset_in_wim = resource_start,
        .uncompressed_size = solid.resource_magic,
    };
}

fn writeU32(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .little);
}

fn writeU64(output: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, output[offset..][0..8], value, .little);
}
